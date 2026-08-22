import Foundation
import Testing
import TycoonContent
import TycoonEngine

@Suite("Contract offers")
struct ContractOfferTests {
    @Test func offersRefreshWeeklyWithCountBoundsExpiryAndCatalogNames() throws {
        let balance = try BalanceConfig.loadBundled()
        let content = TestContent.bundled
        var state = GameState.newGame(companyName: "Acme", seed: 21, balance: balance)

        // Days 1-6: no offer sheet yet.
        for _ in 0..<6 { Reducer.tick(&state, balance: balance, content: content) }
        #expect(state.contractOffers.isEmpty)

        let day7Events = Reducer.tick(&state, balance: balance, content: content)
        #expect(day7Events.contains(.contractOffersRefreshed(day: 7)))
        #expect(state.eventLog.contains(.contractOffersRefreshed(day: 7)))
        #expect(state.contractOffers.count == balance.contractOfferCount)

        for offer in state.contractOffers {
            #expect(content.names.clientCompanies.contains(offer.clientName))
            #expect(offer.expiresDay == 7 + balance.contractOfferRefreshDays)

            // Year 1: totalPts is an unscaled U(ptsMin, ptsMax) roll.
            let totalPts = offer.requiredCodePts + offer.requiredDesignPts
            #expect(totalPts >= balance.contractPtsMin)
            #expect(totalPts <= balance.contractPtsMax)

            let codeShare = offer.requiredCodePts / totalPts
            #expect(codeShare >= balance.contractCodeSplitMin - 1e-9)
            #expect(codeShare <= balance.contractCodeSplitMax + 1e-9)

            let payoutFloor = totalPts * balance.contractPayoutPerPoint * balance.contractUrgencyPremiumMin
            let payoutCeiling = totalPts * balance.contractPayoutPerPoint * balance.contractUrgencyPremiumMax
            #expect(Double(offer.payout) >= payoutFloor - 0.5)
            #expect(Double(offer.payout) <= payoutCeiling + 0.5)
            #expect(offer.penalty == Int((balance.contractPenaltyFraction * Double(offer.payout)).rounded()))

            let deadlineFloor = Int((totalPts / balance.contractDeadlinePtsPerDay * balance.contractDeadlineSlackMin).rounded(.up))
            let deadlineCeiling = Int((totalPts / balance.contractDeadlinePtsPerDay * balance.contractDeadlineSlackMax).rounded(.up))
            #expect(offer.deadlineDays >= deadlineFloor)
            #expect(offer.deadlineDays <= deadlineCeiling)
        }
    }

    @Test func refreshReplacesTheSheetAndIsDeterministicPerSeed() throws {
        let balance = try BalanceConfig.loadBundled()
        let content = TestContent.bundled

        func offers(afterDays days: Int, seed: UInt64) -> [ContractOffer] {
            var state = GameState.newGame(companyName: "Acme", seed: seed, balance: balance)
            for _ in 0..<days { Reducer.tick(&state, balance: balance, content: content) }
            return state.contractOffers
        }

        let week1 = offers(afterDays: 7, seed: 33)
        #expect(week1 == offers(afterDays: 7, seed: 33))
        #expect(week1 != offers(afterDays: 7, seed: 34))

        // The next refresh replaces the whole sheet with fresh rolls.
        let week2 = offers(afterDays: 14, seed: 33)
        #expect(week2.count == balance.contractOfferCount)
        #expect(Set(week2.map(\.id)).isDisjoint(with: week1.map(\.id)))
        #expect(week2.allSatisfy { $0.expiresDay == 14 + balance.contractOfferRefreshDays })
    }

    @Test func offerPointsScaleWithYear() throws {
        // Pinning the roll range to a single value isolates the year scaling.
        let balance = TestBalance.make(contractPtsMin: 100, contractPtsMax: 100)
        let content = TestContent.tiny()

        var state = GameState.newGame(companyName: "Acme", seed: 22, balance: balance)
        for _ in 0..<7 { Reducer.tick(&state, balance: balance, content: content) }
        for offer in state.contractOffers {
            // Year 1: scale = 1 + 0.25 * 0 = 1.0.
            #expect(abs(offer.requiredCodePts + offer.requiredDesignPts - 100) < 1e-9)
        }

        var later = GameState.newGame(companyName: "Acme", seed: 22, balance: balance)
        later.day = 363
        Reducer.tick(&later, balance: balance, content: content) // day 364 = year 2 refresh
        #expect(later.contractOffers.count == balance.contractOfferCount)
        for offer in later.contractOffers {
            // Year 2: scale = 1 + 0.25 * 1 = 1.25.
            #expect(abs(offer.requiredCodePts + offer.requiredDesignPts - 125) < 1e-9)
        }
    }
}

@Suite("Contract lifecycle")
struct ContractLifecycleTests {
    private let content = TestContent.tiny()

    /// A hand-built active job for exact-progress and settlement tests.
    private func job(
        id: UUID = UUID(),
        requiredCodePts: Double,
        requiredDesignPts: Double,
        deadlineDay: Int,
        payout: Int = 1_800,
        penalty: Int = 540
    ) -> ContractJob {
        ContractJob(
            id: id,
            clientName: "TestCo",
            requiredCodePts: requiredCodePts,
            requiredDesignPts: requiredDesignPts,
            progressCode: 0,
            progressDesign: 0,
            deadlineDay: deadlineDay,
            payout: payout,
            penalty: penalty,
            acceptedDay: 0
        )
    }

    @Test func acceptContractMovesTheOfferIntoActiveJobsAndEmits() throws {
        let balance = TestBalance.standard
        var state = GameState.newGame(companyName: "Acme", seed: 40, balance: balance)
        for _ in 0..<7 { Reducer.tick(&state, balance: balance, content: content) }
        let offer = try #require(state.contractOffers.first)

        let events = Reducer.apply(
            .acceptContract(offerID: offer.id), to: &state, balance: balance, content: content
        )

        #expect(events == [.contractAccepted(contractID: offer.id, day: 7)])
        #expect(state.eventLog.contains(.contractAccepted(contractID: offer.id, day: 7)))
        #expect(state.contractOffers.count == balance.contractOfferCount - 1)
        #expect(!state.contractOffers.contains(where: { $0.id == offer.id }))

        let job = try #require(state.activeContract(id: offer.id))
        #expect(job.clientName == offer.clientName)
        #expect(job.requiredCodePts == offer.requiredCodePts)
        #expect(job.requiredDesignPts == offer.requiredDesignPts)
        #expect(job.progressCode == 0)
        #expect(job.progressDesign == 0)
        #expect(job.deadlineDay == 7 + offer.deadlineDays)
        #expect(job.payout == offer.payout)
        #expect(job.penalty == offer.penalty)
        #expect(job.acceptedDay == 7)
    }

    @Test func acceptContractIgnoresUnknownAndExpiredOffers() {
        let balance = TestBalance.standard
        var state = GameState.newGame(companyName: "Acme", seed: 41, balance: balance)

        // Unknown offer: ignored.
        #expect(Reducer.apply(
            .acceptContract(offerID: UUID()), to: &state, balance: balance, content: content
        ).isEmpty)
        #expect(state.activeContracts.isEmpty)

        // Expired offer: ignored (the sheet is replaced at the next refresh).
        let stale = ContractOffer(
            id: UUID(), clientName: "TestCo",
            requiredCodePts: 10, requiredDesignPts: 5,
            payout: 900, penalty: 270,
            deadlineDays: 5, expiresDay: 3
        )
        state.contractOffers = [stale]
        state.day = 4
        #expect(Reducer.apply(
            .acceptContract(offerID: stale.id), to: &state, balance: balance, content: content
        ).isEmpty)
        #expect(state.activeContracts.isEmpty)
        #expect(state.eventLog.isEmpty)
    }

    @Test func assignedEmployeesProgressTheJobAtExactRates() throws {
        let balance = TestBalance.make(skillGrowthRate: 0, life: TestBalance.quietLife)
        var state = GameState.newGame(companyName: "Acme", seed: 42, balance: balance)
        TestLife.pinPeak(&state) // founder output multiplier exactly 1
        let job = job(requiredCodePts: 500, requiredDesignPts: 500, deadlineDay: 100)
        state.activeContracts = [job]

        let worker = TestPeople.employee(coding: 50, design: 25)
        state.employees.append(worker)
        let founderID = try #require(state.employees.first).id
        Reducer.apply(
            .assign(employeeID: founderID, to: .contract(job.id)),
            to: &state, balance: balance, content: content
        )
        Reducer.apply(
            .assign(employeeID: worker.id, to: .contract(job.id)),
            to: &state, balance: balance, content: content
        )

        for _ in 0..<3 { Reducer.tick(&state, balance: balance, content: content) }

        // Per day (growth off): code = (1 + 40/25) + (1 + 50/25) = 5.6,
        // design = (1 + 30/25) + (1 + 25/25) = 4.2. Three days:
        let updated = try #require(state.activeContract(id: job.id))
        #expect(abs(updated.progressCode - 16.8) < 1e-9)
        #expect(abs(updated.progressDesign - 12.6) < 1e-9)
    }

    @Test func contractOutputAppliesDevSpeedTechAndGrowsSkills() throws {
        let balance = TestBalance.make(life: TestBalance.quietLife)
        let content = TestContent.tiny(
            techTree: [TestTech.node(id: "speed", researchCost: 10, effect: .devSpeedMultiplier(bonus: 0.10))]
        )
        var state = GameState.newGame(companyName: "Acme", seed: 43, balance: balance)
        TestLife.pinPeak(&state) // founder output multiplier exactly 1
        state.research.unlocked.insert("speed")
        let job = job(requiredCodePts: 500, requiredDesignPts: 500, deadlineDay: 100)
        state.activeContracts = [job]
        let founderID = try #require(state.employees.first).id
        Reducer.apply(
            .assign(employeeID: founderID, to: .contract(job.id)),
            to: &state, balance: balance, content: content
        )

        Reducer.tick(&state, balance: balance, content: content)

        // Founder (coding 40, design 30) with the x1.1 dev-speed tech:
        // code = (1 + 40/25) * 1.1 = 2.86, design = (1 + 30/25) * 1.1 = 2.42.
        let updated = try #require(state.activeContract(id: job.id))
        #expect(abs(updated.progressCode - 2.86) < 1e-9)
        #expect(abs(updated.progressDesign - 2.42) < 1e-9)

        // A productive contract day grows both skills by the standard rule.
        let founder = try #require(state.employees.first)
        #expect(abs(founder.skills.coding - (40 + 0.08 * 0.6)) < 1e-9)
        #expect(abs(founder.skills.design - (30 + 0.08 * 0.7)) < 1e-9)
    }

    @Test func completionPaysPostsLedgerRewardsReputationAndEmits() throws {
        let balance = TestBalance.make(life: TestBalance.quietLife)
        var state = GameState.newGame(companyName: "Acme", seed: 44, balance: balance)
        TestLife.pinPeak(&state) // founder output multiplier exactly 1
        state.company.reputation = 99.5 // the +1.0 reward clamps at 100
        let job = job(requiredCodePts: 2, requiredDesignPts: 2, deadlineDay: 50)
        state.activeContracts = [job]
        let founderID = try #require(state.employees.first).id
        Reducer.apply(
            .assign(employeeID: founderID, to: .contract(job.id)),
            to: &state, balance: balance, content: content
        )

        // Day 1: founder adds code 2.6 / design 2.2 — both pools clear.
        let events = Reducer.tick(&state, balance: balance, content: content)

        #expect(events.contains(.contractCompleted(contractID: job.id, payout: 1_800, day: 1)))
        #expect(state.company.cash == balance.startingCash + 1_800)
        #expect(state.company.reputation == 100)
        #expect(state.activeContracts.isEmpty)
        #expect(state.activeContract(id: job.id) == nil)

        let entry = try #require(state.ledger.entries.last)
        #expect(entry == LedgerEntry(day: 1, amount: 1_800, category: .contracts, label: "TestCo"))

        // The next daily sweep returns the worker to idle.
        Reducer.tick(&state, balance: balance, content: content)
        #expect(try #require(state.employees.first).assignment == .idle)
    }

    @Test func deadlineMissPenalizesClampsReputationAndEmits() throws {
        let balance = TestBalance.standard
        var state = GameState.newGame(companyName: "Acme", seed: 45, balance: balance)
        state.company.reputation = 1.0 // the -2.0 penalty clamps at 0
        let job = job(requiredCodePts: 1_000, requiredDesignPts: 1_000, deadlineDay: 2, penalty: 270)
        state.activeContracts = [job]
        let founderID = try #require(state.employees.first).id
        Reducer.apply(
            .assign(employeeID: founderID, to: .contract(job.id)),
            to: &state, balance: balance, content: content
        )

        // Alive through the deadline day itself.
        Reducer.tick(&state, balance: balance, content: content) // day 1
        Reducer.tick(&state, balance: balance, content: content) // day 2 == deadline
        #expect(state.activeContracts.count == 1)

        // Day 3 > deadlineDay: the client walks.
        let events = Reducer.tick(&state, balance: balance, content: content)
        #expect(events.contains(.contractFailed(contractID: job.id, penalty: 270, day: 3)))
        #expect(state.company.cash == balance.startingCash - 270)
        #expect(state.company.reputation == 0)
        #expect(state.activeContracts.isEmpty)

        let entry = try #require(state.ledger.entries.last)
        #expect(entry == LedgerEntry(day: 3, amount: -270, category: .contracts, label: "TestCo"))

        // The next daily sweep returns the worker to idle.
        Reducer.tick(&state, balance: balance, content: content)
        #expect(try #require(state.employees.first).assignment == .idle)
    }

    @Test func sweepResetsAssignmentsToUnknownContracts() throws {
        let balance = TestBalance.standard
        var state = GameState.newGame(companyName: "Acme", seed: 46, balance: balance)
        let founderID = try #require(state.employees.first).id
        Reducer.apply(
            .assign(employeeID: founderID, to: .contract(UUID())),
            to: &state, balance: balance, content: content
        )

        // The assignment sticks until the next daily sweep clears it.
        guard case .contract = try #require(state.employees.first).assignment else {
            Issue.record("expected the contract assignment to stick until the sweep")
            return
        }
        Reducer.tick(&state, balance: balance, content: content)
        #expect(try #require(state.employees.first).assignment == .idle)
    }
}
