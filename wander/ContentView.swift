//
//  ContentView.swift
//  wander
//
//  Map-first experience with native Apple navigation and controls.
//

import AuthenticationServices
import CoreLocation
import MapKit
import SwiftData
import SwiftUI
import UIKit

private enum RootTab: Hashable {
    case explore
    case friends
    case profile
}

private enum OutingComposerPresentation {
    static let creationDetent = PresentationDetent.fraction(0.66)
}

private struct OutingComposerPresentationModifier: ViewModifier {
    let isCreating: Bool
    @Binding var selectedDetent: PresentationDetent

    func body(content: Content) -> some View {
        content
            .presentationDetents(
                isCreating
                    ? [OutingComposerPresentation.creationDetent, .large]
                    : [.large],
                selection: $selectedDetent
            )
            .presentationBackgroundInteraction(
                isCreating
                    ? .enabled(
                        upThrough: OutingComposerPresentation.creationDetent
                    )
                    : .disabled
            )
            .presentationDragIndicator(.visible)
    }
}

struct FriendMapSummary: Identifiable, Hashable {
    let userID: String
    let displayName: String
    let avatarID: String
    let profileColorHex: String
    let locationSampledAt: Date?
    let spotEnteredAt: Date?
    let isLocationFresh: Bool
    let cellCount: Int

    var id: String { userID }
    var canShowOnMap: Bool { locationSampledAt != nil || cellCount > 0 }
}

private struct FriendSelection: Identifiable, Equatable {
    let userID: String

    var id: String { userID }
}

struct ContentView: View {
    private static let navigationDateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()

    @StateObject private var locationTracker = LocationTracker()
    @StateObject private var friendSyncService = FriendSyncService.shared
    @StateObject private var outingPlanService = OutingPlanService.shared
    @StateObject private var outingAttendanceService =
        OutingAttendanceService.shared
    @StateObject private var notificationService = NotificationService.shared
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @AppStorage("profile.displayName") private var displayName = ""
    @AppStorage(ProfileAvatar.storageKey) private var avatarID = ""
    @AppStorage(ProfileColor.storageKey) private var profileColorHex = ""

    @ObservedObject private var cityBoundary = CityBoundary.shared

    @State private var selectedTab: RootTab = .explore
    @State private var filterSheetVisible = false
    @State private var outingComposerVisible = false
    @State private var outingComposerDetent =
        OutingComposerPresentation.creationDetent
    @State private var editingOutingEvent: OutingPlan?
    @State private var pendingOutingCoordinate: CLLocationCoordinate2D?
    @State private var centerOnUser = false
    @State private var resetMapOrientation = false
    @State private var centerOnFriendUserID: String?
    @State private var centerOnOutingPlanEventID: String?
    @State private var selectedOutingPlanEventID: String?
    @State private var heatMapEnabled = false
    @State private var selectedFriendExplorationUserIDs: Set<String> = []
    @State private var knownFriendUserIDs: Set<String> = []
    @State private var cityProgress: CityProgress?
    @State private var friendExplorationProgress: [String: CityProgress] = [:]
    @State private var friendNavigationSelection: FriendSelection?
    @State private var selectedFriendProfile: FriendSelection?
    @State private var outingAttendanceErrorMessage: String?
    @State private var cityBoundaryResolutionState: CityBoundaryResolutionState = .loading

    #if DEBUG
    @State private var debugDrawerVisible = false
    @State private var drawerExpanded = false
    #endif

    var body: some View {
        let allFriendExplorations = friendSyncService.friendExplorations
        let summaries = friendSummaries(
            locations: friendSyncService.friendLocations,
            explorations: allFriendExplorations
        )

        GeometryReader { geometry in
            TabView(selection: $selectedTab) {
                exploreTab(
                    allFriendExplorations: allFriendExplorations,
                    friendSummaries: summaries
                )
                    .tabItem {
                        tabBarImage("TabIconExplore", accessibilityLabel: "Explorer")
                    }
                    .tag(RootTab.explore)

                FriendsView(
                    service: friendSyncService,
                    friends: summaries,
                    onShowOnMap: showFriendOnMap
                )
                .tabItem {
                    tabBarImage("TabIconFriends", accessibilityLabel: "Amis")
                }
                .tag(RootTab.friends)

                ProfileView(
                    displayName: $displayName,
                    avatarID: $avatarID,
                    profileColorHex: $profileColorHex,
                    locationTracker: locationTracker,
                    cityProgress: cityProgress,
                    cityProgressUnavailableText: cityProgressUnavailableText,
                    onProfileColorSelected: { selectedColorHex in
                        friendSyncService.updateProfileColor(
                            selectedColorHex,
                            userInitiated: true
                        )
                    }
                )
                .tabItem {
                    tabBarImage("TabIconProfile", accessibilityLabel: "Profil")
                }
                .tag(RootTab.profile)
            }
            #if DEBUG
            .overlay(alignment: .bottom) {
                if debugDrawerVisible {
                    DebugDrawerView(
                        locationTracker: locationTracker,
                        isExpanded: $drawerExpanded,
                        cityProgress: cityProgress,
                        parentGeometry: geometry
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .overlay {
                ThreeFingerPressCatcher {
                    toggleDebugDrawerVisibility()
                }
                .frame(width: 0, height: 0)
                .allowsHitTesting(false)
            }
            #endif
        }
        .onAppear {
            locationTracker.configure(with: modelContext)
            restoreOwnExplorationIfAvailable()
            locationTracker.resumeTrackingIfNeeded()
            friendSyncService.updateDisplayName(displayName)
            friendSyncService.updateAvatarID(avatarID)
            syncProfileColor(profileColorHex)
            let discoveredCellIDs = locationTracker.discoveredCellIDs
            friendSyncService.syncDiscoveredCells(discoveredCellIDs)
            refreshCityProgress(discoveredCellIDs: discoveredCellIDs)
            refreshFriendExplorationProgress()
            synchronizeOutingPlanObservation()
            synchronizeOutingAttendanceObservation()

            Task {
                await cityBoundary.load()
                cityBoundaryResolutionState = cityBoundary.cityCellIDs.isEmpty
                    ? .unavailable
                    : .ready
                if let location = locationTracker.lastLocation {
                    cityBoundary.detectCity(for: location.coordinate)
                }
            }
        }
        .onChange(of: locationTracker.lastLocation) { _, location in
            guard let location else { return }

            cityBoundary.detectCity(for: location.coordinate)
            guard locationTracker.trackingEnabled else { return }

            friendSyncService.updateLocation(
                location,
                displayName: displayName.isEmpty ? "Explorer" : displayName,
                spotEnteredAt: locationTracker.currentSpotEnteredAt
            )
        }
        .onChange(of: locationTracker.trackingEnabled, initial: true) { _, isEnabled in
            if !isEnabled {
                friendSyncService.stopSharingLocation()
            }
        }
        .onChange(of: displayName) { _, newDisplayName in
            friendSyncService.updateDisplayName(newDisplayName)
        }
        .onChange(of: avatarID) { _, newAvatarID in
            friendSyncService.updateAvatarID(newAvatarID)
        }
        .onChange(of: profileColorHex) { _, newProfileColorHex in
            syncProfileColor(newProfileColorHex)
        }
        .onChange(of: locationTracker.newlyDiscoveredCellIDs) { _, cellIDs in
            guard !cellIDs.isEmpty else { return }
            friendSyncService.addDiscoveredCells(cellIDs)
        }
        .onChange(of: locationTracker.discoveredCellIDs) { _, discoveredCellIDs in
            refreshCityProgress(discoveredCellIDs: discoveredCellIDs)
        }
        .onChange(of: friendSyncService.isProfileReady) { _, isReady in
            synchronizeOutingPlanObservation()
            synchronizeOutingAttendanceObservation()
            guard isReady else { return }

            friendSyncService.updateDisplayName(displayName)
            friendSyncService.updateAvatarID(avatarID)
            friendSyncService.updateProfileColor(profileColorHex)
            friendSyncService.syncDiscoveredCells(locationTracker.discoveredCellIDs)
            if !locationTracker.trackingEnabled {
                friendSyncService.stopSharingLocation()
            }
            openPendingNotificationRouteIfPossible()
            openPendingFriendRequestNotificationRouteIfPossible()
        }
        .onChange(of: acceptedFriendUserIDs, initial: true) { _, userIDs in
            selectNewFriends(from: userIDs)
            reconcileFriendPresentations(acceptedUserIDs: userIDs)
            synchronizeOutingPlanObservation()
            synchronizeOutingAttendanceObservation()
            reconcileSelectedOutingPlan()
            openPendingNotificationRouteIfPossible()
        }
        .onChange(of: outingPlanService.events) {
            synchronizeOutingAttendanceObservation()
            reconcileSelectedOutingPlan()
        }
        .onChange(of: notificationService.pendingRoute, initial: true) {
            openPendingNotificationRouteIfPossible()
        }
        .onChange(
            of: notificationService.pendingFriendRequestRoute,
            initial: true
        ) {
            openPendingFriendRequestNotificationRouteIfPossible()
        }
        .onChange(of: friendSyncService.friendLocations) {
            refreshFriendExplorationProgress()
            reconcileFriendPresentations(
                acceptedUserIDs: acceptedFriendUserIDs
            )
        }
        .onChange(of: friendSyncService.friendExplorationRevision) {
            refreshFriendExplorationProgress()
        }
        .onChange(of: friendSyncService.ownExplorationRevision) {
            restoreOwnExplorationIfAvailable()
        }
        .onChange(of: cityBoundary.cityCellIDs) {
            refreshCityProgress()
            refreshFriendExplorationProgress()
        }
        .onChange(of: cityBoundary.currentCity.id) {
            refreshCityProgress()
        }
        .onChange(of: cityBoundary.localizedCity?.id) {
            refreshCityProgress()
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                locationTracker.resumeTrackingIfNeeded()
                openPendingNotificationRouteIfPossible()
                openPendingFriendRequestNotificationRouteIfPossible()
            case .background:
                if locationTracker.trackingEnabled {
                    locationTracker.applyTrackingMode(.background)
                }
            case .inactive:
                break
            @unknown default:
                break
            }
        }
        .onDisappear {
            outingPlanService.stopObserving()
            outingAttendanceService.stopObserving()
        }
    }

    private func tabBarImage(
        _ assetName: String,
        accessibilityLabel: String
    ) -> some View {
        Image(assetName)
            .renderingMode(.original)
            .accessibilityLabel(accessibilityLabel)
    }

    // MARK: - Explore

    private func exploreTab(
        allFriendExplorations: [String: FriendExploration],
        friendSummaries: [FriendMapSummary]
    ) -> some View {
        let visibleFriendExplorations = allFriendExplorations.filter {
            selectedFriendExplorationUserIDs.contains($0.key)
        }
        let outingPlans = mapOutingPlans
        let selectedOutingPlan = selectedOutingPlanEventID.flatMap {
            outingPlans[$0]
        }

        return FriendEdgeRailView(
            friends: friendSummaries,
            onSelect: { friend in
                guard friend.canShowOnMap else { return }
                showFriendOnMap(friend)
            }
        ) {
            ZStack(alignment: .topTrailing) {
                MapWithFogView(
                    locationTracker: locationTracker,
                    discoveredCellIDs: locationTracker.discoveredCellIDs,
                    cityBoundaryCoordinates: cityBoundary.boundaryCoordinates,
                    friendLocations: friendSyncService.friendLocations,
                    freshFriendLocationUserIDs:
                        friendSyncService.freshFriendLocationUserIDs,
                    outingPlans: outingPlans,
                    friendExplorations: visibleFriendExplorations,
                    allFriendExplorations: allFriendExplorations,
                    userExplorationProgress: cityProgress,
                    friendExplorationProgress: friendExplorationProgress,
                    loadedFriendExplorationUserIDs:
                        friendSyncService.loadedFriendExplorationUserIDs,
                    userDisplayName: displayName,
                    userAvatarID: avatarID,
                    userProfileColorHex: profileColorHex,
                    centerOnUser: $centerOnUser,
                    resetMapOrientation: $resetMapOrientation,
                    centerOnFriendUserID: $centerOnFriendUserID,
                    centerOnOutingPlanEventID: $centerOnOutingPlanEventID,
                    pendingOutingCoordinate: pendingOutingCoordinate,
                    isEventCreationEnabled: !outingComposerVisible,
                    selectedOutingPlanEventID: selectedOutingPlanEventID,
                    showsHeatMap: heatMapEnabled,
                    heatMapCellData: locationTracker.heatMapCellData,
                    heatMapRevision: locationTracker.heatMapRevision,
                    onJoinFriend: presentNavigationOptions,
                    onViewFriendProfile: presentFriendProfile,
                    onSelectOutingPlan: { eventID in
                        selectedOutingPlanEventID = eventID
                    },
                    onDeselectOutingPlan: { eventID in
                        guard selectedOutingPlanEventID == eventID else { return }
                        selectedOutingPlanEventID = nil
                    },
                    onCreateEvent: { coordinate in
                        guard CLLocationCoordinate2DIsValid(coordinate),
                              !outingComposerVisible else {
                            return
                        }
                        selectedOutingPlanEventID = nil
                        editingOutingEvent = nil
                        pendingOutingCoordinate = coordinate
                        outingComposerDetent =
                            OutingComposerPresentation.creationDetent
                        outingComposerVisible = true
                    }
                )
                .ignoresSafeArea()

                ownExplorationStatusOverlay

                if let selectedOutingPlan {
                    OutingPlanDetailCardView(
                        outing: selectedOutingPlan,
                        onDismiss: {
                            selectedOutingPlanEventID = nil
                        },
                        onEdit: {
                            pendingOutingCoordinate = nil
                            editingOutingEvent = selectedOutingPlan.plan
                            outingComposerDetent = .large
                            outingComposerVisible = true
                        },
                        onToggleAttendance: {
                            toggleOutingAttendance(
                                eventID: selectedOutingPlan.plan.eventIDValue
                            )
                        }
                    )
                    .frame(maxWidth: 600)
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                    .frame(maxWidth: .infinity, alignment: .top)
                    .transition(
                        accessibilityReduceMotion
                            ? .identity
                            : .move(edge: .top).combined(with: .opacity)
                    )
                    .zIndex(1)
                } else {
                    Button {
                        filterSheetVisible = true
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease")
                    }
                    .buttonStyle(.glass)
                    .buttonBorderShape(.circle)
                    .controlSize(.large)
                    .accessibilityLabel("Filtres de la carte")
                    .accessibilityHint("Choisir les informations visibles sur la carte")
                    .padding(.top, 8)
                    .padding(.trailing, 16)
                    .transition(.opacity)
                }
            }
            .animation(
                accessibilityReduceMotion
                    ? nil
                    : .spring(response: 0.42, dampingFraction: 0.86),
                value: selectedOutingPlanEventID
            )
            .safeAreaInset(edge: .bottom, spacing: 0) {
                HStack(alignment: .bottom) {
                    Spacer()

                    VStack(spacing: 10) {
                        Button {
                            resetMapOrientation = true
                        } label: {
                            Image(systemName: "safari")
                        }
                        .buttonStyle(.glass)
                        .buttonBorderShape(.circle)
                        .controlSize(.large)
                        .accessibilityLabel("Orienter la carte vers le nord")

                        Button {
                            centerOnUser = true
                        } label: {
                            Image(systemName: "scope")
                        }
                        .buttonStyle(.glass)
                        .buttonBorderShape(.circle)
                        .controlSize(.large)
                        .accessibilityLabel("Recentrer la carte sur ma position")
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
        }
        .sheet(isPresented: $filterSheetVisible) {
            MapFiltersSheet(
                heatMapEnabled: $heatMapEnabled,
                friends: friendSummaries.filter { $0.cellCount > 0 },
                selectedFriendUserIDs: $selectedFriendExplorationUserIDs
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(
            isPresented: $outingComposerVisible,
            onDismiss: {
                editingOutingEvent = nil
                pendingOutingCoordinate = nil
            }
        ) {
            OutingPlanComposerView(
                displayName: displayName.isEmpty ? "Explorer" : displayName,
                initialCoordinate: pendingOutingCoordinate,
                editingEvent: editingOutingEvent
            )
            .modifier(
                OutingComposerPresentationModifier(
                    isCreating: editingOutingEvent == nil,
                    selectedDetent: $outingComposerDetent
                )
            )
        }
        .alert(
            "Rejoindre \(selectedNavigationFriendName)",
            isPresented: navigationAlertIsPresented
        ) {
            Button("Google Maps") {
                openGoogleMaps()
            }

            if canOpenNaverMapForSelectedFriend {
                Button("Naver Map · À pied") {
                    openNaverMap()
                }
            }

            Button("Annuler", role: .cancel) {}
        } message: {
            Text(selectedNavigationMessage)
        }
        .sheet(item: $selectedFriendProfile) { selection in
            FriendProfileSheet(
                userID: selection.userID,
                service: friendSyncService,
                cityBoundary: cityBoundary,
                cityBoundaryResolutionState: $cityBoundaryResolutionState
            )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .alert(
            "Participation impossible",
            isPresented: outingAttendanceErrorIsPresented
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(
                outingAttendanceErrorMessage
                    ?? "La participation n’a pas pu être modifiée. Réessaie."
            )
        }
    }

    @ViewBuilder
    private var ownExplorationStatusOverlay: some View {
        if locationTracker.discoveredCellIDs.isEmpty {
            if locationTracker.explorationRestoreError != nil {
                ContentUnavailableView {
                    Label(
                        "Carte indisponible",
                        systemImage: "externaldrive.badge.exclamationmark"
                    )
                } description: {
                    Text(
                        "Wander n’a pas pu enregistrer les zones de ton compte "
                            + "sur cet appareil."
                    )
                } actions: {
                    Button("Réessayer") {
                        restoreOwnExplorationIfAvailable()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.regularMaterial)
            } else {
                switch friendSyncService.ownExplorationSyncState {
                case .idle, .loading:
                    ProgressView("Restauration de ta carte…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(.regularMaterial)
                case .failed:
                    ContentUnavailableView {
                        Label(
                            "Synchronisation impossible",
                            systemImage: "icloud.slash"
                        )
                    } description: {
                        Text(
                            friendSyncService.ownExplorationErrorMessage
                                ?? "Vérifie ta connexion internet pour retrouver les zones enregistrées sur ton compte."
                        )
                    } actions: {
                        Button("Réessayer") {
                            friendSyncService.retryOwnExplorationSync()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.regularMaterial)
                case .ready:
                    EmptyView()
                }
            }
        }
    }

    private func presentNavigationOptions(_ userID: String) {
        guard currentNavigationDestination(for: userID) != nil else { return }
        friendNavigationSelection = FriendSelection(userID: userID)
    }

    private func presentFriendProfile(_ userID: String) {
        guard acceptedFriendUserIDs.contains(userID) else { return }
        selectedFriendProfile = FriendSelection(userID: userID)
    }

    private var navigationAlertIsPresented: Binding<Bool> {
        Binding(
            get: { friendNavigationSelection != nil },
            set: { isPresented in
                if !isPresented {
                    friendNavigationSelection = nil
                }
            }
        )
    }

    private var outingAttendanceErrorIsPresented: Binding<Bool> {
        Binding(
            get: { outingAttendanceErrorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    outingAttendanceErrorMessage = nil
                }
            }
        )
    }

    private func openGoogleMaps() {
        guard let destination = selectedNavigationDestination else {
            friendNavigationSelection = nil
            return
        }

        var components = URLComponents(
            string: "https://www.google.com/maps/dir/"
        )
        components?.queryItems = [
            URLQueryItem(name: "api", value: "1"),
            URLQueryItem(
                name: "destination",
                value: coordinateQueryValue(destination.coordinate)
            )
        ]

        guard let url = components?.url else { return }
        UIApplication.shared.open(url)
    }

    private func openNaverMap() {
        guard let destination = selectedNavigationDestination else {
            friendNavigationSelection = nil
            return
        }

        guard let url = naverMapURL(for: destination),
              UIApplication.shared.canOpenURL(url) else {
            return
        }
        UIApplication.shared.open(url)
    }

    private func canOpenNaverMap(for destination: FriendNavigationDestination) -> Bool {
        guard isInsideNaverMapCoverage(destination.coordinate),
              let url = naverMapURL(for: destination) else {
            return false
        }
        return UIApplication.shared.canOpenURL(url)
    }

    private func naverMapURL(
        for destination: FriendNavigationDestination
    ) -> URL? {
        var components = URLComponents()
        components.scheme = "nmap"
        components.host = "route"
        components.path = "/walk"
        components.queryItems = [
            URLQueryItem(
                name: "dlat",
                value: destination.coordinate.latitude.description
            ),
            URLQueryItem(
                name: "dlng",
                value: destination.coordinate.longitude.description
            ),
            URLQueryItem(name: "dname", value: destination.displayName),
            URLQueryItem(
                name: "appname",
                value: Bundle.main.bundleIdentifier ?? "com.iterar.wander.wander"
            )
        ]
        return components.url
    }

    private func isInsideNaverMapCoverage(
        _ coordinate: MapUserCoordinate
    ) -> Bool {
        (31.43...44.35).contains(coordinate.latitude)
            && (122.37...132.00).contains(coordinate.longitude)
    }

    private func coordinateQueryValue(_ coordinate: MapUserCoordinate) -> String {
        "\(coordinate.latitude),\(coordinate.longitude)"
    }

    private func navigationMessage(
        for destination: FriendNavigationDestination
    ) -> String {
        let sampledAt = Self.navigationDateTimeFormatter.string(
            from: destination.sampledAt
        )
        return "L’itinéraire utilisera la dernière position connue de \(destination.displayName), enregistrée \(sampledAt)."
    }

    private var selectedNavigationDestination: FriendNavigationDestination? {
        guard let userID = friendNavigationSelection?.userID else { return nil }
        return currentNavigationDestination(for: userID)
    }

    private var selectedNavigationFriendName: String {
        selectedNavigationDestination?.displayName ?? "cet ami"
    }

    private var selectedNavigationMessage: String {
        guard let destination = selectedNavigationDestination else {
            return "La position de cet ami n’est plus disponible."
        }
        return navigationMessage(for: destination)
    }

    private var canOpenNaverMapForSelectedFriend: Bool {
        guard let destination = selectedNavigationDestination else { return false }
        return canOpenNaverMap(for: destination)
    }

    private func currentNavigationDestination(
        for userID: String
    ) -> FriendNavigationDestination? {
        guard acceptedFriendUserIDs.contains(userID),
              let location = friendSyncService.friendLocations[userID],
              location.userID == userID,
              CLLocationCoordinate2DIsValid(location.coordinate),
              location.coordinate.latitude.isFinite,
              location.coordinate.longitude.isFinite else {
            return nil
        }

        return FriendNavigationDestination(
            userID: userID,
            displayName: location.displayName,
            coordinate: MapUserCoordinate(location.coordinate),
            sampledAt: location.sampledAt
        )
    }

    private func reconcileFriendPresentations(
        acceptedUserIDs: Set<String>
    ) {
        if let userID = friendNavigationSelection?.userID,
           (!acceptedUserIDs.contains(userID)
            || currentNavigationDestination(for: userID) == nil) {
            friendNavigationSelection = nil
        }

        if let userID = selectedFriendProfile?.userID,
           !acceptedUserIDs.contains(userID) {
            selectedFriendProfile = nil
        }
    }

    // MARK: - Friends

    private func friendSummaries(
        locations: [String: FriendLocation],
        explorations: [String: FriendExploration]
    ) -> [FriendMapSummary] {
        friendSyncService.acceptedFriends
            .map { friend in
                let location = locations[friend.userID]
                let exploration = explorations[friend.userID]
                let isLocationFresh =
                    friendSyncService.freshFriendLocationUserIDs.contains(
                        friend.userID
                    )

                return FriendMapSummary(
                    userID: friend.userID,
                    displayName: location?.displayName
                        ?? exploration?.displayName
                        ?? friend.displayName,
                    avatarID: friend.avatarID,
                    profileColorHex: ProfileColor.normalizedHex(
                        location?.profileColorHex
                            ?? exploration?.profileColorHex
                            ?? friend.profileColorHex
                    ) ?? ProfileColor.generatedHex(seed: friend.userID),
                    locationSampledAt: location?.sampledAt,
                    spotEnteredAt: location?.spotEnteredAt,
                    isLocationFresh: isLocationFresh,
                    cellCount: exploration?.cellIDs.count ?? 0
                )
            }
            .sorted { lhs, rhs in
                lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
            }
    }

    private func showFriendOnMap(_ friend: FriendMapSummary) {
        guard friend.canShowOnMap else { return }
        selectedFriendExplorationUserIDs.insert(friend.userID)
        centerOnFriendUserID = friend.userID
        selectedTab = .explore
    }

    private var acceptedFriendUserIDs: Set<String> {
        Set(friendSyncService.acceptedFriends.map(\.userID))
    }

    private var mapOutingPlans: [String: MapOutingPlan] {
        guard let currentUserID = FirebaseService.shared.currentUserId else {
            return [:]
        }

        let acceptedFriendsByUserID = friendSyncService.acceptedFriends.reduce(
            into: [String: FriendContact]()
        ) { result, friend in
            result[friend.userID] = friend
        }
        func attendees(for plan: OutingPlan) -> [MapOutingAttendee] {
            outingAttendanceService.visibleAttendances(for: plan)
            .filter {
                plan.ownerID != currentUserID
                    || acceptedFriendUserIDs.contains($0.participantID)
            }
            .map { attendance in
                MapOutingAttendee(
                    userID: attendance.participantID,
                    displayName: attendance.displayName,
                    avatarID: attendance.avatarID
                )
            }
            .sorted { lhs, rhs in
                let comparison = lhs.displayName.localizedCaseInsensitiveCompare(
                    rhs.displayName
                )
                if comparison != .orderedSame {
                    return comparison == .orderedAscending
                }
                return lhs.userID < rhs.userID
            }
        }

        return outingPlanService.events.reduce(
            into: [String: MapOutingPlan]()
        ) { result, entry in
            let (eventID, plan) = entry
            let ownerID = plan.ownerID
            if ownerID == currentUserID {
                result[eventID] = MapOutingPlan(
                    plan: plan,
                    displayName: displayName,
                    profileColorHex:
                        ProfileColor.normalizedHex(profileColorHex)
                        ?? ProfileColor.generatedHex(seed: ownerID),
                    isCurrentUser: true,
                    attendees: attendees(for: plan),
                    isCurrentUserAttending: false,
                    isAttendanceUpdating: false
                )
                return
            }

            guard let friend = acceptedFriendsByUserID[ownerID] else {
                return
            }
            result[eventID] = MapOutingPlan(
                plan: plan,
                displayName: friend.displayName,
                profileColorHex:
                    ProfileColor.normalizedHex(friend.profileColorHex)
                    ?? ProfileColor.generatedHex(seed: ownerID),
                isCurrentUser: false,
                attendees: attendees(for: plan),
                isCurrentUserAttending: outingAttendanceService.isAttending(
                    eventIDValue: eventID,
                    publicationIDValue: plan.publicationIDValue
                ),
                isAttendanceUpdating:
                    outingAttendanceService.updatingEventIDs.contains(eventID)
            )
        }
    }

    private func reconcileSelectedOutingPlan() {
        guard let selectedOutingPlanEventID,
              mapOutingPlans[selectedOutingPlanEventID] == nil else {
            return
        }
        self.selectedOutingPlanEventID = nil
    }

    private func synchronizeOutingPlanObservation() {
        guard friendSyncService.isProfileReady else {
            outingPlanService.stopObserving()
            return
        }
        outingPlanService.observeEvents(
            forAcceptedFriendUserIDs: acceptedFriendUserIDs
        )
    }

    private func synchronizeOutingAttendanceObservation() {
        guard friendSyncService.isProfileReady else {
            outingAttendanceService.stopObserving()
            return
        }
        outingAttendanceService.observe(
            events: outingPlanService.events,
            acceptedFriendUserIDs: acceptedFriendUserIDs
        )
    }

    private func toggleOutingAttendance(eventID: String) {
        guard let event = outingPlanService.events[eventID],
              acceptedFriendUserIDs.contains(event.ownerID) else {
            outingAttendanceErrorMessage = "Cet événement n’est plus disponible."
            return
        }

        let shouldAttend = !outingAttendanceService.isAttending(
            eventIDValue: eventID,
            publicationIDValue: event.publicationIDValue
        )
        Task {
            do {
                try await outingAttendanceService.setAttending(
                    shouldAttend,
                    event: event
                )
            } catch let error as OutingAttendanceServiceError {
                outingAttendanceErrorMessage = error.errorDescription
                    ?? "La participation n’a pas pu être modifiée. Réessaie."
            } catch {
                outingAttendanceErrorMessage =
                    "La participation n’a pas pu être modifiée. Réessaie."
            }
        }
    }

    private func openPendingNotificationRouteIfPossible() {
        guard friendSyncService.isProfileReady,
              let route = notificationService.pendingRoute else {
            return
        }

        Task {
            do {
                _ = try await outingPlanService.refreshEventFromNotification(
                    ownerID: route.ownerID,
                    eventIDValue: route.eventIDValue,
                    publicationID: route.publicationID
                )

                // The direct Firestore read proves current authorization. Wait
                // for the local friendship presentation before asking MapKit
                // to select the corresponding annotation.
                guard let currentUserID = FirebaseService.shared.currentUserId,
                      route.ownerID == currentUserID
                        || acceptedFriendUserIDs.contains(route.ownerID) else {
                    return
                }

                selectedTab = .explore
                centerOnOutingPlanEventID = route.eventIDValue
                notificationService.consume(route)
            } catch is OutingPlanServiceError {
                notificationService.consume(route)
            } catch {
                // Keep a route after a transient network failure. Returning to
                // the active scene retries the server-side authorization read.
            }
        }
    }

    private func openPendingFriendRequestNotificationRouteIfPossible() {
        guard friendSyncService.isProfileReady,
              let route = notificationService.pendingFriendRequestRoute else {
            return
        }

        selectedTab = .friends
        notificationService.consume(route)
    }

    private func refreshFriendExplorationProgress() {
        let explorations = friendSyncService.friendExplorations
        let loadedUserIDs = friendSyncService.loadedFriendExplorationUserIDs

        friendExplorationProgress = friendSyncService.friendLocations.reduce(into: [:]) {
            result, entry in
            let (userID, location) = entry
            guard loadedUserIDs.contains(userID),
                  let exploration = explorations[userID],
                  let progress = cityBoundary.progress(
                    against: exploration.cellIDs,
                    at: location.coordinate
                  ) else {
                return
            }

            result[userID] = progress
        }
    }

    private func selectNewFriends(from currentUserIDs: Set<String>) {
        let newUserIDs = currentUserIDs.subtracting(knownFriendUserIDs)
        selectedFriendExplorationUserIDs.formUnion(newUserIDs)
        selectedFriendExplorationUserIDs.formIntersection(currentUserIDs)
        knownFriendUserIDs = currentUserIDs
    }

    private func syncProfileColor(_ rawValue: String) {
        let normalizedValue =
            ProfileColor.normalizedHex(rawValue)
            ?? ProfileColor.storedOrGeneratedHex()

        if profileColorHex != normalizedValue {
            profileColorHex = normalizedValue
        }

        friendSyncService.updateProfileColor(normalizedValue)
    }

    private func restoreOwnExplorationIfAvailable() {
        guard friendSyncService.ownExplorationSyncState == .ready else {
            return
        }

        guard locationTracker.restoreDiscoveredCells(
            friendSyncService.ownExplorationCells
        ) else {
            return
        }

        let reconciledCellIDs = locationTracker.discoveredCellIDs
        friendSyncService.syncDiscoveredCells(reconciledCellIDs)
        refreshCityProgress(discoveredCellIDs: reconciledCellIDs)
    }

    // MARK: - City progress

    private func refreshCityProgress(discoveredCellIDs: Set<String>? = nil) {
        let cellIDs = discoveredCellIDs
            ?? locationTracker.discoveredCellIDs
        let refreshedProgress = cityBoundary.progress(against: cellIDs)

        if cityProgress != refreshedProgress {
            cityProgress = refreshedProgress
        }
    }

    private var cityProgressUnavailableText: String {
        guard locationTracker.lastLocation != nil else {
            return "Active l’exploration pour révéler la carte."
        }

        guard !cityBoundary.cityCellIDs.isEmpty else {
            return "Préparation de la ville…"
        }

        return "Cette ville n’est pas encore disponible."
    }

    #if DEBUG
    private func toggleDebugDrawerVisibility() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            debugDrawerVisible.toggle()

            if !debugDrawerVisible {
                drawerExpanded = false
            }
        }
    }
    #endif
}

// MARK: - Friends

private struct FriendsView: View {
    @ObservedObject var service: FriendSyncService
    let friends: [FriendMapSummary]
    let onShowOnMap: (FriendMapSummary) -> Void

    @State private var friendCodeInput = ""
    @State private var processingRequestID: String?
    @State private var processingFriendUserID: String?
    @State private var friendPendingRemoval: FriendMapSummary?

    var body: some View {
        NavigationStack {
            List {
                Section("Ton code ami") {
                    if service.isPreparingProfile {
                        HStack(spacing: 10) {
                            ProgressView()
                            Text("Création de ton code…")
                                .foregroundStyle(.secondary)
                        }
                    } else if let friendCode = service.friendCode, !friendCode.isEmpty {
                        HStack {
                            Text(friendCode)
                                .font(.title3.weight(.semibold))
                                .monospaced()
                                .textSelection(.enabled)

                            Spacer()

                            Button {
                                UIPasteboard.general.string = friendCode
                            } label: {
                                Label("Copier", systemImage: "doc.on.doc")
                            }
                            .buttonStyle(.borderless)
                        }

                        ShareLink(item: shareMessage(for: friendCode)) {
                            Label("Partager mon code", systemImage: "square.and.arrow.up")
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            Label(
                                "Code indisponible",
                                systemImage: "exclamationmark.circle"
                            )
                            .foregroundStyle(.secondary)

                            Button("Réessayer") {
                                service.retryProfileSetup()
                            }
                        }
                    }
                }

                Section("Ajouter un ami") {
                    TextField("Code ami", text: $friendCodeInput)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .submitLabel(.send)
                        .onSubmit(sendFriendRequest)

                    Button(action: sendFriendRequest) {
                        if service.isProcessingFriendAction
                            && processingRequestID == nil {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Label("Ajouter un ami", systemImage: "person.badge.plus")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(
                        friendCodeInput.isEmpty
                            || !service.isProfileReady
                            || service.isProcessingFriendAction
                    )
                }

                if !service.incomingRequests.isEmpty {
                    Section("Demandes reçues") {
                        ForEach(service.incomingRequests) { request in
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(spacing: 10) {
                                    ProfileAvatarView(
                                        avatarID: request.avatarID,
                                        size: 32
                                    )
                                    .accessibilityHidden(true)

                                    Text(request.displayName)
                                }

                                if processingRequestID == request.id {
                                    HStack(spacing: 10) {
                                        ProgressView()
                                        Text("Mise à jour…")
                                            .foregroundStyle(.secondary)
                                    }
                                } else {
                                    HStack {
                                        Button("Accepter") {
                                            process(request, accepting: true)
                                        }
                                        .buttonStyle(.borderedProminent)
                                        .disabled(service.isProcessingFriendAction)

                                        Button("Refuser", role: .destructive) {
                                            process(request, accepting: false)
                                        }
                                        .buttonStyle(.bordered)
                                        .disabled(service.isProcessingFriendAction)
                                    }
                                }
                            }
                            .padding(.vertical, 3)
                        }
                    }
                }

                Section("Mes amis") {
                    if friends.isEmpty {
                        Text("Aucun ami pour le moment.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(friends) { friend in
                            HStack {
                                if friend.canShowOnMap {
                                    Button {
                                        onShowOnMap(friend)
                                    } label: {
                                        FriendRow(friend: friend)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel(
                                        "Afficher \(friend.displayName) sur la carte"
                                    )
                                } else {
                                    FriendRow(friend: friend)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }

                                if processingFriendUserID == friend.userID {
                                    ProgressView()
                                }
                            }
                            .swipeActions(
                                edge: .trailing,
                                allowsFullSwipe: false
                            ) {
                                Button(role: .destructive) {
                                    friendPendingRemoval = friend
                                } label: {
                                    Label(
                                        "Retirer",
                                        systemImage: "person.badge.minus"
                                    )
                                }
                                .disabled(service.isProcessingFriendAction)
                            }
                        }
                    }
                }

                if !service.outgoingRequests.isEmpty {
                    Section("En attente") {
                        ForEach(service.outgoingRequests) { request in
                            HStack {
                                ProfileAvatarView(
                                    avatarID: request.avatarID,
                                    size: 32
                                )
                                .accessibilityHidden(true)

                                Text(request.displayName)
                                Spacer()
                                Text("Demande envoyée")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Amis")
            .alert(
                removalAlertTitle,
                isPresented: removalAlertIsPresented,
                presenting: friendPendingRemoval
            ) { friend in
                Button("Retirer", role: .destructive) {
                    remove(friend)
                }
                Button("Annuler", role: .cancel) {}
            } message: { _ in
                Text(
                    "Vous disparaîtrez tous les deux de la liste d’amis de l’autre. "
                        + "Il faudra envoyer une nouvelle demande pour redevenir amis."
                )
            }
            .alert(
                "Impossible de terminer l’action",
                isPresented: errorIsPresented
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(service.errorMessage ?? "Réessaie dans quelques instants.")
            }
            .onChange(of: service.isProcessingFriendAction) { _, isProcessing in
                if !isProcessing {
                    processingRequestID = nil
                    processingFriendUserID = nil
                }
            }
        }
    }

    private var errorIsPresented: Binding<Bool> {
        Binding(
            get: {
                service.errorMessage != nil
            },
            set: { isPresented in
                if !isPresented {
                    service.clearError()
                }
            }
        )
    }

    private var removalAlertIsPresented: Binding<Bool> {
        Binding(
            get: {
                friendPendingRemoval != nil
            },
            set: { isPresented in
                if !isPresented {
                    friendPendingRemoval = nil
                }
            }
        )
    }

    private var removalAlertTitle: String {
        guard let friendPendingRemoval else {
            return "Retirer cet ami ?"
        }
        return "Retirer \(friendPendingRemoval.displayName) de tes amis ?"
    }

    private func shareMessage(for friendCode: String) -> String {
        "Ajoute-moi sur Wander avec le code \(friendCode)."
    }

    private func sendFriendRequest() {
        guard service.isProfileReady,
              !friendCodeInput.isEmpty,
              !service.isProcessingFriendAction else { return }
        let submittedCode = friendCodeInput

        service.sendFriendRequest(code: submittedCode) { didSend in
            guard didSend else { return }

            DispatchQueue.main.async {
                if friendCodeInput == submittedCode {
                    friendCodeInput = ""
                }
            }
        }
    }

    private func process(_ request: FriendRequest, accepting: Bool) {
        processingRequestID = request.id

        if accepting {
            service.accept(request)
        } else {
            service.decline(request)
        }

        if !service.isProcessingFriendAction {
            processingRequestID = nil
        }
    }

    private func remove(_ friend: FriendMapSummary) {
        processingFriendUserID = friend.userID
        service.removeFriend(userID: friend.userID)

        if !service.isProcessingFriendAction {
            processingFriendUserID = nil
        }
    }
}

private struct FriendRow: View {
    let friend: FriendMapSummary

    var body: some View {
        HStack(spacing: 12) {
            FriendAvatarBadge(
                avatarID: friend.avatarID,
                profileColorHex: friend.profileColorHex,
                size: 30
            )
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(friend.displayName)
                    .font(.body.weight(.medium))

                TimelineView(.periodic(from: .now, by: 60)) { context in
                    statusLabel(relativeTo: context.date)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private func statusLabel(relativeTo referenceDate: Date) -> some View {
        if let sampledAt = friend.locationSampledAt {
            let locationText = presenceStatusText(relativeTo: referenceDate)
                ?? positionStatusText(sampledAt, relativeTo: referenceDate)
            Text(
                [
                    locationText,
                    explorationStatusText
                ]
                .compactMap { $0 }
                .joined(separator: " · ")
            )
        } else if let explorationText = explorationStatusText {
            Text(explorationText)
        } else {
            Text("Position indisponible")
        }
    }

    private func positionStatusText(
        _ sampledAt: Date,
        relativeTo referenceDate: Date
    ) -> String {
        let age = referenceDate.timeIntervalSince(sampledAt)
        guard age >= 60 else {
            return "Dernière position reçue à l’instant"
        }

        let relativeText = Self.relativePositionFormatter.localizedString(
            for: sampledAt,
            relativeTo: referenceDate
        )
        return "Dernière position reçue \(relativeText)"
    }

    private func presenceStatusText(relativeTo referenceDate: Date) -> String? {
        guard friend.isLocationFresh,
              let sampledAt = friend.locationSampledAt,
              let enteredAt = friend.spotEnteredAt else {
            return nil
        }

        let sampleAge = referenceDate.timeIntervalSince(sampledAt)
        guard sampleAge >= -Self.maximumFutureTimestampSkew,
              enteredAt <= sampledAt else {
            return nil
        }

        let duration = max(0, referenceDate.timeIntervalSince(enteredAt))
        return "Au même endroit depuis \(Self.durationText(duration))"
    }

    private static func durationText(_ duration: TimeInterval) -> String {
        let totalMinutes = max(0, Int(duration / 60))
        guard totalMinutes > 0 else { return "moins d’1 min" }

        let days = totalMinutes / (24 * 60)
        let hours = (totalMinutes % (24 * 60)) / 60
        let minutes = totalMinutes % 60

        if days > 0 {
            return hours > 0 ? "\(days) j \(hours) h" : "\(days) j"
        }
        if hours > 0 {
            return minutes > 0 ? "\(hours) h \(minutes) min" : "\(hours) h"
        }
        return "\(minutes) min"
    }

    private static let maximumFutureTimestampSkew: TimeInterval = 60

    private static let relativePositionFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateTimeStyle = .numeric
        formatter.unitsStyle = .abbreviated
        return formatter
    }()

    private var explorationStatusText: String? {
        switch friend.cellCount {
        case 0:
            nil
        case 1:
            "1 zone explorée"
        default:
            "\(friend.cellCount) zones explorées"
        }
    }
}

// MARK: - Profile

private struct ProfileView: View {
    @Binding var displayName: String
    @Binding var avatarID: String
    @Binding var profileColorHex: String
    @ObservedObject var locationTracker: LocationTracker
    @ObservedObject private var authenticationService = FirebaseService.shared
    @ObservedObject private var friendSyncService = FriendSyncService.shared
    @ObservedObject private var notificationService = NotificationService.shared
    @AppStorage("profile.onboardingCompleted") private var onboardingCompleted = false

    let cityProgress: CityProgress?
    let cityProgressUnavailableText: String
    let onProfileColorSelected: (String) -> Void

    @State private var signOutConfirmationPresented = false
    @State private var deleteConfirmationPresented = false
    @State private var deletionAuthorizationPresented = false
    @State private var accountActionErrorMessage: String?
    @State private var isSigningOut = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 16) {
                        ProfileAvatarView(avatarID: avatarID, size: 72)
                            .overlay {
                                Circle()
                                    .stroke(
                                        ProfileColor.color(hex: profileColorHex),
                                        lineWidth: 4
                                    )
                            }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(displayName.isEmpty ? "Explorer" : displayName)
                                .font(.title2.bold())

                            Label(
                                locationTracker.isTracking ? "Exploration active" : "Exploration en pause",
                                systemImage: locationTracker.isTracking ? "location.fill" : "pause.circle"
                            )
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                }

                Section("Avatar") {
                    ProfileAvatarPicker(selection: $avatarID)
                }

                Section {
                    TextField("Pseudo", text: $displayName)
                        .textInputAutocapitalization(.words)
                        .submitLabel(.done)

                    ColorPicker(
                        "Couleur de ma carte",
                        selection: profileColorBinding,
                        supportsOpacity: false
                    )
                } header: {
                    Text("Identité")
                } footer: {
                    Text(
                        "Cette couleur identifie tes zones explorées chez tes amis et entoure ton avatar sur la carte."
                    )
                }

                Section {
                    Toggle("Enregistrer mes déplacements", isOn: trackingBinding)

                    if locationTracker.authorizationStatus == .authorizedWhenInUse
                        || locationTracker.authorizationStatus == .authorizedAlways {
                        Toggle(
                            "Continuer en arrière-plan",
                            isOn: backgroundTrackingBinding
                        )
                    }

                    if locationTracker.authorizationStatus == .denied
                        || locationTracker.authorizationStatus == .restricted {
                        Label(
                            "Autorise la localisation dans Réglages pour reprendre l’exploration.",
                            systemImage: "location.slash"
                        )
                        .foregroundStyle(.secondary)

                        Button {
                            openSettings()
                        } label: {
                            Label("Ouvrir Réglages", systemImage: "gear")
                        }
                    } else if let lastError = locationTracker.lastError {
                        Label(lastError, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Localisation")
                } footer: {
                    Text(
                        "Quand l’exploration est active, Wander utilise ta position pour révéler la carte et alimenter les fonctions entre amis. Le suivi en arrière-plan reste optionnel."
                    )
                }

                Section {
                    Toggle(
                        "Activité de mes amis",
                        isOn: notificationsBinding
                    )

                    Label(
                        notificationAuthorizationText,
                        systemImage: notificationAuthorizationSystemImage
                    )
                    .foregroundStyle(.secondary)

                    if notificationService.authorizationStatus == .denied {
                        Button {
                            openSettings()
                        } label: {
                            Label("Ouvrir Réglages", systemImage: "gear")
                        }
                    }

                    if let errorMessage = notificationService.errorMessage {
                        Label(
                            errorMessage,
                            systemImage: "exclamationmark.triangle"
                        )
                        .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Notifications")
                } footer: {
                    Text(
                        "Active-les pour recevoir les demandes d’amis, les nouvelles sorties et les participations de tes amis acceptés. Wander n’affiche jamais leur adresse ni leurs coordonnées dans une notification."
                    )
                }

                Section("Progression") {
                    LabeledContent(
                        "Ville",
                        value: cityProgress?.cityName ?? cityProgressUnavailableText
                    )

                    LabeledContent(
                        "Progression",
                        value: cityProgress?.percentageText ?? "—"
                    )

                    LabeledContent("Zones explorées") {
                        Text(exploredCellsText)
                            .monospacedDigit()
                    }
                }

                accountSection
            }
            .navigationTitle("Profil")
        }
        .onAppear {
            Task {
                await notificationService.refreshAuthorizationStatus()
            }
            if friendSyncService.isAccountDeletionPending {
                deletionAuthorizationPresented = true
            }
        }
        .onChange(of: friendSyncService.isAccountDeletionPending) {
            if friendSyncService.isAccountDeletionPending {
                deletionAuthorizationPresented = true
            }
        }
        .alert(
            "Se déconnecter ?",
            isPresented: $signOutConfirmationPresented
        ) {
            Button("Se déconnecter") {
                isSigningOut = true
                Task {
                    do {
                        try await notificationService.prepareForSignOut()
                        if !authenticationService.signOut() {
                            await notificationService.enableNotifications()
                            accountActionErrorMessage =
                                authenticationService.authErrorMessage
                        }
                    } catch {
                        accountActionErrorMessage = error.localizedDescription
                    }
                    isSigningOut = false
                }
            }

            Button("Annuler", role: .cancel) {}
        } message: {
            Text(
                "Tes données restent enregistrées et seront retrouvées à ta prochaine connexion."
            )
        }
        .alert(
            "Supprimer définitivement ton compte ?",
            isPresented: $deleteConfirmationPresented
        ) {
            Button("Continuer", role: .destructive) {
                deletionAuthorizationPresented = true
            }

            Button("Annuler", role: .cancel) {}
        } message: {
            Text(
                "Ton profil, ta progression, tes relations et tes données locales seront définitivement supprimés. Cette action est irréversible."
            )
        }
        .sheet(isPresented: $deletionAuthorizationPresented) {
            deletionAuthorizationSheet
        }
        .alert(
            "Impossible de terminer l’action",
            isPresented: accountActionErrorPresented
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(accountActionErrorMessage ?? "Réessaie dans quelques instants.")
        }
    }

    private var accountSection: some View {
        Section {
            Button {
                signOutConfirmationPresented = true
            } label: {
                Label(
                    "Se déconnecter",
                    systemImage: "rectangle.portrait.and.arrow.right"
                )
            }
            .disabled(isSigningOut)

            Button(role: .destructive) {
                deleteConfirmationPresented = true
            } label: {
                Label(
                    accountDeletionButtonTitle,
                    systemImage: "person.crop.circle.badge.minus"
                )
            }
            .disabled(isSigningOut)
        } header: {
            Text("Compte")
        } footer: {
            Text(
                "La déconnexion conserve tes données. La suppression du compte efface définitivement ton profil Wander, ta progression, tes relations et les données de cet appareil."
            )
        }
    }

    private var accountDeletionButtonTitle: String {
        friendSyncService.isAccountDeletionPending
            ? "Terminer la suppression"
            : "Supprimer mon compte"
    }

    private var deletionAuthorizationSheet: some View {
        AccountDeletionAuthorizationView(
            authenticationService: authenticationService,
            deletionIsPending: friendSyncService.isAccountDeletionPending,
            errorMessage: accountActionErrorMessage,
            onCompletion: handleAccountDeletionAuthorization,
            onCancel: cancelAccountDeletionAuthorization
        )
        .interactiveDismissDisabled(
            authenticationService.isDeletingAccount
                || friendSyncService.isAccountDeletionPending
        )
    }

    private var accountActionErrorPresented: Binding<Bool> {
        Binding(
            get: { accountActionErrorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    accountActionErrorMessage = nil
                }
            }
        )
    }

    private func cancelAccountDeletionAuthorization() {
        authenticationService.cancelAccountDeletion()
        deletionAuthorizationPresented = false
    }

    private var trackingBinding: Binding<Bool> {
        Binding(
            get: {
                locationTracker.trackingEnabled
            },
            set: { isEnabled in
                if isEnabled {
                    locationTracker.startTracking()
                } else {
                    locationTracker.stopTracking()
                }
            }
        )
    }

    private var backgroundTrackingBinding: Binding<Bool> {
        Binding(
            get: {
                locationTracker.backgroundTrackingEnabled
            },
            set: { isEnabled in
                locationTracker.setBackgroundTrackingEnabled(isEnabled)
            }
        )
    }

    private var notificationsBinding: Binding<Bool> {
        Binding(
            get: { notificationService.isEnabled },
            set: { isEnabled in
                notificationService.clearError()
                Task {
                    if isEnabled {
                        await notificationService.enableNotifications()
                    } else {
                        await notificationService.disableNotifications()
                    }
                }
            }
        )
    }

    private var notificationAuthorizationText: String {
        switch notificationService.authorizationStatus {
        case .notDetermined:
            "Autorisation non demandée"
        case .denied:
            "Notifications refusées dans Réglages"
        case .authorized:
            "Notifications autorisées"
        case .provisional:
            "Notifications autorisées provisoirement"
        case .ephemeral:
            "Notifications autorisées temporairement"
        @unknown default:
            "État des notifications indisponible"
        }
    }

    private var notificationAuthorizationSystemImage: String {
        notificationService.authorizationAllowsNotifications
            ? "bell.badge"
            : "bell.slash"
    }

    private var exploredCellsText: String {
        guard let cityProgress else { return "—" }
        return "\(cityProgress.exploredCells) / \(cityProgress.totalCells)"
    }

    private func handleAccountDeletionAuthorization(
        _ result: Result<ASAuthorization, Error>
    ) {
        let authenticationService = authenticationService
        let friendSyncService = friendSyncService
        let locationTracker = locationTracker

        Task {
            do {
                guard let authorizationCode = try await authenticationService
                    .reauthenticateForAccountDeletion(result) else {
                    if friendSyncService.isAccountDeletionPending {
                        accountActionErrorMessage =
                            "La vérification Apple est nécessaire pour terminer la suppression."
                    } else {
                        deletionAuthorizationPresented = false
                    }
                    return
                }

                try await notificationService.prepareForAccountDeletion()
                try await friendSyncService.deleteCurrentAccountData()
                try await authenticationService.finishAccountDeletion(
                    authorizationCode: authorizationCode
                )

                var localCleanupError: Error?
                do {
                    try locationTracker.resetLocalData()
                } catch {
                    localCleanupError = error
                }

                clearLocalProfileData()

                do {
                    try await friendSyncService.clearLocalFirestoreCache()
                } catch {
                    localCleanupError = localCleanupError ?? error
                }

                if let localCleanupError {
                    print(
                        "[Profile] account deleted but local cleanup failed: "
                            + localCleanupError.localizedDescription
                    )
                }
            } catch {
                authenticationService.cancelAccountDeletion()
                if let authenticationError =
                    error as? FirebaseService.AccountDeletionError {
                    accountActionErrorMessage =
                        authenticationError.errorDescription
                } else {
                    accountActionErrorMessage =
                        friendSyncService.accountDeletionMessage(for: error)
                }
            }
        }
    }

    private func clearLocalProfileData() {
        displayName = ""
        avatarID = ""
        profileColorHex = ""

        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: ProfileAvatar.storageKey)
        defaults.removeObject(forKey: ProfileAvatar.ownerStorageKey)
        defaults.removeObject(forKey: ProfileColor.storageKey)
        defaults.removeObject(forKey: ProfileColor.ownerStorageKey)
        defaults.removeObject(forKey: ProfileColor.pendingOwnerStorageKey)
        defaults.removeObject(
            forKey: ProfileColor.pendingUserSelectionStorageKey
        )
        onboardingCompleted = false

        defaults.removeObject(forKey: "profile.displayName")
        defaults.removeObject(forKey: "profile.avatarImageData")
        defaults.removeObject(forKey: "profile.onboardingCompleted")
    }

    private func openSettings() {
        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(settingsURL)
    }

    private var profileColorBinding: Binding<Color> {
        Binding(
            get: {
                ProfileColor.color(hex: profileColorHex)
            },
            set: { newColor in
                let selectedColorHex = ProfileColor.hex(from: newColor)
                profileColorHex = selectedColorHex
                onProfileColorSelected(selectedColorHex)
            }
        )
    }
}

private struct AccountDeletionAuthorizationView: View {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject var authenticationService: FirebaseService

    let deletionIsPending: Bool
    let errorMessage: String?
    let onCompletion: (Result<ASAuthorization, Error>) -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    Image(systemName: "person.crop.circle.badge.minus")
                        .font(.system(size: 48))
                        .foregroundStyle(.red)
                        .accessibilityHidden(true)

                    VStack(spacing: 8) {
                        Text(
                            deletionIsPending
                                ? "Terminer la suppression"
                                : "Confirmer avec Apple"
                        )
                        .font(.title2.bold())

                        Text(
                            deletionIsPending
                                ? "La suppression a déjà commencé. Identifie-toi de nouveau pour effacer les données restantes."
                                : "Wander doit vérifier ton identité avant de supprimer définitivement ton compte."
                        )
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    }

                    if authenticationService.isDeletingAccount {
                        ProgressView("Suppression du compte…")
                    } else {
                        SignInWithAppleButton(
                            .continue,
                            onRequest: authenticationService
                                .prepareAccountDeletionAuthorizationRequest,
                            onCompletion: onCompletion
                        )
                        .signInWithAppleButtonStyle(
                            colorScheme == .dark ? .white : .black
                        )
                        .frame(height: 50)
                        .accessibilityLabel(
                            "Confirmer la suppression avec Apple"
                        )
                    }

                    if let errorMessage {
                        Label(
                            errorMessage,
                            systemImage: "exclamationmark.triangle"
                        )
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
            }
            .navigationTitle("Suppression du compte")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !deletionIsPending
                    && !authenticationService.isDeletingAccount {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Annuler", action: onCancel)
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - Map filters

private struct MapFiltersSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var heatMapEnabled: Bool
    let friends: [FriendMapSummary]
    @Binding var selectedFriendUserIDs: Set<String>

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Carte de fréquentation", isOn: $heatMapEnabled)
                } header: {
                    Text("Exploration")
                } footer: {
                    Text("Affiche les zones où tu as passé le plus de temps.")
                }

                Section {
                    if friends.isEmpty {
                        Text(
                            "Les cartes de tes amis apparaîtront dès qu’ils auront exploré une zone."
                        )
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(friends) { friend in
                            Toggle(
                                isOn: selectionBinding(for: friend.userID)
                            ) {
                                HStack(spacing: 10) {
                                    Circle()
                                        .fill(
                                            ProfileColor.color(
                                                hex: friend.profileColorHex
                                            )
                                        )
                                        .frame(width: 12, height: 12)
                                        .accessibilityHidden(true)

                                    Text(friend.displayName)

                                    Spacer()

                                    Text(friend.cellCount.formatted())
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .monospacedDigit()
                                }
                            }
                        }
                    }
                } header: {
                    Text("Cartes des amis")
                } footer: {
                    Text("Le nombre indique les zones explorées par chaque ami.")
                }
            }
            .navigationTitle("Affichage")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Terminé") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func selectionBinding(for userID: String) -> Binding<Bool> {
        Binding(
            get: {
                selectedFriendUserIDs.contains(userID)
            },
            set: { isSelected in
                if isSelected {
                    selectedFriendUserIDs.insert(userID)
                } else {
                    selectedFriendUserIDs.remove(userID)
                }
            }
        )
    }
}

#if DEBUG
private struct ThreeFingerPressCatcher: UIViewRepresentable {
    var onPress: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onPress: onPress)
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.isUserInteractionEnabled = false

        DispatchQueue.main.async {
            context.coordinator.attach(to: view.window)
        }

        return view
    }

    func updateUIView(_ view: UIView, context: Context) {
        context.coordinator.onPress = onPress

        DispatchQueue.main.async {
            context.coordinator.attach(to: view.window)
        }
    }

    static func dismantleUIView(_ view: UIView, coordinator: Coordinator) {
        coordinator.detach()
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var onPress: () -> Void

        private weak var attachedView: UIView?
        private weak var gestureRecognizer: UILongPressGestureRecognizer?

        init(onPress: @escaping () -> Void) {
            self.onPress = onPress
        }

        func attach(to view: UIView?) {
            guard let view, attachedView !== view else { return }

            detach()

            let gestureRecognizer = UILongPressGestureRecognizer(
                target: self,
                action: #selector(handlePress(_:))
            )
            gestureRecognizer.numberOfTouchesRequired = 3
            gestureRecognizer.minimumPressDuration = 0.25
            gestureRecognizer.cancelsTouchesInView = false
            gestureRecognizer.delaysTouchesBegan = false
            gestureRecognizer.delaysTouchesEnded = false
            gestureRecognizer.delegate = self

            view.addGestureRecognizer(gestureRecognizer)
            attachedView = view
            self.gestureRecognizer = gestureRecognizer
        }

        func detach() {
            if let gestureRecognizer, let attachedView {
                attachedView.removeGestureRecognizer(gestureRecognizer)
            }

            attachedView = nil
            gestureRecognizer = nil
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            true
        }

        @objc private func handlePress(_ gestureRecognizer: UILongPressGestureRecognizer) {
            guard gestureRecognizer.state == .began else { return }
            onPress()
        }
    }
}
#endif

#Preview {
    ContentView()
}
