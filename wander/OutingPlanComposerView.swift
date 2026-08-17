//
//  OutingPlanComposerView.swift
//  wander
//

import CoreLocation
import MapKit
import SwiftUI
import UIKit

@MainActor
struct OutingPlanComposerView: View {
    private enum LoadingState {
        case loading
        case loaded
        case failed(String)
    }

    let displayName: String

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var notificationService = NotificationService.shared

    @State private var loadingState: LoadingState = .loading
    @State private var existingPlan: OutingPlan?
    @State private var selectedCoordinate: CLLocationCoordinate2D?
    @State private var placeName = ""
    @State private var address: String?
    @State private var plannedAt: Date
    @State private var isResolvingAddress = false
    @State private var isWriting = false
    @State private var writeErrorMessage: String?
    @State private var cancellationConfirmationVisible = false
    @State private var activeReverseGeocoding: MKReverseGeocodingRequest?
    @State private var reverseGeocodingRequestID: UUID?

    private let planningWindowStart: Date
    private let service: OutingPlanService
    private let eventIDToLoad: String?

    init(
        displayName: String,
        initialCoordinate: CLLocationCoordinate2D?,
        editingEvent: OutingPlan? = nil
    ) {
        let referenceDate = Date()
        let coordinate = editingEvent?.coordinate ?? initialCoordinate

        self.displayName = displayName
        self.planningWindowStart = referenceDate
        self.service = OutingPlanService.shared
        self.eventIDToLoad = editingEvent?.eventIDValue
        _loadingState = State(
            initialValue: editingEvent == nil ? .loaded : .loading
        )
        _existingPlan = State(initialValue: editingEvent)
        _selectedCoordinate = State(initialValue: coordinate)
        _placeName = State(
            initialValue: editingEvent?.placeName
                ?? (coordinate == nil ? "" : "Lieu sélectionné")
        )
        _address = State(initialValue: editingEvent?.address)
        _plannedAt = State(
            initialValue: editingEvent?.plannedAt
                ?? referenceDate.addingTimeInterval(60 * 60)
        )
    }

    var body: some View {
        NavigationStack {
            Group {
                switch loadingState {
                case .loading:
                    ProgressView("Chargement de ton événement…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .loaded:
                    composerForm
                case .failed(let message):
                    ContentUnavailableView {
                        Label(
                            "Événement indisponible",
                            systemImage: "icloud.slash"
                        )
                    } description: {
                        Text(message)
                    } actions: {
                        Button("Réessayer") {
                            Task {
                                await loadEvent()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
            .navigationTitle(
                existingPlan == nil ? "Nouvel événement" : "Modifier l’événement"
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") {
                        dismiss()
                    }
                    .disabled(isWriting)
                }

                if case .loaded = loadingState {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(existingPlan == nil ? "Publier" : "Enregistrer") {
                            publishPlan()
                        }
                        .disabled(!canPublish || isWriting)
                    }
                }
            }
        }
        .interactiveDismissDisabled(isWriting)
        .task {
            await loadEvent()
        }
        .onDisappear {
            cancelReverseGeocoding()
        }
        .confirmationDialog(
            "Annuler cet événement ?",
            isPresented: $cancellationConfirmationVisible,
            titleVisibility: .visible
        ) {
            Button("Annuler l’événement", role: .destructive) {
                cancelPlan()
            }
            Button("Garder l’événement", role: .cancel) {}
        } message: {
            Text("L’événement publié sera supprimé.")
        }
    }

    private var composerForm: some View {
        Form {
            Section {
                if let selectedCoordinate {
                    LabeledContent("Lieu") {
                        VStack(alignment: .trailing, spacing: 3) {
                            Text(
                                placeName.isEmpty
                                    ? "Lieu sélectionné"
                                    : placeName
                            )

                            if isResolvingAddress {
                                ProgressView("Adresse…")
                                    .controlSize(.small)
                            } else if let address {
                                Text(address)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.trailing)
                            }

                            Text(coordinateText(selectedCoordinate))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                } else {
                    Label(
                        "Le point sélectionné n’est plus disponible.",
                        systemImage: "mappin.slash"
                    )
                    .foregroundStyle(.secondary)
                }
            } header: {
                Text("Lieu")
            }

            Section {
                DatePicker(
                    "Heure prévue",
                    selection: $plannedAt,
                    in: planningDateRange,
                    displayedComponents: [.date, .hourAndMinute]
                )
            } header: {
                Text("Quand ?")
            } footer: {
                Text("Choisis une heure dans les prochaines 24 heures.")
            }

            Section {
                Toggle(
                    "Recevoir les notifications sociales",
                    isOn: notificationsBinding
                )

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
                    "Ce réglage ne bloque jamais la publication. Il permet de recevoir les demandes d’amis et les prochains événements de tes amis acceptés."
                )
            }

            if let writeErrorMessage {
                Section {
                    Label(
                        writeErrorMessage,
                        systemImage: "exclamationmark.triangle"
                    )
                    .foregroundStyle(.red)
                }
            }

            if existingPlan != nil {
                Section {
                    Button("Annuler cet événement", role: .destructive) {
                        cancellationConfirmationVisible = true
                    }
                    .disabled(isWriting)
                }
            }

            if isWriting {
                Section {
                    ProgressView(
                        existingPlan == nil
                            ? "Publication…"
                            : "Enregistrement…"
                    )
                }
            }
        }
    }

    private var planningDateRange: ClosedRange<Date> {
        ClosedRange(
            uncheckedBounds: (
                lower: planningWindowStart,
                upper: planningWindowStart.addingTimeInterval(
                    OutingPlan.maximumPlanningInterval
                )
            )
        )
    }

    private var canPublish: Bool {
        let referenceDate = Date()
        return selectedCoordinate != nil
            && !placeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && plannedAt > referenceDate
            && plannedAt.timeIntervalSince(referenceDate)
                <= OutingPlan.maximumPlanningInterval
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

    private func loadEvent() async {
        guard let eventIDToLoad else {
            loadingState = .loaded
            if let selectedCoordinate {
                resolveAddress(for: selectedCoordinate)
            }
            return
        }
        loadingState = .loading
        writeErrorMessage = nil

        do {
            guard let plan = try await service.fetchEvent(
                eventIDValue: eventIDToLoad
            ) else {
                loadingState = .failed("Cet événement n’existe plus.")
                return
            }
            existingPlan = plan

            selectedCoordinate = plan.coordinate
            placeName = plan.placeName
            address = plan.address
            plannedAt = validPlanningDate(plan.plannedAt)

            loadingState = .loaded
        } catch {
            loadingState = .failed(error.localizedDescription)
        }
    }

    private func validPlanningDate(_ date: Date) -> Date {
        guard planningDateRange.contains(date), date > Date() else {
            return min(
                Date().addingTimeInterval(60 * 60),
                planningDateRange.upperBound
            )
        }
        return date
    }

    private func resolveAddress(for coordinate: CLLocationCoordinate2D) {
        let location = CLLocation(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
        )
        guard let request = MKReverseGeocodingRequest(location: location) else {
            return
        }

        let requestID = UUID()
        reverseGeocodingRequestID = requestID
        activeReverseGeocoding = request
        isResolvingAddress = true

        request.getMapItems { mapItems, _ in
            guard reverseGeocodingRequestID == requestID else { return }

            activeReverseGeocoding = nil
            reverseGeocodingRequestID = nil
            isResolvingAddress = false

            guard let mapItem = mapItems?.first else { return }
            placeName = resultTitle(for: mapItem)
            address = formattedAddress(for: mapItem)
        }
    }

    private func publishPlan() {
        guard let selectedCoordinate else { return }

        isWriting = true
        writeErrorMessage = nil
        cancelReverseGeocoding()

        let draft = OutingPlanDraft(
            displayName: publicationDisplayName,
            placeName: placeName,
            address: address,
            coordinate: selectedCoordinate,
            plannedAt: plannedAt,
            timeZoneIdentifier: TimeZone.current.identifier
        )

        Task {
            do {
                _ = try await service.publish(
                    draft,
                    eventIDValue: existingPlan?.eventIDValue
                )
                dismiss()
            } catch {
                isWriting = false
                writeErrorMessage = error.localizedDescription
            }
        }
    }

    private func cancelPlan() {
        isWriting = true
        writeErrorMessage = nil
        cancelReverseGeocoding()

        Task {
            do {
                guard let eventID = existingPlan?.eventIDValue else { return }
                try await service.cancel(eventIDValue: eventID)
                dismiss()
            } catch {
                isWriting = false
                writeErrorMessage = error.localizedDescription
            }
        }
    }

    private func openSettings() {
        guard let settingsURL = URL(
            string: UIApplication.openSettingsURLString
        ) else {
            return
        }
        UIApplication.shared.open(settingsURL)
    }

    private func cancelReverseGeocoding() {
        activeReverseGeocoding?.cancel()
        activeReverseGeocoding = nil
        reverseGeocodingRequestID = nil
        isResolvingAddress = false
    }

    private func resultTitle(for mapItem: MKMapItem) -> String {
        if let name = mapItem.name?.trimmingCharacters(
            in: .whitespacesAndNewlines
        ), !name.isEmpty {
            return String(name.prefix(OutingPlan.maximumPlaceNameLength))
        }

        if let shortAddress = mapItem.address?.shortAddress?.trimmingCharacters(
            in: .whitespacesAndNewlines
        ), !shortAddress.isEmpty {
            return String(
                shortAddress.prefix(OutingPlan.maximumPlaceNameLength)
            )
        }

        return "Lieu sélectionné"
    }

    private func formattedAddress(for mapItem: MKMapItem) -> String? {
        let value = mapItem.addressRepresentations?.fullAddress(
            includingRegion: false,
            singleLine: true
        ) ?? mapItem.address?.fullAddress

        guard let normalized = value?.trimmingCharacters(
            in: .whitespacesAndNewlines
        ), !normalized.isEmpty,
              normalized.count <= OutingPlan.maximumAddressLength else {
            return nil
        }
        return normalized
    }

    private var publicationDisplayName: String {
        let normalized = displayName.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        let resolved = normalized.isEmpty ? "Explorer" : normalized
        return String(resolved.prefix(OutingPlan.maximumDisplayNameLength))
    }

    private func coordinateText(
        _ coordinate: CLLocationCoordinate2D
    ) -> String {
        String(
            format: "%.5f, %.5f",
            coordinate.latitude,
            coordinate.longitude
        )
    }
}
