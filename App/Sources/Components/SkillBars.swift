import SwiftUI
import TycoonEngine

/// Three compact skill bars (coding / design / marketing) for an employee
/// or candidate, side by side. Skills are 0–100; colors reuse the phase
/// palette where the skills line up (code, design) plus orange for
/// marketing (matching PixelKit's megaphone bubble).
struct SkillBars: View {
    let skills: SkillSet

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            SkillBar(label: "Coding", value: skills.coding, tint: Theme.codePhase)
            SkillBar(label: "Design", value: skills.design, tint: Theme.designPhase)
            SkillBar(label: "Marketing", value: skills.marketing, tint: Theme.warning)
        }
    }
}

/// One labeled 0–100 skill bar: caption label + value above a thin
/// tinted capsule track.
private struct SkillBar: View {
    let label: String
    let value: Double
    let tint: Color

    private var fraction: Double {
        min(max(value / 100, 0), 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 2)
                Text("\(Int(value.rounded()))")
                    .font(.system(.caption2, design: .rounded).weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(tint)
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.chipBackground)
                    Capsule()
                        .fill(tint)
                        .frame(width: max(proxy.size.width * fraction, fraction > 0 ? 4 : 0))
                }
            }
            .frame(height: 4)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label) skill \(Int(value.rounded())) of 100")
    }
}
