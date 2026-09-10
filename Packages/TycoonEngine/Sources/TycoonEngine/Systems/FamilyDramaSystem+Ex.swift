import Foundation
import TycoonContent

// MARK: K7 (partner and diary)

/// Iteration 15 — K7. The ex on the cap table.
///
/// A long marriage costs a slice of the company (`FamilyDrama.equityToEx`),
/// and until now the ex was a string holding it. After a divorce that gave
/// equity the family room shows the slice and what it is worth today, and
/// the founder can buy it back at `partner.buyOutMultiple` over that —
/// wallet first, company cash for the rest, refused with a case open or
/// when it would leave under `partner.buyOutRunwayWeeks` of runway. The ex
/// becomes an address-book contact at the settlement (`.formerPartner`),
/// with rapport where affection was and an id and archetype from their
/// stored seed: no draw.
///
/// And "Pack a bag" now means what its line says: the settlement follows.
/// The confrontation's `.leave` breaks up at once, as before, and keeps a
/// `FamilyLeaving` snapshot so the estate can still be divided afterwards.
///
/// Nothing here runs for a founder who never divorced — which is every bot.
extension FamilyDramaSystem {
    /// Buys the ex's slice back.
    static func buyOutEx(state: inout GameState, balance: BalanceConfig) -> [GameEvent] {
        guard state.exBuyOutBlocker(balance: balance) == nil,
              var settlement = state.familyDrama.settlement,
              let price = state.exBuyOutPrice(balance: balance)
        else { return [] }

        let fromWallet = min(max(0, state.life.wallet), price)
        state.life.wallet -= fromWallet
        let fromCompany = price - fromWallet
        if fromCompany > 0 {
            state.company.cash -= fromCompany
            state.ledger.post(LedgerEntry(
                day: state.day, amount: -fromCompany, category: .other,
                label: "Bought back the ex's shares"
            ))
        }
        let points = settlement.equityGiven
        state.investors.equityRemaining = min(100, state.investors.equityRemaining + points)
        settlement.boughtOutDay = state.day
        state.familyDrama.settlement = settlement
        if let id = settlement.exContactID,
           let index = state.networking.contacts.firstIndex(where: { $0.id == id }) {
            state.networking.contacts[index].lastMetDay = state.day
        }
        return [.exBoughtOut(points: points, price: price, fromWallet: fromWallet, day: state.day)]
    }

    /// The snapshot "Pack a bag" keeps, taken before the breakup wipes the
    /// partner's name, seed and affection.
    static func snapshotLeaving(_ state: inout GameState) {
        let family = state.life.family
        guard family.stage != .single, !state.familyDrama.isDivorced else { return }
        state.familyDrama.leaving = FamilyLeaving(
            day: state.day,
            marriedDays: family.stage == .married ? max(0, state.day - family.stageSinceDay) : 0,
            exName: family.partnerName ?? "your ex",
            seed: family.partnerAppearanceSeed,
            affection: family.affection,
            contactID: PartnerDerivation.personID(family),
            wasOnPayroll: family.partnerEmployeeID != nil
        )
    }

    /// The ex, in the address book: the contact they already were (the
    /// address book, the alumni list), or a new one from their seed.
    /// Returns the contact's id, or `nil` with no seed to derive one from.
    static func exContact(
        from leaving: FamilyLeaving,
        state: inout GameState,
        balance: BalanceConfig
    ) -> UUID? {
        guard let id = leaving.contactID ?? leaving.seed.map(PartnerDerivation.personID(seed:)) else {
            return nil
        }
        let rapport = min(100, max(0, leaving.affection))
        if let index = state.networking.contacts.firstIndex(where: { $0.id == id }) {
            state.networking.contacts[index].outcome = .formerPartner
            state.networking.contacts[index].rapport = rapport
            state.networking.contacts[index].lastMetDay = state.day
            state.networking.contacts[index].isRevealed = true
            return id
        }
        guard let seed = leaving.seed else { return nil }
        let skills = PartnerDerivation.skills(seed: seed)
        state.networking.contacts.append(Contact(
            id: id,
            name: leaving.exName,
            appearanceSeed: seed,
            archetype: PartnerDerivation.archetype(seed: seed),
            skills: skills,
            askingSalary: PartnerDerivation.ask(skills: skills, balance: balance, seed: seed),
            rapport: rapport,
            interest: 0,
            metDay: state.day,
            lastMetDay: state.day,
            isRevealed: true,
            outcome: .formerPartner
        ))
        return id
    }
}

/// The marriage as it stood the night the founder packed a bag.
public struct FamilyLeaving: Codable, Equatable, Sendable {
    public var day: Int
    public var marriedDays: Int
    public var exName: String
    public var seed: UInt64?
    public var affection: Double
    public var contactID: UUID?
    public var wasOnPayroll: Bool
}

// MARK: - Queries

extension GameState {
    /// The ex's points, while they still hold them.
    public var exHeldEquity: Double? {
        guard let settlement = familyDrama.settlement,
              settlement.equityGiven > 0, settlement.boughtOutDay == nil
        else { return nil }
        return settlement.equityGiven
    }

    /// What the ex's slice is worth today: points / 100 × the company's
    /// valuation.
    public func exSliceValue(balance: BalanceConfig) -> Int? {
        exHeldEquity.map { Int(($0 / 100 * Double(companyValuation(balance: balance))).rounded()) }
    }

    /// Their price: today's value × `partner.buyOutMultiple`.
    public func exBuyOutPrice(balance: BalanceConfig) -> Int? {
        exSliceValue(balance: balance).map {
            Int((Double($0) * balance.partner.buyOutMultiple).rounded())
        }
    }

    /// Why buying the ex out would be refused, or `nil`.
    public func exBuyOutBlocker(balance: BalanceConfig) -> String? {
        guard let settlement = familyDrama.settlement, settlement.equityGiven > 0 else {
            return "They hold none of the company"
        }
        if let day = settlement.boughtOutDay { return "Bought back on day \(day)" }
        guard let price = exBuyOutPrice(balance: balance) else { return "Not available" }
        if crime.pendingCase != nil { return "Not with a case open" }
        let wallet = max(0, life.wallet)
        if price > wallet + company.cash {
            return "Need \((price - wallet - company.cash).crimeMoney) more between you and the company"
        }
        let fromCompany = max(0, price - wallet)
        let floor = balance.partner.buyOutRunwayWeeks * weeklyBurn(balance: balance)
        if fromCompany > 0, company.cash - fromCompany < floor {
            return "It would leave under \(balance.partner.buyOutRunwayWeeks) weeks of runway"
        }
        return nil
    }

    /// Days of marriage the settlement will count: the snapshot's after a
    /// packed bag, else today's.
    public var familySettlementMarriedDays: Int {
        if life.family.stage == .single, let leaving = familyDrama.leaving { return leaving.marriedDays }
        return life.family.stage == .married ? max(0, day - life.family.stageSinceDay) : 0
    }

    /// Whether the partner worked here during this relationship — the
    /// settlement's co-founder clause.
    public var familySettlementPartnerWorkedHere: Bool {
        if life.family.stage == .single, let leaving = familyDrama.leaving { return leaving.wasOnPayroll }
        return life.family.partnerEmployeeID != nil
    }

    /// The points a settlement signed today would give the ex — what the
    /// divorce sheet and "Pack a bag" print.
    public func familyProjectedExEquity(balance: BalanceConfig) -> Double {
        FamilyDrama.equityToEx(
            marriedDays: familySettlementMarriedDays,
            equityRemaining: investors.equityRemaining,
            balance: balance.familyDrama,
            ignoresMarriedDays: familySettlementPartnerWorkedHere
        )
    }

    /// The ex in the address book, if they are in it.
    public var exContact: Contact? {
        familyDrama.settlement?.exContactID.flatMap { networking.contact($0) }
    }
}

// MARK: end K7
