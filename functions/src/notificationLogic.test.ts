import assert from "node:assert/strict";
import { describe, test } from "node:test";
import {
  acceptedRecipientIDs,
  buildNotificationContent,
  deduplicateTargetsByToken,
  isPermanentMessagingError,
  notificationData,
} from "./notificationLogic.js";

describe("acceptedRecipientIDs", () => {
  test("targets only unique accepted friends", () => {
    assert.deepEqual(
      acceptedRecipientIDs("owner", [
        { participants: ["friend-b", "owner"], status: "accepted" },
        { participants: ["owner", "pending"], status: "pending" },
        { participants: ["owner", "friend-a"], status: "accepted" },
        { participants: ["owner", "friend-a"], status: "accepted" },
        { participants: ["owner", "owner"], status: "accepted" },
        { participants: ["stranger-a", "stranger-b"], status: "accepted" },
        { participants: ["owner", "invalid__friend"], status: "accepted" },
      ]),
      ["friend-a", "friend-b"],
    );
  });
});

describe("notification content", () => {
  test("contains only the public outing summary", () => {
    const content = buildNotificationContent({
      displayName: "Samuel",
      placeName: "Gyeongbokgung Palace",
      plannedAt: new Date("2026-08-14T10:30:00.000Z"),
      timeZoneIdentifier: "Asia/Seoul",
    });

    assert.deepEqual(content, {
      title: "Sortie prévue",
      body: "Samuel prévoit Gyeongbokgung Palace à 19:30",
    });
    assert.equal(JSON.stringify(content).includes("latitude"), false);
    assert.equal(JSON.stringify(content).includes("address"), false);
  });

  test("rejects non-normalized text and invalid time zones", () => {
    assert.throws(() => buildNotificationContent({
      displayName: "Samuel ",
      placeName: "Palace",
      plannedAt: new Date(),
      timeZoneIdentifier: "Asia/Seoul",
    }));
    assert.throws(() => buildNotificationContent({
      displayName: "Samuel",
      placeName: "Palace",
      plannedAt: new Date(),
      timeZoneIdentifier: "Not/AZone",
    }));
  });

  test("route payload has no location or account recipient data", () => {
    assert.deepEqual(
      notificationData(
        "owner",
        "5e973c7d-f824-4e73-8ef0-f86cfeaf21e2",
      ),
      {
        type: "outingPublished",
        outingOwnerId: "owner",
        publicationId: "5e973c7d-f824-4e73-8ef0-f86cfeaf21e2",
      },
    );
  });
});

describe("device targets", () => {
  test("keeps the newest document for a duplicated token", () => {
    const targets = deduplicateTargetsByToken([
      {
        recipientID: "friend-a",
        deviceID: "old",
        token: "same-token",
        updatedAtMilliseconds: 1,
      },
      {
        recipientID: "friend-b",
        deviceID: "new",
        token: "same-token",
        updatedAtMilliseconds: 2,
      },
      {
        recipientID: "friend-a",
        deviceID: "other",
        token: "other-token",
        updatedAtMilliseconds: 1,
      },
    ]);

    assert.equal(targets.length, 2);
    assert.equal(targets.some((target) => target.deviceID === "new"), true);
    assert.equal(targets.some((target) => target.deviceID === "old"), false);
  });

  test("recognizes only permanent registration failures", () => {
    assert.equal(
      isPermanentMessagingError("messaging/registration-token-not-registered"),
      true,
    );
    assert.equal(isPermanentMessagingError("messaging/internal-error"), false);
  });
});
