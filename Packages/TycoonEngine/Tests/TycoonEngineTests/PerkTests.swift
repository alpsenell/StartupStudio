import Foundation
import Testing
import TycoonContent
@testable import TycoonEngine

/// The two perks that were awarded, had balance numbers, and were read by
/// nothing (iteration 5, WS-G): Press Contacts and Veteran Crew now do
/// what their blurbs say.
@Suite("Dead perks")
struct PerkTests {
    private static let content = TestContent.bundled

    private static func balance() throws -> BalanceConfig {
        try BalanceConfig.loadBundled()
    }

    /// The same campaign on the same build, with and without the perk:
    /// the perk posts exactly `pressContactsHypeBonus` more.
    @Test func pressContactsLandsEveryCampaignHarder() throws {
        let balance = try Self.balance()
        var plain = GameState.newGame(companyName: "Acme", seed: 31, balance: balance)
        Reducer.apply(
            .startProduct(typeID: "mobile_app", topicID: "fitness", name: "Loud", focus: .balanced),
            to: &plain, balance: balance, content: Self.content
        )
        let product = try #require(plain.productInDevelopment)
        var withPerk = plain
        withPerk.progression.perks.insert(ProgressionPerk.pressContacts.rawValue)

        func hype(_ state: GameState) -> Double {
            guard case .development(let dev)? = state.product(id: product.id)?.stage else { return -1 }
            return dev.hype
        }
        let before = hype(plain)
        Reducer.apply(
            .startCampaign(kindID: CampaignKind.socialPush.rawValue, productID: product.id),
            to: &plain, balance: balance, content: Self.content
        )
        Reducer.apply(
            .startCampaign(kindID: CampaignKind.socialPush.rawValue, productID: product.id),
            to: &withPerk, balance: balance, content: Self.content
        )
        // A social push accrues its hype daily; the perk is the only thing
        // that lands on day one.
        #expect(hype(plain) == before)
        #expect(hype(withPerk) == before + balance.progression.pressContactsHypeBonus)
        #expect(plain.campaigns.count == 1)
        #expect(withPerk.campaigns.count == 1)
    }

    /// The same crew for a month, with and without the perk: everyone's
    /// morale settles higher, because the target they drift towards is
    /// `veteranCrewMoraleBonus` higher.
    @Test func veteranCrewLiftsEverybodysMorale() throws {
        let balance = try Self.balance()
        var plain = GameState.newGame(companyName: "Acme", seed: 32, balance: balance)
        plain.employees.append(Employee(
            id: UUID(), name: "Nadia", skills: SkillSet(coding: 45, design: 30, marketing: 20),
            weeklySalary: 900, assignment: .idle, isFounder: false, hiredDay: 0,
            appearanceSeed: 7, morale: 60, role: .backend
        ))
        var withPerk = plain
        withPerk.progression.perks.insert(ProgressionPerk.veteranCrew.rawValue)

        for _ in 0..<28 {
            Reducer.tick(&plain, balance: balance, content: Self.content)
            Reducer.tick(&withPerk, balance: balance, content: Self.content)
        }
        let plainMorale = try #require(plain.employees.first { !$0.isFounder }?.morale)
        let perkMorale = try #require(withPerk.employees.first { !$0.isFounder }?.morale)
        #expect(perkMorale > plainMorale, "veteran crew: \(perkMorale) against \(plainMorale)")
        #expect(perkMorale - plainMorale <= balance.progression.veteranCrewMoraleBonus + 0.001)
        // Nothing else moved: same day, same cash, same stream.
        #expect(plain.day == withPerk.day)
        #expect(plain.company.cash == withPerk.company.cash)
        #expect(plain.rng == withPerk.rng)
    }
}
