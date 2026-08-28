import Foundation
import Testing
@testable import TycoonContent

/// The WS-F content catalogs: traits, chapter goals and investor personas.
@Suite("Progression content")
struct ProgressionContentTests {
    private static func catalog() throws -> ContentCatalog {
        try ContentCatalog.loadBundled()
    }

    // MARK: - Traits

    /// The engine derives traits during `Codable` decoding, where there is
    /// no catalog to consult, so it carries its own copy of the id list.
    /// This pins `Traits.json` to that list — same ids, same order.
    ///
    /// Kept as a literal (rather than importing TycoonEngine, which
    /// depends on this package) so the two lists are genuinely independent.
    @Test func traitsMatchTheEngineCanonicalOrder() throws {
        let expected = [
            "nightOwl", "mentor", "perfectionist", "speedster", "socialButterfly",
            "loner", "flightRisk", "loyalist", "jokester", "grumbler",
            "prodigy", "workhorse", "fragile", "showman",
        ]
        #expect(try Self.catalog().traits.map(\.id) == expected)
    }

    /// Every trait has to earn its place: a name, a blurb, a line of voice,
    /// and at least one number it moves.
    @Test func everyTraitIsFullyAuthoredAndDoesSomething() throws {
        for trait in try Self.catalog().traits {
            #expect(!trait.name.isEmpty, "\(trait.id) has no name")
            #expect(trait.blurb?.isEmpty == false, "\(trait.id) has no blurb")
            #expect(trait.bio?.isEmpty == false, "\(trait.id) has no bio line")
            #expect(trait.effects != .neutral, "\(trait.id) changes nothing")
        }
    }

    /// Trait ids are unique, or derivation could hand out a duplicate.
    @Test func traitIDsAreUnique() throws {
        let ids = try Self.catalog().traits.map(\.id)
        #expect(Set(ids).count == ids.count)
    }

    /// An `effects` block that only lists one field still decodes, with
    /// everything else neutral.
    @Test func partialEffectsBlocksDecode() throws {
        let json = Data(#"{"id":"x","name":"X","effects":{"outputMult":1.5}}"#.utf8)
        let trait = try JSONDecoder().decode(TraitDef.self, from: json)
        #expect(trait.effects.outputMult == 1.5)
        #expect(trait.effects.skillGrowthMult == 1)
        #expect(trait.effects.moraleTargetDelta == 0)
        #expect(trait.effects.quitStreakBonus == 0)
        #expect(trait.effects.poachResist == 1)
        #expect(trait.isPositive)
        #expect(trait.blurb == nil)
    }

    /// A trait with no `effects` key at all is inert rather than a failure.
    @Test func aTraitWithoutEffectsIsNeutral() throws {
        let json = Data(#"{"id":"x","name":"X"}"#.utf8)
        let trait = try JSONDecoder().decode(TraitDef.self, from: json)
        #expect(trait.effects == .neutral)
    }
}
