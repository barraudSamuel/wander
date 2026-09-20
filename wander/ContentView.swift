//
//  ContentView.swift
//  wander
//
//  Map-first experience with native Apple navigation and controls.
//

import CoreLocation
import MapKit
import SwiftData
import SwiftUI
import UIKit

enum MapDetailSelection: Equatable {
    case friend(String)
    case outing(String)

    var friendUserID: String? {
        guard case .friend(let userID) = self else { return nil }
        return userID
    }

    var outingEventID: String? {
        guard case .outing(let eventID) = self else { return nil }
        return eventID
    }
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
    let isGhostModeEnabled: Bool

    var id: String { userID }
    var canShowOnMap: Bool { !isGhostModeEnabled && locationSampledAt != nil }
}

private struct FriendSelection: Identifiable, Equatable {
    let userID: String

    var id: String { userID }
}

private struct ExternalMapNavigationDestination: Equatable {
    let displayName: String
    let coordinate: MapUserCoordinate
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
    @StateObject private var locationPushService = LocationPushService.shared
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext
    @AppStorage("profile.displayName") private var displayName = ""
    @AppStorage(ProfileAvatar.storageKey) private var avatarID = ""
    @AppStorage(ProfileColor.storageKey) private var profileColorHex = ""

    @ObservedObject private var cityBoundary = CityBoundary.shared

    @State private var dockSelection: MotionDockSelection = .explore
    @State private var friendCodeInput = ""
    @State private var isProfileAccountFlowActive = false
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
    @State private var selectedMapDetail: MapDetailSelection?
    @State private var visibleRosterEventIDs: Set<String> = []
    @State private var heatMapEnabled = false
    @State private var cityProgress: CityProgress?
    @State private var friendNavigationSelection: FriendSelection?
    @State private var selectedOutingNavigationEventID: String?
    @State private var selectedFriendProfile: FriendSelection?
    @State private var outingAttendanceErrorMessage: String?

    #if DEBUG
    @State private var debugDrawerVisible = false
    @State private var drawerExpanded = false
    #endif

    var body: some View {
        lifecycleObservedContent
    }

    private var mapDockContent: some View {
        let summaries = friendSummaries(
            locations: friendSyncService.friendLocations
        )

        return GeometryReader { geometry in
            MotionDockView(selection: dockSelectionBinding) {
                exploreTab()
            } friends: {
                FriendsPanelView(
                    service: friendSyncService,
                    friends: summaries,
                    onShowOnMap: showFriendOnMap,
                    onViewProfile: presentFriendProfile,
                    friendCodeInput: $friendCodeInput
                )
            } profile: {
                ProfilePanelView(
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
                    },
                    onAccountFlowStateChanged: { isProfileAccountFlowActive = $0 }
                )
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
    }

    private var profileObservedContent: some View {
        mapDockContent
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
            synchronizeOutingPlanObservation()
            synchronizeOutingAttendanceObservation()
            synchronizeLocationPushRegistration()

            Task {
                await cityBoundary.load()
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
            synchronizeLocationPushRegistration()
        }
        .onChange(
            of: locationTracker.backgroundTrackingEnabled,
            initial: true
        ) {
            synchronizeLocationPushRegistration()
        }
        .onChange(of: locationTracker.authorizationStatus, initial: true) {
            synchronizeLocationPushRegistration()
        }
        .onChange(
            of: friendSyncService.isLocationSharingAllowed,
            initial: true
        ) { _, isAllowed in
            synchronizeLocationPushRegistration()
            if isAllowed {
                locationTracker.resetSharedPresenceAndRequestLocation()
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
            synchronizeLocationPushRegistration()
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
    }

    private var dockSelectionBinding: Binding<MotionDockSelection> {
        Binding(
            get: { dockSelection },
            set: { newSelection in
                guard !isProfileAccountFlowActive else { return }
                dockSelection = newSelection
            }
        )
    }

    private var outingObservedContent: some View {
        profileObservedContent
        .onChange(of: acceptedFriendUserIDs, initial: true) { _, userIDs in
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
        .onChange(of: selectedOutingPlanEventID) {
            synchronizeOutingAttendanceObservation()
        }
        .onChange(of: visibleRosterEventIDs) {
            synchronizeOutingAttendanceObservation()
        }
        .onChange(of: isProfileAccountFlowActive) { _, isActive in
            guard !isActive else { return }
            openPendingNotificationRouteIfPossible()
            openPendingFriendRequestNotificationRouteIfPossible()
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
            locationPushService.receiveLocations(
                friendSyncService.friendLocations
            )
            reconcileFriendPresentations(
                acceptedUserIDs: acceptedFriendUserIDs
            )
        }
        .onChange(
            of: friendSyncService.ghostFriendUserIDs,
            initial: true
        ) { _, userIDs in
            locationPushService.receiveUnavailableFriends(userIDs)
            reconcileFriendPresentations(
                acceptedUserIDs: acceptedFriendUserIDs
            )
        }
    }

    private var lifecycleObservedContent: some View {
        outingObservedContent
        .onChange(of: friendSyncService.ownExplorationRevision) {
            restoreOwnExplorationIfAvailable()
        }
        .onChange(of: cityBoundary.cityCellIDs) {
            refreshCityProgress()
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
                friendSyncService.resumeGhostModeSynchronization()
                locationTracker.resumeTrackingIfNeeded()
                synchronizeLocationPushRegistration()
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
        .sheet(item: $selectedFriendProfile) { selection in
            FriendProfileSheet(
                userID: selection.userID,
                service: friendSyncService,
                onOpenDirections: {
                    dockSelection = .explore
                    presentNavigationOptions(selection.userID)
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Explore

    private var selectedOutingPlanEventID: String? {
        selectedMapDetail?.outingEventID
    }

    private func exploreTab() -> some View {
        let outingPlans = mapOutingPlans

        return MapDetailSplitView(isPresented: true) {
            MapEventsPanelView(
                outings: outingPlans,
                showsDetail: selectedMapDetail?.friendUserID != nil,
                selectedEventID: selectedOutingPlanEventID,
                currentLocation: locationTracker.lastLocation,
                isLoading: outingPlanService.isLoading,
                hasLoadError: outingPlanService.hasLoadError,
                onRetry: { outingPlanService.retryFailedObservations() },
                isListActive: dockSelection == .explore && scenePhase == .active,
                onVisibleEventIDsChange: { visibleRosterEventIDs = $0 },
                onSetAttendance: { eventID, shouldAttend in
                    setOutingAttendance(shouldAttend, eventID: eventID)
                },
                onEdit: { eventID in
                    guard let outing = outingPlans[eventID], outing.isCurrentUser else { return }
                    pendingOutingCoordinate = nil
                    editingOutingEvent = outing.plan
                    outingComposerDetent = .large
                    outingComposerVisible = true
                },
                onOpenDirections: presentOutingNavigationOptions,
                onSelect: { eventID in
                    selectedMapDetail = .outing(eventID)
                    centerOnOutingPlanEventID = eventID
                }
            ) {
                if let userID = selectedMapDetail?.friendUserID {
                    FriendProfilePanel(
                        userID: userID,
                        service: friendSyncService,
                        onDismiss: { selectedMapDetail = nil },
                        onOpenDirections: { presentNavigationOptions(userID) }
                    )
                    .id(userID)
                }
            }
        } map: {
            ZStack(alignment: .topTrailing) {
                MapWithFogView(
                    locationTracker: locationTracker,
                    discoveredCellIDs: locationTracker.discoveredCellIDs,
                    cityBoundaryCoordinates: cityBoundary.boundaryCoordinates,
                    friendLocations: friendSyncService.friendLocations,
                    freshFriendLocationUserIDs:
                        friendSyncService.freshFriendLocationUserIDs,
                    refreshingFriendLocationUserIDs:
                        locationPushService.refreshingFriendUserIDs,
                    outingPlans: outingPlans,
                    userExplorationProgress: cityProgress,
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
                    selectedFriendProfileUserID: selectedMapDetail?.friendUserID,
                    showsHeatMap: heatMapEnabled,
                    heatMapCellData: locationTracker.heatMapCellData,
                    heatMapRevision: locationTracker.heatMapRevision,
                    onJoinFriend: presentNavigationOptions,
                    onSelectFriend: presentMapFriendProfile,
                    onViewFriendProfile: presentMapFriendProfile,
                    onSelectOutingPlan: { eventID in
                        selectedMapDetail = .outing(eventID)
                    },
                    onCreateEvent: { coordinate in
                        guard CLLocationCoordinate2DIsValid(coordinate),
                              !outingComposerVisible else {
                            return
                        }
                        selectedMapDetail = nil
                        editingOutingEvent = nil
                        pendingOutingCoordinate = coordinate
                        outingComposerDetent =
                            OutingComposerPresentation.creationDetent
                        outingComposerVisible = true
                    }
                )

                ownExplorationStatusOverlay
                    .modifier(MapContentSafeArea())

                if selectedMapDetail?.friendUserID == nil {
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
                    .modifier(MapContentSafeArea(edges: [.top, .trailing]))
                }
            }
            .overlay(alignment: .bottom) {
                HStack(alignment: .bottom) {
                    GhostModeMapControl(service: friendSyncService)

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
                .modifier(MapContentSafeArea(edges: [.bottom, .horizontal]))
            }
        }
        .sheet(isPresented: $filterSheetVisible) {
            MapFiltersSheet(
                heatMapEnabled: $heatMapEnabled
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
            "Itinéraire vers \(selectedNavigationFriendName)",
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
        .alert(
            "Itinéraire vers \(selectedOutingNavigationName)",
            isPresented: outingNavigationAlertIsPresented
        ) {
            Button("Google Maps") {
                openGoogleMapsForSelectedOuting()
            }

            if canOpenNaverMapForSelectedOuting {
                Button("Naver Map · À pied") {
                    openNaverMapForSelectedOuting()
                }
            }

            Button("Annuler", role: .cancel) {}
        } message: {
            Text(selectedOutingNavigationMessage)
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

    private func presentOutingNavigationOptions(eventID: String) {
        guard currentOutingNavigationDestination(for: eventID) != nil else {
            return
        }
        selectedOutingNavigationEventID = eventID
    }

    private func presentMapFriendProfile(_ userID: String) {
        guard acceptedFriendUserIDs.contains(userID) else { return }
        selectedMapDetail = .friend(userID)
        guard !friendSyncService.ghostFriendUserIDs.contains(userID),
              let location = friendSyncService.friendLocation(for: userID) else {
            return
        }
        locationPushService.requestRefresh(for: userID, currentLocation: location)
    }

    private func presentFriendProfile(_ userID: String) {
        guard acceptedFriendUserIDs.contains(userID) else { return }
        dockSelection = .explore
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

    private var outingNavigationAlertIsPresented: Binding<Bool> {
        Binding(
            get: { selectedOutingNavigationEventID != nil },
            set: { isPresented in
                if !isPresented {
                    selectedOutingNavigationEventID = nil
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

        openGoogleMaps(
            to: externalMapNavigationDestination(for: destination)
        )
    }

    private func openGoogleMapsForSelectedOuting() {
        guard let destination = selectedOutingNavigationDestination else {
            selectedOutingNavigationEventID = nil
            return
        }

        openGoogleMaps(to: destination)
    }

    private func openGoogleMaps(
        to destination: ExternalMapNavigationDestination
    ) {
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

        openNaverMap(
            to: externalMapNavigationDestination(for: destination)
        )
    }

    private func openNaverMapForSelectedOuting() {
        guard let destination = selectedOutingNavigationDestination else {
            selectedOutingNavigationEventID = nil
            return
        }

        openNaverMap(to: destination)
    }

    private func openNaverMap(
        to destination: ExternalMapNavigationDestination
    ) {
        guard let url = naverMapURL(for: destination),
              UIApplication.shared.canOpenURL(url) else {
            return
        }
        UIApplication.shared.open(url)
    }

    private func canOpenNaverMap(
        for destination: ExternalMapNavigationDestination
    ) -> Bool {
        guard isInsideNaverMapCoverage(destination.coordinate),
              let url = naverMapURL(for: destination) else {
            return false
        }
        return UIApplication.shared.canOpenURL(url)
    }

    private func naverMapURL(
        for destination: ExternalMapNavigationDestination
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
        return canOpenNaverMap(
            for: externalMapNavigationDestination(for: destination)
        )
    }

    private var selectedOutingNavigationDestination: ExternalMapNavigationDestination? {
        guard let eventID = selectedOutingNavigationEventID else { return nil }
        return currentOutingNavigationDestination(for: eventID)
    }

    private var selectedOutingNavigationName: String {
        selectedOutingNavigationDestination?.displayName ?? "cet événement"
    }

    private var selectedOutingNavigationMessage: String {
        guard let eventID = selectedOutingNavigationEventID,
              let outing = mapOutingPlans[eventID] else {
            return "Le lieu de cet événement n’est plus disponible."
        }

        return outing.plan.address
            ?? "L’itinéraire utilisera le lieu enregistré pour cet événement."
    }

    private var canOpenNaverMapForSelectedOuting: Bool {
        guard let destination = selectedOutingNavigationDestination else {
            return false
        }
        return canOpenNaverMap(for: destination)
    }

    private func currentOutingNavigationDestination(
        for eventID: String
    ) -> ExternalMapNavigationDestination? {
        guard let outing = mapOutingPlans[eventID] else { return nil }
        let coordinate = outing.plan.coordinate
        guard CLLocationCoordinate2DIsValid(coordinate),
              coordinate.latitude.isFinite,
              coordinate.longitude.isFinite else {
            return nil
        }

        return ExternalMapNavigationDestination(
            displayName: outing.plan.placeName,
            coordinate: MapUserCoordinate(coordinate)
        )
    }

    private func currentNavigationDestination(
        for userID: String
    ) -> FriendNavigationDestination? {
        guard acceptedFriendUserIDs.contains(userID),
              !friendSyncService.ghostFriendUserIDs.contains(userID),
              let location = friendSyncService.friendLocation(for: userID),
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

    private func externalMapNavigationDestination(
        for destination: FriendNavigationDestination
    ) -> ExternalMapNavigationDestination {
        ExternalMapNavigationDestination(
            displayName: destination.displayName,
            coordinate: destination.coordinate
        )
    }

    private func reconcileFriendPresentations(
        acceptedUserIDs: Set<String>
    ) {
        if let userID = centerOnFriendUserID,
           (!acceptedUserIDs.contains(userID)
            || currentNavigationDestination(for: userID) == nil) {
            centerOnFriendUserID = nil
        }

        if let userID = friendNavigationSelection?.userID,
           (!acceptedUserIDs.contains(userID)
            || currentNavigationDestination(for: userID) == nil) {
            friendNavigationSelection = nil
        }

        if let userID = selectedMapDetail?.friendUserID,
           !acceptedUserIDs.contains(userID) {
            selectedMapDetail = nil
        }

        if let userID = selectedFriendProfile?.userID,
           !acceptedUserIDs.contains(userID) {
            selectedFriendProfile = nil
        }
    }

    // MARK: - Friends

    private func friendSummaries(
        locations: [String: FriendLocation]
    ) -> [FriendMapSummary] {
        friendSyncService.acceptedFriends
            .map { friend in
                let isGhostModeEnabled = friend.isGhostModeEnabled
                    || friendSyncService.ghostFriendUserIDs.contains(friend.userID)
                let location = isGhostModeEnabled ? nil : locations[friend.userID]
                let isLocationFresh =
                    friendSyncService.freshFriendLocationUserIDs.contains(
                        friend.userID
                    )

                return FriendMapSummary(
                    userID: friend.userID,
                    displayName: location?.displayName
                        ?? friend.displayName,
                    avatarID: friend.avatarID,
                    profileColorHex: ProfileColor.normalizedHex(
                        location?.profileColorHex
                            ?? friend.profileColorHex
                    ) ?? ProfileColor.generatedHex(seed: friend.userID),
                    locationSampledAt: location?.sampledAt,
                    spotEnteredAt: location?.spotEnteredAt,
                    isLocationFresh: !isGhostModeEnabled && isLocationFresh,
                    isGhostModeEnabled: isGhostModeEnabled
                )
            }
            .sorted { lhs, rhs in
                lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
            }
    }

    private func showFriendOnMap(_ friend: FriendMapSummary) {
        guard friend.canShowOnMap,
              currentNavigationDestination(for: friend.userID) != nil else { return }
        centerOnFriendUserID = friend.userID
        dockSelection = .explore
    }

    private func synchronizeLocationPushRegistration() {
        locationPushService.synchronizeRegistration(
            userID: FirebaseService.shared.currentUserId,
            trackingEnabled: locationTracker.trackingEnabled,
            backgroundTrackingEnabled:
                locationTracker.backgroundTrackingEnabled,
            locationSharingAllowed: friendSyncService.isLocationSharingAllowed,
            authorizationStatus: locationTracker.authorizationStatus
        )
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

        func declines(for plan: OutingPlan) -> [MapOutingAttendee] {
            outingAttendanceService.visibleDeclines(for: plan)
            .filter {
                plan.ownerID != currentUserID
                    || acceptedFriendUserIDs.contains($0.participantID)
            }
            .map { decline in
                MapOutingAttendee(
                    userID: decline.participantID,
                    displayName: decline.displayName,
                    avatarID: decline.avatarID
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
                    organizer: MapOutingAttendee(
                        userID: ownerID,
                        displayName: displayName.isEmpty
                            ? plan.displayName
                            : displayName,
                        avatarID: avatarID
                    ),
                    profileColorHex:
                        ProfileColor.normalizedHex(profileColorHex)
                        ?? ProfileColor.generatedHex(seed: ownerID),
                    isCurrentUser: true,
                    rosterState: outingAttendanceService.rosterState(
                        eventIDValue: eventID
                    ),
                    participationState: .notRequested,
                    attendees: attendees(for: plan),
                    declines: declines(for: plan),
                    isAttendanceUpdating: false
                )
                return
            }

            guard let friend = acceptedFriendsByUserID[ownerID] else {
                return
            }
            result[eventID] = MapOutingPlan(
                plan: plan,
                organizer: MapOutingAttendee(
                    userID: ownerID,
                    displayName: friend.displayName,
                    avatarID: friend.avatarID
                ),
                profileColorHex:
                    ProfileColor.normalizedHex(friend.profileColorHex)
                    ?? ProfileColor.generatedHex(seed: ownerID),
                isCurrentUser: false,
                rosterState: outingAttendanceService.rosterState(
                    eventIDValue: eventID
                ),
                participationState: outingAttendanceService
                    .participationState(
                        eventIDValue: eventID,
                        publicationIDValue: plan.publicationIDValue
                    ),
                attendees: attendees(for: plan),
                declines: declines(for: plan),
                isAttendanceUpdating:
                    outingAttendanceService.updatingEventIDs.contains(eventID)
            )
        }
    }

    private func reconcileSelectedOutingPlan() {
        let outingPlans = mapOutingPlans

        if let selectedOutingPlanEventID,
           outingPlans[selectedOutingPlanEventID] == nil {
            self.selectedMapDetail = nil
        }

        if let selectedOutingNavigationEventID,
           outingPlans[selectedOutingNavigationEventID] == nil {
            self.selectedOutingNavigationEventID = nil
        }
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
            acceptedFriendUserIDs: acceptedFriendUserIDs,
            selectedEventID: selectedOutingPlanEventID,
            visibleRosterEventIDs: visibleRosterEventIDs
        )
    }

    private func setOutingAttendance(
        _ shouldAttend: Bool,
        eventID: String
    ) {
        guard let event = outingPlanService.events[eventID],
              acceptedFriendUserIDs.contains(event.ownerID) else {
            outingAttendanceErrorMessage = "Cet événement n’est plus disponible."
            return
        }

        switch outingAttendanceService.participationState(
            eventIDValue: eventID,
            publicationIDValue: event.publicationIDValue
        ) {
        case .attending:
            if shouldAttend { return }
        case .declined:
            if !shouldAttend { return }
        case .notResponded:
            break
        case .notRequested, .loading:
            outingAttendanceErrorMessage =
                "Ta participation est encore en cours de vérification."
            return
        case .unavailable:
            outingAttendanceErrorMessage =
                "Ta participation est momentanément indisponible."
            return
        }
        Task {
            do {
                try await outingAttendanceService.setResponse(
                    shouldAttend ? .attending : .declined,
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
        guard !isProfileAccountFlowActive,
              friendSyncService.isProfileReady,
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

                // The account flow may have opened while the event was loading.
                guard !isProfileAccountFlowActive else { return }
                dockSelection = .explore
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
        guard !isProfileAccountFlowActive,
              friendSyncService.isProfileReady,
              let route = notificationService.pendingFriendRequestRoute else {
            return
        }

        dockSelection = .friends
        notificationService.consume(route)
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

// MARK: - Ghost mode

private struct GhostModeMapControl: View {
    @ObservedObject var service: FriendSyncService
    @State private var errorDetailsPresented = false
    @State private var conflictDetailsPresented = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let conflictMessage = service.ghostModeConflictMessage {
                Button {
                    conflictDetailsPresented = true
                } label: {
                    Label("Visibilité mise à jour", systemImage: "info.circle")
                }
                .buttonStyle(.glass)
                .accessibilityHint(
                    "Lire pourquoi ton précédent choix n’a pas été appliqué"
                )
                .alert(
                    "Visibilité mise à jour",
                    isPresented: $conflictDetailsPresented
                ) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text(conflictMessage)
                }
            }

            if service.ghostModeErrorMessage != nil {
                Label("Réessayer", systemImage: "exclamationmark.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if service.isGhostModePending {
                Text("En attente")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if service.isGhostModeEnabled {
                Text("Indisponible")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            modeButton
        }
    }

    private var modeButton: some View {
        Button {
            if service.ghostModeErrorMessage != nil {
                errorDetailsPresented = true
            } else if service.isGhostModePending {
                service.retryGhostModeChange()
            } else {
                service.setGhostModeEnabled(!service.isGhostModeEnabled)
            }
        } label: {
            Text("👻")
                .accessibilityHidden(true)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .controlSize(.large)
        .disabled(!service.canChangeGhostMode)
        .accessibilityLabel("Mode fantôme")
        .accessibilityValue(accessibilityStatus)
        .accessibilityHint(
            service.isGhostModePending || service.ghostModeErrorMessage != nil
                ? "Réessayer la synchronisation de ton choix"
                : service.isGhostModeEnabled
                    ? "Reprendre le partage de ta position"
                    : "Masquer ta position à tous tes amis"
        )
        .alert(
            "Mode fantôme en attente",
            isPresented: $errorDetailsPresented
        ) {
            Button("Réessayer") {
                service.retryGhostModeChange()
            }
            Button("Fermer", role: .cancel) {}
        } message: {
            Text(service.ghostModeErrorMessage ?? "Vérifie ta connexion et réessaie.")
        }
    }

    private var accessibilityStatus: String {
        if service.isGhostModePending || service.ghostModeErrorMessage != nil {
            return service.isGhostModeEnabled
                ? "Activation en attente"
                : "Désactivation en attente"
        }
        return service.isGhostModeEnabled ? "Activé" : "Désactivé"
    }
}

struct GhostModeStatusView: View {
    @ObservedObject var service: FriendSyncService

    var body: some View {
        if service.isGhostModePending {
            Label(
                service.isGhostModeEnabled
                    ? "Activation en attente"
                    : "Désactivation en attente",
                systemImage: "clock"
            )
            .foregroundStyle(.secondary)

            Text(
                service.isGhostModeEnabled
                    ? "En attente de confirmation. Ta dernière position partagée peut rester visible jusque-là."
                    : "Ta position reste masquée jusqu’à la confirmation."
            )
            .font(.footnote)
            .foregroundStyle(.secondary)
        } else if service.isGhostModeEnabled {
            Text("👻 Indisponible pour tes amis")
                .accessibilityLabel("Indisponible pour tes amis, mode fantôme activé")
                .foregroundStyle(.secondary)
        } else {
            Text("Mode fantôme désactivé")
                .foregroundStyle(.secondary)
        }

        if let conflictMessage = service.ghostModeConflictMessage {
            Label(conflictMessage, systemImage: "info.circle")
                .foregroundStyle(.secondary)
        }

        if let errorMessage = service.ghostModeErrorMessage {
            Label(errorMessage, systemImage: "exclamationmark.triangle")
                .foregroundStyle(.secondary)

            Button("Réessayer la synchronisation") {
                service.retryGhostModeChange()
            }
            .disabled(!service.canChangeGhostMode)
        }
    }
}

// MARK: - Map filters

private struct MapFiltersSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var heatMapEnabled: Bool

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
