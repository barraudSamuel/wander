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

    static func canRespond(to outing: MapOutingPlan) -> Bool {
        guard !outing.isCurrentUser, !outing.isAttendanceUpdating else { return false }
        switch outing.participationState {
        case .attending, .declined, .notResponded: return true
        case .loading, .notRequested, .unavailable: return false
        }
    }

    static func participants(for outing: MapOutingPlan) -> [MapOutingAttendee] {
        guard outing.rosterState == .available else { return [] }
        return outing.visiblePeople
    }

    static func accessibilitySummary(for outing: MapOutingPlan, location: CLLocation?, now: Date) -> String {
        let organizer = outing.isCurrentUser ? "Vous" : outing.organizer.displayName
        let verb = outing.isCurrentUser ? "organisez" : "organise"
        let date = outing.plan.plannedAt.formatted(
            .dateTime.day().month(.abbreviated).hour().minute().locale(Locale(identifier: "fr_FR"))
        )
        var label = "\(organizer) \(verb) \(outing.plan.category.activityDescription) le \(date)"
        let participants = participants(for: outing).dropFirst()
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

/// A new request also scrolls to a previously selected event.
struct MapEventScrollRequest: Equatable {
    let eventID: String
    let id = UUID()
}

/// The list stays mounted while hidden so reopening preserves its scroll position.
struct MapEventsPanelView: View {
    @ScaledMetric(relativeTo: .caption) private var avatarSize: CGFloat = 24
    @State private var visibleEventIDs: Set<String> = []
    @State private var handledScrollRequestID: UUID?

    let outings: [String: MapOutingPlan]
    var scrollRequest: MapEventScrollRequest?
    var currentLocation: CLLocation?
    var isLoading = false
    var hasLoadError = false
    var onRetry: () -> Void = {}
    var isListActive = true
    var onVisibleEventIDsChange: (Set<String>) -> Void = { _ in }
    var onShowOnMap: (String) -> Void = { _ in }
    var onSetAttendance: (String, Bool) -> Void = { _, _ in }
    var onEdit: (String) -> Void = { _ in }
    var onOpenDirections: (String) -> Void = { _ in }

    private var requestedRosterEventIDs: Set<String> {
        guard isListActive else { return [] }
        return visibleEventIDs.intersection(outings.keys)
    }

    private var pendingScrollRequest: MapEventScrollRequest? {
        guard isListActive, let scrollRequest,
              scrollRequest.id != handledScrollRequestID,
              outings[scrollRequest.eventID] != nil else { return nil }
        return scrollRequest
    }

    var body: some View {
        let orderedOutings = MapEventListPresentation.sortedOutings(Array(outings.values))
        ScrollViewReader { proxy in
            TimelineView(.periodic(from: .now, by: 60)) { context in
                eventList(orderedOutings, now: context.date)
            }
            .onChange(of: pendingScrollRequest, initial: true) { _, request in
                guard let request else { return }
                proxy.scrollTo(request.eventID, anchor: .top)
                handledScrollRequestID = request.id
            }
        }
        .onChange(of: requestedRosterEventIDs, initial: true) { _, ids in
            onVisibleEventIDsChange(ids)
        }
        .onDisappear { onVisibleEventIDsChange([]) }
    }

    private func eventList(_ orderedOutings: [MapOutingPlan], now: Date) -> some View {
        List {
            if outings.isEmpty || isLoading || hasLoadError {
                Section("Événements") { statusContent }
            }
            ForEach(orderedOutings, id: \.plan.id) { outing in
                Section {
                    eventCard(outing, now: now)
                        .id(outing.plan.id)
                        .onAppear { visibleEventIDs.insert(outing.plan.id) }
                        .onDisappear { visibleEventIDs.remove(outing.plan.id) }
                } header: {
                    if outing.plan.id == orderedOutings.first?.plan.id, !isLoading, !hasLoadError {
                        Text("Événements")
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .listSectionSpacing(8)
        .scrollContentBackground(.visible)
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

    private func eventCard(_ outing: MapOutingPlan, now: Date) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                onShowOnMap(outing.plan.id)
            } label: {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: outing.plan.category.systemImageName)
                        .font(.title2)
                        .foregroundStyle(.tint)
                        .frame(width: 32, height: 32)
                        .accessibilityHidden(true)
                    invitation(outing, now: now)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Afficher \(outing.plan.placeName) sur la carte")
            .accessibilityIdentifier("event-focus-" + outing.plan.id)
            Divider()
            HStack(spacing: 8) {
                participantPreview(outing)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                eventActions(for: outing)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(MapEventListPresentation.accessibilitySummary(for: outing, location: currentLocation, now: now))
        .accessibilityIdentifier("event-card-" + outing.plan.id)
    }

    private func invitation(_ outing: MapOutingPlan, now: Date) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            if !outing.isCurrentUser {
                Text("Proposé par \(outing.organizer.displayName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(outing.plan.placeName)
                .font(.headline)
            scheduleAndDistance(outing, now: now)
            if let address = outing.plan.address {
                Text(address).font(.caption).foregroundStyle(.secondary)
            }
            if !outing.isCurrentUser {
                if outing.isAttendanceUpdating {
                    ProgressView("Envoi…").controlSize(.mini)
                } else {
                    Text(MapEventListPresentation.status(for: outing))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func scheduleAndDistance(_ outing: MapOutingPlan, now: Date) -> some View {
        let date = outing.plan.plannedAt.formatted(.dateTime
            .day().month(.wide).hour().minute().locale(Locale(identifier: "fr_FR")))
        let distance = MapEventListPresentation.distance(
            to: outing.plan.coordinate, from: currentLocation, now: now, compact: true
        )
        return ViewThatFits(in: .horizontal) {
            HStack(spacing: 6) {
                Text(date)
                if let distance {
                    Text("·").accessibilityHidden(true)
                    Text(distance)
                }
            }
            .fixedSize()
            VStack(alignment: .leading, spacing: 3) {
                Text(date)
                if let distance { Text(distance) }
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    @ViewBuilder
    private func participantPreview(_ outing: MapOutingPlan) -> some View {
        switch outing.rosterState {
        case .available:
            let participants = MapEventListPresentation.participants(for: outing)
            HStack(spacing: 8) {
                HStack(spacing: -6) {
                    ForEach(participants.prefix(3)) { person in
                        ProfileAvatarView(avatarID: person.avatarID, size: avatarSize)
                    }
                }
                .accessibilityHidden(true)
                Text(participants.count.formatted()).monospacedDigit()
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel((participants.count == 1 ? "1 participant : " : "\(participants.count) participants : ")
                + participants.map(\.displayName).formatted(.list(type: .and)
                .locale(Locale(identifier: "fr_FR"))))
        case .loading, .notRequested:
            ProgressView().controlSize(.mini)
                .accessibilityLabel("Chargement des participants")
        case .unavailable:
            Label("Participants indisponibles", systemImage: "person.crop.circle.badge.exclamationmark")
                .labelStyle(.iconOnly)
        }
    }

    private func eventActions(for outing: MapOutingPlan) -> some View {
        HStack(spacing: 4) { actionButtons(for: outing) }
        .fixedSize()
        .buttonStyle(.bordered)
        .controlSize(.small)
    }

    @ViewBuilder
    private func actionButtons(for outing: MapOutingPlan) -> some View {
        if outing.isCurrentUser {
            eventAction("Modifier", systemImage: "pencil") { onEdit(outing.plan.id) }
        } else {
            eventAction("Participer", systemImage: "checkmark") { onSetAttendance(outing.plan.id, true) }
                .buttonStyle(.borderedProminent)
                .disabled(!MapEventListPresentation.canRespond(to: outing))
            eventAction("Refuser", systemImage: "xmark") { onSetAttendance(outing.plan.id, false) }
                .disabled(!MapEventListPresentation.canRespond(to: outing))
        }
        eventAction("Itinéraire", systemImage: "map") { onOpenDirections(outing.plan.id) }
    }

    private func eventAction(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .labelStyle(.iconOnly)
                .frame(width: 28, height: 32)
        }
        .accessibilityLabel(title)
    }
}
