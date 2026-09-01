import assert from "node:assert/strict";
import test from "node:test";
import {
  AttendanceCleanupCandidate,
  FriendshipCleanupDirection,
  FriendshipCleanupStore,
  friendshipRevocation,
  runFriendshipRevocationCleanup,
  shouldDeleteRevokedAttendance,
} from "./friendshipCleanupLogic.js";

class TestTimestamp {
  constructor(private readonly milliseconds: number) {}

  toMillis(): number {
    return this.milliseconds;
  }
}

function acceptedFriendship(): Record<string, unknown> {
  return {
    participants: ["alice", "bob"],
    requestedBy: "alice",
    status: "accepted",
    createdAt: new TestTimestamp(1_000),
    acceptedAt: new TestTimestamp(2_000),
  };
}

test("friendshipRevocation accepts a stable accepted to revoking transition", () => {
  const before = acceptedFriendship();
  const after = {
    ...before,
    status: "revoking",
    revokedAt: new TestTimestamp(3_000),
  };

  assert.deepEqual(friendshipRevocation(before, after), {
    participantIDs: ["alice", "bob"],
    revokedAtMilliseconds: 3_000,
  });
});

test("friendshipRevocation rejects unrelated or malformed transitions", () => {
  const before = acceptedFriendship();
  const validAfter = {
    ...before,
    status: "revoking",
    revokedAt: new TestTimestamp(3_000),
  };

  assert.equal(friendshipRevocation(before, before), undefined);
  assert.equal(friendshipRevocation(
    { ...before, status: "pending" },
    validAfter,
  ), undefined);
  assert.equal(friendshipRevocation(before, {
    ...validAfter,
    participants: ["alice", "mallory"],
  }), undefined);
  assert.equal(friendshipRevocation(before, {
    ...validAfter,
    requestedBy: "bob",
  }), undefined);
  assert.equal(friendshipRevocation(before, {
    ...validAfter,
    revokedAt: "not-a-timestamp",
  }), undefined);
});

test("attendance cleanup includes the revocation boundary", () => {
  assert.equal(shouldDeleteRevokedAttendance(
    {
      eventId: "event-a",
      participantId: "bob",
      joinedAt: new TestTimestamp(3_000),
    },
    "event-a",
    "bob",
    3_000,
  ), true);
});

test("decline cleanup uses the negative response timestamp", () => {
  assert.equal(shouldDeleteRevokedAttendance(
    {
      eventId: "event-a",
      participantId: "bob",
      respondedAt: new TestTimestamp(3_000),
    },
    "event-a",
    "bob",
    3_000,
  ), true);
});

test("attendance cleanup preserves newer or unrelated records", () => {
  const attendance = {
    eventId: "event-a",
    participantId: "bob",
    joinedAt: new TestTimestamp(3_001),
  };

  assert.equal(shouldDeleteRevokedAttendance(
    attendance,
    "event-a",
    "bob",
    3_000,
  ), false);
  assert.equal(shouldDeleteRevokedAttendance(
    { ...attendance, joinedAt: new TestTimestamp(2_000) },
    "event-b",
    "bob",
    3_000,
  ), false);
  assert.equal(shouldDeleteRevokedAttendance(
    { ...attendance, joinedAt: new TestTimestamp(2_000) },
    "event-a",
    "alice",
    3_000,
  ), false);
  assert.equal(shouldDeleteRevokedAttendance(
    { ...attendance, joinedAt: "not-a-timestamp" },
    "event-a",
    "bob",
    3_000,
  ), false);
});

class TestCleanupStore implements FriendshipCleanupStore<string> {
  readonly deletedBatches: string[][] = [];
  readonly loadedDirections: FriendshipCleanupDirection[] = [];
  finalized = false;
  failDeleteOnce = false;

  constructor(
    private readonly candidatesByDirection:
      Map<string, AttendanceCleanupCandidate<string>[]>,
  ) {}

  async loadAttendances(
    direction: FriendshipCleanupDirection,
  ): Promise<readonly AttendanceCleanupCandidate<string>[]> {
    this.loadedDirections.push(direction);
    return this.candidatesByDirection.get(
      `${direction.ownerID}:${direction.participantID}`,
    ) ?? [];
  }

  async deleteAttendances(references: readonly string[]): Promise<void> {
    if (this.failDeleteOnce) {
      this.failDeleteOnce = false;
      throw new Error("transient delete failure");
    }

    this.deletedBatches.push([...references]);
    for (const candidates of this.candidatesByDirection.values()) {
      for (const reference of references) {
        const index = candidates.findIndex(
          (candidate) => candidate.reference === reference,
        );
        if (index >= 0) {
          candidates.splice(index, 1);
        }
      }
    }
  }

  async finalizeRevocation(): Promise<void> {
    this.finalized = true;
  }
}

function attendanceCandidate(
  reference: string,
  eventID: string,
  participantID: string,
  joinedAtMilliseconds: number,
): AttendanceCleanupCandidate<string> {
  return {
    reference,
    eventID,
    data: {
      eventId: eventID,
      participantId: participantID,
      joinedAt: new TestTimestamp(joinedAtMilliseconds),
    },
  };
}

function declineCandidate(
  reference: string,
  eventID: string,
  participantID: string,
  respondedAtMilliseconds: number,
): AttendanceCleanupCandidate<string> {
  return {
    reference,
    eventID,
    data: {
      eventId: eventID,
      participantId: participantID,
      respondedAt: new TestTimestamp(respondedAtMilliseconds),
    },
  };
}

test("cleanup covers both directions, multiple events, and bounded batches", async () => {
  const store = new TestCleanupStore(new Map([
    ["alice:bob", [
      attendanceCandidate("a-1", "event-a", "bob", 1_000),
      attendanceCandidate("a-2", "event-b", "bob", 2_000),
      declineCandidate("a-decline", "event-c", "bob", 2_500),
      attendanceCandidate("newer", "event-c", "bob", 3_001),
    ]],
    ["bob:alice", [
      attendanceCandidate("b-1", "event-d", "alice", 3_000),
    ]],
  ]));

  const deletedCount = await runFriendshipRevocationCleanup(
    {
      participantIDs: ["alice", "bob"],
      revokedAtMilliseconds: 3_000,
    },
    store,
    1,
  );

  assert.equal(deletedCount, 4);
  assert.deepEqual(store.loadedDirections, [
    { ownerID: "alice", participantID: "bob" },
    { ownerID: "bob", participantID: "alice" },
  ]);
  assert.deepEqual(
    store.deletedBatches,
    [["a-1"], ["a-2"], ["a-decline"], ["b-1"]],
  );
  assert.equal(store.finalized, true);
});

test("cleanup retry is idempotent and finalizes only after success", async () => {
  const store = new TestCleanupStore(new Map([
    ["alice:bob", [
      attendanceCandidate("a-1", "event-a", "bob", 1_000),
    ]],
  ]));
  const revocation = {
    participantIDs: ["alice", "bob"] as const,
    revokedAtMilliseconds: 3_000,
  };
  store.failDeleteOnce = true;

  await assert.rejects(
    runFriendshipRevocationCleanup(revocation, store),
    /transient delete failure/,
  );
  assert.equal(store.finalized, false);

  assert.equal(
    await runFriendshipRevocationCleanup(revocation, store),
    1,
  );
  assert.equal(store.finalized, true);
  assert.equal(
    await runFriendshipRevocationCleanup(revocation, store),
    0,
  );
});
