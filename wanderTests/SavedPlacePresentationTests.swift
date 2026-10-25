import UIKit
import XCTest
@testable import wander

@MainActor
final class SavedPlacePresentationTests: XCTestCase {
    func testMapEmphasisChangesSizeContinuouslyAndDelaysTheLabel() {
        let compact = SavedPlaceAnnotationView.Geometry(emphasis: 0, labelWidth: 80)
        let middle = SavedPlaceAnnotationView.Geometry(emphasis: 0.5, labelWidth: 80)
        let detailed = SavedPlaceAnnotationView.Geometry(emphasis: 1, labelWidth: 80)
        XCTAssertEqual(compact.state.width, 24)
        XCTAssertEqual(middle.state.width, 37)
        XCTAssertEqual(detailed.state.width, 50)
        XCTAssertEqual(middle.state.tip, 3)
        XCTAssertEqual(compact.state.stickerOpacity, 0)
        XCTAssertGreaterThan(middle.state.stickerOpacity, 0)
        XCTAssertLessThan(middle.state.stickerOpacity, 0.1)
        XCTAssertEqual(detailed.state.stickerOpacity, 1)
        XCTAssertEqual(SavedPlaceAnnotationView.Geometry(emphasis: -1, labelWidth: 80).state, compact.state)
        XCTAssertEqual(SavedPlaceAnnotationView.Geometry(emphasis: 2, labelWidth: 80).state, detailed.state)
    }

    func testEmphasisRetargetPreservesPositionAndVelocityThroughReversal() {
        var motion = SavedPlaceEmphasisMotion()
        motion.retarget(1)
        motion.advance(by: 0.06)
        let value = motion.value
        let velocity = motion.velocity
        XCTAssertGreaterThan(value, 0)
        XCTAssertGreaterThan(velocity, 0)
        motion.retarget(0)
        XCTAssertEqual(motion.value, value)
        XCTAssertEqual(motion.velocity, velocity)
        motion.advance(by: 0.000001)
        XCTAssertEqual((motion.value - value) / 0.000001, velocity, accuracy: 0.002)
        motion.advance(by: 1)
        XCTAssertTrue(motion.isSettled)
        XCTAssertEqual(motion.value, 0)
    }

    func testRepeatedCameraTargetsDoNotRestartOrFreezeTheMotion() {
        var motion = SavedPlaceEmphasisMotion()
        var lastValue: CGFloat = 0
        for step in 1...60 {
            motion.retarget(CGFloat(step) / 60)
            motion.advance(by: 1 / 60)
            XCTAssertGreaterThan(motion.value, lastValue)
            lastValue = motion.value
        }
        XCTAssertGreaterThan(motion.value, 0.9)
        motion.advance(by: 1)
        XCTAssertEqual(motion.value, 1)
        XCTAssertTrue(motion.isSettled)
    }

    func testEmphasisIntegrationIsIndependentOfFrameInterval() {
        var sixtyHertz = SavedPlaceEmphasisMotion()
        var oneTwentyHertz = SavedPlaceEmphasisMotion()
        for target: CGFloat in [1, 0.4, 0.9, 0, 1] {
            sixtyHertz.retarget(target)
            oneTwentyHertz.retarget(target)
            for _ in 0..<6 { sixtyHertz.advance(by: 1 / 60) }
            for _ in 0..<12 { oneTwentyHertz.advance(by: 1 / 120) }
            XCTAssertEqual(sixtyHertz.value, oneTwentyHertz.value, accuracy: 0.000001)
            XCTAssertEqual(sixtyHertz.velocity, oneTwentyHertz.velocity, accuracy: 0.000001)
        }
    }

    func testNumericTargetAndRenderedGeometryAreIndependentDuringMotion() async throws {
        let (pin, window, previousWindow) = try hostPin()
        defer { window.isHidden = true; window.rootViewController = nil; previousWindow?.makeKey() }
        pin.setMapEmphasis(1)
        XCTAssertEqual(pin.presentationGeometry.circleRect.width, 50)
        XCTAssertEqual(pin.renderedBodyRect.width, 24)
        XCTAssertFalse(pin.containsRenderedPoint(CGPoint(x: 20, y: -30)),
                       "Hit testing must use the photo on screen, not its larger target")
        try await Task.sleep(for: .milliseconds(60))
        let width = pin.renderedBodyRect.width
        XCTAssertGreaterThan(width, 24)
        XCTAssertLessThan(width, 50)
        XCTAssertEqual(pin.renderedAnchorInHost.x, 22, accuracy: 0.001)
        XCTAssertEqual(pin.renderedAnchorInHost.y, 22, accuracy: 0.001)
        pin.setMapEmphasis(0.4)
        XCTAssertEqual(pin.presentationGeometry.circleRect.width, 34.4, accuracy: 0.001)
        XCTAssertEqual(pin.renderedBodyRect.width, width, accuracy: 0.001)
        try await Task.sleep(for: .milliseconds(650))
        XCTAssertEqual(pin.renderedBodyRect.width, 34.4, accuracy: 0.001)
        XCTAssertFalse(pin.isTransitioning)
    }

    func testSameTargetDoesNotReenterTheCompletionCallback() {
        let pin = makePin()
        var completions = 0
        pin.onPresentationTransitionEnd = {
            completions += 1
            pin.setMapEmphasis(0.65)
        }
        pin.setMapEmphasis(0.65, animated: false)
        XCTAssertEqual(completions, 1)
        XCTAssertEqual(pin.renderedBodyRect.width, 40.9, accuracy: 0.001)
    }

    func testReusingOrDetachingAPinStopsItsMotion() async throws {
        let (pin, window, previousWindow) = try hostPin()
        defer { window.isHidden = true; window.rootViewController = nil; previousWindow?.makeKey() }
        pin.setMapEmphasis(1)
        XCTAssertTrue(pin.isTransitioning)
        pin.removeFromSuperview()
        XCTAssertFalse(pin.isTransitioning)
        XCTAssertEqual(pin.renderedBodyRect.width, 50)
        window.rootViewController?.view.addSubview(pin)
        pin.setMapEmphasis(0)
        XCTAssertTrue(pin.isTransitioning)
        pin.prepareForReuse()
        XCTAssertFalse(pin.isTransitioning)
        XCTAssertEqual(pin.mapEmphasis, 0)
        XCTAssertEqual(pin.renderedBodyRect.width, 24)
        try await Task.sleep(for: .milliseconds(80))
        XCTAssertEqual(pin.renderedBodyRect.width, 24)
    }

    func testSelectionKeepsOnlyThePhotoAndMinimumTouchTargetInteractive() {
        let pin = makePin()
        for selected in [false, true] {
            pin.setSelected(selected, animated: false)
            XCTAssertTrue(pin.point(inside: CGPoint(x: 22, y: 10), with: nil))
            XCTAssertFalse(pin.point(inside: CGPoint(x: -100, y: -100), with: nil))
            XCTAssertFalse(pin.point(inside: CGPoint(x: 22, y: -120), with: nil),
                           "Selection must not create an invisible card hit target")
            XCTAssertFalse(pin.point(inside: CGPoint(x: 0, y: 40), with: nil))
        }
    }

    func testLateIllustrationPreservesTheInFlightSizeAndFallbackRemainsUsable() async throws {
        let (pin, window, previousWindow) = try hostPin()
        defer { window.isHidden = true; window.rootViewController = nil; previousWindow?.makeKey() }
        let visual = try XCTUnwrap(pin.subviews.compactMap { $0 as? SavedPlaceCalloutView }.first)
        XCTAssertNil(visual.photoView.image)
        XCTAssertFalse(visual.fallbackView.isHidden)
        pin.setMapEmphasis(1)
        pin.setSelected(true, animated: true)
        try await Task.sleep(for: .milliseconds(60))
        let width = pin.renderedBodyRect.width
        let image = try XCTUnwrap(SavedPlaceIllustration.image(for: "pin-fixture"))
        pin.updatePhoto(image)
        XCTAssertEqual(pin.renderedBodyRect.width, width, accuracy: 0.001)
        XCTAssertTrue(pin.isTransitioning)
        XCTAssertTrue(visual.photoView.image === image)
        XCTAssertTrue(visual.fallbackView.isHidden)
        try await Task.sleep(for: .milliseconds(650))
        pin.updatePhoto(nil)
        XCTAssertTrue(pin.isSelected)
        XCTAssertFalse(pin.isTransitioning)
        XCTAssertFalse(visual.fallbackView.isHidden)
        XCTAssertEqual(pin.renderedBodyRect.width, 50)
    }

    func testSelectionDoesNotInterruptSizeOrChangeItsTarget() async throws {
        let (pin, window, previousWindow) = try hostPin()
        defer { window.isHidden = true; window.rootViewController = nil; previousWindow?.makeKey() }
        pin.setMapEmphasis(1)
        try await Task.sleep(for: .milliseconds(60))
        let intermediateWidth = pin.renderedBodyRect.width
        XCTAssertGreaterThan(intermediateWidth, 24)
        XCTAssertLessThan(intermediateWidth, 50)
        pin.setSelected(true, animated: true)
        XCTAssertEqual(pin.renderedBodyRect.width, intermediateWidth)
        XCTAssertEqual(pin.presentationGeometry.circleRect.width, 50)
        XCTAssertTrue(pin.isTransitioning)
        XCTAssertTrue(pin.isAccessibilityElement)
        XCTAssertTrue(pin.accessibilityTraits.contains(.selected))
        try await Task.sleep(for: .milliseconds(40))
        XCTAssertGreaterThan(pin.renderedBodyRect.width, intermediateWidth)

        pin.setMapEmphasis(0.4)
        let beforeDismissal = pin.renderedBodyRect.width
        pin.setSelected(false, animated: true)
        XCTAssertEqual(pin.renderedBodyRect.width, beforeDismissal)
        XCTAssertTrue(pin.isTransitioning)
        try await Task.sleep(for: .milliseconds(650))
        XCTAssertEqual(pin.renderedBodyRect.width, 34.4, accuracy: 0.001)
        XCTAssertEqual(pin.renderedAnchorInHost.x, 22, accuracy: 0.001)
        XCTAssertEqual(pin.renderedAnchorInHost.y, 22, accuracy: 0.001)
        XCTAssertFalse(pin.isTransitioning)
    }

    func testSelectedPinFollowsZoomDownToCompactWithoutChangingPhotoAnchor() async throws {
        let (pin, window, previousWindow) = try hostPin()
        defer { window.isHidden = true; window.rootViewController = nil; previousWindow?.makeKey() }
        pin.setMapEmphasis(1, animated: false)
        pin.setSelected(true, animated: false)
        pin.setMapEmphasis(0)
        try await Task.sleep(for: .milliseconds(60))
        XCTAssertGreaterThan(pin.renderedBodyRect.width, 24)
        XCTAssertLessThan(pin.renderedBodyRect.width, 50)
        try await Task.sleep(for: .milliseconds(650))
        XCTAssertEqual(pin.renderedBodyRect.width, 24)
        XCTAssertTrue(pin.isSelected)
        XCTAssertFalse(pin.showsLabels)
        XCTAssertFalse(pin.isTransitioning)
        XCTAssertEqual(pin.renderedAnchorInHost, CGPoint(x: 22, y: 22))
    }

    func testEveryMapSizeKeepsTheTipAtTheGeographicPoint() {
        for step in 0...100 {
            let geometry = SavedPlaceAnnotationView.Geometry(emphasis: CGFloat(step) / 100, labelWidth: 90)
            XCTAssertEqual(geometry.contentSize, CGSize(width: 44, height: 44))
            XCTAssertEqual(geometry.anchor, CGPoint(x: 22, y: 22))
            XCTAssertEqual(geometry.state.bodyRect.midX, 0, accuracy: 0.001)
            XCTAssertEqual(geometry.state.bodyRect.maxY + geometry.state.tip, 0, accuracy: 0.001)
        }
    }

    private func hostPin() throws -> (SavedPlaceAnnotationView, UIWindow, UIWindow?) {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previousWindow = scene.windows.first(where: \.isKeyWindow)
        let window = UIWindow(windowScene: scene)
        let controller = UIViewController()
        window.frame = scene.effectiveGeometry.coordinateSpace.bounds
        window.rootViewController = controller
        let pin = makePin()
        controller.view.addSubview(pin)
        pin.frame = CGRect(x: 160, y: 430, width: 44, height: 44)
        window.makeKeyAndVisible()
        window.layoutIfNeeded()
        return (pin, window, previousWindow)
    }

    private func makePin() -> SavedPlaceAnnotationView {
        let imported = NaverImportedPlace(id: "pin-fixture", name: "Café de démonstration", address: "Adresse fictive",
                                         latitude: 37, longitude: 127, naverURL: URL(string: "https://map.naver.com/")!,
                                         isUnavailable: false, hasLocationWarning: false, categoryCode: "CAFE", categoryName: "Café")
        let annotation = SavedPlaceAnnotation(place: SavedPlace(place: imported, ownerID: "test", listName: "Tests"))
        let pin = SavedPlaceAnnotationView(annotation: annotation, reuseIdentifier: nil)
        pin.configure(with: annotation)
        return pin
    }
}
