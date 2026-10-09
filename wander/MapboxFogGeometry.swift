import Ch3
import CoreGraphics
import CoreLocation
import H3

/// Produces a planar world mask with the union of discovered cells removed.
enum MapboxFogGeometry {
    struct Polygon: Sendable {
        let rings: [[CLLocationCoordinate2D]]
    }

    private nonisolated static let scale = 100_000.0
    private nonisolated static let limit = 85.0511287798066

    nonisolated static func polygons(cellIDs: Set<String>) -> [Polygon] {
        var cellsByResolution: [Int: [H3.H3Index]] = [:]
        for id in cellIDs.sorted() {
            guard !Task.isCancelled else { return [] }
            guard let cell = H3.H3Index(string: id), cell.isValid else { continue }
            cellsByResolution[cell.resolution, default: []].append(cell)
        }
        var rings: [[CLLocationCoordinate2D]] = []
        for resolution in cellsByResolution.keys.sorted() {
            guard !Task.isCancelled else { return [] }
            rings.append(contentsOf: mergedRings(cells: cellsByResolution[resolution] ?? []))
        }
        return polygons(revealedRings: rings)
    }

    /// Remove shared H3 edges before CoreGraphics clips the remaining contours.
    /// Passing every touching hexagon to path subtraction scales poorly.
    private nonisolated static func mergedRings(cells: [H3.H3Index]) -> [[CLLocationCoordinate2D]] {
        guard !cells.isEmpty else { return [] }
        let rawCells = Set(cells.map(\.rawValue)).sorted()
        var polygon = LinkedGeoPolygon()
        guard cellsToLinkedMultiPolygon(rawCells, Int32(rawCells.count), &polygon) == 0 else {
            // H3 frees the linked output itself when normalization fails.
            return cells.map { $0.boundary().map { .init(latitude: $0.lat, longitude: $0.lng) } }
        }
        defer { destroyLinkedMultiPolygon(&polygon) }
        var rings: [[CLLocationCoordinate2D]] = []
        var currentPolygon: LinkedGeoPolygon? = polygon
        while let nextPolygon = currentPolygon {
            var loop = nextPolygon.first
            while let currentLoop = loop {
                guard !Task.isCancelled else { return [] }
                var ring: [CLLocationCoordinate2D] = []
                var vertex = currentLoop.pointee.first
                while let currentVertex = vertex {
                    let point = currentVertex.pointee.vertex
                    ring.append(.init(latitude: radsToDegs(point.lat), longitude: radsToDegs(point.lng)))
                    vertex = currentVertex.pointee.next
                }
                rings.append(ring)
                loop = currentLoop.pointee.next
            }
            currentPolygon = nextPolygon.next?.pointee
        }
        return rings
    }

    nonisolated static func polygons(revealedRings: [[CLLocationCoordinate2D]]) -> [Polygon] {
        let world = CGPath(rect: CGRect(x: -180 * scale, y: -180 * scale,
                                       width: 360 * scale, height: 360 * scale), transform: nil)
        let revealed = CGMutablePath()
        for ring in revealedRings where ring.count >= 3 {
            guard !Task.isCancelled else { return [] }
            guard ring.allSatisfy({ CLLocationCoordinate2DIsValid($0) }) else { continue }
            var previous = ring[0].longitude
            let points = ring.map { coordinate -> CGPoint in
                var longitude = coordinate.longitude
                while longitude - previous > 180 { longitude -= 360 }
                while longitude - previous < -180 { longitude += 360 }
                previous = longitude
                return project(latitude: coordinate.latitude, longitude: longitude)
            }
            // Include the opposite world edge when a cell crosses the date line.
            for shift in [-360.0, 0, 360] {
                let shifted = points.map { CGPoint(x: $0.x + shift * scale, y: $0.y) }
                let bounds = shifted.reduce(CGRect.null) { $0.union(CGRect(origin: $1, size: .zero)) }
                guard bounds.intersects(world.boundingBoxOfPath) else { continue }
                revealed.addLines(between: shifted)
                revealed.closeSubpath()
            }
        }

        // Boolean subtraction joins adjacent cells and clips crossings into
        // notches, rather than emitting invalid overlapping/touching holes.
        guard !Task.isCancelled else { return [] }
        let mask = world.subtracting(revealed, using: .winding)
        guard !Task.isCancelled else { return [] }
        return mask.componentsSeparated(using: .winding).compactMap { component in
            var rings: [[CGPoint]] = []
            var points: [CGPoint] = []
            component.applyWithBlock { element in
                switch element.pointee.type {
                case .moveToPoint:
                    points = [element.pointee.points[0]]
                case .addLineToPoint:
                    points.append(element.pointee.points[0])
                case .closeSubpath:
                    if points.count >= 3 {
                        if points.last != points.first { points.append(points[0]) }
                        rings.append(points)
                    }
                    points = []
                default:
                    break // Inputs contain only straight edges.
                }
            }
            guard !rings.isEmpty else { return nil }
            rings.sort { abs(area($0)) > abs(area($1)) }
            let coordinates = rings.enumerated().map { index, ring in
                let counterclockwise = area(ring) > 0
                let oriented = counterclockwise == (index == 0) ? ring : ring.reversed()
                return oriented.map(unproject)
            }
            return Polygon(rings: coordinates)
        }
    }

    private nonisolated static func project(latitude: Double, longitude: Double) -> CGPoint {
        let latitude = min(limit, max(-limit, latitude)) * .pi / 180
        return CGPoint(x: longitude * scale,
                       y: log(tan(.pi / 4 + latitude / 2)) * 180 / .pi * scale)
    }

    private nonisolated static func unproject(_ point: CGPoint) -> CLLocationCoordinate2D {
        let latitude = (2 * atan(exp(point.y / scale * .pi / 180)) - .pi / 2) * 180 / .pi
        return .init(latitude: min(limit, max(-limit, latitude)),
                     longitude: min(180, max(-180, point.x / scale)))
    }

    private nonisolated static func area(_ ring: [CGPoint]) -> Double {
        zip(ring, ring.dropFirst()).reduce(0) { $0 + $1.0.x * $1.1.y - $1.1.x * $1.0.y } / 2
    }
}
