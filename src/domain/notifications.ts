export interface Reminder {
  at: number;
  id: string;
}

/** FR9.3. Next 7 days, at most 60, nearest first. iOS pending cap is 64. */
export function rollingSchedule(items: Reminder[], now: number, horizonDays = 7, cap = 60): Reminder[] {
  const horizon = now + horizonDays * 24 * 60 * 60 * 1000;
  return items
    .filter((item) => item.at >= now && item.at <= horizon)
    .sort((a, b) => a.at - b.at)
    .slice(0, cap);
}

export function withinQuietHours(minutes: number, start = 21 * 60, end = 7 * 60): boolean {
  if (start === end) return false;
  if (start < end) return minutes >= start && minutes < end;
  return minutes >= start || minutes < end;
}
