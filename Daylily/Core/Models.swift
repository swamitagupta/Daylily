import Foundation

struct Activity: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var symbol: String
    var tintHex: String
    var isArchived = false

    init(id: UUID = UUID(), name: String, symbol: String, tintHex: String, isArchived: Bool = false) {
        self.id = id
        self.name = name
        self.symbol = symbol
        self.tintHex = tintHex
        self.isArchived = isArchived
    }

    // Synthesized decoding rejects payloads that omit a non-optional key even
    // when it has a default value, and synthesis ignores the defaults. Pre-archive
    // installs never wrote `isArchived`; they must keep loading as active items.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        symbol = try container.decode(String.self, forKey: .symbol)
        tintHex = try container.decode(String.self, forKey: .tintHex)
        isArchived = try container.decodeIfPresent(Bool.self, forKey: .isArchived) ?? false
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, symbol, tintHex, isArchived
    }
}

struct Outcome: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var symbol: String
    var lowLabel: String
    var highLabel: String
    var tintHex: String
    var isArchived = false

    init(id: UUID = UUID(), name: String, symbol: String, lowLabel: String, highLabel: String,
         tintHex: String, isArchived: Bool = false) {
        self.id = id
        self.name = name
        self.symbol = symbol
        self.lowLabel = lowLabel
        self.highLabel = highLabel
        self.tintHex = tintHex
        self.isArchived = isArchived
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        symbol = try container.decode(String.self, forKey: .symbol)
        lowLabel = try container.decode(String.self, forKey: .lowLabel)
        highLabel = try container.decode(String.self, forKey: .highLabel)
        tintHex = try container.decode(String.self, forKey: .tintHex)
        isArchived = try container.decodeIfPresent(Bool.self, forKey: .isArchived) ?? false
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, symbol, lowLabel, highLabel, tintHex, isArchived
    }
}

struct DailyEntry: Identifiable, Codable, Hashable {
    var id: String { dateKey }
    var dateKey: String
    var completedActivityIDs: Set<UUID> = []
    var outcomeRatings: [UUID: Int] = [:]
    var note: String = ""
    var submittedAt: Date?
    var isDemo = false

    init(dateKey: String, completedActivityIDs: Set<UUID> = [], outcomeRatings: [UUID: Int] = [:],
         note: String = "", submittedAt: Date? = nil, isDemo: Bool = false) {
        self.dateKey = dateKey
        self.completedActivityIDs = completedActivityIDs
        self.outcomeRatings = outcomeRatings
        self.note = note
        self.submittedAt = submittedAt
        self.isDemo = isDemo
    }

    // Older payloads predate `note`, `submittedAt`, and `isDemo`; all optional
    // keys fall back to their declared defaults.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        dateKey = try container.decode(String.self, forKey: .dateKey)
        completedActivityIDs = try container.decodeIfPresent(Set<UUID>.self, forKey: .completedActivityIDs) ?? []
        outcomeRatings = try container.decodeIfPresent([UUID: Int].self, forKey: .outcomeRatings) ?? [:]
        note = try container.decodeIfPresent(String.self, forKey: .note) ?? ""
        submittedAt = try container.decodeIfPresent(Date.self, forKey: .submittedAt)
        isDemo = try container.decodeIfPresent(Bool.self, forKey: .isDemo) ?? false
    }

    private enum CodingKeys: String, CodingKey {
        case dateKey, completedActivityIDs, outcomeRatings, note, submittedAt, isDemo
    }
}

// The legacy name and fields preserve previously saved experiments as ongoing
// activity/outcome questions. The UI no longer uses their dates or duration.
struct Experiment: Identifiable, Codable, Hashable {
    var id = UUID()
    var activityID: UUID
    var outcomeID: UUID
    var createdAt = Date()
    var durationDays: Int = 14
    var isActive = true
    var endedAt: Date?
}

struct SavedGraph: Identifiable, Codable, Hashable {
    var id = UUID()
    var outcomeIDs: [UUID]
    var activityIDs: Set<UUID>
    var createdAt = Date()
    /// Sample-data graphs are seeded with the demo history and leave with it;
    /// the flag is what keeps "remove sample days" from touching real graphs.
    var isDemo = false

    init(id: UUID = UUID(), outcomeIDs: [UUID], activityIDs: Set<UUID>,
         createdAt: Date = Date(), isDemo: Bool = false) {
        self.id = id
        self.outcomeIDs = outcomeIDs
        self.activityIDs = activityIDs
        self.createdAt = createdAt
        self.isDemo = isDemo
    }

    // `outcomeIDs` preserves the line order. The legacy `outcomeID` key is still
    // read so existing installs load, and still written so older builds can
    // import backups (they just show the first line).
    private enum CodingKeys: String, CodingKey {
        case id, outcomeIDs, outcomeID, activityIDs, createdAt, isDemo
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        if let ids = try container.decodeIfPresent([UUID].self, forKey: .outcomeIDs) {
            var seen = Set<UUID>()
            outcomeIDs = ids.filter { seen.insert($0).inserted }
        } else {
            outcomeIDs = [try container.decode(UUID.self, forKey: .outcomeID)]
        }
        activityIDs = try container.decode(Set<UUID>.self, forKey: .activityIDs)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        isDemo = try container.decodeIfPresent(Bool.self, forKey: .isDemo) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(outcomeIDs, forKey: .outcomeIDs)
        if let primary = outcomeIDs.first { try container.encode(primary, forKey: .outcomeID) }
        try container.encode(activityIDs, forKey: .activityIDs)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(isDemo, forKey: .isDemo)
    }
}

struct PersistedState: Codable {
    var activities: [Activity]
    var outcomes: [Outcome]
    var entries: [String: DailyEntry]
    var experiments: [Experiment]
    var insightSelection: InsightSelection?
    var savedGraphs: [SavedGraph]?
    /// Optional so payloads written before reminders existed (and their
    /// backups) keep decoding; `nil` means reminders were never turned on.
    var remindersEnabled: Bool? = nil
    /// Minutes after midnight; optional for the same backward-compatibility
    /// reason, with 9:30 PM as the fallback.
    var reminderMinutes: Int? = nil
}

struct DaylilyBackup: Codable {
    let format: String
    let version: Int
    let exportedAt: Date
    let state: PersistedState

    init(state: PersistedState) {
        self.format = "daylily-backup"
        self.version = 1
        self.exportedAt = .now
        self.state = state
    }

    static func read(_ data: Data) throws -> DaylilyBackup {
        guard data.count <= 20_000_000 else { throw BackupError.tooLarge }
        let backup: DaylilyBackup
        do { backup = try JSONDecoder().decode(DaylilyBackup.self, from: data) }
        catch { throw BackupError.invalidFile }
        guard backup.format == "daylily-backup" else { throw BackupError.invalidFile }
        guard backup.version == 1 else { throw BackupError.unsupportedVersion }
        let activityIDs = Set(backup.state.activities.map(\.id))
        let outcomeIDs = Set(backup.state.outcomes.map(\.id))
        let graphs = backup.state.savedGraphs ?? []
        guard activityIDs.count == backup.state.activities.count,
              outcomeIDs.count == backup.state.outcomes.count,
              Set(graphs.map(\.id)).count == graphs.count,
              backup.state.entries.allSatisfy({ key, entry in
                  key == entry.dateKey &&
                  entry.completedActivityIDs.isSubset(of: activityIDs) &&
                  entry.outcomeRatings.keys.allSatisfy { outcomeIDs.contains($0) && (1...5).contains(entry.outcomeRatings[$0] ?? 0) }
              }),
              graphs.allSatisfy({ !$0.outcomeIDs.isEmpty && Set($0.outcomeIDs).isSubset(of: outcomeIDs) && $0.activityIDs.isSubset(of: activityIDs) })
        else { throw BackupError.invalidFile }
        return backup
    }

    var checkInCount: Int { state.entries.values.filter { $0.submittedAt != nil }.count }
}

enum BackupError: LocalizedError {
    case invalidFile, unsupportedVersion, tooLarge, noData

    var errorDescription: String? {
        switch self {
        case .invalidFile: String(localized: "This is not a valid Daylily backup. Nothing was changed.")
        case .unsupportedVersion: String(localized: "This backup was made by a newer version of Daylily. Nothing was changed.")
        case .tooLarge: String(localized: "This backup is too large to import. Nothing was changed.")
        case .noData: String(localized: "There is no readable Daylily data to export.")
        }
    }
}

struct InsightSelection: Codable, Hashable {
    var outcomeID: UUID?
    var activityIDs: Set<UUID>
}

extension Date {
    static let dayKeyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    var dayKey: String { Self.dayKeyFormatter.string(from: self) }
}
