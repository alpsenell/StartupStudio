import SwiftUI
import TycoonEngine

/// Reusable design/code/polish weight editor: three sliders whose live
/// percentage labels always display as summing to 100%.
///
/// Weights are relative — the engine normalizes them — so the sliders bind
/// straight to the raw `PhaseFocus` values while the labels show the
/// normalized split.
struct FocusEditor: View {
    @Binding var focus: PhaseFocus

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            let split = normalizedPercentages
            sliderRow(
                label: "Design",
                value: $focus.design,
                tint: Theme.designPhase,
                percent: split[0]
            )
            sliderRow(
                label: "Code",
                value: $focus.code,
                tint: Theme.codePhase,
                percent: split[1]
            )
            sliderRow(
                label: "Polish",
                value: $focus.polish,
                tint: Theme.polishPhase,
                percent: split[2]
            )
            Text("Where the team spends its time, split \(split[0])/\(split[1])/\(split[2]).")
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .contentTransition(.numericText())
                .animation(Theme.Motion.selection, value: split)
        }
    }

    private func sliderRow(
        label: String,
        value: Binding<Double>,
        tint: Color,
        percent: Int
    ) -> some View {
        HStack(spacing: Theme.Spacing.md) {
            Text(label)
                .font(.system(.subheadline, design: .rounded).weight(.medium))
                .frame(width: 56, alignment: .leading)
            Slider(value: value, in: 0...1)
                .tint(tint)
                .accessibilityLabel("\(label) focus")
                .accessibilityValue("\(percent) percent")
            Text("\(percent)%")
                .font(Theme.Typography.number(.subheadline))
                .foregroundStyle(tint)
                .frame(width: 44, alignment: .trailing)
                .contentTransition(.numericText())
                .animation(Theme.Motion.valueChange, value: percent)
        }
    }

    /// The three weights as whole percentages that always sum to exactly
    /// 100 (the last value absorbs rounding error).
    private var normalizedPercentages: [Int] {
        let weights = [max(focus.design, 0), max(focus.code, 0), max(focus.polish, 0)]
        let total = weights.reduce(0, +)
        guard total > 0 else { return [34, 33, 33] }

        let design = Int((weights[0] / total * 100).rounded())
        var code = Int((weights[1] / total * 100).rounded())
        var polish = 100 - design - code
        if polish < 0 {
            code += polish
            polish = 0
        }
        return [design, code, polish]
    }
}
