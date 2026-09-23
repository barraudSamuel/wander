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
        assertFriendsListIsHittable(false)
        XCTAssertTrue(command("explore").isSelected)
        assertTabFrames(tabFrames)
        let start = command("explore").coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let end = command("friends").coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.6, thenDragTo: end)
        assertFriendsListIsHittable(true)
        XCTAssertTrue(command("friends").isSelected)
        XCTAssertFalse(command("profile").exists)
        assertFriendsBelowMap()
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
        // The 44 pt hit target overlaps the 20 pt separator by 12 pt.
        XCTAssertEqual(mapViewport.frame.maxY, eventsHandle.frame.minY + 12, accuracy: 2)
        XCTAssertLessThan(mapViewport.frame.height, fullMapFrame.height)
        XCTAssertEqual(eventList.frame.maxY, app.windows.firstMatch.frame.maxY, accuracy: 2)
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
        for panel in ["friends"] {
            command(panel).tap()
            assertFriendsListIsHittable(true)
            XCTAssertFalse(command("events").isSelected)
            XCTAssertFalse(eventList.isHittable)
            assertEventsFrame(buttonFrame)
            command("events").tap()
            assertFriendsListIsHittable(false)
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
        assertFriendsListIsHittable(true)
        XCTAssertTrue(friendsList.buttons["Accepter"].exists)
        assertTabFrames(tabFrames)
        assertFriendsBelowMap()
        command("friends").tap()
        assertFriendsListIsHittable(false)
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
        assertFriendsListIsHittable(false)
        assertMapMarkerRemains(group, at: groupFrame)
        closeOwnSheet()
        assertMapMarkerRemains(group, at: groupFrame)
        XCTAssertTrue(profileButton.isHittable)
        XCTAssertEqual(profileButton.frame, profileFrame)
        XCTAssertEqual(app.maps.firstMatch.frame, originalMap)
        assertTabFrames(tabFrames)
    }

    func testMapRemainsInteractiveAboveFriendsList() {
        let nativeMapSize = app.maps.firstMatch.frame.size
        let fullHeight = mapViewport.frame.height
        command("friends").tap()
        assertFriendsListIsHittable(true)
        XCTAssertTrue(friendsHandle.waitForExistence(timeout: 3))
        XCTAssertLessThan(mapViewport.frame.height, fullHeight * 0.7)
        XCTAssertGreaterThan(mapViewport.frame.height, fullHeight * 0.3)
        XCTAssertEqual(app.maps.firstMatch.frame.size, nativeMapSize)
        assertFriendsBelowMap()
        XCTAssertFalse(app.buttons["motion-dock-dismiss"].exists)
        mapViewport.coordinate(withNormalizedOffset: CGVector(dx: 0.15, dy: 0.4)).tap()
        assertFriendsListIsHittable(true)

        let group = app.buttons["Groupe, 2 sorties prévues"]
        XCTAssertTrue(group.waitForExistence(timeout: 5))
        let beforeX = group.frame.midX
        let start = mapViewport.coordinate(withNormalizedOffset: CGVector(dx: 0.25, dy: 0.6))
        start.press(
            forDuration: 0.05,
            thenDragTo: start.withOffset(CGVector(dx: 65, dy: 0)),
            withVelocity: .slow,
            thenHoldForDuration: 0.3
        )
        XCTAssertGreaterThan(abs(group.frame.midX - beforeX), 25)
        assertFriendsListIsHittable(true)
        XCTAssertEqual(app.maps.firstMatch.frame.size, nativeMapSize)
        command("explore").tap()
        assertFriendsListIsHittable(false)
        XCTAssertEqual(mapViewport.frame.height, fullHeight, accuracy: 2)
        XCTAssertFalse(eventList.isHittable)
    }

    func testFriendsListKeepsRequestsHeightAndScrollAcrossEventsAndProfile() {
        command("friends").tap()
        assertFriendsListIsHittable(true)
        friendsList.buttons["Accepter"].tap()
        XCTAssertFalse(friendsList.buttons["Accepter"].exists)
        XCTAssertTrue(friendsList.staticTexts["Camille"].exists)
        let start = friendsHandle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: -80)))
        let friendsHeight = friendsList.frame.height
        let row = friendsList.staticTexts["Ami 20"]
        for _ in 0..<8 {
            if row.isHittable { break }
            friendsList.swipeUp()
        }
        XCTAssertTrue(row.isHittable)
        let rowY = row.frame.minY

        command("events").tap()
        XCTAssertTrue(eventList.waitForExistence(timeout: 3))
        assertFriendsListIsHittable(false)
        let eventStart = eventsHandle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        eventStart.press(forDuration: 0.05, thenDragTo: eventStart.withOffset(CGVector(dx: 0, dy: -60)))
        let eventsHeight = eventList.frame.height
        command("friends").tap()
        assertFriendsListIsHittable(true)
        XCTAssertFalse(eventList.isHittable)
        XCTAssertEqual(friendsList.frame.height, friendsHeight, accuracy: 2)
        XCTAssertEqual(row.frame.minY, rowY, accuracy: 2)
        profileButton.tap()
        XCTAssertTrue(ownSheet.waitForExistence(timeout: 3))
        assertFriendsListIsHittable(false)
        closeOwnSheet()
        assertFriendsListIsHittable(true)
        XCTAssertEqual(friendsList.frame.height, friendsHeight, accuracy: 2)
        XCTAssertEqual(row.frame.minY, rowY, accuracy: 2)
        command("events").tap()
        XCTAssertTrue(eventList.waitForExistence(timeout: 3))
        XCTAssertEqual(eventList.frame.height, eventsHeight, accuracy: 2)
        command("friends").tap()
        XCTAssertTrue(friendsHandle.waitForExistence(timeout: 3))
        let closeStart = friendsHandle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        closeStart.press(forDuration: 0.05, thenDragTo: command("friends").coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)))
        assertFriendsListIsHittable(false)
        XCTAssertTrue(command("explore").isSelected)
        XCTAssertFalse(eventList.isHittable)
    }

    func testBottomOfFriendsListClearsNativeDock() {
        command("friends").tap()
        assertFriendsListIsHittable(true)
        let tabBar = app.tabBars["native-map-tab-bar"]
        XCTAssertEqual(friendsList.frame.maxY, app.windows.firstMatch.frame.maxY, accuracy: 2)
        attachScreenshot("Les amis défilent derrière le dock")

        let lastFriend = friendsList.cells.containing(.staticText, identifier: "Alex").firstMatch
        for _ in 0..<25 {
            if lastFriend.isHittable && lastFriend.frame.maxY <= tabBar.frame.minY { break }
            swipeListAboveDock(friendsList, tabBar: tabBar)
        }

        XCTAssertTrue(lastFriend.isHittable)
        XCTAssertLessThanOrEqual(lastFriend.frame.maxY, tabBar.frame.minY)
        attachScreenshot("Dernier ami au-dessus du dock")
    }

    func testBottomOfEventsListClearsNativeDock() {
        app.terminate()
        app.launchArguments += ["-debug-social-map-many-events"]
        app.launch()
        command("events").tap()
        XCTAssertTrue(eventList.waitForExistence(timeout: 3))
        XCTAssertTrue(eventList.isHittable)
        XCTAssertTrue(command("events").isSelected)
        XCTAssertTrue(command("explore").isSelected)
        XCTAssertFalse(command("friends").isSelected)
        XCTAssertFalse(friendsList.isHittable)
        XCTAssertTrue(eventsHandle.isHittable)
        XCTAssertEqual(eventList.frame.maxY, app.windows.firstMatch.frame.maxY, accuracy: 2)
        attachScreenshot("Les événements défilent derrière le dock")

        let lastEvent = app.buttons["event-detail-row-00000000-0000-4000-8000-000000000018"]
        let tabBar = app.tabBars["native-map-tab-bar"]
        for _ in 0..<25 {
            if lastEvent.isHittable && lastEvent.frame.maxY <= tabBar.frame.minY { break }
            swipeListAboveDock(eventList, tabBar: tabBar)
            XCTAssertTrue(command("events").isSelected)
        }

        XCTAssertTrue(lastEvent.isHittable)
        XCTAssertLessThanOrEqual(lastEvent.frame.maxY, tabBar.frame.minY)
        attachScreenshot("Dernier événement au-dessus du dock")
    }

    func testFriendListRestoresAfterOpeningAnIndividualProfile() {
        app.terminate()
        app.launchArguments += ["-debug-social-map-mixed", "-debug-dock-friends"]
        app.launch()
        assertFriendsListIsHittable(true, timeout: 10)
        friendsList.buttons["Refuser"].tap()
        XCTAssertFalse(friendsList.buttons["Refuser"].exists)
        let listFrame = friendsList.frame
        friendsList.buttons["Amina"].tap()
        let sheet = app.scrollViews["friend-profile-scroll"].firstMatch
        XCTAssertTrue(sheet.waitForExistence(timeout: 3))
        assertFriendsListIsHittable(false)
        let start = sheet.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.05))
        let bottom = app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.98))
        start.press(forDuration: 0.05, thenDragTo: bottom)
        XCTAssertTrue(sheet.waitForNonExistence(timeout: 3))
        assertFriendsListIsHittable(true)
        XCTAssertEqual(friendsList.frame, listFrame)
        XCTAssertTrue(command("friends").isSelected)
        XCTAssertFalse(friendsList.buttons["Refuser"].exists)
        attachScreenshot("Amis et invitations sous la carte")
    }

    func testFriendInvitationsLiveInProfileAndDraftSurvivesClosing() {
        command("friends").tap()
        assertFriendsListIsHittable(true)
        XCTAssertTrue(app.staticTexts["Ami 1"].exists)
        XCTAssertFalse(app.textFields["Code ami"].exists)
        XCTAssertFalse(app.buttons["Partager mon code"].exists)
        XCTAssertFalse(app.buttons["Ajouter un ami"].exists)
        command("explore").tap()

        profileButton.tap()
        XCTAssertTrue(ownSheet.waitForExistence(timeout: 3))
        let share = ownSheet.buttons["Partager mon code"]
        revealInOwnSheet(share)
        XCTAssertTrue(ownSheet.staticTexts["WANDER23456"].exists)
        XCTAssertTrue(ownSheet.buttons["Copier"].exists)
        let code = ownSheet.textFields["Code ami"]
        revealInOwnSheet(code)
        let add = ownSheet.buttons["Ajouter un ami"]
        XCTAssertTrue(add.exists)
        XCTAssertFalse(add.isEnabled)
        code.tap()
        code.typeText("WANDER")
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 3))
        XCTAssertTrue(add.isEnabled)
        closeOwnSheet()
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 3))

        command("friends").tap()
        assertFriendsListIsHittable(true)
        XCTAssertFalse(app.textFields["Code ami"].exists)
        command("explore").tap()
        profileButton.tap()
        XCTAssertTrue(ownSheet.waitForExistence(timeout: 3))
        revealInOwnSheet(code)
        XCTAssertEqual(code.value as? String, "WANDER")
        attachScreenshot("Code ami et invitation dans le profil personnel")
        closeOwnSheet()

        let user = app.buttons["Moi, Vous"]
        XCTAssertTrue(user.waitForExistence(timeout: 3))
        user.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(ownSheet.waitForExistence(timeout: 3))
        revealInOwnSheet(code)
        XCTAssertEqual(code.value as? String, "WANDER")
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
        assertFriendsListIsHittable(true)
        XCTAssertTrue(command("events").isHittable)
        XCTAssertLessThanOrEqual(command("events").frame.maxX, app.windows.firstMatch.frame.maxX)
        XCTAssertEqual(command("events").frame.midY, command("friends").frame.midY, accuracy: 2)
        command("explore").tap()
        assertFriendsListIsHittable(false)
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

    private var friendsHandle: XCUIElement { app.buttons["map-friends-resize-handle"] }

    private func swipeListAboveDock(_ list: XCUIElement, tabBar: XCUIElement) {
        let startY = min(list.frame.maxY - 30, tabBar.frame.minY - 40)
        let endY = list.frame.minY + 40
        let window = app.windows.firstMatch
        let start = window.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: list.frame.midX, dy: startY))
        let end = window.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: list.frame.midX, dy: endY))
        start.press(forDuration: 0.05, thenDragTo: end)
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

    private func assertFriendsBelowMap() {
        assertFriendsListIsHittable(true)
        XCTAssertLessThanOrEqual(mapViewport.frame.maxY, friendsList.frame.minY)
        XCTAssertEqual(friendsList.frame.width, mapViewport.frame.width, accuracy: 2)
        XCTAssertEqual(friendsList.frame.maxY, app.windows.firstMatch.frame.maxY, accuracy: 2)
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
