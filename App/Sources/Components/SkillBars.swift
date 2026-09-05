import SwiftUI
import TycoonEngine

/// Three compact skill bars (coding / design / marketing) for an employee
/// or candidate, side by side. Skills are 0–100; colors reuse the phase
/// palette where the skills line up (code, design) plus orange for
/// marketing (matching PixelKit's megaphone bubble).
struct SkillBars: View {
    let skills: SkillSet
    /// A second set to compare against — the roster's best on each skill —
    /// drawn as a tick on the track, so a candidate reads as "better than
    /// anyone we have" at a glance.
    var reference: SkillSet?

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            SkillBar(label: String(localized: "Coding", comment: "One of the three skills a person is rated 0-100 on"), value: skills.coding, tint: Theme.codePhase, reference: reference?.coding)
            SkillBar(label: String(localized: "Design", comment: "Used for the design build phase, the design skill, and the founder archetype skill chip. One word, on a chip or a bar label"), value: skills.design, tint: Theme.designPhase, reference: reference?.design)
            SkillBar(label: String(localized: "Marketing", comment: "Used as a ledger bucket (campaign spend) and as the marketing skill on a bar"), value: skills.marketing, tint: Theme.warning, reference: reference?.marketing)
        }
    }
}

/// One labeled 0–100 skill bar: caption label + value above a thin
/// tinted capsule track.
private struct SkillBar: View {
    let label: String
    let value: Double
    let tint: Color
    var reference: Double?

    private var fraction: Double {
        min(max(value / 100, 0), 1)
    }

    private var referenceFraction: Double? {
        reference.map { min(max($0 / 100, 0), 1) }
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
                    .font(Theme.Typography.number(.caption2))
                    .foregroundStyle(tint)
                    .contentTransition(.numericText())
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.chipBackground)
                    Capsule()
                        .fill(tint)
                        .frame(width: max(proxy.size.width * fraction, fraction > 0 ? 4 : 0))
                    if let referenceFraction {
                        Rectangle()
                            .fill(Theme.pixelInk)
                            .frame(width: 2, height: 8)
                            .offset(x: max(0, proxy.size.width * referenceFraction - 1), y: -2)
                            .accessibilityHidden(true)
                    }
                }
            }
            .frame(height: 4)
        }
        .frame(maxWidth: .infinity)
        // Training and on-the-job growth both move this weekly; the digit
        // and the fill are one change, so they animate as one.
        .animation(Theme.Motion.valueChange, value: value)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(label) skill \(Int(value.rounded())) of 100"
                + (reference.map { ", your best is \(Int($0.rounded()))" } ?? "")
        )
    }
}
