import PixelKit
import SwiftUI
import TycoonEngine

/// The coffee machine's menu: dinner for the whole team, or a coffee with
/// one person — the same two actions the Team tab and the manage sheet
/// send (`.teamDinner`, `.grabCoffee`), with their costs, greyed with the
/// reason when the engine would refuse them: nobody hired, too soon, or
/// not enough cash. The gates mirror `SocialSystem`'s; the engine still
/// enforces them.
///
/// A sheet rather than a `Menu` or a confirmation dialog because a tap on
/// a canvas cannot open a `Menu`, and a dialog cannot grey a choice with
/// its reason next to it.
struct CoffeeMachineSheet: View {
    let engine: GameEngine

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                CoffeeMachineMenu(engine: engine)
                    .padding(Theme.Spacing.lg)
            }
            .background(Theme.screenBackground)
            .navigationTitle("Coffee machine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

/// The menu itself, as a card, so a snapshot can render it without the
/// sheet chrome.
struct CoffeeMachineMenu: View {
    let engine: GameEngine

    @Environment(GameShell.self) private var injectedShell: GameShell?
    /// See `GameShell.shared`: read optionally, because SwiftUI updates
    /// this property for presented content before the environment is
    /// installed and the non-optional form traps there.
    private var shell: GameShell { injectedShell ?? .shared }

    var body: some View {
        CardView("Coffee machine", systemImage: "cup.and.saucer.fill") {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                dinnerRow
                if !staff.isEmpty {
                    Divider()
                    Text("Coffee with")
                        .font(.system(.caption, design: .rounded).weight(.semibold))
                        .textCase(.uppercase)
                        .kerning(0.6)
                        .foregroundStyle(.secondary)
                    ForEach(staff) { employee in
                        coffeeRow(employee)
                    }
                }
            }
        }
    }

    /// Everyone but the founder: the people you can take out.
    private var staff: [Employee] {
        engine.state.employees.filter { !$0.isFounder }
    }

    /// Team dinner: morale and loyalty for everyone, per-head cost, one
    /// global cooldown. Mirrors `SocialSystem.teamDinner`'s gates.
    private var dinnerRow: some View {
        let state = engine.state
        let social = engine.balance.social
        let cost = social.dinnerCostPerHead * state.headcount
        let onCooldown = state.lastTeamDinnerDay.map {
            state.day - $0 < social.teamDinnerCooldownDays
        } ?? false
        let blocker: String? = if staff.isEmpty {
            "Hire someone first"
        } else if onCooldown {
            "The team ate out recently"
        } else if state.company.cash < cost {
            "Need \((cost - state.company.cash).money) more"
        } else {
            nil
        }
        return MenuRow(
            title: "Team dinner",
            detail: blocker ?? "\(cost.money) · morale and loyalty up, for everyone",
            enabled: blocker == nil,
            systemImage: "fork.knife"
        ) {
            shell.toasts.send(.teamDinner, to: engine, rejected: "Dinner fell through - check the cash.")
        } leading: {
            Image(systemName: "fork.knife.circle.fill")
                .font(.title2)
                .foregroundStyle(Theme.accent)
                .frame(width: 34, height: 34)
        }
    }

    /// Coffee with one person: a little morale and loyalty, the company
    /// pays, and the per-person cooldown coffee shares with the 1-on-1 and
    /// the gift. Mirrors `SocialSystem.socialAction`'s gates.
    private func coffeeRow(_ employee: Employee) -> some View {
        let state = engine.state
        let social = engine.balance.social
        let cost = social.coffeeCost
        let daysLeft = employee.lastSocialDay.map {
            social.socialCooldownDays - (state.day - $0)
        } ?? 0
        let blocker: String? = if daysLeft > 0 {
            "You caught up recently · \(daysLeft) day\(daysLeft == 1 ? "" : "s") to go"
        } else if state.company.cash < cost {
            "Need \((cost - state.company.cash).money) more"
        } else {
            nil
        }
        return MenuRow(
            title: employee.name,
            detail: blocker ?? "\(cost.money) · a little morale and loyalty",
            enabled: blocker == nil,
            systemImage: "cup.and.saucer.fill"
        ) {
            shell.toasts.send(
                .grabCoffee(employeeID: employee.id), to: engine,
                rejected: "No coffee - check the cash."
            )
        } leading: {
            PixelPortrait(
                seed: employee.appearanceSeed,
                role: RoleLook(rawValue: employee.role.rawValue) ?? .none
            )
        }
    }
}

/// One choice on the coffee machine: a face or an icon, a title, the cost
/// or the reason it is greyed, and the action's own symbol.
private struct MenuRow<Leading: View>: View {
    let title: String
    let detail: String
    let enabled: Bool
    let systemImage: String
    let action: () -> Void
    @ViewBuilder let leading: () -> Leading

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.md) {
                leading()
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(enabled ? .primary : .secondary)
                    Text(detail)
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(enabled ? .secondary : .tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: Theme.Spacing.sm)
                Image(systemName: systemImage)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(enabled ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(.tertiary))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressableRow)
        .disabled(!enabled)
        .accessibilityLabel("\(title). \(detail)")
    }
}
