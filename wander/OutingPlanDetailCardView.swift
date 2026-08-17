//
//  OutingPlanDetailCardView.swift
//  wander
//

import SwiftUI

struct OutingPlanDetailCardView: View {
    let outing: MapOutingPlan
    let onDismiss: () -> Void
    let onEdit: () -> Void
    let onToggleAttendance: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            outingDetails
            participationSummary

            if outing.isCurrentUser {
                editButton
            } else {
                attendanceButton
            }
        }
        .padding(16)
        .background(
            .regularMaterial,
            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
        .accessibilityElement(children: .contain)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Sortie prévue")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text(outing.plan.placeName)
                    .font(.title2.weight(.semibold))
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: onDismiss) {
                Image(systemName: "xmark")
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .accessibilityLabel("Fermer la fiche de la sortie")
        }
    }

    private var outingDetails: some View {
        VStack(alignment: .leading, spacing: 8) {
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
        if outing.isCurrentUser || outing.isCurrentUserAttending {
            HStack(spacing: 10) {
                if !outing.attendees.isEmpty {
                    OutingAttendeeAvatarStack(attendees: outing.attendees)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(participantCountText)
                        .font(.subheadline.weight(.medium))

                    if outing.isCurrentUserAttending {
                        Text("Vous participez")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        } else {
            Label("Vous ne participez pas", systemImage: "person.2")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var attendanceButton: some View {
        Button(action: onToggleAttendance) {
            HStack(spacing: 8) {
                if outing.isAttendanceUpdating {
                    ProgressView()
                        .controlSize(.small)
                    Text("Mise à jour…")
                } else {
                    Label(
                        outing.isCurrentUserAttending
                            ? "Je ne participe plus"
                            : "Je participe",
                        systemImage: outing.isCurrentUserAttending
                            ? "checkmark.circle.fill"
                            : "person.badge.plus"
                    )
                }
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(outing.isAttendanceUpdating)
        .accessibilityHint("Modifie ta participation à cette sortie")
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
            : "Organisée par \(outing.displayName)"
    }

    private var participantCountText: String {
        switch outing.attendees.count {
        case 0:
            "Aucun participant"
        case 1:
            "1 participant"
        default:
            "\(outing.attendees.count) participants"
        }
    }
}

private struct OutingAttendeeAvatarStack: View {
    let attendees: [MapOutingAttendee]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(attendees.prefix(4)) { attendee in
                ProfileAvatarView(avatarID: attendee.avatarID, size: 32)
                    .accessibilityHidden(true)
            }

            let hiddenCount = attendees.count - min(attendees.count, 4)
            if hiddenCount > 0 {
                Text("+\(hiddenCount)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        let names = attendees.map(\.displayName)
        return "Participants : "
            + ListFormatter.localizedString(byJoining: names)
    }
}
