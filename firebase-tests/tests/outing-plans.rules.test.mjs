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

function planData(overrides = {}) {
  const plannedAt = new Date(Date.now() + 60 * 60 * 1000);
  return {
    ownerId,
    publicationId: crypto.randomUUID(),
    displayName: "Samuel",
    placeName: "Gyeongbokgung Palace",
    address: "161 Sajik-ro, Jongno-gu",
    location: new GeoPoint(37.5796, 126.977),
    plannedAt: Timestamp.fromDate(plannedAt),
    expiresAt: Timestamp.fromDate(
      new Date(plannedAt.getTime() + 2 * 60 * 60 * 1000),
    ),
    publishedAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
    timeZoneIdentifier: "Asia/Seoul",
    ...overrides,
  };
}

async function seedPlan(data = planData()) {
  await testEnvironment.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), "plans", ownerId), {
      ...data,
      publishedAt: Timestamp.now(),
      updatedAt: Timestamp.now(),
    });
  });
}

async function seedFriendship(userId, status) {
  const participants = [ownerId, userId].sort();
  const pairId = participants.join("__");
  await testEnvironment.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), "friendships", pairId), {
      participants,
      requestedBy: ownerId,
      status,
      createdAt: Timestamp.now(),
      ...(status === "accepted" ? { acceptedAt: Timestamp.now() } : {}),
    });
  });
}

before(async () => {
  const rules = await readFile(new URL("../../firestore.rules", import.meta.url), "utf8");
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
});

after(async () => {
  await testEnvironment.cleanup();
});

describe("plans/{userID}", () => {
  test("the owner can create, replace, read, and delete a plan", async () => {
    const database = authenticatedFirestore(ownerId);
    const reference = doc(database, "plans", ownerId);

    await assertSucceeds(setDoc(reference, planData()));
    await assertSucceeds(getDoc(reference));
    await assertSucceeds(
      setDoc(reference, planData({ placeName: "Namsan Seoul Tower" })),
    );
    await assertSucceeds(deleteDoc(reference));
  });

  test("an accepted friend can read the plan by its direct path", async () => {
    await seedPlan();
    await seedFriendship(friendId, "accepted");

    const reference = doc(authenticatedFirestore(friendId), "plans", ownerId);
    await assertSucceeds(getDoc(reference));
  });

  test("an accepted friend cannot read an expired plan", async () => {
    const plannedAt = new Date(Date.now() - 3 * 60 * 60 * 1000);
    await seedPlan(
      planData({
        plannedAt: Timestamp.fromDate(plannedAt),
        expiresAt: Timestamp.fromDate(
          new Date(plannedAt.getTime() + 2 * 60 * 60 * 1000),
        ),
      }),
    );
    await seedFriendship(friendId, "accepted");

    const reference = doc(authenticatedFirestore(friendId), "plans", ownerId);
    await assertFails(getDoc(reference));
  });

  test("a pending friend cannot read the plan", async () => {
    await seedPlan();
    await seedFriendship(pendingFriendId, "pending");

    const reference = doc(
      authenticatedFirestore(pendingFriendId),
      "plans",
      ownerId,
    );
    await assertFails(getDoc(reference));
  });

  test("a signed-in stranger cannot read the plan", async () => {
    await seedPlan();
    const reference = doc(authenticatedFirestore(strangerId), "plans", ownerId);
    await assertFails(getDoc(reference));
  });

  test("an unauthenticated user cannot read the plan", async () => {
    await seedPlan();
    const database = testEnvironment.unauthenticatedContext().firestore();
    await assertFails(getDoc(doc(database, "plans", ownerId)));
  });

  test("a non-Apple Firebase session is rejected", async () => {
    const database = testEnvironment
      .authenticatedContext(ownerId, {
        firebase: { sign_in_provider: "password" },
      })
      .firestore();
    await assertFails(setDoc(doc(database, "plans", ownerId), planData()));
  });

  test("listing the plans collection is always rejected", async () => {
    await seedPlan();
    const database = authenticatedFirestore(ownerId);
    await assertFails(getDocs(collection(database, "plans")));
  });

  test("another user cannot write or delete the owner's plan", async () => {
    await seedPlan();
    const reference = doc(authenticatedFirestore(strangerId), "plans", ownerId);
    await assertFails(setDoc(reference, planData()));
    await assertFails(deleteDoc(reference));
  });

  test("an update must use a new publication ID", async () => {
    const database = authenticatedFirestore(ownerId);
    const reference = doc(database, "plans", ownerId);
    const publicationId = crypto.randomUUID();

    await assertSucceeds(setDoc(reference, planData({ publicationId })));
    await assertFails(
      setDoc(reference, planData({ publicationId, placeName: "Bukchon" })),
    );
  });

  test("unexpected fields are rejected", async () => {
    const database = authenticatedFirestore(ownerId);
    await assertFails(
      setDoc(
        doc(database, "plans", ownerId),
        planData({ privateNote: "secret" }),
      ),
    );
  });

  test("text must be normalized", async () => {
    const database = authenticatedFirestore(ownerId);
    await assertFails(
      setDoc(
        doc(database, "plans", ownerId),
        planData({ placeName: "Namsan  Seoul Tower" }),
      ),
    );
  });

  test("invalid dates are rejected", async (t) => {
    const database = authenticatedFirestore(ownerId);
    const reference = doc(database, "plans", ownerId);

    await t.test("planned in the past", async () => {
      const plannedAt = new Date(Date.now() - 60 * 1000);
      await assertFails(
        setDoc(
          reference,
          planData({
            plannedAt: Timestamp.fromDate(plannedAt),
            expiresAt: Timestamp.fromDate(
              new Date(plannedAt.getTime() + 60 * 60 * 1000),
            ),
          }),
        ),
      );
    });

    await t.test("planned more than 24 hours ahead", async () => {
      const plannedAt = new Date(Date.now() + 25 * 60 * 60 * 1000);
      await assertFails(
        setDoc(
          reference,
          planData({
            plannedAt: Timestamp.fromDate(plannedAt),
            expiresAt: Timestamp.fromDate(
              new Date(plannedAt.getTime() + 60 * 60 * 1000),
            ),
          }),
        ),
      );
    });

    await t.test("expiring more than two hours after the plan", async () => {
      const plannedAt = new Date(Date.now() + 60 * 60 * 1000);
      await assertFails(
        setDoc(
          reference,
          planData({
            plannedAt: Timestamp.fromDate(plannedAt),
            expiresAt: Timestamp.fromDate(
              new Date(plannedAt.getTime() + 3 * 60 * 60 * 1000),
            ),
          }),
        ),
      );
    });
  });

  test("an invalid location value is rejected", async () => {
    const database = authenticatedFirestore(ownerId);
    await assertFails(
      setDoc(
        doc(database, "plans", ownerId),
        planData({ location: "37.5796,126.977" }),
      ),
    );
  });

  test("a pending account deletion blocks publication but not cancellation", async () => {
    await testEnvironment.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), "users", ownerId), {
        deletionRequestedAt: Timestamp.now(),
      });
    });

    const database = authenticatedFirestore(ownerId);
    const reference = doc(database, "plans", ownerId);
    await assertFails(setDoc(reference, planData()));

    await seedPlan();
    await assertSucceeds(deleteDoc(reference));
  });
});
