import Foundation
import Testing
import TycoonContent
import TycoonEngine

private func relationshipBalance(
    affectionDrift: Double = -0.3,
    neglectDrift: Double = -0.5,
    neglectDays: Int = 14,
    affectionRelationshipFactor: Double = 0.012,
    bondDecayPerDay: Double = 0.12,
    bondPerSocialAction: Double = 6,
    bondOutputFactor: Double = 0.12,
    bondMoraleTargetFactor: Double = 0.06,
    bondLoyaltyPerDay: Double = 0.15,
    stageMinAffection: [String: Double] = [:]
) -> BalanceConfig.RelationshipBalance {
    BalanceConfig.RelationshipBalance(
        startingAffection: 55,
        affectionDrift: affectionDrift,
        neglectDrift: neglectDrift,
        neglectDays: neglectDays,
        affectionRelationshipFactor: affectionRelationshipFactor,
        partnerActivities: [
            PartnerActivity.call.rawValue: .init(
                cost: 0, affection: 4, energy: -1, mood: 2, relationships: 1, cooldownDays: 1
            ),
            PartnerActivity.dateNight.rawValue: .init(
                cost: 140, affection: 11, energy: -3, mood: 6, relationships: 5, cooldownDays: 3
            ),
            PartnerActivity.gift.rawValue: .init(
                cost: 450, affection: 15, mood: 4, relationships: 3, cooldownDays: 7
            ),
        ],
        stageMinAffection: stageMinAffection,
        bondDecayPerDay: bondDecayPerDay,
        bondPerSocialAction: bondPerSocialAction,
        hangOut: .init(cost: 70, affection: 0, energy: -4, mood: 5, relationships: 4, cooldownDays: 5),
        mentorSkillGain: 4.5,
        mentorEnergyCost: 8,
        mentorCooldownDays: 7,
        bondOutputFactor: bondOutputFactor,
        bondMoraleTargetFactor: bondMoraleTargetFactor,
        bondLoyaltyPerDay: bondLoyaltyPerDay
    )
}

private func balance(
    relationships: BalanceConfig.RelationshipBalance = relationshipBalance(),
    staff: BalanceConfig.StaffBalance = TestBalance.frozenStaff
) -> BalanceConfig {
    TestBalance.make(
        candidateRefreshDays: 10_000,
        contractOfferRefreshDays: 10_000,
        eventCheckIntervalDays: 10_000,
        life: TestBalance.quietLife,
        staff: staff,
        relationships: relationships
    )
}

private func newGame(_ balance: BalanceConfig) -> GameState {
    var state = GameState.newGame(companyName: "Acme", seed: 3, balance: balance)
    state.life.wallet = 50_000
    TestLife.pinPeak(&state)
    return state
}

// MARK: - The partner

@Suite("Partner affection")
struct PartnerAffectionTests {
    @Test("Affection slides when the founder does nothing")
    func affectionDrifts() {
        let config = balance()
        var state = newGame(config)
        TestLife.setPartner(&state, stage: .partner)
        state.life.family.affection = 80
        state.life.family.lastPartnerDay = 0

        for _ in 0..<10 { Reducer.tick(&state, balance: config, content: TestContent.tiny()) }
        #expect(abs(state.life.family.affection - 77) < 1e-9)
    }

    @Test("Being ignored for a fortnight makes it worse")
    func neglectAccelerates() {
        let config = balance()
        var attended = newGame(config)
        TestLife.setPartner(&attended, stage: .partner)
        attended.life.family.affection = 90
        var ignored = attended

        let content = TestContent.tiny()
        for _ in 0..<20 {
            // One of them keeps in touch; the phone call is free.
            Reducer.apply(.spendTimeWithPartner(.call), to: &attended, balance: config, content: content)
            Reducer.tick(&attended, balance: config, content: content)
            Reducer.tick(&ignored, balance: config, content: content)
        }

        #expect(attended.life.family.affection > ignored.life.family.affection)
        // Past `neglectDays` the ignored partner is losing 0.8 a day, not 0.3.
        #expect(ignored.life.family.affection < 90 - 20 * 0.3)
    }

    @Test("A single founder's affection is not simulated at all")
    func singleFoundersHaveNoAffection() {
        let config = balance()
        var state = newGame(config)
        state.life.meters.relationships = 50

        for _ in 0..<10 { Reducer.tick(&state, balance: config, content: TestContent.tiny()) }
        #expect(state.life.family.affection == 0)
        #expect(state.life.meters.relationships == 50)
    }

    @Test("A happy partner lifts the relationships meter, an unhappy one drains it")
    func affectionFeedsTheMeter() {
        let config = balance()
        var happy = newGame(config)
        TestLife.setPartner(&happy, stage: .married)
        happy.life.meters.relationships = 50
        happy.life.family.affection = 100
        var unhappy = happy
        unhappy.life.family.affection = 10

        let content = TestContent.tiny()
        for _ in 0..<5 {
            Reducer.tick(&happy, balance: config, content: content)
            Reducer.tick(&unhappy, balance: config, content: content)
        }
        #expect(happy.life.meters.relationships > 50)
        #expect(unhappy.life.meters.relationships < 50)
    }

    @Test("A partner on the way out says so first")
    func driftingWarns() {
        let config = balance()
        var state = newGame(config)
        TestLife.setPartner(&state, stage: .married)
        // One tick above the warning line, so the next crossing is this one.
        state.life.family.affection = balance().life.breakupThreshold + 15.1
        state.life.family.lastPartnerDay = state.day

        let events = Reducer.tick(&state, balance: config, content: TestContent.tiny())
        #expect(events.contains { if case .partnerDrifting = $0 { true } else { false } })

        // And only once — it is a warning, not a nag.
        let again = Reducer.tick(&state, balance: config, content: TestContent.tiny())
        #expect(!again.contains { if case .partnerDrifting = $0 { true } else { false } })
    }

    @Test("A breakup clears the partner's inner life")
    func breakupClearsEverything() {
        let config = balance()
        var state = newGame(config)
        TestLife.setPartner(&state, stage: .married)
        state.life.family.affection = 80
        state.life.family.partnerContactID = UUID()
        state.life.meters.relationships = 0
        state.life.lowRelationshipStreakDays = config.life.breakupStreakDays

        Reducer.tick(&state, balance: config, content: TestContent.tiny())

        #expect(state.life.family.stage == .single)
        #expect(state.life.family.affection == 0)
        #expect(state.life.family.partnerContactID == nil)
        #expect(state.life.family.lastPartnerDay == nil)
    }
}

// MARK: - Partner activities

@Suite("Partner activities")
struct PartnerActivityTests {
    @Test("A date night costs the wallet and buys affection")
    func dateNightWorks() {
        let config = balance()
        var state = newGame(config)
        TestLife.setPartner(&state, stage: .partner)
        state.life.family.affection = 50

        let events = Reducer.apply(
            .spendTimeWithPartner(.dateNight), to: &state, balance: config, content: TestContent.tiny()
        )

        #expect(state.life.wallet == 50_000 - 140)
        #expect(state.life.family.affection == 61)
        #expect(state.life.family.lastPartnerDay == state.day)
        #expect(events.contains { if case .partnerTime = $0 { true } else { false } })
    }

    @Test("A single founder has nobody to call")
    func singleFounderRefused() {
        let config = balance()
        var state = newGame(config)

        #expect(Reducer.apply(
            .spendTimeWithPartner(.call), to: &state, balance: config, content: TestContent.tiny()
        ).isEmpty)
        #expect(
            state.partnerActivityBlocker(.call, balance: config) == "You're not seeing anyone"
        )
    }

    @Test("Each activity has its own cooldown")
    func cooldownsArePerActivity() {
        let config = balance()
        var state = newGame(config)
        TestLife.setPartner(&state, stage: .partner)
        let content = TestContent.tiny()

        Reducer.apply(.spendTimeWithPartner(.gift), to: &state, balance: config, content: content)
        #expect(Reducer.apply(
            .spendTimeWithPartner(.gift), to: &state, balance: config, content: content
        ).isEmpty)
        #expect(!Reducer.apply(
            .spendTimeWithPartner(.call), to: &state, balance: config, content: content
        ).isEmpty)
    }

    @Test("Conversation makes the same evening go further")
    func charmScalesAffection() {
        let founder = BalanceConfig.FounderBalance(
            starting: FounderSkillSet(
                conversation: 50, technical: 50, marketKnowledge: 50, leadership: 50, finance: 50
            ),
            skillMidpoint: 50,
            conversationFactor: 0.6
        )
        let config = TestBalance.make(
            candidateRefreshDays: 10_000,
            contractOfferRefreshDays: 10_000,
            eventCheckIntervalDays: 10_000,
            life: TestBalance.quietLife,
            founder: founder,
            relationships: relationshipBalance()
        )
        var charming = newGame(config)
        TestLife.setPartner(&charming, stage: .partner)
        charming.life.family.affection = 20
        var awkward = charming
        charming.life.skills.conversation = 100
        awkward.life.skills.conversation = 0

        let content = TestContent.tiny()
        Reducer.apply(.spendTimeWithPartner(.dateNight), to: &charming, balance: config, content: content)
        Reducer.apply(.spendTimeWithPartner(.dateNight), to: &awkward, balance: config, content: content)

        #expect(charming.life.family.affection > awkward.life.family.affection)
    }

    @Test("Marriage needs a partner who actually wants to")
    func affectionGatesTheLadder() {
        let config = balance(relationships: relationshipBalance(
            stageMinAffection: [RelationshipStage.married.rawValue: 70]
        ))
        var state = newGame(config)
        TestLife.setPartner(&state, stage: .partner, sinceDay: -400)
        state.day = 400
        state.life.family.stageSinceDay = 0
        state.life.meters.relationships = 100
        state.life.family.affection = 40
        let content = TestContent.tiny()

        #expect(Reducer.apply(
            .advanceRelationship, to: &state, balance: config, content: content
        ).isEmpty)

        state.life.family.affection = 80
        #expect(!Reducer.apply(
            .advanceRelationship, to: &state, balance: config, content: content
        ).isEmpty)
        #expect(state.life.family.stage == .married)
    }
}

// MARK: - The team

@Suite("Founder–team bond")
struct FounderBondTests {
    private func withHire(_ config: BalanceConfig, bond: Double = 0) -> (GameState, UUID) {
        var state = newGame(config)
        var hire = TestPeople.employee()
        hire.founderBond = bond
        state.employees.append(hire)
        return (state, hire.id)
    }

    @Test("An evening out with somebody on the team is the founder's own money")
    func hangOutIsPersonal() {
        let config = balance()
        var (state, id) = withHire(config)

        let events = Reducer.apply(
            .hangOutWith(employeeID: id), to: &state, balance: config, content: TestContent.tiny()
        )

        #expect(state.life.wallet == 50_000 - 70)
        #expect(state.company.cash == config.startingCash)
        #expect((state.employees.last?.founderBond ?? 0) > 0)
        #expect(events.contains { if case .hungOutWith = $0 { true } else { false } })
    }

    @Test("Company social actions build the founder's bond too")
    func coffeeBuildsBond() {
        let config = balance()
        var (state, id) = withHire(config)

        Reducer.apply(.grabCoffee(employeeID: id), to: &state, balance: config, content: TestContent.tiny())
        #expect((state.employees.last?.founderBond ?? 0) == 6)
    }

    @Test("A bond nobody tends fades")
    func bondDecays() {
        let config = balance()
        var (state, _) = withHire(config, bond: 50)

        for _ in 0..<10 { Reducer.tick(&state, balance: config, content: TestContent.tiny()) }
        #expect(abs((state.employees.last?.founderBond ?? 0) - 48.8) < 1e-9)
    }

    @Test("A strong bond is worth output and loyalty")
    func bondIsWorthSomething() {
        let config = balance()
        var (close, _) = withHire(config, bond: 100)
        var (distant, _) = withHire(config, bond: 0)

        let closeOutput = try! #require(close.employees.last).performanceMultiplier(balance: config)
        let distantOutput = try! #require(distant.employees.last).performanceMultiplier(balance: config)
        #expect(closeOutput > distantOutput)

        let content = TestContent.tiny()
        for _ in 0..<10 {
            Reducer.tick(&close, balance: config, content: content)
            Reducer.tick(&distant, balance: config, content: content)
        }
        #expect((close.employees.last?.loyalty ?? 0) > (distant.employees.last?.loyalty ?? 0))
    }

    @Test("Mentoring teaches a skill on the founder's own energy")
    func mentoringTeaches() {
        let config = balance()
        var (state, id) = withHire(config)
        let before = state.employees.last?.skills.coding ?? 0

        let events = Reducer.apply(
            .mentorEmployee(employeeID: id, skill: .coding),
            to: &state, balance: config, content: TestContent.tiny()
        )

        #expect((state.employees.last?.skills.coding ?? 0) > before)
        #expect(state.life.meters.energy == 92)
        #expect(state.company.cash == config.startingCash)
        #expect(events.contains { if case .employeeMentored = $0 { true } else { false } })
    }

    @Test("A founder who knows the subject teaches more of it")
    func mentoringScalesWithTheFounder() {
        let founder = BalanceConfig.FounderBalance(skillMidpoint: 50)
        let config = TestBalance.make(
            candidateRefreshDays: 10_000,
            contractOfferRefreshDays: 10_000,
            eventCheckIntervalDays: 10_000,
            life: TestBalance.quietLife,
            founder: founder,
            relationships: relationshipBalance()
        )
        var (expert, id) = withHire(config)
        var novice = expert
        expert.life.skills.technical = 100
        expert.life.skills.leadership = 100
        novice.life.skills.technical = 0
        novice.life.skills.leadership = 0

        let content = TestContent.tiny()
        Reducer.apply(.mentorEmployee(employeeID: id, skill: .coding),
                      to: &expert, balance: config, content: content)
        Reducer.apply(.mentorEmployee(employeeID: id, skill: .coding),
                      to: &novice, balance: config, content: content)

        #expect((expert.employees.last?.skills.coding ?? 0) > (novice.employees.last?.skills.coding ?? 0))
    }

    @Test("Mentoring has a cooldown")
    func mentorCooldown() {
        let config = balance()
        var (state, id) = withHire(config)
        let content = TestContent.tiny()

        Reducer.apply(.mentorEmployee(employeeID: id, skill: .design),
                      to: &state, balance: config, content: content)
        #expect(Reducer.apply(.mentorEmployee(employeeID: id, skill: .design),
                              to: &state, balance: config, content: content).isEmpty)
        #expect(state.mentorBlocker(employeeID: id, balance: config) == "Again in 7 days")
    }

    @Test("A balance with no relationships block leaves bonds inert")
    func inertWithoutTheBlock() {
        let config = TestBalance.make(life: TestBalance.quietLife)
        var (close, id) = withHire(config, bond: 100)
        let (distant, _) = withHire(config, bond: 0)

        // The bond is worth nothing to output...
        let closeOutput = try! #require(close.employees.last).performanceMultiplier(balance: config)
        let distantOutput = try! #require(distant.employees.last).performanceMultiplier(balance: config)
        #expect(closeOutput == distantOutput)

        // ...and nothing moves it, in either direction.
        Reducer.apply(.grabCoffee(employeeID: id), to: &close, balance: config, content: TestContent.tiny())
        for _ in 0..<10 { Reducer.tick(&close, balance: config, content: TestContent.tiny()) }
        #expect(close.employees.last?.founderBond == 100)
    }
}
