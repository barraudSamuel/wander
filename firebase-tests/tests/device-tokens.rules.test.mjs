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

const projectId = "demo-wander-device-tokens";
const ownerId = "device-owner";
const strangerId = "device-stranger";
const deviceId = "ios-phone";

let testEnvironment;

function authenticatedFirestore(userId) {
  return testEnvironment.authenticatedContext(userId).firestore();
}

function deviceReference(database, userId = ownerId) {
  return doc(database, "users", userId, "devices", deviceId);
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

describe("users/{uid}/devices", () => {
  test("the owner can use a flexible device payload", async () => {
    const database = authenticatedFirestore(ownerId);
    const reference = deviceReference(database);

    await assertSucceeds(setDoc(reference, {
      token: "short-or-long-client-defined-token",
      platform: "future-ios",
      metadata: { appVersion: "next" },
    }));
    await assertSucceeds(getDoc(reference));
    await assertSucceeds(getDocs(
      collection(database, "users", ownerId, "devices"),
    ));
    await assertSucceeds(updateDoc(reference, { extraField: true }));
    await assertSucceeds(deleteDoc(reference));
  });

  test("another account cannot access device tokens", async () => {
    await testEnvironment.withSecurityRulesDisabled(async (context) => {
      await setDoc(deviceReference(context.firestore()), { token: "secret" });
    });

    const database = authenticatedFirestore(strangerId);
    await assertFails(getDoc(deviceReference(database)));
    await assertFails(getDocs(
      collection(database, "users", ownerId, "devices"),
    ));
    await assertFails(setDoc(deviceReference(database), { token: "stolen" }));
    await assertFails(deleteDoc(deviceReference(database)));
  });

  test("signed-out clients are rejected", async () => {
    const database = testEnvironment.unauthenticatedContext().firestore();

    await assertFails(getDoc(deviceReference(database)));
    await assertFails(setDoc(deviceReference(database), { token: "none" }));
  });
});
