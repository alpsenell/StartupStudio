import Foundation
import Testing
import TycoonContent
@testable import TycoonEngine

/// The Incumbent (iteration 5, WS-A): the late-game antagonist, founded
/// into the player's two best markets once the company is worth having,
/// beatable by holding both for half a year, and — as of this lane —
/// buyable for its shelf.
@Suite("The incumbent")
struct IncumbentTests {
    private static let content = TestContent.bundled

    /// Rivals on, the field still (no drift, rolls or bleed), so the
    /// incumbent is the only thing that arrives.
    private static func balance(rivals: Int = 4, enabled: Bool = true) throws -> BalanceConfig {
        var balance = try BalanceConfig.loadBundled()
        balance.rivals.rivalCount = rivals
        RivalFightFixtures.stillRivals(&balance)
        balance.rivals.depth.incumbentEnabled = enabled
        return balance
    }

    /// A studio with two live products — fitness held at 80, music at 60,
    /// travel at 90 but delisted — and `cash` in the bank. Ticked to the
    /// first weekly pass.
    private static func company(
        cash: Int,
        balance: BalanceConfig,
        share: [String: Double] = [:],
        fitnessScore: Int = 70
    ) -> (state: GameState, events: [GameEvent]) {
        var state = GameState.newGame(companyName: "Acme", seed: 51, balance: balance)
        RivalFightFixtures.addPlayerProduct(to: &state, topicID: "fitness", score: fitnessScore, name: "Stride")
        RivalFightFixtures.addPlayerProduct(to: &state, topicID: "music", score: 65, name: "Chord")
        let delisted = RivalFightFixtures.addPlayerProduct(to: &state, topicID: "travel", score: 80, name: "Gone")
        if let index = state.products.firstIndex(where: { $0.id == delisted }),
           case .released(var info) = state.products[index].stage {
            info.offMarket = true
            state.products[index].stage = .released(info)
        }
        state.market.standing["fitness"] = 80
        state.market.standing["music"] = 60
        state.market.standing["travel"] = 90
        state.company.cash = cash
        state.rivals.playerShare = share
        var events: [GameEvent] = []
        for _ in 0..<balance.rivals.evolveIntervalDays {
            events.append(contentsOf: Reducer.tick(&state, balance: balance, content: Self.content))
        }
        return (state, events)
    }

    private static func arrival(in events: [GameEvent]) -> UUID? {
        for event in events {
            if case let .incumbentArrived(rivalID, _, _) = event { return rivalID }
        }
        return nil
    }

    // MARK: - Arrival

    @Test func crossingTheValuationFloorBringsAGiantIntoYourBestLiveMarkets() throws {
        let balance = try Self.balance()
        let depth = balance.rivals.depth
        let (state, events) = Self.company(cash: 1_100_000, balance: balance)
        #expect(state.companyValuation(balance: balance) >= depth.incumbentValuationFloor)

        let rivalID = try #require(Self.arrival(in: events), "no incumbent arrived")
        let incumbent = try #require(state.rivals.incumbent)
        #expect(incumbent.id == rivalID)
        #expect(incumbent.isIncumbent)
        #expect(incumbent.personality == .deepPockets)
        #expect(!incumbent.name.isEmpty)
        // 0.6 × 1.1M / 4000 = 165, clamped to the band's top.
        #expect(incumbent.strength == depth.incumbentStrengthMax)
        #expect(incumbent.reputation >= depth.incumbentReputationMin)
        #expect(incumbent.reputation <= depth.incumbentReputationMax)
        // The two highest-standing topics with something live: travel is
        // higher but delisted, so fitness then music.
        #expect(incumbent.focusTopicIDs == ["fitness", "music"])
        // It joins the field above the floor rather than taking a slot.
        #expect(state.rivals.rivals.count == balance.rivals.rivalCount + 1)
        #expect(state.rivals.incumbentFoundedDay == state.day)
        #expect(state.rivals.incumbentHeldSinceDay == nil)

        // It opens in the higher — a product on its shelf and a challenge
        // on the clock, whatever the quality window says.
        #expect(incumbent.products.count == 1)
        #expect(incumbent.products[0].topicID == "fitness")
        let challenge = try #require(state.rivals.challenge(in: "fitness"))
        #expect(challenge.rivalID == rivalID)
        #expect(challenge.productName == incumbent.products[0].name)
        #expect(events.contains { if case .categoryChallenged(rivalID, "fitness", _, _, _, _) = $0 { true } else { false } })
        #expect(events.contains { if case .rivalProductLaunched(rivalID, _, "fitness", _, _) = $0 { true } else { false } })
        #expect(state.rivals.pendingChallenge?.rivalID == rivalID)
        // Worth what the strategic buyout needs a buyer to be worth.
        #expect(incumbent.valuation(balance: balance) >= 400_000)
    }

    /// The second trigger — owned topics — ships off: two owned topics is
    /// not a size (see `DepthBalance`). Switched on, it brings the giant
    /// to a poor but dominant studio.
    @Test func owningTopicsOutrightBringsItOnlyWhereThatTriggerIsOn() throws {
        let shipped = try Self.balance()
        #expect(shipped.rivals.depth.incumbentDominatedTopics == 0)
        // Poor but dominant: the share table from last week says two
        // contested topics are owned.
        let (quiet, quietEvents) = Self.company(
            cash: 20_000, balance: shipped, share: ["fitness": 0.8, "music": 0.7]
        )
        #expect(quiet.companyValuation(balance: shipped) < shipped.rivals.depth.incumbentValuationFloor)
        #expect(Self.arrival(in: quietEvents) == nil)
        #expect(quiet.rivals.incumbent == nil)

        var designed = shipped
        designed.rivals.depth.incumbentDominatedTopics = 2
        let (state, events) = Self.company(
            cash: 20_000, balance: designed, share: ["fitness": 0.8, "music": 0.7]
        )
        #expect(Self.arrival(in: events) != nil)
        #expect(state.rivals.incumbent != nil)
    }

    @Test func nothingArrivesBelowTheLine() throws {
        let balance = try Self.balance()
        let (state, events) = Self.company(cash: 20_000, balance: balance, share: ["fitness": 0.8])
        #expect(Self.arrival(in: events) == nil)
        #expect(state.rivals.incumbent == nil)
        #expect(state.rivals.incumbentFoundedDay == nil)
        #expect(state.rivals.rivals.count == balance.rivals.rivalCount)
    }

    @Test func theFlagIsTheWholeOfIt() throws {
        let off = try Self.balance(enabled: false)
        let (state, events) = Self.company(cash: 1_100_000, balance: off)
        #expect(Self.arrival(in: events) == nil)
        #expect(state.rivals.incumbent == nil)
        #expect(state.rivals.challenges.isEmpty)
    }

    /// The pacing suite's world: no field for a giant to join, so a
    /// company worth a million draws nothing and meets nobody, whatever
    /// the flag says.
    @Test func noIncumbentEverJoinsAnEmptyField() throws {
        let on = try Self.balance(rivals: 0, enabled: true)
        let off = try Self.balance(rivals: 0, enabled: false)
        let (withFlag, eventsOn) = Self.company(cash: 1_200_000, balance: on)
        let (withoutFlag, _) = Self.company(cash: 1_200_000, balance: off)
        #expect(Self.arrival(in: eventsOn) == nil)
        #expect(withFlag.rivals.rivals.isEmpty)
        // The fixture's product ids are fresh each time, so compare the
        // parts the flag could have moved: the world stream, the field,
        // the books.
        #expect(withFlag.worldRNG == withoutFlag.worldRNG, "the flag drew from the world stream")
        #expect(withFlag.rivals == withoutFlag.rivals)
        #expect(withFlag.company == withoutFlag.company)
        #expect(withFlag.market.standing == withoutFlag.market.standing)
    }

    @Test func onePerRun() throws {
        let balance = try Self.balance()
        var (state, events) = Self.company(cash: 1_100_000, balance: balance)
        let first = try #require(Self.arrival(in: events))
        // Gone — bought, say — and the company still worth having.
        state.rivals.rivals.removeAll { $0.id == first }
        var later: [GameEvent] = []
        for _ in 0..<(4 * GameState.daysPerWeek) {
            later.append(contentsOf: Reducer.tick(&state, balance: balance, content: Self.content))
        }
        #expect(Self.arrival(in: later) == nil)
        #expect(state.rivals.incumbent == nil)
        #expect(state.rivals.incumbentFoundedDay != nil)
    }

    @Test func aCompanyWithNothingLiveIsNotWorthFighting() throws {
        let balance = try Self.balance()
        var state = GameState.newGame(companyName: "Acme", seed: 52, balance: balance)
        state.company.cash = 1_200_000
        var events: [GameEvent] = []
        for _ in 0..<balance.rivals.evolveIntervalDays {
            events.append(contentsOf: Reducer.tick(&state, balance: balance, content: Self.content))
        }
        #expect(Self.arrival(in: events) == nil)
        #expect(state.rivals.incumbentFoundedDay == nil)
    }

    // MARK: - The retreat

    /// An incumbent — the whole field, so nothing else launches or clones
    /// — on the board in fitness and music with products of
    /// `fitnessQuality` and `musicQuality`, against the player's 80 and
    /// 65. The player's products never delist (a static fixture's sales
    /// decay below the delist line inside half a year) and the
    /// incumbent's launch on day `launchDay`, so both sides are still
    /// competing when the clock matures.
    private static func standoff(
        fitnessQuality: Double,
        musicQuality: Double,
        weeks: Int,
        retreatWeeks: Int = 26,
        launchDay: Int = 60
    ) throws -> (state: GameState, events: [GameEvent], id: UUID) {
        var balance = try Self.balance(rivals: 1)
        balance.rivals.depth.incumbentRetreatWeeks = retreatWeeks
        balance.delistFraction = 0
        var state = GameState.newGame(companyName: "Acme", seed: 53, balance: balance)
        RivalFightFixtures.addPlayerProduct(to: &state, topicID: "fitness", score: 80)
        RivalFightFixtures.addPlayerProduct(to: &state, topicID: "music", score: 65)
        state.market.standing["fitness"] = 80
        state.market.standing["music"] = 60
        let id = UUID()
        state.rivals.rivals = [Rival(
            id: id, name: "Meridian Works", strength: 90, reputation: 70,
            focusTopicIDs: ["fitness", "music"], foundedDay: 0, appearanceSeed: 9,
            products: [
                RivalProduct(id: UUID(), name: "Their Fitness", topicID: "fitness", typeID: "mobile_app",
                             quality: fitnessQuality, launchDay: launchDay, weeklyUnits: 500),
                RivalProduct(id: UUID(), name: "Their Music", topicID: "music", typeID: "mobile_app",
                             quality: musicQuality, launchDay: launchDay, weeklyUnits: 500),
            ],
            personality: .deepPockets, isIncumbent: true
        )]
        state.rivals.incumbentFoundedDay = 0
        var events: [GameEvent] = []
        for _ in 0..<(weeks * GameState.daysPerWeek) {
            events.append(contentsOf: Reducer.tick(&state, balance: balance, content: Self.content))
        }
        return (state, events, id)
    }

    @Test func holdingBothItsMarketsForHalfAYearMakesItRetreat() throws {
        let depth = try Self.balance().rivals.depth
        // Weak products: the player holds both from the first pass, so the
        // clock starts on week 1 and runs out on week 27. The control is
        // the same run with the retreat out of reach, so the seed's
        // company events cancel and the award is measured exactly.
        let (state, events, id) = try Self.standoff(fitnessQuality: 40, musicQuality: 40, weeks: 27)
        let (control, controlEvents, _) = try Self.standoff(
            fitnessQuality: 40, musicQuality: 40, weeks: 27, retreatWeeks: 1_000
        )
        #expect(events.contains(.incumbentRetreated(rivalID: id, name: "Meridian Works", day: 27 * 7)))
        #expect(!controlEvents.contains { if case .incumbentRetreated = $0 { true } else { false } })

        let rival = try #require(state.rivals.rival(id: id), "the retreated giant should stay on the board")
        #expect(!rival.isIncumbent)
        #expect(rival.focusTopicIDs.isEmpty)
        #expect(rival.products.isEmpty, "its products in the player's topics go with it")
        #expect(state.rivals.incumbent == nil)
        #expect(state.rivals.incumbentHeldSinceDay == nil)
        #expect(control.rivals.incumbentHeldSinceDay == 7)
        #expect(state.company.reputation == control.company.reputation + depth.incumbentRetreatReputationGain)
        // Fitness was already near the top of the ledger; the award clamps.
        let maxStanding = try Self.balance().market.standing.maxStanding
        #expect(
            abs(state.market.standing(for: "fitness")
                - min(maxStanding, control.market.standing(for: "fitness") + depth.incumbentRetreatStandingGain)) < 1e-9
        )
        #expect(
            abs(state.market.standing(for: "music")
                - (control.market.standing(for: "music") + depth.incumbentRetreatStandingGain)) < 1e-9
        )
        // And the topics are the whole market again.
        #expect(state.rivals.share(for: "fitness") == 1.0)
        #expect(control.rivals.share(for: "fitness") < 1.0)
    }

    @Test func theClockRunsOnlyWhileBothAreHeld() throws {
        let balance = try Self.balance()
        // A 95 against the player's 65 in music: never held there, so the
        // clock never starts, however long fitness is held. (Checked
        // before the products fade: a faded product contests nothing.)
        let (state, events, id) = try Self.standoff(fitnessQuality: 40, musicQuality: 95, weeks: 20)
        #expect(!events.contains { if case .incumbentRetreated = $0 { true } else { false } })
        #expect(state.rivals.share(for: "fitness") >= balance.rivals.depth.challengeHoldShare)
        #expect(state.rivals.share(for: "music") < balance.rivals.depth.challengeHoldShare)
        #expect(state.rivals.incumbentHeldSinceDay == nil)
        #expect(state.rivals.rival(id: id)?.isIncumbent == true)

        // Holding both starts it on the first weekly pass.
        let (held, _, _) = try Self.standoff(fitnessQuality: 40, musicQuality: 40, weeks: 4)
        #expect(held.rivals.incumbentHeldSinceDay == 7)
    }

    // MARK: - Acquisition buys the shelf

    /// A rich, dominant studio selling in fitness (a 60), music (a 50) and
    /// travel (a 70), and a small rival with: two products beating it — a
    /// 72 in fitness, a 55 in music — a second, weaker fitness app, a 40
    /// in travel that is worse than the player's, an 80 in dating where
    /// the player has nothing, and one long faded.
    private static func buyable() throws -> (state: GameState, balance: BalanceConfig, rivalID: UUID) {
        var balance = try Self.balance(rivals: 1)
        balance.delistFraction = 0
        var state = GameState.newGame(companyName: "Acme", seed: 54, balance: balance)
        state.company.cash = 300_000
        RivalFightFixtures.addPlayerProduct(to: &state, topicID: "fitness", score: 60, name: "Stride")
        RivalFightFixtures.addPlayerProduct(to: &state, topicID: "music", score: 50, name: "Chord")
        RivalFightFixtures.addPlayerProduct(to: &state, topicID: "travel", score: 70, name: "Wander")
        let rivalID = UUID()
        state.rivals.rivals = [Rival(
            id: rivalID, name: "Halcyon Systems", strength: 20, reputation: 20,
            focusTopicIDs: ["fitness", "music"], foundedDay: 0, appearanceSeed: 3,
            products: [
                RivalProduct(id: UUID(), name: "Kite Notes", topicID: "fitness", typeID: "mobile_app",
                             quality: 72, launchDay: 10, weeklyUnits: 300),
                RivalProduct(id: UUID(), name: "Kite Lite", topicID: "fitness", typeID: "mobile_app",
                             quality: 65, launchDay: 12, weeklyUnits: 100),
                RivalProduct(id: UUID(), name: "Orbit Deck", topicID: "music", typeID: "mobile_app",
                             quality: 55, launchDay: 20, weeklyUnits: 200),
                RivalProduct(id: UUID(), name: "Lesser Trip", topicID: "travel", typeID: "mobile_app",
                             quality: 40, launchDay: 18, weeklyUnits: 50),
                RivalProduct(id: UUID(), name: "Side Bet", topicID: "dating", typeID: "mobile_app",
                             quality: 80, launchDay: 15, weeklyUnits: 200),
                RivalProduct(id: UUID(), name: "Old Lantern", topicID: "fitness", typeID: "mobile_app",
                             quality: 90, launchDay: -400, weeklyUnits: 0),
            ],
            personality: .copycat
        )]
        // A week on the market so the shelf is contested and the numbers
        // are the live ones.
        for _ in 0..<GameState.daysPerWeek {
            Reducer.tick(&state, balance: balance, content: Self.content)
        }
        state.day = 30
        return (state, balance, rivalID)
    }

    @Test func buyingARivalAbsorbsWhatItIsSelling() throws {
        var (state, balance, rivalID) = try Self.buyable()
        let before = state.products.count
        let events = Reducer.apply(
            .acquireRival(rivalID: rivalID), to: &state, balance: balance, content: Self.content
        )
        #expect(events.contains { if case .rivalAcquired(rivalID, _, _, _) = $0 { true } else { false } },
                "the acquisition was refused, so this proves nothing")
        #expect(state.rivals.rival(id: rivalID) == nil)

        let absorbed = state.products.suffix(from: before)
        #expect(
            absorbed.count == 2,
            "only the best product beating the player's in each category comes; the rest stay behind"
        )
        #expect(absorbed.map(\.name) == ["Kite Notes", "Orbit Deck"])
        #expect(absorbed.map(\.topicID) == ["fitness", "music"])
        for (product, quality) in zip(absorbed, [72.0, 55.0]) {
            guard case .released(let info) = product.stage else {
                Issue.record("\(product.name) was not absorbed as released")
                continue
            }
            #expect(!info.offMarket)
            #expect(info.quality == quality)
            #expect(info.reviews.count == balance.reviewOutlets.count)
            #expect(abs(Double(info.averageReviewScore) - quality) <= 3, "\(product.name) reviews at \(info.averageReviewScore) against a \(quality)")
            #expect(info.reviews.allSatisfy { !$0.blurb.isEmpty })
            #expect(Set(info.reviews.map(\.outlet)) == Set(balance.reviewOutlets))
            #expect(info.priceTier == .standard)
            #expect(!info.isSubscription)
        }
        for left in ["Kite Lite", "Lesser Trip", "Side Bet", "Old Lantern"] {
            #expect(
                !state.products.contains { $0.name == left },
                Comment(rawValue: "\(left) should have stayed behind")
            )
        }
    }

    @Test func anAbsorbedShelfSellsAndHoldsItsTopics() throws {
        var (state, balance, rivalID) = try Self.buyable()
        _ = Reducer.apply(.acquireRival(rivalID: rivalID), to: &state, balance: balance, content: Self.content)
        // The field re-founds a fresh minnow; whatever it does, the topics
        // the shelf came with are the player's whole market next week.
        for _ in 0..<GameState.daysPerWeek {
            Reducer.tick(&state, balance: balance, content: Self.content)
        }
        for name in ["Kite Notes", "Orbit Deck"] {
            let product = try #require(state.products.first { $0.name == name })
            guard case .released(let info) = product.stage else { continue }
            #expect(!info.weeklySales.isEmpty, "\(name) posted no sales")
            #expect(info.weeklySales.last?.revenue ?? 0 > 0)
        }
        #expect(state.rivals.share(for: "fitness") == 1.0)
        #expect(state.rivals.share(for: "music") == 1.0)
        #expect(state.market.standing(for: "fitness") > 0)
    }

    @Test func aRefusedAcquisitionAbsorbsNothing() throws {
        var (state, balance, rivalID) = try Self.buyable()
        state.company.cash = 0
        let before = state
        #expect(Reducer.apply(.acquireRival(rivalID: rivalID), to: &state, balance: balance, content: Self.content).isEmpty)
        #expect(state == before)
    }
}
