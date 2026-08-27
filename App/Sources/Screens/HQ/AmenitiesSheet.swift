import SwiftUI
import TycoonEngine

/// The office amenities sheet, opened from the Office card: one card per
/// amenity (icon, effect, build cost, weekly upkeep, unlock tier) with a
/// Build button. The engine enforces tier, cash, and ownership; the UI
/// explains why a button is disabled.
struct AmenitiesSheet: View {
    let engine: GameEngine

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.lg) {
                    ForEach(Amenity.allCases, id: \.self) { amenity in
                        let def = engine.balance.company.amenity(amenity)
                        AmenityCard(
                            amenity: amenity,
                            upgradeCost: def.upgradeCost,
                            weeklyCost: def.weeklyCost,
                            minTier: def.minTier,
                            moraleBonus: def.moraleBonus,
                            founderHealthBonus: def.founderHealthBonus,
                            isOwned: engine.state.hasAmenity(amenity),
                            officeTier: engine.state.company.officeTier,
                            cash: engine.state.company.cash,
                            opsActive: engine.state.hasDepartment(.ops)
                        ) {
                            engine.send(.buildAmenity(amenity))
                        }
                    }
                    if engine.state.hasDepartment(.ops) {
                        Text("Operations is keeping upkeep \(Int(opsAmenityUpkeepDiscount * 100))% lower.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(Theme.Spacing.lg)
            }
            .background(Theme.screenBackground)
            .navigationTitle("Amenities")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        // Opening day: a success haptic when a new amenity lands.
        .sensoryFeedback(.success, trigger: engine.state.amenities.count)
    }
}

// MARK: - Amenity card

/// One amenity. Takes the balance definition's fields individually so the
/// card depends on the values, not the def's type.
private struct AmenityCard: View {
    let amenity: Amenity
    let upgradeCost: Int
    let weeklyCost: Int
    let minTier: OfficeTier
    let moraleBonus: Double
    let founderHealthBonus: Double
    let isOwned: Bool
    let officeTier: OfficeTier
    let cash: Int
    let opsActive: Bool
    let build: () -> Void

    private var tierLocked: Bool { officeTier.rank < minTier.rank }
    private var canAfford: Bool { cash >= upgradeCost }
    private var shortfall: Int { upgradeCost - cash }
    private var upkeep: Int { amenityWeeklyUpkeep(weeklyCost, opsActive: opsActive) }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: amenity.systemImage)
                    .font(.title3)
                    .foregroundStyle(isOwned ? Theme.positiveCash : Theme.accent)
                    .frame(width: 32, height: 32)
                    .background(
                        Theme.chipBackground,
                        in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(amenity.displayName)
                        .font(.system(.headline, design: .rounded))
                    Text(costLine)
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: Theme.Spacing.sm)

                TierPill(tier: minTier, locked: tierLocked)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(amenity.effectSummary)
                    .font(.subheadline)
                Text(effectNumbers)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button(action: build) {
                Label(isOwned ? "Built ✓" : "Build", systemImage: isOwned ? "checkmark" : "hammer.fill")
                    .font(.system(.headline, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Spacing.xs)
            }
            .buttonStyle(.borderedProminent)
            .tint(isOwned ? Theme.positiveCash : Theme.accent)
            .disabled(isOwned || tierLocked || !canAfford)
            .accessibilityLabel(buttonAccessibilityLabel)

            if let reason = disabledReason {
                Text(reason)
                    .font(.footnote)
                    .monospacedDigit()
                    .foregroundStyle(.tertiary)
            }
        }
        .cardStyle()
    }

    private var costLine: String {
        let upkeepText = opsActive
            ? "\(upkeep.money)/wk upkeep (Ops −\(Int(opsAmenityUpkeepDiscount * 100))%)"
            : "\(upkeep.money)/wk upkeep"
        return "\(upgradeCost.money) · \(upkeepText)"
    }

    /// The balance numbers behind the flavor copy.
    private var effectNumbers: String {
        var parts: [String] = []
        if moraleBonus > 0 {
            parts.append("Team morale target +\(Int(moraleBonus.rounded()))")
        }
        if founderHealthBonus > 0 {
            parts.append("founder health up")
        }
        return parts.isEmpty ? "No direct stat effect." : parts.joined(separator: " · ") + "."
    }

    /// Why Build is disabled — `nil` when it's tappable or already built.
    private var disabledReason: String? {
        if isOwned { return nil }
        if tierLocked { return "Needs the \(minTier.displayName)" }
        if !canAfford { return "Need \(shortfall.money) more" }
        return nil
    }

    private var buttonAccessibilityLabel: String {
        if isOwned { return "\(amenity.displayName) built" }
        let base = "Build the \(amenity.displayName) for \(upgradeCost.money), \(upkeep.money) weekly upkeep"
        return disabledReason.map { base + ". " + $0 } ?? base
    }
}

/// "From Loft" capsule in the amenity card header; warning-tinted while
/// the office is still too small.
private struct TierPill: View {
    let tier: OfficeTier
    let locked: Bool

    var body: some View {
        Text("From \(tier.displayName)")
            .font(.system(.caption, design: .rounded).weight(.semibold))
            .foregroundStyle(locked ? Theme.warning : .secondary)
            .padding(.horizontal, Theme.Spacing.sm)
            .padding(.vertical, 2)
            .background(Theme.chipBackground, in: Capsule())
            .accessibilityLabel(locked ? "Unlocks at the \(tier.displayName)" : "Available from the \(tier.displayName)")
    }
}
