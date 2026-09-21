import XCTest
@testable import Daylily

/// Contracts that keep old installs and exported backups loadable, and keep
/// malformed backups from ever entering app state.
final class ModelCodableTests: XCTestCase {
    private let activityID = UUID()
    private let outcomeID = UUID()
    private let graphID = UUID()
    private let dateKey = "2026-09-01"

    // MARK: SavedGraph — legacy `outcomeID` compatibility

    func testLegacyOutcomeIDDecodesToSingletonOutcomeIDs() throws {
        let json = """
        {"id":"\(graphID.uuidString)","outcomeID":"\(outcomeID.uuidString)",\
        "activityIDs":["\(activityID.uuidString)"],"createdAt":0}
        """
        let graph = try JSONDecoder().decode(SavedGraph.self, from: Data(json.utf8))
        XCTAssertEqual(graph.outcomeIDs, [outcomeID])
        XCTAssertEqual(graph.activityIDs, [activityID])
    }

    func testDuplicateOutcomeIDsAreDedupedAndOrderPreserved() throws {
        let extra = UUID()
        let json = """
        {"id":"\(graphID.uuidString)","outcomeIDs":["\(outcomeID.uuidString)","\
        \(outcomeID.uuidString)","\(extra.uuidString)"],\
        "activityIDs":["\(activityID.uuidString)"],"createdAt":0}
        """
        let graph = try JSONDecoder().decode(SavedGraph.self, from: Data(json.utf8))
        XCTAssertEqual(graph.outcomeIDs, [outcomeID, extra])
    }

    func testEncodeWritesBothOutcomeKeysForOlderBuilds() throws {
        let second = UUID()
        let graph = SavedGraph(id: graphID, outcomeIDs: [outcomeID, second],
                               activityIDs: [activityID], createdAt: Date(timeIntervalSince1970: 100))
        let object = try XCTUnwrap(JSONSerialization.jsonObject(
            with: try JSONEncoder().encode(graph)) as? [String: Any])
        XCTAssertEqual(object["outcomeID"] as? String, outcomeID.uuidString)
        XCTAssertEqual(object["outcomeIDs"] as? [String], [outcomeID.uuidString, second.uuidString])
        XCTAssertNotNil(object["createdAt"])
    }

    // MARK: Legacy optional flags normalize to plain Bool

    func testActivityOmittingIsArchivedDecodesAsActive() throws {
        let json = """
        {"id":"\(activityID.uuidString)","name":"Read","symbol":"books.vertical.fill","tintHex":"7258D6"}
        """
        let activity = try JSONDecoder().decode(Activity.self, from: Data(json.utf8))
        XCTAssertFalse(activity.isArchived)
    }

    func testArchivedFlagRoundTripsAsPlainBool() throws {
        var activity = Activity(id: activityID, name: "Read", symbol: "books.vertical.fill", tintHex: "7258D6")
        activity.isArchived = true
        let data = try JSONEncoder().encode(activity)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(object["isArchived"] as? Bool, true, "must be a plain Bool for older builds")
        XCTAssertEqual(try JSONDecoder().decode(Activity.self, from: data), activity)
    }

    func testOutcomeOmittingIsArchivedDecodesAsActive() throws {
        let json = """
        {"id":"\(outcomeID.uuidString)","name":"Calm","symbol":"wind","lowLabel":"Low",\
        "highLabel":"High","tintHex":"4A8DA8"}
        """
        let outcome = try JSONDecoder().decode(Outcome.self, from: Data(json.utf8))
        XCTAssertFalse(outcome.isArchived)
    }

    func testEntryOmittingIsDemoDecodesAsPersonal() throws {
        // `outcomeRatings` is `[UUID: Int]`; JSONEncoder writes dictionaries with
        // non-string keys as an array of single-entry objects, so the empty map is `[]`.
        let json = """
        {"dateKey":"\(dateKey)","completedActivityIDs":[],"outcomeRatings":[],"note":""}
        """
        let entry = try JSONDecoder().decode(DailyEntry.self, from: Data(json.utf8))
        XCTAssertFalse(entry.isDemo)
        XCTAssertNil(entry.submittedAt)
    }

    func testGraphOmittingIsDemoDecodesAsPersonal() throws {
        let json = """
        {"id":"\(graphID.uuidString)","outcomeIDs":["\(outcomeID.uuidString)"],\
        "activityIDs":["\(activityID.uuidString)"],"createdAt":0}
        """
        let graph = try JSONDecoder().decode(SavedGraph.self, from: Data(json.utf8))
        XCTAssertFalse(graph.isDemo, "graphs saved before sample graphs existed are the user's own")
    }

    func testGraphSampleFlagRoundTripsAsPlainBool() throws {
        let graph = SavedGraph(id: graphID, outcomeIDs: [outcomeID],
                               activityIDs: [activityID], isDemo: true)
        let data = try JSONEncoder().encode(graph)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(object["isDemo"] as? Bool, true, "must be a plain Bool for older builds")
        XCTAssertEqual(try JSONDecoder().decode(SavedGraph.self, from: data), graph)
    }

    // MARK: DaylilyBackup.read — validation gate

    private func validBackup() -> DaylilyBackup {
        let activity = Activity(id: activityID, name: "Read", symbol: "books.vertical.fill", tintHex: "7258D6")
        let outcome = Outcome(id: outcomeID, name: "Calm", symbol: "wind",
                              lowLabel: "Low", highLabel: "High", tintHex: "4A8DA8")
        var entry = DailyEntry(dateKey: dateKey)
        entry.completedActivityIDs = [activityID]
        entry.outcomeRatings = [outcomeID: 4]
        entry.submittedAt = Date(timeIntervalSince1970: 1_780_000_000)
        return DaylilyBackup(state: PersistedState(
            activities: [activity], outcomes: [outcome], entries: [dateKey: entry], experiments: [],
            insightSelection: nil, savedGraphs: [SavedGraph(id: graphID, outcomeIDs: [outcomeID],
                                                            activityIDs: [activityID])]))
    }

    private func validData() throws -> Data { try JSONEncoder().encode(validBackup()) }

    private func patched(_ patch: (inout [String: Any]) throws -> Void) throws -> Data {
        var object = try XCTUnwrap(JSONSerialization.jsonObject(
            with: try JSONEncoder().encode(validBackup())) as? [String: Any])
        try patch(&object)
        return try JSONSerialization.data(withJSONObject: object)
    }

    private func patchedState(_ patch: (inout [String: Any]) throws -> Void) throws -> Data {
        try patched { object in
            var state = try XCTUnwrap(object["state"] as? [String: Any])
            try patch(&state)
            object["state"] = state
        }
    }

    private func patchedEntry(_ patch: (inout [String: Any]) throws -> Void) throws -> Data {
        try patchedState { state in
            var entries = try XCTUnwrap(state["entries"] as? [String: Any])
            var entry = try XCTUnwrap(entries[dateKey] as? [String: Any])
            try patch(&entry)
            entries[dateKey] = entry
            state["entries"] = entries
        }
    }

    private func assertRejects(_ data: Data, _ expected: BackupError,
                               file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertThrowsError(try DaylilyBackup.read(data), file: file, line: line) { error in
            XCTAssertEqual(error as? BackupError, expected, file: file, line: line)
        }
    }

    func testWellFormedBackupIsAccepted() throws {
        let backup = try DaylilyBackup.read(validData())
        XCTAssertEqual(backup.checkInCount, 1)
        XCTAssertEqual(backup.state.savedGraphs?.count, 1)
    }

    func testUnparseableFileIsRejected() {
        assertRejects(Data("not even json".utf8), .invalidFile)
    }

    func testWrongFormatStringIsRejected() throws {
        assertRejects(try patched { $0["format"] = "grove-backup" }, .invalidFile)
    }

    func testVersionTwoIsRejected() throws {
        assertRejects(try patched { $0["version"] = 2 }, .unsupportedVersion)
    }

    func testOversizedPayloadIsRejected() {
        assertRejects(Data(count: 20_000_001), .tooLarge)
    }

    func testDuplicateActivityIDsAreRejected() throws {
        assertRejects(try patchedState { state in
            let activities = try XCTUnwrap(state["activities"] as? [[String: Any]])
            state["activities"] = activities + activities
        }, .invalidFile)
    }

    func testEntryReferencingUnknownActivityIsRejected() throws {
        assertRejects(try patchedEntry { entry in
            var ids = try XCTUnwrap(entry["completedActivityIDs"] as? [String])
            ids.append(UUID().uuidString)
            entry["completedActivityIDs"] = ids
        }, .invalidFile)
    }

    func testEntryKeyMismatchingDateKeyIsRejected() throws {
        assertRejects(try patchedState { state in
            var entries = try XCTUnwrap(state["entries"] as? [String: Any])
            let entry = try XCTUnwrap(entries.removeValue(forKey: dateKey))
            entries["2026-09-02"] = entry
            state["entries"] = entries
        }, .invalidFile)
    }

    func testRatingBelowRangeIsRejected() throws {
        assertRejects(try patchedEntry { entry in
            entry["outcomeRatings"] = [["\(outcomeID.uuidString)": 0]]
        }, .invalidFile)
    }

    func testRatingAboveRangeIsRejected() throws {
        assertRejects(try patchedEntry { entry in
            entry["outcomeRatings"] = [["\(outcomeID.uuidString)": 6]]
        }, .invalidFile)
    }

    func testGraphReferencingUnknownOutcomeIsRejected() throws {
        assertRejects(try patchedState { state in
            var graphs = try XCTUnwrap(state["savedGraphs"] as? [[String: Any]])
            graphs[0]["outcomeIDs"] = [UUID().uuidString]
            state["savedGraphs"] = graphs
        }, .invalidFile)
    }

    func testGraphWithEmptyOutcomeIDsIsRejected() throws {
        assertRejects(try patchedState { state in
            var graphs = try XCTUnwrap(state["savedGraphs"] as? [[String: Any]])
            graphs[0]["outcomeIDs"] = [String]()
            state["savedGraphs"] = graphs
        }, .invalidFile)
    }
}
