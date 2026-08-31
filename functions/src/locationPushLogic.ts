export const locationFreshnessMilliseconds = 5 * 60 * 1_000;
export const locationPushCooldownMilliseconds = 4 * 60 * 1_000;
export const locationPushRegistrationLifetimeMilliseconds =
  30 * 24 * 60 * 60 * 1_000;

export type APNsEnvironment = "sandbox" | "production";

export interface LocationPushDeviceCandidate {
  deviceID: string;
  token?: unknown;
  environment?: unknown;
  updatedAtMilliseconds?: unknown;
}

export interface LocationPushTarget {
  deviceID: string;
  token: string;
  environment: APNsEnvironment;
  updatedAtMilliseconds: number;
}

export interface AcceptedFriendshipCandidate {
  participants?: unknown;
  status?: unknown;
}

export function isValidLocationRefreshRequest(
  requesterID: string,
  targetUserID: unknown,
  requestID: unknown,
): targetUserID is string {
  return isValidUserID(requesterID)
    && typeof targetUserID === "string"
    && isValidUserID(targetUserID)
    && targetUserID !== requesterID
    && typeof requestID === "string"
    && /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
      .test(requestID);
}

export function acceptedFriendshipMatches(
  requesterID: string,
  targetUserID: string,
  friendship: AcceptedFriendshipCandidate | undefined,
): boolean {
  if (friendship?.status !== "accepted" || !Array.isArray(friendship.participants)) {
    return false;
  }

  const expected = [requesterID, targetUserID].sort();
  return friendship.participants.length === 2
    && friendship.participants[0] === expected[0]
    && friendship.participants[1] === expected[1];
}

export function isLocationSampleFresh(
  sampledAtMilliseconds: unknown,
  nowMilliseconds: number,
): boolean {
  if (
    typeof sampledAtMilliseconds !== "number"
    || !Number.isFinite(sampledAtMilliseconds)
    || !Number.isFinite(nowMilliseconds)
  ) {
    return false;
  }

  const age = nowMilliseconds - sampledAtMilliseconds;
  return age >= -60_000 && age < locationFreshnessMilliseconds;
}

export function isLocationPushRateLimited(
  lastSentAtMilliseconds: unknown,
  nowMilliseconds: number,
): boolean {
  if (
    typeof lastSentAtMilliseconds !== "number"
    || !Number.isFinite(lastSentAtMilliseconds)
    || !Number.isFinite(nowMilliseconds)
  ) {
    return false;
  }

  const age = nowMilliseconds - lastSentAtMilliseconds;
  return age >= 0 && age < locationPushCooldownMilliseconds;
}

export function locationPushTargets(
  candidates: readonly LocationPushDeviceCandidate[],
  nowMilliseconds: number = Date.now(),
): LocationPushTarget[] {
  const byToken = new Map<string, LocationPushTarget>();

  for (const candidate of candidates) {
    if (
      typeof candidate.token !== "string"
      || !isValidLocationPushToken(candidate.token)
      || (candidate.environment !== "sandbox"
        && candidate.environment !== "production")
      || typeof candidate.updatedAtMilliseconds !== "number"
      || !Number.isFinite(candidate.updatedAtMilliseconds)
      || candidate.updatedAtMilliseconds > nowMilliseconds + 60_000
      || nowMilliseconds - candidate.updatedAtMilliseconds
        > locationPushRegistrationLifetimeMilliseconds
    ) {
      continue;
    }

    const current = byToken.get(candidate.token);
    if (!current || candidate.updatedAtMilliseconds > current.updatedAtMilliseconds) {
      byToken.set(candidate.token, {
        deviceID: candidate.deviceID,
        token: candidate.token,
        environment: candidate.environment,
        updatedAtMilliseconds: candidate.updatedAtMilliseconds,
      });
    }
  }

  return [...byToken.values()].sort((lhs, rhs) =>
    rhs.updatedAtMilliseconds - lhs.updatedAtMilliseconds
      || lhs.deviceID.localeCompare(rhs.deviceID)
  );
}

export function isPermanentAPNsLocationPushFailure(reason: string): boolean {
  return reason === "BadDeviceToken"
    || reason === "DeviceTokenNotForTopic"
    || reason === "Unregistered";
}

export function locationPushPairID(firstUserID: string, secondUserID: string): string {
  if (
    !isValidUserID(firstUserID)
    || !isValidUserID(secondUserID)
    || firstUserID === secondUserID
  ) {
    throw new Error("Invalid location refresh pair");
  }
  return [firstUserID, secondUserID].sort().join("__");
}

function isValidLocationPushToken(token: string): boolean {
  return token.length >= 40
    && token.length <= 400
    && token.length % 2 === 0
    && /^[0-9a-f]+$/i.test(token);
}

function isValidUserID(userID: string): boolean {
  return userID.length >= 1
    && userID.length <= 128
    && !userID.includes("/")
    && !userID.includes("__");
}
