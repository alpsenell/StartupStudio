import Foundation

/// How hard the founder works. Scales founder output and drives the daily
/// drift of the life meters.
public enum WorkSchedule: String, Codable, Equatable, Sendable, CaseIterable {
    case chill, normal, crunch
}

/// What the founder does with the weekend. Resolves every 7th day.
public enum WeekendActivity: String, Codable, Equatable, Sendable, CaseIterable {
    case rest, gym, dateNight, friends, hobby, familyTime, vacation, doctor, spa, networking
}

/// A same-day life action, distinct from the planned weekend: instant
/// meter effects, wallet cost, per-activity cooldown, and a shared
/// per-day cap. Tuned in `balance.instantLife.activities`.
public enum InstantActivity: String, Codable, Equatable, Sendable, CaseIterable {
    case gymSession, walk, cinema, restaurant
}

/// The founder's relationship ladder.
public enum RelationshipStage: String, Codable, Equatable, Sendable, CaseIterable {
    case single, dating, partner, married

    /// Position on the single → married ladder, for minimum-stage gates.
    var rank: Int { Self.allCases.firstIndex(of: self) ?? 0 }

    /// The stage one rung up: single → dating → partner → married, and
    /// `nil` at the top.
    public var next: RelationshipStage? {
        let ladder = Self.allCases
        let index = ladder.index(after: rank)
        return index < ladder.endIndex ? ladder[index] : nil
    }
}

/// Where the founder lives, from a studio flat up to a penthouse.
public enum HomeTier: String, Codable, Equatable, Sendable, CaseIterable {
    case studioFlat, apartment, house, penthouse

    public var displayName: String {
        switch self {
        case .studioFlat: "Studio Flat"
        case .apartment: "Apartment"
        case .house: "House"
        case .penthouse: "Penthouse"
        }
    }

    /// Position on the studio flat → penthouse ladder, for minimum-home
    /// gates (e.g. children need at least `balance.life.childMinHome`).
    var rank: Int { Self.allCases.firstIndex(of: self) ?? 0 }

    /// The tier one rung down the ladder, `nil` at the bottom — where an
    /// evicted founder ends up.
    public var previous: HomeTier? {
        rank > 0 ? Self.allCases[rank - 1] : nil
    }

    /// The tier one rung up the ladder, `nil` at the top.
    public var next: HomeTier? {
        let ladder = Self.allCases
        let index = ladder.index(after: rank)
        return index < ladder.endIndex ? ladder[index] : nil
    }
}

/// The founder's four wellbeing meters, each 0...100.
public struct LifeMeters: Codable, Equatable, Sendable {
    public var energy: Double
    public var health: Double
    public var mood: Double
    public var relationships: Double

    public init(energy: Double, health: Double, mood: Double, relationships: Double) {
        self.energy = energy
        self.health = health
        self.mood = mood
        self.relationships = relationships
    }

    /// Adds the deltas and clamps every meter back into 0...100.
    mutating func apply(
        energy: Double = 0, health: Double = 0, mood: Double = 0, relationships: Double = 0
    ) {
        self.energy = Self.clamped(self.energy + energy)
        self.health = Self.clamped(self.health + health)
        self.mood = Self.clamped(self.mood + mood)
        self.relationships = Self.clamped(self.relationships + relationships)
    }

    static func clamped(_ value: Double) -> Double {
        min(100, max(0, value))
    }
}

/// One of the founder's children.
public struct Child: Codable, Equatable, Sendable, Identifiable {
    public let id: UUID
    public var name: String
    public var bornDay: Int
    /// Drives the pixel-art look; derived from `GameState.rng` at birth.
    public var appearanceSeed: UInt64

    public init(id: UUID, name: String, bornDay: Int, appearanceSeed: UInt64) {
        self.id = id
        self.name = name
        self.bornDay = bornDay
        self.appearanceSeed = appearanceSeed
    }
}

/// The founder's partner and children.
public struct FamilyState: Codable, Equatable, Sendable {
    public var stage: RelationshipStage
    /// The day the current stage was reached (0 for a new game).
    public var stageSinceDay: Int
    /// Set from the `dating` stage on; cleared by a breakup.
    public var partnerName: String?
    public var partnerAppearanceSeed: UInt64?
    /// Children stay through a breakup.
    public var children: [Child]
    public var lastChildDay: Int?
    /// 0...100: how the partner feels about being with this founder, as
    /// opposed to how the founder's *life* is going. It drifts down on its
    /// own and only the founder's own time brings it back, which is the
    /// point — the relationships meter can be carried by a night out with
    /// friends, but a partner cannot.
    public var affection: Double
    /// Last day each partner activity was done, keyed by raw value.
    public var partnerCooldowns: [String: Int]
    /// The last day the founder did anything with their partner at all.
    public var lastPartnerDay: Int?
    /// Set when the partner came out of the address book, so the contact
    /// and the relationship stay the same person.
    public var partnerContactID: UUID?

    public init(
        stage: RelationshipStage,
        stageSinceDay: Int,
        partnerName: String?,
        partnerAppearanceSeed: UInt64?,
        children: [Child],
        lastChildDay: Int?,
        affection: Double = 0,
        partnerCooldowns: [String: Int] = [:],
        lastPartnerDay: Int? = nil,
        partnerContactID: UUID? = nil
    ) {
        self.stage = stage
        self.stageSinceDay = stageSinceDay
        self.partnerName = partnerName
        self.partnerAppearanceSeed = partnerAppearanceSeed
        self.children = children
        self.lastChildDay = lastChildDay
        self.affection = affection
        self.partnerCooldowns = partnerCooldowns
        self.lastPartnerDay = lastPartnerDay
        self.partnerContactID = partnerContactID
    }
}

// MARK: - Codable

// Hand-written (in an extension, so the memberwise initializer survives)
// so a save written before the partner had an inner life keeps loading,
// and so the cooldown map encodes as a sorted array of entries — the same
// determinism argument as `LifeState.instantCooldowns`.
extension FamilyState {
    private enum CodingKeys: String, CodingKey {
        case stage, stageSinceDay, partnerName, partnerAppearanceSeed, children, lastChildDay
        case affection, partnerCooldowns, lastPartnerDay, partnerContactID
    }

    private struct CooldownEntry: Codable {
        var activity: String
        var day: Int
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let cooldowns = try container.decodeIfPresent(
            [CooldownEntry].self, forKey: .partnerCooldowns
        ) ?? []
        self.init(
            stage: try container.decode(RelationshipStage.self, forKey: .stage),
            stageSinceDay: try container.decode(Int.self, forKey: .stageSinceDay),
            partnerName: try container.decodeIfPresent(String.self, forKey: .partnerName),
            partnerAppearanceSeed: try container.decodeIfPresent(
                UInt64.self, forKey: .partnerAppearanceSeed
            ),
            children: try container.decode([Child].self, forKey: .children),
            lastChildDay: try container.decodeIfPresent(Int.self, forKey: .lastChildDay),
            affection: try container.decodeIfPresent(Double.self, forKey: .affection) ?? 0,
            partnerCooldowns: Dictionary(
                cooldowns.map { ($0.activity, $0.day) }, uniquingKeysWith: { _, last in last }
            ),
            lastPartnerDay: try container.decodeIfPresent(Int.self, forKey: .lastPartnerDay),
            partnerContactID: try container.decodeIfPresent(UUID.self, forKey: .partnerContactID)
        )
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(stage, forKey: .stage)
        try container.encode(stageSinceDay, forKey: .stageSinceDay)
        try container.encodeIfPresent(partnerName, forKey: .partnerName)
        try container.encodeIfPresent(partnerAppearanceSeed, forKey: .partnerAppearanceSeed)
        try container.encode(children, forKey: .children)
        try container.encodeIfPresent(lastChildDay, forKey: .lastChildDay)
        try container.encode(affection, forKey: .affection)
        try container.encode(
            partnerCooldowns.keys.sorted().map {
                CooldownEntry(activity: $0, day: partnerCooldowns[$0] ?? 0)
            },
            forKey: .partnerCooldowns
        )
        try container.encodeIfPresent(lastPartnerDay, forKey: .lastPartnerDay)
        try container.encodeIfPresent(partnerContactID, forKey: .partnerContactID)
    }
}

/// Everything about the founder's personal life: meters, schedule, the
/// weekend plan, personal money, home, family, and absence windows.
/// Advanced by `LifeSystem`, first in the daily system order.
public struct LifeState: Codable, Equatable, Sendable {
    public var meters: LifeMeters
    public var schedule: WorkSchedule
    /// Resolves every weekly day and persists week to week; a vacation
    /// resets it to `.rest` once it fires.
    public var plannedActivity: WeekendActivity
    /// Personal money, separate from company cash. May go negative.
    public var wallet: Int
    /// Weekly, paid by the company into the wallet.
    public var founderSalary: Int
    public var home: HomeTier
    public var family: FamilyState
    /// The founder is absent (produces nothing) while `day < awayUntilDay`.
    public var awayUntilDay: Int?
    /// The day the current absence began, so the team can notice a long
    /// one. `nil` whenever the founder is around.
    public var awaySinceDay: Int?
    /// Why the founder is away, e.g. "Burnout", "Hospital", "Vacation".
    public var awayReason: String?
    /// The founder has a cold (output × `coldOutputFactor`) while
    /// `day < coldUntilDay`.
    public var coldUntilDay: Int?
    /// Consecutive days with relationships below the breakup threshold
    /// while in a relationship.
    public var lowRelationshipStreakDays: Int
    /// Last day each instant activity was done, keyed by raw value
    /// (cooldowns).
    public var instantCooldowns: [String: Int]
    /// Instant activities done today; resets at the top of each daily tick
    /// and caps at `balance.instantLife.maxPerDay`. A second, smaller cap
    /// under the weekly evening budget: it stops a whole week being spent
    /// on one Tuesday.
    public var instantActionsToday: Int
    /// Item ids the founder owns, kept sorted (bought via `.buyItem`;
    /// their daily mood drift joins the meter drift).
    public var possessions: [String]
    /// The founder's five personal attributes, trained with
    /// `.trainFounderSkill` and picked up in smaller doses just by doing
    /// the work.
    public var skills: FounderSkillSet
    /// Last day each training method was used, keyed by raw value.
    public var trainingCooldowns: [String: Int]
    /// Training sessions done today; resets at the top of each daily tick
    /// and caps at `balance.founder.maxTrainingsPerDay`. Like
    /// `instantActionsToday`, a per-day guard under the weekly budget.
    public var trainingsToday: Int
    /// Evenings spent this week. Reset on the weekly boundary, and capped
    /// at `balance.life.eveningsPerWeek` for the founder's *effective*
    /// schedule — see `GameState.eveningsLeftThisWeek`.
    ///
    /// This is the Life tab's scarce resource. Before it existed, every
    /// personal action sat on its own independent cooldown, so nothing
    /// competed with anything and the optimal play was to tap each button
    /// on the day it stopped being grey. One pool means an evening spent
    /// on a course is an evening not spent on a partner whose affection is
    /// sliding, or on the new hire a rival has been taking to lunch — and
    /// it gives crunch a cost that is not another meter.
    public var eveningsSpentThisWeek: Int

    public init(
        meters: LifeMeters,
        schedule: WorkSchedule,
        plannedActivity: WeekendActivity,
        wallet: Int,
        founderSalary: Int,
        home: HomeTier,
        family: FamilyState,
        awayUntilDay: Int?,
        awaySinceDay: Int? = nil,
        awayReason: String?,
        coldUntilDay: Int?,
        lowRelationshipStreakDays: Int,
        instantCooldowns: [String: Int] = [:],
        instantActionsToday: Int = 0,
        possessions: [String] = [],
        eveningsSpentThisWeek: Int = 0,
        skills: FounderSkillSet = FounderSkillSet(
            conversation: 50, technical: 50, marketKnowledge: 50, leadership: 50, finance: 50
        ),
        trainingCooldowns: [String: Int] = [:],
        trainingsToday: Int = 0
    ) {
        self.meters = meters
        self.schedule = schedule
        self.plannedActivity = plannedActivity
        self.wallet = wallet
        self.founderSalary = founderSalary
        self.home = home
        self.family = family
        self.awayUntilDay = awayUntilDay
        self.awaySinceDay = awaySinceDay
        self.awayReason = awayReason
        self.coldUntilDay = coldUntilDay
        self.lowRelationshipStreakDays = lowRelationshipStreakDays
        self.instantCooldowns = instantCooldowns
        self.instantActionsToday = instantActionsToday
        self.possessions = possessions
        self.eveningsSpentThisWeek = eveningsSpentThisWeek
        self.skills = skills
        self.trainingCooldowns = trainingCooldowns
        self.trainingsToday = trainingsToday
    }

    /// Whether the founder is absent on `day` (half-open: back on
    /// `awayUntilDay` itself).
    public func isAway(day: Int) -> Bool {
        guard let awayUntilDay else { return false }
        return day < awayUntilDay
    }

    /// Whether the founder has a cold on `day` (half-open: well again on
    /// `coldUntilDay` itself).
    public func hasCold(day: Int) -> Bool {
        guard let coldUntilDay else { return false }
        return day < coldUntilDay
    }

    /// A fresh life for `GameState.newGame`: rested, single, in a studio
    /// flat, with the balance's starting wallet and default salary.
    static func newGame(balance: BalanceConfig) -> LifeState {
        var life = newGame(
            wallet: balance.life.startingWallet,
            founderSalary: balance.life.defaultFounderSalary
        )
        life.skills = balance.founder.starting
        return life
    }

    /// The starting life with explicit money values. Also the fallback for
    /// saves written before the life system existed (empty wallet, no
    /// salary).
    static func newGame(wallet: Int, founderSalary: Int) -> LifeState {
        LifeState(
            meters: LifeMeters(energy: 80, health: 80, mood: 70, relationships: 50),
            schedule: .normal,
            plannedActivity: .rest,
            wallet: wallet,
            founderSalary: founderSalary,
            home: .studioFlat,
            family: FamilyState(
                stage: .single,
                stageSinceDay: 0,
                partnerName: nil,
                partnerAppearanceSeed: nil,
                children: [],
                lastChildDay: nil
            ),
            awayUntilDay: nil,
            awaySinceDay: nil,
            awayReason: nil,
            coldUntilDay: nil,
            lowRelationshipStreakDays: 0
        )
    }
}

// MARK: - Codable

// Hand-written (in an extension, preserving the memberwise initializer) so
// saves written before instant activities existed keep loading, and so the
// cooldown map encodes as an array of entries sorted by activity —
// byte-identical for identical states whatever the encoder's key ordering
// (the `MarketState.history` precedent).
extension LifeState {
    private enum CodingKeys: String, CodingKey {
        case meters, schedule, plannedActivity, wallet, founderSalary, home, family
        case awayUntilDay, awaySinceDay, awayReason, coldUntilDay, lowRelationshipStreakDays
        case instantCooldowns, instantActionsToday, possessions
        case skills, trainingCooldowns, trainingsToday, eveningsSpentThisWeek
    }

    private struct CooldownEntry: Codable {
        var activity: String
        var day: Int
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let cooldowns = try container.decodeIfPresent([CooldownEntry].self, forKey: .instantCooldowns) ?? []
        let training = try container.decodeIfPresent([CooldownEntry].self, forKey: .trainingCooldowns) ?? []
        self.init(
            meters: try container.decode(LifeMeters.self, forKey: .meters),
            schedule: try container.decode(WorkSchedule.self, forKey: .schedule),
            plannedActivity: try container.decode(WeekendActivity.self, forKey: .plannedActivity),
            wallet: try container.decode(Int.self, forKey: .wallet),
            founderSalary: try container.decode(Int.self, forKey: .founderSalary),
            home: try container.decode(HomeTier.self, forKey: .home),
            family: try container.decode(FamilyState.self, forKey: .family),
            awayUntilDay: try container.decodeIfPresent(Int.self, forKey: .awayUntilDay),
            awaySinceDay: try container.decodeIfPresent(Int.self, forKey: .awaySinceDay),
            awayReason: try container.decodeIfPresent(String.self, forKey: .awayReason),
            coldUntilDay: try container.decodeIfPresent(Int.self, forKey: .coldUntilDay),
            lowRelationshipStreakDays: try container.decode(Int.self, forKey: .lowRelationshipStreakDays),
            instantCooldowns: Dictionary(
                cooldowns.map { ($0.activity, $0.day) }, uniquingKeysWith: { _, last in last }
            ),
            instantActionsToday: try container.decodeIfPresent(Int.self, forKey: .instantActionsToday) ?? 0,
            possessions: try container.decodeIfPresent([String].self, forKey: .possessions) ?? [],
            // A save written before the founder had attributes decodes
            // with the shipped starting sheet, which is what that founder
            // has been playing with all along.
            skills: try container.decodeIfPresent(FounderSkillSet.self, forKey: .skills)
                ?? BalanceConfig.FounderBalance.default.starting,
            trainingCooldowns: Dictionary(
                training.map { ($0.activity, $0.day) }, uniquingKeysWith: { _, last in last }
            ),
            trainingsToday: try container.decodeIfPresent(Int.self, forKey: .trainingsToday) ?? 0
        )
        // A save written before the evening budget existed starts the week
        // with a full one, which is the generous reading and costs nothing.
        eveningsSpentThisWeek = try container.decodeIfPresent(
            Int.self, forKey: .eveningsSpentThisWeek
        ) ?? 0
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(meters, forKey: .meters)
        try container.encode(schedule, forKey: .schedule)
        try container.encode(plannedActivity, forKey: .plannedActivity)
        try container.encode(wallet, forKey: .wallet)
        try container.encode(founderSalary, forKey: .founderSalary)
        try container.encode(home, forKey: .home)
        try container.encode(family, forKey: .family)
        try container.encodeIfPresent(awayUntilDay, forKey: .awayUntilDay)
        try container.encodeIfPresent(awaySinceDay, forKey: .awaySinceDay)
        try container.encodeIfPresent(awayReason, forKey: .awayReason)
        try container.encodeIfPresent(coldUntilDay, forKey: .coldUntilDay)
        try container.encode(lowRelationshipStreakDays, forKey: .lowRelationshipStreakDays)
        try container.encode(
            instantCooldowns.keys.sorted().map {
                CooldownEntry(activity: $0, day: instantCooldowns[$0] ?? 0)
            },
            forKey: .instantCooldowns
        )
        try container.encode(instantActionsToday, forKey: .instantActionsToday)
        try container.encode(possessions.sorted(), forKey: .possessions)
        try container.encode(skills, forKey: .skills)
        try container.encode(
            trainingCooldowns.keys.sorted().map {
                CooldownEntry(activity: $0, day: trainingCooldowns[$0] ?? 0)
            },
            forKey: .trainingCooldowns
        )
        try container.encode(trainingsToday, forKey: .trainingsToday)
        try container.encode(eveningsSpentThisWeek, forKey: .eveningsSpentThisWeek)
    }
}

// MARK: - The evening budget

/// The founder's week, as a resource.
///
/// Every personal action — a course, a date, a night out with somebody on
/// the team, an afternoon teaching them something, a trip to the gym —
/// spends one evening from a pool the work schedule sets. Company social
/// actions (a coffee, a one-on-one, a gift, the team dinner) do not: those
/// happen during the working day on the company's money, and keeping them
/// free is what makes the founder's own time worth something by contrast.
///
/// A balance with no `life.eveningsPerWeek` has no budget, and every gate
/// falls back to the per-day caps it used before this existed.
extension GameState {
    /// Evenings this week, or `nil` when this balance has no budget.
    ///
    /// Read off `effectiveSchedule`, not `life.schedule`, so a founder
    /// signed off after a hospital stay actually gets the chill week's
    /// evenings rather than the crunch they still intend to go back to.
    public func eveningsPerWeek(_ balance: BalanceConfig) -> Int? {
        balance.life.evenings(for: effectiveSchedule)
    }

    /// Evenings left this week, or `nil` when there is no budget.
    public func eveningsLeftThisWeek(_ balance: BalanceConfig) -> Int? {
        eveningsPerWeek(balance).map { max(0, $0 - life.eveningsSpentThisWeek) }
    }

    /// Whether the founder has an evening to give. Always true without a
    /// budget.
    func hasEveningFree(_ balance: BalanceConfig) -> Bool {
        eveningsLeftThisWeek(balance).map { $0 > 0 } ?? true
    }

    /// Books one evening. A no-op without a budget, so the counter stays
    /// at zero and nothing downstream reads a number that means nothing.
    mutating func spendEvening(_ balance: BalanceConfig) {
        guard eveningsPerWeek(balance) != nil else { return }
        life.eveningsSpentThisWeek += 1
    }

    /// The blocker every personal action shares, in the player's words.
    func eveningBlocker(_ balance: BalanceConfig) -> String? {
        hasEveningFree(balance) ? nil : "No evenings left this week"
    }
}

// MARK: - Founder multipliers

extension GameState {
    /// The founder's daily output multiplier, applied to product, contract,
    /// and research output:
    /// `scheduleFactor × (minOutputFactor + (1 − minOutputFactor) × wellbeing) × (cold ? coldOutputFactor : 1) × chronic × talent`
    /// where `wellbeing = (wE·energy + wH·health + wM·mood) / 100` with the
    /// balance's wellbeing weights, and `chronic` is
    /// `economy.chronicOutputFactor` while the founder is living with a
    /// long-term condition, and `talent` is the founder's technical
    /// attribute read through `BalanceConfig.FounderBalance.factor` — and 0
    /// while the founder is away.
    public func founderOutputMultiplier(balance: BalanceConfig) -> Double {
        guard !life.isAway(day: day) else { return 0 }
        let config = balance.life
        let weights = config.wellbeingWeights
        let wellbeing = (weights.energy * life.meters.energy
            + weights.health * life.meters.health
            + weights.mood * life.meters.mood) / 100
        let vitality = config.minOutputFactor + (1 - config.minOutputFactor) * wellbeing
        let cold = life.hasCold(day: day) ? config.coldOutputFactor : 1
        let chronic = economy.chronicCondition ? balance.economy.chronicOutputFactor : 1
        // ...and how good at this the founder actually is. Neutral at the
        // balance's `skillMidpoint`, so a fresh run is unchanged and every
        // point of training is visible on the Life tab's output line.
        return config.outputFactor(for: effectiveSchedule) * vitality * cold * chronic
            * founderTalentFactor(balance)
    }

    /// The schedule the founder is actually keeping, as opposed to the one
    /// set on the Life tab: `.chill` while they are away, and `.chill`
    /// again for the fortnight they are signed off after a hospital stay.
    /// `life.schedule` keeps the founder's *intent*, so the run they were
    /// on resumes by itself when the sick note runs out.
    public var effectiveSchedule: WorkSchedule {
        life.isAway(day: day) || LifeSystem.isConvalescing(self) ? .chill : life.schedule
    }

    /// Multiplier on the bug chance of code the founder works on:
    /// `1 + max(0, lowEnergyBugThreshold − energy) / lowEnergyBugDivisor`.
    public func founderBugChanceMultiplier(balance: BalanceConfig) -> Double {
        let config = balance.life
        let tired = 1 + max(0, config.lowEnergyBugThreshold - life.meters.energy)
            / config.lowEnergyBugDivisor
        // A founder who actually knows the stack writes fewer of them, and
        // one who doesn't writes more. The divisor is zero in a balance
        // without the founder block, which leaves the pre-attribute
        // formula exactly as it was.
        let divisor = balance.founder.technicalBugDivisor
        guard divisor > 0 else { return tired }
        let skilled = max(
            0.5, 1 - (life.skills.technical - balance.founder.skillMidpoint) / divisor
        )
        return tired * skilled
    }
}
