import Foundation
import Testing
import TycoonContent
import TycoonEngine

@Suite("Full-loop determinism")
struct FullLoopDeterminismTests {
    /// Runs 400 ticks with a fixed action script: start dating and plan
    /// date nights on day 2, start a product on day 3, hire the first
    /// candidate on day 15 (the pool refreshes on day 14), refocus on day
    /// 20, park the hire on research on day 30, put them back on the
    /// product on day 40, ship on day 60 (well past the code gate), move in
    /// with the partner on day 61 (59 days of dating at maxed
    /// relationships), move everyone to research on day 70, start
    /// "code_reviews" on day 71 (the day-30..40 banked RP pours in and
    /// daily RP completes it), start "press_kit" on day 73 (unlocking press
    /// releases), start a second product on day 90 (nobody is idle, so it
    /// idles at zero progress), run a social push on day 91 and a press
    /// release on day 92, crunch from day 100, accept a fresh contract offer
    /// on day 105 and put both employees on it (it completes well before
    /// its deadline), upgrade the office to the loft on day 130 (sales
    /// revenue covers the cost long before then), drop back to a normal
    /// schedule and start paying the founder on day 131, book a vacation on
    /// day 142 (it fires on day 147 and the founder is back on day 154),
    /// build a game room on day 132 (the loft unlocks it), start
    /// "version_control" on day 200 (by then banked RP covers its cost, so
    /// it completes immediately on start), accept another offer on day 210
    /// that nobody works — it dies at its deadline — and move into an
    /// apartment on day 390 (the salary covers it by then). From day 131
    /// on, the first lawyer and the first QA engineer to show up in a
    /// candidate pool are hired (the loft lets lawyers roll; the hires
    /// join whatever is in development), forming the Legal department.
    /// From day 62 on, every Monday plans the weekend on a three-week
    /// rotation (date night, rest, rest — with gym replacing the rests
    /// during weeks 23...34) so the founder never burns out or drifts into
    /// a breakup. Random events roll every 30 days and life events every
    /// 14 days throughout.
    private func runScript(seed: UInt64) throws -> Data {
        // The script's day-numbered choreography predates rivals; disable
        // them so poaches don't rewrite the cast mid-script.
        var balance = try BalanceConfig.loadBundled()
        balance.rivals.rivalCount = 0
        let content = TestContent.bundled
        var state = GameState.newGame(companyName: "Determined", seed: seed, balance: balance)
        // The script is about draw order and event choreography, not about
        // affording the loft: under the economy pass this studio cannot pay
        // for the day-130 upgrade on its own, and without the loft there are
        // no lawyers on the sheet and half the choreography never fires.
        // A founding grant takes money out of the equation entirely, so the
        // script tests what it is for; being applied on both runs, it keeps
        // them byte-identical.
        state.company.cash += 1_000_000
        var productID: UUID?
        var secondProductID: UUID?
        var hiredID: UUID?
        var lawyerID: UUID?
        var qaID: UUID?
        var workedContractID: UUID?
        var abandonedContractID: UUID?

        for _ in 0..<400 {
            Reducer.tick(&state, balance: balance, content: content)

            // The weekend rotation, planned the day after each weekend.
            if state.day >= 62, state.day % 7 == 1 {
                let week = state.day / 7
                let plan: WeekendActivity = switch week % 3 {
                case 0: .dateNight
                default: (23...34).contains(week) ? .gym : .rest
                }
                Reducer.apply(.planWeekend(plan), to: &state, balance: balance, content: content)
            }

            // Scripted candidate picks once the loft is in: the first
            // lawyer and the first QA engineer on any sheet.
            if state.day >= 131 {
                if lawyerID == nil, let lawyer = state.candidatePool.first(where: { $0.role == .lawyer }) {
                    Reducer.apply(.hire(candidateID: lawyer.id), to: &state, balance: balance, content: content)
                    lawyerID = lawyer.id
                }
                if qaID == nil, let qa = state.candidatePool.first(where: { $0.role == .qa }) {
                    Reducer.apply(.hire(candidateID: qa.id), to: &state, balance: balance, content: content)
                    qaID = qa.id
                }
            }

            switch state.day {
            case 2:
                Reducer.apply(.advanceRelationship, to: &state, balance: balance, content: content)
                Reducer.apply(.planWeekend(.dateNight), to: &state, balance: balance, content: content)
            case 3:
                Reducer.apply(
                    .startProduct(typeID: "mobile_app", topicID: "fitness", name: "FitTrack", focus: .balanced),
                    to: &state, balance: balance, content: content
                )
                productID = state.productInDevelopment?.id
            case 15:
                let candidateID = try #require(state.candidatePool.first).id
                Reducer.apply(
                    .hire(candidateID: candidateID),
                    to: &state, balance: balance, content: content
                )
                hiredID = candidateID
            case 20:
                let id = try #require(productID)
                Reducer.apply(
                    .setPhaseFocus(productID: id, focus: PhaseFocus(design: 1, code: 3, polish: 1)),
                    to: &state, balance: balance, content: content
                )
            case 30:
                Reducer.apply(
                    .assign(employeeID: try #require(hiredID), to: .research),
                    to: &state, balance: balance, content: content
                )
            case 40:
                Reducer.apply(
                    .assign(employeeID: try #require(hiredID), to: .product(try #require(productID))),
                    to: &state, balance: balance, content: content
                )
            case 60:
                let id = try #require(productID)
                Reducer.apply(.ship(productID: id), to: &state, balance: balance, content: content)
            case 61:
                Reducer.apply(.advanceRelationship, to: &state, balance: balance, content: content)
            case 70:
                let founderID = try #require(state.employees.first).id
                Reducer.apply(
                    .assign(employeeID: founderID, to: .research),
                    to: &state, balance: balance, content: content
                )
                Reducer.apply(
                    .assign(employeeID: try #require(hiredID), to: .research),
                    to: &state, balance: balance, content: content
                )
            case 71:
                Reducer.apply(
                    .startResearch(nodeID: "code_reviews"),
                    to: &state, balance: balance, content: content
                )
            case 73:
                Reducer.apply(
                    .startResearch(nodeID: "press_kit"),
                    to: &state, balance: balance, content: content
                )
            case 90:
                Reducer.apply(
                    .startProduct(typeID: "web_app", topicID: "social", name: "Buzzly", focus: .balanced),
                    to: &state, balance: balance, content: content
                )
                secondProductID = state.productInDevelopment?.id
            case 91:
                Reducer.apply(
                    .startCampaign(kindID: "social_push", productID: try #require(secondProductID)),
                    to: &state, balance: balance, content: content
                )
            case 92:
                Reducer.apply(
                    .startCampaign(kindID: "press_release", productID: try #require(secondProductID)),
                    to: &state, balance: balance, content: content
                )
            case 100:
                Reducer.apply(.setWorkSchedule(.crunch), to: &state, balance: balance, content: content)
            case 130:
                Reducer.apply(.upgradeOffice, to: &state, balance: balance, content: content)
            case 131:
                Reducer.apply(.setWorkSchedule(.normal), to: &state, balance: balance, content: content)
                Reducer.apply(.setFounderSalary(500), to: &state, balance: balance, content: content)
            case 132:
                Reducer.apply(.buildAmenity(.gameRoom), to: &state, balance: balance, content: content)
            case 142:
                Reducer.apply(.planWeekend(.vacation), to: &state, balance: balance, content: content)
            case 390:
                Reducer.apply(.upgradeHome, to: &state, balance: balance, content: content)
            case 105:
                let offerID = try #require(state.contractOffers.first).id
                Reducer.apply(
                    .acceptContract(offerID: offerID),
                    to: &state, balance: balance, content: content
                )
                workedContractID = offerID
                let founderID = try #require(state.employees.first).id
                Reducer.apply(
                    .assign(employeeID: founderID, to: .contract(offerID)),
                    to: &state, balance: balance, content: content
                )
                Reducer.apply(
                    .assign(employeeID: try #require(hiredID), to: .contract(offerID)),
                    to: &state, balance: balance, content: content
                )
            case 200:
                Reducer.apply(
                    .startResearch(nodeID: "version_control"),
                    to: &state, balance: balance, content: content
                )
            case 210:
                let offerID = try #require(state.contractOffers.first).id
                Reducer.apply(
                    .acceptContract(offerID: offerID),
                    to: &state, balance: balance, content: content
                )
                abandonedContractID = offerID
            default:
                break
            }
        }

        // Sanity: the script really hired, shipped, and the product sold.
        guard case .released(let info) = try #require(state.products.first).stage else {
            Issue.record("the scripted product must be released by day 400")
            throw CancellationError()
        }
        #expect(info.launchDay == 60)
        #expect(!info.weeklySales.isEmpty)
        #expect(state.eventLog.contains(.shipped(productID: try #require(productID), day: 60)))
        // Four hires land, and one of them leaves: with WS-A's morale rules
        // and WS-F's traits both live, Ingrid serves notice on day 136 and
        // walks on 143 because the script never answers it. That is the
        // game working, so the sanity check is "four arrived, three stayed".
        #expect(state.employees.count == 3)
        #expect(state.eventLog.contains { if case .resignationNotice = $0 { true } else { false } })
        #expect(state.eventLog.contains { if case .employeeQuit = $0 { true } else { false } })
        #expect(state.eventLog.contains(.hired(employeeID: try #require(hiredID), day: 15)))
        #expect(state.eventLog.contains(.candidatesRefreshed(day: 14)))

        // Sanity: the scripted lawyer and QA picks landed, Legal formed on
        // the tick after the lawyer arrived, and the game room went up.
        let lawyerHireID = try #require(lawyerID)
        let qaHireID = try #require(qaID)
        let lawyer = try #require(state.employee(id: lawyerHireID))
        let qa = try #require(state.employee(id: qaHireID))
        #expect(lawyer.role == .lawyer)
        #expect(qa.role == .qa)
        #expect(lawyer.hiredDay >= 131)
        #expect(qa.hiredDay >= 131)
        #expect(state.eventLog.contains(.departmentFormed(department: .legal, day: lawyer.hiredDay + 1)))
        #expect(state.activeDepartments == [.legal])
        #expect(state.knownDepartments == [.legal])
        #expect(state.eventLog.contains(.amenityBuilt(amenity: .gameRoom, day: 132)))
        #expect(state.amenities == [.gameRoom])
        #expect(state.ledger.entries.contains { $0.label == "Amenities" && $0.amount == -150 })

        // Sanity: all scripted research nodes started and completed.
        #expect(state.eventLog.contains(.researchStarted(nodeID: "code_reviews", day: 71)))
        #expect(state.eventLog.contains(.researchStarted(nodeID: "press_kit", day: 73)))
        #expect(state.eventLog.contains(.researchStarted(nodeID: "version_control", day: 200)))
        #expect(state.research.unlocked.contains("code_reviews"))
        #expect(state.research.unlocked.contains("press_kit"))
        #expect(state.research.unlocked.contains("version_control"))
        #expect(state.eventLog.contains(.researchCompleted(nodeID: "version_control", day: 200)))
        #expect(state.research.activeNodeID == nil)
        #expect(state.research.banked > 0)

        // Sanity: offers refreshed weekly (the final sheet carries Legal's
        // extra offer), both campaigns ran, the worked contract completed,
        // and the abandoned one failed at its deadline.
        #expect(state.eventLog.contains(.contractOffersRefreshed(day: 7)))
        #expect(state.contractOffers.count == 4)
        let campaignStarts = state.eventLog.filter {
            if case .campaignStarted = $0 { return true }
            return false
        }
        #expect(campaignStarts.count == 2)
        // The press release stays in the log as history; the expired social
        // push was removed by the marketing sweep.
        #expect(state.campaigns.count == 1)
        #expect(state.campaigns.first?.kindID == "press_release")
        #expect(state.campaigns.first?.endDay == 92)

        let workedID = try #require(workedContractID)
        let abandonedID = try #require(abandonedContractID)
        #expect(state.eventLog.contains(.contractAccepted(contractID: workedID, day: 105)))
        #expect(state.eventLog.contains(.contractAccepted(contractID: abandonedID, day: 210)))
        #expect(state.eventLog.contains { event in
            if case .contractDelivered(let id, _, _, _) = event { return id == workedID }
            return false
        })
        #expect(state.eventLog.contains { event in
            if case .contractFailed(let id, _, _) = event { return id == abandonedID }
            return false
        })
        #expect(state.activeContracts.isEmpty)

        // Sanity: the day-130 upgrade landed (the first product's sales and
        // the worked contract leave cash far above the loft cost by then)
        // and at least one random event fired across the 13 interval rolls.
        #expect(state.eventLog.contains(.officeUpgraded(tier: .loft, day: 130)))
        #expect(state.company.officeTier == .loft)
        #expect(state.milestonesReached == ["loft"])
        let randomEventCount = state.eventLog.filter {
            if case .randomEvent = $0 { return true }
            return false
        }.count
        #expect(randomEventCount >= 1)

        // Sanity: the founder's life played out as scripted — the two
        // relationship steps, the vacation (away and back), the crunch
        // block, the salary, the apartment, at least one life event out of
        // 28 rolls, and no burnout, hospital stay, breakup, or bankruptcy.
        #expect(state.eventLog.contains(.relationshipChanged(stage: .dating, day: 2)))
        #expect(state.eventLog.contains(.relationshipChanged(stage: .partner, day: 61)))
        #expect(state.life.family.stage == .partner)
        #expect(state.life.family.partnerName != nil)
        #expect(state.eventLog.contains(.weekendSpent(activity: .vacation, day: 147)))
        #expect(state.eventLog.contains(.founderAway(reason: "Vacation", untilDay: 154, day: 147)))
        #expect(state.eventLog.contains(.founderBack(day: 154)))
        #expect(state.life.schedule == .normal)
        #expect(state.life.founderSalary == 500)
        #expect(state.ledger.entries.contains { $0.label == "Founder salary" })
        #expect(state.eventLog.contains(.homeUpgraded(tier: .apartment, day: 390)))
        #expect(state.life.home == .apartment)
        let lifeEventCount = state.eventLog.filter {
            if case .lifeEvent = $0 { return true }
            return false
        }.count
        #expect(lifeEventCount >= 1)
        // Random life events may send the founder away (that's fine), but
        // the schedule rotation must keep the run clear of burnout,
        // hospital stays, breakups, and bankruptcy.
        #expect(!state.eventLog.contains { event in
            switch event {
            case .founderAway(let reason, _, _): reason == "Burnout" || reason == "Hospital"
            case .breakup, .gameOver: true
            default: false
            }
        })

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(state)
    }

    @Test func sameSeedAndScriptProduceByteIdenticalJSONOver400Ticks() throws {
        let first = try runScript(seed: 424_242)
        let second = try runScript(seed: 424_242)
        #expect(first == second)
    }
}
