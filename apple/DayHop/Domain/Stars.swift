import Foundation

enum LedgerType: String, Codable, CaseIterable {
    case step
    case routineBonus = "routine_bonus"
    case streakBonus = "streak_bonus"
    case redemptionHold = "redemption_hold"
    case redemptionRefund = "redemption_refund"
    case adjustment
    case reversal
}

struct LedgerAmount: Equatable {
    var id: String
    var amount: Int
    var type: LedgerType
}

struct AppliedStars: Equatable {
    var balance: Int
    var applied: Int
    var capped: Bool
    var rejected: Bool
}

enum Stars {
    static let maxBalance = 99_999

    static func sum(_ entries: [LedgerAmount]) -> Int {
        entries.reduce(0) { $0 + $1.amount }
    }

    /// R5. Balance is the sum, never negative, and never above 99,999.
    static func apply(balance: Int, amount: Int) -> AppliedStars {
        if amount == 0 { return AppliedStars(balance: balance, applied: 0, capped: false, rejected: true) }
        if amount < 0 {
            if balance + amount < 0 { return AppliedStars(balance: balance, applied: 0, capped: false, rejected: true) }
            return AppliedStars(balance: balance + amount, applied: amount, capped: false, rejected: false)
        }
        let room = maxBalance - balance
        if room <= 0 { return AppliedStars(balance: balance, applied: 0, capped: true, rejected: false) }
        if amount > room { return AppliedStars(balance: maxBalance, applied: room, capped: true, rejected: false) }
        return AppliedStars(balance: balance + amount, applied: amount, capped: false, rejected: false)
    }

    static func stepStarsAllowed(_ stars: Int) -> Bool {
        (0...5).contains(stars)
    }

    static func bonusStarsAllowed(_ stars: Int) -> Bool {
        (0...10).contains(stars)
    }
}
