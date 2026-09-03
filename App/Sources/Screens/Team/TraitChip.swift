import SwiftUI
import TycoonContent
import TycoonEngine

/// One personality trait as a tappable chip. Tapping pops the blurb, so a
/// player can find out what "Flight Risk" costs them without leaving the
/// roster.
struct TraitChip: View {
    let trait: TraitDef
    /// Renders as "?" instead of the name — an unrevealed second trait on
    /// a candidate the founder hasn't interviewed.
    var isHidden: Bool = false

    @State private var showingBlurb = false

    var body: some View {
        Button {
            showingBlurb = true
        } label: {
            HStack(spacing: 3) {
                Image(systemName: isHidden ? "questionmark" : icon)
                    .font(.system(size: 9, weight: .bold))
                Text(isHidden ? "Unknown" : trait.name)
                    .font(.caption2.weight(.semibold))
            }
            .foregroundStyle(tint)
            .padding(.horizontal, Theme.Spacing.sm)
            .padding(.vertical, 3)
            .background(Theme.chipBackground, in: Capsule())
        }
        .buttonStyle(.pressable)
        .disabled(isHidden)
        .popover(isPresented: $showingBlurb) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(trait.name)
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                Text(trait.blurb ?? TraitEffects.describe(trait.effects))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(TraitEffects.describe(trait.effects))
                    .font(.caption2)
                    .monospacedDigit()
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(Theme.Spacing.md)
            .frame(maxWidth: 260)
            .presentationCompactAdaptation(.popover)
        }
        .accessibilityLabel(
            isHidden
                ? "An unknown trait. Interview them to find out."
                : "\(trait.name): \(trait.blurb ?? TraitEffects.describe(trait.effects))"
        )
    }

    private var tint: Color {
        trait.isPositive ? Theme.accent : Theme.warning
    }

    /// A tiny visual tell for the shape of the trait, so a row of chips
    /// reads at a glance.
    private var icon: String {
        if trait.effects.teamGrowthBonus > 0 { return "graduationcap.fill" }
        if trait.effects.dailyReputationBonus > 0 { return "megaphone.fill" }
        if trait.effects.teamMoraleBonus != 0 {
            return trait.effects.teamMoraleBonus > 0 ? "face.smiling.fill" : "cloud.rain.fill"
        }
        if trait.effects.poachResist > 1.5 { return "lock.fill" }
        if trait.effects.poachResist < 0.8 { return "figure.walk.departure" }
        if trait.effects.outputMult > 1.05 { return "bolt.fill" }
        if trait.effects.skillGrowthMult > 1.1 { return "arrow.up.right" }
        if trait.effects.moraleTargetDelta < -4 { return "cloud.fill" }
        return "circle.fill"
    }
}

/// The chips for a person's traits, in their own order. Renders nothing
/// when the content bundle has no trait catalog.
struct TraitChipRow: View {
    let traits: [String]
    let content: ContentCatalog
    /// Trait indices past this one render as "Unknown" — used by the
    /// hiring sheet before an interview.
    var revealedCount: Int?

    /// How long a co-founder takes to show their second trait: nobody
    /// interviewed them, so it comes out the way it does with anyone you
    /// share a garage with — after a quarter.
    static let cofounderRevealDays = 91

    /// The reveal for somebody on payroll: everyone was interviewed or has
    /// been around, except a co-founder in their first quarter (WS-H).
    static func revealedCount(for employee: Employee, day: Int) -> Int? {
        employee.isCofounder && day - employee.hiredDay < cofounderRevealDays ? 1 : nil
    }

    var body: some View {
        let defs = traits.compactMap { id in content.traits.first { $0.id == id } }
        if !defs.isEmpty {
            // Two chips per person; a plain row never needs to wrap.
            HStack(spacing: Theme.Spacing.xs) {
                ForEach(Array(defs.enumerated()), id: \.offset) { index, trait in
                    TraitChip(trait: trait, isHidden: index >= (revealedCount ?? defs.count))
                }
                Spacer(minLength: 0)
            }
        }
    }
}
