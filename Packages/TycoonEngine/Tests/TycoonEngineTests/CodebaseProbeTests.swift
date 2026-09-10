import Foundation
import Testing
import TycoonContent
import TycoonEngine
import TycoonBots

/// Bots that take the head start every time, and the table that says
/// whether it is worth taking.
///
/// The existing pacing bots never build on a codebase — `.startProduct` is
/// greenfield and always will be — so `BalanceTargetsTests` is blind to
/// this feature by construction. These are the runs that are not.
///
/// The claim under test is the PM's: "if playtesters take the head start
/// every time without thinking, the debt number is too small; if they never
/// take it, it's too big." A bot cannot answer the first half, but it can
/// answer whether the two sides are the same size, which is the part that
/// is checkable in numbers.

/// `SoloSlowBot`, except it builds on the studio's own codebase whenever
/// there is one. Same type every time, so from the second product on there
/// always is.
struct CodebaseSoloBot: BotPolicy {
    let name = "solo-codebase"

    func actions(
        for state: GameState,
        balance: BalanceConfig,
        content: ContentCatalog
    ) -> [GameAction] {
        guard let product = state.productsInDevelopment.first else {
            let topic = BotHelp.topic(forProductNumber: state.products.count)
            let name = "Solo \(state.products.count + 1)"
            if let codebase = state.availableCodebases(typeID: "mobile_app").first {
                return [.startProductOnCodebase(
                    typeID: "mobile_app", topicID: topic, name: name,
                    focus: .balanced, codebaseID: codebase.id
                )]
            }
            return [.startProduct(
                typeID: "mobile_app", topicID: topic, name: name, focus: .balanced
            )]
        }
        if BotHelp.looksShippable(product, balance, content, polish: 0.7) {
            return [.ship(productID: product.id)]
        }
        return BotHelp.assignAll(state, to: .product(product.id)) + [
            .setPhaseFocus(
                productID: product.id,
                focus: BotHelp.focusForRemainingWork(product, content)
            )
        ]
    }
}

/// `CrunchHireBot`, except it builds on the codebase whenever one of the
/// right type exists. The bot that finds out what crunching on your own
/// foundations for two years costs — it is the only one that feeds both
/// debt channels, because it crunches every day *and* ships at 85%.
struct CodebaseCrunchBot: BotPolicy {
    let name = "crunch-codebase"
    private let inner = CrunchHireBot()

    func actions(
        for state: GameState,
        balance: BalanceConfig,
        content: ContentCatalog
    ) -> [GameAction] {
        inner.actions(for: state, balance: balance, content: content).map { action in
            guard case let .startProduct(typeID, topicID, name, focus) = action,
                  let codebase = state.availableCodebases(typeID: typeID).first
            else { return action }
            return .startProductOnCodebase(
                typeID: typeID, topicID: topicID, name: name,
                focus: focus, codebaseID: codebase.id
            )
        }
    }
}

@Suite("The codebase, measured")
struct CodebaseProbeTests {
    static let days = BalanceTargetsTests.days
    static let seeds = BalanceTargetsTests.seeds

    /// The shipped balance with rivals off, as `BalanceTargetsTests` runs
    /// it, optionally with the debt channels switched off — the PM's
    /// "head start on, debt off" probe.
    static func balance(debt: Bool) throws -> BalanceConfig {
        var balance = try BalanceTargetsTests.balance()
        if !debt {
            balance.codebase.crunchDebtPerDay = 0
            balance.codebase.shipBugDebt = 0
            balance.codebase.patchDebt = 0
        }
        return balance
    }

    static func runAll(
        _ bot: @autoclosure () -> any BotPolicy,
        debt: Bool = true
    ) throws -> [SimRunner.Result] {
        let balance = try balance(debt: debt)
        return seeds.map {
            SimRunner.run(
                days: days, seed: $0, bot: bot(),
                balance: balance, content: TestContent.bundled
            )
        }
    }

    /// Every release in the order it shipped, as (day, review score).
    static func releases(_ result: SimRunner.Result) -> [(day: Int, score: Int)] {
        result.state.products
            .compactMap { product -> (day: Int, score: Int)? in
                guard case .released(let info) = product.stage else { return nil }
                return (info.launchDay, info.averageReviewScore)
            }
            .sorted { $0.day < $1.day }
    }

    static func median(_ values: [Int]) -> Int {
        let sorted = values.sorted()
        return sorted.isEmpty ? 0 : sorted[sorted.count / 2]
    }

    // MARK: - The gate the probe exists to protect

    /// The first product a studio ever ships is greenfield — there is no
    /// codebase yet to build it on — so `soloFounderShipsALateAndRoughFirstProduct`
    /// cannot move whatever the head start is set to. This asserts that
    /// rather than assuming it: a codebase-taking bot must clear the same
    /// first-product gate as the solo bot the balance was tuned against.
    @Test func theFirstProductIsGreenfieldWhateverTheBotIntends() throws {
        for (label, results) in [
            ("head start + debt", try Self.runAll(CodebaseSoloBot())),
            ("head start only", try Self.runAll(CodebaseSoloBot(), debt: false)),
        ] {
            for result in results {
                let day = try #require(result.firstShipDay, "\(label): never shipped")
                #expect((45...110).contains(day), "\(label): first ship on day \(day)")
                let score = try #require(result.firstProductScore)
                #expect((40...66).contains(score), "\(label): first product reviewed \(score)")
            }
        }
    }

    /// A codebase-taking studio still has to run a company. The gate is
    /// deliberately the same shape as `soloFounderNeverGetsRichAndNeverGoesBust`:
    /// the head start is a head start, not a money printer.
    @Test func theHeadStartIsNotAMoneyPrinter() throws {
        for result in try Self.runAll(CodebaseSoloBot()) {
            #expect(!result.wentBankrupt, "solo-codebase went bankrupt on day \(result.daysRun)")
            #expect(
                result.finalCash < 400_000,
                "solo-codebase sat on \(result.finalCash) after two years"
            )
        }
    }

    /// Both halves of the trade have to be big enough to notice. A head
    /// start nobody can feel is a decorated checkbox; a debt nobody can
    /// feel is a second tax on crunch with no counter-play.
    @Test func bothSidesOfTheTradeAreVisibleInTheNumbers() throws {
        let control = try BalanceTargetsTests.runAll(SoloSlowBot())
        let taking = try Self.runAll(CodebaseSoloBot())

        // The head start buys products. If it did not, nobody would ever
        // take it and the debt would never be paid.
        let controlShipped = Self.median(control.map(\.productsShipped))
        let takingShipped = Self.median(taking.map(\.productsShipped))
        #expect(takingShipped > controlShipped,
                "the head start bought no extra products (\(takingShipped) vs \(controlShipped))")

        // And the debt is real: a studio that has built on the same
        // foundations for two years is carrying something.
        let crunching = try Self.runAll(CodebaseCrunchBot())
        let debts = crunching.compactMap { $0.state.codebases.map(\.debt).max() }
        #expect(Self.median(debts.map { Int($0.rounded()) }) > 0,
                "two years of crunching on one codebase left it spotless")
    }

    // MARK: - The table behind the choice

    /// Not a gate: the numbers `carryFraction`, `debtCeilingPenaltyPerPoint`
    /// and `crunchDebtPerDay` were picked from.
    @Test func codebaseTable() throws {
        func summarize(_ label: String, _ results: [SimRunner.Result]) {
            let all = results.map(Self.releases)
            func nth(_ index: Int, _ pick: ((day: Int, score: Int)) -> Int) -> String {
                let values = all.compactMap { $0.count > index ? pick($0[index]) : nil }
                return values.isEmpty ? "—" : "\(Self.median(values))"
            }
            let debts = results.compactMap { $0.state.codebases.map(\.debt).max() }
            print("""
            \(label.padding(toLength: 20, withPad: " ", startingAt: 0)) \
            ship1 d\(nth(0, \.day))/s\(nth(0, \.score)) \
            ship2 d\(nth(1, \.day))/s\(nth(1, \.score)) \
            ship3 d\(nth(2, \.day))/s\(nth(2, \.score)) \
            ship4 d\(nth(3, \.day))/s\(nth(3, \.score)) \
            shipped \(Self.median(results.map(\.productsShipped))) \
            cash \(Self.median(results.map(\.finalCash))) \
            peakDebt \(Self.median(debts.map { Int($0.rounded()) })) \
            bankrupt \(results.filter(\.wentBankrupt).count)/\(results.count)
            """)
        }

        print("=== The codebase (10 seeds × \(Self.days) days, Normal, rivals off) ===")
        summarize("solo greenfield", try BalanceTargetsTests.runAll(SoloSlowBot()))
        summarize("solo head-start only", try Self.runAll(CodebaseSoloBot(), debt: false))
        summarize("solo shipped", try Self.runAll(CodebaseSoloBot()))
        summarize("crunch greenfield", try BalanceTargetsTests.runAll(CrunchHireBot()))
        summarize("crunch head-start only", try Self.runAll(CodebaseCrunchBot(), debt: false))
        summarize("crunch shipped", try Self.runAll(CodebaseCrunchBot()))
        #expect(Self.seeds.count == 10)
    }
}
