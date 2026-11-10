import Foundation

struct ReminderSlot: Equatable {
    var id: String
    var at: Date
}

enum Reminders {
    /// FR9.3. The next 7 days, at most 60, nearest first. iOS allows 64 pending local notifications.
    static func rollingSchedule(_ items: [ReminderSlot], now: Date, horizonDays: Int = 7, cap: Int = 60) -> [ReminderSlot] {
        let horizon = now.addingTimeInterval(TimeInterval(horizonDays * 24 * 60 * 60))
        return items
            .filter { $0.at >= now && $0.at <= horizon }
            .sorted { $0.at < $1.at }
            .prefix(cap)
            .map { $0 }
    }

    static func withinQuietHours(minutes: Int, start: Int = 21 * 60, end: Int = 7 * 60) -> Bool {
        if start == end { return false }
        if start < end { return minutes >= start && minutes < end }
        return minutes >= start || minutes < end
    }
}
