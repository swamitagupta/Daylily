import XCTest

/// Reorder mode has no unit-testable seam. The arrangement logic itself is
/// covered in `AppStoreTests`; what broke was the wiring — one tap on Reorder
/// fired the Create graph button and left the editor covering the list — and
/// then the mode's own shape, which used to shove every graph down the screen.
@MainActor
final class GraphReorderUITests: XCTestCase {
    private let graphEditorTitle = "New graph"

    /// Cards top to bottom, which is the stored order. Only a card carries an
    /// "Open …" label, so rows inside the graph editor never leak in.
    private func cards(_ app: XCUIApplication) -> [XCUIElement] {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Open '"))
            .allElementsBoundByIndex
            .sorted { $0.frame.minY < $1.frame.minY }
    }

    private func cardLabels(_ app: XCUIApplication) -> [String] { cards(app).map(\.label) }

    /// The outcome name each card is titled with, read off the card's own label.
    private func cardNames(_ app: XCUIApplication) -> [String] {
        cards(app).map { String($0.label.dropFirst("Open ".count).prefix { $0 != " " }) }
    }

    /// Where each card's title sits, by label rather than identifier.
    private func titlePositions(_ app: XCUIApplication, _ names: [String]) -> [String: CGFloat] {
        names.reduce(into: [:]) { positions, name in
            let title = app.staticTexts.matching(NSPredicate(format: "label == %@", name)).firstMatch
            positions[name] = title.exists ? title.frame.minY : -1
        }
    }

    private func moveDownButtons(_ app: XCUIApplication) -> XCUIElementQuery {
        app.buttons.matching(NSPredicate(format: "label == 'Move down'"))
    }

    func testReorderingMovesOneCardWithoutDisturbingThePage() {
        let app = XCUIApplication()
        app.launch()

        // The starter set is one activity and one outcome, and the editor refuses a
        // graph identical to one you already have, so a second card needs a second
        // activity. Name it per run: a simulator holding earlier state must still
        // yield a distinct activity, and therefore a distinct graph.
        let activityName = "Read \(Int(Date().timeIntervalSince1970) % 100000)"

        app.tabBars.buttons["Customize"].tap()
        app.buttons.matching(NSPredicate(format: "label == 'Add'")).element(boundBy: 0).tap()
        XCTAssertTrue(app.navigationBars["Add activity"].waitForExistence(timeout: 5))
        let nameField = app.textFields["e.g. Read"]
        nameField.tap()
        nameField.typeText(activityName)
        app.buttons["Save"].tap()

        app.tabBars.buttons["Patterns"].tap()
        app.buttons["Create graph"].tap()
        XCTAssertTrue(app.navigationBars[graphEditorTitle].waitForExistence(timeout: 5))
        app.buttons["Happiness, not selected"].tap()
        app.buttons["\(activityName), not selected"].tap()
        app.buttons["Create"].tap()
        XCTAssertFalse(app.navigationBars[graphEditorTitle].waitForExistence(timeout: 3),
                       "the graph editor should close once Create is tapped")

        let reorder = app.buttons["Reorder"]
        XCTAssertTrue(reorder.waitForExistence(timeout: 10), "reorder is offered once there are graphs to order")
        XCTAssertTrue(reorder.isHittable,
                      "Reorder must be tappable: frame=\(reorder.frame) app=\(app.frame) "
                        + "editorOpen=\(app.navigationBars[graphEditorTitle].exists) "
                        + "keyboards=\(app.keyboards.count) sheets=\(app.sheets.count)")
        let before = cardLabels(app)
        XCTAssertGreaterThan(before.count, 1, "more than one graph to order")
        let names = cardNames(app)
        let placed = titlePositions(app, names)

        reorder.tap()

        XCTAssertTrue(app.buttons["Done"].waitForExistence(timeout: 5), "Reorder enters reorder mode")
        XCTAssertFalse(app.navigationBars[graphEditorTitle].exists,
                       "tapping Reorder must not open the graph editor")
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "label == 'Reorder'")).count, 0,
                       "the mode is the arrows alone: no system drag handles")
        for (name, position) in placed {
            XCTAssertEqual(titlePositions(app, names)[name] ?? -1, position, accuracy: 0.5,
                           "entering reorder mode must not move \(name)")
        }
        XCTAssertEqual(moveDownButtons(app).count, before.count, "one set of move controls per graph")

        moveDownButtons(app).element(boundBy: 0).tap()
        app.buttons["Done"].firstMatch.tap()

        var expected = before
        expected.swapAt(0, 1)
        XCTAssertEqual(cardLabels(app), expected, "one tap moves one position")

        app.terminate()
        app.launch()
        app.tabBars.buttons["Patterns"].tap()
        XCTAssertTrue(app.buttons["Reorder"].waitForExistence(timeout: 10))
        XCTAssertEqual(cardLabels(app), expected, "the arrangement survives a relaunch")
    }
}
