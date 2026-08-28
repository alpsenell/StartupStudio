import Foundation
import Testing
import TycoonContent
import TycoonEngine

/// The pacing contract. Every gate here is a *design target* for the shipped
/// `Balance.json`, measured over ten seeds of two game years so one lucky
/// market can't carry a claim: the first product is rough and slow, growth
/// is a bet, success brings costs, and neglect loses you people.
///
/// A failure here means the balance needs tuning, not that the reducer is
/// wrong. `baselineTable` prints the numbers behind every gate.
@Suite("Balance targets")
struct BalanceTargetsTests {
    static let days = 730
    static let seeds: [UInt64] = [
        4_242, 1_009, 55_055, 7_777, 31_415,
        86_420, 20_002, 999_331, 64_064, 123_457,
    ]

    /// The large sample, for the two gates that assert a *rate* rather
    /// than a fact about a run. Ten seeds cannot tell 45% from 70%, and —
    /// measured — neither can forty.
    static let manySeeds: [UInt64] = (0..<120).map { 1_000 + UInt64($0) * 7_919 }

    /// The shipped balance at a difficulty, with rivals disabled: the bots
    /// never answer poach or buyout offers, so auto-resolved poaches would
    /// measure the rival system rather than the economy.
    static func balance(_ difficulty: Difficulty = .normal) throws -> BalanceConfig {
        var balance = try BalanceConfig.loadBundled().adjusted(for: difficulty)
        balance.rivals.rivalCount = 0
        return balance
    }

    static func run(
        _ bot: any BotPolicy,
        seed: UInt64,
        difficulty: Difficulty = .normal,
        days: Int = BalanceTargetsTests.days
    ) throws -> SimRunner.Result {
        SimRunner.run(
            days: days,
            seed: seed,
            bot: bot,
            balance: try balance(difficulty),
            content: TestContent.bundled
        )
    }

    static func runAll(
        _ bot: @autoclosure () -> any BotPolicy,
        difficulty: Difficulty = .normal,
        days: Int = BalanceTargetsTests.days
    ) throws -> [SimRunner.Result] {
        try seeds.map { try run(bot(), seed: $0, difficulty: difficulty, days: days) }
    }

    /// How many of `results` satisfy `predicate`.
    static func count(
        _ results: [SimRunner.Result],
        where predicate: (SimRunner.Result) -> Bool
    ) -> Int {
        results.filter(predicate).count
    }

    /// The mean of `value` over `results` (0 for an empty run set).
    static func mean(
        _ results: [SimRunner.Result],
        of value: (SimRunner.Result) -> Double
    ) -> Double {
        guard !results.isEmpty else { return 0 }
        return results.reduce(0) { $0 + value($1) } / Double(results.count)
    }

    // MARK: - The first product is a scrappy one

    @Test func soloFounderShipsALateAndRoughFirstProduct() throws {
        let results = try Self.runAll(SoloSlowBot())

        for result in results {
            let day = try #require(result.firstShipDay, "solo never shipped")
            #expect(
                (45...110).contains(day),
                "solo first ship on day \(day) — the first product should take weeks, not days"
            )
            let score = try #require(result.firstProductScore)
            #expect(
                (40...66).contains(score),
                "solo first product reviewed \(score) — a one-person crew has no business scoring high"
            )
            let revenue = try #require(result.firstProductLifetimeRevenue)
            // Enough to matter, nowhere near enough to retire on: the
            // studio's weekly burn eats it inside a year.
            #expect(
                (8_000...50_000).contains(revenue),
                "solo first product earned \(revenue) lifetime"
            )
        }
    }

    /// The solo founder never gets rich by standing still.
    @Test func soloFounderNeverGetsRichAndNeverGoesBust() throws {
        let results = try Self.runAll(SoloSlowBot())

        for result in results {
            #expect(!result.wentBankrupt, "solo went bankrupt on day \(result.daysRun)")
            #expect(
                result.finalCash < 250_000,
                "solo sat on \(result.finalCash) after two years of doing nothing but shipping"
            )
        }
    }

    // MARK: - Growth is expensive

    @Test func crunchHireClimbsTheLadderOnScheduleAndNotFaster() throws {
        let results = try Self.runAll(CrunchHireBot())

        for result in results {
            if let loft = result.daysToLoft {
                #expect(loft >= 45, "crunch-hire reached the loft on day \(loft) — too cheap")
            }
            #expect(
                result.daysToCampus == nil || (result.daysToCampus ?? 0) >= 500,
                "crunch-hire reached a campus on day \(result.daysToCampus ?? 0)"
            )
            #expect(
                result.productsShipped <= 30,
                "crunch-hire shipped \(result.productsShipped) products in two years"
            )
        }
        // Back to 6 after the balance pass — measured over forty seeds it
        // is 39/40, on a median of day 154, inside §4.1's day 60–150
        // window at the median and comfortably past its day-45 floor.
        // (Relaxed to 4 at integration, when the strategy was going under
        // 10/10 before it could earn the rent.)
        #expect(
            Self.count(results) { $0.daysToLoft != nil } >= 6,
            "crunch-hire should reach the loft on a good share of seeds"
        )
        // §4.1 also asks for the studio on day 250–500. About half the
        // seeds that survive get there, which is the shape the plan wants:
        // the ladder is climbable, not owed.
        let studio = results.compactMap(\.daysToStudio).sorted()
        #expect(!studio.isEmpty, "no crunch-hire seed ever reached the studio")
        // §4.1's window is a design target for the typical run, not a
        // per-seed floor — one fast market should be allowed to be fast.
        #expect(
            (250...500).contains(studio[studio.count / 2]),
            "crunch-hire reached the studio on day \(studio[studio.count / 2]) at the median"
        )
        #expect(
            studio.first ?? 0 >= 180,
            "crunch-hire reached the studio on day \(studio.first ?? 0) — too cheap"
        )
    }

    /// Growth on product revenue alone is a coin flip: about half of these
    /// studios are gone inside two years and the other half are in a
    /// studio office. §4.1 wants exactly that — "at least 3 of 10 seeds go
    /// bankrupt or lose an employee" — and it is worth its own gate,
    /// because for the whole of integration the answer was 10 out of 10.
    ///
    /// **A hundred and twenty seeds**, not the ten the other gates use and
    /// no longer the forty this gate shipped with. The failure rate here is
    /// genuinely chaotic seed to seed — the strategy runs at roughly
    /// break-even, so a single market swing decides a run — and the sample
    /// has to be big enough to carry the claim in the assertion.
    ///
    /// Forty was not. When `Traits.json` authored `crunchMoraleMult` this
    /// gate failed at 67%, which read as a personality layer that had made
    /// permanent crunch a death sentence. It had not: on a hundred and
    /// twenty seeds the authored table is **55%** against **52%** with the
    /// crunch column blanked — three seeds in a hundred and twenty. The
    /// first forty are simply a bad draw for it. The tell was that blanking
    /// only the *punitive* value (fragile) and keeping the two protective
    /// ones still read 25/40, and sweeping fragile from 1.0 to 1.5 wandered
    /// between 22 and 29 with no trend: a reshuffle, not a dose.
    ///
    /// At forty seeds the 95% interval on a ~55% rate is ±15 points, which
    /// is most of the window this gate asserts. At a hundred and twenty it
    /// is ±9, which fits inside it. That is the whole reason for the number.
    @Test func growthOnProductRevenueIsACoinFlip() throws {
        let results = try Self.manySeeds.map { seed in
            SimRunner.run(
                days: Self.days, seed: seed, bot: CrunchHireBot(),
                balance: try Self.balance(), content: TestContent.bundled
            )
        }
        let dead = Double(Self.count(results) { $0.wentBankrupt }) / Double(results.count)
        #expect(
            (0.25...0.65).contains(dead),
            Comment(rawValue: "crunch-hire went under on \(Int(dead * 100))% of "
                + "\(results.count) seeds")
        )
        // The survivors are not merely surviving.
        let studio = Self.count(results) { $0.daysToStudio != nil }
        #expect(
            studio * 4 >= results.count,
            Comment(rawValue: "only \(studio)/\(results.count) crunch-hire seeds reached the studio")
        )
    }

    /// Growing fast has to be able to go wrong.
    @Test func growingFastSometimesCosts() throws {
        let results = try Self.runAll(CrunchHireBot())
        let stumbles = Self.count(results) { $0.wentBankrupt || $0.quits > 0 || $0.burnouts > 0 }
        #expect(
            stumbles >= 3,
            "only \(stumbles)/10 crunch-hire seeds went bankrupt, lost someone, or burned the founder out"
        )
    }

    /// The control. `CrunchHireBot` and `CrunchHireBot.runawayRaise` are
    /// the same strategy with one difference: the first pays a generous
    /// multiple of what the market says somebody is worth, the second adds
    /// a fifth to whatever it is already paying, every day the person is
    /// unhappy, anchored to nothing. Crunch holds morale near the floor,
    /// so the second rule fires again and again — measured, one employee's
    /// wage compounded roughly sixfold over two years while revenue stayed
    /// flat, and payroll ended at three quarters of every cost the company
    /// had.
    ///
    /// It is worth a gate because that one rule is the difference between
    /// ~45% of seeds going under and ~90%, and because it was the harness,
    /// not the game: for the whole of integration this bot was the
    /// evidence that growth had become unsurvivable.
    @Test func mismanagingPayrollStillKillsYou() throws {
        // The same hundred and twenty seeds
        // `growthOnProductRevenueIsACoinFlip` uses, and for the same
        // reason: on ten, both policies can land on 7, and on forty the
        // gap between them swings by twenty points on a sample that has
        // not changed strategy at all.
        func deaths(_ bot: any BotPolicy) throws -> Int {
            try Self.manySeeds.count { seed in
                SimRunner.run(
                    days: Self.days, seed: seed, bot: bot,
                    balance: try Self.balance(), content: TestContent.bundled
                ).wentBankrupt
            }
        }
        let total = Self.manySeeds.count
        let sensible = try deaths(CrunchHireBot())
        let runaway = try deaths(CrunchHireBot.runawayRaise)
        // Measured: 86% against 55%, a thirty-one point gap. The bar is
        // twenty points, which is more than twice the sampling error on
        // either rate.
        #expect(
            runaway >= sensible + total / 5,
            Comment(rawValue: "runaway raises killed \(runaway)/\(total) against "
                + "\(sensible)/\(total) for anchored ones")
        )
        #expect(
            runaway * 10 >= total * 7,
            Comment(rawValue: "only \(runaway)/\(total) runaway-raise seeds went under")
        )
    }

    // MARK: - Recurring revenue is a real strategy

    /// Betting the studio on a platform is a real bet: about half the
    /// seeds run out of money during the long unfunded stretch between the
    /// research and the launch, and the ones that get there are earning
    /// several times what a shelf of mobile apps ever did.
    @Test func saaSBuilderBuildsRecurringRevenue() throws {
        let results = try Self.runAll(SaaSBuilderBot())
        let earners = Self.count(results) { $0.finalWeeklySubscriptionRevenue >= 20_000 }
        #expect(
            earners >= 5,
            """
            only \(earners)/10 SaaS seeds reached $20k/week of subscriptions \
            (\(results.map(\.finalWeeklySubscriptionRevenue)))
            """
        )
        // And the ones that make it are properly rewarded.
        let best = results.map(\.finalWeeklySubscriptionRevenue).max() ?? 0
        #expect(best >= 40_000, "the best SaaS seed only reached $\(best)/week")
    }

    // MARK: - Contracts pay the bills, not the pension

    @Test func contractGrinderMakesALivingNotAFortune() throws {
        let results = try Self.runAll(ContractGrinderBot())

        for result in results {
            #expect(!result.wentBankrupt, "the grinder went bankrupt on day \(result.daysRun)")
            #expect(
                (10_000...120_000).contains(result.finalCash),
                "grinder ended on \(result.finalCash) — contracts should be a living, not an exit"
            )
        }
    }

    // MARK: - Neglect loses you people

    @Test func neglectfulBossLosesPeople() throws {
        let results = try Self.runAll(NeglectfulBot())
        let perYear = results.map { Double($0.quits) * 364.0 / Double(max(1, $0.daysRun)) }
        let losers = Self.count(results) { Double($0.quits) * 364.0 / Double(max(1, $0.daysRun)) >= 2 }
        #expect(
            losers >= 7,
            "only \(losers)/10 neglectful seeds lost 2+ people a year (\(perYear.map { Int($0) }))"
        )
    }

    @Test func lookingAfterPeopleKeepsThem() throws {
        let results = try Self.runAll(CrunchHireBot())
        let bleeding = Self.count(results) { Double($0.quits) * 364.0 / Double(max(1, $0.daysRun)) > 1 }
        #expect(
            bleeding <= 3,
            "\(bleeding)/10 crunch-hire seeds lost more than one person a year despite the raises"
        )
    }

    // MARK: - Consequences reach the founder

    /// §4.1 task 6's invariant, and the one number the debt pass exists
    /// for: **no founder's wallet is ever worse than −$8,000.**
    ///
    /// Before the pass a crunching founder reached **−$90,000** on a
    /// $200-a-week salary — eight hospital bills at $5,000 plus interest
    /// compounding on interest — with `debtMoodPenalty` pinning their mood
    /// at zero, and so their output near `minOutputFactor`, for the rest of
    /// the run. There was no arithmetic that got them back: the rescue
    /// salary was `max(salary, rent × 2)` = $240 a week, which against
    /// $90,000 is thirty-five years.
    @Test func noFounderEverFallsIntoAHoleTheyCannotClimbOutOf() throws {
        let everyone: [(String, [SimRunner.Result])] = [
            ("solo", try Self.runAll(SoloSlowBot())),
            ("crunch-hire", try Self.runAll(CrunchHireBot())),
            ("neglectful", try Self.runAll(NeglectfulBot())),
            ("saas", try Self.runAll(SaaSBuilderBot())),
            ("grinder", try Self.runAll(ContractGrinderBot())),
        ]
        for (name, results) in everyone {
            for result in results {
                #expect(
                    result.minWallet > -8_000,
                    "\(name)'s wallet reached \(result.minWallet) with no eviction to stop it"
                )
            }
        }
    }

    /// And the landlord still writes — to the founders who actually run
    /// their wallet into the ground.
    ///
    /// This assertion used to sit on `SoloSlowBot`, on the reading that a
    /// founder who never manages their life ends up overdrawn. Since the
    /// debt pass they do not, and that is the fix working rather than a
    /// consequence going missing: §4.1 task 6 set `defaultFounderSalary`
    /// above the studio flat's rent precisely "so the wallet doesn't drift
    /// negative by default", and with hospital stays no longer arriving on
    /// top of each other the $80-a-week margin absorbs them (measured: solo
    /// bottoms out at −$2,447, just short of the −$3,000 threshold).
    ///
    /// What the solo founder pays instead is measured below, in health.
    /// The eviction path is exercised by the two bots that crunch: 21 and
    /// 31 warnings across ten seeds each, every one of them followed by a
    /// rescue that actually clears the hole.
    @Test func theLandlordWritesToTheFoundersWhoEarnIt() throws {
        let crunch = try Self.runAll(CrunchHireBot())
        let neglect = try Self.runAll(NeglectfulBot())
        #expect(
            Self.count(crunch + neglect, where: { $0.evictionWarnings > 0 }) >= 10,
            "the landlord never wrote across twenty runs of crunching the founder"
        )
        // And the rescue is real: a company that can carry it ends up
        // paying its founder more than the default it started on.
        #expect(
            (crunch + neglect).contains { $0.state.life.founderSalary > 200 },
            "no company ever raised its founder's salary to clear the overdraft"
        )
    }

    /// The solo founder who never looks after themselves still pays — in
    /// health rather than in rent. Two hospital stays over two years, and
    /// on a good share of seeds a condition that never entirely goes away.
    @Test func theSoloFounderWhoNeverLooksAfterThemselvesPaysForIt() throws {
        let results = try Self.runAll(SoloSlowBot())
        #expect(
            Self.count(results) { $0.hospitalizations >= 1 } >= 8,
            "a founder who never once took a weekend was fine for two years"
        )
        // …and not so often that it is a treadmill. Before the pass a
        // crunching founder went seven to twelve times, discharged at 40
        // health straight back into the schedule that put them there.
        for result in results {
            #expect(
                result.hospitalizations <= 4,
                "solo was in hospital \(result.hospitalizations) times in two years"
            )
        }
    }

    /// The same ceiling on the bot that crunches every day for two years
    /// and never books so much as a gym weekend — the acceptance number
    /// for the convalescence rule.
    @Test func crunchingForeverEndsInHospitalButNotOnATreadmill() throws {
        for result in try Self.runAll(CrunchHireBot()) {
            #expect(
                result.hospitalizations <= 4,
                "crunch-hire was in hospital \(result.hospitalizations) times in two years"
            )
        }
        for result in try Self.runAll(NeglectfulBot()) {
            #expect(
                result.hospitalizations <= 4,
                "neglectful was in hospital \(result.hospitalizations) times in two years"
            )
        }
    }

    // MARK: - The clock only stops when it matters

    /// Tightened at the balance pass from 70/55 back to 50/35, which is
    /// PM §4.1 task 7's 45/30 on the mean (measured: crunch 40/year, solo
    /// 27/year) with headroom for the worst seed (47 and 32).
    ///
    /// §4.1 task 7 and §4.2 task 2 were written independently and, read
    /// literally, do not add up: task 7 budgeted 45/30 against the
    /// scaffold's ten one-line events, and task 2 then specified a story
    /// beat every seven days at 30% *plus* a life beat every fourteen at
    /// 35%, with any beat carrying choices graded `.critical`. Integration
    /// raised the gate to 70/55 to match what the merged game did.
    ///
    /// The decision this pass made instead, in `GameEvent.severity`: a
    /// story beat that asks the player nothing does not stop the clock.
    /// `.narrativeChoice` — the beat with options and a deadline — is
    /// still critical and still always pauses, so nothing is deferred,
    /// dropped or shortened; `.randomEvent` and `.lifeEvent`, which are a
    /// headline and a number the player cannot answer, drop to `.info` and
    /// stay in the feed and the journal. That is nineteen of a solo run's
    /// forty-four annual stops, and it costs no content at all.
    /// `economy.pauseBudgetDays` also went 5 → 10 (measured: 5 and 7 are
    /// indistinguishable because the throttle only ever bites on same-day
    /// collisions; 14 buys nothing over 10).
    @Test func autoPausesStayWithinBudget() throws {
        let crunch = try Self.runAll(CrunchHireBot())
        let solo = try Self.runAll(SoloSlowBot())

        for result in crunch {
            #expect(
                result.pausesPerYear <= 50,
                "crunch-hire paused \(Int(result.pausesPerYear))×/year"
            )
        }
        for result in solo {
            #expect(
                result.pausesPerYear <= 35,
                "solo paused \(Int(result.pausesPerYear))×/year"
            )
        }
        // And the *mean* holds the plan's original number.
        #expect(Self.mean(crunch, of: \.pausesPerYear) <= 45)
        #expect(Self.mean(solo, of: \.pausesPerYear) <= 30)
    }

    // MARK: - Difficulty means something

    /// Hard is harder, measured the only way that means anything: the
    /// same bot, the same seeds, one difficulty apart.
    ///
    /// Not "crunch-hire goes bankrupt more often", which §4.1 task 8 asked
    /// for and which is not true and never will be: on Hard the bot cannot
    /// afford the hires and the office that ruin it on Normal, so it
    /// degenerates into a solo shop — and a solo founder who never hires
    /// does not go bankrupt on any difficulty. Measured over two years:
    /// 7/10 gone on Normal against 3/10 on Hard, with a *third* of the
    /// cash. Counting bankruptcies there says something true about the
    /// strategy and nothing at all about the difficulty column.
    ///
    /// So: every strategy is strictly poorer, and the strategy that
    /// actually bets — a year of runway spent on research before the
    /// platform earns a penny — is the one Hard kills.
    @Test func hardModeIsGenuinelyHard() throws {
        func medianCash(_ bot: @autoclosure () -> any BotPolicy, _ difficulty: Difficulty) throws -> Int {
            try Self.runAll(bot(), difficulty: difficulty)
                .map(\.finalCash).sorted()[Self.seeds.count / 2]
        }
        // Crunch-hire is deliberately not in this list: it *dies* on
        // Normal on most seeds, and a dead company's final cash is
        // negative, so comparing medians would have Hard look richer. Its
        // difficulty story is the headcount assertion at the end.
        for (name, bot) in [
            ("solo", { SoloSlowBot() as any BotPolicy }),
            ("neglectful", { NeglectfulBot() as any BotPolicy }),
            ("saas", { SaaSBuilderBot() as any BotPolicy }),
        ] {
            let hard = try medianCash(bot(), .hard)
            let normal = try medianCash(bot(), .normal)
            #expect(hard < normal, "\(name) ended on \(hard) on Hard against \(normal) on Normal")
        }

        // The bet that Hard calls. On Normal the SaaS builder is the
        // richest strategy in the game; on Hard 0.65× revenue against
        // 1.5× operating costs means most of them never reach the launch.
        let saasHard = Self.count(try Self.runAll(SaaSBuilderBot(), difficulty: .hard)) {
            $0.wentBankrupt
        }
        let saasNormal = Self.count(try Self.runAll(SaaSBuilderBot())) { $0.wentBankrupt }
        #expect(saasHard >= 5, "only \(saasHard)/10 hard SaaS seeds went under in two years")
        #expect(
            saasHard > saasNormal,
            "SaaS: \(saasHard)/10 gone on Hard against \(saasNormal)/10 on Normal"
        )

        // And Hard costs you the company you could have built: the same
        // ambitious strategy tops out smaller.
        let hardPeak = try Self.runAll(CrunchHireBot(), difficulty: .hard)
            .map(\.peakHeadcount).max() ?? 0
        let normalPeak = try Self.runAll(CrunchHireBot()).map(\.peakHeadcount).max() ?? 0
        #expect(
            hardPeak < normalPeak,
            "crunch-hire reached \(hardPeak) people on Hard against \(normalPeak) on Normal"
        )
    }

    @Test func easyModeForgives() throws {
        let results = try Self.runAll(SoloSlowBot(), difficulty: .easy)
        #expect(
            Self.count(results) { $0.wentBankrupt } == 0,
            "a solo founder went bankrupt on Easy"
        )
    }

    // MARK: - Three years of one company

    /// The long view: three game years of one studio have to *contain* the
    /// consequences, not merely permit them. Consequences that only happen
    /// in unit tests are not consequences.
    @Test func threeYearsOfPlayProducesRealConsequences() throws {
        let years = 3 * 364
        let crunch = try Self.seeds.prefix(4).map {
            try Self.run(CrunchHireBot(), seed: $0, days: years)
        }
        let neglect = try Self.seeds.prefix(4).map {
            try Self.run(NeglectfulBot(), seed: $0, days: years)
        }

        // Someone hands in their notice under a boss who never says thank
        // you — and gets an answer, or does not.
        #expect(
            neglect.contains { $0.resignationNotices >= 1 },
            "nobody handed in their notice in three years of being ignored"
        )
        // …and does not under one who hands out raises.
        #expect(
            crunch.allSatisfy { $0.resignationNotices <= 3 },
            "raises should keep notices rare: \(crunch.map(\.resignationNotices))"
        )
        // The founder who crunches for three years ends up in hospital and
        // hears from the landlord.
        #expect(
            crunch.contains { $0.hospitalizations >= 1 },
            "a founder who crunched for three years was never once in hospital"
        )
        #expect(
            (crunch + neglect).contains { $0.evictionWarnings >= 1 },
            "the landlord never wrote in three years across eight runs"
        )
    }

    // MARK: - The table behind the gates

    /// Not a gate: prints the per-bot pacing table the gates above are
    /// derived from, so future tuning has a reference.
    @Test func baselineTable() throws {
        func summarize(_ label: String, _ results: [SimRunner.Result]) {
            func median(_ values: [Int]) -> Int {
                let sorted = values.sorted()
                return sorted.isEmpty ? 0 : sorted[sorted.count / 2]
            }
            print("""
            \(label.padding(toLength: 16, withPad: " ", startingAt: 0)) \
            ship d\(median(results.compactMap(\.firstShipDay))) \
            score \(median(results.compactMap(\.firstProductScore))) \
            rev1 \(median(results.compactMap(\.firstProductLifetimeRevenue))) \
            cash \(median(results.map(\.finalCash))) \
            shipped \(median(results.map(\.productsShipped))) \
            peak \(median(results.map(\.peakHeadcount))) \
            quits \(results.reduce(0) { $0 + $1.quits }) \
            notices \(results.reduce(0) { $0 + $1.resignationNotices })\
             hosp \(results.reduce(0) { $0 + $1.hospitalizations }) \
            evict \(results.reduce(0) { $0 + $1.evictionWarnings }) \
            pauses/y \(median(results.map { Int($0.pausesPerYear) })) \
            bankrupt \(results.filter(\.wentBankrupt).count)/10 \
            loft \(median(results.compactMap(\.daysToLoft))) \
            studio \(median(results.compactMap(\.daysToStudio))) \
            campus \(median(results.compactMap(\.daysToCampus))) \
            MRR \(median(results.map(\.finalWeeklySubscriptionRevenue)))
            """)
        }

        print("=== WS-A balance targets (10 seeds × 730 days, Normal) ===")
        summarize("solo-slow", try Self.runAll(SoloSlowBot()))
        summarize("crunch-hire", try Self.runAll(CrunchHireBot()))
        summarize("saas-builder", try Self.runAll(SaaSBuilderBot()))
        summarize("neglectful", try Self.runAll(NeglectfulBot()))
        summarize("grinder", try Self.runAll(ContractGrinderBot()))
        print("=== Hard (365 days) ===")
        summarize("neglectful/hard", try Self.runAll(NeglectfulBot(), difficulty: .hard, days: 365))
        summarize("crunch/hard", try Self.runAll(CrunchHireBot(), difficulty: .hard, days: 365))
        #expect(Self.seeds.count == 10)
    }
}
