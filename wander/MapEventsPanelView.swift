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
        return outing.visiblePeople.filter { $0.userID != outing.organizer.userID }
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

/// Keep the list mounted beneath the detail so returning preserves its scroll position.
struct MapEventsPanelView<Detail: View>: View {
    @ScaledMetric(relativeTo: .caption) private var avatarSize: CGFloat = 18
    @State private var renderedEventIDs: Set<String> = []

    let outings: [String: MapOutingPlan]
    let showsDetail: Bool
    var currentLocation: CLLocation?
    var isLoading = false
    var hasLoadError = false
    var onRetry: () -> Void = {}
    var isListActive = true
    var onVisibleEventIDsChange: (Set<String>) -> Void = { _ in }
    var onSetAttendance: (String, Bool) -> Void = { _, _ in }
    var onEdit: (String) -> Void = { _ in }
    let onSelect: (String) -> Void
    @ViewBuilder let detail: () -> Detail

    private var requestedRosterEventIDs: Set<String> {
        isListActive ? renderedEventIDs.intersection(outings.keys) : []
    }

    var body: some View {
        ZStack {
            TimelineView(.periodic(from: .now, by: 60)) { context in
                eventList(now: context.date)
            }
            .opacity(showsDetail ? 0 : 1)
            .allowsHitTesting(!showsDetail)
            .accessibilityHidden(showsDetail)

            if showsDetail { detail() }
        }
        .onChange(of: requestedRosterEventIDs, initial: true) { _, ids in
            onVisibleEventIDsChange(ids)
        }
        .onDisappear { onVisibleEventIDsChange([]) }
    }

    private func eventList(now: Date) -> some View {
        List {
            if hasLoadError {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Certains événements sont indisponibles", systemImage: "exclamationmark.triangle")
                    Button("Réessayer", action: onRetry)
                }
                .accessibilityIdentifier("events-list-error")
            }
            if isLoading {
                ProgressView("Chargement des événements…")
                    .accessibilityIdentifier("events-list-loading")
            }
            if outings.isEmpty, !isLoading, !hasLoadError {
                Text("Aucun événement pour le moment")
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("events-list-empty")
            }
            ForEach(MapEventListPresentation.sortedOutings(Array(outings.values)), id: \.plan.id) { outing in
                eventRow(outing, now: now)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .onAppear { renderedEventIDs.insert(outing.plan.id) }
                    .onDisappear { renderedEventIDs.remove(outing.plan.id) }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .accessibilityIdentifier("events-list")
        .background(Color(uiColor: .secondarySystemGroupedBackground))
    }

    private func eventRow(_ outing: MapOutingPlan, now: Date) -> some View {
        let distance = MapEventListPresentation.distance(
            to: outing.plan.coordinate, from: currentLocation, now: now, compact: true
        )
        return Button {
            onSelect(outing.plan.id)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("\(outing.plan.category.emoji) \(outing.plan.category.title)")
                        .font(.body.weight(.semibold))
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    Text(outing.plan.plannedAt.formatted(.dateTime.hour().minute().locale(Locale(identifier: "fr_FR"))))
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                        .fixedSize()
                }
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("📍 \(outing.plan.placeName)")
                        .lineLimit(1)
                    if let distance {
                        Text("· \(distance)")
                            .font(.caption)
                            .fixedSize()
                    }
                    Spacer(minLength: 2)
                    Text(outing.plan.plannedAt.formatted(.dateTime.day().month(.abbreviated).locale(Locale(identifier: "fr_FR"))))
                        .font(.caption)
                        .fixedSize()
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                HStack(spacing: 5) {
                    ProfileAvatarView(avatarID: outing.organizer.avatarID, size: avatarSize)
                    Text(outing.isCurrentUser ? "Vous" : outing.organizer.displayName)
                        .lineLimit(1)
                        .layoutPriority(-1)
                    participantPreview(outing)
                    Spacer(minLength: 4)
                    if !outing.isCurrentUser, outing.participationState == .attending, !outing.isAttendanceUpdating {
                        Image(systemName: "checkmark")
                            .foregroundStyle(.tint)
                    }
                    Text(MapEventListPresentation.compactStatus(for: outing))
                        .fontWeight(.medium)
                        .foregroundStyle(!outing.isCurrentUser && outing.participationState == .attending ? Color.accentColor : .secondary)
                        .fixedSize()
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(MapEventListPresentation.accessibilitySummary(for: outing, location: currentLocation, now: now))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("event-list-row-" + outing.plan.id)
        .accessibilityHint("Ouvrir l’événement et le situer sur la carte")
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if outing.isCurrentUser {
                Button("Modifier", systemImage: "pencil") { onEdit(outing.plan.id) }
                    .tint(.blue)
            } else if MapEventListPresentation.canRespond(to: outing) {
                Button("Participer", systemImage: "checkmark") { onSetAttendance(outing.plan.id, true) }
                    .tint(.blue)
                Button("Ne pas participer", systemImage: "xmark") { onSetAttendance(outing.plan.id, false) }
                    .tint(.gray)
            }
        }
    }

    @ViewBuilder
    private func participantPreview(_ outing: MapOutingPlan) -> some View {
        switch outing.rosterState {
        case .available:
            let participants = MapEventListPresentation.participants(for: outing)
            if participants.isEmpty {
                Text("· Aucun inscrit").lineLimit(1)
            } else {
                Text("·")
                HStack(spacing: -5) {
                    ForEach(participants.prefix(3)) { person in
                        ProfileAvatarView(avatarID: person.avatarID, size: avatarSize)
                    }
                }
                if participants.count > 3 { Text("+\(participants.count - 3)").fixedSize() }
            }
        case .loading, .notRequested:
            ProgressView().controlSize(.mini)
        case .unavailable:
            Image(systemName: "person.crop.circle.badge.exclamationmark")
        }
    }
}
