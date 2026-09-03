import Foundation
import Testing
import TycoonContent
@testable import TycoonEngine

/// The four founding origins (WS-H, iteration 5): a garage is the game that
/// shipped, byte for byte; every other origin is a different day 0 under
/// the same rules, deterministic from the seed and never a draw.
@Suite("Origins")
struct OriginTests {
    static func balance() throws -> BalanceConfig {
        var balance = try BalanceConfig.loadBundled()
        balance.rivals.rivalCount = 0
        return balance
    }

    static let content = TestContent.bundled

    static func newGame(
        _ origin: FoundingOrigin,
        seed: UInt64 = 4_242,
        founder: FounderProfile = .default,
        companyName: String = "Origins Ltd"
    ) throws -> GameState {
        GameState.newGame(
            companyName: companyName, seed: seed, balance: try balance(),
            founder: founder, origin: origin, content: content
        )
    }

    static func tick(_ state: inout GameState, days: Int) throws -> [GameEvent] {
        let balance = try balance()
        var events: [GameEvent] = []
        for _ in 0..<days {
            events.append(contentsOf: Reducer.tick(&state, balance: balance, content: content))
        }
        return events
    }

    static func sortedJSON(_ state: GameState) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(state)
    }

    static func fixture(_ name: String) throws -> Data {
        let url = try #require(
            Bundle.module.url(forResource: name, withExtension: "json"),
            "the \(name) fixture is missing from the test bundle"
        )
        return try Data(contentsOf: url)
    }

    // MARK: - The garage is the game that shipped

    /// `Fixtures/scaffold5-garage-*.json` were written by the `scaffold-5`
    /// tag — before this lane existed — with the same setup as below
    /// (bundled balance, rivals off, sorted keys). A garage on this branch
    /// must produce the same bytes on day 0 and after a month of play:
    /// every field, every stream position, nothing added to the wire.
    @Test(arguments: [
        ("scaffold5-garage-day0-4242", UInt64(4_242), 0),
        ("scaffold5-garage-day30-4242", UInt64(4_242), 30),
        ("scaffold5-garage-day30-77", UInt64(77), 30),
    ])
    func aGarageIsByteIdenticalToTheScaffold(name: String, seed: UInt64, days: Int) throws {
        var state = GameState.newGame(companyName: "Garage Ref", seed: seed, balance: try Self.balance())
        _ = try Self.tick(&state, days: days)

        let reference = try Self.fixture(name)
        #expect(try Self.sortedJSON(state) == reference, "\(name): the garage moved")
        // And the scaffold's save reads back as exactly this state.
        let decoded = try JSONDecoder().decode(GameState.self, from: reference)
        #expect(decoded == state)
        #expect(decoded.origin == .garage)
    }

    @Test func aGarageAppliesNoDelta() throws {
        let balance = try Self.balance()
        let explicit = try Self.newGame(.garage)
        let implicit = GameState.newGame(companyName: "Origins Ltd", seed: 4_242, balance: balance)
        #expect(explicit == implicit)

        #expect(explicit.employees.count == 1)
        #expect(explicit.cofounder == nil)
        #expect(explicit.activeContracts.isEmpty)
        #expect(explicit.lockedTopics.isEmpty)
        #expect(explicit.investors.equityRemaining == 100)
        #expect(explicit.life.home == .studioFlat)
        #expect(explicit.loanBalance == 0)
        #expect(explicit.economy.guaranteedLoanAmount == 0)
        #expect(explicit.company.cash == balance.startingCash)
        #expect(explicit.company.reputation == 10)
        #expect(explicit.ledger.entries.isEmpty)
    }

    /// An origin is deltas only: the four streams sit exactly where the
    /// garage left them, so nothing an origin invents is a draw.
    @Test(arguments: FoundingOrigin.allCases)
    func noOriginMovesTheStreams(origin: FoundingOrigin) throws {
        let garage = try Self.newGame(.garage)
        let state = try Self.newGame(origin)
        #expect(state.rng == garage.rng)
        #expect(state.worldRNG == garage.worldRNG)
        #expect(state.investorRNG == garage.investorRNG)
        #expect(state.socialRNG == garage.socialRNG)
        #expect(state.origin == origin)
    }

    @Test(arguments: FoundingOrigin.allCases)
    func theSameSeedAndOriginGiveTheSameFirstMonth(origin: FoundingOrigin) throws {
        var a = try Self.newGame(origin, seed: 77)
        var b = try Self.newGame(origin, seed: 77)
        _ = try Self.tick(&a, days: 28)
        _ = try Self.tick(&b, days: 28)
        #expect(a == b)
        #expect(a.eventLog == b.eventLog)
        #expect(a.candidatePool.map(\.name) == b.candidatePool.map(\.name))
    }

    @Test(arguments: [FoundingOrigin.cofounded, .spinOut, .mortgaged])
    func everyOtherOriginIsADifferentDayZero(origin: FoundingOrigin) throws {
        let garage = try Self.newGame(.garage)
        let state = try Self.newGame(origin)
        #expect(state != garage)
    }

    // MARK: - Day 0, per origin

    @Test func aCofoundedCompanyHasTwoPeopleAndSeventyPercent() throws {
        let balance = try Self.balance()
        let state = try Self.newGame(.cofounded)
        let config = balance.origins

        #expect(state.employees.count == 2)
        let cofounder = try #require(state.cofounder)
        #expect(cofounder.isCofounder)
        #expect(!cofounder.isFounder)
        #expect(cofounder.skills == config.cofounderSkills)
        #expect(cofounder.skills.coding == 40 && cofounder.skills.design == 40 && cofounder.skills.marketing == 40)
        #expect(cofounder.weeklySalary == 0)
        #expect(cofounder.hiredDay == 0)
        #expect(cofounder.level == .mid)
        #expect(cofounder.assignment == .idle)
        #expect(cofounder.founderBond == config.cofounderBond)
        #expect(cofounder.loyalty == config.cofounderLoyalty)
        #expect(cofounder.traits.count == TraitEffects.traitsPerEmployee)
        #expect(cofounder.name != "Your co-founder", "the name comes from the catalog's pools")
        #expect(state.investors.equityRemaining == 70)
        #expect(state.investors.rounds.isEmpty, "the co-founder is not a round")
        #expect(state.investors.boardExpectation == nil)
        // Everything else is the garage.
        #expect(state.company.cash == balance.startingCash)
        #expect(state.company.reputation == 10)
        #expect(state.activeContracts.isEmpty)
        #expect(state.lockedTopics.isEmpty)
    }

    /// The co-founder's face, id and name are derived from the seed the
    /// way `worldRNG` is: the same seed founds the same company every
    /// time, and a different seed founds a different one.
    @Test func theCofounderIsDerivedFromTheSeedNotDrawn() throws {
        let a = try Self.newGame(.cofounded, seed: 4_242)
        let b = try Self.newGame(.cofounded, seed: 4_242)
        let c = try Self.newGame(.cofounded, seed: 31_415)
        let ca = try #require(a.cofounder), cb = try #require(b.cofounder), cc = try #require(c.cofounder)

        #expect(ca == cb)
        #expect(ca.appearanceSeed == GameState.originSeed(for: 4_242))
        #expect(ca.traits == TraitEffects.derivedTraitIDs(appearanceSeed: ca.appearanceSeed))
        #expect(ca.id != cc.id)
        #expect(ca.appearanceSeed != cc.appearanceSeed)
    }

    @Test(arguments: [
        (FounderArchetype.hacker, EmployeeRole.designer),
        (.designer, .backend),
        (.hustler, .frontend),
    ])
    func theCofounderCoversWhatTheFounderIsNot(archetype: FounderArchetype, role: EmployeeRole) throws {
        let founder = FounderProfile(name: "Mira", archetype: archetype, appearanceSeed: 0x5EED)
        let state = try Self.newGame(.cofounded, founder: founder)
        #expect(try #require(state.cofounder).role == role)
    }

    @Test func aSpinOutStartsWithAClientAReputationAndANonCompete() throws {
        let balance = try Self.balance()
        let config = balance.origins
        let state = try Self.newGame(.spinOut)

        #expect(state.employees.count == 1)
        let job = try #require(state.activeContracts.first)
        #expect(state.activeContracts.count == 1)
        #expect(job.payout == 9_000)
        #expect(job.deadlineDay == 84)
        #expect(job.acceptedDay == 0)
        #expect(job.requiredCodePts + job.requiredDesignPts == config.spinOutContractPoints)
        #expect(job.requiredCodePts == 65 && job.requiredDesignPts == 35)
        #expect(job.penalty == Int((balance.contractPenaltyFraction * 9_000).rounded()))
        #expect(job.requiredSkill == config.spinOutContractRequiredSkill)
        #expect(job.progressCode == 0 && job.progressDesign == 0)
        #expect(Self.content.names.clientCompanies.contains(job.clientName))
        #expect(state.company.reputation == 15)
        #expect(state.company.cash == balance.startingCash)

        #expect(state.lockedTopics.count == 1)
        let (topic, unlockDay) = try #require(state.lockedTopics.first)
        #expect(Self.content.topic(topic) != nil, "the non-compete names a real topic")
        #expect(unlockDay == 52 * 7)
        #expect(state.isTopicLocked(topic))
        #expect(state.topicUnlockDay(topic) == 364)
        #expect(state.investors.equityRemaining == 100)
    }

    @Test func theSpinOutClientAndTopicFollowTheSeed() throws {
        let a = try Self.newGame(.spinOut, seed: 4_242)
        let b = try Self.newGame(.spinOut, seed: 4_242)
        #expect(a.activeContracts == b.activeContracts)
        #expect(a.lockedTopics == b.lockedTopics)
        // Over a handful of seeds the pick moves — it is a pick, not a
        // constant.
        let topics = Set(try [UInt64(1), 2, 3, 4, 5, 6, 7, 8].map {
            try #require(try Self.newGame(.spinOut, seed: $0).lockedTopics.keys.first)
        })
        #expect(topics.count > 1)
    }

    @Test func theNonCompeteRefusesUntilTheDayAndUnlocksOnIt() throws {
        let balance = try Self.balance()
        var state = try Self.newGame(.spinOut)
        // A studio that builds nothing for a year goes under in six
        // months; a founding grant keeps the clock running to day 364.
        state.company.cash += 1_000_000
        let locked = try #require(state.lockedTopics.keys.first)
        let open = try #require(Self.content.topics.first { $0.id != locked }).id
        let type = try #require(Self.content.productTypes.first {
            state.isProductTypeUnlocked($0.id, content: Self.content)
        }).id

        // Day 0: the locked topic is refused, any other is not.
        let refused = Reducer.apply(
            .startProduct(typeID: type, topicID: locked, name: "Nope", focus: .balanced),
            to: &state, balance: balance, content: Self.content
        )
        #expect(refused.isEmpty)
        #expect(state.products.isEmpty)
        var probe = state
        let allowed = Reducer.apply(
            .startProduct(typeID: type, topicID: open, name: "Fine", focus: .balanced),
            to: &probe, balance: balance, content: Self.content
        )
        #expect(!allowed.isEmpty)

        // On a codebase too: the same guard sits under both actions.
        let onCodebase = Reducer.apply(
            .startProductOnCodebase(typeID: type, topicID: locked, name: "Nope", focus: .balanced, codebaseID: type),
            to: &state, balance: balance, content: Self.content
        )
        #expect(onCodebase.isEmpty)

        // The day before the lock ends: still refused.
        _ = try Self.tick(&state, days: 363)
        #expect(state.day == 363)
        #expect(state.isTopicLocked(locked))
        #expect(Reducer.apply(
            .startProduct(typeID: type, topicID: locked, name: "Nope", focus: .balanced),
            to: &state, balance: balance, content: Self.content
        ).isEmpty)

        // Day 364: open.
        _ = try Self.tick(&state, days: 1)
        #expect(state.day == 364)
        #expect(!state.isTopicLocked(locked))
        #expect(state.topicUnlockDay(locked) == nil)
        let started = Reducer.apply(
            .startProduct(typeID: type, topicID: locked, name: "Finally", focus: .balanced),
            to: &state, balance: balance, content: Self.content
        )
        #expect(!started.isEmpty)
        #expect(state.products.first?.topicID == locked)
    }

    /// The day-0 contract is a `ContractJob` like any other, so
    /// `ContractSystem` settles it the same way — paid when the pools
    /// clear, penalised the day after the deadline.
    @Test func theSpinOutContractSettlesLikeAnyOther() throws {
        let balance = try Self.balance()

        // Nobody works it: the deadline passes and the penalty lands.
        var ignored = try Self.newGame(.spinOut)
        let job = try #require(ignored.activeContracts.first)
        let events = try Self.tick(&ignored, days: 85)
        let failed = events.compactMap { event -> (UUID, Int, Int)? in
            if case let .contractFailed(contractID, penalty, day) = event { return (contractID, penalty, day) }
            return nil
        }
        #expect(failed.count == 1)
        #expect(failed.first?.0 == job.id)
        #expect(failed.first?.1 == job.penalty)
        #expect(failed.first?.2 == 85, "settled the day after the deadline, like any other job")
        #expect(ignored.activeContracts.isEmpty)
        // The penalty is in the ledger under the client's name, for the
        // usual fraction of the payout.
        #expect(ignored.ledger.entries.contains {
            $0.category == .contracts && $0.label == job.clientName && $0.amount == -job.penalty
        })

        // The founder works it from day 0: delivered before the deadline,
        // paid, and the crew graded.
        var worked = try Self.newGame(.spinOut)
        let founder = try #require(worked.employees.first { $0.isFounder })
        Reducer.apply(
            .assign(employeeID: founder.id, to: .contract(job.id)),
            to: &worked, balance: balance, content: Self.content
        )
        let workedEvents = try Self.tick(&worked, days: 84)
        let delivered = workedEvents.compactMap { event -> (UUID, Int, Int, Int)? in
            if case let .contractDelivered(contractID, quality, payout, day) = event {
                return (contractID, quality, payout, day)
            }
            return nil
        }
        #expect(delivered.count == 1)
        let delivery = try #require(delivered.first)
        #expect(delivery.0 == job.id)
        #expect(delivery.3 <= 84)
        #expect(delivery.2 > 0)
        #expect(delivery.1 > 0, "the crew was graded")
        #expect(worked.activeContracts.isEmpty)
        #expect(worked.ledger.entries.contains { $0.category == .contracts && $0.label == job.clientName && $0.amount > 0 })
    }

    @Test func aMortgagedFounderOwnsAFlatAndOwesTheBank() throws {
        let balance = try Self.balance()
        let state = try Self.newGame(.mortgaged)

        #expect(state.life.home == .apartment)
        #expect(state.loanBalance == 25_000)
        #expect(state.economy.guaranteedLoanAmount == 25_000, "the whole loan is against the flat")
        #expect(state.company.cash == balance.startingCash + 25_000)
        #expect(state.company.cash == 37_000)
        let drawdown = try #require(state.ledger.entries.first)
        #expect(state.ledger.entries.count == 1)
        #expect(drawdown.amount == 25_000)
        #expect(drawdown.label == "Loan drawdown")
        #expect(drawdown.day == 0)
        // Everything else is the garage.
        #expect(state.employees.count == 1)
        #expect(state.company.reputation == 10)
        #expect(state.investors.equityRemaining == 100)
        #expect(state.life.wallet == balance.life.startingWallet)
    }

    /// The loan is real: interest posts weekly, the apartment's rent is
    /// the founder's, and the bank's guarantee sits over the company's
    /// grace period.
    @Test func theMortgageCostsMoneyEveryWeek() throws {
        var mortgaged = try Self.newGame(.mortgaged)
        var garage = try Self.newGame(.garage)
        _ = try Self.tick(&mortgaged, days: 28)
        _ = try Self.tick(&garage, days: 28)

        let interest = mortgaged.ledger.entries.filter { $0.label.localizedCaseInsensitiveContains("interest") }
        #expect(interest.count == 4, "four weeks, four interest lines")
        let garageDelta = garage.company.cash - 12_000
        let mortgagedDelta = mortgaged.company.cash - 37_000
        #expect(mortgagedDelta < garageDelta, "the mortgaged studio burns faster: interest on top of the same costs")
        #expect(mortgaged.life.wallet < garage.life.wallet, "the flat's rent is higher than the studio's")
    }

    // MARK: - Saves

    @Test func aSaveFromBeforeOriginsDecodesAsAGarage() throws {
        // The scaffold's save, with the `origin` key it already carried
        // removed: what a save from before the scaffold looks like.
        var object = try #require(
            try JSONSerialization.jsonObject(with: try Self.fixture("scaffold5-garage-day30-4242")) as? [String: Any]
        )
        #expect(object.removeValue(forKey: "origin") != nil)
        #expect(object["lockedTopics"] == nil)
        let data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        let state = try JSONDecoder().decode(GameState.self, from: data)
        #expect(state.origin == .garage)
        #expect(state.lockedTopics.isEmpty)
        #expect(state.cofounder == nil)
        #expect(state.employees.allSatisfy { !$0.isCofounder })
        #expect(state.day == 30)
    }

    @Test(arguments: FoundingOrigin.allCases)
    func everyOriginRoundTripsThroughJSON(origin: FoundingOrigin) throws {
        var state = try Self.newGame(origin, seed: 77)
        _ = try Self.tick(&state, days: 30)

        let data = try Self.sortedJSON(state)
        let decoded = try JSONDecoder().decode(GameState.self, from: data)
        #expect(decoded == state)
        #expect(decoded.origin == origin)
        #expect(decoded.lockedTopics == state.lockedTopics)
        #expect(decoded.cofounder == state.cofounder)
        #expect(try Self.sortedJSON(decoded) == data)

        // The wire only carries what the origin added.
        let json = String(decoding: data, as: UTF8.self)
        #expect(json.contains("\"isCofounder\"") == (origin == .cofounded))
        #expect(json.contains("\"lockedTopics\"") == (origin == .spinOut))
    }

    @Test func theBalanceBlockDecodesEmptyAndAbsentAsTheDefault() throws {
        let empty = try JSONDecoder().decode(BalanceConfig.OriginBalance.self, from: Data("{}".utf8))
        #expect(empty == .default)
        let partial = try JSONDecoder().decode(
            BalanceConfig.OriginBalance.self, from: Data(#"{"cofounderEquity": 40}"#.utf8)
        )
        #expect(partial.cofounderEquity == 40)
        #expect(partial.spinOutContractPayout == 9_000)
        #expect(try BalanceConfig.loadBundled().origins == .default, "Balance.json carries the shipped values")
    }

    @Test func replayKeepsTheOrigin() throws {
        // What `GameSession.replayCurrentGame` does: a new game on the
        // ended run's own seed, founder and origin is the same day 0.
        let ended = try Self.newGame(.spinOut, seed: 99)
        let again = try Self.newGame(ended.origin, seed: ended.seed, founder: ended.progression.founder)
        #expect(again == ended)
    }
}
