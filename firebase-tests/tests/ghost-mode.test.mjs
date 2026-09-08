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
  deleteDoc,
  doc,
  getDocFromServer,
  runTransaction,
  serverTimestamp,
  setDoc,
  updateDoc,
  writeBatch,
} from "firebase/firestore";

const projectId = "demo-wander-ghost-mode";
const ownerId = "ghost-owner";
const friendId = "ghost-friend";
const strangerId = "ghost-stranger";
const visibleRevision = "visible-before-ghost";
const ghostRevision = "ghost-enabled";
const resumedRevision = "visible-after-ghost";
const cellId = "8928308280fffff";

let testEnvironment;

function authenticatedFirestore(userId) {
  return testEnvironment.authenticatedContext(userId).firestore();
}

function profileReference(database, userId = ownerId) {
  return doc(database, "users", userId);
}

function locationReference(database) {
  return doc(database, "locations", ownerId);
}

function cellReference(database) {
  return doc(database, "explorations", ownerId, "cells", cellId);
}

function locationData(sampledAt = Timestamp.fromMillis(10_000)) {
  return {
    location: new GeoPoint(1, 2),
    displayName: "Ghost protocol fixture",
    horizontalAccuracy: 10,
    sampledAt,
    updatedAt: serverTimestamp(),
  };
}

async function changeGhostMode(database, enabled, revision) {
  const batch = writeBatch(database);
  batch.update(profileReference(database), {
    isGhostModeEnabled: enabled,
    locationSharingRevision: revision,
    ...(!enabled ? { locationSharingResumedAt: serverTimestamp() } : {}),
  });
  batch.delete(locationReference(database));
  await batch.commit();
}

// These are emulator integration tests of the client/server protocol, using a
// minimal JS fixture. They do not execute the production Swift publishers or
// replace their policy/state tests. Native policy validation also handles
// malformed profile fields and account deletion, outside this fixture's scope.
async function publishConditionally(database, {
  reference,
  data,
  expectedRevision,
  afterFirstRead,
}) {
  let attempts = 0;
  const published = await runTransaction(database, async (transaction) => {
    attempts += 1;
    const snapshot = await transaction.get(profileReference(database));
    const profile = snapshot.data();

    if (attempts === 1 && afterFirstRead) {
      await afterFirstRead();
    }

    if (!snapshot.exists()
      || (profile.isGhostModeEnabled !== undefined
        && profile.isGhostModeEnabled !== false)
      || (profile.locationSharingRevision ?? null) !== expectedRevision
      || (data.sampledAt && profile.locationSharingResumedAt
        && data.sampledAt.toMillis()
          < profile.locationSharingResumedAt.toMillis())) {
      return false;
    }

    transaction.set(reference, data);
    return true;
  });

  return { published, attempts };
}

// Protocol fixture for an intent captured by the client at the user's action.
// The allowed revisions are immutable across transaction retries, including
// null for a legacy profile. Production Swift owns capture and persistence.
async function applyGhostIntent(database, change, { afterFirstRead } = {}) {
  let attempts = 0;
  const status = await runTransaction(database, async (transaction) => {
    attempts += 1;
    const snapshot = await transaction.get(profileReference(database));
    const profile = snapshot.data();

    if (attempts === 1 && afterFirstRead) {
      await afterFirstRead();
    }
    if (!snapshot.exists()) return "conflict";

    const revision = profile.locationSharingRevision ?? null;
    const enabled = profile.isGhostModeEnabled ?? false;
    if (revision === change.revision) {
      return enabled === change.enabled ? "idempotent" : "conflict";
    }
    if (revision !== change.expectedRevision
      && !change.predecessorRevisions.includes(revision)) {
      return "conflict";
    }

    transaction.update(profileReference(database), {
      isGhostModeEnabled: change.enabled,
      locationSharingRevision: change.revision,
      ...(!change.enabled ? { locationSharingResumedAt: serverTimestamp() } : {}),
    });
    transaction.delete(locationReference(database));
    return "applied";
  });

  return { status, attempts };
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
    const participants = [ownerId, friendId].sort();
    await setDoc(
      doc(context.firestore(), "friendships", participants.join("__")),
      { participants, requestedBy: ownerId, status: "accepted" },
    );
  });

  const owner = authenticatedFirestore(ownerId);
  await setDoc(profileReference(owner), {
    displayName: "Ghost protocol fixture",
    isGhostModeEnabled: false,
    locationSharingRevision: visibleRevision,
  });
  await setDoc(locationReference(owner), locationData());
});

after(async () => {
  await testEnvironment.cleanup();
});

describe("ghost client protocol under unchanged Firestore rules", () => {
  test("atomic activation lets an accepted friend read ghost status with no coordinates", async () => {
    const owner = authenticatedFirestore(ownerId);
    const friend = authenticatedFirestore(friendId);
    assert.equal((await getDocFromServer(locationReference(friend))).exists(), true);

    await assertSucceeds(changeGhostMode(owner, true, ghostRevision));

    const profile = await assertSucceeds(getDocFromServer(profileReference(friend)));
    const location = await assertSucceeds(getDocFromServer(locationReference(friend)));
    assert.equal(profile.get("isGhostModeEnabled"), true);
    assert.equal(profile.get("locationSharingRevision"), ghostRevision);
    assert.equal(profile.get("displayName"), "Ghost protocol fixture");
    assert.equal(profile.get("location"), undefined);
    assert.equal(location.exists(), false);
    assert.equal(location.data(), undefined);

    await assertFails(getDocFromServer(profileReference(authenticatedFirestore(strangerId))));
  });

  test("a rejected activation batch leaves both status and existing location unchanged", async () => {
    const owner = authenticatedFirestore(ownerId);
    const batch = writeBatch(owner);
    batch.update(profileReference(owner), {
      isGhostModeEnabled: true,
      locationSharingRevision: ghostRevision,
    });
    batch.delete(locationReference(owner));
    // A prohibited write makes the complete batch fail under the real rules.
    batch.set(profileReference(owner, strangerId), { isGhostModeEnabled: true });

    await assertFails(batch.commit());

    const profile = await getDocFromServer(profileReference(owner));
    assert.equal(profile.get("isGhostModeEnabled"), false);
    assert.equal(profile.get("locationSharingRevision"), visibleRevision);
    assert.equal((await getDocFromServer(locationReference(owner))).exists(), true);
  });

  test("friends and strangers cannot change the owner's status, position, or exploration", async () => {
    await changeGhostMode(authenticatedFirestore(ownerId), true, ghostRevision);

    for (const userId of [friendId, strangerId]) {
      const database = authenticatedFirestore(userId);
      await assertFails(updateDoc(profileReference(database), {
        isGhostModeEnabled: false,
        locationSharingRevision: "spoofed-revision",
      }));
      await assertFails(setDoc(locationReference(database), locationData()));
      await assertFails(deleteDoc(locationReference(database)));
      await assertFails(setDoc(cellReference(database), { sharedAt: serverTimestamp() }));
      await assertFails(changeGhostMode(database, true, "spoofed-activation"));
    }

    const owner = authenticatedFirestore(ownerId);
    assert.equal((await getDocFromServer(profileReference(owner))).get(
      "locationSharingRevision",
    ), ghostRevision);
    assert.equal((await getDocFromServer(locationReference(owner))).exists(), false);
    assert.equal((await getDocFromServer(cellReference(owner))).exists(), false);
  });

  test("legacy profiles without ghost marker or revision can publish conditionally", async () => {
    const owner = authenticatedFirestore(ownerId);
    await setDoc(profileReference(owner), { displayName: "Legacy profile" });
    await deleteDoc(locationReference(owner));

    for (const publication of [
      { reference: locationReference(owner), data: locationData() },
      { reference: cellReference(owner), data: { sharedAt: serverTimestamp() } },
    ]) {
      const result = await publishConditionally(owner, {
        ...publication,
        expectedRevision: null,
      });
      assert.equal(result.published, true);
      assert.equal((await getDocFromServer(publication.reference)).exists(), true);
    }
  });

  for (const target of ["location", "exploration cell"]) {
    test(`a ${target} transaction retries and refuses publication when another owner client activates ghost`, async () => {
      const writer = authenticatedFirestore(ownerId);
      const toggler = authenticatedFirestore(ownerId);
      assert.notEqual(writer, toggler);
      const reference = target === "location"
        ? locationReference(writer)
        : cellReference(writer);
      const data = target === "location"
        ? locationData()
        : { sharedAt: serverTimestamp() };

      const result = await publishConditionally(writer, {
        reference,
        data,
        expectedRevision: visibleRevision,
        // The first transaction has already read the visible profile. Commit
        // the competing client write before allowing its stale attempt to write.
        afterFirstRead: () => changeGhostMode(toggler, true, ghostRevision),
      });

      assert.ok(result.attempts >= 2, "Firestore must retry the stale transaction");
      assert.equal(result.published, false);
      assert.equal((await getDocFromServer(reference)).exists(), false);
      assert.equal((await getDocFromServer(profileReference(writer))).get(
        "locationSharingRevision",
      ), ghostRevision);
      assert.equal((await getDocFromServer(locationReference(writer))).exists(), false);
    });
  }

  test("resuming rejects an old revision and pre-resume sample, then permits fresh position and deferred cells", async () => {
    const owner = authenticatedFirestore(ownerId);
    await changeGhostMode(owner, true, ghostRevision);

    const paused = await publishConditionally(owner, {
      reference: cellReference(owner),
      data: { sharedAt: serverTimestamp() },
      expectedRevision: ghostRevision,
    });
    assert.equal(paused.published, false);

    await changeGhostMode(owner, false, resumedRevision);
    const profile = await getDocFromServer(profileReference(owner));
    const resumedAt = profile.get("locationSharingResumedAt");
    assert.ok(resumedAt instanceof Timestamp);
    const freshSample = Timestamp.fromMillis(resumedAt.toMillis() + 1_000);

    for (const publication of [
      { reference: locationReference(owner), data: locationData(freshSample) },
      { reference: cellReference(owner), data: { sharedAt: serverTimestamp() } },
    ]) {
      const stale = await publishConditionally(owner, {
        ...publication,
        expectedRevision: visibleRevision,
      });
      assert.equal(stale.published, false);
      assert.equal((await getDocFromServer(publication.reference)).exists(), false);
    }

    const oldSample = await publishConditionally(owner, {
      reference: locationReference(owner),
      data: locationData(Timestamp.fromMillis(resumedAt.toMillis() - 1_000)),
      expectedRevision: resumedRevision,
    });
    assert.equal(oldSample.published, false);
    assert.equal((await getDocFromServer(locationReference(owner))).exists(), false);

    const freshPosition = await publishConditionally(owner, {
      reference: locationReference(owner),
      data: locationData(freshSample),
      expectedRevision: resumedRevision,
    });
    const deferredCell = await publishConditionally(owner, {
      reference: cellReference(owner),
      data: { sharedAt: serverTimestamp() },
      expectedRevision: resumedRevision,
    });
    assert.equal(freshPosition.published, true);
    assert.equal(deferredCell.published, true);

    const friend = authenticatedFirestore(friendId);
    const sharedLocation = await getDocFromServer(locationReference(friend));
    assert.equal(sharedLocation.get("sampledAt").toMillis(), freshSample.toMillis());
    assert.equal((await getDocFromServer(cellReference(friend))).exists(), true);
  });

  test("a pending deactivation cannot overwrite a newer activation from another owner client", async () => {
    const writer = authenticatedFirestore(ownerId);
    const otherDevice = authenticatedFirestore(ownerId);
    const pendingDeactivation = {
      enabled: false,
      revision: "local-deactivation",
      expectedRevision: visibleRevision,
      predecessorRevisions: [visibleRevision, "local-activation"],
    };
    const remoteRevision = "other-device-activation";

    const result = await applyGhostIntent(writer, pendingDeactivation, {
      afterFirstRead: async () => {
        const remote = await applyGhostIntent(otherDevice, {
          enabled: true,
          revision: remoteRevision,
          expectedRevision: visibleRevision,
          predecessorRevisions: [],
        });
        assert.equal(remote.status, "applied");
      },
    });

    assert.ok(result.attempts >= 2, "Firestore must retry the stale deactivation");
    assert.equal(result.status, "conflict");
    const profile = await getDocFromServer(profileReference(writer));
    assert.equal(profile.get("isGhostModeEnabled"), true);
    assert.equal(profile.get("locationSharingRevision"), remoteRevision);
    assert.equal(profile.get("locationSharingResumedAt"), undefined);
    assert.equal((await getDocFromServer(locationReference(writer))).exists(), false);
    assert.deepEqual(pendingDeactivation.predecessorRevisions, [
      visibleRevision,
      "local-activation",
    ], "a retry must not adopt the competing device's revision as a new base");
  });

  test("a pending intent accepts a known local predecessor that completes while its transaction is in flight", async () => {
    const writer = authenticatedFirestore(ownerId);
    const predecessorClient = authenticatedFirestore(ownerId);
    await setDoc(profileReference(writer), { displayName: "Legacy profile" });
    const predecessorRevision = "local-predecessor";
    const pendingDeactivation = {
      enabled: false,
      revision: resumedRevision,
      expectedRevision: null,
      predecessorRevisions: [null, "earlier-local-intent", predecessorRevision],
    };

    const result = await applyGhostIntent(writer, pendingDeactivation, {
      afterFirstRead: async () => {
        // Complete an already-issued local intent through a separate Firebase
        // client, after the pending deactivation read its legacy base revision.
        const predecessor = await applyGhostIntent(predecessorClient, {
          enabled: true,
          revision: predecessorRevision,
          expectedRevision: null,
          predecessorRevisions: [],
        });
        assert.equal(predecessor.status, "applied");
      },
    });

    assert.ok(result.attempts >= 2, "Firestore must retry after the predecessor commits");
    assert.equal(result.status, "applied");
    const profile = await getDocFromServer(profileReference(writer));
    assert.equal(profile.get("isGhostModeEnabled"), false);
    assert.equal(profile.get("locationSharingRevision"), resumedRevision);
    assert.ok(profile.get("locationSharingResumedAt") instanceof Timestamp);
    assert.equal((await getDocFromServer(locationReference(writer))).exists(), false);
  });

  test("replaying an acknowledged revision preserves its resume time and freshly shared position", async () => {
    const owner = authenticatedFirestore(ownerId);
    await changeGhostMode(owner, true, ghostRevision);
    const change = {
      enabled: false,
      revision: resumedRevision,
      expectedRevision: ghostRevision,
      predecessorRevisions: [],
    };
    assert.equal((await applyGhostIntent(owner, change)).status, "applied");
    const before = await getDocFromServer(profileReference(owner));
    const resumedAt = before.get("locationSharingResumedAt");
    const freshSample = Timestamp.fromMillis(resumedAt.toMillis() + 1_000);
    const publication = await publishConditionally(owner, {
      reference: locationReference(owner),
      data: locationData(freshSample),
      expectedRevision: resumedRevision,
    });
    assert.equal(publication.published, true);

    assert.equal((await applyGhostIntent(owner, change)).status, "idempotent");
    assert.equal((await applyGhostIntent(owner, {
      ...change,
      enabled: true,
    })).status, "conflict", "the same revision with a different intent is not idempotent");

    const after = await getDocFromServer(profileReference(owner));
    assert.equal(after.get("isGhostModeEnabled"), false);
    assert.equal(after.get("locationSharingRevision"), resumedRevision);
    assert.ok(after.get("locationSharingResumedAt").isEqual(resumedAt));
    const location = await getDocFromServer(locationReference(owner));
    assert.equal(location.exists(), true);
    assert.ok(location.get("sampledAt").isEqual(freshSample));
  });

  test("limitation: unchanged rules still allow an old owner's unconditional writes during ghost mode", async () => {
    const currentClient = authenticatedFirestore(ownerId);
    const oldClient = authenticatedFirestore(ownerId);
    const friend = authenticatedFirestore(friendId);
    await changeGhostMode(currentClient, true, ghostRevision);

    await assertSucceeds(setDoc(locationReference(oldClient), locationData()));
    await assertSucceeds(setDoc(cellReference(oldClient), { sharedAt: serverTimestamp() }));

    assert.equal((await getDocFromServer(profileReference(friend))).get(
      "isGhostModeEnabled",
    ), true);
    const location = await assertSucceeds(getDocFromServer(locationReference(friend)));
    assert.equal(location.exists(), true);
    assert.ok(location.get("location") instanceof GeoPoint);
    assert.equal((await getDocFromServer(cellReference(friend))).exists(), true);
  });
});
