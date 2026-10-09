import CoreGraphics
import CoreLocation
import H3
import XCTest
@testable import wander

final class MapboxFogGeometryTests: XCTestCase {
    func testEmptyExplorationCoversTheMap() {
        let polygons = MapboxFogGeometry.polygons(revealedRings: [])
        XCTAssertTrue(contains(polygons, latitude: 0, longitude: 0))
        XCTAssertTrue(contains(polygons, latitude: 80, longitude: 179))
    }

    func testRevealedPolygonDoesNotClearItsSurroundings() {
        let polygons = MapboxFogGeometry.polygons(revealedRings: [rectangle(10, 20, 11, 21)])
        XCTAssertFalse(contains(polygons, latitude: 10.5, longitude: 20.5))
        XCTAssertTrue(contains(polygons, latitude: 10.5, longitude: 21.1))
        assertValidRings(polygons)
    }

    func testAdjacentRevealedPolygonsHaveNoFogBetweenThem() {
        let polygons = MapboxFogGeometry.polygons(revealedRings: [
            rectangle(10, 20, 11, 21), rectangle(10, 21, 11, 22)
        ])
        for longitude in [20.5, 20.99999, 21, 21.00001, 21.5] {
            XCTAssertFalse(contains(polygons, latitude: 10.5, longitude: longitude))
        }
        XCTAssertTrue(contains(polygons, latitude: 10.5, longitude: 22.1))
        XCTAssertEqual(polygons.count, 1)
        XCTAssertEqual(polygons.first?.rings.count, 2)
    }

    func testH3NeighboursKeepAnUnexploredIslandCovered() throws {
        let center = H3Index(coordinate: H3Coordinate(lat: 37.57, lng: 126.98), resolution: 10)
        let neighbours = try XCTUnwrap(center.hexRing(k: 1))
        let polygons = MapboxFogGeometry.polygons(cellIDs: Set(neighbours.map(\.description)))
        XCTAssertTrue(contains(polygons, latitude: center.coordinate.lat, longitude: center.coordinate.lng))
        for cell in neighbours {
            XCTAssertFalse(contains(polygons, latitude: cell.coordinate.lat, longitude: cell.coordinate.lng))
        }
        assertValidRings(polygons)
    }

    func testAntimeridianRevealsBothEdgesWithoutClearingGreenwich() {
        let ring = rectangle(10, 179, 11, -179)
        let polygons = MapboxFogGeometry.polygons(revealedRings: [ring])
        XCTAssertFalse(contains(polygons, latitude: 10.5, longitude: 179.5))
        XCTAssertFalse(contains(polygons, latitude: 10.5, longitude: -179.5))
        XCTAssertTrue(contains(polygons, latitude: 10.5, longitude: 0))
        assertValidRings(polygons)
    }

    func testRealH3CellsCrossTheAntimeridianWithoutClearingGreenwich() {
        let center = H3Index(coordinate: H3Coordinate(lat: 0, lng: 179.99999), resolution: 10)
        let cells = center.kRing(k: 1)
        XCTAssertTrue(cells.contains { $0.coordinate.lng > 0 })
        XCTAssertTrue(cells.contains { $0.coordinate.lng < 0 })
        let polygons = MapboxFogGeometry.polygons(cellIDs: Set(cells.map(\.description)))
        for cell in cells {
            XCTAssertFalse(contains(polygons, latitude: cell.coordinate.lat, longitude: cell.coordinate.lng))
        }
        XCTAssertTrue(contains(polygons, latitude: 0, longitude: 0))
        assertValidRings(polygons)
    }

    func testLargeContiguousExplorationKeepsOnlyItsExteriorContour() {
        let center = H3Index(coordinate: H3Coordinate(lat: 37.57, lng: 126.98), resolution: 10)
        let cells = center.kRing(k: 18)
        let polygons = MapboxFogGeometry.polygons(cellIDs: Set(cells.map(\.description)))
        XCTAssertEqual(cells.count, 1027)
        XCTAssertEqual(polygons.count, 1)
        XCTAssertEqual(polygons.first?.rings.count, 2)
        XCTAssertLessThan(polygons.flatMap(\.rings).reduce(0) { $0 + $1.count }, cells.count)
        XCTAssertFalse(contains(polygons, latitude: center.coordinate.lat, longitude: center.coordinate.lng))
        assertValidRings(polygons)
    }

    func testOverlappingCellsClearTheirUnion() {
        let polygons = MapboxFogGeometry.polygons(revealedRings: [
            rectangle(10, 20, 12, 22), rectangle(11, 21, 13, 23)
        ])
        XCTAssertFalse(contains(polygons, latitude: 11.5, longitude: 21.5))
        XCTAssertFalse(contains(polygons, latitude: 12.5, longitude: 22.5))
        XCTAssertTrue(contains(polygons, latitude: 10.5, longitude: 22.5))
    }

    func testInvalidCellIDsDoNotRevealAnything() {
        let polygons = MapboxFogGeometry.polygons(cellIDs: ["invalid", "0", "ffffffffffffffff"])
        XCTAssertTrue(contains(polygons, latitude: 0, longitude: 0))
        assertValidRings(polygons)
    }

    func testReplacingExplorationRestoresFogOverRemovedCells() {
        let initial = MapboxFogGeometry.polygons(revealedRings: [rectangle(10, 20, 11, 21)])
        let replaced = MapboxFogGeometry.polygons(revealedRings: [rectangle(10, 22, 11, 23)])
        XCTAssertFalse(contains(initial, latitude: 10.5, longitude: 20.5))
        XCTAssertTrue(contains(replaced, latitude: 10.5, longitude: 20.5))
        XCTAssertFalse(contains(replaced, latitude: 10.5, longitude: 22.5))
    }

    private func rectangle(_ south: Double, _ west: Double, _ north: Double, _ east: Double)
        -> [CLLocationCoordinate2D] {
        [
            .init(latitude: south, longitude: west), .init(latitude: south, longitude: east),
            .init(latitude: north, longitude: east), .init(latitude: north, longitude: west)
        ]
    }

    private func contains(_ polygons: [MapboxFogGeometry.Polygon], latitude: Double, longitude: Double) -> Bool {
        polygons.contains { polygon in
            let path = CGMutablePath()
            for ring in polygon.rings {
                path.addLines(between: ring.map { CGPoint(x: $0.longitude, y: $0.latitude) })
                path.closeSubpath()
            }
            return path.contains(CGPoint(x: longitude, y: latitude), using: .evenOdd)
        }
    }

    private func assertValidRings(_ polygons: [MapboxFogGeometry.Polygon], file: StaticString = #filePath, line: UInt = #line) {
        for polygon in polygons {
            for ring in polygon.rings {
                XCTAssertGreaterThanOrEqual(ring.count, 4, file: file, line: line)
                XCTAssertEqual(ring.first?.latitude, ring.last?.latitude, file: file, line: line)
                XCTAssertEqual(ring.first?.longitude, ring.last?.longitude, file: file, line: line)
                for coordinate in ring {
                    XCTAssertTrue(CLLocationCoordinate2DIsValid(coordinate), file: file, line: line)
                }
            }
        }
    }
}
