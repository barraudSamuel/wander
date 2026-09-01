import { readFile } from "node:fs/promises";
import { after, before, beforeEach, describe, test } from "node:test";
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from "@firebase/rules-unit-testing";
import {
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  setDoc,
  updateDoc,
} from "firebase/firestore";

const projectId = "demo-wander-events";
const ownerId = "event-owner";
const friendId = "event-friend";
const pendingId = "event-pending";
const revokingId = "event-revoking";
const strangerId = "event-stranger";
const eventId = "legacy-or-future-event-id";

let testEnvironment;

function authenticatedFirestore(userId) {
  return testEnvironment.authenticatedContext(userId).firestore();
}

function eventReference(database, userId = ownerId) {
  return doc(database, "users", userId, "events", eventId);
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
  await Promise.all([
    seedFriendship(friendId, "accepted"),
    seedFriendship(pendingId, "pending"),
    seedFriendship(revokingId, "revoking"),
  ]);
});

after(async () => {
  await testEnvironment.cleanup();
});

describe("users/{ownerId}/events", () => {
  test("the owner can evolve an event payload without a rules deployment", async () => {
    const database = authenticatedFirestore(ownerId);
    const reference = eventReference(database);

    await assertSucceeds(setDoc(reference, {
      legacyName: "Sortie",
      category: "future-category",
      arbitraryDateRepresentation: "tomorrow",
      nestedFuturePayload: { version: 8 },
    }));
    await assertSucceeds(updateDoc(reference, {
      anotherNewField: ["supported", "by", "client"],
    }));
    await assertSucceeds(getDoc(reference));
    await assertSucceeds(getDocs(collection(
      database,
      "users",
      ownerId,
      "events",
    )));
    await assertSucceeds(deleteDoc(reference));
  });

  test("accepted friends can read and list events without field constraints", async () => {
    await testEnvironment.withSecurityRulesDisabled(async (context) => {
      await setDoc(eventReference(context.firestore()), { unknownShape: true });
    });

    const database = authenticatedFirestore(friendId);
    await assertSucceeds(getDoc(eventReference(database)));
    await assertSucceeds(getDocs(collection(
      database,
      "users",
      ownerId,
      "events",
    )));
  });

  test("pending, revoking, stranger, and signed-out accounts cannot read events", async () => {
    await testEnvironment.withSecurityRulesDisabled(async (context) => {
      await setDoc(eventReference(context.firestore()), { place: "private" });
    });

    for (const userId of [pendingId, revokingId, strangerId]) {
      const database = authenticatedFirestore(userId);
      await assertFails(getDoc(eventReference(database)));
      await assertFails(getDocs(collection(
        database,
        "users",
        ownerId,
        "events",
      )));
    }

    const signedOut = testEnvironment.unauthenticatedContext().firestore();
    await assertFails(getDoc(eventReference(signedOut)));
  });

  test("friends and strangers cannot write another owner's event", async () => {
    await testEnvironment.withSecurityRulesDisabled(async (context) => {
      await setDoc(eventReference(context.firestore()), { place: "private" });
    });

    for (const userId of [friendId, strangerId]) {
      const database = authenticatedFirestore(userId);
      await assertFails(setDoc(eventReference(database), { overwritten: true }));
      await assertFails(updateDoc(eventReference(database), { overwritten: true }));
      await assertFails(deleteDoc(eventReference(database)));
    }
  });
});
