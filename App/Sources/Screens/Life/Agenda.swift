import SwiftUI
import TycoonContent
import TycoonEngine

/// One dated thing in the founder's next fortnight.
///
/// The desk on Business answers "what has a clock on it *in the business*";
/// the agenda answers "what does the next fortnight look like", which is a
/// different question because half of it is not business at all — a
/// birthday, an evening free, the rent.
struct AgendaItem: Identifiable, Equatable {
    /// What kind of thing it is. Used for the same-day order and the
    /// screen's dots; the copy carries the meaning.
    enum Kind: CaseIterable {
        case contract, ship, board, earnOut, challenge, diary, money, other

        /// Order within one day: work first, the board next, life after
        /// that, and the standing weekly charges at the bottom where they
        /// belong.
        var rank: Int { Self.allCases.firstIndex(of: self) ?? 0 }
    }

    let id: String
    /// Absolute game day.
    let day: Int
    let kind: Kind
    let title: String
    /// The second line, when there is one.
    let detail: String?
    let systemImage: String
    let tint: Color
    /// Where tapping the row goes.
    let route: Route

    static func == (lhs: AgendaItem, rhs: AgendaItem) -> Bool {
        lhs.id == rhs.id && lhs.day == rhs.day
    }
}

/// Reads the next fortnight out of state.
///
/// A pure function of `(state, balance, content)` — no draws, no wall
/// clock, no engine mutation — so the same save always produces the same
/// fortnight and the whole thing is testable on a fixture.
enum Agenda {
    /// How far ahead the agenda looks. Fourteen days: two rent days, two
    /// weekends, and far enough that a contract signed today is on it.
    static let horizonDays = 14

    /// The days the agenda covers, today first.
    static func days(from today: Int) -> [Int] {
        Array(today..<(today + horizonDays))
    }

    /// Everything dated in the next fortnight, soonest first.
    static func items(
        in state: GameState,
        balance: BalanceConfig,
        content: ContentCatalog
    ) -> [AgendaItem] {
        let today = state.day
        let window = today...(today + horizonDays - 1)
        var items: [AgendaItem] = []

        // 1. Everything the desk already dates. The desk is the one place
        //    that knows how to say a contract's grade, a challenge's share
        //    and a term sheet's terms; re-deriving that copy here would be
        //    two truths about the same row. `daysLeft` counts from today
        //    (an overdue contract clamps to 0, which on a calendar is
        //    "now"), so it lands back on an absolute day here.
        for item in Desk.items(in: state, balance: balance, content: content) {
            guard let daysLeft = item.daysLeft else { continue }
            let day = today + daysLeft
            guard window.contains(day) else { continue }
            let kind: AgendaItem.Kind = switch item.section {
            case .contracts: .contract
            case .rivals: .challenge
            default: .other
            }
            items.append(
                AgendaItem(
                    id: "desk-\(item.id)",
                    day: day,
                    kind: kind,
                    title: item.text,
                    detail: nil,
                    systemImage: item.systemImage,
                    tint: item.tint,
                    route: item.route
                )
            )
        }

        // 2. The builds, on the day the ship gate opens at this pace.
        for eta in state.shipETAs(balance: balance, content: content)
        where window.contains(eta.day) {
            items.append(
                AgendaItem(
                    id: "ship-\(eta.productID)",
                    day: eta.day,
                    kind: .ship,
                    title: eta.isReady ? "\(eta.productName) can ship" : "\(eta.productName) ships",
                    detail: eta.isReady
                        ? "The gate is open — every day after this one only adds polish."
                        : "If the crew holds this pace.",
                    systemImage: "hammer.fill",
                    tint: Theme.accent,
                    route: .product(eta.productID)
                )
            )
        }

        // 3. The board's quarter, and the acquirer's version of it. Both
        //    settle on the same review tick, which is why they read as two
        //    lines on one day rather than one line pretending to be both.
        let interval = max(1, balance.investors.reviewIntervalDays)
        let nextReview = (today / interval + 1) * interval
        if window.contains(nextReview) {
            let watching = state.investors.boardExpectations
            if !watching.isEmpty {
                items.append(
                    AgendaItem(
                        id: "board-\(nextReview)",
                        day: nextReview,
                        kind: .board,
                        title: "Board review",
                        detail: watching.count == 1
                            ? "They are watching \(watching[0].displayName.lowercased())."
                            : "\(watching.count) seats grade the quarter.",
                        systemImage: "chart.pie.fill",
                        tint: state.investors.boardPressure >= 60 ? Theme.warning : Theme.accent,
                        route: .investors
                    )
                )
            }
            if let earnOut = state.investors.earnOut, earnOut.remainingReviews > 0 {
                let reviews = earnOut.remainingReviews
                items.append(
                    AgendaItem(
                        id: "earnout-\(nextReview)",
                        day: nextReview,
                        kind: .earnOut,
                        title: "\(earnOut.buyerName) reviews the earn-out",
                        detail: "\(earnOut.outstanding.money) still on the table, "
                            + "\(reviews) review\(reviews == 1 ? "" : "s") to go.",
                        systemImage: "signature",
                        tint: Theme.warning,
                        route: .investors
                    )
                )
            }
        }

        // 4. The diary. The same query the family card's "next" line reads.
        for date in state.familyDates(content: content) where window.contains(date.day) {
            items.append(
                AgendaItem(
                    id: "diary-\(date.id)",
                    day: date.day,
                    kind: .diary,
                    title: date.label,
                    detail: "It costs an evening. Missing it costs more.",
                    systemImage: "heart.fill",
                    tint: Theme.romance,
                    route: .life
                )
            )
        }

        // 5. The standing weekly charges. `FinanceSystem` posts them on
        //    every seventh day, so a fortnight holds two of each.
        let rent = state.officeWeeklyRent(balance: balance)
        let interest = Int((Double(state.loanBalance) * balance.loans.weeklyInterestRate).rounded())
        for day in window where day > 0 && day.isMultiple(of: GameState.daysPerWeek) {
            if rent > 0 {
                items.append(
                    AgendaItem(
                        id: "rent-\(day)",
                        day: day,
                        kind: .money,
                        title: "Office rent",
                        detail: "\(rent.money) posts with the week.",
                        systemImage: "building.2.fill",
                        tint: .secondary,
                        route: .finances
                    )
                )
            }
            if interest > 0 {
                items.append(
                    AgendaItem(
                        id: "loan-\(day)",
                        day: day,
                        kind: .money,
                        title: "Loan interest",
                        detail: "\(interest.money) on \(state.loanBalance.money) outstanding.",
                        systemImage: "banknote.fill",
                        tint: .secondary,
                        route: .finances
                    )
                )
            }
        }

        return items.sorted { lhs, rhs in
            if lhs.day != rhs.day { return lhs.day < rhs.day }
            if lhs.kind.rank != rhs.kind.rank { return lhs.kind.rank < rhs.kind.rank }
            return lhs.id < rhs.id
        }
    }

    // MARK: - Evenings

    /// The days in the fortnight the founder still has an evening for.
    ///
    /// The engine keeps one number — evenings spent this week, refilled on
    /// the week's first day — so a per-day answer is a choice, not a fact.
    /// The choice: the evenings left are the *next* nights you could take,
    /// so they fill forward from today, and a future week starts full and
    /// fills from its own first day. That makes a pip readable as "this
    /// night is yours", which is the question a calendar is asked.
    static func freeEveningDays(in state: GameState, balance: BalanceConfig) -> Set<Int> {
        guard let allowance = balance.life.evenings(for: state.life.schedule), allowance > 0
        else { return [] }
        let today = state.day
        let thisWeek = eveningWeek(of: today)
        let left = state.eveningsLeftThisWeek(balance) ?? allowance

        var free: Set<Int> = []
        var budgets: [Int: Int] = [:]
        for day in days(from: today) {
            let week = eveningWeek(of: day)
            let budget = budgets[week] ?? (week == thisWeek ? left : allowance)
            guard budget > 0 else { continue }
            free.insert(day)
            budgets[week] = budget - 1
        }
        return free
    }

    /// The evening budget's week for a day. `LifeSystem` refills on
    /// `day % 7 == 1`, so a budget week runs from that day for seven days —
    /// one day off the ledger's week, and the offset shows the moment the
    /// pips sit next to the rent.
    static func eveningWeek(of day: Int) -> Int {
        Int(floor(Double(day - 1) / Double(GameState.daysPerWeek)))
    }
}
