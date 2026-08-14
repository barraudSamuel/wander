//
//  ProfileAvatar.swift
//  wander
//

import SwiftUI

enum ProfileAvatar: String, CaseIterable, Identifiable {
    case cyclopsHorns = "cyclops-horns"
    case cyclopsCrown = "cyclops-crown"
    case radiantEye = "radiant-eye"
    case radarFace = "radar-face"
    case starEye = "star-eye"
    case skull
    case waveHair = "wave-hair"
    case flameHair = "flame-hair"
    case labyrinth
    case locatorHair = "locator-hair"
    case socialRays = "social-rays"
    case antennaHair = "antenna-hair"

    static let storageKey = "profile.avatarID"
    static let ownerStorageKey = "profile.avatarOwnerID"

    var id: String { rawValue }

    var assetName: String {
        switch self {
        case .cyclopsHorns: "AvatarCyclopsHorns"
        case .cyclopsCrown: "AvatarCyclopsCrown"
        case .radiantEye: "AvatarRadiantEye"
        case .radarFace: "AvatarRadarFace"
        case .starEye: "AvatarStarEye"
        case .skull: "AvatarSkull"
        case .waveHair: "AvatarWaveHair"
        case .flameHair: "AvatarFlameHair"
        case .labyrinth: "AvatarLabyrinth"
        case .locatorHair: "AvatarLocatorHair"
        case .socialRays: "AvatarSocialRays"
        case .antennaHair: "AvatarAntennaHair"
        }
    }

    var accessibilityName: String {
        switch self {
        case .cyclopsHorns: "Cyclope à cornes"
        case .cyclopsCrown: "Cyclope couronné"
        case .radiantEye: "Œil rayonnant"
        case .radarFace: "Visage radar"
        case .starEye: "Œil étoilé"
        case .skull: "Crâne"
        case .waveHair: "Cheveux ondulés"
        case .flameHair: "Cheveux flamme"
        case .labyrinth: "Visage labyrinthe"
        case .locatorHair: "Cheveux balises"
        case .socialRays: "Visage rayonnant"
        case .antennaHair: "Cheveux antennes"
        }
    }

    static func normalizedID(_ id: String?) -> String? {
        guard let id, Self(rawValue: id) != nil else { return nil }
        return id
    }

    static func randomID() -> String {
        allCases.randomElement()?.rawValue ?? cyclopsHorns.rawValue
    }

    static func generatedID(seed: String) -> String {
        let hash = seed.utf8.reduce(UInt64(14_695_981_039_346_656_037)) {
            ($0 ^ UInt64($1)) &* 1_099_511_628_211
        }
        let index = Int(hash % UInt64(allCases.count))
        return allCases[index].rawValue
    }
}

struct ProfileAvatarView: View {
    let avatarID: String
    let size: CGFloat

    var body: some View {
        Group {
            if let avatar = ProfileAvatar(rawValue: avatarID) {
                Image(avatar.assetName)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.secondary)
                    .padding(size * 0.1)
            }
        }
        .frame(width: size, height: size)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(Circle())
        .contentShape(Circle())
    }
}

struct ProfileAvatarPicker: View {
    @Binding var selection: String

    private let columns = [
        GridItem(.adaptive(minimum: 72, maximum: 88), spacing: 16)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(ProfileAvatar.allCases) { avatar in
                Button {
                    selection = avatar.id
                } label: {
                    ProfileAvatarView(avatarID: avatar.id, size: 72)
                        .overlay {
                            Circle()
                                .stroke(
                                    selection == avatar.id
                                        ? Color.accentColor
                                        : Color.clear,
                                    lineWidth: 4
                                )
                        }
                        .overlay(alignment: .bottomTrailing) {
                            if selection == avatar.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.title3)
                                    .symbolRenderingMode(.palette)
                                    .foregroundStyle(.white, Color.accentColor)
                                    .background(.background, in: Circle())
                            }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(avatar.accessibilityName)
                .accessibilityAddTraits(
                    selection == avatar.id ? .isSelected : []
                )
            }
        }
    }
}
