import assert from "node:assert/strict";
import { describe, test } from "node:test";
import {
  acceptedFriendshipMatches,
  isLocationPushRateLimited,
  isLocationSampleFresh,
  isPermanentAPNsLocationPushFailure,
  isValidLocationRefreshRequest,
  locationPushCooldownMilliseconds,
  locationPushPairID,
  locationPushRegistrationLifetimeMilliseconds,
  locationPushTargets,
} from "./locationPushLogic.js";

describe("location refresh authorization", () => {
  const requestID = "52e973c7-f824-4e73-8ef0-f86cfeaf21e2";

  test("accepts a distinct target and a UUID request", () => {
    assert.equal(
      isValidLocationRefreshRequest("owner", "friend", requestID),
      true,
    );
  });

  test("rejects self, malformed users, and malformed request IDs", () => {
    assert.equal(isValidLocationRefreshRequest("owner", "owner", requestID), false);
    assert.equal(isValidLocationRefreshRequest("owner", "bad/user", requestID), false);
    assert.equal(isValidLocationRefreshRequest("owner", "friend", "request"), false);
  });

  test("requires the exact accepted pair", () => {
    assert.equal(
      acceptedFriendshipMatches("owner", "friend", {
        participants: ["friend", "owner"],
        status: "accepted",
      }),
      true,
    );
    assert.equal(
      acceptedFriendshipMatches("owner", "friend", {
        participants: ["friend", "owner"],
        status: "pending",
      }),
      false,
    );
    assert.equal(
      acceptedFriendshipMatches("owner", "friend", {
        participants: ["friend", "stranger"],
        status: "accepted",
      }),
      false,
    );
  });

  test("builds the deterministic friendship path", () => {
    assert.equal(locationPushPairID("owner", "friend"), "friend__owner");
    assert.throws(() => locationPushPairID("owner", "owner"));
  });
});

describe("location refresh freshness and quota", () => {
  const now = Date.parse("2026-08-31T12:00:00Z");

  test("accepts only samples younger than five minutes", () => {
    assert.equal(isLocationSampleFresh(now - 299_999, now), true);
    assert.equal(isLocationSampleFresh(now - 300_000, now), false);
    assert.equal(isLocationSampleFresh(now + 60_000, now), true);
    assert.equal(isLocationSampleFresh(now + 60_001, now), false);
  });

  test("rate limits target-wide dispatches for four minutes", () => {
    assert.equal(
      isLocationPushRateLimited(now - locationPushCooldownMilliseconds + 1, now),
      true,
    );
    assert.equal(
      isLocationPushRateLimited(now - locationPushCooldownMilliseconds, now),
      false,
    );
    assert.equal(isLocationPushRateLimited(undefined, now), false);
  });
});

describe("location push device targets", () => {
  const firstToken = "ab".repeat(32);
  const secondToken = "cd".repeat(32);
  const now = Date.parse("2026-08-31T12:00:00Z");

  test("filters malformed devices and keeps the newest duplicate token", () => {
    assert.deepEqual(
      locationPushTargets([
        {
          deviceID: "older",
          token: firstToken,
          environment: "sandbox",
          updatedAtMilliseconds: now - 3_000,
        },
        {
          deviceID: "newer",
          token: firstToken,
          environment: "sandbox",
          updatedAtMilliseconds: now - 1_000,
        },
        {
          deviceID: "production",
          token: secondToken,
          environment: "production",
          updatedAtMilliseconds: now - 2_000,
        },
        {
          deviceID: "invalid-token",
          token: "not-hex",
          environment: "sandbox",
          updatedAtMilliseconds: now - 4_000,
        },
        {
          deviceID: "invalid-environment",
          token: "ef".repeat(32),
          environment: "preview",
          updatedAtMilliseconds: now - 5_000,
        },
      ], now),
      [
        {
          deviceID: "newer",
          token: firstToken,
          environment: "sandbox",
          updatedAtMilliseconds: now - 1_000,
        },
        {
          deviceID: "production",
          token: secondToken,
          environment: "production",
          updatedAtMilliseconds: now - 2_000,
        },
      ],
    );
  });

  test("drops registrations that were not renewed in thirty days", () => {
    assert.deepEqual(
      locationPushTargets([
        {
          deviceID: "expired",
          token: firstToken,
          environment: "sandbox",
          updatedAtMilliseconds:
            now - locationPushRegistrationLifetimeMilliseconds - 1,
        },
      ], now),
      [],
    );
  });

  test("identifies only token-invalidating APNs reasons as permanent", () => {
    assert.equal(isPermanentAPNsLocationPushFailure("BadDeviceToken"), true);
    assert.equal(isPermanentAPNsLocationPushFailure("Unregistered"), true);
    assert.equal(isPermanentAPNsLocationPushFailure("TooManyRequests"), false);
    assert.equal(isPermanentAPNsLocationPushFailure("InternalServerError"), false);
  });
});
