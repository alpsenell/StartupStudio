import Foundation
import TycoonContent

// MARK: J5 (announce)

/// Iteration 12 — J5. A ship date, said out loud.
///
/// `ShipETA` projects a day nobody commits to. Announcing one turns it into
/// a promise: the build's hype holds (1% a day, not 2%), campaigns on it land
/// ×1.25, the newspaper prints the date and the war room counts down to it.
/// Miss it once and the press prints a new one, with reputation −4 and the
/// hype at ×0.6; miss that too and it is −8, ×0.4, and nobody prints a
/// third. An announced product is also ripe for the copycat at four weeks
/// instead of eight.
///
/// State is two fields on `Product` (`announcedDay`, `slips`), written only
/// when set. The action is new and no bot sends it, so a run that never
/// announces reads and writes exactly what it did.

/// Why a date cannot be announced. Rule 7: a refused action says why.
public enum AnnounceRefusal: String, Equatable, Sendable, CaseIterable {
    case noSuchBuild
    case shipped
    case noDate
    case tooLate
    case alreadyAnnounced
    case void
    case tooSoon
    case tooFar

    public var sentence: String {
        switch self {
        case .noSuchBuild: "There is no build by that name."
        case .shipped: "It is already out. The date was the day it shipped."
        case .noDate: "Nobody is on it, so there is no date to give."
        case .tooLate: "It could nearly ship already. A date this close is a launch, not an announcement."
        case .alreadyAnnounced: "The press already has a date for this one."
        case .void: "The press stopped printing your dates for this one."
        case .tooSoon: "Three weeks' notice, or it is not an announcement."
        case .tooFar: "A date that far past the ETA is not a promise. Nobody would print it."
        }
    }
}

/// The pure half: rates, factors and the flags the `announce_` events read.
public enum Announce {
    /// The slip that voids the announcement.
    public static let voidAfterSlips = 2
    /// Raised on the first announcement, on the first slip, and when a
    /// second slip voids one. `Events.json`'s `announce_` events read them.
    public static let madeFlag = "announce_made"
    /// Raised while a date stands on a build in development; taken down
    /// the day none does.
    public static let liveFlag = "announce_live"
    public static let slippedFlag = "announce_slipped"
    public static let voidFlag = "announce_void"

    /// The daily hype decay for this product: the announced rate while a
    /// date stands on a build in development, the ordinary one otherwise —
    /// returned untouched, so an unannounced build decays bit for bit as
    /// it did.
    static func hypeDecayRate(for product: Product, _ balance: BalanceConfig) -> Double {
        guard product.announcedDay != nil, case .development = product.stage else {
            return balance.hypeDecayRate
        }
        return balance.announce.hypeDecayRate
    }

    /// What a campaign on this product is multiplied by: the announced
    /// factor while a date stands on a build in development, else 1.
    public static func campaignFactor(for product: Product, _ balance: BalanceConfig) -> Double {
        guard product.announcedDay != nil, case .development = product.stage else { return 1 }
        return balance.announce.campaignFactor
    }

    /// The reputation and the share of hype a slip costs, by which slip it is.
    public static func slipCost(
        slipNumber: Int, balance: BalanceConfig
    ) -> (reputation: Double, hypeFactor: Double) {
        let config = balance.announce
        return slipNumber >= voidAfterSlips
            ? (config.secondSlipReputation, config.secondSlipHypeFactor)
            : (config.firstSlipReputation, config.firstSlipHypeFactor)
    }

    /// Hype kept after `days` of decay at each rate — the sheet's "74%
    /// instead of 55%", from the balance rather than restated.
    public static func hypeKept(days: Int, balance: BalanceConfig) -> (announced: Double, quiet: Double) {
        (
            pow(1 - balance.announce.hypeDecayRate, Double(days)),
            pow(1 - balance.hypeDecayRate, Double(days))
        )
    }
}

extension Product {
    /// A date stands.
    public var isAnnounced: Bool { announcedDay != nil }
    /// A date was ever given — the copycat remembers even a void one.
    public var wasAnnounced: Bool { announcedDay != nil || slips > 0 }
    /// Two dates missed; the press will not print a third.
    public var announceIsVoid: Bool { announcedDay == nil && slips >= Announce.voidAfterSlips }
}

extension GameState {
    /// Why `day` cannot be announced for `productID`, or `nil` when it can.
    public func announceRefusal(
        productID: UUID,
        day announced: Int,
        balance: BalanceConfig,
        content: ContentCatalog
    ) -> AnnounceRefusal? {
        guard let product = product(id: productID) else { return .noSuchBuild }
        guard case .development = product.stage else { return .shipped }
        if product.announceIsVoid { return .void }
        if product.isAnnounced { return .alreadyAnnounced }
        guard let eta = shipETA(for: product, balance: balance, content: content) else { return .noDate }
        if eta.daysAway < balance.announce.earlyLeadDays { return .tooLate }
        if announced < announceEarliestDay(balance: balance) { return .tooSoon }
        if announced > eta.day + balance.announce.maxSlackDays { return .tooFar }
        return nil
    }

    /// The earliest day a date can be named for, from today.
    public func announceEarliestDay(balance: BalanceConfig) -> Int {
        day + max(0, balance.announce.minLeadDays)
    }

    /// The date the sheet proposes for `slackDays` over today's ETA, never
    /// sooner than the minimum notice. `nil` with nobody on the build.
    public func announceProposal(
        productID: UUID,
        slackDays: Int,
        balance: BalanceConfig,
        content: ContentCatalog
    ) -> Int? {
        guard let product = product(id: productID),
              let eta = shipETA(for: product, balance: balance, content: content)
        else { return nil }
        return max(announceEarliestDay(balance: balance), eta.day + max(0, slackDays))
    }

    /// Days from today to the announced date; negative once it is past.
    public func announceDaysLeft(for product: Product) -> Int? {
        product.announcedDay.map { $0 - day }
    }

    /// Today's ETA lands after the announced date: the date is at risk.
    /// `false` without a date, and `false` with no ETA to compare.
    public func announceIsBehind(
        _ product: Product, balance: BalanceConfig, content: ContentCatalog
    ) -> Bool {
        guard let announced = product.announcedDay,
              let eta = shipETA(for: product, balance: balance, content: content)
        else { return false }
        return eta.day > announced
    }

    /// Every build in development with a date standing, soonest first.
    public var announcedBuilds: [Product] {
        productsInDevelopment
            .filter(\.isAnnounced)
            .sorted { ($0.announcedDay ?? 0, $0.name) < ($1.announcedDay ?? 0, $1.name) }
    }

    /// The launch-week interview's warmth from the date: + when today's ETA
    /// makes it (or the product shipped on it), − when it does not (or it
    /// slipped). Exactly 0 for a product nobody announced.
    public func announceInterviewWarmth(
        for productID: UUID, balance: BalanceConfig, content: ContentCatalog
    ) -> Double {
        guard let product = product(id: productID), product.wasAnnounced else { return 0 }
        let warmth = balance.announce.interviewWarmth
        switch product.stage {
        case .development:
            if product.slips > 0 || product.announcedDay == nil { return -warmth }
            return announceIsBehind(product, balance: balance, content: content) ? -warmth : warmth
        case .released:
            return product.slips > 0 ? -warmth : warmth
        }
    }
}

// MARK: end J5

// MARK: T5 (expo and pre-orders)

/// Iteration 17 — T5 (genre G6 merged with player P4). Pre-orders on an
/// announced date.
///
/// On an announced one-time build at least `preorders.minDaysBefore` (21)
/// days from its date, the player can sell `preorders.fraction` (30%) of
/// the forecast's launch — the units it sells until the adoption ramp
/// peaks (`launchWindowEstimate`) — now at `preorders.price` (65%) of the
/// standard price, in cash. The launch weeks deliver them: their first
/// buyers are the pre-orders, already paid for, so their revenue counts
/// only the rest until every pre-order is out
/// (`AnnounceSystem.deliverPreorders`). A slip gives back
/// `preorders.refundPerSlip` (a third) of them in cash on the day J5 takes
/// its −4; the void gives back the rest and costs `preorders.
/// voidReputation` (4) more. Once per product.
///
/// State is `Product.preorders`, written only by `.openPreorders`, which no
/// bot sends.
public struct PreorderBook: Codable, Equatable, Sendable {
    /// Units sold the day pre-orders opened.
    public var units: Int
    /// What one of them paid.
    public var unitPrice: Double
    /// The cash taken that day.
    public var cash: Int
    public var openedDay: Int
    /// The quality the forecast promised when they were sold — the number
    /// the reviews are held to on launch day ("overpromised").
    public var forecastQuality: Double
    /// Given back by slips so far.
    public var refundedUnits: Int
    public var refundedCash: Int
    /// The day the launch weeks finished delivering them, `nil` until they
    /// have.
    public var deliveredDay: Int?
    /// Delivered so far, out of the sales weeks already carved.
    public var deliveredUnits: Int
    /// Sales weeks carved so far (their first buyers were pre-orders).
    public var deliveredWeeks: Int

    public init(
        units: Int,
        unitPrice: Double,
        cash: Int,
        openedDay: Int,
        forecastQuality: Double,
        refundedUnits: Int = 0,
        refundedCash: Int = 0,
        deliveredDay: Int? = nil,
        deliveredUnits: Int = 0,
        deliveredWeeks: Int = 0
    ) {
        self.units = units
        self.unitPrice = unitPrice
        self.cash = cash
        self.openedDay = openedDay
        self.forecastQuality = forecastQuality
        self.refundedUnits = refundedUnits
        self.refundedCash = refundedCash
        self.deliveredDay = deliveredDay
        self.deliveredUnits = deliveredUnits
        self.deliveredWeeks = deliveredWeeks
    }

    /// Sold and not refunded: what the launch owes.
    public var outstanding: Int { max(0, units - refundedUnits) }
    /// Still to go out with the launch weeks.
    public var undelivered: Int { max(0, outstanding - deliveredUnits) }
    public var isDelivered: Bool { deliveredDay != nil }

    private enum CodingKeys: String, CodingKey {
        case units, unitPrice, cash, openedDay, forecastQuality
        case refundedUnits, refundedCash, deliveredDay, deliveredUnits, deliveredWeeks
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            units: try c.decode(Int.self, forKey: .units),
            unitPrice: try c.decode(Double.self, forKey: .unitPrice),
            cash: try c.decode(Int.self, forKey: .cash),
            openedDay: try c.decode(Int.self, forKey: .openedDay),
            forecastQuality: try c.decodeIfPresent(Double.self, forKey: .forecastQuality) ?? 0,
            refundedUnits: try c.decodeIfPresent(Int.self, forKey: .refundedUnits) ?? 0,
            refundedCash: try c.decodeIfPresent(Int.self, forKey: .refundedCash) ?? 0,
            deliveredDay: try c.decodeIfPresent(Int.self, forKey: .deliveredDay),
            deliveredUnits: try c.decodeIfPresent(Int.self, forKey: .deliveredUnits) ?? 0,
            deliveredWeeks: try c.decodeIfPresent(Int.self, forKey: .deliveredWeeks) ?? 0
        )
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(units, forKey: .units)
        try c.encode(unitPrice, forKey: .unitPrice)
        try c.encode(cash, forKey: .cash)
        try c.encode(openedDay, forKey: .openedDay)
        try c.encode(forecastQuality, forKey: .forecastQuality)
        if refundedUnits != 0 { try c.encode(refundedUnits, forKey: .refundedUnits) }
        if refundedCash != 0 { try c.encode(refundedCash, forKey: .refundedCash) }
        try c.encodeIfPresent(deliveredDay, forKey: .deliveredDay)
        if deliveredUnits != 0 { try c.encode(deliveredUnits, forKey: .deliveredUnits) }
        if deliveredWeeks != 0 { try c.encode(deliveredWeeks, forKey: .deliveredWeeks) }
    }
}

/// Why pre-orders cannot open. Rule 7: a refused action says why.
public enum PreorderRefusal: String, Equatable, Sendable, CaseIterable {
    case noSuchBuild
    case shipped
    case alreadyOpened
    case notAnnounced
    case subscription
    case tooClose
    case nothingToSell

    public var sentence: String {
        switch self {
        case .noSuchBuild: "There is no build by that name."
        case .shipped: "It is out. People buy it now; they do not pre-order it."
        case .alreadyOpened: "Pre-orders are open already. Once per product."
        case .notAnnounced: "Nobody pre-orders a build without a date. Announce one first."
        case .subscription: "Subscriptions do not pre-sell. Nobody pays a year up front for a thing that does not exist."
        case .tooClose: "Three weeks before the date, or it is not a pre-order, it is a sale."
        case .nothingToSell: "The forecast sells nothing in the launch week. There is nothing to pre-sell."
        }
    }
}

/// What opening pre-orders would take today, as the sheet prints it and as
/// the action applies it.
public struct PreorderQuote: Equatable, Sendable {
    /// The forecast's launch, from `launchWindowEstimate`: its weeks and
    /// the units in them.
    public var windowWeeks: Int
    public var windowUnits: Int
    public var units: Int
    public var unitPrice: Double
    /// The standard price the launch week would charge.
    public var standardPrice: Double
    public var cash: Int
    /// What the first slip would give back.
    public var firstRefundUnits: Int
    public var firstRefundCash: Int
    public var forecastQuality: Double
}

extension PreorderBook {
    /// Units a slip gives back: `refundPerSlip` of those sold, or on the
    /// void everything still owed.
    public func refundUnits(voiding: Bool, balance: BalanceConfig) -> Int {
        voiding
            ? outstanding
            : min(outstanding, Int((Double(units) * balance.expo.preorders.refundPerSlip).rounded()))
    }

    /// Cash for `units` of them, at what they paid.
    public func refundCash(units: Int) -> Int {
        Int((Double(units) * unitPrice).rounded())
    }
}

extension GameState {
    /// What pre-orders on `productID` would take if opened today; `nil`
    /// for anything not in development or with no launch-week forecast.
    /// Arithmetic only: `preorderRefusal` says whether it is allowed.
    public func preorderQuote(
        productID: UUID, balance: BalanceConfig, content: ContentCatalog
    ) -> PreorderQuote? {
        guard let product = product(id: productID),
              let type = content.productType(product.typeID),
              let window = launchWindowEstimate(productID: productID, balance: balance, content: content),
              let forecast = shipForecast(productID: productID, balance: balance, content: content)
        else { return nil }
        let config = balance.expo.preorders
        let standard = type.unitPrice * balance.economy.priceTier(.standard).priceFactor
        let units = max(0, Int(Double(window.units) * config.fraction))
        let unitPrice = standard * config.price
        let book = PreorderBook(
            units: units, unitPrice: unitPrice, cash: Int((Double(units) * unitPrice).rounded()),
            openedDay: day, forecastQuality: forecast.quality
        )
        let firstRefund = book.refundUnits(voiding: false, balance: balance)
        return PreorderQuote(
            windowWeeks: window.weeks, windowUnits: window.units,
            units: units, unitPrice: unitPrice, standardPrice: standard,
            cash: book.cash, firstRefundUnits: firstRefund, firstRefundCash: book.refundCash(units: firstRefund),
            forecastQuality: forecast.quality
        )
    }

    /// Why pre-orders cannot open on `productID` today, or `nil` when they
    /// can.
    public func preorderRefusal(
        productID: UUID, balance: BalanceConfig, content: ContentCatalog
    ) -> PreorderRefusal? {
        guard let product = product(id: productID) else { return .noSuchBuild }
        guard case .development = product.stage else { return .shipped }
        if product.preorders != nil { return .alreadyOpened }
        guard let date = product.announcedDay else { return .notAnnounced }
        if content.productType(product.typeID)?.revenueModel == .subscription { return .subscription }
        if date - day < balance.expo.preorders.minDaysBefore { return .tooClose }
        guard let quote = preorderQuote(productID: productID, balance: balance, content: content),
              quote.units > 0
        else { return .nothingToSell }
        return nil
    }
}

extension Product {
    /// Launch day's "overpromised": the reviews landed under the quality
    /// the pre-orders were sold on. `false` without pre-orders or reviews.
    public var preordersOverpromised: Bool {
        guard let book = preorders, case .released(let info) = stage, !info.reviews.isEmpty else { return false }
        return Double(info.averageReviewScore) < book.forecastQuality.rounded()
    }
}

// MARK: end T5
