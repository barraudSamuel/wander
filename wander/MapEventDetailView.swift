import SwiftUI

struct MapEventDetailView: View {
    let outing: MapOutingPlan
    let onSetAttendance: (Bool) -> Void
    let onEdit: () -> Void
    let onOpenDirections: () -> Void

    var body: some View {
        List {
            Section {
                Label(outing.plan.placeName, systemImage: "mappin.and.ellipse")
                    .font(.headline)
                if let address = outing.plan.address {
                    Text(address)
                        .foregroundStyle(.secondary)
                }
                Label {
                    Text(outing.plan.plannedAt.formatted(.dateTime
                        .day().month(.wide).hour().minute()
                        .locale(Locale(identifier: "fr_FR"))))
                } icon: {
                    Image(systemName: "calendar")
                }
                Button("Itinéraire", systemImage: "map", action: onOpenDirections)
            }

            Section("Organisateur") {
                person(outing.organizer, name: outing.isCurrentUser ? "Vous" : outing.organizer.displayName)
                if outing.isCurrentUser {
                    Button("Modifier", systemImage: "pencil", action: onEdit)
                }
            }

            if !outing.isCurrentUser {
                Section("Votre réponse") {
                    Text(MapEventListPresentation.status(for: outing))
                        .foregroundStyle(.secondary)
                    if outing.isAttendanceUpdating {
                        ProgressView("Envoi…")
                    }
                    Button("Participer", systemImage: "checkmark") { onSetAttendance(true) }
                        .disabled(!MapEventListPresentation.canRespond(to: outing))
                    Button("Refuser", systemImage: "xmark") { onSetAttendance(false) }
                        .disabled(!MapEventListPresentation.canRespond(to: outing))
                }
            }

            Section("Participants") {
                switch outing.rosterState {
                case .available:
                    let participants = MapEventListPresentation.participants(for: outing)
                    if participants.isEmpty {
                        Text("Aucun autre participant pour le moment")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(participants) { person($0, name: $0.displayName) }
                case .loading, .notRequested:
                    ProgressView("Chargement des participants…")
                case .unavailable:
                    Label("Participants indisponibles", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("event-detail-content")
    }

    private func person(_ person: MapOutingAttendee, name: String) -> some View {
        HStack {
            ProfileAvatarView(avatarID: person.avatarID, size: 28)
            Text(name)
        }
    }
}
