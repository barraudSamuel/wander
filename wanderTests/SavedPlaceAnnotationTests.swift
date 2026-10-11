import UIKit
import XCTest
@testable import wander

@MainActor
final class SavedPlaceAnnotationTests: XCTestCase {
    func testLabelVisibilityHasSeparateZoomInAndZoomOutThresholds() {
        var visible = false
        for (zoom, expected) in [(13.9, false), (14.0, true), (13.9, true),
                                 (13.7, true), (13.69, false), (13.8, false), (15.0, true)] {
            visible = SavedPlaceAnnotationView.shouldShowLabels(at: zoom, wasVisible: visible)
            XCTAssertEqual(visible, expected, "Unexpected labels at zoom \(zoom)")
        }
    }

    func testLongLabelsKeepIconAnchoredAndHitTargetUsableWhenToggled() {
        let annotation = makeAnnotation(name: String(repeating: "Café avec un nom très long ", count: 10))
        let view = SavedPlaceAnnotationView(annotation: annotation, reuseIdentifier: nil)
        view.configure(with: annotation)
        let labels = view.subviews.compactMap { $0 as? UILabel }
        XCTAssertTrue(labels.allSatisfy(\.isHidden))
        XCTAssertEqual(view.bounds.size, CGSize(width: 44, height: 44))

        view.setLabelsVisible(true)
        XCTAssertEqual(labels.map(\.text), [annotation.title, "Café"])
        XCTAssertTrue(labels.allSatisfy { !$0.isHidden && $0.frame.width <= 160 })
        XCTAssertLessThanOrEqual(view.bounds.width, 208)
        XCTAssertEqual(view.centerOffset.width - view.bounds.midX + 22, 0, accuracy: 0.001)
        XCTAssertTrue(view.point(inside: CGPoint(x: 22, y: 22), with: nil))

        view.setLabelsVisible(false)
        XCTAssertEqual(view.bounds.size, CGSize(width: 44, height: 44))
        XCTAssertEqual(view.centerOffset, .zero)
        XCTAssertTrue(labels.allSatisfy(\.isHidden))
    }

    func testReconfigurationUpdatesVisibleNameAndType() {
        let annotation = makeAnnotation(name: "Café initial")
        let view = SavedPlaceAnnotationView(annotation: annotation, reuseIdentifier: nil)
        view.configure(with: annotation)
        view.setLabelsVisible(true)
        annotation.title = "Nouveau restaurant"
        annotation.categoryCode = "DINING"
        view.configure(with: annotation)
        XCTAssertEqual(view.subviews.compactMap { ($0 as? UILabel)?.text },
                       ["Nouveau restaurant", "Restaurant"])
        XCTAssertTrue(view.showsLabels)
        XCTAssertEqual(view.accessibilityValue, "Restaurant")
    }

    private func makeAnnotation(name: String) -> SavedPlaceAnnotation {
        let place = NaverImportedPlace(id: "test", name: name, address: "Adresse de test",
                                      latitude: 37, longitude: 127,
                                      naverURL: URL(string: "https://map.naver.com/")!,
                                      isUnavailable: false, hasLocationWarning: false,
                                      categoryCode: "CAFE", categoryName: "카페")
        return SavedPlaceAnnotation(place: SavedPlace(place: place, ownerID: "test-owner", listName: "Cafés"))
    }
}
