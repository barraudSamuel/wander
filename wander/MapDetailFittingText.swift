import SwiftUI
import UIKit

struct MapDetailTextContent: Equatable {
    enum Fragment: Equatable {
        case text(String)
        case emphasis(String)
        case avatars([String])
    }

    var fragments: [Fragment]
    var accessibilityLabel: String
}

/// Measurement and display use the same native attributed text, including avatars.
struct MapDetailFittingText: UIViewRepresentable {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    let content: MapDetailTextContent
    let minimumFontSize: CGFloat
    let identifier: String

    func makeUIView(context: Context) -> MapDetailFittingLabel {
        MapDetailFittingLabel()
    }

    func updateUIView(_ label: MapDetailFittingLabel, context: Context) {
        label.configure(
            content: content,
            minimumFontSize: minimumFontSize,
            appearance: colorScheme == .dark ? .dark : .light,
            contrast: colorSchemeContrast == .increased ? .high : .normal
        )
        label.accessibilityIdentifier = identifier
        label.accessibilityLabel = content.accessibilityLabel
    }

    func sizeThatFits(
        _ proposal: ProposedViewSize,
        uiView: MapDetailFittingLabel,
        context: Context
    ) -> CGSize? {
        guard let width = proposal.width, width.isFinite else { return nil }
        return uiView.fittedSize(width: width, height: proposal.height)
    }
}

final class MapDetailFittingLabel: UILabel {
    private let measuringLabel = UILabel()
    private var content = MapDetailTextContent(fragments: [], accessibilityLabel: "")
    private var minimumFontSize: CGFloat = 16
    private var appearance: UIUserInterfaceStyle = .light
    private var contrast: UIAccessibilityContrast = .normal
    private var fittedProposal: CGSize?
    private var fittedResult = CGSize.zero
    private var measuredWidth: CGFloat?
    private var measurements: [Measurement] = []

    private struct Measurement {
        let fontSize: CGFloat
        let text: NSAttributedString
        let size: CGSize
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        numberOfLines = 0
        lineBreakMode = .byWordWrapping
        textAlignment = .natural
        backgroundColor = .clear
        isAccessibilityElement = true
        accessibilityTraits = .staticText
        measuringLabel.numberOfLines = 0
        measuringLabel.lineBreakMode = .byWordWrapping
        setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(
        content: MapDetailTextContent,
        minimumFontSize: CGFloat,
        appearance: UIUserInterfaceStyle,
        contrast: UIAccessibilityContrast
    ) {
        guard self.content != content || self.minimumFontSize != minimumFontSize
                || self.appearance != appearance || self.contrast != contrast else { return }
        self.content = content
        self.minimumFontSize = minimumFontSize
        self.appearance = appearance
        self.contrast = contrast
        fittedProposal = nil
        measurements.removeAll(keepingCapacity: true)
        invalidateIntrinsicContentSize()
    }

    func fittedSize(width: CGFloat, height: CGFloat?) -> CGSize {
        guard width > 0 else { return .zero }
        let availableHeight = height.flatMap { $0.isFinite ? max(0, $0) : nil }
        let proposal = CGSize(width: width, height: availableHeight ?? .greatestFiniteMagnitude)
        if fittedProposal == proposal { return fittedResult }
        if measuredWidth != width {
            measurements.removeAll(keepingCapacity: true)
            measuredWidth = width
        }

        var lowerSize = minimumFontSize
        var best = measure(fontSize: lowerSize, width: width)
        if let availableHeight, best.size.height <= availableHeight {
            // The rectangle, rather than an arbitrary font cap, bounds the search.
            var upperSize = max(lowerSize, min(width, availableHeight))
            // Nearby frames usually reuse the same line breaks. Their measurements
            // narrow the search without changing its fitting tolerance.
            for measurement in measurements {
                if measurement.size.height <= availableHeight, measurement.fontSize > lowerSize {
                    lowerSize = measurement.fontSize
                    best = measurement
                } else if measurement.size.height > availableHeight {
                    upperSize = min(upperSize, measurement.fontSize)
                }
            }
            for _ in 0..<12 {
                guard upperSize - lowerSize > 0.1 else { break }
                let candidateSize = (lowerSize + upperSize) / 2
                let candidate = measure(fontSize: candidateSize, width: width)
                if candidate.size.height <= availableHeight {
                    lowerSize = candidateSize
                    best = candidate
                } else {
                    upperSize = candidateSize
                }
            }
        }

        // A minimum-size overflow is returned at its full height to the ScrollView.
        attributedText = best.text
        preferredMaxLayoutWidth = width
        fittedProposal = proposal
        fittedResult = CGSize(width: width, height: best.size.height)
        return fittedResult
    }

    private func measure(fontSize: CGFloat, width: CGFloat) -> Measurement {
        if let cached = measurements.first(where: { $0.fontSize == fontSize }) {
            return cached
        }
        let text = attributedContent(fontSize: fontSize, width: width)
        measuringLabel.attributedText = text
        let size = measuringLabel.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        let measurement = Measurement(
            fontSize: fontSize,
            text: text,
            size: CGSize(width: ceil(size.width), height: ceil(size.height))
        )
        if measurements.count == 64 { measurements.removeFirst() }
        measurements.append(measurement)
        return measurement
    }

    private func attributedContent(fontSize: CGFloat, width: CGFloat) -> NSAttributedString {
        let result = NSMutableAttributedString(string: "")
        let font = UIFont.systemFont(ofSize: fontSize, weight: .medium)
        let traits = UITraitCollection(traitsFrom: [
            UITraitCollection(userInterfaceStyle: appearance),
            UITraitCollection(accessibilityContrast: contrast)
        ])
        let secondary = UIColor.secondaryLabel.resolvedColor(with: traits)
        let primary = UIColor.label.resolvedColor(with: traits)
        let base: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: secondary]

        for fragment in content.fragments {
            switch fragment {
            case .text(let value):
                result.append(NSAttributedString(string: value, attributes: base))
            case .emphasis(let value):
                result.append(NSAttributedString(string: value, attributes: [
                    .font: UIFont.systemFont(ofSize: fontSize, weight: .semibold),
                    .foregroundColor: primary
                ]))
            case .avatars(let avatarIDs):
                guard !avatarIDs.isEmpty else { continue }
                // Keep the roster stable throughout the font search. Removing
                // avatars mid-search would make text height non-monotonic.
                let minimumDiameter = min(minimumFontSize * 1.25, width)
                let count = max(1, min(6, Int(floor((width - minimumDiameter) / (minimumDiameter * 0.7))) + 1))
                let visible = Array(avatarIDs.prefix(count))
                let widthFactor = 1 + CGFloat(visible.count - 1) * 0.7
                let diameter = min(fontSize * 1.25, width / widthFactor)
                let step = diameter * 0.7
                let attachment = NSTextAttachment()
                attachment.image = MapDetailAvatarImages.image(for: visible, traits: traits)
                attachment.bounds = CGRect(
                    x: 0, y: -diameter * 0.2,
                    width: diameter + CGFloat(visible.count - 1) * step, height: diameter
                )
                let avatars = NSMutableAttributedString(attachment: attachment)
                avatars.addAttributes(base, range: NSRange(location: 0, length: avatars.length))
                result.append(avatars)
                let hiddenCount = avatarIDs.count - visible.count
                if hiddenCount > 0 {
                    result.append(NSAttributedString(string: " +\(hiddenCount)", attributes: base))
                }
            }
        }

        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byWordWrapping
        paragraph.lineSpacing = fontSize * 0.1
        paragraph.alignment = .natural
        result.addAttribute(.paragraphStyle, value: paragraph, range: NSRange(location: 0, length: result.length))
        return result
    }
}

private enum MapDetailAvatarImages {
    private static let cache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 48
        return cache
    }()

    static func image(for avatarIDs: [String], traits: UITraitCollection) -> UIImage {
        let key = "\(traits.userInterfaceStyle.rawValue):\(traits.accessibilityContrast.rawValue):\(avatarIDs.joined(separator: "|"))" as NSString
        if let cached = cache.object(forKey: key) { return cached }
        let diameter: CGFloat = 96
        let step = diameter * 0.7
        let size = CGSize(width: diameter + CGFloat(avatarIDs.count - 1) * step, height: diameter)
        let borderColor = UIColor.secondarySystemGroupedBackground.resolvedColor(with: traits)
        let image = UIGraphicsImageRenderer(size: size).image { renderer in
            for (index, avatarID) in avatarIDs.enumerated() {
                let rect = CGRect(x: CGFloat(index) * step, y: 0, width: diameter, height: diameter)
                let circle = UIBezierPath(ovalIn: rect)
                renderer.cgContext.saveGState()
                circle.addClip()
                borderColor.setFill()
                circle.fill()
                if let avatar = ProfileAvatar(rawValue: avatarID), let image = UIImage(named: avatar.assetName) {
                    image.draw(in: rect)
                } else {
                    UIImage(systemName: "person.crop.circle.fill")?
                        .withTintColor(.secondaryLabel.resolvedColor(with: traits), renderingMode: .alwaysOriginal)
                        .draw(in: rect.insetBy(dx: 8, dy: 8))
                }
                renderer.cgContext.restoreGState()
                borderColor.setStroke()
                circle.lineWidth = 2
                circle.stroke()
            }
        }
        cache.setObject(image, forKey: key)
        return image
    }
}
