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

    public init(
        stage: RelationshipStage,
        stageSinceDay: Int,
        partnerName: String?,
        partnerAppearanceSeed: UInt64?,
        children: [Child],
        lastChildDay: Int?
    ) {
        self.stage = stage
        self.stageSinceDay = stageSinceDay
        self.partnerName = partnerName
        self.partnerAppearanceSeed = partnerAppearanceSeed
        self.children = children
        self.lastChildDay = lastChildDay
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
    /// and caps at `balance.instantLife.maxPerDay`.
    public var instantActionsToday: Int
    /// Item ids the founder owns, kept sorted (bought via `.buyItem`;
    /// their daily mood drift joins the meter drift).
    public var possessions: [String]

    public init(
        meters: LifeMeters,
        schedule: WorkSchedule,
        plannedActivity: WeekendActivity,
        wallet: Int,
        founderSalary: Int,
        home: HomeTier,
        family: FamilyState,
        awayUntilDay: Int?,
        awayReason: String?,
        coldUntilDay: Int?,
        lowRelationshipStreakDays: Int,
        instantCooldowns: [String: Int] = [:],
        instantActionsToday: Int = 0,
        possessions: [String] = []
    ) {
        self.meters = meters
        self.schedule = schedule
        self.plannedActivity = plannedActivity
        self.wallet = wallet
        self.founderSalary = founderSalary
        self.home = home
        self.family = family
        self.awayUntilDay = awayUntilDay
        self.awayReason = awayReason
        self.coldUntilDay = coldUntilDay
        self.lowRelationshipStreakDays = lowRelationshipStreakDays
        self.instantCooldowns = instantCooldowns
        self.instantActionsToday = instantActionsToday
        self.possessions = possessions
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
        newGame(wallet: balance.life.startingWallet, founderSalary: balance.life.defaultFounderSalary)
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
        case awayUntilDay, awayReason, coldUntilDay, lowRelationshipStreakDays
        case instantCooldowns, instantActionsToday, possessions
    }

    private struct CooldownEntry: Codable {
        var activity: String
        var day: Int
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let cooldowns = try container.decodeIfPresent([CooldownEntry].self, forKey: .instantCooldowns) ?? []
        self.init(
            meters: try container.decode(LifeMeters.self, forKey: .meters),
            schedule: try container.decode(WorkSchedule.self, forKey: .schedule),
            plannedActivity: try container.decode(WeekendActivity.self, forKey: .plannedActivity),
            wallet: try container.decode(Int.self, forKey: .wallet),
            founderSalary: try container.decode(Int.self, forKey: .founderSalary),
            home: try container.decode(HomeTier.self, forKey: .home),
            family: try container.decode(FamilyState.self, forKey: .family),
            awayUntilDay: try container.decodeIfPresent(Int.self, forKey: .awayUntilDay),
            awayReason: try container.decodeIfPresent(String.self, forKey: .awayReason),
            coldUntilDay: try container.decodeIfPresent(Int.self, forKey: .coldUntilDay),
            lowRelationshipStreakDays: try container.decode(Int.self, forKey: .lowRelationshipStreakDays),
            instantCooldowns: Dictionary(
                cooldowns.map { ($0.activity, $0.day) }, uniquingKeysWith: { _, last in last }
            ),
            instantActionsToday: try container.decodeIfPresent(Int.self, forKey: .instantActionsToday) ?? 0,
            possessions: try container.decodeIfPresent([String].self, forKey: .possessions) ?? []
        )
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
    }
}

// MARK: - Founder multipliers

extension GameState {
    /// The founder's daily output multiplier, applied to product, contract,
    /// and research output:
    /// `scheduleFactor × (minOutputFactor + (1 − minOutputFactor) × wellbeing) × (cold ? coldOutputFactor : 1)`
    /// where `wellbeing = (wE·energy + wH·health + wM·mood) / 100` with the
    /// balance's wellbeing weights — and 0 while the founder is away.
    public func founderOutputMultiplier(balance: BalanceConfig) -> Double {
        guard !life.isAway(day: day) else { return 0 }
        let config = balance.life
        let weights = config.wellbeingWeights
        let wellbeing = (weights.energy * life.meters.energy
            + weights.health * life.meters.health
            + weights.mood * life.meters.mood) / 100
        let vitality = config.minOutputFactor + (1 - config.minOutputFactor) * wellbeing
        let cold = life.hasCold(day: day) ? config.coldOutputFactor : 1
        return config.outputFactor(for: life.schedule) * vitality * cold
    }

    /// Multiplier on the bug chance of code the founder works on:
    /// `1 + max(0, lowEnergyBugThreshold − energy) / lowEnergyBugDivisor`.
    public func founderBugChanceMultiplier(balance: BalanceConfig) -> Double {
        let config = balance.life
        return 1 + max(0, config.lowEnergyBugThreshold - life.meters.energy) / config.lowEnergyBugDivisor
    }
}
