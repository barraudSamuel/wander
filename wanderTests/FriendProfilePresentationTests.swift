import SwiftUI
import UIKit
import XCTest
@testable import wander

@MainActor
final class FriendProfilePresentationTests: XCTestCase {
    func testNativePreparationMeasuresBeforePresentationCompletesAndNeverRepeats() async throws {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let scene = try XCTUnwrap(scenes.first { $0.activationState == .foregroundActive } ?? scenes.first)
        let window = UIWindow(windowScene: scene)
        window.frame = scene.effectiveGeometry.coordinateSpace.bounds
        let root = UIViewController()
        window.rootViewController = root
        window.isHidden = false
        defer {
            root.dismiss(animated: false)
            window.isHidden = true
            window.rootViewController = nil
        }

        let presented = UIViewController()
        presented.modalPresentationStyle = .pageSheet
        let content = FriendProfilePresentationController()
        let body = AnyView(profileBody)
        var tops: [CGFloat] = []
        var didCompletePresentation = false
        content.update(content: body, scroll: AnyView(ScrollView { body })) { top in
            XCTAssertFalse(didCompletePresentation, "Framing must be prepared before opening finishes")
            tops.append(top)
        }
        presented.addChild(content)
        presented.view.addSubview(content.view)
        content.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            content.view.leadingAnchor.constraint(equalTo: presented.view.leadingAnchor),
            content.view.trailingAnchor.constraint(equalTo: presented.view.trailingAnchor),
            content.view.topAnchor.constraint(equalTo: presented.view.topAnchor),
            content.view.bottomAnchor.constraint(equalTo: presented.view.bottomAnchor)
        ])
        content.didMove(toParent: presented)
        await withCheckedContinuation { continuation in
            root.present(presented, animated: true) {
                didCompletePresentation = true
                continuation.resume()
            }
        }

        let sheet = try XCTUnwrap(presented.sheetPresentationController)
        let container = try XCTUnwrap(sheet.containerView)
        XCTAssertEqual(tops.count, 1)
        XCTAssertEqual(try XCTUnwrap(tops.first),
                       container.convert(sheet.frameOfPresentedViewInContainerView, to: window).minY,
                       accuracy: 1)
        let height = try XCTUnwrap(content.preparedHeight)
        XCTAssertGreaterThan(height, 128)
        XCTAssertEqual(sheet.selectedDetentIdentifier, FriendProfilePresentationController.compactDetent)
        sheet.animateChanges { sheet.selectedDetentIdentifier = .large }
        content.prepare(sheet: sheet)
        content.update(content: AnyView(Text("Live data changed")), scroll: AnyView(Text("Updated"))) { _ in
            XCTFail("Live updates must not issue a second framing request")
        }
        content.view.layoutIfNeeded()
        XCTAssertEqual(tops.count, 1)
        XCTAssertEqual(content.preparedHeight, height)
    }

    func testSharedBodyMeasurementUsesActualWidth() {
        let host = UIHostingController(rootView: profileBody)
        host.safeAreaRegions = []
        let narrow = host.sizeThatFits(in: CGSize(width: 240, height: 2_000))
        let wide = host.sizeThatFits(in: CGSize(width: 420, height: 2_000))
        XCTAssertGreaterThan(narrow.height, wide.height)
        XCTAssertEqual(narrow.width, 240, accuracy: 1)
        XCTAssertEqual(wide.width, 420, accuracy: 1)
    }

    private var profileBody: FriendProfileBody {
        FriendProfileBody(
            displayName: "Un nom assez long pour se répartir sur plusieurs lignes",
            avatarID: ProfileAvatar.generatedID(seed: "measurement"),
            profileColorHex: "#3366FF", isGhostModeEnabled: false,
            location: nil, isLocationFresh: false,
            onDismiss: {}, onOpenDirections: {}
        )
    }
}
