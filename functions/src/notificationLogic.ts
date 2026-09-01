export interface EventNotificationInput {
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

export interface FriendRequestCandidate extends FriendshipCandidate {
  requestedBy?: unknown;
}

export interface AttendanceRecipientCandidate {
  participantId?: unknown;
  publicationId?: unknown;
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

export function buildEventNotificationContent(
  input: EventNotificationInput,
): NotificationContent {
  const displayName = normalizedRequiredText(input.displayName, 50);
  const placeName = normalizedRequiredText(input.placeName, 120);
  if (
    Number.isNaN(input.plannedAt.getTime()) ||
    !isSupportedTimeZone(input.timeZoneIdentifier)
  ) {
    throw new Error("Invalid event notification input");
  }

  const time = new Intl.DateTimeFormat("fr-FR", {
    hour: "2-digit",
    minute: "2-digit",
    hourCycle: "h23",
    timeZone: input.timeZoneIdentifier,
  }).format(input.plannedAt);

  return {
    title: "Événement prévu",
    body: `${displayName} prévoit ${placeName} à ${time}`,
  };
}

export function friendRequestRecipientID(
  pairID: string,
  friendship: FriendRequestCandidate,
): string | null {
  if (friendship.status !== "pending" || !Array.isArray(friendship.participants)) {
    return null;
  }

  const participants = friendship.participants;
  if (
    participants.length !== 2 ||
    typeof participants[0] !== "string" ||
    typeof participants[1] !== "string" ||
    !isValidUserID(participants[0]) ||
    !isValidUserID(participants[1]) ||
    participants[0] >= participants[1] ||
    pairID !== `${participants[0]}__${participants[1]}` ||
    typeof friendship.requestedBy !== "string" ||
    !participants.includes(friendship.requestedBy)
  ) {
    return null;
  }

  return participants.find(
    (participant) => participant !== friendship.requestedBy,
  ) ?? null;
}

export function buildFriendRequestNotificationContent(
  displayName: string,
): NotificationContent {
  const normalizedDisplayName = normalizedRequiredText(displayName, 50);
  return {
    title: "Demande d’ami",
    body: `${normalizedDisplayName} veut devenir ton ami.`,
  };
}

export function eventAttendanceRecipientIDs(
  ownerID: string,
  joiningParticipantID: string,
  publicationID: string,
  acceptedFriendIDs: readonly string[],
  attendances: readonly AttendanceRecipientCandidate[],
): string[] {
  if (
    !isValidUserID(ownerID) ||
    !isValidUserID(joiningParticipantID) ||
    ownerID === joiningParticipantID ||
    !isValidPublicationID(publicationID)
  ) {
    throw new Error("Invalid event attendance recipients");
  }

  const accepted = new Set(
    acceptedFriendIDs.filter((candidate) => isValidUserID(candidate)),
  );
  const recipients = new Set<string>([ownerID]);

  for (const attendance of attendances) {
    if (
      attendance.publicationId !== publicationID ||
      typeof attendance.participantId !== "string" ||
      attendance.participantId === joiningParticipantID ||
      !accepted.has(attendance.participantId)
    ) {
      continue;
    }
    recipients.add(attendance.participantId);
  }

  return [...recipients].sort();
}

export function buildEventAttendanceNotificationContent(
  displayName: string,
  placeName: string,
): NotificationContent {
  const normalizedDisplayName = normalizedRequiredText(displayName, 50);
  const normalizedPlaceName = normalizedRequiredText(placeName, 120);
  return {
    title: "Nouvelle participation",
    body: `${normalizedDisplayName} va vous rejoindre pour ${normalizedPlaceName}.`,
  };
}

export function eventAttendanceNotificationData(
  ownerID: string,
  eventID: string,
  publicationID: string,
): Record<string, string> {
  if (
    !isValidUserID(ownerID) ||
    !isValidEventID(eventID) ||
    !isValidPublicationID(publicationID)
  ) {
    throw new Error("Invalid event attendance notification route");
  }

  return {
    type: "eventAttendanceCreated",
    eventOwnerId: ownerID,
    eventId: eventID,
    publicationId: publicationID,
  };
}

export function eventAttendanceDispatchID(
  ownerID: string,
  eventID: string,
  publicationID: string,
  participantID: string,
  joinedAtSeconds: number,
  joinedAtNanoseconds: number,
): string {
  if (
    !isValidUserID(ownerID) ||
    !isValidEventID(eventID) ||
    !isValidPublicationID(publicationID) ||
    !isValidUserID(participantID) ||
    ownerID === participantID ||
    !Number.isSafeInteger(joinedAtSeconds) ||
    !Number.isInteger(joinedAtNanoseconds) ||
    joinedAtNanoseconds < 0 ||
    joinedAtNanoseconds > 999_999_999
  ) {
    throw new Error("Invalid event attendance dispatch identity");
  }

  return `eventAttendance__${ownerID}__${eventID}__${publicationID}__${participantID}__${joinedAtSeconds}_${joinedAtNanoseconds}`;
}

export function buildEventDeclineNotificationContent(
  displayName: string,
  placeName: string,
): NotificationContent {
  const normalizedDisplayName = normalizedRequiredText(displayName, 50);
  const normalizedPlaceName = normalizedRequiredText(placeName, 120);
  return {
    title: "Nouvelle réponse",
    body: `${normalizedDisplayName} ne participera pas à ${normalizedPlaceName}.`,
  };
}

export function eventDeclineNotificationData(
  ownerID: string,
  eventID: string,
  publicationID: string,
): Record<string, string> {
  if (
    !isValidUserID(ownerID) ||
    !isValidEventID(eventID) ||
    !isValidPublicationID(publicationID)
  ) {
    throw new Error("Invalid event decline notification route");
  }

  return {
    type: "eventDeclineCreated",
    eventOwnerId: ownerID,
    eventId: eventID,
    publicationId: publicationID,
  };
}

export function eventDeclineDispatchID(
  ownerID: string,
  eventID: string,
  publicationID: string,
  participantID: string,
  respondedAtSeconds: number,
  respondedAtNanoseconds: number,
): string {
  if (
    !isValidUserID(ownerID) ||
    !isValidEventID(eventID) ||
    !isValidPublicationID(publicationID) ||
    !isValidUserID(participantID) ||
    ownerID === participantID ||
    !Number.isSafeInteger(respondedAtSeconds) ||
    !Number.isInteger(respondedAtNanoseconds) ||
    respondedAtNanoseconds < 0 ||
    respondedAtNanoseconds > 999_999_999
  ) {
    throw new Error("Invalid event decline dispatch identity");
  }

  return `eventDecline__${ownerID}__${eventID}__${publicationID}__${participantID}__${respondedAtSeconds}_${respondedAtNanoseconds}`;
}

export function friendRequestNotificationData(
  pairID: string,
): Record<string, string> {
  if (!isValidPairID(pairID)) {
    throw new Error("Invalid friend request notification route");
  }

  return {
    type: "friendRequestCreated",
    friendshipId: pairID,
  };
}

export function friendRequestDispatchID(
  pairID: string,
  createdAtSeconds: number,
  createdAtNanoseconds: number,
): string {
  if (
    !isValidPairID(pairID) ||
    !Number.isSafeInteger(createdAtSeconds) ||
    !Number.isInteger(createdAtNanoseconds) ||
    createdAtNanoseconds < 0 ||
    createdAtNanoseconds > 999_999_999
  ) {
    throw new Error("Invalid friend request dispatch identity");
  }

  return `friendRequest__${pairID}__${createdAtSeconds}_${createdAtNanoseconds}`;
}

export function eventNotificationData(
  ownerID: string,
  eventID: string,
  publicationID: string,
): Record<string, string> {
  if (
    !isValidUserID(ownerID) ||
    !isValidEventID(eventID) ||
    !isValidPublicationID(publicationID)
  ) {
    throw new Error("Invalid event notification route");
  }

  return {
    type: "eventPublished",
    eventOwnerId: ownerID,
    eventId: eventID,
    publicationId: publicationID,
  };
}

export function eventDispatchID(
  ownerID: string,
  eventID: string,
  publicationID: string,
): string {
  if (
    !isValidUserID(ownerID) ||
    !isValidEventID(eventID) ||
    !isValidPublicationID(publicationID)
  ) {
    throw new Error("Invalid event dispatch identity");
  }

  return `event__${ownerID}__${eventID}__${publicationID}`;
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

export function isValidEventID(value: string): boolean {
  return isValidPublicationID(value);
}

function isValidPairID(value: string): boolean {
  const participants = value.split("__");
  return participants.length === 2 &&
    isValidUserID(participants[0] ?? "") &&
    isValidUserID(participants[1] ?? "") &&
    (participants[0] ?? "") < (participants[1] ?? "");
}

function normalizedRequiredText(value: string, maximumLength: number): string {
  const normalized = value.trim().split(/\s+/u).join(" ");
  if (!normalized || normalized !== value || normalized.length > maximumLength) {
    throw new Error("Invalid event notification text");
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
