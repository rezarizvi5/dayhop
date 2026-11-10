/** R1. routine_date = household local time minus 3 hours, as a date. */

const SHIFT_MS = 3 * 60 * 60 * 1000;

export function wallClock(instant: Date, timeZone: string): { year: number; month: number; day: number; hour: number; minute: number; second: number } {
  const parts = new Intl.DateTimeFormat("en-US", {
    timeZone,
    hourCycle: "h23",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    second: "2-digit",
  }).formatToParts(instant);
  const get = (type: string) => Number(parts.find((p) => p.type === type)?.value);
  return { year: get("year"), month: get("month"), day: get("day"), hour: get("hour"), minute: get("minute"), second: get("second") };
}

function pad(n: number): string {
  return String(n).padStart(2, "0");
}

export function formatDate(year: number, month: number, day: number): string {
  return `${year}-${pad(month)}-${pad(day)}`;
}

/** Civil datetime minus 3 hours, returned as yyyy-MM-dd. Not a timezone conversion. */
export function routineDateFromWall(wall: { year: number; month: number; day: number; hour: number; minute: number; second: number }): string {
  const ms = Date.UTC(wall.year, wall.month - 1, wall.day, wall.hour, wall.minute, wall.second) - SHIFT_MS;
  const shifted = new Date(ms);
  return formatDate(shifted.getUTCFullYear(), shifted.getUTCMonth() + 1, shifted.getUTCDate());
}

export function routineDate(instant: Date, timeZone: string): string {
  return routineDateFromWall(wallClock(instant, timeZone));
}

export function addDays(date: string, days: number): string {
  const [y, m, d] = date.split("-").map(Number);
  const ms = Date.UTC(y, m - 1, d) + days * 24 * 60 * 60 * 1000;
  const next = new Date(ms);
  return formatDate(next.getUTCFullYear(), next.getUTCMonth() + 1, next.getUTCDate());
}

export function dateDiffDays(a: string, b: string): number {
  const [ay, am, ad] = a.split("-").map(Number);
  const [by, bm, bd] = b.split("-").map(Number);
  const ms = Date.UTC(ay, am - 1, ad) - Date.UTC(by, bm - 1, bd);
  return Math.round(ms / (24 * 60 * 60 * 1000));
}

/** EC5.8. Server rejects a routine_date more than one day from the server's household date. */
export function routineDateAllowed(clientDate: string, serverNow: Date, timeZone: string): boolean {
  const serverDate = routineDate(serverNow, timeZone);
  return Math.abs(dateDiffDays(clientDate, serverDate)) <= 1;
}

export function weekdayIndex(date: string): number {
  const [y, m, d] = date.split("-").map(Number);
  return new Date(Date.UTC(y, m - 1, d)).getUTCDay();
}
