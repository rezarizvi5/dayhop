import Foundation

struct StreakDay: Equatable {
    var date: String
    var scheduled: Bool
    var completed: Bool
    var paused: Bool
}

struct StreakResult: Equatable {
    var current: Int
    var best: Int
    var milestoneBonuses: [Int]
    var shieldedDates: [String]
}

enum Streaks {
    static let milestones = [3, 7, 14, 30]

    /// R7. Unscheduled days and pauses neither extend nor break a streak.
    /// One shield each Monday-start week forgives a single missed day.
    /// Today stays open until it is finished.
    static func compute(_ days: [StreakDay], today: String) -> StreakResult {
        let ordered = days.sorted { $0.date < $1.date }
        var current = 0
        var best = 0
        var shielded: [String] = []
        var seenWeeks = Set<String>()
        var awarded = Set<Int>()
        var milestoneBonuses: [Int] = []

        for day in ordered {
            if day.date > today { break }
            if !day.scheduled || day.paused { continue }
            let stillOpen = day.date == today && !day.completed
            if day.completed {
                current += 1
                best = max(best, current)
                for mark in milestones where current == mark && !awarded.contains(mark) {
                    awarded.insert(mark)
                    milestoneBonuses.append(mark)
                }
                continue
            }
            if stillOpen { continue }
            let week = Schedule.weekStartMonday(day.date)
            if !seenWeeks.contains(week) {
                seenWeeks.insert(week)
                shielded.append(day.date)
                continue
            }
            current = 0
        }

        return StreakResult(current: current, best: best, milestoneBonuses: milestoneBonuses, shieldedDates: shielded)
    }
}
