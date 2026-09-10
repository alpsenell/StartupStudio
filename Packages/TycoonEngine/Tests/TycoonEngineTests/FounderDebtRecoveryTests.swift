import Foundation
import Testing
import TycoonContent
import TycoonEngine
import TycoonBots

/// The debt spiral has an exit.
///
/// Before this pass a founder who crunched for two years ended **$90,000**
/// personally overdrawn on a $200-a-week salary: eight or more hospital
/// stays at $5,000 each, interest compounding weekly on the whole hole, a
/// `debtMoodPenalty` pinning their mood at zero (and so their output near
/// `minOutputFactor`) for the rest of the run, and a "rescue" salary of
/// `max(salary, rent × 2)` = $240 a week that would have taken thirty-five
/// years to clear it. It was a spiral with no way out rather than a
/// consequence.
///
/// Five rules give it a floor and a ladder, each measured here:
/// 1. the overdraft stops growing at the eviction threshold;
/// 2. the rescue salary amortises the hole instead of covering the rent;
/// 3. …is re-offered until the company can actually afford it;
/// 4. …and steps back down once the founder is square;
/// 5. a hospital stay signs the founder off, so the crunch that put them
///    there cannot resume the day the bed is free;
/// 6. a People & HR team carries most of the bill;
/// 7. the mood penalty lifts while the wallet is climbing.
@Suite("Founder debt recovery")
struct FounderDebtRecoveryTests {
    static func economy(
        evictionWalletThreshold: Int = -3_000,
        evictionGraceDays: Int = 14,
        evictionRecoveryWeeks: Int = 26,
        convalescenceDays: Int = 14,
        hospitalInsuredFraction: Double = 0.6,
        walletInterestWeeklyRate: Double = 0.015
    ) -> BalanceConfig.EconomyBalance {
        var economy = TestBalance.neutralEconomy
        economy.evictionWalletThreshold = evictionWalletThreshold
        economy.evictionGraceDays = evictionGraceDays
        economy.evictionRecoveryWeeks = evictionRecoveryWeeks
        economy.convalescenceDays = convalescenceDays
        economy.hospitalInsuredFraction = hospitalInsuredFraction
        economy.walletInterestWeeklyRate = walletInterestWeeklyRate
        return economy
    }

    /// A studio with the life meters pinned so only the rule under test
    /// moves anything.
    static func studio(
        economy: BalanceConfig.EconomyBalance? = nil,
        life: BalanceConfig.LifeBalance = TestBalance.quietLife
    ) -> (GameState, BalanceConfig, ContentCatalog) {
        let balance = TestBalance.make(life: life, economy: economy ?? Self.economy())
        var state = GameState.newGame(companyName: "Acme", seed: 51, balance: balance)
        TestLife.pinPeak(&state)
        return (state, balance, TestContent.tiny())
    }

    // MARK: - 1. The overdraft has a floor

    /// Interest is charged on the overdraft the bank actually extended —
    /// as far as the eviction threshold and no further. Past that nobody
    /// is lending the founder anything, so the hole grows linearly with
    /// their outgoings instead of exponentially with itself.
    @Test func theOverdraftStopsGrowingAtTheEvictionThreshold() throws {
        for (wallet, expected) in [(-3_000, 45), (-10_000, 45), (-90_000, 45)] {
            var (state, balance, content) = Self.studio()
            state.life.wallet = wallet
            state.life.founderSalary = 0
            state.company.cash = 0
            let before = state.life.wallet
            for _ in 0..<7 { Reducer.tick(&state, balance: balance, content: content) }
            // One week: the studio flat's 120 rent, then interest on the
            // capped 3,000 — the same $45 however deep the hole is.
            let charged = before - state.life.wallet
            #expect(
                charged == 120 + expected,
                "at \(wallet) a week cost \(charged), not \(120 + expected)"
            )
        }
    }

    /// Uncapped, the same three weeks would compound.
    @Test func withoutTheCapTheHoleCompounds() throws {
        var (state, balance, content) = Self.studio(
            economy: Self.economy(evictionWalletThreshold: Int.min)
        )
        state.life.wallet = -90_000
        state.life.founderSalary = 0
        for _ in 0..<7 { Reducer.tick(&state, balance: balance, content: content) }
        #expect(state.life.wallet < -91_000, "interest on 90,000 should be over a thousand a week")
    }

    // MARK: - 2, 3, 4. The rescue

    @Test func theRescueIsSizedToClearTheHoleNotToCoverTheRent() throws {
        var (state, balance, content) = Self.studio()
        state.life.wallet = -13_000
        state.life.founderSalary = 0
        state.company.cash = 1_000_000
        for _ in 0..<15 { Reducer.tick(&state, balance: balance, content: content) }

        // Living costs (120) plus the overdraft over 26 weeks. The old
        // rule paid `rent × 2` = 240 regardless, which against this hole
        // is over two years of repayments.
        #expect(state.life.founderSalary > 500, "rescued on \(state.life.founderSalary) a week")
        #expect(state.life.founderSalary <= balance.life.founderSalaryMax)
        // A shorter recovery window pays more per week.
        var (fast, fastBalance, fastContent) = Self.studio(
            economy: Self.economy(evictionRecoveryWeeks: 13)
        )
        fast.life.wallet = -13_000
        fast.life.founderSalary = 0
        fast.company.cash = 1_000_000
        for _ in 0..<15 { Reducer.tick(&fast, balance: fastBalance, content: fastContent) }
        #expect(fast.life.founderSalary > state.life.founderSalary)
    }

    /// The rescue is offered again every grace period. A company that
    /// happened to be short of cash on the one day the old rule fired
    /// never bailed its founder out at all, however rich it got afterwards.
    @Test func theRescueIsReofferedUntilTheCompanyCanAffordIt() throws {
        var (state, balance, content) = Self.studio()
        state.life.wallet = -5_000
        state.life.founderSalary = 0

        // Solvent, but nowhere near able to carry a quarter of the rescue.
        for _ in 0..<30 {
            state.company.cash = 1_000
            Reducer.tick(&state, balance: balance, content: content)
        }
        #expect(state.life.founderSalary == 0, "a broke company cannot rescue anybody")

        for _ in 0..<15 {
            state.company.cash = 1_000_000
            Reducer.tick(&state, balance: balance, content: content)
        }
        #expect(state.life.founderSalary > 0, "the rescue was never re-offered")
    }

    @Test func theRescueStepsBackDownOnceTheFounderIsSquare() throws {
        var (state, balance, content) = Self.studio()
        state.life.wallet = -5_000
        state.life.founderSalary = 0
        state.company.cash = 1_000_000
        for _ in 0..<15 { Reducer.tick(&state, balance: balance, content: content) }
        let rescued = state.life.founderSalary
        #expect(rescued > 240)
        #expect(state.economy.rescueSalary == rescued)

        state.life.wallet = 1_000
        Reducer.tick(&state, balance: balance, content: content)
        // Living costs, not the repayment plan: there is nothing left to
        // amortise. (This balance's flat is 120 and its
        // `defaultFounderSalary` is 0.)
        #expect(state.life.founderSalary == 120)
        #expect(state.economy.rescueSalary == nil)
    }

    /// A salary the *player* set is never stepped down. The rescue only
    /// ever unwinds its own raise.
    @Test func aSalaryTheFounderSetThemselvesSurvivesRecovery() throws {
        var (state, balance, content) = Self.studio()
        state.life.wallet = -5_000
        state.life.founderSalary = 0
        state.company.cash = 1_000_000
        for _ in 0..<15 { Reducer.tick(&state, balance: balance, content: content) }
        #expect(state.economy.rescueSalary != nil)

        _ = Reducer.apply(.setFounderSalary(900), to: &state, balance: balance, content: content)
        state.life.wallet = 1_000
        Reducer.tick(&state, balance: balance, content: content)
        #expect(state.life.founderSalary == 900)
    }

    // MARK: - 5. A hospital stay breaks the crunch loop

    @Test func aHospitalStaySignsTheFounderOffAndRefusesCrunch() throws {
        var (state, balance, content) = Self.studio()
        state.life.schedule = .crunch
        state.life.meters.health = 5

        Reducer.tick(&state, balance: balance, content: content)
        #expect(state.life.awayReason == "Hospital")
        // Fourteen days on the ward, then a fortnight signed off.
        #expect(state.economy.convalescingUntilDay == 1 + balance.life.hospitalDays + 14)
        #expect(state.effectiveSchedule == .chill)
        // The founder's *intent* is untouched, so it resumes by itself.
        #expect(state.life.schedule == .crunch)

        // And asking to crunch again is refused while the note stands.
        state.life.schedule = .normal
        _ = Reducer.apply(.setWorkSchedule(.crunch), to: &state, balance: balance, content: content)
        #expect(state.life.schedule == .normal, "the doctor said no")
    }

    @Test func theConvalescenceEndsAndTheFoundersOwnScheduleResumes() throws {
        var (state, balance, content) = Self.studio()
        state.life.schedule = .crunch
        state.life.meters.health = 5
        Reducer.tick(&state, balance: balance, content: content)
        let until = try #require(state.economy.convalescingUntilDay)

        while state.day < until {
            Reducer.tick(&state, balance: balance, content: content)
        }
        #expect(state.economy.convalescingUntilDay == nil)
        #expect(state.effectiveSchedule == .crunch, "the sick note expired; the founder did not")
    }

    /// The point of the rule, in one number: a founder discharged straight
    /// back into a crunch collapses again in weeks. Discharged with a sick
    /// note, they get a season. Driven with the shipped balance, because
    /// `quietLife` zeroes the drift this depends on.
    @Test func beingSignedOffMeasurablyLengthensTheGapBetweenStays() throws {
        func gapBetweenStays(convalescenceDays: Int) throws -> Int {
            var balance = try BalanceConfig.loadBundled()
            balance.economy.convalescenceDays = convalescenceDays
            var state = GameState.newGame(companyName: "Acme", seed: 51, balance: balance)
            state.life.schedule = .crunch
            var stays: [Int] = []
            for _ in 0..<600 {
                // A studio with no products would go under long before the
                // second stay; this test is about the founder, not the books.
                state.company.cash = 1_000_000
                for event in Reducer.tick(&state, balance: balance, content: TestContent.bundled) {
                    if case .founderAway("Hospital", _, let day) = event { stays.append(day) }
                }
                // The founder keeps asking to crunch, the way a player who
                // has a deadline does — and the way `CrunchHireBot` does.
                _ = Reducer.apply(
                    .setWorkSchedule(.crunch), to: &state,
                    balance: balance, content: TestContent.bundled
                )
                if stays.count >= 2 { break }
            }
            return stays.count >= 2 ? stays[1] - stays[0] : 600
        }
        let signedOff = try gapBetweenStays(convalescenceDays: 14)
        let straightBack = try gapBetweenStays(convalescenceDays: 0)
        #expect(
            signedOff > straightBack,
            "signed off: \(signedOff) days between stays; straight back: \(straightBack)"
        )
    }

    // MARK: - 6. A People team carries the bill

    @Test func aPeopleTeamCarriesMostOfTheHospitalBill() throws {
        func bill(withHR: Bool) -> Int {
            let balance = TestBalance.make(economy: Self.economy())
            var state = GameState.newGame(companyName: "Acme", seed: 51, balance: balance)
            TestLife.pinPeak(&state)
            if withHR { state.employees.append(TestPeople.employee(name: "Robin", role: .hr)) }
            state.life.meters.health = 5
            let before = state.life.wallet
            Reducer.tick(&state, balance: balance, content: TestContent.tiny())
            return before - state.life.wallet
        }
        let uninsured = bill(withHR: false)
        #expect(uninsured == Int(TestBalance.make(economy: Self.economy()).life.hospitalBill))
        // 60% carried by the company.
        #expect(bill(withHR: true) == Int(Double(uninsured) * 0.4))
    }

    // MARK: - 7. The mood penalty is escapable

    @Test func theDebtMoodPenaltyLiftsWhileTheWalletIsClimbing() throws {
        // Sinking: rent goes out, nothing comes in, the mood penalty bites.
        var (sinking, balance, content) = Self.studio()
        sinking.life.wallet = -1_000
        sinking.life.founderSalary = 0
        sinking.life.meters.mood = 50
        for _ in 0..<14 { Reducer.tick(&sinking, balance: balance, content: content) }

        // Climbing: the company is paying enough to clear the rent and
        // more, so the wallet rises week on week.
        var (climbing, _, _) = Self.studio()
        climbing.life.wallet = -1_000
        climbing.life.founderSalary = 600
        climbing.company.cash = 1_000_000
        climbing.life.meters.mood = 50
        for _ in 0..<14 { Reducer.tick(&climbing, balance: balance, content: content) }

        #expect(climbing.life.wallet > sinking.life.wallet)
        #expect(
            climbing.life.meters.mood > sinking.life.meters.mood,
            "climbing out of debt should not feel the same as sinking into it"
        )
    }

    // MARK: - The whole thing, over two years

    /// The acceptance number. Every bot, ten seeds, two game years: nobody
    /// ends in a hole they cannot climb out of, and the founder who never
    /// once looks up is in hospital a handful of times rather than every
    /// other month.
    @Test func acrossTwoYearsNoFounderEndsBeyondRecovery() throws {
        for bot in [
            { CrunchHireBot() as any BotPolicy },
            { NeglectfulBot() as any BotPolicy },
            { SoloSlowBot() as any BotPolicy },
        ] {
            for seed in BalanceTargetsTests.seeds {
                let result = try BalanceTargetsTests.run(bot(), seed: seed)
                #expect(
                    result.state.life.wallet >= -15_000,
                    "\(result.botName) seed \(seed) ended on \(result.state.life.wallet)"
                )
                #expect(
                    result.hospitalizations <= 4,
                    "\(result.botName) seed \(seed): \(result.hospitalizations) hospital stays"
                )
            }
        }
    }
}
