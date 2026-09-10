import Foundation

// Iteration 11, wave two — W3 owns this file. What the founder does to a
// rival studio in the dark: a private investigator on their founder, a
// mole in their office, a poach that uses what the PI found, their
// roadmap bought off somebody, and their storefront taken down in the
// week they launch.
//
// **Identity at the default.** `GameState.espionage` is `.empty` until the
// player presses one of five buttons on a rival's page; it is encoded only
// while it is non-empty, and `EspionageSystem` returns on the first line of
// its tick while it is empty. Nothing here is reached by a pacing bot, a
// fixture replay or a save written before it existed. The rival half —
// their mole, their PI, their hack — runs on N5's machine behind
// `OfficeSecretsState.watching`, which only the Team tab sets, so that half
// is gated too.
//
// **Draws.** `state.socialRNG` only, and only from an operation the player
// asked for: one word for whether it lands, one for whether it is traced,
// and one for which facts a dossier comes back with. `rng` and `worldRNG`
// are never touched.
//
// Types are prefixed `Espionage…` (rule 8); the counterintelligence half
// lives on N5's `SecretKind`/`SecretResponse` under W3 markers, because a
// rival running a thread against you *is* a thread.

// MARK: - The five operations

/// The five things the founder can have done to a studio. Raw values go
/// into saves (`EspionageOpRecord.operation`) and onto the command line
/// (`-autoSpy <operation>`), so they are stable.
public enum EspionageOperation: String, Codable, Equatable, Sendable, CaseIterable {
    /// A private investigator on the other founder. Comes back with a
    /// dossier: three things that are true and one that is useful.
    case tailFounder
    /// Somebody of yours, inside theirs. Reports what they are shipping,
    /// a month before they ship it.
    case placeMole
    /// The poach the non-compete stopped, made with the dossier in hand.
    case poachWithDirt
    /// Their roadmap, bought from somebody who had a copy of it.
    case buyRoadmap
    /// Their storefront, down in the week they launch.
    case hackStorefront

    public var displayName: String {
        switch self {
        case .tailFounder: "Put somebody on their founder"
        case .placeMole: "Place a mole"
        case .poachWithDirt: "Poach with the dirt"
        case .buyRoadmap: "Buy their roadmap"
        case .hackStorefront: "Take the storefront down"
        }
    }

    /// The one-line pitch on the button, before the numbers.
    public var pitch: String {
        switch self {
        case .tailFounder: "A quiet man with a camera and no opinions about any of it."
        case .placeMole: "Somebody junior, somewhere boring, with a very good memory."
        case .poachWithDirt: "Ask again, and mention the photographs."
        case .buyRoadmap: "Everything they are building, in the order they are building it."
        case .hackStorefront: "Their launch week, spent explaining an error page."
        }
    }

    /// What the record entry calls it, in the founder's own diary.
    public var recordLine: String {
        switch self {
        case .tailFounder: "You paid somebody to follow another founder home."
        case .placeMole: "You put one of yours inside somebody else's company."
        case .poachWithDirt: "You hired somebody by making it awkward not to come."
        case .buyRoadmap: "You bought a document you knew was not for sale."
        case .hackStorefront: "You took a competitor's shop off the internet for a week."
        }
    }

    public var systemImageName: String {
        switch self {
        case .tailFounder: "binoculars.fill"
        case .placeMole: "person.fill.badge.plus"
        case .poachWithDirt: "person.crop.circle.badge.exclamationmark.fill"
        case .buyRoadmap: "map.fill"
        case .hackStorefront: "bolt.horizontal.circle.fill"
        }
    }

    /// The `spy_*` id for what a run of this operation prints.
    public func eventID(_ suffix: String) -> String {
        "spy_\(rawValue.lowercased())_\(suffix)"
    }
}

// MARK: - Why an operation was refused

/// Rule 7: a refused operation says why, in the founder's words.
public enum EspionageRefusal: String, Equatable, Sendable, CaseIterable {
    case casePending, away, noRival, noWallet, noCompanyCash
    case needDossier, alreadyDone, tooSoon, nothingToHack, nothingToBuild

    public var sentence: String {
        switch self {
        case .casePending: "You have a hearing on the books. Now is not the week for this."
        case .away: "You're not at your desk, and this is not a phone call."
        case .noRival: "This studio is gone. There is nobody left to do it to."
        case .noWallet: "Cash out of your own pocket, and your pocket is empty."
        case .noCompanyCash: "The company cannot cover it, and this cannot go on a card."
        case .needDossier: "You have nothing on them yet. Put somebody on their founder first."
        case .alreadyDone: "You already have that. Doing it twice is how people get caught."
        case .tooSoon: "Too soon after the last one. Let the dust settle."
        case .nothingToHack: "They have nothing on sale worth taking down."
        case .nothingToBuild: "You have nothing in development to point their roadmap at."
        }
    }
}

// MARK: - What comes back

/// What a private investigator found. Three facts and a number: the
/// number is what the facts are worth in the room where they matter.
public struct EspionageDossier: Codable, Equatable, Sendable, Identifiable {
    public var rivalID: UUID
    /// The studio's name on the day it was compiled, so a folded rival's
    /// dossier still reads.
    public var rivalName: String
    public var day: Int
    /// Three things, in the order the investigator found them.
    public var facts: [String]
    /// 0…1. How much the facts are worth: added to the odds of everything
    /// else you do to this studio, and what the poach leans on.
    public var leverage: Double

    public var id: UUID { rivalID }

    public init(
        rivalID: UUID,
        rivalName: String,
        day: Int,
        facts: [String] = [],
        leverage: Double = 0
    ) {
        self.rivalID = rivalID
        self.rivalName = rivalName
        self.day = day
        self.facts = facts
        self.leverage = leverage
    }

    /// Paper goes cold: a dossier is worth its full leverage for a season
    /// and half of it after that.
    public func leverage(on day: Int, coldDays: Int) -> Double {
        day - self.day <= coldDays ? leverage : leverage / 2
    }
}

/// What the mole sends back: the thing they are shipping, and roughly
/// when. The feature board's "they are shipping X" card reads this.
public struct EspionageIntel: Codable, Equatable, Sendable, Identifiable {
    public var rivalID: UUID
    public var rivalName: String
    public var topicID: String
    /// The name the mole heard it called inside the building.
    public var codename: String
    /// When they expect to ship it.
    public var expectedDay: Int
    /// When the mole reported.
    public var day: Int
    /// Set once the day arrived and the report was closed out.
    public var closedDay: Int?

    public var id: String { "\(rivalID.uuidString)-\(topicID)-\(day)" }

    public init(
        rivalID: UUID,
        rivalName: String,
        topicID: String,
        codename: String,
        expectedDay: Int,
        day: Int,
        closedDay: Int? = nil
    ) {
        self.rivalID = rivalID
        self.rivalName = rivalName
        self.topicID = topicID
        self.codename = codename
        self.expectedDay = expectedDay
        self.day = day
        self.closedDay = closedDay
    }

    public var isLive: Bool { closedDay == nil }

    public func daysToLaunch(from day: Int) -> Int { max(0, expectedDay - day) }
}

/// One operation, run: what it was, who it was against, whether it landed
/// and whether anybody traced it.
public struct EspionageOpRecord: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    /// `EspionageOperation`'s raw value.
    public var operation: String
    public var rivalID: UUID
    public var rivalName: String
    public var day: Int
    public var landed: Bool
    /// Set on the day somebody worked out who did it.
    public var tracedDay: Int?
    /// One line for the card: what it actually bought.
    public var note: String

    public init(
        id: String,
        operation: String,
        rivalID: UUID,
        rivalName: String,
        day: Int,
        landed: Bool,
        tracedDay: Int? = nil,
        note: String = ""
    ) {
        self.id = id
        self.operation = operation
        self.rivalID = rivalID
        self.rivalName = rivalName
        self.day = day
        self.landed = landed
        self.tracedDay = tracedDay
        self.note = note
    }

    public var op: EspionageOperation? { EspionageOperation(rawValue: operation) }
}

// MARK: - The state

/// Everything the founder has had done to somebody else.
public struct EspionageState: Codable, Equatable, Sendable {
    /// Every operation run, oldest first, capped.
    public var ops: [EspionageOpRecord]
    /// One dossier per studio, the newest kept.
    public var dossiers: [EspionageDossier]
    /// Mole reports, live and closed.
    public var intel: [EspionageIntel]
    /// Topics whose roadmap the founder has bought, so the card can say
    /// which shelf the plan came off.
    public var stolenTopicIDs: [String]
    /// The day the last operation ran, for the cooling-off period.
    public var lastOpDay: Int?

    static let maxOps = 16
    static let maxIntel = 8

    public init(
        ops: [EspionageOpRecord] = [],
        dossiers: [EspionageDossier] = [],
        intel: [EspionageIntel] = [],
        stolenTopicIDs: [String] = [],
        lastOpDay: Int? = nil
    ) {
        self.ops = ops
        self.dossiers = dossiers
        self.intel = intel
        self.stolenTopicIDs = stolenTopicIDs
        self.lastOpDay = lastOpDay
    }

    public static let empty = EspionageState()

    /// The dossier on one studio, if there is one.
    public func dossier(on rivalID: UUID) -> EspionageDossier? {
        dossiers.first { $0.rivalID == rivalID }
    }

    /// Live mole reports about one studio.
    public func liveIntel(on rivalID: UUID) -> EspionageIntel? {
        intel.first { $0.rivalID == rivalID && $0.isLive }
    }

    /// Every live report, newest first — the card and the rival column
    /// both read this rather than the whole list.
    public var liveIntel: [EspionageIntel] {
        intel.filter(\.isLive).sorted { $0.expectedDay < $1.expectedDay }
    }

    /// Whether this operation has already been run against this studio and
    /// is still standing (a dossier, a mole, a bought roadmap).
    public func hasStanding(_ operation: EspionageOperation, against rivalID: UUID) -> Bool {
        switch operation {
        case .tailFounder: return dossier(on: rivalID) != nil
        case .placeMole: return liveIntel(on: rivalID) != nil
        default: return false
        }
    }

    public func ops(against rivalID: UUID) -> [EspionageOpRecord] {
        ops.filter { $0.rivalID == rivalID }
    }

    private enum CodingKeys: String, CodingKey {
        case ops, dossiers, intel, stolenTopicIDs, lastOpDay
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            ops: try container.decodeIfPresent([EspionageOpRecord].self, forKey: .ops) ?? [],
            dossiers: try container.decodeIfPresent([EspionageDossier].self, forKey: .dossiers) ?? [],
            intel: try container.decodeIfPresent([EspionageIntel].self, forKey: .intel) ?? [],
            stolenTopicIDs: try container.decodeIfPresent([String].self, forKey: .stolenTopicIDs) ?? [],
            lastOpDay: try container.decodeIfPresent(Int.self, forKey: .lastOpDay)
        )
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if !ops.isEmpty { try container.encode(ops, forKey: .ops) }
        if !dossiers.isEmpty { try container.encode(dossiers, forKey: .dossiers) }
        if !intel.isEmpty { try container.encode(intel, forKey: .intel) }
        if !stolenTopicIDs.isEmpty {
            try container.encode(stolenTopicIDs, forKey: .stolenTopicIDs)
        }
        try container.encodeIfPresent(lastOpDay, forKey: .lastOpDay)
    }
}

// MARK: - The arithmetic

/// The lane's pure half: what an operation costs, how likely it is to
/// land, how likely it is to be traced, and what it is worth.
///
/// Nothing here mutates or draws. The card puts exactly these numbers on
/// the button, so the odds the player reads are the odds the engine rolls.
public enum Espionage {

    /// What it costs, and out of whose pocket. A private investigator and
    /// a poach are the founder's own money; a mole, a roadmap and a
    /// contractor with a botnet go through the company, because they have
    /// to be invoiced as something.
    public static func cost(
        _ operation: EspionageOperation, balance: BalanceConfig.EspionageBalance
    ) -> (wallet: Int, company: Int) {
        switch operation {
        case .tailFounder: (balance.tailFee, 0)
        case .placeMole: (0, balance.moleFee)
        case .poachWithDirt: (balance.poachFee, 0)
        case .buyRoadmap: (0, balance.roadmapFee)
        case .hackStorefront: (0, balance.hackFee)
        }
    }

    /// The notoriety it adds to N1's needle.
    public static func notorietyCost(
        _ operation: EspionageOperation, balance: BalanceConfig.EspionageBalance
    ) -> Double {
        switch operation {
        case .tailFounder: balance.tailNotoriety
        case .placeMole: balance.moleNotoriety
        case .poachWithDirt: balance.poachNotoriety
        case .buyRoadmap: balance.roadmapNotoriety
        case .hackStorefront: balance.hackNotoriety
        }
    }

    /// The chance it lands: the operation's own footing, the founder's
    /// nerve, the size of the studio it is aimed at, and whatever the
    /// dossier is worth. Never certain, never hopeless.
    public static func successChance(
        _ operation: EspionageOperation,
        rival: Rival,
        skill: Double,
        dossier: EspionageDossier?,
        day: Int,
        balance: BalanceConfig.EspionageBalance
    ) -> Double {
        let base: Double = switch operation {
        case .tailFounder: balance.tailSuccess
        case .placeMole: balance.moleSuccess
        case .poachWithDirt: balance.poachSuccess
        case .buyRoadmap: balance.roadmapSuccess
        case .hackStorefront: balance.hackSuccess
        }
        let nerve = skill / max(1, balance.successSkillDivisor)
        let theirSize = rival.strength / 100 * balance.strengthResistance
        let leverage = (dossier?.leverage(on: day, coldDays: balance.dossierColdDays) ?? 0)
            * balance.dossierSuccessBonus
        return min(balance.successCeiling, max(
            balance.successFloor, base + nerve - theirSize + leverage
        ))
    }

    /// The chance somebody works out who did it, on the day it is done.
    ///
    /// N1's two factors do the work — the founder's own notoriety warms
    /// it, a Legal department cools it — over a per-operation base, and a
    /// botched operation is far easier to trace than one that landed. The
    /// entry it leaves on N1's record is rolled again every week by the
    /// crime sweep, so this is the first roll, not the only one.
    public static func traceChance(
        _ operation: EspionageOperation,
        landed: Bool,
        notoriety: Double,
        hasLegal: Bool,
        balance: BalanceConfig.EspionageBalance,
        crime: BalanceConfig.CrimeBalance,
        // MARK: J2 (record) — fame's spotlight, exactly 1 at fame zero.
        spotlight: Double = 1
        // MARK: end J2
    ) -> Double {
        let base: Double = switch operation {
        case .tailFounder: balance.tailTrace
        case .placeMole: balance.moleTrace
        case .poachWithDirt: balance.poachTrace
        case .buyRoadmap: balance.roadmapTrace
        case .hackStorefront: balance.hackTrace
        }
        let heat = 1 + notoriety / 100 * crime.notorietyDiscoveryFactor
        let legal = hasLegal ? crime.legalDepartmentFactor : 1
        let botched = landed ? 1 : balance.botchedTraceFactor
        // MARK: J2 (record) — × spotlight.
        return min(balance.traceCeiling, base * heat * legal * botched * spotlight)
        // MARK: end J2
    }

    /// The grudge an operation earns you, traced or not. A studio that
    /// knows who did it holds the whole thing.
    public static func grudge(
        traced: Bool, balance: BalanceConfig.EspionageBalance
    ) -> Double {
        traced ? 100 : balance.quietGrudge
    }
}
