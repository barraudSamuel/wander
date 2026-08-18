//
//  ShareComposerView.swift
//  WanderShareExtension
//

import CoreLocation
import Foundation
import SwiftUI

@MainActor
struct ShareComposerView: View {
    private enum LoadingState {
        case loading
        case loaded
        case failed(String)
    }

    let inputItems: [NSExtensionItem]
    let onCancel: () -> Void
    let onComplete: () -> Void

    @State private var loadingState: LoadingState = .loading
    @State private var session: ShareExtensionSession?
    @State private var place: ResolvedSharedPlace?
    @State private var category: OutingCategory?
    @State private var plannedAt: Date
    @State private var isPublishing = false
    @State private var publicationErrorMessage: String?

    private let planningWindowStart: Date
    private let eventIDValue = UUID().uuidString

    init(
        inputItems: [NSExtensionItem],
        onCancel: @escaping () -> Void,
        onComplete: @escaping () -> Void
    ) {
        let referenceDate = Date()
        self.inputItems = inputItems
        self.onCancel = onCancel
        self.onComplete = onComplete
        self.planningWindowStart = referenceDate
        _plannedAt = State(
            initialValue: referenceDate.addingTimeInterval(60 * 60)
        )
    }

    var body: some View {
        NavigationStack {
            Group {
                switch loadingState {
                case .loading:
                    ProgressView("Préparation du lieu…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .loaded:
                    composerForm
                case .failed(let message):
                    ContentUnavailableView {
                        Label(
                            "Lieu indisponible",
                            systemImage: "mappin.slash"
                        )
                    } description: {
                        Text(message)
                    } actions: {
                        Button("Réessayer") {
                            Task { await prepare() }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
            .navigationTitle("Nouvel événement")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer", action: onCancel)
                        .disabled(isPublishing)
                }

                if case .loaded = loadingState {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Publier", action: publish)
                            .disabled(!canPublish || isPublishing)
                    }
                }
            }
        }
        .interactiveDismissDisabled(isPublishing)
        .task {
            await prepare()
        }
    }

    private var composerForm: some View {
        Form {
            Section("Lieu") {
                if let place {
                    LabeledContent("Lieu") {
                        VStack(alignment: .trailing, spacing: 3) {
                            Text(place.placeName)

                            if let address = place.address {
                                Text(address)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.trailing)
                            }

                            Text(coordinateText(place.coordinate))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Section("Type de sortie") {
                Picker("Catégorie", selection: $category) {
                    Text("Choisir…")
                        .tag(nil as OutingCategory?)

                    ForEach(OutingCategory.allCases) { category in
                        Label(
                            category.title,
                            systemImage: category.systemImageName
                        )
                        .tag(category as OutingCategory?)
                    }
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

            if let publicationErrorMessage {
                Section {
                    Label(
                        publicationErrorMessage,
                        systemImage: "exclamationmark.triangle"
                    )
                    .foregroundStyle(.red)
                }
            }

            if isPublishing {
                Section {
                    ProgressView("Publication…")
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
        guard place != nil, session != nil, category != nil else { return false }
        let referenceDate = Date()
        return plannedAt > referenceDate
            && plannedAt.timeIntervalSince(referenceDate)
                <= OutingPlan.maximumPlanningInterval
    }

    private func prepare() async {
        loadingState = .loading
        publicationErrorMessage = nil

        do {
            let input = try await SharedPlaceInputLoader.load(from: inputItems)
            let resolvedPlace = try await SharedPlaceResolver().resolve(input)
            session = try await ShareExtensionFirebaseBootstrap.loadSession()
            place = resolvedPlace
            loadingState = .loaded
        } catch {
            session = nil
            place = nil
            loadingState = .failed(error.localizedDescription)
        }
    }

    private func publish() {
        guard let session, let place, let category else { return }

        isPublishing = true
        publicationErrorMessage = nil
        let draft = OutingPlanDraft(
            displayName: session.displayName,
            placeName: place.placeName,
            address: place.address,
            category: category,
            coordinate: place.coordinate,
            plannedAt: plannedAt,
            timeZoneIdentifier: TimeZone.current.identifier
        )

        Task {
            do {
                let publisher = OutingPlanPublisher()
                _ = try await publisher.publish(
                    draft,
                    ownerID: session.userID,
                    eventIDValue: eventIDValue
                )
                onComplete()
            } catch {
                isPublishing = false
                publicationErrorMessage = error.localizedDescription
            }
        }
    }

    private func coordinateText(_ coordinate: CLLocationCoordinate2D) -> String {
        String(
            format: "%.5f, %.5f",
            coordinate.latitude,
            coordinate.longitude
        )
    }
}
