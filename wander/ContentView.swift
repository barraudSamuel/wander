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
    case ownProfile
    case friend(String)
    case outing(String)

    var profile: MapProfileSelection? {
        switch self {
        case .ownProfile: .currentUser
        case .friend(let userID): .friend(userID)
        case .outing: nil
        }
    }

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

    @State private var bottomList: MapBottomList?
    @State private var friendCodeInput = ""
    @State private var isProfileAccountFlowActive = false
    @State private var outingComposerVisible = false
    @State private var outingComposerDetent =
        OutingComposerPresentation.creationDetent
    @State private var editingOutingEvent: OutingPlan?
    @State private var pendingOutingCoordinate: CLLocationCoordinate2D?
    @State private var centerOnUser = false
    @State private var centerOnFriendUserID: String?
    @State private var centerOnOutingPlanEventID: String?
    @State private var selectedMapDetail: MapDetailSelection?
    @State private var visibleRosterEventIDs: Set<String> = []
    @State private var heatMapEnabled = false
    @State private var cityProgress: CityProgress?
    @State private var friendNavigationSelection: FriendSelection?
    @State private var selectedOutingNavigationEventID: String?
    @State private var pendingFriendDirectionsUserID: String?
    @State private var presentedProfile: MapProfileSelection?
    @State private var shouldFocusOwnProfile = true
    @State private var friendCameraRequest: MapFriendCameraRequest?
    @State private var outingAttendanceErrorMessage: String?

    #if DEBUG
    @State private var debugDrawerVisible = false
    @State private var drawerExpanded = false
    #endif

    var body: some View {
        lifecycleObservedContent
    }

    private var mapDockContent: some View {
        return GeometryReader { geometry in
            MotionDockView(
                selection: dockSelectionBinding,
                isEventsPresented: areEventsPresented,
                onToggleEvents: toggleEvents
            ) {
                exploreTab()
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

    private var areEventsPresented: Bool {
        bottomList == .events && selectedMapDetail?.profile == nil
    }

    private func toggleEvents() {
        guard !isProfileAccountFlowActive else { return }
        let shouldPresent = !areEventsPresented
        if selectedMapDetail?.profile != nil { selectedMapDetail = nil }
        bottomList = shouldPresent ? .events : nil
    }

    private var dockSelectionBinding: Binding<MotionDockSelection> {
        Binding(
            get: { bottomList == .friends ? .friends : .explore },
            set: { newSelection in
                guard !isProfileAccountFlowActive else { return }
                bottomList = newSelection == .friends ? .friends : nil
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
        .sheet(item: mapProfileSelection, onDismiss: mapProfileDidDismiss) { selection in
            Group {
                switch selection {
                case .currentUser:
                    OwnProfileSheet(
                        displayName: displayName, avatarID: avatarID,
                        profileColorHex: profileColorHex,
                        locationTracker: locationTracker, cityProgress: cityProgress,
                        isGhostModeEnabled: friendSyncService.isGhostModeEnabled,
                        onPreparePresentation: { sheetTop in
                            guard selectedMapDetail?.profile == selection,
                                  shouldFocusOwnProfile else { return }
                            friendCameraRequest = MapFriendCameraRequest(
                                target: selection, sheetTopInWindow: sheetTop
                            )
                        }
                    ) { summary in
                        ProfilePanelView(
                            displayName: $displayName,
                            avatarID: $avatarID,
                            profileColorHex: $profileColorHex,
                            friendCodeInput: $friendCodeInput,
                            locationTracker: locationTracker,
                            summary: summary,
                            heatMapEnabled: $heatMapEnabled,
                            onProfileColorSelected: { selectedColorHex in
                                friendSyncService.updateProfileColor(
                                    selectedColorHex, userInitiated: true
                                )
                            },
                            onAccountFlowStateChanged: { isProfileAccountFlowActive = $0 }
                        )
                    }
                case .friend(let userID):
                    FriendProfileSheet(
                        userID: userID,
                        service: friendSyncService,
                        onOpenDirections: {
                            pendingFriendDirectionsUserID = userID
                            selectedMapDetail = nil
                        },
                        onPreparePresentation: { sheetTop in
                            guard selectedMapDetail?.profile == selection,
                                  currentNavigationDestination(for: userID) != nil else { return }
                            friendCameraRequest = MapFriendCameraRequest(
                                target: selection, sheetTopInWindow: sheetTop
                            )
                        }
                    )
                }
            }
            .interactiveDismissDisabled(isProfileAccountFlowActive)
            .onAppear { presentedProfile = selection }
            .id(selection.id)
        }
    }

    // MARK: - Explore

    private var selectedOutingPlanEventID: String? {
        selectedMapDetail?.outingEventID
    }

    private func exploreTab() -> some View {
        let outingPlans = mapOutingPlans

        return MapDetailSplitView(
            isPresented: false,
            bottomList: $bottomList,
            areListsObscured: selectedMapDetail?.profile != nil
        ) {
            EmptyView()
        } events: {
            MapEventsPanelView(
                outings: outingPlans,
                selectedEventID: selectedOutingPlanEventID,
                currentLocation: locationTracker.lastLocation,
                isLoading: outingPlanService.isLoading,
                hasLoadError: outingPlanService.hasLoadError,
                onRetry: { outingPlanService.retryFailedObservations() },
                isListActive: areEventsPresented && scenePhase == .active,
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
            )
        } friends: {
            FriendsPanelView(
                service: friendSyncService,
                friends: friendSummaries(locations: friendSyncService.friendLocations),
                onShowOnMap: showFriendOnMap,
                onViewProfile: presentMapFriendProfile,
                isActive: bottomList == .friends && selectedMapDetail?.profile == nil
            )
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
                    resetMapOrientation: .constant(false),
                    centerOnFriendUserID: $centerOnFriendUserID,
                    centerOnOutingPlanEventID: $centerOnOutingPlanEventID,
                    pendingOutingCoordinate: pendingOutingCoordinate,
                    isEventCreationEnabled: !outingComposerVisible && !isProfileAccountFlowActive,
                    selectedOutingPlanEventID: selectedOutingPlanEventID,
                    selectedMapProfile: selectedMapDetail?.profile,
                    friendCameraRequest: friendCameraRequest,
                    showsHeatMap: heatMapEnabled,
                    heatMapCellData: locationTracker.heatMapCellData,
                    heatMapRevision: locationTracker.heatMapRevision,
                    onJoinFriend: presentNavigationOptions,
                    onSelectOwnProfile: { presentOwnProfile(focusOnMap: true) },
                    onSelectFriend: presentMapFriendProfile,
                    onViewFriendProfile: presentMapFriendProfile,
                    onSelectOutingPlan: { eventID in
                        guard !isProfileAccountFlowActive else { return }
                        selectedMapDetail = .outing(eventID)
                    },
                    onCreateEvent: { coordinate in
                        guard !isProfileAccountFlowActive,
                              CLLocationCoordinate2DIsValid(coordinate),
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

                MapImageButton(assetName: "TabIconProfile", label: "Mon profil") {
                    presentOwnProfile(focusOnMap: false)
                }
                .accessibilityHint("Ouvrir mon profil et les réglages de la carte")
                .accessibilityIdentifier("map-own-profile")
                .padding(.top, 8)
                .padding(.trailing, 16)
                .modifier(MapContentSafeArea(edges: [.top, .trailing]))
            }
            .overlay(alignment: .bottomTrailing) {
                Button {
                    centerOnUser = true
                } label: {
                    Image(systemName: "scope")
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .controlSize(.large)
                .accessibilityLabel("Recentrer la carte sur ma position")
                .padding(.horizontal)
                .padding(.bottom, 20)
                .modifier(MapContentSafeArea(edges: [.bottom, .horizontal]))
            }
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

    private func presentOwnProfile(focusOnMap: Bool) {
        guard !isProfileAccountFlowActive else { return }
        // MapKit can echo a programmatic pin selection after the sheet opens.
        guard selectedMapDetail != .ownProfile else { return }
        shouldFocusOwnProfile = focusOnMap
        if !focusOnMap { friendCameraRequest = nil }
        selectedMapDetail = .ownProfile
    }

    private func presentMapFriendProfile(_ userID: String) {
        guard !isProfileAccountFlowActive else { return }
        guard acceptedFriendUserIDs.contains(userID) else { return }
        guard selectedMapDetail?.friendUserID != userID else { return }
        selectedMapDetail = .friend(userID)
        guard !friendSyncService.ghostFriendUserIDs.contains(userID),
              let location = friendSyncService.friendLocation(for: userID) else {
            return
        }
        locationPushService.requestRefresh(for: userID, currentLocation: location)
    }

    private var mapProfileSelection: Binding<MapProfileSelection?> {
        Binding(
            get: { selectedMapDetail?.profile },
            set: { selection in
                if let selection {
                    selectedMapDetail = selection.detailSelection
                } else if selectedMapDetail?.profile != nil {
                    // An event may already have replaced the profile selection.
                    selectedMapDetail = nil
                }
            }
        )
    }

    private func recenterAfterProfile(_ profile: MapProfileSelection) {
        guard selectedMapDetail == nil,
              !outingComposerVisible else { return }
        switch profile {
        case .currentUser:
            guard shouldFocusOwnProfile, locationTracker.lastLocation != nil else { return }
        case .friend(let userID):
            guard currentNavigationDestination(for: userID) != nil else { return }
        }
        friendCameraRequest = MapFriendCameraRequest(target: profile)
    }

    private func mapProfileDidDismiss() {
        // Switching sheet items must not recenter over the newly opened profile.
        guard selectedMapDetail?.profile == nil else { return }
        let dismissedProfile = presentedProfile
        presentedProfile = nil
        if let dismissedProfile {
            recenterAfterProfile(dismissedProfile)
        }
        guard let userID = pendingFriendDirectionsUserID else { return }
        pendingFriendDirectionsUserID = nil
        presentNavigationOptions(userID)
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
        presentMapFriendProfile(friend.userID)
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
                bottomList = .events
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

        if selectedMapDetail?.profile != nil { selectedMapDetail = nil }
        bottomList = .friends
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
