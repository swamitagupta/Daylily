import XCTest

/// A tap on the reminder must open today's check-in form, not merely bring the
/// app to the front. Scheduling and the routed payload are covered by
/// `CheckInReminderTests`; what only the simulator can prove is the chain the
/// user walks: banner → system tap response → presenter route → Home sheet.
@MainActor
final class ReminderTapUITests: XCTestCase {
    private let checkInTitle = "How was your day?"
    private let reminderTitle = "A minute for today?"

    func testTappingTheReminderOpensTheCheckInForm() {
        let app = XCUIApplication()
        app.launchArguments += ["-DaylilyDebugDeliverReminder", "YES"]
        app.launch()

        // The permission prompt is decided once per simulator: accept it when
        // it appears, and carry on when an earlier run already settled it.
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let allow = springboard.alerts.buttons["Allow"]
        if allow.waitForExistence(timeout: 5) { allow.tap() }

        // The banner is drawn by Springboard itself, not the app; its element
        // carries the notification title in the accessibility label.
        let banner = springboard.buttons
            .matching(NSPredicate(format: "label CONTAINS %@", reminderTitle))
            .firstMatch
        XCTAssertTrue(banner.waitForExistence(timeout: 20),
                      "the debug launch re-delivers the reminder banner while the app is open")
        banner.tap()

        XCTAssertTrue(app.staticTexts[checkInTitle].waitForExistence(timeout: 10),
                      "tapping the reminder must open the check-in sheet, not just open the app")
        app.terminate()
    }
}
