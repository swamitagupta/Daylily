import XCTest
@testable import Daylily

final class InsightsEngineTests: XCTestCase {
    private var calendar = Calendar.current
    private var today = Date.now

    private func dayKey(daysAgo: Int) -> String {
        let date = calendar.date(byAdding: .day, value: -daysAgo, to: today)!
        return date.dayKey
    }

    private func personalEntry(daysAgo: Int) -> (String, DailyEntry) {
        var entry = DailyEntry(dateKey: dayKey(daysAgo: daysAgo))
        entry.submittedAt = calendar.date(byAdding: .day, value: -daysAgo, to: today)
        return (entry.dateKey, entry)
    }

    func testNoEntriesMeansZeroStreak() {
        XCTAssertEqual(InsightsEngine.personalCurrentStreak(entries: [:], now: today, calendar: calendar), 0)
    }

    func testConsecutiveDaysCountFromToday() {
        let entries = Dictionary(uniqueKeysWithValues: [0, 1, 2].map { personalEntry(daysAgo: $0) })
        XCTAssertEqual(InsightsEngine.personalCurrentStreak(entries: entries, now: today, calendar: calendar), 3)
    }

    func testUnrecordedTodayDoesNotBreakYesterdayStreak() {
        let entries = Dictionary(uniqueKeysWithValues: [1, 2, 3].map { personalEntry(daysAgo: $0) })
        XCTAssertEqual(InsightsEngine.personalCurrentStreak(entries: entries, now: today, calendar: calendar), 3)
    }

    func testStreakStopsAtFirstGap() {
        var entries = Dictionary(uniqueKeysWithValues: [0, 1, 3].map { personalEntry(daysAgo: $0) })
        XCTAssertEqual(InsightsEngine.personalCurrentStreak(entries: entries, now: today, calendar: calendar), 2)
        entries[dayKey(daysAgo: 2)] = DailyEntry(dateKey: dayKey(daysAgo: 2)) // unsent draft
        XCTAssertEqual(InsightsEngine.personalCurrentStreak(entries: entries, now: today, calendar: calendar), 2)
    }

    func testNothingTodayOrYesterdayMeansStreakIsZero() {
        let entries = Dictionary(uniqueKeysWithValues: [3, 4].map { personalEntry(daysAgo: $0) })
        XCTAssertEqual(InsightsEngine.personalCurrentStreak(entries: entries, now: today, calendar: calendar), 0)
    }

    func testDemoDaysDoNotCountAsPersonalCheckIns() {
        var demo = DailyEntry(dateKey: dayKey(daysAgo: 0))
        demo.submittedAt = today
        demo.isDemo = true
        var entries = [demo.dateKey: demo]
        XCTAssertEqual(InsightsEngine.personalCurrentStreak(entries: entries, now: today, calendar: calendar), 0)

        // Personal yesterday behind a demo today: streak starts at yesterday.
        let (yesterdayKey, yesterday) = personalEntry(daysAgo: 1)
        entries[yesterdayKey] = yesterday
        XCTAssertEqual(InsightsEngine.personalCurrentStreak(entries: entries, now: today, calendar: calendar), 1)
    }

    func testDraftTodayDoesNotStartStreak() {
        // submittedAt == nil draft today → gate falls through to yesterday, which is absent → 0.
        let entries = [dayKey(daysAgo: 0): DailyEntry(dateKey: dayKey(daysAgo: 0))]
        XCTAssertEqual(InsightsEngine.personalCurrentStreak(entries: entries, now: today, calendar: calendar), 0)
    }
}
