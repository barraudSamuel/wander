import assert from "node:assert/strict";
import { describe, test } from "node:test";
import {
  acceptedRecipientIDs,
  buildFriendRequestNotificationContent,
  buildNotificationContent,
  buildOutingAttendanceNotificationContent,
  deduplicateTargetsByToken,
  friendRequestDispatchID,
  friendRequestNotificationData,
  friendRequestRecipientID,
  isPermanentMessagingError,
  notificationData,
  outingAttendanceDispatchID,
  outingAttendanceNotificationData,
  outingAttendanceRecipientIDs,
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

describe("friend request notifications", () => {
  test("targets only the recipient of a valid pending friendship", () => {
    assert.equal(
      friendRequestRecipientID("recipient__requester", {
        participants: ["recipient", "requester"],
        requestedBy: "requester",
        status: "pending",
      }),
      "recipient",
    );

    assert.equal(
      friendRequestRecipientID("recipient__requester", {
        participants: ["recipient", "requester"],
        requestedBy: "recipient",
        status: "pending",
      }),
      "requester",
    );
  });

  test("rejects accepted, malformed, mismatched, and self friendships", () => {
    assert.equal(
      friendRequestRecipientID("recipient__requester", {
        participants: ["recipient", "requester"],
        requestedBy: "requester",
        status: "accepted",
      }),
      null,
    );
    assert.equal(
      friendRequestRecipientID("requester__recipient", {
        participants: ["recipient", "requester"],
        requestedBy: "requester",
        status: "pending",
      }),
      null,
    );
    assert.equal(
      friendRequestRecipientID("recipient__requester", {
        participants: ["recipient", "requester"],
        requestedBy: "stranger",
        status: "pending",
      }),
      null,
    );
    assert.equal(
      friendRequestRecipientID("same__same", {
        participants: ["same", "same"],
        requestedBy: "same",
        status: "pending",
      }),
      null,
    );
  });

  test("builds private visible content and a minimal route", () => {
    assert.deepEqual(
      buildFriendRequestNotificationContent("Samuel"),
      {
        title: "Demande d’ami",
        body: "Samuel veut devenir ton ami.",
      },
    );
    assert.deepEqual(
      friendRequestNotificationData("recipient__requester"),
      {
        type: "friendRequestCreated",
        friendshipId: "recipient__requester",
      },
    );
    assert.throws(() => buildFriendRequestNotificationContent("Samuel "));
    assert.throws(() => friendRequestNotificationData("invalid"));
  });

  test("uses the creation timestamp to distinguish later requests", () => {
    assert.notEqual(
      friendRequestDispatchID("recipient__requester", 1, 0),
      friendRequestDispatchID("recipient__requester", 2, 0),
    );
    assert.equal(
      friendRequestDispatchID("recipient__requester", 1, 42),
      "friendRequest__recipient__requester__1_42",
    );
    assert.throws(() =>
      friendRequestDispatchID("recipient__requester", 1, -1)
    );
  });
});

describe("outing attendance notifications", () => {
  const publicationID = "5e973c7d-f824-4e73-8ef0-f86cfeaf21e2";

  test("targets the owner and current accepted participants except the joiner", () => {
    assert.deepEqual(
      outingAttendanceRecipientIDs(
        "owner",
        "joiner",
        publicationID,
        ["joiner", "participant-a", "participant-b", "revoked"],
        [
          { participantId: "joiner", publicationId: publicationID },
          { participantId: "participant-b", publicationId: publicationID },
          { participantId: "participant-a", publicationId: publicationID },
          { participantId: "participant-a", publicationId: publicationID },
          { participantId: "revoked", publicationId: crypto.randomUUID() },
          { participantId: "stranger", publicationId: publicationID },
          { participantId: "invalid__id", publicationId: publicationID },
        ],
      ),
      ["owner", "participant-a", "participant-b"],
    );
  });

  test("builds named content without private route data", () => {
    assert.deepEqual(
      buildOutingAttendanceNotificationContent("Léa", "Namsan"),
      {
        title: "Nouvelle participation",
        body: "Léa va vous rejoindre pour Namsan.",
      },
    );
    assert.deepEqual(
      outingAttendanceNotificationData("owner", publicationID),
      {
        type: "outingAttendanceCreated",
        outingOwnerId: "owner",
        publicationId: publicationID,
      },
    );
    assert.equal(
      JSON.stringify(
        outingAttendanceNotificationData("owner", publicationID),
      ).includes("participant"),
      false,
    );
    assert.throws(() =>
      buildOutingAttendanceNotificationContent("Léa ", "Namsan")
    );
  });

  test("uses a deterministic identity and rejects malformed identities", () => {
    assert.equal(
      outingAttendanceDispatchID("owner", publicationID, "joiner", 12, 34),
      `outingAttendance__owner__${publicationID}__joiner__12_34`,
    );
    assert.throws(() =>
      outingAttendanceDispatchID("owner", publicationID, "owner", 12, 34)
    );
    assert.throws(() =>
      outingAttendanceDispatchID("owner", publicationID, "joiner", 12, -1)
    );
    assert.throws(() =>
      outingAttendanceRecipientIDs(
        "owner",
        "owner",
        publicationID,
        [],
        [],
      )
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
