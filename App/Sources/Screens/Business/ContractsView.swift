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
                EmptyStateCard(
                    message: "No active contracts.",
                    systemImage: "briefcase",
                    hint: "Accept an offer below to put the team on paid work.",
                    tint: Theme.accent
                )
            } else {
                ForEach(engine.state.activeContracts) { job in
                    ActiveContractCard(engine: engine, job: job)
                }
            }

            BusinessSectionHeader(title: "Offers", systemImage: "envelope.fill")
            if engine.state.contractOffers.isEmpty {
                EmptyStateCard(
                    message: "No offers right now.",
                    systemImage: "envelope",
                    hint: "New clients call every week — reputation brings better ones.",
                    tint: Theme.accent
                )
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

    @Environment(AppRouter.self) private var router

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
                .monospacedDigit()
                .foregroundStyle(.secondary)

            if job.requiredSkill > 0 {
                qualityLine
            }

            if !hasWorkers {
                HStack(spacing: Theme.Spacing.md) {
                    Text("Nobody is working on this — it makes no progress.")
                        .font(.footnote)
                        .foregroundStyle(Theme.warning)
                    Spacer(minLength: Theme.Spacing.sm)
                    IdleAssignMenu(engine: engine, assignment: .contract(job.id))
                }
            }
        }
        .cardStyle()
        .accessibilityElement(children: .contain)
        .accessibilityLabel(
            "Contract with \(job.clientName), \(daysLeft) day\(daysLeft == 1 ? "" : "s") left, pays \(job.payout.money)"
        )
    }

    /// How the crew stacks up against the client's skill expectations —
    /// mirrors the engine's delivery grade so a weak crew is flagged
    /// before the client rejects the work.
    @ViewBuilder private var qualityLine: some View {
        let projected = job.projectedQuality
        let quality = engine.balance.contractQuality
        if job.skillDays == 0 {
            Text("Client expects skill ~\(Int(job.requiredSkill.rounded())). Nobody has worked on it yet.")
                .font(.footnote)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        } else if projected >= quality.greatThreshold {
            Text("Crew skill \(Int(job.averageCrewSkill.rounded())) vs. expected \(Int(job.requiredSkill.rounded())) — on track for full pay.")
                .font(.footnote)
                .monospacedDigit()
                .foregroundStyle(Theme.positiveCash)
        } else if projected >= quality.okayThreshold {
            Text("Crew skill \(Int(job.averageCrewSkill.rounded())) vs. expected \(Int(job.requiredSkill.rounded())) — the client will have notes.")
                .font(.footnote)
                .monospacedDigit()
                .foregroundStyle(Theme.warning)
        } else {
            Text("Crew skill \(Int(job.averageCrewSkill.rounded())) is far below the expected \(Int(job.requiredSkill.rounded())) — the client will reject the quality.")
                .font(.footnote)
                .monospacedDigit()
                .foregroundStyle(Theme.negativeCash)
        }
    }
}

// MARK: - Offer

private struct ContractOfferCard: View {
    let engine: GameEngine
    let offer: ContractOffer

    @Environment(GameShell.self) private var injectedShell: GameShell?
    /// See `GameShell.shared`: read optionally, because SwiftUI
    /// updates this property for presented content before the
    /// environment is installed and the non-optional form traps there.
    private var shell: GameShell { injectedShell ?? .shared }

    private var expiresIn: Int {
        offer.expiresDay - engine.state.day
    }

    private var requirementSummary: String {
        var summary = "Code \(Int(offer.requiredCodePts.rounded())) · Design \(Int(offer.requiredDesignPts.rounded())) pts"
        if offer.requiredSkill > 0 {
            summary += " · Skill ~\(Int(offer.requiredSkill.rounded()))"
        }
        return summary
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack(alignment: .top, spacing: Theme.Spacing.sm) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(offer.clientName)
                        .font(.system(.headline, design: .rounded))
                    Text(requirementSummary)
                        .font(Theme.Typography.number(.caption, weight: .regular))
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
                    .font(Theme.Typography.number(.caption, weight: .regular))
                    .foregroundStyle(Theme.negativeCash)
                Spacer(minLength: 0)
            }

            HStack(spacing: Theme.Spacing.md) {
                Text("Due in \(offer.deadlineDays) days once accepted")
                    .font(.footnote)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                Spacer(minLength: Theme.Spacing.sm)
                Button("Accept") {
                    shell.toasts.send(
                        .acceptContract(offerID: offer.id),
                        to: engine,
                        rejected: "\(offer.clientName) pulled the offer"
                    )
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
            .font(Theme.Typography.number(.caption2))
            .foregroundStyle(tint)
            .padding(.horizontal, Theme.Spacing.xs + 2)
            .padding(.vertical, 2)
            .background(Theme.chipBackground, in: Capsule())
    }
}
