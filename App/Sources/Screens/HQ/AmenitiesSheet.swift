import SwiftUI
import TycoonEngine

/// The office amenities sheet, opened from the Office card: one card per
/// amenity (icon, effect, build cost, weekly upkeep, unlock tier) with a
/// Build button. The engine enforces tier, cash, and ownership; the UI
/// explains why a button is disabled.
///
/// Iteration 15 — K6: a built game room, cafeteria or gym also takes a
/// break (`.callBreak`), with its price on the button and what it does to
/// the Now card's ship date printed under it. A tap on the amenity in the
/// office opens this sheet — the break has one home.
struct AmenitiesSheet: View {
    let engine: GameEngine

    @Environment(\.dismiss) private var dismiss
    @Environment(GameShell.self) private var injectedShell: GameShell?
    /// See `GameShell.shared`: read optionally, because SwiftUI
    /// updates this property for presented content before the
    /// environment is installed and the non-optional form traps there.
    private var shell: GameShell { injectedShell ?? .shared }

    // MARK: K6 (home and rooms)
    /// Tomorrow's Now-card sentence with and without a break, re-read once
    /// a day while the sheet is open.
    @State private var breakPreview: RoomBreakPreview?
    // MARK: end K6

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
                            opsActive: engine.state.hasDepartment(.ops),
                            balance: engine.balance,
                            // MARK: K6 (home and rooms)
                            roomBreak: roomBreak(for: amenity),
                            // MARK: end K6
                            // MARK: S2 (office downgrade)
                            inStorage: engine.state.officeStoredAmenities.contains(amenity)
                            // MARK: end S2
                        ) {
                            shell.toasts.send(
                                .buildAmenity(amenity),
                                to: engine,
                                rejected: "The \(amenity.displayName.lowercased()) will have to wait."
                            )
                        }
                    }
                    if engine.state.hasDepartment(.ops) {
                        Text(
                            "Operations is keeping upkeep \(opsAmenityUpkeepDiscountPercent(balance: engine.balance))% lower."
                        )
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
        // MARK: K6 (home and rooms)
        .task(id: engine.state.day) {
            breakPreview = RoomBreakPreview.make(engine: engine)
        }
        // MARK: end K6
    }

    // MARK: K6 (home and rooms)

    /// The break row for a built game room, cafeteria or gym; `nil` for
    /// the shuttle and anything not built.
    private func roomBreak(for amenity: Amenity) -> AmenityBreakRow? {
        guard GameState.breakAmenities.contains(amenity), engine.state.hasAmenity(amenity) else { return nil }
        let config = engine.balance.home
        var parts = ["everyone +\(Int(config.breakMorale.rounded())) morale"]
        if amenity == .gym { parts.append("+\(Int(config.breakGymEnergy.rounded())) your energy") }
        parts.append("a day's work on every build ×\(String(format: "%g", config.breakDayFactor))")
        return AmenityBreakRow(
            title: "Call a break · " + parts.joined(separator: " · "),
            preview: breakPreview?.line,
            blocker: engine.state.roomBreakBlocker(amenity, balance: engine.balance),
            call: { callBreak(amenity) }
        )
    }

    private func callBreak(_ amenity: Amenity) {
        let day = engine.state.day
        engine.send(.callBreak(amenity: amenity))
        guard engine.state.lastBreakDay == day else {
            Haptics.warning()
            shell.toasts.show(
                engine.state.roomBreakBlocker(amenity, balance: engine.balance) ?? "No break today.",
                icon: "hand.raised.fill",
                tint: Theme.warning,
                severity: .notable
            )
            return
        }
        Haptics.commit()
        shell.toasts.show(
            "Break in the \(amenity.displayName.lowercased()). Everyone's a little happier; tomorrow's builds go slower.",
            icon: amenity.systemImage,
            tint: Theme.accent
        )
    }
    // MARK: end K6
}

// MARK: K6 (home and rooms)

/// What a break would do to the Now card's sentence tomorrow: one day of
/// the real reducer on two copies of the state, one with the break and one
/// without. The copies are thrown away and nothing is sent — the preview
/// is the same arithmetic the next tick will do, so it cannot promise what
/// the day will not deliver.
struct RoomBreakPreview: Equatable {
    let productName: String
    let without: String
    let with: String

    var line: String {
        without == with
            ? "\(productName): \(without) either way"
            : "\(productName): \(without) → with a break, \(with.prefix(1).lowercased() + with.dropFirst())"
    }

    @MainActor
    static func make(engine: GameEngine) -> RoomBreakPreview? {
        let state = engine.state
        guard let product = state.productInDevelopment,
              let amenity = GameState.breakAmenities.first(where: {
                  state.roomBreakBlocker($0, balance: engine.balance) == nil
              })
        else { return nil }
        var plain = state
        var broke = state
        Reducer.apply(.callBreak(amenity: amenity), to: &broke, balance: engine.balance, content: engine.content)
        guard broke.lastBreakDay == state.day else { return nil }
        Reducer.tick(&plain, balance: engine.balance, content: engine.content)
        Reducer.tick(&broke, balance: engine.balance, content: engine.content)
        let without = plain.buildETA(productID: product.id, balance: engine.balance, content: engine.content)
        let with = broke.buildETA(productID: product.id, balance: engine.balance, content: engine.content)
        return RoomBreakPreview(
            productName: product.name,
            without: NowBuildETA.sentence(without),
            with: NowBuildETA.sentence(with)
        )
    }
}

/// The break under a built game room, cafeteria or gym.
private struct AmenityBreakRow {
    let title: String
    let preview: String?
    let blocker: String?
    let call: () -> Void
}
// MARK: end K6

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
    let balance: BalanceConfig
    // MARK: K6 (home and rooms)
    let roomBreak: AmenityBreakRow?
    // MARK: end K6
    // MARK: S2 (office downgrade)
    /// Built, then boxed up by a move down: kept, dormant, back at its tier.
    var inStorage = false
    // MARK: end S2
    let build: () -> Void

    private var tierLocked: Bool { officeTier.rank < minTier.rank }
    private var canAfford: Bool { cash >= upgradeCost }
    private var shortfall: Int { upgradeCost - cash }
    private var upkeep: Int {
        amenityWeeklyUpkeep(weeklyCost, opsActive: opsActive, balance: balance)
    }

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
                        .font(Theme.Typography.number(.caption, weight: .regular))
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
                // MARK: S2 (office downgrade) — a stored amenity says so on the button
                Label(
                    isOwned ? "Built ✓" : inStorage ? "In storage" : "Build",
                    systemImage: isOwned ? "checkmark" : inStorage ? "shippingbox.fill" : "hammer.fill"
                )
                // MARK: end S2
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

            // MARK: K6 (home and rooms)
            if let roomBreak {
                Divider()
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Button(action: roomBreak.call) {
                        Text(roomBreak.title)
                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(PixelButtonStyle(fill: Theme.pixelPaper))
                    .disabled(roomBreak.blocker != nil)
                    .opacity(roomBreak.blocker == nil ? 1 : 0.55)
                    Text(roomBreak.blocker ?? roomBreak.preview ?? "Nothing in development: the break costs no ship date.")
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(roomBreak.blocker == nil ? Color.secondary : Theme.warning)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Once a week.")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .accessibilityElement(children: .combine)
            }
            // MARK: end K6
        }
        .cardStyle()
    }

    private var costLine: String {
        let upkeepText = opsActive
            ? "\(upkeep.money)/wk upkeep (Ops -\(opsAmenityUpkeepDiscountPercent(balance: balance))%)"
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
        // MARK: S2 (office downgrade)
        if inStorage {
            return "In storage since the move down: no upkeep, no effect. It comes back out at the \(minTier.displayName), free"
        }
        // MARK: end S2
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
