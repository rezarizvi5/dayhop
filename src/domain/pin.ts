const TRIVIAL = new Set(["0000", "1234"]);

export function pinError(pin: string): string | null {
  if (!/^\d{4}$/.test(pin)) return "Use 4 digits.";
  if (TRIVIAL.has(pin)) return "Pick a PIN that is not 0000 or 1234.";
  return null;
}

export interface LockoutState {
  failures: number;
  lockedUntil: number | null;
}

export function registerPinFailure(state: LockoutState, now: number): LockoutState {
  const failures = state.failures + 1;
  if (failures === 5) return { failures, lockedUntil: now + 5 * 60 * 1000 };
  if (failures === 10) return { failures, lockedUntil: now + 15 * 60 * 1000 };
  if (failures > 10 && failures % 5 === 0) return { failures, lockedUntil: now + 15 * 60 * 1000 };
  return { failures, lockedUntil: state.lockedUntil };
}

export function pinLocked(state: LockoutState, now: number): boolean {
  return state.lockedUntil != null && now < state.lockedUntil;
}
