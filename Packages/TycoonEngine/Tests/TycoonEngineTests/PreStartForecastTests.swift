import Foundation
import Testing
import TycoonContent
@testable import TycoonEngine

/// The forecast before the first line of code, the split that matches the
/// work, and the snapshot a release keeps for launch day.
@Suite("Pre-start forecast")
struct PreStartForecastTests {
    @MainActor
    private func fresh() -> (state: GameState, balance: BalanceConfig, content: ContentCatalog) {
        let engine = GameEngine.newGame(companyName: "Forecast Ltd", seed: 4242)
        return (engine.state, engine.balance, engine.content)
    }

    @MainActor
    @Test func theCrewCeilingBeforeStartEqualsTheCeilingOnDayOne() throws {
        var (state, balance, content) = fresh()
        let type = try #require(content.productTypes.first {
            state.isProductTypeUnlocked($0.id, content: content)
        })
        let topic = try #require(content.topics.first)

        let before = try #require(ShipForecast.preStart(
            typeID: type.id, topicID: topic.id, codebaseID: nil,
            state: state, balance: balance, content: content
        ))
        #expect(before.bugFactor == 1)
        #expect(before.marketScale == 1)
        #expect(before.quality == before.crewCeiling * 100)

        _ = Reducer.apply(
            .startProduct(typeID: type.id, topicID: topic.id, name: "Overcast", focus: .balanced),
            to: &state, balance: balance, content: content
        )
        _ = Reducer.tick(&state, balance: balance, content: content)
        let product = try #require(state.productInDevelopment)
        let dayOne = try #require(state.shipForecast(productID: product.id, balance: balance, content: content))

        // The same crew, the same arithmetic: the ceilings agree.
        #expect(abs(dayOne.skillCeiling - before.skillCeiling) < 0.0001)
        #expect(abs(dayOne.crewCeiling - before.crewCeiling) < 0.0001)
        #expect(dayOne.topicFit == before.topicFit)
    }

    @MainActor
    @Test func aPoorTopicLowersThePreStartNumber() throws {
        let (state, balance, content) = fresh()
        let type = try #require(content.productTypes.first {
            state.isProductTypeUnlocked($0.id, content: content)
        })
        let numbers = content.topics.map { topic -> (fit: Double, quality: Double) in
            let forecast = ShipForecast.preStart(
                typeID: type.id, topicID: topic.id, codebaseID: nil,
                state: state, balance: balance, content: content
            )!
            return (forecast.topicFit, forecast.quality)
        }
        // Wherever the catalog dislikes a pairing, the number says so.
        for (fit, quality) in numbers where fit < 1 {
            #expect(quality < numbers.map(\.quality).max()!)
        }
    }

    @MainActor
    @Test func matchingWeightsEachPoolByWhatItStillNeeds() throws {
        let (_, _, content) = fresh()
        let type = try #require(content.productTypes.first)
        let fresh = DevProgress(designPts: 0, codePts: 0, polishPts: 0, openBugs: 0, focus: .balanced, hype: 0)
        let atStart = PhaseFocus.matching(progress: fresh, type: type)
        #expect(atStart.design == type.designPts && atStart.code == type.codePts && atStart.polish == type.polishPts)
        #expect(PhaseFocus.matching(type: type) == atStart)

        let designDone = DevProgress(
            designPts: type.designPts, codePts: type.codePts / 4, polishPts: 0, openBugs: 0, focus: .balanced, hype: 0)
        let later = PhaseFocus.matching(progress: designDone, type: type)
        #expect(later.design == 0)
        #expect(abs(later.code - type.codePts * 3 / 4) < 0.0001)
        #expect(later.polish == type.polishPts)

        let done = DevProgress(
            designPts: type.designPts, codePts: type.codePts, polishPts: type.polishPts, openBugs: 0, focus: .balanced, hype: 0)
        #expect(PhaseFocus.matching(progress: done, type: type) == .balanced)
    }

    @MainActor
    @Test func aReleaseKeepsTheForecastItShippedWith() throws {
        var (state, balance, content) = fresh()
        let type = try #require(content.productTypes.first {
            state.isProductTypeUnlocked($0.id, content: content)
        })
        let topic = try #require(content.topics.first)
        _ = Reducer.apply(
            .startProduct(typeID: type.id, topicID: topic.id, name: "Overcast", focus: .balanced),
            to: &state, balance: balance, content: content
        )
        let product = try #require(state.productInDevelopment)
        // Build until the code gate opens, then ship.
        var days = 0
        while days < 400 {
            _ = Reducer.tick(&state, balance: balance, content: content)
            days += 1
            if let forecast = state.shipForecast(productID: product.id, balance: balance, content: content),
               forecast.canShip { break }
        }
        let expected = try #require(state.shipForecast(productID: product.id, balance: balance, content: content))
        _ = Reducer.apply(.ship(productID: product.id), to: &state, balance: balance, content: content)
        guard case .released(let info)? = state.product(id: product.id)?.stage else {
            Issue.record("the product did not ship")
            return
        }
        let kept = try #require(info.launchForecast)
        #expect(abs(kept.crewCeiling - expected.crewCeiling) < 0.0001)
        #expect(kept.limitingFactor == expected.limitingFactor)
    }
}
