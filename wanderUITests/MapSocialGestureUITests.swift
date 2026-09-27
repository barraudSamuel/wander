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

    func testOwnAvatarOpensSheetWithoutCalloutAndReopensAfterDismissal() {
        app.terminate()
        app.launchArguments = ["-debug-social-map", "-debug-social-map-fullscreen"]
        app.launch()
        XCTAssertTrue(map.waitForExistence(timeout: 10))
        let user = app.buttons["Moi, Vous"]
        XCTAssertTrue(user.waitForExistence(timeout: 5))
        let fullMapFrame = map.frame
        let ownSheet = app.descendants(matching: .any)["own-profile-scroll"].firstMatch
        for expands in [false, true] {
            user.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            XCTAssertTrue(ownSheet.waitForExistence(timeout: 5))
            XCTAssertTrue(ownSheet.staticTexts["Moi"].exists)
            XCTAssertTrue(ownSheet.staticTexts["Exploration"].exists)
            XCTAssertEqual(app.buttons.matching(NSPredicate(format: "label == %@", "Copier l’adresse")).count,
                           ownSheet.buttons.matching(NSPredicate(format: "label == %@", "Copier l’adresse")).count)
            XCTAssertFalse(app.buttons["Itinéraire"].exists)
            XCTAssertEqual(map.frame, fullMapFrame)
            let framed = NSPredicate { _, _ in
                user.exists && user.frame.maxY + 8 < ownSheet.frame.minY
                    && user.frame.minY >= self.app.statusBars.firstMatch.frame.maxY
            }
            expectation(for: framed, evaluatedWith: user)
            waitForExpectations(timeout: 5)
            attachScreenshot(named: "Profil personnel compact sans tooltip")
            if expands {
                let compactTop = ownSheet.frame.minY
                ownSheet.swipeUp()
                let expanded = NSPredicate { _, _ in ownSheet.frame.minY < compactTop - 50 }
                expectation(for: expanded, evaluatedWith: ownSheet)
                waitForExpectations(timeout: 3)
                attachScreenshot(named: "Profil personnel agrandi")
            }
            let start = ownSheet.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.05))
            let bottom = app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.98))
            start.press(forDuration: 0.05, thenDragTo: bottom)
            XCTAssertTrue(ownSheet.waitForNonExistence(timeout: 3))
            XCTAssertEqual(map.frame, fullMapFrame)
        }
    }

    func testOwnAvatarSelectionOpensSeparateSheetAndReturnsToProfile() {
        app.terminate()
        app.launchArguments = ["-debug-social-map", "-debug-social-map-fullscreen"]
        app.launch()
        XCTAssertTrue(map.waitForExistence(timeout: 10))
        app.buttons["map-own-profile"].tap()

        let ownSheet = app.descendants(matching: .any)["own-profile-scroll"].firstMatch
        XCTAssertTrue(ownSheet.waitForExistence(timeout: 5))
        XCTAssertFalse(ownSheet.staticTexts["Avatar"].exists)

        let avatarButton = app.buttons["own-profile-avatar"].firstMatch
        XCTAssertTrue(avatarButton.waitForExistence(timeout: 3))
        avatarButton.tap()

        let title = app.navigationBars["Choisir un avatar"]
        XCTAssertTrue(title.waitForExistence(timeout: 3))
        app.buttons["Crâne"].tap()
        XCTAssertTrue(title.waitForNonExistence(timeout: 3))
        XCTAssertTrue(ownSheet.exists)

        avatarButton.tap()
        XCTAssertTrue(title.waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Crâne"].isSelected)
        app.buttons["Fermer"].tap()
        XCTAssertTrue(ownSheet.exists)
    }

    func testOwnSettingsOpensSeparateSheetAndReturnsToProfile() {
        app.terminate()
        app.launchArguments = ["-debug-social-map", "-debug-social-map-fullscreen"]
        app.launch()
        XCTAssertTrue(map.waitForExistence(timeout: 10))
        app.buttons["map-own-profile"].tap()

        let ownSheet = app.descendants(matching: .any)["own-profile-scroll"].firstMatch
        XCTAssertTrue(ownSheet.waitForExistence(timeout: 5))
        XCTAssertFalse(ownSheet.staticTexts["Affichage de la carte"].exists)

        let settingsButton = app.buttons["own-profile-settings"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 3))
        settingsButton.tap()

        let title = app.navigationBars["Réglages"]
        XCTAssertTrue(title.waitForExistence(timeout: 3))
        XCTAssertTrue(app.switches["profile-heat-map"].exists)
        app.buttons["Fermer"].tap()
        XCTAssertTrue(title.waitForNonExistence(timeout: 3))
        XCTAssertTrue(ownSheet.exists)

        settingsButton.tap()
        XCTAssertTrue(title.waitForExistence(timeout: 3))
    }

    func testOwnProfileFromGroupThenFriendProfile() {
        app.terminate()
        app.launchArguments = ["-debug-social-map", "-debug-social-map-mixed", "-debug-social-map-fullscreen"]
        app.launch()
        let group = app.buttons["Groupe, 3 personnes et 2 sorties prévues"]
        XCTAssertTrue(group.waitForExistence(timeout: 10))
        group.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        let expanded = app.buttons["Groupe ouvert, 3 personnes et 2 sorties prévues"]
        XCTAssertTrue(expanded.waitForExistence(timeout: 3))
        tapExpandedRow(expanded, index: 0, rowCount: 5)
        let ownSheet = app.descendants(matching: .any)["own-profile-scroll"].firstMatch
        XCTAssertTrue(ownSheet.waitForExistence(timeout: 5))
        XCTAssertTrue(ownSheet.staticTexts["Moi"].exists)
        XCTAssertFalse(detailPane.exists)
        let start = ownSheet.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.05))
        let bottom = app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.98))
        start.press(forDuration: 0.05, thenDragTo: bottom)
        XCTAssertTrue(ownSheet.waitForNonExistence(timeout: 3))
        openMixedFriend(eventCount: 2)
        XCTAssertTrue(detailPane.staticTexts["Amina"].exists)
        XCTAssertTrue(app.buttons["Itinéraire"].isHittable)
        XCTAssertFalse(app.buttons["own-profile-settings"].exists)
        XCTAssertFalse(ownSheet.exists)
        closeFriendSheet()
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
        cancelGroupRow(index: 1, eventNumber: 1, expectedTitle: "Repas", remainingTitle: "Café")
        cancelRemainingEvent(eventNumber: 2, title: "Café")
    }

    func testCancelUpperEventThenRemainingEvent() {
        cancelGroupRow(index: 0, eventNumber: 2, expectedTitle: "Café", remainingTitle: "Repas")
        cancelRemainingEvent(eventNumber: 1, title: "Repas")
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

    func testBothMapEdgesCenterOwnProfileWithoutSelectingGroup() {
        let group = app.buttons["Groupe, 2 sorties prévues"]
        let user = app.buttons["Moi, Vous"]
        XCTAssertTrue(group.waitForExistence(timeout: 10))
        XCTAssertTrue(user.exists)

        func anchor(_ element: XCUIElement) -> CGPoint {
            CGPoint(x: element.frame.midX, y: element.frame.maxY)
        }
        func separation() -> CGFloat {
            let first = anchor(group)
            let second = anchor(user)
            return hypot(first.x - second.x, first.y - second.y)
        }

        for rightEdge in [false, true] {
            let before = separation()
            let x = rightEdge ? map.frame.width - 12 : 12
            let origin = map.coordinate(withNormalizedOffset: .zero)
            let lower = origin.withOffset(CGVector(dx: x, dy: map.frame.height * 0.65))
            let upper = origin.withOffset(CGVector(dx: x, dy: map.frame.height * 0.25))
            lower.press(forDuration: 0.05, thenDragTo: upper)
            let zoomed = NSPredicate { _, _ in separation() > before * 1.1 }
            expectation(for: zoomed, evaluatedWith: app)
            waitForExpectations(timeout: 3)
            // The scenario starts centered on the current user, now an eligible target.
            XCTAssertEqual(anchor(user).x, map.frame.midX, accuracy: 8)
            XCTAssertEqual(anchor(user).y, usableMapCenterY, accuracy: 40)
            XCTAssertFalse(app.buttons["Groupe ouvert, 2 sorties prévues"].exists)

            let afterZoom = separation()
            upper.press(forDuration: 0.05, thenDragTo: lower)
            let zoomedOut = NSPredicate { _, _ in separation() < afterZoom * 0.9 }
            expectation(for: zoomedOut, evaluatedWith: app)
            waitForExpectations(timeout: 3)
            XCTAssertEqual(anchor(user).x, map.frame.midX, accuracy: 8)
            XCTAssertEqual(anchor(user).y, usableMapCenterY, accuracy: 40)
        }
        attachScreenshot(named: "Zoom des deux bords, après relâchement")
    }

    func testEdgeZoomCentersOwnProfileWhenNoOtherMarkersExist() {
        app.terminate()
        app.launchArguments = ["-debug-social-map", "-debug-social-map-empty-list"]
        app.launch()
        let user = app.buttons["Moi, Vous"]
        XCTAssertTrue(user.waitForExistence(timeout: 10))
        let paneWasVisible = detailPane.exists
        let start = map.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.65))
        start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 60, dy: 0)))
        XCTAssertGreaterThan(abs(user.frame.midX - map.frame.midX), 20)
        let origin = map.coordinate(withNormalizedOffset: .zero)
        let lower = origin.withOffset(CGVector(dx: 12, dy: map.frame.height * 0.65))
        let upper = origin.withOffset(CGVector(dx: 12, dy: map.frame.height * 0.35))
        lower.press(forDuration: 0.05, thenDragTo: upper)
        let centered = NSPredicate { _, _ in abs(user.frame.midX - self.map.frame.midX) < 8 }
        expectation(for: centered, evaluatedWith: app)
        waitForExpectations(timeout: 3)
        XCTAssertEqual(user.frame.maxY, usableMapCenterY, accuracy: 40)
        XCTAssertEqual(detailPane.exists, paneWasVisible)
    }

    func testHorizontalDragStartingAtEdgeStillPansMap() {
        let group = app.buttons["Groupe, 2 sorties prévues"]
        XCTAssertTrue(group.waitForExistence(timeout: 10))
        let before = group.frame.midX
        let origin = map.coordinate(withNormalizedOffset: .zero)
        let start = origin.withOffset(CGVector(dx: 12, dy: map.frame.height * 0.65))
        let end = origin.withOffset(CGVector(dx: map.frame.width * 0.4, dy: map.frame.height * 0.65))
        start.press(forDuration: 0.05, thenDragTo: end)
        let moved = NSPredicate { _, _ in abs(group.frame.midX - before) > 30 }
        expectation(for: moved, evaluatedWith: app)
        waitForExpectations(timeout: 3)
    }

    func testEdgeZoomWithAnOpenFriendSheet() {
        launchDetailScenario(["mixed", "open-friend"])
        let group = app.buttons["Groupe, 3 personnes et 2 sorties prévues"]
        XCTAssertTrue(group.waitForExistence(timeout: 3))
        let mapFrame = map.frame
        let exposedHeight = detailPane.frame.minY - map.frame.minY
        XCTAssertGreaterThan(exposedHeight, 100)
        let origin = map.coordinate(withNormalizedOffset: .zero)
        let pan = origin.withOffset(CGVector(dx: map.frame.width * 0.2, dy: exposedHeight * 0.6))
        pan.press(forDuration: 0.05, thenDragTo: pan.withOffset(CGVector(dx: 60, dy: 0)))
        let before = group.frame
        let lower = origin.withOffset(CGVector(dx: 12, dy: exposedHeight * 0.8))
        let upper = origin.withOffset(CGVector(dx: 12, dy: exposedHeight * 0.25))
        lower.press(forDuration: 0.05, thenDragTo: upper)
        let moved = NSPredicate { _, _ in
            abs(group.frame.midX - before.midX) + abs(group.frame.midY - before.midY) > 5
        }
        expectation(for: moved, evaluatedWith: app)
        waitForExpectations(timeout: 3)
        XCTAssertTrue(detailPane.exists)
        XCTAssertEqual(map.frame, mapFrame)
        attachScreenshot(named: "Zoom de bord au-dessus de la fiche ami")
    }

    func testFriendSheetExpandsWithoutResizingMapAndKeepsSelection() {
        launchDetailScenario(["mixed"])
        let fullMapFrame = map.frame
        openMixedFriend(eventCount: 2)
        XCTAssertFalse(resizeHandle.exists)
        XCTAssertEqual(map.frame, fullMapFrame)
        XCTAssertTrue(map.frame.intersects(detailPane.frame))
        XCTAssertGreaterThan(detailPane.frame.minY, map.frame.minY)
        XCTAssertTrue(app.buttons["Itinéraire"].isHittable)
        attachScreenshot(named: "Fiche ami compacte superposée à la carte")
        let initialTop = detailPane.frame.minY
        detailPane.swipeUp()
        let expanded = NSPredicate { _, _ in
            self.detailPane.frame.minY < initialTop - 50
        }
        expectation(for: expanded, evaluatedWith: detailPane)
        waitForExpectations(timeout: 3)
        XCTAssertEqual(map.frame, fullMapFrame)
        XCTAssertTrue(detailPane.staticTexts["Amina"].exists)
        XCTAssertFalse(app.buttons["Retour aux événements"].exists)
        XCTAssertFalse(resizeHandle.exists)
        attachScreenshot(named: "Fiche ami agrandie sur une carte de taille constante")
    }

    func testFriendDismissalRecentersAfterSheetResize() {
        launchDetailScenario(["mixed", "open-friend", "fullscreen"])
        let initialTop = detailPane.frame.minY
        detailPane.swipeUp()
        let expanded = NSPredicate { _, _ in self.detailPane.frame.minY < initialTop - 50 }
        expectation(for: expanded, evaluatedWith: detailPane)
        waitForExpectations(timeout: 3)
        closeFriendSheet()
        let group = app.buttons["Groupe, 3 personnes et 2 sorties prévues"]
        let centeredAfterDismissal = NSPredicate { _, _ in
            // The group annotation anchors eight points below its bottom edge.
            group.exists && abs(group.frame.maxY + 8 - self.usableMapCenterY) < 40
        }
        expectation(for: centeredAfterDismissal, evaluatedWith: group)
        waitForExpectations(timeout: 3)
        XCTAssertFalse(detailPane.exists)
    }

    func testFriendSheetHasNoCloseButtonAndDismissesFromBothHeights() {
        for expandSheet in [false, true] {
            launchDetailScenario(["mixed", "open-friend", "fullscreen"])
            XCTAssertFalse(app.buttons["Fermer la fiche de l’ami"].exists)
            if expandSheet {
                let initialTop = detailPane.frame.minY
                detailPane.swipeUp()
                let expanded = NSPredicate { _, _ in self.detailPane.frame.minY < initialTop - 50 }
                expectation(for: expanded, evaluatedWith: detailPane)
                waitForExpectations(timeout: 3)
            }
            closeFriendSheet()
        }
    }

    func testPreparedFriendOpeningLeavesTheWholePinAboveTheSheet() {
        launchDetailScenario(["mixed", "fullscreen"])
        openMixedFriend(eventCount: 2)
        let friend = app.buttons["Amina, Ami"]
        let framed = NSPredicate { _, _ in
            friend.exists && friend.frame.maxY + 8 < self.detailPane.frame.minY
                && friend.frame.minY >= self.app.statusBars.firstMatch.frame.maxY
        }
        expectation(for: framed, evaluatedWith: friend)
        waitForExpectations(timeout: 5)
        XCTAssertTrue(detailPane.buttons["Itinéraire"].isHittable)
    }

    func testNativeMapRenderSizeStaysStableAcrossPaneChanges() {
        let nativeMap = app.maps.firstMatch
        let initialSize = nativeMap.frame.size
        openGroupedEvent(index: 0)
        openEventList()
        XCTAssertFalse(revealEvent(2).isSelected)
        XCTAssertEqual(nativeMap.frame.size, initialSize)
        eventsButton.tap()
        XCTAssertTrue(eventsResizeHandle.waitForNonExistence(timeout: 3))
        XCTAssertEqual(nativeMap.frame.size, initialSize)
        app.segmentedControls.buttons["Mixte"].tap()
        let fullMapFrame = map.frame
        openMixedFriend(eventCount: 2)
        XCTAssertEqual(map.frame, fullMapFrame)
        detailPane.swipeUp()
        XCTAssertEqual(nativeMap.frame.width, initialSize.width, accuracy: 1)
        XCTAssertEqual(nativeMap.frame.height, initialSize.height, accuracy: 1)
        XCTAssertTrue(detailPane.staticTexts["Amina"].exists)
        closeFriendSheet()
        XCTAssertFalse(resizeHandle.exists)
        XCTAssertFalse(eventListIsInteractive)
        XCTAssertEqual(map.frame, fullMapFrame)
        XCTAssertEqual(nativeMap.frame.height, initialSize.height, accuracy: 1)
    }

    func testDockPanelsRemainAvailableAfterClosingFriendSheet() {
        launchDetailScenario(["mixed", "open-friend", "fullscreen"])
        let mapFrame = map.frame
        let nativeSize = app.maps.firstMatch.frame.size
        closeFriendSheet()
        for panel in ["friends"] {
            app.buttons["motion-dock-" + panel].tap()
            assertFriendsListIsHittable(true)
            app.buttons["motion-dock-explore"].tap()
            assertFriendsListIsHittable(false)
            XCTAssertFalse(detailPane.exists)
            XCTAssertEqual(map.frame, mapFrame)
            XCTAssertEqual(app.maps.firstMatch.frame.size, nativeSize)
        }
        XCTAssertFalse(app.scrollViews["outing-detail-scroll"].exists)
        XCTAssertFalse(eventListIsInteractive)
        attachScreenshot(named: "Carte conservée après fermeture de la fiche et des panneaux")
    }

    func testFullMapRestoresAfterEventsAndDockPanels() {
        launchDetailScenario(["fullscreen"])
        XCTAssertTrue(app.buttons["motion-dock-explore"].isHittable)
        assertFullMap(window: app.windows.firstMatch.frame)
        let nativeSize = app.maps.firstMatch.frame.size
        openGroupedEvent(index: 0)
        XCTAssertTrue(eventListIsInteractive)
        XCTAssertFalse(app.navigationBars.buttons["Événements"].exists)
        XCTAssertTrue(eventsResizeHandle.isHittable)
        XCTAssertEqual(app.maps.firstMatch.frame.size, nativeSize)
        openEventList()
        XCTAssertFalse(revealEvent(2).isSelected)
        assertEventsBelowMap(nativeSize: nativeSize)
        app.buttons["motion-dock-friends"].tap()
        assertFriendsListIsHittable(true)
        XCTAssertFalse(eventsButton.isSelected)
        eventsButton.tap()
        assertFriendsListIsHittable(false)
        XCTAssertFalse(revealEvent(2).isSelected)
        XCTAssertTrue(eventsButton.isSelected)
        eventsButton.tap()
        XCTAssertTrue(eventsResizeHandle.waitForNonExistence(timeout: 3))
        assertFullMap(window: app.windows.firstMatch.frame)

        defer { XCUIDevice.shared.orientation = .portrait }
        XCUIDevice.shared.orientation = .landscapeLeft
        let landscape = NSPredicate { _, _ in
            self.app.windows.firstMatch.frame.width > self.app.windows.firstMatch.frame.height
        }
        expectation(for: landscape, evaluatedWith: app)
        waitForExpectations(timeout: 5)
        assertFullMap(window: app.windows.firstMatch.frame)
        attachScreenshot(named: "Carte plein écran après fermeture de la liste en paysage")
    }

    func testFriendSheetDragDismissesAndKeepsFullMap() {
        launchDetailScenario(["mixed"])
        let fullMapFrame = map.frame
        openMixedFriend(eventCount: 2)
        XCTAssertFalse(resizeHandle.exists)
        XCTAssertTrue(app.buttons["Itinéraire"].isHittable)
        let start = detailPane.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.1))
        let bottom = app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.98))
        start.press(forDuration: 0.05, thenDragTo: bottom)
        XCTAssertTrue(detailPane.waitForNonExistence(timeout: 3))
        XCTAssertFalse(eventListIsInteractive)
        XCTAssertEqual(map.frame, fullMapFrame)
        openMixedFriend(eventCount: 2)
        XCTAssertTrue(detailPane.staticTexts["Amina"].exists)
        closeFriendSheet()
        XCTAssertEqual(map.frame, fullMapFrame)
    }

    func testVerticalScrollAfterCardTapKeepsPanelStable() {
        launchDetailScenario(["guest", "many-events", "fullscreen"])
        tapCardBody(1)
        let listFrame = eventListViewport
        let mapFrame = map.frame
        let response = eventRow(1).label
        let firstCardTop = eventRow(1).frame.minY
        scrollEventList(up: true)
        XCTAssertLessThan(eventRow(1).frame.minY, firstCardTop - 20)
        XCTAssertTrue(eventsResizeHandle.isHittable)
        XCTAssertEqual(eventListViewport, listFrame)
        XCTAssertEqual(map.frame, mapFrame)
        XCTAssertFalse(resizeHandle.exists)
        XCTAssertFalse(app.scrollViews["outing-detail-scroll"].exists)
        XCTAssertFalse(revealEvent(1).isSelected)
        XCTAssertEqual(eventRow(1).label, response)
    }

    func testNativePanWorksAboveEventList() {
        openGroupedEvent(index: 0)
        openEventList()
        let user = app.buttons["Moi, Vous"]
        XCTAssertTrue(user.waitForExistence(timeout: 3))
        let originalX = user.frame.midX
        let listFrame = eventListViewport
        let mapHeight = map.frame.height
        let start = map.coordinate(withNormalizedOffset: CGVector(dx: 0.15, dy: 0.7))
        let end = map.coordinate(withNormalizedOffset: CGVector(dx: 0.45, dy: 0.7))
        start.press(forDuration: 0.05, thenDragTo: end)
        let mapMoved = NSPredicate { _, _ in
            user.exists && abs(user.frame.midX - originalX) > 30
        }
        expectation(for: mapMoved, evaluatedWith: app)
        waitForExpectations(timeout: 3)
        XCTAssertFalse(eventRow(2).isSelected)
        XCTAssertEqual(eventListViewport, listFrame)
        XCTAssertEqual(map.frame.height, mapHeight, accuracy: 2)
    }

    func testMixedGroupOpensFriendSheetOverMap() {
        let fullMapFrame = map.frame
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
        XCTAssertEqual(map.frame, fullMapFrame)
        XCTAssertTrue(map.frame.intersects(detailPane.frame))
        XCTAssertGreaterThan(detailPane.frame.minY, map.frame.minY)
        XCTAssertTrue(app.buttons["Itinéraire"].isHittable)
        XCTAssertFalse(resizeHandle.exists)
        closeFriendSheet()
        XCTAssertFalse(eventListIsInteractive)
    }

    func testGuestCardActionsRespondWithoutResizingMap() {
        launchDetailScenario(["guest", "stress", "fullscreen"])
        openEventList()
        let mapFrame = map.frame
        for shouldAttend in [true, false, true] {
            revealEventAction(shouldAttend ? "Participer" : "Refuser", event: 1).tap()
            XCTAssertTrue(eventRow(1).label.contains(shouldAttend ? "Vous participez" : "Vous ne participez pas"))
            XCTAssertTrue(eventListIsInteractive)
            XCTAssertEqual(map.frame, mapFrame)
        }
        XCTAssertFalse(resizeHandle.exists)
    }

    func testUnavailableAndUpdatingParticipationKeepsDirectionsAccessible() {
        for state in ["loading", "unavailable", "updating"] {
            launchDetailScenario(["guest", "open-event", state])
            for title in ["Participer", "Refuser"] {
                XCTAssertFalse(revealEventAction(title, event: 1).isEnabled)
            }
            let message = state == "loading" ? "Votre réponse est en cours de chargement"
                : state == "unavailable" ? "Votre réponse est indisponible" : "Envoi…"
            let card = eventRow(1)
            XCTAssertTrue(card.label.contains(message)
                || card.descendants(matching: .any).matching(NSPredicate(format: "label == %@", message)).firstMatch.exists)
            let directions = revealEventAction("Itinéraire", event: 1)
            XCTAssertTrue(directions.isEnabled)
            directions.tap()
            XCTAssertTrue(app.alerts["Itinéraire de test"].waitForExistence(timeout: 3))
        }
    }

    func testFriendActionsRespectGhostAndMissingPosition() {
        for state in ["ghost", "missing-location", "stale"] {
            launchDetailScenario(["mixed", "open-friend", state])
            let directions = app.buttons["Itinéraire"]
            XCTAssertTrue(directions.waitForExistence(timeout: 3))
            XCTAssertTrue(directions.isHittable)
            XCTAssertEqual(directions.isEnabled, state == "stale")
            XCTAssertFalse(app.buttons["Fermer la fiche de l’ami"].exists)
            XCTAssertFalse(resizeHandle.exists)
            let mapFrame = map.frame
            detailPane.swipeUp()
            XCTAssertTrue(directions.isHittable)
            XCTAssertEqual(directions.isEnabled, state == "stale")
            XCTAssertEqual(map.frame, mapFrame)
            if state == "stale" {
                directions.tap()
                XCTAssertTrue(detailPane.waitForNonExistence(timeout: 3))
                XCTAssertTrue(app.alerts["Itinéraire de test"].waitForExistence(timeout: 3))
            } else {
                closeFriendSheet()
            }
        }
    }

    func testGuestCardActionsRemainAvailableInLandscape() {
        launchDetailScenario(["guest", "open-event", "fullscreen"])
        defer { XCUIDevice.shared.orientation = .portrait }
        XCUIDevice.shared.orientation = .landscapeLeft
        let landscape = NSPredicate { _, _ in
            self.app.windows.firstMatch.frame.width > self.app.windows.firstMatch.frame.height
        }
        expectation(for: landscape, evaluatedWith: app)
        waitForExpectations(timeout: 5)
        for title in ["Participer", "Refuser", "Itinéraire"] {
            XCTAssertTrue(revealEventAction(title, event: 1).isHittable)
        }
        XCTAssertFalse(app.descendants(matching: .any)["event-detail-content"].exists)
        XCTAssertTrue(eventListIsInteractive)
    }

    private func launchDetailScenario(_ options: [String]) {
        app.terminate()
        app.launchArguments = ["-debug-social-map"] + options.map { "-debug-social-map-" + $0 }
        app.launch()
        XCTAssertTrue(map.waitForExistence(timeout: 10))
        XCTAssertTrue(eventsButton.waitForExistence(timeout: 3))
        if options.contains("open-friend") {
            XCTAssertTrue(detailPane.waitForExistence(timeout: 3))
        } else if options.contains("open-event") {
            XCTAssertTrue(eventList.waitForExistence(timeout: 3))
            XCTAssertTrue(eventsResizeHandle.isHittable)
        } else {
            XCTAssertFalse(eventListIsInteractive)
            XCTAssertFalse(eventsResizeHandle.exists)
            XCTAssertFalse(resizeHandle.exists)
        }
    }

    func testCardBodyRecentersAfterMapPanAndRepeatedTap() {
        launchDetailScenario(["fullscreen"])
        revealEvent(1)
        tapCardBody(1)
        let pin = eventPin("Repas")
        XCTAssertTrue(pin.waitForExistence(timeout: 3))
        let centered = NSPredicate { _, _ in
            pin.exists && abs(pin.frame.midX - self.map.frame.midX) < 8
        }
        expectation(for: centered, evaluatedWith: pin)
        waitForExpectations(timeout: 3)
        let initialFrame = pin.frame
        let listFrame = eventListViewport
        let cardFrame = eventRow(1).frame
        let handleFrame = eventsResizeHandle.frame
        for _ in 0..<2 {
            let start = map.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.7))
            start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 80, dy: 0)))
            XCTAssertGreaterThan(abs(pin.frame.midX - initialFrame.midX), 30)
            tapCardBody(1)
            let restored = NSPredicate { _, _ in
                pin.exists && abs(pin.frame.midX - initialFrame.midX) < 8
                    && abs(pin.frame.midY - initialFrame.midY) < 8
            }
            expectation(for: restored, evaluatedWith: pin)
            waitForExpectations(timeout: 3)
            XCTAssertEqual(eventRow(1).frame.minY, cardFrame.minY, accuracy: 2)
        }
        XCTAssertEqual(eventsResizeHandle.frame, handleFrame)
        XCTAssertEqual(eventListViewport, listFrame)
        XCTAssertTrue(eventListIsInteractive)
        XCTAssertFalse(app.descendants(matching: .any)["event-detail-content"].exists)
    }

    func testEventListOpensOnDemandAndIsSortedVertically() {
        XCTAssertFalse(eventListIsInteractive)
        XCTAssertFalse(detailPane.exists)
        XCTAssertFalse(resizeHandle.exists)
        XCTAssertFalse(eventsResizeHandle.exists)
        let fullMapHeight = map.frame.height
        openEventList()
        XCTAssertLessThan(map.frame.height, fullMapHeight)
        eventsResizeHandle.tap()
        let meal = revealEvent(1)
        XCTAssertTrue(eventRow(2).waitForExistence(timeout: 3))
        XCTAssertGreaterThan(eventRow(2).frame.minY, meal.frame.minY)
        XCTAssertEqual(eventRow(2).frame.minX, meal.frame.minX, accuracy: 2)
        tapCardBody(1)
        XCTAssertFalse(meal.isSelected)
        XCTAssertTrue(eventListIsInteractive)
        XCTAssertFalse(app.scrollViews["outing-detail-scroll"].exists)
        attachScreenshot(named: "Liste chronologique ouverte par le bouton événements")
    }

    func testEventListScrollSurvivesFriendAndDockPanels() {
        launchDetailScenario(["mixed", "many-events", "fullscreen", "roster-probe"])
        let probe = app.staticTexts["debug-list-rosters"]
        XCTAssertTrue(probe.waitForExistence(timeout: 3))
        func requestedIDs() -> String { (probe.value as? String ?? "").components(separatedBy: ";")[0] }
        XCTAssertTrue(requestedIDs().isEmpty)
        let row = revealEvent(12)
        row.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: 40, dy: 25)).tap()
        let rowFrame = row.frame
        let listFrame = eventListViewport
        let nativeSize = app.maps.firstMatch.frame.size
        XCTAssertFalse(eventRow(1).isHittable)
        app.buttons["motion-dock-friends"].tap()
        assertFriendsListIsHittable(true)
        XCTAssertFalse(eventsButton.isSelected)
        eventsButton.tap()
        XCTAssertFalse(row.isSelected)
        app.buttons["map-own-profile"].tap()
        let ownSheet = app.descendants(matching: .any)["own-profile-scroll"].firstMatch
        XCTAssertTrue(ownSheet.waitForExistence(timeout: 3))
        XCTAssertFalse(eventsButton.isSelected)
        let start = ownSheet.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.05))
        let bottom = app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.98))
        start.press(forDuration: 0.05, thenDragTo: bottom)
        XCTAssertTrue(ownSheet.waitForNonExistence(timeout: 3))
        XCTAssertTrue(eventList.waitForExistence(timeout: 3))
        XCTAssertEqual(row.frame.minY, rowFrame.minY, accuracy: 2)
        XCTAssertFalse(row.isSelected, "Le profil remplace la sélection active, sans réinitialiser la liste.")
        XCTAssertTrue(eventsButton.isSelected)
        XCTAssertTrue((probe.value as? String ?? "").contains("suspended=true"))
        XCTAssertFalse(requestedIDs().isEmpty)
        openMixedFriend(eventCount: 18)
        XCTAssertFalse(eventListIsInteractive)
        XCTAssertFalse(eventsButton.isSelected)
        let rostersSuspended = NSPredicate { _, _ in requestedIDs().isEmpty }
        expectation(for: rostersSuspended, evaluatedWith: probe)
        waitForExpectations(timeout: 3)
        XCTAssertEqual(app.maps.firstMatch.frame.size, nativeSize)
        closeFriendSheet()
        XCTAssertTrue(eventList.waitForExistence(timeout: 3))
        let rostersResumed = NSPredicate { _, _ in !requestedIDs().isEmpty }
        expectation(for: rostersResumed, evaluatedWith: probe)
        waitForExpectations(timeout: 3)
        XCTAssertEqual(eventListViewport, listFrame)
        XCTAssertEqual(row.frame.minY, rowFrame.minY, accuracy: 2)
        XCTAssertTrue(row.isHittable)
        XCTAssertTrue(eventsButton.isSelected)
        XCTAssertEqual(app.maps.firstMatch.frame.size, nativeSize)
        attachScreenshot(named: "Défilement conservé après la fiche ami et les panneaux")
    }

    func testEventListEmptyLoadingAndErrorStates() {
        for (option, identifier) in [
            ("empty-list", "events-list-empty"),
            ("list-loading", "events-list-loading"),
            ("list-error", "events-list-error"),
            ("partial-list-error", "events-list-error")
        ] {
            launchDetailScenario([option, "fullscreen"])
            openEventList()
            XCTAssertTrue(app.descendants(matching: .any)[identifier].firstMatch.waitForExistence(timeout: 3))
            if option != "empty-list" {
                XCTAssertFalse(app.staticTexts["events-list-empty"].exists)
            }
            if option == "partial-list-error" {
                XCTAssertTrue(revealEvent(1).isHittable)
            }
            eventsButton.tap()
            XCTAssertTrue(eventsResizeHandle.waitForNonExistence(timeout: 3))
            XCTAssertFalse(eventListIsInteractive)
            openEventList()
            XCTAssertTrue(app.descendants(matching: .any)[identifier].firstMatch.waitForExistence(timeout: 3))
        }
    }

    func testEventListCanRespondAndCancelWithoutMapTap() {
        launchDetailScenario(["guest", "fullscreen"])
        openEventList()
        let userFrame = app.buttons["Moi, Vous"].frame
        revealEventAction("Participer", event: 1).tap()
        XCTAssertTrue(eventRow(1).label.contains("Vous participez"))
        XCTAssertTrue(revealEvent(2).label.contains("Vous n’avez pas encore répondu"))
        revealEventAction("Refuser", event: 2).tap()
        XCTAssertTrue(eventRow(2).label.contains("Vous ne participez pas"))
        XCTAssertTrue(revealEvent(1).label.contains("Vous participez"))
        XCTAssertEqual(app.buttons["Moi, Vous"].frame.midX, userFrame.midX, accuracy: 2)
        XCTAssertEqual(app.buttons["Moi, Vous"].frame.midY, userFrame.midY, accuracy: 2)
        XCTAssertTrue(eventListIsInteractive)

        launchDetailScenario(["fullscreen"])
        openEventList()
        let handleFrame = eventsResizeHandle.frame
        cancelPresentedEvent(eventNumber: 1)
        XCTAssertEqual(eventsResizeHandle.frame, handleFrame)
        XCTAssertFalse(eventRow(1).exists)
        XCTAssertTrue(revealEvent(2).isHittable)
    }

    func testEventSummariesAndResponseAfterVerticalScroll() {
        launchDetailScenario(["social-list", "fullscreen"])
        openEventList()
        XCTAssertTrue(eventList.staticTexts["Événements"].exists)
        XCTAssertFalse(app.navigationBars["Événements"].exists)
        XCTAssertFalse(app.buttons["events-list-filter"].exists)
        XCTAssertFalse(eventList.staticTexts["Aujourd’hui"].exists)
        XCTAssertFalse(eventList.staticTexts["Demain"].exists)
        XCTAssertTrue(eventRow(1).label.contains("Théo organise un repas"))
        XCTAssertTrue(eventRow(1).label.contains("Lieu : Bistrot du parc"))
        XCTAssertTrue(eventRow(1).label.contains("Vous n’avez pas encore répondu"))
        XCTAssertTrue(eventRow(1).label.contains("à vol d’oiseau"))
        attachScreenshot(named: "Événements avec date et réponse")
        tapCardBody(2)
        XCTAssertTrue(eventListIsInteractive)
        revealEventAction("Refuser", event: 2).tap()
        XCTAssertTrue(revealEvent(2).label.contains("Vous ne participez pas"))
        XCTAssertFalse(app.scrollViews["outing-detail-scroll"].exists)
        XCTAssertTrue(eventRow(2).isHittable)
        XCTAssertTrue(revealEvent(2).label.contains("Vous ne participez pas"))
        XCTAssertTrue(revealEvent(3).label.contains("Vous organisez"))
        XCTAssertTrue(revealEvent(2).label.contains("Vous ne participez pas"))
        attachScreenshot(named: "Réponse conservée après défilement")
    }

    func testEventSummariesWithLongPlaceAndMissingOrStaleLocation() {
        for option in ["list-no-location", "list-stale-location"] {
            launchDetailScenario(["guest", "stress", "fullscreen", option])
            openEventList()
            XCTAssertFalse(eventRow(1).label.contains("à vol d’oiseau"))
            XCTAssertTrue(eventRow(1).label.contains("Café du parc et des promenades au bord de la rivière"))
            attachScreenshot(named: "Libellé conservant le lieu complet")
            tapCardBody(1)
            XCTAssertFalse(app.buttons["Retour aux événements"].exists)
            XCTAssertFalse(app.scrollViews["outing-detail-scroll"].exists)
            XCTAssertTrue(eventRow(1).isHittable)
        }
    }

    func testEventListParticipantGroupsAndUnknownStates() {
        launchDetailScenario(["participants-list", "guest", "fullscreen", "list-no-location"])
        openEventList()
        XCTAssertTrue(eventRow(1).label.contains("Aucun autre participant"))
        XCTAssertTrue(revealEvent(2).label.contains("avec Invité 1. Lieu"))
        XCTAssertTrue(revealEvent(3).label.contains("Invité 3"))
        attachScreenshot(named: "Participants un, deux et quatre, organisateur inclus")
        scrollEventList(up: true)
        XCTAssertTrue(revealEvent(4).isHittable)
        XCTAssertTrue(revealEvent(4).label.contains("Invité 5"))
        // Let native overscroll spring back before recording its composited frame.
        RunLoop.main.run(until: Date().addingTimeInterval(1))
        attachScreenshot(named: "Résumé des six participants dans la liste, organisateur inclus")
        tapCardBody(4)
        XCTAssertFalse(app.buttons["Retour aux événements"].exists)
        XCTAssertFalse(app.scrollViews["outing-detail-scroll"].exists)
        XCTAssertTrue(revealEvent(4).isHittable)
        RunLoop.main.run(until: Date().addingTimeInterval(1))
        attachScreenshot(named: "Résumé des six participants conservé après sélection")
        for (option, message) in [("loading", "Chargement des participants"), ("unavailable", "Participants indisponibles")] {
            launchDetailScenario(["guest", "fullscreen", option])
            openEventList()
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
        XCTAssertTrue(requestedIDs().isEmpty)
        openEventList()
        let requested = NSPredicate { _, _ in !requestedIDs().isEmpty }
        expectation(for: requested, evaluatedWith: probe)
        waitForExpectations(timeout: 3)
        let firstIDs = requestedIDs()
        XCTAssertLessThan(firstIDs.components(separatedBy: ",").count, 18)
        tapCardBody(12)
        XCTAssertNotEqual(requestedIDs(), firstIDs)
        XCTAssertLessThan(requestedIDs().components(separatedBy: ",").count, 18)
        app.buttons["motion-dock-friends"].tap()
        assertFriendsListIsHittable(true)
        XCTAssertFalse(eventsButton.isSelected)
        eventsButton.tap()
        XCTAssertTrue(probe.waitForExistence(timeout: 3))
        XCTAssertTrue((probe.value as? String ?? "").contains("suspended=true"))
        XCTAssertFalse(requestedIDs().isEmpty)
        XCTAssertTrue(eventsButton.isSelected)
    }

    func testEventCardsExposeDirectGuestAndOrganizerActions() {
        launchDetailScenario(["social-list", "fullscreen"])
        let card = revealEvent(1)
        XCTAssertGreaterThan(card.frame.width, eventListViewport.width * 0.8)
        XCTAssertFalse(card.buttons["Modifier"].exists)
        let initialListFrame = eventListViewport
        revealEventAction("Participer", event: 1).tap()
        XCTAssertTrue(eventRow(1).label.contains("Vous participez"))
        XCTAssertTrue(revealEvent(2).label.contains("Vous participez"))
        revealEventAction("Refuser", event: 1).tap()
        XCTAssertTrue(eventRow(1).label.contains("Vous ne participez pas"))
        XCTAssertTrue(revealEvent(2).label.contains("Vous participez"))
        XCTAssertEqual(eventListViewport, initialListFrame)
        let owned = revealEvent(3)
        XCTAssertFalse(owned.buttons["Participer"].exists)
        XCTAssertFalse(owned.buttons["Refuser"].exists)
        revealEventAction("Modifier", event: 3).tap()
        XCTAssertTrue(app.buttons["Annuler cet événement"].waitForExistence(timeout: 3))
    }

    func testEventListUnknownOrUpdatingResponseDisablesResponseActions() {
        for option in ["loading", "unavailable", "updating"] {
            launchDetailScenario(["guest", "fullscreen", option])
            for title in ["Participer", "Refuser"] {
                XCTAssertFalse(revealEventAction(title, event: 1).isEnabled)
            }
            XCTAssertTrue(revealEventAction("Itinéraire", event: 1).isEnabled)
        }
    }

    func testEventListInLandscape() {
        app.terminate()
        app.launchArguments = ["-debug-social-map", "-debug-social-map-many-events", "-debug-social-map-fullscreen"]
        app.launch()
        XCTAssertTrue(eventsButton.waitForExistence(timeout: 10))
        openEventList()
        XCTAssertTrue(eventRow(1).isHittable)
        tapCardBody(1)
        XCTAssertFalse(app.buttons["Retour aux événements"].exists)
        XCTAssertFalse(app.scrollViews["outing-detail-scroll"].exists)
        XCTAssertTrue(eventList.waitForExistence(timeout: 3))
        attachScreenshot(named: "Liste")

        defer { XCUIDevice.shared.orientation = .portrait }
        XCUIDevice.shared.orientation = .landscapeLeft
        let landscape = NSPredicate { _, _ in
            self.app.windows.firstMatch.frame.width > self.app.windows.firstMatch.frame.height
        }
        expectation(for: landscape, evaluatedWith: app)
        waitForExpectations(timeout: 5)
        XCTAssertFalse(resizeHandle.exists)
        XCTAssertGreaterThan(map.frame.height, 40)
        let listY = eventListViewport.minY
        scrollEventList(up: true)
        XCTAssertEqual(eventListViewport.minY, listY, accuracy: 2)
        XCTAssertTrue(eventListIsInteractive)
        attachScreenshot(named: "Liste en paysage")
    }

    func testEventsButtonOpensListBelowMapWithoutChangingNativeSize() {
        launchDetailScenario(["guest", "many-events", "fullscreen"])
        let nativeSize = app.maps.firstMatch.frame.size
        let fullMapHeight = map.frame.height
        openEventList()
        XCTAssertTrue(eventsButton.isSelected)
        XCTAssertLessThan(map.frame.height, fullMapHeight)
        assertEventsBelowMap(nativeSize: nativeSize)
        let row = revealEvent(1)
        row.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: 40, dy: 25)).tap()
        XCTAssertFalse(row.isSelected)
        XCTAssertTrue(row.label.contains("Lieu : Sortie 1"))
        XCTAssertTrue(row.label.contains("Théo organise"))
        tapCardBody(2)
        XCTAssertFalse(eventRow(2).isSelected)
        XCTAssertFalse(detailPane.exists)
        assertEventsBelowMap(nativeSize: nativeSize)
        attachScreenshot(named: "Liste détaillée sous la carte ouverte par le bouton")
    }

    func testEventListHandleResizesThenFoldsBackToFullMap() {
        launchDetailScenario(["many-events", "fullscreen"])
        let nativeSize = app.maps.firstMatch.frame.size
        let fullMapFrame = map.frame
        openEventList()
        let initialListHeight = eventListViewport.height
        let initialMapHeight = map.frame.height
        let handle = eventsResizeHandle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        handle.press(forDuration: 0.05, thenDragTo: handle.withOffset(CGVector(dx: 0, dy: -90)))
        let resized = NSPredicate { _, _ in
            abs(self.eventListViewport.height - initialListHeight - 90) < 8
        }
        expectation(for: resized, evaluatedWith: app)
        waitForExpectations(timeout: 3)
        XCTAssertEqual(map.frame.height, initialMapHeight - 90, accuracy: 8)
        assertEventsBelowMap(nativeSize: nativeSize)

        foldEventListByDragging()
        XCTAssertEqual(map.frame, fullMapFrame)
        XCTAssertEqual(app.maps.firstMatch.frame.size, nativeSize)
        assertFullMap(window: app.windows.firstMatch.frame)

        openEventList()
        let thirdHeight = eventListViewport.height
        eventsResizeHandle.tap()
        XCTAssertGreaterThan(eventListViewport.height, thirdHeight + 50)
        assertEventsBelowMap(nativeSize: nativeSize)
        eventsResizeHandle.tap()
        XCTAssertTrue(eventsResizeHandle.waitForNonExistence(timeout: 3))
        XCTAssertFalse(eventsButton.isSelected)
        XCTAssertEqual(app.maps.firstMatch.frame.size, nativeSize)
        assertFullMap(window: app.windows.firstMatch.frame)
    }

    func testEventListScrollDoesNotResizeOrFoldPane() {
        launchDetailScenario(["many-events", "fullscreen"])
        openEventList()
        let listFrame = eventListViewport
        let handleFrame = eventsResizeHandle.frame
        let mapFrame = map.frame
        let firstCardTop = eventRow(1).frame.minY
        scrollEventList(up: true)
        XCTAssertLessThan(eventRow(1).frame.minY, firstCardTop - 20)
        XCTAssertEqual(eventListViewport, listFrame)
        XCTAssertEqual(eventsResizeHandle.frame, handleFrame)
        XCTAssertEqual(map.frame, mapFrame)
        scrollEventList(up: false)
        XCTAssertTrue(eventListIsInteractive)
        XCTAssertEqual(eventsResizeHandle.frame, handleFrame)
        XCTAssertEqual(map.frame, mapFrame)
        XCTAssertTrue(eventsButton.isSelected)
    }

    func testEventListKeepsScrollWhileClosedAndSuspendsRosters() {
        launchDetailScenario(["many-events", "guest", "fullscreen", "roster-probe"])
        let probe = app.staticTexts["debug-list-rosters"]
        XCTAssertTrue(probe.waitForExistence(timeout: 3))
        func requestedIDs() -> Set<String> {
            let ids = (probe.value as? String ?? "").components(separatedBy: ";")[0]
            return Set(ids.split(separator: ",").map(String.init))
        }
        XCTAssertTrue(requestedIDs().isEmpty)
        let row = revealEvent(12)
        row.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: 40, dy: 25)).tap()
        let rowFrame = row.frame
        let activeIDs = requestedIDs()
        XCTAssertFalse(activeIDs.isEmpty)
        XCTAssertLessThan(activeIDs.count, 18)
        let nativeSize = app.maps.firstMatch.frame.size

        for closeWithHandle in [false, true] {
            if closeWithHandle {
                foldEventListByDragging()
            } else {
                eventsButton.tap()
                XCTAssertTrue(eventsResizeHandle.waitForNonExistence(timeout: 3))
            }
            XCTAssertFalse(eventsButton.isSelected)
            XCTAssertFalse(eventListIsInteractive)
            let suspended = NSPredicate { _, _ in requestedIDs().isEmpty }
            expectation(for: suspended, evaluatedWith: probe)
            waitForExpectations(timeout: 3)
            assertFullMap(window: app.windows.firstMatch.frame)
            openEventList()
            let restored = NSPredicate { _, _ in requestedIDs() == activeIDs }
            expectation(for: restored, evaluatedWith: probe)
            waitForExpectations(timeout: 3)
            XCTAssertEqual(row.frame.minY, rowFrame.minY, accuracy: 2)
            XCTAssertTrue(row.isHittable)
            XCTAssertFalse(row.isSelected)
            assertEventsBelowMap(nativeSize: nativeSize)
        }
    }

    func testDetailedListReturnsAtSameHeightAndScrollAfterFriendProfile() {
        launchDetailScenario(["mixed", "many-events", "fullscreen", "roster-probe"])
        openEventList()
        let initialHeight = eventListViewport.height
        let handle = eventsResizeHandle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        handle.press(forDuration: 0.05, thenDragTo: handle.withOffset(CGVector(dx: 0, dy: -80)))
        let resized = NSPredicate { _, _ in self.eventListViewport.height > initialHeight + 50 }
        expectation(for: resized, evaluatedWith: eventList)
        waitForExpectations(timeout: 3)
        let row = revealEvent(12)
        row.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: 40, dy: 25)).tap()
        let listFrame = eventListViewport
        let rowFrame = row.frame
        let nativeSize = app.maps.firstMatch.frame.size
        let probe = app.staticTexts["debug-list-rosters"]
        app.buttons["motion-dock-friends"].tap()
        assertFriendsListIsHittable(true)
        friendsList.buttons["Amina"].tap()
        XCTAssertTrue(detailPane.staticTexts["Amina"].waitForExistence(timeout: 3))
        XCTAssertFalse(eventListIsInteractive)
        XCTAssertFalse(eventsResizeHandle.exists)
        XCTAssertFalse(eventsButton.isSelected)
        let suspended = NSPredicate { _, _ in
            (probe.value as? String ?? "").hasPrefix(";")
        }
        expectation(for: suspended, evaluatedWith: probe)
        waitForExpectations(timeout: 3)
        closeFriendSheet()
        assertFriendsListIsHittable(true)
        openEventList()
        XCTAssertTrue(eventList.waitForExistence(timeout: 3))
        XCTAssertEqual(eventListViewport, listFrame)
        XCTAssertEqual(row.frame.minY, rowFrame.minY, accuracy: 2)
        XCTAssertTrue(row.isHittable)
        assertEventsBelowMap(nativeSize: nativeSize)
    }

    func testCardDirectionsRemainAvailableAfterResponse() {
        launchDetailScenario(["guest", "fullscreen"])
        openEventList()
        let mapFrame = map.frame
        revealEventAction("Participer", event: 1).tap()
        XCTAssertTrue(eventRow(1).label.contains("Vous participez"))
        XCTAssertEqual(map.frame, mapFrame)
        revealEventAction("Itinéraire", event: 1).tap()
        XCTAssertTrue(app.alerts["Itinéraire de test"].waitForExistence(timeout: 3))
    }

    func testCardTapLongPressAndHorizontalSwipeKeepListAndPanelStable() {
        launchDetailScenario(["many-events", "guest", "fullscreen", "roster-probe"])
        openEventList()
        let handle = eventsResizeHandle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        handle.press(forDuration: 0.05, thenDragTo: handle.withOffset(CGVector(dx: 0, dy: -100)))
        let card = revealEvent(18)
        let response = card.label
        let cardFrame = card.frame
        let listFrame = eventListViewport
        let handleFrame = eventsResizeHandle.frame
        let mapFrame = map.frame
        let nativeSize = app.maps.firstMatch.frame.size
        let body = card.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.15))
        body.tap()
        body.press(forDuration: 1)
        body.press(forDuration: 0.05, thenDragTo: body.withOffset(CGVector(dx: -80, dy: 0)))
        XCTAssertTrue(eventListIsInteractive)
        XCTAssertFalse(app.descendants(matching: .any)["event-detail-content"].exists)
        XCTAssertFalse(app.navigationBars.buttons["Événements"].exists)
        XCTAssertFalse(app.menus.firstMatch.exists)
        XCTAssertEqual(card.label, response)
        XCTAssertEqual(card.frame.minX, cardFrame.minX, accuracy: 2)
        XCTAssertEqual(card.frame.minY, cardFrame.minY, accuracy: 2)
        XCTAssertEqual(eventListViewport, listFrame)
        XCTAssertEqual(eventsResizeHandle.frame, handleFrame)
        XCTAssertEqual(map.frame, mapFrame)
        XCTAssertEqual(app.maps.firstMatch.frame.size, nativeSize)
        let probe = app.staticTexts["debug-list-rosters"]
        let active = NSPredicate { _, _ in !(probe.value as? String ?? "").hasPrefix(";") }
        expectation(for: active, evaluatedWith: probe)
        waitForExpectations(timeout: 3)
    }

    func testGroupedEventTargetsCardWithoutExpandingPanel() {
        launchDetailScenario(["fullscreen", "roster-probe"])
        let nativeSize = app.maps.firstMatch.frame.size
        openEventList()
        let handleFrame = eventsResizeHandle.frame
        eventsButton.tap()
        XCTAssertTrue(eventsResizeHandle.waitForNonExistence(timeout: 3))
        openGroupedEvent(index: 0)
        XCTAssertTrue(eventRow(2).isHittable)
        XCTAssertTrue(eventRow(2).label.contains("Café"))
        XCTAssertEqual(eventsResizeHandle.frame, handleFrame)
        XCTAssertFalse(app.descendants(matching: .any)["event-detail-content"].exists)
        let probe = app.staticTexts["debug-list-rosters"]
        let active = NSPredicate { _, _ in !(probe.value as? String ?? "").hasPrefix(";") }
        expectation(for: active, evaluatedWith: probe)
        waitForExpectations(timeout: 3)
        assertEventsBelowMap(nativeSize: nativeSize)
    }

    func testInitiallyTargetedEventScrollsToItsCard() {
        launchDetailScenario(["many-events", "open-event", "fullscreen"])
        let targeted = NSPredicate { _, _ in
            let card = self.eventRow(18)
            let bounds = self.eventListViewport
            return card.exists && card.isHittable
                && card.frame.minY >= bounds.minY
                && card.frame.minY + 40 <= bounds.maxY
        }
        expectation(for: targeted, evaluatedWith: app)
        waitForExpectations(timeout: 3)
        XCTAssertFalse(eventRow(1).isHittable)
        XCTAssertEqual(eventsResizeHandle.value as? String, "Un tiers de l’écran")
        XCTAssertFalse(app.descendants(matching: .any)["event-detail-content"].exists)
    }

    func testSelectingSameEventPinAgainReturnsToItsCard() {
        launchDetailScenario(["fullscreen"])
        openGroupedEvent(index: 0)
        let pin = eventPin("Café")
        XCTAssertTrue(pin.waitForExistence(timeout: 3))
        let handleFrame = eventsResizeHandle.frame
        for _ in 0..<2 {
            revealEvent(1)
            let before = eventRow(2).frame.minY
            pin.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            let targeted = NSPredicate { _, _ in
                let card = self.eventRow(2)
                let bounds = self.eventListViewport
                return card.exists && card.isHittable
                    && card.frame.minY >= bounds.minY
                    && card.frame.minY + 40 <= bounds.maxY
                    && card.frame.minY < before - 20
            }
            expectation(for: targeted, evaluatedWith: app)
            waitForExpectations(timeout: 3)
            XCTAssertEqual(eventsResizeHandle.frame, handleFrame)
            XCTAssertFalse(app.descendants(matching: .any)["event-detail-content"].exists)
        }
    }

    private func tapCardBody(_ number: Int) {
        revealEvent(number).coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: 40, dy: 25)).tap()
    }

    @discardableResult
    private func revealEventAction(_ title: String, event number: Int) -> XCUIElement {
        revealEvent(number)
        let button = eventRow(number).buttons[title].firstMatch
        for _ in 0..<25 {
            let bounds = eventListViewport
            if button.exists, button.isHittable,
               button.frame.minY >= bounds.minY, button.frame.maxY <= bounds.maxY {
                return button
            }
            let scrollDown = button.exists && button.frame.minY < bounds.minY
            let start = app.windows.firstMatch.coordinate(withNormalizedOffset: .zero)
                .withOffset(CGVector(dx: bounds.midX, dy: bounds.midY))
            let distance = min(70, bounds.height * 0.3) * (scrollDown ? 1 : -1)
            start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: distance)))
        }
        XCTFail("Action \(title) de la carte \(number) non visible")
        return button
    }

    private func attachInterfaceDiagnostics(named name: String) {
        attachScreenshot(named: name)
        let hierarchy = XCTAttachment(string: app.debugDescription)
        hierarchy.name = name + " - hiérarchie"
        hierarchy.lifetime = .keepAlways
        add(hierarchy)
    }

    private func openEventList() {
        if !eventsResizeHandle.exists {
            XCTAssertTrue(eventsButton.waitForExistence(timeout: 3))
            eventsButton.tap()
        }
        XCTAssertTrue(eventList.waitForExistence(timeout: 3))
        XCTAssertTrue(eventsResizeHandle.waitForExistence(timeout: 3))
        if !eventListIsInteractive { attachInterfaceDiagnostics(named: "Liste non interactive après ouverture") }
        XCTAssertTrue(eventListIsInteractive)
        XCTAssertTrue(eventsResizeHandle.isHittable)
    }

    private func foldEventListByDragging() {
        let start = eventsResizeHandle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let distance = max(80, eventsPane.frame.height - 60)
        start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: distance)))
        XCTAssertTrue(eventsResizeHandle.waitForNonExistence(timeout: 3))
        XCTAssertFalse(eventListIsInteractive)
        XCTAssertFalse(eventsButton.isSelected)
    }

    private func assertEventsBelowMap(nativeSize: CGSize) {
        XCTAssertEqual(map.frame.maxY, eventsResizeHandle.frame.midY - 10, accuracy: 2)
        XCTAssertEqual(eventsResizeHandle.frame.height, 44, accuracy: 1)
        XCTAssertEqual(eventsPane.frame.minY - map.frame.maxY, 20, accuracy: 2)
        XCTAssertEqual(eventsPane.frame.minY, eventsResizeHandle.frame.midY + 10, accuracy: 2)
        XCTAssertGreaterThan(eventListViewport.height, 0)
        XCTAssertFalse(app.navigationBars["Événements"].exists)
        XCTAssertGreaterThanOrEqual(eventListViewport.minY, eventsResizeHandle.frame.maxY - 2)
        XCTAssertTrue(eventListIsInteractive)
        XCTAssertLessThanOrEqual(eventListViewport.maxY, app.buttons["motion-dock-explore"].frame.minY)
        XCTAssertLessThanOrEqual(eventListViewport.maxY, eventsButton.frame.minY)
        XCTAssertTrue(eventsButton.isSelected)
        XCTAssertEqual(app.maps.firstMatch.frame.width, nativeSize.width, accuracy: 1)
        XCTAssertEqual(app.maps.firstMatch.frame.height, nativeSize.height, accuracy: 1)
    }

    private var eventsResizeHandle: XCUIElement {
        app.buttons["map-events-resize-handle"].firstMatch
    }

    private var eventsPane: XCUIElement {
        app.descendants(matching: .any)["map-events-pane"].firstMatch
    }

    @discardableResult
    private func revealEvent(_ number: Int) -> XCUIElement {
        openEventList()
        let row = eventRow(number)
        for _ in 0..<max(20, number * 3) {
            let bounds = eventListViewport
            if row.exists && row.isHittable,
               row.frame.minY >= bounds.minY, row.frame.minY + min(60, row.frame.height) <= bounds.maxY {
                return row
            }
            let visibleNumbers = app.descendants(matching: .any).matching(NSPredicate(
                format: "identifier BEGINSWITH %@", "event-card-"
            )).allElementsBoundByIndex.filter { $0.isHittable }
                .compactMap { Int($0.identifier.suffix(12)) }
            let scrollDown = (row.exists && row.frame.minY < bounds.minY)
                || visibleNumbers.min().map({ number < $0 }) == true
            let start = app.windows.firstMatch.coordinate(withNormalizedOffset: .zero)
                .withOffset(CGVector(dx: bounds.midX, dy: bounds.midY))
            let alignmentDistance = row.exists ? abs(row.frame.minY - bounds.minY - 8) : 100
            let distance = min(100, bounds.height * 0.4, max(15, alignmentDistance)) * (scrollDown ? 1 : -1)
            start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: distance)))
        }
        XCTFail("Carte événement \(number) non visible après défilement")
        return row
    }

    private func assertFullMap(window: CGRect) {
        XCTAssertFalse(detailPane.exists)
        XCTAssertFalse(resizeHandle.exists)
        XCTAssertFalse(eventsResizeHandle.exists)
        XCTAssertFalse(eventListIsInteractive)
        XCTAssertFalse(eventsButton.isSelected)
        XCTAssertEqual(map.frame.minY, window.minY, accuracy: 1)
        XCTAssertEqual(map.frame.maxY, window.maxY, accuracy: 1)
        XCTAssertEqual(map.frame.width, window.width, accuracy: 1)
    }

    private func assertFriendsListIsHittable(
        _ expected: Bool,
        timeout: TimeInterval = 3,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let predicate = NSPredicate { _, _ in
            let list = self.friendsList
            return (list.exists && list.isHittable) == expected
        }
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: timeout), .completed,
                       file: file, line: line)
    }

    private var friendsList: XCUIElement {
        app.descendants(matching: .any)["friends-expanded-list"].firstMatch
    }

    private var eventList: XCUIElement {
        app.descendants(matching: .any)["events-expanded-list"].firstMatch
    }

    private var eventListIsInteractive: Bool {
        isEventListInteractive(in: app)
    }

    private var eventListViewport: CGRect {
        eventContentViewport(in: app, content: eventList)
    }

    private func scrollEventList(up: Bool) {
        let bounds = eventListViewport
        let start = app.windows.firstMatch.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: bounds.midX, dy: bounds.midY))
        let distance = bounds.height * 0.4 * (up ? -1 : 1)
        start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: distance)))
    }

    private var eventsButton: XCUIElement { app.buttons["motion-dock-events"] }

    // The map camera excludes the bottom controls. The assertion tolerance
    // also accounts for the top safe area, absent from XCUIElement's frame.
    private var usableMapCenterY: CGFloat {
        let controlsTop = app.segmentedControls.firstMatch.exists
            ? app.segmentedControls.firstMatch.frame.minY : eventsButton.frame.minY
        return (map.frame.minY + controlsTop) / 2
    }

    private func openMixedFriend(eventCount: Int) {
        let summary = "3 personnes et \(eventCount) sorties prévues"
        let group = app.buttons["Groupe, " + summary]
        XCTAssertTrue(group.waitForExistence(timeout: 3))
        group.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        let expanded = app.buttons["Groupe ouvert, " + summary]
        let didExpand = expanded.waitForExistence(timeout: 3)
        if !didExpand { attachInterfaceDiagnostics(named: "Groupe mixte non ouvert après appui") }
        XCTAssertTrue(didExpand)
        tapExpandedRow(expanded, index: 1, rowCount: eventCount + 3)
        XCTAssertTrue(detailPane.staticTexts["Amina"].waitForExistence(timeout: 3))
    }

    private func eventRow(_ number: Int) -> XCUIElement {
        app.descendants(matching: .any)[String(format: "event-card-00000000-0000-4000-8000-%012d", number)].firstMatch
    }

    // MARK: - Scenario interactions

    private var map: XCUIElement { app.otherElements["map-visible-viewport"].firstMatch }

    private var detailPane: XCUIElement {
        app.scrollViews["friend-profile-scroll"].firstMatch
    }

    private var resizeHandle: XCUIElement {
        app.descendants(matching: .any)["map-detail-resize-handle"].firstMatch
    }

    private func closeFriendSheet() {
        XCTAssertTrue(detailPane.exists)
        let start = detailPane.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.1))
        let bottom = app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.98))
        start.press(forDuration: 0.05, thenDragTo: bottom)
        XCTAssertTrue(detailPane.waitForNonExistence(timeout: 3))
    }

    private func openGroupedEvent(index: Int) {
        let group = app.buttons["Groupe, 2 sorties prévues"]
        XCTAssertTrue(group.waitForExistence(timeout: 10))
        group.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        let expanded = app.buttons["Groupe ouvert, 2 sorties prévues"]
        XCTAssertTrue(expanded.waitForExistence(timeout: 2))
        tapExpandedRow(expanded, index: index, rowCount: 2)
        XCTAssertTrue(expanded.waitForNonExistence(timeout: 3))
        XCTAssertTrue(eventList.waitForExistence(timeout: 3))
        XCTAssertTrue(eventsResizeHandle.isHittable)
        XCTAssertTrue(eventListIsInteractive)
        XCTAssertFalse(detailPane.exists)
        XCTAssertFalse(resizeHandle.exists)
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

    private func cancelGroupRow(index: Int, eventNumber: Int, expectedTitle: String, remainingTitle: String) {
        openGroupedEvent(index: index)
        XCTAssertTrue(eventRow(eventNumber).label.contains(expectedTitle))
        cancelPresentedEvent(eventNumber: eventNumber)
        XCTAssertTrue(eventPin(remainingTitle).waitForExistence(timeout: 3))
        XCTAssertFalse(eventPin(expectedTitle).exists)
    }

    private func cancelRemainingEvent(eventNumber: Int, title: String) {
        eventPin(title).coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        cancelPresentedEvent(eventNumber: eventNumber)
        XCTAssertFalse(eventPin(title).exists)
        XCTAssertFalse(app.buttons["Groupe, 2 sorties prévues"].exists)
    }

    private func cancelPresentedEvent(eventNumber: Int) {
        revealEventAction("Modifier", event: eventNumber).tap()
        let cancel = app.buttons["Annuler cet événement"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 3))
        if !cancel.isHittable { app.swipeUp() }
        cancel.tap()
        app.buttons["Annuler l’événement"].tap()
        XCTAssertTrue(cancel.waitForNonExistence(timeout: 3))
        XCTAssertTrue(eventList.waitForExistence(timeout: 3))
        XCTAssertFalse(eventRow(eventNumber).exists)
    }

    private func eventPin(_ title: String) -> XCUIElement {
        app.buttons["Votre sortie prévue, \(title), organisateur seul"]
    }
}

/// Opt-in on a connected device. Selecting and scrolling existing events never
/// creates or edits account data.
@MainActor
final class MapDeviceSmokeUITests: XCTestCase {
    func testRealEventListWithMetalValidation() throws {
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
        let eventsButton = app.buttons["motion-dock-events"]
        let list = app.descendants(matching: .any)["events-expanded-list"].firstMatch
        let handle = app.buttons["map-events-resize-handle"]
        XCTAssertTrue(viewport.waitForExistence(timeout: 3))
        XCTAssertTrue(eventsButton.waitForExistence(timeout: 3))
        let window = app.windows.firstMatch.frame
        XCTAssertEqual(viewport.frame.minY, window.minY, accuracy: 1)
        XCTAssertEqual(viewport.frame.maxY, window.maxY, accuracy: 1)
        XCTAssertFalse(eventsButton.isSelected)
        XCTAssertFalse(isEventListInteractive(in: app))
        XCTAssertTrue(app.buttons["map-own-profile"].isHittable)
        XCTAssertTrue(app.buttons["Recentrer la carte sur ma position"].isHittable)
        let nativeSize = nativeMap.frame.size
        eventsButton.tap()
        XCTAssertTrue(list.waitForExistence(timeout: 3))
        XCTAssertTrue(handle.waitForExistence(timeout: 3))
        XCTAssertTrue(eventsButton.isSelected)
        XCTAssertEqual(viewport.frame.maxY, handle.frame.midY - 10, accuracy: 2)
        XCTAssertLessThanOrEqual(eventContentViewport(in: app, content: list).maxY, eventsButton.frame.minY)
        let events = app.descendants(matching: .any).matching(NSPredicate(
            format: "identifier BEGINSWITH %@", "event-card-"
        ))
        guard events.firstMatch.waitForExistence(timeout: 15) else {
            throw XCTSkip("Aucune sortie existante accessible pour ce contrôle.")
        }
        for cycle in 0..<4 {
            let event = try XCTUnwrap(events.allElementsBoundByIndex.first {
                $0.isHittable && $0.frame.minY >= eventContentViewport(in: app, content: list).minY
                    && $0.frame.minY + 40 <= eventContentViewport(in: app, content: list).maxY
            })
            event.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: 30, dy: 25)).tap()
            XCTAssertFalse(app.descendants(matching: .any)["event-detail-content"].exists)
            XCTAssertTrue(isEventListInteractive(in: app))
            XCTAssertFalse(app.buttons["map-detail-resize-handle"].exists)
            XCTAssertEqual(nativeMap.frame.width, nativeSize.width, accuracy: 1)
            XCTAssertEqual(nativeMap.frame.height, nativeSize.height, accuracy: 1)
            XCTAssertEqual(viewport.frame.maxY, handle.frame.midY - 10, accuracy: 2)
            XCTAssertEqual(app.state, .runningForeground)
            XCTAssertFalse(app.scrollViews["outing-detail-scroll"].exists)
            if cycle == 0 {
                let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
                screenshot.name = "Liste événements sur iPhone avec Metal actif"
                screenshot.lifetime = .keepAlways
                add(screenshot)
            }
            XCTAssertTrue(isEventListInteractive(in: app))
            XCTAssertFalse(event.isSelected)
            if cycle.isMultiple(of: 2) { list.swipeUp() } else { list.swipeDown() }
            eventsButton.tap()
            XCTAssertTrue(handle.waitForNonExistence(timeout: 3))
            XCTAssertFalse(eventsButton.isSelected)
            XCTAssertFalse(isEventListInteractive(in: app))
            XCTAssertEqual(viewport.frame.maxY, window.maxY, accuracy: 1)
            XCTAssertEqual(nativeMap.frame.size, nativeSize)
            eventsButton.tap()
            XCTAssertTrue(handle.waitForExistence(timeout: 3))
            XCTAssertTrue(eventsButton.isSelected)
            XCTAssertEqual(nativeMap.frame.size, nativeSize)
        }
        #endif
    }
}

/// Native collections extend beneath the navigation bar and dock. Their children,
/// rather than the collection container, identify the visible interactive content.
@MainActor
private func eventContentViewport(in app: XCUIApplication, content: XCUIElement) -> CGRect {
    let pane = app.descendants(matching: .any)["map-events-pane"].firstMatch
    guard content.exists, pane.exists else { return .zero }
    let frame = content.frame.intersection(pane.frame)
    guard !frame.isNull else { return .zero }
    let navigationBar = app.navigationBars.firstMatch
    let top = navigationBar.exists ? max(frame.minY, navigationBar.frame.maxY) : frame.minY
    var bottom = frame.maxY
    for control in [app.buttons["motion-dock-explore"], app.buttons["motion-dock-events"],
                    app.segmentedControls.firstMatch] where control.exists {
        bottom = min(bottom, control.frame.minY)
    }
    return CGRect(x: frame.minX, y: top, width: frame.width, height: max(0, bottom - top))
}

@MainActor
private func isEventListInteractive(in app: XCUIApplication) -> Bool {
    let list = app.descendants(matching: .any)["events-expanded-list"].firstMatch
    guard list.exists, app.buttons["motion-dock-events"].isSelected else { return false }
    let viewport = eventContentViewport(in: app, content: list)
    for type in [XCUIElement.ElementType.button, .staticText, .progressIndicator] {
        if list.descendants(matching: type).allElementsBoundByIndex.contains(where: {
            $0.isHittable && viewport.intersects($0.frame)
        }) { return true }
    }
    return false
}
