import SwiftUI
import TycoonContent
import TycoonEngine

/// "Hold the Category" on the market report: every topic as a category the
/// studio either holds or does not, ordered by standing.
///
/// The row is deliberately three facts wide — what your name is worth here,
/// what the market is doing, and who else is in it — because those are the
/// three things the decision to defend a category is made of. The fourth,
/// the forward read, appears only in the categories the studio holds: that
/// asymmetry is the whole reward, so an unheld row says what it would take
/// rather than showing nothing.
///
/// Read-only, like the rest of this screen. Rows push the existing topic
/// detail through the report's own `TopicRoute`.
struct CategoryStripCard: View {
    let engine: GameEngine

    private var categories: [CategorySnapshot] {
        MarketAnalysis.categories(
            state: engine.state, content: engine.content, balance: engine.balance
        )
    }

    private var held: Int {
        categories.filter(\.holdsCategory).count
    }

    var body: some View {
        let categories = self.categories
        CardView("Your categories", systemImage: "flag.fill") {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text(summary(categories))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(spacing: 0) {
                    ForEach(Array(categories.enumerated()), id: \.element.id) { index, category in
                        NavigationLink(value: TopicRoute(topicID: category.id)) {
                            CategoryRow(
                                category: category,
                                driftSigma: engine.balance.market.driftSigma
                            )
                        }
                        .buttonStyle(.plain)
                        if index < categories.count - 1 {
                            Divider()
                        }
                    }
                }

                Text("Standing is rent, not a trophy: shipping, patching and campaigning here "
                    + "build it, and every week with nothing on the market here wears it down.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func summary(_ categories: [CategorySnapshot]) -> String {
        let threshold = Int(engine.balance.market.standing.forecastThreshold.rounded())
        guard let best = categories.first, best.standing > 0 else {
            return "You have no standing anywhere yet. Ship into a topic and it starts here."
        }
        if held == 0 {
            return "\(best.topic.name) is your strongest category at \(best.standingLabel). "
                + "Reach \(threshold) and you get to read that market weeks ahead."
        }
        let word = held == 1 ? "category" : "categories"
        return "You hold \(held) \(word). "
            + "In those, and nowhere else, you can see where demand is heading."
    }
}

// MARK: - Row

private struct CategoryRow: View {
    let category: CategorySnapshot
    let driftSigma: Double

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: category.topic.iconSystemName)
                    .font(.subheadline)
                    .foregroundStyle(category.tint)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: Theme.Spacing.xs) {
                        Text(category.topic.name)
                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                            .lineLimit(1)
                        if category.holdsCategory {
                            Image(systemName: "eye.fill")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(Theme.positiveCash)
                        }
                    }
                    StandingBar(fraction: category.standingFraction, tint: category.tint)
                    Text("\(category.tier) · \(category.fieldLabel)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: Theme.Spacing.sm)

                VStack(alignment: .trailing, spacing: 2) {
                    Text(category.standingLabel)
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(category.tint)
                        .contentTransition(.numericText())
                    HStack(spacing: 2) {
                        Image(systemName: category.market.direction.systemImage)
                            .font(.caption2.weight(.bold))
                        Text(category.market.multiplierLabel)
                            .font(.caption2)
                            .monospacedDigit()
                    }
                    .foregroundStyle(category.market.direction.tint)
                }
                .frame(width: 62, alignment: .trailing)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }

            forwardRead
        }
        .padding(.vertical, Theme.Spacing.sm)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(.isButton)
    }

    @ViewBuilder private var forwardRead: some View {
        if let read = category.forwardRead(driftSigma: driftSigma) {
            HStack(alignment: .top, spacing: Theme.Spacing.xs) {
                Image(systemName: "binoculars.fill")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Theme.positiveCash)
                Text(read)
                    .font(.caption2)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.leading, 24 + Theme.Spacing.md)
        } else if category.standing > 0 {
            Text("\(Int((category.threshold - category.standing).rounded())) more standing "
                + "to read this market ahead.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .padding(.leading, 24 + Theme.Spacing.md)
        }
    }

    private var accessibilityLabel: String {
        var summary = category.accessibilitySummary
        if let read = category.forwardRead(driftSigma: driftSigma) {
            summary += ". Forward read: \(read)"
        }
        return summary
    }
}

/// The standing meter. Deliberately small: standing is a running total, not
/// a score, and the number beside it is the precise reading.
struct StandingBar: View {
    let fraction: Double
    let tint: Color
    var height: CGFloat = 4

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Theme.chipBackground)
                Capsule()
                    .fill(tint)
                    .frame(width: max(0, geometry.size.width * min(1, max(0, fraction))))
            }
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }
}
