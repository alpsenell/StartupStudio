import Foundation
import Testing
import TycoonContent
@testable import TycoonEngine

/// The Category Fight (iteration 5, WS-A): the phantom price war, the
/// share floor standing buys, the six-week challenge and the weekly
/// strength bleed.
///
/// The contract this suite protects is the same as `CategoryStandingTests`:
/// none of it reaches a game with `rivalCount = 0`, so the 19 pacing gates
/// measure the same table. Everything here is gated on a rival actually
/// selling into a topic the player is selling into.
@Suite("Category fight")
struct CategoryFightTests {
    private static let content = TestContent.bundled

    /// The bundled balance with the field on.
    private static func balance(rivals: Int = 4) throws -> BalanceConfig {
        var balance = try BalanceConfig.loadBundled()
        balance.rivals.rivalCount = rivals
        return balance
    }

    // MARK: - The phantom price war

    /// Finding 1's evidence: "Anvil Digital started a price war in Finance"
    /// on day 15, against a company with no products. A rival's first
    /// launch into a topic the player has never entered is not the player
    /// beating it, so there is nothing to retaliate against.
    @Test func aFreshGameWithNoProductIsNeverAtWar() throws {
        let balance = try Self.balance()
        for seed in BalanceTargetsTests.seeds {
            var state = GameState.newGame(companyName: "Quiet", seed: seed, balance: balance)
            var wars: [GameEvent] = []
            var launches = 0
            for _ in 0..<90 {
                for event in Reducer.tick(&state, balance: balance, content: Self.content) {
                    if case .priceWarStarted = event { wars.append(event) }
                    if case .rivalProductLaunched = event { launches += 1 }
                }
                #expect(state.products.isEmpty)
            }
            #expect(wars.isEmpty, "seed \(seed): a price war against a company with no products: \(wars)")
        }
    }

    /// …and the war still fires where it should: a player product that
    /// out-sells a rival's twice provokes one (`beatingARivalTwiceStartsAPriceWar`
    /// in `RivalProductTests` is the positive half; this pins that the fix
    /// did not silence it by checking the trigger topic is one the player
    /// is actually in).
    @Test func theWarStillFiresInATopicThePlayerSellsIn() throws {
        let balance = try Self.balance(rivals: 1)
        var state = GameState.newGame(companyName: "Acme", seed: 47, balance: balance)
        state.rivals.rivals = []
        RivalFightFixtures.addPlayerProduct(to: &state, topicID: "fitness", score: 88)
        let rivalID = RivalProductTests.addRival(
            to: &state, personality: .deepPockets, topicID: "fitness", productQuality: 30
        )
        var warTopic: String?
        for _ in 0..<(8 * GameState.daysPerWeek) {
            for event in Reducer.tick(&state, balance: balance, content: Self.content) {
                if case .priceWarStarted(let id, let topicID, _, _) = event, id == rivalID {
                    warTopic = topicID
                }
            }
            if warTopic != nil { break }
        }
        #expect(warTopic == "fitness")
    }

    // MARK: - The balance block

    @Test func theShippedBalanceCarriesTheDepthBlock() throws {
        let depth = try BalanceConfig.loadBundled().rivals.depth
        #expect(depth == .default)
        #expect(depth.shareFloorAtFullStanding == 0.55)
        #expect(depth.challengeWeeks == 6)
        // Designed at 1.0, shipped at 0.5 — see `DepthBalance`.
        #expect(depth.strengthPerWeekBeaten == 0.5)
        #expect(depth.incumbentEnabled)
        #expect(depth.incumbentValuationFloor == 750_000)
    }

    /// A `"rivals"` object from before the block, or one that tunes a
    /// single knob, still decodes — against the shipped defaults.
    @Test func aRivalsBlockWithoutDepthStillDecodes() throws {
        let balance = try BalanceConfig.loadBundled()
        let data = try JSONEncoder().encode(balance.rivals)
        var object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(object["depth"] != nil)

        object.removeValue(forKey: "depth")
        let absent = try JSONDecoder().decode(
            BalanceConfig.RivalBalance.self, from: try JSONSerialization.data(withJSONObject: object)
        )
        #expect(absent.depth == .default)
        #expect(absent.rivalCount == balance.rivals.rivalCount)

        object["depth"] = ["challengeWeeks": 9]
        let partial = try JSONDecoder().decode(
            BalanceConfig.RivalBalance.self, from: try JSONSerialization.data(withJSONObject: object)
        )
        #expect(partial.depth.challengeWeeks == 9)
        #expect(partial.depth.shareFloorAtFullStanding == 0.55)
    }

    // MARK: - Standing holds share

    /// The player's share of a contested topic at a given standing, with a
    /// rival product good enough to push the raw share under every floor.
    private static func share(atStanding standing: Double, floorAtFull: Double = 0.55) throws -> Double {
        var balance = try Self.balance(rivals: 1)
        balance.rivals.depth.shareFloorAtFullStanding = floorAtFull
        balance.rivals.depth.strengthPerWeekBeaten = 0
        balance.rivals.depth.standingPerWeekBeaten = 0
        var state = GameState.newGame(companyName: "Acme", seed: 44, balance: balance)
        state.rivals.rivals = []
        RivalFightFixtures.addPlayerProduct(to: &state, topicID: "fitness", score: 40)
        _ = RivalProductTests.addRival(
            to: &state, personality: .deepPockets, topicID: "fitness", productQuality: 90
        )
        state.market.standing["fitness"] = standing
        // Tick to an evolution day so the weekly share pass runs; the
        // market's own retainer moves standing by half a point, which is
        // why the assertions below leave a margin.
        for _ in 0..<balance.rivals.evolveIntervalDays {
            Reducer.tick(&state, balance: balance, content: Self.content)
        }
        return state.rivals.share(for: "fitness")
    }

    @Test func standingHoldsShareOnlyOnceItClearsTheHardFloor() throws {
        // A 40 against a 90 is worth 16% of the market on quality; the old
        // floor makes it 30, and nothing below standing ~55 changes that.
        let raw = (40.0 * 40.0) / (40.0 * 40.0 + 90.0 * 90.0)
        #expect(raw < RivalDepthTuning.shareMin)
        #expect(try Self.share(atStanding: 0) == RivalDepthTuning.shareMin)
        #expect(try Self.share(atStanding: 50) == RivalDepthTuning.shareMin)

        // Above it, the floor is standing's: 0.44 at 80, 0.55 at 100.
        let at80 = try Self.share(atStanding: 80)
        #expect(at80 > RivalDepthTuning.shareMin)
        #expect(abs(at80 - 0.55 * 0.805) < 0.01, "share at standing 80 was \(at80)")
        let at100 = try Self.share(atStanding: 100)
        #expect(abs(at100 - 0.55) < 0.01, "share at standing 100 was \(at100)")

        // And the knob is the whole of it: switched off, standing 100 reads
        // like standing 0.
        #expect(try Self.share(atStanding: 100, floorAtFull: 0) == RivalDepthTuning.shareMin)
    }

    /// The twin of `standingNeverReachesTheEconomy`, with rivals on: a run
    /// whose standing never leaves zero measures the same cash, the same
    /// reputation and the same share whether the floor term is 0.55 or 0.
    /// The floor is the one place standing now reaches the economy, and
    /// this pins that it reaches it through standing alone.
    @Test func atStandingZeroTheFloorIsANoOpToTheDollar() throws {
        func run(floorAtFull: Double) throws -> (cash: Int, reputation: Double, share: [String: Double]) {
            var balance = try Self.balance()
            balance.rivals.depth.shareFloorAtFullStanding = floorAtFull
            // Standing stays at zero: nothing pays into the ledger.
            balance.market.standing.shipGain = 0
            balance.market.standing.reviewGainPerPoint = 0
            balance.market.standing.patchGain = 0
            balance.market.standing.campaignGain = 0
            balance.market.standing.presenceWeeklyGain = 0
            let result = SimRunner.run(
                days: 400, seed: 4_242, bot: SoloSlowBot(),
                balance: balance, content: Self.content
            )
            #expect(result.state.market.standing.values.allSatisfy { $0 == 0 })
            return (result.state.company.cash, result.state.company.reputation, result.state.rivals.playerShare)
        }
        let shipped = try run(floorAtFull: 0.55)
        let off = try run(floorAtFull: 0)
        #expect(shipped.cash == off.cash)
        #expect(shipped.reputation == off.reputation)
        #expect(shipped.share == off.share)
        #expect(!shipped.share.isEmpty, "the run was never contested, so this proves nothing")
    }

    // MARK: - The challenge opens

    /// A player at standing `standing` in fitness with a product scoring
    /// `score`, and a copycat elsewhere at `rivalStrength` that will clone
    /// the product eight weeks after its launch. Returns the state after
    /// `weeks` weeks and the challenge events seen.
    private static func copycatScenario(
        standing: Double,
        score: Int = 60,
        rivalStrength: Double = 70,
        weeks: Int = 9,
        lastChallengeDay: Int? = nil,
        configure: (inout BalanceConfig) -> Void = { _ in }
    ) throws -> (state: GameState, challenged: [GameEvent], launched: Int) {
        var balance = try Self.balance(rivals: 1)
        RivalFightFixtures.stillRivals(&balance)
        configure(&balance)
        var state = GameState.newGame(companyName: "Acme", seed: 46, balance: balance)
        state.rivals.rivals = []
        RivalFightFixtures.addPlayerProduct(to: &state, topicID: "fitness", score: score)
        _ = RivalProductTests.addRival(
            to: &state, personality: .copycat, topicID: "productivity", productQuality: nil
        )
        state.rivals.rivals[0].strength = rivalStrength
        state.market.standing["fitness"] = standing
        if let lastChallengeDay { state.rivals.lastChallengeDay["fitness"] = lastChallengeDay }

        var challenged: [GameEvent] = []
        var launched = 0
        for _ in 0..<(weeks * GameState.daysPerWeek) {
            for event in Reducer.tick(&state, balance: balance, content: Self.content) {
                if case .categoryChallenged = event { challenged.append(event) }
                if case .rivalProductLaunched = event { launched += 1 }
            }
        }
        return (state, challenged, launched)
    }

    @Test func aLaunchIntoAHeldCategoryStopsTheClock() throws {
        let (state, challenged, launched) = try Self.copycatScenario(standing: 60)
        #expect(launched == 1, "the copycat never cloned the product, so this proves nothing")
        #expect(challenged.count == 1)
        guard case let .categoryChallenged(rivalID, topicID, productName, quality, respondByDay, day)? = challenged.first
        else { return }
        #expect(topicID == "fitness")
        #expect(rivalID == state.rivals.rivals[0].id)
        #expect(!productName.isEmpty)
        // Within the window below the player's 60, or better.
        #expect(quality >= 45)
        #expect(respondByDay == day + 6 * GameState.daysPerWeek)
        #expect(challenged[0].severity == .critical, "the challenge has to stop the clock")

        let pending = try #require(state.rivals.pendingChallenge)
        #expect(pending.topicID == "fitness")
        #expect(pending.isPending)
        #expect(pending.settlesDay == respondByDay)
        #expect(state.rivals.lastChallengeDay["fitness"] == day)
        #expect(state.rivals.challenge(in: "fitness") == pending)
    }

    @Test func noChallengeBelowTheStandingBar() throws {
        // Eight weeks of the retainer (+0.5 a week) run before the clone
        // lands; 40 stays under the bar, 49 would not.
        let (_, challenged, launched) = try Self.copycatScenario(standing: 40)
        #expect(launched == 1)
        #expect(challenged.isEmpty, "a category the player does not hold is not worth a clock stop")
    }

    @Test func noChallengeFromALaunchWellBelowThePlayersBest() throws {
        // A strength-20 studio clones at 20-ish: nowhere near a 60.
        let (_, challenged, launched) = try Self.copycatScenario(standing: 60, rivalStrength: 20)
        #expect(launched == 1)
        #expect(challenged.isEmpty, "a weak clone read as a challenge — that is the nag the window guards")
    }

    @Test func oneChallengePerTopicPerCooldown() throws {
        // The clone lands on day 56. A fight opened 100 days before that is
        // inside the 26-week cooldown; one opened 200 days before is not.
        let inside = try Self.copycatScenario(standing: 60, lastChallengeDay: -100)
        #expect(inside.launched == 1)
        #expect(inside.challenged.isEmpty)
        let outside = try Self.copycatScenario(standing: 60, lastChallengeDay: -200)
        #expect(outside.challenged.count == 1)
    }

    @Test func theKnobsAreTheWholeOfIt() throws {
        // The bar off the scale: never a challenge, however held the topic.
        let (_, challenged, launched) = try Self.copycatScenario(standing: 100) {
            $0.rivals.depth.challengeMinStanding = .infinity
        }
        #expect(launched == 1)
        #expect(challenged.isEmpty)
    }

    // MARK: - The settlement

    /// A fight already open in fitness, settling on the next weekly pass,
    /// against a rival product of `rivalQuality`; the player scores
    /// `score` at `standing`. Rivals are still (no drift, no rolls), so
    /// every number below is exact.
    private static func settle(
        score: Int,
        rivalQuality: Double,
        standing: Double = 60,
        before: (inout GameState) -> Void = { _ in }
    ) throws -> (state: GameState, events: [GameEvent], rivalID: UUID, standingBefore: Double, strengthBefore: Double) {
        var balance = try Self.balance(rivals: 1)
        RivalFightFixtures.stillRivals(&balance)
        var state = GameState.newGame(companyName: "Acme", seed: 48, balance: balance)
        state.rivals.rivals = []
        RivalFightFixtures.addPlayerProduct(to: &state, topicID: "fitness", score: score)
        let rivalID = RivalProductTests.addRival(
            to: &state, personality: .deepPockets, topicID: "music", productQuality: nil
        )
        state.rivals.rivals[0].products = [RivalProduct(
            id: UUID(), name: "Their Thing", topicID: "fitness", typeID: "mobile_app",
            quality: rivalQuality, launchDay: 0, weeklyUnits: 100
        )]
        state.market.standing["fitness"] = standing
        state.rivals.challenges = [CategoryChallenge(
            rivalID: rivalID, topicID: "fitness", productName: "Their Thing",
            quality: rivalQuality, startedDay: 0, settlesDay: balance.rivals.evolveIntervalDays
        )]
        before(&state)
        let standingBefore = state.market.standing(for: "fitness")
        let strengthBefore = state.rivals.rivals.first?.strength ?? 0

        var events: [GameEvent] = []
        for _ in 0..<balance.rivals.evolveIntervalDays {
            events.append(contentsOf: Reducer.tick(&state, balance: balance, content: Self.content))
        }
        return (state, events, rivalID, standingBefore, strengthBefore)
    }

    @Test func holdingTheCategoryCostsTheRivalStrengthAndPaysStanding() throws {
        let depth = BalanceConfig.RivalBalance.DepthBalance.default
        let (state, events, rivalID, standingBefore, strengthBefore) = try Self.settle(score: 80, rivalQuality: 45)
        #expect(state.rivals.share(for: "fitness") >= depth.challengeHoldShare)
        #expect(events.contains(.categoryHeld(rivalID: rivalID, topicID: "fitness", day: state.day)))
        #expect(!events.contains { if case .categoryLost = $0 { true } else { false } })
        #expect(state.rivals.challenges.isEmpty, "a settled fight is over")
        #expect(state.rivals.rivals[0].strength == strengthBefore - depth.heldRivalStrengthLoss)
        // The week's retainer (+0.5) lands on the same day; the award is on top of it.
        let gained = state.market.standing(for: "fitness") - standingBefore
        #expect(gained >= depth.heldStandingGain && gained < depth.heldStandingGain + 1, "standing moved by \(gained)")
        #expect(!state.rivals.rivals[0].focusTopicIDs.contains("fitness"))
    }

    @Test func losingTheCategoryCostsStandingAndFeedsTheRival() throws {
        let depth = BalanceConfig.RivalBalance.DepthBalance.default
        let (state, events, rivalID, standingBefore, strengthBefore) = try Self.settle(score: 50, rivalQuality: 95)
        #expect(state.rivals.share(for: "fitness") < depth.challengeHoldShare)
        #expect(events.contains(.categoryLost(rivalID: rivalID, topicID: "fitness", day: state.day)))
        #expect(state.rivals.rivals[0].strength == strengthBefore + depth.lostRivalStrengthGain)
        let lost = standingBefore - state.market.standing(for: "fitness")
        #expect(lost > depth.lostStandingLoss - 1 && lost <= depth.lostStandingLoss, "standing moved by \(-lost)")
        // …and it keeps coming: the topic is on its list now.
        #expect(state.rivals.rivals[0].focusTopicIDs.contains("fitness"))
    }

    @Test func aCategoryWalkedOutOfMidFightIsLostNotHeldByDefault() throws {
        let (state, events, rivalID, _, _) = try Self.settle(score: 80, rivalQuality: 45) { state in
            // Delist the player's only product there before the settlement.
            if case .released(var info) = state.products[0].stage {
                info.offMarket = true
                state.products[0].stage = .released(info)
            }
        }
        #expect(state.rivals.playerShare["fitness"] == nil)
        #expect(events.contains(.categoryLost(rivalID: rivalID, topicID: "fitness", day: state.day)))
    }

    @Test func aFightSettlesEvenWhenTheRivalIsGone() throws {
        // The rival folded or was bought mid-fight: the player out-sold it
        // off the board, which is holding the category.
        let (state, events, rivalID, _, _) = try Self.settle(score: 80, rivalQuality: 45) { state in
            state.rivals.rivals = []
        }
        #expect(events.contains(.categoryHeld(rivalID: rivalID, topicID: "fitness", day: state.day)))
        #expect(state.rivals.challenges.isEmpty)
    }

    // MARK: - The answers

    /// A fight open in fitness with the player at 60 and a rival at 55,
    /// nothing in development, so every routed answer can land.
    private static func openFight(
        configure: (inout GameState, BalanceConfig) -> Void = { _, _ in }
    ) throws -> (GameState, BalanceConfig, UUID) {
        var balance = try Self.balance(rivals: 1)
        RivalFightFixtures.stillRivals(&balance)
        var state = GameState.newGame(companyName: "Acme", seed: 49, balance: balance)
        state.rivals.rivals = []
        let productID = RivalFightFixtures.addPlayerProduct(to: &state, topicID: "fitness", score: 60)
        let rivalID = RivalProductTests.addRival(
            to: &state, personality: .deepPockets, topicID: "fitness", productQuality: 55
        )
        state.market.standing["fitness"] = 60
        state.rivals.challenges = [CategoryChallenge(
            rivalID: rivalID, topicID: "fitness", productName: "Their Thing",
            quality: 55, startedDay: state.day, settlesDay: state.day + 42
        )]
        configure(&state, balance)
        return (state, balance, productID)
    }

    @Test func concedingClearsTheSheetButNotTheSettlement() throws {
        var (state, balance, _) = try Self.openFight()
        #expect(state.rivals.pendingChallenge != nil)
        let events = Reducer.apply(.concedeCategory, to: &state, balance: balance, content: Self.content)
        #expect(events.isEmpty)
        #expect(state.rivals.pendingChallenge == nil, "the sheet is still up")
        let fight = try #require(state.rivals.challenge(in: "fitness"))
        #expect(fight.conceded)
        #expect(fight.answeredDay == state.day)
        // Conceding twice is nothing.
        #expect(Reducer.apply(.concedeCategory, to: &state, balance: balance, content: Self.content).isEmpty)

        // Six weeks on, the fight still settles — on the numbers.
        var settled: [GameEvent] = []
        for _ in 0..<42 {
            settled.append(contentsOf: Reducer.tick(&state, balance: balance, content: Self.content))
        }
        #expect(settled.contains { if case .categoryHeld = $0 { true } else { false } })
        #expect(state.rivals.challenges.isEmpty)
    }

    @Test func aPriceCutRoutesToTheBestProductAndAnswers() throws {
        var (state, balance, productID) = try Self.openFight()
        let events = Reducer.apply(
            .defendCategory(topicID: "fitness", defense: .budgetPrice),
            to: &state, balance: balance, content: Self.content
        )
        #expect(events.contains(.priceChanged(productID: productID, tier: .budget, day: state.day)))
        guard case .released(let info) = state.products[0].stage else { return }
        #expect(info.priceTier == .budget)
        let fight = try #require(state.rivals.challenge(in: "fitness"))
        #expect(!fight.isPending)
        #expect(!fight.conceded)
        #expect(state.rivals.pendingChallenge == nil)

        // Already budget: nothing to route, and the fight stays as it was.
        let again = Reducer.apply(
            .defendCategory(topicID: "fitness", defense: .budgetPrice),
            to: &state, balance: balance, content: Self.content
        )
        #expect(again.isEmpty)
    }

    @Test func aPatchTakesTheBuildSlotOrLeavesTheQuestionOpen() throws {
        // With the one garage slot taken, the patch cannot start and the
        // challenge stays pending — the sheet must not close on nothing.
        var (busy, balance, productID) = try Self.openFight { state, balance in
            _ = Reducer.apply(
                .startProduct(typeID: "mobile_app", topicID: "music", name: "Next", focus: .balanced),
                to: &state, balance: balance, content: Self.content
            )
        }
        #expect(!busy.hasFreeDevSlot)
        let refused = Reducer.apply(
            .defendCategory(topicID: "fitness", defense: .patch),
            to: &busy, balance: balance, content: Self.content
        )
        #expect(refused.isEmpty)
        #expect(busy.economy.update(for: productID) == nil)
        #expect(busy.rivals.pendingChallenge != nil)

        // With the slot free, the patch starts and the question is answered.
        var (free, _, freeProductID) = try Self.openFight()
        _ = Reducer.apply(
            .defendCategory(topicID: "fitness", defense: .patch),
            to: &free, balance: balance, content: Self.content
        )
        #expect(free.economy.update(for: freeProductID) != nil)
        #expect(free.rivals.pendingChallenge == nil)
    }

    @Test func aCampaignCostsCashAndAnswers() throws {
        var (state, balance, productID) = try Self.openFight()
        let events = Reducer.apply(
            .defendCategory(topicID: "fitness", defense: .campaign),
            to: &state, balance: balance, content: Self.content
        )
        #expect(events.contains { if case .campaignStarted = $0 { true } else { false } })
        #expect(state.campaigns.contains { $0.productID == productID && $0.kindID == CampaignKind.socialPush.rawValue })
        #expect(state.rivals.pendingChallenge == nil)
    }

    @Test func aDefenceInATopicWithNoFightIsNothing() throws {
        var (state, balance, _) = try Self.openFight()
        let before = state
        let events = Reducer.apply(
            .defendCategory(topicID: "music", defense: .budgetPrice),
            to: &state, balance: balance, content: Self.content
        )
        #expect(events.isEmpty)
        #expect(state == before)
    }

    // MARK: - The strength bleed

    /// A player product scoring `score` in fitness against one rival
    /// product at `rivalQuality` there (and one somewhere the player is
    /// not), run for `weeks` with a still field so the bleed is the only
    /// thing moving strength.
    private static func bleed(
        score: Int,
        rivalQuality: Double,
        weeks: Int = 4,
        playerLive: Bool = true
    ) throws -> (state: GameState, strengthBefore: Double, standingBefore: Double) {
        var balance = try Self.balance(rivals: 1)
        RivalFightFixtures.stillRivals(&balance)
        balance.rivals.depth.strengthPerWeekBeaten = 1
        balance.rivals.depth.standingPerWeekBeaten = 1
        var state = GameState.newGame(companyName: "Acme", seed: 50, balance: balance)
        state.rivals.rivals = []
        if playerLive {
            RivalFightFixtures.addPlayerProduct(to: &state, topicID: "fitness", score: score)
        }
        _ = RivalProductTests.addRival(
            to: &state, personality: .deepPockets, topicID: "fitness", productQuality: rivalQuality
        )
        // A second shelf entry in a topic the player is not in: never bled.
        state.rivals.rivals[0].products.append(RivalProduct(
            id: UUID(), name: "Elsewhere", topicID: "music", typeID: "mobile_app",
            quality: 30, launchDay: 0, weeklyUnits: 10
        ))
        state.market.standing["fitness"] = 30
        let strengthBefore = state.rivals.rivals[0].strength
        let standingBefore = state.market.standing(for: "fitness")
        for _ in 0..<(weeks * GameState.daysPerWeek) {
            Reducer.tick(&state, balance: balance, content: Self.content)
        }
        return (state, strengthBefore, standingBefore)
    }

    @Test func anOutSoldRivalLosesAPointOfStrengthAWeek() throws {
        let (state, before, _) = try Self.bleed(score: 80, rivalQuality: 40, weeks: 4)
        #expect(state.rivals.share(for: "fitness") > 0.5)
        #expect(state.rivals.rivals[0].strength == before - 4)
    }

    @Test func anOutSoldPlayerLosesAPointOfStandingAWeek() throws {
        let (state, strengthBefore, standingBefore) = try Self.bleed(score: 40, rivalQuality: 80, weeks: 4)
        #expect(state.rivals.share(for: "fitness") < 0.5)
        #expect(state.rivals.rivals[0].strength == strengthBefore)
        // Four weeks of the retainer (+0.5) against four of the bleed (−1).
        #expect(abs(state.market.standing(for: "fitness") - (standingBefore + 4 * 0.5 - 4)) < 1e-9)
    }

    @Test func anEvenSplitCostsNobody() throws {
        let (state, strengthBefore, standingBefore) = try Self.bleed(score: 60, rivalQuality: 60, weeks: 4)
        #expect(state.rivals.share(for: "fitness") == 0.5)
        #expect(state.rivals.rivals[0].strength == strengthBefore)
        #expect(abs(state.market.standing(for: "fitness") - (standingBefore + 4 * 0.5)) < 1e-9)
    }

    @Test func aTopicThePlayerIsNotInBleedsNobody() throws {
        // The rival sells in music and fitness; the player has nothing
        // anywhere. No share entry, no bleed — the same guard as the war fix.
        let (state, strengthBefore, _) = try Self.bleed(score: 0, rivalQuality: 40, weeks: 4, playerLive: false)
        #expect(state.rivals.playerShare.isEmpty)
        #expect(state.rivals.rivals[0].strength == strengthBefore)
    }

    @Test func sixMonthsOfBeingOutSoldTakesTwentyFivePoints() throws {
        // A product competes for `relevanceWeeks` (26) and fades on the
        // 26th evolve day before the bleed runs, so six months of being
        // out-sold is 25 points — a mid-range founding lands at the fold
        // line. (The fold itself is `evolve`'s; the deep-pockets studio
        // here takes the beating and stays. Fold rates over seeds are
        // measured in `RivalFightBotTests`.)
        let (state, before, _) = try Self.bleed(score: 85, rivalQuality: 40, weeks: 26)
        #expect(before == 50)
        #expect(state.rivals.rivals[0].strength == before - 25)
        #expect(state.rivals.rivals[0].competingProducts(on: state.day).isEmpty)
    }

    // MARK: - Save compatibility

    @Test func challengesRoundTripAndOldSavesDecodeWithNone() throws {
        var rivals = RivalsState.empty
        let rivalID = UUID()
        rivals.challenges = [CategoryChallenge(
            rivalID: rivalID, topicID: "fitness", productName: "Kite Notes",
            quality: 58, startedDay: 100, settlesDay: 142, answeredDay: 101, conceded: true
        )]
        rivals.lastChallengeDay = ["music": 40, "fitness": 100]
        rivals.incumbentFoundedDay = 300
        rivals.incumbentHeldSinceDay = 310
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(rivals)
        let decoded = try JSONDecoder().decode(RivalsState.self, from: data)
        #expect(decoded == rivals)
        #expect(decoded.pendingChallenge == nil)
        #expect(decoded.challenge(in: "fitness")?.conceded == true)

        // Stable order for the cooldown table.
        var object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let days = try #require(object["lastChallengeDay"] as? [[String: Any]])
        #expect(days.compactMap { $0["topicID"] as? String } == ["fitness", "music"])

        // A save from before the fight existed.
        for key in ["challenges", "lastChallengeDay", "incumbentFoundedDay", "incumbentHeldSinceDay"] {
            object.removeValue(forKey: key)
        }
        let legacy = try JSONDecoder().decode(
            RivalsState.self, from: try JSONSerialization.data(withJSONObject: object)
        )
        #expect(legacy.challenges.isEmpty)
        #expect(legacy.lastChallengeDay.isEmpty)
        #expect(legacy.incumbentFoundedDay == nil)
        #expect(legacy.incumbentHeldSinceDay == nil)
        #expect(legacy.pendingChallenge == nil)

        // …and a rival from before the incumbent.
        let rival = try JSONDecoder().decode(Rival.self, from: Data("""
        {"id": "11111111-2222-3333-4444-555555555555", "name": "Old", "strength": 42,
         "reputation": 30, "focusTopicIDs": ["fitness"], "foundedDay": 3, "appearanceSeed": 99}
        """.utf8))
        #expect(!rival.isIncumbent)
    }
}


/// Shared fixtures for the WS-A suites: a player product on the market at
/// a chosen score, in a chosen topic, and a field that holds still.
enum RivalFightFixtures {
    /// Rivals that neither drift, ship, stumble nor bleed, so a test about
    /// one settlement's numbers is about that settlement alone.
    static func stillRivals(_ balance: inout BalanceConfig) {
        balance.rivals.strengthDriftSigma = 0
        balance.rivals.shipChance = 0
        balance.rivals.stumbleChance = 0
        balance.rivals.depth.strengthPerWeekBeaten = 0
        balance.rivals.depth.standingPerWeekBeaten = 0
        balance.rivals.depth.incumbentEnabled = false
    }

    @discardableResult
    static func addPlayerProduct(
        to state: inout GameState,
        topicID: String,
        score: Int,
        launchDay: Int = 0,
        tier: PriceTier = .standard,
        name: String = "Player Thing"
    ) -> UUID {
        let id = UUID()
        let reviews = (0..<4).map { index in
            Review(outlet: "Outlet \(index)", score: score, blurb: "b")
        }
        state.products.append(Product(
            id: id,
            name: name,
            typeID: "mobile_app",
            topicID: topicID,
            stage: .released(ReleaseInfo(
                launchDay: launchDay,
                quality: Double(score),
                reviews: reviews,
                weeklySales: [],
                offMarket: false,
                priceTier: tier
            ))
        ))
        return id
    }
}
