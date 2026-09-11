import XCTest
import UIKit

@MainActor
final class MapSocialGestureUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        #if DEBUG && targetEnvironment(simulator)
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        app = XCUIApplication()
        app.launchArguments = ["-debug-social-map"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Scénario carte sociale"].waitForExistence(timeout: 10))
        XCTAssertTrue(map.waitForExistence(timeout: 3))
        let portrait = NSPredicate { _, _ in
            self.app.windows.firstMatch.frame.height > self.app.windows.firstMatch.frame.width
        }
        expectation(for: portrait, evaluatedWith: app)
        waitForExpectations(timeout: 5)
        #else
        throw XCTSkip("Le scénario local nécessite Debug sur simulateur.")
        #endif
    }

    func testOpeningGroupAndClosingOnBackground() {
        let group = app.buttons["Groupe, 2 sorties prévues"]
        XCTAssertTrue(group.waitForExistence(timeout: 10))
        group.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        map.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.7)).tap()
        XCTAssertTrue(group.waitForExistence(timeout: 2))
        // XCTest waits for idle between actions. Rapid timing is verified by
        // simulator pointer injection and the diagnostic traces saved in the plan.
    }

    func testCancelLowerEventThenRemainingEvent() {
        cancelGroupRow(index: 1, expectedTitle: "Repas", remainingTitle: "Café")
        cancelRemainingEvent(title: "Café")
    }

    func testCancelUpperEventThenRemainingEvent() {
        cancelGroupRow(index: 0, expectedTitle: "Café", remainingTitle: "Repas")
        cancelRemainingEvent(title: "Repas")
    }

    func testMixedAndPeopleGroupsCloseOnBackground() {
        for (scenario, summary) in [
            ("Mixte", "3 personnes et 2 sorties prévues"),
            ("Utilisateurs", "3 personnes")
        ] {
            app.segmentedControls.buttons[scenario].tap()
            let group = app.buttons["Groupe, \(summary)"]
            XCTAssertTrue(group.waitForExistence(timeout: 3))
            group.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            XCTAssertTrue(app.buttons["Groupe ouvert, \(summary)"].waitForExistence(timeout: 2))
            map.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.7)).tap()
            XCTAssertTrue(group.waitForExistence(timeout: 2))
        }
    }

    func testNativePanClosesGroupAndMovesMap() {
        let group = app.buttons["Groupe, 2 sorties prévues"]
        XCTAssertTrue(group.waitForExistence(timeout: 3))
        let originalCenter = CGPoint(x: group.frame.midX, y: group.frame.midY)
        group.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(app.buttons["Groupe ouvert, 2 sorties prévues"].waitForExistence(timeout: 2))
        let start = map.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.7))
        let end = map.coordinate(withNormalizedOffset: CGVector(dx: 0.55, dy: 0.7))
        start.press(forDuration: 0.05, thenDragTo: end)
        XCTAssertTrue(group.waitForExistence(timeout: 2))
        XCTAssertGreaterThan(abs(group.frame.midX - originalCenter.x), 30)
    }

    func testNativePinchAndDoubleTapZoom() {
        let group = app.buttons["Groupe, 2 sorties prévues"]
        XCTAssertTrue(group.waitForExistence(timeout: 3))
        let user = app.buttons["Moi, Vous"]
        XCTAssertTrue(user.exists)
        func separation() -> CGFloat {
            hypot(group.frame.midX - user.frame.midX, group.frame.maxY - user.frame.maxY)
        }
        let originalSeparation = separation()
        // Send a native two-finger gesture centered on unobstructed map content.
        map.pinch(withScale: 1.3, velocity: 1)
        // Distance between two geographic anchors is independent of the pinch
        // center and of any simultaneous rotation performed by XCTest. MapKit
        // can still be animating after XCTest reports the application as idle.
        let pinchZoomed = NSPredicate { _, _ in
            group.exists && user.exists && separation() > originalSeparation * 1.15
        }
        expectation(for: pinchZoomed, evaluatedWith: app)
        waitForExpectations(timeout: 3)
        let afterPinchSeparation = separation()
        // Stay away from the annotations near the horizontal center, whose
        // hit targets can intercept the first tap after the pinch.
        map.coordinate(withNormalizedOffset: CGVector(dx: 0.25, dy: 0.5)).doubleTap()
        let doubleTapZoomed = NSPredicate { _, _ in
            group.exists && user.exists && separation() > afterPinchSeparation * 1.5
        }
        expectation(for: doubleTapZoomed, evaluatedWith: app)
        waitForExpectations(timeout: 3)
    }

    func testEventPaneDragResizesMapAndKeepsSelection() {
        openGroupedEvent(index: 0, title: "Café")
        XCTAssertLessThanOrEqual(detailPane.frame.maxY, resizeHandle.frame.minY + 2)
        XCTAssertLessThanOrEqual(resizeHandle.frame.maxY, map.frame.minY + 2)
        XCTAssertEqual(resizeHandle.frame.height, 44, accuracy: 1)
        attachScreenshot(named: "Fiche événement arrondie, ouverture au tiers")
        let initialDetailHeight = detailPane.frame.height
        let initialMapHeight = map.frame.height
        let dragDistance: CGFloat = 137
        let start = resizeHandle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: dragDistance)))

        let retainedHeight = NSPredicate { _, _ in
            abs(self.detailPane.frame.height - initialDetailHeight - dragDistance) < 8
        }
        expectation(for: retainedHeight, evaluatedWith: detailPane)
        waitForExpectations(timeout: 3)
        XCTAssertEqual(detailPane.frame.height, initialDetailHeight + dragDistance, accuracy: 8)
        XCTAssertEqual(map.frame.height, initialMapHeight - dragDistance, accuracy: 8)
        XCTAssertTrue(detailPane.staticTexts["Café"].firstMatch.exists)
        XCTAssertTrue(app.buttons["Retour aux événements"].isHittable)
        XCTAssertLessThanOrEqual(resizeHandle.frame.maxY, map.frame.minY + 2)
        attachScreenshot(named: "Fiche événement à hauteur libre, carte visible")
    }

    func testNativeMapRenderSizeStaysStableAcrossPaneChanges() {
        let nativeMap = app.maps.firstMatch
        let initialSize = nativeMap.frame.size
        openGroupedEvent(index: 0, title: "Café")
        XCTAssertEqual(nativeMap.frame.width, initialSize.width, accuracy: 1)
        XCTAssertEqual(nativeMap.frame.height, initialSize.height, accuracy: 1)

        for _ in 0..<3 {
            resizeHandle.tap()
            XCTAssertEqual(nativeMap.frame.width, initialSize.width, accuracy: 1)
            XCTAssertEqual(nativeMap.frame.height, initialSize.height, accuracy: 1)
        }
        app.buttons["Retour aux événements"].tap()
        XCTAssertTrue(eventList.waitForExistence(timeout: 3))
        XCTAssertEqual(nativeMap.frame.size.height, initialSize.height, accuracy: 1)
    }

    func testDockPanelsPreserveResizedMapDetail() {
        app.terminate()
        app.launchArguments = ["-debug-social-map", "-debug-social-map-fullscreen"]
        app.launch()
        XCTAssertTrue(map.waitForExistence(timeout: 10))
        openGroupedEvent(index: 0, title: "Café")
        let initialHeight = detailPane.frame.height
        let handle = resizeHandle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        handle.press(forDuration: 0.05, thenDragTo: handle.withOffset(CGVector(dx: 0, dy: 70)))
        XCTAssertGreaterThan(detailPane.frame.height, initialHeight + 40)
        let detailFrame = detailPane.frame
        let mapFrame = map.frame
        let user = app.buttons["Moi, Vous"]
        XCTAssertTrue(user.exists)
        let userFrame = user.frame

        func assertPreservedDetail() {
            XCTAssertTrue(detailPane.waitForExistence(timeout: 3))
            XCTAssertTrue(detailPane.staticTexts["Café"].firstMatch.exists)
            XCTAssertEqual(detailPane.frame.minY, detailFrame.minY, accuracy: 1)
            XCTAssertEqual(detailPane.frame.height, detailFrame.height, accuracy: 1)
            XCTAssertEqual(map.frame, mapFrame)
            XCTAssertEqual(user.frame.midX, userFrame.midX, accuracy: 2)
            XCTAssertEqual(user.frame.midY, userFrame.midY, accuracy: 2)
        }

        app.buttons["motion-dock-friends"].tap()
        XCTAssertTrue(app.textFields["Code ami"].waitForExistence(timeout: 3))
        attachScreenshot(named: "Amis superposé à la fiche redimensionnée")
        app.buttons["motion-dock-profile"].tap()
        XCTAssertTrue(app.textFields["Pseudo"].waitForExistence(timeout: 3))
        attachScreenshot(named: "Profil superposé à la fiche redimensionnée")
        app.buttons["motion-dock-explore"].tap()
        assertPreservedDetail()

        app.buttons["motion-dock-friends"].tap()
        XCTAssertTrue(app.textFields["Code ami"].waitForExistence(timeout: 3))
        app.buttons["motion-dock-friends"].tap()
        assertPreservedDetail()

        app.buttons["motion-dock-profile"].tap()
        XCTAssertTrue(app.textFields["Pseudo"].waitForExistence(timeout: 3))
        // Tap over the underlying detail: only the overlay closes.
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.13)).tap()
        assertPreservedDetail()
        attachScreenshot(named: "Fiche et carte conservées après fermeture du panneau")
        app.buttons["Retour aux événements"].tap()
        XCTAssertTrue(eventList.waitForExistence(timeout: 3))
    }

    func testPermanentPanelAndMapFillWindowBehindMotionDock() {
        app.terminate()
        app.launchArguments = ["-debug-social-map", "-debug-social-map-fullscreen"]
        app.launch()
        XCTAssertTrue(map.waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["motion-dock-explore"].isHittable)
        let window = app.windows.firstMatch.frame
        assertSharedMap(window: window)
        attachScreenshot(named: "Liste permanente et carte derrière les barres système")
        let nativeMap = app.maps.firstMatch
        let nativeSize = nativeMap.frame.size

        openGroupedEvent(index: 0, title: "Café")
        XCTAssertEqual(detailPane.frame.minY, window.minY, accuracy: 1)
        XCTAssertEqual(map.frame.maxY, window.maxY, accuracy: 1)
        XCTAssertTrue(app.buttons["Retour aux événements"].isHittable)
        for _ in 0..<3 {
            resizeHandle.tap()
            XCTAssertEqual(nativeMap.frame.width, nativeSize.width, accuracy: 0.01)
            XCTAssertEqual(nativeMap.frame.height, nativeSize.height, accuracy: 0.01)
            XCTAssertEqual(map.frame.maxY, window.maxY, accuracy: 1)
        }
        attachScreenshot(named: "Fiche ouverte et carte derrière le dock")
        app.buttons["Retour aux événements"].tap()
        XCTAssertTrue(eventList.waitForExistence(timeout: 3))
        assertSharedMap(window: window)
        // Wait for the panel state before tapping a command that moves during expansion.
        app.buttons["motion-dock-friends"].tap()
        XCTAssertTrue(app.textFields["Code ami"].waitForExistence(timeout: 3))
        app.buttons["motion-dock-explore"].tap()
        XCTAssertTrue(app.textFields["Code ami"].waitForNonExistence(timeout: 3))
        XCTAssertTrue(map.waitForExistence(timeout: 3))
        assertSharedMap(window: window)

        defer { XCUIDevice.shared.orientation = .portrait }
        XCUIDevice.shared.orientation = .landscapeLeft
        let landscape = NSPredicate { _, _ in
            self.app.windows.firstMatch.frame.width > self.app.windows.firstMatch.frame.height
        }
        expectation(for: landscape, evaluatedWith: app)
        waitForExpectations(timeout: 5)
        let landscapeWindow = app.windows.firstMatch.frame
        assertSharedMap(window: landscapeWindow)
        // The map now occupies the bottom of the window, including in landscape.
        let edge = map.coordinate(withNormalizedOffset: CGVector(dx: 1, dy: 0.35))
            .withOffset(CGVector(dx: -1, dy: 0))
        edge.press(forDuration: 0.05, thenDragTo: edge.withOffset(CGVector(dx: -120, dy: 0)))
        let emptyRail = app.images["Aucun ami"]
        XCTAssertTrue(emptyRail.waitForExistence(timeout: 3))
        let railSettled = NSPredicate { _, _ in
            emptyRail.isHittable && emptyRail.frame.maxX < landscapeWindow.maxX - 14
        }
        expectation(for: railSettled, evaluatedWith: emptyRail)
        waitForExpectations(timeout: 3)
        XCTAssertTrue(emptyRail.isHittable)
        XCTAssertLessThan(emptyRail.frame.maxX, landscapeWindow.maxX - 14)
        attachScreenshot(named: "Liste permanente et rail accessible en paysage")
    }

    func testResizeButtonCyclesSizesAndReturnPreservesPanel() {
        let fullMapHeight = map.frame.height
        openGroupedEvent(index: 1, title: "Repas")
        waitForResizeValue("Un tiers de l’écran")
        let initialHeight = detailPane.frame.height

        resizeHandle.tap()
        waitForResizeValue("Fiche agrandie")
        XCTAssertGreaterThan(detailPane.frame.height, initialHeight + 50)
        let expandedHeight = detailPane.frame.height

        resizeHandle.tap()
        waitForResizeValue("Fiche réduite")
        XCTAssertLessThan(detailPane.frame.height, expandedHeight)
        // Minimum readable height can clamp both compact and one-third presets.
        XCTAssertLessThanOrEqual(detailPane.frame.height, initialHeight)

        resizeHandle.tap()
        waitForResizeValue("Un tiers de l’écran")
        XCTAssertEqual(detailPane.frame.height, initialHeight, accuracy: 2)
        app.buttons["Retour aux événements"].tap()
        XCTAssertTrue(eventList.waitForExistence(timeout: 3))
        XCTAssertTrue(resizeHandle.isHittable)
        XCTAssertEqual(map.frame.height, fullMapHeight, accuracy: 2)
    }

    func testDetailScrollKeepsPaneAndHeaderInPlace() {
        openGroupedEvent(index: 0, title: "Café")
        resizeHandle.tap()
        resizeHandle.tap()
        waitForResizeValue("Fiche réduite")
        let paneHeight = detailPane.frame.height
        let handleY = resizeHandle.frame.minY
        let close = app.buttons["Retour aux événements"]
        let closeY = close.frame.minY
        let edit = app.buttons["Modifier l’événement"]
        XCTAssertTrue(edit.isHittable)
        let editY = edit.frame.midY
        let directions = app.buttons["Itinéraire"]
        XCTAssertTrue(directions.isHittable)
        XCTAssertEqual(editY, directions.frame.midY, accuracy: 2)

        app.scrollViews["outing-detail-scroll"].swipeUp()
        XCTAssertEqual(edit.frame.midY, editY, accuracy: 2)

        XCTAssertTrue(edit.isHittable)
        XCTAssertTrue(close.isHittable)
        XCTAssertEqual(close.frame.minY, closeY, accuracy: 2)
        XCTAssertEqual(detailPane.frame.height, paneHeight, accuracy: 2)
        XCTAssertEqual(resizeHandle.frame.minY, handleY, accuracy: 2)
        XCTAssertEqual(resizeHandle.value as? String, "Fiche réduite")
    }

    func testNativePanWorksInMapBelowEventPane() {
        openGroupedEvent(index: 0, title: "Café")
        let user = app.buttons["Moi, Vous"]
        XCTAssertTrue(user.waitForExistence(timeout: 3))
        let originalX = user.frame.midX
        let paneHeight = detailPane.frame.height
        let mapHeight = map.frame.height
        let start = map.coordinate(withNormalizedOffset: CGVector(dx: 0.15, dy: 0.7))
        let end = map.coordinate(withNormalizedOffset: CGVector(dx: 0.45, dy: 0.7))
        start.press(forDuration: 0.05, thenDragTo: end)
        let mapMoved = NSPredicate { _, _ in
            user.exists && abs(user.frame.midX - originalX) > 30
        }
        expectation(for: mapMoved, evaluatedWith: app)
        waitForExpectations(timeout: 3)
        XCTAssertTrue(detailPane.staticTexts["Café"].firstMatch.exists)
        XCTAssertEqual(detailPane.frame.height, paneHeight, accuracy: 2)
        XCTAssertEqual(map.frame.height, mapHeight, accuracy: 2)
    }

    func testMixedGroupOpensFriendAboveMap() {
        app.segmentedControls.buttons["Mixte"].tap()
        let group = app.buttons["Groupe, 3 personnes et 2 sorties prévues"]
        XCTAssertTrue(group.waitForExistence(timeout: 3))
        group.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        let expanded = app.buttons["Groupe ouvert, 3 personnes et 2 sorties prévues"]
        XCTAssertTrue(expanded.waitForExistence(timeout: 2))
        // People precede events, with the current user first and then Amina.
        tapExpandedRow(expanded, index: 1, rowCount: 5)

        XCTAssertTrue(detailPane.waitForExistence(timeout: 3))
        XCTAssertTrue(detailPane.staticTexts["Amina"].waitForExistence(timeout: 3))
        XCTAssertLessThanOrEqual(detailPane.frame.maxY, map.frame.minY)
        let profileScroll = app.scrollViews["friend-profile-scroll"]
        XCTAssertTrue(profileScroll.exists)
        reveal(app.buttons["Itinéraire"], in: profileScroll)
        XCTAssertTrue(app.buttons["Fermer la fiche de l’ami"].isHittable)
        app.buttons["Fermer la fiche de l’ami"].tap()
        XCTAssertTrue(eventList.waitForExistence(timeout: 3))
    }

    func testGuestActionsStayVisibleAndRespondAtEverySize() {
        launchDetailScenario(["guest", "stress", "open-event", "fullscreen"])
        let narrative = app.staticTexts["outing-detail-narrative"]
        XCTAssertTrue(narrative.waitForExistence(timeout: 3))
        XCTAssertTrue(narrative.label.contains("Invité 9"))
        XCTAssertFalse(app.staticTexts["Lieu de test"].exists)
        for _ in 0..<3 {
            assertGuestActionsOnOneLine()
            resizeHandle.tap()
        }
        let decline = app.buttons["Je ne participe pas"]
        decline.tap()
        XCTAssertTrue(decline.isSelected)
        XCTAssertTrue(narrative.label.contains("Ne participent pas : Vous"))
        let attend = app.buttons["Je participe"]
        attend.tap()
        XCTAssertTrue(attend.isSelected)
        XCTAssertFalse(decline.isSelected)
        XCTAssertFalse(narrative.label.contains("Ne participent pas : Vous"))
        app.buttons["Itinéraire"].tap()
        XCTAssertTrue(app.alerts["Itinéraire de test"].waitForExistence(timeout: 3))
        app.alerts.buttons["Fermer"].tap()
        attachScreenshot(named: "Résumé narratif et trois actions fixes")
    }

    func testUnavailableAndUpdatingParticipationKeepsDirectionsAccessible() {
        for state in ["loading", "unavailable", "updating"] {
            launchDetailScenario(["guest", "open-event", state])
            let attend = app.buttons["Je participe"]
            XCTAssertTrue(attend.waitForExistence(timeout: 3))
            XCTAssertFalse(attend.isEnabled)
            XCTAssertFalse(app.buttons["Je ne participe pas"].isEnabled)
            XCTAssertTrue(app.buttons["Itinéraire"].isEnabled)
            XCTAssertTrue(app.buttons["Itinéraire"].isHittable)
        }
    }

    func testFriendActionsRespectGhostAndMissingPosition() {
        for state in ["ghost", "missing-location", "stale"] {
            launchDetailScenario(["mixed", "open-friend", state])
            let directions = app.buttons["Itinéraire"]
            XCTAssertTrue(directions.waitForExistence(timeout: 3))
            XCTAssertEqual(directions.isEnabled, state == "stale")
            for _ in 0..<3 {
                XCTAssertTrue(app.buttons["Fermer la fiche de l’ami"].isHittable)
                XCTAssertLessThanOrEqual(directions.frame.maxY, resizeHandle.frame.minY)
                resizeHandle.tap()
                let settled = NSPredicate { _, _ in
                    directions.frame.maxY <= self.resizeHandle.frame.minY
                        && abs(self.detailPane.frame.maxY - self.resizeHandle.frame.minY) < 2
                }
                expectation(for: settled, evaluatedWith: app)
                waitForExpectations(timeout: 3)
            }
            if state == "stale" {
                directions.tap()
                XCTAssertTrue(app.alerts["Itinéraire de test"].waitForExistence(timeout: 3))
            }
        }
    }

    func testCompactGuestActionsAndMapRemainAvailable() {
        app.terminate()
        app.launchArguments = ["-debug-social-map", "-debug-social-map-guest", "-debug-social-map-stress",
                               "-debug-social-map-open-event", "-debug-social-map-fullscreen"]
        app.launch()
        XCTAssertTrue(detailPane.waitForExistence(timeout: 10))
        resizeHandle.tap()
        resizeHandle.tap()
        waitForResizeValue("Fiche réduite")
        assertGuestActionsOnOneLine()
        XCTAssertTrue(app.buttons["Retour aux événements"].isHittable)
        XCTAssertGreaterThan(map.frame.height, 100)
        let handleY = resizeHandle.frame.minY
        app.scrollViews["outing-detail-scroll"].swipeUp()
        XCTAssertEqual(resizeHandle.frame.minY, handleY, accuracy: 2)
        assertGuestActionsOnOneLine()
        attachScreenshot(named: "Fiche réduite")
        resizeHandle.tap()
        resizeHandle.tap()
        waitForResizeValue("Fiche agrandie")
        assertGuestActionsOnOneLine()
        app.scrollViews["outing-detail-scroll"].swipeDown()
        attachScreenshot(named: "Avatars en fiche agrandie")
        app.scrollViews["outing-detail-scroll"].swipeUp()
        attachScreenshot(named: "Participants en fiche agrandie")

        defer { XCUIDevice.shared.orientation = .portrait }
        XCUIDevice.shared.orientation = .landscapeLeft
        let landscape = NSPredicate { _, _ in
            self.app.windows.firstMatch.frame.width > self.app.windows.firstMatch.frame.height
        }
        expectation(for: landscape, evaluatedWith: app)
        waitForExpectations(timeout: 5)
        resizeHandle.tap()
        waitForResizeValue("Fiche réduite")
        assertGuestActionsOnOneLine()
        XCTAssertGreaterThan(app.scrollViews["outing-detail-scroll"].frame.height, 70)
        XCTAssertGreaterThan(map.frame.height, 60)
        attachScreenshot(named: "Actions et résumé accessibles en paysage")
    }

    private func launchDetailScenario(_ options: [String]) {
        app.terminate()
        app.launchArguments = ["-debug-social-map"] + options.map { "-debug-social-map-" + $0 }
        app.launch()
        XCTAssertTrue(detailPane.waitForExistence(timeout: 10))
    }

    private func assertGuestActionsOnOneLine() {
        let buttons = ["Itinéraire", "Je ne participe pas", "Je participe"].map { app.buttons[$0] }
        for button in buttons {
            XCTAssertTrue(button.isHittable, button.label)
            XCTAssertGreaterThanOrEqual(button.frame.width + 0.01, 44, button.label)
            XCTAssertGreaterThanOrEqual(button.frame.height + 0.01, 44, button.label)
            XCTAssertEqual(button.frame.midY, buttons[0].frame.midY, accuracy: 2)
            XCTAssertLessThanOrEqual(button.frame.maxY, resizeHandle.frame.minY)
            XCTAssertGreaterThanOrEqual(button.frame.minX, detailPane.frame.minX)
            XCTAssertLessThanOrEqual(button.frame.maxX, detailPane.frame.maxX)
        }
        XCTAssertLessThanOrEqual(buttons[0].frame.maxX, buttons[1].frame.minX)
        XCTAssertLessThanOrEqual(buttons[1].frame.maxX, buttons[2].frame.minX)
    }

    func testEventListIsDefaultAndSorted() {
        XCTAssertTrue(eventList.waitForExistence(timeout: 3))
        resizeHandle.tap()
        waitForResizeValue("Fiche agrandie")
        let meal = eventRow(1)
        let coffee = eventRow(2)
        XCTAssertTrue(meal.isHittable)
        XCTAssertTrue(coffee.exists)
        XCTAssertLessThan(meal.frame.minY, coffee.frame.minY)
        meal.tap()
        XCTAssertTrue(app.buttons["Retour aux événements"].waitForExistence(timeout: 3))
        XCTAssertTrue(detailPane.staticTexts["Repas"].exists)
        // The native collection stays mounted to preserve its scroll position.
        XCTAssertFalse(eventList.isHittable)
        app.buttons["Retour aux événements"].tap()
        XCTAssertTrue(eventList.waitForExistence(timeout: 3))
        attachScreenshot(named: "Liste des événements visible par défaut")
    }

    func testEventListResizeScrollAndReturnPreservePosition() {
        launchDetailScenario(["many-events", "fullscreen"])
        XCTAssertTrue(eventList.waitForExistence(timeout: 3))
        let firstMapHeight = map.frame.height
        let visibleBefore = visibleEventRows.count
        let initialRowHeight = eventRow(1).frame.height
        resizeHandle.tap()
        waitForResizeValue("Fiche agrandie")
        XCTAssertGreaterThan(visibleEventRows.count, visibleBefore)
        XCTAssertEqual(eventRow(1).frame.height, initialRowHeight, accuracy: 2)
        XCTAssertLessThan(map.frame.height, firstMapHeight)
        let paneFrame = detailPane.frame
        eventList.swipeUp()
        let row = visibleEventRows.first {
            $0.frame.minY > eventList.frame.minY + 10
                && $0.frame.maxY < eventList.frame.maxY - 10
        }
        guard let row else { XCTFail("Aucune ligne entièrement visible après défilement"); return }
        let rowFrame = row.frame
        XCTAssertFalse(eventRow(1).exists && eventRow(1).isHittable)
        row.tap()
        XCTAssertTrue(app.buttons["Retour aux événements"].waitForExistence(timeout: 3))
        app.buttons["Retour aux événements"].tap()
        XCTAssertTrue(eventList.waitForExistence(timeout: 3))
        XCTAssertEqual(detailPane.frame.minX, paneFrame.minX, accuracy: 0.5)
        XCTAssertEqual(detailPane.frame.minY, paneFrame.minY, accuracy: 0.5)
        XCTAssertEqual(detailPane.frame.width, paneFrame.width, accuracy: 0.5)
        XCTAssertEqual(detailPane.frame.height, paneFrame.height, accuracy: 0.5)
        XCTAssertEqual(row.frame.minY, rowFrame.minY, accuracy: 2)
        attachScreenshot(named: "Liste agrandie et défilement conservé après consultation")
    }

    func testEventListEmptyLoadingAndErrorStates() {
        for (option, identifier) in [
            ("empty-list", "events-list-empty"),
            ("list-loading", "events-list-loading"),
            ("list-error", "events-list-error"),
            ("partial-list-error", "events-list-error")
        ] {
            launchDetailScenario([option, "fullscreen"])
            XCTAssertTrue(app.descendants(matching: .any)[identifier].firstMatch.waitForExistence(timeout: 3))
            if option != "empty-list" {
                XCTAssertFalse(app.staticTexts["events-list-empty"].exists)
            }
            if option == "partial-list-error" {
                XCTAssertTrue(eventRow(1).exists)
            }
        }
    }

    func testEventListCanRespondAndCancelWithoutMapTap() {
        launchDetailScenario(["guest", "fullscreen"])
        eventRow(1).tap()
        app.buttons["Je participe"].tap()
        XCTAssertTrue(app.staticTexts["Vous participez"].waitForExistence(timeout: 3))
        app.buttons["Retour aux événements"].tap()
        eventRow(1).tap()
        app.buttons["Je ne participe pas"].tap()
        XCTAssertTrue(app.staticTexts["Vous ne participez pas"].waitForExistence(timeout: 3))
        app.buttons["Itinéraire"].tap()
        XCTAssertTrue(app.alerts["Itinéraire de test"].waitForExistence(timeout: 3))
        app.alerts.buttons["Fermer"].tap()

        launchDetailScenario(["fullscreen"])
        eventRow(1).tap()
        cancelPresentedEvent(title: "Repas")
        XCTAssertTrue(eventList.waitForExistence(timeout: 3))
        XCTAssertFalse(eventRow(1).exists)
        XCTAssertTrue(eventRow(2).isHittable)
    }

    func testEventListNarrativeWithoutHeadersAndResponseAfterReturn() {
        launchDetailScenario(["social-list", "fullscreen"])
        XCTAssertFalse(detailPane.staticTexts["Événements"].exists)
        XCTAssertFalse(app.buttons["events-list-filter"].exists)
        XCTAssertFalse(detailPane.staticTexts["Aujourd’hui"].exists)
        XCTAssertFalse(detailPane.staticTexts["Demain"].exists)
        XCTAssertTrue(eventRow(1).label.contains("Théo organise un repas"))
        XCTAssertTrue(eventRow(1).label.contains("Lieu : Bistrot du parc"))
        XCTAssertTrue(eventRow(1).label.contains("Vous n’avez pas encore répondu"))
        XCTAssertTrue(eventRow(1).label.contains("à vol d’oiseau"))
        attachScreenshot(named: "Liste en phrases sans en-tête")
        resizeHandle.tap()
        waitForResizeValue("Fiche agrandie")
        attachScreenshot(named: "Phrases et avatars dans la liste agrandie")
        eventRow(2).tap()
        app.buttons["Je ne participe pas"].tap()
        XCTAssertTrue(app.staticTexts["Vous ne participez pas"].waitForExistence(timeout: 3))
        app.buttons["Retour aux événements"].tap()
        XCTAssertTrue(eventRow(2).isHittable)
        XCTAssertTrue(eventRow(2).label.contains("Vous ne participez pas"))
        XCTAssertTrue(eventRow(3).label.contains("Vous organisez"))
        attachScreenshot(named: "Réponse intégrée à la phrase après consultation")
    }

    func testEventListNarrativeWithLongPlaceAndMissingOrStaleLocation() {
        for option in ["list-no-location", "list-stale-location"] {
            launchDetailScenario(["guest", "stress", "fullscreen", option])
            XCTAssertFalse(eventRow(1).label.contains("à vol d’oiseau"))
            XCTAssertTrue(eventRow(1).label.contains("Café du parc et des promenades au bord de la rivière"))
            resizeHandle.tap()
            waitForResizeValue("Fiche agrandie")
            attachScreenshot(named: "Phrase longue avec lieu complet")
            eventRow(1).tap()
            XCTAssertTrue(app.buttons["Retour aux événements"].waitForExistence(timeout: 3))
            app.buttons["Retour aux événements"].tap()
            XCTAssertTrue(eventRow(1).isHittable)
        }
    }

    func testEventListParticipantGroupsAndUnknownStates() {
        launchDetailScenario(["participants-list", "guest", "fullscreen", "list-no-location"])
        resizeHandle.tap()
        waitForResizeValue("Fiche agrandie")
        XCTAssertTrue(eventRow(1).label.contains("Aucun autre participant"))
        XCTAssertTrue(eventRow(2).label.contains("avec Invité 1. Lieu"))
        XCTAssertTrue(eventRow(3).label.contains("Invité 3"))
        attachScreenshot(named: "Participants zéro, un et trois avec le lieu")
        eventList.swipeUp()
        XCTAssertTrue(eventRow(4).isHittable)
        XCTAssertTrue(eventRow(4).label.contains("Invité 5"))
        // Let native overscroll spring back before recording its composited frame.
        RunLoop.main.run(until: Date().addingTimeInterval(1))
        attachScreenshot(named: "Trois avatars et deux participants supplémentaires")
        eventRow(4).tap()
        XCTAssertTrue(app.buttons["Retour aux événements"].waitForExistence(timeout: 3))
        app.buttons["Retour aux événements"].tap()
        XCTAssertTrue(eventRow(4).isHittable)
        RunLoop.main.run(until: Date().addingTimeInterval(1))
        attachScreenshot(named: "Groupe de cinq conservé au retour")
        for (option, message) in [("loading", "Chargement des participants"), ("unavailable", "Participants indisponibles")] {
            launchDetailScenario(["guest", "fullscreen", option])
            XCTAssertTrue(eventRow(1).label.contains(message))
            XCTAssertFalse(eventRow(1).label.contains("Aucun autre participant"))
            attachScreenshot(named: message)
        }
    }

    func testEventListRequestsRostersOnScrollAndSuspendsOutsideExplorer() {
        launchDetailScenario(["many-events", "guest", "fullscreen", "roster-probe"])
        let probe = app.staticTexts["debug-list-rosters"]
        XCTAssertTrue(probe.waitForExistence(timeout: 3))
        func requestedIDs() -> String { (probe.value as? String ?? "").components(separatedBy: ";")[0] }
        let firstIDs = requestedIDs()
        XCTAssertFalse(firstIDs.isEmpty)
        XCTAssertLessThan(firstIDs.components(separatedBy: ",").count, 18)
        resizeHandle.tap()
        waitForResizeValue("Fiche agrandie")
        eventList.swipeUp()
        XCTAssertNotEqual(requestedIDs(), firstIDs)
        XCTAssertLessThan(requestedIDs().components(separatedBy: ",").count, 18)
        app.buttons["motion-dock-friends"].tap()
        XCTAssertTrue(app.textFields["Code ami"].waitForExistence(timeout: 3))
        app.buttons["motion-dock-explore"].tap()
        XCTAssertTrue(probe.waitForExistence(timeout: 3))
        XCTAssertTrue((probe.value as? String ?? "").contains("suspended=true"))
        XCTAssertFalse(requestedIDs().isEmpty)
    }

    func testCompactListDensityAndDirectSwipeActions() {
        launchDetailScenario(["social-list", "fullscreen"])
        XCTAssertGreaterThanOrEqual(eventRow(1).frame.height, 70)
        XCTAssertLessThanOrEqual(eventRow(1).frame.height, 94)
        let initialHandle = resizeHandle.frame
        eventRow(1).swipeLeft()
        XCTAssertTrue(app.buttons["Participer"].waitForExistence(timeout: 3))
        app.buttons["Participer"].tap()
        XCTAssertTrue(eventRow(1).label.contains("Vous participez"))
        XCTAssertTrue(eventRow(2).label.contains("Vous participez"))
        XCTAssertFalse(app.buttons["Retour aux événements"].exists)
        eventRow(1).swipeLeft()
        app.buttons["Ne pas participer"].tap()
        XCTAssertTrue(eventRow(1).label.contains("Vous ne participez pas"))
        XCTAssertTrue(eventRow(2).label.contains("Vous participez"))
        XCTAssertEqual(resizeHandle.frame.minY, initialHandle.minY, accuracy: 1)
        resizeHandle.tap()
        waitForResizeValue("Fiche agrandie")
        RunLoop.main.run(until: Date().addingTimeInterval(1))
        attachScreenshot(named: "Agenda social compact et réponses directes")
        eventRow(3).swipeLeft()
        XCTAssertTrue(app.buttons["Modifier"].waitForExistence(timeout: 3))
        app.buttons["Modifier"].tap()
        XCTAssertTrue(app.buttons["Annuler cet événement"].waitForExistence(timeout: 3))
    }

    func testCompactListUnknownOrUpdatingResponseCannotBeSwiped() {
        for option in ["loading", "unavailable", "updating"] {
            launchDetailScenario(["guest", "fullscreen", option])
            eventRow(1).swipeLeft()
            XCTAssertFalse(app.buttons["Participer"].exists)
            XCTAssertFalse(app.buttons["Ne pas participer"].exists)
            XCTAssertTrue(eventRow(1).exists)
        }
    }

    func testEventListInLandscape() {
        app.terminate()
        app.launchArguments = ["-debug-social-map", "-debug-social-map-many-events", "-debug-social-map-fullscreen"]
        app.launch()
        XCTAssertTrue(eventList.waitForExistence(timeout: 10))
        resizeHandle.tap()
        waitForResizeValue("Fiche agrandie")
        XCTAssertTrue(eventRow(1).isHittable)
        eventRow(1).tap()
        XCTAssertTrue(app.buttons["Retour aux événements"].waitForExistence(timeout: 3))
        app.buttons["Retour aux événements"].tap()
        XCTAssertTrue(eventList.waitForExistence(timeout: 3))
        attachScreenshot(named: "Liste")

        defer { XCUIDevice.shared.orientation = .portrait }
        XCUIDevice.shared.orientation = .landscapeLeft
        let landscape = NSPredicate { _, _ in
            self.app.windows.firstMatch.frame.width > self.app.windows.firstMatch.frame.height
        }
        expectation(for: landscape, evaluatedWith: app)
        waitForExpectations(timeout: 5)
        XCTAssertTrue(resizeHandle.isHittable)
        XCTAssertGreaterThan(map.frame.height, 40)
        let handleY = resizeHandle.frame.minY
        eventList.swipeUp()
        XCTAssertEqual(resizeHandle.frame.minY, handleY, accuracy: 2)
        XCTAssertTrue(eventList.isHittable)
        attachScreenshot(named: "Liste en paysage")
    }

    private func assertSharedMap(window: CGRect) {
        XCTAssertEqual(detailPane.frame.minY, window.minY, accuracy: 1)
        XCTAssertEqual(map.frame.maxY, window.maxY, accuracy: 1)
        XCTAssertLessThanOrEqual(detailPane.frame.maxY, resizeHandle.frame.minY + 2)
        XCTAssertEqual(resizeHandle.frame.maxY, map.frame.minY, accuracy: 1)
        XCTAssertEqual(map.frame.width, window.width, accuracy: 1)
    }

    private var eventList: XCUIElement {
        // With no header, SwiftUI exposes the collection itself as the detail pane.
        app.collectionViews.matching(NSPredicate(
            format: "identifier IN %@", ["events-list", "map-detail-pane"]
        )).firstMatch
    }

    private var visibleEventRows: [XCUIElement] {
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "event-list-row-"))
            .allElementsBoundByIndex.filter { $0.isHittable }
    }

    private func eventRow(_ number: Int) -> XCUIElement {
        app.buttons[String(format: "event-list-row-00000000-0000-4000-8000-%012d", number)]
    }

    // MARK: - Scenario interactions

    private var map: XCUIElement { app.otherElements["map-visible-viewport"].firstMatch }

    private var detailPane: XCUIElement {
        app.descendants(matching: .any)["map-detail-pane"].firstMatch
    }

    private var resizeHandle: XCUIElement {
        app.descendants(matching: .any)["map-detail-resize-handle"].firstMatch
    }

    private func waitForResizeValue(_ value: String) {
        let resized = NSPredicate(format: "value == %@", value)
        expectation(for: resized, evaluatedWith: resizeHandle)
        waitForExpectations(timeout: 3)
    }

    private func openGroupedEvent(index: Int, title: String) {
        let group = app.buttons["Groupe, 2 sorties prévues"]
        XCTAssertTrue(group.waitForExistence(timeout: 10))
        group.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        let expanded = app.buttons["Groupe ouvert, 2 sorties prévues"]
        XCTAssertTrue(expanded.waitForExistence(timeout: 2))
        tapExpandedRow(expanded, index: index, rowCount: 2)
        XCTAssertTrue(detailPane.waitForExistence(timeout: 3))
        XCTAssertTrue(detailPane.staticTexts[title].firstMatch.waitForExistence(timeout: 3))
    }

    private func tapExpandedRow(_ group: XCUIElement, index: Int, rowCount: Int) {
        // The group exposes VoiceOver actions; pointer tests target its visible
        // rows instead of invoking those actions and bypassing UIKit gestures.
        // The simulator's text size also enlarges native cluster rows. Use the
        // visible list height, which is capped when all rows cannot fit.
        let rowHeight = clusterRowHeight
        let listHeight = min(360, CGFloat(rowCount) * rowHeight + 12, map.frame.height - 32)
        let offset = listHeight - 6 - (CGFloat(index) + 0.5) * rowHeight
        group.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 1))
            .withOffset(CGVector(dx: 0, dy: -offset)).tap()
    }

    private var clusterRowHeight: CGFloat {
        UIApplication.shared.preferredContentSizeCategory.isAccessibilityCategory ? 72 : 58
    }

    private func attachScreenshot(named name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func cancelGroupRow(index: Int, expectedTitle: String, remainingTitle: String) {
        openGroupedEvent(index: index, title: expectedTitle)
        cancelPresentedEvent(title: expectedTitle)
        XCTAssertTrue(eventPin(remainingTitle).waitForExistence(timeout: 3))
        XCTAssertFalse(eventPin(expectedTitle).exists)
    }

    private func cancelRemainingEvent(title: String) {
        eventPin(title).coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        cancelPresentedEvent(title: title)
        XCTAssertFalse(eventPin(title).exists)
        XCTAssertFalse(app.buttons["Groupe, 2 sorties prévues"].exists)
    }

    private func cancelPresentedEvent(title: String) {
        XCTAssertTrue(app.staticTexts[title].firstMatch.waitForExistence(timeout: 3))
        let edit = app.buttons["Modifier l’événement"]
        reveal(edit, in: app.scrollViews["outing-detail-scroll"])
        edit.tap()
        let cancel = app.buttons["Annuler cet événement"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 3))
        if !cancel.isHittable { app.swipeUp() }
        cancel.tap()
        app.buttons["Annuler l’événement"].tap()
        XCTAssertTrue(edit.waitForNonExistence(timeout: 3))
    }

    private func reveal(_ element: XCUIElement, in scrollView: XCUIElement) {
        XCTAssertTrue(scrollView.waitForExistence(timeout: 3))
        for _ in 0..<8 where !element.isHittable {
            scrollView.swipeUp()
        }
        XCTAssertTrue(element.isHittable)
    }

    private func eventPin(_ title: String) -> XCUIElement {
        app.buttons["Votre sortie prévue, \(title), organisateur seul"]
    }
}

/// Opt-in by selecting this class on a connected device. It only opens and
/// resizes an existing event; it never creates or edits account data.
@MainActor
final class MapDeviceSmokeUITests: XCTestCase {
    func testRealEventResizingWithMetalValidation() throws {
        #if targetEnvironment(simulator)
        throw XCTSkip("Ce contrôle nécessite l’iPhone connecté et ses événements existants.")
        #else
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["MTL_DEBUG_LAYER"] = "1"
        app.launch()
        let explore = app.buttons["motion-dock-explore"]
        if explore.waitForExistence(timeout: 15) { explore.tap() }
        let nativeMap = app.maps.firstMatch
        XCTAssertTrue(nativeMap.waitForExistence(timeout: 15))
        let viewport = app.otherElements["map-visible-viewport"].firstMatch
        XCTAssertTrue(viewport.waitForExistence(timeout: 3))
        let window = app.windows.firstMatch.frame
        XCTAssertEqual(viewport.frame.maxY, window.maxY, accuracy: 1)
        XCTAssertGreaterThan(viewport.frame.minY, window.minY)
        XCTAssertTrue(app.buttons["Filtres de la carte"].isHittable)
        XCTAssertTrue(app.buttons["Recentrer la carte sur ma position"].isHittable)
        let fullScreenCapture = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        fullScreenCapture.name = "Carte plein écran sur iPhone"
        fullScreenCapture.lifetime = .keepAlways
        add(fullScreenCapture)
        let nativeSize = nativeMap.frame.size
        let events = app.buttons.matching(NSPredicate(
            format: "label BEGINSWITH %@ OR label BEGINSWITH %@",
            "Votre sortie prévue,", "Sortie prévue,"
        ))
        guard events.firstMatch.waitForExistence(timeout: 15) else {
            throw XCTSkip("Aucune sortie existante directement accessible pour ce contrôle.")
        }

        for cycle in 0..<4 {
            let event = try XCTUnwrap(events.allElementsBoundByIndex.first(where: \.isHittable))
            event.tap()
            let handle = app.buttons["map-detail-resize-handle"]
            XCTAssertTrue(handle.waitForExistence(timeout: 5))
            for _ in 0..<3 {
                handle.tap()
                XCTAssertEqual(nativeMap.frame.width, nativeSize.width, accuracy: 1)
                XCTAssertEqual(nativeMap.frame.height, nativeSize.height, accuracy: 1)
                XCTAssertTrue(app.buttons["Retour aux événements"].isHittable)
                XCTAssertEqual(viewport.frame.maxY, window.maxY, accuracy: 1)
                XCTAssertEqual(app.state, .runningForeground)
            }
            let start = handle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: -100)))
            XCTAssertEqual(nativeMap.frame.height, nativeSize.height, accuracy: 1)
            if cycle == 0 {
                let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
                screenshot.name = "Fiche arrondie sur iPhone avec Metal actif"
                screenshot.lifetime = .keepAlways
                add(screenshot)
            }
            app.buttons["Retour aux événements"].tap()
            XCTAssertTrue(handle.isHittable)
            XCTAssertEqual(nativeMap.frame.height, nativeSize.height, accuracy: 1)
            XCTAssertEqual(viewport.frame.maxY, window.maxY, accuracy: 1)
            XCTAssertGreaterThan(viewport.frame.minY, window.minY)
        }
        #endif
    }
}
