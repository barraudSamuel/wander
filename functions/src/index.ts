import { createPrivateKey, sign } from "node:crypto";
import { connect } from "node:http2";
import { initializeApp } from "firebase-admin/app";
import {
  DocumentReference,
  FieldValue,
  Timestamp,
  getFirestore,
} from "firebase-admin/firestore";
import { getMessaging } from "firebase-admin/messaging";
import { logger } from "firebase-functions";
import { defineSecret } from "firebase-functions/params";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import {
  onDocumentCreated,
  onDocumentDeleted,
  onDocumentUpdated,
  onDocumentWritten,
} from "firebase-functions/v2/firestore";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { expiredEventCutoff } from "./eventCleanupLogic.js";
import {
  LocationPushTarget,
  acceptedFriendshipMatches,
  isLocationPushRateLimited,
  isLocationSampleFresh,
  isPermanentAPNsLocationPushFailure,
  isValidLocationRefreshRequest,
  locationPushPairID,
  locationPushTargets,
} from "./locationPushLogic.js";
import {
  DeviceTargetCandidate,
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
  isValidEventID,
  isValidPublicationID,
  isValidUserID,
} from "./notificationLogic.js";

initializeApp();

const database = getFirestore();
const maximumBatchSize = 500;
const apnsAuthKey = defineSecret("APNS_AUTH_KEY");
const apnsKeyID = defineSecret("APNS_KEY_ID");
const apnsTeamID = defineSecret("APNS_TEAM_ID");
const locationPushTopic = "com.iterar.wander.wander.location-query";

let cachedProviderToken: {
  value: string;
  createdAtSeconds: number;
  keyID: string;
  teamID: string;
} | undefined;

interface DeviceTarget extends DeviceTargetCandidate {
  deviceReference: DocumentReference;
}

interface ClaimedTarget extends DeviceTarget {
  claimReference: DocumentReference;
}

interface StoredLocationPushTarget extends LocationPushTarget {
  deviceReference: DocumentReference;
}

interface APNsLocationPushResult {
  success: boolean;
  statusCode: number;
  reason?: string;
}

export const requestFriendLocationRefresh = onCall(
  {
    region: "asia-northeast3",
    maxInstances: 20,
    secrets: [apnsAuthKey, apnsKeyID, apnsTeamID],
  },
  async (request) => {
    const requesterID = request.auth?.uid;
    const targetUserID = request.data?.targetUserId;
    const requestID = request.data?.requestId;

    if (
      !requesterID
      || request.auth?.token.firebase?.sign_in_provider !== "apple.com"
    ) {
      throw new HttpsError("unauthenticated", "Authentication required.");
    }
    if (!isValidLocationRefreshRequest(requesterID, targetUserID, requestID)) {
      throw new HttpsError("invalid-argument", "Invalid location refresh request.");
    }

    const pairID = locationPushPairID(requesterID, targetUserID);
    const [friendshipSnapshot, targetProfileSnapshot, locationSnapshot] =
      await Promise.all([
        database.collection("friendships").doc(pairID).get(),
        database.collection("users").doc(targetUserID).get(),
        database.collection("locations").doc(targetUserID).get(),
      ]);

    if (!acceptedFriendshipMatches(
      requesterID,
      targetUserID,
      friendshipSnapshot.data(),
    )) {
      throw new HttpsError(
        "permission-denied",
        "An accepted friendship is required.",
      );
    }

    if (
      !targetProfileSnapshot.exists
      || targetProfileSnapshot.data()?.deletionRequestedAt instanceof Timestamp
    ) {
      return { status: "unavailable" };
    }

    const sampledAt = locationSnapshot.data()?.sampledAt;
    if (
      sampledAt instanceof Timestamp
      && isLocationSampleFresh(sampledAt.toMillis(), Date.now())
    ) {
      return { status: "fresh" };
    }

    const deviceSnapshot = await database
      .collection("users")
      .doc(targetUserID)
      .collection("locationPushDevices")
      .get();
    const targetsByDeviceID = new Map(
      deviceSnapshot.docs.map((document) => [document.id, document]),
    );
    const targets = locationPushTargets(deviceSnapshot.docs.map((document) => {
      const data = document.data();
      return {
        deviceID: document.id,
        token: data.token,
        environment: data.environment,
        updatedAtMilliseconds: data.updatedAt instanceof Timestamp
          ? data.updatedAt.toMillis()
          : undefined,
      };
    })).flatMap((target): StoredLocationPushTarget[] => {
      const deviceDocument = targetsByDeviceID.get(target.deviceID);
      return deviceDocument
        ? [{ ...target, deviceReference: deviceDocument.ref }]
        : [];
    });

    if (targets.length === 0) {
      return { status: "unavailable" };
    }

    const dispatchReference = database
      .collection("locationPushDispatches")
      .doc(targetUserID);
    const dispatchClaimed = await database.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(dispatchReference);
      const lastSentAt = snapshot.data()?.lastSentAt;
      if (
        lastSentAt instanceof Timestamp
        && isLocationPushRateLimited(lastSentAt.toMillis(), Date.now())
      ) {
        return false;
      }

      transaction.set(dispatchReference, {
        requesterId: requesterID,
        requestId: requestID,
        lastSentAt: FieldValue.serverTimestamp(),
      });
      return true;
    });

    if (!dispatchClaimed) {
      return { status: "throttled" };
    }

    let providerToken: string;
    try {
      providerToken = makeAPNsProviderToken(
        apnsAuthKey.value(),
        apnsKeyID.value(),
        apnsTeamID.value(),
      );
    } catch {
      logger.error("Location push provider credentials are unavailable.");
      throw new HttpsError("internal", "Location refresh is unavailable.");
    }

    const results = await Promise.all(targets.map(async (target) => ({
      target,
      result: await sendAPNsLocationPush(target, requestID, providerToken),
    })));

    await Promise.all(results.map(async ({ target, result }) => {
      if (
        result.reason
        && isPermanentAPNsLocationPushFailure(result.reason)
      ) {
        await deleteLocationPushDeviceIfTokenMatches(target);
      }
    }));

    const sentCount = results.filter(({ result }) => result.success).length;
    if (sentCount === 0) {
      logger.warn("No location push target accepted the request.", {
        targetCount: targets.length,
        statusCodes: results.map(({ result }) => result.statusCode),
      });
      return { status: "unavailable" };
    }

    return { status: "sent" };
  },
);

export const notifyAcceptedFriendsOfEvent = onDocumentWritten(
  {
    document: "users/{ownerId}/events/{eventId}",
    region: "asia-northeast3",
    maxInstances: 10,
  },
  async (event) => {
    const ownerID = event.params.ownerId;
    const eventID = event.params.eventId;
    const after = event.data?.after;
    if (
      !after?.exists ||
      !isValidUserID(ownerID) ||
      !isValidEventID(eventID)
    ) {
      return;
    }

    const userEvent = after.data();
    if (!userEvent) {
      return;
    }
    const publicationID = userEvent.publicationId;
    const previousPublicationID = event.data?.before.exists
      ? event.data.before.data()?.publicationId
      : undefined;

    if (
      userEvent.ownerId !== ownerID ||
      userEvent.eventId !== eventID ||
      typeof publicationID !== "string" ||
      !isValidPublicationID(publicationID) ||
      publicationID === previousPublicationID ||
      typeof userEvent.displayName !== "string" ||
      typeof userEvent.placeName !== "string" ||
      !(userEvent.plannedAt instanceof Timestamp) ||
      typeof userEvent.timeZoneIdentifier !== "string"
    ) {
      return;
    }

    const content = buildEventNotificationContent({
      displayName: userEvent.displayName,
      placeName: userEvent.placeName,
      plannedAt: userEvent.plannedAt.toDate(),
      timeZoneIdentifier: userEvent.timeZoneIdentifier,
    });
    const data = eventNotificationData(
      ownerID,
      eventID,
      publicationID,
    );
    const dispatchReference = database
      .collection("notificationDispatches")
      .doc(eventDispatchID(ownerID, eventID, publicationID));

    const friendshipSnapshot = await database
      .collection("friendships")
      .where("participants", "array-contains", ownerID)
      .get();
    const recipientIDs = acceptedRecipientIDs(
      ownerID,
      friendshipSnapshot.docs.map((document) => document.data()),
    );
    await dispatchNotification(
      dispatchReference,
      recipientIDs,
      content,
      data,
      {
        type: "eventPublished",
        eventId: eventID,
        ownerId: ownerID,
        publicationId: publicationID,
      },
    );
  },
);

export const notifyRecipientOfFriendRequest = onDocumentCreated(
  {
    document: "friendships/{pairId}",
    region: "asia-northeast3",
    maxInstances: 10,
  },
  async (event) => {
    const pairID = event.params.pairId;
    const snapshot = event.data;
    const request = snapshot?.data();
    if (!snapshot || !request) {
      return;
    }

    const recipientID = friendRequestRecipientID(pairID, request);
    const requesterID = request.requestedBy;
    const createdAt = request.createdAt;
    if (
      !recipientID ||
      typeof requesterID !== "string" ||
      !(createdAt instanceof Timestamp)
    ) {
      return;
    }

    const currentSnapshot = await snapshot.ref.get();
    const currentRequest = currentSnapshot.data();
    const currentCreatedAt = currentRequest?.createdAt;
    if (
      !currentSnapshot.exists ||
      !currentRequest ||
      friendRequestRecipientID(pairID, currentRequest) !== recipientID ||
      currentRequest.requestedBy !== requesterID ||
      !(currentCreatedAt instanceof Timestamp) ||
      !currentCreatedAt.isEqual(createdAt)
    ) {
      return;
    }

    const requesterSnapshot = await database
      .collection("users")
      .doc(requesterID)
      .get();
    const displayName = requesterSnapshot.data()?.displayName;
    if (typeof displayName !== "string") {
      return;
    }

    let content;
    try {
      content = buildFriendRequestNotificationContent(displayName);
    } catch {
      logger.warn("Friend request notification skipped for an invalid profile.", {
        friendshipId: pairID,
      });
      return;
    }

    const data = friendRequestNotificationData(pairID);
    const dispatchReference = database
      .collection("notificationDispatches")
      .doc(friendRequestDispatchID(
        pairID,
        createdAt.seconds,
        createdAt.nanoseconds,
      ));

    await dispatchNotification(
      dispatchReference,
      [recipientID],
      content,
      data,
      {
        type: "friendRequestCreated",
        friendshipId: pairID,
        requesterId: requesterID,
        recipientId: recipientID,
        requestCreatedAt: createdAt,
      },
    );
  },
);

export const notifyEventParticipantsOfAttendance = onDocumentCreated(
  {
    document: "users/{ownerId}/events/{eventId}/attendees/{attendanceId}",
    region: "asia-northeast3",
    maxInstances: 10,
  },
  async (event) => {
    const ownerID = event.params.ownerId;
    const eventID = event.params.eventId;
    const attendanceID = event.params.attendanceId;
    const createdSnapshot = event.data;
    const createdAttendance = createdSnapshot?.data();
    if (
      !createdSnapshot ||
      !createdAttendance ||
      !isValidUserID(ownerID) ||
      !isValidEventID(eventID)
    ) {
      return;
    }

    const participantID = createdAttendance.participantId;
    const publicationID = createdAttendance.publicationId;
    const displayName = createdAttendance.displayName;
    const avatarID = createdAttendance.avatarID;
    const joinedAt = createdAttendance.joinedAt;
    if (
      createdAttendance.eventId !== eventID ||
      typeof participantID !== "string" ||
      !isValidUserID(participantID) ||
      typeof publicationID !== "string" ||
      !isValidPublicationID(publicationID) ||
      attendanceID !== `${publicationID}__${participantID}` ||
      typeof displayName !== "string" ||
      typeof avatarID !== "string" ||
      !(joinedAt instanceof Timestamp)
    ) {
      return;
    }

    const eventReference = database
      .collection("users")
      .doc(ownerID)
      .collection("events")
      .doc(eventID);
    const profileReference = database.collection("users").doc(participantID);
    const [currentAttendanceSnapshot, eventSnapshot, profileSnapshot] =
      await Promise.all([
        createdSnapshot.ref.get(),
        eventReference.get(),
        profileReference.get(),
      ]);
    const currentAttendance = currentAttendanceSnapshot.data();
    const currentJoinedAt = currentAttendance?.joinedAt;
    const userEvent = eventSnapshot.data();
    const profile = profileSnapshot.data();
    if (
      !currentAttendanceSnapshot.exists ||
      currentAttendance?.eventId !== eventID ||
      currentAttendance?.participantId !== participantID ||
      currentAttendance?.publicationId !== publicationID ||
      currentAttendance?.displayName !== displayName ||
      currentAttendance?.avatarID !== avatarID ||
      !(currentJoinedAt instanceof Timestamp) ||
      !currentJoinedAt.isEqual(joinedAt) ||
      !eventSnapshot.exists ||
      userEvent?.eventId !== eventID ||
      userEvent?.ownerId !== ownerID ||
      participantID === ownerID ||
      userEvent?.publicationId !== publicationID ||
      typeof userEvent?.placeName !== "string" ||
      !profileSnapshot.exists ||
      profile?.displayName !== displayName ||
      profile?.avatarID !== avatarID
    ) {
      return;
    }

    const friendshipSnapshot = await database
      .collection("friendships")
      .where("participants", "array-contains", ownerID)
      .get();
    const acceptedFriendIDs = acceptedRecipientIDs(
      ownerID,
      friendshipSnapshot.docs.map((document) => document.data()),
    );
    if (!acceptedFriendIDs.includes(participantID)) {
      return;
    }

    const attendanceSnapshot = await eventReference
      .collection("attendees")
      .where("publicationId", "==", publicationID)
      .get();
    const validAttendances = attendanceSnapshot.docs.flatMap((document) => {
      const attendance = document.data();
      const candidateParticipantID = attendance.participantId;
      if (
        attendance.eventId !== eventID ||
        typeof candidateParticipantID !== "string" ||
        !isValidUserID(candidateParticipantID) ||
        document.id !== `${publicationID}__${candidateParticipantID}` ||
        attendance.publicationId !== publicationID
      ) {
        return [];
      }
      return [{
        participantId: candidateParticipantID,
        publicationId: publicationID,
      }];
    });

    let content;
    try {
      content = buildEventAttendanceNotificationContent(
        displayName,
        userEvent.placeName,
      );
    } catch {
      logger.warn(
        "Event attendance notification skipped for invalid visible text.",
      );
      return;
    }

    const recipientIDs = eventAttendanceRecipientIDs(
      ownerID,
      participantID,
      publicationID,
      acceptedFriendIDs,
      validAttendances,
    );
    const data = eventAttendanceNotificationData(
      ownerID,
      eventID,
      publicationID,
    );
    const dispatchReference = database
      .collection("notificationDispatches")
      .doc(eventAttendanceDispatchID(
        ownerID,
        eventID,
        publicationID,
        participantID,
        joinedAt.seconds,
        joinedAt.nanoseconds,
      ));

    await dispatchNotification(
      dispatchReference,
      recipientIDs,
      content,
      data,
      {
        type: "eventAttendanceCreated",
        eventId: eventID,
        ownerId: ownerID,
        publicationId: publicationID,
        participantId: participantID,
        attendanceJoinedAt: joinedAt,
      },
    );
  },
);

export const cleanupEventAttendances = onDocumentDeleted(
  {
    document: "users/{ownerId}/events/{eventId}",
    region: "asia-northeast3",
    maxInstances: 10,
  },
  async (event) => {
    const deletedEvent = event.data;
    if (!deletedEvent) {
      return;
    }

    await deleteEventAttendances(deletedEvent.ref);
  },
);

export const cleanupExpiredEvents = onSchedule(
  {
    schedule: "every 60 minutes",
    region: "asia-northeast3",
    maxInstances: 1,
  },
  async () => {
    const cutoff = Timestamp.fromDate(expiredEventCutoff(new Date()));
    let deletedEventCount = 0;

    while (true) {
      const snapshot = await database
        .collectionGroup("events")
        .where("publishedAt", "<=", cutoff)
        .limit(maximumBatchSize)
        .get();
      if (snapshot.empty) {
        logger.info("Expired event cleanup completed.", {
          cutoff: cutoff.toDate().toISOString(),
          deletedEventCount,
        });
        return;
      }

      const batch = database.batch();
      for (const document of snapshot.docs) {
        batch.delete(document.ref);
      }
      await batch.commit();
      deletedEventCount += snapshot.size;
    }
  },
);

export const cleanupReplacedEventAttendances = onDocumentUpdated(
  {
    document: "users/{ownerId}/events/{eventId}",
    region: "asia-northeast3",
    maxInstances: 10,
  },
  async (event) => {
    const change = event.data;
    if (!change) {
      return;
    }

    const beforePublicationID = change.before.data().publicationId;
    const afterPublicationID = change.after.data().publicationId;
    if (
      typeof beforePublicationID !== "string" ||
      !isValidPublicationID(beforePublicationID) ||
      typeof afterPublicationID !== "string" ||
      !isValidPublicationID(afterPublicationID) ||
      beforePublicationID === afterPublicationID
    ) {
      return;
    }

    await deleteEventAttendances(
      change.after.ref,
      beforePublicationID,
    );
  },
);

async function deleteEventAttendances(
  eventReference: DocumentReference,
  publicationID?: string,
): Promise<void> {
  const attendees = eventReference.collection("attendees");
  const attendanceQuery = publicationID
    ? attendees.where("publicationId", "==", publicationID)
    : attendees;

  while (true) {
    const snapshot = await attendanceQuery.limit(maximumBatchSize).get();
    if (snapshot.empty) {
      return;
    }

    const batch = database.batch();
    for (const document of snapshot.docs) {
      batch.delete(document.ref);
    }
    await batch.commit();
  }
}

async function dispatchNotification(
  dispatchReference: DocumentReference,
  recipientIDs: readonly string[],
  content: { title: string; body: string },
  data: Record<string, string>,
  metadata: Record<string, unknown>,
): Promise<void> {
  const targets = deduplicateTargetsByToken(
    await loadDeviceTargets(recipientIDs),
  );

  await dispatchReference.set(
    {
      ...metadata,
      recipientCount: recipientIDs.length,
      candidateDeviceCount: targets.length,
      updatedAt: FieldValue.serverTimestamp(),
    },
    { merge: true },
  );

  const claimedTargets = (
    await Promise.all(
      targets.map((target) => claimTarget(dispatchReference, target)),
    )
  ).filter((target): target is ClaimedTarget => target !== null);

  for (let index = 0; index < claimedTargets.length; index += maximumBatchSize) {
    const chunk = claimedTargets.slice(index, index + maximumBatchSize);
    await sendChunk(chunk, content, data);
  }

  await dispatchReference.set(
    {
      claimedDeviceCount: claimedTargets.length,
      completedAt: FieldValue.serverTimestamp(),
    },
    { merge: true },
  );
}

async function loadDeviceTargets(
  recipientIDs: readonly string[],
): Promise<DeviceTarget[]> {
  const snapshots = await Promise.all(
    recipientIDs.map(async (recipientID) => ({
      recipientID,
      snapshot: await database
        .collection("users")
        .doc(recipientID)
        .collection("devices")
        .get(),
    })),
  );

  return snapshots.flatMap(({ recipientID, snapshot }) =>
    snapshot.docs.flatMap((document): DeviceTarget[] => {
      const data = document.data();
      if (
        typeof data.token !== "string" ||
        data.token.length < 20 ||
        data.token.length > 4096 ||
        data.platform !== "ios" ||
        !(data.updatedAt instanceof Timestamp)
      ) {
        return [];
      }

      return [{
        recipientID,
        deviceID: document.id,
        token: data.token,
        updatedAtMilliseconds: data.updatedAt.toMillis(),
        deviceReference: document.ref,
      }];
    }),
  );
}

async function claimTarget(
  dispatchReference: DocumentReference,
  target: DeviceTarget,
): Promise<ClaimedTarget | null> {
  const claimReference = dispatchReference
    .collection("devices")
    .doc(`${target.recipientID}__${target.deviceID}`);

  try {
    await claimReference.create({
      recipientId: target.recipientID,
      deviceId: target.deviceID,
      status: "claimed",
      claimedAt: FieldValue.serverTimestamp(),
    });
    return { ...target, claimReference };
  } catch (error) {
    if (isAlreadyExistsError(error)) {
      return null;
    }
    throw error;
  }
}

async function sendChunk(
  targets: readonly ClaimedTarget[],
  content: { title: string; body: string },
  data: Record<string, string>,
): Promise<void> {
  if (targets.length === 0) {
    return;
  }

  try {
    const response = await getMessaging().sendEachForMulticast({
      tokens: targets.map((target) => target.token),
      notification: content,
      data,
      apns: {
        payload: {
          aps: {
            sound: "default",
          },
        },
      },
    });

    await Promise.all(response.responses.map(async (result, index) => {
      const target = targets[index];
      if (!target) {
        return;
      }

      const errorCode = result.error?.code;
      await target.claimReference.set(
        {
          status: result.success ? "sent" : "failed",
          ...(errorCode ? { errorCode } : {}),
          completedAt: FieldValue.serverTimestamp(),
        },
        { merge: true },
      );

      if (isPermanentMessagingError(errorCode)) {
        await deleteDeviceIfTokenMatches(target);
      }
    }));
  } catch (error) {
    await Promise.all(targets.map((target) => target.claimReference.set(
      {
        status: "failed",
        completedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    )));
    logger.error("Notification batch failed after claims were reserved.", {
      deviceCount: targets.length,
    });
  }
}

async function deleteDeviceIfTokenMatches(target: DeviceTarget): Promise<void> {
  await database.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(target.deviceReference);
    if (snapshot.data()?.token === target.token) {
      transaction.delete(target.deviceReference);
    }
  });
}

function isAlreadyExistsError(error: unknown): boolean {
  if (!error || typeof error !== "object" || !("code" in error)) {
    return false;
  }
  const code = (error as { code?: unknown }).code;
  return code === 6 || code === "6" || code === "already-exists";
}

function makeAPNsProviderToken(
  privateKeyValue: string,
  keyIDValue: string,
  teamIDValue: string,
): string {
  const keyID = keyIDValue.trim();
  const teamID = teamIDValue.trim();
  const privateKey = privateKeyValue.replaceAll("\\n", "\n").trim();
  if (
    !/^[A-Z0-9]{10}$/.test(keyID)
    || !/^[A-Z0-9]{10}$/.test(teamID)
    || !privateKey.includes("BEGIN PRIVATE KEY")
  ) {
    throw new Error("Invalid APNs provider credentials");
  }

  const nowSeconds = Math.floor(Date.now() / 1_000);
  if (
    cachedProviderToken
    && cachedProviderToken.keyID === keyID
    && cachedProviderToken.teamID === teamID
    && nowSeconds - cachedProviderToken.createdAtSeconds < 50 * 60
  ) {
    return cachedProviderToken.value;
  }

  const encodedHeader = base64URL(JSON.stringify({ alg: "ES256", kid: keyID }));
  const encodedClaims = base64URL(JSON.stringify({ iss: teamID, iat: nowSeconds }));
  const signingInput = `${encodedHeader}.${encodedClaims}`;
  const signature = sign("sha256", Buffer.from(signingInput), {
    key: createPrivateKey(privateKey),
    dsaEncoding: "ieee-p1363",
  });
  const value = `${signingInput}.${signature.toString("base64url")}`;
  cachedProviderToken = {
    value,
    createdAtSeconds: nowSeconds,
    keyID,
    teamID,
  };
  return value;
}

function base64URL(value: string): string {
  return Buffer.from(value).toString("base64url");
}

async function sendAPNsLocationPush(
  target: StoredLocationPushTarget,
  requestID: string,
  providerToken: string,
): Promise<APNsLocationPushResult> {
  const authority = target.environment === "sandbox"
    ? "https://api.sandbox.push.apple.com"
    : "https://api.push.apple.com";

  return new Promise((resolve) => {
    const client = connect(authority);
    let didFinish = false;
    const timeout = setTimeout(() => {
      finish({ success: false, statusCode: 0, reason: "RequestTimeout" });
    }, 10_000);

    const finish = (result: APNsLocationPushResult) => {
      if (didFinish) return;
      didFinish = true;
      clearTimeout(timeout);
      client.destroy();
      resolve(result);
    };

    client.once("error", () => {
      finish({ success: false, statusCode: 0 });
    });

    try {
      const stream = client.request({
        ":method": "POST",
        ":path": `/3/device/${target.token}`,
        authorization: `bearer ${providerToken}`,
        "apns-topic": locationPushTopic,
        "apns-push-type": "location",
        "apns-priority": "10",
        "apns-expiration": "0",
        "apns-id": requestID,
        "content-type": "application/json",
      });
      let statusCode = 0;
      let responseBody = "";

      stream.setEncoding("utf8");
      stream.on("response", (headers) => {
        const rawStatus = headers[":status"];
        statusCode = typeof rawStatus === "number"
          ? rawStatus
          : Number(rawStatus) || 0;
      });
      stream.on("data", (chunk: string) => {
        if (responseBody.length < 4_096) {
          responseBody += chunk;
        }
      });
      stream.once("error", () => {
        finish({ success: false, statusCode });
      });
      stream.once("end", () => {
        let reason: string | undefined;
        if (responseBody) {
          try {
            const parsed = JSON.parse(responseBody) as { reason?: unknown };
            if (typeof parsed.reason === "string") {
              reason = parsed.reason;
            }
          } catch {
            // APNs error bodies are best-effort diagnostics only.
          }
        }
        finish({
          success: statusCode === 200,
          statusCode,
          ...(reason ? { reason } : {}),
        });
      });

      stream.end(JSON.stringify({
        aps: {},
        requestId: requestID,
      }));
    } catch {
      finish({ success: false, statusCode: 0 });
    }
  });
}

async function deleteLocationPushDeviceIfTokenMatches(
  target: StoredLocationPushTarget,
): Promise<void> {
  await database.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(target.deviceReference);
    if (snapshot.data()?.token === target.token) {
      transaction.delete(target.deviceReference);
    }
  });
}
