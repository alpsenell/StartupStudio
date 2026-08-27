import SwiftUI
import TycoonEngine

/// A pause-and-choose moment surfaced from pending state (a rival's poach
/// or buyout offer, later staff life events). The id is derived from the
/// underlying offer so a new offer re-presents the sheet.
struct DecisionPrompt: Identifiable {
    struct Option: Identifiable {
        let id = UUID()
        let label: String
        /// One-line consequence shown under the label.
        let detail: String?
        let role: ButtonRole?
        let action: GameAction

        init(label: String, detail: String? = nil, role: ButtonRole? = nil, action: GameAction) {
            self.label = label
            self.detail = detail
            self.role = role
            self.action = action
        }
    }

    let id: String
    let systemImage: String
    let tint: Color
    let title: String
    let message: String
    let stats: [(label: String, value: String)]
    let options: [Option]
}

/// The reusable modal for `DecisionPrompt`s, presented at the app root so
/// the offer surfaces on whatever tab is frontmost. The timeline is paused
/// while one is up, so interactive dismissal is disabled: every way out
/// sends a `GameAction` that clears the pending offer (the decline option
/// is always last).
struct DecisionSheet: View {
    let prompt: DecisionPrompt
    let engine: GameEngine

    var body: some View {
        NavigationStack {
            VStack(spacing: Theme.Spacing.lg) {
                Spacer(minLength: 0)

                Image(systemName: prompt.systemImage)
                    .font(.system(size: 44))
                    .foregroundStyle(prompt.tint)

                VStack(spacing: Theme.Spacing.sm) {
                    Text(prompt.title)
                        .font(.system(.title2, design: .rounded).weight(.bold))
                        .multilineTextAlignment(.center)
                    Text(prompt.message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, Theme.Spacing.xl)

                if !prompt.stats.isEmpty {
                    HStack(spacing: Theme.Spacing.sm) {
                        ForEach(Array(prompt.stats.enumerated()), id: \.offset) { _, stat in
                            StatPill(systemImage: "circle.fill", value: "\(stat.label) \(stat.value)")
                        }
                    }
                }

                Spacer(minLength: 0)

                VStack(spacing: Theme.Spacing.sm) {
                    ForEach(prompt.options) { option in
                        Button(role: option.role) {
                            engine.send(option.action)
                        } label: {
                            VStack(spacing: 2) {
                                Text(option.label)
                                    .font(.system(.headline, design: .rounded))
                                if let detail = option.detail {
                                    Text(detail)
                                        .font(.caption)
                                        .opacity(0.8)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Theme.Spacing.xs)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(option.role == .destructive ? Theme.negativeCash : Theme.accent)
                    }
                }
                .padding(.horizontal, Theme.Spacing.xl)
                .padding(.bottom, Theme.Spacing.xl)
            }
            .background(Theme.screenBackground)
        }
        .presentationDetents([.medium])
        .interactiveDismissDisabled()
    }
}

// MARK: - Prompt mapping

extension DecisionPrompt {
    /// The prompt for whatever offer is pending, poach first. Reads pending
    /// state (not transient events) so an offer survives app relaunches.
    static func pending(in state: GameState, balance: BalanceConfig) -> DecisionPrompt? {
        if let poach = state.rivals.pendingPoach {
            return poachPrompt(poach, state: state)
        }
        if let buyout = state.rivals.pendingBuyout {
            return buyoutPrompt(buyout, state: state)
        }
        if let staffEvent = state.pendingStaffEvent {
            return staffEventPrompt(staffEvent, state: state, balance: balance)
        }
        return nil
    }

    private static func staffEventPrompt(
        _ event: StaffEvent,
        state: GameState,
        balance: BalanceConfig
    ) -> DecisionPrompt? {
        guard let employee = state.employee(id: event.employeeID) else { return nil }
        let social = balance.social
        let (title, message, supportDetail): (String, String, String) = switch event.kind {
        case .familyEmergency: (
            "\(employee.name) has a family emergency",
            "They need some time. Cover for them and pay \(social.supportCost.money), or insist the work comes first.",
            "Costs \(social.supportCost.money) · time off · loyalty way up"
        )
        case .rivalOfferRumor: (
            "\(employee.name) is being courted",
            "Word is a rival has been buying them lunch. Show them they matter — or trust they'll stay.",
            "Costs \(social.supportCost.money) · loyalty way up"
        )
        }
        return DecisionPrompt(
            id: "staff-\(event.employeeID.uuidString)-\(event.respondByDay)",
            systemImage: event.kind == .familyEmergency
                ? "heart.text.square.fill"
                : "person.fill.questionmark",
            tint: Theme.warning,
            title: title,
            message: message,
            stats: [("Loyalty", "\(Int(employee.loyalty.rounded()))")],
            options: [
                Option(
                    label: "Be supportive",
                    detail: supportDetail,
                    action: .resolveStaffEvent(choice: .supportive)
                ),
                Option(
                    label: "Business first",
                    detail: "Free, but loyalty takes a hit",
                    role: .destructive,
                    action: .resolveStaffEvent(choice: .strict)
                ),
            ]
        )
    }

    private static func poachPrompt(_ offer: PoachOffer, state: GameState) -> DecisionPrompt? {
        guard let employee = state.employee(id: offer.employeeID) else { return nil }
        let rivalName = state.rivals.rival(id: offer.rivalID)?.name ?? "A rival"
        return DecisionPrompt(
            id: "poach-\(offer.employeeID.uuidString)-\(offer.respondByDay)",
            systemImage: "person.fill.questionmark",
            tint: Theme.warning,
            title: "\(rivalName) wants \(employee.name)",
            message: "They're offering \(offer.offeredWeeklySalary.money)/wk (currently \(employee.weeklySalary.money)/wk). Match it, or let \(employee.name) walk.",
            stats: [
                ("Offer", "\(offer.offeredWeeklySalary.money)/wk"),
                ("Loyalty", "\(Int(employee.loyalty.rounded()))"),
            ],
            options: [
                Option(
                    label: "Match the offer",
                    detail: "Raise salary to \(offer.offeredWeeklySalary.money)/wk",
                    action: .matchPoachOffer
                ),
                Option(
                    label: "Let them go",
                    detail: "\(employee.name) joins \(rivalName)",
                    role: .destructive,
                    action: .declinePoachOffer
                ),
            ]
        )
    }

    private static func buyoutPrompt(_ offer: BuyoutOffer, state: GameState) -> DecisionPrompt? {
        let rivalName = state.rivals.rival(id: offer.rivalID)?.name ?? "A rival"
        return DecisionPrompt(
            id: "buyout-\(offer.rivalID.uuidString)-\(offer.respondByDay)",
            systemImage: "envelope.badge.fill",
            tint: Theme.accent,
            title: "\(rivalName) wants to buy you out",
            message: "They're offering \(offer.amount.money) for \(state.company.name). Accepting ends the run as a successful exit.",
            stats: [("Offer", offer.amount.money)],
            options: [
                Option(
                    label: "Sell the company",
                    detail: "Exit with \(offer.amount.money)",
                    action: .acceptBuyout
                ),
                Option(
                    label: "Decline",
                    detail: "Keep building",
                    action: .declineBuyout
                ),
            ]
        )
    }
}
