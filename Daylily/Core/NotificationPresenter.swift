import Foundation
import Observation
import UserNotifications

/// What a tap on a delivered notification asks the app to show.
///
/// The raw value travels in the notification's `userInfo`, so a payload from
/// another source (or an older build) resolves to no route instead of guessing.
enum NotificationRoute: String, Hashable, Sendable {
    /// Today's check-in sheet, opened from Home.
    case checkIn

    /// Key under which a scheduled request tags its content with its route.
    static let userInfoKey = "daylily.route"

    init?(userInfo: [AnyHashable: Any]) {
        guard let raw = userInfo[Self.userInfoKey] as? String else { return nil }
        self.init(rawValue: raw)
    }
}

/// Presents delivered notifications and turns taps into navigation.
///
/// Without a `UNUserNotificationCenterDelegate`, iOS silently discards a
/// notification that arrives in the foreground — which would hide the daily
/// reminder exactly when the app happens to be open as it fires, and makes the
/// reminder's arrival impossible to observe on demand.
///
/// A tap is recorded as `pendingRoute` rather than announced as an event: on a
/// cold launch the system reports the interaction before any view exists to
/// observe it, so only state survives to be consumed when Home appears.
@MainActor
@Observable
final class NotificationPresenter: NSObject, UNUserNotificationCenterDelegate {
    /// A routed tap no view has taken up yet; consumers clear it as they open.
    var pendingRoute: NotificationRoute?

    /// Returns the presentation options; the banner still respects the phone's
    /// sound, Focus, and notification settings.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    /// Records the tapped notification's route for the views to open.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        // The payload dictionary is parsed here, on the callback's thread:
        // only the resolved route crosses to the main actor.
        let route = NotificationRoute(userInfo: response.notification.request.content.userInfo)
        // The handler is the callback's own hand-off, invoked exactly once
        // below; the ObjC API does not mark it `@Sendable`.
        nonisolated(unsafe) let finish = completionHandler
        Task { @MainActor in
            if let route { self.pendingRoute = route }
            finish()
        }
    }
}
