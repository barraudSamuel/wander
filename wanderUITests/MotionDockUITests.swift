import XCTest
import UIKit

@MainActor
final class MotionDockUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        app = XCUIApplication()
        app.launchArguments = ["-debug-social-map", "-debug-social-map-fullscreen"]
        app.launch()
        XCTAssertTrue(command("friends").waitForExistence(timeout: 10))
    }

    func testUsesNativeTabBarAndSupportsPressThenSlide() {
        let tabBar = app.tabBars["native-map-tab-bar"]
        XCTAssertTrue(tabBar.waitForExistence(timeout: 3), "La navigation doit utiliser la barre système.")
        let tabFrames = ["explore", "friends", "profile"].map { command($0).frame }
        command("friends").doubleTap()
        XCTAssertTrue(app.textFields["Code ami"].waitForNonExistence(timeout: 3))
        XCTAssertTrue(command("explore").isSelected)
        assertTabFrames(tabFrames)
        let start = command("friends").coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let end = command("profile").coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.6, thenDragTo: end)
        XCTAssertTrue(app.textFields["Pseudo"].waitForExistence(timeout: 3))
        XCTAssertTrue(command("profile").isSelected)
        assertPanelAboveTabBar()
        attachScreenshot("Barre native après appui maintenu et glissement")
    }

    func testSwitchPanelsAndCloseFromActiveCommand() {
        let originalMap = app.maps.firstMatch.frame
        let tabFrames = ["explore", "friends", "profile"].map { command($0).frame }
        command("friends").tap()
        XCTAssertTrue(app.textFields["Code ami"].waitForExistence(timeout: 3))
        XCTAssertEqual(app.staticTexts["motion-dock-heading"].label, "Amis")
        XCTAssertFalse(app.navigationBars.firstMatch.isHittable)
        assertTabFrames(tabFrames)
        assertPanelAboveTabBar()
        attachScreenshot("Panneau Amis")
        command("profile").tap()
        XCTAssertTrue(app.textFields["Pseudo"].waitForExistence(timeout: 3))
        XCTAssertEqual(app.staticTexts["motion-dock-heading"].label, "Profil")
        XCTAssertFalse(app.navigationBars.firstMatch.isHittable)
        assertTabFrames(tabFrames)
        assertPanelAboveTabBar()
        attachScreenshot("Panneau Profil")
        XCTAssertFalse(app.textFields["Code ami"].exists)
        command("profile").tap()
        XCTAssertTrue(app.textFields["Pseudo"].waitForNonExistence(timeout: 3))
        XCTAssertEqual(app.maps.firstMatch.frame, originalMap)
    }

    func testOutsideTapOnlyClosesPanelAndPreservesCamera() {
        let map = app.maps.firstMatch
        let group = app.buttons["Groupe, 2 sorties prévues"]
        XCTAssertTrue(group.waitForExistence(timeout: 5))
        let user = app.buttons["Moi, Vous"]
        XCTAssertTrue(user.exists)
        let originalSeparation = hypot(
            group.frame.midX - user.frame.midX,
            group.frame.maxY - user.frame.maxY
        )
        map.pinch(withScale: 1.3, velocity: 1)
        let zoomed = NSPredicate { _, _ in
            hypot(group.frame.midX - user.frame.midX, group.frame.maxY - user.frame.maxY)
                > originalSeparation * 1.15
        }
        expectation(for: zoomed, evaluatedWith: app)
        waitForExpectations(timeout: 3)

        let beforePanX = group.frame.midX
        let panStart = map.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.7))
        panStart.press(
            forDuration: 0.05,
            thenDragTo: panStart.withOffset(CGVector(dx: 70, dy: 0)),
            withVelocity: .slow,
            thenHoldForDuration: 0.3
        )
        XCTAssertGreaterThan(abs(group.frame.midX - beforePanX), 30)
        let mapFrame = map.frame
        let groupFrame = group.frame
        command("friends").tap()
        XCTAssertTrue(app.textFields["Code ami"].waitForExistence(timeout: 3))
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.15)).tap()
        XCTAssertTrue(app.textFields["Code ami"].waitForNonExistence(timeout: 3))
        XCTAssertEqual(map.frame, mapFrame)
        XCTAssertEqual(group.frame.midX, groupFrame.midX, accuracy: 2)
        XCTAssertEqual(group.frame.midY, groupFrame.midY, accuracy: 2)
        XCTAssertTrue(app.descendants(matching: .any)["map-detail-pane"].firstMatch.isHittable)
    }

    func testKeyboardAndDraftSurvivePanelSwitch() {
        command("friends").tap()
        let code = app.textFields["Code ami"]
        XCTAssertTrue(code.waitForExistence(timeout: 3))
        code.tap()
        code.typeText("WANDER")
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 3))
        XCTAssertTrue(command("profile").isHittable)
        command("profile").tap()
        XCTAssertTrue(app.textFields["Pseudo"].waitForExistence(timeout: 3))
        command("friends").tap()
        XCTAssertTrue(code.waitForExistence(timeout: 3))
        XCTAssertEqual(code.value as? String, "WANDER")
        command("explore").tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 3))
        XCTAssertTrue(app.maps.firstMatch.exists)
    }

    func testLongContentScrollsAndConfirmationKeepsProfile() {
        command("profile").tap()
        XCTAssertTrue(app.textFields["Pseudo"].waitForExistence(timeout: 3))
        app.buttons["Confirmation de test"].tap()
        XCTAssertTrue(app.alerts["Action de test"].waitForExistence(timeout: 3))
        app.alerts.buttons["Annuler"].tap()
        XCTAssertTrue(command("profile").isSelected)
        for _ in 0..<6 {
            if app.staticTexts["Réglage 30"].isHittable { break }
            app.collectionViews.firstMatch.swipeUp()
        }
        XCTAssertTrue(app.staticTexts["Réglage 30"].isHittable)
        XCTAssertTrue(command("friends").isHittable)
        attachScreenshot("Profil défilant")
    }

    func testLandscapeKeepsCommandsReachable() {
        app.terminate()
        app.launch()
        XCTAssertTrue(command("friends").waitForExistence(timeout: 10))
        command("friends").tap()
        XCTAssertTrue(app.textFields["Code ami"].waitForExistence(timeout: 3))
        attachScreenshot("Amis")
        XCUIDevice.shared.orientation = .landscapeLeft
        defer { XCUIDevice.shared.orientation = .portrait }
        let landscapeReady = NSPredicate { _, _ in
            let window = self.app.windows.firstMatch.frame
            let button = self.command("profile")
            return window.width > window.height && button.isHittable
                && button.frame.maxY <= window.maxY
        }
        expectation(for: landscapeReady, evaluatedWith: app)
        waitForExpectations(timeout: 5)
        XCTAssertTrue(command("profile").isHittable)
        command("profile").tap()
        XCTAssertTrue(app.textFields["Pseudo"].waitForExistence(timeout: 3))
        XCTAssertTrue(command("explore").isHittable)
        attachScreenshot("Profil paysage")
        command("explore").tap()
        XCTAssertTrue(app.textFields["Pseudo"].waitForNonExistence(timeout: 3))
    }

    private func assertTabFrames(_ expected: [CGRect]) {
        for (name, frame) in zip(["explore", "friends", "profile"], expected) {
            XCTAssertEqual(command(name).frame.midX, frame.midX, accuracy: 1)
            XCTAssertEqual(command(name).frame.midY, frame.midY, accuracy: 1)
        }
    }

    private func assertPanelAboveTabBar() {
        let panel = app.otherElements["motion-dock-panel"].firstMatch
        XCTAssertTrue(panel.exists)
        XCTAssertLessThanOrEqual(panel.frame.maxY, app.tabBars["native-map-tab-bar"].frame.minY)
    }

    private func command(_ name: String) -> XCUIElement {
        app.buttons["motion-dock-" + name]
    }

    private func attachScreenshot(_ name: String) {
        // App-window snapshots can crop the rotated window on Simulator.
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
