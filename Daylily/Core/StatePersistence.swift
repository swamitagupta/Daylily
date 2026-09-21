import Foundation

/// `UserDefaults` storage for `PersistedState`: primary key plus a
/// previous-state fallback, with undecodable data quarantined rather than
/// destroyed. The recovery-mode gate stays in `AppStore`; this type just
/// moves bytes and never decides what the UI shows.
final class StatePersistence {
    enum Key {
        static let storage = "daylily.persisted-state.v2"
        static let fallback = "daylily.persisted-state.v2.previous"
        static let unreadable = "daylily.persisted-state.v2.unreadable"
        static let unreadableFallback = "daylily.persisted-state.v2.previous.unreadable"
        static let demoDismissed = "daylily.demo-data-dismissed.v1"
    }

    struct LoadOutcome {
        /// `nil` on a fresh install or when nothing stored is readable.
        var state: PersistedState?
        var recoveredFromLocalBackup = false
        var requiresRecovery = false
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Prefers the primary state; falls back to the previous copy (promoting it
    /// back to primary and quarantining the broken primary). When both copies
    /// exist but neither decodes, flags `requiresRecovery` and touches nothing.
    func load() -> LoadOutcome {
        let primaryData = defaults.data(forKey: Key.storage)
        let fallbackData = defaults.data(forKey: Key.fallback)
        if let primaryData, let decoded = try? JSONDecoder().decode(PersistedState.self, from: primaryData) {
            return LoadOutcome(state: decoded)
        }
        if let fallbackData, let decoded = try? JSONDecoder().decode(PersistedState.self, from: fallbackData) {
            if let primaryData { defaults.set(primaryData, forKey: Key.unreadable) }
            defaults.set(fallbackData, forKey: Key.storage)
            return LoadOutcome(state: decoded, recoveredFromLocalBackup: true)
        }
        if primaryData != nil || fallbackData != nil {
            return LoadOutcome(requiresRecovery: true)
        }
        return LoadOutcome()
    }

    /// Writes `state` as primary. The old primary is promoted to the fallback
    /// slot only when it is different and decodes — never garbage. If the
    /// fallback is missing or undecodable it is refreshed from `state`.
    func save(_ state: PersistedState) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        if let previous = defaults.data(forKey: Key.storage), previous != data,
           (try? JSONDecoder().decode(PersistedState.self, from: previous)) != nil {
            defaults.set(previous, forKey: Key.fallback)
        }
        defaults.set(data, forKey: Key.storage)
        if defaults.data(forKey: Key.fallback) == nil ||
            (try? JSONDecoder().decode(PersistedState.self, from: defaults.data(forKey: Key.fallback) ?? Data())) == nil {
            defaults.set(data, forKey: Key.fallback)
        }
    }

    /// After a destructive permanent deletion both slots must hold the trimmed
    /// state, so the old fallback can never resurrect deleted items.
    func savePermanent(_ state: PersistedState) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        defaults.set(data, forKey: Key.storage)
        defaults.set(data, forKey: Key.fallback)
        defaults.removeObject(forKey: Key.unreadable)
        defaults.removeObject(forKey: Key.unreadableFallback)
    }

    /// Keeps the unreadable payloads around for support/backup before they are
    /// overwritten or cleared.
    func preserveUnreadableCopies() {
        if let data = defaults.data(forKey: Key.storage) { defaults.set(data, forKey: Key.unreadable) }
        if let data = defaults.data(forKey: Key.fallback) { defaults.set(data, forKey: Key.unreadableFallback) }
    }

    func clearStoredStates() {
        defaults.removeObject(forKey: Key.storage)
        defaults.removeObject(forKey: Key.fallback)
    }

    var isDemoDismissed: Bool { defaults.bool(forKey: Key.demoDismissed) }
    func markDemoDismissed() { defaults.set(true, forKey: Key.demoDismissed) }

    // Test seam: lets a suite assert quarantine/rotation without exposing keys
    // publicly in the app-facing API.
    func debugData(forKey key: String) -> Data? { defaults.data(forKey: key) }
    func debugSetRaw(_ data: Data, forKey key: String) { defaults.set(data, forKey: key) }
}
