import XCTest

/// The suggestion's own rules live in `IconSuggestionTests`. What only the
/// running app can show is the wiring around them: that the sheet waits for the
/// name to settle before choosing, that the subtitle admits where the icon came
/// from and stops claiming it once the user disagrees, and that a tap on the
/// grid outranks anything typed afterwards.
@MainActor
final class IconSuggestionUITests: XCTestCase {
    private let suggestionNote = "Suggested from the name. Tap to change"

    private func openAddActivity(_ app: XCUIApplication) -> XCUIElement {
        app.tabBars.buttons["Customize"].tap()
        app.buttons.matching(NSPredicate(format: "label == 'Add'")).element(boundBy: 0).tap()
        XCTAssertTrue(app.navigationBars["Add activity"].waitForExistence(timeout: 5))
        let field = app.textFields["e.g. Read"]
        field.tap()
        return field
    }

    /// Matched on a prefix: a selected SwiftUI button reads its state out in the
    /// accessibility label, so an exact match would only work while unselected.
    private func icon(_ app: XCUIApplication, _ title: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", title)).firstMatch
    }

    private func dismissKeyboard(_ app: XCUIApplication) {
        // The keyboard offers its own Done as well as the toolbar item, so take
        // the first match rather than demanding a unique one.
        let done = app.buttons.matching(NSPredicate(format: "label == 'Done'")).firstMatch
        if done.exists { done.tap() }
    }

    func testNameChoosesTheIconAndAManualPickEndsTheGuessing() {
        let app = XCUIApplication()
        app.launch()

        let nameField = openAddActivity(app)
        nameField.typeText("Morning walk")
        dismissKeyboard(app)

        XCTAssertTrue(app.staticTexts[suggestionNote].waitForExistence(timeout: 5),
                      "the sheet should say the icon came from the name")
        XCTAssertTrue(icon(app, "Walk").isSelected, "a morning walk should choose the walk icon")

        icon(app, "Run").tap()
        XCTAssertTrue(app.staticTexts["Tap to choose"].waitForExistence(timeout: 5),
                      "the subtitle must stop claiming the suggestion once the user disagrees")
        XCTAssertTrue(icon(app, "Run").isSelected)
        XCTAssertFalse(icon(app, "Walk").isSelected, "one icon is chosen at a time")

        // Typing more must not undo the icon the user just picked.
        nameField.tap()
        nameField.typeText("ing")
        dismissKeyboard(app)
        XCTAssertTrue(icon(app, "Run").isSelected, "a manual pick outranks the name from then on")
        XCTAssertFalse(app.staticTexts[suggestionNote].exists)

        app.terminate()
    }

    func testNameWithoutMeaningKeepsTheDefaultIcon() {
        let app = XCUIApplication()
        app.launch()

        let nameField = openAddActivity(app)
        nameField.typeText("Zorblax")
        dismissKeyboard(app)

        XCTAssertTrue(app.staticTexts["Tap to choose"].exists,
                      "a name nothing was read from must not be claimed as a suggestion")
        // `sparkles` is the activity default; the grid lists it under "Clean".
        XCTAssertTrue(icon(app, "Clean").isSelected, "an unreadable name keeps the default icon")

        app.terminate()
    }
}
