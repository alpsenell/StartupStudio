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
