import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import test from "node:test";
import { deleteApp, initializeApp } from "firebase-admin/app";
import {
  Firestore,
  Timestamp,
  Transaction,
  getFirestore,
} from "firebase-admin/firestore";
import {
  deleteExpiredEvents,
  eventRetentionMilliseconds,
  expiredEventCutoff,
} from "./eventCleanupLogic.js";

test("expiredEventCutoff returns exactly 12 hours before the reference", () => {
  const referenceDate = new Date("2026-08-22T12:00:00.000Z");

  const cutoff = expiredEventCutoff(referenceDate);

  assert.equal(
    cutoff.getTime(),
    referenceDate.getTime() - eventRetentionMilliseconds,
  );
  assert.equal(cutoff.toISOString(), "2026-08-22T00:00:00.000Z");
});

test("the cutoff includes 12-hour-old events and excludes newer ones", () => {
  const cutoff = expiredEventCutoff(
    new Date("2026-08-22T12:00:00.000Z"),
  ).getTime();

  assert.equal(new Date("2026-08-22T00:00:00.000Z").getTime() <= cutoff, true);
  assert.equal(new Date("2026-08-22T00:00:00.001Z").getTime() <= cutoff, false);
});

const emulatorOptions = {
  skip: !process.env.FIRESTORE_EMULATOR_HOST,
  timeout: 30_000,
};
const referenceDate = new Date("2026-09-13T12:00:00.000Z");
const cutoff = Timestamp.fromDate(expiredEventCutoff(referenceDate));
const recentPublication = Timestamp.fromDate(referenceDate);
const oldPublication = Timestamp.fromMillis(cutoff.toMillis() - 86_400_000);
const futureStart = Timestamp.fromMillis(referenceDate.getTime() + 3_600_000);

async function withEmulatorDatabase(
  run: (database: Firestore) => Promise<void>,
): Promise<void> {
  assert.ok(process.env.FIRESTORE_EMULATOR_HOST, "Emulator is required");
  const projectID = `demo-event-cleanup-${randomUUID().slice(0, 8)}`;
  assert.match(projectID, /^demo-/);
  process.env.METADATA_SERVER_DETECTION = "none";
  const app = initializeApp({ projectId: projectID }, projectID);
  const database = getFirestore(app);

  try {
    await run(database);
  } finally {
    try {
      await database.recursiveDelete(database.collection("users"));
    } finally {
      await deleteApp(app);
    }
  }
}

test(
  "cleanup expires events at their start plus 12 hours regardless of publication",
  emulatorOptions,
  async () => withEmulatorDatabase(async (database) => {
    const events = database.collection("users").doc("owner").collection("events");
    const batch = database.batch();
    batch.set(events.doc("expired"), {
      plannedAt: Timestamp.fromMillis(cutoff.toMillis() - 1),
      publishedAt: recentPublication,
    });
    batch.set(events.doc("exactly-12-hours"), {
      plannedAt: cutoff,
      publishedAt: recentPublication,
    });
    batch.set(events.doc("one-millisecond-newer"), {
      plannedAt: Timestamp.fromMillis(cutoff.toMillis() + 1),
      publishedAt: oldPublication,
    });
    batch.set(events.doc("future"), {
      plannedAt: futureStart,
      publishedAt: oldPublication,
    });
    await batch.commit();

    assert.equal(await deleteExpiredEvents(database, cutoff), 2);
    assert.deepEqual(
      (await events.get()).docs.map((document) => document.id).sort(),
      ["future", "one-millisecond-newer"],
    );
  }),
);

test(
  "cleanup honors rescheduling but category edits do not postpone expiration",
  emulatorOptions,
  async () => withEmulatorDatabase(async (database) => {
    const events = database.collection("users").doc("owner").collection("events");
    const rescheduled = events.doc("rescheduled");
    const recategorized = events.doc("recategorized");
    await Promise.all([rescheduled, recategorized].map((reference) =>
      reference.set({
        plannedAt: cutoff,
        publishedAt: oldPublication,
        category: "walk",
      })
    ));
    await rescheduled.update({
      plannedAt: futureStart,
      publishedAt: recentPublication,
    });
    await recategorized.update({
      category: "coffee",
      publishedAt: recentPublication,
    });

    assert.equal(await deleteExpiredEvents(database, cutoff), 1);
    assert.equal((await rescheduled.get()).exists, true);
    assert.equal((await recategorized.get()).exists, false);
  }),
);

test(
  "cleanup removes more than 500 events across owners and is idempotent",
  emulatorOptions,
  async () => withEmulatorDatabase(async (database) => {
    const expiredReferences = Array.from({ length: 503 }, (_, index) =>
      database.doc(`users/owner-${index % 3}/events/expired-${index}`)
    );
    for (let offset = 0; offset < expiredReferences.length; offset += 500) {
      const batch = database.batch();
      for (const reference of expiredReferences.slice(offset, offset + 500)) {
        batch.set(reference, {
          plannedAt: cutoff,
          publishedAt: recentPublication,
        });
      }
      await batch.commit();
    }
    const futureReferences = [
      database.doc("users/owner-0/events/future"),
      database.doc("users/owner-3/events/future"),
    ];
    await Promise.all(futureReferences.map((reference) => reference.set({
      plannedAt: futureStart,
      publishedAt: oldPublication,
    })));

    assert.equal(await deleteExpiredEvents(database, cutoff), 503);
    assert.deepEqual(
      (await database.collectionGroup("events").get()).docs
        .map((document) => document.ref.path).sort(),
      futureReferences.map((reference) => reference.path).sort(),
    );
    assert.equal(await deleteExpiredEvents(database, cutoff), 0);
  }),
);

test(
  "cleanup retries with the new start and counts only committed deletions",
  emulatorOptions,
  async (context) => withEmulatorDatabase(async (database) => {
    const rescheduled = database.doc("users/owner/events/rescheduled");
    const expired = database.doc("users/owner/events/expired");
    await Promise.all([rescheduled, expired].map((reference) => reference.set({
      plannedAt: cutoff,
      publishedAt: oldPublication,
    })));

    const runTransaction = database.runTransaction.bind(database);
    let transactionAttempts = 0;
    let rescheduling: Promise<unknown> | undefined;
    context.mock.method(database, "runTransaction", async <T>(
      updateFunction: (transaction: Transaction) => Promise<T>,
    ): Promise<T> => runTransaction(async (transaction) => {
      transactionAttempts += 1;
      await rescheduling;
      const result = await updateFunction(transaction);
      if (transactionAttempts === 1) {
        // Queue a concurrent edit after the read, then force Firestore to
        // release the transaction locks and retry before any delete commits.
        rescheduling = rescheduled.update({ plannedAt: futureStart });
        throw Object.assign(new Error("Retry after concurrent rescheduling"), {
          code: 10, // Firestore ABORTED
        });
      }
      return result;
    }));

    assert.equal(await deleteExpiredEvents(database, cutoff), 1);
    assert.ok(transactionAttempts >= 3);
    assert.equal((await expired.get()).exists, false);
    const retained = await rescheduled.get();
    assert.equal(retained.exists, true);
    assert.deepEqual(retained.get("plannedAt"), futureStart);
  }),
);
