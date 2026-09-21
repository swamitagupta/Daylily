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
        app.tabBars.buttons["Patterns"].tap()

        let reorder = app.buttons["Reorder"]
        XCTAssertTrue(reorder.waitForExistence(timeout: 10), "reorder is offered once there are graphs to order")
        let before = cardLabels(app)
        XCTAssertGreaterThan(before.count, 1, "the seed provides more than one graph")
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
