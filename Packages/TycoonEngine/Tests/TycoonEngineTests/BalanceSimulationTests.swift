import Foundation
import Testing
import TycoonContent
import TycoonEngine
import TycoonBots

/// Long-horizon balance gates: three deterministic bots each play 730 days
/// (two game years) through the real reducer against the shipped
/// Balance.json, and the run must satisfy the survival invariants below.
/// A failure here means Balance.json needs tuning, not that the reducer is
/// wrong.
@Suite("Balance simulation harness")
struct BalanceSimulationTests {
    private static let days = 730

    private static func run(_ bot: any BotPolicy, seed: UInt64) throws -> SimRunner.Result {
        // Rivals are disabled: the bots predate them and never answer
        // offers, so auto-resolved poaches would decimate every roster.
        var balance = try BalanceConfig.loadBundled()
        balance.rivals.rivalCount = 0
        return SimRunner.run(
            days: days,
            seed: seed,
            bot: bot,
            balance: balance,
            content: TestContent.bundled
        )
    }

    /// Invariants every bot must satisfy: the run finished without the state
    /// going pathological — cash within sane bounds (Int is always finite;
    /// this guards runaway feedback loops) and no unbounded arrays.
    private func assertCommonInvariants(_ result: SimRunner.Result) {
        #expect(abs(result.finalCash) < 1_000_000_000, "\(result.botName): runaway cash")
        #expect(abs(result.minCash) < 1_000_000_000, "\(result.botName): runaway debt")
        #expect(result.maxLedgerCount <= 500, "\(result.botName): unbounded ledger")
        #expect(result.maxEventLogCount <= 500, "\(result.botName): unbounded event log")
    }

    @Test func contractGrinderSurvivesTwoYears() throws {
        let result = try Self.run(ContractGrinderBot(), seed: 7_301)

        assertCommonInvariants(result)
        #expect(!result.wentBankrupt, "grinder went bankrupt on day \(result.daysRun)")
        #expect(result.daysRun == Self.days)
        #expect(result.productsShipped == 0, "the grinder never builds products")
        #expect(result.contractsCompleted > 0)
    }

    /// Replaces the old "ship-fast reaches $50k of revenue" gate, which
    /// measured the pre-economy-pass numbers. Speed alone no longer pays:
    /// the bot dumps mobile app after mobile app into a single topic, so
    /// launch saturation and genre fatigue shrink each release (its ledger
    /// runs 1054, 1603, 887, 344, 147, 27) until the payroll outruns the
    /// revenue.
    @Test func shippingFastIntoOneTopicSaturatesIt() throws {
        let result = try Self.run(ShipFastBot(), seed: 7_302)

        assertCommonInvariants(result)
        #expect(result.productsShipped > 5, "ship-fast is supposed to be prolific")

        let revenues = result.state.products.compactMap { product -> Int? in
            guard case .released(let info) = product.stage else { return nil }
            return info.totalRevenue
        }
        let first = try #require(revenues.first)
        let fifth = try #require(revenues.dropFirst(4).first)
        #expect(
            fifth < first / 4,
            "the fifth release into the same topic earned \(fifth) against the first's \(first)"
        )
        #expect(
            result.totalProductRevenue < 200_000,
            "spamming one topic still earned \(result.totalProductRevenue)"
        )
    }

    /// The loft is still reachable on a mixed contract/product strategy —
    /// but under the economy pass it is a decision, not a milestone the
    /// game hands out: this bot sinks every release into one topic, and
    /// after about ninety weeks of that the loft's rent outruns the sales
    /// it can still find. It gets there, and then it has to keep earning.
    @Test func balancedReachesTheLoftAndThenHasToKeepEarning() throws {
        let result = try Self.run(BalancedBot(), seed: 7_303)

        assertCommonInvariants(result)
        #expect(result.officeTier != .garage, "balanced never left the garage")
        #expect(result.state.milestonesReached.contains(OfficeTier.loft.rawValue))
        #expect(result.daysRun > 365, "balanced should survive its first year")
        #expect(result.contractsCompleted > 0)
    }

    /// Not a gate: logs the per-bot baseline table so future tuning has a
    /// reference for what the current Balance.json produces.
    @Test func baselineTableForFutureTuning() throws {
        let results = [
            try Self.run(ContractGrinderBot(), seed: 7_301),
            try Self.run(ShipFastBot(), seed: 7_302),
            try Self.run(BalancedBot(), seed: 7_303),
        ]

        print("=== Balance baseline (730 days, bundled Balance.json) ===")
        for result in results {
            print(result.tableRow)
        }
        #expect(results.count == 3)
    }
}
