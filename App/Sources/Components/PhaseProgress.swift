import SwiftUI
import TycoonContent
import TycoonEngine

/// One labeled development-phase progress bar (label left, points right,
/// tinted capsule track below). Fills with a spring as points accrue.
struct PhaseProgressBar: View {
    let label: String
    let points: Double
    let required: Double
    let tint: Color
    /// Compact mode (HQ dashboard): thinner bar, no points readout.
    var compact: Bool = false

    private var fraction: Double {
        guard required > 0 else { return 0 }
        return min(points / required, 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack {
                Text(label)
                    .font(compact ? .caption2 : .caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if !compact {
                    Text(pointsText)
                        .font(.system(.caption, design: .rounded).weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .contentTransition(.numericText())
                }
            }
            track
        }
        .animation(.spring(duration: 0.35), value: fraction)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label) \(pointsText)")
    }

    private var pointsText: String {
        required > 0
            ? "\(Int(points.rounded()))/\(Int(required.rounded()))"
            : "\(Int(points.rounded())) pts"
    }

    private var track: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.chipBackground)
                Capsule()
                    .fill(tint)
                    .frame(width: max(proxy.size.width * fraction, fraction > 0 ? 6 : 0))
            }
        }
        .frame(height: compact ? 5 : 8)
    }
}

/// The three design/code/polish bars for a product in development,
/// measured against its type's point requirements.
struct TriPhaseProgress: View {
    let progress: DevProgress
    /// The product's type definition; `nil` falls back to a points-only
    /// readout (defensive — content should always resolve).
    let type: ProductTypeDef?
    var compact: Bool = false

    var body: some View {
        VStack(spacing: compact ? Theme.Spacing.xs + 2 : Theme.Spacing.sm) {
            PhaseProgressBar(
                label: "Design",
                points: progress.designPts,
                required: type?.designPts ?? 0,
                tint: Theme.designPhase,
                compact: compact
            )
            PhaseProgressBar(
                label: "Code",
                points: progress.codePts,
                required: type?.codePts ?? 0,
                tint: Theme.codePhase,
                compact: compact
            )
            PhaseProgressBar(
                label: "Polish",
                points: progress.polishPts,
                required: type?.polishPts ?? 0,
                tint: Theme.polishPhase,
                compact: compact
            )
        }
    }
}
