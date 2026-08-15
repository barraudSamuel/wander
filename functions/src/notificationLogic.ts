export interface OutingNotificationInput {
  displayName: string;
  placeName: string;
  plannedAt: Date;
  timeZoneIdentifier: string;
}

export interface NotificationContent {
  title: string;
  body: string;
}

export interface FriendshipCandidate {
  participants?: unknown;
  status?: unknown;
}

export interface DeviceTargetCandidate {
  recipientID: string;
  deviceID: string;
  token: string;
  updatedAtMilliseconds: number;
}

export function acceptedRecipientIDs(
  ownerID: string,
  friendships: readonly FriendshipCandidate[],
): string[] {
  const recipients = new Set<string>();

  for (const friendship of friendships) {
    if (friendship.status !== "accepted") {
      continue;
    }
    if (!Array.isArray(friendship.participants)) {
      continue;
    }

    const participants = friendship.participants.filter(
      (value): value is string => typeof value === "string" && value.length > 0,
    );
    if (
      participants.length !== 2 ||
      new Set(participants).size !== 2 ||
      !participants.includes(ownerID)
    ) {
      continue;
    }

    const recipientID = participants.find((value) => value !== ownerID);
    if (recipientID && isValidUserID(recipientID)) {
      recipients.add(recipientID);
    }
  }

  return [...recipients].sort();
}

export function buildNotificationContent(
  input: OutingNotificationInput,
): NotificationContent {
  const displayName = normalizedRequiredText(input.displayName, 50);
  const placeName = normalizedRequiredText(input.placeName, 120);
  if (
    Number.isNaN(input.plannedAt.getTime()) ||
    !isSupportedTimeZone(input.timeZoneIdentifier)
  ) {
    throw new Error("Invalid outing notification input");
  }

  const time = new Intl.DateTimeFormat("fr-FR", {
    hour: "2-digit",
    minute: "2-digit",
    hourCycle: "h23",
    timeZone: input.timeZoneIdentifier,
  }).format(input.plannedAt);

  return {
    title: "Sortie prévue",
    body: `${displayName} prévoit ${placeName} à ${time}`,
  };
}

export function notificationData(
  ownerID: string,
  publicationID: string,
): Record<string, string> {
  if (!isValidUserID(ownerID) || !isValidPublicationID(publicationID)) {
    throw new Error("Invalid outing notification route");
  }

  return {
    type: "outingPublished",
    outingOwnerId: ownerID,
    publicationId: publicationID,
  };
}

export function deduplicateTargetsByToken<T extends DeviceTargetCandidate>(
  targets: readonly T[],
): T[] {
  const sortedTargets = [...targets].sort((lhs, rhs) => {
    if (lhs.updatedAtMilliseconds !== rhs.updatedAtMilliseconds) {
      return rhs.updatedAtMilliseconds - lhs.updatedAtMilliseconds;
    }
    return `${lhs.recipientID}/${lhs.deviceID}`.localeCompare(
      `${rhs.recipientID}/${rhs.deviceID}`,
    );
  });
  const seenTokens = new Set<string>();

  return sortedTargets.filter((target) => {
    if (seenTokens.has(target.token)) {
      return false;
    }
    seenTokens.add(target.token);
    return true;
  });
}

export function isPermanentMessagingError(code: string | undefined): boolean {
  return code === "messaging/invalid-registration-token" ||
    code === "messaging/registration-token-not-registered" ||
    code === "messaging/installation-id-not-registered";
}

export function isValidUserID(value: string): boolean {
  return value.length >= 1 && value.length <= 128 && !value.includes("__");
}

export function isValidPublicationID(value: string): boolean {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
    .test(value);
}

function normalizedRequiredText(value: string, maximumLength: number): string {
  const normalized = value.trim().split(/\s+/u).join(" ");
  if (!normalized || normalized !== value || normalized.length > maximumLength) {
    throw new Error("Invalid outing notification text");
  }
  return normalized;
}

function isSupportedTimeZone(identifier: string): boolean {
  try {
    new Intl.DateTimeFormat("fr-FR", { timeZone: identifier }).format();
    return true;
  } catch {
    return false;
  }
}
