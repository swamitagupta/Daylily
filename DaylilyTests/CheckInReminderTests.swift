import XCTest
import UserNotifications
@testable import Daylily

/// The reminder must land on the next 9:30 PM whose check-in is still open,
/// must never be left armed for a day that is already saved, and must be
/// dropped the moment reminders are off or the system refuses them.
@MainActor
final class CheckInReminderTests: XCTestCase {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        return calendar
    }()

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day,
                                           hour: hour, minute: minute))!
    }

    private func makeDefaults() -> UserDefaults {
        UserDefaults(suiteName: "DaylilyReminderTests.\(UUID().uuidString)")!
    }

    // MARK: Timing rule

    func testReminderTargetsTonightWhileCheckInIsOpen() {
        let fireDate = CheckInReminderPlan.nextFireDate(now: date(2026, 9, 20, 11), calendar: calendar,
                                                        checkInSubmittedToday: false)
        XCTAssertEqual(fireDate, date(2026, 9, 20, 21, 30))
    }

    func testSavedDaySkipsTonightAndArmsTomorrow() {
        let fireDate = CheckInReminderPlan.nextFireDate(now: date(2026, 9, 20, 11), calendar: calendar,
                                                        checkInSubmittedToday: true)
        XCTAssertEqual(fireDate, date(2026, 9, 21, 21, 30))
    }

    func testEveningAfterNineThirtyAlreadyWaitsForTomorrow() {
        let fireDate = CheckInReminderPlan.nextFireDate(now: date(2026, 9, 20, 22), calendar: calendar,
                                                        checkInSubmittedToday: false)
        XCTAssertEqual(fireDate, date(2026, 9, 21, 21, 30))
    }

    func testNineThirtyExactlyNeverSchedulesAPastTrigger() {
        let fireDate = CheckInReminderPlan.nextFireDate(now: date(2026, 9, 20, 21, 30), calendar: calendar,
                                                        checkInSubmittedToday: false)
        XCTAssertEqual(fireDate, date(2026, 9, 21, 21, 30))
    }

    func testSpringForwardKeepsNineThirtyPMLocal() {
        // 2026-03-08 is the US spring-forward day; 9:30 PM is late enough that
        // the time itself still exists, and the reminder must stay there.
        let fireDate = CheckInReminderPlan.nextFireDate(now: date(2026, 3, 8, 9), calendar: calendar,
                                                        checkInSubmittedToday: false)
        XCTAssertEqual(fireDate, date(2026, 3, 8, 21, 30))
        XCTAssertEqual(calendar.component(.hour, from: fireDate), 21)
        XCTAssertEqual(calendar.component(.minute, from: fireDate), 30)
    }

    // MARK: Scheduling

    private func fireDate(of request: UNNotificationRequest?) -> Date? {
        guard let components = (request?.trigger as? UNCalendarNotificationTrigger)?.dateComponents else { return nil }
        return calendar.date(from: components)
    }

    func testSyncArmsExactlyOneNineThirtyPMReminder() async {
        let center = FakeNotificationCenter()
        let reminder = CheckInReminder(center: center, calendar: calendar)

        await reminder.sync(enabled: true, checkInSubmittedToday: false, now: date(2026, 9, 20, 11))

        XCTAssertEqual(center.added.count, 1)
        XCTAssertEqual(center.added.first?.identifier, CheckInReminder.identifier)
        XCTAssertEqual(fireDate(of: center.added.first), date(2026, 9, 20, 21, 30))
        XCTAssertFalse((center.added.first?.trigger as? UNCalendarNotificationTrigger)?.repeats ?? true)
        XCTAssertFalse(center.added.first?.content.title.isEmpty ?? true)
    }

    func testSavedDayClearsTheDeliveredNudgeAndArmsTomorrow() async {
        let center = FakeNotificationCenter()
        let reminder = CheckInReminder(center: center, calendar: calendar)

        await reminder.sync(enabled: true, checkInSubmittedToday: true, now: date(2026, 9, 20, 11))

        XCTAssertEqual(fireDate(of: center.added.last), date(2026, 9, 21, 21, 30))
        XCTAssertEqual(center.removedDelivered, [CheckInReminder.identifier],
                       "a nudge for a saved day must not linger in Notification Center")
    }

    func testDisabledRemindersLeaveNothingPending() async {
        let center = FakeNotificationCenter()
        let reminder = CheckInReminder(center: center, calendar: calendar)

        await reminder.sync(enabled: false, checkInSubmittedToday: false, now: date(2026, 9, 20, 11))

        XCTAssertTrue(center.added.isEmpty)
        XCTAssertEqual(center.removedPending, [CheckInReminder.identifier])
        XCTAssertEqual(center.removedDelivered, [CheckInReminder.identifier])
    }

    func testRefusedPermissionLeavesNothingPending() async {
        let center = FakeNotificationCenter()
        center.status = .denied
        let reminder = CheckInReminder(center: center, calendar: calendar)

        await reminder.sync(enabled: true, checkInSubmittedToday: false, now: date(2026, 9, 20, 11))

        XCTAssertTrue(center.added.isEmpty)
        XCTAssertEqual(center.removedPending, [CheckInReminder.identifier])
        XCTAssertEqual(reminder.authorizationStatus, .denied)
    }

    func testRequestAuthorizationReportsTheSystemAnswer() async {
        let center = FakeNotificationCenter()
        center.status = .denied
        center.grantsAuthorization = false
        let reminder = CheckInReminder(center: center, calendar: calendar)

        let granted = await reminder.requestAuthorization()

        XCTAssertFalse(granted)
        XCTAssertEqual(reminder.authorizationStatus, .denied)
    }

    // MARK: Store integration

    func testStoreArmsTonightAndRearmsTomorrowAfterASavedCheckIn() async {
        let center = FakeNotificationCenter()
        let calendar = self.calendar
        let store = AppStore(defaults: makeDefaults(), now: date(2026, 9, 20, 11),
                             reminders: CheckInReminder(center: center, calendar: calendar))
        store.remindersEnabled = true

        await store.syncReminder()
        XCTAssertEqual(fireDate(of: center.added.last), date(2026, 9, 20, 21, 30))
        XCTAssertEqual(store.reminderPermission, .allowed)

        store.saveCheckIn(DailyEntry(dateKey: "2026-09-20", outcomeRatings: [UUID(): 4]))
        await store.syncReminder()
        XCTAssertEqual(fireDate(of: center.added.last), date(2026, 9, 21, 21, 30),
                       "saving today's check-in must retire tonight's reminder")
    }

    func testStoreRemembersTheChoiceAcrossLaunches() async {
        let defaults = makeDefaults()
        let now = date(2026, 9, 20, 11)
        let store = AppStore(defaults: defaults, now: now,
                             reminders: CheckInReminder(center: FakeNotificationCenter(), calendar: calendar))
        store.remindersEnabled = true

        let relaunched = AppStore(defaults: defaults, now: now,
                                  reminders: CheckInReminder(center: FakeNotificationCenter(), calendar: calendar))
        XCTAssertTrue(relaunched.remindersEnabled)
    }

    // MARK: Chosen time

    func testChosenTimeTargetsTonightWhileItIsStillAhead() {
        let fireDate = CheckInReminderPlan.nextFireDate(now: date(2026, 9, 20, 11), calendar: calendar,
                                                        checkInSubmittedToday: false,
                                                        time: ReminderTime(hour: 22, minute: 15))
        XCTAssertEqual(fireDate, date(2026, 9, 20, 22, 15))
    }

    func testChosenTimeAlreadyPastTodayWaitsForTomorrow() {
        let fireDate = CheckInReminderPlan.nextFireDate(now: date(2026, 9, 20, 11), calendar: calendar,
                                                        checkInSubmittedToday: false,
                                                        time: ReminderTime(hour: 8, minute: 0))
        XCTAssertEqual(fireDate, date(2026, 9, 21, 8))
    }

    func testSyncUsesTheChosenTime() async {
        let center = FakeNotificationCenter()
        let reminder = CheckInReminder(center: center, calendar: calendar)

        await reminder.sync(enabled: true, checkInSubmittedToday: false,
                            now: date(2026, 9, 20, 6), time: ReminderTime(hour: 7, minute: 5))

        XCTAssertEqual(fireDate(of: center.added.last), date(2026, 9, 20, 7, 5))
    }

    func testStoredMinutesOutsideTheDayFallBackInsideIt() {
        XCTAssertEqual(ReminderTime(minutesAfterMidnight: -30), ReminderTime(hour: 0, minute: 0))
        XCTAssertEqual(ReminderTime(minutesAfterMidnight: 24 * 60), ReminderTime(hour: 23, minute: 59))
        XCTAssertEqual(ReminderTime(minutesAfterMidnight: 21 * 60 + 30), .default)
    }

    func testStoreReArmsAtTheChosenTimeOnceThePickerSettles() async throws {
        let center = FakeNotificationCenter()
        let store = AppStore(defaults: makeDefaults(), now: date(2026, 9, 20, 11),
                             reminders: CheckInReminder(center: center, calendar: calendar))
        store.remindersEnabled = true
        await store.syncReminder()
        XCTAssertEqual(fireDate(of: center.added.last), date(2026, 9, 20, 21, 30))

        store.setReminderTime(ReminderTime(hour: 7, minute: 5))
        try await Task.sleep(for: .milliseconds(900))

        XCTAssertEqual(store.reminderTime, ReminderTime(hour: 7, minute: 5))
        XCTAssertEqual(fireDate(of: center.added.last), date(2026, 9, 21, 7, 5),
                       "a time already past today must arm tomorrow")
    }

    func testStoreRemembersTheChosenTimeAcrossLaunches() async {
        let defaults = makeDefaults()
        let now = date(2026, 9, 20, 11)
        let store = AppStore(defaults: defaults, now: now,
                             reminders: CheckInReminder(center: FakeNotificationCenter(), calendar: calendar))
        store.setReminderTime(ReminderTime(hour: 18, minute: 45))

        let relaunched = AppStore(defaults: defaults, now: now,
                                  reminders: CheckInReminder(center: FakeNotificationCenter(), calendar: calendar))
        XCTAssertEqual(relaunched.reminderTime, ReminderTime(hour: 18, minute: 45))
    }

    func testEnablingAsksForPermissionAndKeepsTheToggleOn() async {
        let center = FakeNotificationCenter()
        let store = AppStore(defaults: makeDefaults(), now: date(2026, 9, 20, 11),
                             reminders: CheckInReminder(center: center, calendar: calendar))

        await store.setRemindersEnabled(true)

        XCTAssertTrue(center.requestedAuthorization)
        XCTAssertTrue(store.remindersEnabled)
        XCTAssertEqual(fireDate(of: center.added.last), date(2026, 9, 20, 21, 30))
    }

    func testRefusedPermissionLeavesTheToggleOff() async {
        let center = FakeNotificationCenter()
        center.status = .denied
        center.grantsAuthorization = false
        let store = AppStore(defaults: makeDefaults(), now: date(2026, 9, 20, 11),
                             reminders: CheckInReminder(center: center, calendar: calendar))

        await store.setRemindersEnabled(true)

        XCTAssertFalse(store.remindersEnabled)
        XCTAssertEqual(store.reminderPermission, .denied)
        XCTAssertTrue(center.added.isEmpty)
    }

    func testTurningRemindersOffClearsThePendingRequest() async {
        let center = FakeNotificationCenter()
        let store = AppStore(defaults: makeDefaults(), now: date(2026, 9, 20, 11),
                             reminders: CheckInReminder(center: center, calendar: calendar))
        await store.setRemindersEnabled(true)
        XCTAssertFalse(center.added.isEmpty)

        await store.setRemindersEnabled(false)

        XCTAssertFalse(store.remindersEnabled)
        XCTAssertEqual(center.removedPending, [CheckInReminder.identifier])
    }

    // MARK: Tap routing

    /// A tap on the delivered nudge resolves to the check-in sheet through the
    /// `userInfo` the request carries; the presenter never sees the identifier.
    func testDeliveredNudgeCarriesTheCheckInRoute() {
        let request = CheckInReminder.request(fireDate: date(2025, 3, 10, 21, 30),
                                              calendar: calendar)
        XCTAssertEqual(NotificationRoute(userInfo: request.content.userInfo), .checkIn)
    }

    /// Payloads from another source — or from a build that never tagged them —
    /// must resolve to no route rather than open a sheet on a guess.
    func testUntaggedOrForeignPayloadResolvesToNoRoute() {
        XCTAssertNil(NotificationRoute(userInfo: [:]))
        XCTAssertNil(NotificationRoute(userInfo: [NotificationRoute.userInfoKey: "settings"]))
    }
}
