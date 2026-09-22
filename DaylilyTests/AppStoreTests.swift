import XCTest
@testable import Daylily

/// First-run content and how sample data leaves. Sample graphs must arrive with
/// the sample days — and must never take a real graph down with them.
@MainActor
final class AppStoreTests: XCTestCase {
    private func makeDefaults() -> UserDefaults {
        UserDefaults(suiteName: "DaylilyStoreTests.\(UUID().uuidString)")!
    }

    private func makeStore(_ defaults: UserDefaults) -> AppStore {
        AppStore(defaults: defaults, reminders: CheckInReminder(center: FakeNotificationCenter()))
    }

    func testFirstRunSeedsSampleDaysAndSampleGraphs() throws {
        let store = makeStore(makeDefaults())

        XCTAssertEqual(store.demoEntryCount, 21)
        XCTAssertEqual(store.savedGraphs.count, 2)
        XCTAssertTrue(store.savedGraphs.allSatisfy(\.isDemo))
        // A sample graph whose items don't resolve draws nothing.
        let outcomeIDs = Set(store.outcomes.map(\.id))
        let activityIDs = Set(store.activities.map(\.id))
        for graph in store.savedGraphs {
            XCTAssertTrue(graph.outcomeIDs.allSatisfy(outcomeIDs.contains))
            XCTAssertTrue(graph.activityIDs.allSatisfy(activityIDs.contains))
        }
    }

    func testSampleGraphsPlotTheSeededHistory() {
        let store = makeStore(makeDefaults())
        let series = TimelineEngine.series(entries: store.entries, days: 7, now: store.now)

        let ratedDayCounts = store.savedGraphs.map { graph in
            graph.outcomeIDs.map { series.ratedDayCount(for: $0) }.reduce(0, +)
        }
        XCTAssertTrue(ratedDayCounts.allSatisfy { $0 > 0 },
                      "every sample graph must have a line on first launch")
    }

    func testRemovingSampleDataKeepsPersonalCheckInsAndGraphs() throws {
        let store = makeStore(makeDefaults())
        let outcome = try XCTUnwrap(store.activeOutcomes.first)
        let activity = try XCTUnwrap(store.activeActivities.first)
        store.addGraph(outcomeIDs: [outcome.id], activityIDs: [activity.id])
        let personalGraph = try XCTUnwrap(store.savedGraphs.first { !$0.isDemo })

        var draft = DailyEntry(dateKey: store.now.dayKey)
        draft.outcomeRatings[outcome.id] = 5
        store.saveCheckIn(draft)

        store.removeDemoData()

        XCTAssertEqual(store.demoEntryCount, 0)
        XCTAssertEqual(store.savedGraphs.map(\.id), [personalGraph.id])
        XCTAssertTrue(store.isSubmitted(store.now))
    }

    func testRemovedSampleDataStaysGoneAcrossRelaunch() {
        let defaults = makeDefaults()
        makeStore(defaults).removeDemoData()

        let reopened = makeStore(defaults)

        XCTAssertEqual(reopened.demoEntryCount, 0)
        XCTAssertTrue(reopened.savedGraphs.isEmpty)
    }

    func testReorderingGraphsIsKeptAcrossRelaunch() throws {
        let defaults = makeDefaults()
        let store = makeStore(defaults)
        let outcome = try XCTUnwrap(store.activeOutcomes.first)
        let activity = try XCTUnwrap(store.activeActivities.first)
        store.addGraph(outcomeIDs: [outcome.id], activityIDs: [activity.id])

        let before = store.savedGraphs.map(\.id)
        let newest = try XCTUnwrap(before.first)
        XCTAssertEqual(before.count, 3, "two sample graphs plus the new one")

        store.moveGraph(id: newest, by: 1)
        let stepped = store.savedGraphs.map(\.id)
        XCTAssertEqual(stepped[1], newest, "one tap moves one position")

        store.moveGraph(id: newest, by: 1)
        store.moveGraph(id: newest, by: 1)
        XCTAssertEqual(store.savedGraphs.map(\.id).last, newest,
                       "the arrows carry a graph to the end of the list")
        store.moveGraph(id: newest, by: 1)
        XCTAssertEqual(store.savedGraphs.map(\.id).last, newest,
                       "the end of the list is the end: nothing moves off it")

        let end = try XCTUnwrap(store.savedGraphs.last).id
        store.moveGraph(id: end, by: -1)
        XCTAssertEqual(store.savedGraphs.map(\.id)[store.savedGraphs.count - 2], end,
                       "and back up again")

        let after = store.savedGraphs.map(\.id)
        XCTAssertEqual(Set(after), Set(before), "reordering never loses or duplicates a graph")
        XCTAssertEqual(makeStore(defaults).savedGraphs.map(\.id), after,
                       "the user's arrangement must survive a relaunch")
    }
}
