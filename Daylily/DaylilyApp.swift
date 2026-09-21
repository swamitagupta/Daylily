import SwiftUI
import UserNotifications

@main
struct DaylilyApp: App {
    @State private var store = AppStore()
    // Held for the process lifetime: `UNUserNotificationCenter.delegate` is weak.
    private let presenter = NotificationPresenter()

    init() {
        UNUserNotificationCenter.current().delegate = presenter
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
        }
    }
}
