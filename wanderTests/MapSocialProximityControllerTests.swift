import MapKit
import UIKit
import XCTest
@testable import wander

/// Exercises the controller through real MapKit annotations, views, and delegate callbacks.
@MainActor
final class MapSocialProximityControllerTests: XCTestCase {
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

        XCTAssertTrue(fixture.isSelected(friend))
        XCTAssertEqual(fixture.attachedCount(of: friend), 1)
        XCTAssertEqual(fixture.socialAnnotations.count, 1)
        XCTAssertTrue(fixture.mapView.view(for: friend) === view)
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
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async { continuation.resume() }
        }

        XCTAssertFalse(fixture.isSelected(friend))
        XCTAssertFalse(fixture.controller.isFocused(friend))
    }

    // MARK: - Bounded native view waits

    private func makeFixture() async throws -> MapFixture {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let scene = try XCTUnwrap(scenes.first { $0.activationState == .foregroundActive } ?? scenes.first)
        let fixture = MapFixture(windowScene: scene)
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

@MainActor
private final class MapFixture: NSObject, MKMapViewDelegate {
    private let window: UIWindow
    private weak var previousKeyWindow: UIWindow?
    private var sources: [MapSocialClusterMemberID: MKPointAnnotation] = [:]
    private(set) var hasSettledInitialRegion = false
    let mapView = MKMapView(frame: .zero)

    lazy var controller = MapSocialProximityController(
        presentation: { [weak self] group in
            self?.presentation(for: group) ?? MapSocialClusterPresentation(people: [], outings: [])
        },
        setFocusAppearance: { focused, view in
            (view as? MKMarkerAnnotationView)?.markerTintColor = focused ? .systemOrange : .systemBlue
        }
    )

    init(windowScene: UIWindowScene) {
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
