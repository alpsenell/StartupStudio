import SwiftUI
import TycoonEngine

// MARK: T1 (exits and joins)

/// The options row on the buyout and sell-up sheets: the director's loan
/// comes back first, the vested holders are paid their share, and the
/// unvested are answered *before* the tap — **Let them lapse** or
/// **Accelerate**, each with the founder's share of the price on it and
/// what it closes. The sheet's sell and earn-out buttons then send the
/// exit actions that carry the answer (`answering`). `nil` — no row —
/// with no loan and no holder, which is every sheet it was before.
struct ExitOptionsRow {
    let split: LadderExitSplit
    /// The earn-out is one of this sheet's answers: a lapse costs a review
    /// there, and the row says so.
    let offersEarnOut: Bool
    let namePenalty: Double

    static func make(
        price: Int,
        state: GameState,
        balance: BalanceConfig,
        offersEarnOut: Bool
    ) -> ExitOptionsRow? {
        let split = state.ladderExitSplit(price: price, balance: balance)
        guard !split.isEmpty else { return nil }
        return ExitOptionsRow(split: split, offersEarnOut: offersEarnOut, namePenalty: balance.exits.lapsedNamePenalty)
    }

    /// `prompt` with the row on it (or unchanged, with nothing to settle).
    static func attach(
        to prompt: DecisionPrompt,
        price: Int?,
        state: GameState,
        balance: BalanceConfig,
        offersEarnOut: Bool
    ) -> DecisionPrompt {
        guard let price else { return prompt }
        var prompt = prompt
        prompt.exitRow = make(price: price, state: state, balance: balance, offersEarnOut: offersEarnOut)
        return prompt
    }

    /// `option` with its exit action answering the unvested; any other
    /// option unchanged.
    func answering(_ option: DecisionPrompt.Option, accelerate: Bool) -> DecisionPrompt.Option {
        let action: GameAction
        switch option.action {
        case .acceptBuyout: action = .exitAcceptBuyout(accelerate: accelerate)
        case .acceptBuyoutEarnOut: action = .exitAcceptBuyoutEarnOut(accelerate: accelerate)
        case .sellUp: action = .exitSellUp(accelerate: accelerate)
        default: return option
        }
        return DecisionPrompt.Option(
            label: option.label, detail: option.detail, role: option.role,
            cashDelta: option.cashDelta, disabledReason: option.disabledReason, action: action
        )
    }

    // MARK: Copy

    /// "3% in options · 2% not vested".
    var headline: String {
        let out = split.vestedPoints + split.unvestedPoints
        guard out > 0 else { return "Nothing in options" }
        let points = GameState.ladderPoints(out)
        guard split.hasUnvested else { return "\(points) in options, all vested" }
        return "\(points) in options · \(GameState.ladderPoints(split.unvestedPoints)) not vested"
    }

    /// The lines that happen whatever the answer: the loan, the vested.
    var lines: [String] {
        var lines: [String] = []
        if split.loan > 0 {
            lines.append("Your \(split.loan.money) loan to the company comes back to you first.")
        }
        let vested = split.holders.filter { $0.vested > 0 }
        if !vested.isEmpty {
            let names = Self.names(vested.map(\.name))
            lines.append(
                "\(GameState.ladderPoints(split.vestedPoints)) vested: \(split.vestedPaid.money) of the price to \(names)."
            )
        }
        return lines
    }

    let lapseLabel = "Let them lapse"
    let accelerateLabel = "Accelerate"

    /// "$354,667 to you · Tariq won't be coming with you · name +2".
    var lapseDetail: String {
        let leaving = split.unvestedHolders.map(\.name)
        let names = Self.names(leaving)
        var detail = "\(split.founderProceeds(accelerate: false).money) to you · "
            + "\(names) won't come · name +\(Self.number(namePenalty * Double(leaving.count)))"
        if offersEarnOut {
            detail += " · earn-out: a missed review"
        }
        return detail
    }

    /// "$343,226 to you · $11,441 vests for them today · the team arrives whole".
    var accelerateDetail: String {
        "\(split.founderProceeds(accelerate: true).money) to you · "
            + "\(split.accelerationCost.money) vests for them · the team stays whole"
    }

    /// "Priya", "Priya and Tariq", "Priya, Tariq and Sofia".
    static func names(_ full: [String]) -> String {
        let first = full.map { $0.split(separator: " ").first.map(String.init) ?? $0 }
        guard first.count > 1 else { return first.first ?? "nobody" }
        return first.dropLast().joined(separator: ", ") + " and " + (first.last ?? "")
    }

    private static func number(_ value: Double) -> String {
        value == value.rounded() ? "\(Int(value))" : String(format: "%.1f", value)
    }

    // MARK: Lines elsewhere

    /// The feed's line for `.exitSettled`.
    static func settledLine(
        kind: ExitKind, loan: Int, paid: Int, holders: Int, lapsed: Int, accelerated: Bool
    ) -> String {
        let sale = switch kind {
        case .acquired: "The sale"
        case .soldUp: "The sell-up"
        case .earnOut: "The earn-out"
        case .ipo: "The listing"
        }
        var parts: [String] = []
        if loan > 0 { parts.append("repaid your \(loan.money) loan first") }
        if paid > 0 { parts.append("paid \(paid.money) to \(holders) option holder\(holders == 1 ? "" : "s")") }
        var line = sale + " " + (parts.isEmpty ? "settled the options" : parts.joined(separator: " and "))
        if accelerated {
            line += "; the unvested vested today."
        } else if lapsed > 0 {
            line += "; \(lapsed) holder\(lapsed == 1 ? "'s" : "s'") unvested options lapsed back to you."
        } else {
            line += "."
        }
        return line
    }

    /// The post-mortem's line for a sell-up that settled something.
    static func postMortemLine(_ record: ExitRecord) -> String {
        var parts: [String] = []
        if record.loanRepaid > 0 { parts.append("repaid your \(record.loanRepaid.money) director's loan first") }
        if record.optionsPaid > 0 {
            parts.append("paid \(record.optionsPaid.money) of the \(record.price.money) to the option holders")
        }
        var line = "The sale " + (parts.isEmpty ? "settled the options" : parts.joined(separator: " and "))
        if !record.lapsedIDs.isEmpty {
            line += "; \(record.lapsedIDs.count) holder\(record.lapsedIDs.count == 1 ? "" : "s") lost what had not vested"
        }
        return line + "."
    }
}

/// The row itself, on pixel paper above the sheet's answers.
struct ExitOptionsRowView: View {
    let row: ExitOptionsRow
    @Binding var accelerate: Bool

    var body: some View {
        PixelPanel {
            VStack(alignment: .leading, spacing: 6) {
                PixelText(
                    text: String(localized: "OPTIONS", comment: "Pixel header over the buyout sheet's options row. Uppercase A-Z only"),
                    scale: 2, color: Theme.pixelAccent
                )
                Text(row.headline)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.pixelInk)
                ForEach(row.lines, id: \.self) { line in
                    Text(line)
                        .font(.caption)
                        .foregroundStyle(Theme.pixelInk.opacity(0.8))
                        .fixedSize(horizontal: false, vertical: true)
                }
                if row.split.hasUnvested {
                    HStack(alignment: .top, spacing: Theme.Spacing.sm) {
                        choice(false)
                        choice(true)
                    }
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        // The answers are pinned under the question; the row keeps its
        // full height and the question's body gives way instead.
        .fixedSize(horizontal: false, vertical: true)
    }

    private func choice(_ value: Bool) -> some View {
        let selected = accelerate == value
        return Button {
            Haptics.tap()
            accelerate = value
        } label: {
            VStack(spacing: 2) {
                Text(value ? row.accelerateLabel : row.lapseLabel)
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                Text(value ? row.accelerateDetail : row.lapseDetail)
                    .font(.caption2)
                    .opacity(0.9)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(PixelButtonStyle(fill: selected ? Theme.pixelAccent : Theme.pixelInk.opacity(0.35)))
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityHint("Answers the unvested options before you sell")
    }
}

// MARK: end T1
