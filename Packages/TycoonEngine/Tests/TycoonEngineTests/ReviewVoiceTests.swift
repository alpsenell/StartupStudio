import Foundation
import Testing
import TycoonContent
@testable import TycoonEngine

/// Review voices: four outlets with four personalities, eight blurbs per
/// band each, product-aware placeholders, and callouts earned by the ship
/// context rather than drawn for.
@Suite("Review voices")
struct ReviewVoiceTests {
    private let bands = ["dire", "poor", "mixed", "good", "stellar"]

    @Test("every outlet has a persona and eight blurbs in every band")
    func catalogIsComplete() throws {
        let balance = try BalanceConfig.loadBundled()
        let catalog = try #require(TestContent.bundled.reviews)
        #expect(catalog.outlets.count == balance.reviewOutlets.count)
        for outlet in balance.reviewOutlets {
            #expect(catalog.persona(outlet: outlet)?.isEmpty == false, "\(outlet) has no persona")
            for band in bands {
                let lines = try #require(catalog.blurbs(outlet: outlet, band: band))
                #expect(lines.count >= 8, "\(outlet)/\(band) has only \(lines.count)")
                #expect(Set(lines).count == lines.count, "\(outlet)/\(band) repeats a line")
            }
        }
    }

    @Test("each band has at least 32 distinct blurbs across the outlets")
    func bandBreadth() throws {
        let balance = try BalanceConfig.loadBundled()
        let catalog = try #require(TestContent.bundled.reviews)
        for band in bands {
            let all = balance.reviewOutlets.flatMap { catalog.blurbs(outlet: $0, band: band) ?? [] }
            #expect(all.count >= 32, "band \(band) has \(all.count)")
            #expect(Set(all).count == all.count, "band \(band) repeats across outlets")
        }
    }

    @Test("outlets do not share blurbs — the voices stay distinct")
    func voicesAreDistinct() throws {
        let catalog = try #require(TestContent.bundled.reviews)
        var seen: Set<String> = []
        for outlet in catalog.outlets {
            for lines in outlet.bands.values {
                for line in lines {
                    #expect(!seen.contains(line), "\(outlet.id) reuses \"\(line)\"")
                    seen.insert(line)
                }
            }
        }
    }

    @Test("placeholders are filled from the product")
    func placeholdersFilled() throws {
        let catalog = try #require(TestContent.bundled.reviews)
        let context = ReviewContext(
            productName: "FitTrack", typeName: "Mobile App", topicName: "Fitness",
            bugRatio: 0, polishRatio: 0.5, hype: 20, marketScale: 1
        )
        var rng = SeededRNG(seed: 1)
        for outlet in catalog.outlets {
            for band in bands {
                for _ in 0..<40 {
                    let score = Self.midScore(of: band)
                    let blurb = ReviewBlurbs.pick(
                        for: score, rng: &rng,
                        outlet: outlet.id, context: context, catalog: catalog
                    )
                    #expect(!blurb.contains("{"), "unfilled placeholder in \"\(blurb)\"")
                }
            }
        }
    }

    @Test("the callout names the thing that actually happened")
    func calloutsFollowContext() {
        let base = ReviewContext(
            productName: "X", typeName: "app", topicName: "fitness",
            bugRatio: 0, polishRatio: 0.5, hype: 20, marketScale: 1
        )
        var buggy = base
        buggy.bugRatio = 0.4
        #expect(ReviewBlurbs.callout(for: 50, context: buggy) == "buggy")

        var overpromised = base
        overpromised.hype = 70
        #expect(ReviewBlurbs.callout(for: 40, context: overpromised) == "overpromised")
        #expect(ReviewBlurbs.callout(for: 80, context: overpromised) == nil)

        var crowded = base
        crowded.marketScale = 0.4
        #expect(ReviewBlurbs.callout(for: 60, context: crowded) == "crowded")

        var polished = base
        polished.polishRatio = 1.0
        #expect(ReviewBlurbs.callout(for: 70, context: polished) == "polished")
        #expect(ReviewBlurbs.callout(for: 30, context: polished) == nil)

        var quiet = base
        quiet.hype = 2
        #expect(ReviewBlurbs.callout(for: 70, context: quiet) == "unnoticed")

        #expect(ReviewBlurbs.callout(for: 50, context: base) == nil)
    }

    @Test("a review costs exactly one RNG word, with or without content")
    func drawBudgetUnchanged() throws {
        let catalog = try #require(TestContent.bundled.reviews)
        let context = ReviewContext(
            productName: "X", typeName: "app", topicName: "fitness",
            bugRatio: 0.4, polishRatio: 1, hype: 60, marketScale: 0.4
        )
        var withContent = SeededRNG(seed: 88)
        var without = SeededRNG(seed: 88)
        var plain = SeededRNG(seed: 88)
        _ = ReviewBlurbs.pick(
            for: 30, rng: &withContent, outlet: "TechDaily", context: context, catalog: catalog
        )
        _ = ReviewBlurbs.pick(for: 30, rng: &without)
        _ = plain.next()
        #expect(withContent == plain)
        #expect(without == plain)
    }

    @Test("an unknown outlet or an empty catalog falls back to the built-in bands")
    func fallback() {
        var rng = SeededRNG(seed: 5)
        let unknown = ReviewBlurbs.pick(
            for: 90, rng: &rng, outlet: "Nowhere Weekly", catalog: ReviewCatalog.empty
        )
        #expect(!unknown.isEmpty)
        #expect(!unknown.contains("{"))
    }

    @Test("a shipped product's four reviews read as four different outlets")
    func shipUsesTheVoices() throws {
        let balance = try BalanceConfig.loadBundled()
        let content = TestContent.bundled
        var state = GameState.newGame(companyName: "Acme", seed: 21, balance: balance)
        Reducer.apply(
            .startProduct(
                typeID: "mobile_app", topicID: "fitness", name: "FitTrack",
                focus: PhaseFocus(design: 0, code: 1, polish: 0)
            ),
            to: &state, balance: balance, content: content
        )
        let id = state.products[0].id
        for _ in 0..<28 { Reducer.tick(&state, balance: balance, content: content) }
        Reducer.apply(.ship(productID: id), to: &state, balance: balance, content: content)

        guard case .released(let info) = try #require(state.products.first).stage else {
            Issue.record("expected a released stage")
            return
        }
        #expect(info.reviews.count == 4)
        let catalog = try #require(content.reviews)
        for review in info.reviews {
            #expect(!review.blurb.contains("{"))
            let band = ReviewBlurbs.band(for: review.score)
            let own = catalog.blurbs(outlet: review.outlet, band: band) ?? []
            #expect(
                own.contains(where: { review.blurb.hasPrefix(Self.stripPlaceholders($0)) })
                    || own.contains(where: { review.blurb.contains(Self.stripPlaceholders($0)) }),
                "\(review.outlet) blurb \"\(review.blurb)\" is not one of its own"
            )
        }
    }

    private static func midScore(of band: String) -> Int {
        switch band {
        case "dire": 10
        case "poor": 30
        case "mixed": 50
        case "good": 70
        default: 90
        }
    }

    /// The part of a template before its first placeholder, so a filled
    /// blurb can be matched back to the line it came from.
    private static func stripPlaceholders(_ template: String) -> String {
        guard let brace = template.firstIndex(of: "{") else { return template }
        return String(template[template.startIndex..<brace])
    }
}
