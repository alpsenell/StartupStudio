import Foundation
import TycoonContent

// Iteration 11, wave two — W2 (family drama). W2 owns this file.
//
// Marriage has a downside. An affair gets discovered, a divorce splits the
// things, custody of the children is a hearing in N1's room, the in-laws
// have a spare room, the sibling wants a job and then a stake and then a
// loan, the parents get old and somebody pays for the care, and a will
// decides who gets the company.
//
// Everything here is inert until the founder acts: the relatives are
// *derived* from `state.seed` (the way `FriendRoster.derive` derives the
// friends) and nothing is written to the save until the player opens the
// room or an affair they started is discovered. `FamilyDramaSystem.run`
// returns on its first line while that is true, so a run that never
// touches any of this writes the bytes it always wrote.

// MARK: - Who the family is

/// The relatives onboarding never made.
public enum FamilyRelation: String, Codable, Equatable, Sendable, CaseIterable {
    case mother, father, sibling, motherInLaw, fatherInLaw

    public var displayName: String {
        switch self {
        case .mother: "Your mother"
        case .father: "Your father"
        case .sibling: "Your sibling"
        case .motherInLaw: "Your mother-in-law"
        case .fatherInLaw: "Your father-in-law"
        }
    }

    /// The short word the card uses under the name.
    public var shortName: String {
        switch self {
        case .mother: "Mum"
        case .father: "Dad"
        case .sibling: "Sibling"
        case .motherInLaw: "Mother-in-law"
        case .fatherInLaw: "Father-in-law"
        }
    }

    /// The two who get old, need care and eventually a funeral.
    public var isParent: Bool { self == .mother || self == .father }
    /// The two who came with the partner.
    public var isInLaw: Bool { self == .motherInLaw || self == .fatherInLaw }
}

/// A relative as the app draws them. Derived from the seed, never stored:
/// nothing about a name and a face is worth a byte.
public struct FamilyRelative: Equatable, Sendable, Identifiable {
    public let relation: FamilyRelation
    public let name: String
    public let appearanceSeed: UInt64
    /// Roughly how old they are today, which is what the care clock reads.
    public let age: Int

    public var id: String { relation.rawValue }

    public init(relation: FamilyRelation, name: String, appearanceSeed: UInt64, age: Int) {
        self.relation = relation
        self.name = name
        self.appearanceSeed = appearanceSeed
        self.age = age
    }

    /// "Mum, 71".
    public var caption: String { "\(relation.shortName), \(age)" }
}

/// Derives the family onboarding never created, exactly the way
/// `FriendRoster.derive` derives the friends: a private stream off the
/// seed, so nobody else's draws move.
public enum FamilyKin {
    /// Where the parents start, in years, on day 0.
    public static let parentStartAge = 66
    public static let siblingStartAge = 34
    /// The calendar's year, so an age matches the diary.
    public static let daysPerYear = 364

    /// The founder's mother, father and sibling, plus the partner's
    /// parents once there is a partner. Deterministic in the seed and in
    /// the partner's appearance seed, so the in-laws arrive with the
    /// partner and are somebody else entirely after a divorce.
    public static func derive(
        seed: UInt64,
        partnerSeed: UInt64?,
        names: NamePools,
        day: Int
    ) -> [FamilyRelative] {
        var rng = SeededRNG(seed: seed &* 0x9E37_79B9_7F4A_7C15 &+ 11)
        let pool = names.firstNames.isEmpty ? ["Alex"] : names.firstNames
        let lastNames = names.lastNames.isEmpty ? [""] : names.lastNames
        let surname = lastNames[rng.nextInt(in: 0...(lastNames.count - 1))]
        let years = max(0, day) / daysPerYear

        func person(_ relation: FamilyRelation, age: Int) -> FamilyRelative {
            let first = pool[rng.nextInt(in: 0...(pool.count - 1))]
            let full = surname.isEmpty ? first : "\(first) \(surname)"
            return FamilyRelative(
                relation: relation, name: full, appearanceSeed: rng.next(), age: age + years
            )
        }

        var people: [FamilyRelative] = [
            person(.mother, age: parentStartAge),
            person(.father, age: parentStartAge + 2),
            person(.sibling, age: siblingStartAge),
        ]
        guard let partnerSeed else { return people }
        var inLaw = SeededRNG(seed: partnerSeed &* 0xD6E8_FEB8_6659_FD93 &+ 7)
        let inLawSurname = lastNames[inLaw.nextInt(in: 0...(lastNames.count - 1))]
        func inLawPerson(_ relation: FamilyRelation, age: Int) -> FamilyRelative {
            let first = pool[inLaw.nextInt(in: 0...(pool.count - 1))]
            let full = inLawSurname.isEmpty ? first : "\(first) \(inLawSurname)"
            return FamilyRelative(
                relation: relation, name: full, appearanceSeed: inLaw.next(), age: age + years
            )
        }
        people.append(inLawPerson(.motherInLaw, age: parentStartAge - 1))
        people.append(inLawPerson(.fatherInLaw, age: parentStartAge + 1))
        return people
    }
}

// MARK: - What the founder changed about them

/// The save's half of a relative: only the things the founder did. Every
/// field is written only once it is non-default, and the array is encoded
/// sorted by relation, so two runs that did the same things in the same
/// order write the same bytes.
public struct FamilyKinRecord: Codable, Equatable, Sendable, Identifiable {
    public var relation: String
    /// 0…100, starting at `defaultBond`.
    public var bond: Double
    public var lastSeenDay: Int?
    /// Set the day they died. Parents only.
    public var diedDay: Int?
    /// Somebody is paying for a home. Parents only.
    public var careSinceDay: Int?
    /// The sibling's escalation: 0 nothing, 1 a job, 2 a stake, 3 a loan.
    public var askStage: Int
    /// The day the current ask went out; `nil` when nothing is pending.
    public var askOpenDay: Int?
    /// The sibling on the payroll, if the founder said yes.
    public var employeeID: UUID?
    /// Points of equity the sibling talked the founder out of.
    public var stakePoints: Double
    /// Money lent, and not seen again.
    public var lentAmount: Int
    /// The in-laws are in the spare room.
    public var movedInDay: Int?

    public static let defaultBond: Double = 55

    public var id: String { relation }

    public init(
        relation: String,
        bond: Double = FamilyKinRecord.defaultBond,
        lastSeenDay: Int? = nil,
        diedDay: Int? = nil,
        careSinceDay: Int? = nil,
        askStage: Int = 0,
        askOpenDay: Int? = nil,
        employeeID: UUID? = nil,
        stakePoints: Double = 0,
        lentAmount: Int = 0,
        movedInDay: Int? = nil
    ) {
        self.relation = relation
        self.bond = bond
        self.lastSeenDay = lastSeenDay
        self.diedDay = diedDay
        self.careSinceDay = careSinceDay
        self.askStage = askStage
        self.askOpenDay = askOpenDay
        self.employeeID = employeeID
        self.stakePoints = stakePoints
        self.lentAmount = lentAmount
        self.movedInDay = movedInDay
    }

    public var kind: FamilyRelation? { FamilyRelation(rawValue: relation) }
    public var isAlive: Bool { diedDay == nil }
    public var isInCare: Bool { careSinceDay != nil && diedDay == nil }
    public var hasOpenAsk: Bool { askOpenDay != nil && askStage > 0 }

    private enum CodingKeys: String, CodingKey {
        case relation, bond, lastSeenDay, diedDay, careSinceDay
        case askStage, askOpenDay, employeeID, stakePoints, lentAmount, movedInDay
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            relation: try c.decode(String.self, forKey: .relation),
            bond: try c.decodeIfPresent(Double.self, forKey: .bond) ?? Self.defaultBond,
            lastSeenDay: try c.decodeIfPresent(Int.self, forKey: .lastSeenDay),
            diedDay: try c.decodeIfPresent(Int.self, forKey: .diedDay),
            careSinceDay: try c.decodeIfPresent(Int.self, forKey: .careSinceDay),
            askStage: try c.decodeIfPresent(Int.self, forKey: .askStage) ?? 0,
            askOpenDay: try c.decodeIfPresent(Int.self, forKey: .askOpenDay),
            employeeID: try c.decodeIfPresent(UUID.self, forKey: .employeeID),
            stakePoints: try c.decodeIfPresent(Double.self, forKey: .stakePoints) ?? 0,
            lentAmount: try c.decodeIfPresent(Int.self, forKey: .lentAmount) ?? 0,
            movedInDay: try c.decodeIfPresent(Int.self, forKey: .movedInDay)
        )
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(relation, forKey: .relation)
        if bond != Self.defaultBond { try c.encode(bond, forKey: .bond) }
        try c.encodeIfPresent(lastSeenDay, forKey: .lastSeenDay)
        try c.encodeIfPresent(diedDay, forKey: .diedDay)
        try c.encodeIfPresent(careSinceDay, forKey: .careSinceDay)
        if askStage != 0 { try c.encode(askStage, forKey: .askStage) }
        try c.encodeIfPresent(askOpenDay, forKey: .askOpenDay)
        try c.encodeIfPresent(employeeID, forKey: .employeeID)
        if stakePoints != 0 { try c.encode(stakePoints, forKey: .stakePoints) }
        if lentAmount != 0 { try c.encode(lentAmount, forKey: .lentAmount) }
        try c.encodeIfPresent(movedInDay, forKey: .movedInDay)
    }
}

/// What the sibling is asking for this time.
public enum FamilyAsk: Int, Codable, Equatable, Sendable, CaseIterable {
    case job = 1, stake = 2, loan = 3

    public var title: String {
        switch self {
        case .job: "They want a job"
        case .stake: "They want a piece of it"
        case .loan: "They want a loan"
        }
    }

    public var body: String {
        switch self {
        case .job:
            "\"You're always saying you can't find people.\" They have a CV. "
                + "It is one page and most of it is the education section."
        case .stake:
            "\"I was there when you had nothing.\" They were. They were there "
                + "on the sofa, mostly, but they were there."
        case .loan:
            "\"Just till the thing comes through.\" There is always a thing, "
                + "and it never comes through."
        }
    }

    public var yesLabel: String {
        switch self {
        case .job: "Put them on the payroll"
        case .stake: "Sign over a slice"
        case .loan: "Write the cheque"
        }
    }
}

// MARK: - The confrontation

/// What the founder says when the partner already knows. Rule 11: the
/// affair is a fact and a conversation about a fact. It is never a scene.
public enum FamilyConfession: String, Codable, Equatable, Sendable, CaseIterable {
    case confess, deny, endIt, leave

    public var label: String {
        switch self {
        case .confess: "Tell them everything"
        case .deny: "Deny it"
        case .endIt: "End it tonight"
        case .leave: "Pack a bag"
        }
    }

    /// The line under the button, so the consequence is on the button.
    public var detail: String {
        switch self {
        case .confess: "Affection −22 · the affair is over · they decide later"
        case .deny: "Affection −38 · they have already seen the calendar"
        case .endIt: "Affection −14 · the affair is over · nothing is said again"
        case .leave: "You end the marriage · the settlement follows"
        }
    }

    /// What the room says back.
    public var line: String {
        switch self {
        case .confess:
            "You say all of it, in order, and it takes four minutes. "
                + "They ask one question about a Tuesday in March."
        case .deny:
            "\"Okay,\" they say, and put the phone down on the table, screen up. "
                + "Neither of you touches it."
        case .endIt:
            "You send the message from the kitchen with them in the room. "
                + "They watch you type it and say nothing at all."
        case .leave:
            "You take the small case, because the big one is in their wardrobe. "
                + "The dog follows you to the door and stops there."
        }
    }

    /// Whether the affair itself ends here.
    public var endsAffair: Bool { self != .deny }
}

// MARK: - The settlement

/// What each side walked away with. Written once, at the divorce.
public struct FamilySettlement: Codable, Equatable, Sendable {
    public var day: Int
    /// The founder kept the roof — and, with it, L7's decor.
    public var keptHome: Bool
    /// Catalog ids the founder kept, sorted.
    public var keptAssetIDs: [String]
    /// Catalog ids that went, sorted.
    public var lostAssetIDs: [String]
    /// The dog, by name, and which way it went.
    public var petName: String
    public var petKept: Bool
    /// Positive: money came in. Negative: the founder wrote a cheque.
    public var cashTransfer: Int
    /// Points of the company the ex now holds.
    public var equityGiven: Double
    /// Who was represented by whom (`CrimeLawyer` raw values).
    public var lawyer: String
    public var theirLawyer: String
    /// The name on the other side of the table.
    public var exName: String
    // MARK: K7 (partner and diary)
    /// The day the founder bought the slice back; `nil` while the ex
    /// still holds it (and on every save written before K7).
    public var boughtOutDay: Int? = nil
    /// The ex in the address book. `nil` on a settlement signed before K7:
    /// "They changed their number".
    public var exContactID: UUID? = nil
    // MARK: end K7

    public init(
        day: Int,
        keptHome: Bool,
        keptAssetIDs: [String] = [],
        lostAssetIDs: [String] = [],
        petName: String = "",
        petKept: Bool = false,
        cashTransfer: Int = 0,
        equityGiven: Double = 0,
        lawyer: String = CrimeLawyer.dutySolicitor.rawValue,
        theirLawyer: String = CrimeLawyer.dutySolicitor.rawValue,
        exName: String = ""
    ) {
        self.day = day
        self.keptHome = keptHome
        self.keptAssetIDs = keptAssetIDs
        self.lostAssetIDs = lostAssetIDs
        self.petName = petName
        self.petKept = petKept
        self.cashTransfer = cashTransfer
        self.equityGiven = equityGiven
        self.lawyer = lawyer
        self.theirLawyer = theirLawyer
        self.exName = exName
    }
}

// MARK: - Custody

/// How the family court split the week.
public enum FamilyCustody: String, Codable, Equatable, Sendable, CaseIterable {
    case full, shared, weekends, none

    public var displayName: String {
        switch self {
        case .full: "Full custody"
        case .shared: "Shared custody"
        case .weekends: "Weekends only"
        case .none: "No custody"
        }
    }

    /// What it does to every child's bond, once.
    public var bondDelta: Double {
        switch self {
        case .full: 6
        case .shared: 0
        case .weekends: -9
        case .none: -22
        }
    }

    /// Whether the children live with the founder. The home follows them.
    public var keepsTheHouse: Bool { self == .full || self == .shared }

    /// The line the bench reads out.
    public var closing: String {
        switch self {
        case .full:
            "\"The children will live with the applicant.\" Nobody in the room looks pleased. "
                + "That is not what the room is for."
        case .shared:
            "\"Week on, week off, and both of you will be civil at the handover.\" "
                + "One of you already knows they will not be."
        case .weekends:
            "\"Alternate weekends and half the holidays.\" It sounds like a lot until "
                + "you write it down as days."
        case .none:
            "\"Contact to be agreed between the parties.\" There is no party to agree with."
        }
    }
}

// MARK: - The will

/// Who gets the company when the founder is gone.
public enum FamilyHeir: String, Codable, Equatable, Sendable, CaseIterable {
    case partner, child, employee, sibling, nobody

    public var displayName: String {
        switch self {
        case .partner: "Your partner"
        case .child: "One of the children"
        case .employee: "The longest-serving"
        case .sibling: "Your sibling"
        case .nobody: "Nobody in particular"
        }
    }

    public var note: String {
        switch self {
        case .partner: "They have heard the numbers at dinner for years."
        case .child: "They grew up in the office. Some of that was on purpose."
        case .employee: "They were here before the second desk arrived."
        case .sibling: "It would be the first thing they finished."
        case .nobody: "The board can fight about it. They will enjoy that."
        }
    }
}

// MARK: - The state

public struct FamilyDramaState: Codable, Equatable, Sendable {
    /// Set the first time the player opens the family room — the identity
    /// gate, the same shape as N3's assets screen.
    public var openedDay: Int?
    /// The day the partner found out. The confrontation is on screen
    /// while nothing has been said back.
    public var confrontedDay: Int?
    public var confessionAnswer: String?
    public var divorcedDay: Int?
    public var settlement: FamilySettlement?
    /// The custody case in N1's room, and how it ended.
    public var custodyCaseID: String?
    public var custodyVerdict: String?
    public var custodyDecidedDay: Int?
    /// Every relative the founder has changed.
    public var kin: [FamilyKinRecord]
    /// What the home is costing the wallet every week.
    public var careWeeklyBill: Int
    /// Who inherits — W2's own field, behind the scaffold's name.
    public var heir: String?
    public var heirChildID: UUID?
    public var heirName: String?
    public var willSignedDay: Int?
    /// A parent has died and the room is full. One argument to settle.
    public var funeralDay: Int?
    public var funeralRelation: String?
    public var funeralAnswer: String?
    /// The last day the weekly sweep ran, so a save loaded mid-week does
    /// not roll twice.
    public var lastSweepDay: Int?
    /// The day the parents' birthdays went into the diary, so they go in
    /// exactly once.
    public var calendarSeededDay: Int?
    // MARK: K7 (partner and diary)
    /// The marriage as it stood when the founder packed a bag, so the
    /// settlement can follow. Cleared by the divorce.
    public var leaving: FamilyLeaving? = nil
    // MARK: end K7

    public init(
        openedDay: Int? = nil,
        confrontedDay: Int? = nil,
        confessionAnswer: String? = nil,
        divorcedDay: Int? = nil,
        settlement: FamilySettlement? = nil,
        custodyCaseID: String? = nil,
        custodyVerdict: String? = nil,
        custodyDecidedDay: Int? = nil,
        kin: [FamilyKinRecord] = [],
        careWeeklyBill: Int = 0,
        heir: String? = nil,
        heirChildID: UUID? = nil,
        heirName: String? = nil,
        willSignedDay: Int? = nil,
        funeralDay: Int? = nil,
        funeralRelation: String? = nil,
        funeralAnswer: String? = nil,
        lastSweepDay: Int? = nil,
        calendarSeededDay: Int? = nil
    ) {
        self.openedDay = openedDay
        self.confrontedDay = confrontedDay
        self.confessionAnswer = confessionAnswer
        self.divorcedDay = divorcedDay
        self.settlement = settlement
        self.custodyCaseID = custodyCaseID
        self.custodyVerdict = custodyVerdict
        self.custodyDecidedDay = custodyDecidedDay
        self.kin = kin
        self.careWeeklyBill = careWeeklyBill
        self.heir = heir
        self.heirChildID = heirChildID
        self.heirName = heirName
        self.willSignedDay = willSignedDay
        self.funeralDay = funeralDay
        self.funeralRelation = funeralRelation
        self.funeralAnswer = funeralAnswer
        self.lastSweepDay = lastSweepDay
        self.calendarSeededDay = calendarSeededDay
    }

    public static let empty = FamilyDramaState()

    // MARK: Queries

    /// They know, and nothing has been said back yet.
    public var isConfrontationOpen: Bool { confrontedDay != nil && confessionAnswer == nil }
    /// The funeral is on screen.
    public var isFuneralOpen: Bool { funeralDay != nil && funeralAnswer == nil }
    public var isDivorced: Bool { divorcedDay != nil }
    public var custody: FamilyCustody? { custodyVerdict.flatMap(FamilyCustody.init(rawValue:)) }
    public var heirKind: FamilyHeir? { heir.flatMap(FamilyHeir.init(rawValue:)) }

    public func record(_ relation: FamilyRelation) -> FamilyKinRecord? {
        kin.first { $0.relation == relation.rawValue }
    }

    /// The record for a relative, made on demand — the only place a
    /// relative starts costing bytes.
    mutating func upsert(_ relation: FamilyRelation, _ body: (inout FamilyKinRecord) -> Void) {
        if let index = kin.firstIndex(where: { $0.relation == relation.rawValue }) {
            body(&kin[index])
        } else {
            var record = FamilyKinRecord(relation: relation.rawValue)
            body(&record)
            kin.append(record)
            kin.sort { $0.relation < $1.relation }
        }
    }

    /// The ask waiting for an answer, if any.
    public var pendingAsk: FamilyKinRecord? { kin.first(where: \.hasOpenAsk) }

    // MARK: Codable

    private enum CodingKeys: String, CodingKey {
        case openedDay, confrontedDay, confessionAnswer, divorcedDay, settlement
        case custodyCaseID, custodyVerdict, custodyDecidedDay, kin, careWeeklyBill
        case heir, heirChildID, heirName, willSignedDay
        case funeralDay, funeralRelation, funeralAnswer, lastSweepDay, calendarSeededDay
        // MARK: K7 (partner and diary)
        case leaving
        // MARK: end K7
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            openedDay: try c.decodeIfPresent(Int.self, forKey: .openedDay),
            confrontedDay: try c.decodeIfPresent(Int.self, forKey: .confrontedDay),
            confessionAnswer: try c.decodeIfPresent(String.self, forKey: .confessionAnswer),
            divorcedDay: try c.decodeIfPresent(Int.self, forKey: .divorcedDay),
            settlement: try c.decodeIfPresent(FamilySettlement.self, forKey: .settlement),
            custodyCaseID: try c.decodeIfPresent(String.self, forKey: .custodyCaseID),
            custodyVerdict: try c.decodeIfPresent(String.self, forKey: .custodyVerdict),
            custodyDecidedDay: try c.decodeIfPresent(Int.self, forKey: .custodyDecidedDay),
            kin: try c.decodeIfPresent([FamilyKinRecord].self, forKey: .kin) ?? [],
            careWeeklyBill: try c.decodeIfPresent(Int.self, forKey: .careWeeklyBill) ?? 0,
            heir: try c.decodeIfPresent(String.self, forKey: .heir),
            heirChildID: try c.decodeIfPresent(UUID.self, forKey: .heirChildID),
            heirName: try c.decodeIfPresent(String.self, forKey: .heirName),
            willSignedDay: try c.decodeIfPresent(Int.self, forKey: .willSignedDay),
            funeralDay: try c.decodeIfPresent(Int.self, forKey: .funeralDay),
            funeralRelation: try c.decodeIfPresent(String.self, forKey: .funeralRelation),
            funeralAnswer: try c.decodeIfPresent(String.self, forKey: .funeralAnswer),
            lastSweepDay: try c.decodeIfPresent(Int.self, forKey: .lastSweepDay),
            calendarSeededDay: try c.decodeIfPresent(Int.self, forKey: .calendarSeededDay)
        )
        // MARK: K7 (partner and diary)
        leaving = try c.decodeIfPresent(FamilyLeaving.self, forKey: .leaving)
        // MARK: end K7
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(openedDay, forKey: .openedDay)
        try c.encodeIfPresent(confrontedDay, forKey: .confrontedDay)
        try c.encodeIfPresent(confessionAnswer, forKey: .confessionAnswer)
        try c.encodeIfPresent(divorcedDay, forKey: .divorcedDay)
        try c.encodeIfPresent(settlement, forKey: .settlement)
        try c.encodeIfPresent(custodyCaseID, forKey: .custodyCaseID)
        try c.encodeIfPresent(custodyVerdict, forKey: .custodyVerdict)
        try c.encodeIfPresent(custodyDecidedDay, forKey: .custodyDecidedDay)
        if !kin.isEmpty { try c.encode(kin.sorted { $0.relation < $1.relation }, forKey: .kin) }
        if careWeeklyBill != 0 { try c.encode(careWeeklyBill, forKey: .careWeeklyBill) }
        try c.encodeIfPresent(heir, forKey: .heir)
        try c.encodeIfPresent(heirChildID, forKey: .heirChildID)
        try c.encodeIfPresent(heirName, forKey: .heirName)
        try c.encodeIfPresent(willSignedDay, forKey: .willSignedDay)
        try c.encodeIfPresent(funeralDay, forKey: .funeralDay)
        try c.encodeIfPresent(funeralRelation, forKey: .funeralRelation)
        try c.encodeIfPresent(funeralAnswer, forKey: .funeralAnswer)
        try c.encodeIfPresent(lastSweepDay, forKey: .lastSweepDay)
        try c.encodeIfPresent(calendarSeededDay, forKey: .calendarSeededDay)
        // MARK: K7 (partner and diary)
        try c.encodeIfPresent(leaving, forKey: .leaving)
        // MARK: end K7
    }
}

// MARK: - The arithmetic

/// The lane's pure half: the odds of being found out, what a settlement
/// owes, what a childhood is worth as evidence, and how a family court
/// grades three exchanges.
///
/// Nothing here mutates, draws or reads a clock, so the app can put the
/// number on the button that the engine is about to write.
public enum FamilyDrama {
    /// The narrative flag the discovery raises; the `family_` events gate
    /// on it with `requires.flagsAll`.
    public static let discoveredFlag = "family_affair_found"
    /// Raised by the divorce.
    public static let divorcedFlag = "family_divorced"
    /// Raised while the founder is paying for a parent's care.
    public static let careFlag = "family_care"
    /// Raised by a parent's death.
    public static let bereavedFlag = "family_bereaved"
    /// Raised once the will is signed.
    public static let willFlag = "family_will"
    /// Raised the first time the founder opens the family room. Every
    /// `family_` beat that is not already behind one of the flags above
    /// gates on it, so nothing this lane adds joins the pool a pacing bot
    /// draws from — which is what keeps the byte-identical fixtures
    /// byte-identical.
    public static let openedFlag = "family_room"
    /// The `LegalCase.kind` a custody hearing carries.
    public static let custodyCaseKind = "custody"

    // MARK: Discovery

    /// The weekly chance the affair surfaces.
    ///
    /// Three things move it: how long it has been running (a fortnight is
    /// a secret, a year is a habit), whether somebody is already watching
    /// the founder for a vice (N3's `intervened` — a standing
    /// intervention means a partner who is already counting the evenings),
    /// and fame (N4: a famous founder is photographed at lunch).
    /// Ceilinged, so it is never certain in any one week.
    public static func discoveryChance(
        weeksRunning: Double,
        intervened: Bool,
        fame: Double,
        balance: BalanceConfig.FamilyDramaBalance
    ) -> Double {
        let base = balance.discoveryWeekly
            * (1 + max(0, weeksRunning) * balance.discoveryAgeFactor)
        let watched = intervened ? balance.interventionDiscoveryBonus : 0
        let famous = max(0, min(100, fame)) / 100 * balance.fameDiscoveryBonus
        return min(balance.discoveryCeiling, base + watched + famous)
    }

    // MARK: The settlement

    /// The founder's share of the estate, 0…1.
    ///
    /// Half, and then the lawyers argue: the difference between the two
    /// tiers moves it, and an affair the court has heard about moves it
    /// the other way. Clamped, because no judge gives anybody everything.
    public static func entitlement(
        lawyer: CrimeLawyer,
        theirLawyer: CrimeLawyer,
        affairDiscovered: Bool,
        marriedDays: Int,
        balance: BalanceConfig.FamilyDramaBalance
    ) -> Double {
        var share = 0.5 + (lawyer.weight - theirLawyer.weight) * balance.lawyerSwing
        if affairDiscovered { share -= balance.affairSharePenalty }
        // A long marriage flattens it back towards half, whoever paid for
        // the better suit.
        let years = Double(max(0, marriedDays)) / Double(FamilyKin.daysPerYear)
        let pull = min(1, years / max(1, balance.longMarriageYears))
        share = share + (0.5 - share) * pull * balance.longMarriagePull
        return min(balance.shareCeiling, max(balance.shareFloor, share))
    }

    /// The equity a long marriage costs, in points off `equityRemaining`.
    /// Zero for anything shorter than the balance's threshold, which is
    /// why an early divorce is only about the car.
    public static func equityToEx(
        marriedDays: Int,
        equityRemaining: Double,
        balance: BalanceConfig.FamilyDramaBalance,
        // MARK: K7 (partner and diary)
        // A partner who worked at the company was a co-founder in all but
        // name: the threshold does not apply and every year counts.
        ignoresMarriedDays: Bool = false
        // MARK: end K7
    ) -> Double {
        let threshold = ignoresMarriedDays ? 0 : balance.equityMarriedDays // K7
        guard marriedDays >= threshold else { return 0 }
        let years = Double(marriedDays - threshold)
            / Double(FamilyKin.daysPerYear)
        let points = balance.equityBasePoints + years * balance.equityPointsPerYear
        return max(0, min(balance.equityMaxPoints, min(equityRemaining * 0.5, points)))
    }

    /// What the founder's lawyer costs, by tier — the same three tiers the
    /// courtroom already sells, priced for a family court.
    public static func lawyerFee(
        _ lawyer: CrimeLawyer, balance: BalanceConfig.FamilyDramaBalance
    ) -> Int {
        switch lawyer {
        case .dutySolicitor: 0
        case .highStreet: balance.highStreetFee
        case .silk: balance.silkFee
        }
    }

    // MARK: Custody

    /// What one kind of memory is worth in a family court, in points.
    /// Positive is the founder's; negative is the other side's. This is
    /// the whole evidence table, and the sheet prints it as it is.
    public static func evidenceWeight(_ kind: ChildMemoryKind) -> Double {
        switch kind {
        case .birthdayKept: 3
        case .evening: 2
        case .internSummer: 2
        case .wedding: 1
        case .launch: 0.5
        case .chapter: 0
        case .grewUp: 0
        case .exit: 0
        case .sabbatical: 1
        case .missedBirthday: -4
        case .burnout: -2
        case .hospital: -1.5
        case .eviction: -2
        case .internQuit: -1
        }
    }

    /// The custody hearing's opening standing: the children's ledgers,
    /// scaled, plus what the bond already says, less a discovered affair.
    ///
    /// A founder who kept the birthdays walks in ahead. A founder whose
    /// children remember two burnouts and a missed birthday does not.
    public static func custodyStanding(
        children: [Child],
        affairDiscovered: Bool,
        lawyer: CrimeLawyer,
        balance: BalanceConfig.FamilyDramaBalance
    ) -> Double {
        guard !children.isEmpty else { return 0 }
        var points = 0.0
        for child in children {
            for memory in child.memories {
                guard let kind = ChildMemoryKind(rawValue: memory.kind) else { continue }
                points += evidenceWeight(kind)
            }
            points += (child.bond - Child.defaultBond) * balance.bondEvidenceFactor
        }
        var standing = points / Double(children.count) * balance.evidenceScale
        standing += lawyer.weight * balance.custodyLawyerFactor
        if affairDiscovered { standing -= balance.custodyAffairPenalty }
        return min(100, max(-100, standing))
    }

    /// The band a standing falls into. Shared is deliberately the wide
    /// middle: most families end up with a rota.
    public static func custodyVerdict(
        _ standing: Double, balance: BalanceConfig.FamilyDramaBalance
    ) -> FamilyCustody {
        switch standing {
        case balance.fullCustodyStanding...: .full
        case balance.sharedCustodyStanding..<balance.fullCustodyStanding: .shared
        case balance.weekendsStanding..<balance.sharedCustodyStanding: .weekends
        default: .none
        }
    }

    /// How the room reads right now, in one word, for the bench.
    public static func custodyLabel(
        _ standing: Double, balance: BalanceConfig.FamilyDramaBalance
    ) -> String {
        custodyVerdict(standing, balance: balance).displayName
    }

    // MARK: The family court's copy

    /// The opener the family court uses instead of a charge.
    public static func custodyOpener(childCount: Int) -> String {
        childCount == 1
            ? "\"We are here about one child, and we have until four o'clock.\""
            : "\"We are here about \(childCount) children. Nobody is on trial. "
                + "Everybody behaves that way anyway.\""
    }

    /// What the bench says back. Deterministic in the roll that graded the
    /// exchange, so no extra draw is needed — the same contract as
    /// `Crime.reply`.
    public static func custodyReply(
        _ exchange: CrimeExchange, landed: Bool, roll: Double
    ) -> String {
        let pool = landed ? custodyLanded(exchange) : custodyMissed(exchange)
        let index = min(pool.count - 1, max(0, Int(roll * Double(pool.count))))
        return pool[index]
    }

    private static func custodyLanded(_ exchange: CrimeExchange) -> [String] {
        switch exchange {
        case .deny: [
            "\"The diary says you were there.\" For once, the diary says you were there.",
            "The other side's counsel stops writing and looks at their own notes.",
            "\"Noted.\" The bench moves on, which is the best outcome available.",
        ]
        case .explain: [
            "You describe a Tuesday routine in detail and the room believes you.",
            "\"So the school run is yours.\" \"On the days I said.\" \"Yes. It is.\"",
            "The welfare officer nods once. It is the only thing they do all morning.",
        ]
        case .apologise: [
            "\"The court notes that the applicant is not pretending.\"",
            "You say the missed birthday out loud before anybody else can.",
            "The bench takes their glasses off, which is either very good or very bad.",
        ]
        case .blameTheCFO: [
            "\"The company kept you late.\" \"The company is me.\" The bench allows it.",
            "You put it on the round, and the round is at least real.",
            "\"Everybody's work is difficult.\" But they write the hours down.",
        ]
        case .objection: [
            "\"That is not what the ledger says, and counsel knows it.\" Sustained.",
            "\"Sustained. Ask it properly.\"",
            "Your solicitor objects to a characterisation and, remarkably, wins.",
        ]
        }
    }

    private static func custodyMissed(_ exchange: CrimeExchange) -> [String] {
        switch exchange {
        case .deny: [
            "The other side reads out three dates. You were at the office for all of them.",
            "\"You were there.\" \"I was.\" \"Until?\" You do not finish the sentence.",
            "The children's own words are read into the record. That part is quiet.",
        ]
        case .explain: [
            "You explain the funding round to a family court. It goes how you'd think.",
            "\"In hours, please.\" In hours it is not very many.",
            "The bench asks which school. You take one second too long.",
        ]
        case .apologise: [
            "\"Sorry you missed it, or sorry it is on a list?\"",
            "The apology is taken as agreed fact, because that is what it was.",
            "\"Thank you. The court will note the birthdays as admitted.\"",
        ]
        case .blameTheCFO: [
            "\"The company\" is not a person the court can order to do the school run.",
            "You blame the round. Your ex-partner writes something short down.",
            "The bench dislikes this more than it disliked the missed birthdays.",
        ]
        case .objection: [
            "\"Overruled. This is not that kind of court.\"",
            "\"Overruled — and we will not be doing that again this morning.\"",
            "Your solicitor objects. The bench waits. Your solicitor sits.",
        ]
        }
    }

    // MARK: The funeral

    /// The one argument the family has at the funeral, and the two ways it
    /// can be settled.
    public enum FuneralArgument: String, Codable, Equatable, Sendable, CaseIterable {
        case takeIt, letThemHaveIt, walkOut

        public var label: String {
            switch self {
            case .takeIt: "Say it, in the car park"
            case .letThemHaveIt: "Let them have it"
            case .walkOut: "Leave before the sandwiches"
            }
        }

        public var detail: String {
            switch self {
            case .takeIt: "Sibling bond −18 · mood +6 · it is said"
            case .letThemHaveIt: "Sibling bond +12 · mood −8"
            case .walkOut: "Sibling bond −8 · mood −4 · you get the afternoon back"
            }
        }

        public var line: String {
            switch self {
            case .takeIt:
                "You say it by the hired cars, at a normal volume, and a cousin "
                    + "pretends to look at their phone."
            case .letThemHaveIt:
                "You let them tell the story their way, including the part that is "
                    + "not true, and you hold the plate."
            case .walkOut:
                "You get in the car at twenty past. Nobody comes after you, which is "
                    + "either kind or the whole problem."
            }
        }
    }
}
