import SwiftUI
import TycoonEngine

/// One screen for all the money, opened from the HUD's cash pill.
///
/// The money story used to be told on three tabs: burn and runway on HQ,
/// the loan on Business → Finances, the wallet on Life → Money, and the
/// rule that the house secures the loan connected numbers no screen showed
/// together. This is where they sit side by side; the three cards keep
/// their summaries and link here.
struct MoneySheet: View {
    let engine: GameEngine

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                MoneySheetContent(engine: engine) { dismiss() }
                    .padding(Theme.Spacing.lg)
            }
            .background(Theme.screenBackground)
            .navigationTitle("Money")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

/// The sheet without its navigation chrome, so a snapshot can draw it.
struct MoneySheetContent: View {
    let engine: GameEngine
    /// Called before a deep link, so the sheet is out of the way.
    var beforeRoute: (() -> Void)?

    /// Optional, not because a sheet might be drawn without a router —
    /// it always has one — but because SwiftUI updates a presented sheet's
    /// content *while the host is being torn down*, and a non-optional
    /// `@Environment(AppRouter.self)` read traps there (the crash
    /// `StorefrontAutoRoute` documents). `OfficeCard` reads it the same
    /// way for the same reason. A nil router means the tap has nowhere to
    /// go, which on a sheet that is closing is exactly right.
    @Environment(AppRouter.self) private var router: AppRouter?

    var body: some View {
        let state = engine.state
        let balance = engine.balance
        let life = state.life
        let cash = state.company.cash
        let burn = engine.weeklyBurn
        let incomeLastWeek = state.ledger.entries
            .filter { $0.amount > 0 && $0.day > state.day - 7 }
            .reduce(0) { $0 + $1.amount }
        let worstDebt = state.codebases.map(\.debt).max() ?? 0
        let outstanding = state.loanBalance
        let creditLimit = state.creditLimit(balance: balance)
        let secured = state.securedHeadroom(balance: balance)
        let interest = Int((Double(outstanding) * balance.loans.weeklyInterestRate).rounded())
        let rent = homeWeeklyRent(life.home, balance: balance)
        let median = state.teamMedianSalary

        VStack(spacing: Theme.Spacing.lg) {
            CardView(String(localized: "Company", comment: "Money sheet card: the company purse"), systemImage: "building.2.fill") {
                VStack(spacing: Theme.Spacing.sm) {
                    row(String(localized: "Cash", comment: "One word, used both for the money-sheet row showing cash on hand and for the weekly report card about money in and out"), cash.money, tint: cash < 0 ? Theme.negativeCash : .primary)
                    row(String(localized: "Weekly burn", comment: "Money sheet row: what the company spends a week"), String(localized: "\(burn.money)/wk", comment: "Money per week. wk is short for week"), tint: burn > 0 ? Theme.warning : .primary)
                    row(String(localized: "Runway", comment: "Money sheet row: how long the cash lasts"), runway(cash: cash, burn: burn).text, tint: runway(cash: cash, burn: burn).tint)
                    row(String(localized: "Income last week", comment: "Money sheet row: money in over the last week"), incomeLastWeek.money, tint: incomeLastWeek > 0 ? Theme.positiveCash : .secondary)
                    if worstDebt >= 1 {
                        row(String(localized: "Technical debt", comment: "Money sheet row: the worst codebase debt score"), "\(Int(worstDebt.rounded()))", tint: Theme.warning)
                    }
                }
            }

            CardView(String(localized: "Bank", comment: "Money sheet card: loans and the credit limit"), systemImage: "banknote.fill") {
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    row(String(localized: "Outstanding", comment: "Money sheet row: loan principal still owed"), outstanding.money, tint: outstanding > 0 ? Theme.negativeCash : .primary)
                    row(String(localized: "Credit limit", comment: "Money sheet row: the most the bank will lend"), creditLimit.money, tint: .primary)
                    if outstanding > 0 {
                        row(String(localized: "Interest", comment: "Money sheet row: interest charged each week"), String(localized: "\(interest.money)/wk", comment: "Money per week. wk is short for week"), tint: Theme.warning)
                    }
                    if state.guaranteedDebt > 0 {
                        row(String(localized: "Guaranteed by you", comment: "Money sheet row: debt secured against the founder home"), state.guaranteedDebt.money, tint: Theme.warning)
                    }
                    // The rule that connects the wallet, the loan and the
                    // home, drawn in one line.
                    Text(
                        secured > 0
                            ? "Your \(life.home.displayName.lowercased()) secures \(secured.money) of the limit. Stay in the red with guaranteed debt and the bank takes your savings, then the house."
                            : "A \(life.home.displayName.lowercased()) secures nothing; the bank lends on the company's name alone."
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                }
            }

            // MARK: P3 (purchases: surfaces and copy)
            // The fourth card, after the other outside money: two cash
            // packs, the grant in dollars and the price on each. Absent
            // without a store.
            ShopAppStoreCard(engine: engine)
            // MARK: end P3

            // MARK: K1 (founder money)
            // The director's loan and the dividend: the founder's own money
            // in the company, with every price printed before the tap.
            FounderMoneyCard(engine: engine)
            // MARK: end K1

            CardView(String(localized: "You",comment: "Card and step heading for the founder as a person - their money, their meters, their name"), systemImage: "person.fill") {
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    row(String(localized: "Wallet", comment: "Money sheet row: the founder own money"), life.wallet.money, tint: life.wallet < 0 ? Theme.negativeCash : .primary)
                    row(String(localized: "Salary", comment: "Money sheet row: what the founder pays themselves"), String(localized: "\(life.founderSalary.money)/wk", comment: "Money per week. wk is short for week"), tint: .primary)
                    if let median, median > 0 {
                        let over = Double(life.founderSalary) > Double(median) * 1.5
                        row(String(localized: "Team median", comment: "Money sheet row: the median salary on the team"), String(localized: "\(median.money)/wk", comment: "Money per week. wk is short for week"), tint: over ? Theme.warning : .secondary)
                        if over {
                            Text("More than 1.5× the team's median: morale slides, and a board adds it to the pressure.")
                                .font(.caption)
                                .foregroundStyle(Theme.warning)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    row(String(localized: "Rent", comment: "Used as a ledger bucket (the office rent) and as the money-sheet row for the founder home rent"), String(localized: "\(rent.money)/wk", comment: "Money per week. wk is short for week"), tint: life.wallet < rent ? Theme.negativeCash : .primary)
                    if let next = life.home.next {
                        row(String(localized: "Next home", comment: "Money sheet row: the next home up the ladder and its price"), "\(next.displayName) · \(homeUpgradeCost(next, balance: balance).money)", tint: .secondary)
                    }
                }
            }

            HStack(spacing: Theme.Spacing.sm) {
                link(String(localized: "Finances", comment: "Money sheet link to the finance ledger"), systemImage: "banknote.fill", route: .finances)
                link(String(localized: "Life", comment: "Money sheet link to the Life tab"), systemImage: "heart.fill", route: .life)
            }
        }
    }

    private func row(_ label: String, _ value: String, tint: Color) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(Theme.Typography.number(.subheadline))
                .foregroundStyle(tint)
                .contentTransition(.numericText())
        }
        .accessibilityElement(children: .combine)
    }

    private func link(_ label: String, systemImage: String, route: Route) -> some View {
        Button {
            Haptics.tap()
            beforeRoute?()
            router?.go(route)
        } label: {
            Label(label, systemImage: systemImage)
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Spacing.xs)
        }
        .buttonStyle(.bordered)
        .tint(Theme.accent)
    }

    private func runway(cash: Int, burn: Int) -> (text: String, tint: Color) {
        if cash < 0 { return (String(localized: "in the red", comment: "Runway readout when cash is below zero. Lower case: it is dropped into a line, not a heading"), Theme.negativeCash) }
        guard burn > 0 else { return (String(localized: "no burn", comment: "Runway readout when the company spends nothing. Lower case: it is dropped into a line, not a heading"), Theme.positiveCash) }
        let weeks = cash / burn
        return (String(localized: "\(weeks) wk", comment: "Runway readout: weeks of cash left. wk is short for weeks"), weeks <= 4 ? Theme.warning : .primary)
    }
}

/// "See all money": the link every partial view carries to the sheet. The
/// engine is read from the shell's environment-free path (`GameShell`
/// owns no engine), so the link takes it explicitly where it is used.
struct MoneySheetLink: View {
    var engine: GameEngine?

    @State private var showing = false

    var body: some View {
        if let engine {
            Button {
                Haptics.tap()
                showing = true
            } label: {
                Label("See all money", systemImage: "list.bullet.rectangle.portrait")
                    .font(.system(.footnote, design: .rounded).weight(.semibold))
            }
            .buttonStyle(.borderless)
            .tint(Theme.accent)
            .sheet(isPresented: $showing) {
                MoneySheet(engine: engine)
            }
        }
    }
}
