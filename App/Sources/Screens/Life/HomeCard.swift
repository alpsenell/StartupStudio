import PixelKit
import SwiftUI
import TycoonEngine

/// The pixel-art home scene card at the top of the Life tab. Shows the
/// founder's evening at home (partner and kids included), an away banner
/// while the founder is travelling, and — until the penthouse — the
/// upgrade affordance for the next home.
///
/// Mirrors `CardView`'s header styling by hand because this card carries a
/// trailing accessory in the header row (same as `OfficeCard`).
struct HomeCard: View {
    let engine: GameEngine

    var body: some View {
        let state = engine.state
        let life = state.life

        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "house.fill")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.accent)
                Text("Home")
                    .font(.system(.footnote, design: .rounded).weight(.semibold))
                    .textCase(.uppercase)
                    .kerning(0.6)
                    .foregroundStyle(.secondary)
                Spacer(minLength: Theme.Spacing.sm)
                HomeTierPill(tier: life.home)
            }

            HomeSceneView(tier: tierStyle, occupants: occupants, activity: activity, mood: mood)
                .frame(maxWidth: .infinity)
                .accessibilityLabel(sceneAccessibilityLabel)

            if life.isAway(day: state.day) {
                AwayBanner(reason: life.awayReason, untilDay: life.awayUntilDay, day: state.day)
            }

            if let next = life.home.next {
                Divider()
                HomeUpgradeRow(
                    next: next,
                    upgradeCost: homeUpgradeCost(next, balance: engine.balance),
                    weeklyRent: homeWeeklyRent(next, balance: engine.balance),
                    wallet: life.wallet
                ) {
                    engine.send(.upgradeHome)
                }
            }
        }
        .cardStyle()
        // Moving day: the scene above re-renders with the new tier; add a
        // success haptic so the moment lands.
        .sensoryFeedback(.success, trigger: life.home)
    }

    /// `HomeTier` and `HomeTierStyle` share raw values by design; the
    /// fallback is defensive and should never trigger.
    private var tierStyle: HomeTierStyle {
        HomeTierStyle(rawValue: engine.state.life.home.rawValue) ?? .studioFlat
    }

    /// The founder from the roster, the partner (once there is one), and
    /// every child, all drawn from their appearance seeds.
    private var occupants: HomeOccupants {
        let state = engine.state
        let family = state.life.family
        // Defensive: the founder is always on the roster.
        let founderSeed = state.employees.first(where: \.isFounder)?.appearanceSeed ?? 1
        let partner = family.stage == .single
            ? nil
            : family.partnerAppearanceSeed.map { CharacterAppearance(seed: $0) }
        return HomeOccupants(
            founder: CharacterAppearance(seed: founderSeed),
            partner: partner,
            children: family.children.map { CharacterAppearance(seed: $0.appearanceSeed) }
        )
    }

    /// What the founder is doing at home this evening. Weekdays show the
    /// evening after work (asleep early when drained); weekend days show the
    /// planned activity.
    private var activity: HomeActivity {
        let state = engine.state
        let life = state.life
        if life.isAway(day: state.day) { return .away }

        let isWeekend = state.dayOfWeek >= 6
        guard isWeekend else {
            return life.meters.energy < 30 ? .sleeping : .relaxing
        }

        return switch life.plannedActivity {
        case .rest: .sleeping
        case .gym: .exercising
        case .dateNight: .dinner
        case .friends: .relaxing
        case .hobby: .gaming
        case .familyTime: life.family.children.isEmpty ? .dinner : .withBaby
        case .vacation: .away
        case .doctor: .reading
        }
    }

    private var mood: MoodLevel {
        let mood = engine.state.life.meters.mood
        if mood >= 70 { return .great }
        if mood <= 35 { return .low }
        return .okay
    }

    private var sceneAccessibilityLabel: String {
        let state = engine.state
        let life = state.life
        let household = 1
            + (life.family.stage == .single ? 0 : 1)
            + life.family.children.count
        let presence = life.isAway(day: state.day) ? "founder away" : "founder at home"
        return "\(life.home.displayName) scene, \(presence), household of \(household)"
    }
}

// MARK: - Away banner

/// Shown inside the home card while the founder is travelling (vacation,
/// conference, ...). The reason comes from the engine verbatim.
private struct AwayBanner: View {
    let reason: String?
    let untilDay: Int?
    let day: Int

    private var daysLeft: Int {
        max(0, (untilDay ?? day) - day)
    }

    private var message: String {
        let what = reason ?? "Away"
        return "\(what) — back in \(daysLeft) day\(daysLeft == 1 ? "" : "s")"
    }

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "airplane.departure")
                .font(.subheadline)
            Text(message)
                .font(.subheadline)
                .monospacedDigit()
            Spacer(minLength: 0)
        }
        .foregroundStyle(Theme.warning)
        .padding(Theme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Theme.warning.opacity(0.12),
            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
        )
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Home upgrade row

/// The next-home upgrade affordance: what you get, what it costs, and the
/// button that sends `.upgradeHome`. Paid from the founder's wallet, not
/// company cash — so the shortfall is wallet-based.
private struct HomeUpgradeRow: View {
    let next: HomeTier
    let upgradeCost: Int
    let weeklyRent: Int
    let wallet: Int
    let upgrade: () -> Void

    private var canAfford: Bool { wallet >= upgradeCost }
    private var shortfall: Int { upgradeCost - wallet }

    private var summary: String {
        var parts = ["\(upgradeCost.money)", "\(weeklyRent.money)/wk rent"]
        if next.allowsChildren {
            parts.append("kids allowed")
        }
        return parts.joined(separator: " · ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack(spacing: Theme.Spacing.md) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Next: \(next.displayName)")
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    Text(summary)
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: Theme.Spacing.sm)
                Button("Move", action: upgrade)
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                    .tint(Theme.accent)
                    .disabled(!canAfford)
            }
            if !canAfford {
                Text("Need \(shortfall.money) more in your wallet")
                    .font(.footnote)
                    .monospacedDigit()
                    .foregroundStyle(.tertiary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        let base = "Move to the \(next.displayName) for \(upgradeCost.money): \(weeklyRent.money) weekly rent."
        return canAfford ? base : base + " Need \(shortfall.money) more."
    }
}

// MARK: - Home tier pill

/// Compact home-name capsule for the card header.
private struct HomeTierPill: View {
    let tier: HomeTier

    var body: some View {
        HStack(spacing: Theme.Spacing.xs) {
            Image(systemName: tier.systemImage)
                .font(.caption2.weight(.semibold))
            Text(tier.displayName)
                .font(.system(.caption, design: .rounded).weight(.semibold))
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, Theme.Spacing.sm)
        .padding(.vertical, 2)
        .background(Theme.chipBackground, in: Capsule())
        .accessibilityLabel("Home: \(tier.displayName)")
    }
}
