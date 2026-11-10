import Foundation

enum PinIssue: Equatable {
    case length
    case trivial
    case unavailable
}

struct LockoutState: Equatable {
    var failures: Int
    var lockedUntil: Date?
}

enum ParentPin {
    static func issue(_ pin: String) -> PinIssue? {
        guard pin.range(of: #"^\d{4}$"#, options: .regularExpression) != nil else { return .length }
        if pin == "0000" || pin == "1234" { return .trivial }
        return nil
    }

    static func registerFailure(_ state: LockoutState, now: Date) -> LockoutState {
        let failures = state.failures + 1
        if failures == 5 { return LockoutState(failures: failures, lockedUntil: now.addingTimeInterval(5 * 60)) }
        if failures == 10 || (failures > 10 && failures % 5 == 0) {
            return LockoutState(failures: failures, lockedUntil: now.addingTimeInterval(15 * 60))
        }
        return LockoutState(failures: failures, lockedUntil: state.lockedUntil)
    }

    static func isLocked(_ state: LockoutState, now: Date) -> Bool {
        guard let until = state.lockedUntil else { return false }
        return now < until
    }
}
