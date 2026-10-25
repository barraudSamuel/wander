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
            openSavedPlaceSheet(pin)
            XCTAssertTrue(app.staticTexts["Adresse de démonstration"].waitForExistence(timeout: 3))
            revealSheetControl(app.links["saved-place-open-naver"])
            screenshot("Fiche native avec lien Naver")
            closeSavedPlaceSheet()
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

    func testCreateEventFromSavedAddressPrefillsPlaceAndCategory() {
        loadPreview()
        XCTAssertTrue(app.staticTexts["1 adresse à importer"].waitForExistence(timeout: 5))
        submit.tap()
        XCTAssertTrue(app.staticTexts["Import terminé"].waitForExistence(timeout: 5))
        submit.tap()

        let pin = app.buttons["saved-place-test-cafe"]
        XCTAssertTrue(pin.waitForExistence(timeout: 5))
        for attempt in 0..<2 {
            openSavedPlaceSheet(pin)
            let create = app.buttons["saved-place-create-event"]
            revealSheetControl(create)
            create.tap()
            XCTAssertTrue(app.navigationBars["Nouvel événement"].waitForExistence(timeout: 5))
            XCTAssertFalse(savedPlaceNavigation.exists, "The sheet closes before the composer opens")
            let placeText = composerPlaceText
            XCTAssertTrue(placeText.contains("Café de test"))
            XCTAssertTrue(placeText.contains("Adresse de démonstration"))
            XCTAssertTrue(placeText.contains("37.56650, 126.97400"))
            XCTAssertTrue(app.buttons["outing-category"].staticTexts["Café"].exists)
            XCTAssertTrue(app.buttons["Publier"].isEnabled)
            screenshot("Événement prérempli depuis une adresse")
            if attempt == 0 {
                app.buttons["Fermer"].tap()
                XCTAssertTrue(app.navigationBars["Nouvel événement"].waitForNonExistence(timeout: 3))
            } else {
                app.buttons["outing-category"].tap()
                app.buttons["Repas"].tap()
                XCTAssertTrue(app.buttons["outing-category"].staticTexts["Repas"].exists)
                app.buttons["Publier"].tap()
            }
        }
        XCTAssertTrue(app.navigationBars["Nouvel événement"].waitForNonExistence(timeout: 5))
        app.buttons["motion-dock-events"].tap()
        let publishedCard = app.descendants(matching: .any).matching(NSPredicate(
            format: "identifier BEGINSWITH %@ AND label CONTAINS %@", "event-card-", "Lieu : Café de test."
        )).firstMatch
        XCTAssertTrue(publishedCard.waitForExistence(timeout: 5))
        XCTAssertTrue(publishedCard.label.contains("un repas"))
        XCTAssertTrue(publishedCard.staticTexts["Adresse de démonstration"].exists)
    }

    func testUnknownCategoryRequiresChoiceAndLongPlaceCanPublish() {
        loadPreview("https://naver.me/long-place")
        XCTAssertTrue(app.staticTexts["1 adresse à importer"].waitForExistence(timeout: 5))
        submit.tap()
        XCTAssertTrue(app.staticTexts["Import terminé"].waitForExistence(timeout: 5))
        submit.tap()
        let pin = app.buttons["saved-place-test-cafe"]
        XCTAssertTrue(pin.waitForExistence(timeout: 5))
        openSavedPlaceSheet(pin)
        let create = app.buttons["saved-place-create-event"]
        revealSheetControl(create)
        create.tap()
        XCTAssertTrue(app.navigationBars["Nouvel événement"].waitForExistence(timeout: 5))
        app.swipeUp()
        let placeText = composerPlaceText
        XCTAssertTrue(placeText.contains(String(repeating: "N", count: 120)))
        XCTAssertFalse(placeText.contains(String(repeating: "N", count: 121)))
        XCTAssertTrue(placeText.contains(String(repeating: "A", count: 200)))
        XCTAssertFalse(placeText.contains(String(repeating: "A", count: 201)))
        XCTAssertFalse(app.buttons["Publier"].isEnabled)
        let category = app.buttons["outing-category"]
        if !category.isHittable { app.swipeUp() }
        category.tap()
        app.buttons["Café"].tap()
        XCTAssertTrue(app.buttons["Publier"].isEnabled)
        app.buttons["Publier"].tap()
        XCTAssertTrue(app.navigationBars["Nouvel événement"].waitForNonExistence(timeout: 5))
    }

    private var composerPlaceText: String {
        let place = app.descendants(matching: .any).matching(identifier: "outing-place")
        XCTAssertGreaterThan(place.count, 0)
        return place.allElementsBoundByIndex.map {
            $0.label + ($0.value as? String ?? "")
        }.joined(separator: " ")
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
        centerPhotoPin(pin, on: map)
        let expanded = NSPredicate { _, _ in self.hasPresentation("Détaillé", pin: pin) }
        expectation(for: expanded, evaluatedWith: app)
        waitForExpectations(timeout: 5)
        screenshot("Nom et type visibles dès l’import")

        // Start below the label threshold using the native edge zoom.
        let edgeStart = map.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: 12, dy: map.frame.height * 0.3))
        let edgeEnd = edgeStart.withOffset(CGVector(dx: 0, dy: 420))
        edgeStart.press(forDuration: 0.05, thenDragTo: edgeEnd, withVelocity: .slow, thenHoldForDuration: 0.2)
        let compact = NSPredicate { _, _ in self.hasPresentation("Compact", pin: pin) }
        expectation(for: compact, evaluatedWith: app)
        waitForExpectations(timeout: 5)
        screenshot("Adresse compacte après dézoom")

        let zoomIn = map.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: 12, dy: map.frame.height * 0.78))
        zoomIn.press(forDuration: 0.05, thenDragTo: zoomIn.withOffset(CGVector(dx: 0, dy: -420)),
                     withVelocity: .slow, thenHoldForDuration: 0.2)
        centerPhotoPin(pin, on: map)
        expectation(for: expanded, evaluatedWith: app)
        waitForExpectations(timeout: 5)
        XCTAssertTrue((pin.value as? String)?.contains("Café") == true)
        screenshot("Nom et type visibles après zoom")

        openSavedPlaceSheet(pin)
        XCTAssertTrue(app.staticTexts["Adresse de démonstration"].waitForExistence(timeout: 3))
    }

    func testNativeSheetOpensAndClosesFromBothPinSizes() {
        loadPreview()
        XCTAssertTrue(app.staticTexts["1 adresse à importer"].waitForExistence(timeout: 5))
        submit.tap()
        XCTAssertTrue(app.staticTexts["Import terminé"].waitForExistence(timeout: 5))
        submit.tap()
        let pin = app.buttons["saved-place-test-cafe"]
        let map = app.otherElements["map-visible-viewport"].firstMatch
        XCTAssertTrue(pin.waitForExistence(timeout: 5))
        centerPhotoPin(pin, on: map)
        expectation(for: NSPredicate { _, _ in self.hasPresentation("Détaillé", pin: pin) }, evaluatedWith: app)
        waitForExpectations(timeout: 5)
        screenshot("Pin photo détaillé avec ombre et contour blanc")

        openSavedPlaceSheet(pin)
        XCTAssertTrue(app.staticTexts["Adresse de démonstration"].exists)
        XCTAssertTrue(app.staticTexts["Dernière liste importée"].exists)
        XCTAssertTrue(app.staticTexts["Lieu signalé indisponible par Naver"].exists)
        screenshot("Fiche native depuis le pin détaillé")
        closeSavedPlaceSheet()
        XCTAssertTrue(pin.waitForExistence(timeout: 3))
        XCTAssertFalse(pin.isSelected)

        let edge = map.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: 12, dy: map.frame.height * 0.3))
        edge.press(forDuration: 0.05, thenDragTo: edge.withOffset(CGVector(dx: 0, dy: 420)),
                   withVelocity: .slow, thenHoldForDuration: 0.2)
        expectation(for: NSPredicate { _, _ in self.hasPresentation("Compact", pin: pin) }, evaluatedWith: app)
        waitForExpectations(timeout: 5)
        screenshot("Pin photo compact")
        openSavedPlaceSheet(pin)
        screenshot("Fiche native depuis le pin compact")
        closeSavedPlaceSheet()
        XCTAssertTrue(pin.waitForExistence(timeout: 3))
        XCTAssertFalse(pin.isSelected)
        XCTAssertTrue(hasPresentation("Compact", pin: pin))
        openSavedPlaceSheet(pin)
        closeSavedPlaceSheet()
    }

    func testNativeSheetExpandsCollapsesAndDismissesByDragging() {
        loadPreview()
        XCTAssertTrue(app.staticTexts["1 adresse à importer"].waitForExistence(timeout: 5))
        submit.tap()
        XCTAssertTrue(app.staticTexts["Import terminé"].waitForExistence(timeout: 5))
        submit.tap()
        let pin = app.buttons["saved-place-test-cafe"]
        XCTAssertTrue(pin.waitForExistence(timeout: 5))
        openSavedPlaceSheet(pin)
        let navigation = savedPlaceNavigation
        let mediumY = navigation.frame.midY
        XCTAssertGreaterThan(mediumY, app.frame.height * 0.35, "The sheet starts at medium height")

        dragSheetHeader(toY: app.frame.minY + 100)
        expectation(for: NSPredicate { _, _ in
            navigation.exists && navigation.frame.midY < mediumY - 120
        }, evaluatedWith: app)
        waitForExpectations(timeout: 5)
        screenshot("Fiche native agrandie")
        let largeY = navigation.frame.midY
        dragSheetHeader(toY: mediumY)
        expectation(for: NSPredicate { _, _ in
            navigation.exists && navigation.frame.midY > largeY + 120
        }, evaluatedWith: app)
        waitForExpectations(timeout: 5)
        screenshot("Fiche native revenue à mi-hauteur")

        dragSheetHeader(toY: app.frame.maxY - 12)
        XCTAssertTrue(navigation.waitForNonExistence(timeout: 5))
        XCTAssertFalse(pin.isSelected)
        openSavedPlaceSheet(pin)
        closeSavedPlaceSheet()
    }

    func testLeftEdgeZoomStartsOnSavedAddressIconAndStillAllowsTap() {
        checkEdgeZoomStartingOnAddress(atRightEdge: false)
    }

    func testRightEdgeZoomStartsOnSavedPhotoPinAndStillAllowsTap() {
        checkEdgeZoomStartingOnAddress(atRightEdge: true)
    }

    private func checkEdgeZoomStartingOnAddress(atRightEdge: Bool) {
        loadPreview()
        XCTAssertTrue(app.staticTexts["1 adresse à importer"].waitForExistence(timeout: 5))
        submit.tap()
        XCTAssertTrue(app.staticTexts["Import terminé"].waitForExistence(timeout: 5))
        submit.tap()
        let pin = app.buttons["saved-place-test-cafe"]
        let map = app.otherElements["map-visible-viewport"].firstMatch
        XCTAssertTrue(pin.waitForExistence(timeout: 5))
        centerPhotoPin(pin, on: map)
        if atRightEdge {
            // Separate the address from nearby social hit targets before moving
            // it to the right edge, so the gesture starts on the photo itself.
            map.pinch(withScale: 2, velocity: 1)
            centerPhotoPin(pin, on: map)
        }
        let expanded = NSPredicate { _, _ in self.hasPresentation("Détaillé", pin: pin) }
        expectation(for: expanded, evaluatedWith: app)
        waitForExpectations(timeout: 5)

        func dragFromAddress(translationY: CGFloat) {
            let touchOffset = pin.frame.width / 2
            let edgeX = atRightEdge ? map.frame.maxX - 14 : map.frame.minX + 22
            // Keep the entire positioning gesture onscreen and horizontal.
            let offsetX = edgeX - pin.frame.minX - touchOffset
            if abs(offsetX) > 10 {
                let panStart = map.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(
                    dx: pin.frame.minX + 22 - map.frame.minX,
                    dy: pin.frame.midY - map.frame.minY
                ))
                let panEnd = panStart.withOffset(CGVector(dx: offsetX, dy: 0))
                panStart.press(forDuration: 0.05, thenDragTo: panEnd, withVelocity: .slow,
                               thenHoldForDuration: 0.2)
            }
            // Native panning consumes a few points before recognition; the touch must
            // land inside the 44-point edge band, not at an exact screen coordinate.
            let aligned = NSPredicate { _, _ in
                pin.exists && abs(pin.frame.minX + touchOffset - edgeX) <= 21
            }
            expectation(for: aligned, evaluatedWith: app)
            waitForExpectations(timeout: 5)
            // Nearby event hit targets can overlap the top of the compact address.
            // The left side of the small photo is exposed beside the social
            // markers in this fixture; their foreground touch target stays active.
            let point = CGPoint(x: pin.frame.minX + touchOffset - 8, y: pin.frame.midY - 12)
            XCTAssertTrue(pin.frame.contains(point))
            XCTAssertLessThanOrEqual(min(point.x - map.frame.minX, map.frame.maxX - point.x), 44)
            screenshot("Adresse sous le pouce avant glissement")
            let start = map.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(
                dx: point.x - map.frame.minX, dy: point.y - map.frame.minY
            ))
            start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: translationY)),
                        withVelocity: .slow, thenHoldForDuration: 0.2)
            XCTAssertFalse(savedPlaceNavigation.exists)
            if translationY > 0 {
                XCTAssertTrue(!pin.exists || hypot(pin.frame.midX - point.x - 8,
                                                    pin.frame.midY - point.y - 12) > 20,
                              "Zooming out moves the edge address toward the center")
            }
        }

        dragFromAddress(translationY: 180)
        screenshot("Dézoom depuis l’adresse")

        dragFromAddress(translationY: -180)
        if atRightEdge {
            screenshot("Zoom avant depuis l’adresse au bord droit")
            // Depending on the social focus target, the photo can remain partly
            // visible. Only recover the framing when it actually leaves the screen.
            if !pin.isHittable { app.buttons["map-recenter"].tap() }
        }
        XCTAssertTrue(pin.waitForExistence(timeout: 5))
        centerPhotoPin(pin, on: map)
        expectation(for: expanded, evaluatedWith: app)
        waitForExpectations(timeout: 5)
        screenshot("Zoom depuis l’adresse")
        openSavedPlaceSheet(pin)
        XCTAssertTrue(app.staticTexts["Adresse de démonstration"].exists)
    }

    func testDenseAddressesKeepPhotosAndOpenDetails() {
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
        map.pinch(withScale: 3.5, velocity: 0.5)
        let focusVisible = NSPredicate { _, _ in
            let visiblePins = pins.allElementsBoundByIndex
            return visiblePins.count >= 4
                && visiblePins.contains { self.hasPresentation("Détaillé", pin: $0) }
                && visiblePins.contains { self.hasPresentation("Compact", pin: $0) }
        }
        expectation(for: focusVisible, evaluatedWith: app)
        waitForExpectations(timeout: 5)
        screenshot("Pins photo compacts et détaillés dans une zone dense")

        let edgeStart = map.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: 12, dy: map.frame.height * 0.2))
        edgeStart.press(forDuration: 0.05, thenDragTo: edgeStart.withOffset(CGVector(dx: 0, dy: 40)),
                        withVelocity: .slow, thenHoldForDuration: 0.2)
        XCTAssertTrue(pins.firstMatch.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["creation-menu-naver"].exists)
        screenshot("Pins photo conservés après dézoom doux")

        var openedIDs: Set<String> = []
        for _ in 0..<2 {
            // The closest visible address has the highest saved-place z order.
            let central = pins.allElementsBoundByIndex.filter {
                $0.isHittable && !openedIDs.contains($0.identifier)
            }.min {
                hypot($0.frame.midX - map.frame.midX, $0.frame.midY - map.frame.midY)
                    < hypot($1.frame.midX - map.frame.midX, $1.frame.midY - map.frame.midY)
            }
            guard let central else { return XCTFail("A central address must remain available") }
            let id = central.identifier
            let name = central.label
            openSavedPlaceSheet(central)
            XCTAssertEqual(app.navigationBars.matching(identifier: "Adresse enregistrée").count, 1)
            XCTAssertTrue(app.staticTexts[name].exists, "Open the foreground photo despite nearby addresses")
            closeSavedPlaceSheet()
            XCTAssertFalse(pins.allElementsBoundByIndex.contains { $0.isSelected })
            openedIDs.insert(id)
        }
        XCTAssertEqual(openedIDs.count, 2)
    }

    func testDensePinsFollowPanAndZoomWithoutOpeningSheet() {
        loadPreview("https://naver.me/dense")
        XCTAssertTrue(app.staticTexts["36 adresses à importer"].waitForExistence(timeout: 5))
        submit.tap()
        XCTAssertTrue(app.staticTexts["Import terminé"].waitForExistence(timeout: 5))
        submit.tap()
        let map = app.otherElements["map-visible-viewport"].firstMatch
        let pins = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "saved-place-dense-"))
        XCTAssertTrue(pins.firstMatch.waitForExistence(timeout: 5))
        let initial = pins.allElementsBoundByIndex.min {
            hypot($0.frame.midX - map.frame.midX, $0.frame.midY - map.frame.midY)
                < hypot($1.frame.midX - map.frame.midX, $1.frame.midY - map.frame.midY)
        }
        guard let initial else { return XCTFail("The dense fixture must be visible") }
        let start = map.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.4))
        let aligned = start.withOffset(CGVector(dx: map.frame.midX - initial.frame.midX,
                                               dy: map.frame.midY - initial.frame.midY))
        start.press(forDuration: 0.05, thenDragTo: aligned, withVelocity: .slow, thenHoldForDuration: 0.2)
        map.pinch(withScale: 3.5, velocity: 0.5)
        screenshot("Début déplacement des pins photo")
        let pan = map.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.55))
        for delta in [CGVector(dx: 100, dy: 60), CGVector(dx: -145, dy: -100), CGVector(dx: 45, dy: 40)] {
            pan.press(forDuration: 0.05, thenDragTo: pan.withOffset(delta),
                      withVelocity: XCUIGestureVelocity(rawValue: 65), thenHoldForDuration: 0.2)
            XCTAssertTrue(pins.firstMatch.exists)
            XCTAssertFalse(savedPlaceNavigation.exists)
        }
        let edge = map.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0.25))
            .withOffset(CGVector(dx: 12, dy: 0))
        for dy in [45.0, -45.0] {
            edge.press(forDuration: 0.05, thenDragTo: edge.withOffset(CGVector(dx: 0, dy: dy)),
                       withVelocity: XCUIGestureVelocity(rawValue: 40), thenHoldForDuration: 0.2)
        }
        if let visible = pins.allElementsBoundByIndex.first(where: { $0.isHittable }) {
            centerPhotoPin(visible, on: map)
        }
        let focused = NSPredicate { _, _ in
            pins.allElementsBoundByIndex.contains { self.hasPresentation("Détaillé", pin: $0) }
        }
        expectation(for: focused, evaluatedWith: app)
        waitForExpectations(timeout: 5)
        screenshot("Fin déplacement des pins photo")
    }

    func testPasteSharedTextIntoSingleField() {
        UIPasteboard.general.string = "[NAVER Maps]\nCafés\nhttps://naver.me/demo"
        app.buttons["naver-import-paste"].tap()
        XCTAssertTrue(submit.isEnabled)
        XCTAssertEqual(app.textFields.count, 1)
        submit.tap()
        XCTAssertTrue(app.staticTexts["1 adresse à importer"].waitForExistence(timeout: 5))
    }

    private func hasPresentation(_ presentation: String, pin: XCUIElement) -> Bool {
        pin.exists && (pin.value as? String)?.contains(presentation) == true
    }

    private func waitUntilHittable(_ element: XCUIElement) {
        XCTAssertTrue(element.waitForExistence(timeout: 5))
        expectation(for: NSPredicate { _, _ in element.exists && element.isHittable }, evaluatedWith: app)
        waitForExpectations(timeout: 5)
    }

    private func centerPhotoPin(_ pin: XCUIElement, on map: XCUIElement) {
        let start = map.coordinate(withNormalizedOffset: CGVector(dx: 0.35, dy: 0.45))
        let end = start.withOffset(CGVector(dx: map.frame.midX - pin.frame.midX,
                                           dy: map.frame.midY - pin.frame.midY))
        start.press(forDuration: 0.05, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.2)
    }

    private func openSavedPlaceSheet(_ pin: XCUIElement) {
        waitUntilHittable(pin)
        // The fixed Mapbox host is centered on the geographic anchor, below the
        // photo. This point lies inside its drawn body at every map emphasis.
        let photoPoint = hasPresentation("Compact", pin: pin)
            ? CGVector(dx: -8, dy: -12) : CGVector(dx: 0, dy: -24)
        pin.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .withOffset(photoPoint).tap()
        waitUntilHittable(savedPlaceNavigation)
        XCTAssertFalse(app.buttons["saved-place-information"].exists)
        XCTAssertFalse(app.buttons["saved-place-photo"].exists)
    }

    private var savedPlaceNavigation: XCUIElement {
        app.navigationBars["Adresse enregistrée"]
    }

    private func closeSavedPlaceSheet() {
        let close = savedPlaceNavigation.buttons["Fermer"]
        waitUntilHittable(close)
        close.tap()
        XCTAssertTrue(savedPlaceNavigation.waitForNonExistence(timeout: 5))
    }

    private func dragSheetHeader(toY y: CGFloat) {
        let frame = savedPlaceNavigation.frame
        let origin = app.coordinate(withNormalizedOffset: .zero)
        let start = origin.withOffset(CGVector(dx: frame.midX, dy: frame.midY))
        let end = origin.withOffset(CGVector(dx: frame.midX, dy: y))
        start.press(forDuration: 0.05, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.2)
    }

    private func revealSheetControl(_ control: XCUIElement) {
        XCTAssertTrue(savedPlaceNavigation.waitForExistence(timeout: 3))
        for _ in 0..<8 {
            if control.exists && control.isHittable { break }
            let origin = app.coordinate(withNormalizedOffset: .zero)
            let start = origin.withOffset(CGVector(dx: app.frame.midX, dy: app.frame.maxY - 90))
            let end = origin.withOffset(CGVector(dx: app.frame.midX, dy: savedPlaceNavigation.frame.maxY + 30))
            start.press(forDuration: 0.05, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.2)
        }
        waitUntilHittable(control)
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

    private func loadPreview(_ link: String = "https://naver.me/demo") {
        let field = app.textFields["naver-import-link"]
        field.tap()
        field.typeText(link)
        submit.tap()
    }

    private func screenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
