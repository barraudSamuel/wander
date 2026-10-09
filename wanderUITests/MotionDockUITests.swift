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
        XCTAssertTrue(command("events").waitForExistence(timeout: 10))
    }

    func testEventsButtonReplacesNavigationBar() {
        XCTAssertFalse(app.tabBars.firstMatch.exists)
        XCTAssertFalse(command("explore").exists)
        XCTAssertTrue(command("events").isHittable)
        XCTAssertFalse(command("friends").exists)
        XCTAssertFalse(command("profile").exists)
        XCTAssertFalse(app.buttons["map-friends-resize-handle"].exists)
        command("events").tap()
        XCTAssertTrue(eventList.waitForExistence(timeout: 3))
        command("events").tap()
        XCTAssertTrue(eventsHandle.waitForNonExistence(timeout: 3))
        attachScreenshot("Bouton événements seul en bas de la carte")
    }

    func testEventsButtonStaysCenteredAcrossRepeatedListToggles() {
        let events = command("events")
        XCTAssertTrue(events.waitForExistence(timeout: 3))
        assertEventsCenteredAtBottom()
        XCTAssertFalse(events.isSelected)
        XCTAssertFalse(eventList.isHittable)
        let nativeMapSize = app.descendants(matching: .any).matching(identifier: "exploration-map-canvas").firstMatch.frame.size
        let fullMapFrame = mapViewport.frame
        let buttonFrame = events.frame

        for iteration in 0..<4 {
            events.tap()
            XCTAssertTrue(eventList.waitForExistence(timeout: 3))
            XCTAssertTrue(eventList.isHittable)
            XCTAssertTrue(events.isSelected)
            // The 44 pt hit target overlaps the 20 pt separator by 12 pt.
            XCTAssertEqual(mapViewport.frame.maxY, eventsHandle.frame.minY + 12, accuracy: 2)
            XCTAssertLessThan(mapViewport.frame.height, fullMapFrame.height)
            XCTAssertEqual(eventList.frame.maxY, app.windows.firstMatch.frame.maxY, accuracy: 2)
            XCTAssertEqual(app.descendants(matching: .any).matching(identifier: "exploration-map-canvas").firstMatch.frame.size, nativeMapSize)
            assertEventsFrame(buttonFrame)

            if iteration == 0 {
                attachScreenshot("Croix de fermeture des événements ouverts")
            }

            events.tap()
            XCTAssertTrue(eventsHandle.waitForNonExistence(timeout: 3))
            XCTAssertFalse(eventList.isHittable)
            XCTAssertFalse(events.isSelected)
            XCTAssertEqual(mapViewport.frame, fullMapFrame)
            XCTAssertEqual(app.descendants(matching: .any).matching(identifier: "exploration-map-canvas").firstMatch.frame.size, nativeMapSize)
            assertEventsFrame(buttonFrame)
        }
        attachScreenshot("Bouton événements centré après ouvertures et fermetures")
    }

    func testEventsButtonReturnsFromPanelsAndOpensAfterFriendSheetCloses() {
        app.terminate()
        app.launchArguments += ["-debug-social-map-mixed", "-debug-social-map-open-friend"]
        app.launch()
        let friendPane = app.scrollViews["friend-profile-scroll"].firstMatch
        XCTAssertTrue(friendPane.waitForExistence(timeout: 10))
        XCTAssertTrue(friendPane.staticTexts["Amina"].exists)
        XCTAssertFalse(command("events").isSelected)
        let nativeMapSize = app.descendants(matching: .any).matching(identifier: "exploration-map-canvas").firstMatch.frame.size
        let start = friendPane.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.1))
        let bottom = app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.98))
        start.press(forDuration: 0.05, thenDragTo: bottom)
        XCTAssertTrue(friendPane.waitForNonExistence(timeout: 3))
        command("events").tap()
        XCTAssertTrue(eventList.waitForExistence(timeout: 3))
        XCTAssertTrue(eventList.isHittable)
        XCTAssertTrue(command("events").isSelected)
        assertEventsCenteredAtBottom()
        XCTAssertFalse(app.buttons["map-detail-resize-handle"].exists)
        XCTAssertEqual(app.descendants(matching: .any).matching(identifier: "exploration-map-canvas").firstMatch.frame.size, nativeMapSize)
    }

    func testImageButtonEdgesOpenTheirSheets() {
        let events = command("events")
        XCTAssertEqual(events.frame.width, 56, accuracy: 1)
        XCTAssertEqual(events.frame.height, 56, accuracy: 1)
        XCTAssertEqual(profileButton.frame.width, 44, accuracy: 1)
        XCTAssertEqual(profileButton.frame.height, 44, accuracy: 1)

        // Touch near either edge of each image, which fills its control.
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
        let originalMap = app.descendants(matching: .any).matching(identifier: "exploration-map-canvas").firstMatch.frame
        let originalViewport = mapViewport.frame
        profileButton.tap()
        XCTAssertTrue(ownSheet.waitForExistence(timeout: 3))
        XCTAssertTrue(ownSheet.staticTexts["Moi"].exists)
        revealInOwnSheet(ownSheet.buttons["Accepter"])
        XCTAssertTrue(ownSheet.staticTexts["Demandes reçues"].exists)
        XCTAssertTrue(ownSheet.staticTexts["Mes amis"].exists)
        XCTAssertEqual(app.descendants(matching: .any).matching(identifier: "exploration-map-canvas").firstMatch.frame, originalMap)
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

    func testBottomOfEventsListClearsEventsButton() {
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
        XCTAssertFalse(command("explore").exists)
        XCTAssertFalse(command("friends").exists)
        XCTAssertFalse(ownSheet.exists)
        XCTAssertTrue(eventsHandle.isHittable)
        XCTAssertEqual(eventList.frame.maxY, app.windows.firstMatch.frame.maxY, accuracy: 2)
        attachScreenshot("Les événements défilent derrière le bouton")

        let lastEvent = app.descendants(matching: .any)["event-card-00000000-0000-4000-8000-000000000018"].firstMatch
        let events = command("events")
        for _ in 0..<25 {
            if lastEvent.exists && lastEvent.isHittable && lastEvent.frame.maxY <= events.frame.minY { break }
            swipeListAboveEventsButton(eventList)
            XCTAssertTrue(events.isSelected)
        }

        XCTAssertTrue(lastEvent.isHittable)
        XCTAssertLessThanOrEqual(lastEvent.frame.maxY, events.frame.minY)
        attachScreenshot("Dernier événement au-dessus du bouton")
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
        let eventsFrame = command("events").frame
        let originalMap = app.descendants(matching: .any).matching(identifier: "exploration-map-canvas").firstMatch.frame
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
        assertEventsCenteredAtBottom()
        assertEventsFrame(eventsFrame)
        XCTAssertEqual(app.descendants(matching: .any).matching(identifier: "exploration-map-canvas").firstMatch.frame, originalMap)
        command("events").tap()
        XCTAssertTrue(eventsHandle.waitForExistence(timeout: 3))
        command("events").tap()
        XCTAssertTrue(eventsHandle.waitForNonExistence(timeout: 3))

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
        XCTAssertFalse(app.switches["profile-heat-map"].exists)
        let ghostMode = app.switches["Mode fantôme"]
        XCTAssertTrue(ghostMode.waitForExistence(timeout: 3))
        ghostMode.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        XCTAssertEqual(ghostMode.value as? String, "1")
        app.navigationBars["Réglages"].buttons["Fermer"].tap()
        XCTAssertTrue(ownSheet.exists)
        revealInOwnSheet(ownSheet.buttons["Accepter"])
        closeOwnSheet()
        profileButton.tap()
        XCTAssertTrue(ownSheet.waitForExistence(timeout: 3))
        app.buttons["own-profile-settings"].tap()
        XCTAssertEqual(ghostMode.value as? String, "1")
    }

    func testEventsButtonRemainsCenteredAndReachableAfterClosingProfile() {
        let eventsFrame = command("events").frame
        profileButton.tap()
        XCTAssertTrue(ownSheet.waitForExistence(timeout: 3))
        revealInOwnSheet(ownSheet.buttons["Accepter"])
        closeOwnSheet()
        XCTAssertFalse(command("friends").exists)
        XCTAssertFalse(command("explore").exists)
        XCTAssertFalse(app.tabBars.firstMatch.exists)
        assertEventsCenteredAtBottom()
        assertEventsFrame(eventsFrame)
        attachScreenshot("Bouton événements après fermeture du profil")
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


    private func swipeListAboveEventsButton(_ list: XCUIElement) {
        let startY = min(list.frame.maxY - 30, command("events").frame.minY - 40)
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

    private func assertEventsCenteredAtBottom(file: StaticString = #filePath, line: UInt = #line) {
        let events = command("events")
        let window = app.windows.firstMatch.frame
        XCTAssertTrue(events.isHittable, file: file, line: line)
        XCTAssertEqual(events.frame.width, 56, accuracy: 1, file: file, line: line)
        XCTAssertEqual(events.frame.height, 56, accuracy: 1, file: file, line: line)
        XCTAssertEqual(events.frame.midX, window.midX, accuracy: 1, file: file, line: line)
        XCTAssertGreaterThanOrEqual(events.frame.minY, window.maxY - 120, file: file, line: line)
        XCTAssertLessThanOrEqual(events.frame.maxY, window.maxY - 8, file: file, line: line)
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
