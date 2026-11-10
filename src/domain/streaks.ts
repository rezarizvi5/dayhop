import { addDays } from "./routine-day";
import { weekStartMonday } from "./schedule";

export const MILESTONES = [3, 7, 14, 30] as const;

export interface StreakDay {
  date: string;
  scheduled: boolean;
  completed: boolean;
  paused: boolean;
}

export interface StreakResult {
  current: number;
  best: number;
  milestoneBonuses: number[];
  shieldedDates: string[];
}

/**
 * R7. A scheduled, completed, approved day extends the streak.
 * An unscheduled day neither extends nor breaks it. A pause preserves it.
 * One shield per Monday-start week forgives a single missed day before today.
 * Today, if still open and incomplete, does not break the streak.
 */
export function computeStreak(days: StreakDay[], today: string): StreakResult {
  const ordered = [...days].sort((a, b) => a.date.localeCompare(b.date));
  let current = 0;
  let best = 0;
  const shielded = new Set<string>();
  const seenWeeks = new Set<string>();
  const awarded = new Set<number>();
  const milestoneBonuses: number[] = [];

  for (const day of ordered) {
    if (day.date > today) break;
    if (!day.scheduled || day.paused) continue;
    const done = day.completed;
    const stillOpen = day.date === today && !done;
    if (done) {
      current += 1;
      best = Math.max(best, current);
      for (const mark of MILESTONES) {
        if (current === mark && !awarded.has(mark)) {
          awarded.add(mark);
          milestoneBonuses.push(mark);
        }
      }
      continue;
    }
    if (stillOpen) continue;
    const week = weekStartMonday(day.date);
    if (!seenWeeks.has(week)) {
      seenWeeks.add(week);
      shielded.add(day.date);
      continue;
    }
    current = 0;
  }

  return { current, best, milestoneBonuses, shieldedDates: [...shielded] };
}

export function datesBetween(start: string, end: string): string[] {
  const out: string[] = [];
  let cursor = start;
  while (cursor <= end) {
    out.push(cursor);
    cursor = addDays(cursor, 1);
  }
  return out;
}
