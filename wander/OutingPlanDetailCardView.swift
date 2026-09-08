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
        VStack(spacing: 0) {
            header
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(outing.plan.placeName)
                        .font(.title2.weight(.semibold))
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)

                    outingDetails
                    participationSummary
                    directionsButton

                    if outing.isCurrentUser {
                        editButton
                    } else {
                        attendanceControl
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
            }
            .accessibilityIdentifier("outing-detail-scroll")
        }
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .accessibilityElement(children: .contain)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Text("Sortie prévue")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: onDismiss) {
                Image(systemName: "xmark")
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .frame(minWidth: 44, minHeight: 44)
            .accessibilityLabel("Fermer la fiche de la sortie")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private var outingDetails: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(
                outing.plan.category.title,
                systemImage: outing.plan.category.systemImageName
            )

            Label(
                outing.plan.plannedAt.formatted(
                    date: .abbreviated,
                    time: .shortened
                ),
                systemImage: "calendar"
            )

            if let address = outing.plan.address {
                Label(address, systemImage: "mappin.and.ellipse")
            }

            Label(organizerText, systemImage: "person.crop.circle")
        }
        .font(.body)
        .symbolRenderingMode(.hierarchical)
    }

    @ViewBuilder
    private var participationSummary: some View {
        VStack(alignment: .leading, spacing: 4) {
            switch outing.rosterState {
            case .available:
                VStack(alignment: .leading, spacing: 8) {
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 10) {
                            participantAvatars
                            Text(peopleCountText)
                                .font(.subheadline.weight(.medium))
                                .fixedSize(horizontal: true, vertical: false)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            participantAvatars
                            Text(peopleCountText)
                                .font(.subheadline.weight(.medium))
                        }
                    }

                    if !outing.visibleDeclines.isEmpty {
                        ViewThatFits(in: .horizontal) {
                            HStack(spacing: 10) {
                                declineAvatars
                                Text(declineCountText)
                                    .fixedSize(horizontal: true, vertical: false)
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                declineAvatars
                                Text(declineCountText)
                            }
                        }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }
                }

            case .loading, .notRequested:
                ProgressView("Chargement des participants…")
                    .font(.subheadline)

            case .unavailable:
                Label("Participants indisponibles", systemImage: "person.2")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if !outing.isCurrentUser {
                participationStatus
            }
        }
    }

    private var participantAvatars: some View {
        OutingPeopleAvatarStack(
            people: outing.visiblePeople,
            accessibilityText: participantsAccessibilityText
        )
    }

    private var declineAvatars: some View {
        OutingPeopleAvatarStack(
            people: outing.visibleDeclines,
            accessibilityText: declinesAccessibilityText
        )
    }

    @ViewBuilder
    private var participationStatus: some View {
        switch outing.participationState {
        case .attending:
            Text("Vous participez")
                .font(.footnote)
                .foregroundStyle(.secondary)

        case .notResponded:
            Text("Vous n’avez pas encore répondu")
                .font(.footnote)
                .foregroundStyle(.secondary)

        case .declined:
            Text("Vous ne participez pas")
                .font(.footnote)
                .foregroundStyle(.secondary)

        case .loading, .notRequested:
            ProgressView("Vérification de votre participation…")
                .font(.footnote)

        case .unavailable:
            Label(
                "Participation indisponible",
                systemImage: "person.crop.circle.badge.exclamationmark"
            )
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var attendanceControl: some View {
        switch outing.participationState {
        case .attending, .notResponded, .declined:
            attendanceButtons
        case .loading, .notRequested, .unavailable:
            EmptyView()
        }
    }

    private var attendanceButtons: some View {
        VStack(spacing: 8) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    attendanceButton(shouldAttend: true)
                    attendanceButton(shouldAttend: false)
                }

                VStack(spacing: 8) {
                    attendanceButton(shouldAttend: true)
                    attendanceButton(shouldAttend: false)
                }
            }

            if outing.isAttendanceUpdating {
                ProgressView("Mise à jour de votre réponse…")
                    .font(.footnote)
            }
        }
    }

    @ViewBuilder
    private func attendanceButton(shouldAttend: Bool) -> some View {
        let isSelected = shouldAttend
            ? outing.participationState == .attending
            : outing.participationState == .declined
        let label = shouldAttend ? "Je participe" : "Non, je ne participe pas"
        let systemImage = isSelected
            ? "checkmark.circle.fill"
            : shouldAttend ? "person.badge.plus" : "person.crop.circle.badge.xmark"

        if isSelected {
            Button {
                onSetAttendance(shouldAttend)
            } label: {
                Label(label, systemImage: systemImage)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(outing.isAttendanceUpdating)
            .accessibilityHint("Réponse actuellement sélectionnée")
        } else {
            Button {
                onSetAttendance(shouldAttend)
            } label: {
                Label(label, systemImage: systemImage)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .disabled(outing.isAttendanceUpdating)
            .accessibilityHint("Choisit cette réponse pour la sortie")
        }
    }

    private var directionsButton: some View {
        Button(action: onOpenDirections) {
            Label("Itinéraire", systemImage: "map")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .accessibilityHint(
            "Choisir une application pour rejoindre le lieu de cet événement"
        )
    }

    private var editButton: some View {
        Button(action: onEdit) {
            Label("Modifier l’événement", systemImage: "pencil")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .accessibilityHint("Modifie ou annule cet événement")
    }

    private var organizerText: String {
        outing.isCurrentUser
            ? "Organisée par vous"
            : "Organisée par \(outing.organizer.displayName)"
    }

    private var peopleCountText: String {
        switch outing.visiblePeople.count {
        case 1:
            "1 personne participe"
        default:
            "\(outing.visiblePeople.count) personnes participent"
        }
    }

    private var declineCountText: String {
        switch outing.visibleDeclines.count {
        case 1:
            "1 personne ne participe pas"
        default:
            "\(outing.visibleDeclines.count) personnes ne participent pas"
        }
    }

    private var participantsAccessibilityText: String {
        let organizerDescription = outing.isCurrentUser
            ? "Vous organisez la sortie."
            : "Sortie organisée par \(outing.organizer.displayName)."
        let participantNames = outing.visiblePeople
            .filter { $0.userID != outing.organizer.userID }
            .map(\.displayName)
        guard !participantNames.isEmpty else {
            return organizerDescription + " Aucun autre participant."
        }
        return organizerDescription + " Participants : "
            + ListFormatter.localizedString(byJoining: participantNames)
    }

    private var declinesAccessibilityText: String {
        "Ne participent pas : "
            + ListFormatter.localizedString(
                byJoining: outing.visibleDeclines.map(\.displayName)
            )
    }
}

private struct OutingPeopleAvatarStack: View {
    private static let maximumVisibleCount = 6
    private static let avatarOverlap: CGFloat = 12
    private static let avatarSeparatorWidth: CGFloat = 2

    let people: [MapOutingAttendee]
    let accessibilityText: String

    var body: some View {
        HStack(spacing: 6) {
            HStack(spacing: -Self.avatarOverlap) {
                ForEach(people.prefix(Self.maximumVisibleCount)) { person in
                    ProfileAvatarView(avatarID: person.avatarID, size: 32)
                        .overlay {
                            Circle()
                                .stroke(
                                    Color(uiColor: .systemBackground),
                                    lineWidth: Self.avatarSeparatorWidth
                                )
                        }
                        .accessibilityHidden(true)
                }
            }

            let hiddenCount = people.count
                - min(people.count, Self.maximumVisibleCount)
            if hiddenCount > 0 {
                Text("+\(hiddenCount)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }
}
