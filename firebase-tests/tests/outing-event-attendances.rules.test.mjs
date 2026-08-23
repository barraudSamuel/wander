import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { after, before, beforeEach, describe, test } from "node:test";
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from "@firebase/rules-unit-testing";
import {
  GeoPoint,
  Timestamp,
  collection,
  collectionGroup,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  query,
  serverTimestamp,
  setDoc,
  where,
} from "firebase/firestore";

const projectId = "demo-wander";
const ownerId = "owner";
const participantId = "participant";
const otherParticipantId = "other-participant";
const nonParticipantId = "non-participant";
const strangerId = "stranger";
const appleClaims = {
  firebase: { sign_in_provider: "apple.com" },
};

const profiles = {
  [ownerId]: { displayName: "Organisateur", avatarID: "radar-face" },
  [participantId]: { displayName: "Léa", avatarID: "radiant-eye" },
  [otherParticipantId]: { displayName: "Noah", avatarID: "star-eye" },
  [nonParticipantId]: { displayName: "Mina", avatarID: "cyclops-crown" },
  [strangerId]: { displayName: "Inconnu", avatarID: "skull" },
};

let testEnvironment;

function authenticatedFirestore(userId) {
  return testEnvironment.authenticatedContext(userId, appleClaims).firestore();
}

function eventData(eventId, publicationId) {
  return {
    eventId,
    ownerId,
    publicationId,
    displayName: profiles[ownerId].displayName,
    placeName: "Namsan Seoul Tower",
    category: "coffee",
    location: new GeoPoint(37.5512, 126.9882),
    plannedAt: Timestamp.fromMillis(Date.now() + 60 * 60 * 1000),
    publishedAt: Timestamp.now(),
    updatedAt: Timestamp.now(),
    timeZoneIdentifier: "Asia/Seoul",
  };
}

function attendanceId(publicationId, userId = participantId) {
  return `${publicationId}__${userId}`;
}

function attendanceData(
  eventId,
  publicationId,
  userId = participantId,
  overrides = {},
) {
  return {
    eventId,
    participantId: userId,
    publicationId,
    displayName: profiles[userId].displayName,
    avatarID: profiles[userId].avatarID,
    joinedAt: serverTimestamp(),
    ...overrides,
  };
}

function attendanceReference(
  database,
  eventId,
  publicationId,
  userId = participantId,
) {
  return doc(
    database,
    "users",
    ownerId,
    "events",
    eventId,
    "attendees",
    attendanceId(publicationId, userId),
  );
}

async function seedEvent(eventId, publicationId) {
  await testEnvironment.withSecurityRulesDisabled(async (context) => {
    await setDoc(
      doc(context.firestore(), "users", ownerId, "events", eventId),
      eventData(eventId, publicationId),
    );
  });
}

async function seedFriendship(userId, status = "accepted") {
  const participants = [ownerId, userId].sort();
  await testEnvironment.withSecurityRulesDisabled(async (context) => {
    await setDoc(
      doc(context.firestore(), "friendships", participants.join("__")),
      {
        participants,
        requestedBy: ownerId,
        status,
        createdAt: Timestamp.now(),
        ...(status === "accepted" ? { acceptedAt: Timestamp.now() } : {}),
      },
    );
  });
}

async function seedAttendance(
  eventId,
  publicationId,
  userId = participantId,
) {
  await testEnvironment.withSecurityRulesDisabled(async (context) => {
    await setDoc(
      attendanceReference(
        context.firestore(),
        eventId,
        publicationId,
        userId,
      ),
      {
        ...attendanceData(eventId, publicationId, userId),
        joinedAt: Timestamp.now(),
      },
    );
  });
}

function currentAttendancesQuery(database, eventId, publicationId) {
  return query(
    collection(
      database,
      "users",
      ownerId,
      "events",
      eventId,
      "attendees",
    ),
    where("publicationId", "==", publicationId),
  );
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
    await Promise.all(Object.entries(profiles).map(([userId, profile]) =>
      setDoc(doc(context.firestore(), "users", userId), {
        ...profile,
        friendCode: `CODE${userId.replaceAll("-", "").toUpperCase()}ZZ`
          .slice(0, 12),
        profileColorHex: "#123456",
        createdAt: Timestamp.now(),
        updatedAt: Timestamp.now(),
      })
    ));
  });
});

after(async () => {
  await testEnvironment.cleanup();
});

describe("users/{ownerID}/events/{eventID}/attendees", () => {
  test("an accepted friend can create, read, and delete their attendance", async () => {
    const eventId = crypto.randomUUID();
    const publicationId = crypto.randomUUID();
    await seedEvent(eventId, publicationId);
    await seedFriendship(participantId);
    const database = authenticatedFirestore(participantId);
    const reference = attendanceReference(database, eventId, publicationId);

    await assertSucceeds(
      setDoc(reference, attendanceData(eventId, publicationId)),
    );
    await assertSucceeds(getDoc(reference));
    await assertSucceeds(deleteDoc(reference));
  });

  test("the owner can list and remove attendance per event", async () => {
    const firstEventId = crypto.randomUUID();
    const secondEventId = crypto.randomUUID();
    const firstPublicationId = crypto.randomUUID();
    const secondPublicationId = crypto.randomUUID();
    await seedEvent(firstEventId, firstPublicationId);
    await seedEvent(secondEventId, secondPublicationId);
    await seedAttendance(firstEventId, firstPublicationId);
    await seedAttendance(
      secondEventId,
      secondPublicationId,
      otherParticipantId,
    );

    const database = authenticatedFirestore(ownerId);
    const firstSnapshot = await assertSucceeds(getDocs(
      currentAttendancesQuery(database, firstEventId, firstPublicationId),
    ));
    assert.deepEqual(
      firstSnapshot.docs.map((document) => document.data().eventId),
      [firstEventId],
    );
    await assertSucceeds(deleteDoc(attendanceReference(
      database,
      firstEventId,
      firstPublicationId,
    )));

    const secondSnapshot = await assertSucceeds(getDocs(
      currentAttendancesQuery(database, secondEventId, secondPublicationId),
    ));
    assert.equal(secondSnapshot.size, 1);
  });

  test("an event update preserves attendance for the stable publication", async () => {
    const eventId = crypto.randomUUID();
    const publicationId = crypto.randomUUID();
    await seedEvent(eventId, publicationId);
    await seedFriendship(participantId);
    await seedAttendance(eventId, publicationId);

    const ownerDatabase = authenticatedFirestore(ownerId);
    await assertSucceeds(setDoc(
      doc(ownerDatabase, "users", ownerId, "events", eventId),
      {
        ...eventData(eventId, publicationId),
        category: "meal",
        publishedAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      },
    ));

    const participantDatabase = authenticatedFirestore(participantId);
    const reference = attendanceReference(
      participantDatabase,
      eventId,
      publicationId,
    );
    const snapshot = await assertSucceeds(getDoc(reference));
    assert.equal(snapshot.exists(), true);
    assert.equal(snapshot.data().publicationId, publicationId);
  });

  test("current participants can list peers but non-participants cannot", async () => {
    const eventId = crypto.randomUUID();
    const publicationId = crypto.randomUUID();
    await seedEvent(eventId, publicationId);
    await seedFriendship(participantId);
    await seedFriendship(otherParticipantId);
    await seedFriendship(nonParticipantId);
    await seedAttendance(eventId, publicationId, participantId);
    await seedAttendance(eventId, publicationId, otherParticipantId);

    const participantSnapshot = await assertSucceeds(getDocs(
      currentAttendancesQuery(
        authenticatedFirestore(participantId),
        eventId,
        publicationId,
      ),
    ));
    assert.equal(participantSnapshot.size, 2);

    await assertFails(getDocs(currentAttendancesQuery(
      authenticatedFirestore(nonParticipantId),
      eventId,
      publicationId,
    )));
  });

  test("attendance cannot target another event or publication", async () => {
    const eventId = crypto.randomUUID();
    const publicationId = crypto.randomUUID();
    await seedEvent(eventId, publicationId);
    await seedFriendship(participantId);
    const database = authenticatedFirestore(participantId);
    const reference = attendanceReference(database, eventId, publicationId);

    await assertFails(setDoc(
      reference,
      attendanceData(crypto.randomUUID(), publicationId),
    ));
    await assertFails(setDoc(
      reference,
      attendanceData(eventId, crypto.randomUUID()),
    ));
    await assertFails(setDoc(
      reference,
      attendanceData(eventId, publicationId, participantId, {
        expiresAt: Timestamp.now(),
      }),
    ));
  });

  test("strangers, owners, and spoofed participants cannot join", async () => {
    const eventId = crypto.randomUUID();
    const publicationId = crypto.randomUUID();
    await seedEvent(eventId, publicationId);

    await assertFails(setDoc(
      attendanceReference(
        authenticatedFirestore(strangerId),
        eventId,
        publicationId,
        strangerId,
      ),
      attendanceData(eventId, publicationId, strangerId),
    ));
    await assertFails(setDoc(
      attendanceReference(
        authenticatedFirestore(ownerId),
        eventId,
        publicationId,
        ownerId,
      ),
      attendanceData(eventId, publicationId, ownerId),
    ));

    await seedFriendship(participantId);
    await assertFails(setDoc(
      attendanceReference(
        authenticatedFirestore(participantId),
        eventId,
        publicationId,
      ),
      attendanceData(eventId, publicationId, participantId, {
        participantId: otherParticipantId,
      }),
    ));
  });

  test("a revoked participant loses list access but can leave", async () => {
    const eventId = crypto.randomUUID();
    const publicationId = crypto.randomUUID();
    await seedEvent(eventId, publicationId);
    await seedFriendship(participantId);
    await seedAttendance(eventId, publicationId, participantId);
    const database = authenticatedFirestore(participantId);
    const attendances = currentAttendancesQuery(
      database,
      eventId,
      publicationId,
    );
    const reference = attendanceReference(database, eventId, publicationId);
    await assertSucceeds(getDocs(attendances));

    await testEnvironment.withSecurityRulesDisabled(async (context) => {
      const participants = [ownerId, participantId].sort();
      await deleteDoc(doc(
        context.firestore(),
        "friendships",
        participants.join("__"),
      ));
    });
    await assertFails(getDocs(attendances));
    await assertSucceeds(deleteDoc(reference));
  });

  test("account cleanup can query only the signed-in participant's records", async () => {
    const eventId = crypto.randomUUID();
    const publicationId = crypto.randomUUID();
    await seedEvent(eventId, publicationId);
    await seedAttendance(eventId, publicationId, participantId);
    await seedAttendance(eventId, publicationId, otherParticipantId);

    const database = authenticatedFirestore(participantId);
    const ownRecords = query(
      collectionGroup(database, "attendees"),
      where("participantId", "==", participantId),
    );
    const snapshot = await assertSucceeds(getDocs(ownRecords));
    assert.equal(snapshot.size, 1);

    await assertFails(getDocs(query(
      collectionGroup(database, "attendees"),
      where("participantId", "==", otherParticipantId),
    )));
  });
});
