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
const otherFriendId = "other-friend";
const nonParticipantFriendId = "non-participant-friend";
const pendingFriendId = "pending-friend";
const strangerId = "stranger";
const appleClaims = {
  firebase: { sign_in_provider: "apple.com" },
};

let testEnvironment;

const profiles = {
  [ownerId]: { displayName: "Organisateur", avatarID: "radar-face" },
  [participantId]: { displayName: "Léa", avatarID: "radiant-eye" },
  [otherFriendId]: { displayName: "Noah", avatarID: "star-eye" },
  [nonParticipantFriendId]: {
    displayName: "Mina",
    avatarID: "cyclops-crown",
  },
  [pendingFriendId]: { displayName: "Jin", avatarID: "wave-hair" },
  [strangerId]: { displayName: "Inconnu", avatarID: "skull" },
};

function authenticatedFirestore(userId) {
  return testEnvironment.authenticatedContext(userId, appleClaims).firestore();
}

function planData(publicationId, overrides = {}) {
  const plannedAt = new Date(Date.now() + 60 * 60 * 1000);
  return {
    ownerId,
    publicationId,
    displayName: "Organisateur",
    placeName: "Namsan Seoul Tower",
    location: new GeoPoint(37.5512, 126.9882),
    plannedAt: Timestamp.fromDate(plannedAt),
    expiresAt: Timestamp.fromDate(
      new Date(plannedAt.getTime() + 2 * 60 * 60 * 1000),
    ),
    publishedAt: Timestamp.now(),
    updatedAt: Timestamp.now(),
    timeZoneIdentifier: "Asia/Seoul",
    ...overrides,
  };
}

function attendanceId(publicationId, userId = participantId) {
  return `${publicationId}__${userId}`;
}

function attendanceData(publicationId, expiresAt, overrides = {}) {
  return {
    participantId,
    publicationId,
    displayName: profiles[participantId].displayName,
    avatarID: profiles[participantId].avatarID,
    joinedAt: serverTimestamp(),
    expiresAt,
    ...overrides,
  };
}

function attendanceReference(
  database,
  publicationId,
  userId = participantId,
) {
  return doc(
    database,
    "plans",
    ownerId,
    "attendees",
    attendanceId(publicationId, userId),
  );
}

async function seedPlan(publicationId, overrides = {}) {
  const data = planData(publicationId, overrides);
  await testEnvironment.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), "plans", ownerId), data);
  });
  return data;
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

async function seedProfiles() {
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
}

async function seedAttendance(
  publicationId,
  expiresAt,
  userId = participantId,
) {
  const profile = profiles[userId];
  await testEnvironment.withSecurityRulesDisabled(async (context) => {
    await setDoc(
      attendanceReference(context.firestore(), publicationId, userId),
      {
        participantId: userId,
        publicationId,
        displayName: profile.displayName,
        avatarID: profile.avatarID,
        joinedAt: Timestamp.now(),
        expiresAt,
      },
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
    firestore: {
      host: "127.0.0.1",
      port: 8980,
      rules,
    },
  });
});

beforeEach(async () => {
  await testEnvironment.clearFirestore();
  await seedProfiles();
});

after(async () => {
  await testEnvironment.cleanup();
});

describe("plans/{ownerID}/attendees/{publicationID}__{participantID}", () => {
  test("an accepted friend can create, read, and delete their attendance", async () => {
    const publicationId = crypto.randomUUID();
    const plan = await seedPlan(publicationId);
    await seedFriendship(participantId);
    const reference = attendanceReference(
      authenticatedFirestore(participantId),
      publicationId,
    );

    await assertSucceeds(
      setDoc(reference, attendanceData(publicationId, plan.expiresAt)),
    );
    await assertSucceeds(getDoc(reference));
    await assertSucceeds(deleteDoc(reference));
  });

  test("the owner can list and remove attendances under their plan", async () => {
    const publicationId = crypto.randomUUID();
    const plan = await seedPlan(publicationId);
    await seedFriendship(participantId);
    await seedAttendance(publicationId, plan.expiresAt);

    const database = authenticatedFirestore(ownerId);
    const attendees = query(
      collection(database, "plans", ownerId, "attendees"),
      where("publicationId", "==", publicationId),
    );
    const snapshot = await assertSucceeds(getDocs(attendees));
    assert.equal(snapshot.size, 1);
    await assertSucceeds(
      deleteDoc(attendanceReference(database, publicationId)),
    );
  });

  test("only the owner and current participants can list participant avatars", async () => {
    const publicationId = crypto.randomUUID();
    const plan = await seedPlan(publicationId);
    await seedFriendship(participantId);
    await seedFriendship(otherFriendId);
    await seedFriendship(nonParticipantFriendId);
    await seedAttendance(publicationId, plan.expiresAt);

    const nonParticipantDatabase = authenticatedFirestore(
      nonParticipantFriendId,
    );
    await assertFails(
      getDoc(attendanceReference(nonParticipantDatabase, publicationId)),
    );
    await assertFails(
      getDocs(query(
        collection(
          nonParticipantDatabase,
          "plans",
          ownerId,
          "attendees",
        ),
        where("publicationId", "==", publicationId),
      )),
    );

    await seedAttendance(publicationId, plan.expiresAt, otherFriendId);
    const participantDatabase = authenticatedFirestore(otherFriendId);
    const currentParticipants = query(
      collection(participantDatabase, "plans", ownerId, "attendees"),
      where("publicationId", "==", publicationId),
    );
    const snapshot = await assertSucceeds(getDocs(currentParticipants));
    assert.equal(snapshot.size, 2);
    assert.deepEqual(
      snapshot.docs.map((document) => document.data().displayName).sort(),
      ["Léa", "Noah"],
    );
    await assertFails(
      getDocs(collection(
        participantDatabase,
        "plans",
        ownerId,
        "attendees",
      )),
    );

    await deleteDoc(
      attendanceReference(
        participantDatabase,
        publicationId,
        otherFriendId,
      ),
    );
    await assertFails(getDocs(currentParticipants));
  });

  test("a participant loses list access when friendship is revoked", async () => {
    const publicationId = crypto.randomUUID();
    const plan = await seedPlan(publicationId);
    await seedFriendship(participantId);
    await seedAttendance(publicationId, plan.expiresAt);
    const database = authenticatedFirestore(participantId);
    const currentParticipants = query(
      collection(database, "plans", ownerId, "attendees"),
      where("publicationId", "==", publicationId),
    );
    await assertSucceeds(getDocs(currentParticipants));

    await testEnvironment.withSecurityRulesDisabled(async (context) => {
      const participants = [ownerId, participantId].sort();
      await deleteDoc(
        doc(
          context.firestore(),
          "friendships",
          participants.join("__"),
        ),
      );
    });

    await assertFails(getDocs(currentParticipants));
  });

  test("pending friends, strangers, owners, and signed-out users cannot join", async (t) => {
    const publicationId = crypto.randomUUID();
    const plan = await seedPlan(publicationId);
    await seedFriendship(pendingFriendId, "pending");

    await t.test("pending friend", async () => {
      const reference = attendanceReference(
        authenticatedFirestore(pendingFriendId),
        publicationId,
        pendingFriendId,
      );
      await assertFails(
        setDoc(
          reference,
          attendanceData(publicationId, plan.expiresAt, {
            participantId: pendingFriendId,
          }),
        ),
      );
    });

    await t.test("stranger", async () => {
      const reference = attendanceReference(
        authenticatedFirestore(strangerId),
        publicationId,
        strangerId,
      );
      await assertFails(
        setDoc(
          reference,
          attendanceData(publicationId, plan.expiresAt, {
            participantId: strangerId,
          }),
        ),
      );
    });

    await t.test("owner", async () => {
      const reference = attendanceReference(
        authenticatedFirestore(ownerId),
        publicationId,
        ownerId,
      );
      await assertFails(
        setDoc(
          reference,
          attendanceData(publicationId, plan.expiresAt, {
            participantId: ownerId,
          }),
        ),
      );
    });

    await t.test("signed-out user", async () => {
      const database = testEnvironment.unauthenticatedContext().firestore();
      await assertFails(
        setDoc(
          attendanceReference(database, publicationId),
          attendanceData(publicationId, plan.expiresAt),
        ),
      );
    });
  });

  test("spoofed and malformed attendance documents are rejected", async (t) => {
    const publicationId = crypto.randomUUID();
    const plan = await seedPlan(publicationId);
    await seedFriendship(participantId);
    const database = authenticatedFirestore(participantId);
    const reference = attendanceReference(database, publicationId);

    await t.test("spoofed participant", async () => {
      await assertFails(
        setDoc(
          reference,
          attendanceData(publicationId, plan.expiresAt, {
            participantId: otherFriendId,
          }),
        ),
      );
    });

    await t.test("mismatched publication", async () => {
      await assertFails(
        setDoc(
          reference,
          attendanceData(crypto.randomUUID(), plan.expiresAt),
        ),
      );
    });

    await t.test("mismatched expiration", async () => {
      await assertFails(
        setDoc(
          reference,
          attendanceData(
            publicationId,
            Timestamp.fromDate(new Date(Date.now() + 30 * 60 * 1000)),
          ),
        ),
      );
    });

    await t.test("extra field", async () => {
      await assertFails(
        setDoc(
          reference,
          attendanceData(publicationId, plan.expiresAt, { note: "private" }),
        ),
      );
    });

    await t.test("spoofed display name", async () => {
      await assertFails(
        setDoc(
          reference,
          attendanceData(publicationId, plan.expiresAt, {
            displayName: "Quelqu’un d’autre",
          }),
        ),
      );
    });

    await t.test("spoofed avatar", async () => {
      await assertFails(
        setDoc(
          reference,
          attendanceData(publicationId, plan.expiresAt, {
            avatarID: "skull",
          }),
        ),
      );
    });
  });

  test("an attendance cannot be updated", async () => {
    const publicationId = crypto.randomUUID();
    const plan = await seedPlan(publicationId);
    await seedFriendship(participantId);
    await seedAttendance(publicationId, plan.expiresAt);

    await assertFails(
      setDoc(
        attendanceReference(
          authenticatedFirestore(participantId),
          publicationId,
        ),
        attendanceData(publicationId, plan.expiresAt),
      ),
    );
  });

  test("joining an expired plan is rejected", async () => {
    const publicationId = crypto.randomUUID();
    const expiredAt = Timestamp.fromDate(new Date(Date.now() - 60 * 1000));
    await seedPlan(publicationId, { expiresAt: expiredAt });
    await seedFriendship(participantId);

    await assertFails(
      setDoc(
        attendanceReference(
          authenticatedFirestore(participantId),
          publicationId,
        ),
        attendanceData(publicationId, expiredAt),
      ),
    );
  });

  test("a former friend can still remove their existing attendance", async () => {
    const publicationId = crypto.randomUUID();
    const plan = await seedPlan(publicationId);
    await seedFriendship(participantId);
    await seedAttendance(publicationId, plan.expiresAt);

    await testEnvironment.withSecurityRulesDisabled(async (context) => {
      const participants = [ownerId, participantId].sort();
      await deleteDoc(
        doc(
          context.firestore(),
          "friendships",
          participants.join("__"),
        ),
      );
    });

    await assertSucceeds(
      deleteDoc(
        attendanceReference(
          authenticatedFirestore(participantId),
          publicationId,
        ),
      ),
    );
  });

  test("account cleanup can query only the authenticated user's attendances", async () => {
    const publicationId = crypto.randomUUID();
    const plan = await seedPlan(publicationId);
    await seedFriendship(participantId);
    await seedAttendance(publicationId, plan.expiresAt);

    const ownAttendances = query(
      collectionGroup(authenticatedFirestore(participantId), "attendees"),
      where("participantId", "==", participantId),
    );
    const snapshot = await assertSucceeds(getDocs(ownAttendances));
    assert.equal(snapshot.size, 1);

    const foreignAttendances = query(
      collectionGroup(authenticatedFirestore(strangerId), "attendees"),
      where("participantId", "==", participantId),
    );
    await assertFails(getDocs(foreignAttendances));
  });

  test("a new publication accepts a new response without reusing the old one", async () => {
    const oldPublicationId = crypto.randomUUID();
    const oldPlan = await seedPlan(oldPublicationId);
    await seedFriendship(participantId);
    await seedAttendance(oldPublicationId, oldPlan.expiresAt);

    const newPublicationId = crypto.randomUUID();
    const newPlan = await seedPlan(newPublicationId);
    const database = authenticatedFirestore(participantId);
    await assertSucceeds(
      setDoc(
        attendanceReference(database, newPublicationId),
        attendanceData(newPublicationId, newPlan.expiresAt),
      ),
    );

    await assertSucceeds(
      getDoc(attendanceReference(database, oldPublicationId)),
    );
    await assertSucceeds(
      getDoc(attendanceReference(database, newPublicationId)),
    );
  });
});
