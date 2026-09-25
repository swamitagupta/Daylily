import Foundation

/// Picks a colour for a new item: whichever accent the existing items use least.
///
/// The colour carries no meaning in Daylily — it is how a day's icons stay
/// distinguishable in the calendar and how one line is told from another in a
/// chart — so new items should not all arrive in the same accent. Counting what
/// is already in use spreads them without asking the user to think about it.
enum PaletteSuggestion {
    /// Hexes outside the palette (an item whose colour predates it) are ignored
    /// rather than counted, since they can never be the answer.
    static func leastUsedHex(usedHexes: [String]) -> String {
        var counts: [String: Int] = [:]
        for hex in usedHexes {
            counts[normalized(hex), default: 0] += 1
        }

        var best = IconCatalog.colorChoices[0].hex
        var bestCount = Int.max
        // Strictly less than: a tie keeps the earlier accent, so the first new
        // item is Purple and the sixth repeats it rather than choosing at random.
        for choice in IconCatalog.colorChoices where (counts[normalized(choice.hex)] ?? 0) < bestCount {
            best = choice.hex
            bestCount = counts[normalized(choice.hex)] ?? 0
        }
        return best
    }

    private static func normalized(_ hex: String) -> String {
        hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted).uppercased()
    }
}
