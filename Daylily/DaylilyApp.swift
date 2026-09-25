import SwiftUI
import UserNotifications

@main
struct DaylilyApp: App {
    @State private var store = AppStore()
    /// Held for the process lifetime: `UNUserNotificationCenter.delegate` is
    /// weak, and the views read tapped-notification routes from this instance.
    @State private var notifier: NotificationPresenter

    init() {
        let notifier = NotificationPresenter()
        UNUserNotificationCenter.current().delegate = notifier
        _notifier = State(initialValue: notifier)
        #if DEBUG
        debugDeliverReminderIfRequested()
        debugSeedDenseCalendarIfRequested()
        #endif
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .environment(notifier)
        }
    }

    #if DEBUG
    /// Test seam: launching with `-DaylilyDebugDeliverReminder YES` re-delivers
    /// the reminder banner every few seconds (`trigger: nil` bypasses the
    /// calendar), so a UI test can exercise the real tap path without waiting
    /// for 9:30 PM. Periodic rather than one-shot because banners are transient:
    /// a test that begins watching after the first banner faded must still
    /// catch a later one, and the same identifier means they never stack.
    private func debugDeliverReminderIfRequested() {
        guard UserDefaults.standard.bool(forKey: "DaylilyDebugDeliverReminder") else { return }
        let center = UNUserNotificationCenter.current()
        Task {
            _ = try? await center.requestAuthorization(options: [.alert, .sound])
            let content = CheckInReminder.request(fireDate: .now, calendar: .current).content
            for _ in 0..<10 {
                try? await center.add(UNNotificationRequest(identifier: CheckInReminder.identifier,
                                                            content: content, trigger: nil))
                try? await Task.sleep(for: .seconds(3))
            }
        }
    }

    /// Test seam: launching with `-DaylilyDebugSeedDenseCalendar YES` fills the
    /// store with a 1…12 activity ladder so the calendar density UI test needs
    /// no externally injected state.
    private func debugSeedDenseCalendarIfRequested() {
        guard UserDefaults.standard.bool(forKey: "DaylilyDebugSeedDenseCalendar") else { return }
        store.debugSeedDenseCalendar()
    }
    #endif
}
