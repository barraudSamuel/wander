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
  serverTimestamp,
  setDoc,
} from "firebase/firestore";

const projectId = "demo-wander-location-push";
const ownerId = "location-push-owner";
const strangerId = "location-push-stranger";
const deviceId = "d4c87be0-88a8-4d69-9878-84ff24b93ca2";
const validToken = "ab".repeat(32);
const appleClaims = {
  firebase: { sign_in_provider: "apple.com" },
};

let testEnvironment;

function authenticatedFirestore(userId) {
  return testEnvironment.authenticatedContext(userId, appleClaims).firestore();
}

function deviceData(overrides = {}) {
  return {
    token: validToken,
    environment: "sandbox",
    updatedAt: serverTimestamp(),
    ...overrides,
  };
}

function deviceReference(database, userId = ownerId, id = deviceId) {
  return doc(database, "users", userId, "locationPushDevices", id);
}

async function seedDevice() {
  await testEnvironment.withSecurityRulesDisabled(async (context) => {
    await setDoc(deviceReference(context.firestore()), {
      token: validToken,
      environment: "sandbox",
      updatedAt: new Date(),
    });
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
});

after(async () => {
  await testEnvironment.cleanup();
});

describe("users/{uid}/locationPushDevices/{deviceId}", () => {
  test("the owner controls only their location push registrations", async () => {
    const database = authenticatedFirestore(ownerId);
    const reference = deviceReference(database);

    await assertSucceeds(setDoc(reference, deviceData()));
    await assertSucceeds(getDoc(reference));
    await assertSucceeds(
      getDocs(collection(database, "users", ownerId, "locationPushDevices")),
    );
    await assertSucceeds(
      setDoc(reference, deviceData({ environment: "production" })),
    );
    await assertSucceeds(deleteDoc(reference));
  });

  test("another account cannot read, list, write, or delete registrations", async () => {
    await seedDevice();
    const database = authenticatedFirestore(strangerId);
    const reference = deviceReference(database);

    await assertFails(getDoc(reference));
    await assertFails(
      getDocs(collection(database, "users", ownerId, "locationPushDevices")),
    );
    await assertFails(setDoc(reference, deviceData()));
    await assertFails(deleteDoc(reference));
  });

  test("validates token, environment, device ID, and exact fields", async (t) => {
    const database = authenticatedFirestore(ownerId);

    await t.test("non-hex token", async () => {
      await assertFails(
        setDoc(deviceReference(database), deviceData({ token: "zz".repeat(32) })),
      );
    });

    await t.test("short token", async () => {
      await assertFails(
        setDoc(deviceReference(database), deviceData({ token: "ab" })),
      );
    });

    await t.test("unknown environment", async () => {
      await assertFails(
        setDoc(deviceReference(database), deviceData({ environment: "preview" })),
      );
    });

    await t.test("invalid device ID", async () => {
      await assertFails(
        setDoc(deviceReference(database, ownerId, "phone"), deviceData()),
      );
    });

    await t.test("unexpected field", async () => {
      await assertFails(
        setDoc(deviceReference(database), deviceData({ ownerId })),
      );
    });
  });

  test("requires Apple authentication and allows cleanup during deletion", async () => {
    const passwordSession = testEnvironment
      .authenticatedContext(ownerId, {
        firebase: { sign_in_provider: "password" },
      })
      .firestore();
    await assertFails(setDoc(deviceReference(passwordSession), deviceData()));

    await seedDevice();
    await testEnvironment.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), "users", ownerId), {
        deletionRequestedAt: new Date(),
      });
    });

    const database = authenticatedFirestore(ownerId);
    const reference = deviceReference(database);
    await assertFails(setDoc(reference, deviceData()));
    await assertSucceeds(deleteDoc(reference));
  });
});

describe("locationPushDispatches/{targetUserId}", () => {
  async function seedDispatch() {
    await testEnvironment.withSecurityRulesDisabled(async (context) => {
      await setDoc(
        doc(context.firestore(), "locationPushDispatches", ownerId),
        {
          requesterId: strangerId,
          requestId: "52e973c7-f824-4e73-8ef0-f86cfeaf21e2",
          lastSentAt: new Date(),
        },
      );
    });
  }

  test("clients cannot read or write server quota state", async () => {
    await seedDispatch();
    const database = authenticatedFirestore(ownerId);
    const reference = doc(database, "locationPushDispatches", ownerId);

    await assertFails(getDoc(reference));
    await assertFails(setDoc(reference, { lastSentAt: serverTimestamp() }));
  });

  test("only the target can delete quota state during account cleanup", async () => {
    await seedDispatch();
    await assertFails(
      deleteDoc(
        doc(
          authenticatedFirestore(strangerId),
          "locationPushDispatches",
          ownerId,
        ),
      ),
    );
    await assertSucceeds(
      deleteDoc(
        doc(
          authenticatedFirestore(ownerId),
          "locationPushDispatches",
          ownerId,
        ),
      ),
    );
  });
});
