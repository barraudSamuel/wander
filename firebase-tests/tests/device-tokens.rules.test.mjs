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

const projectId = "demo-wander-device-tokens";
const ownerId = "device-owner";
const strangerId = "device-stranger";
const deviceId = "d4c87be0-88a8-4d69-9878-84ff24b93ca2";
const appleClaims = {
  firebase: { sign_in_provider: "apple.com" },
};

let testEnvironment;

function authenticatedFirestore(userId) {
  return testEnvironment.authenticatedContext(userId, appleClaims).firestore();
}

function deviceData(overrides = {}) {
  return {
    token: "fcm-token-value-with-more-than-twenty-characters",
    platform: "ios",
    updatedAt: serverTimestamp(),
    ...overrides,
  };
}

function deviceReference(database, userId = ownerId, id = deviceId) {
  return doc(database, "users", userId, "devices", id);
}

async function seedDevice(data = deviceData()) {
  await testEnvironment.withSecurityRulesDisabled(async (context) => {
    await setDoc(deviceReference(context.firestore()), {
      ...data,
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

describe("users/{userID}/devices/{deviceID}", () => {
  test("the owner can create, read, list, update, and delete a device", async () => {
    const database = authenticatedFirestore(ownerId);
    const reference = deviceReference(database);

    await assertSucceeds(setDoc(reference, deviceData()));
    await assertSucceeds(getDoc(reference));
    await assertSucceeds(
      getDocs(collection(database, "users", ownerId, "devices")),
    );
    await assertSucceeds(
      setDoc(reference, deviceData({ token: "replacement-token-value-long-enough" })),
    );
    await assertSucceeds(deleteDoc(reference));
  });

  test("another account cannot read, list, write, or delete devices", async () => {
    await seedDevice();
    const database = authenticatedFirestore(strangerId);
    const reference = deviceReference(database);

    await assertFails(getDoc(reference));
    await assertFails(
      getDocs(collection(database, "users", ownerId, "devices")),
    );
    await assertFails(setDoc(reference, deviceData()));
    await assertFails(deleteDoc(reference));
  });

  test("an unauthenticated or non-Apple session is rejected", async () => {
    const unauthenticated = testEnvironment
      .unauthenticatedContext()
      .firestore();
    await assertFails(
      setDoc(deviceReference(unauthenticated), deviceData()),
    );

    const passwordSession = testEnvironment
      .authenticatedContext(ownerId, {
        firebase: { sign_in_provider: "password" },
      })
      .firestore();
    await assertFails(
      setDoc(deviceReference(passwordSession), deviceData()),
    );
  });

  test("device ID, token, platform, and exact fields are validated", async (t) => {
    const database = authenticatedFirestore(ownerId);

    await t.test("invalid device ID", async () => {
      await assertFails(
        setDoc(deviceReference(database, ownerId, "phone"), deviceData()),
      );
    });

    await t.test("short token", async () => {
      await assertFails(
        setDoc(deviceReference(database), deviceData({ token: "short" })),
      );
    });

    await t.test("wrong platform", async () => {
      await assertFails(
        setDoc(deviceReference(database), deviceData({ platform: "android" })),
      );
    });

    await t.test("unexpected field", async () => {
      await assertFails(
        setDoc(deviceReference(database), deviceData({ ownerId })),
      );
    });
  });

  test("pending account deletion blocks writes but still permits cleanup", async () => {
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
