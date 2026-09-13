import Foundation

/// How the founder's daily output is split across the three point pools.
/// Values are free-form on input; the reducer normalizes to sum 1.0 when the
/// focus is applied (all-zero input becomes equal thirds).
public struct PhaseFocus: Codable, Equatable, Sendable {
    public var design: Double
    public var code: Double
    public var polish: Double

    public init(design: Double, code: Double, polish: Double) {
        self.design = design
        self.code = code
        self.polish = polish
    }

    /// Equal thirds.
    public static let balanced = PhaseFocus(design: 1.0 / 3.0, code: 1.0 / 3.0, polish: 1.0 / 3.0)

    /// A copy scaled so the components sum to 1.0. A non-positive sum
    /// (e.g. all-zero input) becomes `balanced`.
    var normalized: PhaseFocus {
        let sum = design + code + polish
        guard sum > 0 else { return .balanced }
        return PhaseFocus(design: design / sum, code: code / sum, polish: polish / sum)
    }
}

/// Progress of a product still in development.
public struct DevProgress: Codable, Equatable, Sendable {
    public var designPts: Double
    public var codePts: Double
    public var polishPts: Double
    public var openBugs: Int
    public var focus: PhaseFocus
    /// Marketing hype: fed by campaigns, decayed daily by `MarketingSystem`,
    /// and captured into `ReleaseInfo.hypeAtLaunch` at ship.
    public var hype: Double
    /// Running sum of the crew's pool-weighted skill, one sample per day
    /// anyone worked on this product. Divided by `crewSkillDays` at ship it
    /// becomes the skill index behind the quality ceiling — a product can
    /// only be as good as the people who built it (the `ContractJob`
    /// `skillDaySum` / `skillDays` precedent).
    public var crewSkillDaySum: Double
    public var crewSkillDays: Int
    /// The technical debt *this build has created so far* — crunch days,
    /// mostly — waiting to be handed to the codebase it leaves behind at
    /// ship.
    ///
    /// It is deliberately inert until then. The debt that shapes this
    /// product's ceiling and bug rate is its codebase's live debt
    /// (`GameState.inheritedDebt(for:)`), which is exactly 0 for a
    /// greenfield build; the mess made today lands on the *next* product.
    /// That is both the truthful reading of technical debt and the
    /// property that keeps a greenfield build bit-identical to the shipped
    /// balance no matter what `crunchDebtPerDay` is set to — see
    /// `CodebaseSystem`.
    public var debtAccrued: Double

    public init(
        designPts: Double,
        codePts: Double,
        polishPts: Double,
        openBugs: Int,
        focus: PhaseFocus,
        hype: Double,
        crewSkillDaySum: Double = 0,
        crewSkillDays: Int = 0,
        debtAccrued: Double = 0
    ) {
        self.designPts = designPts
        self.codePts = codePts
        self.polishPts = polishPts
        self.openBugs = openBugs
        self.focus = focus
        self.hype = hype
        self.crewSkillDaySum = crewSkillDaySum
        self.crewSkillDays = crewSkillDays
        self.debtAccrued = debtAccrued
    }

    /// The crew's average pool-weighted skill over the build, 0...100.
    /// A product nobody ever worked reads 0.
    public var crewSkillIndex: Double {
        guard crewSkillDays > 0 else { return 0 }
        return crewSkillDaySum / Double(crewSkillDays)
    }
}

// Hand-written decode so a product that was mid-build when the skill
// ceiling landed keeps loading: no recorded crew skill reads as a build
// nobody has worked yet, and the first day of work starts the average.
extension DevProgress {
    private enum CodingKeys: String, CodingKey {
        case designPts, codePts, polishPts, openBugs, focus, hype
        case crewSkillDaySum, crewSkillDays
        case debtAccrued
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            designPts: try container.decode(Double.self, forKey: .designPts),
            codePts: try container.decode(Double.self, forKey: .codePts),
            polishPts: try container.decode(Double.self, forKey: .polishPts),
            openBugs: try container.decode(Int.self, forKey: .openBugs),
            focus: try container.decode(PhaseFocus.self, forKey: .focus),
            hype: try container.decode(Double.self, forKey: .hype),
            crewSkillDaySum: try container.decodeIfPresent(Double.self, forKey: .crewSkillDaySum) ?? 0,
            crewSkillDays: try container.decodeIfPresent(Int.self, forKey: .crewSkillDays) ?? 0,
            debtAccrued: try container.decodeIfPresent(Double.self, forKey: .debtAccrued) ?? 0
        )
    }
}

/// A single press review of a released product.
public struct Review: Codable, Equatable, Sendable {
    public var outlet: String
    /// 0-100.
    public var score: Int
    public var blurb: String

    public init(outlet: String, score: Int, blurb: String) {
        self.outlet = outlet
        self.score = score
        self.blurb = blurb
    }
}

/// One week of sales for a released product.
public struct WeeklySale: Codable, Equatable, Sendable {
    /// 0 = launch week.
    public var weekIndex: Int
    public var units: Int
    public var revenue: Int

    public init(weekIndex: Int, units: Int, revenue: Int) {
        self.weekIndex = weekIndex
        self.units = units
        self.revenue = revenue
    }
}

/// How a released product is priced. Budget charges ×0.6 for ×1.5 the
/// demand, premium ×1.6 for ×0.6 — and a premium price the reviews do not
/// back up drives subscribers away twice as fast. Every product ships
/// `.standard`.
public enum PriceTier: String, Codable, Equatable, Sendable, CaseIterable {
    case budget, standard, premium

    public var displayName: String {
        switch self {
        case .budget: "Budget"
        case .standard: "Standard"
        case .premium: "Premium"
        }
    }
}

/// Everything known about a product after it shipped.
public struct ReleaseInfo: Codable, Equatable, Sendable {
    public var launchDay: Int
    /// 0-100.
    public var quality: Double
    public var reviews: [Review]
    public var weeklySales: [WeeklySale]
    public var offMarket: Bool
    /// The development hype captured at ship; feeds the review hype bonus
    /// and the weekly sales peak multiplier.
    public var hypeAtLaunch: Double
    /// Hype from campaigns run *after* launch. Decays daily like a
    /// development product's does, and feeds sales rather than reviews —
    /// the press has already filed, but people can still be told the thing
    /// exists. `hypeAtLaunch` is frozen at ship and cannot serve this.
    public var liveHype: Double
    /// How many weeks sales take to ramp up to the full peak, computed at
    /// ship from the team's marketing skill and launch hype. 1 = the old
    /// instant-peak behavior (also the fallback for pre-adoption saves).
    public var adoptionWeeks: Double
    /// Launch saturation × genre fatigue captured at ship (the studio's
    /// own recent releases in the same topic / of the same type shrink the
    /// peak); multiplies the weekly sales peak for the product's life.
    /// 1 = untouched (also the fallback for pre-saturation saves).
    public var launchMarketScale: Double
    /// Bugs players hit after launch: seeded at ship from whatever was
    /// still open and discovered week by week as units sell. Each one
    /// shaves a slice off sales until support clears it.
    public var liveBugs: Int
    /// Where the product sits on the price ladder: budget trades margin
    /// for reach, premium the reverse.
    public var priceTier: PriceTier
    /// Paying subscribers, for subscription products; always 0 for
    /// one-off sales.
    public var subscribers: Int
    /// Whether revenue comes from a recurring subscription rather than
    /// one-time sales. Read from `ProductTypeDef.revenueModel` at ship.
    public var isSubscription: Bool
    /// The day the most recent patch landed, `nil` if none ever has. Buys
    /// one bumper sales week.
    public var lastUpdateDay: Int?
    /// How many patches have shipped for this product.
    public var updateCount: Int
    /// The forecast's terms the day this shipped, for launch day to say
    /// why. Absent on releases from before it was recorded.
    public var launchForecast: LaunchForecast?
    // MARK: K2 (product lifecycle)
    /// The day the player retired this product (`sunsetProduct`, or the
    /// successor's `shipReplacing`). `nil` for every product the market
    /// delisted on its own and every product from before it existed. Only
    /// the player's tap writes it; not written while `nil`.
    public var sunsetDay: Int?
    /// The day the player last moved this product's price through the
    /// priced confirmation (`repriceProduct`): the 28-day cooldown reads it.
    public var lastPriceChangeDay: Int?
    /// A rise on a one-time product sells ×`riseUnitsFactor` until this
    /// day: people wait for the sale.
    public var priceRiseUntilDay: Int?
    /// The day the last cut was a sale: one bumper week, once a quarter.
    public var lastSaleDay: Int?
    // MARK: end K2

    public init(
        launchDay: Int,
        quality: Double,
        reviews: [Review],
        weeklySales: [WeeklySale],
        offMarket: Bool,
        hypeAtLaunch: Double = 0,
        liveHype: Double = 0,
        adoptionWeeks: Double = 1,
        launchMarketScale: Double = 1,
        liveBugs: Int = 0,
        priceTier: PriceTier = .standard,
        subscribers: Int = 0,
        isSubscription: Bool = false,
        lastUpdateDay: Int? = nil,
        updateCount: Int = 0,
        launchForecast: LaunchForecast? = nil,
        // MARK: K2 (product lifecycle)
        sunsetDay: Int? = nil,
        lastPriceChangeDay: Int? = nil,
        priceRiseUntilDay: Int? = nil,
        lastSaleDay: Int? = nil
        // MARK: end K2
    ) {
        self.launchForecast = launchForecast
        // MARK: K2 (product lifecycle)
        self.sunsetDay = sunsetDay
        self.lastPriceChangeDay = lastPriceChangeDay
        self.priceRiseUntilDay = priceRiseUntilDay
        self.lastSaleDay = lastSaleDay
        // MARK: end K2
        self.launchDay = launchDay
        self.quality = quality
        self.reviews = reviews
        self.weeklySales = weeklySales
        self.offMarket = offMarket
        self.hypeAtLaunch = hypeAtLaunch
        self.liveHype = liveHype
        self.adoptionWeeks = adoptionWeeks
        self.launchMarketScale = launchMarketScale
        self.liveBugs = liveBugs
        self.priceTier = priceTier
        self.subscribers = subscribers
        self.isSubscription = isSubscription
        self.lastUpdateDay = lastUpdateDay
        self.updateCount = updateCount
    }

    /// Rounded mean review score, 0 if there are no reviews.
    public var averageReviewScore: Int {
        guard !reviews.isEmpty else { return 0 }
        let mean = Double(reviews.reduce(0) { $0 + $1.score }) / Double(reviews.count)
        return Int(mean.rounded())
    }

    /// Lifetime revenue across all recorded sales weeks.
    public var totalRevenue: Int {
        weeklySales.reduce(0) { $0 + $1.revenue }
    }
}

// Hand-written decode so saves written before the adoption ramp, launch
// saturation, or live ops existed keep loading (a missing `adoptionWeeks`
// reads as the old instant peak; a missing `launchMarketScale` as an
// untouched peak; missing live-ops keys as a bug-free, standard-priced,
// one-time-sale release).
extension ReleaseInfo {
    private enum CodingKeys: String, CodingKey {
        case launchDay, quality, reviews, weeklySales, offMarket, hypeAtLaunch, adoptionWeeks
        case liveHype
        case launchMarketScale, liveBugs, priceTier, subscribers, isSubscription
        case lastUpdateDay, updateCount
        case launchForecast
        // MARK: K2 (product lifecycle) — optional, so the synthesized
        // encode writes them only when set: a release nobody retired or
        // re-priced encodes to the bytes it always did.
        case sunsetDay, lastPriceChangeDay, priceRiseUntilDay, lastSaleDay
        // MARK: end K2
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            launchDay: try container.decode(Int.self, forKey: .launchDay),
            quality: try container.decode(Double.self, forKey: .quality),
            reviews: try container.decode([Review].self, forKey: .reviews),
            weeklySales: try container.decode([WeeklySale].self, forKey: .weeklySales),
            offMarket: try container.decode(Bool.self, forKey: .offMarket),
            hypeAtLaunch: try container.decodeIfPresent(Double.self, forKey: .hypeAtLaunch) ?? 0,
            liveHype: try container.decodeIfPresent(Double.self, forKey: .liveHype) ?? 0,
            adoptionWeeks: try container.decodeIfPresent(Double.self, forKey: .adoptionWeeks) ?? 1,
            launchMarketScale: try container.decodeIfPresent(Double.self, forKey: .launchMarketScale) ?? 1,
            liveBugs: try container.decodeIfPresent(Int.self, forKey: .liveBugs) ?? 0,
            priceTier: try container.decodeIfPresent(PriceTier.self, forKey: .priceTier) ?? .standard,
            subscribers: try container.decodeIfPresent(Int.self, forKey: .subscribers) ?? 0,
            isSubscription: try container.decodeIfPresent(Bool.self, forKey: .isSubscription) ?? false,
            lastUpdateDay: try container.decodeIfPresent(Int.self, forKey: .lastUpdateDay),
            updateCount: try container.decodeIfPresent(Int.self, forKey: .updateCount) ?? 0,
            launchForecast: try container.decodeIfPresent(LaunchForecast.self, forKey: .launchForecast),
            // MARK: K2 (product lifecycle)
            sunsetDay: try container.decodeIfPresent(Int.self, forKey: .sunsetDay),
            lastPriceChangeDay: try container.decodeIfPresent(Int.self, forKey: .lastPriceChangeDay),
            priceRiseUntilDay: try container.decodeIfPresent(Int.self, forKey: .priceRiseUntilDay),
            lastSaleDay: try container.decodeIfPresent(Int.self, forKey: .lastSaleDay)
            // MARK: end K2
        )
    }
}

/// Lifecycle of a product: in development, then released.
public enum ProductStage: Codable, Equatable, Sendable {
    case development(DevProgress)
    case released(ReleaseInfo)
}

/// A software product the studio is building or has shipped.
public struct Product: Codable, Equatable, Sendable, Identifiable {
    public let id: UUID
    public var name: String
    /// `ProductTypeDef.id` in the content catalog.
    public var typeID: String
    /// `TopicDef.id` in the content catalog.
    public var topicID: String
    public var stage: ProductStage
    /// The `Codebase.id` this product was started on, `nil` for a
    /// greenfield build. Also `nil` for every product started before
    /// codebases existed, which is why an old save reads as greenfield
    /// and behaves exactly as it did.
    public var codebaseID: String?
    /// Iteration 10 (M1): the `FeatureCard` ids placed on this product's
    /// board, in slot order. Empty is the default and the whole of the old
    /// game: an empty board multiplies quality by exactly 1.0 and is not
    /// written to the save at all.
    public var features: [String]
    // MARK: J5 (announce)
    /// The ship date told to the press, `nil` until one is and again once
    /// a second slip voids it. Kept after launch, so the copycat can read
    /// that it was announced. Not written while `nil`.
    public var announcedDay: Int?
    /// How many announced dates this build has missed (0, 1 or 2). Not
    /// written while 0.
    public var slips: Int
    // MARK: end J5
    // MARK: K2 (product lifecycle)
    /// The product this one replaced (`shipReplacing`), `nil` for every
    /// product that replaced nothing. Not written while `nil`.
    public var parentID: UUID?
    // MARK: end K2
    // MARK: T4 (publisher)
    /// The rival that advanced this build money for a share of it
    /// (`shopToPublisher`), `nil` for every product nobody published. Not
    /// written while `nil`.
    public var publisher: Publisher? = nil
    // MARK: end T4

    public init(
        id: UUID,
        name: String,
        typeID: String,
        topicID: String,
        stage: ProductStage,
        codebaseID: String? = nil,
        features: [String] = [],
        // MARK: J5 (announce)
        announcedDay: Int? = nil,
        slips: Int = 0,
        // MARK: end J5
        // MARK: K2 (product lifecycle)
        parentID: UUID? = nil
        // MARK: end K2
    ) {
        self.id = id
        self.name = name
        self.typeID = typeID
        self.topicID = topicID
        self.stage = stage
        self.codebaseID = codebaseID
        self.features = features
        // MARK: J5 (announce)
        self.announcedDay = announcedDay
        self.slips = slips
        // MARK: end J5
        // MARK: K2 (product lifecycle)
        self.parentID = parentID
        // MARK: end K2
    }
}

// Hand-written decode so an in-flight product from a save written before
// codebases existed keeps loading — with no codebase, which is greenfield,
// which is what it was — and, since iteration 10, with an empty feature
// board, which is what every product had before there were boards.
//
// The encode is hand-written for the other half of that promise: an empty
// board writes no `features` key at all, so a run that never opens the
// board produces byte-identical JSON to the one that shipped (which is
// what `OriginTests` and `ReleaseFixtureGenerator` check).
extension Product {
    private enum CodingKeys: String, CodingKey {
        case id, name, typeID, topicID, stage, codebaseID
        case features
        // MARK: J5 (announce)
        case announcedDay, slips
        // MARK: end J5
        // MARK: K2 (product lifecycle)
        case parentID
        // MARK: end K2
        // MARK: T4 (publisher)
        case publisher
        // MARK: end T4
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try container.decode(UUID.self, forKey: .id),
            name: try container.decode(String.self, forKey: .name),
            typeID: try container.decode(String.self, forKey: .typeID),
            topicID: try container.decode(String.self, forKey: .topicID),
            stage: try container.decode(ProductStage.self, forKey: .stage),
            codebaseID: try container.decodeIfPresent(String.self, forKey: .codebaseID),
            features: try container.decodeIfPresent([String].self, forKey: .features) ?? [],
            // MARK: J5 (announce)
            announcedDay: try container.decodeIfPresent(Int.self, forKey: .announcedDay),
            slips: try container.decodeIfPresent(Int.self, forKey: .slips) ?? 0,
            // MARK: end J5
            // MARK: K2 (product lifecycle)
            parentID: try container.decodeIfPresent(UUID.self, forKey: .parentID)
            // MARK: end K2
        )
        // MARK: T4 (publisher)
        publisher = try container.decodeIfPresent(Publisher.self, forKey: .publisher)
        // MARK: end T4
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(typeID, forKey: .typeID)
        try container.encode(topicID, forKey: .topicID)
        try container.encode(stage, forKey: .stage)
        try container.encodeIfPresent(codebaseID, forKey: .codebaseID)
        if !features.isEmpty { try container.encode(features, forKey: .features) }
        // MARK: J5 (announce) — written only when set, so a product nobody
        // announced encodes to the bytes it always did.
        try container.encodeIfPresent(announcedDay, forKey: .announcedDay)
        if slips != 0 { try container.encode(slips, forKey: .slips) }
        // MARK: end J5
        // MARK: K2 (product lifecycle) — only a successor has one.
        try container.encodeIfPresent(parentID, forKey: .parentID)
        // MARK: end K2
        // MARK: T4 (publisher) — only a published build has one.
        try container.encodeIfPresent(publisher, forKey: .publisher)
        // MARK: end T4
    }
}

extension UUID {
    /// Builds a UUID from two words of the seeded RNG.
    ///
    /// `UUID()` (like `Date()` and the system RNG) is banned inside the
    /// simulation: ids must replay byte-identically from the same seed, so
    /// all 128 bits come from `GameState.rng`.
    init(from rng: inout SeededRNG) {
        let hi = rng.next()
        let lo = rng.next()
        self.init(uuid: (
            UInt8(truncatingIfNeeded: hi >> 56), UInt8(truncatingIfNeeded: hi >> 48),
            UInt8(truncatingIfNeeded: hi >> 40), UInt8(truncatingIfNeeded: hi >> 32),
            UInt8(truncatingIfNeeded: hi >> 24), UInt8(truncatingIfNeeded: hi >> 16),
            UInt8(truncatingIfNeeded: hi >> 8), UInt8(truncatingIfNeeded: hi),
            UInt8(truncatingIfNeeded: lo >> 56), UInt8(truncatingIfNeeded: lo >> 48),
            UInt8(truncatingIfNeeded: lo >> 40), UInt8(truncatingIfNeeded: lo >> 32),
            UInt8(truncatingIfNeeded: lo >> 24), UInt8(truncatingIfNeeded: lo >> 16),
            UInt8(truncatingIfNeeded: lo >> 8), UInt8(truncatingIfNeeded: lo)
        ))
    }
}
