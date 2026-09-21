import XCTest
@testable import Daylily

/// One fresh `UserDefaults` suite per test — no cross-test contamination, and
/// production `.standard` is never touched.
final class StatePersistenceTests: XCTestCase {
    private func makeDefaults() -> UserDefaults {
        UserDefaults(suiteName: "DaylilyTests.\(UUID().uuidString)")!
    }

    private func makeState(activityName: String = "Read", graphCount: Int = 0) -> PersistedState {
        let activity = Activity(name: activityName, symbol: "books.vertical.fill", tintHex: "7258D6")
        let outcome = Outcome(name: "Calm", symbol: "wind", lowLabel: "Low", highLabel: "High", tintHex: "4A8DA8")
        let graphs = (0..<graphCount).map { _ in
            SavedGraph(outcomeIDs: [outcome.id], activityIDs: [activity.id])
        }
        return PersistedState(activities: [activity], outcomes: [outcome], entries: [:],
                              experiments: [], insightSelection: nil, savedGraphs: graphs)
    }

    func testFreshStoreLoadReportsNothingStored() {
        let loaded = StatePersistence(defaults: makeDefaults()).load()
        XCTAssertNil(loaded.state)
        XCTAssertFalse(loaded.requiresRecovery)
        XCTAssertFalse(loaded.recoveredFromLocalBackup)
    }

    func testFirstSaveSeedsBothPrimaryAndFallback() {
        let defaults = makeDefaults()
        let persistence = StatePersistence(defaults: defaults)
        persistence.save(makeState())
        XCTAssertNotNil(persistence.debugData(forKey: StatePersistence.Key.storage))
        XCTAssertNotNil(persistence.debugData(forKey: StatePersistence.Key.fallback))
    }

    func testSecondSavePromotesPreviousPrimaryToFallback() {
        let persistence = StatePersistence(defaults: makeDefaults())
        persistence.save(makeState(activityName: "First"))
        persistence.save(makeState(activityName: "Second"))
        let primary = try! JSONDecoder().decode(PersistedState.self,
                                                from: persistence.debugData(forKey: StatePersistence.Key.storage)!)
        let fallback = try! JSONDecoder().decode(PersistedState.self,
                                                 from: persistence.debugData(forKey: StatePersistence.Key.fallback)!)
        XCTAssertEqual(primary.activities.map(\.name), ["Second"])
        XCTAssertEqual(fallback.activities.map(\.name), ["First"])
    }

    func testUndecodablePrimaryIsNeverPromotedToFallback() {
        let defaults = makeDefaults()
        let persistence = StatePersistence(defaults: defaults)
        persistence.debugSetRaw(Data("garbage".utf8), forKey: StatePersistence.Key.storage)
        persistence.save(makeState(activityName: "Good"))
        let fallback = try! JSONDecoder().decode(PersistedState.self,
                                                 from: persistence.debugData(forKey: StatePersistence.Key.fallback)!)
        XCTAssertEqual(fallback.activities.map(\.name), ["Good"])
    }

    func testLoadRecoversFromFallbackAndQuarantinesBrokenPrimary() {
        let defaults = makeDefaults()
        let persistence = StatePersistence(defaults: defaults)
        let saved = makeState(activityName: "Saved")
        persistence.save(saved)
        persistence.debugSetRaw(Data("garbage".utf8), forKey: StatePersistence.Key.storage)

        let loaded = persistence.load()
        XCTAssertTrue(loaded.recoveredFromLocalBackup)
        XCTAssertFalse(loaded.requiresRecovery)
        XCTAssertEqual(loaded.state?.activities.map(\.name), ["Saved"])
        // Primary was rewritten with the fallback…
        XCTAssertEqual(loaded.state?.outcomes.count,
                       try! JSONDecoder().decode(PersistedState.self,
                       from: persistence.debugData(forKey: StatePersistence.Key.storage)!).outcomes.count)
        // …and the broken bytes preserved, not destroyed.
        XCTAssertEqual(persistence.debugData(forKey: StatePersistence.Key.unreadable), Data("garbage".utf8))
    }

    func testLoadWithBothCopiesUndecodableRequestsRecoveryAndTouchesNothing() {
        let defaults = makeDefaults()
        let persistence = StatePersistence(defaults: defaults)
        persistence.debugSetRaw(Data("bad-primary".utf8), forKey: StatePersistence.Key.storage)
        persistence.debugSetRaw(Data("bad-fallback".utf8), forKey: StatePersistence.Key.fallback)

        let loaded = persistence.load()
        XCTAssertNil(loaded.state)
        XCTAssertTrue(loaded.requiresRecovery)
        XCTAssertFalse(loaded.recoveredFromLocalBackup)
        XCTAssertEqual(persistence.debugData(forKey: StatePersistence.Key.storage), Data("bad-primary".utf8))
        XCTAssertNil(persistence.debugData(forKey: StatePersistence.Key.unreadable))
    }

    func testSavePermanentOverwritesFallbackAndClearsQuarantine() {
        let defaults = makeDefaults()
        let persistence = StatePersistence(defaults: defaults)
        persistence.save(makeState(activityName: "Old"))
        persistence.debugSetRaw(Data("garbage".utf8), forKey: StatePersistence.Key.unreadable)
        persistence.debugSetRaw(Data("garbage2".utf8), forKey: StatePersistence.Key.unreadableFallback)

        let trimmed = makeState(activityName: "Trimmed")
        persistence.savePermanent(trimmed)
        let primary = persistence.debugData(forKey: StatePersistence.Key.storage)
        let fallback = persistence.debugData(forKey: StatePersistence.Key.fallback)
        XCTAssertEqual(primary, fallback, "both slots must hold the trimmed state")
        let decoded = try! JSONDecoder().decode(PersistedState.self, from: primary!)
        XCTAssertEqual(decoded.activities.map(\.name), ["Trimmed"])
        XCTAssertNil(persistence.debugData(forKey: StatePersistence.Key.unreadable))
        XCTAssertNil(persistence.debugData(forKey: StatePersistence.Key.unreadableFallback))
    }

    func testClearStoredStatesLeavesFreshInstallSemantics() {
        let defaults = makeDefaults()
        let persistence = StatePersistence(defaults: defaults)
        persistence.save(makeState())
        persistence.clearStoredStates()
        let loaded = persistence.load()
        XCTAssertNil(loaded.state)
        XCTAssertFalse(loaded.requiresRecovery)
    }

    func testDemoDismissedFlagRoundTrips() {
        let persistence = StatePersistence(defaults: makeDefaults())
        XCTAssertFalse(persistence.isDemoDismissed)
        persistence.markDemoDismissed()
        XCTAssertTrue(persistence.isDemoDismissed)
    }
}
