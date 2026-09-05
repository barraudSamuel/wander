import CoreLocation
import XCTest
@testable import wander

/// Characterizes the geographic rules previously held by MapWithFogView.Coordinator.
@MainActor
final class MapSocialProximityStateTests: XCTestCase {
    private typealias State = MapSocialProximityState
    private typealias MemberID = MapSocialClusterMemberID

    func testExistingPairSurvives24MetersButSeparatesAt26Meters() throws {
        var state = State()
        XCTAssertTrue(state.update(sources: pair(distance: 19)))
        let groupID = try XCTUnwrap(state.groups.first?.id)
        XCTAssertEqual(members(in: state), [[.currentUser, .friend("a")]])

        XCTAssertTrue(state.update(sources: pair(distance: 24)))
        XCTAssertEqual(members(in: state), [[.currentUser, .friend("a")]])
        XCTAssertEqual(state.groups.first?.id, groupID)

        state.update(sources: pair(distance: 26))
        XCTAssertEqual(members(in: state), [[.currentUser], [.friend("a")]])
        XCTAssertEqual(state.groups.map(\.id), ["0:current-user", "1:friend:a"])

        state.update(sources: pair(distance: 24))
        XCTAssertEqual(state.groups.count, 2, "A separated pair must re-enter within 20 meters.")
        state.update(sources: pair(distance: 19))
        XCTAssertEqual(state.groups.count, 1)
        XCTAssertNotEqual(state.groups.first?.id, groupID)
    }

    func testNewPairAt21MetersStaysSeparate() {
        var state = State()
        state.update(sources: pair(distance: 21))
        XCTAssertEqual(members(in: state), [[.currentUser], [.friend("a")]])
    }

    func testProximityDoesNotConnectAChainOfDistantEndpoints() {
        var state = State()
        state.update(sources: [
            source(.currentUser, meters: 0),
            source(.friend("a"), meters: 15),
            source(.friend("b"), meters: 30)
        ])

        XCTAssertEqual(state.groups.count, 2)
        XCTAssertEqual(state.groups.map { $0.memberIDs.count }.sorted(), [1, 2])
        XCTAssertFalse(state.groups.contains {
            $0.memberIDs.contains(.currentUser) && $0.memberIDs.contains(.friend("b"))
        })
    }

    func testInputPermutationPreservesCompositionIdentityAndRevision() {
        let sources = [
            source(.currentUser, meters: 0),
            source(.friend("a"), meters: 15),
            source(.outing("a"), meters: 30)
        ]
        var state = State()
        state.update(sources: sources)
        let originalGroups = state.groups
        let originalRevision = state.revision

        XCTAssertFalse(state.update(sources: Array(sources.reversed())))
        XCTAssertEqual(state.groups, originalGroups)
        XCTAssertEqual(state.revision, originalRevision)

        var reversedState = State()
        reversedState.update(sources: Array(sources.reversed()))
        XCTAssertEqual(members(in: reversedState), members(in: state))
    }

    func testCloserNewNeighborDoesNotBreakAnExistingPair() throws {
        var state = State()
        state.update(sources: pair(distance: 19))
        let originalID = try XCTUnwrap(state.groups.first?.id)

        state.update(sources: pair(distance: 19) + [source(.friend("b"), meters: 21)])

        XCTAssertEqual(members(in: state), [[.currentUser, .friend("a")], [.friend("b")]])
        XCTAssertEqual(state.groups.first?.id, originalID)
    }

    func testMixedMembersHaveDistinctStableKeysAndShareOneGroup() {
        var state = State()
        state.update(sources: [
            source(.outing("shared"), meters: 10),
            source(.friend("shared"), meters: 5),
            source(.currentUser, meters: 0)
        ])

        XCTAssertEqual(members(in: state), [[.currentUser, .friend("shared"), .outing("shared")]])
        XCTAssertEqual(MemberID.currentUser.stableKey, "0:current-user")
        XCTAssertEqual(MemberID.friend("shared").stableKey, "1:friend:shared")
        XCTAssertEqual(MemberID.outing("shared").stableKey, "2:outing:shared")
    }

    func testIdenticalSnapshotAndFocusDoNotChangeRevisionOrIdentity() {
        let sources = pair(distance: 19)
        var state = State()
        state.update(sources: sources)
        let originalGroups = state.groups
        let originalRevision = state.revision

        XCTAssertFalse(state.update(sources: sources))
        XCTAssertFalse(state.focus(nil))
        XCTAssertEqual(state.groups, originalGroups)
        XCTAssertEqual(state.revision, originalRevision)

        XCTAssertTrue(state.focus(.currentUser))
        XCTAssertEqual(state.revision, originalRevision + 1)
        XCTAssertFalse(state.focus(.currentUser))
        XCTAssertFalse(state.update(sources: sources))
        XCTAssertEqual(state.revision, originalRevision + 1)
    }

    func testFocusedMemberIsExcludedAndRemainingGroupKeepsItsIdentity() throws {
        var state = State()
        state.update(sources: [
            source(.currentUser, meters: 0),
            source(.friend("a"), meters: 5),
            source(.outing("b"), meters: 10)
        ])
        let originalID = try XCTUnwrap(state.groups.first?.id)

        XCTAssertTrue(state.focus(.friend("a")))
        XCTAssertEqual(state.focusedMemberID, .friend("a"))
        XCTAssertEqual(members(in: state), [[.currentUser, .outing("b")]])
        XCTAssertEqual(state.groups.first?.id, originalID)

        XCTAssertTrue(state.focus(nil))
        XCTAssertNil(state.focusedMemberID)
        XCTAssertEqual(members(in: state), [[.currentUser, .friend("a"), .outing("b")]])
        XCTAssertEqual(state.groups.first?.id, originalID)
    }

    func testPairHistorySurvivesTemporaryFocusAndMovementTo24Meters() {
        var state = State()
        state.update(sources: pair(distance: 19))
        state.focus(.currentUser)
        state.update(sources: pair(distance: 24))

        XCTAssertEqual(state.focusedMemberID, .currentUser)
        XCTAssertEqual(members(in: state), [[.friend("a")]])

        state.focus(nil)
        XCTAssertEqual(members(in: state), [[.currentUser, .friend("a")]])
    }

    func testPairHistoryExpiresBeyond25MetersEvenDuringFocus() {
        var state = State()
        state.update(sources: pair(distance: 19))
        state.focus(.currentUser)
        state.update(sources: pair(distance: 26))
        state.update(sources: pair(distance: 24))
        state.focus(nil)

        XCTAssertEqual(members(in: state), [[.currentUser], [.friend("a")]])
    }

    func testRemovingFocusedMemberClearsFocusAndPairHistory() {
        var state = State()
        state.update(sources: pair(distance: 19))
        state.focus(.friend("a"))
        state.update(sources: [source(.currentUser, meters: 0)])

        XCTAssertNil(state.focusedMemberID)
        XCTAssertEqual(members(in: state), [[.currentUser]])

        state.update(sources: pair(distance: 24))
        XCTAssertEqual(members(in: state), [[.currentUser], [.friend("a")]])
    }

    func testInvalidSourcesRemainSingletonsAndCannotBeFocused() {
        var state = State()
        let sources = [
            State.Source(id: .currentUser, coordinate: CLLocationCoordinate2D(latitude: .nan, longitude: 0)),
            source(.friend("a"), meters: 0),
            State.Source(id: .outing("b"), coordinate: kCLLocationCoordinate2DInvalid)
        ]
        state.update(sources: sources)
        let revision = state.revision

        XCTAssertEqual(members(in: state), [[.currentUser], [.friend("a")], [.outing("b")]])
        XCTAssertFalse(state.update(sources: sources), "Unchanged NaN coordinates must not invalidate the snapshot.")
        XCTAssertFalse(state.focus(.currentUser))
        XCTAssertFalse(state.focus(.outing("b")))
        XCTAssertFalse(state.focus(.friend("missing")))
        XCTAssertNil(state.focusedMemberID)
        XCTAssertEqual(state.revision, revision)
    }

    func testInvalidatingFocusedCoordinateClearsFocusAndRetainedPair() {
        var state = State()
        state.update(sources: pair(distance: 19))
        state.focus(.friend("a"))
        state.update(sources: [
            source(.currentUser, meters: 0),
            State.Source(id: .friend("a"), coordinate: kCLLocationCoordinate2DInvalid)
        ])

        XCTAssertNil(state.focusedMemberID)
        XCTAssertEqual(members(in: state), [[.currentUser], [.friend("a")]])

        state.update(sources: pair(distance: 24))
        XCTAssertEqual(state.groups.count, 2)
    }

    func testEmptySnapshotClearsGroupsFocusAndPairHistory() {
        var state = State()
        state.update(sources: pair(distance: 19))
        state.focus(.currentUser)

        XCTAssertTrue(state.update(sources: []))
        XCTAssertTrue(state.groups.isEmpty)
        XCTAssertNil(state.focusedMemberID)
        XCTAssertFalse(state.update(sources: []))

        state.update(sources: pair(distance: 24))
        XCTAssertEqual(state.groups.count, 2)
    }

    func testResetClearsPreviousGroupingAndAdvancesRevision() {
        var state = State()
        state.update(sources: pair(distance: 19))
        state.focus(.currentUser)
        let revision = state.revision

        state.reset()
        XCTAssertTrue(state.groups.isEmpty)
        XCTAssertNil(state.focusedMemberID)
        XCTAssertGreaterThan(state.revision, revision)

        XCTAssertTrue(state.update(sources: pair(distance: 24)))
        XCTAssertEqual(state.groups.count, 2)
    }

    func testMergingGroupsReusesIdentityWithGreatestMemberOverlap() throws {
        var state = State()
        state.update(sources: [
            source(.friend("a"), meters: 0),
            source(.friend("b"), meters: 5),
            source(.friend("c"), meters: 10),
            source(.friend("d"), meters: 100),
            source(.friend("e"), meters: 105)
        ])
        let largerGroupID = try XCTUnwrap(state.groups.first { $0.memberIDs.count == 3 }?.id)

        state.update(sources: ["a", "b", "c", "d", "e"].map {
            source(.friend($0), meters: 0)
        })

        XCTAssertEqual(state.groups.count, 1)
        XCTAssertEqual(state.groups.first?.id, largerGroupID)
    }

    func testMergingEqualOverlapGroupsUsesOldIdentifierAsTieBreaker() throws {
        var state = State()
        state.update(sources: [
            source(.friend("a"), meters: 0),
            source(.friend("b"), meters: 5),
            source(.friend("c"), meters: 100),
            source(.friend("d"), meters: 105)
        ])
        let expectedID = try XCTUnwrap(state.groups.map(\.id).min())
        XCTAssertEqual(state.groups.count, 2)

        state.update(sources: ["a", "b", "c", "d"].map {
            source(.friend($0), meters: 0)
        })

        XCTAssertEqual(state.groups.count, 1)
        XCTAssertEqual(state.groups.first?.id, expectedID)
    }

    func testSplittingGroupReusesItsIdentityOnlyOnce() throws {
        var state = State()
        state.update(sources: ["a", "b", "c", "d"].map {
            source(.friend($0), meters: 0)
        })
        let originalID = try XCTUnwrap(state.groups.first?.id)

        state.update(sources: [
            source(.friend("a"), meters: 0),
            source(.friend("b"), meters: 5),
            source(.friend("c"), meters: 100),
            source(.friend("d"), meters: 105)
        ])

        XCTAssertEqual(members(in: state), [[.friend("a"), .friend("b")], [.friend("c"), .friend("d")]])
        XCTAssertEqual(state.groups.first?.id, originalID)
        XCTAssertEqual(Set(state.groups.map(\.id)).count, 2)
    }

    // MARK: - Fixtures

    private func pair(distance: CLLocationDistance) -> [State.Source] {
        [source(.currentUser, meters: 0), source(.friend("a"), meters: distance)]
    }

    private func source(_ id: MemberID, meters: CLLocationDistance) -> State.Source {
        // Eastward equatorial offsets keep the fixtures away from threshold rounding.
        State.Source(
            id: id,
            coordinate: CLLocationCoordinate2D(
                latitude: 0,
                longitude: meters / 111_319.49079327358
            )
        )
    }

    private func members(in state: State) -> [[MemberID]] {
        state.groups.map(\.memberIDs)
    }
}
