//
//  CityBoundary.swift
//  wander
//
//  Loads a city GeoJSON boundary, normalizes longitudes, turns it into H3
//  resolution 10 cells, caches the result, and computes the exploration
//  percentage against the locally discovered cells.
//

import Foundation
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

@MainActor
final class CityBoundary {
    static let shared = CityBoundary()

    let cityName = "Ho Chi Minh City"

    /// All H3 resolution 10 cell IDs inside the city boundary.
    private(set) var cityCellIDs: Set<String> = []

    /// Normalized city boundary coordinates, exposed for the fog overlay.
    private(set) var boundaryCoordinates: [CLLocationCoordinate2D] = []

    private lazy var cacheURL: URL = {
        let urls = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let appSupport = urls.first!.appendingPathComponent("wander", isDirectory: true)
        if !FileManager.default.fileExists(atPath: appSupport.path) {
            try? FileManager.default.createDirectory(at: appSupport, withIntermediateDirectories: true)
        }
        return appSupport.appendingPathComponent("city_hcm_cells.json")
    }()

    private init() {}

    /// Loads the city boundary cells from cache, or computes and caches them.
    /// The heavy H3 polyfill runs on a background task, the rest stays on MainActor.
    func load() async {
        guard parseHoChiMinhBoundary() != nil else {
            cityCellIDs = []
            return
        }

        if let cached = loadCached() {
            cityCellIDs = cached
            return
        }

        let ring = boundaryCoordinates.map {
            H3Coordinate(lat: $0.latitude, lng: $0.longitude)
        }
        let ids = await Task.detached(priority: .userInitiated) {
            let polygon = H3GeoPolygon(exterior: ring)
            let cells = polygon.fill(resolution: 10)
            return Set(cells.map { $0.description })
        }.value

        cityCellIDs = ids
        cache(ids)
    }

    /// Computes the current progress for the given discovered cells.
    func progress(against discoveredCells: [DiscoveredCell]) -> CityProgress {
        let discoveredIDs = Set(discoveredCells.map { $0.id })
        let explored = cityCellIDs.intersection(discoveredIDs)
        return CityProgress(
            cityName: cityName,
            totalCells: cityCellIDs.count,
            exploredCells: explored.count
        )
    }

    // MARK: - Parsing

    private func parseHoChiMinhBoundary() -> [H3Coordinate]? {
        guard let data = CityGeoJSONData.hoChiMinhCity.data(using: .utf8) else { return nil }

        do {
            let collection = try JSONDecoder().decode(GeoJSONFeatureCollection.self, from: data)
            guard let firstFeature = collection.features.first,
                  let ring = firstFeature.geometry.exteriorRing else { return nil }

            let h3Ring = ring.map { position -> H3Coordinate in
                let lon = normalizeLongitude(position[0])
                let lat = position[1]
                return H3Coordinate(lat: lat, lng: lon)
            }

            boundaryCoordinates = h3Ring.map {
                CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lng)
            }

            return h3Ring
        } catch {
            print("[CityBoundary] failed to parse GeoJSON: \(error.localizedDescription)")
            return nil
        }
    }

    /// Wraps a longitude into the [-180, 180] range.
    private func normalizeLongitude(_ longitude: Double) -> Double {
        var lon = longitude.truncatingRemainder(dividingBy: 360)
        if lon > 180 { lon -= 360 }
        if lon <= -180 { lon += 360 }
        return lon
    }

    // MARK: - Cache

    private func loadCached() -> Set<String>? {
        guard FileManager.default.fileExists(atPath: cacheURL.path) else { return nil }
        do {
            let data = try Data(contentsOf: cacheURL)
            let decoded = try JSONDecoder().decode([String].self, from: data)
            return Set(decoded)
        } catch {
            print("[CityBoundary] failed to load cache: \(error.localizedDescription)")
            return nil
        }
    }

    private func cache(_ ids: Set<String>) {
        do {
            let data = try JSONEncoder().encode(Array(ids))
            try data.write(to: cacheURL, options: .atomic)
        } catch {
            print("[CityBoundary] failed to cache city cells: \(error.localizedDescription)")
        }
    }
}
