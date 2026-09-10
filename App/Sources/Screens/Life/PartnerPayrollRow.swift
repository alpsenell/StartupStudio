import SwiftUI
import TycoonEngine

// MARK: K7 (partner and diary)

/// Iteration 15 — K7. The partner card's office row.
///
/// Before: *Hire them*, with the ask, the role and both couplings printed —
/// what their morale reads today, what a crunch week costs the marriage,
/// and what the breakup would mean. After: what the office is doing to the
/// marriage today, in numbers ("−0.6 a day: the office" during crunch), and
/// the household draw the room is holding against its median.
struct PartnerPayrollRow: View {
    let engine: GameEngine

    @Environment(GameShell.self) private var injectedShell: GameShell?
    /// See `GameShell.shared`: read optionally, because SwiftUI updates
    /// presented content before the environment is installed.
    private var shell: GameShell { injectedShell ?? .shared }

    var body: some View {
        let state = engine.state
        if let partner = state.partnerOnPayroll {
            onPayroll(partner, state: state)
        } else if state.life.family.stage == .partner || state.life.family.stage == .married {
            hireRow(state: state)
        }
    }

    // MARK: Before

    private func hireRow(state: GameState) -> some View {
        let balance = engine.balance
        let blocker = state.partnerHireBlocker(balance: balance)
        let ask = state.partnerHireAsk(balance: balance) ?? 0
        let role = state.partnerHireProfile?.role.displayName ?? "Generalist"
        let morale = (state.life.family.affection - 50) * balance.partner.moraleAffectionFactor
        let crunch = abs(balance.partner.crunchAffectionPerDay)
        return Button { hire(state: state) } label: {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: "briefcase.fill")
                        .foregroundStyle(blocker == nil ? Theme.romance : .secondary)
                        .frame(width: 22)
                    Text("Hire them · \(role) · \(ask.money)/wk")
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(.primary)
                    Spacer(minLength: 0)
                }
                Text("Loyal from day one: their morale reads affection, \(signed(morale)) today. Crunch costs the marriage \(decimal(crunch)) a day; a launch +\(Int(balance.partner.shipAffection)), a burnout \(signed(balance.partner.burnoutAffection)).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Their pay comes home and counts as yours against the team's median. A breakup is a resignation the same day, and a settlement takes a slice however short the marriage.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if let blocker {
                    Text(blocker)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Theme.warning)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Theme.Spacing.md)
            .background(Theme.chipBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.pressableRow)
        .disabled(blocker != nil)
        .accessibilityLabel("Hire them, \(ask.money) a week. \(blocker ?? "")")
    }

    private func hire(state: GameState) {
        let first = firstName(state.life.family.partnerName)
        Haptics.commit()
        shell.toasts.send(
            .hirePartner, to: engine,
            ack: "\(first) starts Monday.",
            rejected: state.partnerHireBlocker(balance: engine.balance) ?? "Not right now.",
            icon: "briefcase.fill"
        )
    }

    // MARK: After

    private func onPayroll(_ partner: Employee, state: GameState) -> some View {
        let balance = engine.balance
        let morale = state.partnerMoraleTargetDelta(for: partner, balance: balance)
        let crunch = state.partnerCrunchAffectionPerDay(balance: balance)
        let draw = state.life.founderSalary + partner.weeklySalary
        return VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Label("Works here · \(partner.role.displayName) · \(partner.weeklySalary.money)/wk", systemImage: "briefcase.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.romance)
            Text("Their morale target \(signed(morale)) from affection.")
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(.secondary)
            if crunch < 0 {
                Label("\(decimal(crunch)) a day: the office", systemImage: "flame.fill")
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(Theme.warning)
            } else {
                Text("The office is off crunch: affection moves with your schedule alone.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(drawLine(draw: draw, state: state))
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.md)
        .background(Theme.chipBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private func drawLine(draw: Int, state: GameState) -> String {
        guard let median = state.teamMedianSalary else {
            return "Household draw \(draw.money)/wk."
        }
        return "Household draw \(draw.money)/wk against a team median of \(median.money)."
    }

    // MARK: Formatting

    private func signed(_ value: Double) -> String {
        let rounded = Int(value.rounded())
        return rounded > 0 ? "+\(rounded)" : rounded < 0 ? "−\(-rounded)" : "±0"
    }

    private func decimal(_ value: Double) -> String {
        let text = String(format: "%.1f", abs(value))
        return value < 0 ? "−\(text)" : text
    }

    private func firstName(_ name: String?) -> String {
        name.flatMap { $0.split(separator: " ").first.map(String.init) } ?? "They"
    }
}

/// The roster row's chip for the partner on payroll.
struct PartnerChip: View {
    var body: some View {
        Image(systemName: "heart.fill")
            .font(.caption2.weight(.bold))
            .foregroundStyle(Theme.romance)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(Theme.romance.opacity(0.15), in: Capsule())
            .accessibilityLabel("Your partner")
    }
}

// MARK: end K7
