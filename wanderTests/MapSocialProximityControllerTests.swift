import MapKit
import UIKit
import UIKit.UIGestureRecognizerSubclass
import XCTest
@testable import wander

/// Exercises the controller through real MapKit annotations, views, and delegate callbacks.
@MainActor
final class MapSocialProximityControllerTests: XCTestCase {
    func testProfileCameraOwnsFriendOpeningFromPinGroupAndOffscreenTarget() async throws {
        var requests: [String] = []
        let fixture = try await makeFixture(onRequestFriendProfile: { requests.append($0) })
        defer { fixture.close() }
        let friend = fixture.annotation("Amina", meters: 0)
        fixture.update([.friend("amina"): friend])
        try await eventually("The friend pin is rendered") { fixture.mapView.view(for: friend) != nil }
        let view = try XCTUnwrap(fixture.mapView.view(for: friend))
        let centers = fixture.mapView.centerRequestCount
        let regions = fixture.mapView.regionRequestCount
        XCTAssertEqual(fixture.controller.activate(friend, view: view, on: fixture.mapView), .friend("amina"))
        XCTAssertEqual(fixture.mapView.centerRequestCount, centers)
        XCTAssertEqual(fixture.mapView.regionRequestCount, regions)

        fixture.controller.collapse(on: fixture.mapView)
        fixture.update(fixture.mixedSources())
        let group = try XCTUnwrap(fixture.groups.first)
        try await eventually("The group is rendered") { fixture.groupView(for: group) != nil }
        fixture.groupView(for: group)?.onSelectMember?(.friend("amina"))
        XCTAssertEqual(requests, ["amina"])
        XCTAssertEqual(fixture.mapView.centerRequestCount, centers)
        XCTAssertEqual(fixture.mapView.regionRequestCount, regions)

        fixture.update([.friend("far"): fixture.annotation("Far away", meters: 50_000)])
        fixture.controller.center(on: .friend("far"), on: fixture.mapView)
        XCTAssertEqual(requests, ["amina", "far"], "Offscreen selection must not wait for a visible pin")
        await flushMainQueue()
        XCTAssertEqual(fixture.mapView.centerRequestCount, centers)
        XCTAssertEqual(fixture.mapView.regionRequestCount, regions)

        fixture.update([.outing("event"): fixture.annotation("Event", meters: 100)])
        fixture.controller.center(on: .outing("event"), on: fixture.mapView)
        XCTAssertEqual(fixture.mapView.regionRequestCount, regions + 1, "Events keep native centering")
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
        fixture.mapView.selectAnnotation(group, animated: false)
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
            let anchor = fixture.mapView.convert(group.coordinate, toPointTo: fixture.mapView)
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
        // setCenter updates projection before MapKit lays out its annotation views.
        try await eventually("MapKit lays out the list at its projected position") {
            view.layoutIfNeeded()
            let anchor = fixture.mapView.convert(group.coordinate, toPointTo: fixture.mapView)
            let expected = view.projectedExpandedFrame(at: anchor).insetBy(dx: 6, dy: 6)
            let actual = scrollView.convert(scrollView.bounds, to: fixture.mapView)
            return abs(actual.minX - expected.minX) <= 1
                && abs(actual.minY - expected.minY) <= 1
                && abs(actual.height - expected.height) <= 1
        }
        let anchor = fixture.mapView.convert(group.coordinate, toPointTo: fixture.mapView)
        let expectedFrame = view.projectedExpandedFrame(at: anchor).insetBy(dx: 6, dy: 6)
        let actualFrame = scrollView.convert(scrollView.bounds, to: fixture.mapView)
        XCTAssertEqual(actualFrame.minX, expectedFrame.minX, accuracy: 1)
        XCTAssertEqual(actualFrame.minY, expectedFrame.minY, accuracy: 1)
        XCTAssertEqual(actualFrame.height, expectedFrame.height, accuracy: 1)

        scrollView.setContentOffset(CGPoint(x: 0, y: 40), animated: false)
        let centerRequests = fixture.mapView.centerRequestCount
        for _ in 0..<5 {
            fixture.controller.viewportDidChange(on: fixture.mapView)
        }
        XCTAssertEqual(fixture.mapView.centerRequestCount, centerRequests)
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

        fixture.mapView.selectAnnotation(group, animated: false)
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
        try await eventually("MapKit selects the extracted member") { fixture.isSelected(friend) }

        XCTAssertTrue(fixture.groups.first === group)
        XCTAssertEqual(fixture.socialAnnotations.count, 2)
        XCTAssertEqual(group.memberAnnotations.count, 2)
        XCTAssertFalse(group.memberAnnotations.contains { ($0 as AnyObject) === friend })
        XCTAssertTrue(fixture.mapView.view(for: friend)?.isAccessibilityElement == true)
        XCTAssertEqual(fixture.attachedCount(of: friend), 1)

        fixture.mapView.deselectAnnotation(friend, animated: false)
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
        try await eventually("The singleton view appears") { fixture.mapView.view(for: friend) != nil }
        let view = try XCTUnwrap(fixture.mapView.view(for: friend))

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

        let centerRequests = fixture.mapView.centerRequestCount
        let revision = fixture.controller.presentationRevision
        fixture.visibleBounds = fixture.mapView.bounds.insetBy(dx: 0, dy: 120)
        fixture.controller.viewportDidChange(on: fixture.mapView)
        XCTAssertEqual(fixture.mapView.centerRequestCount, centerRequests)
        XCTAssertEqual(fixture.controller.presentationRevision, revision)

        XCTAssertTrue(fixture.isSelected(friend))
        XCTAssertEqual(fixture.attachedCount(of: friend), 1)
        XCTAssertEqual(fixture.socialAnnotations.count, 1)
        XCTAssertTrue(fixture.mapView.view(for: friend) === view)
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
            fixture.isSelected(walk) && fixture.mapView.view(for: coffee) != nil
        }
        let coffeeView = try XCTUnwrap(fixture.mapView.view(for: coffee))

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
            fixture.isSelected(friend) && fixture.mapView.view(for: outing) != nil
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
        XCTAssertEqual(fixture.mapView.selectedAnnotations.count, 1)
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
        fixture.mapView.deselectAnnotation(friend, animated: false)
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
            fixture.groupView(for: group) != nil && fixture.mapView.view(for: outing) != nil
        }
        let groupView = try XCTUnwrap(fixture.groupView(for: group))
        let outingView = try XCTUnwrap(fixture.mapView.view(for: outing))
        fixture.mapView.selectAnnotation(group, animated: false)
        try await eventually("The initial group is expanded") { groupView.isExpanded }

        // The old group's callback must not be responsible for closing its view.
        fixture.mapView.deselectAnnotation(group, animated: false)
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
        // MapKit can finish one camera update before reporting the next one.
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
        try await eventually("The friend view appears") { fixture.mapView.view(for: friend) != nil }
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
        fixture.mapView.selectAnnotation(group, animated: false)
        try await eventually("The group expands") { view.isExpanded }

        let replacement = MKPointAnnotation()
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
        XCTAssertEqual(fixture.mapView.view(for: replacement)?.annotation?.title ?? nil, "Amina actualisée")
    }

    func testReplacingFocusedSourcePreservesNativeSelectionAndIgnoresOldCallbacks() async throws {
        let fixture = try await makeFixture()
        defer { fixture.close() }
        var sources = fixture.mixedSources()
        let previousFriend = try XCTUnwrap(sources[.friend("amina")])
        fixture.update(sources)
        fixture.controller.select(.friend("amina"), on: fixture.mapView)
        try await eventually("The original friend is selected") { fixture.isSelected(previousFriend) }
        let previousView = try XCTUnwrap(fixture.mapView.view(for: previousFriend))
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
        fixture.mapView.selectAnnotation(previousGroup, animated: false)
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
        fixture.mapView.selectAnnotation(replacementGroup, animated: false)
        try await eventually("The replacement group expands") { replacementView.isExpanded }

        fixture.controller.didDeselect(previousGroup, on: fixture.mapView)
        await flushMainQueue()

        XCTAssertTrue(replacementView.isExpanded)
        XCTAssertTrue(replacementView.accessibilityTraits.contains(.selected))
        XCTAssertTrue(fixture.isSelected(replacementGroup))
        XCTAssertEqual(fixture.socialAnnotations.count, 1)

        fixture.mapView.deselectAnnotation(replacementGroup, animated: false)
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
        try await eventually("The singleton view appears") { fixture.mapView.view(for: friend) != nil }

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
        try await eventually("The singleton view appears") { fixture.mapView.view(for: friend) != nil }

        fixture.controller.select(.friend("amina"), on: fixture.mapView)
        fixture.controller.collapse(on: fixture.mapView)
        await flushMainQueue()

        XCTAssertFalse(fixture.isSelected(friend))
        XCTAssertFalse(fixture.controller.isFocused(friend))
        XCTAssertEqual(fixture.attachedCount(of: friend), 1)
        XCTAssertEqual(fixture.socialAnnotations.count, 1)
    }

    // MARK: - Passive touch observer callbacks

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
        let events: [(id: MapSocialClusterMemberID, annotation: MKPointAnnotation)] = [
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
        fixture.mapView.selectAnnotation(group, animated: false)
        try await eventually("The coincident event list opens") { groupView.isExpanded }
        groupView.layoutIfNeeded()

        let rows = fixture.memberRows(in: groupView)
        XCTAssertEqual(rows.map(\.accessibilityLabel), ["Balade", "Café"])
        let row = try XCTUnwrap(rows.indices.contains(rowIndex) ? rows[rowIndex] : nil)
        let center = row.convert(CGPoint(x: row.bounds.midX, y: row.bounds.midY), to: groupView)
        XCTAssertTrue(groupView.hitTest(center, with: nil) === row)

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
        // This does not synthesize a finger gesture or MapKit's competing gesture callbacks.
        row.sendActions(for: .touchUpInside)
        try await eventually("The chosen row selects its own event") {
            fixture.isSelected(selected.annotation) && fixture.controller.isFocused(selected.annotation)
        }

        XCTAssertFalse(fixture.controller.isFocused(remaining.annotation))
        XCTAssertFalse(fixture.isSelected(remaining.annotation))
        XCTAssertEqual(fixture.mapView.selectedAnnotations.count, 1)
        XCTAssertTrue(fixture.groups.isEmpty)
        XCTAssertEqual(fixture.attachedCount(of: group), 0)
        XCTAssertEqual(fixture.attachedCount(of: selected.annotation), 1)
        XCTAssertEqual(fixture.attachedCount(of: remaining.annotation), 1)
        XCTAssertEqual(fixture.socialAnnotations.count, 2)
        XCTAssertTrue(fixture.deselectedMembers.isEmpty)

        fixture.update([remaining.id: remaining.annotation])
        try await eventually("Removing the chosen event leaves one unselected singleton") {
            fixture.socialAnnotations.count == 1 && fixture.mapView.selectedAnnotations.isEmpty
        }
        // Repeated source snapshots must not dismiss the product presentation a second time.
        fixture.update([remaining.id: remaining.annotation])
        await flushMainQueue()

        XCTAssertFalse(fixture.controller.isFocused(selected.annotation))
        XCTAssertFalse(fixture.controller.isFocused(remaining.annotation))
        XCTAssertFalse(fixture.controller.hasActivePresentation)
        XCTAssertTrue(fixture.mapView.selectedAnnotations.isEmpty)
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

    private func makeFixture(onRequestFriendProfile: ((String) -> Void)? = nil) async throws -> MapFixture {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let scene = try XCTUnwrap(scenes.first { $0.activationState == .foregroundActive } ?? scenes.first)
        let fixture = MapFixture(windowScene: scene, onRequestFriendProfile: onRequestFriendProfile)
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

@MainActor
private final class MapFixture: NSObject, MKMapViewDelegate {
    private let onRequestFriendProfile: ((String) -> Void)?
    private let window: UIWindow
    private weak var previousKeyWindow: UIWindow?
    private var sources: [MapSocialClusterMemberID: MKPointAnnotation] = [:]
    private(set) var hasSettledInitialRegion = false
    private(set) var deselectedMembers: [MapSocialClusterMemberID] = []
    let mapView = CenterTrackingMapView(frame: .zero)
    var visibleBounds: CGRect?

    lazy var controller = MapSocialProximityController(
        presentation: { [weak self] group in
            self?.presentation(for: group) ?? MapSocialClusterPresentation(people: [], outings: [])
        },
        setFocusAppearance: { focused, view in
            (view as? MKMarkerAnnotationView)?.markerTintColor = focused ? .systemOrange : .systemBlue
        },
        onDeselectMember: { [weak self] memberID in
            self?.deselectedMembers.append(memberID)
        },
        onRequestFriendProfile: onRequestFriendProfile,
        visibleBounds: { [weak self] mapView in
            self?.visibleBounds ?? mapView.bounds.inset(by: mapView.safeAreaInsets)
        }
    )

    init(windowScene: UIWindowScene, onRequestFriendProfile: ((String) -> Void)? = nil) {
        self.onRequestFriendProfile = onRequestFriendProfile
        previousKeyWindow = windowScene.windows.first(where: \.isKeyWindow)
        window = UIWindow(windowScene: windowScene)
        window.frame = windowScene.effectiveGeometry.coordinateSpace.bounds
        super.init()

        let rootViewController = UIViewController()
        rootViewController.view = mapView
        window.rootViewController = rootViewController
        window.windowLevel = UIWindow.Level(rawValue: UIWindow.Level.normal.rawValue + 1)
        mapView.delegate = self
        window.makeKeyAndVisible()
        window.layoutIfNeeded()
        mapView.setRegion(
            MKCoordinateRegion(center: coordinate(meters: 5), latitudinalMeters: 1_000, longitudinalMeters: 1_000),
            animated: false
        )
    }

    func close() {
        controller.tearDown()
        mapView.delegate = nil
        mapView.removeAnnotations(mapView.annotations)
        mapView.removeFromSuperview()
        window.isHidden = true
        window.rootViewController = nil
        previousKeyWindow?.makeKey()
    }

    func coordinate(meters: Double) -> CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: 48.8566 + meters / 111_195, longitude: 2.3522)
    }

    func annotation(_ title: String, meters: Double) -> MKPointAnnotation {
        let annotation = MKPointAnnotation()
        annotation.coordinate = coordinate(meters: meters)
        annotation.title = title
        return annotation
    }

    func mixedSources() -> [MapSocialClusterMemberID: MKPointAnnotation] {
        [
            .currentUser: annotation("Vous", meters: 0),
            .friend("amina"): annotation("Amina", meters: 5),
            .outing("walk"): annotation("Balade", meters: 10)
        ]
    }

    func update(_ sources: [MapSocialClusterMemberID: MKPointAnnotation]) {
        self.sources = sources
        controller.update(sources: sources.mapValues { $0 as any MKAnnotation }, on: mapView)
    }

    var socialAnnotations: [any MKAnnotation] {
        mapView.annotations.filter { $0 is MKPointAnnotation || $0 is MapSocialProximityGroupAnnotation }
    }

    var groups: [MapSocialProximityGroupAnnotation] {
        mapView.annotations.compactMap { $0 as? MapSocialProximityGroupAnnotation }
    }

    func groupView(for group: MapSocialProximityGroupAnnotation) -> MapSocialClusterAnnotationView? {
        mapView.view(for: group) as? MapSocialClusterAnnotationView
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

    func isSelected(_ annotation: any MKAnnotation) -> Bool {
        mapView.selectedAnnotations.contains { ($0 as AnyObject) === (annotation as AnyObject) }
    }

    func attachedCount(of annotation: any MKAnnotation) -> Int {
        mapView.annotations.filter { ($0 as AnyObject) === (annotation as AnyObject) }.count
    }

    // MARK: - Native delegate forwarding

    func mapView(_ mapView: MKMapView, viewFor annotation: any MKAnnotation) -> MKAnnotationView? {
        if let group = annotation as? MapSocialProximityGroupAnnotation {
            let view = (mapView.dequeueReusableAnnotationView(
                withIdentifier: MapSocialClusterAnnotationView.reuseIdentifier
            ) as? MapSocialClusterAnnotationView) ?? MapSocialClusterAnnotationView(
                annotation: group,
                reuseIdentifier: MapSocialClusterAnnotationView.reuseIdentifier
            )
            view.annotation = group
            controller.configure(view, for: group, on: mapView)
            return view
        }
        guard annotation is MKPointAnnotation else { return nil }
        let view = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: nil)
        view.displayPriority = .required
        view.clusteringIdentifier = nil
        view.isAccessibilityElement = true
        view.accessibilityLabel = annotation.title ?? nil
        return view
    }

    func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
        guard let annotation = view.annotation else { return }
        controller.activate(annotation, view: view, on: mapView)
    }

    func mapView(_ mapView: MKMapView, didDeselect view: MKAnnotationView) {
        guard let annotation = view.annotation else { return }
        controller.didDeselect(annotation, on: mapView)
    }

    func mapView(_ mapView: MKMapView, didAdd views: [MKAnnotationView]) {
        controller.didAddViews(on: mapView)
    }

    func mapViewDidChangeVisibleRegion(_ mapView: MKMapView) {
        controller.visibleRegionDidChange(on: mapView)
    }

    func mapView(_ mapView: MKMapView, regionWillChangeAnimated animated: Bool) {
        controller.regionWillChange(on: mapView)
    }

    func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        controller.regionDidChange(on: mapView)
        hasSettledInitialRegion = true
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
private final class CenterTrackingMapView: MKMapView {
    private(set) var centerRequestCount = 0
    private(set) var regionRequestCount = 0

    override func setRegion(_ region: MKCoordinateRegion, animated: Bool) {
        regionRequestCount += 1
        super.setRegion(region, animated: animated)
    }

    override func setCenter(_ coordinate: CLLocationCoordinate2D, animated: Bool) {
        centerRequestCount += 1
        super.setCenter(coordinate, animated: animated)
    }
}
