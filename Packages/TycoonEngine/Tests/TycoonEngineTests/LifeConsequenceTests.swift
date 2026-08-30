import Foundation
import Testing
import TycoonContent
import TycoonEngine

/// The founder's life is no longer decorative. Debt compounds, the landlord
/// eventually acts, a second hospital stay in a year leaves something
/// permanent, two burnouts make the trade press, and nobody calling for two
/// months costs you your mood.
@Suite("Founder consequences")
struct LifeConsequenceTests {
    static func economy(
        walletInterestWeeklyRate: Double = 0.015,
        evictionWalletThreshold: Int = -3_000,
        evictionGraceDays: Int = 14,
        chronicWindowDays: Int = 364,
        chronicMaxEnergy: Double = 80,
        chronicOutputFactor: Double = 0.9,
        chronicCureWeeks: Int = 3,
        lonelinessDays: Int = 60,
        lonelinessMoodDrift: Double = 0.5,
        lonelinessRelationshipThreshold: Double = 1,
        burnoutWindowDays: Int = 364,
        burnoutReputationPenalty: Double = 3
    ) -> BalanceConfig.EconomyBalance {
        var economy = TestBalance.neutralEconomy
        economy.walletInterestWeeklyRate = walletInterestWeeklyRate
        economy.evictionWalletThreshold = evictionWalletThreshold
        economy.evictionGraceDays = evictionGraceDays
        economy.chronicWindowDays = chronicWindowDays
        economy.chronicMaxEnergy = chronicMaxEnergy
        economy.chronicOutputFactor = chronicOutputFactor
        economy.chronicCureWeeks = chronicCureWeeks
        economy.lonelinessDays = lonelinessDays
        economy.lonelinessMoodDrift = lonelinessMoodDrift
        economy.lonelinessRelationshipThreshold = lonelinessRelationshipThreshold
        economy.burnoutWindowDays = burnoutWindowDays
        economy.burnoutReputationPenalty = burnoutReputationPenalty
        return economy
    }

    static func studio(
        economy: BalanceConfig.EconomyBalance,
        life: BalanceConfig.LifeBalance = TestBalance.quietLife,
        seed: UInt64 = 51
    ) -> (GameState, BalanceConfig, ContentCatalog) {
        let balance = TestBalance.make(life: life, economy: economy)
        var state = GameState.newGame(companyName: "Acme", seed: seed, balance: balance)
        TestLife.pinPeak(&state)
        return (state, balance, TestContent.tiny())
    }

    // MARK: - The debt spiral

    @Test func anOverdrawnWalletCompoundsWeekly() throws {
        var (state, balance, content) = Self.studio(economy: Self.economy())
        state.life.wallet = -10_000
        state.life.founderSalary = 0
        for _ in 0..<7 {
            Reducer.tick(&state, balance: balance, content: content)
        }
        // −10,000 − 120 rent = −10,120, then 1.5% interest — charged on
        // the first −3,000 only, because the overdraft is extended exactly
        // as far as the eviction threshold and no further: −45, not −152.
        //
        // Uncapped this compounds: a founder hospitalised eight times over
        // two years reached −$90k on a $200-a-week salary, of which some
        // $38k was interest on interest, and no arithmetic got them back.
        // Now the hole grows linearly and the rescue below can clear it.
        #expect(state.life.wallet == -10_165)
    }

    @Test func theLandlordWarnsBeforeActing() throws {
        var (state, balance, content) = Self.studio(economy: Self.economy())
        state.life.wallet = -5_000

        let events = Reducer.tick(&state, balance: balance, content: content)
        let warning = events.compactMap { event -> Int? in
            if case .evictionWarning(let untilDay, _) = event { return untilDay }
            return nil
        }
        #expect(warning == [state.day + 14])
        #expect(state.economy.evictionWarningDay == state.day)

        // No second warning while the first stands.
        var more = 0
        for _ in 0..<10 {
            for event in Reducer.tick(&state, balance: balance, content: content) {
                if case .evictionWarning = event { more += 1 }
            }
        }
        #expect(more == 0, "the warning stands; it is not re-served every day")
    }

    @Test func aWalletBackInTheBlackWithdrawsTheWarning() throws {
        var (state, balance, content) = Self.studio(economy: Self.economy())
        state.life.wallet = -5_000
        Reducer.tick(&state, balance: balance, content: content)
        #expect(state.economy.evictionWarningDay != nil)

        state.life.wallet = 500
        Reducer.tick(&state, balance: balance, content: content)
        #expect(state.economy.evictionWarningDay == nil)
    }

    @Test func aCompanyThatCanAffordItStartsPayingTheFounderProperly() throws {
        var (state, balance, content) = Self.studio(economy: Self.economy())
        state.life.wallet = -5_000
        state.life.founderSalary = 0
        state.company.cash = 1_000_000
        for _ in 0..<15 {
            Reducer.tick(&state, balance: balance, content: content)
        }
        // The rescue is sized to *clear the hole*, not merely to cover the
        // rent: living costs (the studio flat's 120) plus the 5,000
        // overdraft amortised over `evictionRecoveryWeeks` (26) — 120 +
        // 193 = 313, and 325 once two weeks of rent have deepened it.
        //
        // It used to be `max(salary, rent × 2)` = 240, which against a
        // 5,000 overdraft is 68 weeks of repayment and against the 30,000
        // a crunching founder actually reaches is fifteen years. That is
        // not a rescue, it is a rounding error.
        #expect(state.life.founderSalary == 325)
    }

    /// …and steps back down once the founder is square, rather than
    /// leaving the company paying three times the going rate for the rest
    /// of the run because of one bad quarter.
    @Test func theRescueStepsBackDownOnceTheFounderIsSquare() throws {
        var (state, balance, content) = Self.studio(economy: Self.economy())
        state.life.wallet = -5_000
        state.life.founderSalary = 0
        state.company.cash = 1_000_000
        for _ in 0..<15 {
            Reducer.tick(&state, balance: balance, content: content)
        }
        let rescued = state.life.founderSalary
        #expect(rescued > 240)
        #expect(state.economy.rescueSalary == rescued)

        state.life.wallet = 1_000
        Reducer.tick(&state, balance: balance, content: content)
        // Living costs (this balance's studio flat is 120 a week, and its
        // `defaultFounderSalary` is 0), not the repayment plan: the debt
        // is cleared, so there is nothing left to amortise.
        #expect(state.life.founderSalary == 120)
        #expect(state.economy.rescueSalary == nil)
    }

    /// A salary the player set themselves is never stepped down — the
    /// rescue only ever unwinds its own raise.
    @Test func aSalaryTheFounderSetThemselvesSurvivesRecovery() throws {
        var (state, balance, content) = Self.studio(economy: Self.economy())
        state.life.wallet = -5_000
        state.life.founderSalary = 0
        state.company.cash = 1_000_000
        for _ in 0..<15 {
            Reducer.tick(&state, balance: balance, content: content)
        }
        #expect(state.economy.rescueSalary != nil)

        _ = Reducer.apply(
            .setFounderSalary(900), to: &state, balance: balance, content: content
        )
        state.life.wallet = 1_000
        Reducer.tick(&state, balance: balance, content: content)
        #expect(state.life.founderSalary == 900)
    }

    @Test func aCompanyThatCannotAffordItMovesTheFounderSomewhereCheaper() throws {
        var (state, balance, content) = Self.studio(economy: Self.economy())
        state.life.home = .house
        state.life.wallet = -5_000
        state.company.cash = 100

        var downgraded: HomeTier?
        for _ in 0..<20 {
            for event in Reducer.tick(&state, balance: balance, content: content) {
                if case .homeDowngraded(let tier, _) = event { downgraded = tier }
            }
        }
        #expect(downgraded == .apartment)
        #expect(state.life.home == .apartment)
    }

    // MARK: - Chronic condition

    /// A life balance where the founder's health collapses on cue.
    static func fragileLife(healthDrift: Double = -40) -> BalanceConfig.LifeBalance {
        TestBalance.life(
            normalDrift: BalanceConfig.LifeBalance.MeterDrift(
                energy: 0, health: healthDrift, mood: 0, relationships: 0
            ),
            hospitalDays: 1,
            lifeEventIntervalDays: 10_000
        )
    }

    @Test func aSecondHospitalStayInAYearLeavesSomethingPermanent() throws {
        var (state, balance, content) = Self.studio(
            economy: Self.economy(), life: Self.fragileLife()
        )
        var diagnosed = false
        var stays = 0
        for _ in 0..<40 {
            for event in Reducer.tick(&state, balance: balance, content: content) {
                if case .founderAway(let reason, _, _) = event, reason == "Hospital" { stays += 1 }
                if case .chronicConditionDiagnosed = event { diagnosed = true }
            }
            if diagnosed { break }
        }
        #expect(stays == 2, "it should take exactly two stays, not one")
        #expect(diagnosed)
        #expect(state.economy.chronicCondition)
    }

    @Test func aChronicConditionCapsEnergyAndDocksOutput() throws {
        var (state, balance, content) = Self.studio(economy: Self.economy())
        state.economy.chronicCondition = true
        let healthy = state.founderOutputMultiplier(balance: balance)

        Reducer.tick(&state, balance: balance, content: content)
        #expect(state.life.meters.energy <= 80)
        var well = state
        well.economy.chronicCondition = false
        #expect(abs(state.founderOutputMultiplier(balance: balance)
            - well.founderOutputMultiplier(balance: balance) * 0.9) < 1e-9)
        #expect(healthy > 0)
    }

    @Test func threeRestorativeWeekendsInARowClearIt() throws {
        var (state, balance, content) = Self.studio(economy: Self.economy())
        state.economy.chronicCondition = true
        state.life.plannedActivity = .spa
        state.life.wallet = 100_000

        var cleared = false
        for _ in 0..<21 {
            for event in Reducer.tick(&state, balance: balance, content: content) {
                if case .chronicConditionCleared = event { cleared = true }
            }
        }
        #expect(cleared)
        #expect(!state.economy.chronicCondition)
    }

    @Test func aWeekendOffTheProgrammeBreaksTheStreak() throws {
        var (state, balance, content) = Self.studio(economy: Self.economy())
        state.economy.chronicCondition = true
        state.life.plannedActivity = .spa
        state.life.wallet = 100_000

        for _ in 0..<14 {
            Reducer.tick(&state, balance: balance, content: content)
        }
        #expect(state.economy.recoveryWeeks == 2)
        state.life.plannedActivity = .hobby
        for _ in 0..<7 {
            Reducer.tick(&state, balance: balance, content: content)
        }
        #expect(state.economy.recoveryWeeks == 0)
        #expect(state.economy.chronicCondition)
    }

    // MARK: - Meltdown

    @Test func burningOutTwiceInAYearMakesTheNews() throws {
        let life = TestBalance.life(
            normalDrift: BalanceConfig.LifeBalance.MeterDrift(
                energy: -40, health: 0, mood: 0, relationships: 0
            ),
            burnoutDays: 1,
            lifeEventIntervalDays: 10_000
        )
        var (state, balance, content) = Self.studio(economy: Self.economy(), life: life)
        state.company.reputation = 50

        var meltdowns = 0
        for _ in 0..<40 {
            for event in Reducer.tick(&state, balance: balance, content: content) {
                if case .founderMeltdown = event { meltdowns += 1 }
            }
        }
        #expect(meltdowns >= 1)
        #expect(state.company.reputation < 50)
    }

    // MARK: - Loneliness

    @Test func nobodyCallingForTwoMonthsStartsToCost() throws {
        var (state, balance, content) = Self.studio(
            economy: Self.economy(lonelinessDays: 10, lonelinessRelationshipThreshold: 5)
        )
        state.life.meters.relationships = 0
        state.life.meters.mood = 50 // off the clamp, so a drift shows
        state.life.family.stage = .single
        state.life.plannedActivity = .gym // no mood from the weekend

        // The clock starts on the first day at rock bottom…
        Reducer.tick(&state, balance: balance, content: content)
        #expect(state.economy.lonelySinceDay == 1)
        // …but nothing is lost until it has run.
        let moodBefore = state.life.meters.mood
        for _ in 0..<9 {
            Reducer.tick(&state, balance: balance, content: content)
        }
        #expect(state.life.meters.mood == moodBefore)

        for _ in 0..<4 {
            Reducer.tick(&state, balance: balance, content: content)
        }
        #expect(state.life.meters.mood < moodBefore, "loneliness should drag the mood down")
    }

    @Test func aNightOutBreaksALonelyRun() throws {
        var (state, balance, content) = Self.studio(
            economy: Self.economy(lonelinessDays: 10, lonelinessRelationshipThreshold: 5)
        )
        state.life.meters.relationships = 0
        state.life.family.stage = .single
        state.life.plannedActivity = .friends
        state.life.wallet = 10_000

        for _ in 0..<6 {
            Reducer.tick(&state, balance: balance, content: content)
        }
        #expect(state.economy.lonelySinceDay != nil)
        // Day 7 is the weekend: seeing people resets the clock.
        Reducer.tick(&state, balance: balance, content: content)
        #expect(state.economy.lonelySinceDay == nil)
    }

    // MARK: - Save compatibility

    @Test func lifeStateDecodesWithoutTheAwaySinceKey() throws {
        let json = """
        {"meters":{"energy":50,"health":50,"mood":50,"relationships":50},"schedule":"normal",\
        "plannedActivity":"rest","wallet":100,"founderSalary":0,"home":"studioFlat",\
        "family":{"stage":"single","stageSinceDay":0,"children":[]},\
        "lowRelationshipStreakDays":0}
        """
        let life = try JSONDecoder().decode(LifeState.self, from: Data(json.utf8))
        #expect(life.awaySinceDay == nil)
        #expect(life.wallet == 100)
    }
}
