import SwiftUI
import TycoonContent
import TycoonEngine

/// *How we do things here*: the rules the founder's answers became, each
/// with the day and the person whose question set it, and a way to take
/// one back — publicly, at a cost the confirm names.
///
/// A rule can only be *made* by somebody asking; this card shows and
/// reverses, which is the guard against it reading as a settings page.
struct PoliciesCard: View {
    let engine: GameEngine

    @State private var policyToReverse: StaffPolicy?

    var body: some View {
        CardView("How we do things here", systemImage: "text.book.closed.fill") {
            VStack(spacing: 0) {
                ForEach(Array(policies.enumerated()), id: \.element.id) { index, policy in
                    PolicyRow(
                        policy: policy,
                        name: name(of: policy),
                        rule: rule(of: policy),
                        state: engine.state,
                        // MARK: T6 (away)
                        detail: holidayLine(policy)
                        // MARK: end T6
                    ) {
                        policyToReverse = policy
                    }
                    if index < policies.count - 1 {
                        Divider()
                    }
                }
            }
        }
        .confirmationDialog(
            policyToReverse.map { "Reverse the \(name(of: $0).lowercased()) rule?" } ?? "",
            isPresented: dialogPresented,
            titleVisibility: .visible,
            presenting: policyToReverse
        ) { policy in
            Button(
                policy.choice == .supportive ? "Reverse it — everyone will know" : "Drop the rule",
                role: .destructive
            ) {
                engine.send(.reverseStaffPolicy(flag: policy.flag))
            }
            Button("Keep the rule", role: .cancel) {}
        } message: { policy in
            Text(reversalCost(policy))
        }
    }

    private var policies: [StaffPolicy] { engine.state.staffMemory.policies }

    private func definition(of policy: StaffPolicy) -> StaffEventDef? {
        engine.content.staffEvent(policy.kind.rawValue)
    }

    /// "Parental leave", from the content; the kind's raw name if the
    /// catalog has moved on.
    private func name(of policy: StaffPolicy) -> String {
        definition(of: policy)?.policy?.name ?? policy.kind.rawValue
    }

    /// The answer the rule gives, in the words the sheet used.
    private func rule(of policy: StaffPolicy) -> String {
        guard let def = definition(of: policy) else { return "" }
        return policy.choice == .supportive
            ? (def.supportive?.label ?? def.strict.label)
            : def.strict.label
    }

    /// What reversing costs, in names: the confirm never says "−N" to a
    /// founder who cannot see who N lands on.
    private func reversalCost(_ policy: StaffPolicy) -> String {
        let staff = engine.balance.staff
        guard policy.choice == .supportive else {
            return "Nobody benefited from this rule, so dropping it costs nothing. "
                + "The next person who asks gets the question again."
        }
        let hired = engine.state.employees.filter { !$0.isFounder }
        let benefited = hired.filter { policy.beneficiaries.contains($0.id) }.map(\.name)
        let morale = Int(staff.policyReversalMoralePenalty.rounded())
        let loyalty = Int(staff.policyReversalLoyaltyPenalty.rounded())
        var text = "Everyone on payroll loses \(morale) morale"
        if !benefited.isEmpty {
            text += "; \(benefited.formatted(.list(type: .and))), who benefited, "
                + "\(benefited.count == 1 ? "loses" : "lose") \(loyalty) loyalty too"
        }
        text += ". The next person who asks gets the question again."
        return text
    }

    // MARK: T6 (away)
    /// The holiday rule, in what it does this year: who is away next, or
    /// what the strict answer costs everybody.
    private func holidayLine(_ policy: StaffPolicy) -> String? {
        guard policy.kind == .holidayRequest else { return nil }
        let config = engine.balance.away
        guard policy.choice == .supportive else {
            return "Nobody away · morale target \(Int(config.strictMoraleTarget)) for everyone · burnout talks ×\(String(format: "%.1f", config.strictBurnoutWeight))"
        }
        let next = engine.state.upcomingHolidays(balance: engine.balance).map { holiday in
            let first = holiday.name.split(separator: " ").first.map(String.init) ?? holiday.name
            return "\(first) \(GameState.awayDateLabel(holiday.from))–\(GameState.awayDateLabel(holiday.to))"
        }
        var line = "Morale target +\(Int(config.holidayMoraleTarget)) for everyone"
        if !next.isEmpty { line = "Next away: " + next.joined(separator: " · ") + " · " + line.lowercased() }
        return line
    }
    // MARK: end T6

    private var dialogPresented: Binding<Bool> {
        Binding(
            get: { policyToReverse != nil },
            set: { presented in
                if !presented { policyToReverse = nil }
            }
        )
    }
}

private struct PolicyRow: View {
    let policy: StaffPolicy
    let name: String
    let rule: String
    let state: GameState
    // MARK: T6 (away)
    var detail: String? = nil
    // MARK: end T6
    let reverse: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.md) {
            Image(systemName: DecisionPrompt.staffIcon(for: policy.kind))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(policy.choice == .supportive ? Theme.accent : .secondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                Text(rule)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(provenance)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
                // MARK: T6 (away)
                if let detail {
                    Text(detail)
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                // MARK: end T6
            }

            Spacer(minLength: Theme.Spacing.sm)

            Button(action: reverse) {
                Text("Reverse")
                    .font(.caption.weight(.semibold))
            }
            .buttonStyle(.bordered)
            .tint(Theme.negativeCash)
            .accessibilityLabel("Reverse the \(name.lowercased()) rule")
        }
        .padding(.vertical, Theme.Spacing.sm)
        .accessibilityElement(children: .combine)
    }

    /// "Since March, year 2 · Priya Nair asked · answered for 3".
    private var provenance: String {
        let calendar = GameCalendar(day: policy.setDay)
        var text = "Since \(calendar.monthName), year \(calendar.year) · \(policy.setByName) asked"
        let answered = policy.beneficiaries.count - 1
        if answered > 0 {
            text += " · answered for \(answered) more"
        }
        return text
    }
}
