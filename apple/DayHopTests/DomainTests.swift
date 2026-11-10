import XCTest
@testable import DayHop

final class DomainTests: XCTestCase {
    func testRoutineDayStartsAtThreeLocal() {
        let zone = TimeZone(identifier: "America/New_York")!
        XCTAssertEqual(RoutineCalendar.routineDate(instant: date("2026-05-12T06:59:00Z"), timeZone: zone), "2026-05-11")
        XCTAssertEqual(RoutineCalendar.routineDate(instant: date("2026-05-12T07:00:00Z"), timeZone: zone), "2026-05-12")
    }

    func testUSSpringForwardDoesNotDuplicateTheDate() {
        let zone = TimeZone(identifier: "America/New_York")!
        XCTAssertEqual(RoutineCalendar.routineDate(instant: date("2026-03-08T06:30:00Z"), timeZone: zone), "2026-03-07")
        XCTAssertEqual(RoutineCalendar.routineDate(instant: date("2026-03-08T07:30:00Z"), timeZone: zone), "2026-03-08")
    }

    func testUSFallBackKeepsBothInstantsOnOneDate() {
        let zone = TimeZone(identifier: "America/New_York")!
        let first = RoutineCalendar.routineDate(instant: date("2026-11-01T05:30:00Z"), timeZone: zone)
        let second = RoutineCalendar.routineDate(instant: date("2026-11-01T06:30:00Z"), timeZone: zone)
        XCTAssertEqual(first, second)
    }

    func testAustraliaAndLordHowe() {
        XCTAssertEqual(RoutineCalendar.routineDate(instant: date("2026-04-05T15:30:00Z"), timeZone: TimeZone(identifier: "Australia/Sydney")!), "2026-04-05")
        XCTAssertEqual(RoutineCalendar.routineDate(instant: date("2026-04-04T15:00:00Z"), timeZone: TimeZone(identifier: "Australia/Lord_Howe")!), "2026-04-04")
        XCTAssertEqual(RoutineCalendar.routineDate(instant: date("2026-04-04T17:00:00Z"), timeZone: TimeZone(identifier: "Australia/Lord_Howe")!), "2026-04-05")
    }

    func testUTCPlus13And14() {
        let instant = date("2026-06-01T13:30:00Z")
        let plus13 = RoutineCalendar.routineDate(instant: instant, timeZone: TimeZone(identifier: "Pacific/Tongatapu")!)
        let plus14 = RoutineCalendar.routineDate(instant: instant, timeZone: TimeZone(identifier: "Pacific/Kiritimati")!)
        XCTAssertEqual(plus13, "2026-06-01")
        XCTAssertEqual(plus14, "2026-06-02")
        XCTAssertEqual(RoutineCalendar.dateDiffDays(plus14, plus13), 1)
    }

    func testClientDateWindow() {
        let now = date("2026-06-01T15:00:00Z")
        let zone = TimeZone(identifier: "America/New_York")!
        XCTAssertTrue(RoutineCalendar.routineDateAllowed(clientDate: "2026-06-01", serverNow: now, timeZone: zone))
        XCTAssertFalse(RoutineCalendar.routineDateAllowed(clientDate: "2026-06-03", serverNow: now, timeZone: zone))
        XCTAssertFalse(RoutineCalendar.routineDateAllowed(clientDate: "2026-05-29", serverNow: now, timeZone: zone))
    }

    func testHouseholdZoneDiffersFromUTC() {
        let instant = date("2026-06-02T02:30:00Z")
        XCTAssertEqual(RoutineCalendar.routineDate(instant: instant, timeZone: TimeZone(secondsFromGMT: 0)!), "2026-06-01")
        XCTAssertEqual(RoutineCalendar.routineDate(instant: instant, timeZone: TimeZone(identifier: "Pacific/Auckland")!), "2026-06-02")
    }

    func testMondayBitmask() {
        let weekdays = Schedule.mask(fromWeekdays: [1, 2, 3, 4, 5])
        XCTAssertTrue(Schedule.isScheduled(weekdays, "2026-06-01"))
        XCTAssertFalse(Schedule.isScheduled(weekdays, "2026-06-06"))
        XCTAssertEqual(Schedule.dayBit(for: "2026-06-07"), 64)
        XCTAssertEqual(Schedule.weekStartMonday("2026-06-07"), "2026-06-01")
        XCTAssertEqual(RoutineCalendar.addDays("2026-06-07", 1), "2026-06-08")
    }

    func testStarBalanceNeverGoesNegativeOrPastTheCap() {
        XCTAssertTrue(Stars.apply(balance: 3, amount: -4).rejected)
        XCTAssertEqual(Stars.apply(balance: 3, amount: -2).balance, 1)
        let capped = Stars.apply(balance: Stars.maxBalance - 2, amount: 5)
        XCTAssertEqual(capped.balance, Stars.maxBalance)
        XCTAssertTrue(capped.capped)
        XCTAssertEqual(capped.applied, 2)
        XCTAssertTrue(Stars.stepStarsAllowed(5))
        XCTAssertFalse(Stars.stepStarsAllowed(6))
        XCTAssertEqual(Stars.sum([
            LedgerAmount(id: "a", amount: 1, type: .step),
            LedgerAmount(id: "b", amount: 3, type: .routineBonus),
            LedgerAmount(id: "c", amount: -1, type: .reversal),
        ]), 3)
    }

    func testStreakIgnoresUnscheduledDaysAndPauses() {
        let days = RoutineCalendar.datesBetween("2026-06-01", "2026-06-07").map { date in
            StreakDay(date: date, scheduled: date != "2026-06-06", completed: date != "2026-06-03" && date != "2026-06-06", paused: date == "2026-06-03")
        }
        XCTAssertEqual(Streaks.compute(days, today: "2026-06-07").current, 5)
    }

    func testOneShieldPerWeek() {
        let days = RoutineCalendar.datesBetween("2026-06-01", "2026-06-05").map { date in
            StreakDay(date: date, scheduled: true, completed: date != "2026-06-03", paused: false)
        }
        let result = Streaks.compute(days, today: "2026-06-05")
        XCTAssertEqual(result.shieldedDates, ["2026-06-03"])
        XCTAssertEqual(result.current, 4)
        XCTAssertTrue(result.milestoneBonuses.contains(3))
    }

    func testUnfinishedTodayDoesNotBreak() {
        let days = [
            StreakDay(date: "2026-06-01", scheduled: true, completed: true, paused: false),
            StreakDay(date: "2026-06-02", scheduled: true, completed: false, paused: false),
        ]
        XCTAssertEqual(Streaks.compute(days, today: "2026-06-02").current, 1)
    }

    func testPlanLimitsAndCosmeticStages() {
        XCTAssertTrue(Limits.creationBlocked(plan: .free, plusActive: false, kind: "kid", count: 2))
        XCTAssertFalse(Limits.creationBlocked(plan: .plus, plusActive: true, kind: "kid", count: 2))
        XCTAssertTrue(Limits.creationBlocked(plan: .plus, plusActive: true, kind: "kid", count: 6))
        XCTAssertEqual(Limits.limits(for: .plus, plusActive: false).kids, 2)
        XCTAssertEqual(Limits.cosmeticStage(lifetimeStars: 300, plusActive: false), 0)
        XCTAssertEqual(Limits.cosmeticStage(lifetimeStars: 100, plusActive: true), 100)
        XCTAssertEqual(Limits.cosmeticStage(lifetimeStars: 20, plusActive: true), 0)
    }

    func testKeychainRoundTrip() {
        KeychainStore.set("probe", account: "pin-probe")
        XCTAssertEqual(KeychainStore.get("pin-probe"), "probe", "SecItemAdd status \(KeychainStore.lastStatus)")
        KeychainStore.delete("pin-probe")
    }

    func testNicknameAndPIN() {
        XCTAssertNil(Nicknames.issue("  Maya  "))
        XCTAssertEqual(Nicknames.normalize("  Maya   Jo "), "Maya Jo")
        XCTAssertNotNil(Nicknames.issue("Maya 🌟"))
        XCTAssertNotNil(Nicknames.issue("ab\u{202E}"))
        XCTAssertNotNil(Nicknames.issue(""))
        XCTAssertNil(ParentPin.issue("2580"))
        XCTAssertNotNil(ParentPin.issue("0000"))
        XCTAssertNotNil(ParentPin.issue("1234"))
        var state = LockoutState(failures: 0, lockedUntil: nil)
        let now = Date(timeIntervalSince1970: 1_000)
        for _ in 0..<5 { state = ParentPin.registerFailure(state, now: now) }
        XCTAssertTrue(ParentPin.isLocked(state, now: now))
        XCTAssertFalse(ParentPin.isLocked(state, now: now.addingTimeInterval(5 * 60)))
    }

    func testApprovalAndReminderCap() {
        let start = Date(timeIntervalSince1970: 0)
        XCTAssertTrue(ApprovalRules.shouldAutoApprove(submittedAt: start, now: start.addingTimeInterval(48 * 60 * 60)))
        XCTAssertFalse(ApprovalRules.shouldAutoApprove(submittedAt: start, now: start.addingTimeInterval(48 * 60 * 60 - 1)))
        XCTAssertEqual(ApprovalRules.statusAfterFinish(requiresApproval: true, plusActive: true), .pendingApproval)
        XCTAssertEqual(ApprovalRules.statusAfterFinish(requiresApproval: true, plusActive: false), .completed)
        let items = (0..<80).map { ReminderSlot(id: String($0), at: start.addingTimeInterval(TimeInterval(($0 + 1) * 60 * 60))) }
        let picked = Reminders.rollingSchedule(items, now: start)
        XCTAssertEqual(picked.count, 60)
        XCTAssertEqual(picked[0].id, "0")
        XCTAssertTrue(Reminders.withinQuietHours(minutes: 22 * 60))
        XCTAssertFalse(Reminders.withinQuietHours(minutes: 8 * 60))
    }

    func testIconCatalogCoversTheBundledSet() {
        XCTAssertGreaterThanOrEqual(IconCatalog.all.count, 150)
        XCTAssertEqual(Catalog.templates().count, 4)
        XCTAssertEqual(Catalog.characters.count, 3)
    }

    func testHouseholdJoinNeverMergesTwoHomes() {
        let local = UUID()
        let remote = UUID()
        XCTAssertEqual(CloudRules.join(localRemoteID: nil, serverHouseholdID: nil, localHasContent: true), .uploadLocal)
        XCTAssertEqual(CloudRules.join(localRemoteID: nil, serverHouseholdID: remote, localHasContent: false), .useRemote)
        XCTAssertEqual(CloudRules.join(localRemoteID: nil, serverHouseholdID: remote, localHasContent: true), .refuseMerge)
        XCTAssertEqual(CloudRules.join(localRemoteID: local, serverHouseholdID: nil, localHasContent: true), .uploadLocal)
        XCTAssertEqual(CloudRules.join(localRemoteID: local, serverHouseholdID: local, localHasContent: false), .alreadySynced)
        XCTAssertEqual(CloudRules.join(localRemoteID: local, serverHouseholdID: remote, localHasContent: false), .refuseMerge)
    }

    func testUnlinkKeepsOneIdentity() {
        XCTAssertFalse(CloudRules.canUnlink(identityCount: 0))
        XCTAssertFalse(CloudRules.canUnlink(identityCount: 1))
        XCTAssertTrue(CloudRules.canUnlink(identityCount: 2))
    }

    func testRetryDelayCapsAtFiveMinutes() {
        XCTAssertEqual(CloudRules.retryDelay(attempt: 1), 2, accuracy: 0.001)
        XCTAssertEqual(CloudRules.retryDelay(attempt: 2), 4, accuracy: 0.001)
        XCTAssertEqual(CloudRules.retryDelay(attempt: 20), 300, accuracy: 0.001)
    }

    func testGoogleEmailMustBeVerified() {
        XCTAssertTrue(CloudRules.googleEmailVerified(jwt(["email_verified": true])))
        XCTAssertTrue(CloudRules.googleEmailVerified(jwt(["email_verified": "true"])))
        XCTAssertFalse(CloudRules.googleEmailVerified(jwt(["email_verified": false])))
        XCTAssertFalse(CloudRules.googleEmailVerified("not-a-token"))
    }

    func testCodeChallengeIsBase64URLNotHex() {
        let challenge = CloudRules.codeChallenge("dayhop-verifier")
        XCTAssertFalse(challenge.contains("+"))
        XCTAssertFalse(challenge.contains("/"))
        XCTAssertFalse(challenge.contains("="))
        XCTAssertNotEqual(challenge, CloudRules.sha256Hex("dayhop-verifier"))
        XCTAssertFalse(CloudConfig(url: nil, anonKey: "", googleClientID: "", googleReversedClientID: "").isConfigured)
        XCTAssertFalse(CloudConfig.load().isConfigured)
    }

    private func jwt(_ payload: [String: Any]) -> String {
        let data = try! JSONSerialization.data(withJSONObject: payload)
        var body = data.base64EncodedString()
        body = body.replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
        return "header.\(body).sig"
    }

    private func date(_ value: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: value)!
    }
}
