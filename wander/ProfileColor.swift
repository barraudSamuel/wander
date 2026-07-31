//
//  ProfileColor.swift
//  wander
//

import SwiftUI
import UIKit

enum ProfileColor {
    static let storageKey = "profile.colorHex"
    static let ownerStorageKey = "profile.colorOwnerID"
    static let pendingOwnerStorageKey = "profile.pendingColorOwnerID"
    static let pendingUserSelectionStorageKey =
        "profile.pendingUserSelectedColor"

    static func storedOrGeneratedHex() -> String {
        if let storedHex = UserDefaults.standard
            .string(forKey: storageKey)
            .flatMap(normalizedHex) {
            return storedHex
        }

        let generatedHex = randomHex()
        UserDefaults.standard.set(generatedHex, forKey: storageKey)
        UserDefaults.standard.set(
            UserDefaults.standard.string(forKey: ownerStorageKey) ?? "",
            forKey: pendingOwnerStorageKey
        )
        return generatedHex
    }

    nonisolated static func randomHex() -> String {
        generatedHex(seed: UUID().uuidString)
    }

    nonisolated static func generatedHex(seed: String) -> String {
        var hash: UInt64 = 1_469_598_103_934_665_603
        for byte in seed.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 1_099_511_628_211
        }

        let hueSector = Double(hash % 360) / 60
        let chroma = 0.90 * 0.72
        let intermediate = chroma
            * (1 - abs(hueSector.truncatingRemainder(dividingBy: 2) - 1))
        let match = 0.90 - chroma
        let red: Double
        let green: Double
        let blue: Double

        switch hueSector {
        case 0..<1:
            (red, green, blue) = (chroma, intermediate, 0)
        case 1..<2:
            (red, green, blue) = (intermediate, chroma, 0)
        case 2..<3:
            (red, green, blue) = (0, chroma, intermediate)
        case 3..<4:
            (red, green, blue) = (0, intermediate, chroma)
        case 4..<5:
            (red, green, blue) = (intermediate, 0, chroma)
        default:
            (red, green, blue) = (chroma, 0, intermediate)
        }

        return hex(
            red: CGFloat(red + match),
            green: CGFloat(green + match),
            blue: CGFloat(blue + match)
        )
    }

    nonisolated static func normalizedHex(_ rawValue: String) -> String? {
        let trimmedValue = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let hexDigits = trimmedValue.hasPrefix("#")
            ? String(trimmedValue.dropFirst())
            : trimmedValue
        let uppercaseDigits = hexDigits.uppercased()
        let validDigits = CharacterSet(charactersIn: "0123456789ABCDEF")

        guard uppercaseDigits.count == 6,
              uppercaseDigits.unicodeScalars.allSatisfy(validDigits.contains)
        else {
            return nil
        }

        return "#\(uppercaseDigits)"
    }

    static func uiColor(hex rawValue: String) -> UIColor {
        let normalizedValue =
            normalizedHex(rawValue) ?? generatedHex(seed: rawValue)
        let hexDigits = String(normalizedValue.dropFirst())
        let value = UInt32(hexDigits, radix: 16)!

        return UIColor(
            red: CGFloat((value >> 16) & 0xFF) / 255,
            green: CGFloat((value >> 8) & 0xFF) / 255,
            blue: CGFloat(value & 0xFF) / 255,
            alpha: 1
        )
    }

    static func color(hex rawValue: String) -> Color {
        Color(uiColor: uiColor(hex: rawValue))
    }

    static func foregroundColor(hex rawValue: String) -> Color {
        Color(uiColor: contrastingUIColor(for: uiColor(hex: rawValue)))
    }

    static func contrastingUIColor(for backgroundColor: UIColor) -> UIColor {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        guard backgroundColor.getRed(
            &red,
            green: &green,
            blue: &blue,
            alpha: &alpha
        ) else {
            return UIColor.white
        }

        func linearized(_ component: CGFloat) -> Double {
            let value = Double(component)
            return value <= 0.04045
                ? value / 12.92
                : pow((value + 0.055) / 1.055, 2.4)
        }

        let relativeLuminance =
            0.2126 * linearized(red)
            + 0.7152 * linearized(green)
            + 0.0722 * linearized(blue)
        let blackContrastRatio = (relativeLuminance + 0.05) / 0.05
        let whiteContrastRatio = 1.05 / (relativeLuminance + 0.05)

        return blackContrastRatio >= whiteContrastRatio
            ? UIColor.black
            : UIColor.white
    }

    static func hex(from color: Color) -> String {
        let resolvedColor = UIColor(color).resolvedColor(with: UITraitCollection.current)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        if resolvedColor.getRed(
            &red,
            green: &green,
            blue: &blue,
            alpha: &alpha
        ) {
            return hex(red: red, green: green, blue: blue)
        }

        var white: CGFloat = 0
        if resolvedColor.getWhite(&white, alpha: &alpha) {
            return hex(red: white, green: white, blue: white)
        }

        guard
            let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
            let convertedColor = resolvedColor.cgColor.converted(
                to: colorSpace,
                intent: .defaultIntent,
                options: nil
            ),
            let components = convertedColor.components
        else {
            return storedOrGeneratedHex()
        }

        switch components.count {
        case 2:
            return hex(red: components[0], green: components[0], blue: components[0])
        case 3...:
            return hex(red: components[0], green: components[1], blue: components[2])
        default:
            return storedOrGeneratedHex()
        }
    }

    nonisolated private static func hex(
        red: CGFloat,
        green: CGFloat,
        blue: CGFloat
    ) -> String {
        String(
            format: "#%02X%02X%02X",
            byte(from: red),
            byte(from: green),
            byte(from: blue)
        )
    }

    nonisolated private static func byte(from component: CGFloat) -> Int {
        Int((min(max(component, 0), 1) * 255).rounded())
    }
}
