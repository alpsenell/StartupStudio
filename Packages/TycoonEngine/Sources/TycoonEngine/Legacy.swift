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
    /// Iteration 8: the highest stake a company reached a successful
    /// ending at. Stake n + 1 opens when this is n.
    public var highestStakeWon: Int
    /// Iteration 8: every product any company shipped to a review of 85
    /// or better, appended by the app when the company ends.
    public var hall: [HallEntry]

    public init(
        runs: [LegacyRun] = [],
        endingsReached: Set<EndingKind> = [],
        spentHeirlooms: Set<String> = [],
        highestStakeWon: Int = 0,
        hall: [HallEntry] = []
    ) {
        self.runs = runs
        self.endingsReached = endingsReached
        self.spentHeirlooms = spentHeirlooms
        self.highestStakeWon = highestStakeWon
        self.hall = hall
    }

    /// The highest stake the ladder offers right now.
    public var unlockedStake: Int { min(StakeLadder.count, highestStakeWon + 1) }

    public static let empty = LegacyLedger()

    public var isEmpty: Bool { runs.isEmpty && endingsReached.isEmpty }

    private enum CodingKeys: String, CodingKey {
        case runs, endingsReached, spentHeirlooms, highestStakeWon, hall
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            runs: try container.decodeIfPresent([LegacyRun].self, forKey: .runs) ?? [],
            endingsReached: try container.decodeIfPresent(Set<EndingKind>.self, forKey: .endingsReached) ?? [],
            spentHeirlooms: try container.decodeIfPresent(Set<String>.self, forKey: .spentHeirlooms) ?? [],
            highestStakeWon: try container.decodeIfPresent(Int.self, forKey: .highestStakeWon) ?? 0,
            hall: try container.decodeIfPresent([HallEntry].self, forKey: .hall) ?? []
        )
    }

    /// Adds hall entries the ledger does not have yet (by product id).
    public mutating func induct(_ entries: [HallEntry]) {
        let known = Set(hall.map(\.id))
        hall.append(contentsOf: entries.filter { !known.contains($0.id) })
    }

    /// How many of the address book's contacts a finished company leaves
    /// in the ledger.
    public static let peopleCarried = 8

    /// Records a finished run. Pure: the caller (the app, the moment
    /// `gameOver` becomes non-nil) writes the result back to disk.
    ///
    /// The people are the address book's top `peopleCarried` contacts by
    /// rapport — everyone the founder met, hired or lost to a rival, with
    /// the skills they had at the end and the traits the founder had
    /// learned (a contact who was never listened to shows none). Someone
    /// who burned the founder (`.lost`) or married them (`.romance`) is
    /// not a hire for the next company and stays out. The deed is the
    /// office, when the company owned it outright.
    public mutating func record(_ state: GameState, balance: BalanceConfig) {
        guard let over = state.gameOver else { return }
        var recorded = LegacyRun(
            id: UUID(),
            companyName: state.company.name,
            founderName: state.progression.founder.name,
            seed: state.seed,
            origin: state.origin,
            difficulty: state.difficulty,
            ending: over.kind,
            day: state.day,
            founderNetWorth: state.founderNetWorth(balance: balance),
            people: Self.people(in: state),
            perks: Array(state.progression.perks).sorted(),
            deed: Self.deed(in: state)
        )
        // Iteration 8: what a successor is built from.
        let founder = state.employees.first { $0.isFounder }
        recorded.founderAppearanceSeed = founder?.appearanceSeed ?? state.progression.founder.appearanceSeed
        recorded.founderArchetype = state.progression.founder.archetype
        recorded.children = state.life.family.children.map {
            LegacyChild(id: $0.id, name: $0.name, appearanceSeed: $0.appearanceSeed, bornDay: $0.bornDay)
        }
        recorded.longestServing = state.employees
            .filter { !$0.isFounder }
            .min { lhs, rhs in
                if lhs.hiredDay != rhs.hiredDay { return lhs.hiredDay < rhs.hiredDay }
                return lhs.id.uuidString < rhs.id.uuidString
            }
            .map { employee in
                LegacyPerson(
                    id: employee.id, name: employee.name, appearanceSeed: employee.appearanceSeed,
                    skills: employee.skills, revealedTraits: employee.traits, rapport: 70, role: employee.role
                )
            }
        recorded.lineage = state.lineage
        recorded.stake = state.rules.stake > 0 ? state.rules.stake : nil
        // MARK: Iteration 9 — L2 (life score)
        recorded.lifeScore = LifeScore.score(state, balance: balance)
        // MARK: end of Iteration 9
        let run = recorded
        runs.append(run)
        endingsReached.insert(over.kind)
        // Iteration 8: a successful ending at a stake opens the next rung.
        if over.kind.isSuccess, state.rules.stake > highestStakeWon {
            highestStakeWon = state.rules.stake
        }
    }

    /// The address book's best `peopleCarried` contacts by rapport, ties
    /// broken by id so the same state always records the same eight.
    static func people(in state: GameState) -> [LegacyPerson] {
        state.networking.contacts
            .filter { $0.outcome != .lost && $0.outcome != .romance }
            .sorted { lhs, rhs in
                if lhs.rapport != rhs.rapport { return lhs.rapport > rhs.rapport }
                return lhs.id.uuidString < rhs.id.uuidString
            }
            .prefix(peopleCarried)
            .map { contact in
                LegacyPerson(
                    id: contact.id,
                    name: contact.name,
                    appearanceSeed: contact.appearanceSeed,
                    skills: contact.skills,
                    revealedTraits: contact.isRevealed
                        ? TraitEffects.derivedTraitIDs(appearanceSeed: contact.appearanceSeed)
                        : [],
                    rapport: contact.rapport,
                    role: contact.leftRole ?? contact.archetype.employeeRole
                )
            }
    }

    static func deed(in state: GameState) -> LegacyDeed? {
        guard state.city.ownership.isOwned else { return nil }
        return LegacyDeed(tier: state.company.officeTier, district: state.city.district)
    }

    // MARK: Offers

    /// What the Heirlooms page can put on the table: every person, perk
    /// and deed the finished companies left, once each, minus the ones
    /// already carried. People are offered from the run that saw them
    /// last; perks in `ProgressionPerk` order; each (tier, district) deed
    /// once. Empty when the page has nothing to show.
    public var offers: [HeirloomOffer] {
        var seen: Set<String> = []
        var offers: [HeirloomOffer] = []

        // People, newest run first so the most recent version of a face
        // that appears in two ledgers wins.
        for run in runs.reversed() {
            for person in run.people {
                let heirloom = Heirloom.person(person)
                guard !seen.contains("person.\(person.id.uuidString)") else { continue }
                seen.insert("person.\(person.id.uuidString)")
                offers.append(HeirloomOffer(heirloom: heirloom, companyName: run.companyName, ending: run.ending))
            }
        }
        // Perks, in the declaration order the chapter card uses.
        for perk in ProgressionPerk.allCases {
            guard let run = runs.last(where: { $0.perks.contains(perk.rawValue) }) else { continue }
            offers.append(HeirloomOffer(
                heirloom: .perk(id: perk.rawValue), companyName: run.companyName, ending: run.ending
            ))
        }
        // Deeds, newest first, once per building.
        for run in runs.reversed() {
            guard let deed = run.deed else { continue }
            let heirloom = Heirloom.deed(deed)
            guard !seen.contains(heirloom.id) else { continue }
            seen.insert(heirloom.id)
            offers.append(HeirloomOffer(heirloom: heirloom, companyName: run.companyName, ending: run.ending))
        }
        return offers.filter { !spentHeirlooms.contains($0.heirloom.id) }
    }

    /// Marks an heirloom carried, so it is never offered again.
    public mutating func spend(_ heirloom: Heirloom) {
        spentHeirlooms.insert(heirloom.id)
    }

    // MARK: Merging two devices' ledgers

    /// The union of two ledgers — this device's and the cloud's. Runs are
    /// matched by id (this ledger's order first, the other's unseen runs
    /// after, oldest first); endings and spent heirlooms are unions, so
    /// an heirloom carried on either device is spent on both.
    public func merged(with other: LegacyLedger) -> LegacyLedger {
        var merged = self
        let known = Set(runs.map(\.id))
        merged.runs.append(contentsOf: other.runs.filter { !known.contains($0.id) })
        merged.endingsReached.formUnion(other.endingsReached)
        merged.spentHeirlooms.formUnion(other.spentHeirlooms)
        merged.highestStakeWon = max(highestStakeWon, other.highestStakeWon)
        merged.induct(other.hall)
        return merged
    }
}

/// One heirloom the ledger can offer, and the company it came from.
public struct HeirloomOffer: Equatable, Hashable, Sendable, Identifiable {
    public var heirloom: Heirloom
    public var companyName: String
    public var ending: EndingKind

    public var id: String { heirloom.id }

    public init(heirloom: Heirloom, companyName: String, ending: EndingKind) {
        self.heirloom = heirloom
        self.companyName = companyName
        self.ending = ending
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
    // Iteration 8: the founder's face and archetype, the children, the
    // longest-serving employee, and where the founder came from — what
    // the next company's successors are built from. All optional so a
    // ledger from before the dynasty reads.
    public var founderAppearanceSeed: UInt64?
    public var founderArchetype: FounderArchetype?
    public var children: [LegacyChild]?
    public var longestServing: LegacyPerson?
    public var lineage: Lineage?
    public var stake: Int?

    // MARK: Iteration 9 — L2 (life score)

    /// The founder's life, 0...100, at the moment the company ended —
    /// the second number the ledger and the Dynasty room show next to
    /// net worth. Optional, so a ledger written before life had a score
    /// decodes and simply shows nothing.
    public var lifeScore: Int?

    // MARK: end of Iteration 9

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
    /// What they did for a living — the role they left with, or the one
    /// their archetype implies. Decodes as `nil` from a ledger written
    /// before it was recorded; the skills then say.
    public var role: EmployeeRole?

    public init(
        id: UUID, name: String, appearanceSeed: UInt64, skills: SkillSet,
        revealedTraits: [String] = [], rapport: Double, role: EmployeeRole? = nil
    ) {
        self.id = id
        self.name = name
        self.appearanceSeed = appearanceSeed
        self.skills = skills
        self.revealedTraits = revealedTraits
        self.rapport = rapport
        self.role = role
    }

    /// The role the next company sees them as.
    public var resolvedRole: EmployeeRole {
        role ?? .inferred(isFounder: false, skills: skills)
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
    /// The rapport a carried person arrives with: warm, not bought.
    static let heirloomRapport = 60.0
    /// Their interest in the new company: neutral, the pitch is still yours.
    static let heirloomInterest = 50.0
    /// What a carried person asks over fair pay — the alumni's number.
    static let heirloomAskOverFairPay = 1.1
    /// The deed is capped here: a campus on day 0 would skip the game.
    static let heirloomDeedCap = OfficeTier.studio

    /// Lands `heirloom` on a day-0 state, after the origin and after every
    /// draw `newGame` makes. Three pure deltas, and nothing else moves:
    ///
    /// - `.person` → one `Contact` in the address book, with their skills,
    ///   their face, `leftReason: .formerCompany`, rapport 60, revealed,
    ///   asking fair pay and a tenth — you still recruit them.
    /// - `.perk` → the perk in `progression.perks` from day 0.
    /// - `.deed` → the office at the tier they owned, capped at studio, in
    ///   its district, owned outright at what buying it would cost — so
    ///   there is no rent, and selling it later returns a real number.
    ///
    /// No RNG stream is read; a run with an heirloom is a different
    /// starting state under the same rules. The choice is logged so the
    /// journal's first line says what came with you.
    mutating func applyHeirloom(_ heirloom: Heirloom, balance: BalanceConfig) {
        switch heirloom {
        case .person(let person):
            let role = person.resolvedRole
            // Fair pay is a function of skills and seniority; the stand-in
            // employee is built only to ask the balance what that is.
            let standIn = Employee(
                id: person.id, name: person.name, skills: person.skills, weeklySalary: 0,
                assignment: .idle, isFounder: false, hiredDay: 0,
                appearanceSeed: person.appearanceSeed,
                level: .forSkillTotal(person.skills.total), role: role
            )
            let ask = Int((balance.fairWeeklyPay(for: standIn) * Self.heirloomAskOverFairPay).rounded())
            networking.contacts.removeAll { $0.id == person.id }
            networking.contacts.append(Contact(
                id: person.id,
                name: person.name,
                appearanceSeed: person.appearanceSeed,
                archetype: role.contactArchetype,
                skills: person.skills,
                askingSalary: max(1, ask),
                rapport: Self.heirloomRapport,
                interest: Self.heirloomInterest,
                metDay: day,
                lastMetDay: day,
                isRevealed: true,
                leftDay: day,
                leftReason: .formerCompany,
                leftRole: role
            ))

        case .perk(let id):
            progression.perks.insert(id)

        case .deed(let deed):
            let tier = deed.tier.rank <= Self.heirloomDeedCap.rank ? deed.tier : Self.heirloomDeedCap
            company.officeTier = tier
            city.district = deed.district
            let price = officePurchasePrice(in: deed.district, balance: balance)
            city.ownership = .owned(purchasePrice: price)
            city.propertyValue = price
        }
        logEvents([.heirloomApplied(kind: heirloom.kind, day: day)])
    }

    /// Whether an ending in this run may post to the ranked boards: a
    /// standard-mode run with no heirloom.
    public var isRanked: Bool {
        mode.isRanked && heirloom == nil
    }
}

/// One product in the Hall of Fame (iteration 8).
public struct HallEntry: Codable, Equatable, Hashable, Sendable, Identifiable {
    public var id: UUID
    public var productName: String
    public var companyName: String
    public var founderName: String
    public var topicID: String
    public var typeID: String
    public var score: Int
    public var year: Int
    /// The run's seed, so a hall entry can be replayed.
    public var seed: UInt64

    public init(
        id: UUID, productName: String, companyName: String, founderName: String,
        topicID: String, typeID: String, score: Int, year: Int, seed: UInt64
    ) {
        self.id = id
        self.productName = productName
        self.companyName = companyName
        self.founderName = founderName
        self.topicID = topicID
        self.typeID = typeID
        self.score = score
        self.year = year
        self.seed = seed
    }
}

// MARK: Iteration 8 — the dynasty

/// Who the next founder is to the last one.
public enum SuccessorKind: String, Codable, Equatable, Hashable, Sendable {
    /// The last founder's child, grown up.
    case child
    /// The last company's longest-serving employee.
    case employee
    /// The same founder, older.
    case founder
}

/// Where a company's founder came from, when they came from the ledger.
public struct Lineage: Codable, Equatable, Hashable, Sendable {
    public var predecessorRunID: UUID
    public var predecessorFounderName: String
    public var predecessorCompanyName: String
    public var kind: SuccessorKind

    public init(predecessorRunID: UUID, predecessorFounderName: String, predecessorCompanyName: String, kind: SuccessorKind) {
        self.predecessorRunID = predecessorRunID
        self.predecessorFounderName = predecessorFounderName
        self.predecessorCompanyName = predecessorCompanyName
        self.kind = kind
    }
}

/// A child in the ledger, old enough to found something by the next game.
public struct LegacyChild: Codable, Equatable, Hashable, Sendable, Identifiable {
    public var id: UUID
    public var name: String
    public var appearanceSeed: UInt64
    public var bornDay: Int

    public init(id: UUID, name: String, appearanceSeed: UInt64, bornDay: Int) {
        self.id = id
        self.name = name
        self.appearanceSeed = appearanceSeed
        self.bornDay = bornDay
    }
}
