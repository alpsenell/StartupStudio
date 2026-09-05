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
            CardView("Company", systemImage: "building.2.fill") {
                VStack(spacing: Theme.Spacing.sm) {
                    row("Cash", cash.money, tint: cash < 0 ? Theme.negativeCash : .primary)
                    row("Weekly burn", "\(burn.money)/wk", tint: burn > 0 ? Theme.warning : .primary)
                    row("Runway", runway(cash: cash, burn: burn).text, tint: runway(cash: cash, burn: burn).tint)
                    row("Income last week", incomeLastWeek.money, tint: incomeLastWeek > 0 ? Theme.positiveCash : .secondary)
                    if worstDebt >= 1 {
                        row("Technical debt", "\(Int(worstDebt.rounded()))", tint: Theme.warning)
                    }
                }
            }

            CardView("Bank", systemImage: "banknote.fill") {
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    row("Outstanding", outstanding.money, tint: outstanding > 0 ? Theme.negativeCash : .primary)
                    row("Credit limit", creditLimit.money, tint: .primary)
                    if outstanding > 0 {
                        row("Interest", "\(interest.money)/wk", tint: Theme.warning)
                    }
                    if state.guaranteedDebt > 0 {
                        row("Guaranteed by you", state.guaranteedDebt.money, tint: Theme.warning)
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

            CardView("You", systemImage: "person.fill") {
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    row("Wallet", life.wallet.money, tint: life.wallet < 0 ? Theme.negativeCash : .primary)
                    row("Salary", "\(life.founderSalary.money)/wk", tint: .primary)
                    if let median, median > 0 {
                        let over = Double(life.founderSalary) > Double(median) * 1.5
                        row("Team median", "\(median.money)/wk", tint: over ? Theme.warning : .secondary)
                        if over {
                            Text("More than 1.5× the team's median: morale slides, and a board adds it to the pressure.")
                                .font(.caption)
                                .foregroundStyle(Theme.warning)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    row("Rent", "\(rent.money)/wk", tint: life.wallet < rent ? Theme.negativeCash : .primary)
                    if let next = life.home.next {
                        row("Next home", "\(next.displayName) · \(homeUpgradeCost(next, balance: balance).money)", tint: .secondary)
                    }
                }
            }

            HStack(spacing: Theme.Spacing.sm) {
                link("Finances", systemImage: "banknote.fill", route: .finances)
                link("Life", systemImage: "heart.fill", route: .life)
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
        if cash < 0 { return ("in the red", Theme.negativeCash) }
        guard burn > 0 else { return ("no burn", Theme.positiveCash) }
        let weeks = cash / burn
        return ("\(weeks) wk", weeks <= 4 ? Theme.warning : .primary)
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
