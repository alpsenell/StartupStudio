import Foundation

/// Where the founder is standing when they meet these people. Flavor plus
/// a bias: a demo day is full of investors, a hacker house full of
/// engineers.
public enum NetworkingVenue: String, Codable, Equatable, Sendable, CaseIterable {
    case coworkingMixer, rooftopParty, demoDay, hackerHouse, conferenceBar

    public var displayName: String {
        switch self {
        case .coworkingMixer: "Co-working Mixer"
        case .rooftopParty: "Rooftop Party"
        case .demoDay: "Demo Day"
        case .hackerHouse: "Hacker House"
        case .conferenceBar: "Conference Bar"
        }
    }

    /// One line the room opens with.
    public var blurb: String {
        switch self {
        case .coworkingMixer: "Free wine in plastic cups and a lot of lanyards."
        case .rooftopParty: "Somebody's Series A, and everyone's phone is out."
        case .demoDay: "Eight minutes each. The money is standing at the back."
        case .hackerHouse: "Six laptops, one sofa, and an argument about types."
        case .conferenceBar: "The real conference. Nobody is going to the 9am."
        }
    }

    /// The archetypes this room is weighted toward, in the order the
    /// roster is filled. The rest of the room rolls freely.
    public var favoredArchetypes: [ContactArchetype] {
        switch self {
        case .coworkingMixer: [.ops, .marketer]
        case .rooftopParty: [.marketer, .investor]
        case .demoDay: [.investor, .founder]
        case .hackerHouse: [.engineer, .engineer]
        case .conferenceBar: [.founder, .designer]
        }
    }
}

/// What the person at the party actually does.
public enum ContactArchetype: String, Codable, Equatable, Sendable, CaseIterable {
    case engineer, designer, marketer, ops, investor, founder
    // MARK: Iteration 11, wave two — W4 (inside)
    /// Somebody the founder shared a cell with. They are in the address
    /// book because the weeks put them there, not because anybody was
    /// networking: `partyKinds` below is what a room at a demo day can
    /// hold, and this is not in it.
    case inmate
    // MARK: end of Iteration 11, wave two — W4

    public var displayName: String {
        switch self {
        case .engineer: "Engineer"
        case .designer: "Designer"
        case .marketer: "Marketer"
        case .ops: "Operator"
        case .investor: "Investor"
        case .founder: "Founder"
        // MARK: W4 (inside)
        case .inmate: "Did time with you"
        }
    }

    /// The employee role they'd take if they joined.
    public var employeeRole: EmployeeRole {
        switch self {
        case .engineer: .backend
        case .designer: .designer
        case .marketer: .marketer
        case .ops: .ops
        // Money people and other founders come in as operators when they
        // join at all — the point of them is their money and their
        // company, not a seat on the build.
        case .investor, .founder: .ops
        // MARK: W4 (inside) — a job is a job, and it is the one they ask for
        case .inmate: .ops
        }
    }

    /// Whether this person runs something the founder could buy into.
    public var hasCompany: Bool {
        switch self {
        case .founder, .investor: true
        // MARK: W4 (inside) — whatever they ran, they are not running it now
        case .engineer, .designer, .marketer, .ops, .inmate: false
        }
    }

    /// Whether this person has money to put into somebody else's company.
    public var isBacker: Bool {
        switch self {
        case .investor: true
        // MARK: W4 (inside)
        case .engineer, .designer, .marketer, .ops, .founder, .inmate: false
        }
    }
}

// MARK: Iteration 11, wave two — W4 (inside)

extension ContactArchetype {
    /// The archetypes a room at a party can hold, in the order they have
    /// always been in.
    ///
    /// `NetworkingSystem` used to roll over `allCases`, and adding a
    /// seventh case to that enum would have moved every venue roster every
    /// run has ever drawn. The rooms roll over this instead, which is the
    /// six that were always there; `inmate` is not somebody you meet at a
    /// demo day.
    public static let partyKinds: [ContactArchetype] = [
        .engineer, .designer, .marketer, .ops, .investor, .founder,
    ]
}

// MARK: end of Iteration 11, wave two — W4

/// Why somebody stopped being on payroll. Carried on the contact they
/// become, because the address book should be able to say it, and because
/// the three exits price the person differently: a poach sets their ask
/// at the rival's number, the other two at fair pay and a little.
public enum DepartureReason: String, Codable, Equatable, Sendable {
    case quit, poached, fired
    /// Iteration 7 (R2): carried over from a finished company as an
    /// heirloom. Never set by the engine's own departures.
    case formerCompany

    public var displayName: String {
        switch self {
        case .quit: "Quit"
        case .poached: "Poached"
        case .fired: "Let go"
        case .formerCompany: "Former company"
        }
    }
}

extension EmployeeRole {
    /// The archetype an employee reads as once they are a contact again —
    /// the inverse of `ContactArchetype.employeeRole`. Every builder is an
    /// engineer or a designer; the support roles are operators. The
    /// founder never becomes a contact.
    public var contactArchetype: ContactArchetype {
        switch self {
        case .frontend, .backend, .qa: .engineer
        case .designer: .designer
        case .marketer: .marketer
        case .lawyer, .hr, .ops: .ops
        case .founder: .founder
        }
    }
}

/// A person the founder has met. Contacts live in the address book across
/// events: rapport, what they know about the company, and any deal that
/// came of it all persist.
///
/// Somebody who used to work here is a contact too (`leftDay`): they keep
/// the id and the face they had on payroll, so the person the founder runs
/// into at a demo day is recognisably the person who quit in March.
public struct Contact: Codable, Equatable, Sendable, Identifiable {
    public let id: UUID
    public var name: String
    /// Drives the pixel-art look, the same way an employee's does.
    public var appearanceSeed: UInt64
    public var archetype: ContactArchetype
    public var skills: SkillSet
    /// What they'd want as a salaried hire.
    public var askingSalary: Int
    /// Their own startup, for archetypes that have one.
    public var companyName: String?
    /// What their company is nominally worth — the price of a stake.
    public var companyValuation: Int
    /// 0...100: how much they like the founder.
    public var rapport: Double
    /// 0...100: how interested they are in the founder's company.
    public var interest: Double
    public var metDay: Int
    /// The last day the founder spoke to them at all.
    public var lastMetDay: Int
    /// Set once the founder has listened long enough to learn what this
    /// person actually wants; until then the offers show as unknown.
    public var isRevealed: Bool
    /// What became of them, if anything. A contact with an outcome is
    /// closed: they stay in the book as history and never appear in a
    /// room again.
    public var outcome: ContactOutcome?
    /// Set on somebody who used to work here: the day they left, why, and
    /// what they did. Nil on everybody the founder met at a party, and nil
    /// out of any save written before alumni existed.
    public var leftDay: Int?
    public var leftReason: DepartureReason?
    public var leftRole: EmployeeRole?

    public init(
        id: UUID,
        name: String,
        appearanceSeed: UInt64,
        archetype: ContactArchetype,
        skills: SkillSet,
        askingSalary: Int,
        companyName: String? = nil,
        companyValuation: Int = 0,
        rapport: Double = 0,
        interest: Double = 0,
        metDay: Int,
        lastMetDay: Int,
        isRevealed: Bool = false,
        outcome: ContactOutcome? = nil,
        leftDay: Int? = nil,
        leftReason: DepartureReason? = nil,
        leftRole: EmployeeRole? = nil
    ) {
        self.id = id
        self.name = name
        self.appearanceSeed = appearanceSeed
        self.archetype = archetype
        self.skills = skills
        self.askingSalary = askingSalary
        self.companyName = companyName
        self.companyValuation = companyValuation
        self.rapport = rapport
        self.interest = interest
        self.metDay = metDay
        self.lastMetDay = lastMetDay
        self.isRevealed = isRevealed
        self.outcome = outcome
        self.leftDay = leftDay
        self.leftReason = leftReason
        self.leftRole = leftRole
    }

    /// Whether they are still someone the founder could do something with.
    public var isOpen: Bool {
        // MARK: K7 (partner and diary) — the ex is still someone to talk to.
        if outcome == .formerPartner { return true }
        // MARK: end K7
        return outcome == nil
    }

    /// Whether this person used to be on payroll.
    public var isAlumnus: Bool { leftDay != nil }

    /// Whether there is a company here the founder could buy into: the
    /// archetypes that always run one, and an alum who went and founded
    /// something after leaving.
    public var runsACompany: Bool {
        companyValuation > 0 && (archetype.hasCompany || companyName != nil)
    }
}

// MARK: - What a contact is asking for

// The terms are a pure function of the contact and the balance, so the
// number on the offer button in the UI is the number the engine charges —
// there is no second copy of the arithmetic to drift out of sync, and the
// player can see the deal get better as the rapport does.
extension Contact {
    /// Equity they want to come and work here instead of taking a salary,
    /// priced off what they'd be worth on payroll.
    public func equityAsk(_ config: BalanceConfig.NetworkingBalance) -> Double {
        min(config.equityHireEquityMax, max(
            config.equityHireEquityMin, skills.total * config.equityHireEquityPerSkillPoint
        ))
    }

    /// What an equity hire still costs in weekly salary.
    public func equityHireSalary(_ config: BalanceConfig.NetworkingBalance) -> Int {
        Int((Double(askingSalary) * config.equityHireSalaryFactor).rounded())
    }

    /// The slice of *their* company they will sell the founder.
    public func stakeOnOffer(_ config: BalanceConfig.NetworkingBalance) -> Double {
        guard runsACompany else { return 0 }
        return min(
            config.investStakeMax,
            config.investStakeBase + rapport * config.investStakePerRapportPoint
        )
    }

    /// What that slice costs the founder's wallet, after the discount
    /// rapport buys.
    public func stakePrice(_ config: BalanceConfig.NetworkingBalance) -> Int {
        let stake = stakeOnOffer(config)
        guard stake > 0 else { return 0 }
        let discount = max(0, 1 - rapport * config.investDiscountPerRapportPoint)
        return Int((Double(companyValuation) * stake / 100 * discount).rounded())
    }

    /// The cheque they would write and the equity they would want for it.
    /// `dealFactor` is the founder's finance attribute: a founder who
    /// knows what a term sheet says gets more money for the same slice.
    public func angelTerms(
        _ config: BalanceConfig.NetworkingBalance,
        dealFactor: Double
    ) -> (amount: Int, equity: Double) {
        guard archetype.isBacker else { return (0, 0) }
        let equity = max(0.5, config.angelMaxEquity * rapport / 100)
        let amount = Int(
            (Double(config.angelCashPerEquityPoint) * equity * dealFactor).rounded()
        )
        return (amount, equity)
    }
}

/// How a contact's story ended.
public enum ContactOutcome: String, Codable, Equatable, Sendable {
    /// Hired onto payroll like any other employee.
    case hired
    /// Joined as an owner: equity out, a fraction of the salary.
    case partner
    /// The founder bought a stake in their company.
    case backed
    /// They put money into the founder's company.
    case angel
    /// They are the founder's partner now.
    case romance
    /// They folded, moved on, or stopped returning calls.
    case lost
    // MARK: K7 (partner and diary)
    /// Iteration 15 — K7. They were married to the founder. Still in the
    /// book and still someone to talk to, recruit or ask out again:
    /// `isOpen` counts them as open.
    case formerPartner
    // MARK: end K7
}

/// A stake the founder personally holds in somebody else's startup. Paid
/// for out of the wallet, and it pays back into the wallet — this is the
/// founder's own money, not the company's.
public struct Holding: Codable, Equatable, Sendable, Identifiable {
    /// The contact this stake came from, so the address book can link it.
    public let id: UUID
    public var companyName: String
    /// Percentage points owned (0...100).
    public var stakePercent: Double
    /// What the founder paid.
    public var invested: Int
    /// What the company is worth today.
    public var valuation: Int
    public var boughtDay: Int

    public init(
        id: UUID,
        companyName: String,
        stakePercent: Double,
        invested: Int,
        valuation: Int,
        boughtDay: Int
    ) {
        self.id = id
        self.companyName = companyName
        self.stakePercent = stakePercent
        self.invested = invested
        self.valuation = valuation
        self.boughtDay = boughtDay
    }

    /// What the stake is worth on paper right now.
    public var currentValue: Int {
        Int((Double(valuation) * stakePercent / 100).rounded())
    }
}

/// One evening: a room, the people in it, and how much of the founder is
/// left. Ends when the exchanges run out, the founder walks out, or the
/// event expires.
public struct NetworkingEvent: Codable, Equatable, Sendable {
    public var venue: NetworkingVenue
    public var day: Int
    /// The event closes at the start of this day.
    public var expiresOnDay: Int
    /// Contacts in the room, in the order they should be drawn.
    public var contactIDs: [UUID]
    /// Exchanges the founder has left tonight.
    public var conversationsLeft: Int

    public init(
        venue: NetworkingVenue,
        day: Int,
        expiresOnDay: Int,
        contactIDs: [UUID],
        conversationsLeft: Int
    ) {
        self.venue = venue
        self.day = day
        self.expiresOnDay = expiresOnDay
        self.contactIDs = contactIDs
        self.conversationsLeft = conversationsLeft
    }
}

/// What the founder says next.
public enum ConversationTopic: String, Codable, Equatable, Sendable, CaseIterable {
    /// Safe, small, and it always lands.
    case smallTalk
    /// Talk about the work. Lands on the founder's technical and market
    /// sense, and it is worth more than small talk when it does.
    case shopTalk
    /// Ask about them. Never fails, moves rapport a little, and it is the
    /// only way to learn what this person actually wants.
    case listen
    /// Pitch the company. Moves their interest, and needs some rapport
    /// first or it reads as what it is.
    case pitch

    public var displayName: String {
        switch self {
        case .smallTalk: "Small talk"
        case .shopTalk: "Talk shop"
        case .listen: "Ask about them"
        case .pitch: "Pitch the company"
        }
    }
}

/// A deal the founder can put on the table once the rapport is there.
public enum NetworkingOffer: String, Codable, Equatable, Sendable, CaseIterable {
    /// A salaried job, like any other hire.
    case recruit
    /// A seat at the table: equity out of the founder's own stake, and
    /// they work for a fraction of their ask.
    case equityHire
    /// The founder buys into *their* company with wallet money.
    case backThem
    /// They buy into the founder's company: cash in, equity out.
    case takeTheirMoney
    /// Ask them out.
    case askOut

    public var displayName: String {
        switch self {
        case .recruit: "Offer them a job"
        case .equityHire: "Offer them equity"
        case .backThem: "Invest in their startup"
        case .takeTheirMoney: "Ask them to invest"
        case .askOut: "Ask them out"
        }
    }
}

/// A slice of the company signed away to somebody the founder met, kept
/// so the cap table can name them. The equity itself comes out of
/// `InvestorState.equityRemaining`, the same pool a funding round draws
/// on — this is the record of where it went, not a second ledger.
public struct EquityGrant: Codable, Equatable, Sendable, Identifiable {
    /// The contact who holds it.
    public let id: UUID
    public var name: String
    /// Percentage points of the company.
    public var percent: Double
    public var day: Int
    /// Whether they took it to work here or to write a cheque.
    public var reason: Reason

    public enum Reason: String, Codable, Equatable, Sendable {
        case partner, angel

        public var displayName: String {
            switch self {
            case .partner: "Joined for equity"
            case .angel: "Angel round"
            }
        }
    }

    public init(id: UUID, name: String, percent: Double, day: Int, reason: Reason) {
        self.id = id
        self.name = name
        self.percent = percent
        self.day = day
        self.reason = reason
    }
}

/// The address book, the room the founder is standing in, and the stakes
/// they hold in other people's companies. Advanced by `NetworkingSystem`.
public struct NetworkingState: Codable, Equatable, Sendable {
    /// Everybody the founder has met, newest last.
    public var contacts: [Contact]
    /// The event in progress, if the founder is at one.
    public var pendingEvent: NetworkingEvent?
    /// Stakes in other people's startups.
    public var holdings: [Holding]
    /// Equity signed over to people from the address book, oldest first.
    public var grants: [EquityGrant]
    public var lastEventDay: Int?

    public init(
        contacts: [Contact] = [],
        pendingEvent: NetworkingEvent? = nil,
        holdings: [Holding] = [],
        grants: [EquityGrant] = [],
        lastEventDay: Int? = nil
    ) {
        self.contacts = contacts
        self.pendingEvent = pendingEvent
        self.holdings = holdings
        self.grants = grants
        self.lastEventDay = lastEventDay
    }

    public static let empty = NetworkingState()

    public func contact(_ id: UUID) -> Contact? {
        contacts.first { $0.id == id }
    }

    /// The people standing in the room right now, in the event's order.
    public var contactsInRoom: [Contact] {
        guard let event = pendingEvent else { return [] }
        return event.contactIDs.compactMap { id in contacts.first { $0.id == id } }
    }

    /// What every stake the founder holds is worth on paper.
    public var portfolioValue: Int {
        holdings.reduce(0) { $0 + $1.currentValue }
    }

    /// What the founder has put into those stakes.
    public var portfolioInvested: Int {
        holdings.reduce(0) { $0 + $1.invested }
    }
}

/// Something the founder does with their partner. Personal money and
/// personal time — the company pays for none of it.
public enum PartnerActivity: String, Codable, Equatable, Sendable, CaseIterable {
    case call, dateNight, gift, weekendAway

    public var displayName: String {
        switch self {
        case .call: "Call them"
        case .dateNight: "Date night"
        case .gift: "Buy a gift"
        case .weekendAway: "Weekend away"
        }
    }
}
