import SwiftUI
import UIKit

enum Theme {
    static let ink = adaptive(light: "29272F", dark: "F2EDF5")
    static let secondaryInk = adaptive(light: "706C78", dark: "B8B0BF")
    static let background = adaptive(light: "F6F2EA", dark: "17151B")
    static let card = adaptive(light: "FFFDF8", dark: "28242D")
    static let lavender = adaptive(light: "7258D6", dark: "C1A9FF")
    static let softLavender = adaptive(light: "EAE4FA", dark: "3B304F")
    static let green = adaptive(light: "4C9A72", dark: "86CDA5")
    static let successBackground = adaptive(light: "4C9A72", dark: "34785B")
    static let actionBackground = adaptive(light: "29272F", dark: "6B50BD")
    static let ratingEmpty = adaptive(light: "E9E5DD", dark: "45404B")
    static let streakText = adaptive(light: "B46A36", dark: "F0B985")
    static let streakBackground = adaptive(light: "F8E9DA", dark: "493427")
    static let cardShadow = Color.black

    private static func adaptive(light: String, dark: String) -> Color {
        Color(uiColor: UIColor { traits in UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light) })
    }
}

/// Screen-level brand type. Fixed point sizes would truncate at larger
/// accessibility sizes, so headings ride the semantic ramp with rounded design:
/// `.display` renders 34pt bold at Default, `.title` 28pt bold, both scaling.
enum Fonts {
    static let display = Font.system(.largeTitle, design: .rounded).weight(.bold)
    static let title = Font.system(.title, design: .rounded).weight(.bold)
}

/// The one hex parser in the app. Accepts "#RRGGBB", "RRGGBB", and stray
/// punctuation (trimmed to alphanumerics); unreadable strings become gray
/// rather than silently rendering black.
extension UIColor {
    fileprivate convenience init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        guard Scanner(string: cleaned).scanHexInt64(&value) else {
            self.init(red: 0.5, green: 0.5, blue: 0.5, alpha: 1)
            return
        }
        self.init(red: Double((value >> 16) & 0xFF) / 255,
                  green: Double((value >> 8) & 0xFF) / 255,
                  blue: Double(value & 0xFF) / 255, alpha: 1)
    }
}

extension Color {
    init(hex: String) {
        self.init(uiColor: UIColor(hex: hex))
    }
}

extension String {
    var isEmojiChoice: Bool { unicodeScalars.contains { !$0.isASCII } }
}

struct CardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(18)
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: Theme.cardShadow.opacity(0.12), radius: 16, y: 7)
    }
}

extension View {
    func daylilyCard() -> some View { modifier(CardModifier()) }

    /// Single-column reading measure. Daylily is a phone layout, so on iPad the
    /// content stays a comfortable centered column instead of stretching the
    /// calendar and cards across the full width of the display.
    func daylilyContentWidth() -> some View {
        frame(maxWidth: 640).frame(maxWidth: .infinity)
    }

    /// The 44pt minimum hit area, for controls whose visible shape is smaller
    /// than their tap target (text-only buttons, icon buttons, capsules).
    func daylilyTapTarget() -> some View {
        frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
    }
}
