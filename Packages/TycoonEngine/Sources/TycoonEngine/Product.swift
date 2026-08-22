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

    public init(
        designPts: Double,
        codePts: Double,
        polishPts: Double,
        openBugs: Int,
        focus: PhaseFocus,
        hype: Double
    ) {
        self.designPts = designPts
        self.codePts = codePts
        self.polishPts = polishPts
        self.openBugs = openBugs
        self.focus = focus
        self.hype = hype
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

    public init(
        launchDay: Int,
        quality: Double,
        reviews: [Review],
        weeklySales: [WeeklySale],
        offMarket: Bool,
        hypeAtLaunch: Double = 0
    ) {
        self.launchDay = launchDay
        self.quality = quality
        self.reviews = reviews
        self.weeklySales = weeklySales
        self.offMarket = offMarket
        self.hypeAtLaunch = hypeAtLaunch
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

    public init(id: UUID, name: String, typeID: String, topicID: String, stage: ProductStage) {
        self.id = id
        self.name = name
        self.typeID = typeID
        self.topicID = topicID
        self.stage = stage
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
