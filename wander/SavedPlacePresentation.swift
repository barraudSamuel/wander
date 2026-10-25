import UIKit

/// A critically damped follower. Retargeting preserves both position and velocity.
struct SavedPlaceEmphasisMotion {
    private(set) var value: CGFloat = 0
    private(set) var velocity: CGFloat = 0
    private(set) var target: CGFloat = 0
    var isSettled: Bool { value == target && velocity == 0 }

    static func bounded(_ emphasis: CGFloat) -> CGFloat {
        emphasis.isFinite ? min(1, max(0, emphasis)) : 0
    }

    mutating func retarget(_ emphasis: CGFloat) {
        target = Self.bounded(emphasis)
    }

    mutating func reset(to emphasis: CGFloat) {
        value = Self.bounded(emphasis)
        target = value
        velocity = 0
    }

    mutating func advance(by elapsed: TimeInterval) {
        guard elapsed > 0, elapsed.isFinite, !isSettled else { return }
        let frequency: CGFloat = 24
        let time = CGFloat(elapsed)
        let displacement = value - target
        let coefficient = velocity + frequency * displacement
        let decay = exp(-frequency * time)
        value = target + (displacement + coefficient * time) * decay
        velocity = (velocity - frequency * coefficient * time) * decay
        if abs(value - target) < 0.0001, abs(velocity) < 0.001 {
            value = target
            velocity = 0
        }
    }
}

/// Dimensions drawn by a map pin. Its geographic point is always (0, 0).
struct SavedPlaceVisualState: Equatable {
    var width: CGFloat
    var height: CGFloat
    var radius: CGFloat
    var border: CGFloat
    var tip: CGFloat
    var stickerOpacity: CGFloat
    var stickerScale: CGFloat

    static func mapPin(emphasis: CGFloat) -> Self {
        let value = SavedPlaceEmphasisMotion.bounded(emphasis)
        let labelProgress = min(1, max(0, (value - 0.45) / 0.4))
        let width = 24 + 26 * value
        return Self(width: width, height: width, radius: width / 2, border: 2 + value,
                    tip: 6 * value,
                    stickerOpacity: labelProgress * labelProgress * (3 - 2 * labelProgress),
                    stickerScale: 14 / 24)
    }

    var bodyRect: CGRect {
        CGRect(x: -width / 2, y: -height - tip, width: width, height: height)
    }

    func stickerRect(baseWidth: CGFloat) -> CGRect {
        CGRect(x: -baseWidth * stickerScale / 2, y: bodyRect.minY + 2 - 22 * stickerScale,
               width: baseWidth * stickerScale, height: 44 * stickerScale)
    }
}

/// Category lettering follows a shallow arc, with a white outline around each glyph.
final class SavedPlaceCategoryStickerView: UIView {
    var text = "" { didSet { setNeedsDisplay() } }
    var fontSize: CGFloat = 14 { didSet { setNeedsDisplay() } }

    static func font(size: CGFloat) -> UIFont {
        let font = UIFont.systemFont(ofSize: size, weight: .heavy)
        return UIFont(descriptor: font.fontDescriptor.withDesign(.rounded) ?? font.fontDescriptor, size: size)
    }

    static func measuredWidth(for text: String, size: CGFloat) -> CGFloat {
        ceil((text as NSString).size(withAttributes: [.font: font(size: size)]).width) + 16
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = false
        isUserInteractionEnabled = false
        contentMode = .redraw
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext(), !text.isEmpty else { return }
        let font = Self.font(size: fontSize)
        let outline: [NSAttributedString.Key: Any] = [
            .font: font, .foregroundColor: UIColor.white, .strokeColor: UIColor.white, .strokeWidth: -30
        ]
        let fill: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: UIColor.black]
        let characters = text.map(String.init)
        let widths = characters.map { ($0 as NSString).size(withAttributes: [.font: font]).width }
        let textWidth = widths.reduce(0, +)
        // Draw every outline first, then every black glyph. Adjacent white strokes must
        // never cover the preceding character's black fill at the small pin size.
        for attributes in [outline, fill] {
            var cursor = (bounds.width - textWidth) / 2
            for (character, width) in zip(characters, widths) {
                let x = cursor + width / 2
                let normalized = (x - bounds.midX) / max(1, textWidth / 2)
                context.saveGState()
                context.translateBy(x: x, y: bounds.midY + normalized * normalized * 3)
                context.rotate(by: normalized * 0.12)
                (character as NSString).draw(at: CGPoint(x: -width / 2, y: -font.lineHeight / 2),
                                            withAttributes: attributes)
                context.restoreGState()
                cursor += width
            }
        }
    }
}
