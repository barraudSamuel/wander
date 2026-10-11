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

    func testAllDenseAddressesAppearImmediately() {
        let field = app.textFields["naver-import-link"]
        field.tap()
        field.typeText("https://naver.me/dense")
        submit.tap()
        XCTAssertTrue(app.staticTexts["36 adresses à importer"].waitForExistence(timeout: 5))
        submit.tap()
        XCTAssertTrue(app.staticTexts["Import terminé"].waitForExistence(timeout: 5))
        submit.tap()
        let pins = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "saved-place-dense-"))
        expectation(for: NSPredicate { _, _ in pins.count == 36 }, evaluatedWith: app)
        waitForExpectations(timeout: 5)
        XCTAssertTrue(pins.allElementsBoundByIndex.allSatisfy { $0.frame.width > 44 })
        screenshot("Toutes les adresses visibles dès l’import")
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
