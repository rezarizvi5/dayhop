import Foundation

enum RunStatus: String, Codable {
    case inProgress = "in_progress"
    case pendingApproval = "pending_approval"
    case approved
    case completed
    case reopened
    case expired
}

enum ApprovalRules {
    static let autoInterval: TimeInterval = 48 * 60 * 60

    static func shouldAutoApprove(submittedAt: Date, now: Date) -> Bool {
        now.timeIntervalSince(submittedAt) >= autoInterval
    }

    static func statusAfterFinish(requiresApproval: Bool, plusActive: Bool) -> RunStatus {
        if requiresApproval && plusActive { return .pendingApproval }
        return .completed
    }

    static var finished: Set<RunStatus> { [.completed, .approved, .pendingApproval] }
}
