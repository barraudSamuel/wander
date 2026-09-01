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

const projectId = "demo-wander-social-access";
const ownerId = "social-owner";
const friendId = "social-friend";
const pendingId = "social-pending";
const revokingId = "social-revoking";
const strangerId = "social-stranger";
const cellId = "future-cell-format";

let testEnvironment;

function authenticatedFirestore(userId) {
  return testEnvironment.authenticatedContext(userId).firestore();
}

function locationReference(database, userId = ownerId) {
  return doc(database, "locations", userId);
}

function cellReference(database, userId = ownerId) {
  return doc(database, "explorations", userId, "cells", cellId);
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

describe("map and exploration social access", () => {
  test("the owner can write flexible location and exploration payloads", async () => {
    const database = authenticatedFirestore(ownerId);

    await assertSucceeds(setDoc(locationReference(database), {
      coordinateV2: { latitude: "future", longitude: "format" },
      sampledAt: "client-defined",
      extraField: true,
    }));
    await assertSucceeds(updateDoc(locationReference(database), {
      presenceModelV3: { entered: true },
    }));
    await assertSucceeds(setDoc(cellReference(database), {
      sharedAt: "legacy-or-future-time",
      metadata: { source: "next-client" },
    }));
    await assertSucceeds(deleteDoc(cellReference(database)));
  });

  test("accepted friends can read map data and explorations", async () => {
    await testEnvironment.withSecurityRulesDisabled(async (context) => {
      await setDoc(locationReference(context.firestore()), { private: true });
      await setDoc(cellReference(context.firestore()), { private: true });
    });

    const database = authenticatedFirestore(friendId);
    await assertSucceeds(getDoc(locationReference(database)));
    await assertSucceeds(getDoc(cellReference(database)));
    await assertSucceeds(getDocs(collection(
      database,
      "explorations",
      ownerId,
      "cells",
    )));
  });

  test("pending, revoking, stranger, and signed-out accounts cannot see map data", async () => {
    await testEnvironment.withSecurityRulesDisabled(async (context) => {
      await setDoc(locationReference(context.firestore()), { private: true });
      await setDoc(cellReference(context.firestore()), { private: true });
    });

    for (const userId of [pendingId, revokingId, strangerId]) {
      const database = authenticatedFirestore(userId);
      await assertFails(getDoc(locationReference(database)));
      await assertFails(getDoc(cellReference(database)));
      await assertFails(getDocs(collection(
        database,
        "explorations",
        ownerId,
        "cells",
      )));
    }

    const signedOut = testEnvironment.unauthenticatedContext().firestore();
    await assertFails(getDoc(locationReference(signedOut)));
    await assertFails(getDoc(cellReference(signedOut)));
  });

  test("friends cannot overwrite another account's map data", async () => {
    const database = authenticatedFirestore(friendId);

    await assertFails(setDoc(locationReference(database), { spoofed: true }));
    await assertFails(setDoc(cellReference(database), { spoofed: true }));
    await assertFails(deleteDoc(locationReference(database)));
  });

  test("global location lists stay disabled", async () => {
    await assertFails(getDocs(collection(
      authenticatedFirestore(ownerId),
      "locations",
    )));
  });
});
