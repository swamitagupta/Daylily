import Foundation

/// The icons and colours an item may be given, in one place.
///
/// The editor's grid and `IconSuggestion` both read this list, because a
/// suggester that can return a symbol the grid does not offer would leave the
/// editor showing an icon nobody can select back — the pre-existing "Current
/// icon" row exists for legacy payloads, not for suggestions.
///
/// Titles are resolved through `String(localized:)` at construction; the fields
/// are plain `String`s so the whole catalog is `Sendable` and the suggestion
/// tests can read the names the user sees.
enum IconCatalog {
    enum Kind: Sendable {
        case activity, outcome
    }

    struct IconChoice: Identifiable, Sendable {
        let title: String
        let symbol: String
        var id: String { symbol }

        init(_ title: String.LocalizationValue, _ symbol: String) {
            self.title = String(localized: title)
            self.symbol = symbol
        }
    }

    struct ColorChoice: Identifiable, Sendable {
        let name: String
        let hex: String
        var id: String { hex }

        init(name: String.LocalizationValue, hex: String) {
            self.name = String(localized: name)
            self.hex = hex
        }
    }

    static let activityIcons: [IconChoice] = [
        .init("Office", "building.2.fill"), .init("Tennis", "tennis.racket"),
        .init("Walk", "figure.walk"), .init("Run", "figure.run"),
        .init("Meditate", "figure.mind.and.body"), .init("Cycle", "bicycle"),
        .init("Workout", "figure.strengthtraining.traditional"), .init("Swim", "figure.pool.swim"),
        .init("Yoga", "figure.yoga"), .init("Hike", "mountain.2.fill"),
        .init("Read", "books.vertical.fill"), .init("Write", "pencil.line"),
        .init("Work", "laptopcomputer"), .init("Learn", "graduationcap.fill"),
        .init("Coffee", "cup.and.saucer.fill"), .init("Cook", "frying.pan.fill"),
        .init("Eat well", "fork.knife"), .init("Water", "drop.fill"),
        .init("Create", "paintpalette.fill"), .init("Music", "music.note"),
        .init("Clean", "sparkles"), .init("Sleep", "bed.double.fill"),
        .init("Nature", "leaf.fill"), .init("Outside", "sun.max.fill"),
        .init("Friends", "person.2.fill"), .init("Family", "house.fill"),
        .init("Pet", "pawprint.fill"), .init("Travel", "airplane"),
        .init("Drive", "car.fill"), .init("Games", "gamecontroller.fill"),
        .init("Shopping", "bag.fill"), .init("Phone", "iphone"),
        .init("Talk", "bubble.left.fill"), .init("Medicine", "cross.case.fill"),
        .init("Self-care", "heart.fill"), .init("Rest", "moon.fill")
    ]

    static let outcomeIcons: [IconChoice] = [
        .init("Happy", "face.smiling.fill"), .init("Calm", "wind"),
        .init("Energy", "bolt.fill"), .init("Peaceful", "leaf.fill"),
        .init("Loved", "heart.fill"), .init("Connected", "person.2.fill"),
        .init("Confident", "star.fill"), .init("Motivated", "flame.fill"),
        .init("Focused", "scope"), .init("Creative", "paintbrush.pointed.fill"),
        .init("Grateful", "hands.sparkles.fill"), .init("Hopeful", "sun.max.fill"),
        .init("Rested", "moon.stars.fill"), .init("Sleepy", "bed.double.fill"),
        .init("Anxious", "waveform.path"), .init("Sad", "cloud.rain.fill"),
        .init("Stressed", "exclamationmark.circle.fill"), .init("Angry", "bolt.heart.fill"),
        .init("Thoughtful", "brain.head.profile"), .init("Uncertain", "questionmark.circle.fill"),
        .init("Balanced", "circle.lefthalf.filled"), .init("Growing", "tree.fill"),
        .init("Bright", "sparkles"), .init("Good", "checkmark.seal.fill")
    ]

    /// The five accents, in the order they are offered; `PaletteSuggestion`
    /// breaks ties by this order so the choice is never arbitrary.
    static let colorChoices: [ColorChoice] = [
        ColorChoice(name: "Purple", hex: "7258D6"),
        ColorChoice(name: "Green", hex: "4C9A72"),
        ColorChoice(name: "Orange", hex: "E39452"),
        ColorChoice(name: "Rose", hex: "D66B69"),
        ColorChoice(name: "Blue", hex: "4A8DA8")
    ]

    static func icons(for kind: Kind) -> [IconChoice] {
        kind == .activity ? activityIcons : outcomeIcons
    }

    static func contains(symbol: String, kind: Kind) -> Bool {
        icons(for: kind).contains { $0.symbol == symbol }
    }

    /// What a new item shows before its name says anything, and what it falls
    /// back to when the name stays unreadable.
    static func defaultSymbol(for kind: Kind) -> String {
        kind == .activity ? "sparkles" : "face.smiling.fill"
    }

    /// The accent a new item starts on, before the palette suggestion runs.
    static var defaultHex: String { colorChoices[0].hex }
}
