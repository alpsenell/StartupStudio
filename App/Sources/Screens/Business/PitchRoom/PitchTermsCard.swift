import SwiftUI
import TycoonContent
import TycoonEngine

/// What is actually on the table, as it stands right now.
///
/// Every row is `paper → what it would be if the founder got up now`,
/// computed with the same `PitchRoom` functions the engine settles with,
/// so nothing here is a second copy of the arithmetic. At warmth zero
/// every row shows one number and no arrow — which is the point: a
/// conversation that went nowhere leaves the deal exactly as it was.
struct PitchTermsCard: View {
    let engine: GameEngine
    let session: PitchSession

    private var config: BalanceConfig.PitchBalance { engine.balance.pitch }

    var body: some View {
        CardView(title, systemImage: icon) {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                if session.wantRevealed, let want {
                    Label {
                        Text("They want ")
                            .foregroundStyle(.secondary)
                            + Text(want.name).fontWeight(.semibold)
                    } icon: {
                        Image(systemName: "target")
                            .foregroundStyle(Theme.accent)
                    }
                    .font(.footnote)
                }
                rows
            }
        }
    }

    private var want: PitchWantDef? {
        engine.content.pitchCounterpart(session.counterpart.rawValue)?
            .wants.first { $0.id == session.wantID }
    }

    private var title: String {
        switch session.counterpart {
        case .investor: "On the table"
        case .client: "The job"
        case .journalist: "The launch"
        case .board: "The quarter"
        }
    }

    private var icon: String {
        switch session.counterpart {
        case .investor: "doc.text.fill"
        case .client: "briefcase.fill"
        case .journalist: "newspaper.fill"
        case .board: "gauge.with.needle"
        }
    }

    @ViewBuilder
    private var rows: some View {
        switch session.counterpart {
        case .investor: investorRows
        case .client: clientRows
        case .journalist: journalistRows
        case .board: boardRows
        }
    }

    // MARK: - Investor

    @ViewBuilder
    private var investorRows: some View {
        if let offer = engine.state.investors.pendingOffer {
            let revised = PitchRoom.revised(offer, warmth: session.warmth, balance: config)
            PitchTermRow(
                label: "Cheque",
                from: offer.amount.money,
                to: revised.amount == offer.amount ? nil : revised.amount.money,
                better: revised.amount > offer.amount
            )
            PitchTermRow(
                label: "Their equity",
                from: "\(offer.equity.oneDecimal)%",
                to: revised.equity == offer.equity ? nil : "\(revised.equity.oneDecimal)%",
                better: revised.equity < offer.equity
            )
            PitchTermRow(
                label: "Patience",
                from: "\(offer.patienceWeeks) weeks",
                to: revised.patienceWeeks == offer.patienceWeeks ? nil : "\(revised.patienceWeeks) weeks",
                better: revised.patienceWeeks > offer.patienceWeeks
            )
            PitchFootnote("Get up now and this is the sheet you answer. Taking it, or not, is still your call.")
        } else {
            PitchFootnote("The term sheet has gone.")
        }
    }

    // MARK: - Client

    @ViewBuilder
    private var clientRows: some View {
        if let id = session.subjectID,
           let offer = engine.state.contractOffers.first(where: { $0.id == id }) {
            let revised = PitchRoom.revised(offer, warmth: session.warmth, balance: config)
            PitchTermRow(
                label: "Fee",
                from: offer.payout.money,
                to: revised.payout == offer.payout ? nil : revised.payout.money,
                better: revised.payout > offer.payout
            )
            PitchTermRow(
                label: "Deadline",
                from: "\(offer.deadlineDays) days",
                to: revised.deadlineDays == offer.deadlineDays ? nil : "\(revised.deadlineDays) days",
                better: revised.deadlineDays > offer.deadlineDays
            )
            if offer.requiredSkill > 0 {
                PitchTermRow(
                    label: "Crew they expect",
                    from: "~\(Int(offer.requiredSkill.rounded()))",
                    to: Int(revised.requiredSkill.rounded()) == Int(offer.requiredSkill.rounded())
                        ? nil
                        : "~\(Int(revised.requiredSkill.rounded()))",
                    better: revised.requiredSkill < offer.requiredSkill
                )
            }
            PitchFootnote("The penalty moves with the fee. Accepting it is still a separate decision.")
        } else {
            PitchFootnote("They've taken the job elsewhere.")
        }
    }

    // MARK: - Journalist

    @ViewBuilder
    private var journalistRows: some View {
        let notch = PitchRoom.pressNotch(session.warmth, balance: config)
        let hype = PitchRoom.hypeDelta(session.warmth, balance: config)
        PitchTermRow(
            label: "Their review",
            from: "As it lands",
            to: notch == 0 ? nil : (notch > 0 ? "A notch kinder" : "A notch harsher"),
            better: notch > 0
        )
        PitchTermRow(
            label: "Buzz before launch",
            from: "As it stands",
            to: abs(hype) < 0.5
                ? nil
                : "\(hype > 0 ? "+" : "\u{2212}")\(abs(Int(hype.rounded()))) hype",
            better: hype > 0
        )
        PitchFootnote(
            notch == 0
                ? "A polite twenty minutes doesn't move a review. You need them on side, or against you."
                : "One outlet's verdict, and the front page's lead, move with this."
        )
    }

    // MARK: - Board

    @ViewBuilder
    private var boardRows: some View {
        let pressure = engine.state.investors.boardPressure
        let after = min(100, max(0, pressure + PitchRoom.pressureDelta(session.warmth, balance: config)))
        PitchTermRow(
            label: "Pressure",
            from: "\(Int(pressure.rounded())) / 100",
            to: Int(after.rounded()) == Int(pressure.rounded()) ? nil : "\(Int(after.rounded())) / 100",
            better: after < pressure
        )
        if let expectation = engine.state.investors.boardExpectation {
            PitchFootnote("They watch \(expectation.displayName.lowercased()). This meeting doesn't change that — only how patient they are about it.")
        } else {
            PitchFootnote("This meeting moves the pressure in the room, nothing else.")
        }
    }
}

// MARK: - Bits

/// One term: what the paper says, and what it would say if the founder
/// got up now. The arrow only appears once something has actually moved.
private struct PitchTermRow: View {
    let label: String
    let from: String
    let to: String?
    let better: Bool

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer(minLength: Theme.Spacing.sm)
            Text(from)
                .font(Theme.Typography.number(.subheadline))
                .foregroundStyle(to == nil ? .primary : .secondary)
                .strikethrough(to != nil, color: .secondary)
            if let to {
                Image(systemName: "arrow.right")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.tertiary)
                Text(to)
                    .font(Theme.Typography.number(.subheadline))
                    .foregroundStyle(better ? Theme.positiveCash : Theme.negativeCash)
                    .contentTransition(.numericText())
            }
        }
        .animation(Theme.Motion.valueChange, value: to)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            to.map { "\(label): \(from), now \($0)" } ?? "\(label): \(from), unchanged"
        )
    }
}

private struct PitchFootnote: View {
    let text: String

    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.caption2)
            .foregroundStyle(.tertiary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
