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
                        .font(Theme.Typography.number(.caption))
                        .foregroundStyle(.secondary)
                        .contentTransition(.numericText())
                }
            }
            track
        }
        .animation(Theme.Motion.valueChange, value: fraction)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label) \(pointsText)")
    }

    private var pointsText: String {
        required > 0
            ? "\(Int(points.rounded()))/\(Int(required.rounded()))"
            : String(localized: "\(Int(points.rounded())) pts", comment: "Progress bar readout when the requirement is unknown: points banked. Abbreviation of points")
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
                label: String(localized: "Design", comment: "Used for the design build phase, the design skill, and the founder archetype skill chip. One word, on a chip or a bar label"),
                points: progress.designPts,
                required: type?.designPts ?? 0,
                tint: Theme.designPhase,
                compact: compact
            )
            PhaseProgressBar(
                label: String(localized: "Code", comment: "Used both for the code build phase and for the founder coding skill. One word, on a chip or a bar label"),
                points: progress.codePts,
                required: type?.codePts ?? 0,
                tint: Theme.codePhase,
                compact: compact
            )
            PhaseProgressBar(
                label: String(localized: "Polish", comment: "One of the three build phases a product goes through"),
                points: progress.polishPts,
                required: type?.polishPts ?? 0,
                tint: Theme.polishPhase,
                compact: compact
            )
        }
    }
}

// MARK: V3 (ux: card weights, the Now card)

/// One bar for a build in development (C11): design, code and polish as
/// three segments, each as wide as its share of the type's points and
/// filled by its own progress. It replaces the three bars on the Now card;
/// the Products tab keeps `TriPhaseProgress` with its numbers.
struct SegmentedPhaseBar: View {
    let progress: DevProgress
    /// `nil` draws three equal, empty segments (defensive — content should
    /// always resolve).
    let type: ProductTypeDef?
    var height: CGFloat = 8

    private struct Segment {
        let label: String
        let fraction: Double
        let weight: Double
        let tint: Color
    }

    private var segments: [Segment] {
        func fraction(_ points: Double, _ required: Double?) -> Double {
            guard let required, required > 0 else { return 0 }
            return min(max(points / required, 0), 1)
        }
        return [
            Segment(
                label: String(localized: "Design", comment: "Used for the design build phase, the design skill, and the founder archetype skill chip. One word, on a chip or a bar label"),
                fraction: fraction(progress.designPts, type?.designPts),
                weight: max(type?.designPts ?? 1, 1),
                tint: Theme.designPhase
            ),
            Segment(
                label: String(localized: "Code", comment: "Used both for the code build phase and for the founder coding skill. One word, on a chip or a bar label"),
                fraction: fraction(progress.codePts, type?.codePts),
                weight: max(type?.codePts ?? 1, 1),
                tint: Theme.codePhase
            ),
            Segment(
                label: String(localized: "Polish", comment: "One of the three build phases a product goes through"),
                fraction: fraction(progress.polishPts, type?.polishPts),
                weight: max(type?.polishPts ?? 1, 1),
                tint: Theme.polishPhase
            ),
        ]
    }

    var body: some View {
        let segments = segments
        let gap: CGFloat = 2
        let total = segments.reduce(0) { $0 + $1.weight }
        GeometryReader { proxy in
            let usable = max(0, proxy.size.width - gap * CGFloat(segments.count - 1))
            HStack(spacing: gap) {
                ForEach(segments.indices, id: \.self) { index in
                    let segment = segments[index]
                    let width = usable * segment.weight / total
                    ZStack(alignment: .leading) {
                        Rectangle().fill(Theme.chipBackground)
                        Rectangle()
                            .fill(segment.tint)
                            .frame(width: width * segment.fraction)
                    }
                    .frame(width: width)
                }
            }
        }
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
        .animation(Theme.Motion.valueChange, value: segments.map(\.fraction))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            segments
                .map { "\($0.label) \(Int(($0.fraction * 100).rounded()))%" }
                .joined(separator: ", ")
        )
    }
}

// MARK: end V3
