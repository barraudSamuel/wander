import UIKit
import XCTest
@testable import wander

@MainActor
final class OutingCategoryBadgeViewTests: XCTestCase {
    func testUnchangedParticipantsKeepTheirViewsThroughLayoutAndStyleUpdates() throws {
        let badge = OutingCategoryBadgeView(frame: CGRect(x: 0, y: 0, width: 40, height: 40))
        let avatars = ["skull", "radiant-eye", "star-eye", "wave-hair"]
        configure(badge, avatars: avatars)
        let originalAvatars = avatarViews(in: badge)
        let originalCounter = try XCTUnwrap(counter(in: badge))
        XCTAssertEqual(originalAvatars.count, 3)
        XCTAssertEqual(originalCounter.text, "+1")

        for size in [CGFloat(48), 56, 40] {
            badge.frame.size = CGSize(width: size, height: size)
            badge.configure(
                category: .walk, profileColorHex: "#FF9500", isCurrentUser: true,
                participantAvatarIDs: avatars
            )
            badge.layoutIfNeeded()
            XCTAssertEqual(avatarViews(in: badge).map(ObjectIdentifier.init), originalAvatars.map(ObjectIdentifier.init))
            XCTAssertTrue(counter(in: badge) === originalCounter)
        }
    }

    func testReorderedAndReplacedParticipantsUpdateDisplayedImages() throws {
        let badge = OutingCategoryBadgeView()
        configure(badge, avatars: ["skull", "radiant-eye"])
        let originalAvatars = avatarViews(in: badge)
        let skullImage = try XCTUnwrap(originalAvatars.first?.image)
        let eyeImage = try XCTUnwrap(originalAvatars.last?.image)

        configure(badge, avatars: ["radiant-eye", "skull"])
        let reorderedAvatars = avatarViews(in: badge)
        XCTAssertEqual(reorderedAvatars.count, 2)
        XCTAssertEqual(reorderedAvatars.first?.image, eyeImage)
        XCTAssertEqual(reorderedAvatars.last?.image, skullImage)

        configure(badge, avatars: ["star-eye"])
        let replacement = try XCTUnwrap(avatarViews(in: badge).first?.image)
        XCTAssertEqual(avatarViews(in: badge).count, 1)
        XCTAssertEqual(replacement, try XCTUnwrap(UIImage(named: ProfileAvatar.starEye.assetName)))
        XCTAssertNil(counter(in: badge))
    }

    func testParticipantCountChangesAndEmptyRosterRemoveStaleViews() {
        let badge = OutingCategoryBadgeView()
        configure(badge, avatars: Array(repeating: "skull", count: 5))
        XCTAssertEqual(avatarViews(in: badge).count, 3)
        XCTAssertEqual(counter(in: badge)?.text, "+2")

        configure(badge, avatars: Array(repeating: "skull", count: 4))
        XCTAssertEqual(counter(in: badge)?.text, "+1")
        configure(badge, avatars: Array(repeating: "skull", count: 3))
        XCTAssertEqual(avatarViews(in: badge).count, 3)
        XCTAssertNil(counter(in: badge))

        let removedViews = avatarViews(in: badge)
        configure(badge, avatars: [])
        XCTAssertTrue(avatarViews(in: badge).isEmpty)
        XCTAssertNil(counter(in: badge))
        XCTAssertTrue(removedViews.allSatisfy { $0.superview == nil })

        configure(badge, avatars: ["skull"])
        XCTAssertEqual(avatarViews(in: badge).count, 1)
    }

    private func configure(_ badge: OutingCategoryBadgeView, avatars: [String]) {
        badge.configure(
            category: .coffee, profileColorHex: "#3478F6", isCurrentUser: false,
            participantAvatarIDs: avatars
        )
    }

    private func avatarViews(in badge: OutingCategoryBadgeView) -> [UIImageView] {
        badge.subviews.compactMap { $0 as? UIImageView }
    }

    private func counter(in badge: OutingCategoryBadgeView) -> UILabel? {
        badge.subviews.compactMap { $0 as? UILabel }.first
    }
}
