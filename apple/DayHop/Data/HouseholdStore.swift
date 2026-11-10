import Combine
import Foundation
import UIKit
import UserNotifications

enum ParentRoute: Hashable {
    case inbox
    case rewards
    case settings
    case paywall
    case summary
    case help
    case invites
    case methods
    case addKid
    case legal(String)
    case kid(UUID)
    case editor(UUID?, UUID)

    var token: String {
        switch self {
        case .inbox: return "inbox"
        case .rewards: return "rewards"
        case .settings: return "settings"
        case .paywall: return "paywall"
        case .summary: return "summary"
        case .help: return "help"
        case .invites: return "invites"
        case .methods: return "methods"
        case .addKid: return "add-kid"
        case .legal(let name): return "legal-\(name)"
        case .kid(let id): return "kid-\(id.uuidString)"
        case .editor(let routine, let kid): return "editor-\(routine?.uuidString ?? "new")-\(kid.uuidString)"
        }
    }
}

enum GatePurpose: Equatable, Identifiable {
    case exitKidMode
    case openParent(ParentRoute)
    case signOut
    case changePIN

    var id: String {
        switch self {
        case .exitKidMode: return "exit"
        case .openParent(let route): return "open-\(route.token)"
        case .signOut: return "sign-out"
        case .changePIN: return "change-pin"
        }
    }
}

enum PinCheck: Equatable {
    case ok
    case mismatch
    case locked
}

enum ResetPIN: Equatable {
    case ok
    case password
    case pin(PinIssue)
}

enum InviteLookup: Equatable {
    case created
    case missing
    case revoked
    case used
    case expired
    case rate
    case sameDevice
    case limit
}

enum RewardWrite: Equatable {
    case ok
    case plan
    case cost
    case length
    case limit
    case forbidden
}

enum AdjustIssue: Equatable {
    case empty
    case rejected
}

struct KidResult: Equatable {
    var write: KidWrite
    var id: UUID?
}

struct WeekStats: Equatable {
    var scheduledDays: Int
    var completedDays: Int
    var bestRoutine: String?
    var starsEarned: Int
    var starsSpent: Int
    var streak: Int
    var summaryReady: Bool
}

private struct PlannedReminder {
    var id: String
    var at: Date
    var body: String
    var kidID: UUID
}

final class NotificationBridge: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationBridge()
    weak var store: HouseholdStore?

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        Task { @MainActor in
            let blocked = self.store?.snapshot.kidMode ?? false
            completionHandler(blocked ? [] : [.banner, .sound])
        }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let info = response.notification.request.content.userInfo
        Task { @MainActor in
            self.store?.handleNotification(userInfo: info)
            completionHandler()
        }
    }
}

@MainActor
final class HouseholdStore: ObservableObject {
    @Published var snapshot: HouseholdSnapshot
    @Published var showPaywall = false
    @Published var askForReminders = false
    @Published var gate: GatePurpose?
    @Published var pendingRoute: ParentRoute?

    private let fileURL: URL
    private var didLaunch = false
    private var inHousekeeping = false
    private let installKey = "dayhop.installed.v1"

    init() {
        let url = Self.storageURL()
        fileURL = url
        snapshot = Self.load(url) ?? HouseholdSnapshot()
        NotificationBridge.shared.store = self
        UNUserNotificationCenter.current().delegate = NotificationBridge.shared
    }

    var zone: TimeZone { TimeZone(identifier: snapshot.timeZoneID) ?? .current }
    var plusActive: Bool {
        guard snapshot.plan == .plus else { return false }
        guard let expiry = snapshot.plusExpiresAt else { return true }
        return expiry > Date()
    }
    var hasPIN: Bool { KeychainStore.get("pin") != nil }
    var activeKids: [Kid] { snapshot.kids.filter { $0.archivedAt == nil } }
    var pendingRuns: [RoutineRun] { snapshot.runs.filter { $0.status == .pendingApproval } }
    var pendingRewards: [Redemption] { snapshot.redemptions.filter { $0.status == .requested } }
    var showOnboarding: Bool {
        if !snapshot.signedIn || !snapshot.adultConfirmed || snapshot.consentAt == nil { return true }
        if snapshot.onboardStep < 8 || !hasPIN { return true }
        return false
    }
    var deviceZoneDiffers: Bool {
        let device = TimeZone.current.identifier
        return device != snapshot.timeZoneID && snapshot.dismissedZoneID != device
    }
    var overFreeLimit: Bool {
        guard !plusActive else { return false }
        let caps = Limits.limits(for: .free, plusActive: false)
        if activeKids.count > caps.kids { return true }
        return activeKids.contains { activeRoutineCount($0.id) > caps.routinesPerKid }
    }

    func launch() {
        guard !didLaunch else { return }
        didLaunch = true
        let defaults = UserDefaults.standard
        if !defaults.bool(forKey: installKey) {
            KeychainStore.deleteAll()
            defaults.set(true, forKey: installKey)
        }
        housekeeping()
        Task { await considerReminderPrompt() }
    }

    func becameActive() {
        housekeeping()
        Task { await considerReminderPrompt() }
    }

    func todayString(_ now: Date = Date()) -> String {
        RoutineCalendar.routineDate(instant: now, timeZone: zone)
    }

    func kid(_ id: UUID) -> Kid? { snapshot.kids.first { $0.id == id } }

    func greeting(for kid: Kid) -> String {
        let hour = RoutineCalendar.wallClock(instant: Date(), timeZone: zone).hour
        switch Schedule.currentLabel(hour: hour) {
        case .morning: return Copy.goodMorning(kid.nickname)
        case .afternoon: return Copy.goodAfternoon(kid.nickname)
        case .evening, .custom: return Copy.goodEvening(kid.nickname)
        }
    }

    func stageMark(for kid: Kid) -> Int {
        Limits.cosmeticStage(lifetimeStars: kid.lifetimeStars, plusActive: plusActive)
    }

    func routines(for kidID: UUID, on date: String) -> [Routine] {
        snapshot.routines.filter { routine in
            routine.archivedAt == nil && routine.kidIDs.contains(kidID) && Schedule.isScheduled(routine.days, date)
        }.sorted { lhs, rhs in
            if lhs.timeOfDay.sortIndex == rhs.timeOfDay.sortIndex { return lhs.name < rhs.name }
            return lhs.timeOfDay.sortIndex < rhs.timeOfDay.sortIndex
        }
    }

    func run(kidID: UUID, routineID: UUID, date: String) -> RoutineRun? {
        snapshot.runs.first { $0.kidID == kidID && $0.routineID == routineID && $0.routineDate == date }
    }

    func isCurrent(_ routine: Routine) -> Bool {
        let hour = RoutineCalendar.wallClock(instant: Date(), timeZone: zone).hour
        return routine.timeOfDay == Schedule.currentLabel(hour: hour)
    }

    func weekStats(for kid: Kid) -> WeekStats {
        let today = todayString()
        let start = RoutineCalendar.addDays(today, -6)
        let created = RoutineCalendar.dateString(from: kid.createdAt, timeZone: zone)
        var scheduledDays = 0
        var completedDays = 0
        var finishes: [UUID: Int] = [:]
        for date in RoutineCalendar.datesBetween(start, today) where date >= created {
            let scheduled = routines(for: kid.id, on: date)
            guard !scheduled.isEmpty else { continue }
            scheduledDays += 1
            let runs = snapshot.runs.filter { $0.kidID == kid.id && $0.routineDate == date }
            if runs.contains(where: dayCounts) { completedDays += 1 }
            for run in runs where run.status == .completed || run.status == .approved || run.status == .pendingApproval {
                finishes[run.routineID, default: 0] += 1
            }
        }
        let bestID = finishes.max { $0.value < $1.value }?.key
        let window = householdDate(start) ?? Date().addingTimeInterval(-7 * 86_400)
        let rows = snapshot.ledger.filter { $0.kidID == kid.id && $0.createdAt >= window }
        let wall = RoutineCalendar.wallClock(instant: Date(), timeZone: zone)
        let ready = RoutineCalendar.weekdayIndex(today) == 0 && wall.hour >= 18
        return WeekStats(
            scheduledDays: scheduledDays,
            completedDays: completedDays,
            bestRoutine: snapshot.routines.first { $0.id == bestID }?.name,
            starsEarned: rows.filter { $0.amount > 0 }.reduce(0) { $0 + $1.amount },
            starsSpent: rows.filter { $0.type == .redemptionHold }.reduce(0) { $0 + abs($1.amount) },
            streak: kid.streakCurrent,
            summaryReady: ready
        )
    }

    func signIn(email: String, password: String) -> SignInIssue? {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard trimmed.contains("@"), trimmed.contains("."), password.count >= 10 else { return .invalid }
        if snapshot.email.isEmpty {
            KeychainStore.set(passwordHash(password), account: "password")
            snapshot.email = trimmed
            snapshot.signedIn = true
            snapshot.onboardStep = 2
            commit()
            return nil
        }
        guard snapshot.email == trimmed else { return .differentHousehold }
        guard passwordMatches(password) else { return .password }
        snapshot.signedIn = true
        snapshot.onboardStep = hasPIN ? 8 : 7
        commit()
        return nil
    }

    func confirmAdult() {
        snapshot.adultConfirmed = true
        snapshot.onboardStep = 3
        commit()
    }

    func declineAdult() {
        KeychainStore.deleteAll()
        snapshot = HouseholdSnapshot()
        commit()
    }

    func setHousehold(name: String, timeZoneID: String) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard Limits.householdNameLength.contains(trimmed.count), !Nicknames.containsForbidden(trimmed) else { return false }
        snapshot.householdName = trimmed
        snapshot.timeZoneID = timeZoneID
        if snapshot.onboardStep <= 3 { snapshot.onboardStep = 4 }
        commit()
        return true
    }

    func recordConsent() {
        snapshot.consentAt = Date()
        snapshot.onboardStep = 5
        commit()
    }

    func skipToSignIn() {
        snapshot.onboardStep = max(snapshot.onboardStep, 1)
        commit()
    }

    func setPIN(_ pin: String) -> PinIssue? {
        if let issue = ParentPin.issue(pin) { return issue }
        KeychainStore.set(pinHash(pin), account: "pin")
        snapshot.pinFailures = 0
        snapshot.pinLockedUntil = nil
        snapshot.onboardStep = max(snapshot.onboardStep, 8)
        commit()
        return nil
    }

    func checkPIN(_ pin: String) -> PinCheck {
        let now = Date()
        let state = LockoutState(failures: snapshot.pinFailures, lockedUntil: snapshot.pinLockedUntil)
        if ParentPin.isLocked(state, now: now) { return .locked }
        guard KeychainStore.get("pin") == pinHash(pin) else {
            let next = ParentPin.registerFailure(state, now: now)
            snapshot.pinFailures = next.failures
            snapshot.pinLockedUntil = next.lockedUntil
            commit()
            return ParentPin.isLocked(next, now: now) ? .locked : .mismatch
        }
        snapshot.pinFailures = 0
        snapshot.pinLockedUntil = nil
        commit()
        return .ok
    }

    func resetPIN(password: String, newPIN: String) -> ResetPIN {
        guard passwordMatches(password) else { return .password }
        if let issue = ParentPin.issue(newPIN) { return .pin(issue) }
        KeychainStore.set(pinHash(newPIN), account: "pin")
        snapshot.pinFailures = 0
        snapshot.pinLockedUntil = nil
        snapshot.onboardStep = max(snapshot.onboardStep, 8)
        commit()
        return .ok
    }

    func signOut() {
        KeychainStore.delete("pin")
        snapshot.signedIn = false
        snapshot.kidMode = false
        snapshot.onboardStep = 1
        snapshot.pinFailures = 0
        snapshot.pinLockedUntil = nil
        gate = nil
        commit()
    }

    func deleteAccount(password: String) -> Bool {
        guard passwordMatches(password) else { return false }
        KeychainStore.deleteAll()
        snapshot = HouseholdSnapshot()
        gate = nil
        commit()
        return true
    }

    func loadSample() {
        let kidID = UUID(uuidString: "00000000-0000-4000-8000-000000000001")!
        let routineID = UUID(uuidString: "00000000-0000-4000-8000-000000000002")!
        let rewardID = UUID(uuidString: "00000000-0000-4000-8000-000000000003")!
        let created = Date().addingTimeInterval(-14 * 86_400)
        let template = Catalog.templates()[0]
        let steps = template.activeSteps.enumerated().map { index, step in
            Step(id: UUID(), title: step.title, iconKey: step.iconKey, stars: 1, position: index, timerMinutes: step.iconKey == "toothbrush" ? 2 : nil, archived: false)
        }
        var fresh = HouseholdSnapshot()
        fresh.signedIn = true
        fresh.email = "maya@dayhop.example"
        fresh.onboardStep = 8
        fresh.adultConfirmed = true
        fresh.consentAt = Date()
        fresh.householdName = Copy.sampleHouse
        fresh.timeZoneID = TimeZone.current.identifier
        fresh.plan = .plus
        fresh.plusProduct = "monthly"
        fresh.plusExpiresAt = Date().addingTimeInterval(7 * 86_400)
        fresh.soundOn = true
        fresh.readAloud = true
        fresh.kids = [Kid(id: kidID, nickname: "Maya", ageBand: .five, characterID: "pip", accent: Catalog.accents[0], starsBalance: 4, lifetimeStars: 4, streakCurrent: 1, streakBest: 1, createdAt: created, archivedAt: nil, pauses: [])]
        fresh.routines = [Routine(id: routineID, name: template.name, timeOfDay: .morning, days: 127, startTime: "07:30", requiresApproval: true, bonusStars: 3, version: 1, createdAt: created, archivedAt: nil, kidIDs: [kidID], inactiveKidIDs: [], steps: steps)]
        fresh.rewards = [Reward(id: rewardID, title: "Extra story", iconKey: "book", cost: 8, weeklyLimit: nil, archivedAt: nil)]
        fresh.ledger = [LedgerRow(id: "seed", kidID: kidID, amount: 4, type: .adjustment, note: "Sample start", createdAt: Date())]
        fresh.createdFirstRoutine = true
        snapshot = fresh
        let yesterday = RoutineCalendar.addDays(todayString(), -1)
        var completions: [UUID: StepCompletion] = [:]
        for step in steps { completions[step.id] = StepCompletion(id: UUID(), undoneAt: nil) }
        snapshot.runs = [RoutineRun(id: UUID(), kidID: kidID, routineID: routineID, routineDate: yesterday, status: .approved, version: 1, steps: steps, bonusStars: 3, requiresApproval: true, completions: completions, submittedAt: Date().addingTimeInterval(-86_400), autoApproved: false, credited: true)]
        KeychainStore.set(passwordHash("preview-house"), account: "password")
        KeychainStore.set(pinHash("2580"), account: "pin")
        refreshDerived()
        commit()
    }

    func passwordMatches(_ password: String) -> Bool {
        KeychainStore.get("password") == passwordHash(password)
    }

    func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    func handleNotification(userInfo: [AnyHashable: Any]) {
        let screen = userInfo["screen"] as? String
        let kidID = (userInfo["kidID"] as? String).flatMap(UUID.init)
        let route: ParentRoute
        switch screen {
        case "rewards": route = .rewards
        case "kid": route = kidID.map(ParentRoute.kid) ?? .inbox
        default: route = .inbox
        }
        pendingRoute = route
        if snapshot.kidMode { gate = .openParent(route) }
    }

    func dismissZone() {
        snapshot.dismissedZoneID = TimeZone.current.identifier
        commit()
    }

    func adoptDeviceZone() {
        snapshot.timeZoneID = TimeZone.current.identifier
        snapshot.dismissedZoneID = nil
        housekeeping()
        Task { await rescheduleReminders() }
    }

    func dismissCap() {
        snapshot.balanceCapped = false
        commit()
    }

    func setSound(_ on: Bool) {
        snapshot.soundOn = on
        commit()
    }

    func setReadAloud(_ on: Bool) {
        snapshot.readAloud = on
        commit()
    }

    func setFaceID(_ on: Bool) {
        snapshot.faceIDOn = on
        commit()
    }

    func setQuiet(start: Int, end: Int) {
        snapshot.quietStartMinute = start
        snapshot.quietEndMinute = end
        commit()
        Task { await rescheduleReminders() }
    }

    func setReminder(_ routineID: UUID, on: Bool) {
        if on {
            if !snapshot.reminderRoutineIDs.contains(routineID) { snapshot.reminderRoutineIDs.append(routineID) }
        } else {
            snapshot.reminderRoutineIDs.removeAll { $0 == routineID }
        }
        commit()
        Task { await rescheduleReminders() }
    }

    func declineReminderPrompt() {
        snapshot.notificationAskedAt = Date()
        askForReminders = false
        commit()
    }

    func allowReminders() async {
        snapshot.notificationAskedAt = Date()
        askForReminders = false
        commit()
        let granted = await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { ok, _ in
                continuation.resume(returning: ok)
            }
        }
        if granted { await rescheduleReminders() }
    }

    func considerReminderPrompt() async {
        guard snapshot.signedIn, snapshot.onboardStep >= 8, !snapshot.kidMode else { return }
        guard snapshot.routines.contains(where: { $0.archivedAt == nil }) else { return }
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        if settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional {
            await rescheduleReminders()
            return
        }
        guard settings.authorizationStatus == .notDetermined else { return }
        if let asked = snapshot.notificationAskedAt, Date().timeIntervalSince(asked) < 30 * 24 * 3600 { return }
        askForReminders = true
    }

    func rescheduleReminders() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }
        let pending = await center.pendingNotificationRequests()
        center.removePendingNotificationRequests(withIdentifiers: pending.map(\.identifier).filter { $0.hasPrefix("dayhop.reminder.") })
        let planned = makeReminders(now: Date())
        let capped = Reminders.rollingSchedule(planned.map { ReminderSlot(id: $0.id, at: $0.at) }, now: Date())
        let chosen = Set(capped.map(\.id))
        let device = Calendar.current
        for slot in planned where chosen.contains(slot.id) {
            let content = UNMutableNotificationContent()
            content.title = Copy.appName
            content.body = slot.body
            content.sound = .default
            content.userInfo = ["screen": "kid", "kidID": slot.kidID.uuidString]
            let trigger = UNCalendarNotificationTrigger(dateMatching: device.dateComponents([.year, .month, .day, .hour, .minute], from: slot.at), repeats: false)
            try? await center.add(UNNotificationRequest(identifier: slot.id, content: content, trigger: trigger))
        }
    }

    private func makeReminders(now: Date) -> [PlannedReminder] {
        var slots: [PlannedReminder] = []
        let today = todayString(now)
        for routine in snapshot.routines where routine.archivedAt == nil && snapshot.reminderRoutineIDs.contains(routine.id) {
            guard let start = routine.startTime, let clock = parseClock(start) else { continue }
            let minutes = clock.0 * 60 + clock.1
            if Reminders.withinQuietHours(minutes: minutes, start: snapshot.quietStartMinute, end: snapshot.quietEndMinute) { continue }
            for offset in 0..<7 {
                let date = RoutineCalendar.addDays(today, offset)
                guard Schedule.isScheduled(routine.days, date), let instant = householdDate(date, hour: clock.0, minute: clock.1) else { continue }
                for kidID in routine.kidIDs {
                    guard let kid = self.kid(kidID), kid.archivedAt == nil else { continue }
                    slots.append(PlannedReminder(
                        id: "dayhop.reminder.\(routine.id.uuidString).\(kidID.uuidString).\(date)",
                        at: instant,
                        body: Copy.reminder(kid: kid.nickname, routine: routine.name),
                        kidID: kidID
                    ))
                }
            }
        }
        return slots
    }

    func exportJSON() -> String {
        struct Payload: Encodable {
            var householdName: String
            var timeZone: String
            var email: String
            var plan: PlanID
            var kids: [Kid]
            var routines: [Routine]
            var runs: [RoutineRun]
            var rewards: [Reward]
            var redemptions: [Redemption]
            var ledger: [LedgerRow]
        }
        let payload = Payload(householdName: snapshot.householdName, timeZone: snapshot.timeZoneID, email: snapshot.email, plan: snapshot.plan, kids: snapshot.kids, routines: snapshot.routines, runs: snapshot.runs, rewards: snapshot.rewards, redemptions: snapshot.redemptions, ledger: snapshot.ledger)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(payload) else { return "{}" }
        return String(decoding: data, as: UTF8.self)
    }

    func exportCSV() -> String {
        let formatter = ISO8601DateFormatter()
        var lines = ["id,kid,amount,type,note,created"]
        for row in snapshot.ledger {
            let note = (row.note ?? "").replacingOccurrences(of: "\"", with: "'")
            lines.append("\(row.id),\(row.kidID.uuidString),\(row.amount),\(row.type.rawValue),\"\(note)\",\(formatter.string(from: row.createdAt))")
        }
        return lines.joined(separator: "\n")
    }

    private func dayCounts(_ run: RoutineRun) -> Bool {
        if run.requiresApproval { return run.status == .approved }
        return run.status == .completed || run.status == .approved
    }

    private func passwordHash(_ password: String) -> String { Digest.hex("dayhop-password-v1:" + password) }
    private func pinHash(_ pin: String) -> String { Digest.hex("dayhop-pin-v1:" + pin) }

    private func parseClock(_ value: String) -> (Int, Int)? {
        let bits = value.split(separator: ":")
        guard bits.count == 2, let hour = Int(bits[0]), let minute = Int(bits[1]), (0...23).contains(hour), (0...59).contains(minute) else { return nil }
        return (hour, minute)
    }

    private func householdDate(_ date: String, hour: Int = 0, minute: Int = 0) -> Date? {
        guard let parts = RoutineCalendar.parts(date) else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        return calendar.date(from: DateComponents(year: parts.0, month: parts.1, day: parts.2, hour: hour, minute: minute))
    }

    func commit() {
        snapshot.savedAt = Date()
        let copy = snapshot
        snapshot = copy
        persist(copy)
        let count = snapshot.kidMode ? 0 : pendingRuns.count + pendingRewards.count
        UNUserNotificationCenter.current().setBadgeCount(count, withCompletionHandler: nil)
    }

    func activeRoutineCount(_ kidID: UUID) -> Int {
        snapshot.routines.filter { $0.archivedAt == nil && $0.kidIDs.contains(kidID) }.count
    }

    func housekeeping() {
        guard !inHousekeeping else { return }
        inHousekeeping = true
        defer { inHousekeeping = false }
        let today = todayString()
        for index in snapshot.runs.indices where snapshot.runs[index].routineDate < today && (snapshot.runs[index].status == .inProgress || snapshot.runs[index].status == .reopened) {
            snapshot.runs[index].status = .expired
        }
        let stale = snapshot.runs.enumerated().filter { _, run in
            guard run.status == .pendingApproval else { return false }
            if !plusActive { return true }
            guard let submitted = run.submittedAt else { return false }
            return ApprovalRules.shouldAutoApprove(submittedAt: submitted, now: Date())
        }.map(\.offset)
        for index in stale.reversed() {
            approveNow(index: index, reopen: [], forceAuto: true)
        }
        if snapshot.kidMode, let id = snapshot.activeKidID, activeKids.allSatisfy({ $0.id != id }) {
            snapshot.kidMode = false
            snapshot.activeKidID = nil
        }
        refreshDerived()
        commit()
    }

    @discardableResult
    func credit(kidID: UUID, amount: Int, type: LedgerType, key: String, note: String? = nil) -> Bool {
        if snapshot.ledger.contains(where: { $0.id == key }) { return true }
        guard let index = snapshot.kids.firstIndex(where: { $0.id == kidID }) else { return false }
        let applied = Stars.apply(balance: snapshot.kids[index].starsBalance, amount: amount)
        if applied.rejected { return false }
        if applied.capped { snapshot.balanceCapped = true }
        guard applied.applied != 0 else { return false }
        snapshot.kids[index].starsBalance = applied.balance
        if applied.applied > 0 { snapshot.kids[index].lifetimeStars += applied.applied }
        snapshot.ledger.append(LedgerRow(id: key, kidID: kidID, amount: applied.applied, type: type, note: note, createdAt: Date()))
        return true
    }

    func refreshDerived() {
        let today = todayString()
        for index in snapshot.kids.indices {
            let result = streakResult(for: snapshot.kids[index], today: today)
            snapshot.kids[index].streakCurrent = result.current
            snapshot.kids[index].streakBest = max(snapshot.kids[index].streakBest, result.best)
            let kidID = snapshot.kids[index].id
            for mark in result.milestoneBonuses {
                credit(kidID: kidID, amount: Limits.streakBonusStars, type: .streakBonus, key: "streak:\(kidID.uuidString):\(mark)")
            }
        }
    }

    private func streakResult(for kid: Kid, today: String) -> StreakResult {
        let created = RoutineCalendar.dateString(from: kid.createdAt, timeZone: zone)
        let earliestRun = snapshot.runs.filter { $0.kidID == kid.id }.map(\.routineDate).min()
        let start = min(created, earliestRun ?? created)
        let days = RoutineCalendar.datesBetween(start, today).map { date -> StreakDay in
            let paused = kid.pauses.contains { date >= $0.start && date <= $0.end }
            let scheduled = snapshot.routines.contains { routine in
                guard routine.kidIDs.contains(kid.id) || routine.inactiveKidIDs.contains(kid.id) else { return false }
                let began = RoutineCalendar.dateString(from: routine.createdAt, timeZone: zone)
                if date < began { return false }
                if let archived = routine.archivedAt, date > RoutineCalendar.dateString(from: archived, timeZone: zone) { return false }
                return Schedule.isScheduled(routine.days, date)
            }
            let completed = snapshot.runs.contains { $0.kidID == kid.id && $0.routineDate == date && dayCounts($0) }
            return StreakDay(date: date, scheduled: scheduled, completed: completed, paused: paused)
        }
        return Streaks.compute(days, today: today)
    }

    func approveNow(index: Int, reopen: [UUID], forceAuto: Bool) {
        var run = snapshot.runs[index]
        if !reopen.isEmpty {
            for stepID in reopen {
                guard var completion = run.completions[stepID] else { continue }
                completion.undoneAt = Date()
                run.completions[stepID] = completion
            }
            run.status = .reopened
            snapshot.runs[index] = run
            return
        }
        let auto = forceAuto || (run.submittedAt.map { ApprovalRules.shouldAutoApprove(submittedAt: $0, now: Date()) } ?? false)
        run.status = .approved
        run.autoApproved = auto
        run.credited = true
        snapshot.runs[index] = run
        for step in run.steps {
            guard let completion = run.completions[step.id], completion.undoneAt == nil, step.stars > 0 else { continue }
            credit(kidID: run.kidID, amount: step.stars, type: .step, key: "step:\(completion.id.uuidString)")
        }
        if run.bonusStars > 0 {
            credit(kidID: run.kidID, amount: run.bonusStars, type: .routineBonus, key: "bonus:\(run.id.uuidString)")
        }
        refreshDerived()
    }

    private func persist(_ snapshot: HouseholdSnapshot) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(snapshot) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    private static func load(_ url: URL) -> HouseholdSnapshot? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(HouseholdSnapshot.self, from: data)
    }

    private static func storageURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory
        let folder = base.appendingPathComponent("DayHop", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appendingPathComponent("household.json")
    }
}
