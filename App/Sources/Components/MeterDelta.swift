import SwiftUI

/// A meter's value with its change since the last report: the number, the
/// label, and a signed delta (or a dash). Used by the weekly report's
/// founder card and, inline, by the Life tab's wellbeing meters.
struct MeterDelta: View {
    let label: String
    let value: Double
    let delta: Double

    var body: some View {
        VStack(spacing: 2) {
            Text(value.formatted(.number.precision(.fractionLength(0))))
                .font(Theme.Typography.number(.headline, weight: .bold))
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            if abs(delta) >= 0.5 {
                Text((delta > 0 ? "+" : "") + delta.formatted(.number.precision(.fractionLength(0))))
                    .font(Theme.Typography.number(.caption2))
                    .foregroundStyle(delta > 0 ? Theme.positiveCash : Theme.negativeCash)
            } else {
                Text("—")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label) \(Int(value)), change \(Int(delta))")
    }
}
