import CoreGraphics
import XCTest
@testable import wander

@MainActor
final class SavedPlaceEmphasisLayoutTests: XCTestCase {
    private typealias Layout = SavedPlaceEmphasisLayout
    private let viewport = CGRect(x: 0, y: 0, width: 400, height: 800)

    func testFarZoomKeepsEveryPhotoSmall() {
        let candidates = [
            candidate("center", x: 200, y: 400),
            candidate("top", x: 200, y: 120),
            candidate("edge", x: 390, y: 400)
        ]

        let placements = Layout.resolve(candidates, viewport: viewport, zoom: 11)

        XCTAssertEqual(placements.count, candidates.count)
        XCTAssertTrue(placements.allSatisfy { $0.emphasis == 0 })
    }

    func testSeveralCentralPhotosStayLargeWithoutAQuota() {
        let candidates = (0..<12).map { index in
            candidate("place-\(index)", x: 130 + CGFloat(index % 4) * 45,
                      y: 180 + CGFloat(index / 4) * 180)
        }

        let placements = Layout.resolve(candidates, viewport: viewport, zoom: 14)

        XCTAssertEqual(placements.count, 12)
        XCTAssertTrue(placements.allSatisfy { $0.emphasis == 1 })
    }

    func testOverlappingNeighborsAndTheirSelectionNeverChangeEmphasis() throws {
        let subject = candidate("subject", x: 340, y: 400)
        let alone = try XCTUnwrap(Layout.resolve([subject], viewport: viewport, zoom: 12.7).first)
        let crowded = Layout.resolve([
            candidate("a", x: 340, y: 400, selected: true),
            subject,
            candidate("z", x: 341, y: 400)
        ], viewport: viewport, zoom: 12.7)

        XCTAssertGreaterThan(alone.emphasis, 0)
        XCTAssertLessThan(alone.emphasis, 1)
        XCTAssertEqual(try placement("subject", in: crowded).emphasis, alone.emphasis)
        XCTAssertEqual(try placement("a", in: crowded).emphasis, alone.emphasis)
    }

    func testHighCentralPhotoStaysLargerThanALaterallyDisplacedPhotoCloserToCenter() throws {
        let placements = Layout.resolve([
            candidate("high", x: 200, y: 120),
            candidate("side", x: 360, y: 400),
            candidate("edge", x: 400, y: 400),
            candidate("outside", x: -20, y: 400)
        ], viewport: viewport, zoom: 14)

        XCTAssertEqual(try placement("high", in: placements).emphasis, 1)
        XCTAssertLessThan(try placement("side", in: placements).emphasis, 0.5)
        XCTAssertEqual(try placement("edge", in: placements).emphasis, 0)
        XCTAssertEqual(try placement("outside", in: placements).emphasis, 0)
    }

    func testZoomGrowthIsProgressiveAndContinuous() throws {
        let zooms = [12.2, 12.4, 12.6, 12.8, 13.0, 13.2]
        let values = try zooms.map { try emphasis(x: 200, y: 400, zoom: $0) }

        XCTAssertEqual(values.first, 0)
        XCTAssertEqual(values.last, 1)
        for pair in zip(values, values.dropFirst()) {
            XCTAssertLessThan(pair.0, pair.1)
        }
        for zoom in [12.2, 12.7, 13.2] {
            XCTAssertEqual(try emphasis(x: 200, y: 400, zoom: zoom - 0.00001),
                           try emphasis(x: 200, y: 400, zoom: zoom + 0.00001),
                           accuracy: 0.0001)
        }
    }

    func testPositionFadesContinuouslyTowardEachEdge() throws {
        let horizontal = try [200, 296, 320, 350, 384, 400].map {
            try emphasis(x: CGFloat($0), y: 400)
        }
        let vertical = try [400, 712, 735, 770, 792, 800].map {
            try emphasis(x: 200, y: CGFloat($0))
        }

        for values in [horizontal, vertical] {
            XCTAssertEqual(values.first, 1)
            XCTAssertEqual(values.last, 0)
            XCTAssertTrue(values.contains { $0 > 0 && $0 < 1 })
            for pair in zip(values, values.dropFirst()) {
                XCTAssertGreaterThanOrEqual(pair.0, pair.1)
            }
        }
        for x in [296.0, 340, 384] {
            XCTAssertEqual(try emphasis(x: x - 0.001, y: 400),
                           try emphasis(x: x + 0.001, y: 400), accuracy: 0.0001)
        }
        for y in [712.0, 750, 792] {
            XCTAssertEqual(try emphasis(x: 200, y: y - 0.001),
                           try emphasis(x: 200, y: y + 0.001), accuracy: 0.0001)
        }
    }

    func testEmphasisDependsOnCurrentPositionAndZoomWithoutHistory() throws {
        let first = try emphasis(x: 340, y: 400, zoom: 12.7)
        _ = try emphasis(x: 200, y: 400, zoom: 15)
        _ = try emphasis(x: 0, y: 400, zoom: 10)

        XCTAssertEqual(try emphasis(x: 340, y: 400, zoom: 12.7), first)
    }

    func testPriorityUsesGeometricDistanceThenStableIdentifier() {
        let candidates = [
            candidate("far", x: 200, y: 120),
            candidate("b", x: 240, y: 400),
            candidate("a", x: 160, y: 400),
            candidate("center", x: 200, y: 400)
        ]

        let forward = Layout.resolve(candidates, viewport: viewport, zoom: 14)
        let reversed = Layout.resolve(Array(candidates.reversed()), viewport: viewport, zoom: 14)

        XCTAssertEqual(forward.map(\.id), ["center", "a", "b", "far"])
        XCTAssertEqual(forward.map(\.priority), [-1, -2, -3, -4])
        XCTAssertEqual(reversed.map(\.id), forward.map(\.id))
        XCTAssertEqual(reversed.map(\.priority), forward.map(\.priority))
        XCTAssertEqual(reversed.map(\.emphasis), forward.map(\.emphasis))
    }

    func testSelectionGetsPriorityOneAndLeavesZeroReservedForSocialMarkers() throws {
        let placements = Layout.resolve([
            candidate("selected", x: 398, y: 400, selected: true),
            candidate("center", x: 200, y: 400),
            candidate("near", x: 210, y: 400)
        ], viewport: viewport, zoom: 14)

        XCTAssertEqual(try placement("selected", in: placements).priority, 1)
        XCTAssertEqual(try placement("selected", in: placements).emphasis, 0)
        XCTAssertEqual(try placement("center", in: placements).priority, -1)
        XCTAssertEqual(try placement("near", in: placements).priority, -2)
        XCTAssertFalse(placements.contains { $0.priority == 0 })
    }

    func testViewportTranslationPreservesEmphasisAndPriority() {
        let candidates = [candidate("center", x: 200, y: 400), candidate("side", x: 340, y: 400)]
        let translated = candidates.map {
            Layout.Candidate(id: $0.id, point: CGPoint(x: $0.point.x + 73, y: $0.point.y + 131),
                             isSelected: $0.isSelected)
        }
        let original = Layout.resolve(candidates, viewport: viewport, zoom: 12.7)
        let moved = Layout.resolve(translated, viewport: viewport.offsetBy(dx: 73, dy: 131), zoom: 12.7)

        XCTAssertEqual(moved.map(\.id), original.map(\.id))
        XCTAssertEqual(moved.map(\.priority), original.map(\.priority))
        XCTAssertEqual(moved.map(\.emphasis), original.map(\.emphasis))
    }

    func testUnavailableGeometryOrZoomProducesFiniteSmallEmphasis() {
        let center = candidate("center", x: 200, y: 400)
        let invalid = candidate("invalid", x: .nan, y: 400)
        let samples = [
            Layout.resolve([center], viewport: .zero, zoom: 14),
            Layout.resolve([center], viewport: .null, zoom: 14),
            Layout.resolve([center], viewport: viewport, zoom: .nan),
            Layout.resolve([invalid], viewport: viewport, zoom: 14)
        ]

        for placements in samples {
            XCTAssertEqual(placements.count, 1)
            XCTAssertEqual(placements.first?.emphasis, 0)
        }
        XCTAssertTrue(Layout.resolve([], viewport: viewport, zoom: 14).isEmpty)
    }

    // MARK: - Fixtures

    private func candidate(_ id: String, x: CGFloat, y: CGFloat, selected: Bool = false) -> Layout.Candidate {
        Layout.Candidate(id: id, point: CGPoint(x: x, y: y), isSelected: selected)
    }

    private func placement(_ id: String, in placements: [Layout.Placement]) throws -> Layout.Placement {
        try XCTUnwrap(placements.first { $0.id == id })
    }

    private func emphasis(x: CGFloat, y: CGFloat, zoom: Double = 14) throws -> CGFloat {
        let placements = Layout.resolve([candidate("place", x: x, y: y)], viewport: viewport, zoom: zoom)
        return try XCTUnwrap(placements.first).emphasis
    }
}
