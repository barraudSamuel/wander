export const eventRetentionMilliseconds = 12 * 60 * 60 * 1_000;

export function expiredEventCutoff(referenceDate: Date): Date {
  return new Date(referenceDate.getTime() - eventRetentionMilliseconds);
}
