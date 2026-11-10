import Foundation

enum TimeOfDay: String, Codable, CaseIterable, Identifiable {
    case morning
    case afternoon
    case evening
    case custom

    var id: String { rawValue }

    var sortIndex: Int {
        switch self {
        case .morning: return 0
        case .afternoon: return 1
        case .evening: return 2
        case .custom: return 3
        }
    }
}

/// Mon=1, Tue=2, Wed=4, Thu=8, Fri=16, Sat=32, Sun=64.
enum Schedule {
    static let dayBits = [64, 1, 2, 4, 8, 16, 32]
    static let weekdayLabels = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    static let weekdayBits = [1, 2, 4, 8, 16, 32, 64]

    static func dayBit(for date: String) -> Int {
        let index = RoutineCalendar.weekdayIndex(date)
        guard dayBits.indices.contains(index) else { return 0 }
        return dayBits[index]
    }

    static func isScheduled(_ daysMask: Int, _ date: String) -> Bool {
        guard (1...127).contains(daysMask) else { return false }
        return daysMask & dayBit(for: date) != 0
    }

    static func mask(fromWeekdays weekdays: [Int]) -> Int {
        weekdays.reduce(0) { mask, day in
            guard dayBits.indices.contains(day) else { return mask }
            return mask | dayBits[day]
        }
    }

    static func weekStartMonday(_ date: String) -> String {
        let index = RoutineCalendar.weekdayIndex(date)
        let fromMonday = index == 0 ? 6 : index - 1
        return RoutineCalendar.addDays(date, -fromMonday)
    }

    static func currentLabel(hour: Int) -> TimeOfDay {
        if hour < 12 { return .morning }
        if hour < 17 { return .afternoon }
        return .evening
    }
}
