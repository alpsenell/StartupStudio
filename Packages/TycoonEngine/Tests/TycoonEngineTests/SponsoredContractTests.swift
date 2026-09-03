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
}
