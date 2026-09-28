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
        XCTAssertTrue(command("explore").waitForExistence(timeout: 10))
    }

    func testNativeNavigationContainsExploreAndEventsWithoutFriends() {
        let tabBar = app.tabBars["native-map-tab-bar"]
        XCTAssertTrue(tabBar.waitForExistence(timeout: 3))
        XCTAssertEqual(tabBar.buttons.count, 1)
        XCTAssertTrue(command("explore").isSelected)
        XCTAssertTrue(command("events").isHittable)
        XCTAssertFalse(command("friends").exists)
        XCTAssertFalse(command("profile").exists)
        XCTAssertFalse(app.buttons["map-friends-resize-handle"].exists)
        command("events").tap()
        XCTAssertTrue(eventList.waitForExistence(timeout: 3))
        command("explore").tap()
        XCTAssertTrue(eventsHandle.waitForNonExistence(timeout: 3))
        attachScreenshot("Navigation Explorer et Événements")
    }

    func testEventsButtonSitsBesideNativeTabsAndTogglesList() {
        let tabBar = app.tabBars["native-map-tab-bar"]
        let events = command("events")
        XCTAssertTrue(events.waitForExistence(timeout: 3))
        XCTAssertEqual(tabBar.buttons.count, 1)
        XCTAssertFalse(tabBar.buttons["motion-dock-events"].exists)
        XCTAssertGreaterThanOrEqual(events.frame.minX, tabBar.frame.maxX)
        XCTAssertGreaterThanOrEqual(events.frame.width, 44)
        XCTAssertGreaterThanOrEqual(events.frame.height, 44)
        XCTAssertLessThanOrEqual(events.frame.maxX, app.windows.firstMatch.frame.maxX)
        XCTAssertEqual(events.frame.midY, command("explore").frame.midY, accuracy: 2,
                       "Le calendrier doit être centré verticalement sur les onglets.")
        XCTAssertTrue(events.isHittable)
        XCTAssertFalse(events.isSelected)
        XCTAssertFalse(eventList.isHittable)
        let nativeMapSize = app.maps.firstMatch.frame.size
        let fullMapFrame = mapViewport.frame
        let exploreFrame = command("explore").frame
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
        assertExploreFrame(exploreFrame)

        events.tap()
        XCTAssertTrue(eventsHandle.waitForNonExistence(timeout: 3))
        XCTAssertFalse(eventList.isHittable)
        XCTAssertFalse(events.isSelected)
        XCTAssertEqual(mapViewport.frame, fullMapFrame)
        XCTAssertEqual(app.maps.firstMatch.frame.size, nativeMapSize)
        assertEventsFrame(buttonFrame)
        assertExploreFrame(exploreFrame)
        attachScreenshot("Bouton événements à droite de la barre native")
    }

    func testEventsButtonReturnsFromPanelsAndOpensAfterFriendSheetCloses() {
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
            XCTAssertTrue(eventsHandle.waitForNonExistence(timeout: 3))
            XCTAssertFalse(eventList.isHittable)
            XCTAssertFalse(events.isSelected)

            profileButton.coordinate(withNormalizedOffset: CGVector(dx: edge, dy: 0.5)).tap()
            XCTAssertTrue(ownSheet.waitForExistence(timeout: 3))
            closeOwnSheet()
        }
    }

    func testFriendRequestNotificationShowsReceivedRequests() {
        app.terminate()
        app.launchArguments += ["-debug-social-map-friend-request-notification"]
        app.launch()
        XCTAssertTrue(ownSheet.waitForExistence(timeout: 10))
        let accept = ownSheet.buttons["Accepter"]
        let visible = NSPredicate { _, _ in accept.exists && accept.isHittable }
        expectation(for: visible, evaluatedWith: accept)
        waitForExpectations(timeout: 5)
        XCTAssertFalse(app.buttons["map-friends-resize-handle"].exists)
        attachScreenshot("Notification vers les demandes du profil")
    }

    func testFriendRequestNotificationWaitsForDelayedRequestData() {
        app.terminate()
        app.launchArguments += ["-debug-social-map-friend-request-notification",
                                "-debug-social-map-delayed-friend-request"]
        app.launch()
        XCTAssertTrue(ownSheet.waitForExistence(timeout: 10))
        let accept = ownSheet.buttons["Accepter"]
        let visible = NSPredicate { _, _ in accept.exists && accept.isHittable }
        expectation(for: visible, evaluatedWith: accept)
        waitForExpectations(timeout: 8)
        ownSheet.buttons["Refuser"].tap()
        XCTAssertFalse(accept.exists)
    }

    func testFriendsLiveInProfileWithoutSplittingMap() {
        let originalMap = app.maps.firstMatch.frame
        let originalViewport = mapViewport.frame
        profileButton.tap()
        XCTAssertTrue(ownSheet.waitForExistence(timeout: 3))
        XCTAssertTrue(ownSheet.staticTexts["Moi"].exists)
        revealInOwnSheet(ownSheet.buttons["Accepter"])
        XCTAssertTrue(ownSheet.staticTexts["Demandes reçues"].exists)
        XCTAssertTrue(ownSheet.staticTexts["Mes amis"].exists)
        XCTAssertEqual(app.maps.firstMatch.frame, originalMap)
        XCTAssertEqual(mapViewport.frame, originalViewport)
        XCTAssertFalse(app.buttons["map-friends-resize-handle"].exists)
        XCTAssertFalse(command("friends").exists)
        attachScreenshot("Demandes et amis dans le profil")
        closeOwnSheet()
        XCTAssertEqual(mapViewport.frame, originalViewport)
        XCTAssertTrue(command("events").isHittable)
    }

    func testEmptyFriendsStateLivesInProfile() {
        app.terminate()
        app.launchArguments += ["-debug-social-map-friends-empty"]
        app.launch()
        profileButton.tap()
        XCTAssertTrue(ownSheet.waitForExistence(timeout: 3))
        revealInOwnSheet(ownSheet.staticTexts["Aucun ami pour le moment."])
        XCTAssertFalse(ownSheet.buttons["Accepter"].exists)
        revealInOwnSheet(ownSheet.buttons["Partager mon code"])
        revealInOwnSheet(ownSheet.textFields["Code ami"])
    }

    func testAcceptedRequestPersistsAfterClosingProfile() {
        profileButton.tap()
        XCTAssertTrue(ownSheet.waitForExistence(timeout: 3))
        revealInOwnSheet(ownSheet.buttons["Accepter"])
        ownSheet.buttons["Accepter"].tap()
        XCTAssertFalse(ownSheet.buttons["Accepter"].exists)
        XCTAssertTrue(ownSheet.staticTexts["Camille"].exists)
        closeOwnSheet()
        command("events").tap()
        XCTAssertTrue(eventList.waitForExistence(timeout: 3))
        let listFrame = eventList.frame
        profileButton.tap()
        XCTAssertTrue(ownSheet.waitForExistence(timeout: 3))
        revealInOwnSheet(ownSheet.staticTexts["Camille"])
        XCTAssertFalse(ownSheet.buttons["Accepter"].exists)
        closeOwnSheet()
        XCTAssertTrue(eventList.isHittable)
        XCTAssertEqual(eventList.frame, listFrame)
    }

    func testLongFriendsListAndInvitationsShareProfileScroll() {
        profileButton.tap()
        XCTAssertTrue(ownSheet.waitForExistence(timeout: 3))
        let lastFriend = ownSheet.staticTexts["Ami 30"]
        revealInOwnSheet(lastFriend)
        XCTAssertTrue(lastFriend.isHittable)
        revealInOwnSheet(ownSheet.staticTexts["Alex, Demande envoyée"])
        XCTAssertTrue(ownSheet.staticTexts["En attente"].exists)
        revealInOwnSheet(ownSheet.buttons["Ajouter un ami"])
        XCTAssertTrue(ownSheet.textFields["Code ami"].isHittable)
        attachScreenshot("Bas du profil avec demandes envoyées et ajout d’ami")
    }

    func testBottomOfEventsListClearsNativeDock() {
        app.terminate()
        app.launchArguments += ["-debug-social-map-many-events"]
        app.launch()
        command("events").tap()
        XCTAssertTrue(eventList.waitForExistence(timeout: 3))
        XCTAssertTrue(eventList.isHittable)
        let title = eventList.staticTexts["Événements"]
        XCTAssertTrue(title.isHittable)
        XCTAssertEqual(eventList.staticTexts.matching(identifier: "Événements").count, 1)
        XCTAssertFalse(app.staticTexts["events-panel-title"].exists)
        XCTAssertTrue(command("events").isSelected)
        XCTAssertTrue(command("explore").isSelected)
        XCTAssertFalse(command("friends").exists)
        XCTAssertFalse(ownSheet.exists)
        XCTAssertTrue(eventsHandle.isHittable)
        XCTAssertEqual(eventList.frame.maxY, app.windows.firstMatch.frame.maxY, accuracy: 2)
        attachScreenshot("Les événements défilent derrière le dock")

        let lastEvent = app.descendants(matching: .any)["event-card-00000000-0000-4000-8000-000000000018"].firstMatch
        let tabBar = app.tabBars["native-map-tab-bar"]
        for _ in 0..<25 {
            if lastEvent.exists && lastEvent.isHittable && lastEvent.frame.maxY <= tabBar.frame.minY { break }
            swipeListAboveDock(eventList, tabBar: tabBar)
            XCTAssertTrue(command("events").isSelected)
        }

        XCTAssertTrue(lastEvent.isHittable)
        XCTAssertLessThanOrEqual(lastEvent.frame.maxY, tabBar.frame.minY)
        attachScreenshot("Dernier événement au-dessus du dock")
    }

    func testFriendProfileOpensFromOwnProfileAndRequestsStayDeclined() {
        app.terminate()
        app.launchArguments += ["-debug-social-map-mixed"]
        app.launch()
        profileButton.tap()
        XCTAssertTrue(ownSheet.waitForExistence(timeout: 3))
        revealInOwnSheet(ownSheet.buttons["Refuser"])
        ownSheet.buttons["Refuser"].tap()
        revealInOwnSheet(ownSheet.buttons["Amina"])
        ownSheet.buttons["Amina"].tap()
        let sheet = app.scrollViews["friend-profile-scroll"].firstMatch
        XCTAssertTrue(sheet.waitForExistence(timeout: 3))
        XCTAssertTrue(sheet.staticTexts["Amina"].exists)
        XCTAssertFalse(ownSheet.exists)
        let start = sheet.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.05))
        let bottom = app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.98))
        start.press(forDuration: 0.05, thenDragTo: bottom)
        XCTAssertTrue(sheet.waitForNonExistence(timeout: 3))
        profileButton.tap()
        XCTAssertTrue(ownSheet.waitForExistence(timeout: 3))
        revealInOwnSheet(ownSheet.buttons["Amina"])
        XCTAssertFalse(ownSheet.buttons["Refuser"].exists)
        attachScreenshot("Liste des amis dans le profil personnel")
    }

    func testFriendRemovalRequiresConfirmationInProfile() {
        app.terminate()
        app.launchArguments += ["-debug-social-map-mixed"]
        app.launch()
        profileButton.tap()
        XCTAssertTrue(ownSheet.waitForExistence(timeout: 3))
        let friend = ownSheet.buttons["Amina"]
        revealInOwnSheet(friend)
        friend.swipeLeft()
        ownSheet.buttons["Retirer"].tap()
        let alert = app.alerts["Retirer cet ami ?"]
        XCTAssertTrue(alert.waitForExistence(timeout: 3))
        alert.buttons["Annuler"].tap()
        XCTAssertTrue(friend.exists)
        friend.swipeLeft()
        ownSheet.buttons["Retirer"].tap()
        XCTAssertTrue(alert.waitForExistence(timeout: 3))
        alert.buttons["Retirer"].tap()
        XCTAssertTrue(friend.waitForNonExistence(timeout: 3))
        XCTAssertTrue(ownSheet.exists)
    }

    func testFriendInvitationsLiveInProfileAndDraftSurvivesClosing() {
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
        revealInOwnSheet(add)
        XCTAssertTrue(add.isEnabled)
        closeOwnSheet()
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 3))

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

    func testSettingsRemainAvailableAlongsideFriends() {
        profileButton.tap()
        XCTAssertTrue(ownSheet.waitForExistence(timeout: 3))
        app.buttons["own-profile-settings"].tap()
        XCTAssertTrue(app.navigationBars["Réglages"].waitForExistence(timeout: 3))
        let heatMap = app.switches["profile-heat-map"]
        XCTAssertTrue(heatMap.waitForExistence(timeout: 3))
        heatMap.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        XCTAssertEqual(heatMap.value as? String, "1")
        app.navigationBars["Réglages"].buttons["Fermer"].tap()
        XCTAssertTrue(ownSheet.exists)
        revealInOwnSheet(ownSheet.buttons["Accepter"])
        closeOwnSheet()
        profileButton.tap()
        XCTAssertTrue(ownSheet.waitForExistence(timeout: 3))
        app.buttons["own-profile-settings"].tap()
        XCTAssertEqual(heatMap.value as? String, "1")
    }

    func testCommandsRemainReachableAfterClosingProfile() {
        profileButton.tap()
        XCTAssertTrue(ownSheet.waitForExistence(timeout: 3))
        revealInOwnSheet(ownSheet.buttons["Accepter"])
        closeOwnSheet()
        XCTAssertFalse(command("friends").exists)
        for name in ["explore", "events"] {
            let button = command(name)
            XCTAssertTrue(button.isHittable)
            XCTAssertLessThanOrEqual(button.frame.maxX, app.windows.firstMatch.frame.maxX)
            XCTAssertLessThanOrEqual(button.frame.maxY, app.windows.firstMatch.frame.maxY)
        }
        XCTAssertEqual(command("events").frame.midY, command("explore").frame.midY, accuracy: 2)
        attachScreenshot("Navigation après fermeture du profil")
    }

    private var profileButton: XCUIElement { app.buttons["map-own-profile"] }

    private var ownSheet: XCUIElement {
        app.descendants(matching: .any)["own-profile-scroll"].firstMatch
    }

    private func revealInOwnSheet(_ element: XCUIElement) {
        for _ in 0..<20 {
            if element.exists && element.isHittable { return }
            ownSheet.swipeUp()
        }
        XCTAssertTrue(element.isHittable)
    }

    private func closeOwnSheet() {
        for _ in 0..<20 {
            if !ownSheet.exists { return }
            if ownSheet.staticTexts["Exploration"].exists && ownSheet.staticTexts["Exploration"].isHittable { break }
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

    private func assertExploreFrame(_ expected: CGRect) {
        XCTAssertEqual(command("explore").frame.midX, expected.midX, accuracy: 1)
        XCTAssertEqual(command("explore").frame.midY, expected.midY, accuracy: 1)
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
