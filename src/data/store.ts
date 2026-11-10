import { create } from "zustand";
import { createJSONStorage, persist } from "zustand/middleware";
import { AGE_BANDS, CHARACTERS, TEMPLATES, type RoutineTemplate } from "./templates";
import {
  applyAmount,
  computeStreak,
  cosmeticStage,
  creationBlocked,
  datesBetween,
  isScheduled,
  nicknameError,
  normalizeNickname,
  pinError,
  pinLocked,
  registerPinFailure,
  routineDate,
  routineDateAllowed,
  shouldAutoApprove,
  statusAfterFinish,
  type PlanId,
  type RunStatus,
} from "../domain";

export interface Step {
  id: string;
  title: string;
  iconKey: string;
  stars: number;
  position: number;
  timerMinutes?: number;
}

export interface Routine {
  id: string;
  name: string;
  timeOfDay: RoutineTemplate["timeOfDay"];
  days: number;
  startTime?: string;
  requiresApproval: boolean;
  bonusStars: number;
  version: number;
  archivedAt?: string;
  kidIds: string[];
  steps: Step[];
}

export interface Kid {
  id: string;
  nickname: string;
  ageBand: (typeof AGE_BANDS)[number];
  characterId: string;
  accent: string;
  starsBalance: number;
  lifetimeStars: number;
  streakCurrent: number;
  streakBest: number;
  archivedAt?: string;
  pauses: { start: string; end: string }[];
}

export interface Run {
  id: string;
  kidId: string;
  routineId: string;
  routineDate: string;
  status: RunStatus;
  version: number;
  steps: Step[];
  bonusStars: number;
  requiresApproval: boolean;
  completions: Record<string, { id: string; undoneAt?: string }>;
  submittedAt?: number;
  autoApproved?: boolean;
  credited: boolean;
}

export interface Reward {
  id: string;
  title: string;
  iconKey: string;
  cost: number;
  weeklyLimit?: number;
  archivedAt?: string;
}

export interface Redemption {
  id: string;
  kidId: string;
  rewardId: string;
  title: string;
  cost: number;
  status: "requested" | "fulfilled" | "denied";
  requestedAt: number;
}

export interface LedgerRow {
  id: string;
  kidId: string;
  amount: number;
  type: string;
  note?: string;
  createdAt: number;
}

interface OutboxItem {
  id: string;
  rpc: string;
  status: "pending" | "failed";
  error?: string;
}

export interface AppState {
  onboardStep: number;
  adultConfirmed: boolean;
  consentAt?: string;
  policyVersion: string;
  householdName: string;
  timeZone: string;
  plan: PlanId;
  plusExpiresAt?: number;
  kids: Kid[];
  routines: Routine[];
  runs: Run[];
  rewards: Reward[];
  redemptions: Redemption[];
  ledger: LedgerRow[];
  pinHash?: string;
  pinFailures: number;
  pinLockedUntil: number | null;
  kidMode: boolean;
  activeKidId?: string;
  outbox: OutboxItem[];
  soundOn: boolean;
  readAloud: boolean;
  deleted: boolean;
  loadSample: () => void;
  setOnboard: (step: number) => void;
  confirmAdult: (yes: boolean) => void;
  setHousehold: (name: string, timeZone: string) => void;
  recordConsent: () => void;
  addKid: (input: { nickname: string; ageBand: Kid["ageBand"]; characterId: string; accent: string }) => { ok: boolean; error?: string; id?: string };
  addRoutineFromTemplate: (templateId: string, kidId: string) => { ok: boolean; error?: string; id?: string };
  saveRoutine: (routine: Routine, expectedVersion: number) => { ok: boolean; error?: string };
  setPin: (pin: string) => string | null;
  checkPin: (pin: string) => { ok: boolean; message?: string };
  enterKidMode: (kidId: string) => void;
  exitKidMode: () => void;
  completeStep: (input: { completionId: string; kidId: string; routineId: string; stepId: string }) => { ok: boolean; message?: string };
  undoStep: (runId: string, stepId: string) => void;
  approveRun: (runId: string, reopenStepIds: string[]) => { ok: boolean; message?: string };
  addReward: (reward: Omit<Reward, "id">) => { ok: boolean; error?: string };
  requestReward: (redemptionId: string, kidId: string, rewardId: string) => { ok: boolean; message?: string };
  resolveRedemption: (id: string, action: "fulfilled" | "denied") => void;
  adjustStars: (kidId: string, amount: number, note: string) => { ok: boolean; message?: string };
  setPlan: (plan: PlanId) => void;
  deleteKid: (id: string) => void;
  deleteAccount: () => void;
  exportData: () => string;
  today: () => string;
}

const memory = new Map<string, string>();
const storage = createJSONStorage(() => ({
  getItem: (name: string) => {
    if (typeof localStorage !== "undefined") return localStorage.getItem(name);
    return memory.get(name) ?? null;
  },
  setItem: (name: string, value: string) => {
    if (typeof localStorage !== "undefined") localStorage.setItem(name, value);
    else memory.set(name, value);
  },
  removeItem: (name: string) => {
    if (typeof localStorage !== "undefined") localStorage.removeItem(name);
    else memory.delete(name);
  },
}));

function id(): string {
  return Math.random().toString(36).slice(2) + Date.now().toString(36);
}

function hashPin(pin: string): string {
  let h = 2166136261;
  const salt = "dayhop-device";
  for (const ch of salt + pin) {
    h ^= ch.charCodeAt(0);
    h = Math.imul(h, 16777619);
  }
  return (h >>> 0).toString(16);
}

function plusActive(state: { plan: PlanId; plusExpiresAt?: number }): boolean {
  if (state.plan !== "plus") return false;
  if (state.plusExpiresAt == null) return true;
  return state.plusExpiresAt > Date.now();
}

function recomputeKid(kid: Kid, runs: Run[], today: string): Kid {
  const mine = runs.filter((run) => run.kidId === kid.id);
  const dates = new Set<string>();
  for (const run of mine) dates.add(run.routineDate);
  const start = [...dates].sort()[0] ?? today;
  const days = datesBetween(start, today).map((date) => {
    const scheduled = mine.some((run) => run.routineDate === date) || false;
    const paused = kid.pauses.some((pause) => date >= pause.start && date <= pause.end);
    const dayRuns = mine.filter((run) => run.routineDate === date);
    const completed = dayRuns.some((run) => run.status === "completed" || run.status === "approved");
    return { date, scheduled: scheduled || dayRuns.length > 0, completed, paused };
  });
  const streak = computeStreak(days, today);
  return { ...kid, streakCurrent: streak.current, streakBest: Math.max(kid.streakBest, streak.best) };
}

function credit(state: AppState, kidId: string, amount: number, type: string, key: string, note?: string): Partial<AppState> {
  if (state.ledger.some((row) => row.id === key)) return {};
  const kid = state.kids.find((item) => item.id === kidId);
  if (!kid) return {};
  const next = applyAmount(kid.starsBalance, amount);
  if (next.rejected || next.applied === 0) return {};
  const lifetime = amount > 0 ? kid.lifetimeStars + next.applied : kid.lifetimeStars;
  return {
    kids: state.kids.map((item) => (item.id === kidId ? { ...item, starsBalance: next.balance, lifetimeStars: lifetime } : item)),
    ledger: [...state.ledger, { id: key, kidId, amount: next.applied, type, note, createdAt: Date.now() }],
  };
}

export const useApp = create<AppState>()(
  persist(
    (set, get) => ({
      onboardStep: 0,
      adultConfirmed: false,
      policyVersion: "2026-11-09",
      householdName: "",
      timeZone: "America/New_York",
      plan: "free",
      kids: [],
      routines: [],
      runs: [],
      rewards: [],
      redemptions: [],
      ledger: [],
      pinFailures: 0,
      pinLockedUntil: null,
      kidMode: false,
      outbox: [],
      soundOn: true,
      readAloud: true,
      deleted: false,
      today: () => routineDate(new Date(), get().timeZone),
      loadSample: () => {
        const kidId = "maya";
        const routineId = "maya-morning";
        const template = TEMPLATES[0];
        set({
          deleted: false,
          adultConfirmed: true,
          consentAt: new Date().toISOString(),
          householdName: "Maya's house",
          timeZone: Intl.DateTimeFormat().resolvedOptions().timeZone || "America/New_York",
          onboardStep: 8,
          pinHash: hashPin("2580"),
          plan: "plus",
          plusExpiresAt: Date.now() + 7 * 24 * 60 * 60 * 1000,
          kids: [
            {
              id: kidId,
              nickname: "Maya",
              ageBand: "5-6",
              characterId: "pip",
              accent: CHARACTERS[0].color,
              starsBalance: 4,
              lifetimeStars: 4,
              streakCurrent: 1,
              streakBest: 1,
              pauses: [],
            },
          ],
          routines: [
            {
              id: routineId,
              name: template.name,
              timeOfDay: template.timeOfDay,
              days: 127,
              bonusStars: template.bonusStars,
              requiresApproval: true,
              version: 1,
              kidIds: [kidId],
              steps: template.steps.map((step, index) => ({ ...step, id: `${routineId}-${index}`, position: index })),
            },
          ],
          rewards: [{ id: "story", title: "Extra story", iconKey: "book", cost: 8 }],
          ledger: [{ id: "seed", kidId, amount: 4, type: "adjustment", note: "Sample start", createdAt: Date.now() }],
        });
      },
      setOnboard: (step) => set({ onboardStep: step }),
      confirmAdult: (yes) => set(yes ? { adultConfirmed: true, onboardStep: 3 } : { adultConfirmed: false, onboardStep: 0, householdName: "" }),
      setHousehold: (name, timeZone) => set({ householdName: name.slice(0, 40), timeZone, onboardStep: 4 }),
      recordConsent: () => set({ consentAt: new Date().toISOString(), onboardStep: 5 }),
      addKid: (input) => {
        const state = get();
        if (!state.consentAt) return { ok: false, error: "Record consent before a kid profile." };
        const nickname = normalizeNickname(input.nickname);
        const error = nicknameError(nickname);
        if (error) return { ok: false, error };
        const active = state.kids.filter((kid) => !kid.archivedAt).length;
        if (creationBlocked(state.plan, plusActive(state), "kid", active)) return { ok: false, error: "PLAN_REQUIRED" };
        const kid: Kid = {
          id: id(),
          nickname,
          ageBand: input.ageBand,
          characterId: input.characterId || CHARACTERS[0].id,
          accent: input.accent,
          starsBalance: 0,
          lifetimeStars: 0,
          streakCurrent: 0,
          streakBest: 0,
          pauses: [],
        };
        set({ kids: [...state.kids, kid], onboardStep: Math.max(state.onboardStep, 6) });
        return { ok: true, id: kid.id };
      },
      addRoutineFromTemplate: (templateId, kidId) => {
        const state = get();
        const template = TEMPLATES.find((item) => item.id === templateId);
        if (!template) return { ok: false, error: "Missing template." };
        const count = state.routines.filter((routine) => !routine.archivedAt && routine.kidIds.includes(kidId)).length;
        if (creationBlocked(state.plan, plusActive(state), "routine", count)) return { ok: false, error: "PLAN_REQUIRED" };
        const routineId = id();
        const routine: Routine = {
          id: routineId,
          name: template.name,
          timeOfDay: template.timeOfDay,
          days: template.days,
          bonusStars: template.bonusStars,
          requiresApproval: false,
          version: 1,
          kidIds: [kidId],
          steps: template.steps.map((step, index) => ({ ...step, id: id(), position: index })),
        };
        set({ routines: [...state.routines, routine], onboardStep: Math.max(state.onboardStep, 7) });
        return { ok: true, id: routineId };
      },
      saveRoutine: (routine, expectedVersion) => {
        const state = get();
        const current = state.routines.find((item) => item.id === routine.id);
        if (current && current.version !== expectedVersion) return { ok: false, error: "STALE_VERSION" };
        if (routine.steps.length < 1) return { ok: false, error: "Add at least one step." };
        if (routine.steps.length > 15) return { ok: false, error: "15 steps is the maximum." };
        if (routine.requiresApproval && !plusActive(state)) return { ok: false, error: "PLAN_REQUIRED" };
        const next = { ...routine, version: (current?.version ?? 0) + 1 };
        set({
          routines: current ? state.routines.map((item) => (item.id === routine.id ? next : item)) : [...state.routines, next],
        });
        return { ok: true };
      },
      setPin: (pin) => {
        const error = pinError(pin);
        if (error) return error;
        set({ pinHash: hashPin(pin), pinFailures: 0, pinLockedUntil: null, onboardStep: 8 });
        return null;
      },
      checkPin: (pin) => {
        const state = get();
        const now = Date.now();
        if (pinLocked({ failures: state.pinFailures, lockedUntil: state.pinLockedUntil }, now)) {
          return { ok: false, message: "Ask a grown-up." };
        }
        if (state.pinHash && hashPin(pin) === state.pinHash) {
          set({ pinFailures: 0, pinLockedUntil: null });
          return { ok: true };
        }
        const next = registerPinFailure({ failures: state.pinFailures, lockedUntil: state.pinLockedUntil }, now);
        set({ pinFailures: next.failures, pinLockedUntil: next.lockedUntil });
        return { ok: false, message: next.lockedUntil && next.lockedUntil > now ? "Ask a grown-up." : "That PIN does not match." };
      },
      enterKidMode: (kidId) => set({ kidMode: true, activeKidId: kidId }),
      exitKidMode: () => set({ kidMode: false }),
      completeStep: ({ completionId, kidId, routineId, stepId }) => {
        const state = get();
        const today = routineDate(new Date(), state.timeZone);
        if (!routineDateAllowed(today, new Date(), state.timeZone)) return { ok: false, message: "That was yesterday's one!" };
        const routine = state.routines.find((item) => item.id === routineId && item.kidIds.includes(kidId) && !item.archivedAt);
        if (!routine) return { ok: false, message: "That routine is not on today." };
        if (!isScheduled(routine.days, today)) return { ok: false, message: "Nothing on the list for today." };
        let run = state.runs.find((item) => item.kidId === kidId && item.routineId === routineId && item.routineDate === today);
        if (run && (run.status === "expired" || run.routineDate !== today)) return { ok: false, message: "That was yesterday's one!" };
        if (!run) {
          run = {
            id: id(),
            kidId,
            routineId,
            routineDate: today,
            status: "in_progress",
            version: routine.version,
            steps: routine.steps.map((step) => ({ ...step })),
            bonusStars: routine.bonusStars,
            requiresApproval: routine.requiresApproval && plusActive(state),
            completions: {},
            credited: false,
          };
        }
        if (run.status === "approved" || run.status === "completed" || run.status === "pending_approval") {
          return { ok: false, message: "That routine is already finished." };
        }
        const existing = Object.values(run.completions).find((item) => item.id === completionId);
        if (existing && !("undoneAt" in existing && existing.undoneAt)) return { ok: true };
        const step = run.steps.find((item) => item.id === stepId);
        if (!step || !Number.isInteger(step.stars) || step.stars < 0 || step.stars > 5) return { ok: false, message: "That step cannot be saved." };
        const completions: Run["completions"] = { ...run.completions, [stepId]: { id: completionId } };
        const doneCount = run.steps.filter((item) => completions[item.id] && !completions[item.id].undoneAt).length;
        const finished = doneCount === run.steps.length;
        const status = finished ? statusAfterFinish(run.requiresApproval, true) : "in_progress";
        const nextRun: Run = { ...run, completions, status, submittedAt: finished ? Date.now() : run.submittedAt };
        let runs = state.runs.some((item) => item.id === run!.id) ? state.runs.map((item) => (item.id === run!.id ? nextRun : item)) : [...state.runs, nextRun];
        let patch: Partial<AppState> = { runs };
        if (!run.requiresApproval) {
          const starKey = `step:${completionId}`;
          if (!state.ledger.some((row) => row.id === starKey) && step.stars > 0) {
            patch = { ...patch, ...credit({ ...state, ...patch, runs }, kidId, step.stars, "step", starKey) };
          }
          if (finished) {
            patch = { ...patch, ...credit({ ...state, ...patch }, kidId, run.bonusStars, "routine_bonus", `bonus:${run.id}`) };
            const merged = { ...state, ...patch, runs };
            patch.kids = merged.kids.map((kid) => (kid.id === kidId ? recomputeKid(kid, merged.runs, today) : kid));
          }
        }
        set(patch);
        return { ok: true };
      },
      undoStep: (runId, stepId) => {
        const state = get();
        const run = state.runs.find((item) => item.id === runId);
        if (!run || run.status === "approved" || run.status === "completed" || run.status === "pending_approval") return;
        const completion = run.completions[stepId];
        if (!completion || completion.undoneAt) return;
        const step = run.steps.find((item) => item.id === stepId);
        const completions = { ...run.completions, [stepId]: { ...completion, undoneAt: new Date().toISOString() } };
        const runs = state.runs.map((item) => (item.id === runId ? { ...item, completions, status: "in_progress" as const } : item));
        let patch: Partial<AppState> = { runs };
        if (step && step.stars > 0 && !run.requiresApproval) {
          patch = { ...patch, ...credit({ ...state, runs }, run.kidId, -step.stars, "reversal", `undo:${completion.id}`) };
        }
        set(patch);
      },
      approveRun: (runId, reopenStepIds) => {
        const state = get();
        const run = state.runs.find((item) => item.id === runId);
        if (!run) return { ok: false, message: "NOT_FOUND" };
        if (run.status === "approved" || run.status === "completed") return { ok: false, message: "ALREADY_HANDLED" };
        if (reopenStepIds.length) {
          const completions = { ...run.completions };
          for (const stepId of reopenStepIds) {
            if (completions[stepId]) completions[stepId] = { ...completions[stepId], undoneAt: new Date().toISOString() };
          }
          set({
            runs: state.runs.map((item) => (item.id === runId ? { ...item, completions, status: "reopened" } : item)),
          });
          return { ok: true };
        }
        const auto = run.submittedAt != null && shouldAutoApprove(run.submittedAt, Date.now());
        let patch: Partial<AppState> = {
          runs: state.runs.map((item) => (item.id === runId ? { ...item, status: "approved", credited: true, autoApproved: auto } : item)),
        };
        for (const step of run.steps) {
          const completion = run.completions[step.id];
          if (!completion || completion.undoneAt || step.stars === 0) continue;
          patch = { ...patch, ...credit({ ...state, ...patch }, run.kidId, step.stars, "step", `step:${completion.id}`) };
        }
        patch = { ...patch, ...credit({ ...state, ...patch }, run.kidId, run.bonusStars, "routine_bonus", `bonus:${run.id}`) };
        const today = routineDate(new Date(), state.timeZone);
        const merged = { ...state, ...patch };
        patch.kids = merged.kids.map((kid) => (kid.id === run.kidId ? recomputeKid(kid, merged.runs, today) : kid));
        set(patch);
        return { ok: true };
      },
      addReward: (reward) => {
        const state = get();
        if (!plusActive(state)) return { ok: false, error: "PLAN_REQUIRED" };
        if (state.rewards.filter((item) => !item.archivedAt).length >= 25) return { ok: false, error: "25 rewards is the maximum." };
        if (reward.cost < 1 || reward.cost > 999) return { ok: false, error: "Cost must be 1 to 999." };
        set({ rewards: [...state.rewards, { ...reward, id: id() }] });
        return { ok: true };
      },
      requestReward: (redemptionId, kidId, rewardId) => {
        const state = get();
        if (!plusActive(state)) return { ok: false, message: "Ask a grown-up about Plus." };
        if (state.redemptions.some((item) => item.id === redemptionId)) return { ok: true };
        const reward = state.rewards.find((item) => item.id === rewardId);
        const kid = state.kids.find((item) => item.id === kidId);
        if (!reward || !kid) return { ok: false, message: "NOT_FOUND" };
        if (kid.starsBalance < reward.cost) return { ok: false, message: `${reward.cost - kid.starsBalance} more stars to go!` };
        const held = credit(state, kidId, -reward.cost, "redemption_hold", `hold:${redemptionId}`);
        set({
          ...held,
          redemptions: [...state.redemptions, { id: redemptionId, kidId, rewardId, title: reward.title, cost: reward.cost, status: "requested", requestedAt: Date.now() }],
        });
        return { ok: true };
      },
      resolveRedemption: (redemptionId, action) => {
        const state = get();
        const item = state.redemptions.find((row) => row.id === redemptionId);
        if (!item || item.status !== "requested") return;
        let patch: Partial<AppState> = {
          redemptions: state.redemptions.map((row) => (row.id === redemptionId ? { ...row, status: action } : row)),
        };
        if (action === "denied") patch = { ...patch, ...credit(state, item.kidId, item.cost, "redemption_refund", `refund:${redemptionId}`) };
        set(patch);
      },
      adjustStars: (kidId, amount, note) => {
        if (!note.trim() || amount === 0) return { ok: false, message: "Add an amount and a note." };
        const state = get();
        const result = credit(state, kidId, amount, "adjustment", `adjust:${id()}`, note.slice(0, 120));
        if (!result.kids) return { ok: false, message: "That would take the balance below zero, or the balance is already full." };
        set(result);
        return { ok: true };
      },
      setPlan: (plan) => set({ plan, plusExpiresAt: plan === "plus" ? Date.now() + 7 * 24 * 60 * 60 * 1000 : undefined }),
      deleteKid: (kidId) => {
        const state = get();
        set({
          kids: state.kids.filter((kid) => kid.id !== kidId),
          runs: state.runs.filter((run) => run.kidId !== kidId),
          redemptions: state.redemptions.filter((item) => item.kidId !== kidId),
          activeKidId: state.activeKidId === kidId ? undefined : state.activeKidId,
        });
      },
      deleteAccount: () =>
        set({
          deleted: true,
          kids: [],
          routines: [],
          runs: [],
          rewards: [],
          redemptions: [],
          ledger: [],
          pinHash: undefined,
          kidMode: false,
          householdName: "",
          consentAt: undefined,
          onboardStep: 0,
          adultConfirmed: false,
        }),
      exportData: () => {
        const state = get();
        return JSON.stringify(
          {
            householdName: state.householdName,
            timeZone: state.timeZone,
            plan: state.plan,
            kids: state.kids,
            routines: state.routines,
            runs: state.runs,
            rewards: state.rewards,
            redemptions: state.redemptions,
            ledger: state.ledger,
          },
          null,
          2,
        );
      },
    }),
    {
      name: "dayhop",
      storage,
      partialize: (state) => {
        const data: Record<string, unknown> = {};
        for (const [key, value] of Object.entries(state)) {
          if (typeof value !== "function") data[key] = value;
        }
        return data as unknown as AppState;
      },
    },
  ),
);

export function characterFor(id: string) {
  return CHARACTERS.find((item) => item.id === id) ?? CHARACTERS[0];
}

export function stageLabel(lifetime: number, plan: PlanId, expires?: number): string {
  const stage = cosmeticStage(lifetime, plan === "plus" && (expires == null || expires > Date.now()));
  if (stage >= 300) return "Stage 300";
  if (stage >= 100) return "Stage 100";
  if (stage >= 25) return "Stage 25";
  return "Stage 0";
}
