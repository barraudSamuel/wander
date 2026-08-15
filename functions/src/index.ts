import { initializeApp } from "firebase-admin/app";
import {
  DocumentReference,
  FieldValue,
  Timestamp,
  getFirestore,
} from "firebase-admin/firestore";
import { getMessaging } from "firebase-admin/messaging";
import { logger } from "firebase-functions";
import { onDocumentWritten } from "firebase-functions/v2/firestore";
import {
  DeviceTargetCandidate,
  acceptedRecipientIDs,
  buildNotificationContent,
  deduplicateTargetsByToken,
  isPermanentMessagingError,
  isValidPublicationID,
  isValidUserID,
  notificationData,
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
    const targets = deduplicateTargetsByToken(
      await loadDeviceTargets(recipientIDs),
    );

    await dispatchReference.set(
      {
        ownerId: ownerID,
        publicationId: publicationID,
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
  },
);

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
    logger.error("Outing notification batch failed after claims were reserved.", {
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
