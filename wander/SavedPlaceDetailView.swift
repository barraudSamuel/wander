import SwiftUI

struct SavedPlaceDetailView: View {
    let place: SavedPlace
    let onCreateEvent: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(place.name).font(.title2.bold())
                    Text(place.address)
                    LabeledContent("Dernière liste importée", value: place.listName)
                }
                if place.isUnavailable || place.hasLocationWarning {
                    Section {
                        if place.isUnavailable {
                            Label("Lieu signalé indisponible par Naver", systemImage: "exclamationmark.triangle")
                        }
                        if place.hasLocationWarning {
                            Label("Position à vérifier sur Naver", systemImage: "mappin.slash")
                        }
                    }
                }
                Section {
                    Button(action: onCreateEvent) {
                        Label("Créer un événement", systemImage: "calendar.badge.plus")
                    }
                    .accessibilityIdentifier("saved-place-create-event")
                }
                if let url = place.naverURL {
                    Section {
                        Link(destination: url) {
                            Label("Ouvrir dans Naver", systemImage: "arrow.up.right.square")
                        }
                        .accessibilityIdentifier("saved-place-open-naver")
                    }
                }
            }
            .navigationTitle("Adresse enregistrée")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fermer", systemImage: "xmark") { dismiss() }
                }
            }
        }
        .accessibilityIdentifier("saved-place-detail")
    }
}
