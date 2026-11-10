export type PlanId = "free" | "plus";

export interface PlanLimits {
  guardians: number;
  kids: number;
  routinesPerKid: number;
  rewards: boolean;
  approval: boolean;
  weekly: "basic" | "full";
  cosmeticStages: boolean;
  maxSteps: number;
  maxActiveRewards: number;
  maxKidsHard: number;
}

export const LIMITS: Record<PlanId, PlanLimits> = {
  free: {
    guardians: 2,
    kids: 2,
    routinesPerKid: 3,
    rewards: false,
    approval: false,
    weekly: "basic",
    cosmeticStages: false,
    maxSteps: 15,
    maxActiveRewards: 0,
    maxKidsHard: 6,
  },
  plus: {
    guardians: 4,
    kids: 6,
    routinesPerKid: 10,
    rewards: true,
    approval: true,
    weekly: "full",
    cosmeticStages: true,
    maxSteps: 15,
    maxActiveRewards: 25,
    maxKidsHard: 6,
  },
};

export function limitsFor(plan: PlanId, plusActive: boolean): PlanLimits {
  return plusActive && plan === "plus" ? LIMITS.plus : LIMITS.free;
}

/** EC11.7. Existing records stay. Creation past the free cap is blocked. Approval falls back to auto. */
export function creationBlocked(plan: PlanId, plusActive: boolean, kind: "kid" | "routine" | "guardian" | "reward", count: number): boolean {
  const limits = limitsFor(plan, plusActive);
  if (kind === "kid") return count >= limits.kids;
  if (kind === "routine") return count >= limits.routinesPerKid;
  if (kind === "guardian") return count >= limits.guardians;
  return !limits.rewards || count >= limits.maxActiveRewards;
}

export const REWARD_COST = { min: 1, max: 999 };
export const NICKNAME_LENGTH = { min: 1, max: 20 };
export const ROUTINE_NAME_LENGTH = { min: 1, max: 30 };
export const STEP_TITLE_LENGTH = { min: 1, max: 40 };
export const HOUSEHOLD_NAME_LENGTH = { min: 1, max: 40 };

export const COSMETIC_STAGES = [0, 25, 100, 300] as const;

export function cosmeticStage(lifetimeStars: number, plusActive: boolean): number {
  if (!plusActive) return 0;
  let stage = 0;
  for (const mark of COSMETIC_STAGES) {
    if (lifetimeStars >= mark) stage = mark;
  }
  return stage;
}
