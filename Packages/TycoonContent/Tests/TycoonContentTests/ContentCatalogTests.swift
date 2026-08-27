import Foundation
import Testing
import TycoonContent

// MARK: - Bundled catalog

@Suite("Bundled catalog")
struct BundledCatalogTests {
    let catalog: ContentCatalog

    init() throws {
        self.catalog = try ContentCatalog.loadBundled()
    }

    // 1. Load + counts

    @Test("loadBundled succeeds with the expected content counts")
    func countsMatch() {
        #expect(catalog.productTypes.count == 6)
        #expect(catalog.topics.count == 12)
        #expect(catalog.techTree.count == 20)
        #expect(catalog.events.count >= 60)
        #expect(catalog.lifeEvents.count >= 45)
        #expect(catalog.names.firstNames.count >= 40)
        #expect(catalog.names.lastNames.count >= 40)
        #expect(catalog.names.clientCompanies.count >= 30)
        #expect(catalog.names.partnerNames.count >= 30)
        #expect(catalog.names.childNames.count >= 30)
    }

    @Test("productTypes preserve stable JSON order")
    func stableOrder() {
        #expect(catalog.productTypes.first?.id == "mobile_app")
    }

    // 2. Referential integrity

    @Test("every fitByType key is a real product type id, with an allowed fit value")
    func fitByTypeReferencesRealProductTypes() {
        let typeIDs = Set(catalog.productTypes.map(\.id))
        for topic in catalog.topics {
            for (typeID, fit) in topic.fitByType {
                #expect(
                    typeIDs.contains(typeID),
                    "Topic \(topic.id) references unknown product type \(typeID)"
                )
                #expect(
                    fit == 0.8 || fit == 1.0 || fit == 1.15,
                    "Topic \(topic.id) has out-of-band fit \(fit) for \(typeID)"
                )
            }
        }
    }

    @Test("tech prerequisites exist and sit on a strictly lower tier (implies acyclic)")
    func techPrerequisitesAreValid() throws {
        let tierByID = Dictionary(
            catalog.techTree.map { ($0.id, $0.tier) },
            uniquingKeysWith: { first, _ in first }
        )
        for node in catalog.techTree {
            #expect((1...5).contains(node.tier), "\(node.id) has out-of-range tier \(node.tier)")
            #expect(node.researchCost > 0, "\(node.id) has non-positive research cost")
            #expect(node.cashCost >= 0, "\(node.id) has negative cash cost")
            for prereq in node.prerequisites {
                let prereqTier = try #require(
                    tierByID[prereq],
                    "\(node.id) requires unknown tech \(prereq)"
                )
                #expect(
                    prereqTier < node.tier,
                    "\(node.id) (tier \(node.tier)) depends on \(prereq) (tier \(prereqTier))"
                )
            }
        }
    }

    @Test("every unlockProductType effect references a real product type")
    func unlockEffectsReferenceRealProductTypes() {
        let typeIDs = Set(catalog.productTypes.map(\.id))
        for node in catalog.techTree {
            if case .unlockProductType(let id) = node.effect {
                #expect(typeIDs.contains(id), "\(node.id) unlocks unknown product type \(id)")
            }
        }
    }

    @Test("no duplicate ids or pool entries anywhere")
    func noDuplicateIDs() {
        #expect(Set(catalog.productTypes.map(\.id)).count == catalog.productTypes.count)
        #expect(Set(catalog.topics.map(\.id)).count == catalog.topics.count)
        #expect(Set(catalog.techTree.map(\.id)).count == catalog.techTree.count)
        #expect(Set(catalog.events.map(\.id)).count == catalog.events.count)
        #expect(Set(catalog.lifeEvents.map(\.id)).count == catalog.lifeEvents.count)
        #expect(Set(catalog.names.firstNames).count == catalog.names.firstNames.count)
        #expect(Set(catalog.names.lastNames).count == catalog.names.lastNames.count)
        #expect(Set(catalog.names.clientCompanies).count == catalog.names.clientCompanies.count)
        #expect(Set(catalog.names.partnerNames).count == catalog.names.partnerNames.count)
        #expect(Set(catalog.names.childNames).count == catalog.names.childNames.count)
    }

    @Test("all event weights are at least 1")
    func eventWeightsArePositive() {
        for event in catalog.events {
            #expect(event.weight >= 1, "\(event.id) has weight \(event.weight)")
        }
    }

    // 3. Starters and unlock coverage

    @Test("exactly mobile_app and web_app are unlocked from the start")
    func startersAreExactlyMobileAndWeb() {
        let starters = Set(catalog.productTypes.filter(\.unlockedFromStart).map(\.id))
        #expect(starters == ["mobile_app", "web_app"])
    }

    @Test("every non-starter product type has an unlockProductType tech node")
    func everyNonStarterHasAnUnlockNode() {
        let unlockedByTech = Set(catalog.techTree.compactMap { node -> String? in
            if case .unlockProductType(let id) = node.effect { return id }
            return nil
        })
        for type in catalog.productTypes where !type.unlockedFromStart {
            #expect(unlockedByTech.contains(type.id), "\(type.id) is never unlocked by research")
        }
        let starters = Set(catalog.productTypes.filter(\.unlockedFromStart).map(\.id))
        #expect(unlockedByTech.isDisjoint(with: starters), "starter types must not need research")
    }

    @Test("research unlocks exactly the press_release and launch_event campaign kinds")
    func campaignKindUnlocks() {
        let kinds = catalog.techTree.compactMap { node -> String? in
            if case .unlockCampaignKind(let id) = node.effect { return id }
            return nil
        }
        #expect(kinds.count == 2)
        #expect(Set(kinds) == ["press_release", "launch_event"])
    }

    // 5. Lookup helpers

    @Test("lookup helpers return the matching item and nil for unknown ids")
    func lookupHelpers() throws {
        let mobile = try #require(catalog.productType("mobile_app"))
        #expect(mobile.name == "Mobile App")
        #expect(catalog.productType("flying_car") == nil)

        let firstTopic = try #require(catalog.topics.first)
        #expect(catalog.topic(firstTopic.id) == firstTopic)
        #expect(catalog.topic("underwater_basket_weaving") == nil)

        let firstTech = try #require(catalog.techTree.first)
        #expect(catalog.tech(firstTech.id) == firstTech)
        #expect(catalog.tech("time_machine") == nil)

        let firstLife = try #require(catalog.lifeEvents.first)
        #expect(catalog.lifeEvent(firstLife.id) == firstLife)
        #expect(catalog.lifeEvent("lottery_win") == nil)
    }

    // 6. Life events

    @Test("life event weights are >= 1 and gates use valid values")
    func lifeEventGatesAreValid() {
        let stages: Set<String> = ["single", "dating", "partner", "married"]
        for event in catalog.lifeEvents {
            #expect(event.weight >= 1, "\(event.id) has weight \(event.weight)")
            #expect(!event.headline.isEmpty, "\(event.id) has an empty headline")
            if let stage = event.minStage {
                #expect(stages.contains(stage), "\(event.id) gates on unknown stage \(stage)")
            }
            if let cap = event.maxRelationships {
                #expect((0...100).contains(cap), "\(event.id) has out-of-range maxRelationships \(cap)")
            }
            #expect(event.impact.coldDays >= 0, "\(event.id) has negative coldDays")
            #expect(event.impact.awayDays >= 0, "\(event.id) has negative awayDays")
            if event.impact.awayDays > 0 {
                #expect(event.impact.awayReason != nil, "\(event.id) sends the founder away without a reason")
            }
        }
    }

    @Test("the life event catalog covers every gate and impact kind")
    func lifeEventCatalogHasVariety() {
        let events = catalog.lifeEvents
        #expect(events.contains { $0.minStage != nil })
        #expect(events.contains { $0.requiresChildren })
        #expect(events.contains { $0.maxRelationships != nil })
        #expect(events.contains { $0.impact.coldDays > 0 })
        #expect(events.contains { $0.impact.awayDays > 0 })
        #expect(events.contains { $0.impact.wallet > 0 })
        #expect(events.contains { $0.impact.wallet < 0 })
        #expect(events.contains { $0.impact.energy < 0 })
        #expect(events.contains { $0.impact.health > 0 })
        #expect(events.contains { $0.impact.mood > 0 })
        #expect(events.contains { $0.impact.relationships > 0 })
    }
}

// MARK: - LifeEventDef JSON format

@Suite("LifeEventDef JSON format")
struct LifeEventDefCodableTests {
    @Test("omitted impact and gate fields decode to their defaults")
    func decodesWithDefaults() throws {
        let json = """
        {
          "id": "viral_tweet",
          "headline": "A joke about your company goes viral.",
          "weight": 3,
          "impact": { "mood": 8 }
        }
        """
        let event = try JSONDecoder().decode(LifeEventDef.self, from: Data(json.utf8))
        #expect(event.id == "viral_tweet")
        #expect(event.weight == 3)
        #expect(event.minStage == nil)
        #expect(event.requiresChildren == false)
        #expect(event.maxRelationships == nil)
        #expect(event.impact == LifeEventDef.Impact(mood: 8))
        #expect(event.impact.energy == 0)
        #expect(event.impact.health == 0)
        #expect(event.impact.relationships == 0)
        #expect(event.impact.wallet == 0)
        #expect(event.impact.coldDays == 0)
        #expect(event.impact.awayDays == 0)
        #expect(event.impact.awayReason == nil)
    }

    @Test("a fully specified literal decodes every field")
    func decodesFullLiteral() throws {
        let json = """
        {
          "id": "family_emergency",
          "headline": "Family emergency.",
          "weight": 2,
          "minStage": "dating",
          "requiresChildren": true,
          "maxRelationships": 40,
          "impact": {
            "energy": -1.5, "health": -2, "mood": -6, "relationships": 1,
            "wallet": -300, "coldDays": 1, "awayDays": 3, "awayReason": "Family emergency"
          }
        }
        """
        let event = try JSONDecoder().decode(LifeEventDef.self, from: Data(json.utf8))
        #expect(event.minStage == "dating")
        #expect(event.requiresChildren == true)
        #expect(event.maxRelationships == 40)
        #expect(event.impact == LifeEventDef.Impact(
            energy: -1.5, health: -2, mood: -6, relationships: 1,
            wallet: -300, coldDays: 1, awayDays: 3, awayReason: "Family emergency"
        ))
    }

    @Test("LifeEventDef round-trips through Codable")
    func roundTrips() throws {
        let original = LifeEventDef(
            id: "cold",
            headline: "You caught a cold.",
            weight: 5,
            minStage: nil,
            requiresChildren: false,
            maxRelationships: 60.5,
            impact: LifeEventDef.Impact(energy: -10, coldDays: 5)
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(LifeEventDef.self, from: data)
        #expect(decoded == original)
    }

    @Test("missing required fields are rejected")
    func missingRequiredFieldsThrow() {
        #expect(throws: (any Error).self) {
            try JSONDecoder().decode(
                LifeEventDef.self,
                from: Data(#"{ "id": "x", "headline": "h", "weight": 1 }"#.utf8)
            )
        }
        #expect(throws: (any Error).self) {
            try JSONDecoder().decode(
                LifeEventDef.self,
                from: Data(#"{ "id": "x", "headline": "h", "impact": {} }"#.utf8)
            )
        }
    }
}

// MARK: - Effect / Impact JSON format

@Suite("Effect and Impact JSON format")
struct EffectImpactCodableTests {
    // 4a. Round-trips

    @Test("every TechNode.Effect case round-trips through Codable")
    func effectRoundTrips() throws {
        let cases: [TechNode.Effect] = [
            .unlockProductType(id: "desktop_tool"),
            .qualityMultiplier(bonus: 0.05),
            .devSpeedMultiplier(bonus: 0.10),
            .unlockCampaignKind(id: "launch_event"),
        ]
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        for original in cases {
            let data = try encoder.encode(original)
            let decoded = try decoder.decode(TechNode.Effect.self, from: data)
            #expect(decoded == original)
        }
    }

    @Test("every EventDef.Impact case round-trips through Codable")
    func impactRoundTrips() throws {
        let cases: [EventDef.Impact] = [
            .cashDelta(amount: -800),
            .reputationDelta(amount: 3.5),
            .hypeDeltaOnActiveProduct(amount: 12),
        ]
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        for original in cases {
            let data = try encoder.encode(original)
            let decoded = try decoder.decode(EventDef.Impact.self, from: data)
            #expect(decoded == original)
        }
    }

    // 4b. Hand-written literals lock the human-editable discriminator format.

    @Test("Effect decodes from the human-editable discriminator format")
    func effectDecodesHumanEditableFormat() throws {
        let decoder = JSONDecoder()
        let expectations: [(json: String, expected: TechNode.Effect)] = [
            (#"{ "type": "unlockProductType", "id": "desktop_tool" }"#,
             .unlockProductType(id: "desktop_tool")),
            (#"{ "type": "qualityMultiplier", "bonus": 0.05 }"#,
             .qualityMultiplier(bonus: 0.05)),
            (#"{ "type": "devSpeedMultiplier", "bonus": 0.1 }"#,
             .devSpeedMultiplier(bonus: 0.1)),
            (#"{ "type": "unlockCampaignKind", "id": "press_release" }"#,
             .unlockCampaignKind(id: "press_release")),
        ]
        for (json, expected) in expectations {
            let decoded = try decoder.decode(TechNode.Effect.self, from: Data(json.utf8))
            #expect(decoded == expected, "failed for literal: \(json)")
        }
    }

    @Test("Impact decodes from the human-editable discriminator format")
    func impactDecodesHumanEditableFormat() throws {
        let decoder = JSONDecoder()
        let expectations: [(json: String, expected: EventDef.Impact)] = [
            (#"{ "type": "cashDelta", "amount": -800 }"#,
             .cashDelta(amount: -800)),
            (#"{ "type": "reputationDelta", "amount": 3.5 }"#,
             .reputationDelta(amount: 3.5)),
            (#"{ "type": "hypeDeltaOnActiveProduct", "amount": 10 }"#,
             .hypeDeltaOnActiveProduct(amount: 10)),
        ]
        for (json, expected) in expectations {
            let decoded = try decoder.decode(EventDef.Impact.self, from: Data(json.utf8))
            #expect(decoded == expected, "failed for literal: \(json)")
        }
    }

    @Test("a full TechNode decodes from a hand-written JSON literal")
    func techNodeDecodesFromLiteral() throws {
        let json = """
        {
          "id": "game_engine",
          "name": "Game Engine",
          "tier": 2,
          "researchCost": 100,
          "cashCost": 3000,
          "prerequisites": ["desktop_dev_kit"],
          "effect": { "type": "unlockProductType", "id": "game" },
          "blurb": "Physics, particles, and a level editor."
        }
        """
        let node = try JSONDecoder().decode(TechNode.self, from: Data(json.utf8))
        #expect(node.id == "game_engine")
        #expect(node.tier == 2)
        #expect(node.researchCost == 100)
        #expect(node.cashCost == 3000)
        #expect(node.prerequisites == ["desktop_dev_kit"])
        #expect(node.effect == .unlockProductType(id: "game"))
    }

    @Test("unknown discriminator values are rejected")
    func unknownDiscriminatorsThrow() {
        let decoder = JSONDecoder()
        #expect(throws: (any Error).self) {
            try decoder.decode(TechNode.Effect.self, from: Data(#"{ "type": "timeTravel" }"#.utf8))
        }
        #expect(throws: (any Error).self) {
            try decoder.decode(EventDef.Impact.self, from: Data(#"{ "type": "moraleDelta", "amount": 1 }"#.utf8))
        }
    }
}
