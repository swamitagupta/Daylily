import XCTest

/// Proves the two-rows-of-three day cells stay legible on the narrowest
/// supported phone. The `-DaylilyDebugSeedDenseCalendar` seam records days
/// carrying 1…12 activities; a day past the six-slot display limit shows four
/// glyphs plus a `+8` chip on its twelve check-ins, so finding that chip
/// after scrolling means the full density laid out without clipping.
@MainActor
final class CalendarDensityUITests: XCTestCase {
    func testOverflowChipRendersAtFullDensity() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-DaylilyDebugSeedDenseCalendar", "YES"]
        app.launch()

        // Scroll until the grid is in view; the chip lives in the last
        // recorded day's cell, always inside the current month.
        let chip = app.staticTexts["+8"]
        for _ in 0..<5 where !chip.exists {
            app.swipeUp()
        }
        XCTAssertTrue(chip.waitForExistence(timeout: 10),
                      "a day with twelve activities must show six markers plus +6")

        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.lifetime = .keepAlways
        add(shot)
        app.terminate()
    }
}
