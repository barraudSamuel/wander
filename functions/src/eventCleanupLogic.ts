import { Firestore, Timestamp } from "firebase-admin/firestore";

export const eventRetentionMilliseconds = 12 * 60 * 60 * 1_000;

export function expiredEventCutoff(referenceDate: Date): Date {
  return new Date(referenceDate.getTime() - eventRetentionMilliseconds);
}

export async function deleteExpiredEvents(
  database: Firestore,
  cutoff: Timestamp,
): Promise<number> {
  const expiredEvents = database
    .collectionGroup("events")
    .where("plannedAt", "<=", cutoff)
    .limit(500);
  let deletedEventCount = 0;

  while (true) {
    const deletedBatchCount = await database.runTransaction(async (transaction) => {
      // Read and delete together so a concurrent reschedule cannot leave
      // a stale expiration decision between the query and the commit.
      const snapshot = await transaction.get(expiredEvents);
      for (const document of snapshot.docs) {
        transaction.delete(document.ref);
      }
      return snapshot.size;
    });
    if (deletedBatchCount === 0) {
      return deletedEventCount;
    }
    deletedEventCount += deletedBatchCount;
  }
}
