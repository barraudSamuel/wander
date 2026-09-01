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

const projectId = "demo-wander-profiles";
const ownerId = "profile-owner";
const friendId = "profile-friend";
const strangerId = "profile-stranger";
const friendCode = "FRIEND-CODE-NEXT";

let testEnvironment;

function authenticatedFirestore(userId) {
  return testEnvironment.authenticatedContext(userId).firestore();
}

function profileReference(database, userId = ownerId) {
  return doc(database, "users", userId);
}

async function seedFriendship(status) {
  const participants = [ownerId, friendId].sort();
  await testEnvironment.withSecurityRulesDisabled(async (context) => {
    await setDoc(
      doc(context.firestore(), "friendships", participants.join("__")),
      {
        participants,
        requestedBy: ownerId,
        status,
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
  await testEnvironment.withSecurityRulesDisabled(async (context) => {
    await setDoc(profileReference(context.firestore()), {
      displayName: "Samuel",
      avatarID: "legacy-or-future-avatar",
      customProfileField: { revision: 3 },
    });
  });
});

after(async () => {
  await testEnvironment.cleanup();
});

describe("profiles and friend codes", () => {
  test("the owner can evolve the profile schema freely", async () => {
    const database = authenticatedFirestore(ownerId);
    const reference = profileReference(database);

    await assertSucceeds(getDoc(reference));
    await assertSucceeds(updateDoc(reference, {
      avatarID: "uploaded-photo-url-or-new-catalog-value",
      futureField: [1, 2, 3],
    }));
    await assertSucceeds(deleteDoc(reference));
    await assertSucceeds(setDoc(reference, { minimalProfile: true }));
  });

  test("pending and accepted relations can read a basic profile", async () => {
    for (const status of ["pending", "accepted"]) {
      await testEnvironment.clearFirestore();
      await testEnvironment.withSecurityRulesDisabled(async (context) => {
        await setDoc(profileReference(context.firestore()), {
          displayName: "Samuel",
        });
      });
      await seedFriendship(status);
      await assertSucceeds(getDoc(
        profileReference(authenticatedFirestore(friendId)),
      ));
    }
  });

  test("strangers and revoked relations cannot read or write a profile", async () => {
    await assertFails(getDoc(
      profileReference(authenticatedFirestore(strangerId)),
    ));
    await assertFails(updateDoc(
      profileReference(authenticatedFirestore(strangerId)),
      { displayName: "Imposteur" },
    ));

    await seedFriendship("revoking");
    await assertFails(getDoc(
      profileReference(authenticatedFirestore(friendId)),
    ));
    await assertFails(getDocs(collection(
      authenticatedFirestore(ownerId),
      "users",
    )));
  });

  test("friend codes are resolvable but remain owned by their creator", async () => {
    const ownerDatabase = authenticatedFirestore(ownerId);
    const strangerDatabase = authenticatedFirestore(strangerId);
    const ownerReference = doc(ownerDatabase, "friendCodes", friendCode);
    const strangerReference = doc(strangerDatabase, "friendCodes", friendCode);

    await assertSucceeds(setDoc(ownerReference, {
      ownerId,
      displayName: "Samuel",
      futureField: true,
    }));
    await assertSucceeds(getDoc(strangerReference));
    await assertFails(updateDoc(strangerReference, { displayName: "Volé" }));
    await assertFails(deleteDoc(strangerReference));
    await assertSucceeds(updateDoc(ownerReference, { displayName: "Sam" }));
    await assertSucceeds(deleteDoc(ownerReference));
    await assertFails(getDocs(collection(ownerDatabase, "friendCodes")));
  });

  test("signed-out clients cannot resolve profiles or codes", async () => {
    const database = testEnvironment.unauthenticatedContext().firestore();

    await assertFails(getDoc(profileReference(database)));
    await assertFails(getDoc(doc(database, "friendCodes", friendCode)));
  });
});
