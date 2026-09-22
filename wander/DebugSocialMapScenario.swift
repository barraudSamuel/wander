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
    @State private var eventsExpanded = false
    @State private var selectedDetail = DebugSocialMapScene.initialSelection

    var body: some View {
        if ProcessInfo.processInfo.arguments.contains("-debug-social-map-fullscreen") {
            MotionDockView(
                selection: $dockSelection,
                isEventsPresented: areEventsPresented,
                onToggleEvents: toggleEvents
            ) {
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
                            MapImageButton(
                                assetName: "TabIconEvents", label: "Événements",
                                isSelected: areEventsPresented, action: toggleEvents
                            )
                            .accessibilityIdentifier("motion-dock-events")
                            Button("Réinitialiser") { revision += 1 }
                        }
                    }
                    .padding()
                    .background(.regularMaterial)
                }
        }
    }

    private var areEventsPresented: Bool {
        eventsExpanded && dockSelection == .explore && selectedDetail?.profile == nil
    }

    private func toggleEvents() {
        let shouldPresent = !areEventsPresented
        dockSelection = .explore
        if selectedDetail?.profile != nil { selectedDetail = nil }
        eventsExpanded = shouldPresent
    }

    private func resetPresentation() {
        eventsExpanded = false
        selectedDetail = nil
    }

    private var mapScene: some View {
        DebugSocialMapScene(
            kind: scene,
            isListActive: dockSelection == .explore,
            eventsExpanded: $eventsExpanded,
            selectedDetail: $selectedDetail
        )
        .id("\(scene.rawValue)-\(revision)")
        .onChange(of: scene) { _, _ in resetPresentation() }
        .onChange(of: revision) { _, _ in resetPresentation() }
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
    @Binding private var selectedDetail: MapDetailSelection?
    @Binding private var eventsExpanded: Bool
    @State private var editingEvent: OutingPlan?
    @State private var centerOnUser = false
    @State private var resetOrientation = false
    @State private var centerOnFriend: String?
    @State private var centerOnEvent: String?
    @State private var responses: [String: OutingAttendanceParticipationState] = [:]
    @State private var showsDirections = false
    @State private var opensDirectionsAfterDismiss = false
    @State private var presentedProfile: MapProfileSelection?
    @State private var shouldFocusOwnProfile = true
    @State private var friendCameraRequest: MapFriendCameraRequest?
    @State private var profileName = "Moi"
    @State private var avatarID = ProfileAvatar.cyclopsHorns.rawValue
    @State private var heatMapEnabled = false
    @State private var ghostModeEnabled = false
    @State private var profileConfirmation = false

    private static func hasArgument(_ argument: String) -> Bool {
        arguments.contains("-debug-social-map-" + argument)
    }

    init(
        kind: DebugSocialMapScenarioView.SceneKind,
        isListActive: Bool,
        eventsExpanded: Binding<Bool>,
        selectedDetail: Binding<MapDetailSelection?>
    ) {
        self.isListActive = isListActive
        self._eventsExpanded = eventsExpanded
        self._selectedDetail = selectedDetail
        self.friends = Self.makeFriends(kind: kind)
        let coordinate = Self.coordinate
        _locationTracker = StateObject(wrappedValue: LocationTracker(
            scenarioLocation: CLLocation(
                latitude: coordinate.latitude + (kind == .events ? 0.0015 : 0),
                longitude: coordinate.longitude
            )
        ))
        _plans = State(initialValue: Dictionary(uniqueKeysWithValues: Self.makePlans(kind: kind).map { ($0.id, $0) }))
    }

    private static func makePlans(kind: DebugSocialMapScenarioView.SceneKind) -> [OutingPlan] {
        guard kind != .people, !hasArgument("empty-list") else { return [] }
        let count = hasArgument("many-events") ? 18
            : hasArgument("social-list") || hasArgument("participants-list") ? 4 : 2
        return (1...count).map { number in
            plan(number: number, category: number.isMultiple(of: 2) ? .coffee : .meal)
        }
    }

    static var initialSelection: MapDetailSelection? {
        if hasArgument("open-event"), let event = makePlans(kind: .events).last {
            return .outing(event.id)
        }
        if hasArgument("open-friend") { return .friend("scenario-amina") }
        return nil
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
                receivedAt: referenceDate, spotEnteredAt: referenceDate.addingTimeInterval(-1800)
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
        MapDetailSplitView(
            isPresented: false,
            isEventsExpanded: $eventsExpanded,
            areEventsObscured: selectedDetail?.profile != nil
        ) {
            EmptyView()
        } events: {
            MapEventsPanelView(
                outings: Self.hasArgument("list-loading") || Self.hasArgument("list-error") ? [:] : presentations,
                selectedEventID: selectedDetail?.outingEventID,
                currentLocation: listLocation,
                isLoading: Self.hasArgument("list-loading"),
                hasLoadError: Self.hasArgument("list-error") || Self.hasArgument("partial-list-error"),
                isListActive: isListActive && eventsExpanded && selectedDetail?.profile == nil,
                onVisibleEventIDsChange: { ids in
                    if !isListActive && ids.isEmpty { didSuspendRosters = true }
                    requestedRosterIDs = ids
                },
                onSetAttendance: { id, shouldAttend in
                    responses[id] = shouldAttend ? .attending : .declined
                },
                onEdit: { id in editingEvent = plans[id] },
                onOpenDirections: { _ in showsDirections = true },
                onSelect: { id in
                    selectedDetail = .outing(id)
                    centerOnEvent = id
                }
            )
        } map: {
            mapView(presentations: presentations)
        }
        .sheet(item: mapProfileSelection, onDismiss: mapProfileDidDismiss) { selection in
            Group {
                switch selection {
                case .currentUser:
                    OwnProfileSheet(
                        displayName: profileName, avatarID: avatarID,
                        profileColorHex: "#3478F6", locationTracker: locationTracker,
                        cityProgress: nil, isGhostModeEnabled: ghostModeEnabled,
                        onPreparePresentation: { sheetTop in
                            guard selectedDetail?.profile == selection,
                                  shouldFocusOwnProfile else { return }
                            friendCameraRequest = MapFriendCameraRequest(
                                target: selection, sheetTopInWindow: sheetTop
                            )
                        }
                    ) { summary in
                        Form {
                            Section {
                                summary
                                    .listRowInsets(EdgeInsets())
                                    .listRowBackground(Color.clear)
                            }
                            Section("Affichage de la carte") {
                                Toggle("Carte de fréquentation", isOn: $heatMapEnabled)
                                    .accessibilityIdentifier("profile-heat-map")
                            }
                            Section("Avatar") {
                                ProfileAvatarPicker(selection: $avatarID)
                            }
                            Section("Identité") {
                                TextField("Pseudo", text: $profileName)
                                    .submitLabel(.done)
                            }
                            Section("Visibilité auprès de mes amis") {
                                Toggle("Mode fantôme", isOn: $ghostModeEnabled)
                            }
                            Section("Compte") {
                                Button("Confirmation de test") { profileConfirmation = true }
                            }
                        }
                        .contentMargins(.top, 0, for: .scrollContent)
                        .scrollDismissesKeyboard(.interactively)
                        .accessibilityIdentifier("own-profile-scroll")
                        .alert("Action de test", isPresented: $profileConfirmation) {
                            Button("Annuler", role: .cancel) {}
                        }
                    }
                case .friend(let id):
                    if let friend = friends[id] {
                        FriendProfileContentView(
                            displayName: friend.displayName,
                            avatarID: friend.avatarID,
                            profileColorHex: friend.profileColorHex,
                            isGhostModeEnabled: Self.hasArgument("ghost"),
                            location: Self.hasArgument("missing-location") ? nil : friend,
                            isLocationFresh: !Self.hasArgument("stale"),
                            onOpenDirections: {
                                opensDirectionsAfterDismiss = true
                                selectedDetail = nil
                            },
                            onPreparePresentation: { sheetTop in
                                guard selectedDetail?.profile == selection,
                                      !Self.hasArgument("ghost"),
                                      !Self.hasArgument("missing-location") else { return }
                                friendCameraRequest = MapFriendCameraRequest(
                                    target: selection, sheetTopInWindow: sheetTop
                                )
                            }
                        )
                    }
                }
            }
            .interactiveDismissDisabled(profileConfirmation)
            .onAppear { presentedProfile = selection }
            .id(selection.id)
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

    private func presentOwnProfile(focusOnMap: Bool) {
        // MapKit can echo a programmatic pin selection after the sheet opens.
        guard selectedDetail != .ownProfile else { return }
        shouldFocusOwnProfile = focusOnMap
        if !focusOnMap { friendCameraRequest = nil }
        selectedDetail = .ownProfile
    }

    private func mapProfileDidDismiss() {
        guard selectedDetail?.profile == nil else { return }
        let dismissedProfile = presentedProfile
        presentedProfile = nil
        if let dismissedProfile, selectedDetail == nil, isListActive, editingEvent == nil {
            let canRecenter: Bool
            switch dismissedProfile {
            case .currentUser: canRecenter = shouldFocusOwnProfile && locationTracker.lastLocation != nil
            case .friend: canRecenter = !Self.hasArgument("ghost") && !Self.hasArgument("missing-location")
            }
            if canRecenter { friendCameraRequest = MapFriendCameraRequest(target: dismissedProfile) }
        }
        guard opensDirectionsAfterDismiss else { return }
        opensDirectionsAfterDismiss = false
        showsDirections = true
    }

    private var mapProfileSelection: Binding<MapProfileSelection?> {
        Binding(
            get: { selectedDetail?.profile },
            set: { profile in
                if let profile {
                    selectedDetail = profile.detailSelection
                } else if selectedDetail?.profile != nil {
                    selectedDetail = nil
                }
            }
        )
    }

    private func mapView(presentations: [String: MapOutingPlan]) -> some View {
        MapWithFogView(
            locationTracker: locationTracker,
            discoveredCellIDs: [], cityBoundaryCoordinates: [],
            friendLocations: friends, freshFriendLocationUserIDs: Set(friends.keys),
            outingPlans: presentations,
            userDisplayName: profileName, userAvatarID: avatarID,
            userProfileColorHex: "#3478F6",
            centerOnUser: $centerOnUser, resetMapOrientation: $resetOrientation,
            centerOnFriendUserID: $centerOnFriend, centerOnOutingPlanEventID: $centerOnEvent,
            isEventCreationEnabled: editingEvent == nil,
            selectedOutingPlanEventID: selectedDetail?.outingEventID,
            selectedMapProfile: selectedDetail?.profile,
            friendCameraRequest: friendCameraRequest,
            showsSystemUserLocation: false,
            showsHeatMap: heatMapEnabled,
            onSelectOwnProfile: { presentOwnProfile(focusOnMap: true) },
            onSelectFriend: { selectedDetail = .friend($0) },
            onSelectOutingPlan: { selectedDetail = .outing($0) }
        )
        .overlay(alignment: .topTrailing) {
            MapImageButton(assetName: "TabIconProfile", label: "Mon profil") {
                presentOwnProfile(focusOnMap: false)
            }
            .accessibilityIdentifier("map-own-profile")
            .padding(.top, 8)
            .padding(.trailing, 16)
            .modifier(MapContentSafeArea(edges: [.top, .trailing]))
        }
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
