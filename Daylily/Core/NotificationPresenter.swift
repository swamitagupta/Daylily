import Foundation
import UserNotifications

/// Makes a delivered notification visible while the app is open.
///
/// Without a `UNUserNotificationCenterDelegate`, iOS silently discards a
/// notification that arrives in the foreground — which would hide the daily
/// reminder exactly when the app happens to be open as it fires, and makes the
/// reminder's arrival impossible to observe on demand.
@MainActor
final class NotificationPresenter: NSObject, UNUserNotificationCenterDelegate {
    /// Returns the presentation options; the banner still respects the phone's
    /// sound, Focus, and notification settings.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }
}
