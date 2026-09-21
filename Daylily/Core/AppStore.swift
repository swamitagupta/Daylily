import Foundation
import Observation

@MainActor
@Observable
final class AppStore {
    var activities: [Activity] = [] { didSet { save() } }
    var outcomes: [Outcome] = [] { didSet { save() } }
    var entries: [String: DailyEntry] = [:] { didSet { save() } }
    var experiments: [Experiment] = [] { didSet { save() } }
    var insightSelection = InsightSelection(outcomeID: nil, activityIDs: []) { didSet { save() } }
    var savedGraphs: [SavedGraph] = [] { didSet { save() } }
    /// Single source of "now" for the UI. Bumped via `refreshClock()` on
    /// foregrounding so a night away doesn't strand yesterday's "today".
    var now = Date.now
    /// The user's standing choice, independent of what the system currently
    /// allows: a revoked permission leaves the toggle on and the warning in
    /// Customize explains why nothing is being sent.
    var remindersEnabled = false { didSet { save() } }
    /// The user's chosen reminder time; `setReminderTime` is the mutation path
    /// so a picker's continuous updates only re-arm the pending request once.
    var reminderTime = ReminderTime.default { didSet { save() } }
    private(set) var reminderPermission: ReminderPermission = .unknown
    private(set) var requiresRecovery = false
    private(set) var recoveredFromLocalBackup = false

    private let persistence: StatePersistence
    @ObservationIgnored private let reminders: CheckInReminder
    @ObservationIgnored private var reminderResync: Task<Void, Never>?
    @ObservationIgnored private var isLoading = true

    init(defaults: UserDefaults = .standard, now: Date = .now,
         reminders: CheckInReminder? = nil) {
        persistence = StatePersistence(defaults: defaults)
        self.reminders = reminders ?? CheckInReminder()
        self.now = now
        let loaded = persistence.load()
        requiresRecovery = loaded.requiresRecovery
        recoveredFromLocalBackup = loaded.recoveredFromLocalBackup

        if let state = loaded.state {
            load(state)
        } else if !requiresRecovery {
            let starter = Migrations.seedStarterLibrary()
            activities = starter.activities
            outcomes = starter.outcomes
            entries = [:]
            experiments = []
            insightSelection = InsightSelection(outcomeID: outcomes.first?.id,
                                                activityIDs: Set(activities.prefix(2).map(\.id)))
        }

        if !requiresRecovery {
            activities = Migrations.migratingEmojiSymbols(in: activities)
            outcomes = Migrations.migratingEmojiSymbols(in: outcomes)
        }

        #if DEBUG
        if !requiresRecovery && !persistence.isDemoDismissed {
            let seeded = Migrations.demoEntries(activities: activities, outcomes: outcomes,
                                                existing: entries, now: now)
            if !seeded.isEmpty {
                entries.merge(seeded, uniquingKeysWith: { current, _ in current })
                // Sample graphs only ride along with a fresh seeding, and never
                // displace graphs the user already made.
                if savedGraphs.isEmpty {
                    savedGraphs = Migrations.demoGraphs(activities: activities, outcomes: outcomes)
                }
            }
        }
        #endif

        isLoading = false
        save()
        Task { await syncReminder() }
    }

    private func load(_ state: PersistedState) {
        activities = state.activities
        outcomes = state.outcomes
        entries = state.entries
        experiments = state.experiments
        remindersEnabled = state.remindersEnabled ?? false
        reminderTime = state.reminderMinutes.map(ReminderTime.init(minutesAfterMidnight:)) ?? .default
        insightSelection = state.insightSelection ?? InsightSelection(
            outcomeID: state.outcomes.first?.id,
            activityIDs: Set(state.activities.filter { !$0.isArchived }.prefix(2).map(\.id))
        )
        savedGraphs = state.savedGraphs ?? Migrations.migratedGraphs(from: state)
    }

    func entry(for date: Date) -> DailyEntry {
        entries[date.dayKey] ?? DailyEntry(dateKey: date.dayKey)
    }

    /// Re-bases "today" on every foreground and re-arms the reminder, so a night
    /// spent in the background cannot leave a stale day or a stale reminder.
    func refreshClock() {
        now = .now
        Task { await syncReminder() }
    }

    func saveCheckIn(_ draft: DailyEntry) {
        var day = draft
        day.submittedAt = .now
        day.isDemo = false
        entries[day.dateKey] = day
        Task { await syncReminder() }
    }

    /// Records the user's choice, asking the system for permission the first
    /// time. A refusal leaves the toggle off and `reminderPermission` denied.
    func setRemindersEnabled(_ enabled: Bool) async {
        if enabled {
            remindersEnabled = await reminders.requestAuthorization()
        } else {
            remindersEnabled = false
        }
        await syncReminder()
    }

    /// Records a new reminder time. A `DatePicker` reports every wheel tick, so
    /// the pending request is only re-armed once the value settles.
    func setReminderTime(_ time: ReminderTime) {
        guard time != reminderTime else { return }
        reminderTime = time
        reminderResync?.cancel()
        reminderResync = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            await self?.syncReminder()
        }
    }

    /// Recomputes the single pending reminder from current state.
    /// Called on launch, on foreground, after a save, and after a time change.
    func syncReminder() async {
        if remindersEnabled && reminders.authorizationStatus == .notDetermined {
            // The user already opted in (or a backup carried the preference);
            // this only prompts when the system has never asked.
            await reminders.requestAuthorization()
        }
        await reminders.sync(enabled: remindersEnabled,
                             checkInSubmittedToday: isSubmitted(now), now: now,
                             time: reminderTime)
        reminderPermission = ReminderPermission(reminders.authorizationStatus)
    }

    func isSubmitted(_ date: Date) -> Bool {
        entry(for: date).submittedAt != nil
    }

    var demoEntryCount: Int {
        entries.values.filter { $0.isDemo }.count
    }

    var hasDemoData: Bool { demoEntryCount > 0 }

    var activeActivities: [Activity] { activities.filter { !$0.isArchived } }
    var activeOutcomes: [Outcome] { outcomes.filter { !$0.isArchived } }
    var archivedActivities: [Activity] { activities.filter { $0.isArchived } }
    var archivedOutcomes: [Outcome] { outcomes.filter { $0.isArchived } }

    var personalCurrentStreak: Int { InsightsEngine.personalCurrentStreak(entries: entries, now: now) }

    func addActivity(name: String, symbol: String, color: String) {
        activities.append(Activity(name: name, symbol: symbol, tintHex: color))
    }

    func addOutcome(name: String, symbol: String, low: String, high: String, color: String) {
        outcomes.append(Outcome(name: name, symbol: symbol, lowLabel: low, highLabel: high, tintHex: color))
    }

    // Mutated in place: entry `completedActivityIDs` / `outcomeRatings` and experiment
    // references are keyed by these ids, so a replacement element would orphan history.
    func updateActivity(id: UUID, name: String, symbol: String, color: String) {
        guard let index = activities.firstIndex(where: { $0.id == id }) else { return }
        activities[index].name = name
        activities[index].symbol = symbol
        activities[index].tintHex = color
    }

    func updateOutcome(id: UUID, name: String, symbol: String, low: String, high: String, color: String) {
        guard let index = outcomes.firstIndex(where: { $0.id == id }) else { return }
        outcomes[index].name = name
        outcomes[index].symbol = symbol
        outcomes[index].lowLabel = low
        outcomes[index].highLabel = high
        outcomes[index].tintHex = color
    }

    func archiveActivity(id: UUID) {
        guard let index = activities.firstIndex(where: { $0.id == id }) else { return }
        activities[index].isArchived = true
    }

    func archiveOutcome(id: UUID) {
        guard let index = outcomes.firstIndex(where: { $0.id == id }) else { return }
        outcomes[index].isArchived = true
    }

    func restoreActivity(id: UUID) {
        guard let index = activities.firstIndex(where: { $0.id == id }) else { return }
        activities[index].isArchived = false
    }

    func restoreOutcome(id: UUID) {
        guard let index = outcomes.firstIndex(where: { $0.id == id }) else { return }
        outcomes[index].isArchived = false
    }

    func activityDeletionImpact(id: UUID) -> (checkIns: Int, graphs: Int) {
        (entries.values.filter { $0.submittedAt != nil && $0.completedActivityIDs.contains(id) }.count,
         savedGraphs.filter { $0.activityIDs.contains(id) }.count)
    }

    func outcomeDeletionImpact(id: UUID) -> (checkIns: Int, graphs: Int) {
        (entries.values.filter { $0.submittedAt != nil && $0.outcomeRatings[id] != nil }.count,
         savedGraphs.filter { $0.outcomeIDs.contains(id) }.count)
    }

    func permanentlyDeleteActivity(id: UUID) {
        guard activities.contains(where: { $0.id == id }) else { return }
        isLoading = true
        for key in Array(entries.keys) {
            entries[key]?.completedActivityIDs.remove(id)
        }
        savedGraphs.removeAll { $0.activityIDs.contains(id) }
        experiments.removeAll { $0.activityID == id }
        insightSelection.activityIDs.remove(id)
        activities.removeAll { $0.id == id }
        isLoading = false
        persistence.savePermanent(currentState)
    }

    func permanentlyDeleteOutcome(id: UUID) {
        guard outcomes.contains(where: { $0.id == id }) else { return }
        isLoading = true
        for key in Array(entries.keys) {
            entries[key]?.outcomeRatings.removeValue(forKey: id)
        }
        savedGraphs = savedGraphs.compactMap { graph in
            let remaining = graph.outcomeIDs.filter { $0 != id }
            guard !remaining.isEmpty else { return nil }
            var updated = graph
            updated.outcomeIDs = remaining
            return updated
        }
        experiments.removeAll { $0.outcomeID == id }
        if insightSelection.outcomeID == id { insightSelection.outcomeID = nil }
        outcomes.removeAll { $0.id == id }
        isLoading = false
        persistence.savePermanent(currentState)
    }

    func addGraph(outcomeIDs: [UUID], activityIDs: Set<UUID>) {
        guard !outcomeIDs.isEmpty, !activityIDs.isEmpty else { return }
        savedGraphs.insert(SavedGraph(outcomeIDs: outcomeIDs, activityIDs: activityIDs), at: 0)
    }

    func updateGraph(id: UUID, outcomeIDs: [UUID], activityIDs: Set<UUID>) {
        guard !outcomeIDs.isEmpty, !activityIDs.isEmpty,
              let index = savedGraphs.firstIndex(where: { $0.id == id }) else { return }
        savedGraphs[index].outcomeIDs = outcomeIDs
        savedGraphs[index].activityIDs = activityIDs
    }

    func deleteGraph(id: UUID) {
        savedGraphs.removeAll { $0.id == id }
    }

    /// Moves one graph a single position: the arrows in reorder mode. The list
    /// order is the user's arrangement, so it is stored as shown and survives
    /// relaunch and backup export; new graphs still land on top.
    func moveGraph(id: UUID, by offset: Int) {
        guard let index = savedGraphs.firstIndex(where: { $0.id == id }) else { return }
        let target = index + offset
        guard savedGraphs.indices.contains(target) else { return }
        savedGraphs.swapAt(index, target)
    }

    func removeDemoData() {
        entries = entries.filter { !$0.value.isDemo }
        savedGraphs.removeAll { $0.isDemo }
        persistence.markDemoDismissed()
    }

    func exportBackup() throws -> Data {
        guard !requiresRecovery else { throw BackupError.noData }
        let backup = DaylilyBackup(state: currentState)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(backup)
    }

    func importBackup(_ backup: DaylilyBackup) {
        if requiresRecovery { persistence.preserveUnreadableCopies() }
        isLoading = true
        load(backup.state)
        activities = Migrations.migratingEmojiSymbols(in: activities)
        outcomes = Migrations.migratingEmojiSymbols(in: outcomes)
        persistence.markDemoDismissed()
        requiresRecovery = false
        recoveredFromLocalBackup = false
        isLoading = false
        save()
        Task { await syncReminder() }
    }

    func startFreshAfterRecoveryFailure() {
        guard requiresRecovery else { return }
        persistence.preserveUnreadableCopies()
        persistence.clearStoredStates()
        isLoading = true
        let starter = Migrations.seedStarterLibrary()
        activities = starter.activities
        outcomes = starter.outcomes
        entries = [:]
        experiments = []
        savedGraphs = []
        insightSelection = InsightSelection(outcomeID: outcomes.first?.id,
                                            activityIDs: Set(activities.prefix(2).map(\.id)))
        persistence.markDemoDismissed()
        requiresRecovery = false
        isLoading = false
        save()
    }

    private var currentState: PersistedState {
        PersistedState(activities: activities, outcomes: outcomes, entries: entries,
                       experiments: experiments, insightSelection: insightSelection,
                       savedGraphs: savedGraphs, remindersEnabled: remindersEnabled,
                       reminderMinutes: reminderTime.minutesAfterMidnight)
    }

    private func save() {
        guard !isLoading && !requiresRecovery else { return }
        persistence.save(currentState)
    }
}
