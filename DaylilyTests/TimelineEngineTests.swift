import XCTest
@testable import Daylily

final class TimelineEngineTests: XCTestCase {
    private var calendar = Calendar.current
    private var today = Date.now

    private func date(daysAgo: Int) -> Date {
        calendar.date(byAdding: .day, value: -daysAgo, to: today)!
    }

    private func dayKey(daysAgo: Int) -> String {
        date(daysAgo: daysAgo).dayKey
    }

    /// Mirrors how the engine derives its window: from `startOfDay(now)` back.
    private func startOfDay(daysBeforeToday days: Int) -> Date {
        let end = calendar.startOfDay(for: today)
        return calendar.date(byAdding: .day, value: -days, to: end)!
    }

    private func submitted(daysAgo: Int, ratings: [UUID: Int] = [:]) -> (String, DailyEntry) {
        var entry = DailyEntry(dateKey: dayKey(daysAgo: daysAgo), outcomeRatings: ratings)
        entry.submittedAt = date(daysAgo: daysAgo)
        return (entry.dateKey, entry)
    }

    private func draft(daysAgo: Int) -> (String, DailyEntry) {
        let entry = DailyEntry(dateKey: dayKey(daysAgo: daysAgo))
        return (entry.dateKey, entry)
    }

    private func series(_ entries: [String: DailyEntry], days: Int?) -> TimelineEngine.Series {
        TimelineEngine.series(entries: entries, days: days, now: today, calendar: calendar)
    }

    // MARK: - Range

    func testBoundedRangeEndsToday() {
        let result = series([:], days: 7)
        XCTAssertEqual(result.dates.count, 7)
        XCTAssertEqual(result.dates.first, startOfDay(daysBeforeToday: 6))
        XCTAssertEqual(result.dates.last, calendar.startOfDay(for: today))
    }

    func testOpenRangeAnchorsAtOldestSubmittedDay() {
        var entries = Dictionary(uniqueKeysWithValues: [submitted(daysAgo: 20)])
        entries.merge(Dictionary(uniqueKeysWithValues: [submitted(daysAgo: 0)])) { current, _ in current }

        let result = series(entries, days: nil)
        XCTAssertEqual(result.dates.count, 21)
        XCTAssertEqual(result.dates.first, calendar.startOfDay(for: date(daysAgo: 20)))
        XCTAssertEqual(result.dates.last, calendar.startOfDay(for: today))
    }

    func testOpenRangeFallsBackToFourteenDaysWithoutSubmittedHistory() {
        // Drafts are not history: an unsubmitted day must not stretch the range.
        let drafts = Dictionary(uniqueKeysWithValues: [draft(daysAgo: 30), draft(daysAgo: 12)])
        XCTAssertEqual(series(drafts, days: nil).dates.count, 14)
        XCTAssertEqual(series([:], days: nil).dates.count, 14)
    }

    // MARK: - Records

    func testRecordsMarkOnlySubmittedDays() {
        let entries = Dictionary(uniqueKeysWithValues: [submitted(daysAgo: 3), draft(daysAgo: 0)])

        let result = series(entries, days: 5)
        XCTAssertEqual(result.records.count, 5)
        XCTAssertNotNil(result.records[1])
        XCTAssertNil(result.records[0])
        XCTAssertNil(result.records[4], "an unsubmitted draft is not a recorded day")
    }

    func testRatedDayCountCountsOnlyDaysRatedForThatOutcome() {
        let calm = UUID(), energy = UUID(), unrated = UUID()
        let entries = Dictionary(uniqueKeysWithValues: [
            submitted(daysAgo: 5, ratings: [calm: 4, energy: 2]),
            submitted(daysAgo: 4, ratings: [calm: 5]),
            submitted(daysAgo: 2, ratings: [energy: 3]),
            submitted(daysAgo: 1),
        ])

        let result = series(entries, days: 7)
        XCTAssertEqual(result.ratedDayCount(for: calm), 2)
        XCTAssertEqual(result.ratedDayCount(for: energy), 2)
        XCTAssertEqual(result.ratedDayCount(for: unrated), 0)
    }

    // MARK: - Line dodging

    func testCoincidingRatingsGetSymmetricOffsetsWhileUniqueOnesStayAligned() {
        let first = UUID(), second = UUID(), unique = UUID()
        let entries = Dictionary(uniqueKeysWithValues: [
            submitted(daysAgo: 0, ratings: [first: 3, second: 3, unique: 5]),
        ])

        let offsets = TimelineEngine.overlapOffsets(
            records: series(entries, days: 3).records,
            outcomeIDs: [first, second, unique],
            compact: false
        )

        let lastDay = offsets[2]
        XCTAssertEqual(lastDay[first] ?? 0, -1.3, accuracy: 0.0001)
        XCTAssertEqual(lastDay[second] ?? 0, 1.3, accuracy: 0.0001)
        XCTAssertNil(lastDay[unique], "a day with a single rating for an outcome needs no dodge")
        XCTAssertTrue(offsets[0].isEmpty, "an unrecorded day has nothing to dodge")
    }

    func testEndChipsAreClampedToTheChartInsteadOfRunningOff() {
        let first = UUID(), second = UUID(), third = UUID()
        let entries = Dictionary(uniqueKeysWithValues: [
            submitted(daysAgo: 0, ratings: [first: 1, second: 1, third: 1]),
        ])

        let offsets = TimelineEngine.endOffsets(
            records: series(entries, days: 1).records,
            outcomeIDs: [first, second, third],
            compact: false
        )

        let chartHeight = TimelineEngine.chartHeight(compact: false)
        let top: CGFloat = 9
        let chipRadius: CGFloat = 9.5
        let bottom = top + chartHeight
        let baseline = bottom  // rating 1 sits on the bottom gridline

        XCTAssertEqual(offsets.count, 3)
        let centres = offsets.values.map { baseline + $0 }.sorted()
        XCTAssertEqual(Set(centres).count, 3, "three chips ending together must stay distinct")

        // Spacing keeps the chips from painting over each other.
        for (lower, upper) in zip(centres, centres.dropFirst()) {
            XCTAssertGreaterThanOrEqual(upper - lower, chipRadius * 2)
        }
        // The group is nudged back toward the chart; unclamped it would run
        // 20pt past the baseline instead.
        XCTAssertLessThan(centres.max()!, baseline + 20)
        for centre in centres {
            XCTAssertGreaterThanOrEqual(centre, top - chipRadius - 0.0001)
            XCTAssertLessThanOrEqual(centre, bottom + chipRadius + 0.0001)
        }
    }

    func testEndChipsAreLeftAlignedWhenLinesDoNotCollide() {
        let first = UUID(), second = UUID()
        let entries = Dictionary(uniqueKeysWithValues: [
            submitted(daysAgo: 0, ratings: [first: 5, second: 3]),
        ])

        let offsets = TimelineEngine.endOffsets(
            records: series(entries, days: 1).records,
            outcomeIDs: [first, second],
            compact: false
        )
        XCTAssertTrue(offsets.isEmpty)
    }

    func testEndChipsConsiderOnlyEachLinesLastRatedDay() {
        let first = UUID(), second = UUID()
        let entries = Dictionary(uniqueKeysWithValues: [
            submitted(daysAgo: 2, ratings: [first: 4, second: 4]),  // collide, but not at the end
            submitted(daysAgo: 0, ratings: [first: 2, second: 5]),  // different end points
        ])

        let offsets = TimelineEngine.endOffsets(
            records: series(entries, days: 3).records,
            outcomeIDs: [first, second],
            compact: false
        )
        XCTAssertTrue(offsets.isEmpty)
    }
}
