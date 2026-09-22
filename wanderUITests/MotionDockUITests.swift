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
        let tabFrames = ["explore", "friends"].map { command($0).frame }
        command("friends").doubleTap()
        XCTAssertTrue(app.textFields["Code ami"].waitForNonExistence(timeout: 3))
        XCTAssertTrue(command("explore").isSelected)
        assertTabFrames(tabFrames)
        let start = command("explore").coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let end = command("friends").coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.6, thenDragTo: end)
        XCTAssertTrue(app.textFields["Code ami"].waitForExistence(timeout: 3))
        XCTAssertTrue(command("friends").isSelected)
        XCTAssertFalse(command("profile").exists)
        assertPanelAboveTabBar()
        attachScreenshot("Barre native après appui maintenu et glissement")
    }

    func testEventsButtonSitsBesideNativeTabsAndTogglesList() {
        let tabBar = app.tabBars["native-map-tab-bar"]
        let events = command("events")
        XCTAssertTrue(events.waitForExistence(timeout: 3))
        XCTAssertEqual(tabBar.buttons.count, 2)
        XCTAssertFalse(tabBar.buttons["motion-dock-events"].exists)
        XCTAssertGreaterThanOrEqual(events.frame.minX, tabBar.frame.maxX)
        XCTAssertGreaterThanOrEqual(events.frame.width, 44)
        XCTAssertGreaterThanOrEqual(events.frame.height, 44)
        XCTAssertLessThanOrEqual(events.frame.maxX, app.windows.firstMatch.frame.maxX)
        XCTAssertEqual(events.frame.midY, command("friends").frame.midY, accuracy: 2,
                       "Le calendrier doit être centré verticalement sur les onglets.")
        XCTAssertTrue(events.isHittable)
        XCTAssertFalse(events.isSelected)
        XCTAssertFalse(eventList.isHittable)
        let nativeMapSize = app.maps.firstMatch.frame.size
        let fullMapFrame = mapViewport.frame
        let tabFrames = ["explore", "friends"].map { command($0).frame }
        let buttonFrame = events.frame

        events.tap()
        XCTAssertTrue(eventList.waitForExistence(timeout: 3))
        XCTAssertTrue(eventList.isHittable)
        XCTAssertTrue(events.isSelected)
        XCTAssertTrue(command("explore").isSelected)
        XCTAssertEqual(mapViewport.frame.maxY, eventsHandle.frame.minY, accuracy: 2)
        XCTAssertLessThan(mapViewport.frame.height, fullMapFrame.height)
        XCTAssertLessThanOrEqual(eventList.frame.maxY, events.frame.minY)
        XCTAssertEqual(app.maps.firstMatch.frame.size, nativeMapSize)
        XCTAssertEqual(events.frame, buttonFrame)
        assertTabFrames(tabFrames)

        events.tap()
        XCTAssertTrue(eventsHandle.waitForNonExistence(timeout: 3))
        XCTAssertFalse(eventList.isHittable)
        XCTAssertFalse(events.isSelected)
        XCTAssertEqual(mapViewport.frame, fullMapFrame)
        XCTAssertEqual(app.maps.firstMatch.frame.size, nativeMapSize)
        assertEventsFrame(buttonFrame)
        assertTabFrames(tabFrames)
        attachScreenshot("Bouton événements à droite de la barre native")
    }

    func testEventsButtonReturnsFromPanelsAndOpensAfterFriendSheetCloses() {
        let buttonFrame = command("events").frame
        for (panel, field) in [("friends", "Code ami")] {
            command(panel).tap()
            XCTAssertTrue(app.textFields[field].waitForExistence(timeout: 3))
            XCTAssertFalse(command("events").isSelected)
            XCTAssertFalse(eventList.isHittable)
            assertEventsFrame(buttonFrame)
            command("events").tap()
            XCTAssertTrue(app.textFields[field].waitForNonExistence(timeout: 3))
            XCTAssertTrue(command("explore").isSelected)
            XCTAssertTrue(command("events").isSelected)
            XCTAssertTrue(eventList.isHittable)
            XCTAssertTrue(eventsHandle.isHittable)
            assertEventsFrame(buttonFrame)

            command("events").tap()
            XCTAssertTrue(eventsHandle.waitForNonExistence(timeout: 3))
            XCTAssertFalse(command("events").isSelected)
            assertEventsFrame(buttonFrame)

            command("events").tap()
            XCTAssertTrue(eventsHandle.waitForExistence(timeout: 3))
            assertEventsFrame(buttonFrame)
        }

        app.terminate()
        app.launchArguments += ["-debug-social-map-mixed", "-debug-social-map-open-friend"]
        app.launch()
        let friendPane = app.scrollViews["friend-profile-scroll"].firstMatch
        XCTAssertTrue(friendPane.waitForExistence(timeout: 10))
        XCTAssertTrue(friendPane.staticTexts["Amina"].exists)
        XCTAssertFalse(command("events").isSelected)
        let nativeMapSize = app.maps.firstMatch.frame.size
        let start = friendPane.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.1))
        let bottom = app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.98))
        start.press(forDuration: 0.05, thenDragTo: bottom)
        XCTAssertTrue(friendPane.waitForNonExistence(timeout: 3))
        command("events").tap()
        XCTAssertTrue(eventList.waitForExistence(timeout: 3))
        XCTAssertTrue(eventList.isHittable)
        XCTAssertTrue(command("events").isSelected)
        XCTAssertTrue(command("explore").isSelected)
        XCTAssertFalse(app.buttons["map-detail-resize-handle"].exists)
        XCTAssertEqual(app.maps.firstMatch.frame.size, nativeMapSize)
    }

    func testImageButtonEdgesOpenTheirSheets() {
        let events = command("events")
        XCTAssertEqual(events.frame.width, 44, accuracy: 1)
        XCTAssertEqual(events.frame.height, 44, accuracy: 1)
        XCTAssertEqual(profileButton.frame.width, 44, accuracy: 1)
        XCTAssertEqual(profileButton.frame.height, 44, accuracy: 1)

        // Touch near either edge of each image, which fills its 44 pt control.
        for edge in [0.08, 0.92] {
            events.coordinate(withNormalizedOffset: CGVector(dx: edge, dy: 0.5)).tap()
            XCTAssertTrue(eventList.waitForExistence(timeout: 3))
            XCTAssertTrue(events.isSelected)
            events.coordinate(withNormalizedOffset: CGVector(dx: edge, dy: 0.5)).tap()
            XCTAssertTrue(eventList.waitForNonExistence(timeout: 3))
            XCTAssertFalse(events.isSelected)

            profileButton.coordinate(withNormalizedOffset: CGVector(dx: edge, dy: 0.5)).tap()
            XCTAssertTrue(ownSheet.waitForExistence(timeout: 3))
            closeOwnSheet()
        }
    }

    func testFriendsPanelClosesFromActiveCommandAndProfileUsesSheet() {
        let originalMap = app.maps.firstMatch.frame
        let tabFrames = ["explore", "friends"].map { command($0).frame }
        command("friends").tap()
        XCTAssertTrue(app.textFields["Code ami"].waitForExistence(timeout: 3))
        XCTAssertEqual(app.staticTexts["motion-dock-heading"].label, "Amis")
        assertTabFrames(tabFrames)
        assertPanelAboveTabBar()
        command("friends").tap()
        XCTAssertTrue(app.textFields["Code ami"].waitForNonExistence(timeout: 3))
        XCTAssertTrue(command("explore").isSelected)
        XCTAssertFalse(command("profile").exists)
        XCTAssertFalse(app.buttons["Filtres de la carte"].exists)
        let group = app.buttons["Groupe, 2 sorties prévues"]
        XCTAssertTrue(group.waitForExistence(timeout: 5))
        let panStart = app.maps.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.6))
        panStart.press(
            forDuration: 0.05,
            thenDragTo: panStart.withOffset(CGVector(dx: 70, dy: 0)),
            withVelocity: .slow,
            thenHoldForDuration: 0.3
        )
        let groupFrame = group.frame
        let profileFrame = profileButton.frame
        profileButton.tap()
        XCTAssertTrue(ownSheet.waitForExistence(timeout: 3))
        XCTAssertTrue(profileButton.exists)
        XCTAssertTrue(profileButton.isHittable)
        XCTAssertEqual(profileButton.frame, profileFrame)
        XCTAssertTrue(ownSheet.staticTexts["Moi"].exists)
        XCTAssertFalse(app.otherElements["motion-dock-panel"].exists)
        assertMapMarkerRemains(group, at: groupFrame)
        closeOwnSheet()
        assertMapMarkerRemains(group, at: groupFrame)
        XCTAssertTrue(profileButton.isHittable)
        XCTAssertEqual(profileButton.frame, profileFrame)
        XCTAssertEqual(app.maps.firstMatch.frame, originalMap)
        assertTabFrames(tabFrames)
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
        XCTAssertFalse(app.scrollViews["friend-profile-scroll"].firstMatch.isHittable)
        XCTAssertFalse(eventList.isHittable)
        XCTAssertFalse(command("events").isSelected)
    }

    func testKeyboardAndDraftSurvivePanelSwitch() {
        command("friends").tap()
        let code = app.textFields["Code ami"]
        XCTAssertTrue(code.waitForExistence(timeout: 3))
        code.tap()
        code.typeText("WANDER")
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 3))
        XCTAssertTrue(command("events").isHittable)
        XCTAssertLessThanOrEqual(command("events").frame.maxY, app.keyboards.firstMatch.frame.minY)
        XCTAssertEqual(command("events").frame.midY, command("friends").frame.midY, accuracy: 2)
        command("explore").tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 3))
        profileButton.tap()
        XCTAssertTrue(ownSheet.waitForExistence(timeout: 3))
        closeOwnSheet()
        command("friends").tap()
        XCTAssertTrue(code.waitForExistence(timeout: 3))
        XCTAssertEqual(code.value as? String, "WANDER")
        command("explore").tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 3))
        XCTAssertTrue(app.maps.firstMatch.exists)
        command("friends").tap()
        XCTAssertTrue(code.waitForExistence(timeout: 3))
        code.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 3))
        command("events").tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 3))
        XCTAssertTrue(command("explore").isSelected)
        XCTAssertTrue(command("events").isSelected)
        XCTAssertTrue(eventList.isHittable)
    }

    func testProfileSettingsPersistBetweenButtonAndAvatarAndConfirmationStaysInSheet() {
        profileButton.tap()
        XCTAssertTrue(ownSheet.waitForExistence(timeout: 3))
        let compactTop = ownSheet.frame.minY
        ownSheet.swipeUp()
        let expanded = NSPredicate { _, _ in self.ownSheet.frame.minY < compactTop - 50 }
        expectation(for: expanded, evaluatedWith: ownSheet)
        waitForExpectations(timeout: 3)
        let heatMap = ownSheet.switches["profile-heat-map"]
        revealInOwnSheet(heatMap)
        XCTAssertEqual(heatMap.value as? String, "0")
        heatMap.tap()
        XCTAssertEqual(heatMap.value as? String, "1")
        let name = ownSheet.textFields["Pseudo"]
        revealInOwnSheet(name)
        name.tap()
        name.typeText(" test")
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 3))
        name.typeText("\n")
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 3))
        let confirmation = ownSheet.buttons["Confirmation de test"]
        revealInOwnSheet(confirmation)
        confirmation.tap()
        XCTAssertTrue(app.alerts["Action de test"].waitForExistence(timeout: 3))
        app.alerts.buttons["Annuler"].tap()
        XCTAssertTrue(ownSheet.exists)
        attachScreenshot("Réglages du profil dans la feuille unique")
        closeOwnSheet()

        let user = app.buttons["Moi test, Vous"]
        XCTAssertTrue(user.waitForExistence(timeout: 3))
        user.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(ownSheet.waitForExistence(timeout: 3))
        XCTAssertTrue(ownSheet.staticTexts["Moi test"].exists)
        revealInOwnSheet(heatMap)
        XCTAssertEqual(heatMap.value as? String, "1")
        revealInOwnSheet(name)
        XCTAssertEqual(name.value as? String, "Moi test")
    }

    func testLandscapeKeepsCommandsReachable() {
        XCUIDevice.shared.orientation = .landscapeLeft
        defer { XCUIDevice.shared.orientation = .portrait }
        let landscapeReady = NSPredicate { _, _ in
            let window = self.app.windows.firstMatch.frame
            let button = self.command("friends")
            return window.width > window.height && button.isHittable
                && button.frame.maxY <= window.maxY
        }
        expectation(for: landscapeReady, evaluatedWith: app)
        waitForExpectations(timeout: 5)
        command("friends").tap()
        XCTAssertTrue(app.textFields["Code ami"].waitForExistence(timeout: 3))
        XCTAssertTrue(command("events").isHittable)
        XCTAssertLessThanOrEqual(command("events").frame.maxX, app.windows.firstMatch.frame.maxX)
        XCTAssertEqual(command("events").frame.midY, command("friends").frame.midY, accuracy: 2)
        command("explore").tap()
        XCTAssertTrue(app.textFields["Code ami"].waitForNonExistence(timeout: 3))
        XCTAssertTrue(profileButton.isHittable)
        profileButton.tap()
        XCTAssertTrue(ownSheet.waitForExistence(timeout: 3))
        let name = ownSheet.textFields["Pseudo"]
        revealInOwnSheet(name)
        XCTAssertTrue(name.isHittable)
        attachScreenshot("Profil en feuille paysage")
    }

    private func assertMapMarkerRemains(_ marker: XCUIElement, at frame: CGRect) {
        let moved = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in
                !marker.exists || abs(marker.frame.midX - frame.midX) > 2
                    || abs(marker.frame.midY - frame.midY) > 2
            },
            object: nil
        )
        moved.isInverted = true
        // Observe long enough to catch the deferred sheet camera animation.
        wait(for: [moved], timeout: 1)
    }

    private var profileButton: XCUIElement { app.buttons["map-own-profile"] }

    private var ownSheet: XCUIElement {
        app.descendants(matching: .any)["own-profile-scroll"].firstMatch
    }

    private func revealInOwnSheet(_ element: XCUIElement) {
        for _ in 0..<10 {
            if element.isHittable { return }
            ownSheet.swipeUp()
        }
        XCTAssertTrue(element.isHittable)
    }

    private func closeOwnSheet() {
        for _ in 0..<8 {
            if ownSheet.staticTexts["Exploration"].isHittable { break }
            ownSheet.swipeDown()
        }
        let start = ownSheet.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.02))
        let bottom = app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.98))
        start.press(forDuration: 0.05, thenDragTo: bottom)
        XCTAssertTrue(ownSheet.waitForNonExistence(timeout: 3))
    }

    private var eventList: XCUIElement {
        app.descendants(matching: .any)["events-expanded-list"].firstMatch
    }

    private var eventsHandle: XCUIElement { app.buttons["map-events-resize-handle"] }

    private var mapViewport: XCUIElement { app.otherElements["map-visible-viewport"].firstMatch }

    private func assertEventsFrame(_ expected: CGRect, file: StaticString = #filePath, line: UInt = #line) {
        let actual = command("events").frame
        XCTAssertEqual(actual.width, expected.width, accuracy: 1, file: file, line: line)
        XCTAssertEqual(actual.height, expected.height, accuracy: 1, file: file, line: line)
        XCTAssertEqual(actual.midX, expected.midX, accuracy: 1, file: file, line: line)
        XCTAssertEqual(actual.midY, expected.midY, accuracy: 1, file: file, line: line)
    }

    private func assertTabFrames(_ expected: [CGRect]) {
        for (name, frame) in zip(["explore", "friends"], expected) {
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
