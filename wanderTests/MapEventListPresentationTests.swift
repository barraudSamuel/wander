import CoreLocation
import XCTest
@testable import wander

@MainActor
final class MapEventListPresentationTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_789_041_600)
    func testAllEventsRemainChronologicalRegardlessOfResponse() {
        let owner = outing(number: 2, mine: true, date: now)
        let guest = outing(number: 1, response: .declined, date: now)
        let earlier = outing(number: 3, response: .loading, date: now.addingTimeInterval(-60))
        XCTAssertEqual(
            MapEventListPresentation.sortedOutings([owner, earlier, guest]).map(\.plan.id),
            [earlier.plan.id, guest.plan.id, owner.plan.id]
        )
    }

    func testSummaryKeepsFullEventInformation() {
        let event = outing(number: 1, response: .attending)
        let content = MapEventListPresentation.accessibilitySummary(for: event, location: nil, now: now)
        XCTAssertTrue(content.hasPrefix("Théo organise un café le "))
        XCTAssertTrue(content.contains("Lieu : Café des amis."))
        XCTAssertTrue(content.hasSuffix("Vous participez."))
        XCTAssertFalse(content.contains("☕"))
        let owned = MapEventListPresentation.accessibilitySummary(for: outing(number: 2, mine: true), location: nil, now: now)
        XCTAssertTrue(owned.hasPrefix("Vous organisez un café"))
        XCTAssertFalse(owned.contains("répondu"))
    }

    func testSummaryDistinguishesUnknownAndDeclinedResponses() {
        for (response, expected) in [
            (OutingAttendanceParticipationState.loading, "Votre réponse est en cours de chargement."),
            (.notRequested, "Votre réponse est en cours de chargement."),
            (.unavailable, "Votre réponse est indisponible."),
            (.notResponded, "Vous n’avez pas encore répondu."),
            (.declined, "Vous ne participez pas.")
        ] {
            let content = MapEventListPresentation.accessibilitySummary(for: outing(number: 1, response: response), location: nil, now: now)
            XCTAssertTrue(content.hasSuffix(expected))
        }
    }

    func testHighlightedTextReflowsAndClearsCachedContent() {
        let label = MapDetailFittingLabel()
        label.configure(
            content: MapDetailTextContent(fragments: [
                .avatars(["skull"]), .text(" Théo organise un "), .highlighted("☕️"),
                .text(" au "), .highlighted("📍 Café du parc et des promenades au bord de la rivière")
            ], accessibilityLabel: "Sortie au café"),
            minimumFontSize: 17, appearance: .dark, contrast: .normal
        )
        let wide = label.fittedSize(width: 360, height: nil)
        let narrow = label.fittedSize(width: 160, height: nil)
        XCTAssertGreaterThan(narrow.height, wide.height)
        XCTAssertEqual(label.fittedSize(width: 360, height: nil), wide)
        label.configure(
            content: MapDetailTextContent(fragments: [.text("Court")], accessibilityLabel: "Court"),
            minimumFontSize: 17, appearance: .light, contrast: .normal
        )
        XCTAssertLessThan(label.fittedSize(width: 360, height: nil).height, wide.height)
        XCTAssertEqual(label.attributedText?.string, "Court")
    }

    func testSingleParticipantIncludesNameAndAvatarWithoutRepeatingOrganizer() {
        let organizer = MapOutingAttendee(userID: "owner", displayName: "Théo", avatarID: "skull")
        let person = MapOutingAttendee(userID: "guest", displayName: "Jules", avatarID: "guest-avatar")
        let content = MapEventListPresentation.accessibilitySummary(
            for: outing(number: 1, attendees: [organizer, person, person]), location: nil, now: now
        )
        XCTAssertTrue(content.contains(" avec Jules. Lieu"))
    }

    func testGroupsKeepAllParticipantNamesInSummary() {
        let people = (1...5).map {
            MapOutingAttendee(userID: "guest-\($0)", displayName: "Invité \($0)", avatarID: "avatar-\($0)")
        }
        for count in [2, 3, 5] {
            let content = MapEventListPresentation.accessibilitySummary(
                for: outing(number: 1, attendees: Array(people.prefix(count))), location: nil, now: now
            )
            XCTAssertTrue(content.contains("Invité \(count)"))
        }
    }

    func testEmptyRosterAndDeclinesAreNotParticipants() {
        let declined = MapOutingAttendee(userID: "declined", displayName: "Absent", avatarID: "skull")
        let content = MapEventListPresentation.accessibilitySummary(
            for: outing(number: 1, declines: [declined]), location: nil, now: now
        )
        XCTAssertTrue(content.contains("Aucun autre participant pour le moment"))
        XCTAssertFalse(content.contains("Absent"))
    }

    func testUnknownRosterNeverClaimsThereAreNoParticipantsOrShowsStalePeople() {
        let stale = MapOutingAttendee(userID: "stale", displayName: "Ancien", avatarID: "stale-avatar")
        for state in [OutingAttendanceRosterState.loading, .notRequested, .unavailable] {
            let content = MapEventListPresentation.accessibilitySummary(
                for: outing(number: 1, rosterState: state, attendees: [stale]), location: nil, now: now
            )
            XCTAssertTrue(content.contains(state == .unavailable ? "Participants indisponibles" : "Chargement des participants"))
            XCTAssertFalse(content.contains("Aucun autre participant"))
            XCTAssertFalse(content.contains("Ancien"))
        }
    }

    func testCompactStatusesAndResponseGuards() {
        for (state, title, allowed) in [
            (OutingAttendanceParticipationState.notResponded, "À répondre", true),
            (.attending, "J’y vais", true), (.declined, "Pas cette fois", true),
            (.loading, "Vérification…", false), (.notRequested, "Vérification…", false),
            (.unavailable, "Indisponible", false)
        ] {
            let event = outing(number: 1, response: state)
            XCTAssertEqual(MapEventListPresentation.compactStatus(for: event), title)
            XCTAssertEqual(MapEventListPresentation.canRespond(to: event), allowed)
        }
        let pending = outing(number: 1, response: .attending, updating: true)
        XCTAssertFalse(MapEventListPresentation.canRespond(to: pending))
        XCTAssertEqual(MapEventListPresentation.compactStatus(for: pending), "Envoi…")
        let owner = outing(number: 1, mine: true)
        XCTAssertFalse(MapEventListPresentation.canRespond(to: owner))
        XCTAssertEqual(MapEventListPresentation.compactStatus(for: owner), "Vous organisez")
    }

    func testParticipantPreviewExcludesOrganizerDuplicatesAndStaleData() {
        let owner = MapOutingAttendee(userID: "owner", displayName: "Théo", avatarID: "skull")
        let guest = MapOutingAttendee(userID: "guest", displayName: "Jules", avatarID: "skull")
        XCTAssertEqual(MapEventListPresentation.participants(for: outing(number: 1, attendees: [owner, guest, guest])), [guest])
        for state in [OutingAttendanceRosterState.loading, .notRequested, .unavailable] {
            XCTAssertTrue(MapEventListPresentation.participants(for: outing(number: 1, rosterState: state, attendees: [guest])).isEmpty)
        }
    }

    func testDistanceDisappearsWhenLocationExpiresOrIsUnreliable() {
        let destination = CLLocationCoordinate2D(latitude: 48.8566, longitude: 2.3522)
        func location(age: TimeInterval = 0, accuracy: Double = 10) -> CLLocation {
            CLLocation(coordinate: destination, altitude: 0, horizontalAccuracy: accuracy,
                       verticalAccuracy: -1, timestamp: now.addingTimeInterval(-age))
        }
        XCTAssertNotNil(MapEventListPresentation.distance(to: destination, from: location(age: 300), now: now))
        for invalid in [nil, location(age: 301), location(age: -31), location(accuracy: -1), location(accuracy: 101)] {
            XCTAssertNil(MapEventListPresentation.distance(to: destination, from: invalid, now: now))
        }
        XCTAssertEqual(MapEventListPresentation.distance(to: destination, from: location(), now: now), "À moins de 100 m à vol d’oiseau")
        let nearby = CLLocationCoordinate2D(latitude: destination.latitude + 0.0015, longitude: destination.longitude)
        XCTAssertEqual(MapEventListPresentation.distance(to: nearby, from: location(), now: now), "≈ 200 m à vol d’oiseau")
        XCTAssertEqual(MapEventListPresentation.distance(to: nearby, from: location(), now: now, compact: true), "≈ 200 m")
    }

    private func outing(
        number: Int, mine: Bool = false, response: OutingAttendanceParticipationState = .notResponded,
        date: Date? = nil, rosterState: OutingAttendanceRosterState = .available,
        attendees: [MapOutingAttendee] = [], declines: [MapOutingAttendee] = [], updating: Bool = false
    ) -> MapOutingPlan {
        let id = UUID(uuidString: String(format: "00000000-0000-4000-8000-%012d", number))!
        let plan = OutingPlan(
            eventID: id, eventIDValue: id.uuidString, ownerID: "owner",
            publicationID: id, publicationIDValue: id.uuidString,
            displayName: "Théo", placeName: "Café des amis", address: nil, category: .coffee,
            coordinate: CLLocationCoordinate2D(latitude: 48.8566, longitude: 2.3522),
            plannedAt: date ?? now, publishedAt: now, updatedAt: now, timeZoneIdentifier: "Europe/Paris"
        )
        return MapOutingPlan(
            plan: plan, organizer: MapOutingAttendee(userID: "owner", displayName: "Théo", avatarID: "skull"),
            profileColorHex: "#3478F6", isCurrentUser: mine, rosterState: rosterState,
            participationState: response, attendees: attendees, declines: declines, isAttendanceUpdating: updating
        )
    }
}
