import SwiftUI
import TycoonEngine

/// Iteration 17 — T7 (press and stakes): *Exclusive to…* on the ship
/// confirmation.
///
/// A self-contained row: pick one of the review outlets, or none. The pick
/// is held here, keyed by product, until the ship goes through; the host's
/// *Ship it* then calls `ExclusivePick.shared.grantAfterShip`, which sends
/// `.grantExclusive` right after the ship action — so the row composes
/// with every way a build ships (the plain ship today, T2's priced sheet at
/// merge). The engine refuses a grant on anything that did not ship today.
@MainActor
@Observable
final class ExclusivePick {
    static let shared = ExclusivePick()

    /// The outlet picked for each build still waiting to ship.
    private(set) var outlets: [UUID: String] = [:]

    func outlet(for productID: UUID) -> String? { outlets[productID] }

    func pick(_ outlet: String?, for productID: UUID) {
        outlets[productID] = outlet
    }

    /// Gives the picked outlet the exclusive, if one was picked, and
    /// forgets the pick. Call right after the ship action.
    func grantAfterShip(productID: UUID, engine: GameEngine) {
        guard let outlet = outlets.removeValue(forKey: productID) else { return }
        _ = engine.send(.grantExclusive(productID: productID, outlet: outlet))
    }
}

struct ExclusiveRow: View {
    let engine: GameEngine
    let productID: UUID

    private var pick: ExclusivePick { ExclusivePick.shared }

    private var chosen: String? { pick.outlet(for: productID) }

    var body: some View {
        let press = engine.balance.press
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Menu {
                Button {
                    Haptics.tap()
                    pick.pick(nil, for: productID)
                } label: {
                    Text("None — every outlet at once")
                }
                ForEach(engine.balance.reviewOutlets, id: \.self) { outlet in
                    Button {
                        Haptics.tap()
                        pick.pick(outlet, for: productID)
                    } label: {
                        Text(menuLabel(outlet))
                    }
                }
            } label: {
                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: "newspaper.fill")
                        .font(.caption.weight(.semibold))
                    Text(chosen.map { String(localized: "Exclusive to \($0)", comment: "Ship row: the outlet given the review copy first") }
                        ?? String(localized: "Exclusive to… none", comment: "Ship row: no outlet gets the review copy first"))
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, Theme.Spacing.sm)
                .background(Theme.chipBackground, in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
            }
            .accessibilityLabel(chosen.map { "Exclusive to \($0)" } ?? "No exclusive")
            .accessibilityHint("Picks the review outlet that gets the build first")

            Text(consequence(chosen, press: press))
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// "TechDaily · warm to you (+4)".
    private func menuLabel(_ outlet: String) -> String {
        "\(outlet) · \(PressByline.short(outlet: outlet, state: engine.state, balance: engine.balance))"
    }

    /// Both answers, with what each costs later.
    private func consequence(_ outlet: String?, press: BalanceConfig.PressBalance) -> String {
        guard let outlet else {
            return String(
                localized: "Even-handed: all four publish on launch day, launch week reads their average, and no one's standing moves.",
                comment: "Ship row: what shipping without an exclusive does"
            )
        }
        let gain = Int(press.exclusiveGain.rounded())
        let snub = Int(press.snub.rounded())
        let standing = PressByline.short(outlet: outlet, state: engine.state, balance: engine.balance)
        return String(
            localized: "\(outlet) alone judges launch week · \(standing). The other three publish \(press.embargoDays) days later, so launch week's buyers read \(outlet)'s score — higher or lower than all four would have been. \(outlet) warms +\(gain), the other three cool −\(snub) for your next launch.",
            comment: "Ship row: what an exclusive does now and what it closes later"
        )
    }
}
