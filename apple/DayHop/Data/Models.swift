import Foundation

enum AgeBand: String, Codable, CaseIterable, Identifiable {
    case three = "3-4"
    case five = "5-6"
    case seven = "7-8"
    case nine = "9-10"
    case eleven = "11+"

    var id: String { rawValue }

    var preReader: Bool { self == .three || self == .five }
}

struct StreakPause: Codable, Equatable, Identifiable {
    var id: UUID
    var start: String
    var end: String
}

struct Kid: Codable, Equatable, Identifiable {
    var id: UUID
    var nickname: String
    var ageBand: AgeBand
    var characterID: String
    var accent: String
    var starsBalance: Int
    var lifetimeStars: Int
    var streakCurrent: Int
    var streakBest: Int
    var createdAt: Date
    var archivedAt: Date?
    var pauses: [StreakPause]
}

struct Step: Codable, Equatable, Identifiable {
    var id: UUID
    var title: String
    var iconKey: String
    var stars: Int
    var position: Int
    var timerMinutes: Int?
    var archived: Bool
}

struct Routine: Codable, Equatable, Identifiable {
    var id: UUID
    var name: String
    var timeOfDay: TimeOfDay
    var days: Int
    var startTime: String?
    var requiresApproval: Bool
    var bonusStars: Int
    var version: Int
    var createdAt: Date
    var archivedAt: Date?
    var kidIDs: [UUID]
    var inactiveKidIDs: [UUID]
    var steps: [Step]

    var activeSteps: [Step] {
        steps.filter { !$0.archived }.sorted { $0.position < $1.position }
    }
}

struct StepCompletion: Codable, Equatable {
    var id: UUID
    var undoneAt: Date?
}

struct RoutineRun: Codable, Equatable, Identifiable {
    var id: UUID
    var kidID: UUID
    var routineID: UUID
    var routineDate: String
    var status: RunStatus
    var version: Int
    var steps: [Step]
    var bonusStars: Int
    var requiresApproval: Bool
    var completions: [UUID: StepCompletion]
    var submittedAt: Date?
    var autoApproved: Bool
    var credited: Bool

    func isDone(_ stepID: UUID) -> Bool {
        guard let completion = completions[stepID] else { return false }
        return completion.undoneAt == nil
    }
}

struct Reward: Codable, Equatable, Identifiable {
    var id: UUID
    var title: String
    var iconKey: String
    var cost: Int
    var weeklyLimit: Int?
    var archivedAt: Date?
}

enum RedemptionStatus: String, Codable {
    case requested
    case fulfilled
    case denied
    case cancelled
}

struct Redemption: Codable, Equatable, Identifiable {
    var id: UUID
    var kidID: UUID
    var rewardID: UUID
    var title: String
    var cost: Int
    var status: RedemptionStatus
    var requestedAt: Date
    var resolvedAt: Date?
}

struct LedgerRow: Codable, Equatable, Identifiable {
    var id: String
    var kidID: UUID
    var amount: Int
    var type: LedgerType
    var note: String?
    var createdAt: Date
}

struct Invite: Codable, Equatable, Identifiable {
    var id: UUID
    var code: String
    var createdAt: Date
    var expiresAt: Date
    var revokedAt: Date?
    var usedAt: Date?

    var isOpen: Bool { revokedAt == nil && usedAt == nil && expiresAt > Date() }
}

struct HouseholdSnapshot: Codable, Equatable {
    var schemaVersion: Int = 1
    var signedIn: Bool = false
    var email: String = ""
    var onboardStep: Int = 0
    var adultConfirmed: Bool = false
    var consentAt: Date?
    var policyVersion: String = "2026-11-09"
    var householdName: String = ""
    var timeZoneID: String = TimeZone.current.identifier
    var plan: PlanID = .free
    var plusProduct: String?
    var plusExpiresAt: Date?
    var kids: [Kid] = []
    var routines: [Routine] = []
    var runs: [RoutineRun] = []
    var rewards: [Reward] = []
    var redemptions: [Redemption] = []
    var ledger: [LedgerRow] = []
    var pinFailures: Int = 0
    var pinLockedUntil: Date?
    var kidMode: Bool = false
    var activeKidID: UUID?
    var soundOn: Bool = true
    var readAloud: Bool = true
    var faceIDOn: Bool = true
    var notificationAskedAt: Date?
    var notificationNoteDismissedAt: Date?
    var reminderRoutineIDs: [UUID] = []
    var quietStartMinute: Int = 21 * 60
    var quietEndMinute: Int = 7 * 60
    var notifyApprovals: Bool = true
    var notifyFinished: Bool = true
    var notifyRewards: Bool = true
    var notifySummary: Bool = true
    var notifyInvites: Bool = true
    var notifyBilling: Bool = true
    var invites: [Invite] = []
    var inviteFailures: [Date] = []
    var savedAt: Date = Date()
    var balanceCapped: Bool = false
    var dismissedZoneID: String?
    var createdFirstRoutine: Bool = false
}

enum StepOutcome: Equatable {
    case ok
    case finishedNow
    case yesterday
    case notToday
    case missing
    case finished
    case invalid
    case starsSpent
}

enum RewardOutcome: Equatable {
    case ok
    case needsPlus
    case missing
    case weeklyLimit
    case short(Int)
}

enum SaveIssue: Equatable {
    case name
    case noSteps
    case tooMany
    case step
    case stars
    case bonus
    case kids
    case days
    case plan
    case stale
    case overLimit
}

enum SignInIssue: Equatable {
    case invalid
    case password
    case differentHousehold
    case notConfigured
    case offline
    case cancelled
    case unverified
    case confirmationSent
    case alreadyLinked
    case useExisting
    case generic
}

enum KidWrite: Equatable {
    case ok
    case duplicate
    case consent
    case nickname(NicknameIssue)
    case plan
    case restoreWindow
}
