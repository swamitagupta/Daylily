import Foundation

/// One-way upgrades for state written by older Daylily builds, plus starter
/// and demo content. Everything here is pure — state in, state out — so
/// migrations are testable without the store or `UserDefaults`.
enum Migrations {
    // MARK: Emoji → SF Symbol

    static let activityEmojiSymbols: [String: String] = [
        "🏢": "building.2.fill", "🎾": "tennis.racket", "🚶": "figure.walk",
        "🏃": "figure.run", "🧘": "figure.mind.and.body", "🚴": "bicycle",
        "🏋️": "figure.strengthtraining.traditional", "📚": "books.vertical.fill",
        "✍️": "pencil.line", "💻": "laptopcomputer", "☕️": "cup.and.saucer.fill",
        "🍳": "frying.pan.fill", "🥗": "fork.knife", "🎨": "paintpalette.fill",
        "🎵": "music.note", "🧹": "sparkles", "🛌": "bed.double.fill",
        "🌿": "leaf.fill", "👥": "person.2.fill", "🐕": "pawprint.fill",
        "🚗": "car.fill", "✈️": "airplane", "🏊": "figure.pool.swim",
        "🎮": "gamecontroller.fill", "🛍️": "bag.fill", "📱": "iphone",
        "💬": "bubble.left.fill", "💊": "cross.case.fill", "🧴": "heart.fill",
        "🌞": "sun.max.fill", "✨": "sparkles"
    ]

    static let outcomeEmojiSymbols: [String: String] = [
        "😊": "face.smiling.fill", "😌": "wind", "⚡️": "bolt.fill",
        "😴": "bed.double.fill", "😟": "waveform.path", "😢": "cloud.rain.fill",
        "😍": "heart.fill", "🤔": "brain.head.profile", "😤": "exclamationmark.circle.fill",
        "😮‍💨": "wind", "😇": "star.fill", "💪": "flame.fill",
        "🧠": "brain.head.profile", "💛": "heart.fill", "🌤️": "sun.max.fill",
        "🌧️": "cloud.rain.fill", "🥰": "heart.fill", "😎": "star.fill",
        "🥱": "moon.stars.fill", "🤯": "bolt.heart.fill", "😔": "cloud.rain.fill",
        "😃": "face.smiling.fill", "😐": "circle.lefthalf.filled", "🫶": "heart.fill"
    ]

    /// Known emoji map to their adopted symbol; unknown emoji fall back to
    /// `sparkles`; SF Symbol strings (and ids) pass through untouched.
    static func migratingEmojiSymbols(in activities: [Activity]) -> [Activity] {
        activities.map { activity in
            guard activity.symbol.isEmojiChoice else { return activity }
            var migrated = activity
            migrated.symbol = activityEmojiSymbols[activity.symbol] ?? "sparkles"
            return migrated
        }
    }

    static func migratingEmojiSymbols(in outcomes: [Outcome]) -> [Outcome] {
        outcomes.map { outcome in
            guard outcome.symbol.isEmojiChoice else { return outcome }
            var migrated = outcome
            migrated.symbol = outcomeEmojiSymbols[outcome.symbol] ?? "sparkles"
            return migrated
        }
    }

    // MARK: Legacy insight selection / experiments → saved graphs

    static func migratedGraphs(from state: PersistedState) -> [SavedGraph] {
        var graphs: [SavedGraph] = []
        if let selection = state.insightSelection,
           let outcomeID = selection.outcomeID,
           !selection.activityIDs.isEmpty {
            graphs.append(SavedGraph(outcomeIDs: [outcomeID], activityIDs: selection.activityIDs))
        }
        for experiment in state.experiments {
            let ids: Set<UUID> = [experiment.activityID]
            if !graphs.contains(where: { $0.outcomeIDs == [experiment.outcomeID] && $0.activityIDs == ids }) {
                graphs.append(SavedGraph(outcomeIDs: [experiment.outcomeID], activityIDs: ids))
            }
        }
        return graphs
    }

    // MARK: Starter library

    static func seedStarterLibrary() -> (activities: [Activity], outcomes: [Outcome]) {
        let walk = Activity(name: "Walk", symbol: "figure.walk", tintHex: "E39452")
        let mood = Outcome(name: "Mood", symbol: "face.smiling.fill", lowLabel: "Low", highLabel: "High", tintHex: "E6A13A")

        return ([walk], [mood])
    }

    // MARK: Demo history (call site stays DEBUG-only)

    /// The sample graph that makes a first run legible: it compares the starter
    /// outcome against the starter activity over the seeded history, so a new
    /// user sees what a graph *is* without having to build one first. Marked
    /// `isDemo` so removing sample data removes exactly what seeding added.
    static func demoGraphs(activities: [Activity], outcomes: [Outcome]) -> [SavedGraph] {
        [("Mood", "Walk")].compactMap { outcomeName, activityName in
            guard let outcome = outcomes.first(where: { $0.name == outcomeName }),
                  let activity = activities.first(where: { $0.name == activityName }) else { return nil }
            return SavedGraph(outcomeIDs: [outcome.id], activityIDs: [activity.id], isDemo: true)
        }
    }

    /// 21 days of synthetic check-ins that give the timeline a believable shape
    /// on first launch. Purely additive: existing days are never touched, and an
    /// already-demo'd store re-seeds nothing.
    static func demoEntries(activities: [Activity], outcomes: [Outcome],
                            existing: [String: DailyEntry],
                            now: Date = .now, calendar: Calendar = .current) -> [String: DailyEntry] {
        guard !existing.values.contains(where: { $0.isDemo }),
              let walk = activities.first(where: { $0.name == "Walk" }),
              let mood = outcomes.first(where: { $0.name == "Mood" }) else { return [:] }

        var seeded: [String: DailyEntry] = [:]
        for offset in 1...21 {
            guard let date = calendar.date(byAdding: .day, value: -offset, to: now),
                  existing[date.dayKey] == nil else { continue }

            let weekday = calendar.component(.weekday, from: date)
            // Walked most days, with enough misses to leave gaps in the line.
            let walkDay = offset % 2 == 0 || weekday == 1 || offset % 5 == 0

            var entry = DailyEntry(dateKey: date.dayKey)
            if walkDay { entry.completedActivityIDs.insert(walk.id) }

            let smallVariation = offset % 4 == 0 ? 1 : 0
            entry.outcomeRatings[mood.id] = min(5, walkDay ? 4 + smallVariation : 2 + (offset % 2))
            entry.note = offset == 3 ? "Demo: a walk after work felt restorative." : ""
            entry.submittedAt = calendar.date(bySettingHour: 20, minute: 0, second: 0, of: date)
            entry.isDemo = true
            seeded[date.dayKey] = entry
        }
        return seeded
    }
}
