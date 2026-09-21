import XCTest
@testable import Daylily

final class MigrationsTests: XCTestCase {
    // MARK: Emoji → SF Symbol

    func testKnownActivityEmojiMapsToAdoptedSymbol() {
        let legacy = Activity(name: "Office", symbol: "🏢", tintHex: "7258D6")
        let migrated = Migrations.migratingEmojiSymbols(in: [legacy])
        XCTAssertEqual(migrated.count, 1)
        XCTAssertEqual(migrated[0].symbol, "building.2.fill")
        XCTAssertEqual(migrated[0].id, legacy.id, "ids must survive: history is keyed by them")
        XCTAssertEqual(migrated[0].name, "Office")
        XCTAssertEqual(migrated[0].tintHex, "7258D6")
    }

    func testUnknownEmojiFallsBackToSparkles() {
        let exotic = Activity(name: "Dino walk", symbol: "🦖", tintHex: "4C9A72")
        let migrated = Migrations.migratingEmojiSymbols(in: [exotic])
        XCTAssertEqual(migrated[0].symbol, "sparkles")
    }

    func testSFSymbolStringsAreUntouched() {
        let modern = Activity(name: "Tennis", symbol: "tennis.racket", tintHex: "4C9A72")
        let migrated = Migrations.migratingEmojiSymbols(in: [modern])
        XCTAssertEqual(migrated, [modern])
    }

    func testKnownOutcomeEmojiMapsToAdoptedSymbol() {
        let legacy = Outcome(name: "Happy", symbol: "😊", lowLabel: "Low", highLabel: "High", tintHex: "E6A13A")
        let migrated = Migrations.migratingEmojiSymbols(in: [legacy])
        XCTAssertEqual(migrated[0].symbol, "face.smiling.fill")
        XCTAssertEqual(migrated[0].id, legacy.id)
    }

    // MARK: insight selection / experiments → saved graphs

    func testMigratedGraphsCarryLegacyInsightSelection() {
        let outcome = UUID()
        let activities: Set<UUID> = [UUID(), UUID()]
        let state = PersistedState(activities: [], outcomes: [], entries: [:], experiments: [],
                                   insightSelection: InsightSelection(outcomeID: outcome, activityIDs: activities),
                                   savedGraphs: nil)
        let graphs = Migrations.migratedGraphs(from: state)
        XCTAssertEqual(graphs.count, 1)
        XCTAssertEqual(graphs[0].outcomeIDs, [outcome])
        XCTAssertEqual(graphs[0].activityIDs, activities)
    }

    func testMigratedGraphsSkipEmptyInsightSelection() {
        let state = PersistedState(activities: [], outcomes: [], entries: [:], experiments: [],
                                   insightSelection: InsightSelection(outcomeID: nil, activityIDs: []),
                                   savedGraphs: nil)
        XCTAssertTrue(Migrations.migratedGraphs(from: state).isEmpty)
    }

    func testMigratedGraphsConvertAndDeduplicateExperiments() {
        let outcomeID = UUID()
        let activityID = UUID()
        let experiment = Experiment(activityID: activityID, outcomeID: outcomeID)
        let state = PersistedState(activities: [], outcomes: [], entries: [:],
                                   experiments: [experiment, experiment],
                                   insightSelection: nil, savedGraphs: nil)
        let graphs = Migrations.migratedGraphs(from: state)
        XCTAssertEqual(graphs.count, 1)
        XCTAssertEqual(graphs[0].outcomeIDs, [outcomeID])
        XCTAssertEqual(graphs[0].activityIDs, [activityID])
    }

    func testMigratedGraphsCombineSelectionAndExperimentsWithoutDupes() {
        let outcomeID = UUID()
        let activityID = UUID()
        let state = PersistedState(activities: [], outcomes: [], entries: [:],
                                   experiments: [Experiment(activityID: activityID, outcomeID: outcomeID)],
                                   insightSelection: InsightSelection(outcomeID: outcomeID,
                                                                      activityIDs: [activityID]),
                                   savedGraphs: nil)
        XCTAssertEqual(Migrations.migratedGraphs(from: state).count, 1)
    }

    func testSeedStarterLibraryMatchesShippedDefaults() {
        let starter = Migrations.seedStarterLibrary()
        XCTAssertEqual(starter.activities.map(\.name), ["Office", "Tennis", "Morning walk"])
        XCTAssertEqual(starter.outcomes.map(\.name), ["Happiness", "Calm", "Energy"])
        XCTAssertFalse(Migrations.migratingEmojiSymbols(in: starter.activities)
            .contains { $0.symbol.isEmojiChoice })
    }

    // MARK: Demo seeding

    func testDemoEntriesSeedTwentyOneDaysWithRatings() {
        let starter = Migrations.seedStarterLibrary()
        let seeded = Migrations.demoEntries(activities: starter.activities, outcomes: starter.outcomes,
                                            existing: [:])
        XCTAssertEqual(seeded.count, 21)
        XCTAssertTrue(seeded.values.allSatisfy { $0.isDemo && $0.submittedAt != nil })
        XCTAssertTrue(seeded.values.allSatisfy {
            $0.outcomeRatings.count == 3 && $0.outcomeRatings.values.allSatisfy { (1...5).contains($0) }
        })
        XCTAssertTrue(seeded.values.contains { !$0.completedActivityIDs.isEmpty },
                      "demo history must show some recorded activity")
        XCTAssertNil(seeded[Date.now.dayKey], "demo days are strictly in the past")
    }

    func testDemoSeedingIsIdempotentAndAdditive() {
        let starter = Migrations.seedStarterLibrary()
        let seeded = Migrations.demoEntries(activities: starter.activities, outcomes: starter.outcomes,
                                            existing: [:])

        // Already demo'd → nothing new.
        XCTAssertTrue(Migrations.demoEntries(activities: starter.activities, outcomes: starter.outcomes,
                                             existing: seeded).isEmpty)

        // A real personal check-in on one day must not be replaced.
        let real = DailyEntry(dateKey: seeded.keys.sorted().first!)
        let kept = Migrations.demoEntries(activities: starter.activities, outcomes: starter.outcomes,
                                          existing: [real.dateKey: real])
        XCTAssertFalse(kept.keys.contains(real.dateKey))
        XCTAssertEqual(kept.count, 20)
    }

    func testDemoSeedingRequiresStarterLibrary() {
        XCTAssertTrue(Migrations.demoEntries(activities: [], outcomes: [], existing: [:]).isEmpty)
    }

    // MARK: Sample graphs

    func testDemoGraphsPairStarterOutcomesWithStarterActivities() {
        let starter = Migrations.seedStarterLibrary()
        let graphs = Migrations.demoGraphs(activities: starter.activities, outcomes: starter.outcomes)
        let outcomeIDs = Set(starter.outcomes.map(\.id))
        let activityIDs = Set(starter.activities.map(\.id))

        XCTAssertEqual(graphs.count, 2)
        XCTAssertTrue(graphs.allSatisfy(\.isDemo))
        XCTAssertTrue(graphs.allSatisfy { $0.outcomeIDs.count == 1 })
        XCTAssertTrue(graphs.allSatisfy { graph in
            graph.outcomeIDs.allSatisfy(outcomeIDs.contains)
                && graph.activityIDs.allSatisfy(activityIDs.contains)
        })
        XCTAssertEqual(Set(graphs.map(\.id)).count, 2, "each sample graph needs its own identity")
    }

    func testDemoGraphsFollowTheSeededHistory() {
        // A sample graph is only worth seeding if the seeded days give it a line:
        // its outcome must be rated, on days its activity also happened.
        let starter = Migrations.seedStarterLibrary()
        let graphs = Migrations.demoGraphs(activities: starter.activities, outcomes: starter.outcomes)
        let entries = Migrations.demoEntries(activities: starter.activities, outcomes: starter.outcomes,
                                             existing: [:])

        for graph in graphs {
            let outcomeID = graph.outcomeIDs[0]
            let rated = entries.values.filter { $0.outcomeRatings[outcomeID] != nil }
            XCTAssertFalse(rated.isEmpty)
            XCTAssertTrue(rated.contains { !$0.completedActivityIDs.isDisjoint(with: graph.activityIDs) },
                          "the marked activity must actually appear on rated days")
        }
    }

    func testDemoGraphsSkipWhenStarterItemsAreMissing() {
        let starter = Migrations.seedStarterLibrary()
        XCTAssertTrue(Migrations.demoGraphs(activities: [], outcomes: []).isEmpty)
        XCTAssertTrue(Migrations.demoGraphs(activities: starter.activities, outcomes: []).isEmpty)
    }
}
