import SwiftUI
import TycoonEngine

// MARK: Iteration 9 — L2 (a life score)

/// The score itself, drawn as the game draws a number that matters: a
/// bitmap figure on pixel paper with "/100" beside it.
///
/// Used at three sizes — the Life tab's card, the screen's header, and
/// the biography's life card — so the number is the same object wherever
/// the player meets it.
struct LifeScoreFigure: View {
    let score: Int
    var scale: CGFloat = 5

    /// Bands, not a gradient: the score is a grade, and a founder should
    /// be able to tell at a glance which of the four they are in.
    static func tint(_ score: Int) -> Color {
        switch score {
        case ..<30: Theme.negativeCash
        case ..<55: Theme.warning
        case ..<80: Theme.pixelAccent
        default: Theme.positiveCash
        }
    }

    /// The one word under the number.
    static func verdict(_ score: Int) -> String {
        switch score {
        case ..<20: "There is nothing here but the company."
        case ..<35: "A life on hold."
        case ..<55: "Getting by."
        case ..<70: "A life, around the edges of the work."
        case ..<85: "A life worth having."
        default: "You got both."
        }
    }

    var body: some View {
        HStack(alignment: .lastTextBaseline, spacing: Theme.Spacing.xs) {
            PixelText(text: "\(score)", scale: scale, color: Self.tint(score))
            // Deliberately about half the figure's scale: "out of a
            // hundred" is context, not the number.
            PixelText(
                text: "/100",
                scale: Swift.max(2, (scale * 0.45).rounded(.down)),
                color: Theme.pixelInk.opacity(0.5)
            )
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Life score \(score) of 100")
    }
}

/// One component of the breakdown: the label, the points, and a bar.
///
/// The penalty line has no bar — there is nothing to fill — so it draws
/// as a red figure with its facts beside it instead.
struct LifeScoreBar: View {
    let component: LifeScore.Component
    /// The bar's own detail line, off on the compact card.
    var showsDetail: Bool = true

    private var isPenalty: Bool { component.max <= 0 }

    private var tint: Color {
        if isPenalty { return Theme.negativeCash }
        switch component.fraction {
        case ..<0.34: return Theme.negativeCash
        case ..<0.67: return Theme.warning
        default: return Theme.positiveCash
        }
    }

    private var pointsLabel: String {
        isPenalty
            ? "\(Int(component.points.rounded()))"
            : "\(Int(component.points.rounded()))/\(Int(component.max.rounded()))"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack(spacing: Theme.Spacing.sm) {
                Text(component.label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer(minLength: Theme.Spacing.sm)
                Text(pointsLabel)
                    .font(Theme.Typography.number(.caption))
                    .foregroundStyle(tint)
                    .contentTransition(.numericText())
                    .animation(Theme.Motion.valueChange, value: component.points)
            }
            if !isPenalty {
                Gauge(value: component.fraction) { EmptyView() }
                    .gaugeStyle(.accessoryLinearCapacity)
                    .tint(tint)
                    .animation(Theme.Motion.valueChange, value: component.fraction)
            }
            if showsDetail {
                Text(component.detail)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            isPenalty
                ? "\(component.label), \(pointsLabel) points. \(component.detail)"
                : "\(component.label), \(pointsLabel). \(component.detail)"
        )
    }
}

/// The whole breakdown as a stack of bars.
struct LifeScoreBreakdown: View {
    let components: [LifeScore.Component]
    var showsDetail: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            ForEach(components) { component in
                LifeScoreBar(component: component, showsDetail: showsDetail)
            }
        }
    }
}

/// The number and its bars in one row, for a screen that is mostly about
/// something else — the biography's life card.
struct LifeScoreSummaryRow: View {
    let score: Int
    let components: [LifeScore.Component]

    /// The bitmap kicker under the figure. Localized, because it is a
    /// word rather than a glyph — and PixelFont has no lowercase and no
    /// accents, so a translation has to survive being upper-cased and
    /// stripped to ASCII.
    static let kicker = String(
        localized: "LIFE",
        comment: "Kicker under the life score on the biography's life card. Drawn in the pixel bitmap font: uppercase ASCII only, no accents, keep it short."
    )

    var body: some View {
        HStack(alignment: .center, spacing: Theme.Spacing.md) {
            PixelPanel(thickness: 3, contentPadding: Theme.Spacing.sm) {
                VStack(alignment: .leading, spacing: 2) {
                    LifeScoreFigure(score: score, scale: 4)
                    PixelText(text: Self.kicker, scale: 1, color: Theme.pixelInk.opacity(0.6))
                }
            }
            .fixedSize()
            VStack(alignment: .leading, spacing: 3) {
                Text(LifeScoreFigure.verdict(score))
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
                Text(
                    components
                        .filter { $0.max > 0 && $0.points >= $0.max * 0.75 }
                        .map(\.label)
                        .joined(separator: " · ")
                )
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
    }
}
