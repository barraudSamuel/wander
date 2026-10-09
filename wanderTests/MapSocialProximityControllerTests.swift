import CoreLocation
import MapboxMaps
import UIKit
import UIKit.UIGestureRecognizerSubclass
import XCTest
@testable import wander

/// Exercises the controller through real Mapbox view annotations and selection callbacks.
@MainActor
final class MapSocialProximityControllerTests: XCTestCase {
    func testSilentEventSelectionDoesNotSilenceLaterUserCentering() async throws {
        let fixture = try await makeFixture()
        defer { fixture.close() }
        let event = fixture.annotation("Event", meters: 100)
        fixture.update([.outing("event"): event])
        fixture.controller.select(.outing("event"), on: fixture.mapView, silently: true)
        XCTAssertTrue(fixture.controller.isSilentPendingSelection(event))

        // Group-member and offscreen-indicator actions use center(on:).
        fixture.controller.center(on: .outing("event"), on: fixture.mapView)
        XCTAssertFalse(fixture.controller.isSilentPendingSelection(event))
        fixture.controller.collapse(on: fixture.mapView)
        XCTAssertFalse(fixture.controller.isSilentPendingSelection(event))
    }

    func testProfileCameraOwnsFriendOpeningFromPinGroupAndOffscreenTarget() async throws {
        var requests: [String] = []
        let fixture = try await makeFixture(onRequestFriendProfile: { requests.append($0) })
        defer { fixture.close() }
        let friend = fixture.annotation("Amina", meters: 0)
        fixture.update([.friend("amina"): friend])
        try await eventually("The friend pin is rendered") { fixture.annotationStore.view(for: friend) != nil }
        let view = try XCTUnwrap(fixture.annotationStore.view(for: friend))
        let initialCamera = fixture.cameraSnapshot
        XCTAssertEqual(fixture.controller.activate(friend, view: view, on: fixture.mapView), .friend("amina"))
        XCTAssertEqual(fixture.cameraSnapshot, initialCamera)

        fixture.controller.collapse(on: fixture.mapView)
        fixture.update(fixture.mixedSources())
        let group = try XCTUnwrap(fixture.groups.first)
        try await eventually("The group is rendered") { fixture.groupView(for: group) != nil }
        fixture.groupView(for: group)?.onSelectMember?(.friend("amina"))
        XCTAssertEqual(requests, ["amina"])
        XCTAssertEqual(fixture.cameraSnapshot, initialCamera)

        fixture.update([.friend("far"): fixture.annotation("Far away", meters: 50_000)])
        fixture.controller.center(on: .friend("far"), on: fixture.mapView)
        XCTAssertEqual(requests, ["amina", "far"], "Offscreen selection must not wait for a visible pin")
        await flushMainQueue()
        XCTAssertEqual(fixture.cameraSnapshot, initialCamera)

        fixture.update([.outing("event"): fixture.annotation("Event", meters: 100)])
        fixture.controller.center(on: .outing("event"), on: fixture.mapView)
        try await eventually("Events keep native centering") { fixture.cameraSnapshot != initialCamera }
    }

    func testOwnProfileCameraOwnsOpeningFromPinAndGroup() async throws {
        var requests = 0
        let fixture = try await makeFixture(onRequestOwnProfile: { requests += 1 })
        defer { fixture.close() }
        let user = fixture.annotation("Vous", meters: 0)
        fixture.update([.currentUser: user])
        try await eventually("The personal pin is rendered") { fixture.annotationStore.view(for: user) != nil }
        let view = try XCTUnwrap(fixture.annotationStore.view(for: user))
        let initialCamera = fixture.cameraSnapshot
        XCTAssertEqual(fixture.controller.activate(user, view: view, on: fixture.mapView), .currentUser)
        XCTAssertEqual(fixture.cameraSnapshot, initialCamera)

        fixture.controller.collapse(on: fixture.mapView)
        fixture.update(fixture.mixedSources())
        let group = try XCTUnwrap(fixture.groups.first)
        try await eventually("The group is rendered") { fixture.groupView(for: group) != nil }
        fixture.groupView(for: group)?.onSelectMember?(.currentUser)
        XCTAssertEqual(requests, 1)
        XCTAssertEqual(fixture.cameraSnapshot, initialCamera)
    }

    func testExpandedGroupFitsChangingViewportWithoutLosingSelectionOrRepeatedCentering() async throws {
        let fixture = try await makeFixture()
        defer { fixture.close() }
        fixture.update(Dictionary(uniqueKeysWithValues: (0..<8).map { index in
            (MapSocialClusterMemberID.outing("event-\(index)"), fixture.annotation("Sortie \(index)", meters: 0))
        }))
        let group = try XCTUnwrap(fixture.groups.first)
        try await eventually("The group view appears") { fixture.groupView(for: group) != nil }
        let view = try XCTUnwrap(fixture.groupView(for: group))
        fixture.annotationStore.selectAnnotation(group, animated: false)
        try await eventually("The group expands") { view.isExpanded }
        let revision = fixture.controller.presentationRevision
        let nativeBounds = fixture.mapView.bounds

        let visibleBounds = CGRect(
            x: nativeBounds.midX - 110,
            y: nativeBounds.midY - 75,
            width: 220,
            height: 150
        )
        fixture.visibleBounds = visibleBounds
        fixture.controller.viewportDidChange(on: fixture.mapView)
        try await eventually("The list and its anchor fit the nonzero-origin viewport") {
            let anchor = fixture.mapView.mapboxMap.point(for: group.coordinate)
            let frame = view.projectedExpandedFrame(at: anchor)
            let safeBounds = visibleBounds.insetBy(dx: 12, dy: 12)
            return safeBounds.insetBy(dx: -1, dy: -1).contains(frame)
                && safeBounds.insetBy(dx: -1, dy: -1).contains(anchor)
        }
        view.layoutIfNeeded()
        let rows = fixture.memberRows(in: view)
        let scrollView = try XCTUnwrap(rows.first?.superview as? UIScrollView)
        XCTAssertEqual(rows.count, 8)
        XCTAssertGreaterThan(scrollView.contentSize.height, scrollView.bounds.height)
        XCTAssertGreaterThan(scrollView.bounds.height, 44)
        // setCenter updates projection before Mapbox lays out its annotation views.
        try await eventually("Mapbox lays out the list at its projected position") {
            view.layoutIfNeeded()
            let anchor = fixture.mapView.mapboxMap.point(for: group.coordinate)
            let expected = view.projectedExpandedFrame(at: anchor).insetBy(dx: 6, dy: 6)
            let actual = scrollView.convert(scrollView.bounds, to: fixture.mapView)
            return abs(actual.minX - expected.minX) <= 1
                && abs(actual.minY - expected.minY) <= 1
                && abs(actual.height - expected.height) <= 1
        }
        let anchor = fixture.mapView.mapboxMap.point(for: group.coordinate)
        let expectedFrame = view.projectedExpandedFrame(at: anchor).insetBy(dx: 6, dy: 6)
        let actualFrame = scrollView.convert(scrollView.bounds, to: fixture.mapView)
        XCTAssertEqual(actualFrame.minX, expectedFrame.minX, accuracy: 1)
        XCTAssertEqual(actualFrame.minY, expectedFrame.minY, accuracy: 1)
        XCTAssertEqual(actualFrame.height, expectedFrame.height, accuracy: 1)

        scrollView.setContentOffset(CGPoint(x: 0, y: 40), animated: false)
        let cameraBefore = fixture.cameraSnapshot
        for _ in 0..<5 {
            fixture.controller.viewportDidChange(on: fixture.mapView)
        }
        XCTAssertEqual(fixture.cameraSnapshot, cameraBefore)
        XCTAssertEqual(scrollView.contentOffset.y, 40, accuracy: 0.5)
        XCTAssertEqual(fixture.controller.presentationRevision, revision)
        XCTAssertTrue(fixture.isSelected(group))
        XCTAssertTrue(view.isExpanded)
        XCTAssertEqual(view.accessibilityCustomActions?.count, 8)
        XCTAssertTrue(fixture.deselectedMembers.isEmpty)
        XCTAssertEqual(fixture.mapView.bounds, nativeBounds)

        let compactHeight = scrollView.bounds.height
        fixture.visibleBounds = nil
        fixture.controller.viewportDidChange(on: fixture.mapView)
        view.layoutIfNeeded()
        XCTAssertGreaterThan(scrollView.bounds.height, compactHeight)
        XCTAssertEqual(fixture.controller.presentationRevision, revision)
        XCTAssertTrue(view.isExpanded)
    }

    func testRefreshingSourcesPreservesGroupIdentityAndExpandedAccessibility() async throws {
        let fixture = try await makeFixture()
        defer { fixture.close() }
        let sources = fixture.mixedSources()
        fixture.update(sources)
        let group = try XCTUnwrap(fixture.groups.first)
        try await eventually("The group view appears") { fixture.groupView(for: group) != nil }
        let view = try XCTUnwrap(fixture.groupView(for: group))

        fixture.annotationStore.selectAnnotation(group, animated: false)
        try await eventually("Native selection expands the group") { view.isExpanded }
        XCTAssertTrue(view.isAccessibilityElement)
        XCTAssertTrue(view.accessibilityTraits.contains(.button))
        XCTAssertTrue(view.accessibilityTraits.contains(.selected))
        XCTAssertEqual(view.accessibilityCustomActions?.count, 3)

        let friend = try XCTUnwrap(sources[.friend("amina")])
        friend.coordinate = fixture.coordinate(meters: 7)
        fixture.update(sources)
        fixture.controller.activate(group, view: view, on: fixture.mapView)

        XCTAssertTrue(fixture.groups.first === group)
        XCTAssertEqual(fixture.socialAnnotations.count, 1)
        XCTAssertTrue(view.isExpanded, "A refresh and repeated activation must preserve the open group.")
        XCTAssertEqual(view.accessibilityCustomActions?.count, 3)
        XCTAssertTrue(group.memberAnnotations.contains { ($0 as AnyObject) === friend })

        fixture.controller.collapse(on: fixture.mapView)
        XCTAssertFalse(view.isExpanded)
        XCTAssertFalse(view.accessibilityTraits.contains(.selected))
        XCTAssertNil(view.accessibilityCustomActions)
    }

    func testSelectingMemberThenDeselectingRestoresGroupWithoutDuplicateAnnotations() async throws {
        let fixture = try await makeFixture()
        defer { fixture.close() }
        let sources = fixture.mixedSources()
        let friend = try XCTUnwrap(sources[.friend("amina")])
        fixture.update(sources)
        let group = try XCTUnwrap(fixture.groups.first)
        try await eventually("The initial group is rendered") { fixture.groupView(for: group) != nil }

        fixture.controller.select(.friend("amina"), on: fixture.mapView)
        try await eventually("Mapbox selects the extracted member") { fixture.isSelected(friend) }

        XCTAssertTrue(fixture.groups.first === group)
        XCTAssertEqual(fixture.socialAnnotations.count, 2)
        XCTAssertEqual(group.memberAnnotations.count, 2)
        XCTAssertFalse(group.memberAnnotations.contains { ($0 as AnyObject) === friend })
        XCTAssertTrue(fixture.annotationStore.view(for: friend)?.isAccessibilityElement == true)
        XCTAssertEqual(fixture.attachedCount(of: friend), 1)

        fixture.annotationStore.deselectAnnotation(friend, animated: false)
        try await eventually("Deselection restores the original group") {
            fixture.socialAnnotations.count == 1 && group.memberAnnotations.count == 3
        }

        XCTAssertFalse(fixture.isSelected(friend))
        XCTAssertTrue(fixture.groups.first === group)
        XCTAssertEqual(fixture.attachedCount(of: friend), 0)
        XCTAssertEqual(group.memberAnnotations.filter { ($0 as AnyObject) === friend }.count, 1)
    }

    func testVisibleSingletonCanBeSelectedAndActivatedRepeatedlyWithoutBeingReplaced() async throws {
        let fixture = try await makeFixture()
        defer { fixture.close() }
        let friend = fixture.annotation("Amina", meters: 0)
        fixture.update([.friend("amina"): friend])
        try await eventually("The singleton view appears") { fixture.annotationStore.view(for: friend) != nil }
        let view = try XCTUnwrap(fixture.annotationStore.view(for: friend))

        // No annotations are added during this selection, so didAdd cannot resume it.
        fixture.controller.select(.friend("amina"), on: fixture.mapView)
        try await eventually("An already visible singleton is selected") { fixture.isSelected(friend) }

        XCTAssertEqual(
            fixture.controller.activate(friend, view: view, on: fixture.mapView),
            .friend("amina")
        )
        XCTAssertEqual(
            fixture.controller.activate(friend, view: view, on: fixture.mapView),
            .friend("amina")
        )
        fixture.update([.friend("amina"): friend])

        let cameraBefore = fixture.cameraSnapshot
        let revision = fixture.controller.presentationRevision
        fixture.visibleBounds = fixture.mapView.bounds.insetBy(dx: 0, dy: 120)
        fixture.controller.viewportDidChange(on: fixture.mapView)
        XCTAssertEqual(fixture.cameraSnapshot, cameraBefore)
        XCTAssertEqual(fixture.controller.presentationRevision, revision)

        XCTAssertTrue(fixture.isSelected(friend))
        XCTAssertEqual(fixture.attachedCount(of: friend), 1)
        XCTAssertEqual(fixture.socialAnnotations.count, 1)
        XCTAssertTrue(fixture.annotationStore.view(for: friend) === view)
    }

    func testActivatingAnotherEventKeepsBothMembersAttachedWithoutRestoringTheirGroup() async throws {
        let fixture = try await makeFixture()
        defer { fixture.close() }
        let walk = fixture.annotation("Balade", meters: 0)
        let coffee = fixture.annotation("Café", meters: 5)
        fixture.update([.outing("walk"): walk, .outing("coffee"): coffee])
        XCTAssertEqual(fixture.groups.count, 1)

        fixture.controller.select(.outing("walk"), on: fixture.mapView)
        try await eventually("The first event is selected and the second has a view") {
            fixture.isSelected(walk) && fixture.annotationStore.view(for: coffee) != nil
        }
        let coffeeView = try XCTUnwrap(fixture.annotationStore.view(for: coffee))

        // The passive tap observer calls activate before native selection finishes.
        XCTAssertEqual(
            fixture.controller.activate(coffee, view: coffeeView, on: fixture.mapView),
            .outing("coffee")
        )

        XCTAssertTrue(fixture.controller.isFocused(coffee))
        XCTAssertFalse(fixture.controller.isFocused(walk))
        XCTAssertEqual(fixture.attachedCount(of: coffee), 1)
        XCTAssertEqual(fixture.attachedCount(of: walk), 1)
        XCTAssertTrue(fixture.groups.isEmpty)
        XCTAssertEqual(fixture.socialAnnotations.count, 2)

        fixture.controller.didDeselect(walk, on: fixture.mapView)
        await flushMainQueue()

        XCTAssertTrue(fixture.controller.isFocused(coffee))
        XCTAssertEqual(fixture.attachedCount(of: coffee), 1)
        XCTAssertEqual(fixture.attachedCount(of: walk), 1)
        XCTAssertTrue(fixture.groups.isEmpty)
    }

    func testRemovingFirstEventSelectedThroughItsRowKeepsTheCoincidentSecondEvent() async throws {
        try await assertSelectingAndRemovingCoincidentEvent(at: 0)
    }

    func testRemovingSecondEventSelectedThroughItsRowKeepsTheCoincidentFirstEvent() async throws {
        try await assertSelectingAndRemovingCoincidentEvent(at: 1)
    }

    func testRapidMemberSelectionsLeaveOnlyTheLatestEventSelected() async throws {
        let fixture = try await makeFixture()
        defer { fixture.close() }
        let friend = fixture.annotation("Amina", meters: 0)
        let outing = fixture.annotation("Balade", meters: 5)
        fixture.update([.friend("amina"): friend, .outing("walk"): outing])

        fixture.controller.select(.friend("amina"), on: fixture.mapView)
        try await eventually("The friend is selected and both member views are available") {
            fixture.isSelected(friend) && fixture.annotationStore.view(for: outing) != nil
        }

        // Queue competing native selections without yielding to the main queue.
        fixture.controller.select(.outing("walk"), on: fixture.mapView)
        fixture.controller.select(.friend("amina"), on: fixture.mapView)
        fixture.controller.select(.outing("walk"), on: fixture.mapView)
        try await eventually("Only the latest requested member is selected") {
            fixture.isSelected(outing) && !fixture.isSelected(friend)
        }

        fixture.controller.didDeselect(friend, on: fixture.mapView)
        await flushMainQueue()

        XCTAssertTrue(fixture.controller.isFocused(outing))
        XCTAssertFalse(fixture.controller.isFocused(friend))
        XCTAssertEqual(fixture.attachedCount(of: outing), 1)
        XCTAssertEqual(fixture.attachedCount(of: friend), 1)
        XCTAssertTrue(fixture.groups.isEmpty)
        XCTAssertEqual(fixture.annotationStore.selectedAnnotations.count, 1)
    }

    func testActivatingGroupClearsMemberFocusAndClosesItsPresentationOnce() async throws {
        let fixture = try await makeFixture()
        defer { fixture.close() }
        let sources = fixture.mixedSources()
        let friend = try XCTUnwrap(sources[.friend("amina")])
        fixture.update(sources)
        fixture.controller.select(.friend("amina"), on: fixture.mapView)
        try await eventually("The member is selected beside the remaining group") {
            fixture.isSelected(friend) && fixture.groups.first.flatMap { fixture.groupView(for: $0) } != nil
        }
        let group = try XCTUnwrap(fixture.groups.first)
        let groupView = try XCTUnwrap(fixture.groupView(for: group))

        // Queue native deselection before the tap observer activates the group.
        fixture.annotationStore.deselectAnnotation(friend, animated: false)
        fixture.controller.activate(group, view: groupView, on: fixture.mapView)
        await flushMainQueue()

        XCTAssertFalse(fixture.controller.isFocused(friend))
        XCTAssertFalse(fixture.isSelected(friend))
        XCTAssertEqual(fixture.attachedCount(of: friend), 0)
        XCTAssertTrue(fixture.groups.first === group)
        XCTAssertEqual(group.memberAnnotations.count, 3)
        XCTAssertEqual(fixture.socialAnnotations.count, 1)
        XCTAssertTrue(groupView.isExpanded)
        XCTAssertTrue(groupView.accessibilityTraits.contains(.selected))
        XCTAssertEqual(fixture.deselectedMembers, [.friend("amina")])
    }

    func testActivatingDistantSingletonClosesThePreviouslyExpandedGroup() async throws {
        let fixture = try await makeFixture()
        defer { fixture.close() }
        let outing = fixture.annotation("Café", meters: 150)
        fixture.update([
            .currentUser: fixture.annotation("Vous", meters: 0),
            .friend("amina"): fixture.annotation("Amina", meters: 5),
            .outing("coffee"): outing
        ])
        let group = try XCTUnwrap(fixture.groups.first)
        try await eventually("The group and distant event have views") {
            fixture.groupView(for: group) != nil && fixture.annotationStore.view(for: outing) != nil
        }
        let groupView = try XCTUnwrap(fixture.groupView(for: group))
        let outingView = try XCTUnwrap(fixture.annotationStore.view(for: outing))
        fixture.annotationStore.selectAnnotation(group, animated: false)
        try await eventually("The initial group is expanded") { groupView.isExpanded }

        // The old group's callback must not be responsible for closing its view.
        fixture.annotationStore.deselectAnnotation(group, animated: false)
        XCTAssertEqual(
            fixture.controller.activate(outing, view: outingView, on: fixture.mapView),
            .outing("coffee")
        )
        await flushMainQueue()

        XCTAssertFalse(groupView.isExpanded)
        XCTAssertFalse(groupView.accessibilityTraits.contains(.selected))
        XCTAssertNil(groupView.accessibilityCustomActions)
        XCTAssertTrue(fixture.controller.isFocused(outing))
        XCTAssertEqual(fixture.attachedCount(of: outing), 1)
        XCTAssertTrue(fixture.groups.first === group)
        XCTAssertEqual(group.memberAnnotations.count, 2)
        XCTAssertEqual(fixture.socialAnnotations.count, 2)
        XCTAssertTrue(fixture.deselectedMembers.isEmpty)
    }

    func testAutomaticRecenteringPreservesSelectionUntilUserMovesTheMap() async throws {
        let fixture = try await makeFixture()
        defer { fixture.close() }
        let sources = fixture.mixedSources()
        let friend = try XCTUnwrap(sources[.friend("amina")])
        fixture.update(sources)
        let group = try XCTUnwrap(fixture.groups.first)

        fixture.controller.center(on: .friend("amina"), on: fixture.mapView)
        // Mapbox can finish one camera update before reporting the next one.
        fixture.controller.regionDidChange(on: fixture.mapView)
        fixture.controller.regionWillChange(on: fixture.mapView, userInitiated: false)
        fixture.controller.visibleRegionDidChange(on: fixture.mapView, userInitiated: false)
        try await eventually("Automatic camera callbacks preserve the requested selection") {
            fixture.isSelected(friend)
        }

        XCTAssertTrue(fixture.controller.isFocused(friend))
        XCTAssertEqual(fixture.attachedCount(of: friend), 1)
        XCTAssertTrue(fixture.deselectedMembers.isEmpty)

        fixture.controller.regionWillChange(on: fixture.mapView, userInitiated: true)
        fixture.controller.visibleRegionDidChange(on: fixture.mapView, userInitiated: true)
        fixture.controller.regionWillChange(on: fixture.mapView, userInitiated: true)
        await flushMainQueue()

        XCTAssertFalse(fixture.isSelected(friend))
        XCTAssertFalse(fixture.controller.isFocused(friend))
        XCTAssertEqual(fixture.attachedCount(of: friend), 0)
        XCTAssertTrue(fixture.groups.first === group)
        XCTAssertEqual(group.memberAnnotations.count, 3)
        XCTAssertEqual(fixture.socialAnnotations.count, 1)
        XCTAssertEqual(fixture.deselectedMembers, [.friend("amina")])
    }

    func testAddingNearbySourcesPreservesSelectionAndRemovingSelectedSourceClearsIt() async throws {
        let fixture = try await makeFixture()
        defer { fixture.close() }
        let friend = fixture.annotation("Amina", meters: 5)
        fixture.update([.friend("amina"): friend])
        try await eventually("The friend view appears") { fixture.annotationStore.view(for: friend) != nil }
        fixture.controller.select(.friend("amina"), on: fixture.mapView)
        try await eventually("The friend is selected") { fixture.isSelected(friend) }

        let currentUser = fixture.annotation("Vous", meters: 0)
        let outing = fixture.annotation("Balade", meters: 10)
        fixture.update([.friend("amina"): friend, .currentUser: currentUser, .outing("walk"): outing])
        let remainingGroup = try XCTUnwrap(fixture.groups.first)

        XCTAssertTrue(fixture.isSelected(friend))
        XCTAssertEqual(remainingGroup.memberAnnotations.count, 2)
        XCTAssertEqual(fixture.socialAnnotations.count, 2)

        fixture.update([.currentUser: currentUser, .outing("walk"): outing])
        try await eventually("The removed friend is no longer selected or attached") {
            !fixture.isSelected(friend) && fixture.attachedCount(of: friend) == 0
        }
        fixture.controller.didDeselect(friend, on: fixture.mapView)
        await flushMainQueue()

        XCTAssertTrue(fixture.groups.first === remainingGroup)
        XCTAssertEqual(fixture.socialAnnotations.count, 1)
        XCTAssertFalse(fixture.controller.isFocused(friend))
        XCTAssertEqual(remainingGroup.memberAnnotations.count, 2)
    }

    func testReplacingSourceObjectAtSameCoordinateUpdatesGroupAndSelectsNewObject() async throws {
        let fixture = try await makeFixture()
        defer { fixture.close() }
        var sources = fixture.mixedSources()
        let previousFriend = try XCTUnwrap(sources[.friend("amina")])
        fixture.update(sources)
        let group = try XCTUnwrap(fixture.groups.first)
        try await eventually("The group view appears") { fixture.groupView(for: group) != nil }
        let view = try XCTUnwrap(fixture.groupView(for: group))
        fixture.annotationStore.selectAnnotation(group, animated: false)
        try await eventually("The group expands") { view.isExpanded }

        let replacement = MapAnnotation()
        replacement.coordinate = previousFriend.coordinate
        replacement.title = "Amina actualisée"
        sources[.friend("amina")] = replacement
        fixture.update(sources)

        XCTAssertTrue(fixture.groups.first === group)
        XCTAssertTrue(view.isExpanded)
        XCTAssertFalse(group.memberAnnotations.contains { ($0 as AnyObject) === previousFriend })
        XCTAssertTrue(group.memberAnnotations.contains { ($0 as AnyObject) === replacement })
        XCTAssertTrue(view.accessibilityCustomActions?.contains {
            $0.name.contains("Amina actualisée")
        } == true)

        // This is the same controller entry used by the real rows and accessibility actions.
        view.onSelectMember?(.friend("amina"))
        try await eventually("The refreshed member is selected") { fixture.isSelected(replacement) }

        XCTAssertEqual(fixture.attachedCount(of: previousFriend), 0)
        XCTAssertEqual(fixture.attachedCount(of: replacement), 1)
        XCTAssertFalse(fixture.isSelected(previousFriend))
        XCTAssertEqual(fixture.annotationStore.view(for: replacement)?.annotation?.title ?? nil, "Amina actualisée")
    }

    func testReplacingFocusedSourcePreservesNativeSelectionAndIgnoresOldCallbacks() async throws {
        let fixture = try await makeFixture()
        defer { fixture.close() }
        var sources = fixture.mixedSources()
        let previousFriend = try XCTUnwrap(sources[.friend("amina")])
        fixture.update(sources)
        fixture.controller.select(.friend("amina"), on: fixture.mapView)
        try await eventually("The original friend is selected") { fixture.isSelected(previousFriend) }
        let previousView = try XCTUnwrap(fixture.annotationStore.view(for: previousFriend))
        let remainingGroup = try XCTUnwrap(fixture.groups.first)

        let replacement = fixture.annotation("Amina actualisée", meters: 5)
        sources[.friend("amina")] = replacement
        fixture.update(sources)
        try await eventually("The replacement inherits the native selection") {
            fixture.isSelected(replacement) && !fixture.isSelected(previousFriend)
        }

        fixture.controller.didDeselect(previousFriend, on: fixture.mapView)
        XCTAssertNil(fixture.controller.activate(previousFriend, view: previousView, on: fixture.mapView))
        await flushMainQueue()

        XCTAssertTrue(fixture.controller.isFocused(replacement))
        XCTAssertFalse(fixture.controller.isFocused(previousFriend))
        XCTAssertTrue(fixture.isSelected(replacement))
        XCTAssertEqual(fixture.attachedCount(of: previousFriend), 0)
        XCTAssertEqual(fixture.attachedCount(of: replacement), 1)
        XCTAssertTrue(fixture.groups.first === remainingGroup)
        XCTAssertEqual(remainingGroup.memberAnnotations.count, 2)
        XCTAssertEqual(fixture.socialAnnotations.count, 2)
        XCTAssertTrue(fixture.deselectedMembers.isEmpty)
    }

    func testLateDeselectionOfReplacedGroupDoesNotCloseNewGroup() async throws {
        let fixture = try await makeFixture()
        defer { fixture.close() }
        fixture.update([
            .currentUser: fixture.annotation("Vous", meters: 0),
            .friend("amina"): fixture.annotation("Amina", meters: 5)
        ])
        let previousGroup = try XCTUnwrap(fixture.groups.first)
        try await eventually("The first group view appears") {
            fixture.groupView(for: previousGroup) != nil
        }
        let previousView = try XCTUnwrap(fixture.groupView(for: previousGroup))
        fixture.annotationStore.selectAnnotation(previousGroup, animated: false)
        try await eventually("The first group expands") { previousView.isExpanded }

        fixture.update([
            .friend("leo"): fixture.annotation("Léo", meters: 0),
            .outing("coffee"): fixture.annotation("Café", meters: 5)
        ])
        let replacementGroup = try XCTUnwrap(fixture.groups.first)
        XCTAssertNotEqual(previousGroup.identifier, replacementGroup.identifier)
        try await eventually("The replacement group view appears") {
            fixture.groupView(for: replacementGroup) != nil
        }
        let replacementView = try XCTUnwrap(fixture.groupView(for: replacementGroup))
        fixture.annotationStore.selectAnnotation(replacementGroup, animated: false)
        try await eventually("The replacement group expands") { replacementView.isExpanded }

        fixture.controller.didDeselect(previousGroup, on: fixture.mapView)
        await flushMainQueue()

        XCTAssertTrue(replacementView.isExpanded)
        XCTAssertTrue(replacementView.accessibilityTraits.contains(.selected))
        XCTAssertTrue(fixture.isSelected(replacementGroup))
        XCTAssertEqual(fixture.socialAnnotations.count, 1)

        fixture.annotationStore.deselectAnnotation(replacementGroup, animated: false)
        try await eventually("Native deselection closes the replacement group") {
            !replacementView.isExpanded
        }
        XCTAssertNil(replacementView.accessibilityCustomActions)
    }

    func testTearDownCancelsSelectionAlreadyScheduledOnMainQueue() async throws {
        let fixture = try await makeFixture()
        defer { fixture.close() }
        let friend = fixture.annotation("Amina", meters: 0)
        fixture.update([.friend("amina"): friend])
        try await eventually("The singleton view appears") { fixture.annotationStore.view(for: friend) != nil }

        fixture.controller.select(.friend("amina"), on: fixture.mapView)
        fixture.controller.tearDown()
        // The selection block is enqueued before this continuation, with no blocking wait.
        await flushMainQueue()

        XCTAssertFalse(fixture.isSelected(friend))
        XCTAssertFalse(fixture.controller.isFocused(friend))
    }

    func testCollapseCancelsSelectionAlreadyScheduledOnMainQueue() async throws {
        let fixture = try await makeFixture()
        defer { fixture.close() }
        let friend = fixture.annotation("Amina", meters: 0)
        fixture.update([.friend("amina"): friend])
        try await eventually("The singleton view appears") { fixture.annotationStore.view(for: friend) != nil }

        fixture.controller.select(.friend("amina"), on: fixture.mapView)
        fixture.controller.collapse(on: fixture.mapView)
        await flushMainQueue()

        XCTAssertFalse(fixture.isSelected(friend))
        XCTAssertFalse(fixture.controller.isFocused(friend))
        XCTAssertEqual(fixture.attachedCount(of: friend), 1)
        XCTAssertEqual(fixture.socialAnnotations.count, 1)
    }

    func testAnnotationStoreBatchOperationsPreserveIdentityAndCleanUpOnce() {
        let mapView = makeLocalMap()
        mapView.frame = CGRect(x: 0, y: 0, width: 320, height: 480)
        let store = MapAnnotationStore(mapView: mapView)
        let first = MapAnnotation(coordinate: CLLocationCoordinate2D(latitude: 48.8566, longitude: 2.3522))
        let deferred = MapAnnotation()
        var createdViews: [ReuseTrackingAnnotationView] = []
        var additions: [Int] = []
        var deselections = 0
        store.makeView = { annotation in
            let view = ReuseTrackingAnnotationView(annotation: annotation)
            view.bounds = CGRect(x: 0, y: 0, width: 24, height: 24)
            createdViews.append(view)
            return view
        }
        store.onDidAdd = { additions.append($0.count) }
        store.onDeselect = { _ in deselections += 1 }
        defer { store.removeAll() }

        store.addAnnotations([first, first, deferred, deferred])
        store.addAnnotations([deferred, first])
        XCTAssertEqual(store.annotations.count, 2)
        XCTAssertTrue(store.annotations[0] === first)
        XCTAssertTrue(store.annotations[1] === deferred)
        XCTAssertEqual(createdViews.count, 1)
        XCTAssertEqual(additions, [1])

        deferred.coordinate = first.coordinate
        store.synchronizeCoordinates()
        XCTAssertEqual(createdViews.count, 2)
        XCTAssertEqual(additions, [1, 1])
        store.selectAnnotation(first, animated: false)
        store.removeAnnotations([first, deferred, first, deferred])

        XCTAssertTrue(store.annotations.isEmpty)
        XCTAssertTrue(store.selectedAnnotations.isEmpty)
        XCTAssertEqual(deselections, 1)
        XCTAssertEqual(createdViews.map(\.reuseCount), [1, 1])
        XCTAssertTrue(createdViews.allSatisfy { $0.superview == nil })
    }

    func testAnnotationStoreMovesResizesAndRemovesItsNativeView() async throws {
        let fixture = try await makeFixture()
        defer { fixture.close() }
        let friend = fixture.annotation("Amina", meters: 0)
        fixture.update([.friend("amina"): friend])
        let view = try XCTUnwrap(fixture.annotationStore.view(for: friend))
        fixture.controller.select(.friend("amina"), on: fixture.mapView)
        try await eventually("The member is selected") { fixture.isSelected(friend) }

        friend.coordinate = fixture.coordinate(meters: 150)
        view.bounds.size = CGSize(width: 72, height: 44)
        view.centerOffset = CGSize(width: 20, height: -30)
        fixture.update([.friend("amina"): friend])
        try await eventually("Mapbox applies the new coordinate, size, and anchor offset") {
            let anchor = fixture.mapView.mapboxMap.point(for: friend.coordinate)
            let frame = view.convert(view.bounds, to: fixture.mapView)
            return !view.isHidden && abs(frame.midX - anchor.x - 20) <= 1
                && abs(frame.midY - anchor.y + 30) <= 1
                && frame.width == 72 && frame.height == 44
        }
        XCTAssertTrue(fixture.annotationStore.view(for: friend) === view)
        XCTAssertTrue(fixture.isSelected(friend))

        fixture.update([:])
        await flushMainQueue()
        XCTAssertNil(view.superview)
        XCTAssertNil(fixture.annotationStore.view(for: friend))
        XCTAssertTrue(fixture.annotationStore.annotations.isEmpty)
        XCTAssertTrue(fixture.annotationStore.selectedAnnotations.isEmpty)
        XCTAssertEqual(fixture.deselectedMembers, [.friend("amina")])
    }

    func testOffscreenFriendIndicatorsFollowCardinalDirectionsAndMapRotation() async throws {
        let fixture = try await makeCoordinatorFixture()
        defer {
            fixture.coordinator.removeMapOffscreenIndicatorContainer()
            fixture.close()
        }
        let center = fixture.mapView.mapboxMap.cameraState.center
        let targets: [(id: String, coordinate: CLLocationCoordinate2D)] = [
            ("north", CLLocationCoordinate2D(latitude: center.latitude + 0.2, longitude: center.longitude)),
            ("east", CLLocationCoordinate2D(latitude: center.latitude, longitude: center.longitude + 0.2)),
            ("south", CLLocationCoordinate2D(latitude: center.latitude - 0.2, longitude: center.longitude)),
            ("west", CLLocationCoordinate2D(latitude: center.latitude, longitude: center.longitude - 0.2)),
            ("visible", center)
        ]
        fixture.coordinator.friendAnnotations = Dictionary(uniqueKeysWithValues: targets.map { target in
            let annotation = FriendLocationAnnotation()
            annotation.userID = target.id
            annotation.coordinate = target.coordinate
            return (target.id, annotation)
        })
        fixture.coordinator.friendPresenceInfoByUserID = Dictionary(uniqueKeysWithValues: targets.map { target in
            (target.id, MapUserPresenceInfo(
                displayName: target.id,
                relationshipText: "Ami",
                locationSampledAt: nil,
                spotEnteredAt: nil,
                isLocationFresh: true,
                keepsSpotDurationVisible: false
            ))
        })
        fixture.coordinator.installMapOffscreenIndicatorContainer(on: fixture.mapView)
        let indicatorBounds = try XCTUnwrap(MapOffscreenIndicatorLayout.indicatorBounds(
            in: fixture.coordinator.visibleSafeBounds(on: fixture.mapView),
            safeAreaInsets: .zero
        ))
        let cases: [(bearing: Double, edges: [MapOffscreenIndicatorEdge])] = [
            (0, [.top, .right, .bottom, .left]),
            (90, [.left, .top, .right, .bottom])
        ]
        for testCase in cases {
            fixture.mapView.mapboxMap.setCamera(to: CameraOptions(bearing: testCase.bearing))
            for target in targets.prefix(4) {
                XCTAssertEqual(fixture.mapView.mapboxMap.point(for: target.coordinate), CGPoint(x: -1, y: -1))
            }
            fixture.coordinator.refreshMapOffscreenIndicators(on: fixture.mapView)
            let indicators = fixture.mapView.subviews.flatMap(\.subviews)
                .compactMap { $0 as? FriendOffscreenIndicatorView }
            XCTAssertEqual(Set(indicators.map(\.userID)), Set(targets.prefix(4).map(\.id)),
                           "Only offscreen friends should receive an indicator")
            for (target, edge) in zip(targets, testCase.edges) {
                let indicator = try XCTUnwrap(indicators.first { $0.userID == target.id })
                let expectedCenter: CGPoint
                switch edge {
                case .top:
                    expectedCenter = CGPoint(x: indicatorBounds.midX, y: indicatorBounds.minY)
                case .right:
                    expectedCenter = CGPoint(x: indicatorBounds.maxX, y: indicatorBounds.midY)
                case .bottom:
                    expectedCenter = CGPoint(x: indicatorBounds.midX, y: indicatorBounds.maxY)
                case .left:
                    expectedCenter = CGPoint(x: indicatorBounds.minX, y: indicatorBounds.midY)
                }
                XCTAssertEqual(indicator.center.x, expectedCenter.x, accuracy: 2,
                               "\(target.id) at bearing \(testCase.bearing)")
                XCTAssertEqual(indicator.center.y, expectedCenter.y, accuracy: 2,
                               "\(target.id) at bearing \(testCase.bearing)")
            }
        }
    }

    // MARK: - Passive touch observer callbacks

    func testNearbyNativeSelectionBeforeTouchEndDoesNotRefreshAnotherFriend() async throws {
        let fixture = try await makeCoordinatorFixture()
        defer { fixture.close() }
        let touch = try fixture.beginTouch(on: fixture.first)
        fixture.annotationStore.selectAnnotation(fixture.second, animated: false)
        fixture.observer.onTapEnded?(touch)
        await flushMainQueue()

        XCTAssertEqual(fixture.selectedFriendIDs, ["first"])
        XCTAssertTrue(fixture.isSelected(fixture.first))
    }

    func testNearbyNativeSelectionAfterTouchEndDoesNotRefreshAnotherFriend() async throws {
        let fixture = try await makeCoordinatorFixture()
        defer { fixture.close() }
        try fixture.tap(fixture.first)
        await flushMainQueue()
        fixture.annotationStore.selectAnnotation(fixture.second, animated: false)
        await flushMainQueue()

        XCTAssertEqual(fixture.selectedFriendIDs, ["first"])
        XCTAssertTrue(fixture.isSelected(fixture.first))
    }

    func testNativeSelectionOfTouchedFriendIsDeliveredOnce() async throws {
        let fixture = try await makeCoordinatorFixture()
        defer { fixture.close() }
        let touch = try fixture.beginTouch(on: fixture.first)
        fixture.annotationStore.selectAnnotation(fixture.first, animated: false)
        fixture.observer.onTapEnded?(touch)
        await flushMainQueue()

        XCTAssertEqual(fixture.selectedFriendIDs, ["first"])
    }

    func testNewTouchCanSelectNearbyFriendImmediately() async throws {
        let fixture = try await makeCoordinatorFixture()
        defer { fixture.close() }
        try fixture.tap(fixture.first)
        try fixture.tap(fixture.second)
        await flushMainQueue()

        XCTAssertEqual(fixture.selectedFriendIDs, ["first", "second"])
        XCTAssertTrue(fixture.isSelected(fixture.second))
    }

    func testCancelledFriendTouchDoesNotActivateAndAllowsNativeSelection() async throws {
        let fixture = try await makeCoordinatorFixture()
        defer { fixture.close() }
        _ = try fixture.beginTouch(on: fixture.first)
        fixture.observer.onTouchCancelled?()
        XCTAssertTrue(fixture.selectedFriendIDs.isEmpty)
        fixture.annotationStore.selectAnnotation(fixture.second, animated: false)
        await flushMainQueue()
        XCTAssertEqual(fixture.selectedFriendIDs, ["second"])
    }

    func testSwiftUIDetailEchoDoesNotReleaseTouchButAnotherDetailDoes() async throws {
        let fixture = try await makeCoordinatorFixture()
        defer { fixture.close() }
        try fixture.tap(fixture.first)
        fixture.coordinator.synchronizeDetailSelection(.friend("first"), on: fixture.mapView)
        await flushMainQueue()
        fixture.annotationStore.selectAnnotation(fixture.second, animated: false)
        await flushMainQueue()
        XCTAssertEqual(fixture.selectedFriendIDs, ["first"])
        XCTAssertTrue(fixture.isSelected(fixture.first))

        fixture.coordinator.synchronizeDetailSelection(.friend("second"), on: fixture.mapView)
        await flushMainQueue()
        XCTAssertEqual(fixture.selectedFriendIDs, ["first", "second"])
        XCTAssertTrue(fixture.isSelected(fixture.second))
    }

    func testRepeatedTapOnSelectedFriendDoesNotRefreshAgain() async throws {
        let fixture = try await makeCoordinatorFixture()
        defer { fixture.close() }
        try fixture.tap(fixture.first)
        try fixture.tap(fixture.first)
        await flushMainQueue()
        XCTAssertEqual(fixture.selectedFriendIDs, ["first"])
    }

    func testNativeSelectionIsAvailableAfterTouchProtectionExpires() async throws {
        let fixture = try await makeCoordinatorFixture()
        defer { fixture.close() }
        try fixture.tap(fixture.first)
        try await Task.sleep(nanoseconds: 1_100_000_000)
        fixture.annotationStore.selectAnnotation(fixture.second, animated: false)
        await flushMainQueue()
        XCTAssertEqual(fixture.selectedFriendIDs, ["first", "second"])
    }

    private func makeCoordinatorFixture() async throws -> CoordinatorMapFixture {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let scene = try XCTUnwrap(scenes.first { $0.activationState == .foregroundActive } ?? scenes.first)
        let fixture = CoordinatorMapFixture(windowScene: scene)
        do {
            try await eventually("Both production friend pins are rendered") {
                fixture.annotationStore.view(for: fixture.first)?.isHidden == false
                    && fixture.annotationStore.view(for: fixture.second)?.isHidden == false
            }
            return fixture
        } catch {
            fixture.close()
            throw error
        }
    }

    func testPassiveTapObserverReportsConsecutiveTouchCallbacks() {
        let view = UIView(frame: CGRect(x: 0, y: 0, width: 200, height: 200))
        let observer = PassiveMapTapObserver(maximumMovement: 12)
        view.addGestureRecognizer(observer)
        let event = UIEvent()
        let openingPoint = CGPoint(x: 20, y: 20)
        let backgroundPoint = CGPoint(x: 120, y: 90)
        var beganPoints: [CGPoint] = []
        var endedPoints: [CGPoint] = []
        var cancellationCount = 0
        observer.onTouchBegan = { beganPoints.append($0) }
        observer.onTapEnded = { endedPoints.append($0) }
        observer.onTouchCancelled = { cancellationCount += 1 }

        // Check callback bookkeeping only; this bypasses UIKit gesture arbitration.
        let openingTouch = ObserverTestTouch(point: openingPoint)
        observer.touchesBegan([openingTouch], with: event)
        observer.touchesEnded([openingTouch], with: event)
        let backgroundTouch = ObserverTestTouch(point: backgroundPoint)
        observer.touchesBegan([backgroundTouch], with: event)
        observer.touchesEnded([backgroundTouch], with: event)

        XCTAssertEqual(beganPoints, [openingPoint, backgroundPoint])
        XCTAssertEqual(endedPoints, [openingPoint, backgroundPoint])
        XCTAssertEqual(cancellationCount, 0)
    }

    func testPassiveTapObserverCancelsDragOnceWithoutReportingATap() {
        let view = UIView(frame: CGRect(x: 0, y: 0, width: 200, height: 200))
        let observer = PassiveMapTapObserver(maximumMovement: 12)
        view.addGestureRecognizer(observer)
        let event = UIEvent()
        let touch = ObserverTestTouch(point: CGPoint(x: 20, y: 20))
        var tapCount = 0
        var cancellationCount = 0
        observer.onTapEnded = { _ in tapCount += 1 }
        observer.onTouchCancelled = { cancellationCount += 1 }

        observer.touchesBegan([touch], with: event)
        touch.point = CGPoint(x: 40, y: 20)
        observer.touchesMoved([touch], with: event)
        observer.touchesEnded([touch], with: event)
        observer.touchesCancelled([touch], with: event)

        XCTAssertEqual(tapCount, 0)
        XCTAssertEqual(cancellationCount, 1)
    }

    func testPassiveTapObserverCancelsSecondFingerOnceWithoutReportingATap() {
        let view = UIView(frame: CGRect(x: 0, y: 0, width: 200, height: 200))
        let observer = PassiveMapTapObserver(maximumMovement: 12)
        view.addGestureRecognizer(observer)
        let event = UIEvent()
        let firstTouch = ObserverTestTouch(point: CGPoint(x: 20, y: 20))
        let secondTouch = ObserverTestTouch(point: CGPoint(x: 60, y: 60))
        var beganCount = 0
        var tapCount = 0
        var cancellationCount = 0
        observer.onTouchBegan = { _ in beganCount += 1 }
        observer.onTapEnded = { _ in tapCount += 1 }
        observer.onTouchCancelled = { cancellationCount += 1 }

        observer.touchesBegan([firstTouch], with: event)
        observer.touchesBegan([secondTouch], with: event)
        observer.touchesEnded([firstTouch, secondTouch], with: event)
        observer.touchesCancelled([firstTouch, secondTouch], with: event)

        XCTAssertEqual(beganCount, 1)
        XCTAssertEqual(tapCount, 0)
        XCTAssertEqual(cancellationCount, 1)
    }

    // MARK: - Bounded native view waits

    private func assertSelectingAndRemovingCoincidentEvent(at rowIndex: Int) async throws {
        let fixture = try await makeFixture()
        defer { fixture.close() }
        let events: [(id: MapSocialClusterMemberID, annotation: MapAnnotation)] = [
            (.outing("a-walk"), fixture.annotation("Balade", meters: 0)),
            (.outing("b-coffee"), fixture.annotation("Café", meters: 0))
        ]
        let selected = events[rowIndex]
        let remaining = events[1 - rowIndex]
        XCTAssertEqual(selected.annotation.coordinate.latitude, remaining.annotation.coordinate.latitude)
        XCTAssertEqual(selected.annotation.coordinate.longitude, remaining.annotation.coordinate.longitude)
        fixture.update(Dictionary(uniqueKeysWithValues: events.map { ($0.id, $0.annotation) }))
        XCTAssertEqual(fixture.groups.count, 1)
        let group = try XCTUnwrap(fixture.groups.first)
        try await eventually("The coincident event group has a view") {
            fixture.groupView(for: group) != nil
        }
        let groupView = try XCTUnwrap(fixture.groupView(for: group))
        fixture.annotationStore.selectAnnotation(group, animated: false)
        try await eventually("The coincident event list opens") { groupView.isExpanded }
        groupView.layoutIfNeeded()

        let rows = fixture.memberRows(in: groupView)
        XCTAssertEqual(rows.map(\.accessibilityLabel), ["Balade", "Café"])
        let row = try XCTUnwrap(rows.indices.contains(rowIndex) ? rows[rowIndex] : nil)
        // The store exposes views before Mapbox places and unhides them.
        try await eventually("The event row owns its rendered map hit target") {
            groupView.layoutIfNeeded()
            let center = row.convert(
                CGPoint(x: row.bounds.midX, y: row.bounds.midY),
                to: fixture.mapView
            )
            return fixture.mapView.hitTest(center, with: nil) === row
        }

        // The row must own a tap even where it overlaps the native marker's bounds.
        let rowTap = try XCTUnwrap(row.gestureRecognizers?.compactMap { $0 as? UITapGestureRecognizer }.first)
        let ancestorTap = UITapGestureRecognizer()
        fixture.mapView.addGestureRecognizer(ancestorTap)
        let scrollPan = UIPanGestureRecognizer()
        fixture.mapView.addGestureRecognizer(scrollPan)
        XCTAssertEqual(rowTap.delegate?.gestureRecognizer?(rowTap, shouldBeRequiredToFailBy: ancestorTap), true)
        XCTAssertEqual(rowTap.delegate?.gestureRecognizer?(rowTap, shouldBeRequiredToFailBy: scrollPan), false)
        XCTAssertTrue(rowTap.cancelsTouchesInView, "A recognized tap must not also fire touchUpInside.")

        // Exercise the real row target/action instead of calling controller.select directly.
        // This does not synthesize a finger gesture or Mapbox's competing gesture callbacks.
        row.sendActions(for: .touchUpInside)
        try await eventually("The chosen row selects its own event") {
            fixture.isSelected(selected.annotation) && fixture.controller.isFocused(selected.annotation)
        }

        XCTAssertFalse(fixture.controller.isFocused(remaining.annotation))
        XCTAssertFalse(fixture.isSelected(remaining.annotation))
        XCTAssertEqual(fixture.annotationStore.selectedAnnotations.count, 1)
        XCTAssertTrue(fixture.groups.isEmpty)
        XCTAssertEqual(fixture.attachedCount(of: group), 0)
        XCTAssertEqual(fixture.attachedCount(of: selected.annotation), 1)
        XCTAssertEqual(fixture.attachedCount(of: remaining.annotation), 1)
        XCTAssertEqual(fixture.socialAnnotations.count, 2)
        XCTAssertTrue(fixture.deselectedMembers.isEmpty)

        fixture.update([remaining.id: remaining.annotation])
        try await eventually("Removing the chosen event leaves one unselected singleton") {
            fixture.socialAnnotations.count == 1 && fixture.annotationStore.selectedAnnotations.isEmpty
        }
        // Repeated source snapshots must not dismiss the product presentation a second time.
        fixture.update([remaining.id: remaining.annotation])
        await flushMainQueue()

        XCTAssertFalse(fixture.controller.isFocused(selected.annotation))
        XCTAssertFalse(fixture.controller.isFocused(remaining.annotation))
        XCTAssertFalse(fixture.controller.hasActivePresentation)
        XCTAssertTrue(fixture.annotationStore.selectedAnnotations.isEmpty)
        XCTAssertTrue(fixture.groups.isEmpty)
        XCTAssertEqual(fixture.attachedCount(of: group), 0)
        XCTAssertEqual(fixture.attachedCount(of: selected.annotation), 0)
        XCTAssertEqual(fixture.attachedCount(of: remaining.annotation), 1)
        XCTAssertEqual(fixture.socialAnnotations.count, 1)
        XCTAssertEqual(fixture.deselectedMembers, [selected.id])
    }

    private func flushMainQueue() async {
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async { continuation.resume() }
        }
    }

    private func makeFixture(onRequestOwnProfile: (() -> Void)? = nil, onRequestFriendProfile: ((String) -> Void)? = nil) async throws -> MapFixture {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let scene = try XCTUnwrap(scenes.first { $0.activationState == .foregroundActive } ?? scenes.first)
        let fixture = MapFixture(windowScene: scene, onRequestOwnProfile: onRequestOwnProfile, onRequestFriendProfile: onRequestFriendProfile)
        do {
            try await eventually("The test map finishes its initial region change") {
                fixture.hasSettledInitialRegion
            }
            return fixture
        } catch {
            fixture.close()
            throw error
        }
    }

    private func eventually(
        _ description: String,
        file: StaticString = #filePath,
        line: UInt = #line,
        condition: @MainActor () -> Bool
    ) async throws {
        let deadline = Date().addingTimeInterval(5)
        while Date() < deadline {
            if condition() { return }
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        XCTFail(description, file: file, line: line)
        throw WaitFailure.timeout
    }

    private enum WaitFailure: Error {
        case timeout
    }
}

/// Supplies coordinates to the observer's public touch callbacks; it does not inject OS events.
@MainActor
private final class ObserverTestTouch: UITouch {
    var point: CGPoint

    init(point: CGPoint) {
        self.point = point
        super.init()
    }

    override func location(in view: UIView?) -> CGPoint {
        point
    }
}

/// Uses the production store and observer; only the ordering of selections is imposed.
@MainActor
private final class CoordinatorMapFixture {
    let mapView = makeLocalMap()
    let first = FriendLocationAnnotation()
    let second = FriendLocationAnnotation()
    private let window: UIWindow
    private weak var previousKeyWindow: UIWindow?
    private(set) var selectedFriendIDs: [String] = []
    let coordinator = MapWithFogView.Coordinator(
        fogColor: .clear, onSelectFriend: { _ in },
        onSelectOutingPlan: { _ in }, onDeselectOutingPlan: { _ in }, onCreateEvent: { _ in }
    )
    var annotationStore: MapAnnotationStore { coordinator.annotationStore }
    var observer: PassiveMapTapObserver {
        mapView.gestureRecognizers!.compactMap { $0 as? PassiveMapTapObserver }.first!
    }

    init(windowScene: UIWindowScene) {
        previousKeyWindow = windowScene.windows.first(where: \.isKeyWindow)
        window = UIWindow(windowScene: windowScene)
        window.frame = windowScene.effectiveGeometry.coordinateSpace.bounds
        coordinator.onSelectFriend = { [weak self] in self?.selectedFriendIDs.append($0) }
        let root = UIViewController()
        root.view = mapView
        window.rootViewController = root
        window.windowLevel = UIWindow.Level(rawValue: UIWindow.Level.normal.rawValue + 1)
        coordinator.install(on: mapView)
        window.makeKeyAndVisible()
        window.layoutIfNeeded()
        let center = CLLocationCoordinate2D(latitude: 48.85, longitude: 2.35)
        mapView.mapboxMap.setCamera(to: CameraOptions(center: center, zoom: 15))
        first.userID = "first"
        first.coordinate = CLLocationCoordinate2D(latitude: center.latitude, longitude: center.longitude - 0.0007)
        second.userID = "second"
        second.coordinate = CLLocationCoordinate2D(latitude: center.latitude, longitude: center.longitude + 0.0007)
        coordinator.friendAnnotations = ["first": first, "second": second]
        coordinator.synchronizeSocialProximityAnnotations(on: mapView)
        coordinator.installImmediateSocialAnnotationRecognizer(on: mapView)
    }

    func beginTouch(on annotation: FriendLocationAnnotation) throws -> CGPoint {
        let view = try XCTUnwrap(annotationStore.view(for: annotation))
        let point = view.convert(CGPoint(x: view.bounds.midX, y: view.bounds.midY), to: mapView)
        observer.onTouchBegan?(point)
        return point
    }

    func tap(_ annotation: FriendLocationAnnotation) throws {
        let touch = try beginTouch(on: annotation)
        observer.onTapEnded?(touch)
    }

    func isSelected(_ annotation: FriendLocationAnnotation) -> Bool {
        annotationStore.selectedAnnotations.contains { ($0 as AnyObject) === annotation }
    }

    func close() {
        coordinator.removeImmediateSocialAnnotationRecognizer(from: mapView)
        coordinator.synchronizeDetailSelection(nil, on: mapView)
        coordinator.friendAnnotations = [:]
        coordinator.synchronizeSocialProximityAnnotations(on: mapView)
        coordinator.onSelectFriend = { _ in }
        mapView.gestures.delegate = nil
        annotationStore.removeAll()
        window.isHidden = true
        window.rootViewController = nil
        previousKeyWindow?.makeKey()
    }
}

@MainActor
private final class MapFixture {
    private let onRequestOwnProfile: (() -> Void)?
    private let onRequestFriendProfile: ((String) -> Void)?
    private let window: UIWindow
    private weak var previousKeyWindow: UIWindow?
    private var sources: [MapSocialClusterMemberID: MapAnnotation] = [:]
    private(set) var hasSettledInitialRegion = false
    private(set) var deselectedMembers: [MapSocialClusterMemberID] = []
    let mapView = makeLocalMap()
    lazy var annotationStore = MapAnnotationStore(mapView: mapView)
    private var subscriptions: Set<AnyCancelable> = []
    var cameraSnapshot: [Double] {
        let camera = mapView.mapboxMap.cameraState
        return [camera.center.latitude, camera.center.longitude, camera.zoom, camera.bearing, camera.pitch]
    }
    var visibleBounds: CGRect?

    lazy var controller = MapSocialProximityController(
        annotationStore: annotationStore,
        presentation: { [weak self] group in
            self?.presentation(for: group) ?? MapSocialClusterPresentation(people: [], outings: [])
        },
        setFocusAppearance: { focused, view in
            view.backgroundColor = focused ? .systemOrange : .systemBlue
        },
        onDeselectMember: { [weak self] memberID in
            self?.deselectedMembers.append(memberID)
        },
        onRequestOwnProfile: onRequestOwnProfile,
        onRequestFriendProfile: onRequestFriendProfile,
        visibleBounds: { [weak self] mapView in
            self?.visibleBounds ?? mapView.bounds.inset(by: mapView.safeAreaInsets)
        }
    )

    init(windowScene: UIWindowScene, onRequestOwnProfile: (() -> Void)? = nil, onRequestFriendProfile: ((String) -> Void)? = nil) {
        self.onRequestOwnProfile = onRequestOwnProfile
        self.onRequestFriendProfile = onRequestFriendProfile
        previousKeyWindow = windowScene.windows.first(where: \.isKeyWindow)
        window = UIWindow(windowScene: windowScene)
        window.frame = windowScene.effectiveGeometry.coordinateSpace.bounds

        let rootViewController = UIViewController()
        rootViewController.view = mapView
        window.rootViewController = rootViewController
        window.windowLevel = UIWindow.Level(rawValue: UIWindow.Level.normal.rawValue + 1)
        annotationStore.makeView = { [weak self] annotation in
            self?.makeView(for: annotation)
        }
        annotationStore.onSelect = { [weak self] view in
            guard let self, let annotation = view.annotation else { return }
            self.controller.activate(annotation, view: view, on: self.mapView)
        }
        annotationStore.onDeselect = { [weak self] view in
            guard let self, let annotation = view.annotation else { return }
            self.controller.didDeselect(annotation, on: self.mapView)
        }
        annotationStore.onDidAdd = { [weak self] _ in
            guard let self else { return }
            self.controller.didAddViews(on: self.mapView)
        }
        mapView.mapboxMap.onMapLoaded.observeNext { [weak self] _ in
            self?.hasSettledInitialRegion = true
        }.store(in: &subscriptions)
        mapView.mapboxMap.onCameraChanged.observe { [weak self] _ in
            guard let self else { return }
            self.controller.visibleRegionDidChange(on: self.mapView)
        }.store(in: &subscriptions)
        mapView.mapboxMap.onMapIdle.observe { [weak self] _ in
            guard let self else { return }
            self.controller.regionDidChange(on: self.mapView)
        }.store(in: &subscriptions)
        window.makeKeyAndVisible()
        window.layoutIfNeeded()
        mapView.mapboxMap.setCamera(to: CameraOptions(center: coordinate(meters: 5), zoom: 15))
    }

    func close() {
        controller.tearDown()
        subscriptions.removeAll()
        annotationStore.removeAll()
        mapView.removeFromSuperview()
        window.isHidden = true
        window.rootViewController = nil
        previousKeyWindow?.makeKey()
    }

    func coordinate(meters: Double) -> CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: 48.8566 + meters / 111_195, longitude: 2.3522)
    }

    func annotation(_ title: String, meters: Double) -> MapAnnotation {
        let annotation = MapAnnotation()
        annotation.coordinate = coordinate(meters: meters)
        annotation.title = title
        return annotation
    }

    func mixedSources() -> [MapSocialClusterMemberID: MapAnnotation] {
        [
            .currentUser: annotation("Vous", meters: 0),
            .friend("amina"): annotation("Amina", meters: 5),
            .outing("walk"): annotation("Balade", meters: 10)
        ]
    }

    func update(_ sources: [MapSocialClusterMemberID: MapAnnotation]) {
        self.sources = sources
        controller.update(sources: sources, on: mapView)
    }

    var socialAnnotations: [MapAnnotation] {
        annotationStore.annotations
    }

    var groups: [MapSocialProximityGroupAnnotation] {
        annotationStore.annotations.compactMap { $0 as? MapSocialProximityGroupAnnotation }
    }

    func groupView(for group: MapSocialProximityGroupAnnotation) -> MapSocialClusterAnnotationView? {
        annotationStore.view(for: group) as? MapSocialClusterAnnotationView
    }

    func memberRows(in view: MapSocialClusterAnnotationView) -> [UIControl] {
        func controls(in parent: UIView) -> [UIControl] {
            parent.subviews.flatMap { child -> [UIControl] in
                if let control = child as? UIControl,
                   control.allControlEvents.contains(.touchUpInside),
                   control.accessibilityLabel != nil {
                    return [control]
                }
                return controls(in: child)
            }
        }
        return controls(in: view).sorted {
            $0.convert($0.bounds, to: view).minY < $1.convert($1.bounds, to: view).minY
        }
    }

    func isSelected(_ annotation: MapAnnotation) -> Bool {
        annotationStore.selectedAnnotations.contains { ($0 as AnyObject) === (annotation as AnyObject) }
    }

    func attachedCount(of annotation: MapAnnotation) -> Int {
        annotationStore.annotations.filter { ($0 as AnyObject) === (annotation as AnyObject) }.count
    }

    // MARK: - Mapbox annotation views

    private func makeView(for annotation: MapAnnotation) -> MapAnnotationView? {
        if let group = annotation as? MapSocialProximityGroupAnnotation {
            let view = MapSocialClusterAnnotationView(
                annotation: group,
                reuseIdentifier: MapSocialClusterAnnotationView.reuseIdentifier
            )
            controller.configure(view, for: group, on: mapView)
            return view
        }
        let view = MapAnnotationView(annotation: annotation)
        view.bounds = CGRect(x: 0, y: 0, width: 36, height: 36)
        view.backgroundColor = .systemBlue
        view.layer.cornerRadius = 18
        view.isAccessibilityElement = true
        view.accessibilityLabel = annotation.title
        return view
    }

    // MARK: - Real group presentation from fixture sources

    private func presentation(for group: MapSocialProximityGroupAnnotation) -> MapSocialClusterPresentation {
        var people: [MapSocialClusterPersonPresentation] = []
        var outings: [MapSocialClusterOutingPresentation] = []
        for annotation in group.memberAnnotations {
            guard let (memberID, source) = sources.first(where: {
                $0.value === (annotation as AnyObject)
            }) else { continue }
            switch memberID {
            case .currentUser:
                people.append(MapSocialClusterPersonPresentation(
                    id: memberID.stableKey,
                    displayName: source.title ?? "Personne",
                    avatarID: ProfileAvatar.cyclopsHorns.rawValue,
                    profileColorHex: "#007AFF",
                    isCurrentUser: true
                ))
            case .friend(let id):
                people.append(MapSocialClusterPersonPresentation(
                    id: id,
                    displayName: source.title ?? "Personne",
                    avatarID: ProfileAvatar.cyclopsHorns.rawValue,
                    profileColorHex: "#007AFF",
                    isCurrentUser: false
                ))
            case .outing(let id):
                outings.append(MapSocialClusterOutingPresentation(
                    id: id,
                    placeName: source.title ?? "Sortie",
                    category: .walk,
                    profileColorHex: "#007AFF",
                    isCurrentUser: false,
                    participantAvatarIDs: []
                ))
            }
        }
        return MapSocialClusterPresentation(people: people, outings: outings)
    }
}

@MainActor
private final class ReuseTrackingAnnotationView: MapAnnotationView {
    private(set) var reuseCount = 0

    override func prepareForReuse() {
        super.prepareForReuse()
        reuseCount += 1
    }
}

/// A local style exercises Mapbox projection and native layout without credentials or tiles.
@MainActor
private func makeLocalMap() -> MapboxMaps.MapView {
    MapboxMaps.MapView(
        frame: .zero,
        mapInitOptions: MapInitOptions(
            cameraOptions: CameraOptions(
                center: CLLocationCoordinate2D(latitude: 48.8566, longitude: 2.3522),
                zoom: 15
            ),
            styleURI: nil,
            styleJSON: ##"{"version":8,"sources":{},"layers":[{"id":"background","type":"background","paint":{"background-color":"#f2f2f2"}}]}"##
        )
    )
}
