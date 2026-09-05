import Foundation
import Testing
import TycoonContent
@testable import TycoonEngine

/// The legacy ledger (iteration 7, R2): what a finished company leaves
/// behind, what the next one may carry, and the rule that an heirloom is
/// exactly one delta on day 0 and never a draw.
@Suite("Legacy ledger and heirlooms")
struct LegacyTests {
    static func balance() throws -> BalanceConfig {
        var balance = try BalanceConfig.loadBundled()
        balance.rivals.rivalCount = 0
        return balance
    }

    static let content = TestContent.bundled

    static func newGame(
        seed: UInt64 = 4_242, heirloom: Heirloom? = nil, origin: FoundingOrigin = .garage
    ) throws -> GameState {
        GameState.newGame(
            companyName: "Legacy Ltd", seed: seed, balance: try balance(),
            origin: origin, content: content, heirloom: heirloom
        )
    }

    /// A deterministic contact; `rapport` is the sort key the ledger uses.
    static func contact(
        _ index: Int, rapport: Double, revealed: Bool = true,
        outcome: ContactOutcome? = nil, leftRole: EmployeeRole? = nil
    ) -> Contact {
        Contact(
            id: UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", index))!,
            name: "Contact \(index)",
            appearanceSeed: UInt64(1_000 + index),
            archetype: .designer,
            skills: SkillSet(coding: Double(20 + index), design: 60, marketing: 10),
            askingSalary: 900,
            rapport: rapport,
            interest: 40,
            metDay: 10,
            lastMetDay: 40,
            isRevealed: revealed,
            outcome: outcome,
            leftDay: leftRole == nil ? nil : 200,
            leftReason: leftRole == nil ? nil : .quit,
            leftRole: leftRole
        )
    }

    /// A finished company: twelve contacts, an owned studio in Midtown,
    /// two perks, an IPO on day 700.
    static func endedState() throws -> GameState {
        var state = try newGame()
        state.day = 700
        state.gameOver = GameOverInfo(day: 700, reason: "Rang the bell.", kind: .ipo)
        for index in 0..<12 {
            state.networking.contacts.append(contact(index, rapport: Double(index * 7)))
        }
        // The two who must not be carried: burned, and married.
        state.networking.contacts.append(contact(50, rapport: 99, outcome: .lost))
        state.networking.contacts.append(contact(51, rapport: 98, outcome: .romance))
        // An alumnus keeps the role they left with; a stranger takes the
        // one their archetype implies.
        state.networking.contacts[0].leftRole = .marketer
        state.networking.contacts[1].isRevealed = false
        state.company.officeTier = .studio
        state.city = CityState(district: .midtown, ownership: .owned(purchasePrice: 90_000), propertyValue: 95_000)
        state.progression.perks = ["talentMagnet", "pressContacts"]
        return state
    }

    // MARK: - Recording a run

    @Test("record captures the top eight contacts by rapport, their skills and the traits the founder saw")
    func recordCapturesEightPeople() throws {
        let state = try Self.endedState()
        var ledger = LegacyLedger.empty
        ledger.record(state, balance: try Self.balance())

        let run = try #require(ledger.runs.first)
        #expect(ledger.runs.count == 1)
        #expect(run.companyName == "Legacy Ltd")
        #expect(run.seed == 4_242)
        #expect(run.ending == .ipo)
        #expect(run.day == 700)
        #expect(ledger.endingsReached == [.ipo])
        #expect(ledger.isEmpty == false)

        // Contacts 11 down to 4 by rapport; the burned and the married are out.
        #expect(run.people.count == LegacyLedger.peopleCarried)
        #expect(run.people.map(\.name) == (4...11).reversed().map { "Contact \($0)" })
        #expect(run.people.allSatisfy { $0.name != "Contact 50" && $0.name != "Contact 51" })
        let best = run.people[0]
        #expect(best.rapport == 77)
        #expect(best.skills == SkillSet(coding: 31, design: 60, marketing: 10))
        #expect(best.appearanceSeed == 1_011)
        #expect(best.revealedTraits == TraitEffects.derivedTraitIDs(appearanceSeed: 1_011))
        #expect(best.role == .designer, "a stranger's role comes from their archetype")
        #expect(run.perks == ["pressContacts", "talentMagnet"])
    }

    @Test("A contact who was never listened to is carried with no traits; an alumnus keeps their role")
    func revealedTraitsAndRoles() throws {
        var state = try Self.endedState()
        // Lift the two special contacts into the top eight.
        state.networking.contacts[0].rapport = 95
        state.networking.contacts[1].rapport = 94
        var ledger = LegacyLedger.empty
        ledger.record(state, balance: try Self.balance())
        let people = try #require(ledger.runs.first).people
        #expect(people[0].name == "Contact 0")
        #expect(people[0].role == .marketer, "the role they left with")
        #expect(people[1].name == "Contact 1")
        #expect(people[1].revealedTraits.isEmpty, "never listened to")
    }

    @Test("record captures the deed when the office is owned, and no deed while renting")
    func recordCapturesTheDeed() throws {
        let owned = try Self.endedState()
        var ledger = LegacyLedger.empty
        ledger.record(owned, balance: try Self.balance())
        #expect(ledger.runs[0].deed == LegacyDeed(tier: .studio, district: .midtown))

        var renting = owned
        renting.city.ownership = .renting
        ledger.record(renting, balance: try Self.balance())
        #expect(ledger.runs[1].deed == nil)
    }

    @Test("record is a no-op on a company that is still running")
    func recordNeedsAnEnding() throws {
        var ledger = LegacyLedger.empty
        ledger.record(try Self.newGame(), balance: try Self.balance())
        #expect(ledger.isEmpty)
    }

    @Test("Fewer than eight contacts records them all, in rapport order")
    func recordWithAThinBook() throws {
        var state = try Self.newGame()
        state.gameOver = GameOverInfo(day: 90, reason: "Broke.", kind: .bankruptcy)
        state.networking.contacts = [Self.contact(1, rapport: 10), Self.contact(2, rapport: 30)]
        var ledger = LegacyLedger.empty
        ledger.record(state, balance: try Self.balance())
        #expect(ledger.runs[0].people.map(\.name) == ["Contact 2", "Contact 1"])
        #expect(ledger.runs[0].deed == nil)
        #expect(ledger.endingsReached == [.bankruptcy])
    }

    @Test("The ledger round-trips through JSON and an old ledger decodes with defaults")
    func codable() throws {
        var ledger = LegacyLedger.empty
        ledger.record(try Self.endedState(), balance: try Self.balance())
        ledger.spend(.perk(id: "talentMagnet"))
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(ledger)
        let decoded = try JSONDecoder().decode(LegacyLedger.self, from: data)
        #expect(decoded == ledger)

        let bare = try JSONDecoder().decode(LegacyLedger.self, from: Data("{}".utf8))
        #expect(bare == .empty)

        // A person written before roles were recorded reads with none and
        // resolves one from the skills.
        var object = try #require(try JSONSerialization.jsonObject(with: try encoder.encode(ledger.runs[0].people[0])) as? [String: Any])
        object.removeValue(forKey: "role")
        let person = try JSONDecoder().decode(LegacyPerson.self, from: try JSONSerialization.data(withJSONObject: object))
        #expect(person.role == nil)
        #expect(person.resolvedRole == .designer)
    }

    // MARK: - Offers and spending

    @Test("The ledger offers each person, perk and deed once, minus the spent ones")
    func offers() throws {
        var ledger = LegacyLedger.empty
        ledger.record(try Self.endedState(), balance: try Self.balance())
        // A second company that knew the same best contact, owned the same
        // building and earned one of the same perks.
        var second = try Self.endedState()
        second.company.name = "Second Co"
        second.gameOver = GameOverInfo(day: 300, reason: "Sold.", kind: .soldUp)
        second.networking.contacts = [Self.contact(11, rapport: 90), Self.contact(70, rapport: 5)]
        second.progression.perks = ["talentMagnet", "veteranCrew"]
        ledger.record(second, balance: try Self.balance())

        let offers = ledger.offers
        let people = offers.filter { if case .person = $0.heirloom { return true } else { return false } }
        let perks = offers.filter { if case .perk = $0.heirloom { return true } else { return false } }
        let deeds = offers.filter { if case .deed = $0.heirloom { return true } else { return false } }

        #expect(people.count == 9, "eight from the first, one new from the second, the shared face once")
        #expect(people[0].companyName == "Second Co", "the newest run's version of a shared face wins")
        #expect(perks.map(\.heirloom) == [.perk(id: "pressContacts"), .perk(id: "talentMagnet"), .perk(id: "veteranCrew")])
        #expect(perks[1].companyName == "Second Co")
        #expect(deeds.count == 1)
        #expect(deeds[0].heirloom == .deed(LegacyDeed(tier: .studio, district: .midtown)))
        #expect(deeds[0].ending == .soldUp)
        #expect(Set(offers.map(\.id)).count == offers.count, "offer ids are unique")

        ledger.spend(.deed(LegacyDeed(tier: .studio, district: .midtown)))
        ledger.spend(.perk(id: "talentMagnet"))
        ledger.spend(people[0].heirloom)
        let remaining = ledger.offers
        #expect(remaining.count == offers.count - 3)
        #expect(remaining.allSatisfy { !ledger.spentHeirlooms.contains($0.id) })
        #expect(LegacyLedger.empty.offers.isEmpty)
    }

    @Test("Merging two devices' ledgers is a union by run id")
    func merge() throws {
        var a = LegacyLedger.empty
        a.record(try Self.endedState(), balance: try Self.balance())
        var b = a
        var another = try Self.endedState()
        another.company.name = "Elsewhere"
        another.gameOver = GameOverInfo(day: 120, reason: "Broke.", kind: .bankruptcy)
        b.record(another, balance: try Self.balance())
        b.spend(.perk(id: "pressContacts"))
        a.spend(.perk(id: "talentMagnet"))

        let merged = a.merged(with: b)
        #expect(merged.runs.map(\.companyName) == ["Legacy Ltd", "Elsewhere"])
        #expect(merged.endingsReached == [.ipo, .bankruptcy])
        #expect(merged.spentHeirlooms == ["perk.pressContacts", "perk.talentMagnet"])
        #expect(a.merged(with: a) == a, "merging with itself changes nothing")
        #expect(b.merged(with: a).runs.count == 2)
    }

    // MARK: - Heirlooms are one delta each

    private static func stripped(_ state: GameState) -> GameState {
        var copy = state
        copy.heirloom = nil
        copy.eventLog = []
        return copy
    }

    @Test("A person heirloom adds one contact, warm and revealed, and nothing else")
    func personHeirloom() throws {
        let plain = try Self.newGame()
        let person = LegacyPerson(
            id: UUID(uuidString: "11111111-2222-3333-4444-555555555555")!,
            name: "Marco Reyes", appearanceSeed: 0xBEEF,
            skills: SkillSet(coding: 70, design: 30, marketing: 20),
            revealedTraits: ["speedster"], rapport: 88, role: .backend
        )
        var heir = try Self.newGame(heirloom: .person(person))
        #expect(heir.heirloom == .person(person))
        #expect(heir.isRanked == false)
        #expect(heir.eventLog == [.heirloomApplied(kind: "person", day: 0)])

        let contact = try #require(heir.networking.contacts.first)
        #expect(heir.networking.contacts.count == 1)
        #expect(contact.id == person.id)
        #expect(contact.name == "Marco Reyes")
        #expect(contact.appearanceSeed == 0xBEEF)
        #expect(contact.skills == person.skills)
        #expect(contact.rapport == 60)
        #expect(contact.isRevealed)
        #expect(contact.leftReason == .formerCompany)
        #expect(contact.leftRole == .backend)
        #expect(contact.archetype == .engineer)
        #expect(contact.leftDay == 0)
        #expect(contact.outcome == nil)
        #expect(contact.isAlumnus)
        #expect(contact.askingSalary > 0, "you still recruit them at their ask")

        heir.networking.contacts = []
        #expect(Self.stripped(heir) == plain, "the contact is the whole delta")
    }

    @Test("A perk heirloom is the perk from day 0 and nothing else")
    func perkHeirloom() throws {
        let plain = try Self.newGame()
        var heir = try Self.newGame(heirloom: .perk(id: "veteranCrew"))
        #expect(heir.progression.perks == ["veteranCrew"])
        #expect(heir.progression.hasPerk(.veteranCrew))
        #expect(heir.eventLog == [.heirloomApplied(kind: "perk", day: 0)])
        heir.progression.perks = []
        #expect(Self.stripped(heir) == plain)
    }

    @Test("A deed heirloom is the office owned in its district with no rent, and nothing else")
    func deedHeirloom() throws {
        let balance = try Self.balance()
        let plain = try Self.newGame()
        var heir = try Self.newGame(heirloom: .deed(LegacyDeed(tier: .loft, district: .techPark)))
        #expect(heir.company.officeTier == .loft)
        #expect(heir.city.district == .techPark)
        #expect(heir.city.ownership.isOwned)
        let price = heir.officePurchasePrice(in: .techPark, balance: balance)
        #expect(heir.city.ownership == .owned(purchasePrice: price))
        #expect(heir.city.propertyValue == price)
        #expect(price > 0)
        #expect(heir.officeWeeklyRent(balance: balance) == 0, "no rent")
        #expect(heir.company.cash == plain.company.cash, "the deed cost nothing today")
        #expect(heir.ledger.entries.isEmpty)
        #expect(heir.eventLog == [.heirloomApplied(kind: "deed", day: 0)])

        heir.company.officeTier = .garage
        heir.city = .legacy
        #expect(Self.stripped(heir) == plain)
    }

    @Test("The deed is capped at a studio")
    func deedCap() throws {
        let heir = try Self.newGame(heirloom: .deed(LegacyDeed(tier: .campus, district: .downtown)))
        #expect(heir.company.officeTier == .studio)
        #expect(heir.city.district == .downtown)
        let studio = try Self.newGame(heirloom: .deed(LegacyDeed(tier: .studio, district: .downtown)))
        #expect(studio.company.officeTier == .studio)
    }

    @Test("An heirloom reads no RNG stream and lands after the origin")
    func heirloomsDrawNothing() throws {
        let garage = try Self.newGame()
        let person = LegacyPerson(
            id: UUID(), name: "Ada", appearanceSeed: 3, skills: SkillSet(coding: 50, design: 50, marketing: 50), rapport: 70
        )
        for heirloom in [Heirloom.person(person), .perk(id: "marketDarling"), .deed(LegacyDeed(tier: .studio, district: .oldTown))] {
            let state = try Self.newGame(heirloom: heirloom, origin: .cofounded)
            #expect(state.rng == garage.rng)
            #expect(state.worldRNG == garage.worldRNG)
            #expect(state.investorRNG == garage.investorRNG)
            #expect(state.socialRNG == garage.socialRNG)
            #expect(state.cofounder != nil, "the origin still applied")
            // The same seed and heirloom found the same company, twice.
            #expect(state == (try Self.newGame(heirloom: heirloom, origin: .cofounded)))
        }
    }

    @Test("An heirloom run survives a save and is still unranked")
    func heirloomPersists() throws {
        let deed = LegacyDeed(tier: .studio, district: .suburbs)
        let state = try Self.newGame(heirloom: .deed(deed))
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let decoded = try JSONDecoder().decode(GameState.self, from: try encoder.encode(state))
        #expect(decoded == state)
        #expect(decoded.heirloom == .deed(deed))
        #expect(decoded.isRanked == false)
    }
}
