#if DEBUG && targetEnvironment(simulator)
import CoreLocation
import SwiftUI

enum DebugSocialMapScenario {
    static let isEnabled = ProcessInfo.processInfo.arguments.contains("-debug-social-map")
}

/// Uses production map, detail and composer views. Only the data source is local.
struct DebugSocialMapScenarioView: View {
    enum SceneKind: String, CaseIterable, Identifiable {
        case events = "Événements"
        case mixed = "Mixte"
        case people = "Utilisateurs"
        var id: String { rawValue }
    }

    @State private var scene: SceneKind = ProcessInfo.processInfo.arguments
        .contains("-debug-social-map-mixed") ? .mixed : .events
    @State private var revision = 0
    @State private var dockSelection: MotionDockSelection = ProcessInfo.processInfo.arguments
        .contains("-debug-dock-friends") ? .friends : .explore
    @State private var friendCode = ""
    @State private var profileName = "Explorateur"
    @State private var profileConfirmation = false

    var body: some View {
        if ProcessInfo.processInfo.arguments.contains("-debug-social-map-fullscreen") {
            MotionDockView(selection: $dockSelection) {
                mapScene
            } friends: {
                NavigationStack {
                    List {
                        Section("Ajouter un ami") {
                            TextField("Code ami", text: $friendCode)
                                .autocorrectionDisabled()
                        }
                        Section("Mes amis") {
                            ForEach(1...30, id: \.self) { number in
                                Text("Ami \(number)")
                            }
                        }
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .toolbar(.hidden, for: .navigationBar)
                }
            } profile: {
                NavigationStack {
                    Form {
                        TextField("Pseudo", text: $profileName)
                        Button("Confirmation de test") { profileConfirmation = true }
                        ForEach(1...30, id: \.self) { number in
                            Text("Réglage \(number)")
                        }
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .toolbar(.hidden, for: .navigationBar)
                    .alert("Action de test", isPresented: $profileConfirmation) {
                        Button("Annuler", role: .cancel) {}
                    }
                }
            }
        } else {
            mapScene
                .safeAreaInset(edge: .bottom) {
                    VStack(spacing: 8) {
                        Picker("Scénario", selection: $scene) {
                            ForEach(SceneKind.allCases) { kind in
                                Text(kind.rawValue).tag(kind)
                            }
                        }
                        .pickerStyle(.segmented)
                        HStack {
                            Text("Scénario carte sociale")
                                .font(.caption)
                            Spacer()
                            Button("Réinitialiser") { revision += 1 }
                        }
                    }
                    .padding()
                    .background(.regularMaterial)
                }
        }
    }

    private var mapScene: some View {
        DebugSocialMapScene(kind: scene, isListActive: dockSelection == .explore)
            .id("\(scene.rawValue)-\(revision)")
    }
}

private struct DebugSocialMapScene: View {
    private static let coordinate = CLLocationCoordinate2D(latitude: 37.5665, longitude: 126.9780)
    private static let ownerID = "scenario-owner"
    private static let arguments = Set(ProcessInfo.processInfo.arguments)

    private let friends: [String: FriendLocation]
    private let isListActive: Bool
    @State private var requestedRosterIDs: Set<String> = []
    @State private var didSuspendRosters = false
    @StateObject private var locationTracker: LocationTracker
    @State private var plans: [String: OutingPlan]
    @State private var selectedDetail: MapDetailSelection?
    @State private var editingEvent: OutingPlan?
    @State private var centerOnUser = false
    @State private var resetOrientation = false
    @State private var centerOnFriend: String?
    @State private var centerOnEvent: String?
    @State private var responses: [String: OutingAttendanceParticipationState] = [:]
    @State private var showsDirections = false

    private static func hasArgument(_ argument: String) -> Bool {
        arguments.contains("-debug-social-map-" + argument)
    }

    init(kind: DebugSocialMapScenarioView.SceneKind, isListActive: Bool) {
        self.isListActive = isListActive
        self.friends = Self.makeFriends(kind: kind)
        let coordinate = Self.coordinate
        _locationTracker = StateObject(wrappedValue: LocationTracker(
            scenarioLocation: CLLocation(
                latitude: coordinate.latitude + (kind == .events ? 0.0015 : 0),
                longitude: coordinate.longitude
            )
        ))
        let events: [OutingPlan] = kind == .people || Self.hasArgument("empty-list") ? [] :
            (1...(Self.hasArgument("many-events") ? 18 : Self.hasArgument("social-list") || Self.hasArgument("participants-list") ? 4 : 2)).map {
                Self.plan(number: $0, category: $0 % 2 == 0 ? .coffee : .meal)
            }
        _plans = State(initialValue: Dictionary(uniqueKeysWithValues: events.map { ($0.id, $0) }))
        if Self.hasArgument("open-event"), let event = events.last {
            _selectedDetail = State(initialValue: .outing(event.id))
        } else if Self.hasArgument("open-friend") {
            _selectedDetail = State(initialValue: .friend("scenario-amina"))
        }
    }

    private static func makeFriends(kind: DebugSocialMapScenarioView.SceneKind) -> [String: FriendLocation] {
        guard kind != .events else { return [:] }
        let referenceDate = Date()
        return Dictionary(uniqueKeysWithValues: ["Amina", "Jules"].map { name in
            let id = "scenario-\(name.lowercased())"
            return (id, FriendLocation(
                userID: id, displayName: name, avatarID: ProfileAvatar.cyclopsHorns.rawValue,
                profileColorHex: "#3478F6", coordinate: Self.coordinate,
                horizontalAccuracy: 5, sampledAt: Self.hasArgument("stale") ? referenceDate.addingTimeInterval(-7200) : referenceDate, updatedAt: referenceDate,
                receivedAt: referenceDate, spotEnteredAt: nil
            ))
        })
    }

    private var presentations: [String: MapOutingPlan] {
        plans.mapValues { plan in
            let isGuest = Self.hasArgument("guest") || (Self.hasArgument("social-list") && !plan.id.hasSuffix("3"))
            let initialResponse: OutingAttendanceParticipationState = Self.hasArgument("social-list") && plan.id.hasSuffix("2")
                ? .attending : Self.hasArgument("social-list") && plan.id.hasSuffix("4") ? .declined
                : isGuest ? .notResponded : .attending
            let response = responses[plan.id] ?? initialResponse
            let state: OutingAttendanceParticipationState = Self.hasArgument("loading")
                ? .loading : Self.hasArgument("unavailable") ? .unavailable : response
            let roster: OutingAttendanceRosterState = Self.hasArgument("loading")
                ? .loading : Self.hasArgument("unavailable") ? .unavailable : .available
            let participantCounts = ["1": 0, "2": 1, "3": 3, "4": 5]
            let count = Self.hasArgument("participants-list") ? participantCounts[String(plan.id.suffix(1)), default: 0]
                : Self.hasArgument("stress") ? 9 : isGuest ? 2 : 0
            var attendees = (0..<count).map { index in
                MapOutingAttendee(
                    userID: "scenario-attendee-\(index)", displayName: "Invité \(index + 1)",
                    avatarID: ProfileAvatar.allCases[index % ProfileAvatar.allCases.count].rawValue
                )
            }
            let me = MapOutingAttendee(userID: "scenario-me", displayName: "Vous", avatarID: ProfileAvatar.skull.rawValue)
            if isGuest, response == .attending { attendees.append(me) }
            return MapOutingPlan(
                plan: plan,
                organizer: MapOutingAttendee(
                    userID: Self.ownerID,
                    displayName: isGuest ? "Théo" : "Moi",
                    avatarID: ProfileAvatar.cyclopsHorns.rawValue
                ),
                profileColorHex: "#3478F6", isCurrentUser: !isGuest,
                rosterState: roster, participationState: state,
                attendees: attendees, declines: isGuest && response == .declined ? [me] : [],
                isAttendanceUpdating: Self.hasArgument("updating")
            )
        }
    }

    var body: some View {
        let presentations = presentations
        MapDetailSplitView(isPresented: true) {
            MapEventsPanelView(
                outings: Self.hasArgument("list-loading") || Self.hasArgument("list-error") ? [:] : presentations,
                showsDetail: selectedDetail != nil,
                currentLocation: listLocation,
                isLoading: Self.hasArgument("list-loading"),
                hasLoadError: Self.hasArgument("list-error") || Self.hasArgument("partial-list-error"),
                isListActive: isListActive,
                onVisibleEventIDsChange: { ids in
                    if !isListActive && ids.isEmpty { didSuspendRosters = true }
                    requestedRosterIDs = ids
                },
                onSetAttendance: { id, shouldAttend in
                    responses[id] = shouldAttend ? .attending : .declined
                },
                onEdit: { id in editingEvent = plans[id] },
                onSelect: { id in
                    selectedDetail = .outing(id)
                    centerOnEvent = id
                }
            ) {
                if let id = selectedDetail?.outingEventID, let outing = presentations[id] {
                    OutingPlanDetailCardView(
                        outing: outing,
                        onDismiss: { selectedDetail = nil },
                        onEdit: { editingEvent = outing.plan },
                        onOpenDirections: { showsDirections = true },
                        onSetAttendance: { responses[id] = $0 ? .attending : .declined }
                    )
                    .id(id)
                } else if let id = selectedDetail?.friendUserID, let friend = friends[id] {
                    FriendProfileContentView(
                        displayName: friend.displayName,
                        avatarID: friend.avatarID,
                        profileColorHex: friend.profileColorHex,
                        isGhostModeEnabled: Self.hasArgument("ghost"),
                        location: Self.hasArgument("missing-location") ? nil : friend,
                        isLocationFresh: !Self.hasArgument("stale"),
                        onDismiss: { selectedDetail = nil },
                        onOpenDirections: { showsDirections = true }
                    )
                    .id(id)
                }
            }
        } map: {
            if ProcessInfo.processInfo.arguments.contains("-debug-social-map-fullscreen") {
                FriendEdgeRailView(friends: [], onSelect: { _ in }) {
                    mapView(presentations: presentations)
                }
            } else {
                mapView(presentations: presentations)
            }
        }
        .alert("Itinéraire de test", isPresented: $showsDirections) {
            Button("Fermer", role: .cancel) {}
        } message: {
            Text("L’action de la fiche a été reçue par le scénario local.")
        }
        .sheet(item: $editingEvent) { event in
            OutingPlanComposerView(
                displayName: "Moi", initialCoordinate: nil, editingEvent: event,
                operations: OutingPlanComposerOperations(
                    fetchEvent: { plans[$0] },
                    publish: { draft, existing in
                        guard let existing else { throw OutingPlanValidationError.invalidEventID }
                        let updated = OutingPlan(
                            eventID: existing.eventID, eventIDValue: existing.eventIDValue,
                            ownerID: existing.ownerID, publicationID: existing.publicationID,
                            publicationIDValue: existing.publicationIDValue,
                            displayName: draft.displayName, placeName: draft.placeName,
                            address: draft.address, category: draft.category,
                            coordinate: draft.coordinate, plannedAt: draft.plannedAt,
                            publishedAt: existing.publishedAt, updatedAt: Date(),
                            timeZoneIdentifier: draft.timeZoneIdentifier
                        )
                        plans[updated.id] = updated
                        return updated
                    },
                    cancel: { id in
                        plans.removeValue(forKey: id)
                        if selectedDetail == .outing(id) { selectedDetail = nil }
                    }
                ),
                showsNotificationSettings: false
            )
        }
    }

    private func mapView(presentations: [String: MapOutingPlan]) -> some View {
        MapWithFogView(
            locationTracker: locationTracker,
            discoveredCellIDs: [], cityBoundaryCoordinates: [],
            friendLocations: friends, freshFriendLocationUserIDs: Set(friends.keys),
            outingPlans: presentations,
            userDisplayName: "Moi", userAvatarID: ProfileAvatar.cyclopsHorns.rawValue,
            userProfileColorHex: "#3478F6",
            centerOnUser: $centerOnUser, resetMapOrientation: $resetOrientation,
            centerOnFriendUserID: $centerOnFriend, centerOnOutingPlanEventID: $centerOnEvent,
            isEventCreationEnabled: editingEvent == nil,
            selectedOutingPlanEventID: selectedDetail?.outingEventID,
            selectedFriendProfileUserID: selectedDetail?.friendUserID,
            showsSystemUserLocation: false,
            onSelectFriend: { selectedDetail = .friend($0) },
            onSelectOutingPlan: { selectedDetail = .outing($0) }
        )
        .overlay(alignment: .topLeading) {
            if Self.hasArgument("roster-probe") {
                Text("Groupes : \(requestedRosterIDs.count)")
                    .font(.caption)
                    .accessibilityIdentifier("debug-list-rosters")
                    .accessibilityValue(requestedRosterIDs.sorted().joined(separator: ",") + ";suspended=\(didSuspendRosters)")
            }
        }
    }

    private var listLocation: CLLocation? {
        guard !Self.hasArgument("list-no-location") else { return nil }
        return CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: Self.coordinate.latitude + 0.0015, longitude: Self.coordinate.longitude),
            altitude: 0, horizontalAccuracy: 10, verticalAccuracy: -1,
            timestamp: Self.hasArgument("list-stale-location") ? Date().addingTimeInterval(-600) : Date()
        )
    }

    private static func plan(number: Int, category: OutingCategory) -> OutingPlan {
        let id = UUID(uuidString: String(format: "00000000-0000-4000-8000-%012d", number))!
        let date = Date()
        return OutingPlan(
            eventID: id, eventIDValue: id.uuidString.lowercased(), ownerID: ownerID,
            publicationID: id, publicationIDValue: id.uuidString.lowercased(),
            displayName: "Moi",
            placeName: hasArgument("social-list") ? ["Bistrot du parc", "Café des amis", "Chez vous", "Café de la place"][number - 1]
                : hasArgument("many-events") ? "Sortie \(number)" : hasArgument("stress") ? "Café du parc et des promenades au bord de la rivière" : category.title,
            address: "Lieu de test",
            category: category, coordinate: coordinate,
            plannedAt: date.addingTimeInterval(Double(number) * 3600),
            publishedAt: date, updatedAt: date, timeZoneIdentifier: "Asia/Seoul"
        )
    }
}
#endif
