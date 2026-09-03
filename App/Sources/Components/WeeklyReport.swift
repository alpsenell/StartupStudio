import Foundation
import TycoonEngine

/// Everything the weekly report shows, derived from state alone.
///
/// Kept separate from the sheet so it can be reconciled against the ledger
/// in a unit test: every number here is either a sum over `LedgerEntry`
/// rows in the week's day range or a direct read of state — the report can
/// never disagree with the books.
struct WeeklyReport: Equatable {
    /// 1-based week of the run this report covers (week 1 = days 0…6).
    let weekIndex: Int
    /// Inclusive day range the week covers.
    let dayRange: ClosedRange<Int>
    /// The calendar the week ended on.
    let calendar: GameCalendar

    /// Sum of positive ledger amounts in the week.
    let income: Int
    /// Sum of negative ledger amounts in the week, as a positive number.
    let expenses: Int
    /// `income - expenses`.
    var net: Int { income - expenses }
    /// Cash on hand at the end of the week.
    let cash: Int

    /// Income by category, largest first; only non-zero buckets.
    let incomeByCategory: [CategoryTotal]
    /// Expenses by category (positive amounts), largest first.
    let expensesByCategory: [CategoryTotal]

    /// Per-product sales for the week, plus that product's recent history
    /// for the sparkline.
    let productSales: [ProductSales]

    /// Team morale now and the change since last week's report.
    let averageMorale: Double
    let moraleDelta: Double
    /// Employees under the balance's quit threshold, unhappiest first.
    let unhappy: [UnhappyEmployee]

    /// Events logged in the week, newest first.
    let events: [GameEvent]

    /// Founder meters at the end of the week.
    let founderMeters: MeterSnapshot
    /// How each meter moved since the previous report (zeroes for the
    /// first one).
    let meterDeltas: MeterSnapshot

    /// Weeks of runway left at the current burn (nil = no burn / infinite).
    let runwayWeeks: Int?
    /// Weekly burn used for the runway figure.
    let weeklyBurn: Int
    /// Contracts due within the next 14 days, soonest first.
    let deadlines: [Deadline]
    /// The one thing to do next week, derived from the top active goal
    /// and its state, with the screen it lives on.
    let nextAction: NextAction?
    /// Campaigns that end within the next 7 days.
    let campaignsEnding: Int

    struct CategoryTotal: Equatable, Identifiable {
        let category: LedgerEntry.Category
        let amount: Int
        var id: String { category.rawValue }
    }

    struct ProductSales: Equatable, Identifiable {
        let id: UUID
        let name: String
        let units: Int
        let revenue: Int
        /// Revenue for the last weeks on the market, oldest first.
        let history: [Int]
        /// Subscribers, for subscription products (0 otherwise).
        let subscribers: Int
        let isSubscription: Bool
        let liveBugs: Int
    }

    struct UnhappyEmployee: Equatable, Identifiable {
        let id: UUID
        let name: String
        let morale: Double
    }

    struct Deadline: Equatable, Identifiable {
        let id: UUID
        let clientName: String
        let dueDay: Int
        let daysLeft: Int
    }

    struct NextAction: Equatable {
        let text: String
        let route: Route
    }

    /// "Do this next: start a product — you have $12,000 and no income."
    /// Keyed on the goal ids the way the coach tips and HQ's Now card are,
    /// so it never coaches toward a goal that will not tick.
    static func nextAction(for state: GameState, balance: BalanceConfig) -> NextAction? {
        guard let goal = state.progression.activeGoals.first,
              let action = NowAction.action(for: goal.id, state: state)
        else { return nil }
        let cash = state.company.cash
        let lastWeekSales = state.ledger.entries
            .filter { $0.category == .sales && $0.day >= state.day - 7 }
            .reduce(0) { $0 + $1.amount }
        let detail: String
        switch action.route {
        case .newProduct:
            detail = lastWeekSales > 0
                ? "you have \(cash.money) and \(lastWeekSales.money) a week coming in"
                : "you have \(cash.money) and no income"
        case .product:
            detail = goal.detail.isEmpty ? "the build is on the Products tab" : goal.detail
        case .hiring:
            let cap = balance.office(state.company.officeTier).headcountCap
            let free = max(0, cap - state.headcount)
            let refresh = max(1, balance.candidateRefreshDays)
            let days = refresh - (state.day % refresh)
            detail = "\(free) empty desk\(free == 1 ? "" : "s"), "
                + (state.candidatePool.isEmpty ? "candidates in \(days) day\(days == 1 ? "" : "s")" : "\(state.candidatePool.count) candidates waiting")
        case .contracts:
            detail = state.contractOffers.isEmpty ? "clients call every week" : "\(state.contractOffers.count) offer\(state.contractOffers.count == 1 ? "" : "s") on the desk"
        default:
            detail = goal.detail
        }
        return NextAction(text: "\(action.label.lowercased()) — \(detail)", route: action.route)
    }

    struct MeterSnapshot: Equatable {
        let energy: Double
        let health: Double
        let mood: Double
        let relationships: Double
    }

    /// Builds the report for the week that just ended.
    ///
    /// - Parameters:
    ///   - state: the live state, at or after the week boundary.
    ///   - balance: the difficulty-adjusted balance (thresholds, burn).
    ///   - weeklyBurn: the engine's own burn figure, so the runway here
    ///     matches the HQ card exactly.
    ///   - previousMorale: last report's average morale, for the delta.
    ///   - previousMeters: last report's founder meters, for their deltas.
    init(
        state: GameState,
        balance: BalanceConfig,
        weeklyBurn: Int,
        previousMorale: Double? = nil,
        previousMeters: MeterSnapshot? = nil
    ) {
        // The week that just closed is the one ending at the last week
        // boundary at or before `state.day`.
        let boundary = (state.day / 7) * 7
        let start = max(0, boundary - 7)
        let end = max(0, boundary - 1)
        let range = start...max(start, end)
        dayRange = range
        weekIndex = start / 7 + 1
        calendar = GameCalendar(day: max(0, boundary - 1))

        let entries = state.ledger.entries.filter { range.contains($0.day) }
        income = entries.filter { $0.amount > 0 }.reduce(0) { $0 + $1.amount }
        expenses = entries.filter { $0.amount < 0 }.reduce(0) { $0 - $1.amount }
        cash = state.company.cash

        incomeByCategory = Self.totals(of: entries.filter { $0.amount > 0 }) { $0 }
        expensesByCategory = Self.totals(of: entries.filter { $0.amount < 0 }) { -$0 }

        let weekIndexInRun = start / 7
        productSales = state.products.compactMap { product in
            guard case .released(let release) = product.stage else { return nil }
            let salesWeek = weekIndexInRun - release.launchDay / 7
            let sale = release.weeklySales.first { $0.weekIndex == salesWeek }
            let history = release.weeklySales.suffix(8).map(\.revenue)
            guard sale != nil || !history.isEmpty else { return nil }
            return ProductSales(
                id: product.id,
                name: product.name,
                units: sale?.units ?? 0,
                revenue: sale?.revenue ?? 0,
                history: Array(history),
                subscribers: release.subscribers,
                isSubscription: release.isSubscription,
                liveBugs: release.liveBugs
            )
        }

        let staff = state.employees.filter { !$0.isFounder }
        averageMorale = staff.isEmpty
            ? 0
            : staff.reduce(0.0) { $0 + $1.morale } / Double(staff.count)
        moraleDelta = averageMorale - (previousMorale ?? averageMorale)
        unhappy = staff
            .filter { $0.morale < balance.staff.quitMoraleThreshold + 12 }
            .sorted { $0.morale < $1.morale }
            .prefix(3)
            .map { UnhappyEmployee(id: $0.id, name: $0.name, morale: $0.morale) }

        // Newest first, but critical events ahead of the rest: the card
        // shows only the first eight, and the week a founder's guarantee
        // was called or somebody resigned should never be pushed out of
        // it by eight quieter days that happened to come later.
        events = state.eventLog
            .filter { range.contains(EventDay.of($0)) }
            .enumerated()
            .sorted { left, right in
                let leftCritical = left.element.severity == .critical
                let rightCritical = right.element.severity == .critical
                if leftCritical != rightCritical { return leftCritical }
                return left.offset > right.offset
            }
            .map(\.element)

        let meters = state.life.meters
        founderMeters = MeterSnapshot(
            energy: meters.energy,
            health: meters.health,
            mood: meters.mood,
            relationships: meters.relationships
        )

        meterDeltas = MeterSnapshot(
            energy: founderMeters.energy - (previousMeters?.energy ?? founderMeters.energy),
            health: founderMeters.health - (previousMeters?.health ?? founderMeters.health),
            mood: founderMeters.mood - (previousMeters?.mood ?? founderMeters.mood),
            relationships: founderMeters.relationships
                - (previousMeters?.relationships ?? founderMeters.relationships)
        )

        self.weeklyBurn = weeklyBurn
        runwayWeeks = weeklyBurn > 0 && state.company.cash > 0
            ? state.company.cash / weeklyBurn
            : nil

        deadlines = state.activeContracts
            .map {
                Deadline(
                    id: $0.id,
                    clientName: $0.clientName,
                    dueDay: $0.deadlineDay,
                    daysLeft: $0.deadlineDay - state.day
                )
            }
            .filter { $0.daysLeft <= 14 }
            .sorted { $0.daysLeft < $1.daysLeft }

        campaignsEnding = state.campaigns.filter { $0.endDay - state.day <= 7 }.count
        nextAction = Self.nextAction(for: state, balance: balance)
    }

    private static func totals(
        of entries: [LedgerEntry],
        sign: (Int) -> Int
    ) -> [CategoryTotal] {
        var sums: [LedgerEntry.Category: Int] = [:]
        for entry in entries {
            sums[entry.category, default: 0] += sign(entry.amount)
        }
        return sums
            .map { CategoryTotal(category: $0.key, amount: $0.value) }
            .filter { $0.amount != 0 }
            // Largest first; ties break on the category name so the
            // order is stable across runs (dictionary order is not).
            .sorted {
                $0.amount == $1.amount
                    ? $0.category.rawValue < $1.category.rawValue
                    : $0.amount > $1.amount
            }
    }
}

/// The day an event carries, without a per-call-site switch.
///
/// Every `GameEvent` case ends in a `day:` label, so this reads it back
/// out of the Codable representation — which keeps working when another
/// workstream appends a case, where a hand-written switch would not.
enum EventDay {
    static func of(_ event: GameEvent) -> Int {
        guard let data = try? JSONEncoder().encode(event),
              let object = try? JSONSerialization.jsonObject(with: data)
        else { return 0 }
        return firstDay(in: object) ?? 0
    }

    private static func firstDay(in object: Any) -> Int? {
        if let dictionary = object as? [String: Any] {
            if let day = dictionary["day"] as? Int { return day }
            for value in dictionary.values {
                if let found = firstDay(in: value) { return found }
            }
        }
        if let array = object as? [Any] {
            for value in array {
                if let found = firstDay(in: value) { return found }
            }
        }
        return nil
    }
}
