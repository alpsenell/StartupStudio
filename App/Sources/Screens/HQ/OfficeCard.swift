import PixelKit
import SwiftUI
import TycoonEngine

/// The pixel-art office scene card at the top of HQ — the game's face.
/// Shows the current office tier with every employee at a desk, a headcount
/// pill against the tier's desk cap, and — until the studio reaches campus —
/// the upgrade affordance for the next tier.
///
/// Mirrors `CardView`'s header styling by hand because this card carries a
/// trailing accessory in the header row.
struct OfficeCard: View {
    let engine: GameEngine

    var body: some View {
        let state = engine.state
        let cap = engine.balance.office(state.company.officeTier).headcountCap

        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "building.2.fill")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.accent)
                Text("Office")
                    .font(.system(.footnote, design: .rounded).weight(.semibold))
                    .textCase(.uppercase)
                    .kerning(0.6)
                    .foregroundStyle(.secondary)
                Spacer(minLength: Theme.Spacing.sm)
                if founderIsAway {
                    FounderAwayChip(reason: state.life.awayReason)
                }
                HeadcountPill(headcount: state.headcount, cap: cap)
            }

            OfficeSceneView(tier: tierStyle, occupants: occupants)
                .frame(maxWidth: .infinity)
                .accessibilityLabel(sceneAccessibilityLabel)

            if let next = state.company.officeTier.next {
                Divider()
                UpgradeRow(
                    next: next,
                    def: engine.balance.office(next),
                    cash: state.company.cash
                ) {
                    engine.send(.upgradeOffice)
                }
            }
        }
        .cardStyle()
        // Moving day: the scene above re-renders with the new tier; add a
        // success haptic so the moment lands.
        .sensoryFeedback(.success, trigger: state.company.officeTier)
    }

    /// `OfficeTier` and `OfficeTierStyle` share raw values by design;
    /// the fallback is defensive and should never trigger.
    private var tierStyle: OfficeTierStyle {
        OfficeTierStyle(rawValue: engine.state.company.officeTier.rawValue) ?? .garage
    }

    /// Travelling founder (vacation, conference, ...): their desk sits empty.
    private var founderIsAway: Bool {
        engine.state.life.isAway(day: engine.state.day)
    }

    /// Founder first, then by hire day, so desk placement stays stable as
    /// people come and go. The founder is left out while away.
    private var occupants: [Occupant] {
        engine.state.employees
            .filter { !($0.isFounder && founderIsAway) }
            .sorted { lhs, rhs in
                if lhs.isFounder != rhs.isFounder { return lhs.isFounder }
                return lhs.hiredDay < rhs.hiredDay
            }
            .map { employee in
                Occupant(
                    id: employee.id,
                    appearance: CharacterAppearance(seed: employee.appearanceSeed),
                    status: workStatus(for: employee),
                    isFounder: employee.isFounder
                )
            }
    }

    /// Maps a simulation assignment onto a cosmetic desk status.
    /// Contracts borrow the marketing bubble until M5 gets its own.
    private func workStatus(for employee: Employee) -> WorkStatus {
        switch employee.assignment {
        case .idle:
            .idle
        case .research:
            .researching
        case .contract:
            .marketing
        case .product:
            employee.skills.coding >= employee.skills.design ? .coding : .designing
        }
    }

    private var sceneAccessibilityLabel: String {
        let tier = engine.state.company.officeTier.displayName
        let count = occupants.count
        let base = "\(tier) office scene, \(count) \(count == 1 ? "person" : "people") at work"
        return founderIsAway ? base + ", founder away" : base
    }
}

/// Small warning capsule in the card header while the founder is out of
/// the office.
private struct FounderAwayChip: View {
    let reason: String?

    var body: some View {
        Label("Founder away: \(reason ?? "out")", systemImage: "airplane.departure")
            .font(.caption2.weight(.semibold))
            .lineLimit(1)
            .foregroundStyle(Theme.warning)
            .padding(.horizontal, Theme.Spacing.xs + 2)
            .padding(.vertical, 2)
            .background(Theme.warning.opacity(0.15), in: Capsule())
            .accessibilityLabel("Founder away: \(reason ?? "out of the office")")
    }
}

/// The next-tier upgrade affordance: what you get, what it costs, and the
/// button that sends `.upgradeOffice`. Disabled with a subtle reason while
/// the studio can't afford the move.
private struct UpgradeRow: View {
    let next: OfficeTier
    let def: BalanceConfig.OfficeDef
    let cash: Int
    let upgrade: () -> Void

    private var canAfford: Bool { cash >= def.upgradeCost }
    private var shortfall: Int { def.upgradeCost - cash }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack(spacing: Theme.Spacing.md) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Next: \(next.displayName)")
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    Text("\(def.upgradeCost.money) · \(def.headcountCap) desks · \(def.weeklyRent.money)/wk rent")
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: Theme.Spacing.sm)
                Button("Upgrade", action: upgrade)
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                    .tint(Theme.accent)
                    .disabled(!canAfford)
            }
            if !canAfford {
                Text("Need \(shortfall.money) more")
                    .font(.footnote)
                    .monospacedDigit()
                    .foregroundStyle(.tertiary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        let summary = "Upgrade to the \(next.displayName) for \(def.upgradeCost.money): "
            + "\(def.headcountCap) desks, \(def.weeklyRent.money) weekly rent."
        return canAfford ? summary : summary + " Need \(shortfall.money) more."
    }
}

/// Compact "3/3 desks" capsule for the card header.
private struct HeadcountPill: View {
    let headcount: Int
    let cap: Int

    var body: some View {
        Text("\(headcount)/\(cap) desks")
            .font(.system(.caption, design: .rounded).weight(.semibold))
            .monospacedDigit()
            .foregroundStyle(headcount >= cap ? Theme.warning : .secondary)
            .padding(.horizontal, Theme.Spacing.sm)
            .padding(.vertical, 2)
            .background(Theme.chipBackground, in: Capsule())
            .contentTransition(.numericText())
            .animation(.spring(duration: 0.35), value: headcount)
            .accessibilityLabel("\(headcount) of \(cap) desks filled")
    }
}
