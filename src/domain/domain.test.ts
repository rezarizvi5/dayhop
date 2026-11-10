// Covers EC3.1 EC4.7 EC5.7 EC5.8 EC7.1 EC7.8 EC9.3 EC9.6 EC13.4 EC13.5 FR7.1 FR13.3
import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { formatInTimeZone } from "date-fns-tz";
import { addDays, dateDiffDays, routineDate, routineDateAllowed, wallClock } from "./routine-day";
import { dayBit, isScheduled, maskFromWeekdays, weekStartMonday } from "./schedule";
import { applyAmount, MAX_BALANCE, stepStarsAllowed, sumLedger } from "./stars";
import { computeStreak, datesBetween } from "./streaks";
import { cosmeticStage, creationBlocked, limitsFor } from "./limits";
import { nicknameError, normalizeNickname } from "./nickname";
import { pinError, pinLocked, registerPinFailure } from "./pin";
import { shouldAutoApprove, statusAfterFinish } from "./approval";
import { rollingSchedule, withinQuietHours } from "./notifications";

describe("routine day R1", () => {
  it("starts the day at 03:00 local", () => {
    const before = new Date("2026-05-12T06:59:00Z");
    const at = new Date("2026-05-12T07:00:00Z");
    assert.equal(routineDate(before, "America/New_York"), "2026-05-11");
    assert.equal(routineDate(at, "America/New_York"), "2026-05-12");
  });

  it("matches date-fns-tz wall clock before the 3 hour shift", () => {
    const instant = new Date("2026-01-15T15:30:00Z");
    const wall = wallClock(instant, "America/Los_Angeles");
    const formatted = formatInTimeZone(instant, "America/Los_Angeles", "yyyy-MM-dd HH:mm");
    assert.equal(`${wall.year}-${String(wall.month).padStart(2, "0")}-${String(wall.day).padStart(2, "0")} ${String(wall.hour).padStart(2, "0")}:${String(wall.minute).padStart(2, "0")}`, formatted);
  });

  it("US spring forward does not duplicate or skip the routine date", () => {
    const before = new Date("2026-03-08T06:30:00Z");
    const after = new Date("2026-03-08T07:30:00Z");
    assert.equal(routineDate(before, "America/New_York"), "2026-03-07");
    assert.equal(routineDate(after, "America/New_York"), "2026-03-08");
  });

  it("US fall back keeps both 1:30 instants on the same routine date", () => {
    const first = new Date("2026-11-01T05:30:00Z");
    const second = new Date("2026-11-01T06:30:00Z");
    assert.equal(routineDate(first, "America/New_York"), routineDate(second, "America/New_York"));
  });

  it("Australia DST end and Lord Howe 30 minute shift each yield one date", () => {
    const sydney = new Date("2026-04-05T15:30:00Z");
    const lordHoweEarly = new Date("2026-04-04T15:00:00Z");
    const lordHoweAfter = new Date("2026-04-04T17:00:00Z");
    assert.equal(routineDate(sydney, "Australia/Sydney"), "2026-04-05");
    assert.equal(routineDate(lordHoweEarly, "Australia/Lord_Howe"), "2026-04-04");
    assert.equal(routineDate(lordHoweAfter, "Australia/Lord_Howe"), "2026-04-05");
  });

  it("UTC+13 and UTC+14 disagree only around the 03:00 boundary", () => {
    const instant = new Date("2026-06-01T13:30:00Z");
    const plus13 = routineDate(instant, "Pacific/Tongatapu");
    const plus14 = routineDate(instant, "Pacific/Kiritimati");
    assert.equal(plus13, "2026-06-01");
    assert.equal(plus14, "2026-06-02");
    assert.equal(dateDiffDays(plus14, plus13), 1);
  });

  it("rejects a client routine date more than one day from the server", () => {
    const now = new Date("2026-06-01T15:00:00Z");
    assert.equal(routineDateAllowed("2026-06-01", now, "America/New_York"), true);
    assert.equal(routineDateAllowed("2026-06-03", now, "America/New_York"), false);
    assert.equal(routineDateAllowed("2026-05-29", now, "America/New_York"), false);
  });

  it("household timezone differs from a UTC device clock", () => {
    const instant = new Date("2026-06-02T02:30:00Z");
    assert.equal(routineDate(instant, "UTC"), "2026-06-01");
    assert.equal(routineDate(instant, "Pacific/Auckland"), "2026-06-02");
  });
});

describe("schedule R2", () => {
  it("uses a Monday-based bitmask", () => {
    const weekdays = maskFromWeekdays([1, 2, 3, 4, 5]);
    assert.equal(isScheduled(weekdays, "2026-06-01"), true);
    assert.equal(isScheduled(weekdays, "2026-06-06"), false);
    assert.equal(dayBit("2026-06-07"), 64);
  });

  it("weeks start Monday", () => {
    assert.equal(weekStartMonday("2026-06-07"), "2026-06-01");
    assert.equal(addDays("2026-06-07", 1), "2026-06-08");
  });
});

describe("stars R5", () => {
  it("never goes negative and caps at 99999", () => {
    assert.equal(applyAmount(3, -4).rejected, true);
    assert.equal(applyAmount(3, -2).balance, 1);
    const capped = applyAmount(MAX_BALANCE - 2, 5);
    assert.equal(capped.balance, MAX_BALANCE);
    assert.equal(capped.capped, true);
    assert.equal(capped.applied, 2);
    assert.equal(stepStarsAllowed(5), true);
    assert.equal(stepStarsAllowed(6), false);
  });

  it("balance equals the ledger sum when nothing is capped", () => {
    const entries = [
      { id: "a", amount: 1, type: "step" as const },
      { id: "b", amount: 3, type: "routine_bonus" as const },
      { id: "c", amount: -1, type: "reversal" as const },
    ];
    assert.equal(sumLedger(entries), 3);
  });
});

describe("streaks R7", () => {
  it("ignores unscheduled days and preserves pauses", () => {
    const days = datesBetween("2026-06-01", "2026-06-07").map((date) => ({
      date,
      scheduled: date !== "2026-06-06",
      completed: date !== "2026-06-03" && date !== "2026-06-06",
      paused: date === "2026-06-03",
    }));
    const result = computeStreak(days, "2026-06-07");
    assert.equal(result.current, 5);
  });

  it("uses one shield per week then breaks", () => {
    const days = datesBetween("2026-06-01", "2026-06-05").map((date) => ({
      date,
      scheduled: true,
      completed: date !== "2026-06-03",
      paused: false,
    }));
    const result = computeStreak(days, "2026-06-05");
    assert.deepEqual(result.shieldedDates, ["2026-06-03"]);
    assert.equal(result.current, 4);
    assert.ok(result.milestoneBonuses.includes(3));
  });

  it("does not break an unfinished today", () => {
    const days = [
      { date: "2026-06-01", scheduled: true, completed: true, paused: false },
      { date: "2026-06-02", scheduled: true, completed: false, paused: false },
    ];
    assert.equal(computeStreak(days, "2026-06-02").current, 1);
  });
});

describe("limits and plan", () => {
  it("blocks a third kid on free and leaves plus open until 6", () => {
    assert.equal(creationBlocked("free", false, "kid", 2), true);
    assert.equal(creationBlocked("plus", true, "kid", 2), false);
    assert.equal(creationBlocked("plus", true, "kid", 6), true);
    assert.equal(limitsFor("plus", false).kids, 2);
  });

  it("cosmetic stages are plus only", () => {
    assert.equal(cosmeticStage(300, false), 0);
    assert.equal(cosmeticStage(100, true), 100);
    assert.equal(cosmeticStage(20, true), 0);
  });
});

describe("nickname EC3.1 and PIN FR13", () => {
  it("rejects emoji, bidi and empty names", () => {
    assert.equal(nicknameError("  Maya  "), null);
    assert.equal(normalizeNickname("  Maya   Jo "), "Maya Jo");
    assert.ok(nicknameError("Maya 🌟"));
    assert.ok(nicknameError("ab\u202e"));
    assert.ok(nicknameError(""));
  });

  it("rejects trivial pins and locks after five failures", () => {
    assert.equal(pinError("2580"), null);
    assert.ok(pinError("0000"));
    assert.ok(pinError("1234"));
    let state = { failures: 0, lockedUntil: null as number | null };
    for (let i = 0; i < 5; i += 1) state = registerPinFailure(state, 1_000);
    assert.equal(pinLocked(state, 1_000), true);
    assert.equal(pinLocked(state, 1_000 + 5 * 60 * 1000), false);
  });
});

describe("approval and notifications", () => {
  it("auto-approves after 48 hours and skips approval when plus is off", () => {
    assert.equal(shouldAutoApprove(0, 48 * 60 * 60 * 1000), true);
    assert.equal(shouldAutoApprove(0, 48 * 60 * 60 * 1000 - 1), false);
    assert.equal(statusAfterFinish(true, true), "pending_approval");
    assert.equal(statusAfterFinish(true, false), "completed");
  });

  it("keeps the nearest 60 reminders inside 7 days", () => {
    const now = 0;
    const items = Array.from({ length: 80 }, (_, i) => ({ id: String(i), at: (i + 1) * 60 * 60 * 1000 }));
    const picked = rollingSchedule(items, now);
    assert.equal(picked.length, 60);
    assert.equal(picked[0].id, "0");
    assert.equal(withinQuietHours(22 * 60), true);
    assert.equal(withinQuietHours(8 * 60), false);
  });
});
