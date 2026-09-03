import Foundation
import Testing
import TycoonContent
@testable import TycoonEngine

/// "Build It For Them": a rival pays for a white-label job, and on
/// delivery ships what you built into its own category.
@Suite("Sponsored contracts")
struct SponsoredContractTests {
    // MARK: - The two fields

    @Test func offerAndJobCarryTheirTopicAndSponsorThroughASave() throws {
        let rivalID = UUID()
        let offer = ContractOffer(
            id: UUID(), clientName: "Northwind Software",
            requiredCodePts: 60, requiredDesignPts: 40,
            payout: 9_000, penalty: 2_700, deadlineDays: 40, expiresDay: 63,
            requiredSkill: 52, topicID: "fitness", sponsorRivalID: rivalID
        )
        #expect(offer.isSponsored)
        let offerData = try JSONEncoder().encode(offer)
        let decodedOffer = try JSONDecoder().decode(ContractOffer.self, from: offerData)
        #expect(decodedOffer == offer)
        #expect(decodedOffer.topicID == "fitness")
        #expect(decodedOffer.sponsorRivalID == rivalID)

        let job = ContractJob(
            id: offer.id, clientName: offer.clientName,
            requiredCodePts: 60, requiredDesignPts: 40,
            progressCode: 10, progressDesign: 5,
            deadlineDay: 96, payout: 9_000, penalty: 2_700, acceptedDay: 56,
            requiredSkill: 52, skillDaySum: 100, skillDays: 2,
            topicID: "fitness", sponsorRivalID: rivalID
        )
        #expect(job.isSponsored)
        let jobData = try JSONEncoder().encode(job)
        let decodedJob = try JSONDecoder().decode(ContractJob.self, from: jobData)
        #expect(decodedJob == job)
        #expect(decodedJob.topicID == "fitness")
        #expect(decodedJob.sponsorRivalID == rivalID)
    }

    /// A save written before this iteration has neither key, and an
    /// ordinary offer written after it encodes neither: both read back as
    /// a plain client job.
    @Test func aSaveWithoutTheFieldsDecodesAsAnOrdinaryJob() throws {
        let plainOffer = ContractOffer(
            id: UUID(), clientName: "Herring & Hound Legal",
            requiredCodePts: 49, requiredDesignPts: 13,
            payout: 3_305, penalty: 992, deadlineDays: 25, expiresDay: 14, requiredSkill: 53
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(plainOffer)
        let text = try #require(String(data: data, encoding: .utf8))
        #expect(!text.contains("topicID"))
        #expect(!text.contains("sponsorRivalID"))

        var object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        object.removeValue(forKey: "topicID")
        object.removeValue(forKey: "sponsorRivalID")
        let legacy = try JSONSerialization.data(withJSONObject: object)
        let decoded = try JSONDecoder().decode(ContractOffer.self, from: legacy)
        #expect(decoded == plainOffer)
        #expect(!decoded.isSponsored)
        #expect(decoded.topicID == nil)

        let job = ContractJob(
            id: plainOffer.id, clientName: plainOffer.clientName,
            requiredCodePts: 49, requiredDesignPts: 13,
            progressCode: 0, progressDesign: 0,
            deadlineDay: 39, payout: 3_305, penalty: 992, acceptedDay: 14, requiredSkill: 53
        )
        var jobObject = try #require(
            try JSONSerialization.jsonObject(with: try encoder.encode(job)) as? [String: Any]
        )
        #expect(jobObject["topicID"] == nil)
        jobObject.removeValue(forKey: "sponsorRivalID")
        let decodedJob = try JSONDecoder().decode(
            ContractJob.self, from: try JSONSerialization.data(withJSONObject: jobObject)
        )
        #expect(decodedJob == job)
        #expect(!decodedJob.isSponsored)
    }

    @Test func acceptingASponsoredOfferCarriesTheTopicAndSponsorOntoTheJob() throws {
        let balance = TestBalance.standard
        let content = TestContent.tiny()
        var state = GameState.newGame(companyName: "Acme", seed: 5, balance: balance)
        let rivalID = UUID()
        let offer = ContractOffer(
            id: UUID(), clientName: "Northwind Software",
            requiredCodePts: 60, requiredDesignPts: 40,
            payout: 9_000, penalty: 2_700, deadlineDays: 40, expiresDay: 7,
            requiredSkill: 52, topicID: "testing", sponsorRivalID: rivalID
        )
        state.contractOffers = [offer]

        Reducer.apply(.acceptContract(offerID: offer.id), to: &state, balance: balance, content: content)

        let job = try #require(state.activeContract(id: offer.id))
        #expect(job.topicID == "testing")
        #expect(job.sponsorRivalID == rivalID)
        #expect(job.isSponsored)
    }

    // MARK: - The roll

    private static let content = TestContent.bundled

    /// The shipped balance with the field sized and the sponsor roll
    /// pinned, so a test about the roll is not a test about luck.
    private static func balance(rivalCount: Int, sponsorChance: Double) throws -> BalanceConfig {
        var balance = try BalanceConfig.loadBundled()
        balance.rivals.rivalCount = rivalCount
        balance.sponsoredContracts.sponsorChance = sponsorChance
        return balance
    }

    private static func encoded(_ state: GameState) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(state)
    }

    /// The neutrality argument, run rather than argued: with no rival in
    /// the world the roll never draws, so a game with the feature on is
    /// byte-identical to one with it off — which is what the pacing
    /// suite measures at `rivalCount = 0`.
    @Test func noRivalMeansNoSponsoredOfferEverAndAnUntouchedGame() throws {
        let on = try Self.balance(rivalCount: 0, sponsorChance: 1)
        var off = on
        off.sponsoredContracts.sponsorChance = 0
        var a = GameState.newGame(companyName: "Acme", seed: 4_242, balance: on)
        var b = GameState.newGame(companyName: "Acme", seed: 4_242, balance: off)
        for _ in 0..<400 {
            Reducer.tick(&a, balance: on, content: Self.content)
            Reducer.tick(&b, balance: off, content: Self.content)
            #expect(a.contractOffers.allSatisfy { !$0.isSponsored })
        }
        #expect(a.rivals.rivals.isEmpty)
        #expect(a == b)
        #expect(try Self.encoded(a) == Self.encoded(b))
    }

    @Test func aSponsorCallsFromWeekEightAndAtMostOncePerSheet() throws {
        let balance = try Self.balance(rivalCount: 4, sponsorChance: 1)
        var state = GameState.newGame(companyName: "Acme", seed: 4_242, balance: balance)
        var sponsoredSheets = 0
        for _ in 0..<200 {
            Reducer.tick(&state, balance: balance, content: Self.content)
            guard state.day % balance.contractOfferRefreshDays == 0 else { continue }
            let sponsored = state.contractOffers.filter(\.isSponsored)
            if state.day < balance.sponsoredContracts.earliestDay {
                #expect(sponsored.isEmpty, "a sponsor called on day \(state.day)")
                continue
            }
            #expect(sponsored.count == 1, "day \(state.day) had \(sponsored.count) sponsored offers")
            #expect(state.contractOffers.count == balance.contractOfferCount)
            guard let offer = sponsored.first,
                  let rivalID = offer.sponsorRivalID,
                  let rival = state.rivals.rival(id: rivalID),
                  let topicID = offer.topicID
            else { continue }
            sponsoredSheets += 1
            #expect(offer.clientName == rival.name)
            // Nothing held yet, so the topic is one of the sponsor's own.
            #expect(rival.focusTopicIDs.contains(topicID))
            #expect(Self.content.topic(topicID) != nil)
            let expectedSkill = min(
                balance.contractQuality.skillCap,
                rival.strength * balance.sponsoredContracts.skillPerStrength
                    + balance.sponsoredContracts.skillBase
            )
            #expect(abs(offer.requiredSkill - expectedSkill) < 1e-9)
            #expect(offer.penalty == Int((balance.contractPenaltyFraction * Double(offer.payout)).rounded()))
            #expect(offer.expiresDay == state.day + balance.contractOfferRefreshDays)
        }
        // Days 56, 63, …, 196: twenty-one sheets.
        #expect(sponsoredSheets == 21)
    }

    /// The sharp version: when the player holds a category, the sponsor
    /// can ask for that one.
    @Test func theSharpVersionNamesTheTopicYouHold() throws {
        var balance = try Self.balance(rivalCount: 4, sponsorChance: 1)
        balance.sponsoredContracts.playerTopicChance = 1
        var state = GameState.newGame(companyName: "Acme", seed: 7, balance: balance)
        state.market.standing = ["fitness": 62, "finance": 30]
        state.day = balance.sponsoredContracts.earliestDay - 1

        Reducer.tick(&state, balance: balance, content: Self.content)

        #expect(state.day == balance.sponsoredContracts.earliestDay)
        let sponsored = state.contractOffers.filter(\.isSponsored)
        #expect(sponsored.count == 1)
        #expect(sponsored.first?.topicID == "fitness")

        // And never when the player holds nothing, whatever the chance.
        var bare = GameState.newGame(companyName: "Acme", seed: 7, balance: balance)
        bare.day = balance.sponsoredContracts.earliestDay - 1
        Reducer.tick(&bare, balance: balance, content: Self.content)
        let bareOffer = try #require(bare.contractOffers.first { $0.isSponsored })
        let sponsorID = try #require(bareOffer.sponsorRivalID)
        let sponsor = try #require(bare.rivals.rival(id: sponsorID))
        let bareTopic = try #require(bareOffer.topicID)
        #expect(sponsor.focusTopicIDs.contains(bareTopic))
    }

    /// The roll draws from `worldRNG` only: the main stream, every other
    /// offer on the sheet, and the sponsored offer's own point pools are
    /// exactly what they would have been without a sponsor.
    @Test func theSponsoredRollLeavesTheMainStreamAlone() throws {
        let on = try Self.balance(rivalCount: 4, sponsorChance: 1)
        var off = on
        off.sponsoredContracts.sponsorChance = 0
        var a = GameState.newGame(companyName: "Acme", seed: 4_242, balance: on)
        var b = GameState.newGame(companyName: "Acme", seed: 4_242, balance: off)
        for _ in 0..<on.sponsoredContracts.earliestDay {
            Reducer.tick(&a, balance: on, content: Self.content)
            Reducer.tick(&b, balance: off, content: Self.content)
        }

        #expect(a.rng == b.rng)
        #expect(a.contractOffers.map(\.id) == b.contractOffers.map(\.id))
        let sponsored = try #require(a.contractOffers.first { $0.isSponsored })
        for (x, y) in zip(a.contractOffers, b.contractOffers) where !x.isSponsored {
            #expect(x == y)
        }
        let base = try #require(b.contractOffers.first { $0.id == sponsored.id })
        #expect(sponsored.requiredCodePts == base.requiredCodePts)
        #expect(sponsored.requiredDesignPts == base.requiredDesignPts)
        #expect(sponsored.payout == Int((Double(base.payout) * on.sponsoredContracts.payoutFactor).rounded()))
        #expect(sponsored.deadlineDays == Int((Double(base.deadlineDays) * on.sponsoredContracts.deadlineFactor).rounded(.up)))
        #expect(sponsored.payout > base.payout)
        #expect(sponsored.deadlineDays > base.deadlineDays)
        // The world stream moved; the rivals themselves did not (the roll
        // runs after `RivalSystem` on the same tick).
        #expect(a.worldRNG != b.worldRNG)
        #expect(a.rivals == b.rivals)
    }
}
