import Foundation
import Testing
import TycoonContent
import TycoonEngine

/// Not gates — instrumentation. `BalanceTargetsTests` says *whether* a
/// strategy survives; these tests say *why*. Every one of them prints a
/// trace and asserts nothing beyond "the run happened", so they can be read
/// while tuning without a red test getting in the way.
///
/// Run one with `swift test --filter BalanceDiagnostics`.
@Suite("Balance diagnostics")
struct BalanceDiagnosticsTests {
    static let seeds = BalanceTargetsTests.seeds

    /// One weekly sample of everything that could be killing a run.
    struct Sample {
        var day: Int
        var cash: Int
        var headcount: Int
        var payroll: Int
        var revenue: Int
        var costs: [LedgerEntry.Category: Int]
        var morale: Double
        var onMarket: Int
        var inDev: Int
        var share: Double
        var wallet: Int
        var away: String?
        var reputation: Double
        var loan: Int
    }

    /// Walks a bot through `days`, sampling the books every `every` days.
    static func trace(
        _ bot: any BotPolicy,
        seed: UInt64,
        difficulty: Difficulty = .normal,
        days: Int = 730,
        every: Int = 28,
        balanceOverride: BalanceConfig? = nil
    ) throws -> (samples: [Sample], result: SimRunner.Result) {
        let balance = try balanceOverride ?? BalanceTargetsTests.balance(difficulty)
        var samples: [Sample] = []
        var state = GameState.newGame(companyName: bot.name, seed: seed, balance: balance)
        let content = TestContent.bundled
        var lastLedgerDay = 0

        for _ in 0..<days {
            _ = Reducer.tick(&state, balance: balance, content: content)
            if state.gameOver != nil { break }
            for action in bot.actions(for: state, balance: balance, content: content) {
                _ = Reducer.apply(action, to: &state, balance: balance, content: content)
            }
            if state.day % every == 0 {
                samples.append(sample(state, since: lastLedgerDay))
                lastLedgerDay = state.day
            }
        }
        samples.append(sample(state, since: lastLedgerDay))

        let result = SimRunner.run(
            days: days, seed: seed, bot: bot, balance: balance, content: content
        )
        return (samples, result)
    }

    static func sample(_ state: GameState, since day: Int) -> Sample {
        var costs: [LedgerEntry.Category: Int] = [:]
        var revenue = 0
        for entry in state.ledger.entries where entry.day > day {
            if entry.amount >= 0 {
                revenue += entry.amount
            } else {
                costs[entry.category, default: 0] += -entry.amount
            }
        }
        let staff = state.employees.filter { !$0.isFounder }
        let onMarket = state.products.filter {
            if case .released(let info) = $0.stage { return !info.offMarket }
            return false
        }
        let shares = onMarket.map { state.market.shareMultiplier(for: $0.topicID) }
        return Sample(
            day: state.day,
            cash: state.company.cash,
            headcount: state.headcount,
            payroll: state.employees.reduce(0) { $0 + $1.weeklySalary },
            revenue: revenue,
            costs: costs,
            morale: staff.isEmpty ? 0 : staff.reduce(0) { $0 + $1.morale } / Double(staff.count),
            onMarket: onMarket.count,
            inDev: state.productsInDevelopment.count,
            share: shares.isEmpty ? 1 : shares.reduce(0, +) / Double(shares.count),
            wallet: state.life.wallet,
            away: state.life.awayReason,
            reputation: state.company.reputation,
            loan: state.loanBalance
        )
    }

    static func print(_ samples: [Sample], _ result: SimRunner.Result, seed: UInt64) {
        Swift.print("""
        --- \(result.botName) seed \(seed): \
        \(result.wentBankrupt ? "DEAD day \(result.daysRun)" : "alive, cash \(result.finalCash)") \
        | ships \(result.productsShipped) quits \(result.quits) hosp \(result.hospitalizations)
        """)
        Swift.print("  day  cash    head pay  rev28  payroll rent  op   host mktg | mor  mkt dev share rep  wallet loan away")
        for sample in samples {
            func cost(_ category: LedgerEntry.Category) -> String {
                String(sample.costs[category] ?? 0).padding(toLength: 5, withPad: " ", startingAt: 0)
            }
            Swift.print("""
              \(String(sample.day).padding(toLength: 4, withPad: " ", startingAt: 0)) \
            \(String(sample.cash).padding(toLength: 7, withPad: " ", startingAt: 0)) \
            \(String(sample.headcount).padding(toLength: 4, withPad: " ", startingAt: 0)) \
            \(String(sample.payroll).padding(toLength: 4, withPad: " ", startingAt: 0)) \
            \(String(sample.revenue).padding(toLength: 6, withPad: " ", startingAt: 0)) \
            \(cost(.payroll))   \(cost(.rent)) \(cost(.operating)) \(cost(.hosting)) \(cost(.marketing)) | \
            \(String(format: "%.0f", sample.morale).padding(toLength: 4, withPad: " ", startingAt: 0)) \
            \(sample.onMarket)   \(sample.inDev)   \
            \(String(format: "%.2f", sample.share)) \
            \(String(format: "%.0f", sample.reputation).padding(toLength: 4, withPad: " ", startingAt: 0)) \
            \(String(sample.wallet).padding(toLength: 6, withPad: " ", startingAt: 0)) \
            \(String(sample.loan).padding(toLength: 5, withPad: " ", startingAt: 0)) \
            \(sample.away ?? "")
            """)
        }
    }

    /// Grid search over the crunch-hire bot's own judgment calls, so the
    /// question "is it the economy or is it the bot?" gets an answer with
    /// numbers behind it. Not a gate.
    @Test func crunchHireStrategyGrid() throws {
        Swift.print("=== crunch-hire strategy grid (10 seeds × 730d, Normal) ===")
        Swift.print("runway big  raise| bankrupt  cash    ships peak loft studio  quits")
        for runway in [10, 11, 12, 13, 14, 15, 16] {
            for big in [2, 4] {
                for raises in [CrunchHireBot.RaisePolicy.marketAnchored, .compounding] {
                    var bot = CrunchHireBot()
                    bot.hireRunwayWeeks = runway
                    bot.upgradeWhenFull = big == 2
                    bot.raises = raises
                    let compounding = raises == .compounding
                    let results = try Self.seeds.map {
                        try BalanceTargetsTests.run(bot, seed: $0)
                    }
                    func median(_ values: [Int]) -> Int {
                        let sorted = values.sorted()
                        return sorted.isEmpty ? -1 : sorted[sorted.count / 2]
                    }
                    Swift.print("""
                    \(String(runway).padding(toLength: 7, withPad: " ", startingAt: 0))\
                    \(String(big).padding(toLength: 4, withPad: " ", startingAt: 0))\
                    \(compounding ? "cmpnd" : "mkt  ")| \
                    \(String(results.filter(\.wentBankrupt).count).padding(toLength: 9, withPad: " ", startingAt: 0))\
                    \(String(median(results.map(\.finalCash))).padding(toLength: 8, withPad: " ", startingAt: 0))\
                    \(String(median(results.map(\.productsShipped))).padding(toLength: 6, withPad: " ", startingAt: 0))\
                    \(String(median(results.map(\.peakHeadcount))).padding(toLength: 5, withPad: " ", startingAt: 0))\
                    \(String(median(results.compactMap(\.daysToLoft))).padding(toLength: 5, withPad: " ", startingAt: 0))\
                    \(String(median(results.compactMap(\.daysToStudio))).padding(toLength: 8, withPad: " ", startingAt: 0))\
                    \(results.reduce(0) { $0 + $1.quits })
                    """)
                }
            }
        }
        #expect(Self.seeds.count == 10)
    }

    /// The 10-seed gate set is a sample. This asks what the underlying
    /// failure rate of the crunch-hire strategy actually is, over enough
    /// seeds that one lucky market cannot move it. Not a gate.
    @Test func crunchHireFailureRateOverManySeeds() throws {
        Swift.print("=== crunch-hire failure rate (40 seeds × 730d, Normal) ===")
        let many: [UInt64] = (0..<40).map { 1_000 + UInt64($0) * 7_919 }
        for runway in [12, 13, 14, 15] {
            for raises in [CrunchHireBot.RaisePolicy.marketAnchored, .compounding] {
                var bot = CrunchHireBot()
                bot.hireRunwayWeeks = runway
                bot.raises = raises
                let results = try many.map { seed in
                    SimRunner.run(
                        days: 730, seed: seed, bot: bot,
                        balance: try BalanceTargetsTests.balance(),
                        content: TestContent.bundled
                    )
                }
                let dead = results.filter(\.wentBankrupt).count
                let loft = results.compactMap(\.daysToLoft).sorted()
                let studio = results.compactMap(\.daysToStudio).sorted()
                let label = raises == .compounding ? "compounding" : "anchored   "
                Swift.print(
                    "runway \(runway) \(label) dead \(dead)/40 (\(dead * 100 / 40)%)"
                        + " loft \(loft.count)/40"
                        + (loft.isEmpty ? "" : " median d\(loft[loft.count / 2])")
                        + " studio \(studio.count)/40"
                        + (studio.isEmpty ? "" : " median d\(studio[studio.count / 2])")
                )
            }
        }
        #expect(Self.seeds.count == 10)
    }

    /// The three levers the integration report named as the suspected
    /// cause of `CrunchHireBot`'s 10/10 bankruptcy, each measured against
    /// the shipped balance rather than argued about. Not a gate.
    ///
    /// Result, in one line: none of them is the driver. The driver was the
    /// harness's own raise rule — see `mismanagingPayrollStillKillsYou`.
    @Test func theSuspectedCulprits() throws {
        let content = TestContent.bundled
        func rate(_ label: String, _ balance: BalanceConfig, _ catalog: ContentCatalog) {
            let results = Self.seeds.map { seed in
                SimRunner.run(
                    days: 730, seed: seed, bot: CrunchHireBot(),
                    balance: balance, content: catalog
                )
            }
            let quits = results.reduce(0) { $0 + $1.quits }
            let morale = results.flatMap { result in
                result.state.employees.filter { !$0.isFounder }.map(\.morale)
            }
            Swift.print(
                "  \(label.padding(toLength: 30, withPad: " ", startingAt: 0))"
                    + "dead \(results.filter(\.wentBankrupt).count)/10"
                    + "  cash \(results.map(\.finalCash).sorted()[5])"
                    + "  quits \(quits)"
                    + "  morale " + (morale.isEmpty
                        ? "n/a"
                        : String(format: "%.0f", morale.reduce(0, +) / Double(morale.count)))
            )
        }

        Swift.print("=== the three suspects (10 seeds × 730d, Normal) ===")
        rate("shipped balance", try BalanceTargetsTests.balance(), content)

        // 1. WS-F's trait table sums to −15 morale across fourteen traits.
        let flat = ContentCatalog(
            productTypes: content.productTypes, topics: content.topics,
            techTree: content.techTree, events: content.events, names: content.names,
            lifeEvents: content.lifeEvents,
            traits: content.traits.map {
                var effects = $0.effects
                effects.moraleTargetDelta = 0
                return TraitDef(
                    id: $0.id, name: $0.name, blurb: $0.blurb, bio: $0.bio,
                    isPositive: $0.isPositive, effects: effects
                )
            },
            dialogue: content.dialogue, news: content.news, reviews: content.reviews,
            goals: content.goals, investors: content.investors,
            staffEvents: content.staffEvents
        )
        rate("traits: morale deltas zeroed", try BalanceTargetsTests.balance(), flat)

        // 2. WS-F's per-topic rival share, which the gates switch off.
        var withRivals = try BalanceTargetsTests.balance()
        withRivals.rivals.rivalCount = 4
        rate("rivals: four, share live", withRivals, content)

        // 3. WS-B's event cash effects, at the 0.45× WS-B itself suggested
        //    once WS-A's economy tightened. Approximated by muting the
        //    legacy random-event channel entirely, which is the strongest
        //    possible version of that change.
        var noEvents = try BalanceTargetsTests.balance()
        noEvents.eventChance = 0
        noEvents.narrative.companyEventChance = 0
        rate("company events: switched off", noEvents, content)

        #expect(Self.seeds.count == 10)
    }

    /// The founder's books: what a crunching founder actually owes at the
    /// end of two years, how often they were in hospital, and whether the
    /// landlord ever wrote. Not a gate.
    @Test func founderDebtProfile() throws {
        Swift.print("=== founder debt profile (10 seeds × 730d, Normal) ===")
        Swift.print("bot              final wallet          min wallet       hosp evict chronic salary")
        func row(_ label: String, _ bot: @autoclosure () -> any BotPolicy) throws {
            let results = try Self.seeds.map { try BalanceTargetsTests.run(bot(), seed: $0) }
            let final = results.map(\.state.life.wallet).sorted()
            let low = results.map(\.minWallet).sorted()
            Swift.print(
                "  \(label.padding(toLength: 15, withPad: " ", startingAt: 0))"
                    + " \(final.first ?? 0)…\(final.last ?? 0)".padding(toLength: 21, withPad: " ", startingAt: 0)
                    + " \(low.first ?? 0)…\(low.last ?? 0)".padding(toLength: 17, withPad: " ", startingAt: 0)
                    + " \(results.reduce(0) { $0 + $1.hospitalizations })".padding(toLength: 5, withPad: " ", startingAt: 0)
                    + " \(results.reduce(0) { $0 + $1.evictionWarnings })".padding(toLength: 6, withPad: " ", startingAt: 0)
                    + " \(results.count { $0.state.economy.chronicCondition })".padding(toLength: 8, withPad: " ", startingAt: 0)
                    + " \(results.map(\.state.life.founderSalary).sorted().last ?? 0)"
            )
        }
        try row("solo-slow", SoloSlowBot())
        try row("crunch-hire", CrunchHireBot())
        try row("neglectful", NeglectfulBot())
        try row("saas-builder", SaaSBuilderBot())
        try row("grinder", ContractGrinderBot())
        #expect(Self.seeds.count == 10)
    }

    /// What Hard actually does to each strategy, since the crunch-hire bot
    /// on Hard cannot afford the hires that ruin it on Normal and so is
    /// not a clean control for "is Hard harder?". Not a gate.
    @Test func hardModeProfile() throws {
        Swift.print("=== Normal vs Hard (10 seeds) ===")
        Swift.print("bot            days  normal: dead cash    peak | hard: dead cash    peak")
        func row(_ label: String, _ bot: @autoclosure () -> any BotPolicy, days: Int) throws {
            func stats(_ difficulty: Difficulty) throws -> String {
                let results = try Self.seeds.map {
                    try BalanceTargetsTests.run(bot(), seed: $0, difficulty: difficulty, days: days)
                }
                let cash = results.map(\.finalCash).sorted()
                return "\(results.filter(\.wentBankrupt).count)/10".padding(toLength: 6, withPad: " ", startingAt: 0)
                    + "\(cash[cash.count / 2])".padding(toLength: 8, withPad: " ", startingAt: 0)
                    + "\(results.map(\.peakHeadcount).sorted()[5])"
            }
            Swift.print(
                "  \(label.padding(toLength: 13, withPad: " ", startingAt: 0))"
                    + " \(days)".padding(toLength: 6, withPad: " ", startingAt: 0)
                    + "        \(try stats(.normal)) | "
                    + "      \(try stats(.hard))"
            )
        }
        for days in [365, 730] {
            try row("crunch-hire", CrunchHireBot(), days: days)
            try row("neglectful", NeglectfulBot(), days: days)
            try row("solo-slow", SoloSlowBot(), days: days)
            try row("saas-builder", SaaSBuilderBot(), days: days)
        }
        #expect(Self.seeds.count == 10)
    }

    /// The investor and board layer, which nothing measured before this
    /// pass. Not a gate.
    @Test func investorProfile() throws {
        Swift.print("=== investor bot (10 seeds × 730d, Normal, rivals live) ===")
        func run(_ bot: InvestorBot, _ label: String, days: Int = 730) throws {
            let balance = try BalanceTargetsTests.balance()
            var withRivals = balance
            withRivals.rivals.rivalCount = 4
            let results = BalanceTargetsTests.seeds.map { seed in
                SimRunner.run(
                    days: days, seed: seed, bot: bot,
                    balance: withRivals, content: TestContent.bundled
                )
            }
            func kinds(_ kind: EndingKind?) -> Int {
                results.count { $0.endingKind == kind }
            }
            let rounds = results.map(\.state.investors.rounds.count)
            let pressure = results.map { Int($0.state.investors.boardPressure) }
            let chapters = results.map(\.state.progression.chapter)
            let goals = results.map(\.state.progression.completedGoalIDs.count)
            let cash = results.map(\.finalCash).sorted()
            let equity = results.map { Int($0.state.investors.equityRemaining) }
            let worth = results.map { $0.state.founderNetWorth(balance: withRivals) / 1_000 }
            let reviews = results.flatMap(\.state.investors.reviews)
            Swift.print("""
              \(label.padding(toLength: 14, withPad: " ", startingAt: 0))\
            alive \(kinds(nil)) bankrupt \(kinds(.bankruptcy)) ousted \(kinds(.oustedByBoard)) \
            ipo \(kinds(.ipo)) acquired \(kinds(.acquired))
                rounds \(rounds.sorted()) pressure \(pressure.sorted())
                chapters \(chapters.sorted()) goals \(goals.sorted()) cash \(cash[5])
                equity \(equity.sorted()) net worth $k \(worth.sorted())
                reviews met \(reviews.count { $0.met })/\(reviews.count) \
            \(BoardExpectation.allCases.map { expectation in
                let asked = reviews.filter { $0.expectation == expectation }
                return "\(expectation) \(asked.count { $0.met })/\(asked.count)"
            }.joined(separator: " "))
            """)
        }
        try run(InvestorBot(), "investor")
        try run(InvestorBot.bootstrapper, "bootstrapper")
        try run(InvestorBot.ignoresTheBoard, "ignores-board")
        try run(InvestorBot.coasts, "coasts")
        // …and again over three years, where the board's arithmetic has
        // room to finish: a seat arrives around day 250, the review is
        // quarterly, and four clear misses are needed.
        try run(InvestorBot(), "investor/3y", days: 1_092)
        try run(InvestorBot.coasts, "coasts/3y", days: 1_092)
        #expect(BalanceTargetsTests.seeds.count == 10)
    }

    /// Every board review across ten runs: what the board asked for, and
    /// whether the pressure moved. Not a gate.
    @Test func boardReviewLog() throws {
        var balance = try BalanceTargetsTests.balance()
        balance.rivals.rivalCount = 4
        Swift.print("=== board reviews (the founder who stops growing, 3 years) ===")
        for seed in BalanceTargetsTests.seeds.prefix(4) {
            let result = SimRunner.run(
                days: 1_092, seed: seed, bot: InvestorBot.coasts,
                balance: balance, content: TestContent.bundled
            )
            let rounds = result.state.investors.rounds
            Swift.print("""
              seed \(seed): \(result.endingKind.map { "\($0)" } ?? "alive") \
            rounds \(rounds.map { "\($0.investorName)(\($0.expects), seat \($0.takesBoardSeat), d\($0.day))" })
            """)
            for review in result.state.investors.reviews {
                Swift.print(
                    "      d\(review.day) \(review.expectation) "
                        + (review.met ? "met " : "MISS")
                        + " pressure \(Int(review.pressure))"
                )
            }
        }
        #expect(BalanceTargetsTests.seeds.count == 10)
    }

    /// What the company is actually worth as the run goes on, against the
    /// valuation floors `Investors.json` asks for. Not a gate.
    @Test func valuationAgainstInvestorFloors() throws {
        var balance = try BalanceTargetsTests.balance()
        balance.rivals.rivalCount = 4
        Swift.print("=== company valuation by day (investor bot, 10 seeds) ===")
        for day in [182, 364, 546, 728] {
            let values = BalanceTargetsTests.seeds.map { seed -> Int in
                let result = SimRunner.run(
                    days: day, seed: seed, bot: InvestorBot(),
                    balance: balance, content: TestContent.bundled
                )
                return result.state.companyValuation(balance: balance)
            }.sorted()
            Swift.print("  d\(day): \(values)")
        }
        Swift.print("  floors: \(TestContent.bundled.investors.map { "\($0.id.prefix(9))=\($0.valuationFloor)\($0.boardSeat ? "*" : "")" })")
        #expect(BalanceTargetsTests.seeds.count == 10)
    }

    @Test func investorCauseOfDeath() throws {
        Swift.print("=== investor bot cause of death ===")
        var balance = try BalanceTargetsTests.balance()
        balance.rivals.rivalCount = 4
        for seed in Self.seeds.prefix(3) {
            let (samples, result) = try Self.trace(
                InvestorBot(), seed: seed, balanceOverride: balance
            )
            Self.print(samples, result, seed: seed)
        }
        #expect(Self.seeds.count == 10)
    }

    @Test func crunchHireCauseOfDeath() throws {
        Swift.print("=== crunch-hire cause of death (Normal, 730d) ===")
        for seed in Self.seeds.prefix(4) {
            let (samples, result) = try Self.trace(CrunchHireBot(), seed: seed)
            Self.print(samples, result, seed: seed)
        }
        #expect(Self.seeds.count == 10)
    }

    @Test func soloForComparison() throws {
        Swift.print("=== solo-slow, the survivor, for comparison ===")
        for seed in Self.seeds.prefix(2) {
            let (samples, result) = try Self.trace(SoloSlowBot(), seed: seed)
            Self.print(samples, result, seed: seed)
        }
        #expect(Self.seeds.count == 10)
    }

    /// Where the pauses come from, by event kind, across a run.
    @Test func pauseBreakdown() throws {
        func breakdown(_ bot: any BotPolicy, _ label: String) throws {
            var counts: [String: Int] = [:]
            var total = 0
            var days = 0
            var perSeed: [Double] = []
            for seed in Self.seeds {
                var seedPauses = 0
                let balance = try BalanceTargetsTests.balance()
                var state = GameState.newGame(
                    companyName: bot.name, seed: seed, balance: balance
                )
                for _ in 0..<730 {
                    _ = Reducer.tick(&state, balance: balance, content: TestContent.bundled)
                    for event in state.economy.pauseEvents {
                        counts[Self.kind(of: event), default: 0] += 1
                        total += 1
                        seedPauses += 1
                    }
                    if state.gameOver != nil { break }
                    for action in bot.actions(
                        for: state, balance: balance, content: TestContent.bundled
                    ) {
                        _ = Reducer.apply(
                            action, to: &state, balance: balance, content: TestContent.bundled
                        )
                    }
                }
                days += state.day
                perSeed.append(Double(seedPauses) * 364 / Double(max(1, state.day)))
            }
            let years = Double(days) / 364
            Swift.print(
                "--- \(label): mean \(String(format: "%.1f", Double(total) / years))/year "
                    + "per-seed \(perSeed.map { Int($0) }.sorted())"
            )
            for (kind, count) in counts.sorted(by: { $0.value > $1.value }) {
                Swift.print(
                    "    \(kind.padding(toLength: 24, withPad: " ", startingAt: 0)) "
                        + String(format: "%5.1f", Double(count) / years) + "/yr"
                )
            }
        }
        Swift.print("=== pause sources (10 seeds × 730d, Normal) ===")
        try breakdown(CrunchHireBot(), "crunch-hire")
        try breakdown(SoloSlowBot(), "solo-slow")
        try breakdown(NeglectfulBot(), "neglectful")
        #expect(Self.seeds.count == 10)
    }

    static func kind(of event: GameEvent) -> String {
        let mirror = String(describing: event)
        guard let paren = mirror.firstIndex(of: "(") else { return mirror }
        return String(mirror[mirror.startIndex..<paren])
    }

    /// Goal and chapter progress: which goals actually complete, and which
    /// never do, for the two bots the plan names.
    @Test func goalProgress() throws {
        Swift.print("=== goal completion (10 seeds × 730d, Normal) ===")
        func report(_ bot: @autoclosure () -> any BotPolicy, _ label: String) throws {
            var completed: [String: Int] = [:]
            var chapters: [Int] = []
            var counts: [Int] = []
            var best: [Int] = []
            var worth: [Int] = []
            var valuation: [Int] = []
            for seed in Self.seeds {
                let result = try BalanceTargetsTests.run(bot(), seed: seed)
                best.append(result.state.progression.stats.bestProductRevenue)
                let balance = try BalanceTargetsTests.balance()
                worth.append(result.state.founderNetWorth(balance: balance))
                valuation.append(result.state.companyValuation(balance: balance))
                for id in result.state.progression.completedGoalIDs {
                    completed[id, default: 0] += 1
                }
                chapters.append(result.state.progression.chapter)
                counts.append(result.state.progression.completedGoalIDs.count)
            }
            Swift.print("""
            --- \(label): goals \(counts.sorted()) \
            median \(counts.sorted()[counts.count / 2]) \
            | chapters \(chapters.sorted())
            """)
            Swift.print("    bestProductRevenue \(best.sorted())")
            Swift.print("    netWorth           \(worth.sorted())")
            Swift.print("    valuation          \(valuation.sorted())")
            let catalog = TestContent.bundled.goals
            for goal in catalog {
                let hits = completed[goal.id] ?? 0
                Swift.print(
                    "    ch\(goal.chapter) \(goal.id.padding(toLength: 26, withPad: " ", startingAt: 0)) "
                        + "\(hits)/10"
                )
            }
        }
        try report(CrunchHireBot(), "crunch-hire")
        try report(GoalCrunchBot(), "goal-crunch")
        try report(GoalSoloBot(), "goal-solo")
        try report(SaaSBuilderBot(), "saas-builder")
        #expect(Self.seeds.count == 10)
    }
}
