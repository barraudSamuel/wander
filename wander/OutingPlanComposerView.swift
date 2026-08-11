//
//  OutingPlanComposerView.swift
//  wander
//

import CoreLocation
import MapKit
import SwiftUI

@MainActor
struct OutingPlanComposerView: View {
    private static let maximumSearchResultCount = 6
    private static let defaultCoordinate = CLLocationCoordinate2D(
        latitude: 10.7769,
        longitude: 106.7009
    )
    private static let defaultSpan = MKCoordinateSpan(
        latitudeDelta: 0.025,
        longitudeDelta: 0.025
    )

    private struct SearchResult: Identifiable {
        let id = UUID()
        let mapItem: MKMapItem
    }

    private enum LoadingState {
        case loading
        case loaded
        case failed(String)
    }

    let displayName: String

    @Environment(\.dismiss) private var dismiss

    @State private var loadingState: LoadingState = .loading
    @State private var existingPlan: OutingPlan?
    @State private var searchQuery = ""
    @State private var searchResults: [SearchResult] = []
    @State private var searchErrorMessage: String?
    @State private var selectedCoordinate: CLLocationCoordinate2D?
    @State private var placeName = ""
    @State private var address: String?
    @State private var plannedAt: Date
    @State private var mapPosition: MapCameraPosition
    @State private var visibleRegion: MKCoordinateRegion
    @State private var isSearching = false
    @State private var isResolvingAddress = false
    @State private var isWriting = false
    @State private var writeErrorMessage: String?
    @State private var cancellationConfirmationVisible = false
    @State private var activeSearch: MKLocalSearch?
    @State private var activeReverseGeocoding: MKReverseGeocodingRequest?
    @State private var searchRequestID: UUID?
    @State private var reverseGeocodingRequestID: UUID?

    private let planningWindowStart: Date
    private let service: OutingPlanService

    init(
        displayName: String,
        initialCoordinate: CLLocationCoordinate2D?
    ) {
        let referenceDate = Date()
        let coordinate = initialCoordinate ?? Self.defaultCoordinate
        let region = MKCoordinateRegion(
            center: coordinate,
            span: Self.defaultSpan
        )

        self.displayName = displayName
        self.planningWindowStart = referenceDate
        self.service = OutingPlanService.shared
        _plannedAt = State(
            initialValue: referenceDate.addingTimeInterval(60 * 60)
        )
        _mapPosition = State(initialValue: .region(region))
        _visibleRegion = State(initialValue: region)
    }

    var body: some View {
        NavigationStack {
            Group {
                switch loadingState {
                case .loading:
                    ProgressView("Chargement de ta sortie…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .loaded:
                    composerForm
                case .failed(let message):
                    ContentUnavailableView {
                        Label(
                            "Sortie indisponible",
                            systemImage: "icloud.slash"
                        )
                    } description: {
                        Text(message)
                    } actions: {
                        Button("Réessayer") {
                            Task {
                                await loadCurrentPlan()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
            .navigationTitle(
                existingPlan == nil ? "Dire où je vais" : "Modifier ma sortie"
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
            await loadCurrentPlan()
        }
        .onDisappear {
            cancelOutstandingMapRequests()
        }
        .confirmationDialog(
            "Annuler cette sortie ?",
            isPresented: $cancellationConfirmationVisible,
            titleVisibility: .visible
        ) {
            Button("Annuler la sortie", role: .destructive) {
                cancelPlan()
            }
            Button("Garder la sortie", role: .cancel) {}
        } message: {
            Text("La sortie publiée sera supprimée.")
        }
    }

    private var composerForm: some View {
        Form {
            Section {
                HStack {
                    TextField(
                        "Établissement ou adresse",
                        text: $searchQuery
                    )
                    .textInputAutocapitalization(.words)
                    .submitLabel(.search)
                    .onSubmit {
                        startSearch()
                    }

                    if isSearching {
                        ProgressView()
                    } else {
                        Button("Rechercher") {
                            startSearch()
                        }
                        .disabled(trimmedSearchQuery.isEmpty)
                    }
                }

                if let searchErrorMessage {
                    Label(
                        searchErrorMessage,
                        systemImage: "exclamationmark.triangle"
                    )
                    .foregroundStyle(.secondary)
                }

                ForEach(searchResults) { result in
                    Button {
                        select(result.mapItem)
                    } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(resultTitle(for: result.mapItem))
                                .foregroundStyle(.primary)

                            if let resultAddress = formattedAddress(
                                for: result.mapItem
                            ) {
                                Text(resultAddress)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                Text("Rechercher un lieu")
            } footer: {
                Text("La recherche utilise uniquement la zone visible sur la carte.")
            }

            Section("Choisir sur la carte") {
                MapReader { proxy in
                    Map(position: $mapPosition) {
                        if let selectedCoordinate {
                            Marker(
                                placeName.isEmpty
                                    ? "Lieu sélectionné"
                                    : placeName,
                                coordinate: selectedCoordinate
                            )
                        }
                    }
                    .mapStyle(.standard)
                    .onMapCameraChange(frequency: .onEnd) { context in
                        visibleRegion = context.region
                    }
                    .simultaneousGesture(
                        SpatialTapGesture()
                            .onEnded { event in
                                guard let coordinate = proxy.convert(
                                    event.location,
                                    from: .local
                                ) else {
                                    return
                                }
                                select(coordinate)
                            }
                    )
                }
                .frame(height: 260)
                .listRowInsets(EdgeInsets())

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
                        "Recherche un lieu ou touche la carte.",
                        systemImage: "hand.tap"
                    )
                    .foregroundStyle(.secondary)
                }
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
                    Button("Annuler cette sortie", role: .destructive) {
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

    private var trimmedSearchQuery: String {
        searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
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

    private func loadCurrentPlan() async {
        loadingState = .loading
        writeErrorMessage = nil

        do {
            let plan = try await service.fetchCurrentPlan()
            existingPlan = plan

            if let plan {
                selectedCoordinate = plan.coordinate
                placeName = plan.placeName
                address = plan.address
                plannedAt = validPlanningDate(plan.plannedAt)
                centerMap(on: plan.coordinate)
            }

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

    private func startSearch() {
        let query = trimmedSearchQuery
        guard !query.isEmpty else { return }

        activeSearch?.cancel()
        let requestID = UUID()
        searchRequestID = requestID
        searchErrorMessage = nil
        searchResults = []
        isSearching = true

        let request = MKLocalSearch.Request(
            naturalLanguageQuery: query,
            region: visibleRegion
        )
        request.regionPriority = .required
        request.resultTypes = [.address, .pointOfInterest]

        let search = MKLocalSearch(request: request)
        activeSearch = search
        search.start { response, error in
            guard searchRequestID == requestID else { return }

            isSearching = false
            activeSearch = nil
            searchRequestID = nil

            if let error {
                searchErrorMessage = messageForSearchError(error)
                return
            }

            let mapItems = response?.mapItems ?? []
            searchResults = mapItems
                .prefix(Self.maximumSearchResultCount)
                .map(SearchResult.init(mapItem:))

            if searchResults.isEmpty {
                searchErrorMessage = "Aucun lieu trouvé dans cette zone."
            }
        }
    }

    private func messageForSearchError(_ error: Error) -> String {
        if let networkMessage = networkSearchErrorMessage(for: error) {
            return networkMessage
        }

        if let mapError = error as? MKError {
            switch mapError.code {
            case .placemarkNotFound:
                return "Aucun lieu trouvé dans cette zone. Déplace la carte ou précise l’adresse."
            case .loadingThrottled:
                return "Trop de recherches ont été lancées. Patiente un instant puis réessaie."
            case .unknown, .serverFailure, .directionsNotFound, .decodingFailed:
                return "Apple Maps est momentanément indisponible. Réessaie."
            @unknown default:
                break
            }
        }

        return "La recherche a échoué. Réessaie."
    }

    private func networkSearchErrorMessage(for error: Error) -> String? {
        let nsError = error as NSError

        if nsError.domain == NSURLErrorDomain {
            switch nsError.code {
            case NSURLErrorNotConnectedToInternet:
                return "La recherche nécessite une connexion internet."
            case NSURLErrorNetworkConnectionLost, NSURLErrorTimedOut:
                return "La connexion a été interrompue. Réessaie."
            default:
                break
            }
        }

        guard let underlyingError = nsError.userInfo[NSUnderlyingErrorKey] as? Error else {
            return nil
        }
        return networkSearchErrorMessage(for: underlyingError)
    }

    private func select(_ mapItem: MKMapItem) {
        cancelReverseGeocoding()

        let coordinate = mapItem.location.coordinate
        selectedCoordinate = coordinate
        placeName = resultTitle(for: mapItem)
        address = formattedAddress(for: mapItem)
        writeErrorMessage = nil
        centerMap(on: coordinate)
    }

    private func select(_ coordinate: CLLocationCoordinate2D) {
        guard CLLocationCoordinate2DIsValid(coordinate) else { return }

        cancelReverseGeocoding()
        selectedCoordinate = coordinate
        placeName = "Lieu sélectionné"
        address = nil
        writeErrorMessage = nil
        resolveAddress(for: coordinate)
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
        cancelOutstandingMapRequests()

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
                _ = try await service.publish(draft)
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
        cancelOutstandingMapRequests()

        Task {
            do {
                try await service.cancelCurrentPlan()
                dismiss()
            } catch {
                isWriting = false
                writeErrorMessage = error.localizedDescription
            }
        }
    }

    private func centerMap(on coordinate: CLLocationCoordinate2D) {
        let region = MKCoordinateRegion(
            center: coordinate,
            span: Self.defaultSpan
        )
        mapPosition = .region(region)
        visibleRegion = region
    }

    private func cancelOutstandingMapRequests() {
        activeSearch?.cancel()
        activeSearch = nil
        searchRequestID = nil
        isSearching = false
        cancelReverseGeocoding()
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
