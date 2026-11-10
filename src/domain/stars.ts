export const MAX_BALANCE = 99_999;

export type LedgerType =
  | "step"
  | "routine_bonus"
  | "streak_bonus"
  | "redemption_hold"
  | "redemption_refund"
  | "adjustment"
  | "reversal";

export interface LedgerEntry {
  id: string;
  amount: number;
  type: LedgerType;
  refId?: string;
}

export function sumLedger(entries: LedgerEntry[]): number {
  return entries.reduce((sum, entry) => sum + entry.amount, 0);
}

/** R5. Balance is the sum, never negative, capped at 99,999. Credits above the cap are recorded but not applied. */
export function applyAmount(balance: number, amount: number): { balance: number; applied: number; capped: boolean; rejected: boolean } {
  if (amount === 0) return { balance, applied: 0, capped: false, rejected: true };
  if (amount < 0) {
    if (balance + amount < 0) return { balance, applied: 0, capped: false, rejected: true };
    return { balance: balance + amount, applied: amount, capped: false, rejected: false };
  }
  const room = MAX_BALANCE - balance;
  if (room <= 0) return { balance, applied: 0, capped: true, rejected: false };
  if (amount > room) return { balance: MAX_BALANCE, applied: room, capped: true, rejected: false };
  return { balance: balance + amount, applied: amount, capped: false, rejected: false };
}

export function stepStarsAllowed(stars: number): boolean {
  return Number.isInteger(stars) && stars >= 0 && stars <= 5;
}

export function bonusStarsAllowed(stars: number): boolean {
  return Number.isInteger(stars) && stars >= 0 && stars <= 10;
}
