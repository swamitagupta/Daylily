import Foundation
import UserNotifications

/// The time of day the daily reminder fires, in the device's own time zone.
struct ReminderTime: Equatable {
    static let `default` = ReminderTime(hour: 21, minute: 30)

    var hour: Int
    var minute: Int

    /// How the choice is persisted: minutes after midnight.
    var minutesAfterMidnight: Int { hour * 60 + minute }

    init(hour: Int, minute: Int) {
        self.hour = hour
        self.minute = minute
    }

    /// Out-of-range stored values fall back inside the day rather than crashing
    /// a date calculation.
    init(minutesAfterMidnight: Int) {
        let clamped = min(max(minutesAfterMidnight, 0), 24 * 60 - 1)
        self.init(hour: clamped / 60, minute: clamped % 60)
    }

    /// Bridges `DatePicker`, which edits whole dates.
    init(date: Date, calendar: Calendar = .current) {
        self.init(hour: calendar.component(.hour, from: date),
                  minute: calendar.component(.minute, from: date))
    }

    func date(onDayOf reference: Date, calendar: Calendar = .current) -> Date {
        calendar.date(bySettingHour: hour, minute: minute, second: 0, of: reference) ?? reference
    }
}

/// The one reminder Daylily keeps armed: a nudge at the user's chosen time for
/// the next day whose check-in is still open.
///
/// iOS cannot evaluate "is today's check-in done?" when a notification fires,
/// so the app holds exactly one pending request and recomputes it every time it
/// is open (`AppStore.syncReminder()`), replacing or dropping the pending one.
enum CheckInReminderPlan {
    /// Tonight at the chosen time while it is still ahead and today's check-in
    /// is open; otherwise the following evening's. A day that is already saved
    /// never fires tonight, and tomorrow stays armed so a day the app is not
    /// opened on is still covered. Both the time and the fire date come from
    /// the device calendar, so the reminder stays at that wall-clock time in
    /// the phone's own time zone and survives DST transitions.
    static func nextFireDate(now: Date, calendar: Calendar = .current,
                             checkInSubmittedToday: Bool,
                             time: ReminderTime = .default) -> Date {
        let today = time.date(onDayOf: now, calendar: calendar)
        if !checkInSubmittedToday && today > now { return today }
        return calendar.date(byAdding: .day, value: 1, to: today)
            ?? today.addingTimeInterval(24 * 60 * 60)
    }
}

/// App-facing view of the system notification permission, so screens never
/// import `UserNotifications` just to read a status.
enum ReminderPermission: Equatable {
    /// Never asked, or asked but not yet decided.
    case unknown
    case allowed
    case denied

    init(_ status: UNAuthorizationStatus) {
        switch status {
        case .authorized, .provisional: self = .allowed
        case .denied: self = .denied
        default: self = .unknown
        }
    }
}

extension UNAuthorizationStatus {
    /// Whether the system will actually deliver the reminder.
    var allowsDelivery: Bool { self == .authorized || self == .provisional }
}

/// The slice of `UNUserNotificationCenter` the reminder needs: a seam so the
/// scheduling rule is testable without the system scheduler.
@MainActor
protocol UserNotificationScheduling: AnyObject {
    var authorizationStatus: UNAuthorizationStatus { get async }
    func requestAuthorization() async -> Bool
    func add(_ request: UNNotificationRequest) async
    func removePending(withIdentifier identifier: String)
    func removeDelivered(withIdentifier identifier: String)
}

/// The real center. `UNUserNotificationCenter` is behind a small wrapper rather
/// than conformed retroactively, so the app never extends a Foundation type.
@MainActor
final class SystemNotificationCenter: UserNotificationScheduling {
    private let center = UNUserNotificationCenter.current()

    // Nonisolated so it can be the default argument of `CheckInReminder.init`;
    // `UNUserNotificationCenter.current()` carries no isolation.
    nonisolated init() {}

    var authorizationStatus: UNAuthorizationStatus {
        get async { await center.notificationSettings().authorizationStatus }
    }

    func requestAuthorization() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
    }

    func add(_ request: UNNotificationRequest) async {
        try? await center.add(request)
    }

    func removePending(withIdentifier identifier: String) {
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
    }

    func removeDelivered(withIdentifier identifier: String) {
        center.removeDeliveredNotifications(withIdentifiers: [identifier])
    }
}

@MainActor
final class CheckInReminder {
    static let identifier = "daylily.checkin.reminder"

    private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined

    private let center: UserNotificationScheduling
    private let calendar: Calendar

    init(center: UserNotificationScheduling = SystemNotificationCenter(),
         calendar: Calendar = .current) {
        self.center = center
        self.calendar = calendar
    }

    /// Prompts only while the system has not decided yet; afterwards it just
    /// reports the standing answer.
    @discardableResult
    func requestAuthorization() async -> Bool {
        let granted = await center.requestAuthorization()
        await refreshAuthorizationStatus()
        return granted
    }

    func refreshAuthorizationStatus() async {
        authorizationStatus = await center.authorizationStatus
    }

    /// Leaves exactly one pending reminder — the next open occurrence of the
    /// chosen time — or none when reminders are off, notifications are not
    /// allowed, or today is already saved.
    func sync(enabled: Bool, checkInSubmittedToday: Bool, now: Date,
              time: ReminderTime = .default) async {
        await refreshAuthorizationStatus()
        guard enabled, authorizationStatus.allowsDelivery else {
            cancel()
            return
        }
        if checkInSubmittedToday {
            // The nudge has done its job; don't leave it sitting in Notification Center.
            center.removeDelivered(withIdentifier: Self.identifier)
        }
        let fireDate = CheckInReminderPlan.nextFireDate(now: now, calendar: calendar,
                                                        checkInSubmittedToday: checkInSubmittedToday,
                                                        time: time)
        await center.add(Self.request(fireDate: fireDate, calendar: calendar))
    }

    func cancel() {
        center.removePending(withIdentifier: Self.identifier)
        center.removeDelivered(withIdentifier: Self.identifier)
    }

    /// One identifier for every arm: the system replaces the pending request,
    /// so reminders can never stack.
    static func request(fireDate: Date, calendar: Calendar) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = String(localized: "A minute for today?")
        content.body = String(localized: "Today's check-in is still open. Note what you did and how you felt.")
        content.sound = .default
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate),
            repeats: false)
        return UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
    }
}
