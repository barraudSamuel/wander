//
//  OutingPlanDetailCardView.swift
//  wander
//

import SwiftUI

struct OutingPlanDetailCardView: View {
    let outing: MapOutingPlan
    let onDismiss: () -> Void
    let onEdit: () -> Void
    let onOpenDirections: () -> Void
    let onSetAttendance: (Bool) -> Void

    var body: some View {
        MapDetailPanel(
            title: outing.plan.placeName,
            closeLabel: "Retour aux événements",
            showsBackButton: true,
            scrollIdentifier: "outing-detail-scroll",
            narrativeIdentifier: "outing-detail-narrative",
            content: narrative,
            onDismiss: onDismiss
        ) {
            if !outing.isCurrentUser {
                participationStatus
            }
        } actions: {
            actionRow
        }
    }

    // MARK: - Narrative

    private var narrative: MapDetailTextContent {
        let organizer = outing.isCurrentUser ? "Vous" : outing.organizer.displayName
        let verb = outing.isCurrentUser ? "organisez" : "organise"
        let participants = outing.visiblePeople.filter { $0.userID != outing.organizer.userID }
        let declines = outing.visibleDeclines
        let fragments: [MapDetailTextContent.Fragment] = [
            .avatars([outing.organizer.avatarID]), .text(" "), .emphasis(organizer),
            .text(" \(verb) "), .emphasis(outing.plan.category.activityDescription),
            .text(" \(outing.plan.category.emoji), le 📅 "), .emphasis(dateDescription), .text(".\n")
        ]
        return MapDetailTextContent(
            fragments: fragments + rosterFragments(participants: participants, declines: declines),
            accessibilityLabel: narrativeAccessibilityText(participants: participants, declines: declines)
        )
    }

    private var dateDescription: String {
        outing.plan.plannedAt.formatted(.dateTime.day().month(.abbreviated).hour().minute())
    }

    private func rosterFragments(
        participants: [MapOutingAttendee], declines: [MapOutingAttendee]
    ) -> [MapDetailTextContent.Fragment] {
        switch outing.rosterState {
        case .available:
            var fragments: [MapDetailTextContent.Fragment]
            if participants.isEmpty {
                fragments = [.text("Aucun autre participant pour le moment.")]
            } else {
                fragments = [.text("Avec "), .avatars(participants.map(\.avatarID)), .text(".")]
            }
            if !declines.isEmpty {
                fragments += [.text("\nPas cette fois : "), .avatars(declines.map(\.avatarID)), .text(".")]
            }
            return fragments
        case .loading, .notRequested:
            return [.text("Chargement des participants…")]
        case .unavailable:
            return [.text("Participants indisponibles")]
        }
    }

    private func narrativeAccessibilityText(
        participants: [MapOutingAttendee], declines: [MapOutingAttendee]
    ) -> String {
        let organizer = outing.isCurrentUser
            ? "Vous organisez"
            : "\(outing.organizer.displayName) organise"
        var result = "\(organizer) \(outing.plan.category.activityDescription), le "
            + dateDescription + ". "
        switch outing.rosterState {
        case .available:
            result += participants.isEmpty
                ? "Aucun autre participant pour le moment."
                : "Avec " + ListFormatter.localizedString(byJoining: participants.map(\.displayName)) + "."
            if !declines.isEmpty {
                result += " Ne participent pas : "
                    + ListFormatter.localizedString(byJoining: declines.map(\.displayName)) + "."
            }
        case .loading, .notRequested:
            result += "Chargement des participants."
        case .unavailable:
            result += "Participants indisponibles."
        }
        return result
    }

    @ViewBuilder
    private var participationStatus: some View {
        if outing.isAttendanceUpdating {
            ProgressView("Mise à jour de votre réponse…")
        } else {
            switch outing.participationState {
            case .attending:
                Text("Vous participez")
            case .notResponded:
                Text("Vous n’avez pas encore répondu")
            case .declined:
                Text("Vous ne participez pas")
            case .loading, .notRequested:
                ProgressView("Vérification de votre participation…")
            case .unavailable:
                Label("Participation indisponible", systemImage: "person.crop.circle.badge.exclamationmark")
            }
        }
    }

    // MARK: - Fixed actions

    private var canRespond: Bool {
        switch outing.participationState {
        case .attending, .notResponded, .declined: true
        case .loading, .notRequested, .unavailable: false
        }
    }

    private var actionRow: some View {
        HStack(spacing: 8) {
            Button(action: onOpenDirections) {
                actionLabel("Itinéraire", symbol: "map")
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("Itinéraire")
            .accessibilityHint("Choisir une application pour rejoindre le lieu de cet événement")

            if outing.isCurrentUser {
                Button(action: onEdit) {
                    actionLabel("Modifier l’événement", symbol: "pencil")
                }
                .buttonStyle(.borderedProminent)
                .accessibilityLabel("Modifier l’événement")
                .accessibilityHint("Modifie ou annule cet événement")
            } else {
                attendanceButton(shouldAttend: false)
                attendanceButton(shouldAttend: true)
            }
        }
        .controlSize(.regular)
        .fixedSize(horizontal: true, vertical: false)
    }

    @ViewBuilder
    private func attendanceButton(shouldAttend: Bool) -> some View {
        let isSelected = shouldAttend
            ? outing.participationState == .attending
            : outing.participationState == .declined
        let title = shouldAttend ? "Je participe" : "Je ne participe pas"
        let symbol = shouldAttend ? "checkmark" : "xmark"
        let button = Button {
            guard canRespond, !outing.isAttendanceUpdating else { return }
            onSetAttendance(shouldAttend)
        } label: {
            actionLabel(title, symbol: symbol)
        }
        .disabled(!canRespond || outing.isAttendanceUpdating)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityValue(outing.isAttendanceUpdating ? "Mise à jour en cours" : isSelected ? "Sélectionné" : "")
        .accessibilityHint(isSelected ? "Réponse actuellement sélectionnée" : "Choisit cette réponse pour la sortie")

        if isSelected {
            button.buttonStyle(.borderedProminent)
        } else {
            button.buttonStyle(.bordered)
        }
    }

    private func actionLabel(_ title: String, symbol: String) -> some View {
        Label(title, systemImage: symbol)
            .labelStyle(.iconOnly)
            .fixedSize(horizontal: true, vertical: false)
            .frame(minWidth: 30, minHeight: 30)
    }
}
