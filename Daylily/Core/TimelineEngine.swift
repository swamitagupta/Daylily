import Foundation

/// Pure math behind the insights timeline: which days to plot, what was
/// recorded on each, and how coinciding points shift so overlapping lines stay
/// readable. No SwiftUI types and no store, so the rules are testable directly.
enum TimelineEngine {

    /// The plotted days and, for each, the submitted entry — `nil` for a day
    /// with no check-in, so line gaps survive into the drawing code.
    struct Series {
        var dates: [Date]
        var records: [DailyEntry?]

        func ratedDayCount(for outcomeID: UUID) -> Int {
            records.compactMap { $0?.outcomeRatings[outcomeID] }.count
        }
    }

    /// `days == nil` means "everything": the range reaches back to the oldest
    /// submitted check-in, or 14 days when nothing has been submitted yet.
    static func series(entries: [String: DailyEntry],
                       days: Int?,
                       now: Date,
                       calendar: Calendar = .current) -> Series {
        let end = calendar.startOfDay(for: now)
        let start: Date
        if let days {
            start = calendar.date(byAdding: .day, value: -(days - 1), to: end) ?? end
        } else if let oldestKey = oldestSubmittedDateKey(in: entries),
                  let oldest = Date.dayKeyFormatter.date(from: oldestKey) {
            start = calendar.startOfDay(for: oldest)
        } else {
            start = calendar.date(byAdding: .day, value: -13, to: end) ?? end
        }
        let count = max(1, (calendar.dateComponents([.day], from: start, to: end).day ?? 0) + 1)
        let dates = (0..<count).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
        let records = dates.map { date -> DailyEntry? in
            guard let entry = entries[date.dayKey], entry.submittedAt != nil else { return nil }
            return entry
        }
        return Series(dates: dates, records: records)
    }

    static func chartHeight(compact: Bool) -> CGFloat { compact ? 86 : 154 }

    /// Chart plus the axis-label row and one 21pt row per activity marker.
    static func canvasHeight(compact: Bool, activityCount: Int) -> CGFloat {
        chartHeight(compact: compact) + 30 + CGFloat(activityCount) * 21
    }

    /// Micro vertical nudges so coinciding lines render as a thin two-tone band
    /// centered on the true rating instead of painting over each other. Only
    /// days where two or more of `outcomeIDs` share a rating get an offset.
    static func overlapOffsets(records: [DailyEntry?],
                               outcomeIDs: [UUID],
                               compact: Bool) -> [[UUID: CGFloat]] {
        let dodge: CGFloat = compact ? 1.8 : 2.6
        var perDay: [[UUID: CGFloat]] = Array(repeating: [:], count: records.count)
        for (index, entry) in records.enumerated() {
            guard let entry else { continue }
            let rated = outcomeIDs.filter { entry.outcomeRatings[$0] != nil }
            for group in Dictionary(grouping: rated, by: { entry.outcomeRatings[$0]! }).values
            where group.count > 1 {
                for (slot, outcomeID) in group.enumerated() {
                    perDay[index][outcomeID] = (CGFloat(slot) - CGFloat(group.count - 1) / 2) * dodge
                }
            }
        }
        return perDay
    }

    /// Vertical offsets for line-end icon labels only, when two lines end on the
    /// same day at the same rating. Lines and dots always stay on the true
    /// rating; the group is shifted as a whole when it would overhang the chart.
    static func endOffsets(records: [DailyEntry?],
                           outcomeIDs: [UUID],
                           compact: Bool) -> [UUID: CGFloat] {
        var last: [UUID: Int] = [:]  // encoded as day * 8 + rating
        for outcomeID in outcomeIDs {
            if let index = records.indices.last(where: { records[$0]?.outcomeRatings[outcomeID] != nil }),
               let rating = records[index]?.outcomeRatings[outcomeID] {
                last[outcomeID] = index * 8 + rating
            }
        }
        let dodge: CGFloat = compact ? 15 : 20
        let chipRadius: CGFloat = compact ? 7 : 9.5
        let top: CGFloat = 9
        let bottom: CGFloat = top + chartHeight(compact: compact)
        var offsets: [UUID: CGFloat] = [:]
        let ended = outcomeIDs.filter { last[$0] != nil }
        let groups = Dictionary(grouping: ended) { last[$0]! }
        for group in groups.values where group.count > 1 {
            let span = CGFloat(group.count - 1)
            let y = bottom - CGFloat(last[group[0]]! % 8 - 1) * chartHeight(compact: compact) / 4
            let half = span / 2 * dodge
            let up = max(0, (top - chipRadius) - (y - half))
            let down = min(0, (bottom + chipRadius) - (y + half))
            let shift = up + down
            for (slot, outcomeID) in group.enumerated() {
                offsets[outcomeID] = (CGFloat(slot) - span / 2) * dodge + shift
            }
        }
        return offsets
    }

    /// `dateKey` is `yyyy-MM-dd`, so the lexicographic minimum is the oldest.
    private static func oldestSubmittedDateKey(in entries: [String: DailyEntry]) -> String? {
        entries.values.filter { $0.submittedAt != nil }.map(\.dateKey).min()
    }
}
