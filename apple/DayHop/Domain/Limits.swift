import Foundation

enum PlanID: String, Codable {
    case free
    case plus
}

struct PlanLimits: Equatable {
    var guardians: Int
    var kids: Int
    var routinesPerKid: Int
    var rewards: Bool
    var approval: Bool
    var weeklyFull: Bool
    var cosmeticStages: Bool
    var maxSteps: Int
    var maxActiveRewards: Int
}

enum Limits {
    static let maxSteps = 15
    static let maxActiveRewards = 25
    static let maxKidsHard = 6
    static let rewardCost = 1...999
    static let nicknameLength = 1...20
    static let routineNameLength = 1...30
    static let stepTitleLength = 1...40
    static let householdNameLength = 1...40
    static let cosmeticMarks = [0, 25, 100, 300]
    static let streakBonusStars = 5

    static func limits(for plan: PlanID, plusActive: Bool) -> PlanLimits {
        if plusActive && plan == .plus {
            return PlanLimits(guardians: 4, kids: 6, routinesPerKid: 10, rewards: true, approval: true, weeklyFull: true, cosmeticStages: true, maxSteps: maxSteps, maxActiveRewards: maxActiveRewards)
        }
        return PlanLimits(guardians: 2, kids: 2, routinesPerKid: 3, rewards: false, approval: false, weeklyFull: false, cosmeticStages: false, maxSteps: maxSteps, maxActiveRewards: 0)
    }

    static func creationBlocked(plan: PlanID, plusActive: Bool, kind: String, count: Int) -> Bool {
        let caps = limits(for: plan, plusActive: plusActive)
        switch kind {
        case "kid": return count >= caps.kids
        case "routine": return count >= caps.routinesPerKid
        case "guardian": return count >= caps.guardians
        default: return !caps.rewards || count >= caps.maxActiveRewards
        }
    }

    static func cosmeticStage(lifetimeStars: Int, plusActive: Bool) -> Int {
        guard plusActive else { return 0 }
        var stage = 0
        for mark in cosmeticMarks where lifetimeStars >= mark {
            stage = mark
        }
        return stage
    }

    static func lengthOK(_ value: String, range: ClosedRange<Int>) -> Bool {
        range.contains(value.count)
    }
}
