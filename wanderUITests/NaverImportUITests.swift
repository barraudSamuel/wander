import XCTest
import UIKit

@MainActor
final class NaverImportUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-debug-social-map", "-debug-social-map-fullscreen", "-debug-social-map-naver"]
        app.launch()
        openImport()
    }

    func testSingleFieldPreviewSaveAndReimportWithoutDuplicates() {
        XCTAssertEqual(app.textFields.count, 1)
        XCTAssertFalse(submit.isEnabled)
        XCTAssertTrue(app.buttons["naver-import-paste"].exists)
        XCTAssertEqual(app.buttons["naver-import-paste"].label, "Coller")
        screenshot("Import Naver à un champ")
        loadPreview()
        XCTAssertTrue(app.staticTexts["1 adresse à importer"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Lieu signalé indisponible par Naver"].exists)
        XCTAssertTrue(app.staticTexts["Position à vérifier sur Naver"].exists)
        screenshot("Aperçu Naver avec icône café")
        submit.tap()
        XCTAssertTrue(app.staticTexts["Import terminé"].waitForExistence(timeout: 5))
        submit.tap()

        let pin = app.buttons["saved-place-test-cafe"]
        XCTAssertTrue(pin.waitForExistence(timeout: 5))
        for _ in 0..<2 {
            pin.tap()
            XCTAssertTrue(app.staticTexts["Adresse de démonstration"].waitForExistence(timeout: 3))
            XCTAssertTrue(app.links["Ouvrir dans Naver"].exists || app.buttons["Ouvrir dans Naver"].exists)
            app.buttons["Fermer"].tap()
            XCTAssertTrue(app.staticTexts["Adresse de démonstration"].waitForNonExistence(timeout: 3))
        }

        openImport()
        loadPreview()
        XCTAssertTrue(app.staticTexts["1 adresse à importer"].waitForExistence(timeout: 5))
        submit.tap()
        XCTAssertTrue(app.staticTexts["Tes adresses étaient déjà importées. Elles ont été mises à jour."].waitForExistence(timeout: 5))
    }

    func testFailureAndClosingWhileLoadingDoNotImport() {
        let field = app.textFields["naver-import-link"]
        field.tap()
        field.typeText("https://naver.me/invalid")
        submit.tap()
        XCTAssertTrue(app.staticTexts["naver-import-error"].waitForExistence(timeout: 5))
        XCTAssertTrue(submit.isEnabled)
        app.buttons["naver-import-close"].tap()
        openImport()
        field.tap()
        field.typeText("https://naver.me/demo")
        submit.tap()
        app.buttons["naver-import-close"].tap()
        XCTAssertTrue(field.waitForNonExistence(timeout: 3))
        XCTAssertFalse(app.buttons["saved-place-test-cafe"].exists)
    }

    func testMapLabelsAppearOnZoomAndDisappearOnZoomOut() {
        loadPreview()
        XCTAssertTrue(app.staticTexts["1 adresse à importer"].waitForExistence(timeout: 5))
        submit.tap()
        XCTAssertTrue(app.staticTexts["Import terminé"].waitForExistence(timeout: 5))
        submit.tap()
        let pin = app.buttons["saved-place-test-cafe"]
        let map = app.otherElements["map-visible-viewport"].firstMatch
        XCTAssertTrue(pin.waitForExistence(timeout: 5))
        let expanded = NSPredicate { _, _ in pin.exists && pin.frame.width > 44 }
        expectation(for: expanded, evaluatedWith: app)
        waitForExpectations(timeout: 5)
        screenshot("Nom et type visibles dès l’import")

        // Start below the label threshold using the native edge zoom.
        let edgeStart = map.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: 12, dy: map.frame.height * 0.3))
        let edgeEnd = edgeStart.withOffset(CGVector(dx: 0, dy: 180))
        edgeStart.press(forDuration: 0.05, thenDragTo: edgeEnd, withVelocity: .slow, thenHoldForDuration: 0.2)
        let compact = NSPredicate { _, _ in pin.exists && abs(pin.frame.width - 44) < 1 }
        expectation(for: compact, evaluatedWith: app)
        waitForExpectations(timeout: 5)
        screenshot("Adresse compacte après dézoom")

        // Pan the saved coordinate toward the center before zooming, so it stays visible.
        let start = map.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: pin.frame.minX + 22 - map.frame.minX,
                                 dy: pin.frame.midY - map.frame.minY))
        let center = map.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.05, thenDragTo: center, withVelocity: .slow, thenHoldForDuration: 0.2)
        map.pinch(withScale: 3, velocity: 1)
        expectation(for: expanded, evaluatedWith: app)
        waitForExpectations(timeout: 5)
        XCTAssertEqual(pin.value as? String, "Café")
        screenshot("Nom et type visibles après zoom")

        pin.tap()
        XCTAssertTrue(app.staticTexts["Adresse de démonstration"].waitForExistence(timeout: 3))
    }

    func testDenseAddressesHideOverlapsAndOpenDetails() {
        let field = app.textFields["naver-import-link"]
        field.tap()
        field.typeText("https://naver.me/dense")
        submit.tap()
        XCTAssertTrue(app.staticTexts["36 adresses à importer"].waitForExistence(timeout: 5))
        submit.tap()
        XCTAssertTrue(app.staticTexts["Import terminé"].waitForExistence(timeout: 5))
        submit.tap()
        let pins = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "saved-place-dense-"))
        let map = app.otherElements["map-visible-viewport"].firstMatch
        XCTAssertTrue(pins.firstMatch.waitForExistence(timeout: 5))
        let initialPin = pins.allElementsBoundByIndex.first { $0.isHittable }
        XCTAssertNotNil(initialPin)
        if let initialPin {
            let panStart = map.coordinate(withNormalizedOffset: CGVector(dx: 0.25, dy: 0.5))
            let panEnd = panStart.withOffset(CGVector(dx: map.frame.midX - initialPin.frame.minX - 22,
                                                     dy: map.frame.midY - initialPin.frame.midY))
            panStart.press(forDuration: 0.05, thenDragTo: panEnd, withVelocity: .slow, thenHoldForDuration: 0.2)
        }
        // Give several names room beyond the nearby social markers before testing zoom out.
        map.pinch(withScale: 1.5, velocity: 0.5)
        let separated = NSPredicate { _, _ in
            let frames = pins.allElementsBoundByIndex.map(\.frame)
            let icons = frames.map { CGRect(x: $0.minX + 4, y: $0.minY + 4, width: 36, height: 36) }
            var labels: [CGRect] = []
            return frames.count >= 4 && frames.count < 36 && frames.enumerated().allSatisfy { index, frame in
                guard icons.dropFirst(index + 1).allSatisfy({ !icons[index].intersects($0) }) else { return false }
                guard frame.width > 44 else { return true }
                let text = CGRect(x: frame.minX + 44, y: frame.minY + 6, width: frame.width - 48, height: 32)
                guard icons.enumerated().filter({ $0.offset != index }).allSatisfy({ !$0.element.intersects(text) }),
                      labels.allSatisfy({ !$0.intersects(text) }) else { return false }
                labels.append(text)
                return true
            }
        }
        expectation(for: separated, evaluatedWith: app)
        waitForExpectations(timeout: 5)
        XCTAssertGreaterThanOrEqual(pins.allElementsBoundByIndex.filter { $0.frame.width > 44 }.count, 2)
        XCTAssertTrue(pins.allElementsBoundByIndex.contains { abs($0.frame.width - 44) < 1 })
        screenshot("Plusieurs icônes conservées et noms sans chevauchement")

        let edgeStart = map.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: 12, dy: map.frame.height * 0.2))
        let edgeEnd = edgeStart.withOffset(CGVector(dx: 0, dy: 40))
        edgeStart.press(forDuration: 0.05, thenDragTo: edgeEnd, withVelocity: .slow, thenHoldForDuration: 0.2)
        expectation(for: separated, evaluatedWith: app)
        waitForExpectations(timeout: 5)
        XCTAssertFalse(app.buttons["creation-menu-naver"].exists)
        screenshot("Icônes conservées après dézoom doux")

        let visiblePin = pins.allElementsBoundByIndex.first { $0.isHittable }
        XCTAssertNotNil(visiblePin)
        visiblePin?.tap()
        XCTAssertTrue(app.staticTexts["Adresse de démonstration"].waitForExistence(timeout: 3))
        app.buttons["Fermer"].tap()
        XCTAssertTrue(app.staticTexts["Adresse de démonstration"].waitForNonExistence(timeout: 3))
    }

    func testPasteSharedTextIntoSingleField() {
        UIPasteboard.general.string = "[NAVER Maps]\nCafés\nhttps://naver.me/demo"
        app.buttons["naver-import-paste"].tap()
        XCTAssertTrue(submit.isEnabled)
        XCTAssertEqual(app.textFields.count, 1)
        submit.tap()
        XCTAssertTrue(app.staticTexts["1 adresse à importer"].waitForExistence(timeout: 5))
    }

    private var submit: XCUIElement { app.buttons["naver-import-submit"] }

    private func openImport() {
        let create = app.buttons["map-create"]
        XCTAssertTrue(create.waitForExistence(timeout: 10))
        create.tap()
        let importButton = app.buttons["creation-menu-naver"]
        XCTAssertTrue(importButton.waitForExistence(timeout: 3))
        importButton.tap()
        XCTAssertTrue(app.textFields["naver-import-link"].waitForExistence(timeout: 3))
    }

    private func loadPreview() {
        let field = app.textFields["naver-import-link"]
        field.tap()
        field.typeText("https://naver.me/demo")
        submit.tap()
    }

    private func screenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
