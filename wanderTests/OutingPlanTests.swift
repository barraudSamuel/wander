import CoreLocation
import XCTest
@testable import wander

@MainActor
final class OutingPlanTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_792_836_000)

    func testKolkataAliasCanBePublishedWithoutChangingItsDateOrIdentifier() throws {
        try assertValidTimeZone("Asia/Kolkata")
    }

    func testCalcuttaAliasCanBePublishedWithoutChangingItsDateOrIdentifier() throws {
        try assertValidTimeZone("Asia/Calcutta")
    }

    func testCanonicalTimeZonesAndUTCAliasesAreAccepted() throws {
        for identifier in ["Asia/Seoul", "Europe/Paris", "GMT", "UTC", "Etc/UTC"] {
            try assertValidTimeZone(identifier)
        }
    }

    func testInvalidIdentifiersAndFixedOffsetFormatsAreRejected() {
        for identifier in ["", "Not/AZone", " Asia/Kolkata", "Asia/Kolkata ", "GMT+0530"] {
            XCTAssertThrowsError(try OutingPlan.validatedDraft(draft(identifier), referenceDate: now)) { error in
                XCTAssertEqual(error as? OutingPlanValidationError, .invalidTimeZone, identifier)
            }
        }
    }

    private func assertValidTimeZone(
        _ identifier: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        let input = draft(identifier)
        let validated = try OutingPlan.validatedDraft(input, referenceDate: now)
        XCTAssertEqual(validated, input, file: file, line: line)
    }

    private func draft(_ timeZoneIdentifier: String) -> OutingPlanDraft {
        OutingPlanDraft(
            displayName: "Samuel",
            placeName: "Café",
            address: nil,
            category: .coffee,
            coordinate: CLLocationCoordinate2D(latitude: 48.85, longitude: 2.35),
            plannedAt: now.addingTimeInterval(3_600),
            timeZoneIdentifier: timeZoneIdentifier
        )
    }
}
