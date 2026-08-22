import assert from "node:assert/strict";
import test from "node:test";
import {
  eventRetentionMilliseconds,
  expiredEventCutoff,
} from "./eventCleanupLogic.js";

test("expiredEventCutoff returns exactly 12 hours before the reference", () => {
  const referenceDate = new Date("2026-08-22T12:00:00.000Z");

  const cutoff = expiredEventCutoff(referenceDate);

  assert.equal(
    cutoff.getTime(),
    referenceDate.getTime() - eventRetentionMilliseconds,
  );
  assert.equal(cutoff.toISOString(), "2026-08-22T00:00:00.000Z");
});

test("the cutoff includes 12-hour-old events and excludes newer ones", () => {
  const cutoff = expiredEventCutoff(
    new Date("2026-08-22T12:00:00.000Z"),
  ).getTime();

  assert.equal(new Date("2026-08-22T00:00:00.000Z").getTime() <= cutoff, true);
  assert.equal(new Date("2026-08-22T00:00:00.001Z").getTime() <= cutoff, false);
});
