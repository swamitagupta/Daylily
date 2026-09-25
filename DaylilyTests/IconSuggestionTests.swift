import XCTest
@testable import Daylily

final class IconSuggestionTests: XCTestCase {
    // MARK: - Reading a name

    func testActivityNameChoosesItsOwnIcon() {
        let cases: [(String, String)] = [
            ("Morning walk", "figure.walk"),
            ("Walk to the shops", "figure.walk"),
            ("Gym session", "figure.strengthtraining.traditional"),
            ("Play Tennis", "tennis.racket"),
            ("Coffee with Sam", "cup.and.saucer.fill"),
            ("Reading", "books.vertical.fill"),
            ("5k run", "figure.run"),
            ("Slept 8 hours", "bed.double.fill"),
            ("Called Mum", "iphone"),
            ("Therapy appointment", "bubble.left.fill"),
            ("Took medication", "cross.case.fill"),
            ("Water", "drop.fill")
        ]
        for (name, symbol) in cases {
            XCTAssertEqual(IconSuggestion.symbol(for: name, kind: .activity), symbol, "for \(name)")
        }
    }

    func testOutcomeNameChoosesItsOwnIcon() {
        let cases: [(String, String)] = [
            ("Energy", "bolt.fill"),
            ("Anxiety", "waveform.path"),
            ("Feeling anxious", "waveform.path"),
            ("Happiness", "face.smiling.fill"),
            ("Motivated", "flame.fill"),
            ("Couldn't sleep", "bed.double.fill")
        ]
        for (name, symbol) in cases {
            XCTAssertEqual(IconSuggestion.symbol(for: name, kind: .outcome), symbol, "for \(name)")
        }
    }

    /// The two kinds hold separate tables, so a word that only means something
    /// as an activity must not resolve against an outcome icon or the reverse.
    func testTablesDoNotLeakAcrossKinds() {
        XCTAssertEqual(IconSuggestion.symbol(for: "Gym", kind: .activity), "figure.strengthtraining.traditional")
        XCTAssertNil(IconSuggestion.symbol(for: "Gym", kind: .outcome))
        XCTAssertEqual(IconSuggestion.symbol(for: "Anxiety", kind: .outcome), "waveform.path")
        XCTAssertNil(IconSuggestion.symbol(for: "Anxiety", kind: .activity))
    }

    func testNameWithoutMeaningHasNoSuggestion() {
        for name in ["", "   ", "x", "Zorblax", "Qwerty", "?!"] {
            XCTAssertNil(IconSuggestion.symbol(for: name, kind: .activity), "for \(name)")
            XCTAssertNil(IconSuggestion.symbol(for: name, kind: .outcome), "for \(name)")
        }
    }

    // MARK: - Matching rules

    func testCaseAccentsAndPunctuationDoNotMatter() {
        for name in ["walk", "Walk", "WALK", "Walking!", "  walk  ", "walk.", "wálk"] {
            XCTAssertEqual(IconSuggestion.symbol(for: name, kind: .activity), "figure.walk", "for \(name)")
        }
    }

    /// An exact word outranks a longer word that merely shares a prefix, which
    /// is what keeps "Workout" off the laptop and "Work" off the dumbbell.
    func testExactWordOutranksSharedPrefix() {
        XCTAssertEqual(IconSuggestion.symbol(for: "Workout", kind: .activity),
                       "figure.strengthtraining.traditional")
        XCTAssertEqual(IconSuggestion.symbol(for: "Work", kind: .activity), "laptopcomputer")
    }

    /// The first word that matches decides, so a name that leads with the
    /// activity is not filed under whatever longer word follows it.
    func testFirstWordWinsOverALongerMatchLater() {
        XCTAssertEqual(IconSuggestion.symbol(for: "Walk to the shops", kind: .activity), "figure.walk")
        XCTAssertEqual(IconSuggestion.symbol(for: "Run to the store", kind: .activity), "figure.run")
        XCTAssertEqual(IconSuggestion.symbol(for: "Coffee and a chat", kind: .activity), "cup.and.saucer.fill")
    }

    func testSuggestionIsDeterministic() {
        let first = IconSuggestion.symbol(for: "Morning walk with the dog", kind: .activity)
        for _ in 0..<50 {
            XCTAssertEqual(IconSuggestion.symbol(for: "Morning walk with the dog", kind: .activity), first)
        }
    }

    // MARK: - The catalog contract

    /// Every icon the grid offers must be reachable by typing its own name: a
    /// table that had drifted from the catalog would otherwise suggest an icon
    /// the user can never select again.
    func testEveryActivityIconIsReachableFromItsOwnTitle() {
        for choice in IconCatalog.activityIcons {
            XCTAssertEqual(IconSuggestion.symbol(for: choice.title, kind: .activity), choice.symbol,
                           "typing \(choice.title) should reach \(choice.symbol)")
        }
    }

    func testEveryOutcomeIconIsReachableFromItsOwnTitle() {
        for choice in IconCatalog.outcomeIcons {
            XCTAssertEqual(IconSuggestion.symbol(for: choice.title, kind: .outcome), choice.symbol,
                           "typing \(choice.title) should reach \(choice.symbol)")
        }
    }

    func testEverySuggestionIsAnIconTheGridOffers() {
        let names = ["Morning walk", "Gym", "Coffee", "Therapy", "Medicine", "Reading", "Zorblax"]
        for name in names {
            if let symbol = IconSuggestion.symbol(for: name, kind: .activity) {
                XCTAssertTrue(IconCatalog.contains(symbol: symbol, kind: .activity), "\(name) → \(symbol)")
            }
            if let symbol = IconSuggestion.symbol(for: name, kind: .outcome) {
                XCTAssertTrue(IconCatalog.contains(symbol: symbol, kind: .outcome), "\(name) → \(symbol)")
            }
        }
    }

    // MARK: - Palette

    func testUnusedPaletteStartsAtTheFirstAccent() {
        XCTAssertEqual(PaletteSuggestion.leastUsedHex(usedHexes: []), IconCatalog.colorChoices[0].hex)
    }

    func testPalettePicksTheLeastUsedAccent() {
        let purple = IconCatalog.colorChoices[0].hex
        let green = IconCatalog.colorChoices[1].hex
        XCTAssertEqual(PaletteSuggestion.leastUsedHex(usedHexes: [purple, purple, green]), IconCatalog.colorChoices[2].hex)
        XCTAssertEqual(PaletteSuggestion.leastUsedHex(usedHexes: [purple, green]), IconCatalog.colorChoices[2].hex)
    }

    func testTiesAndUnknownHexesResolveToTheFirstUnusedAccent() {
        // Every accent used once; the tie goes back to the first in the palette
        // rather than picking arbitrarily.
        let all = IconCatalog.colorChoices.map(\.hex)
        XCTAssertEqual(PaletteSuggestion.leastUsedHex(usedHexes: all), all[0])
        // A colour that predates the palette is not a candidate, so it neither
        // wins nor pushes the count of a real accent up.
        XCTAssertEqual(PaletteSuggestion.leastUsedHex(usedHexes: ["123456"]), all[0])
    }

    func testPaletteIgnoresHexFormatting() {
        let purple = IconCatalog.colorChoices[0].hex
        XCTAssertEqual(PaletteSuggestion.leastUsedHex(usedHexes: ["#\(purple.lowercased())"]),
                       IconCatalog.colorChoices[1].hex)
    }
}
