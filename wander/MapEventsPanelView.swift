import CoreLocation
import SwiftUI

enum MapEventListPresentation {
    static func sortedOutings(_ outings: [MapOutingPlan]) -> [MapOutingPlan] {
        outings.sorted {
            if $0.plan.plannedAt != $1.plan.plannedAt {
                return $0.plan.plannedAt < $1.plan.plannedAt
            }
            return $0.plan.id < $1.plan.id
        }
    }

    static func status(for outing: MapOutingPlan) -> String {
        if outing.isCurrentUser { return "Vous organisez" }
        switch outing.participationState {
        case .attending: return "Vous participez"
        case .declined: return "Vous ne participez pas"
        case .notResponded: return "Vous n’avez pas encore répondu"
        case .loading, .notRequested: return "Votre réponse est en cours de chargement"
        case .unavailable: return "Votre réponse est indisponible"
        }
    }

    static func compactStatus(for outing: MapOutingPlan) -> String {
        if outing.isCurrentUser { return "Vous organisez" }
        if outing.isAttendanceUpdating { return "Envoi…" }
        switch outing.participationState {
        case .attending: return "J’y vais"
        case .declined: return "Pas cette fois"
        case .notResponded: return "À répondre"
        case .loading, .notRequested: return "Vérification…"
        case .unavailable: return "Indisponible"
        }
    }

    static func canRespond(to outing: MapOutingPlan) -> Bool {
        guard !outing.isCurrentUser, !outing.isAttendanceUpdating else { return false }
        switch outing.participationState {
        case .attending, .declined, .notResponded: return true
        case .loading, .notRequested, .unavailable: return false
        }
    }

    static func participants(for outing: MapOutingPlan) -> [MapOutingAttendee] {
        guard outing.rosterState == .available else { return [] }
        return Array(outing.visiblePeople.dropFirst())
    }

    static func accessibilitySummary(for outing: MapOutingPlan, location: CLLocation?, now: Date) -> String {
        let organizer = outing.isCurrentUser ? "Vous" : outing.organizer.displayName
        let verb = outing.isCurrentUser ? "organisez" : "organise"
        let date = outing.plan.plannedAt.formatted(
            .dateTime.day().month(.abbreviated).hour().minute().locale(Locale(identifier: "fr_FR"))
        )
        var label = "\(organizer) \(verb) \(outing.plan.category.activityDescription) le \(date)"
        let participants = participants(for: outing)
        switch outing.rosterState {
        case .available:
            label += participants.isEmpty ? ". Aucun autre participant pour le moment"
                : " avec " + ListFormatter.localizedString(byJoining: participants.map(\.displayName))
        case .loading, .notRequested: label += ". Chargement des participants"
        case .unavailable: label += ". Participants indisponibles"
        }
        label += ". Lieu : \(outing.plan.placeName)."
        if !outing.isCurrentUser { label += " \(status(for: outing))." }
        if let distance = distance(to: outing.plan.coordinate, from: location, now: now) {
            label += " \(distance)."
        }
        return label
    }

    static func distance(
        to coordinate: CLLocationCoordinate2D, from location: CLLocation?, now: Date, compact: Bool = false
    ) -> String? {
        guard let location,
              CLLocationCoordinate2DIsValid(location.coordinate), CLLocationCoordinate2DIsValid(coordinate),
              location.horizontalAccuracy >= 0, location.horizontalAccuracy <= 100,
              now.timeIntervalSince(location.timestamp) >= -30,
              now.timeIntervalSince(location.timestamp) <= 300 else { return nil }
        let meters = location.distance(from: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude))
        guard meters.isFinite else { return nil }
        if meters < 100 { return compact ? "< 100 m" : "À moins de 100 m à vol d’oiseau" }
        let suffix = compact ? "" : " à vol d’oiseau"
        let rounded = (meters / 100).rounded() * 100
        if rounded < 1_000 { return "≈ \(Int(rounded)) m\(suffix)" }
        let kilometers = (rounded / 1_000).formatted(.number.precision(.fractionLength(0...1)))
        return "≈ \(kilometers) km\(suffix)"
    }
}

/// The list stays mounted while hidden so reopening preserves its scroll position.
struct MapEventsPanelView: View {
    @ScaledMetric(relativeTo: .caption) private var avatarSize: CGFloat = 18
    @State private var visibleEventIDs: Set<String> = []

    let outings: [String: MapOutingPlan]
    var selectedEventID: String?
    var currentLocation: CLLocation?
    var isLoading = false
    var hasLoadError = false
    var onRetry: () -> Void = {}
    var isListActive = true
    var onVisibleEventIDsChange: (Set<String>) -> Void = { _ in }
    var onSetAttendance: (String, Bool) -> Void = { _, _ in }
    var onEdit: (String) -> Void = { _ in }
    var onOpenDirections: (String) -> Void = { _ in }
    let onSelect: (String) -> Void

    private var requestedRosterEventIDs: Set<String> {
        guard isListActive else { return [] }
        return visibleEventIDs.intersection(outings.keys)
    }

    var body: some View {
        let orderedOutings = MapEventListPresentation.sortedOutings(Array(outings.values))
        TimelineView(.periodic(from: .now, by: 60)) { context in
            detailedList(orderedOutings, now: context.date)
        }
        .onChange(of: requestedRosterEventIDs, initial: true) { _, ids in
            onVisibleEventIDsChange(ids)
        }
        .onDisappear { onVisibleEventIDsChange([]) }
    }

    private func detailedList(_ outings: [MapOutingPlan], now: Date) -> some View {
        List {
            Section("Événements") {
                statusContent
                ForEach(outings, id: \.plan.id) { outing in
                    eventButton(outing, now: now)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowBackground(selectedEventID == outing.plan.id ? Color.accentColor.opacity(0.12) : .clear)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            eventActions(for: outing)
                        }
                        .onAppear { visibleEventIDs.insert(outing.plan.id) }
                        .onDisappear { visibleEventIDs.remove(outing.plan.id) }
                }
            }
        }
        .accessibilityIdentifier("events-expanded-list")
    }

    @ViewBuilder
    private var statusContent: some View {
        if hasLoadError {
            VStack(alignment: .leading, spacing: 4) {
                Label("Événements indisponibles", systemImage: "exclamationmark.triangle")
                    .font(.caption)
                Button("Réessayer", action: onRetry)
                    .font(.subheadline)
            }
            .accessibilityIdentifier("events-list-error")
        }
        if isLoading {
            ProgressView("Chargement…")
                .font(.subheadline)
                .accessibilityIdentifier("events-list-loading")
        }
        if outings.isEmpty, !isLoading, !hasLoadError {
            Text("Aucun événement pour le moment")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("events-list-empty")
        }
    }

    private func eventButton(_ outing: MapOutingPlan, now: Date) -> some View {
        Button {
            onSelect(outing.plan.id)
        } label: {
            detailedRow(outing, now: now)
                .contentShape(Rectangle())
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(MapEventListPresentation.accessibilitySummary(for: outing, location: currentLocation, now: now))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("event-detail-row-" + outing.plan.id)
        .accessibilityHint("Centrer la carte. Maintenir pour les actions de l’événement.")
        .accessibilityAddTraits(selectedEventID == outing.plan.id ? .isSelected : [])
        .contextMenu {
            eventActions(for: outing)
            Button("Itinéraire", systemImage: "map") { onOpenDirections(outing.plan.id) }
        }
    }

    private func detailedRow(_ outing: MapOutingPlan, now: Date) -> some View {
        let distance = MapEventListPresentation.distance(
            to: outing.plan.coordinate, from: currentLocation, now: now, compact: true
        )
        return VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Label(outing.plan.category.title, systemImage: outing.plan.category.systemImageName)
                    .font(.body.weight(.semibold))
                Spacer(minLength: 4)
                Text(outing.plan.plannedAt.formatted(
                    .dateTime.day().month(.abbreviated).hour().minute().locale(Locale(identifier: "fr_FR"))
                ))
                .font(.caption)
                .monospacedDigit()
            }
            HStack(spacing: 6) {
                Text(outing.plan.placeName).lineLimit(1)
                if let distance { Text("· " + distance).fixedSize() }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            HStack(spacing: 5) {
                ProfileAvatarView(avatarID: outing.organizer.avatarID, size: avatarSize)
                Text(outing.isCurrentUser ? "Vous" : outing.organizer.displayName).lineLimit(1)
                participantPreview(outing)
                Spacer(minLength: 4)
                Text(MapEventListPresentation.compactStatus(for: outing))
                    .fontWeight(.medium)
                    .lineLimit(1)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .foregroundStyle(.primary)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func participantPreview(_ outing: MapOutingPlan) -> some View {
        switch outing.rosterState {
        case .available:
            let participants = MapEventListPresentation.participants(for: outing)
            if participants.isEmpty {
                Text("· Aucun inscrit").lineLimit(1)
            } else {
                HStack(spacing: -5) {
                    ForEach(participants.prefix(3)) { person in
                        ProfileAvatarView(avatarID: person.avatarID, size: avatarSize)
                    }
                }
                if participants.count > 3 { Text("+\(participants.count - 3)").fixedSize() }
            }
        case .loading, .notRequested: ProgressView().controlSize(.mini)
        case .unavailable: Image(systemName: "person.crop.circle.badge.exclamationmark")
        }
    }

    @ViewBuilder
    private func eventActions(for outing: MapOutingPlan) -> some View {
        if outing.isCurrentUser {
            Button("Modifier", systemImage: "pencil") { onEdit(outing.plan.id) }
                .tint(.blue)
        } else if MapEventListPresentation.canRespond(to: outing) {
            Button("Participer", systemImage: "checkmark") { onSetAttendance(outing.plan.id, true) }
                .tint(.blue)
            Button("Refuser", systemImage: "xmark") { onSetAttendance(outing.plan.id, false) }
                .tint(.gray)
        }
    }
}
