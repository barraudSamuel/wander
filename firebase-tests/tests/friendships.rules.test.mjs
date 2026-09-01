import { readFile } from "node:fs/promises";
import { after, before, beforeEach, describe, test } from "node:test";
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from "@firebase/rules-unit-testing";
import {
  Timestamp,
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  query,
  setDoc,
  updateDoc,
  where,
} from "firebase/firestore";

const projectId = "demo-wander-friendships";
const aliceId = "alice";
const bobId = "bob";
const malloryId = "mallory";
const pairId = `${aliceId}__${bobId}`;

let testEnvironment;

function authenticatedFirestore(userId) {
  return testEnvironment.authenticatedContext(userId).firestore();
}

function friendshipReference(database) {
  return doc(database, "friendships", pairId);
}

function friendshipData(status = "pending", overrides = {}) {
  return {
    participants: [aliceId, bobId],
    requestedBy: aliceId,
    status,
    createdAt: Timestamp.fromMillis(1_000),
    ...(status === "accepted" || status === "revoking"
      ? { acceptedAt: Timestamp.fromMillis(2_000) }
      : {}),
    ...(status === "revoking"
      ? { revokedAt: Timestamp.fromMillis(3_000) }
      : {}),
    ...overrides,
  };
}

async function seedFriendship(status) {
  await testEnvironment.withSecurityRulesDisabled(async (context) => {
    await setDoc(
      friendshipReference(context.firestore()),
      friendshipData(status),
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
});

after(async () => {
  await testEnvironment.cleanup();
});

describe("friendship consent", () => {
  test("a requester can inspect an absent pair and create a flexible pending request", async () => {
    const database = authenticatedFirestore(aliceId);
    const reference = friendshipReference(database);

    const missing = await assertSucceeds(getDoc(reference));
    if (missing.exists()) throw new Error("expected an absent friendship");

    await assertSucceeds(setDoc(reference, friendshipData("pending", {
      clientVersion: 42,
      createdAt: "legacy-client-time",
    })));
    await assertSucceeds(getDoc(reference));
  });

  test("a requester cannot self-grant accepted access or create a foreign pair", async () => {
    const aliceDatabase = authenticatedFirestore(aliceId);

    await assertFails(setDoc(
      friendshipReference(aliceDatabase),
      friendshipData("accepted"),
    ));
    await assertFails(setDoc(
      doc(aliceDatabase, "friendships", `${bobId}__${malloryId}`),
      {
        participants: [bobId, malloryId],
        requestedBy: bobId,
        status: "pending",
      },
    ));
  });

  test("only the recipient can accept and friendship identity stays immutable", async () => {
    await seedFriendship("pending");

    await assertFails(updateDoc(
      friendshipReference(authenticatedFirestore(aliceId)),
      { status: "accepted", acceptedAt: "client-time" },
    ));
    await assertSucceeds(updateDoc(
      friendshipReference(authenticatedFirestore(bobId)),
      {
        status: "accepted",
        acceptedAt: "client-time",
        compatibleExtraField: true,
      },
    ));
    await assertFails(updateDoc(
      friendshipReference(authenticatedFirestore(bobId)),
      {
        participants: [aliceId, malloryId],
        status: "revoking",
      },
    ));
  });

  test("either accepted participant can revoke but nobody can restore", async () => {
    await seedFriendship("accepted");
    const reference = friendshipReference(authenticatedFirestore(aliceId));

    await assertSucceeds(updateDoc(reference, {
      status: "revoking",
      revokedAt: "client-or-server-time",
      cleanupRevision: 1,
    }));
    await assertFails(updateDoc(reference, { status: "accepted" }));
  });

  test("pending requests are deletable while accepted pairs require account cleanup", async () => {
    await seedFriendship("pending");
    await assertSucceeds(deleteDoc(
      friendshipReference(authenticatedFirestore(bobId)),
    ));

    await seedFriendship("accepted");
    await assertFails(deleteDoc(
      friendshipReference(authenticatedFirestore(aliceId)),
    ));
    await assertSucceeds(setDoc(
      doc(authenticatedFirestore(aliceId), "users", aliceId),
      { deletionRequestedAt: "flexible-marker" },
    ));
    await assertSucceeds(deleteDoc(
      friendshipReference(authenticatedFirestore(aliceId)),
    ));
  });

  test("friendship reads remain participant-only", async () => {
    await seedFriendship("accepted");

    await assertSucceeds(getDoc(
      friendshipReference(authenticatedFirestore(aliceId)),
    ));
    await assertFails(getDoc(
      friendshipReference(authenticatedFirestore(malloryId)),
    ));

    const aliceQuery = query(
      collection(authenticatedFirestore(aliceId), "friendships"),
      where("participants", "array-contains", aliceId),
    );
    await assertSucceeds(getDocs(aliceQuery));
    await assertFails(getDocs(collection(
      authenticatedFirestore(aliceId),
      "friendships",
    )));
  });

  test("signed-out clients cannot read or create friendships", async () => {
    const database = testEnvironment.unauthenticatedContext().firestore();

    await assertFails(getDoc(friendshipReference(database)));
    await assertFails(setDoc(
      friendshipReference(database),
      friendshipData("pending"),
    ));
  });
});
