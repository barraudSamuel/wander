interface TimestampLike {
  toMillis(): number;
}

export interface FriendshipRevocation {
  participantIDs: readonly [string, string];
  revokedAtMilliseconds: number;
}

export interface FriendshipCleanupDirection {
  ownerID: string;
  participantID: string;
}

export interface AttendanceCleanupCandidate<Reference> {
  reference: Reference;
  eventID: string;
  data: unknown;
}

export interface FriendshipCleanupStore<Reference> {
  loadAttendances(
    direction: FriendshipCleanupDirection,
  ): Promise<readonly AttendanceCleanupCandidate<Reference>[]>;
  deleteAttendances(references: readonly Reference[]): Promise<void>;
  finalizeRevocation(revocation: FriendshipRevocation): Promise<void>;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null;
}

function participantIDs(
  value: unknown,
): readonly [string, string] | undefined {
  if (
    !Array.isArray(value)
    || value.length !== 2
    || typeof value[0] !== "string"
    || value[0].length === 0
    || typeof value[1] !== "string"
    || value[1].length === 0
    || value[0] >= value[1]
  ) {
    return undefined;
  }

  return [value[0], value[1]];
}

function timestampMilliseconds(value: unknown): number | undefined {
  if (!isRecord(value) || typeof value.toMillis !== "function") {
    return undefined;
  }

  const milliseconds = (value as unknown as TimestampLike).toMillis();
  return Number.isFinite(milliseconds) ? milliseconds : undefined;
}

function timestampsMatch(lhs: unknown, rhs: unknown): boolean {
  const lhsMilliseconds = timestampMilliseconds(lhs);
  const rhsMilliseconds = timestampMilliseconds(rhs);
  return lhsMilliseconds !== undefined
    && rhsMilliseconds !== undefined
    && lhsMilliseconds === rhsMilliseconds;
}

export function friendshipRevocation(
  before: unknown,
  after: unknown,
): FriendshipRevocation | undefined {
  if (!isRecord(before) || !isRecord(after)) {
    return undefined;
  }

  const beforeParticipants = participantIDs(before.participants);
  const afterParticipants = participantIDs(after.participants);
  const revokedAtMilliseconds = timestampMilliseconds(after.revokedAt);
  if (
    before.status !== "accepted"
    || after.status !== "revoking"
    || beforeParticipants === undefined
    || afterParticipants === undefined
    || beforeParticipants[0] !== afterParticipants[0]
    || beforeParticipants[1] !== afterParticipants[1]
    || before.requestedBy !== after.requestedBy
    || !timestampsMatch(before.createdAt, after.createdAt)
    || !timestampsMatch(before.acceptedAt, after.acceptedAt)
    || revokedAtMilliseconds === undefined
  ) {
    return undefined;
  }

  return {
    participantIDs: afterParticipants,
    revokedAtMilliseconds,
  };
}

export function shouldDeleteRevokedAttendance(
  attendance: unknown,
  expectedEventID: string,
  participantID: string,
  revokedAtMilliseconds: number,
): boolean {
  if (!isRecord(attendance)) {
    return false;
  }

  const responseAtMilliseconds = timestampMilliseconds(attendance.joinedAt)
    ?? timestampMilliseconds(attendance.respondedAt);
  return attendance.eventId === expectedEventID
    && attendance.participantId === participantID
    && responseAtMilliseconds !== undefined
    && responseAtMilliseconds <= revokedAtMilliseconds;
}

export async function runFriendshipRevocationCleanup<Reference>(
  revocation: FriendshipRevocation,
  store: FriendshipCleanupStore<Reference>,
  maximumBatchSize = 500,
): Promise<number> {
  if (!Number.isInteger(maximumBatchSize) || maximumBatchSize < 1) {
    throw new RangeError("maximumBatchSize must be a positive integer");
  }

  const [firstParticipantID, secondParticipantID] =
    revocation.participantIDs;
  const directions: readonly FriendshipCleanupDirection[] = [
    {
      ownerID: firstParticipantID,
      participantID: secondParticipantID,
    },
    {
      ownerID: secondParticipantID,
      participantID: firstParticipantID,
    },
  ];
  let deletedAttendanceCount = 0;

  for (const direction of directions) {
    const candidates = await store.loadAttendances(direction);
    const references = candidates.flatMap((candidate) =>
      shouldDeleteRevokedAttendance(
        candidate.data,
        candidate.eventID,
        direction.participantID,
        revocation.revokedAtMilliseconds,
      )
        ? [candidate.reference]
        : []
    );
    for (let index = 0; index < references.length; index += maximumBatchSize) {
      const batch = references.slice(index, index + maximumBatchSize);
      await store.deleteAttendances(batch);
      deletedAttendanceCount += batch.length;
    }
  }

  await store.finalizeRevocation(revocation);
  return deletedAttendanceCount;
}
