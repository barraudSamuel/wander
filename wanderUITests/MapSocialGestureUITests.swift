import XCTest
import UIKit

@MainActor
final class MapSocialGestureUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        #if DEBUG && targetEnvironment(simulator)
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-debug-social-map"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Scénario carte sociale"].waitForExistence(timeout: 10))
        XCTAssertTrue(map.waitForExistence(timeout: 3))
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
        attachScreenshot(named: "Fiche événement arrondie, moitié de l’écran")
        let initialDetailHeight = detailPane.frame.height
        let initialMapHeight = map.frame.height
        let start = resizeHandle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: 150)))

        waitForResizeValue("Fiche agrandie")
        XCTAssertGreaterThan(detailPane.frame.height, initialDetailHeight + 50)
        XCTAssertLessThan(map.frame.height, initialMapHeight - 50)
        XCTAssertTrue(detailPane.staticTexts["Café"].firstMatch.exists)
        XCTAssertTrue(app.buttons["Fermer la fiche de la sortie"].isHittable)
        XCTAssertLessThanOrEqual(resizeHandle.frame.maxY, map.frame.minY + 2)
        attachScreenshot(named: "Fiche événement agrandie, carte visible")
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
        app.buttons["Fermer la fiche de la sortie"].tap()
        XCTAssertTrue(detailPane.waitForNonExistence(timeout: 3))
        XCTAssertEqual(nativeMap.frame.size.height, initialSize.height, accuracy: 1)
    }

    func testMapFillsWindowBehindNativeTabBar() {
        app.terminate()
        app.launchArguments = ["-debug-social-map", "-debug-social-map-fullscreen"]
        app.launch()
        XCTAssertTrue(map.waitForExistence(timeout: 10))
        XCTAssertTrue(app.tabBars.buttons["Explorer"].isHittable)
        let window = app.windows.firstMatch.frame
        assertFullScreenMap(map.frame, window: window)
        attachScreenshot(named: "Carte plein écran derrière les barres système")
        let nativeMap = app.maps.firstMatch
        let nativeSize = nativeMap.frame.size

        openGroupedEvent(index: 0, title: "Café")
        XCTAssertEqual(detailPane.frame.minY, window.minY, accuracy: 1)
        XCTAssertEqual(map.frame.maxY, window.maxY, accuracy: 1)
        XCTAssertTrue(app.buttons["Fermer la fiche de la sortie"].isHittable)
        for _ in 0..<3 {
            resizeHandle.tap()
            XCTAssertEqual(nativeMap.frame.width, nativeSize.width, accuracy: 0.01)
            XCTAssertEqual(nativeMap.frame.height, nativeSize.height, accuracy: 0.01)
            XCTAssertEqual(map.frame.maxY, window.maxY, accuracy: 1)
        }
        attachScreenshot(named: "Fiche ouverte et carte derrière les onglets")
        app.buttons["Fermer la fiche de la sortie"].tap()
        XCTAssertTrue(detailPane.waitForNonExistence(timeout: 3))
        assertFullScreenMap(map.frame, window: window)
        app.tabBars.buttons["Amis"].tap()
        app.tabBars.buttons["Explorer"].tap()
        XCTAssertTrue(map.waitForExistence(timeout: 3))
        assertFullScreenMap(map.frame, window: window)

        defer { XCUIDevice.shared.orientation = .portrait }
        XCUIDevice.shared.orientation = .landscapeLeft
        let landscape = NSPredicate { _, _ in
            self.app.windows.firstMatch.frame.width > self.app.windows.firstMatch.frame.height
        }
        expectation(for: landscape, evaluatedWith: app)
        waitForExpectations(timeout: 5)
        let landscapeWindow = app.windows.firstMatch.frame
        assertFullScreenMap(map.frame, window: landscapeWindow)
        let edge = app.coordinate(withNormalizedOffset: CGVector(dx: 1, dy: 0.5))
            .withOffset(CGVector(dx: -1, dy: 0))
        edge.press(forDuration: 0.05, thenDragTo: edge.withOffset(CGVector(dx: -120, dy: 0)))
        let emptyRail = app.images["Aucun ami"]
        XCTAssertTrue(emptyRail.waitForExistence(timeout: 3))
        XCTAssertTrue(emptyRail.isHittable)
        XCTAssertLessThan(emptyRail.frame.maxX, landscapeWindow.maxX - 14)
        attachScreenshot(named: "Carte plein écran et rail accessible en paysage")
    }

    func testResizeButtonCyclesSizesAndCloseRestoresMap() {
        let fullMapHeight = map.frame.height
        openGroupedEvent(index: 1, title: "Repas")
        waitForResizeValue("Moitié de l’écran")
        let halfHeight = detailPane.frame.height

        resizeHandle.tap()
        waitForResizeValue("Fiche agrandie")
        XCTAssertGreaterThan(detailPane.frame.height, halfHeight + 50)

        resizeHandle.tap()
        waitForResizeValue("Fiche réduite")
        XCTAssertLessThan(detailPane.frame.height, halfHeight - 50)

        resizeHandle.tap()
        waitForResizeValue("Moitié de l’écran")
        XCTAssertEqual(detailPane.frame.height, halfHeight, accuracy: 2)
        app.buttons["Fermer la fiche de la sortie"].tap()
        XCTAssertTrue(detailPane.waitForNonExistence(timeout: 3))
        XCTAssertTrue(resizeHandle.waitForNonExistence(timeout: 3))
        XCTAssertEqual(map.frame.height, fullMapHeight, accuracy: 2)
    }

    func testDetailScrollKeepsPaneAndHeaderInPlace() {
        openGroupedEvent(index: 0, title: "Café")
        resizeHandle.tap()
        resizeHandle.tap()
        waitForResizeValue("Fiche réduite")
        let paneHeight = detailPane.frame.height
        let handleY = resizeHandle.frame.minY
        let close = app.buttons["Fermer la fiche de la sortie"]
        let closeY = close.frame.minY
        let edit = app.buttons["Modifier l’événement"]
        XCTAssertFalse(edit.isHittable)

        reveal(edit, in: app.scrollViews["outing-detail-scroll"])

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
        XCTAssertTrue(detailPane.waitForNonExistence(timeout: 3))
    }

    // MARK: - Scenario interactions

    private var map: XCUIElement { app.otherElements["map-visible-viewport"].firstMatch }

    private var detailPane: XCUIElement {
        app.otherElements["map-detail-pane"].firstMatch
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
        let attachment = XCTAttachment(screenshot: app.screenshot())
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
        let explore = app.tabBars.buttons["Explorer"]
        if explore.waitForExistence(timeout: 15) { explore.tap() }
        let nativeMap = app.maps.firstMatch
        XCTAssertTrue(nativeMap.waitForExistence(timeout: 15))
        let viewport = app.otherElements["map-visible-viewport"].firstMatch
        XCTAssertTrue(viewport.waitForExistence(timeout: 3))
        let window = app.windows.firstMatch.frame
        assertFullScreenMap(viewport.frame, window: window)
        XCTAssertTrue(app.buttons["Filtres de la carte"].isHittable)
        XCTAssertTrue(app.buttons["Recentrer la carte sur ma position"].isHittable)
        let fullScreenCapture = XCTAttachment(screenshot: app.screenshot())
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
                XCTAssertTrue(app.buttons["Fermer la fiche de la sortie"].isHittable)
                XCTAssertEqual(viewport.frame.maxY, window.maxY, accuracy: 1)
                XCTAssertEqual(app.state, .runningForeground)
            }
            let start = handle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: -100)))
            XCTAssertEqual(nativeMap.frame.height, nativeSize.height, accuracy: 1)
            if cycle == 0 {
                let screenshot = XCTAttachment(screenshot: app.screenshot())
                screenshot.name = "Fiche arrondie sur iPhone avec Metal actif"
                screenshot.lifetime = .keepAlways
                add(screenshot)
            }
            app.buttons["Fermer la fiche de la sortie"].tap()
            XCTAssertTrue(handle.waitForNonExistence(timeout: 3))
            XCTAssertEqual(nativeMap.frame.height, nativeSize.height, accuracy: 1)
            assertFullScreenMap(viewport.frame, window: window)
        }
        #endif
    }
}

private func assertFullScreenMap(
    _ frame: CGRect,
    window: CGRect,
    file: StaticString = #filePath,
    line: UInt = #line
) {
    XCTAssertEqual(frame.minX, window.minX, accuracy: 1, file: file, line: line)
    XCTAssertEqual(frame.minY, window.minY, accuracy: 1, file: file, line: line)
    XCTAssertEqual(frame.maxX, window.maxX, accuracy: 1, file: file, line: line)
    XCTAssertEqual(frame.maxY, window.maxY, accuracy: 1, file: file, line: line)
}
