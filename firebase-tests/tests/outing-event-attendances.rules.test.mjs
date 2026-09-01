import { readFile } from "node:fs/promises";
import { after, before, beforeEach, describe, test } from "node:test";
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from "@firebase/rules-unit-testing";
import {
  collection,
  collectionGroup,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  query,
  setDoc,
  updateDoc,
  where,
  writeBatch,
} from "firebase/firestore";

const projectId = "demo-wander-event-responses";
const ownerId = "outing-owner";
const participantId = "outing-participant";
const otherFriendId = "outing-other-friend";
const pendingId = "outing-pending";
const revokingId = "outing-revoking";
const strangerId = "outing-stranger";
const eventId = "event-with-flexible-id";
const publicationId = "publication-with-flexible-id";

let testEnvironment;

function authenticatedFirestore(userId) {
  return testEnvironment.authenticatedContext(userId).firestore();
}

function eventReference(database) {
  return doc(database, "users", ownerId, "events", eventId);
}

function responseId(userId = participantId) {
  return `${publicationId}__${userId}`;
}

function attendanceReference(database, userId = participantId) {
  return doc(
    database,
    "users",
    ownerId,
    "events",
    eventId,
    "attendees",
    responseId(userId),
  );
}

function declineReference(database, userId = participantId) {
  return doc(
    database,
    "users",
    ownerId,
    "events",
    eventId,
    "declines",
    responseId(userId),
  );
}

function attendanceData(userId = participantId, overrides = {}) {
  return {
    participantId: userId,
    publicationId,
    displayName: "Flexible attendee",
    clientDefinedTime: "whenever",
    ...overrides,
  };
}

function declineData(userId = participantId, overrides = {}) {
  return {
    participantId: userId,
    publicationId,
    displayName: "Flexible decline",
    clientDefinedTime: "whenever",
    ...overrides,
  };
}

function commitResponseBatch(database, response, userId = participantId) {
  const batch = writeBatch(database);
  if (response === "attending") {
    batch.delete(declineReference(database, userId));
    batch.set(
      attendanceReference(database, userId),
      attendanceData(userId),
    );
  } else {
    batch.delete(attendanceReference(database, userId));
    batch.set(
      declineReference(database, userId),
      declineData(userId),
    );
  }
  return batch.commit();
}

async function seedFriendship(userId, status) {
  const participants = [ownerId, userId].sort();
  await testEnvironment.withSecurityRulesDisabled(async (context) => {
    await setDoc(
      doc(context.firestore(), "friendships", participants.join("__")),
      { participants, requestedBy: ownerId, status },
    );
  });
}

async function seedAttendance(userId = participantId) {
  await testEnvironment.withSecurityRulesDisabled(async (context) => {
    await setDoc(
      attendanceReference(context.firestore(), userId),
      attendanceData(userId),
    );
  });
}

async function seedDecline(userId = participantId) {
  await testEnvironment.withSecurityRulesDisabled(async (context) => {
    await setDoc(
      declineReference(context.firestore(), userId),
      declineData(userId),
    );
  });
}

before(async () => {
  const rules = await readFile(
    new URL("../../firestore.rules", import.meta.url),
    "utf8",
  );
  testEnvironment = await initializeTestEnvironment({
    projectId,
    firestore: { host: "127.0.0.1", port: 8980, rules },
  });
});

beforeEach(async () => {
  await testEnvironment.clearFirestore();
  await testEnvironment.withSecurityRulesDisabled(async (context) => {
    await setDoc(eventReference(context.firestore()), { publicationId });
  });
  await Promise.all([
    seedFriendship(participantId, "accepted"),
    seedFriendship(otherFriendId, "accepted"),
    seedFriendship(pendingId, "pending"),
    seedFriendship(revokingId, "revoking"),
  ]);
});

after(async () => {
  await testEnvironment.cleanup();
});

describe("event response access", () => {
  test("both missing personal listeners succeed for an accepted friend", async () => {
    const database = authenticatedFirestore(participantId);
    const attendance = await assertSucceeds(getDoc(
      attendanceReference(database),
    ));
    const decline = await assertSucceeds(getDoc(declineReference(database)));

    if (attendance.exists() || decline.exists()) {
      throw new Error("expected empty personal response documents");
    }
  });

  test("accepted friends can create and evolve their own flexible response", async () => {
    const database = authenticatedFirestore(participantId);
    const attendance = attendanceReference(database);
    const decline = declineReference(database);

    await assertSucceeds(setDoc(attendance, attendanceData(participantId, {
      avatarID: "future-avatar",
      futureField: { version: 2 },
    })));
    await assertSucceeds(updateDoc(attendance, {
      anotherFutureField: [1, 2, 3],
    }));
    await assertSucceeds(deleteDoc(attendance));
    await assertSucceeds(setDoc(decline, declineData(participantId, {
      reason: "optional-and-client-defined",
    })));
  });

  test("the real client batch supports first responses and response changes", async () => {
    const participantDatabase = authenticatedFirestore(participantId);
    await assertSucceeds(commitResponseBatch(
      participantDatabase,
      "attending",
    ));
    await assertSucceeds(commitResponseBatch(
      participantDatabase,
      "declined",
    ));
    await assertSucceeds(commitResponseBatch(
      participantDatabase,
      "attending",
    ));

    const otherFriendDatabase = authenticatedFirestore(otherFriendId);
    await assertSucceeds(commitResponseBatch(
      otherFriendDatabase,
      "declined",
      otherFriendId,
    ));
    await assertFails(deleteDoc(declineReference(
      participantDatabase,
      otherFriendId,
    )));
  });

  test("owner and accepted friends can list both rosters without publication constraints", async () => {
    await seedAttendance(participantId);
    await seedDecline(otherFriendId);

    for (const userId of [ownerId, participantId, otherFriendId]) {
      const database = authenticatedFirestore(userId);
      await assertSucceeds(getDocs(collection(
        database,
        "users",
        ownerId,
        "events",
        eventId,
        "attendees",
      )));
      await assertSucceeds(getDocs(collection(
        database,
        "users",
        ownerId,
        "events",
        eventId,
        "declines",
      )));
    }
  });

  test("pending, revoking, stranger, and signed-out accounts cannot access rosters or respond", async () => {
    await seedAttendance(participantId);

    for (const userId of [pendingId, revokingId, strangerId]) {
      const database = authenticatedFirestore(userId);
      await assertFails(getDocs(collection(
        database,
        "users",
        ownerId,
        "events",
        eventId,
        "attendees",
      )));
      await assertFails(setDoc(
        attendanceReference(database, userId),
        attendanceData(userId),
      ));
      await assertFails(setDoc(
        declineReference(database, userId),
        declineData(userId),
      ));
      await assertFails(deleteDoc(declineReference(database, userId)));
    }

    const signedOut = testEnvironment.unauthenticatedContext().firestore();
    await assertFails(getDocs(collection(
      signedOut,
      "users",
      ownerId,
      "events",
      eventId,
      "attendees",
    )));
  });

  test("a participant cannot answer for another account or the organizer", async () => {
    const participantDatabase = authenticatedFirestore(participantId);
    await assertFails(setDoc(
      attendanceReference(participantDatabase),
      attendanceData(otherFriendId),
    ));

    const ownerDatabase = authenticatedFirestore(ownerId);
    await assertFails(setDoc(
      attendanceReference(ownerDatabase, ownerId),
      attendanceData(ownerId),
    ));
  });

  test("an accepted friend cannot create a response for a missing event", async () => {
    await testEnvironment.withSecurityRulesDisabled(async (context) => {
      await deleteDoc(eventReference(context.firestore()));
    });

    const database = authenticatedFirestore(participantId);
    await assertFails(deleteDoc(attendanceReference(database)));
    await assertFails(deleteDoc(declineReference(database)));
    await assertFails(commitResponseBatch(database, "attending"));
    await assertFails(commitResponseBatch(database, "declined"));
  });

  test("revocation cuts roster and write access but preserves self-cleanup", async () => {
    await seedAttendance(revokingId);
    const database = authenticatedFirestore(revokingId);
    const ownAttendance = attendanceReference(database, revokingId);

    await assertFails(getDocs(collection(
      database,
      "users",
      ownerId,
      "events",
      eventId,
      "attendees",
    )));
    await assertSucceeds(getDoc(ownAttendance));
    await assertFails(updateDoc(ownAttendance, { stale: false }));
    await assertSucceeds(deleteDoc(ownAttendance));
  });

  test("the organizer can remove responses but cannot impersonate participants", async () => {
    await seedAttendance(participantId);
    await seedDecline(otherFriendId);
    const database = authenticatedFirestore(ownerId);

    await assertSucceeds(deleteDoc(attendanceReference(database)));
    await assertSucceeds(deleteDoc(declineReference(database, otherFriendId)));
    await assertFails(setDoc(
      attendanceReference(database),
      attendanceData(participantId),
    ));
  });

  test("account cleanup can query only the signed-in participant's responses", async () => {
    await seedAttendance(participantId);
    await seedAttendance(otherFriendId);
    await seedDecline(participantId);

    const database = authenticatedFirestore(participantId);
    const ownAttendances = query(
      collectionGroup(database, "attendees"),
      where("participantId", "==", participantId),
    );
    const ownDeclines = query(
      collectionGroup(database, "declines"),
      where("participantId", "==", participantId),
    );
    await assertSucceeds(getDocs(ownAttendances));
    await assertSucceeds(getDocs(ownDeclines));
    await assertFails(getDocs(collectionGroup(database, "attendees")));
    await assertFails(getDocs(query(
      collectionGroup(database, "attendees"),
      where("participantId", "==", otherFriendId),
    )));
  });
});
