import CoreGraphics

enum SavedPlaceEmphasisLayout {
    struct Candidate {
        let id: String
        let point: CGPoint
        let isSelected: Bool
    }

    struct Placement {
        let id: String
        let emphasis: CGFloat
        let priority: Int
    }

    // Initial calibration against the reference video. Each axis has a broad central plateau.
    private static let zoomGrowth: ClosedRange<CGFloat> = 12.2...13.2
    private static let horizontalFade: ClosedRange<CGFloat> = 0.48...0.92
    private static let verticalFade: ClosedRange<CGFloat> = 0.78...0.98

    /// Returns front-to-back placements. Emphasis depends only on the candidate's position and zoom.
    static func resolve(_ candidates: [Candidate], viewport: CGRect, zoom: Double) -> [Placement] {
        let hasViewport = !viewport.isEmpty
            && viewport.width.isFinite && viewport.height.isFinite
            && viewport.midX.isFinite && viewport.midY.isFinite
        let zoomEmphasis = zoom.isFinite ? smoothstep(CGFloat(zoom), over: zoomGrowth) : 0
        let evaluated = candidates.map { candidate -> (candidate: Candidate, emphasis: CGFloat, distance: CGFloat) in
            guard hasViewport, candidate.point.x.isFinite, candidate.point.y.isFinite else {
                return (candidate, 0, .infinity)
            }
            let dx = candidate.point.x - viewport.midX
            let dy = candidate.point.y - viewport.midY
            let horizontal = 1 - smoothstep(abs(dx) / (viewport.width / 2), over: horizontalFade)
            let vertical = 1 - smoothstep(abs(dy) / (viewport.height / 2), over: verticalFade)
            return (candidate, zoomEmphasis * horizontal * vertical, dx * dx + dy * dy)
        }
        let ranked = evaluated.sorted { lhs, rhs in
            if lhs.candidate.isSelected != rhs.candidate.isSelected {
                return lhs.candidate.isSelected
            }
            if lhs.distance != rhs.distance {
                return lhs.distance < rhs.distance
            }
            return lhs.candidate.id < rhs.candidate.id
        }

        // Zero stays available for social markers; every ordinary address remains behind it.
        var ordinaryPriority = 0
        return ranked.map { entry in
            if !entry.candidate.isSelected {
                ordinaryPriority -= 1
            }
            return Placement(id: entry.candidate.id, emphasis: entry.emphasis,
                             priority: entry.candidate.isSelected ? 1 : ordinaryPriority)
        }
    }

    private static func smoothstep(_ value: CGFloat, over range: ClosedRange<CGFloat>) -> CGFloat {
        let progress = min(1, max(0, (value - range.lowerBound) / (range.upperBound - range.lowerBound)))
        return progress * progress * (3 - 2 * progress)
    }
}
