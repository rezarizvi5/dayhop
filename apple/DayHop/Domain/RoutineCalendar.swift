import Foundation

struct WallClock: Equatable {
    var year: Int
    var month: Int
    var day: Int
    var hour: Int
    var minute: Int
    var second: Int
}

/// R1. The routine date is the household wall clock minus 3 hours.
enum RoutineCalendar {
    static func wallClock(instant: Date, timeZone: TimeZone) -> WallClock {
        var calendar = gregorian
        calendar.timeZone = timeZone
        let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: instant)
        return WallClock(
            year: parts.year ?? 1970,
            month: parts.month ?? 1,
            day: parts.day ?? 1,
            hour: parts.hour ?? 0,
            minute: parts.minute ?? 0,
            second: parts.second ?? 0
        )
    }

    /// Civil datetime minus 3 hours, as yyyy-MM-dd. This is not a timezone conversion.
    static func routineDate(from wall: WallClock) -> String {
        var parts = DateComponents()
        parts.calendar = utc
        parts.timeZone = TimeZone(secondsFromGMT: 0)
        parts.year = wall.year
        parts.month = wall.month
        parts.day = wall.day
        parts.hour = wall.hour
        parts.minute = wall.minute
        parts.second = wall.second
        let date = utc.date(from: parts) ?? Date(timeIntervalSince1970: 0)
        let shifted = date.addingTimeInterval(-3 * 60 * 60)
        let out = utc.dateComponents([.year, .month, .day], from: shifted)
        return format(year: out.year ?? 1970, month: out.month ?? 1, day: out.day ?? 1)
    }

    static func routineDate(instant: Date, timeZone: TimeZone) -> String {
        routineDate(from: wallClock(instant: instant, timeZone: timeZone))
    }

    static func format(year: Int, month: Int, day: Int) -> String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }

    static func parts(_ date: String) -> (Int, Int, Int)? {
        let bits = date.split(separator: "-")
        guard bits.count == 3, let year = Int(bits[0]), let month = Int(bits[1]), let day = Int(bits[2]) else { return nil }
        return (year, month, day)
    }

    static func addDays(_ date: String, _ days: Int) -> String {
        guard let (year, month, day) = parts(date),
              let base = utc.date(from: DateComponents(year: year, month: month, day: day)),
              let next = utc.date(byAdding: .day, value: days, to: base) else { return date }
        let out = utc.dateComponents([.year, .month, .day], from: next)
        return format(year: out.year ?? year, month: out.month ?? month, day: out.day ?? day)
    }

    static func dateDiffDays(_ a: String, _ b: String) -> Int {
        guard let (ay, am, ad) = parts(a), let (by, bm, bd) = parts(b),
              let left = utc.date(from: DateComponents(year: ay, month: am, day: ad)),
              let right = utc.date(from: DateComponents(year: by, month: bm, day: bd)) else { return 0 }
        return utc.dateComponents([.day], from: right, to: left).day ?? 0
    }

    /// EC5.8. A routine date more than one day from the household date is rejected.
    static func routineDateAllowed(clientDate: String, serverNow: Date, timeZone: TimeZone) -> Bool {
        abs(dateDiffDays(clientDate, routineDate(instant: serverNow, timeZone: timeZone))) <= 1
    }

    /// Sunday is 0, matching the schedule bitmask.
    static func weekdayIndex(_ date: String) -> Int {
        guard let (year, month, day) = parts(date),
              let value = utc.date(from: DateComponents(year: year, month: month, day: day)) else { return 0 }
        return utc.component(.weekday, from: value) - 1
    }

    static func datesBetween(_ start: String, _ end: String) -> [String] {
        guard start <= end else { return [] }
        var cursor = start
        var dates: [String] = []
        var guardrail = 0
        while cursor <= end && guardrail < 4000 {
            dates.append(cursor)
            cursor = addDays(cursor, 1)
            guardrail += 1
        }
        return dates
    }

    static func dateString(from instant: Date, timeZone: TimeZone) -> String {
        var calendar = gregorian
        calendar.timeZone = timeZone
        let parts = calendar.dateComponents([.year, .month, .day], from: instant)
        return format(year: parts.year ?? 1970, month: parts.month ?? 1, day: parts.day ?? 1)
    }

    private static var gregorian: Calendar { Calendar(identifier: .gregorian) }

    private static var utc: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        return calendar
    }
}
