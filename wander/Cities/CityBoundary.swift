//
//  CityBoundary.swift
//  wander
//
//  Multi-city support: loads GeoJSON boundaries for all supported cities,
//  caches H3 polyfill results per city, auto-detects which city the user
//  is currently in, and computes exploration progress.
//

import Foundation
import Combine
import CoreLocation
import H3

struct CityProgress {
    let cityName: String
    let totalCells: Int
    let exploredCells: Int

    var percentage: Double {
        guard totalCells > 0 else { return 0 }
        return Double(exploredCells) / Double(totalCells)
    }

    var percentageText: String {
        String(format: "%.1f%%", percentage * 100)
    }
}

struct WanderCity {
    let id: String
    let name: String
    let geojson: String
    let cacheKey: String
}

extension WanderCity {
    static let hoChiMinh = WanderCity(
        id: "hcm",
        name: "Ho Chi Minh City",
        geojson: CityGeoJSONData.hoChiMinhCity,
        cacheKey: "city_hcm_cells"
    )
    static let hoiAn = WanderCity(
        id: "hoian",
        name: "Hoi An",
        geojson: CityGeoJSONData.hoiAnCity,
        cacheKey: "city_hoian_cells"
    )
    static let seoul = WanderCity(
        id: "seoul",
        name: "Seoul",
        geojson: CityGeoJSONData.seoulCity,
        cacheKey: "city_seoul_cells"
    )
}

@MainActor
final class CityBoundary: ObservableObject {
    static let shared = CityBoundary()

    let allCities: [WanderCity] = [.hoChiMinh, .hoiAn, .seoul]

    @Published var currentCity: WanderCity = .hoChiMinh
    @Published var boundaryCoordinates: [CLLocationCoordinate2D] = []
    @Published var cityCellIDs: Set<String> = []

    private var cityData: [String: CityData] = [:]

    private struct CityData {
        let cells: Set<String>
        let coordinates: [CLLocationCoordinate2D]
    }

    private init() {}

    // MARK: - Load

    func load() async {
        for city in allCities {
            guard let data = await loadCity(city) else { continue }
            cityData[city.id] = data
        }

        if let data = cityData[currentCity.id] {
            cityCellIDs = data.cells
            boundaryCoordinates = data.coordinates
        } else if let fallback = allCities.first(where: { cityData[$0.id] != nil }) {
            currentCity = fallback
            cityCellIDs = cityData[fallback.id]!.cells
            boundaryCoordinates = cityData[fallback.id]!.coordinates
        }
    }

    private func loadCity(_ city: WanderCity) async -> CityData? {
        let cacheURL = cityCacheURL(for: city.cacheKey)

        // Parse boundary coordinates from GeoJSON.
        guard let (h3Ring, clRing) = parseBoundary(geojson: city.geojson) else { return nil }

        // Use cached H3 cells if available.
        if let cached = loadCachedCells(from: cacheURL) {
            return CityData(cells: cached, coordinates: clRing)
        }

        // Compute H3 polyfill (heavy — off the main actor).
        let ids = await Task.detached(priority: .userInitiated) {
            let polygon = H3GeoPolygon(exterior: h3Ring)
            let cells = polygon.fill(resolution: 10)
            return Set(cells.map { $0.description })
        }.value

        cacheCells(ids, to: cacheURL)
        return CityData(cells: ids, coordinates: clRing)
    }

    // MARK: - City detection

    func detectCity(for coordinate: CLLocationCoordinate2D) {
        for city in allCities {
            guard let data = cityData[city.id] else { continue }
            if isPoint(coordinate, inPolygon: data.coordinates) {
                if currentCity.id != city.id {
                    selectCity(city)
                }
                return
            }
        }
    }

    private func selectCity(_ city: WanderCity) {
        currentCity = city
        if let data = cityData[city.id] {
            cityCellIDs = data.cells
            boundaryCoordinates = data.coordinates
        }
    }

    // MARK: - Progress

    func progress(against discoveredCells: [DiscoveredCell]) -> CityProgress {
        let discoveredIDs = Set(discoveredCells.map { $0.id })
        let explored = cityCellIDs.intersection(discoveredIDs)
        return CityProgress(
            cityName: currentCity.name,
            totalCells: cityCellIDs.count,
            exploredCells: explored.count
        )
    }

    // MARK: - Point-in-polygon (ray casting)

    private func isPoint(_ point: CLLocationCoordinate2D,
                         inPolygon polygon: [CLLocationCoordinate2D]) -> Bool {
        guard polygon.count >= 3 else { return false }

        var inside = false
        var j = polygon.count - 1

        for i in 0..<polygon.count {
            let pi = polygon[i]
            let pj = polygon[j]

            let intersect = (pi.longitude > point.longitude) != (pj.longitude > point.longitude)
                && point.latitude < (pj.latitude - pi.latitude)
                    * (point.longitude - pi.longitude)
                    / (pj.longitude - pi.longitude)
                    + pi.latitude

            if intersect { inside.toggle() }
            j = i
        }

        return inside
    }

    // MARK: - Parsing

    private func parseBoundary(geojson: String) -> (h3Ring: [H3Coordinate], clRing: [CLLocationCoordinate2D])? {
        guard let data = geojson.data(using: .utf8) else { return nil }

        do {
            let collection = try JSONDecoder().decode(GeoJSONFeatureCollection.self, from: data)
            guard let firstFeature = collection.features.first,
                  let ring = firstFeature.geometry.exteriorRing else { return nil }

            let h3Ring = ring.map { position -> H3Coordinate in
                let lon = normalizeLongitude(position[0])
                let lat = position[1]
                return H3Coordinate(lat: lat, lng: lon)
            }

            let clRing = h3Ring.map {
                CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lng)
            }

            return (h3Ring, clRing)
        } catch {
            print("[CityBoundary] failed to parse GeoJSON: \(error.localizedDescription)")
            return nil
        }
    }

    private func normalizeLongitude(_ longitude: Double) -> Double {
        var lon = longitude.truncatingRemainder(dividingBy: 360)
        if lon > 180 { lon -= 360 }
        if lon <= -180 { lon += 360 }
        return lon
    }

    // MARK: - Cache

    private func appSupportDirectory() -> URL {
        guard let dir = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first else {
            fatalError("CityBoundary: applicationSupportDirectory not found")
        }
        let wanderDir = dir.appendingPathComponent("wander", isDirectory: true)
        if !FileManager.default.fileExists(atPath: wanderDir.path) {
            try? FileManager.default.createDirectory(at: wanderDir, withIntermediateDirectories: true)
        }
        return wanderDir
    }

    private func cityCacheURL(for key: String) -> URL {
        appSupportDirectory().appendingPathComponent("\(key).json")
    }

    private func loadCachedCells(from url: URL) -> Set<String>? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        do {
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode([String].self, from: data)
            return Set(decoded)
        } catch {
            print("[CityBoundary] failed to load cache: \(error.localizedDescription)")
            return nil
        }
    }

    private func cacheCells(_ ids: Set<String>, to url: URL) {
        do {
            let data = try JSONEncoder().encode(Array(ids))
            try data.write(to: url, options: .atomic)
        } catch {
            print("[CityBoundary] failed to cache city cells: \(error.localizedDescription)")
        }
    }
}
