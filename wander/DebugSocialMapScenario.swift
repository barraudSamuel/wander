#if DEBUG && targetEnvironment(simulator)
import CoreLocation
import SwiftUI

enum DebugSocialMapScenario {
    static let isEnabled = ProcessInfo.processInfo.arguments.contains("-debug-social-map")
}

/// Uses production map, detail and composer views. Only the data source is local.
struct DebugSocialMapScenarioView: View {
    enum SceneKind: String, CaseIterable, Identifiable {
        case events = "Événements"
        case mixed = "Mixte"
        case people = "Utilisateurs"
        var id: String { rawValue }
    }

    @State private var scene: SceneKind = ProcessInfo.processInfo.arguments
        .contains("-debug-social-map-mixed") ? .mixed : .events
    @State private var revision = 0

    var body: some View {
        DebugSocialMapScene(kind: scene)
            .id("\(scene.rawValue)-\(revision)")
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 8) {
                    Picker("Scénario", selection: $scene) {
                        ForEach(SceneKind.allCases) { kind in
                            Text(kind.rawValue).tag(kind)
                        }
                    }
                    .pickerStyle(.segmented)
                    HStack {
                        Text("Scénario carte sociale")
                            .font(.caption)
                        Spacer()
                        Button("Réinitialiser") { revision += 1 }
                    }
                }
                .padding()
                .background(.regularMaterial)
            }
    }
}

private struct DebugSocialMapScene: View {
    private static let coordinate = CLLocationCoordinate2D(latitude: 37.5665, longitude: 126.9780)
    private static let ownerID = "scenario-owner"

    private let friends: [String: FriendLocation]
    @StateObject private var locationTracker: LocationTracker
    @State private var plans: [String: OutingPlan]
    @State private var selectedEventID: String?
    @State private var editingEvent: OutingPlan?
    @State private var centerOnUser = false
    @State private var resetOrientation = false
    @State private var centerOnFriend: String?
    @State private var centerOnEvent: String?

    init(kind: DebugSocialMapScenarioView.SceneKind) {
        self.friends = Self.makeFriends(kind: kind)
        let coordinate = Self.coordinate
        _locationTracker = StateObject(wrappedValue: LocationTracker(
            scenarioLocation: CLLocation(
                latitude: coordinate.latitude + (kind == .events ? 0.0015 : 0),
                longitude: coordinate.longitude
            )
        ))
        let events = kind == .people ? [] : [
            Self.plan(number: 1, category: .meal),
            Self.plan(number: 2, category: .coffee)
        ]
        _plans = State(initialValue: Dictionary(uniqueKeysWithValues: events.map { ($0.id, $0) }))
    }

    private static func makeFriends(kind: DebugSocialMapScenarioView.SceneKind) -> [String: FriendLocation] {
        guard kind != .events else { return [:] }
        let referenceDate = Date()
        return Dictionary(uniqueKeysWithValues: ["Amina", "Jules"].map { name in
            let id = "scenario-\(name.lowercased())"
            return (id, FriendLocation(
                userID: id, displayName: name, avatarID: ProfileAvatar.cyclopsHorns.rawValue,
                profileColorHex: "#3478F6", coordinate: Self.coordinate,
                horizontalAccuracy: 5, sampledAt: referenceDate, updatedAt: referenceDate,
                receivedAt: referenceDate, spotEnteredAt: nil
            ))
        })
    }

    private var presentations: [String: MapOutingPlan] {
        plans.mapValues { plan in
            MapOutingPlan(
                plan: plan,
                organizer: MapOutingAttendee(userID: Self.ownerID, displayName: "Moi", avatarID: ProfileAvatar.cyclopsHorns.rawValue),
                profileColorHex: "#3478F6", isCurrentUser: true,
                rosterState: .available, participationState: .attending,
                attendees: [], declines: [], isAttendanceUpdating: false
            )
        }
    }

    var body: some View {
        let presentations = presentations
        ZStack(alignment: .top) {
            MapWithFogView(
                locationTracker: locationTracker,
                discoveredCellIDs: [], cityBoundaryCoordinates: [],
                friendLocations: friends, freshFriendLocationUserIDs: Set(friends.keys),
                outingPlans: presentations,
                userDisplayName: "Moi", userAvatarID: ProfileAvatar.cyclopsHorns.rawValue,
                userProfileColorHex: "#3478F6",
                centerOnUser: $centerOnUser, resetMapOrientation: $resetOrientation,
                centerOnFriendUserID: $centerOnFriend, centerOnOutingPlanEventID: $centerOnEvent,
                isEventCreationEnabled: editingEvent == nil,
                selectedOutingPlanEventID: selectedEventID,
                showsSystemUserLocation: false,
                onSelectOutingPlan: { selectedEventID = $0 },
                onDeselectOutingPlan: { id in
                    guard selectedEventID == id else { return }
                    selectedEventID = nil
                }
            )
            .ignoresSafeArea()

            if let id = selectedEventID, let outing = presentations[id] {
                OutingPlanDetailCardView(
                    outing: outing,
                    onDismiss: { selectedEventID = nil },
                    onEdit: { editingEvent = outing.plan },
                    onOpenDirections: {}, onSetAttendance: { _ in }
                )
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .transition(.scale(scale: 0.96, anchor: .top))
            }
        }
        .animation(.spring(response: 0.18, dampingFraction: 0.9), value: selectedEventID)
        .sheet(item: $editingEvent) { event in
            OutingPlanComposerView(
                displayName: "Moi", initialCoordinate: nil, editingEvent: event,
                operations: OutingPlanComposerOperations(
                    fetchEvent: { plans[$0] },
                    publish: { draft, existing in
                        guard let existing else { throw OutingPlanValidationError.invalidEventID }
                        let updated = OutingPlan(
                            eventID: existing.eventID, eventIDValue: existing.eventIDValue,
                            ownerID: existing.ownerID, publicationID: existing.publicationID,
                            publicationIDValue: existing.publicationIDValue,
                            displayName: draft.displayName, placeName: draft.placeName,
                            address: draft.address, category: draft.category,
                            coordinate: draft.coordinate, plannedAt: draft.plannedAt,
                            publishedAt: existing.publishedAt, updatedAt: Date(),
                            timeZoneIdentifier: draft.timeZoneIdentifier
                        )
                        plans[updated.id] = updated
                        return updated
                    },
                    cancel: { id in
                        plans.removeValue(forKey: id)
                        if selectedEventID == id { selectedEventID = nil }
                    }
                ),
                showsNotificationSettings: false
            )
        }
    }

    private static func plan(number: Int, category: OutingCategory) -> OutingPlan {
        let id = UUID(uuidString: "00000000-0000-4000-8000-00000000000\(number)")!
        let date = Date()
        return OutingPlan(
            eventID: id, eventIDValue: id.uuidString.lowercased(), ownerID: ownerID,
            publicationID: id, publicationIDValue: id.uuidString.lowercased(),
            displayName: "Moi", placeName: category.title, address: "Lieu de test",
            category: category, coordinate: coordinate,
            plannedAt: date.addingTimeInterval(Double(number) * 3600),
            publishedAt: date, updatedAt: date, timeZoneIdentifier: "Asia/Seoul"
        )
    }
}
#endif
