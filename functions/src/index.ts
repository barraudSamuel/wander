import { initializeApp } from "firebase-admin/app";
import {
  DocumentReference,
  FieldValue,
  Timestamp,
  getFirestore,
} from "firebase-admin/firestore";
import { getMessaging } from "firebase-admin/messaging";
import { logger } from "firebase-functions";
import {
  onDocumentCreated,
  onDocumentWritten,
} from "firebase-functions/v2/firestore";
import {
  DeviceTargetCandidate,
  acceptedRecipientIDs,
  buildFriendRequestNotificationContent,
  buildNotificationContent,
  buildOutingAttendanceNotificationContent,
  deduplicateTargetsByToken,
  friendRequestDispatchID,
  friendRequestNotificationData,
  friendRequestRecipientID,
  isPermanentMessagingError,
  isValidPublicationID,
  isValidUserID,
  notificationData,
  outingAttendanceDispatchID,
  outingAttendanceNotificationData,
  outingAttendanceRecipientIDs,
} from "./notificationLogic.js";

initializeApp();

const database = getFirestore();
const maximumBatchSize = 500;

interface DeviceTarget extends DeviceTargetCandidate {
  deviceReference: DocumentReference;
}

interface ClaimedTarget extends DeviceTarget {
  claimReference: DocumentReference;
}

export const notifyAcceptedFriendsOfOuting = onDocumentWritten(
  {
    document: "plans/{ownerId}",
    region: "asia-northeast3",
    maxInstances: 10,
  },
  async (event) => {
    const ownerID = event.params.ownerId;
    const after = event.data?.after;
    if (!after?.exists || !isValidUserID(ownerID)) {
      return;
    }

    const plan = after.data();
    if (!plan) {
      return;
    }
    const publicationID = plan.publicationId;
    const previousPublicationID = event.data?.before.exists
      ? event.data.before.data()?.publicationId
      : undefined;

    if (
      typeof publicationID !== "string" ||
      !isValidPublicationID(publicationID) ||
      publicationID === previousPublicationID ||
      plan.ownerId !== ownerID ||
      typeof plan.displayName !== "string" ||
      typeof plan.placeName !== "string" ||
      !(plan.plannedAt instanceof Timestamp) ||
      !(plan.expiresAt instanceof Timestamp) ||
      plan.expiresAt.toMillis() <= Date.now() ||
      typeof plan.timeZoneIdentifier !== "string"
    ) {
      return;
    }

    const content = buildNotificationContent({
      displayName: plan.displayName,
      placeName: plan.placeName,
      plannedAt: plan.plannedAt.toDate(),
      timeZoneIdentifier: plan.timeZoneIdentifier,
    });
    const data = notificationData(ownerID, publicationID);
    const dispatchReference = database
      .collection("notificationDispatches")
      .doc(`${ownerID}__${publicationID}`);

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

export const notifyOutingParticipantsOfAttendance = onDocumentCreated(
  {
    document: "plans/{ownerId}/attendees/{attendanceId}",
    region: "asia-northeast3",
    maxInstances: 10,
  },
  async (event) => {
    const ownerID = event.params.ownerId;
    const attendanceID = event.params.attendanceId;
    const createdSnapshot = event.data;
    const createdAttendance = createdSnapshot?.data();
    if (!createdSnapshot || !createdAttendance || !isValidUserID(ownerID)) {
      return;
    }

    const participantID = createdAttendance.participantId;
    const publicationID = createdAttendance.publicationId;
    const displayName = createdAttendance.displayName;
    const avatarID = createdAttendance.avatarID;
    const joinedAt = createdAttendance.joinedAt;
    const expiresAt = createdAttendance.expiresAt;
    if (
      typeof participantID !== "string" ||
      !isValidUserID(participantID) ||
      participantID === ownerID ||
      typeof publicationID !== "string" ||
      !isValidPublicationID(publicationID) ||
      attendanceID !== `${publicationID}__${participantID}` ||
      typeof displayName !== "string" ||
      typeof avatarID !== "string" ||
      !(joinedAt instanceof Timestamp) ||
      !(expiresAt instanceof Timestamp) ||
      joinedAt.toMillis() >= expiresAt.toMillis() ||
      expiresAt.toMillis() <= Date.now()
    ) {
      return;
    }

    const planReference = database.collection("plans").doc(ownerID);
    const profileReference = database.collection("users").doc(participantID);
    const [currentAttendanceSnapshot, planSnapshot, profileSnapshot] =
      await Promise.all([
        createdSnapshot.ref.get(),
        planReference.get(),
        profileReference.get(),
      ]);
    const currentAttendance = currentAttendanceSnapshot.data();
    const currentJoinedAt = currentAttendance?.joinedAt;
    const currentExpiresAt = currentAttendance?.expiresAt;
    const plan = planSnapshot.data();
    const planExpiresAt = plan?.expiresAt;
    const profile = profileSnapshot.data();
    if (
      !currentAttendanceSnapshot.exists ||
      currentAttendance?.participantId !== participantID ||
      currentAttendance?.publicationId !== publicationID ||
      currentAttendance?.displayName !== displayName ||
      currentAttendance?.avatarID !== avatarID ||
      !(currentJoinedAt instanceof Timestamp) ||
      !currentJoinedAt.isEqual(joinedAt) ||
      !(currentExpiresAt instanceof Timestamp) ||
      !currentExpiresAt.isEqual(expiresAt) ||
      !planSnapshot.exists ||
      plan?.ownerId !== ownerID ||
      plan?.publicationId !== publicationID ||
      typeof plan?.placeName !== "string" ||
      !(planExpiresAt instanceof Timestamp) ||
      !planExpiresAt.isEqual(expiresAt) ||
      planExpiresAt.toMillis() <= Date.now() ||
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

    const attendanceSnapshot = await planReference
      .collection("attendees")
      .where("publicationId", "==", publicationID)
      .get();
    const validAttendances = attendanceSnapshot.docs.flatMap((document) => {
      const attendance = document.data();
      const candidateParticipantID = attendance.participantId;
      const candidateExpiresAt = attendance.expiresAt;
      if (
        typeof candidateParticipantID !== "string" ||
        !isValidUserID(candidateParticipantID) ||
        document.id !== `${publicationID}__${candidateParticipantID}` ||
        attendance.publicationId !== publicationID ||
        !(candidateExpiresAt instanceof Timestamp) ||
        !candidateExpiresAt.isEqual(planExpiresAt)
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
      content = buildOutingAttendanceNotificationContent(
        displayName,
        plan.placeName,
      );
    } catch {
      logger.warn("Attendance notification skipped for invalid visible text.");
      return;
    }

    const recipientIDs = outingAttendanceRecipientIDs(
      ownerID,
      participantID,
      publicationID,
      acceptedFriendIDs,
      validAttendances,
    );
    const data = outingAttendanceNotificationData(ownerID, publicationID);
    const dispatchReference = database
      .collection("notificationDispatches")
      .doc(outingAttendanceDispatchID(
        ownerID,
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
        type: "outingAttendanceCreated",
        ownerId: ownerID,
        publicationId: publicationID,
        participantId: participantID,
        attendanceJoinedAt: joinedAt,
      },
    );
  },
);

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
