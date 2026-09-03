import SwiftUI
import TycoonEngine

/// The founder's four wellbeing meters (0–100) with the resulting output
/// estimate. Meter tints follow the danger bands; the output line mirrors
/// the engine's design formula so the player can see why crunch stops
/// paying off.
struct LifeMetersCard: View {
    let engine: GameEngine

    @Environment(GameShell.self) private var injectedShell: GameShell?
    /// See `GameShell.shared`: read optionally, because SwiftUI
    /// updates this property for presented content before the
    /// environment is installed and the non-optional form traps there.
    private var shell: GameShell { injectedShell ?? .shared }

    var body: some View {
        let state = engine.state
        let life = state.life
        let hasCold = life.hasCold(day: state.day)
        let isAway = life.isAway(day: state.day)
        // Each meter's change since the week began, so a slide is never
        // silent. Nothing to compare against until the first report.
        let start = shell.weekStartMeters

        CardView("Wellbeing", systemImage: "figure.mind.and.body") {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                MeterRow(label: "Energy", systemImage: "bolt.fill", value: life.meters.energy,
                         delta: start.map { life.meters.energy - $0.energy })
                MeterRow(label: "Health", systemImage: "heart.fill", value: life.meters.health,
                         delta: start.map { life.meters.health - $0.health })
                MeterRow(label: "Mood", systemImage: "face.smiling", value: life.meters.mood,
                         delta: start.map { life.meters.mood - $0.mood })
                MeterRow(label: "Relationships", systemImage: "person.2.heart", value: life.meters.relationships,
                         delta: start.map { life.meters.relationships - $0.relationships })

                Divider()

                HStack(spacing: Theme.Spacing.sm) {
                    OutputLine(multiplier: founderOutputEstimate(state: state, balance: engine.balance), isAway: isAway)
                    Spacer(minLength: 0)
                    if hasCold {
                        ColdChip()
                    }
                }
            }
        }
    }
}

// MARK: - Meter row

private struct MeterRow: View {
    let label: String
    let systemImage: String
    let value: Double
    /// Change since the week began, when known.
    var delta: Double?

    private var rounded: Int { Int(value.rounded()) }
    private var tint: Color { lifeMeterTint(value) }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: systemImage)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(tint)
                    .frame(width: 18)
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if let delta, abs(delta) >= 0.5 {
                    Text((delta > 0 ? "+" : "") + delta.formatted(.number.precision(.fractionLength(0)).locale(Theme.gameLocale)))
                        .font(Theme.Typography.number(.caption2))
                        .foregroundStyle(delta > 0 ? Theme.positiveCash : Theme.negativeCash)
                        .contentTransition(.numericText())
                        .animation(Theme.Motion.valueChange, value: delta)
                        .accessibilityLabel("\(delta > 0 ? "up" : "down") \(Int(abs(delta).rounded())) this week")
                }
                Text("\(rounded)")
                    .font(Theme.Typography.number(.caption))
                    .foregroundStyle(tint)
                    .contentTransition(.numericText())
                    .animation(Theme.Motion.valueChange, value: rounded)
            }
            Gauge(value: min(max(value / 100, 0), 1)) {
                EmptyView()
            }
            .gaugeStyle(.accessoryLinearCapacity)
            .tint(tint)
            .animation(Theme.Motion.valueChange, value: value)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(label) \(rounded) of 100"
                + (delta.map { abs($0) >= 0.5 ? ", \($0 > 0 ? "up" : "down") \(Int(abs($0).rounded())) this week" : "" } ?? "")
        )
    }
}

// MARK: - Output line

private struct OutputLine: View {
    let multiplier: Double
    let isAway: Bool

    private var text: String {
        "Founder output ×" + multiplier.formatted(.number.precision(.fractionLength(2)))
    }

    private var tint: Color {
        if isAway || multiplier < 0.7 { return Theme.negativeCash }
        if multiplier < 0.9 { return Theme.warning }
        return .primary
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(text)
                .font(Theme.Typography.number(.subheadline))
                .foregroundStyle(tint)
                .contentTransition(.numericText())
                .animation(Theme.Motion.valueChange, value: multiplier)
            Text(isAway ? "Away from the office — no output today." : "Schedule × wellbeing × health.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Small warning capsule while the founder has a cold (−40% output).
private struct ColdChip: View {
    var body: some View {
        Label("Cold", systemImage: "allergens.fill")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(Theme.warning)
            .padding(.horizontal, Theme.Spacing.xs + 2)
            .padding(.vertical, 2)
            .background(Theme.warning.opacity(0.15), in: Capsule())
            .accessibilityLabel("Has a cold, output reduced")
    }
}
