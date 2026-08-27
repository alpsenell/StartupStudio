import Foundation
import Testing
import TycoonContent
@testable import TycoonEngine

/// The industry-news drumbeat: a weekly headline about the world outside the
/// studio, rendered from `News.json` templates against the live rivals,
/// topics and product words. Flavor only — it changes nothing, never
/// pauses, and draws exclusively from the world RNG.
@Suite("Industry news")
struct IndustryNewsTests {
    private static func balance(
        interval: Int = 7,
        chance: Double = 1.0
    ) -> BalanceConfig {
        var config = TestBalance.make(
            startingCash: 1_000_000,
            weeklyOperatingCost: 0,
            candidateRefreshDays: 10_000,
            contractOfferRefreshDays: 10_000,
            eventChance: 0,
            life: TestBalance.quietLife
        )
        config.narrative = BalanceConfig.NarrativeBalance(
            newsIntervalDays: interval, newsChance: chance
        )
        return config
    }

    private static func catalog(_ news: [NewsTemplate], productWords: [String] = []) -> ContentCatalog {
        let tiny = TestContent.tiny()
        return ContentCatalog(
            productTypes: tiny.productTypes,
            topics: tiny.topics,
            techTree: tiny.techTree,
            events: tiny.events,
            names: NamePools(
                firstNames: ["Ada"], lastNames: ["Lovelace"], clientCompanies: ["TestCo"],
                partnerNames: ["Sam"], childNames: ["Kit"],
                rivalStudios: ["Lumen Labs"], productWords: productWords
            ),
            lifeEvents: tiny.lifeEvents,
            news: news
        )
    }

    private func headlines(_ events: [GameEvent]) -> [String] {
        events.compactMap {
            if case .industryNews(let headline, _) = $0 { return headline }
            return nil
        }
    }

    @Test("a headline lands on the interval and never pauses")
    func headlineOnInterval() {
        let balance = Self.balance()
        let content = Self.catalog([
            NewsTemplate(id: "plain", template: "Conference season starts.")
        ])
        var state = GameState.newGame(companyName: "Acme", seed: 3, balance: balance)

        var found: [String] = []
        for _ in 0..<21 {
            let events = Reducer.tick(&state, balance: balance, content: content)
            found.append(contentsOf: headlines(events))
            for event in events {
                if case .industryNews = event {
                    #expect(!event.pausesTimeline)
                    #expect(event.severity == .quiet)
                }
            }
        }
        #expect(found.count == 3, "one a week for three weeks")
        #expect(found.allSatisfy { $0 == "Conference season starts." })
    }

    @Test("placeholders are filled from the live world")
    func placeholdersFilled() {
        let balance = Self.balance()
        let content = Self.catalog(
            [NewsTemplate(id: "slots", template: "{rival} ships {product} in {topic}: {adjective}, {number}%.")],
            productWords: ["Nimbus", "Ledger", "Atlas"]
        )
        var state = GameState.newGame(companyName: "Acme", seed: 9, balance: balance)
        state.rivals.rivals = [
            Rival(
                id: UUID(uuidString: "00000000-0000-4000-8000-000000000001")!,
                name: "Lumen Labs", strength: 40, reputation: 50,
                focusTopicIDs: ["testing"], foundedDay: 0, appearanceSeed: 1
            )
        ]

        var headline: String?
        for _ in 0..<8 {
            let found = headlines(Reducer.tick(&state, balance: balance, content: content))
            if let first = found.first { headline = first; break }
        }
        let text = headline ?? ""
        #expect(text.hasPrefix("Lumen Labs ships "))
        #expect(!text.contains("{"), "every placeholder was filled: \(text)")
        #expect(text.contains("testing") || text.contains("Testing"))
    }

    @Test("rival-only templates are skipped while the player has no rivals")
    func rivalTemplatesNeedRivals() {
        let balance = Self.balance()
        let content = Self.catalog([
            NewsTemplate(id: "rivalOnly", template: "{rival} ships something.", needsRival: true)
        ])
        var state = GameState.newGame(companyName: "Acme", seed: 4, balance: balance)
        #expect(state.rivals.rivals.isEmpty)

        var found: [String] = []
        for _ in 0..<30 {
            found.append(contentsOf: headlines(Reducer.tick(&state, balance: balance, content: content)))
        }
        #expect(found.isEmpty, "the world does not report on competitors you do not have")
    }

    @Test("an empty news catalog draws nothing at all")
    func emptyCatalogIsSilent() {
        let balance = Self.balance()
        let content = TestContent.tiny()
        var state = GameState.newGame(companyName: "Acme", seed: 4, balance: balance)
        var reference = state

        for _ in 0..<30 {
            Reducer.tick(&state, balance: balance, content: content)
            Reducer.tick(&reference, balance: balance, content: content)
        }
        #expect(state.worldRNG == reference.worldRNG)
        #expect(state.narrative.lastNewsDay == -1_000)
    }

    @Test("the shipped catalog has enough variety for a three-year run")
    func shippedCatalogVariety() throws {
        let content = TestContent.bundled
        #expect(content.news.count >= 40)
        let ids = content.news.map(\.id)
        #expect(Set(ids).count == ids.count, "duplicate news ids")
        let templates = content.news.map(\.template)
        #expect(Set(templates).count == templates.count, "duplicate headlines")
        #expect(content.names.rivalStudios.count >= 40)
        #expect(content.names.productWords.count >= 40)
        #expect(Set(content.names.rivalStudios).count == content.names.rivalStudios.count)
        #expect(Set(content.names.productWords).count == content.names.productWords.count)
        // No rival-free template may reference a rival.
        for template in content.news where !template.needsRival {
            #expect(!template.template.contains("{rival}"), "\(template.id) needs needsRival")
        }
    }

    @Test("three years of news rarely repeats a headline")
    func threeYearsOfVariety() {
        var balance = Self.balance(interval: 7, chance: 1.0)
        balance.rivals = BalanceConfig.RivalBalance.standard
        let content = TestContent.bundled
        var state = GameState.newGame(companyName: "Acme", seed: 77, balance: balance)

        var found: [String] = []
        for _ in 0..<1_092 {
            found.append(contentsOf: headlines(Reducer.tick(&state, balance: balance, content: content)))
        }
        #expect(found.count >= 100)
        let distinct = Set(found)
        #expect(
            Double(distinct.count) / Double(found.count) > 0.55,
            "\(distinct.count) distinct out of \(found.count)"
        )
    }
}
