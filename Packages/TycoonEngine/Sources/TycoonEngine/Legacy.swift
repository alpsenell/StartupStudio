import Foundation

// MARK: Iteration 7 — the legacy ledger (R2)

/// What one finished company left behind: enough to write its line in the
/// hall, to offer one thing from it to the next company, and to say which
/// endings the player has reached.
///
/// The ledger is persisted by the app in its own directory, apart from the
/// save slots, so deleting every slot cannot reach it. It names engine
/// types (`EndingKind`, `FoundingOrigin`, `SkillSet`), which is why it
/// lives here and not in `TycoonSave`.
public struct LegacyLedger: Codable, Equatable, Sendable {
    public var runs: [LegacyRun]
    public var endingsReached: Set<EndingKind>
    /// Heirlooms already carried into a company, by `Heirloom.id`. An
    /// heirloom carries once.
    public var spentHeirlooms: Set<String>

    public init(
        runs: [LegacyRun] = [],
        endingsReached: Set<EndingKind> = [],
        spentHeirlooms: Set<String> = []
    ) {
        self.runs = runs
        self.endingsReached = endingsReached
        self.spentHeirlooms = spentHeirlooms
    }

    public static let empty = LegacyLedger()

    public var isEmpty: Bool { runs.isEmpty && endingsReached.isEmpty }

    private enum CodingKeys: String, CodingKey {
        case runs, endingsReached, spentHeirlooms
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            runs: try container.decodeIfPresent([LegacyRun].self, forKey: .runs) ?? [],
            endingsReached: try container.decodeIfPresent(Set<EndingKind>.self, forKey: .endingsReached) ?? [],
            spentHeirlooms: try container.decodeIfPresent(Set<String>.self, forKey: .spentHeirlooms) ?? []
        )
    }

    /// Records a finished run. Pure: the caller (the app, the moment
    /// `gameOver` becomes non-nil) writes the result back to disk.
    ///
    /// R2 fills in the people, the perks and the deed; the scaffold
    /// records the facts every run has.
    public mutating func record(_ state: GameState, balance: BalanceConfig) {
        guard let over = state.gameOver else { return }
        let run = LegacyRun(
            id: UUID(),
            companyName: state.company.name,
            founderName: state.progression.founder.name,
            seed: state.seed,
            origin: state.origin,
            difficulty: state.difficulty,
            ending: over.kind,
            day: state.day,
            founderNetWorth: state.founderNetWorth(balance: balance),
            people: [],
            perks: Array(state.progression.perks).sorted(),
            deed: nil
        )
        runs.append(run)
        endingsReached.insert(over.kind)
    }
}

/// One finished company in the ledger.
public struct LegacyRun: Codable, Equatable, Sendable, Identifiable {
    public var id: UUID
    public var companyName: String
    public var founderName: String
    public var seed: UInt64
    public var origin: FoundingOrigin
    public var difficulty: Difficulty
    public var ending: EndingKind
    public var day: Int
    public var founderNetWorth: Int
    /// The address book's best contacts by rapport, with what they knew.
    public var people: [LegacyPerson]
    /// Perk ids earned (`Progression.perks`).
    public var perks: [String]
    /// The office, if the company owned it outright.
    public var deed: LegacyDeed?

    public init(
        id: UUID, companyName: String, founderName: String, seed: UInt64,
        origin: FoundingOrigin, difficulty: Difficulty, ending: EndingKind, day: Int,
        founderNetWorth: Int, people: [LegacyPerson] = [], perks: [String] = [],
        deed: LegacyDeed? = nil
    ) {
        self.id = id
        self.companyName = companyName
        self.founderName = founderName
        self.seed = seed
        self.origin = origin
        self.difficulty = difficulty
        self.ending = ending
        self.day = day
        self.founderNetWorth = founderNetWorth
        self.people = people
        self.perks = perks
        self.deed = deed
    }
}

/// Somebody worth carrying into the next company: what they knew and the
/// traits the founder had seen.
public struct LegacyPerson: Codable, Equatable, Sendable, Identifiable {
    public var id: UUID
    public var name: String
    public var appearanceSeed: UInt64
    public var skills: SkillSet
    public var revealedTraits: [String]
    public var rapport: Double

    public init(
        id: UUID, name: String, appearanceSeed: UInt64, skills: SkillSet,
        revealedTraits: [String] = [], rapport: Double
    ) {
        self.id = id
        self.name = name
        self.appearanceSeed = appearanceSeed
        self.skills = skills
        self.revealedTraits = revealedTraits
        self.rapport = rapport
    }
}

/// The office a finished company owned, tier and district.
public struct LegacyDeed: Codable, Equatable, Sendable {
    public var tier: OfficeTier
    public var district: DistrictID

    public init(tier: OfficeTier, district: DistrictID) {
        self.tier = tier
        self.district = district
    }
}

/// The one thing a new company brings from an old one. Chosen on the
/// Heirlooms page (R2), applied by `GameState.newGame(…, heirloom:)` after
/// the origin, as a pure delta that draws nothing.
public enum Heirloom: Codable, Equatable, Hashable, Sendable {
    /// A person from the ledger arrives in the address book.
    case person(LegacyPerson)
    /// A perk from day 0.
    case perk(id: String)
    /// The office, owned outright, at the tier and district it was owned.
    case deed(LegacyDeed)

    /// The key `LegacyLedger.spentHeirlooms` records, so a person carries
    /// once and a deed carries once.
    public var id: String {
        switch self {
        case .person(let person): "person.\(person.id.uuidString)"
        case .perk(let id): "perk.\(id)"
        case .deed(let deed): "deed.\(deed.tier.rawValue).\(deed.district.rawValue)"
        }
    }

    /// The word the `heirloomApplied` event carries.
    public var kind: String {
        switch self {
        case .person: "person"
        case .perk: "perk"
        case .deed: "deed"
        }
    }
}

extension LegacyPerson: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
extension LegacyDeed: Hashable {}

extension GameState {
    /// Lands `heirloom` on a day-0 state. R2 writes the three deltas; the
    /// scaffold records the choice and emits nothing, so `newGame` with an
    /// heirloom is `newGame` without one until then.
    mutating func applyHeirloom(_ heirloom: Heirloom, balance: BalanceConfig) {
        // R2: `.person` → a `Contact` with `leftReason: .formerCompany`,
        // rapport 60; `.perk` → `progression.perks.insert`; `.deed` → the
        // office owned at `deed.tier` (capped at studio) in `deed.district`.
        _ = balance
    }

    /// Whether an ending in this run may post to the ranked boards: a
    /// standard-mode run with no heirloom.
    public var isRanked: Bool {
        mode.isRanked && heirloom == nil
    }
}
