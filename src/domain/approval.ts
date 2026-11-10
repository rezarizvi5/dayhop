const AUTO_MS = 48 * 60 * 60 * 1000;

export function shouldAutoApprove(submittedAt: number, now: number): boolean {
  return now - submittedAt >= AUTO_MS;
}

export type RunStatus = "in_progress" | "pending_approval" | "approved" | "completed" | "reopened" | "expired";

export function statusAfterFinish(requiresApproval: boolean, plusActive: boolean): RunStatus {
  if (requiresApproval && plusActive) return "pending_approval";
  return "completed";
}
