import Foundation

/// Account-scoped intent stays restrictive until the server confirms it.
struct GhostModeState: Equatable {
    nonisolated enum ChangeOutcome: String {
        case applied
        case idempotent
        case conflict
    }

    nonisolated struct Change: Codable, Equatable {
        let enabled: Bool
        let revision: String
        let expectedRevision: String?
        let predecessorRevisions: Set<String?>

        init(
            enabled: Bool,
            revision: String,
            expectedRevision: String? = nil,
            predecessorRevisions: Set<String?> = []
        ) {
            self.enabled = enabled
            self.revision = revision
            self.expectedRevision = expectedRevision
            self.predecessorRevisions = predecessorRevisions
        }

        func outcome(currentRevision: String?, currentEnabled: Bool) -> ChangeOutcome {
            if currentRevision == revision {
                return currentEnabled == enabled ? .idempotent : .conflict
            }
            return currentRevision == expectedRevision
                || predecessorRevisions.contains(currentRevision)
                ? .applied : .conflict
        }
    }

    private(set) var confirmedEnabled: Bool?
    private(set) var confirmedRevision: String?
    private(set) var resumedAt: Date?
    private(set) var pendingChange: Change?
    private(set) var rememberedEnabled: Bool
    private(set) var rememberedRevision: String?

    init(
        rememberedEnabled: Bool = false,
        rememberedRevision: String? = nil,
        pendingChange: Change? = nil
    ) {
        self.rememberedEnabled = rememberedEnabled
        self.rememberedRevision = rememberedRevision
        self.pendingChange = pendingChange
    }

    var isEnabled: Bool {
        pendingChange?.enabled ?? confirmedEnabled ?? rememberedEnabled
    }

    var allowsSharing: Bool {
        confirmedEnabled == false && pendingChange == nil
    }

    mutating func request(_ enabled: Bool, revision: String = UUID().uuidString) {
        let predecessors = pendingChange.map {
            $0.predecessorRevisions.union([$0.expectedRevision, $0.revision])
        } ?? []
        pendingChange = Change(
            enabled: enabled,
            revision: revision,
            expectedRevision: confirmedEnabled != nil
                ? confirmedRevision : rememberedRevision,
            predecessorRevisions: predecessors
        )
    }

    mutating func receive(enabled: Bool, revision: String?, resumedAt: Date?) {
        confirmedEnabled = enabled
        confirmedRevision = revision
        rememberedEnabled = enabled
        rememberedRevision = revision
        self.resumedAt = resumedAt
        if pendingChange?.revision == revision,
           pendingChange?.enabled == enabled {
            pendingChange = nil
        }
    }

    /// The write acknowledgement ends this intent even if another device has
    /// already replaced it. A fresh server read then resolves the current mode.
    mutating func acknowledge(_ change: Change) {
        guard pendingChange?.revision == change.revision else { return }
        pendingChange = nil
        rememberedEnabled = change.enabled
        rememberedRevision = change.revision
        confirmedEnabled = nil
    }

    /// A conflicting remote revision wins over this stale intent, while a
    /// newer explicit local action remains pending for its own transaction.
    mutating func discardConflictingChange(_ change: Change) {
        guard pendingChange?.revision == change.revision else { return }
        pendingChange = nil
        confirmedEnabled = nil
    }
}
