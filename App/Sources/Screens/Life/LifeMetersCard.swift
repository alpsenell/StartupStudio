import SwiftUI
import TycoonEngine

/// The founder's four wellbeing meters (0–100) with the resulting output
/// estimate. Meter tints follow the danger bands; the output line mirrors
/// the engine's design formula so the player can see why crunch stops
/// paying off.
struct LifeMetersCard: View {
    let engine: GameEngine

    var body: some View {
        let state = engine.state
        let life = state.life
        let hasCold = life.hasCold(day: state.day)
        let isAway = life.isAway(day: state.day)

        CardView("Wellbeing", systemImage: "figure.mind.and.body") {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                MeterRow(label: "Energy", systemImage: "bolt.fill", value: life.meters.energy)
                MeterRow(label: "Health", systemImage: "heart.fill", value: life.meters.health)
                MeterRow(label: "Mood", systemImage: "face.smiling", value: life.meters.mood)
                MeterRow(label: "Relationships", systemImage: "person.2.heart", value: life.meters.relationships)

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
        .accessibilityLabel("\(label) \(rounded) of 100")
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
