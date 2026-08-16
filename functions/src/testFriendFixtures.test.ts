import assert from "node:assert/strict";
import { describe, test } from "node:test";
import {
  applicationDefault,
  deleteApp,
  initializeApp,
} from "firebase-admin/app";
import { Timestamp, getFirestore } from "firebase-admin/firestore";
import {
  FixtureToolError,
  buildFixturePlan,
  buildManifestData,
  cleanupTestFriendFixtures,
  fixtureTargetPaths,
  notificationDispatchID,
  parseFixtureManifest,
  refreshTestFriendLocations,
  seedTestFriendFixtures,
} from "./testFriendFixtures.js";
import { parseFixtureCLIArguments } from "./testFriendFixturesCli.js";

const projectID = "wander-1954f";
const ownerUID = "owner-fixture-test";
const now = new Date("2026-08-16T12:00:00.000Z");

function plan() {
  return buildFixturePlan({
    projectID,
    ownerUID,
    acceptedCount: 8,
    pendingCount: 3,
    locationPreset: "seoul",
    now,
  });
}

describe("test friend fixture planning", () => {
  test("builds deterministic, distinct and schema-compatible fixtures", () => {
    const first = plan();
    const second = plan();

    assert.deepEqual(first, second);
    assert.equal(first.fixtures.length, 11);
    assert.equal(new Set(first.fixtures.map((fixture) => fixture.userID)).size, 11);
    assert.equal(
      new Set(first.fixtures.map((fixture) => fixture.friendCode)).size,
      11,
    );
    assert.equal(
      new Set(first.fixtures.map((fixture) =>
        `${fixture.location.latitude}/${fixture.location.longitude}`
      )).size,
      11,
    );
    assert.equal(
      first.fixtures.filter((fixture) => fixture.status === "accepted").length,
      8,
    );
    assert.equal(
      first.fixtures.filter((fixture) => fixture.status === "pending").length,
      3,
    );

    for (const fixture of first.fixtures) {
      assert.match(fixture.userID, /^wander-test-[a-f0-9]{12}-[0-9]{2}$/);
      assert.match(fixture.friendCode, /^[A-HJ-NP-Z2-9]{12}$/);
      assert.ok(fixture.friendshipID.includes(ownerUID));
      assert.ok(fixture.location.latitude >= 37.4);
      assert.ok(fixture.location.latitude <= 37.7);
      assert.ok(fixture.location.longitude >= 126.8);
      assert.ok(fixture.location.longitude <= 127.2);
      assert.ok(fixture.location.spotEnteredAt <= now);
    }
  });

  test("namespaces fixture identifiers by owner", () => {
    const first = plan();
    const other = buildFixturePlan({
      projectID,
      ownerUID: "another-owner",
      acceptedCount: 8,
      pendingCount: 3,
      locationPreset: "seoul",
      now,
    });

    assert.notEqual(first.ownerHash, other.ownerHash);
    assert.notEqual(first.fixtures[0]?.userID, other.fixtures[0]?.userID);
    assert.notEqual(first.fixtures[0]?.friendCode, other.fixtures[0]?.friendCode);
  });

  test("limits the total number of fixtures", () => {
    assert.throws(
      () => buildFixturePlan({
        projectID,
        ownerUID,
        acceptedCount: 50,
        pendingCount: 1,
        locationPreset: "seoul",
      }),
      FixtureToolError,
    );
    assert.throws(
      () => buildFixturePlan({
        projectID,
        ownerUID,
        acceptedCount: 0,
        pendingCount: 0,
        locationPreset: "seoul",
      }),
      FixtureToolError,
    );
  });
});

describe("fixture manifest safety", () => {
  test("round-trips only the expected deterministic targets", () => {
    const fixturePlan = plan();
    const timestamp = Timestamp.fromDate(now);
    const manifest = buildManifestData(fixturePlan, timestamp);
    const parsed = parseFixtureManifest(manifest, projectID, ownerUID);

    assert.equal(parsed.plan.configurationHash, fixturePlan.configurationHash);
    assert.deepEqual(parsed.manifest.fixtures, manifest.fixtures);
    assert.equal(fixtureTargetPaths(parsed.plan).length, 44);
  });

  test("rejects a manifest whose exact targets were altered", () => {
    const fixturePlan = plan();
    const manifest = buildManifestData(fixturePlan, Timestamp.fromDate(now));
    const firstFixture = manifest.fixtures[0];
    assert.ok(firstFixture);
    const tampered = {
      ...manifest,
      fixtures: [
        { ...firstFixture, userID: "real-user" },
        ...manifest.fixtures.slice(1),
      ],
    };

    assert.throws(
      () => parseFixtureManifest(tampered, projectID, ownerUID),
      FixtureToolError,
    );
  });

  test("derives the notification dispatch from the exact pending timestamp", () => {
    const fixturePlan = plan();
    const pending = fixturePlan.fixtures.find(
      (fixture) => fixture.status === "pending",
    );
    assert.ok(pending);
    const timestamp = Timestamp.fromDate(now);

    assert.equal(
      notificationDispatchID(pending.friendshipID, timestamp),
      `friendRequest__${pending.friendshipID}__${timestamp.seconds}_${timestamp.nanoseconds}`,
    );
  });

  test("requires explicit notification consent before a remote write", async () => {
    await assert.rejects(
      () => seedTestFriendFixtures({} as never, {
        projectID,
        ownerUID,
        acceptedCount: 1,
        pendingCount: 1,
        locationPreset: "seoul",
        apply: true,
        allowNotifications: false,
        isEmulator: false,
      }),
      FixtureToolError,
    );
  });
});

describe("fixture command parsing", () => {
  test("defaults to eight accepted friends in Seoul and dry-run", () => {
    const options = parseFixtureCLIArguments([
      "seed",
      "--project",
      projectID,
      "--owner-uid",
      ownerUID,
    ]);

    assert.equal(options.acceptedCount, 8);
    assert.equal(options.pendingCount, 0);
    assert.equal(options.locationPreset, "seoul");
    assert.equal(options.apply, false);
  });

  test("accepts explicit pending notifications and apply", () => {
    const options = parseFixtureCLIArguments([
      "seed",
      "--project",
      projectID,
      "--owner-uid",
      ownerUID,
      "--accepted",
      "5",
      "--pending",
      "2",
      "--allow-notifications",
      "--apply",
    ]);

    assert.equal(options.acceptedCount, 5);
    assert.equal(options.pendingCount, 2);
    assert.equal(options.allowNotifications, true);
    assert.equal(options.apply, true);
  });

  test("rejects missing identifiers, unknown flags and seed-only options", () => {
    assert.throws(
      () => parseFixtureCLIArguments(["seed", "--project", projectID]),
      FixtureToolError,
    );
    assert.throws(
      () => parseFixtureCLIArguments([
        "seed",
        "--project",
        projectID,
        "--owner-uid",
        ownerUID,
        "--unknown",
      ]),
      FixtureToolError,
    );
    assert.throws(
      () => parseFixtureCLIArguments([
        "cleanup",
        "--project",
        projectID,
        "--owner-uid",
        ownerUID,
        "--pending",
        "1",
      ]),
      FixtureToolError,
    );
  });
});

describe("fixture lifecycle", () => {
  test(
    "creates, refreshes and removes only its emulator fixtures",
    { skip: !process.env.FIRESTORE_EMULATOR_HOST },
    async () => {
      const emulatorProjectID = "demo-wander-fixture-lifecycle";
      const emulatorOwnerUID = "emulator-owner";
      process.env.METADATA_SERVER_DETECTION = "none";
      const app = initializeApp(
        {
          credential: applicationDefault(),
          projectId: emulatorProjectID,
        },
        `fixture-lifecycle-${Date.now()}`,
      );
      const database = getFirestore(app);
      const fixturePlan = buildFixturePlan({
        projectID: emulatorProjectID,
        ownerUID: emulatorOwnerUID,
        acceptedCount: 2,
        pendingCount: 1,
        locationPreset: "seoul",
        now,
      });
      const ownerReference = database.collection("users").doc(emulatorOwnerUID);
      const unrelatedReference = database.collection("users").doc(
        "unrelated-emulator-user",
      );
      const collisionReference = database.collection("users").doc(
        fixturePlan.fixtures[0]?.userID ?? "missing",
      );

      try {
        await ownerReference.set({ displayName: "Owner" });
        await unrelatedReference.set({ displayName: "Unrelated" });
        await collisionReference.set({ displayName: "Collision" });
        await assert.rejects(
          () => seedTestFriendFixtures(database, {
            projectID: emulatorProjectID,
            ownerUID: emulatorOwnerUID,
            acceptedCount: 2,
            pendingCount: 1,
            locationPreset: "seoul",
            now,
            apply: false,
            allowNotifications: false,
            isEmulator: true,
          }),
          FixtureToolError,
        );
        await collisionReference.delete();

        const drySeed = await seedTestFriendFixtures(database, {
          projectID: emulatorProjectID,
          ownerUID: emulatorOwnerUID,
          acceptedCount: 2,
          pendingCount: 1,
          locationPreset: "seoul",
          now,
          apply: false,
          allowNotifications: false,
          isEmulator: true,
        });
        assert.equal(drySeed.outcome, "would-create");
        assert.equal(
          (await database.collection("users").doc(
            fixturePlan.fixtures[0]?.userID ?? "missing",
          ).get()).exists,
          false,
        );

        const created = await seedTestFriendFixtures(database, {
          projectID: emulatorProjectID,
          ownerUID: emulatorOwnerUID,
          acceptedCount: 2,
          pendingCount: 1,
          locationPreset: "seoul",
          now,
          apply: true,
          allowNotifications: false,
          isEmulator: true,
        });
        assert.equal(created.outcome, "created");
        assert.equal(
          (await database.collection("users").doc(
            fixturePlan.fixtures[0]?.userID ?? "missing",
          ).get()).exists,
          true,
        );

        const repeated = await seedTestFriendFixtures(database, {
          projectID: emulatorProjectID,
          ownerUID: emulatorOwnerUID,
          acceptedCount: 2,
          pendingCount: 1,
          locationPreset: "seoul",
          now,
          apply: true,
          allowNotifications: false,
          isEmulator: true,
        });
        assert.equal(repeated.outcome, "already-present");

        const refreshedAt = new Date("2026-08-16T13:00:00.000Z");
        const refreshed = await refreshTestFriendLocations(database, {
          projectID: emulatorProjectID,
          ownerUID: emulatorOwnerUID,
          apply: true,
          now: refreshedAt,
        });
        assert.equal(refreshed.outcome, "refreshed");
        const firstLocation = await database.collection("locations").doc(
          fixturePlan.fixtures[0]?.userID ?? "missing",
        ).get();
        assert.equal(
          (firstLocation.data()?.sampledAt as Timestamp | undefined)?.toMillis(),
          refreshedAt.getTime(),
        );

        const dryCleanup = await cleanupTestFriendFixtures(database, {
          projectID: emulatorProjectID,
          ownerUID: emulatorOwnerUID,
          apply: false,
        });
        assert.equal(dryCleanup.outcome, "would-clean");
        const cleaned = await cleanupTestFriendFixtures(database, {
          projectID: emulatorProjectID,
          ownerUID: emulatorOwnerUID,
          apply: true,
        });
        assert.equal(cleaned.outcome, "cleaned");
        assert.equal(
          (await database.collection("users").doc(
            fixturePlan.fixtures[0]?.userID ?? "missing",
          ).get()).exists,
          false,
        );
        assert.equal((await ownerReference.get()).exists, true);
        assert.equal((await unrelatedReference.get()).exists, true);
      } finally {
        await ownerReference.delete();
        await unrelatedReference.delete();
        await deleteApp(app);
      }
    },
  );
});
