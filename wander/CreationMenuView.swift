import SwiftUI

struct CreationMenuView: View {
    let canCreateEvent: Bool
    let onCreateEvent: () -> Void

    var body: some View {
        List {
            Button(action: onCreateEvent) {
                Label {
                    VStack(alignment: .leading) {
                        Text("Créer un événement")
                        Text("À ma position actuelle")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "calendar.badge.plus")
                }
            }
            .disabled(!canCreateEvent)
            .accessibilityIdentifier("creation-menu-event")

            upcomingAction("Importer des adresses", systemImage: "square.and.arrow.down")
            upcomingAction("Créer un groupe d’amis", systemImage: "person.3")

            if !canCreateEvent {
                Text("Ta position est indisponible. Glisse cette feuille vers le bas, puis fais un appui long sur la carte pour créer un événement au lieu de ton choix.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func upcomingAction(_ title: String, systemImage: String) -> some View {
        Button {} label: {
            HStack {
                Label(title, systemImage: systemImage)
                Spacer()
                Text("Bientôt")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .disabled(true)
    }
}
