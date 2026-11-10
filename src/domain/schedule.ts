import { weekdayIndex } from "./routine-day";

/** Mon=1, Tue=2, Wed=4, Thu=8, Fri=16, Sat=32, Sun=64. */
export const DAY_BITS = [64, 1, 2, 4, 8, 16, 32] as const;

export type TimeOfDay = "morning" | "afternoon" | "evening" | "custom";

export const TIME_ORDER: Record<TimeOfDay, number> = {
  morning: 0,
  afternoon: 1,
  evening: 2,
  custom: 3,
};

export function dayBit(date: string): number {
  return DAY_BITS[weekdayIndex(date)];
}

export function isScheduled(daysMask: number, date: string): boolean {
  if (daysMask < 1 || daysMask > 127) return false;
  return (daysMask & dayBit(date)) !== 0;
}

export function maskFromWeekdays(weekdays: number[]): number {
  return weekdays.reduce((mask, day) => mask | DAY_BITS[day], 0);
}

/** Week starts Monday. Returns the Monday of the week containing date. */
export function weekStartMonday(date: string): string {
  const index = weekdayIndex(date);
  const fromMonday = index === 0 ? 6 : index - 1;
  const [y, m, d] = date.split("-").map(Number);
  const ms = Date.UTC(y, m - 1, d) - fromMonday * 24 * 60 * 60 * 1000;
  const next = new Date(ms);
  const pad = (n: number) => String(n).padStart(2, "0");
  return `${next.getUTCFullYear()}-${pad(next.getUTCMonth() + 1)}-${pad(next.getUTCDate())}`;
}
