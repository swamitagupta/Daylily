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
        let office = Activity(name: "Office", symbol: "building.2.fill", tintHex: "7258D6")
        let tennis = Activity(name: "Tennis", symbol: "tennis.racket", tintHex: "4C9A72")
        let walk = Activity(name: "Morning walk", symbol: "figure.walk", tintHex: "E39452")

        let happy = Outcome(name: "Happiness", symbol: "face.smiling.fill", lowLabel: "Low", highLabel: "Glowing", tintHex: "E6A13A")
        let calm = Outcome(name: "Calm", symbol: "wind", lowLabel: "Anxious", highLabel: "Peaceful", tintHex: "4A8DA8")
        let energy = Outcome(name: "Energy", symbol: "bolt.fill", lowLabel: "Drained", highLabel: "Energized", tintHex: "D66B69")

        return ([office, tennis, walk], [happy, calm, energy])
    }

    // MARK: Demo history (call site stays DEBUG-only)

    /// The two sample graphs that make a first run legible: each one compares a
    /// single outcome against a single activity over the seeded history, so a new
    /// user sees what a graph *is* without having to build one first. Marked
    /// `isDemo` so removing sample data removes exactly what seeding added.
    static func demoGraphs(activities: [Activity], outcomes: [Outcome]) -> [SavedGraph] {
        [("Happiness", "Office"), ("Energy", "Morning walk")].compactMap { outcomeName, activityName in
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
              let office = activities.first(where: { $0.name == "Office" }),
              let tennis = activities.first(where: { $0.name == "Tennis" }),
              let walk = activities.first(where: { $0.name == "Morning walk" }),
              let happiness = outcomes.first(where: { $0.name == "Happiness" }),
              let calm = outcomes.first(where: { $0.name == "Calm" }),
              let energy = outcomes.first(where: { $0.name == "Energy" }) else { return [:] }

        var seeded: [String: DailyEntry] = [:]
        for offset in 1...21 {
            guard let date = calendar.date(byAdding: .day, value: -offset, to: now),
                  existing[date.dayKey] == nil else { continue }

            let weekday = calendar.component(.weekday, from: date)
            let isWeekday = (2...6).contains(weekday)
            let officeDay = isWeekday && weekday != 6 && offset % 5 != 0
            let tennisDay = offset % 3 == 0 || offset % 7 == 0
            let walkDay = offset % 2 == 0 || weekday == 1

            var entry = DailyEntry(dateKey: date.dayKey)
            if officeDay { entry.completedActivityIDs.insert(office.id) }
            if tennisDay { entry.completedActivityIDs.insert(tennis.id) }
            if walkDay { entry.completedActivityIDs.insert(walk.id) }

            let smallVariation = offset % 4 == 0 ? 1 : 0
            entry.outcomeRatings[happiness.id] = min(5, officeDay ? 4 + smallVariation : 2 + (offset % 2))
            entry.outcomeRatings[calm.id] = min(5, tennisDay ? 4 + (offset % 2) : 2 + (offset % 2))
            entry.outcomeRatings[energy.id] = min(5, walkDay ? 4 + smallVariation : 2 + (offset % 2))
            entry.note = offset == 3 ? "Demo: tennis after work felt restorative." : ""
            entry.submittedAt = calendar.date(bySettingHour: 20, minute: 0, second: 0, of: date)
            entry.isDemo = true
            seeded[date.dayKey] = entry
        }
        return seeded
    }
}
