import Foundation

/// Pure analysis over stored entries. Inputs are explicit so streak behavior
/// is testable without the store or a live clock.
enum InsightsEngine {
    /// Consecutive personal check-ins ending today (or yesterday, so a streak
    /// survives an unrecorded morning). Demo days and unsent drafts don't count.
    static func personalCurrentStreak(entries: [String: DailyEntry],
                                      now: Date = .now,
                                      calendar: Calendar = .current) -> Int {
        var count = 0
        var date = now
        if !hasPersonalCheckIn(entries[date.dayKey]),
           let yesterday = calendar.date(byAdding: .day, value: -1, to: date) { date = yesterday }
        while hasPersonalCheckIn(entries[date.dayKey]) {
            count += 1
            guard let prior = calendar.date(byAdding: .day, value: -1, to: date) else { break }
            date = prior
        }
        return count
    }

    static func hasPersonalCheckIn(_ entry: DailyEntry?) -> Bool {
        guard let entry else { return false }
        return entry.submittedAt != nil && !entry.isDemo
    }
}
