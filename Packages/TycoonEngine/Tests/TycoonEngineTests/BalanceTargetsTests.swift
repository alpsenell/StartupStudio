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
            #expect(
                (8_000...45_000).contains(revenue),
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
        #expect(
            Self.count(results) { $0.daysToLoft != nil } >= 6,
            "crunch-hire should reach the loft on most seeds"
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

    // MARK: - Recurring revenue is a real strategy

    @Test func saaSBuilderBuildsRecurringRevenue() throws {
        let results = try Self.runAll(SaaSBuilderBot())
        let earners = Self.count(results) { $0.finalWeeklySubscriptionRevenue >= 20_000 }
        #expect(
            earners >= 6,
            """
            only \(earners)/10 SaaS seeds reached $20k/week of subscriptions \
            (\(results.map(\.finalWeeklySubscriptionRevenue)))
            """
        )
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

    @Test func theSoloFounderWhoNeverLooksAfterThemselvesPaysForIt() throws {
        let results = try Self.runAll(SoloSlowBot())
        let warned = Self.count(results) { $0.evictionWarnings > 0 }
        #expect(warned >= 5, "only \(warned)/10 solo seeds ever saw an eviction warning")
        for result in results {
            #expect(
                result.minWallet > -8_000,
                "solo's wallet reached \(result.minWallet) with no eviction to stop it"
            )
        }
    }

    // MARK: - The clock only stops when it matters

    @Test func autoPausesStayWithinBudget() throws {
        let crunch = try Self.runAll(CrunchHireBot())
        let solo = try Self.runAll(SoloSlowBot())

        for result in crunch {
            #expect(
                result.pausesPerYear <= 45,
                "crunch-hire paused \(Int(result.pausesPerYear))×/year"
            )
        }
        for result in solo {
            #expect(
                result.pausesPerYear <= 30,
                "solo paused \(Int(result.pausesPerYear))×/year"
            )
        }
    }

    // MARK: - Difficulty means something

    @Test func hardModeIsGenuinelyHard() throws {
        let results = try Self.runAll(NeglectfulBot(), difficulty: .hard, days: 365)
        let broke = Self.count(results) { $0.wentBankrupt }
        #expect(
            broke >= 5,
            "only \(broke)/10 hard-mode neglectful seeds went under in year one"
        )
    }

    @Test func easyModeForgives() throws {
        let results = try Self.runAll(SoloSlowBot(), difficulty: .easy)
        #expect(
            Self.count(results) { $0.wentBankrupt } == 0,
            "a solo founder went bankrupt on Easy"
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
