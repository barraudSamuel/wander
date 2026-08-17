import assert from "node:assert/strict";
import { describe, test } from "node:test";
import {
  acceptedRecipientIDs,
  buildEventAttendanceNotificationContent,
  buildEventNotificationContent,
  buildFriendRequestNotificationContent,
  deduplicateTargetsByToken,
  eventAttendanceDispatchID,
  eventAttendanceNotificationData,
  eventAttendanceRecipientIDs,
  eventDispatchID,
  eventNotificationData,
  friendRequestDispatchID,
  friendRequestNotificationData,
  friendRequestRecipientID,
  isPermanentMessagingError,
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
  test("contains only the public event summary", () => {
    const content = buildEventNotificationContent({
      displayName: "Samuel",
      placeName: "Gyeongbokgung Palace",
      plannedAt: new Date("2026-08-14T10:30:00.000Z"),
      timeZoneIdentifier: "Asia/Seoul",
    });

    assert.deepEqual(content, {
      title: "Événement prévu",
      body: "Samuel prévoit Gyeongbokgung Palace à 19:30",
    });
    assert.equal(JSON.stringify(content).includes("latitude"), false);
    assert.equal(JSON.stringify(content).includes("address"), false);
  });

  test("rejects non-normalized text and invalid time zones", () => {
    assert.throws(() => buildEventNotificationContent({
      displayName: "Samuel ",
      placeName: "Palace",
      plannedAt: new Date(),
      timeZoneIdentifier: "Asia/Seoul",
    }));
    assert.throws(() => buildEventNotificationContent({
      displayName: "Samuel",
      placeName: "Palace",
      plannedAt: new Date(),
      timeZoneIdentifier: "Not/AZone",
    }));
  });

  test("route payload has no location or account recipient data", () => {
    assert.deepEqual(
      eventNotificationData(
        "owner",
        "52e973c7-f824-4e73-8ef0-f86cfeaf21e2",
        "5e973c7d-f824-4e73-8ef0-f86cfeaf21e2",
      ),
      {
        type: "eventPublished",
        eventOwnerId: "owner",
        eventId: "52e973c7-f824-4e73-8ef0-f86cfeaf21e2",
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

describe("event attendance notifications", () => {
  const publicationID = "5e973c7d-f824-4e73-8ef0-f86cfeaf21e2";

  test("targets the owner and current accepted participants except the joiner", () => {
    assert.deepEqual(
      eventAttendanceRecipientIDs(
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
      buildEventAttendanceNotificationContent("Léa", "Namsan"),
      {
        title: "Nouvelle participation",
        body: "Léa va vous rejoindre pour Namsan.",
      },
    );
    assert.deepEqual(
      eventAttendanceNotificationData(
        "owner",
        "52e973c7-f824-4e73-8ef0-f86cfeaf21e2",
        publicationID,
      ),
      {
        type: "eventAttendanceCreated",
        eventOwnerId: "owner",
        eventId: "52e973c7-f824-4e73-8ef0-f86cfeaf21e2",
        publicationId: publicationID,
      },
    );
    assert.equal(
      JSON.stringify(
        eventAttendanceNotificationData(
          "owner",
          "52e973c7-f824-4e73-8ef0-f86cfeaf21e2",
          publicationID,
        ),
      ).includes("participant"),
      false,
    );
    assert.throws(() =>
      buildEventAttendanceNotificationContent("Léa ", "Namsan")
    );
  });

  test("uses a deterministic identity and rejects malformed identities", () => {
    assert.equal(
      eventAttendanceDispatchID(
        "owner",
        "52e973c7-f824-4e73-8ef0-f86cfeaf21e2",
        publicationID,
        "joiner",
        12,
        34,
      ),
      `eventAttendance__owner__52e973c7-f824-4e73-8ef0-f86cfeaf21e2__${publicationID}__joiner__12_34`,
    );
    assert.throws(() =>
      eventAttendanceDispatchID(
        "owner",
        "52e973c7-f824-4e73-8ef0-f86cfeaf21e2",
        publicationID,
        "owner",
        12,
        34,
      )
    );
    assert.throws(() =>
      eventAttendanceDispatchID(
        "owner",
        "52e973c7-f824-4e73-8ef0-f86cfeaf21e2",
        publicationID,
        "joiner",
        12,
        -1,
      )
    );
    assert.throws(() =>
      eventAttendanceRecipientIDs(
        "owner",
        "owner",
        publicationID,
        [],
        [],
      )
    );
  });
});

describe("event notification identities", () => {
  const eventID = "52e973c7-f824-4e73-8ef0-f86cfeaf21e2";
  const publicationID = "5e973c7d-f824-4e73-8ef0-f86cfeaf21e2";

  test("routes a publication to one stable event", () => {
    assert.deepEqual(
      eventNotificationData("owner", eventID, publicationID),
      {
        type: "eventPublished",
        eventOwnerId: "owner",
        eventId: eventID,
        publicationId: publicationID,
      },
    );
    assert.equal(
      eventDispatchID("owner", eventID, publicationID),
      `event__owner__${eventID}__${publicationID}`,
    );
  });

  test("routes an attendance to one event and one publication", () => {
    assert.deepEqual(
      eventAttendanceNotificationData(
        "owner",
        eventID,
        publicationID,
      ),
      {
        type: "eventAttendanceCreated",
        eventOwnerId: "owner",
        eventId: eventID,
        publicationId: publicationID,
      },
    );
    assert.equal(
      eventAttendanceDispatchID(
        "owner",
        eventID,
        publicationID,
        "joiner",
        12,
        34,
      ),
      `eventAttendance__owner__${eventID}__${publicationID}__joiner__12_34`,
    );
  });

  test("rejects malformed and incomplete multi-event identities", () => {
    assert.throws(() =>
      eventNotificationData("owner", "not-a-uuid", publicationID)
    );
    assert.throws(() =>
      eventDispatchID("owner", eventID, "not-a-uuid")
    );
    assert.throws(() =>
      eventAttendanceDispatchID(
        "owner",
        eventID,
        publicationID,
        "owner",
        12,
        34,
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
