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

const projectId = "demo-wander-location-push";
const ownerId = "push-owner";
const strangerId = "push-stranger";
const deviceId = "background-device";

let testEnvironment;

function authenticatedFirestore(userId) {
  return testEnvironment.authenticatedContext(userId).firestore();
}

function deviceReference(database, userId = ownerId) {
  return doc(
    database,
    "users",
    userId,
    "locationPushDevices",
    deviceId,
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
});

after(async () => {
  await testEnvironment.cleanup();
});

describe("location push security boundary", () => {
  test("the owner can manage a flexible location-push device", async () => {
    const database = authenticatedFirestore(ownerId);
    const reference = deviceReference(database);

    await assertSucceeds(setDoc(reference, {
      token: "client-defined",
      environment: "future",
      capabilities: ["location", "background"],
    }));
    await assertSucceeds(getDoc(reference));
    await assertSucceeds(getDocs(collection(
      database,
      "users",
      ownerId,
      "locationPushDevices",
    )));
    await assertSucceeds(updateDoc(reference, { revision: 2 }));
    await assertSucceeds(deleteDoc(reference));
  });

  test("another account cannot access location-push devices", async () => {
    await testEnvironment.withSecurityRulesDisabled(async (context) => {
      await setDoc(deviceReference(context.firestore()), { token: "secret" });
    });

    const database = authenticatedFirestore(strangerId);
    await assertFails(getDoc(deviceReference(database)));
    await assertFails(getDocs(collection(
      database,
      "users",
      ownerId,
      "locationPushDevices",
    )));
    await assertFails(setDoc(deviceReference(database), { token: "spoofed" }));
  });

  test("backend dispatches remain private to server code", async () => {
    const ownerDatabase = authenticatedFirestore(ownerId);
    const strangerDatabase = authenticatedFirestore(strangerId);
    const dispatch = doc(
      ownerDatabase,
      "locationPushDispatches",
      ownerId,
    );

    await assertFails(getDoc(dispatch));
    await assertFails(setDoc(dispatch, { count: 1 }));
    await assertFails(updateDoc(dispatch, { count: 2 }));
    await assertSucceeds(deleteDoc(dispatch));
    await assertFails(deleteDoc(doc(
      strangerDatabase,
      "locationPushDispatches",
      ownerId,
    )));

    await assertFails(setDoc(doc(
      ownerDatabase,
      "notificationDispatches",
      "client-created",
    ), { target: ownerId }));
  });

  test("signed-out clients are rejected", async () => {
    const database = testEnvironment.unauthenticatedContext().firestore();

    await assertFails(getDoc(deviceReference(database)));
    await assertFails(setDoc(deviceReference(database), { token: "none" }));
  });
});
