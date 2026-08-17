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
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  serverTimestamp,
  setDoc,
} from "firebase/firestore";

const projectId = "demo-wander";
const ownerId = "owner";
const friendId = "friend";
const pendingFriendId = "pending-friend";
const strangerId = "stranger";
const appleClaims = {
  firebase: { sign_in_provider: "apple.com" },
};

let testEnvironment;

function authenticatedFirestore(userId) {
  return testEnvironment.authenticatedContext(userId, appleClaims).firestore();
}

function eventReference(database, eventId, expectedOwnerId = ownerId) {
  return doc(database, "users", expectedOwnerId, "events", eventId);
}

function eventData(eventId, overrides = {}) {
  return {
    eventId,
    ownerId,
    publicationId: crypto.randomUUID(),
    displayName: "Samuel",
    placeName: "Gyeongbokgung Palace",
    category: "coffee",
    address: "161 Sajik-ro, Jongno-gu",
    location: new GeoPoint(37.5796, 126.977),
    plannedAt: Timestamp.fromMillis(Date.now() + 60 * 60 * 1000),
    publishedAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
    timeZoneIdentifier: "Asia/Seoul",
    ...overrides,
  };
}

async function seedProfile(userId, overrides = {}) {
  await testEnvironment.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), "users", userId), {
      displayName: userId === ownerId ? "Samuel" : "Ami",
      avatarID: "radar-face",
      friendCode: `CODE${userId.replaceAll("-", "").toUpperCase()}ZZ`
        .slice(0, 12),
      profileColorHex: "#123456",
      createdAt: Timestamp.now(),
      updatedAt: Timestamp.now(),
      ...overrides,
    });
  });
}

async function seedEvent(eventId, overrides = {}) {
  const data = eventData(eventId, overrides);
  await testEnvironment.withSecurityRulesDisabled(async (context) => {
    await setDoc(eventReference(context.firestore(), eventId), {
      ...data,
      publishedAt: Timestamp.now(),
      updatedAt: Timestamp.now(),
    });
  });
  return data;
}

async function seedFriendship(userId, status) {
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
  await seedProfile(ownerId);
});

after(async () => {
  await testEnvironment.cleanup();
});

describe("users/{ownerID}/events/{eventID}", () => {
  test("the owner can keep multiple events and change them independently", async () => {
    const database = authenticatedFirestore(ownerId);
    const firstEventId = crypto.randomUUID();
    const secondEventId = crypto.randomUUID();
    const firstReference = eventReference(database, firstEventId);
    const secondReference = eventReference(database, secondEventId);

    await assertSucceeds(setDoc(firstReference, eventData(firstEventId)));
    await assertSucceeds(setDoc(secondReference, eventData(secondEventId)));

    const snapshot = await assertSucceeds(
      getDocs(collection(database, "users", ownerId, "events")),
    );
    assert.deepEqual(
      snapshot.docs.map((document) => document.id).sort(),
      [firstEventId, secondEventId].sort(),
    );

    await assertSucceeds(setDoc(
      firstReference,
      eventData(firstEventId, { placeName: "Namsan Seoul Tower" }),
    ));
    await assertSucceeds(deleteDoc(firstReference));
    assert.equal((await assertSucceeds(getDoc(secondReference))).exists(), true);
  });

  test("an update preserves event identity and renews publication identity", async () => {
    const database = authenticatedFirestore(ownerId);
    const eventId = crypto.randomUUID();
    const publicationId = crypto.randomUUID();
    const reference = eventReference(database, eventId);

    await assertSucceeds(setDoc(
      reference,
      eventData(eventId, { publicationId }),
    ));
    await assertFails(setDoc(
      reference,
      eventData(eventId, { publicationId, placeName: "Bukchon" }),
    ));
    await assertFails(setDoc(
      reference,
      eventData(crypto.randomUUID(), { placeName: "Bukchon" }),
    ));
  });

  test("supported categories are accepted", async () => {
    const database = authenticatedFirestore(ownerId);
    const categories = [
      "coffee",
      "meal",
      "drinks",
      "walk",
      "culture",
      "sport",
      "other",
    ];

    for (const category of categories) {
      const eventId = crypto.randomUUID();
      await assertSucceeds(setDoc(
        eventReference(database, eventId),
        eventData(eventId, { category }),
      ));
    }
  });

  test("missing, unknown, and non-string categories are rejected", async () => {
    const database = authenticatedFirestore(ownerId);
    const missingCategoryEventId = crypto.randomUUID();
    const unknownCategoryEventId = crypto.randomUUID();
    const nonStringCategoryEventId = crypto.randomUUID();

    const { category: _category, ...missingCategoryEvent } = eventData(
      missingCategoryEventId,
    );
    await assertFails(setDoc(
      eventReference(database, missingCategoryEventId),
      missingCategoryEvent,
    ));
    await assertFails(setDoc(
      eventReference(database, unknownCategoryEventId),
      eventData(unknownCategoryEventId, { category: "party" }),
    ));
    await assertFails(setDoc(
      eventReference(database, nonStringCategoryEventId),
      eventData(nonStringCategoryEventId, { category: 42 }),
    ));
  });

  test("an accepted friend can list and read persistent owner events", async () => {
    const futureEventId = crypto.randomUUID();
    const pastEventId = crypto.randomUUID();
    await seedEvent(futureEventId);
    await seedEvent(pastEventId, {
      plannedAt: Timestamp.fromMillis(Date.now() - 24 * 60 * 60 * 1000),
    });
    await seedFriendship(friendId, "accepted");

    const database = authenticatedFirestore(friendId);
    const snapshot = await assertSucceeds(
      getDocs(collection(database, "users", ownerId, "events")),
    );
    assert.deepEqual(
      snapshot.docs.map((document) => document.id).sort(),
      [futureEventId, pastEventId].sort(),
    );
    await assertSucceeds(getDoc(eventReference(database, pastEventId)));
  });

  test("pending friends, strangers, and signed-out users cannot read", async () => {
    const eventId = crypto.randomUUID();
    await seedEvent(eventId);
    await seedFriendship(pendingFriendId, "pending");

    await assertFails(getDocs(collection(
      authenticatedFirestore(pendingFriendId),
      "users",
      ownerId,
      "events",
    )));
    await assertFails(
      getDoc(eventReference(authenticatedFirestore(strangerId), eventId)),
    );
    await assertFails(getDoc(eventReference(
      testEnvironment.unauthenticatedContext().firestore(),
      eventId,
    )));
  });

  test("another user and a non-Apple session cannot write", async () => {
    const eventId = crypto.randomUUID();
    await assertFails(setDoc(
      eventReference(authenticatedFirestore(strangerId), eventId),
      eventData(eventId),
    ));

    const passwordDatabase = testEnvironment.authenticatedContext(ownerId, {
      firebase: { sign_in_provider: "password" },
    }).firestore();
    await assertFails(setDoc(
      eventReference(passwordDatabase, eventId),
      eventData(eventId),
    ));
  });

  test("malformed identities, extra fields, and invalid dates are rejected", async () => {
    const database = authenticatedFirestore(ownerId);
    const eventId = crypto.randomUUID();
    const reference = eventReference(database, eventId);

    await assertFails(setDoc(
      reference,
      eventData(eventId, { eventId: crypto.randomUUID() }),
    ));
    await assertFails(setDoc(
      reference,
      eventData(eventId, { privateNote: "secret" }),
    ));
    await assertFails(setDoc(reference, eventData(eventId, {
      plannedAt: Timestamp.fromMillis(Date.now() + 25 * 60 * 60 * 1000),
    })));
    await assertFails(setDoc(
      reference,
      eventData(eventId, { expiresAt: Timestamp.now() }),
    ));
  });

  test("pending account deletion blocks changes but not cancellation", async () => {
    const eventId = crypto.randomUUID();
    await seedProfile(ownerId, { deletionRequestedAt: Timestamp.now() });

    const database = authenticatedFirestore(ownerId);
    const reference = eventReference(database, eventId);
    await assertFails(setDoc(reference, eventData(eventId)));

    await seedEvent(eventId);
    await assertSucceeds(deleteDoc(reference));
  });
});
