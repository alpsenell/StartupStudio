import SwiftUI
import TycoonEngine

// MARK: - Iteration 15 — K1 (founder money)
//
// The money sheet's card for the founder's own money in the company: the
// director's loan (lend, take back) and the dividend (the split printed
// line by line, and every price on the sheet before the tap). One home:
// the money sheet, opened from the HUD's cash pill. The Life tab's money
// card carries a one-line note that links here; the landlord's question is
// a sheet on the queue (`founderMoneyRescuePrompt`).

/// The founder's money in the company, on the money sheet.
struct FounderMoneyCard: View {
    let engine: GameEngine

    @Environment(GameShell.self) private var injectedShell: GameShell?
    /// See `GameShell.shared`: read optionally, as `MoneyCard` does.
    private var shell: GameShell { injectedShell ?? .shared }

    @State private var lendIndex = 1
    @State private var dividendIndex = 1

    var body: some View {
        let state = engine.state
        let balance = engine.balance
        CardView(
            String(localized: "Your money in the company", comment: "Money sheet card: the director's loan and the dividend"),
            systemImage: "arrow.left.arrow.right.circle.fill"
        ) {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                loanSection(state: state, balance: balance)
                Divider()
                dividendSection(state: state, balance: balance)
            }
        }
    }

    // MARK: The director's loan

    @ViewBuilder
    private func loanSection(state: GameState, balance: BalanceConfig) -> some View {
        let owed = state.founderMoney.directorLoan
        let wallet = state.life.wallet
        let cash = state.company.cash
        let burn = engine.weeklyBurn
        let amounts = Self.lendAmounts(wallet: wallet)
        let amount = amounts.isEmpty ? 0 : amounts[min(lendIndex, amounts.count - 1)]

        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            PixelText(text: String(localized: "DIRECTORS LOAN", comment: "Bitmap kicker on the money sheet: the founder's loan to the company. Uppercase A-Z only"), scale: 2, color: Theme.pixelAccent)
            row(String(localized: "The company owes you", comment: "Money sheet row: the director's loan outstanding"), owed.money, tint: owed > 0 ? Theme.accent : .secondary)
            Text("Your own money, lent to the company. Repaid when you ask and cash covers it, and first out of the next round's cheque. If the company goes under, it goes with it.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if amounts.count > 1 {
                chips(amounts.map(\.money), selected: min(lendIndex, amounts.count - 1)) { lendIndex = $0 }
            }
            actionButton(
                title: String(localized: "Lend \(amount.money)", comment: "Money sheet button: lend the company money from the wallet"),
                detail: String(localized: "Wallet \(wallet.money) → \((wallet - amount).money) · runway \(Self.runway(cash, burn)) → \(Self.runway(cash + amount, burn))", comment: "Under the lend button: what it does to the wallet and the runway"),
                refusal: state.founderMoneyLendBlocker(amount: amount),
                prominent: false
            ) {
                shell.toasts.send(
                    .lendToCompany(amount: amount), to: engine,
                    ack: String(localized: "Lent the company \(amount.money)", comment: "Toast after lending the company money"),
                    icon: "arrow.right.circle.fill"
                )
            }

            if owed > 0 {
                let back = min(owed, max(0, cash))
                actionButton(
                    title: String(localized: "Take back \(back.money)", comment: "Money sheet button: repay the director's loan"),
                    detail: String(localized: "Cash \(cash.money) → \((cash - back).money) · runway \(Self.runway(cash, burn)) → \(Self.runway(cash - back, burn))", comment: "Under the repay button: what it does to company cash and runway"),
                    refusal: state.founderMoneyRepayBlocker(amount: back),
                    prominent: false
                ) {
                    shell.toasts.send(
                        .repayDirectorLoan(amount: back), to: engine,
                        ack: String(localized: "The company repaid \(back.money)", comment: "Toast after the director's loan is repaid"),
                        icon: "arrow.left.circle.fill"
                    )
                }
                if let offer = state.investors.pendingOffer {
                    Text("\(offer.investorName)'s cheque repays it first: the company would see \(max(0, offer.amount - owed).money) of their \(offer.amount.money).")
                        .font(.caption)
                        .foregroundStyle(Theme.warning)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    // MARK: The dividend

    @ViewBuilder
    private func dividendSection(state: GameState, balance: BalanceConfig) -> some View {
        let config = balance.founderMoney
        let most = state.founderMoneyMaxDividend(balance: balance)
        let amounts = Self.dividendAmounts(most: most)
        let amount = amounts.isEmpty ? 0 : amounts[min(dividendIndex, amounts.count - 1)]
        let take = state.founderMoneyDividendTake(amount)
        let refusal = state.founderMoneyDividendBlocker(amount: amount, balance: balance)

        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            PixelText(text: String(localized: "DIVIDEND", comment: "Bitmap kicker on the money sheet: paying the company's cash out to its owners. Uppercase A-Z only"), scale: 2, color: Theme.pixelAccent)
                .background { FounderMoneyDebugScroller() }
            Text("The company pays out; you keep your \(Self.percent(state.investors.equityRemaining)) and the rest of the cap table takes theirs. Once a quarter, and never below \(config.dividendRunwayWeeks) weeks of runway.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if amounts.count > 1 {
                chips(amounts.map(\.money), selected: min(dividendIndex, amounts.count - 1)) { dividendIndex = $0 }
            }

            if amount > 0 {
                VStack(spacing: 4) {
                    ForEach(state.founderMoneyDividendSplit(amount: amount)) { line in
                        HStack {
                            Text("\(line.name) · \(Self.percent(line.percent))")
                                .font(.caption.weight(line.isFounder ? .semibold : .regular))
                                .foregroundStyle(line.isFounder ? .primary : .secondary)
                            Spacer()
                            Text(line.amount.money)
                                .font(Theme.Typography.number(.caption, weight: line.isFounder ? .semibold : .regular))
                                .foregroundStyle(line.isFounder ? Theme.positiveCash : .secondary)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
                .padding(Theme.Spacing.sm)
                .background(Theme.chipBackground, in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                // The prices, only while the button would pay: a refused
                // dividend carries its reason instead.
                ForEach(refusal == nil ? priceLines(state: state, balance: balance, amount: amount, take: take) : [], id: \.self) { line in
                    Label(line, systemImage: "exclamationmark.circle")
                        .font(.caption)
                        .foregroundStyle(Theme.warning)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            actionButton(
                title: amount > 0
                    ? String(localized: "Pay \(amount.money) · you take \(take.money)", comment: "Money sheet button: declare a dividend; the founder's share is on the button")
                    : String(localized: "Pay a dividend", comment: "Money sheet button when no dividend can be paid"),
                detail: amount > 0
                    ? String(localized: "Cash \(state.company.cash.money) → \((state.company.cash - amount).money) · wallet \(state.life.wallet.money) → \((state.life.wallet + take).money)", comment: "Under the dividend button: cash and wallet before and after")
                    : nil,
                refusal: refusal,
                prominent: true
            ) {
                shell.toasts.send(
                    .declareDividend(amount: amount), to: engine,
                    ack: String(localized: "Paid a \(amount.money) dividend · you took \(take.money)", comment: "Toast after a dividend"),
                    icon: "chart.pie.fill"
                )
            }

            if let until = state.founderMoneyDividendPayUntilDay(balance: balance) {
                Text("Your last dividend reads as \(state.founderMoneyDividendWeeklyPay(balance: balance).money)/wk of pay until day \(until).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// The prices, before the tap: the board, the streak, the team, the
    /// calendar.
    private func priceLines(state: GameState, balance: BalanceConfig, amount: Int, take: Int) -> [String] {
        let config = balance.founderMoney
        var lines: [String] = []
        if state.founderMoneyDividendAngersBoard {
            lines.append(String(localized: "Your board adds \(Int(config.dividendBoardPressure.rounded())) to its pressure: last quarter lost money.", comment: "Dividend price line: board pressure"))
        } else if state.investors.hasBoard {
            lines.append(String(localized: "Your board lets it pass: last quarter was profitable.", comment: "Dividend price line: no board pressure"))
        }
        let streak = state.investors.profitableQuarters
        lines.append(streak > 0
            ? String(localized: "It is an expense: this quarter must still grow past it, or the \(streak)-quarter profitable streak ends.", comment: "Dividend price line: the profitable streak")
            : String(localized: "It is an expense: this quarter must grow past it to count as profitable.", comment: "Dividend price line: the profitable quarter"))
        if let median = state.teamMedianSalary, median > 0 {
            let weekly = Int((Double(take) / Double(max(1, config.dividendPayWeeks))).rounded())
            let economy = balance.economy
            let ratio = Double(state.life.founderSalary + weekly) / Double(median)
            let penalty = min(economy.founderPayMoraleCap, max(0, ratio - economy.founderPayFairRatio) * economy.founderPayMoralePerRatioPoint)
            lines.append(penalty > 0
                ? String(localized: "For \(config.dividendPayWeeks) weeks the team reads \(weekly.money)/wk on top of your salary: −\(penalty.formatted(.number.precision(.fractionLength(1)).locale(Theme.gameLocale))) morale.", comment: "Dividend price line: the team reads it as pay, with a morale cost")
                : String(localized: "For \(config.dividendPayWeeks) weeks the team reads \(weekly.money)/wk on top of your salary; it stays inside the band.", comment: "Dividend price line: the team reads it as pay, no morale cost"))
        }
        lines.append(String(localized: "The next one no sooner than day \(state.day + config.dividendIntervalDays).", comment: "Dividend price line: the interval"))
        return lines
    }

    // MARK: Pieces

    private func row(_ label: String, _ value: String, tint: Color) -> some View {
        HStack {
            Text(label).font(.subheadline).foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(Theme.Typography.number(.subheadline))
                .foregroundStyle(tint)
                .contentTransition(.numericText())
        }
        .accessibilityElement(children: .combine)
    }

    private func chips(_ labels: [String], selected: Int, pick: @escaping (Int) -> Void) -> some View {
        HStack(spacing: Theme.Spacing.xs) {
            ForEach(Array(labels.enumerated()), id: \.offset) { index, label in
                Button {
                    Haptics.tap()
                    pick(index)
                } label: {
                    Text(label)
                        .font(Theme.Typography.number(.caption, weight: .semibold))
                        .padding(.horizontal, Theme.Spacing.sm)
                        .padding(.vertical, 5)
                        .frame(maxWidth: .infinity)
                        .background(
                            index == selected ? Theme.accent.opacity(0.22) : Theme.chipBackground,
                            in: Capsule()
                        )
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(index == selected ? .isSelected : [])
            }
        }
    }

    /// A button with its consequence under it, or greyed with the reason.
    private func actionButton(
        title: String,
        detail: String?,
        refusal: String?,
        prominent: Bool,
        action: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Button {
                Haptics.commit()
                action()
            } label: {
                Text(title)
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Spacing.xs)
            }
            .buttonStyle(prominent ? AnyPrimitiveButtonStyle(.borderedProminent) : AnyPrimitiveButtonStyle(.bordered))
            .tint(Theme.accent)
            .disabled(refusal != nil)
            if let refusal {
                Text(refusal)
                    .font(.caption)
                    .foregroundStyle(Theme.warning)
                    .fixedSize(horizontal: false, vertical: true)
            } else if let detail {
                Text(detail)
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: Numbers

    /// $1k, $5k, $10k, $25k, $50k that the wallet holds, and the whole
    /// wallet when it is none of those.
    static func lendAmounts(wallet: Int) -> [Int] {
        guard wallet > 0 else { return [] }
        var amounts = [1_000, 5_000, 10_000, 25_000, 50_000].filter { $0 < wallet }
        amounts.append(wallet)
        return Array(amounts.suffix(4))
    }

    /// A quarter, a half and all of what the runway floor allows, to the
    /// hundred dollars.
    static func dividendAmounts(most: Int) -> [Int] {
        guard most >= 100 else { return [] }
        let picks = [most / 4, most / 2, most].map { $0 / 100 * 100 }.filter { $0 > 0 }
        return picks.reduce(into: [Int]()) { if !$0.contains($1) { $0.append($1) } }
    }

    static func runway(_ cash: Int, _ burn: Int) -> String {
        guard cash >= 0 else { return String(localized: "in the red", comment: "Runway readout when cash is below zero") }
        guard burn > 0 else { return "∞" }
        return String(localized: "\(cash / burn) wk", comment: "Runway readout: weeks of cash left. wk is short for weeks")
    }

    static func percent(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...1)).locale(Theme.gameLocale)) + "%"
    }
}

/// `.bordered` or `.borderedProminent`, chosen at runtime.
private struct AnyPrimitiveButtonStyle: PrimitiveButtonStyle {
    private let make: (Configuration) -> AnyView

    init<S: PrimitiveButtonStyle>(_ style: S) {
        make = { AnyView(style.makeBody(configuration: $0)) }
    }

    func makeBody(configuration: Configuration) -> some View { make(configuration) }
}

// MARK: - The Life tab's note

/// One line on the Life tab's money card: what the company owes the
/// founder, the dividend still reading as pay, the landlord's question.
/// Silent when there is none of it.
struct FounderMoneyLifeNote: View {
    let engine: GameEngine

    var body: some View {
        let lines = Self.lines(engine.state, balance: engine.balance)
        if !lines.isEmpty {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(lines, id: \.self) { line in
                    Text(line)
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    static func lines(_ state: GameState, balance: BalanceConfig) -> [String] {
        var lines: [String] = []
        let money = state.founderMoney
        if money.directorLoan > 0 {
            lines.append(String(localized: "The company owes you \(money.directorLoan.money).", comment: "Life money card: the director's loan outstanding"))
        }
        if let until = state.founderMoneyDividendPayUntilDay(balance: balance) {
            lines.append(String(localized: "Your dividend reads as \(state.founderMoneyDividendWeeklyPay(balance: balance).money)/wk of pay until day \(until).", comment: "Life money card: the dividend still counted as pay"))
        }
        if let by = money.rescueRespondByDay {
            lines.append(money.rescueSelling
                ? String(localized: "Sell something: your wallet has to be back above the line by day \(by).", comment: "Life money card: the founder chose to sell something before the landlord calls")
                : String(localized: "The landlord wants an answer by day \(by). It is on the rail.", comment: "Life money card: the landlord's question is open"))
        }
        return lines
    }
}

// MARK: - The landlord's question

extension DecisionPrompt {
    /// The eviction warning, as a question: the company's money in public,
    /// a smaller home, or something sold by the deadline. `nil` once the
    /// founder chose to sell (the question then waits in the assets room).
    static func founderMoneyRescuePrompt(state: GameState, balance: BalanceConfig) -> DecisionPrompt? {
        let money = state.founderMoney
        guard let by = money.rescueRespondByDay, !money.rescueSelling else { return nil }
        let wallet = state.life.wallet
        let line = balance.economy.evictionWalletThreshold
        let rescue = state.founderMoneyRescueSalary(balance: balance)
        let home = state.life.home
        let rentNow = homeWeeklyRent(home, balance: balance)
        let mood = Int(balance.life.breakupMoodPenalty / 2)
        let worth = state.assetResaleValue(balance: balance)
        let median = state.teamMedianSalary

        var takeDetail = String(localized: "\(rescue.money)/wk from the company until you are square, not \(state.life.founderSalary.money).", comment: "Rescue option detail: the salary the company would pay")
        if let median, median > 0 {
            takeDetail += " " + String(localized: "The team's median is \(median.money)/wk and they will read it; so will a board.", comment: "Rescue option detail: the team and the board see it")
        }
        takeDetail += " " + String(localized: "On your name for a year.", comment: "Rescue option detail: the standing cost")

        let moveLabel = home.previous.map {
            String(localized: "Move to a \($0.displayName.lowercased())", comment: "Rescue option: move one home down")
        } ?? String(localized: "Move somewhere cheaper", comment: "Rescue option: move down, when there is nowhere cheaper")
        let moveDetail = home.previous.map {
            String(localized: "Rent \(rentNow.money)/wk → \(homeWeeklyRent($0, balance: balance).money)/wk · mood −\(mood). What happens if you say nothing.", comment: "Rescue option detail: the rent change and the mood cost of moving down")
        }

        return DecisionPrompt(
            id: "rescue-\(by)",
            systemImage: "house.badge.exclamationmark",
            tint: Theme.negativeCash,
            title: String(localized: "The landlord wants the arrears", comment: "Decision sheet title: the eviction warning as a question"),
            message: String(localized: "The letter is on the mat again. You are \(abs(min(0, wallet)).money) down and the landlord wants it cleared by day \(by). The company could cover you. Everybody would know.", comment: "Decision sheet body: the rescue question"),
            stats: [
                (String(localized: "Wallet", comment: "Decision sheet stat: the founder's wallet"), wallet.money),
                (String(localized: "Due", comment: "Decision sheet stat: the landlord's deadline"), String(localized: "day \(by)", comment: "A game day")),
            ],
            options: [
                Option(
                    label: String(localized: "Take the company's money", comment: "Rescue option: the company raises the founder's salary"),
                    detail: takeDetail,
                    disabledReason: state.founderMoneyRescueTakeBlocker(balance: balance),
                    action: .answerRescue(.take)
                ),
                Option(
                    label: moveLabel,
                    detail: moveDetail,
                    role: .destructive,
                    disabledReason: state.founderMoneyMoveDownBlocker,
                    action: .answerRescue(.moveDown)
                ),
                Option(
                    label: String(localized: "Sell something", comment: "Rescue option: sell an asset before the deadline"),
                    detail: String(localized: "Your things would fetch \(worth.money). Counts only if your wallet is back above \(line.money) by day \(by).", comment: "Rescue option detail: selling counts only by the deadline"),
                    disabledReason: worth > 0 ? nil : String(localized: "You own nothing to sell", comment: "Rescue option refusal: no assets"),
                    action: .answerRescue(.sell)
                ),
            ],
            kicker: String(localized: "LANDLORD", comment: "Bitmap kicker: the landlord's question. Uppercase A-Z only")
        )
    }
}

// MARK: - Debug

/// DEBUG: with `-autoFounderMoney dividend|paid`, scroll the money sheet so
/// the dividend is on screen — after the shop card's own scroll (1.5 s),
/// on an anchor of its own.
private struct FounderMoneyDebugScroller: View {
    var body: some View {
        #if DEBUG
        ScrollViewReader { proxy in
            Color.clear
                .id("k1.founderMoney.dividendAnchor")
                .task {
                    guard ["dividend", "paid"].contains(DebugLaunch.founderMoneySeed ?? "") else { return }
                    try? await Task.sleep(for: .seconds(3))
                    proxy.scrollTo("k1.founderMoney.dividendAnchor", anchor: .top)
                }
        }
        #else
        Color.clear
        #endif
    }
}

/// `-autoFounderMoney loan|dividend|paid|rescue`: one situation each,
/// seeded a beat after launch (`FounderMoneySystem.debugSeed`). Pair with
/// `-autoRoute shop` to open the money sheet over it. Debug builds only;
/// nothing in the game sends the seed.
@MainActor
enum FounderMoneyDebug {
    static func startIfAsked(current: @escaping () -> GameEngine) async {
        #if DEBUG
        guard let kind = DebugLaunch.founderMoneySeed else { return }
        try? await Task.sleep(for: .milliseconds(700))
        current().send(.founderMoneyDebugSeed(kind: kind))
        #endif
    }
}
