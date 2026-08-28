import Foundation
import Testing
import TycoonContent

/// Bios and spoken lines: enough written, correctly filtered by trait,
/// mood and context, and chosen purely from the caller's seed.
@Suite("Dialogue catalog")
struct DialogueCatalogTests {
    private let catalog: DialogueCatalog
    private let traits = [
        "nightOwl", "mentor", "perfectionist", "speedster", "socialButterfly",
        "loner", "flightRisk", "loyalist", "jokester", "grumbler",
        "prodigy", "workhorse", "fragile", "showman",
    ]

    init() throws {
        self.catalog = try ContentCatalog.loadBundled().dialogue
    }

    @Test("at least 40 bios, none repeated")
    func bioCount() {
        #expect(catalog.bios.count >= 40)
        let texts = catalog.bios.map(\.text)
        #expect(Set(texts).count == texts.count, "duplicate bio text")
        let ids = catalog.bios.map(\.id)
        #expect(Set(ids).count == ids.count, "duplicate bio id")
        #expect(catalog.bios.contains { $0.traits.isEmpty }, "there must be a generic bio")
    }

    @Test("every trait has a bio written for it")
    func everyTraitHasABio() {
        for trait in traits {
            #expect(
                catalog.bios.contains { $0.traits.contains(trait) },
                "no bio mentions \(trait)"
            )
        }
    }

    @Test("a bio prefers the candidate's traits and falls back to generic")
    func bioSelection() throws {
        let specific = try #require(catalog.bio(for: ["grumbler"], seed: 0))
        let grumblerTexts = Set(
            catalog.bios.filter { $0.traits.contains("grumbler") }.map(\.text)
        )
        #expect(grumblerTexts.contains(specific))

        let generic = try #require(catalog.bio(for: ["nonexistent_trait"], seed: 3))
        let genericTexts = Set(catalog.bios.filter(\.traits.isEmpty).map(\.text))
        #expect(genericTexts.contains(generic))

        // Pure in the seed.
        #expect(catalog.bio(for: ["grumbler"], seed: 7) == catalog.bio(for: ["grumbler"], seed: 7))
    }

    @Test("every context has a line for every mood bucket")
    func lineCoverage() {
        for context in DialogueContext.allCases {
            for mood in [10, 55, 90] {
                #expect(
                    catalog.line(for: [], mood: mood, context: context, seed: 0) != nil,
                    "no generic line for \(context.rawValue) at mood \(mood)"
                )
            }
        }
    }

    @Test("a trait-written line wins over a generic one")
    func traitLinesWin() throws {
        let generic = try #require(catalog.line(for: [], mood: 50, context: .coffee, seed: 0))
        let jokesterPool = Set(
            catalog.lines
                .filter { $0.context == .coffee && $0.traits.contains("jokester") }
                .flatMap(\.lines)
        )
        #expect(!jokesterPool.isEmpty)
        for seed in UInt64(0)..<20 {
            let line = try #require(
                catalog.line(for: ["jokester"], mood: 50, context: .coffee, seed: seed)
            )
            #expect(jokesterPool.contains(line), "\"\(line)\" is not a jokester line")
        }
        #expect(!jokesterPool.contains(generic))
    }

    @Test("mood picks the right register")
    func moodBuckets() throws {
        #expect(DialogueCatalog.moodBucket(10) == "low")
        #expect(DialogueCatalog.moodBucket(55) == "okay")
        #expect(DialogueCatalog.moodBucket(90) == "high")

        let lowPool = Set(
            catalog.lines
                .filter { $0.context == .coding && $0.moods == ["low"] }
                .flatMap(\.lines)
        )
        for seed in UInt64(0)..<10 {
            let line = try #require(catalog.line(for: [], mood: 12, context: .coding, seed: seed))
            #expect(lowPool.contains(line))
        }
    }

    @Test("the seed spreads across the pool")
    func seedSpread() {
        var seen: Set<String> = []
        for seed in UInt64(0)..<40 {
            if let line = catalog.line(for: [], mood: 90, context: .coding, seed: seed) {
                seen.insert(line)
            }
        }
        #expect(seen.count >= 4, "only saw \(seen.count) distinct lines")
    }

    @Test("an empty catalog returns nil so callers keep their fallback")
    func emptyCatalog() {
        #expect(DialogueCatalog.empty.bio(for: ["mentor"], seed: 1) == nil)
        #expect(
            DialogueCatalog.empty.line(for: ["mentor"], mood: 50, context: .coding, seed: 1) == nil
        )
    }

    @Test("no line repeats anywhere in the catalog")
    func noDuplicateLines() {
        let all = catalog.lines.flatMap(\.lines)
        #expect(all.count >= 120, "only \(all.count) lines written")
        #expect(Set(all).count == all.count, "a line is written twice")
    }
}
