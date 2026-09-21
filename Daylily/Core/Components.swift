import SwiftUI

// Shared presentation components used across screens.

/// The brand mark: the six-petal daylily from the app icon, drawn as a path so
/// screens show the flower rather than borrowing a weather glyph.
///
/// The outline is a polar flower traced from the icon art, not from a formula
/// improvised by eye: `reach(θ) = 0.708 + 0.292·|sin(3θ)|^1.08` of the radius.
/// The earlier `|cos(6θ)|` form swung through two lobes per petal, so the mark
/// drew twelve thin petals with a sharp spike between each pair instead of the
/// icon's six plump ones. Measured against the icon's own silhouette, this
/// reaches within 0.5% of the petal radius at every angle.
///
/// `steps` divides by six, so the sampled points land exactly on every petal
/// tip and every notch. The centre is punched out by filling even-odd, matching
/// the icon's hollow middle.
struct DaylilyShape: Shape {
    private let petals = 6
    private let steps = 240
    /// Notch radius as a fraction of the petal reach, measured from the icon.
    private let notchRatio: CGFloat = 0.708
    /// Exponent on the lobe. Above 1 it keeps the petals plump and the notches
    /// rounded rather than pinching them into points.
    private let shoulderBias: CGFloat = 1.08
    /// Centre hole radius as a fraction of the petal reach.
    private let centreHoleRatio: CGFloat = 0.22

    func path(in rect: CGRect) -> Path {
        let centre = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2

        var path = Path()
        for step in 0...steps {
            let progress = CGFloat(step) / CGFloat(steps)
            let angle = progress * 2 * .pi - .pi / 2
            // Half the petal count peaks once per petal, the first peak pointing
            // straight up, which is how the icon is drawn.
            let lobe = pow(abs(sin(CGFloat(petals) / 2 * angle)), shoulderBias)
            let reach = (notchRatio + (1 - notchRatio) * lobe) * radius
            let point = CGPoint(x: centre.x + cos(angle) * reach,
                                y: centre.y + sin(angle) * reach)
            if step == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath()

        let hole = radius * centreHoleRatio
        path.addEllipse(in: CGRect(x: centre.x - hole, y: centre.y - hole,
                                   width: hole * 2, height: hole * 2))
        return path
    }
}

/// Filled, tintable, and resolution independent: `foregroundStyle` colours it
/// like any other glyph, so it works in both appearances and while disabled.
struct DaylilyMark: View {
    var body: some View {
        DaylilyShape()
            .fill(style: FillStyle(eoFill: true))
            .aspectRatio(1, contentMode: .fit)
    }
}

struct SectionTitle: View {
    let title: LocalizedStringKey
    let detail: LocalizedStringKey

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.title3.bold()).foregroundStyle(Theme.ink)
            Text(detail).font(.caption).foregroundStyle(Theme.secondaryInk)
        }
    }
}

struct SymbolBadge: View {
    let symbol: String
    let color: Color
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(color.opacity(0.14))
                .frame(width: 46, height: 46)
            Image(systemName: symbol).font(.system(size: 19, weight: .semibold)).foregroundStyle(color)
        }
    }
}
