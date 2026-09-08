import SwiftUI
import TycoonEngine

/// Iteration 11 — N1. Everything the founder can do between the day the
/// case is raised and the day it is heard: pay it away, buy a better
/// lawyer, pick a line, or walk in.
struct CrimeCaseCard: View {
    let engine: GameEngine
    let legalCase: LegalCase
    /// Opens the courtroom.
    var onStand: () -> Void

    private var days: Int { legalCase.daysToHearing(from: engine.state.day) }
    private var canStand: Bool { engine.state.day >= legalCase.hearingDay }

    var body: some View {
        CardView(
            legalCase.isFounderSuing ? "Your suit" : "The case against you",
            systemImage: "building.columns.fill"
        ) {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                header
                if !legalCase.isFounderSuing {
                    evidenceBar
                    lawyers
                    defences
                    settle
                }
                standUp
            }
        }
    }

    // MARK: - What it is

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
            Text(days == 0
                ? "Listed for today, \(GameState.dateLabel(forDay: legalCase.hearingDay))."
                : "Listed for \(GameState.dateLabel(forDay: legalCase.hearingDay)) — \(days) day\(days == 1 ? "" : "s").")
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
    }

    private var title: String {
        if legalCase.isFounderSuing {
            let name = legalCase.rivalID
                .flatMap { id in engine.state.rivals.rival(id: id)?.name } ?? "a studio"
            return "You against \(name)."
        }
        guard let offence = legalCase.offence else { return "A matter is listed." }
        return "\(offence.accuser) has brought a charge of \(offence.chargeName)."
    }

    // MARK: - What they have

    private var evidenceBar: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("WHAT THEY HAVE")
                    .font(.caption2.weight(.bold))
                    .kerning(0.8)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                Text(evidenceWord)
                    .font(.system(.caption, design: .rounded).weight(.bold))
                    .foregroundStyle(legalCase.evidence > 0.6 ? Theme.negativeCash : Theme.warning)
            }
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.chipBackground)
                    Capsule()
                        .fill(legalCase.evidence > 0.6 ? Theme.negativeCash : Theme.warning)
                        .frame(width: max(2, geometry.size.width * legalCase.evidence))
                }
            }
            .frame(height: 8)
            Text(engine.state.knownDepartments.contains(.legal)
                ? "Legal got to it first, which is why it is not worse."
                : "You have no legal department. Nobody got to it first.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var evidenceWord: String {
        switch legalCase.evidence {
        case ..<0.3: "A suspicion"
        case ..<0.55: "A paper trail"
        case ..<0.8: "Most of it"
        default: "Everything"
        }
    }

    // MARK: - Who is representing you

    private var lawyers: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Representation")
                .font(.caption2.weight(.bold))
                .kerning(0.8)
                .foregroundStyle(.secondary)
            ForEach(CrimeLawyer.ladder, id: \.self) { tier in
                let fee = engine.balance.crime.fee(for: tier)
                let affordable = fee == 0 || engine.state.life.wallet >= fee
                CrimeChoiceRow(
                    title: tier.displayName,
                    detail: tier.blurb,
                    cost: fee == 0
                        ? "Free · no objections"
                        : "\(fee.money) of your own · \(tier.objections) objection\(tier.objections == 1 ? "" : "s")",
                    selected: legalCase.lawyer == tier,
                    enabled: affordable && !canStand,
                    symbol: "person.text.rectangle.fill"
                ) {
                    engine.send(.hireLawyer(tier: tier))
                    Haptics.commit()
                }
            }
        }
    }

    // MARK: - What you are going to say

    private var defences: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("The line you will run")
                .font(.caption2.weight(.bold))
                .kerning(0.8)
                .foregroundStyle(.secondary)
            ForEach(CrimeDefence.allCases, id: \.self) { defence in
                CrimeChoiceRow(
                    title: defence.displayName,
                    detail: defence.blurb,
                    cost: "Rewards “\(defence.favours.displayName)” in the room",
                    selected: legalCase.defence == defence,
                    enabled: !canStand,
                    symbol: defence.favours.symbol
                ) {
                    engine.send(.chooseDefence(defence))
                    Haptics.tap()
                }
            }
        }
    }

    // MARK: - Money

    @ViewBuilder
    private var settle: some View {
        let price = legalCase.settlementPrice
        let canPay = engine.state.life.wallet + engine.state.company.cash >= price
        VStack(alignment: .leading, spacing: 4) {
            Button("Settle for \(price.money)", systemImage: "banknote.fill") {
                engine.send(.settleCase)
                Haptics.commit()
            }
            .buttonStyle(.pressable)
            .font(.footnote.weight(.semibold))
            .disabled(!canPay)
            Text(canPay
                ? "Your wallet first, the company for the rest. No admission, no hearing, and it stays on the record."
                : "You cannot cover it. Your wallet and the company together are short \(max(0, price - engine.state.life.wallet - engine.state.company.cash).money).")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - The door

    @ViewBuilder
    private var standUp: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button("Go to court", systemImage: "figure.stand") { onStand() }
                .buttonStyle(.pressable)
                .font(.footnote.weight(.semibold))
                .disabled(!canStand)
            if !canStand {
                Text("Not until the hearing day. Until then you can prepare, pay, or think about it.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("The clock stops when you walk in.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

// MARK: - A choosable row

/// A row that is a choice rather than a command: it shows what it is,
/// what it costs and whether it is the one currently picked.
struct CrimeChoiceRow: View {
    let title: String
    let detail: String
    let cost: String
    let selected: Bool
    let enabled: Bool
    let symbol: String
    let tap: () -> Void

    var body: some View {
        Button(action: tap) {
            HStack(alignment: .top, spacing: Theme.Spacing.md) {
                Image(systemName: selected ? "checkmark.circle.fill" : symbol)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(selected ? Theme.positiveCash : (enabled ? Theme.accent : .secondary))
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    Text(detail)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(cost)
                        .font(.caption2)
                        .monospacedDigit()
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Theme.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Theme.chipBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(selected ? Theme.positiveCash.opacity(0.6) : .clear, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.pressableRow)
        .disabled(!enabled)
        .accessibilityLabel("\(title). \(detail). \(cost)\(selected ? ". Chosen" : "")")
    }
}
