import SwiftUI
import TycoonEngine

/// The Contracts segment of the Business tab: active client work with live
/// progress, then the current batch of offers to accept.
struct ContractsView: View {
    let engine: GameEngine

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            BusinessSectionHeader(title: "Active", systemImage: "briefcase.fill")
            if engine.state.activeContracts.isEmpty {
                EmptyStateCard(message: "No active contracts — accept an offer to get to work.")
            } else {
                ForEach(engine.state.activeContracts) { job in
                    ActiveContractCard(engine: engine, job: job)
                }
            }

            BusinessSectionHeader(title: "Offers", systemImage: "envelope.fill")
            if engine.state.contractOffers.isEmpty {
                EmptyStateCard(message: "No offers right now — new clients call every week.")
            } else {
                ForEach(engine.state.contractOffers) { offer in
                    ContractOfferCard(engine: engine, offer: offer)
                }
            }
        }
    }
}

// MARK: - Active contract

private struct ActiveContractCard: View {
    let engine: GameEngine
    let job: ContractJob

    private var daysLeft: Int {
        job.deadlineDay - engine.state.day
    }

    /// Nobody assigned means zero daily progress — worth a nudge.
    private var hasWorkers: Bool {
        engine.state.employees.contains { $0.assignment == .contract(job.id) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack(alignment: .top, spacing: Theme.Spacing.sm) {
                Text(job.clientName)
                    .font(.system(.headline, design: .rounded))
                Spacer(minLength: Theme.Spacing.sm)
                DeadlineChip(
                    text: "\(daysLeft) day\(daysLeft == 1 ? "" : "s") left",
                    tint: daysLeft <= 3 ? Theme.negativeCash : .secondary
                )
            }

            VStack(spacing: Theme.Spacing.sm) {
                PhaseProgressBar(
                    label: "Code",
                    points: job.progressCode,
                    required: job.requiredCodePts,
                    tint: Theme.codePhase
                )
                PhaseProgressBar(
                    label: "Design",
                    points: job.progressDesign,
                    required: job.requiredDesignPts,
                    tint: Theme.designPhase
                )
            }

            HStack(spacing: Theme.Spacing.sm) {
                StatPill(
                    systemImage: "dollarsign.circle.fill",
                    value: job.payout.money,
                    tint: Theme.positiveCash
                )
                .accessibilityLabel("Pays \(job.payout.money)")
                Spacer(minLength: 0)
            }

            Text("Miss the deadline and pay \(job.penalty.money).")
                .font(.caption)
                .foregroundStyle(.secondary)

            if !hasWorkers {
                Text("Assign people from the Team tab.")
                    .font(.footnote)
                    .foregroundStyle(Theme.warning)
            }
        }
        .cardStyle()
        .accessibilityElement(children: .contain)
        .accessibilityLabel(
            "Contract with \(job.clientName), \(daysLeft) day\(daysLeft == 1 ? "" : "s") left, pays \(job.payout.money)"
        )
    }
}

// MARK: - Offer

private struct ContractOfferCard: View {
    let engine: GameEngine
    let offer: ContractOffer

    private var expiresIn: Int {
        offer.expiresDay - engine.state.day
    }

    private var requirementSummary: String {
        "Code \(Int(offer.requiredCodePts.rounded())) · Design \(Int(offer.requiredDesignPts.rounded())) pts"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack(alignment: .top, spacing: Theme.Spacing.sm) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(offer.clientName)
                        .font(.system(.headline, design: .rounded))
                    Text(requirementSummary)
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: Theme.Spacing.sm)
                DeadlineChip(
                    text: "Expires in \(expiresIn) day\(expiresIn == 1 ? "" : "s")",
                    tint: .secondary
                )
            }

            HStack(spacing: Theme.Spacing.sm) {
                StatPill(
                    systemImage: "dollarsign.circle.fill",
                    value: offer.payout.money,
                    tint: Theme.positiveCash
                )
                .accessibilityLabel("Pays \(offer.payout.money)")
                Text("Penalty \(offer.penalty.money)")
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(Theme.negativeCash)
                Spacer(minLength: 0)
            }

            HStack(spacing: Theme.Spacing.md) {
                Text("Due in \(offer.deadlineDays) days once accepted")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Spacer(minLength: Theme.Spacing.sm)
                Button("Accept") {
                    engine.send(.acceptContract(offerID: offer.id))
                }
                .font(.system(.footnote, design: .rounded).weight(.semibold))
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
                .accessibilityLabel("Accept the contract from \(offer.clientName)")
            }
        }
        .cardStyle()
        .accessibilityElement(children: .contain)
        .accessibilityLabel(
            "Offer from \(offer.clientName), pays \(offer.payout.money), due in \(offer.deadlineDays) days once accepted, expires in \(expiresIn) day\(expiresIn == 1 ? "" : "s")"
        )
    }
}

// MARK: - Bits

/// Small countdown capsule ("3 days left", "Expires in 5 days").
private struct DeadlineChip: View {
    let text: String
    let tint: Color

    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .monospacedDigit()
            .foregroundStyle(tint)
            .padding(.horizontal, Theme.Spacing.xs + 2)
            .padding(.vertical, 2)
            .background(Theme.chipBackground, in: Capsule())
    }
}

/// Quiet full-width card used when a section has nothing to show.
struct EmptyStateCard: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardStyle()
    }
}
