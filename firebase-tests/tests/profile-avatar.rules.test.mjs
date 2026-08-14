import { readFile } from "node:fs/promises";
import { after, before, beforeEach, describe, test } from "node:test";
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from "@firebase/rules-unit-testing";
import {
  doc,
  getDoc,
  serverTimestamp,
  updateDoc,
  writeBatch,
} from "firebase/firestore";

const projectId = "demo-wander-profile-avatar";
const ownerId = "avatar-owner";
const friendId = "avatar-friend";
const strangerId = "avatar-stranger";
const friendCode = "ABCDEFGH234";
const appleClaims = {
  firebase: { sign_in_provider: "apple.com" },
};

let testEnvironment;

function authenticatedFirestore(userId) {
  return testEnvironment.authenticatedContext(userId, appleClaims).firestore();
}

function userData(overrides = {}) {
  return {
    displayName: "Samuel",
    avatarID: "radiant-eye",
    profileColorHex: "#3366CC",
    friendCode,
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
    ...overrides,
  };
}

async function createProfile(data = userData()) {
  const database = authenticatedFirestore(ownerId);
  const batch = writeBatch(database);
  batch.set(doc(database, "users", ownerId), data);
  batch.set(doc(database, "friendCodes", friendCode), {
    ownerId,
    displayName: data.displayName,
    createdAt: serverTimestamp(),
  });
  return batch.commit();
}

async function seedLegacyProfile() {
  await testEnvironment.withSecurityRulesDisabled(async (context) => {
    const database = context.firestore();
    const batch = writeBatch(database);
    batch.set(doc(database, "users", ownerId), {
      displayName: "Samuel",
      profileColorHex: "#3366CC",
      friendCode,
      createdAt: new Date(),
      updatedAt: new Date(),
    });
    batch.set(doc(database, "friendCodes", friendCode), {
      ownerId,
      displayName: "Samuel",
      createdAt: new Date(),
    });
    await batch.commit();
  });
}

async function seedAcceptedFriendship() {
  const participants = [ownerId, friendId].sort();
  const pairId = participants.join("__");
  await testEnvironment.withSecurityRulesDisabled(async (context) => {
    const database = context.firestore();
    const batch = writeBatch(database);
    batch.set(doc(database, "friendships", pairId), {
      participants,
      requestedBy: ownerId,
      status: "accepted",
      createdAt: new Date(),
      acceptedAt: new Date(),
    });
    await batch.commit();
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

describe("users/{uid} avatarID", () => {
  test("a new profile accepts only catalog avatar identifiers", async () => {
    await assertSucceeds(createProfile());
    await testEnvironment.clearFirestore();
    await assertFails(createProfile(userData({ avatarID: "wizard" })));
    await testEnvironment.clearFirestore();

    const dataWithoutAvatar = userData();
    delete dataWithoutAvatar.avatarID;
    await assertSucceeds(createProfile(dataWithoutAvatar));
  });

  test("an existing profile can select another catalog avatar", async () => {
    await createProfile();
    const reference = doc(authenticatedFirestore(ownerId), "users", ownerId);

    await assertSucceeds(
      updateDoc(reference, {
        avatarID: "skull",
        updatedAt: serverTimestamp(),
      }),
    );
    await assertFails(
      updateDoc(reference, {
        avatarID: "uploaded-photo-url",
        updatedAt: serverTimestamp(),
      }),
    );
  });

  test("a legacy profile can be migrated with a valid avatar", async () => {
    await seedLegacyProfile();
    const reference = doc(authenticatedFirestore(ownerId), "users", ownerId);

    await assertSucceeds(
      updateDoc(reference, {
        avatarID: "cyclops-horns",
        updatedAt: serverTimestamp(),
      }),
    );
  });

  test("an accepted friend can read the selected avatar", async () => {
    await createProfile();
    await seedAcceptedFriendship();

    await assertSucceeds(
      getDoc(doc(authenticatedFirestore(friendId), "users", ownerId)),
    );
    await assertFails(
      getDoc(doc(authenticatedFirestore(strangerId), "users", ownerId)),
    );
  });
});
