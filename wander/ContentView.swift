//
//  ContentView.swift
//  wander
//
//  Root view: map with fog-of-war overlay, city progress banner,
//  a floating location button, and a draggable debug drawer.
//
//  Created by Samuel Barraud on 17/06/2026.
//

import SwiftUI
import MapKit
import CoreLocation
import SwiftData
import UIKit

struct ContentView: View {
    @StateObject private var locationTracker = LocationTracker()
    @StateObject private var groupSyncService = GroupSyncService()
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext
    @AppStorage("profile.displayName") private var displayName = ""
    @AppStorage("profile.avatarImageData") private var avatarImageData = Data()

    @State private var debugDrawerVisible = false
    @State private var drawerExpanded = false
    @State private var profileCardVisible = false
    @State private var filterSheetVisible = false
    @State private var centerOnUser = false
    @State private var heatMapEnabled = false
    @State private var selectedFriendUserIDs: Set<String> = []
    @State private var knownFriendUserIDs: Set<String> = []

    @ObservedObject private var cityBoundary = CityBoundary.shared

    private let topControlHeight: CGFloat = 64
    private let drawerExpandedFraction: CGFloat = 0.55
    private let drawerCollapsedHeight: CGFloat = 120

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                MapWithFogView(
                    locationTracker: locationTracker,
                    discoveredCellIDs: Set(locationTracker.discoveredCells.map { $0.id }),
                    cityBoundaryCoordinates: cityBoundary.boundaryCoordinates,
                    groupMembers: otherGroupMembers,
                    centerOnUser: $centerOnUser,
                    showsHeatMap: heatMapEnabled,
                    friendCellIDsByUserID: filteredFriendCellIDsByUserID,
                    heatMapCellData: locationTracker.heatMapCellData
                )
                .ignoresSafeArea()

                VStack {
                    HStack(spacing: 8) {
                        cityProgressBanner
                        filterButton
                        avatarCircle
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)

                    Spacer()
                }

                VStack {
                    Spacer()
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

                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button {
                            centerOnUser = true
                        } label: {
                            Image(systemName: "location.fill")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(.ultraThinMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .padding(.trailing, 16)
                        .padding(.bottom, locationButtonBottomPadding(in: geometry))
                    }
                }

                ThreeFingerPressCatcher {
                    toggleDebugDrawerVisibility()
                }
                .frame(width: 0, height: 0)
                .allowsHitTesting(false)
            }
        }
        .onAppear {
            locationTracker.configure(with: modelContext)
            locationTracker.resumeTrackingIfNeeded()

            Task {
                await cityBoundary.load()
            }
            syncFriendFilterSelection()
        }
        .onChange(of: groupSyncService.friendCellIDsByUserID) { _, _ in
            syncFriendFilterSelection()
        }
        .onChange(of: locationTracker.newlyDiscoveredCellIDs) { _, newIDs in
            groupSyncService.pushCells(newIDs)
        }
        .onChange(of: locationTracker.lastLocation) { _, location in
            guard let location else { return }
            cityBoundary.detectCity(for: location.coordinate)
            groupSyncService.updateLocation(
                lat: location.coordinate.latitude,
                lng: location.coordinate.longitude,
                cellID: locationTracker.currentH3CellID,
                displayName: displayName.isEmpty ? "Explorer" : displayName
            )
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                if locationTracker.trackingEnabled {
                    locationTracker.applyTrackingMode(.foreground)
                }
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
    }

    // MARK: - Group members

    private var otherGroupMembers: [GroupMember] {
        guard let currentUserId = FirebaseService.shared.currentUserId else { return [] }
        return groupSyncService.groupMembers.values
            .filter { $0.userId != currentUserId && $0.location != nil }
    }

    private var friendScratchSummaries: [FriendScratchSummary] {
        groupSyncService.friendCellIDsByUserID
            .filter { !$0.value.isEmpty }
            .map { userID, cellIDs in
                FriendScratchSummary(
                    userID: userID,
                    displayName: groupSyncService.groupMembers[userID]?.displayName ?? "Explorer",
                    cellCount: cellIDs.count
                )
            }
            .sorted { lhs, rhs in
                lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
            }
    }

    private var filteredFriendCellIDsByUserID: [String: Set<String>] {
        groupSyncService.friendCellIDsByUserID.filter { userID, cellIDs in
            selectedFriendUserIDs.contains(userID) && !cellIDs.isEmpty
        }
    }

    private func syncFriendFilterSelection() {
        let currentUserIDs = Set(groupSyncService.friendCellIDsByUserID.keys)
        let newUserIDs = currentUserIDs.subtracting(knownFriendUserIDs)

        selectedFriendUserIDs.formUnion(newUserIDs)
        selectedFriendUserIDs.formIntersection(currentUserIDs)
        knownFriendUserIDs = currentUserIDs
    }

    // MARK: - City progress

    private var cityProgress: CityProgress? {
        guard !cityBoundary.cityCellIDs.isEmpty else { return nil }
        return cityBoundary.progress(against: locationTracker.discoveredCells)
    }

    private func locationButtonBottomPadding(in geometry: GeometryProxy) -> CGFloat {
        guard debugDrawerVisible else { return 16 }

        let drawerHeight = drawerExpanded
            ? geometry.size.height * drawerExpandedFraction
            : drawerCollapsedHeight

        return drawerHeight + 16
    }

    private func toggleDebugDrawerVisibility() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        withAnimation(.interpolatingSpring(stiffness: 300, damping: 30)) {
            debugDrawerVisible.toggle()

            if !debugDrawerVisible {
                drawerExpanded = false
            }
        }
    }

    private var avatarCircle: some View {
        Button {
            profileCardVisible = true
        } label: {
            ProfileAvatarView(imageData: avatarImageData, size: topControlHeight)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $profileCardVisible) {
            ProfileCardView(
                displayName: displayName,
                avatarImageData: avatarImageData,
                cityProgress: cityProgress,
                isTracking: locationTracker.isTracking
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
    }

    private var filterButton: some View {
        Button {
            filterSheetVisible = true
        } label: {
            Image(systemName: "line.3.horizontal.decrease")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.primary)
                .frame(width: topControlHeight, height: topControlHeight)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $filterSheetVisible) {
            MapFiltersSheet(
                heatMapEnabled: $heatMapEnabled,
                selectedFriendUserIDs: $selectedFriendUserIDs,
                friendScratchSummaries: friendScratchSummaries
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
    }

    private var cityProgressBanner: some View {
        VStack(spacing: 4) {
            if let progress = cityProgress {
                HStack(spacing: 6) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white)
                        .padding(4)
                        .background(Circle().fill(locationTracker.isTracking ? Color.green : Color.secondary.opacity(0.3)))
                    Text(progress.cityName)
                        .font(.caption.bold())
                        .foregroundColor(.primary)
                }

                Text("\(progress.percentageText) explored — \(progress.exploredCells) / \(progress.totalCells) cells")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.secondary.opacity(0.2))
                            .frame(height: 4)

                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.green)
                            .frame(width: geo.size.width * progress.percentage, height: 4)
                    }
                }
                .frame(height: 4)
            } else {
                HStack(spacing: 6) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white)
                        .padding(4)
                        .background(Circle().fill(locationTracker.isTracking ? Color.green : Color.secondary.opacity(0.3)))
                    Text("Calculating city progress…")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .frame(height: topControlHeight)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

private struct ProfileCardView: View {
    let displayName: String
    let avatarImageData: Data
    let cityProgress: CityProgress?
    let isTracking: Bool

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                ProfileAvatarView(imageData: avatarImageData, size: 108)

                VStack(spacing: 4) {
                    Text(displayName.isEmpty ? "Explorer" : displayName)
                        .font(.title2.bold())

                    Text(isTracking ? "Exploration active" : "Exploration en pause")
                        .font(.subheadline)
                        .foregroundStyle(isTracking ? .green : .secondary)
                }
            }

            VStack(spacing: 12) {
                ProfileInfoRow(
                    iconName: "map.fill",
                    title: "Ville",
                    value: cityProgress?.cityName ?? "Calcul en cours"
                )

                ProfileInfoRow(
                    iconName: "chart.pie.fill",
                    title: "Progression",
                    value: cityProgress?.percentageText ?? "-"
                )

                ProfileInfoRow(
                    iconName: "square.grid.3x3.fill",
                    title: "Cellules explorées",
                    value: exploredCellsText
                )
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .padding(.top, 48)
        .padding(.bottom, 20)
    }

    private var exploredCellsText: String {
        guard let cityProgress else { return "-" }
        return "\(cityProgress.exploredCells) / \(cityProgress.totalCells)"
    }
}

private struct FriendScratchSummary: Identifiable {
    let userID: String
    let displayName: String
    let cellCount: Int

    var id: String { userID }
}

private struct MapFiltersSheet: View {
    @Binding var heatMapEnabled: Bool
    @Binding var selectedFriendUserIDs: Set<String>

    let friendScratchSummaries: [FriendScratchSummary]

    var body: some View {
        NavigationStack {
            Form {
                Section("Carte") {
                    Toggle("Heat", isOn: $heatMapEnabled)
                }

                Section("Amis") {
                    if friendScratchSummaries.isEmpty {
                        Text("Aucun scratch ami")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(friendScratchSummaries) { summary in
                            Toggle(isOn: friendSelectionBinding(for: summary.userID)) {
                                HStack(spacing: 10) {
                                    Circle()
                                        .fill(Color(uiColor: FriendColor.color(for: summary.userID)))
                                        .frame(width: 12, height: 12)

                                    Text(summary.displayName)
                                        .lineLimit(1)

                                    Spacer()

                                    Text("\(summary.cellCount)")
                                        .font(.caption.monospacedDigit())
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Filtres")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func friendSelectionBinding(for userID: String) -> Binding<Bool> {
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

private struct ProfileInfoRow: View {
    let iconName: String
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.green)
                .frame(width: 34, height: 34)
                .background(Color.green.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            Text(value)
                .font(.subheadline.bold())
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, 14)
        .frame(height: 54)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

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

            let gestureRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(handlePress(_:)))
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

#Preview {
    ContentView()
}
