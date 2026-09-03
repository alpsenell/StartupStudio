import Foundation
import Testing
import TycoonContent

/// Version-2 event defs are a strict superset of version 1: a def written
/// before requirements, effects and choices existed decodes into the same
/// behavior, and every new field round-trips.
@Suite("EventDef v2")
struct EventDefV2Tests {
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    private func decode<T: Decodable>(_ json: String) throws -> T {
        try decoder.decode(T.self, from: Data(json.utf8))
    }

    // MARK: - Backward compatibility

    @Test("a version-1 company event decodes unchanged")
    func v1CompanyEventDecodes() throws {
        let def: EventDef = try decode("""
        {
          "id": "blog_feature",
          "headline": "A tech blog features your studio.",
          "impact": { "type": "hypeDeltaOnActiveProduct", "amount": 10 },
          "weight": 4
        }
        """)
        #expect(def.id == "blog_feature")
        #expect(def.impact == .hypeDeltaOnActiveProduct(amount: 10))
        #expect(def.weight == 4)
        #expect(def.choices.isEmpty)
        #expect(def.requires == nil)
        #expect(def.effects.isEmpty)
        #expect(def.cooldownDays == 0)
        #expect(def.once == false)
        #expect(def.followUpOnly == false)
        #expect(def.unconditionalEffects == [.hype(amount: 10)])
    }

    @Test("a version-1 life event decodes unchanged")
    func v1LifeEventDecodes() throws {
        let def: LifeEventDef = try decode("""
        {
          "id": "partner_promotion",
          "headline": "Your partner got a promotion.",
          "weight": 3,
          "minStage": "dating",
          "impact": { "wallet": 300, "relationships": 6, "mood": 4 }
        }
        """)
        #expect(def.minStage == "dating")
        #expect(def.impact.wallet == 300)
        #expect(def.choices.isEmpty)
        #expect(def.requires == nil)
        #expect(def.category == .personal)
    }

    @Test("every bundled event and life event still decodes")
    func bundledCatalogDecodes() throws {
        let catalog = try ContentCatalog.loadBundled()
        #expect(!catalog.events.isEmpty)
        #expect(!catalog.lifeEvents.isEmpty)
    }

    // MARK: - New fields

    @Test("requirements, choices and follow-ups round-trip")
    func v2FieldsRoundTrip() throws {
        let def: EventDef = try decode("""
        {
          "id": "journalist_call",
          "headline": "A reporter wants twenty minutes.",
          "body": "She covers small studios and she has done her homework.",
          "weight": 3,
          "category": "press",
          "cooldownDays": 120,
          "once": true,
          "respondByDays": 4,
          "autoChoiceIndex": 1,
          "requires": {
            "minTier": "loft",
            "minHeadcount": 3,
            "flagsNone": ["journalist_burned"]
          },
          "effects": [{ "type": "reputation", "amount": 1 }],
          "choices": [
            {
              "id": "candid",
              "label": "Talk candidly",
              "detail": "Reputation +6 · she writes the profile",
              "effects": [{ "type": "reputation", "amount": 6 }],
              "setFlags": ["journalist_candid"],
              "followUpEventID": "journalist_profile",
              "followUpDelayDays": 21
            },
            { "id": "decline", "label": "Say you're busy" }
          ]
        }
        """)
        #expect(def.requires?.minTier == "loft")
        #expect(def.requires?.minHeadcount == 3)
        #expect(def.requires?.flagsNone == ["journalist_burned"])
        #expect(def.choices.count == 2)
        #expect(def.choices[0].followUpEventID == "journalist_profile")
        #expect(def.choices[0].followUpDelayDays == 21)
        #expect(def.choices[0].setFlags == ["journalist_candid"])
        #expect(def.choices[1].effects.isEmpty)
        #expect(def.autoChoiceIndex == 1)
        #expect(def.once)
        #expect(def.cooldownDays == 120)

        let round: EventDef = try decoder.decode(EventDef.self, from: encoder.encode(def))
        #expect(round == def)
    }

    @Test("every effect kind round-trips through JSON")
    func effectsRoundTrip() throws {
        let effects: [EventEffect] = [
            .cash(amount: -800),
            .reputation(amount: 3),
            .hype(amount: 12),
            .moraleAll(amount: -6),
            .morale(amount: -10, pick: .lowestMorale),
            .loyalty(amount: 5, pick: .random),
            .market(topicID: "fitness", amount: 0.15),
            .loan(amount: 5_000),
            .founderMeters(energy: -5, health: 0, mood: -8, relationships: 2, wallet: -400),
            .away(days: 3, reason: "Deposition"),
            .cold(days: 4),
            .flag("sued"),
            .clearFlag("sued"),
            .skill(skill: .coding, amount: 4, pick: .everyone),
            .research(amount: 20),
            .affection(amount: -20),
            .evening,
            .bond(amount: 8, pick: .lowestMorale),
        ]
        let round = try decoder.decode([EventEffect].self, from: encoder.encode(effects))
        #expect(round == effects)
    }

    @Test("the diary's fields decode terse and round-trip, and a plain def is not dated")
    func diaryFieldsRoundTrip() throws {
        let effects: [EventEffect] = try decode("""
        [{ "type": "affection", "amount": 15 }, { "type": "evening" }, { "type": "bond", "amount": 6 }]
        """)
        #expect(effects == [.affection(amount: 15), .evening, .bond(amount: 6, pick: .random)])
        #expect(EventEffect.affection(amount: -20).summary == "Affection −20")
        #expect(EventEffect.evening.summary == "An evening")
        #expect(EventEffect.bond(amount: 6, pick: .everyone).summary == "Bond +6")

        let def: LifeEventDef = try decode("""
        {
          "id": "kid_birthday",
          "headline": "{child}'s birthday is on Saturday.",
          "body": "They asked whether you'd be there.",
          "weight": 1,
          "requiresChildren": true,
          "followUpOnly": true,
          "category": "family",
          "autoChoiceIndex": 1,
          "diaryLabel": "{child}'s birthday",
          "missedVariantID": "kid_birthday_again",
          "impact": {},
          "choices": [
            { "id": "party", "label": "Go", "effects": [{ "type": "evening" }],
              "requires": { "minEveningsLeft": 1 } },
            { "id": "miss", "label": "Send a present", "effects": [{ "type": "affection", "amount": -20 }] }
          ]
        }
        """)
        #expect(def.isDated)
        #expect(def.diaryLabel == "{child}'s birthday")
        #expect(def.missedVariantID == "kid_birthday_again")
        #expect(def.choices[0].requires?.minEveningsLeft == 1)
        #expect(def.choices[1].requires == nil)
        let round = try decoder.decode(LifeEventDef.self, from: encoder.encode(def))
        #expect(round == def)

        let plain: LifeEventDef = try decode("""
        { "id": "x", "headline": "y", "weight": 1, "impact": {} }
        """)
        #expect(!plain.isDated)
        #expect(plain.missedVariantID == nil)
        let requirements: EventRequirements = try decode("{}")
        #expect(requirements.minEveningsLeft == nil)
    }

    @Test("only random picks cost an RNG draw")
    func drawBudget() {
        #expect(EventEffect.morale(amount: 1, pick: .random).drawsRandomly)
        #expect(!EventEffect.morale(amount: 1, pick: .lowestMorale).drawsRandomly)
        #expect(!EventEffect.cash(amount: 1).drawsRandomly)
    }

    @Test("effect summaries read like the sheet's consequence line")
    func summaries() {
        #expect(EventEffect.cash(amount: -800).summary == "−$800")
        #expect(EventEffect.reputation(amount: 3).summary == "Reputation +3")
        #expect(EventEffect.moraleAll(amount: -6).summary == "Team morale −6")
        #expect(
            EventEffect.founderMeters(
                energy: 0, health: 0, mood: -8, relationships: 0, wallet: -400
            ).summary == "Mood −8 · Wallet −$400"
        )
    }

    @Test("an unknown effect type is a decoding error, not a silent no-op")
    func unknownEffectThrows() {
        #expect(throws: (any Error).self) {
            let _: EventEffect = try decode("{ \"type\": \"teleport\", \"amount\": 1 }")
        }
    }

    @Test("staff event defs decode with terse outcomes")
    func staffEventDecodes() throws {
        let def: StaffEventDef = try decode("""
        {
          "id": "raiseRequest",
          "title": "{name} wants a raise",
          "body": "They brought numbers.",
          "headline": "{name} asked for a raise.",
          "weight": 5,
          "requires": { "minTenureDays": 120, "anyTrait": ["grumbler"] },
          "supportive": { "label": "Give the raise", "salaryPercent": 15, "loyalty": 14 },
          "strict": { "label": "Not this quarter", "loyalty": -14, "morale": -8 }
        }
        """)
        #expect(def.requires?.minTenureDays == 120)
        #expect(def.requires?.anyTrait == ["grumbler"])
        #expect(def.supportive?.salaryPercent == 15)
        #expect(def.isImmediate == false)
        #expect(def.policy == nil)
        #expect(def.strict.morale == -8)
        #expect(def.strict.cash == 0)
    }
}
