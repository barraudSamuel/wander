import XCTest
import FirebaseFirestore
@testable import wander

@MainActor
final class GhostModeTests: XCTestCase {
    func testUnresolvedAccountNeverPublishesEvenWithRememberedVisibleState() {
        XCTAssertFalse(GhostModeState().allowsSharing)
        XCTAssertFalse(GhostModeState(rememberedEnabled: true).allowsSharing)
    }

    func testActivationBlocksImmediatelyAndWaitsForItsServerRevision() {
        var state = visibleState()
        state.request(true, revision: "activate")
        XCTAssertTrue(state.isEnabled)
        XCTAssertFalse(state.allowsSharing)
        state.receive(enabled: false, revision: nil, resumedAt: nil)
        XCTAssertNotNil(state.pendingChange)
        state.receive(enabled: true, revision: "activate", resumedAt: nil)
        XCTAssertNil(state.pendingChange)
        XCTAssertFalse(state.allowsSharing)
    }

    func testDeactivationDoesNotPublishBeforeConfirmation() {
        var state = GhostModeState(rememberedEnabled: true)
        state.receive(enabled: true, revision: "on", resumedAt: nil)
        state.request(false, revision: "off")
        XCTAssertFalse(state.isEnabled)
        XCTAssertFalse(state.allowsSharing)
        let resumedAt = Date()
        state.receive(enabled: false, revision: "off", resumedAt: resumedAt)
        XCTAssertTrue(state.allowsSharing)
        XCTAssertEqual(state.resumedAt, resumedAt)
    }

    func testRapidChangesIgnoreConfirmationForAnOlderIntent() {
        var state = visibleState()
        state.request(true, revision: "first")
        state.request(false, revision: "second")
        state.request(true, revision: "third")
        state.receive(enabled: false, revision: "second", resumedAt: Date())
        XCTAssertEqual(state.pendingChange?.revision, "third")
        XCTAssertTrue(state.isEnabled)
        XCTAssertFalse(state.allowsSharing)
        state.receive(enabled: true, revision: "third", resumedAt: nil)
        XCTAssertNil(state.pendingChange)
    }

    func testRestoredIntentRemainsRestrictiveUntilReconciledWithServer() throws {
        let change = GhostModeState.Change(enabled: false, revision: "pending")
        let encoded = try JSONEncoder().encode(change)
        let restored = try JSONDecoder().decode(GhostModeState.Change.self, from: encoded)
        var state = GhostModeState(rememberedEnabled: true, pendingChange: restored)
        XCTAssertFalse(state.allowsSharing)
        state.receive(enabled: true, revision: "older", resumedAt: nil)
        XCTAssertNotNil(state.pendingChange)
        state.receive(enabled: false, revision: "pending", resumedAt: Date())
        XCTAssertTrue(state.allowsSharing)
    }

    func testRemoteActivationRevokesAnOtherwiseVisibleAccount() {
        var state = visibleState()
        state.receive(enabled: true, revision: "another-device", resumedAt: nil)
        XCTAssertTrue(state.isEnabled)
        XCTAssertFalse(state.allowsSharing)
    }

    func testAcknowledgementDoesNotReplayAnIntentOverAnotherDevice() throws {
        var state = visibleState()
        state.request(true, revision: "local")
        let change = try XCTUnwrap(state.pendingChange)
        state.receive(enabled: false, revision: "newer-remote", resumedAt: Date())
        state.acknowledge(change)
        XCTAssertNil(state.pendingChange)
        XCTAssertFalse(state.allowsSharing, "Wait for a fresh server read after acknowledgement")
        state.receive(enabled: false, revision: "newer-remote", resumedAt: Date())
        XCTAssertTrue(state.allowsSharing)
    }

    func testOldAcknowledgementCannotClearANewerPendingChange() throws {
        var state = visibleState()
        state.request(true, revision: "first")
        let old = try XCTUnwrap(state.pendingChange)
        state.request(false, revision: "second")
        state.acknowledge(old)
        XCTAssertEqual(state.pendingChange?.revision, "second")
        XCTAssertFalse(state.allowsSharing)
    }

    func testRestoredDeactivationCannotReplaceANewerRemoteActivation() throws {
        var state = GhostModeState()
        state.receive(enabled: true, revision: "original-ghost", resumedAt: nil)
        state.request(false, revision: "old-deactivation")
        let encoded = try JSONEncoder().encode(XCTUnwrap(state.pendingChange))
        let pending = try JSONDecoder().decode(GhostModeState.Change.self, from: encoded)
        var restored = GhostModeState(rememberedEnabled: true, pendingChange: pending)

        restored.receive(enabled: true, revision: "newer-remote-ghost", resumedAt: nil)
        XCTAssertEqual(pending.expectedRevision, "original-ghost")
        XCTAssertEqual(pending.outcome(
            currentRevision: "newer-remote-ghost", currentEnabled: true
        ), .conflict)
        restored.discardConflictingChange(pending)
        XCTAssertNil(restored.pendingChange)
        XCTAssertFalse(restored.allowsSharing)
        XCTAssertNil(restored.confirmedEnabled)

        restored.receive(enabled: true, revision: "newer-remote-ghost", resumedAt: nil)
        XCTAssertTrue(restored.isEnabled)
        XCTAssertFalse(restored.allowsSharing)
    }

    func testRapidLocalIntentSurvivesRestoreWithPredecessorInFlight() throws {
        var state = visibleState()
        state.request(true, revision: "in-flight-activation")
        state.request(false, revision: "queued-deactivation")
        let encoded = try JSONEncoder().encode(XCTUnwrap(state.pendingChange))
        let pending = try JSONDecoder().decode(GhostModeState.Change.self, from: encoded)
        var restored = GhostModeState(pendingChange: pending)

        XCTAssertEqual(pending.outcome(currentRevision: nil, currentEnabled: false), .applied,
                       "If the first write failed, the original base remains valid")
        XCTAssertEqual(pending.outcome(
            currentRevision: "in-flight-activation", currentEnabled: true
        ), .applied, "If the first write committed, its successor can finish")
        restored.receive(enabled: true, revision: "in-flight-activation", resumedAt: nil)
        XCTAssertFalse(restored.allowsSharing)
        XCTAssertEqual(restored.pendingChange, pending)
        restored.receive(enabled: false, revision: "queued-deactivation", resumedAt: Date())
        XCTAssertTrue(restored.allowsSharing)
    }

    func testAThirdLocalChoiceRetainsItsChainWithoutAdoptingRemoteRevisions() throws {
        var state = visibleState()
        state.request(true, revision: "first")
        state.request(false, revision: "second")
        state.request(true, revision: "third")
        state.receive(enabled: false, revision: "unrelated-remote", resumedAt: Date())
        let change = try XCTUnwrap(state.pendingChange)
        XCTAssertEqual(change.outcome(currentRevision: nil, currentEnabled: false), .applied)
        XCTAssertEqual(change.outcome(currentRevision: "first", currentEnabled: true), .applied)
        XCTAssertEqual(change.outcome(currentRevision: "second", currentEnabled: false), .applied)
        XCTAssertEqual(change.outcome(
            currentRevision: "unrelated-remote", currentEnabled: false
        ), .conflict)

        state.request(true, revision: "new-explicit-choice")
        XCTAssertEqual(state.pendingChange?.outcome(
            currentRevision: "unrelated-remote", currentEnabled: false
        ), .applied, "Only a new explicit action may target the received remote revision")
    }

    func testIdempotentIntentIsDistinctFromAConflictingValue() throws {
        var state = visibleState()
        state.request(true, revision: "same")
        let change = try XCTUnwrap(state.pendingChange)
        XCTAssertEqual(change.outcome(currentRevision: "same", currentEnabled: true), .idempotent)
        XCTAssertEqual(change.outcome(currentRevision: "same", currentEnabled: false), .conflict)
    }

    func testOldConflictCannotDiscardANewerExplicitIntent() throws {
        var state = visibleState()
        state.request(true, revision: "old")
        let old = try XCTUnwrap(state.pendingChange)
        state.request(false, revision: "new")
        state.discardConflictingChange(old)
        XCTAssertEqual(state.pendingChange?.revision, "new")
        XCTAssertFalse(state.allowsSharing)
    }

    func testAcknowledgedIntentCanBeRememberedWithoutUnlockingSharing() throws {
        for enabled in [true, false] {
            var state = visibleState()
            state.request(enabled, revision: "acknowledged")
            state.acknowledge(try XCTUnwrap(state.pendingChange))
            XCTAssertEqual(state.rememberedEnabled, enabled)
            XCTAssertEqual(state.rememberedRevision, "acknowledged")
            XCTAssertNil(state.pendingChange)
            XCTAssertFalse(state.allowsSharing)

            var restored = GhostModeState(
                rememberedEnabled: state.rememberedEnabled,
                rememberedRevision: state.rememberedRevision
            )
            XCTAssertEqual(restored.isEnabled, enabled)
            XCTAssertFalse(restored.allowsSharing)
            restored.request(!enabled, revision: "offline-choice")
            XCTAssertEqual(restored.pendingChange?.expectedRevision, "acknowledged")
        }
    }

    func testConflictWithVisibleRemoteStillRequiresServerConfirmation() throws {
        var state = visibleState()
        state.request(true, revision: "stale")
        let change = try XCTUnwrap(state.pendingChange)
        state.receive(enabled: false, revision: "remote-visible", resumedAt: Date())
        state.discardConflictingChange(change)
        XCTAssertFalse(state.allowsSharing)
        state.receive(enabled: false, revision: "remote-visible", resumedAt: Date())
        XCTAssertTrue(state.allowsSharing)
    }

    func testCachedFriendSamplesBeforeSharingResumeStayHidden() {
        let resumedAt = Date(timeIntervalSince1970: 2_000)
        XCTAssertFalse(FriendLocation.isAfterSharingResume(
            sampledAt: resumedAt.addingTimeInterval(-1), resumedAt: resumedAt
        ))
        XCTAssertTrue(FriendLocation.isAfterSharingResume(sampledAt: resumedAt, resumedAt: resumedAt))
        XCTAssertTrue(FriendLocation.isAfterSharingResume(
            sampledAt: resumedAt.addingTimeInterval(1), resumedAt: resumedAt
        ))
        XCTAssertTrue(FriendLocation.isAfterSharingResume(
            sampledAt: resumedAt.addingTimeInterval(-1), resumedAt: nil
        ), "Legacy profiles have no resume boundary")
    }

    func testLegacyProfileAllowsPublicationWithNoRevision() {
        XCTAssertTrue(LocationSharingPolicy.allowsPublication(profile: [:], expectedRevision: nil))
    }

    func testGhostAndMalformedFlagsFailClosed() {
        for value: Any in [true, "false", NSNull(), NSNumber(value: 0)] {
            XCTAssertFalse(LocationSharingPolicy.allowsPublication(
                profile: [LocationSharingPolicy.ghostModeKey: value], expectedRevision: nil
            ))
        }
        XCTAssertTrue(LocationSharingPolicy.allowsPublication(
            profile: [LocationSharingPolicy.ghostModeKey: false], expectedRevision: nil
        ))
    }

    func testPublicationRejectsAnEarlierSharingRevision() {
        let profile: [String: Any] = [LocationSharingPolicy.revisionKey: "resumed"]
        XCTAssertFalse(LocationSharingPolicy.allowsPublication(profile: profile, expectedRevision: nil))
        XCTAssertFalse(LocationSharingPolicy.allowsPublication(profile: profile, expectedRevision: "before"))
        XCTAssertTrue(LocationSharingPolicy.allowsPublication(profile: profile, expectedRevision: "resumed"))
        for value: Any in ["", NSNull(), 42] {
            XCTAssertFalse(LocationSharingPolicy.allowsPublication(
                profile: [LocationSharingPolicy.revisionKey: value], expectedRevision: nil
            ))
        }
    }

    func testOnlyPostResumeSamplesCanBePublishedButDeferredCellsCanSync() {
        let resumedAt = Date(timeIntervalSince1970: 1_000)
        let profile: [String: Any] = [LocationSharingPolicy.resumedAtKey: Timestamp(date: resumedAt)]
        XCTAssertFalse(LocationSharingPolicy.allowsPublication(
            profile: profile, expectedRevision: nil, sampledAt: resumedAt.addingTimeInterval(-1)
        ))
        XCTAssertTrue(LocationSharingPolicy.allowsPublication(
            profile: profile, expectedRevision: nil, sampledAt: resumedAt
        ))
        XCTAssertTrue(LocationSharingPolicy.allowsPublication(profile: profile, expectedRevision: nil))
        XCTAssertFalse(LocationSharingPolicy.allowsPublication(
            profile: [LocationSharingPolicy.resumedAtKey: "bad-date"],
            expectedRevision: nil, sampledAt: resumedAt
        ))
    }

    func testAccountDeletionPreventsEveryPublication() {
        XCTAssertFalse(LocationSharingPolicy.allowsPublication(
            profile: ["deletionRequestedAt": Timestamp(date: Date())], expectedRevision: nil
        ))
    }

    private func visibleState() -> GhostModeState {
        var state = GhostModeState()
        state.receive(enabled: false, revision: nil, resumedAt: nil)
        return state
    }
}
