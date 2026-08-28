import Foundation
import Testing
import TycoonContent
import TycoonEngine

@Suite("Marketing campaigns")
struct MarketingTests {
    /// A tiny catalog whose tech tree can unlock both gated campaign kinds.
    static func campaignContent(
        designPts: Double = 1_000, codePts: Double = 1_000, polishPts: Double = 1_000
    ) -> ContentCatalog {
        TestContent.tiny(
            designPts: designPts, codePts: codePts, polishPts: polishPts,
            techTree: [
                TestTech.node(id: "press_kit", researchCost: 10, effect: .unlockCampaignKind(id: "press_release")),
                TestTech.node(id: "launch_stage", researchCost: 10, effect: .unlockCampaignKind(id: "launch_event")),
            ]
        )
    }

    private func hype(of productID: UUID, in state: GameState) throws -> Double {
        guard case .development(let dev) = try #require(state.product(id: productID)).stage else {
            Issue.record("expected the product to be in development")
            throw CancellationError()
        }
        return dev.hype
    }

    private func marketingEntries(in state: GameState) -> [LedgerEntry] {
        state.ledger.entries.filter { $0.category == .marketing }
    }

    @Test func startCampaignGuardsRejectEveryInvalidRequest() throws {
        let balance = TestBalance.standard
        let content = Self.campaignContent()
        var state = GameState.newGame(companyName: "Acme", seed: 50, balance: balance)
        Reducer.apply(
            .startProduct(typeID: "tool", topicID: "testing", name: "T", focus: .balanced),
            to: &state, balance: balance, content: content
        )
        let productID = try #require(state.productInDevelopment?.id)

        func rejected(_ action: GameAction, _ reason: Comment) {
            let before = state
            #expect(Reducer.apply(action, to: &state, balance: balance, content: content).isEmpty, reason)
            #expect(state == before, reason)
        }

        rejected(.startCampaign(kindID: "skywriting", productID: productID), "unknown kind")
        rejected(.startCampaign(kindID: "social_push", productID: UUID()), "unknown product")
        rejected(.startCampaign(kindID: "press_release", productID: productID), "research-locked press release")
        rejected(.startCampaign(kindID: "launch_event", productID: productID), "research-locked launch event")

        state.research.unlocked.insert("launch_stage")
        rejected(.startCampaign(kindID: "launch_event", productID: productID), "office tier below the minimum")

        state.research.unlocked.insert("press_kit")
        state.company.officeTier = .studio
        state.company.cash = 400
        rejected(.startCampaign(kindID: "press_release", productID: productID), "can't afford the press release")
        state.company.cash = 4_999
        rejected(.startCampaign(kindID: "launch_event", productID: productID), "can't afford the launch event")

        // A campaign on a *delisted* product is ignored. A released one
        // that is still selling is a valid target: the Marketing tab has
        // always listed those and promised "a push now keeps it in front
        // of people", while `startCampaign` silently refused every one.
        state.company.cash = 50_000
        let shipped = Product(
            id: UUID(), name: "Old", typeID: "tool", topicID: "testing",
            stage: .released(ReleaseInfo(
                launchDay: 0, quality: 50, reviews: [], weeklySales: [], offMarket: true
            ))
        )
        state.products.append(shipped)
        rejected(.startCampaign(kindID: "social_push", productID: shipped.id), "delisted product")

        // Duplicate kind on the same product while one is still active.
        #expect(Reducer.apply(
            .startCampaign(kindID: "social_push", productID: productID),
            to: &state, balance: balance, content: content
        ).count == 1)
        rejected(.startCampaign(kindID: "social_push", productID: productID), "duplicate active kind")
    }

    @Test func socialPushChargesDailyAddsHypeAndExpires() throws {
        let balance = TestBalance.make(
            bugChanceBase: 0, skillGrowthRate: 0,
            socialPushDurationDays: 3, hypeDecayRate: 0
        )
        let content = Self.campaignContent()
        var state = GameState.newGame(companyName: "Acme", seed: 51, balance: balance)
        Reducer.apply(
            .startProduct(typeID: "tool", topicID: "testing", name: "T", focus: .balanced),
            to: &state, balance: balance, content: content
        )
        let productID = try #require(state.productInDevelopment?.id)
        let cashBefore = state.company.cash

        let events = Reducer.apply(
            .startCampaign(kindID: "social_push", productID: productID),
            to: &state, balance: balance, content: content
        )
        let campaign = try #require(state.campaigns.first)
        #expect(events == [.campaignStarted(campaignID: campaign.id, day: 0)])
        #expect(campaign.kindID == "social_push")
        #expect(campaign.productID == productID)
        #expect(campaign.endDay == balance.socialPushDurationDays)
        // No upfront cost, no immediate hype.
        #expect(state.company.cash == cashBefore)
        #expect(try hype(of: productID, in: state) == 0)

        // Each active day bills the daily cost and adds the daily hype.
        for day in 1...3 {
            Reducer.tick(&state, balance: balance, content: content)
            #expect(state.company.cash == cashBefore - day * balance.socialPushDailyCost)
            #expect(abs((try hype(of: productID, in: state)) - Double(day) * balance.socialPushDailyHype) < 1e-9)
        }
        let entries = marketingEntries(in: state)
        #expect(entries.count == 3)
        #expect(entries.allSatisfy { $0.amount == -balance.socialPushDailyCost })

        // Past endDay the campaign is removed and billing stops.
        Reducer.tick(&state, balance: balance, content: content) // day 4
        #expect(state.campaigns.isEmpty)
        #expect(state.company.cash == cashBefore - 3 * balance.socialPushDailyCost)
        #expect(abs((try hype(of: productID, in: state)) - 6.0) < 1e-9)
    }

    @Test func oneShotCampaignsChargeUpfrontAddHypeImmediatelyAndStayAsHistory() throws {
        let balance = TestBalance.make(bugChanceBase: 0, hypeDecayRate: 0)
        let content = Self.campaignContent()
        var state = GameState.newGame(companyName: "Acme", seed: 52, balance: balance)
        state.research.unlocked = ["press_kit", "launch_stage"]
        state.company.officeTier = .studio
        Reducer.apply(
            .startProduct(typeID: "tool", topicID: "testing", name: "T", focus: .balanced),
            to: &state, balance: balance, content: content
        )
        let productID = try #require(state.productInDevelopment?.id)
        let cashBefore = state.company.cash

        #expect(Reducer.apply(
            .startCampaign(kindID: "press_release", productID: productID),
            to: &state, balance: balance, content: content
        ).count == 1)
        #expect(state.company.cash == cashBefore - balance.pressReleaseCost)
        #expect(abs((try hype(of: productID, in: state)) - balance.pressReleaseHype) < 1e-9)
        let press = try #require(state.campaigns.first)
        #expect(press.endDay == 0)
        #expect(marketingEntries(in: state).last == LedgerEntry(
            day: 0, amount: -balance.pressReleaseCost, category: .marketing, label: "Press release"
        ))

        #expect(Reducer.apply(
            .startCampaign(kindID: "launch_event", productID: productID),
            to: &state, balance: balance, content: content
        ).count == 1)
        #expect(state.company.cash == cashBefore - balance.pressReleaseCost - balance.launchEventCost)
        #expect(abs((try hype(of: productID, in: state)) - (balance.pressReleaseHype + balance.launchEventHype)) < 1e-9)
        #expect(marketingEntries(in: state).last == LedgerEntry(
            day: 0, amount: -balance.launchEventCost, category: .marketing, label: "Launch event"
        ))

        // A same-day duplicate one-shot is still "active" and blocked.
        #expect(Reducer.apply(
            .startCampaign(kindID: "press_release", productID: productID),
            to: &state, balance: balance, content: content
        ).isEmpty)

        // One-shot records survive the daily sweep as history…
        Reducer.tick(&state, balance: balance, content: content)
        #expect(state.campaigns.count == 2)
        // …and a fresh press release is allowed again the next day.
        #expect(Reducer.apply(
            .startCampaign(kindID: "press_release", productID: productID),
            to: &state, balance: balance, content: content
        ).count == 1)
        #expect(state.campaigns.count == 3)
    }

    @Test func hypeDecaysDailyBeforeCampaignAdditions() throws {
        let balance = TestBalance.make(bugChanceBase: 0) // default hypeDecayRate 0.02
        let content = Self.campaignContent()
        var state = GameState.newGame(companyName: "Acme", seed: 53, balance: balance)
        state.research.unlocked.insert("press_kit")
        Reducer.apply(
            .startProduct(typeID: "tool", topicID: "testing", name: "T", focus: .balanced),
            to: &state, balance: balance, content: content
        )
        let productID = try #require(state.productInDevelopment?.id)

        Reducer.apply(
            .startCampaign(kindID: "press_release", productID: productID),
            to: &state, balance: balance, content: content
        )
        Reducer.apply(
            .startCampaign(kindID: "social_push", productID: productID),
            to: &state, balance: balance, content: content
        )
        #expect(abs((try hype(of: productID, in: state)) - balance.pressReleaseHype) < 1e-9)

        // The next day decays yesterday's 15 hype first, then adds the push's 2.
        Reducer.tick(&state, balance: balance, content: content)
        let expected = balance.pressReleaseHype * (1 - balance.hypeDecayRate) + balance.socialPushDailyHype
        #expect(abs((try hype(of: productID, in: state)) - expected) < 1e-9)
    }

    @Test func socialPushEndsWhenTheProductShipsAndHypeCarriesToLaunch() throws {
        let balance = TestBalance.make(
            bugChanceBase: 0, skillGrowthRate: 0, reviewNoiseSigma: 0, hypeDecayRate: 0
        )
        let content = Self.campaignContent(designPts: 2, codePts: 2, polishPts: 2)
        var state = GameState.newGame(companyName: "Acme", seed: 54, balance: balance)
        Reducer.apply(
            .startProduct(typeID: "tool", topicID: "testing", name: "T", focus: .balanced),
            to: &state, balance: balance, content: content
        )
        let productID = try #require(state.productInDevelopment?.id)
        Reducer.apply(
            .startCampaign(kindID: "social_push", productID: productID),
            to: &state, balance: balance, content: content
        )

        // Three active days: 150 billed, hype 6; all pools complete.
        for _ in 0..<3 { Reducer.tick(&state, balance: balance, content: content) }
        Reducer.apply(.ship(productID: productID), to: &state, balance: balance, content: content)

        guard case .released(let info) = try #require(state.product(id: productID)).stage else {
            Issue.record("expected a released stage")
            return
        }
        #expect(abs(info.hypeAtLaunch - 6.0) < 1e-9)
        #expect(marketingEntries(in: state).count == 3)

        // The shipped product's push is removed without billing another day.
        Reducer.tick(&state, balance: balance, content: content)
        #expect(state.campaigns.isEmpty)
        #expect(marketingEntries(in: state).count == 3)
    }
}

// MARK: - Repeats and the post-launch channel

/// The exploit and the missing channel: a one-shot ends the day it starts,
/// so before a cooldown existed the duplicate guard lapsed overnight and a
/// $500 press release could be bought every day.
@Suite("Campaign repeats and post-launch pushes")
struct CampaignRepeatTests {
    private static func economy(
        campaignCooldownDays: Int = 14,
        campaignRepeatHypeDecay: Double = 0.7,
        liveHypeSalesFactor: Double = 1
    ) -> BalanceConfig.EconomyBalance {
        var economy = TestBalance.neutralEconomy
        economy.campaignCooldownDays = campaignCooldownDays
        economy.campaignRepeatHypeDecay = campaignRepeatHypeDecay
        economy.liveHypeSalesFactor = liveHypeSalesFactor
        return economy
    }

    private static func started(
        _ balance: BalanceConfig
    ) throws -> (GameState, UUID, ContentCatalog) {
        let content = MarketingTests.campaignContent()
        var state = GameState.newGame(companyName: "Acme", seed: 3, balance: balance)
        state.company.cash = 500_000
        state.research.unlocked.insert("press_kit")
        Reducer.apply(
            .startProduct(typeID: "tool", topicID: "testing", name: "T", focus: .balanced),
            to: &state, balance: balance, content: content
        )
        let id = try #require(state.productInDevelopment?.id)
        return (state, id, content)
    }

    @Test("A press release cannot be repeated the next day")
    func oneShotsHaveACooldown() throws {
        let balance = TestBalance.make(life: TestBalance.quietLife, economy: Self.economy())
        var (state, id, content) = try Self.started(balance)

        #expect(!Reducer.apply(
            .startCampaign(kindID: "press_release", productID: id),
            to: &state, balance: balance, content: content
        ).isEmpty)

        Reducer.tick(&state, balance: balance, content: content)
        #expect(Reducer.apply(
            .startCampaign(kindID: "press_release", productID: id),
            to: &state, balance: balance, content: content
        ).isEmpty)
    }

    @Test("Telling the same story again is worth less")
    func repeatsDecay() throws {
        let balance = TestBalance.make(life: TestBalance.quietLife, economy: Self.economy())
        var (state, id, content) = try Self.started(balance)

        func pressRelease() throws -> Double {
            guard case .development(let before) = try #require(state.product(id: id)).stage else {
                return 0
            }
            Reducer.apply(
                .startCampaign(kindID: "press_release", productID: id),
                to: &state, balance: balance, content: content
            )
            guard case .development(let after) = try #require(state.product(id: id)).stage else {
                return 0
            }
            return after.hype - before.hype
        }

        let first = try pressRelease()
        // Past the cooldown, and hype decay does not touch the delta.
        for _ in 0..<15 { Reducer.tick(&state, balance: balance, content: content) }
        let second = try pressRelease()

        #expect(first > 0)
        #expect(second < first)
        #expect(abs(second - first * 0.7) < 0.01)
    }

    @Test("A push on a released product feeds sales, not reviews")
    func postLaunchPushIsRealNow() throws {
        let balance = TestBalance.make(life: TestBalance.quietLife, economy: Self.economy())
        let content = MarketingTests.campaignContent()
        var state = GameState.newGame(companyName: "Acme", seed: 3, balance: balance)
        state.company.cash = 500_000
        let released = Product(
            id: UUID(), name: "Live", typeID: "tool", topicID: "testing",
            stage: .released(ReleaseInfo(
                launchDay: 0, quality: 60, reviews: [], weeklySales: [], offMarket: false
            ))
        )
        state.products.append(released)

        // The tab always offered this and the engine always refused it.
        #expect(!Reducer.apply(
            .startCampaign(kindID: "social_push", productID: released.id),
            to: &state, balance: balance, content: content
        ).isEmpty)

        Reducer.tick(&state, balance: balance, content: content)
        guard case .released(let info) = try #require(state.product(id: released.id)).stage else {
            return
        }
        #expect(info.liveHype > 0)
        // The press has already filed: this buys attention, not a better
        // score.
        #expect(info.hypeAtLaunch == 0)
    }

    @Test("A push bought for the launch ends at the launch")
    func launchPushDoesNotBillOnPastRelease() throws {
        let balance = TestBalance.make(life: TestBalance.quietLife, economy: Self.economy())
        var (state, id, content) = try Self.started(balance)
        Reducer.apply(
            .startCampaign(kindID: "social_push", productID: id),
            to: &state, balance: balance, content: content
        )
        #expect(state.campaigns.count == 1)

        // Ship it out from under the running push.
        if case .development = state.product(id: id)?.stage {
            let index = try #require(state.products.firstIndex { $0.id == id })
            state.products[index].stage = .released(ReleaseInfo(
                launchDay: state.day, quality: 60, reviews: [], weeklySales: [], offMarket: false
            ))
        }
        Reducer.tick(&state, balance: balance, content: content)

        // Its job was the launch; the player is not billed past it.
        #expect(state.campaigns.isEmpty)
    }
}
