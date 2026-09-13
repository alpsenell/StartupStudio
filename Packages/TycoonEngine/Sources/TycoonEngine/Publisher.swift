import Foundation
import TycoonContent

// MARK: T4 (publisher)

// Iteration 17 — T4 (genre G1). The publishing deal.
//
// The strongest rival at `publisher.minStrength` advances a build in
// development what it costs to finish — `(crew pay + running costs + rent)
// × the weeks to the ETA` — in cash today. It takes `publisher.share` of
// the product's revenue every week for as long as it sells, names the date
// (the ETA plus two weeks, announced through J5's own announcement, so a
// slip costs what a slip costs and claws back a quarter of the advance),
// puts its name on launch day (`launchEventHype × launchHypeFactor`), and
// moves into the topic the day it signs. *Buy them out* later at
// `buyoutMultiple ×` the advance, less what they have been paid.
//
// State is one optional field on `Product`, written only when set. The
// counterparty is picked by sort and the terms by arithmetic: nothing here
// reads a stream, and no bot sends either action.

/// The publisher on one build: who, what they paid, what they take.
public struct Publisher: Codable, Equatable, Sendable {
    public var rivalID: UUID
    /// Kept so the deal still names them if the studio leaves the field.
    public var rivalName: String
    /// What they paid up front, in dollars.
    public var advance: Int
    /// Their share of the weekly revenue, 0…1.
    public var share: Double
    public var signedDay: Int
    /// The share paid to them so far.
    public var paidBack: Int
    /// What missed dates have cost so far.
    public var clawedBack: Int

    public init(
        rivalID: UUID,
        rivalName: String,
        advance: Int,
        share: Double,
        signedDay: Int,
        paidBack: Int = 0,
        clawedBack: Int = 0
    ) {
        self.rivalID = rivalID
        self.rivalName = rivalName
        self.advance = advance
        self.share = share
        self.signedDay = signedDay
        self.paidBack = paidBack
        self.clawedBack = clawedBack
    }
}

/// Why a build cannot be shopped today. Rule 7: a refused action says why.
public enum PublisherRefusal: String, Equatable, Sendable, CaseIterable {
    case ended
    case noSuchBuild
    case shipped
    case published
    case earnOut
    case void
    case nobody
    case noDate
    case tooLate
    case noPrint

    public var sentence: String {
        switch self {
        case .ended: "This company already had its ending."
        case .noSuchBuild: "There is no build by that name."
        case .shipped: "It is out already. Publishers pay for what is still being built."
        case .published: "Somebody already publishes this one."
        case .earnOut: "It is sold already: the earn-out is running."
        case .void: "The press stopped printing your dates for this one, and a publisher sells a date."
        case .nobody: "Nobody would publish this."
        case .noDate: "Nobody is on it, so there is no date to sell."
        case .tooLate: "It could nearly ship already. Nobody advances money on a finished build."
        case .noPrint: "The press would not print the date a publisher needs."
        }
    }
}

/// What their share of the first weeks would come to, on today's forecast.
public struct PublisherEstimate: Equatable, Sendable {
    /// The review the press would give the finished build today (no hype,
    /// no noise): the crew's ceiling against this year's expectations.
    public var review: Int
    public var weeks: Int
    /// The build's revenue over `weeks`, standard price, after the launch
    /// saturation the forecast already reads.
    public var revenue: Int
    /// Their share of it.
    public var theirs: Int
}

/// A publishing deal's terms for one build, printed before the tap, or why
/// there is none.
public struct PublisherTerms: Equatable, Sendable {
    public var rivalID: UUID?
    public var rivalName: String?
    /// The crew's own weekly pay…
    public var crewPay: Int
    /// …and the line the advance counts, after the floor.
    public var crewLine: Int
    public var runningCost: Int
    public var rent: Int
    public var daysToETA: Int
    /// The weeks the advance pays for (the ETA's, × `advanceWeeksFactor`).
    public var weeksPaid: Double
    public var advance: Int
    public var share: Double
    /// The date in print once they sign: theirs, or the one already standing.
    public var date: Int?
    public var keepsStandingDate: Bool
    public var launchHype: Double
    /// What one missed date claws back.
    public var clawbackPerSlip: Int
    /// What buying them out would cost the day after signing.
    public var buyoutAtSigning: Int
    public var topicID: String
    /// The studio already lives in this topic.
    public var topicIsHome: Bool
    public var estimate: PublisherEstimate?
    public var refusal: PublisherRefusal?

    public var weekly: Int { crewLine + runningCost + rent }
    public var isOpen: Bool { refusal == nil }
}

extension GameState {
    /// The counterparty: the strongest rival at `publisher.minStrength`,
    /// ties broken on the id as `RivalSystem` breaks them.
    public func publisherCandidate(balance: BalanceConfig) -> Rival? {
        Self.dealStrongest(rivals.rivals.filter { $0.strength >= balance.publisher.minStrength })
    }

    /// Today's terms for `productID`.
    public func publisherTerms(productID: UUID, balance: BalanceConfig, content: ContentCatalog) -> PublisherTerms {
        let config = balance.publisher
        let product = product(id: productID)
        let rival = publisherCandidate(balance: balance)
        let eta = product.flatMap { shipETA(for: $0, balance: balance, content: content) }
        let crewPay = employees.filter { $0.assignment == .product(productID) }.reduce(0) { $0 + $1.weeklySalary }
        let crewLine = max(crewPay, Int((Double(balance.salaryBase) * config.crewFloorSalaryBases).rounded()))
        let running = balance.weeklyOperatingCost
        let rent = officeWeeklyRent(balance: balance)
        let days = eta?.daysAway ?? 0
        let weeks = Double(days) / Double(Self.daysPerWeek) * config.advanceWeeksFactor
        let advance = max(0, Int((Double(crewLine + running + rent) * weeks).rounded()))
        let standing = product?.announcedDay
        let date = standing ?? eta.map { $0.day + max(0, config.dateSlackDays) }
        let share = min(1, max(0, config.share))
        let topicID = product?.topicID ?? ""
        return PublisherTerms(
            rivalID: rival?.id,
            rivalName: rival?.name,
            crewPay: crewPay,
            crewLine: crewLine,
            runningCost: running,
            rent: rent,
            daysToETA: days,
            weeksPaid: weeks,
            advance: advance,
            share: share,
            date: date,
            keepsStandingDate: standing != nil,
            launchHype: balance.launchEventHype * config.launchHypeFactor,
            clawbackPerSlip: Int((Double(advance) * config.clawbackPerSlip).rounded()),
            buyoutAtSigning: Int((Double(advance) * config.buyoutMultiple).rounded()),
            topicID: topicID,
            topicIsHome: rival?.focusTopicIDs.contains(topicID) ?? false,
            estimate: product.flatMap { publisherEstimate(for: $0, share: share, balance: balance, content: content) },
            refusal: publisherRefusal(product: product, rival: rival, eta: eta, date: date, balance: balance, content: content)
        )
    }

    private func publisherRefusal(
        product: Product?, rival: Rival?, eta: ShipETA?, date: Int?,
        balance: BalanceConfig, content: ContentCatalog
    ) -> PublisherRefusal? {
        if gameOver != nil || epilogue != nil { return .ended }
        guard let product else { return .noSuchBuild }
        guard case .development = product.stage else { return .shipped }
        if product.publisher != nil { return .published }
        if investors.earnOut != nil { return .earnOut }
        if product.announceIsVoid { return .void }
        if rival == nil { return .nobody }
        guard let eta else { return .noDate }
        if eta.daysAway < balance.announce.earlyLeadDays { return .tooLate }
        if !product.isAnnounced {
            guard let date,
                  announceRefusal(productID: product.id, day: date, balance: balance, content: content) == nil
            else { return .noPrint }
        }
        return nil
    }

    /// Their share of the build's first `estimateWeeks` weeks, at the
    /// review the press would give it finished today.
    public func publisherEstimate(
        for product: Product, share: Double, balance: BalanceConfig, content: ContentCatalog
    ) -> PublisherEstimate? {
        guard let type = content.productType(product.typeID),
              let forecast = shipForecast(productID: product.id, balance: balance, content: content)
        else { return nil }
        let quality = min(100, forecast.crewCeiling * 100 * forecast.featureMultiplier)
        let expected = balance.reviewExpectationBase
            + balance.reviewExpectationPerYear * Double(year - 1)
            + balance.reviewExpectationRepFactor * company.reputation
            + balance.economy.expectationPerComplexity * (type.complexity - 1)
        let score = quality - balance.reviewShortfallPenalty * max(0, expected - quality)
        let review = min(balance.reviewCeiling, max(balance.reviewFloor, Int(score)))
        let marketing = employees.isEmpty ? 0
            : employees.reduce(0.0) { $0 + $1.skills.marketing } / Double(employees.count)
        let ramp = max(balance.adoption.rampWeeksMin,
                       balance.adoption.rampWeeksMax - marketing / balance.adoption.marketingDivisor)
        let weeks = max(1, balance.publisher.estimateWeeks)
        let revenue = Self.publisherRevenue(
            type: type, review: review, marketScale: forecast.marketScale,
            adoptionWeeks: ramp, weeks: weeks, balance: balance
        )
        return PublisherEstimate(
            review: review, weeks: weeks, revenue: revenue,
            theirs: Int((Double(revenue) * share).rounded())
        )
    }

    /// A release's revenue over `weeks` as `postWeeklySales` would post it
    /// with no hype, a flat market and the standard price.
    static func publisherRevenue(
        type: ProductTypeDef, review: Int, marketScale: Double,
        adoptionWeeks: Double, weeks: Int, balance: BalanceConfig
    ) -> Int {
        let q = Double(review) / 100
        let economy = balance.economy
        let demand = type.marketSize * balance.marketSizeScale
            * (balance.salesBaseFactor + balance.salesQualityFactor * q) * marketScale
        let ramp = max(1, adoptionWeeks)
        var total = 0.0
        var book = 0.0
        for week in 0..<weeks {
            let adoption = min(1, (Double(week) + 1) / ramp)
            if type.revenueModel == .subscription {
                let acquired = demand / max(1, economy.subscriberAcquisitionWeeks) * adoption
                let churn = max(0, economy.churnBase - economy.churnQualityFactor * q)
                book = max(0, book + acquired - book * churn)
                let subscribers = book.rounded()
                if adoption >= 1, subscribers < Double(economy.subscriptionFloorSubscribers) { break }
                total += subscribers * type.unitPrice
            } else {
                let decay = balance.salesDecayBase + balance.salesDecayQualityFactor * q
                let units = Double(Int(demand * adoption * pow(decay, max(0, Double(week) - (ramp - 1)))))
                if units == 0 || (adoption >= 1 && units < balance.delistFraction * demand) { break }
                total += units * type.unitPrice
            }
        }
        return Int(total.rounded())
    }

    /// Whether the publisher on `product` still takes its share: the deal
    /// lapses with the studio (bought, folded).
    public func publisherIsActive(_ product: Product) -> Bool {
        guard let publisher = product.publisher else { return false }
        return rivals.rival(id: publisher.rivalID) != nil
    }

    /// The publisher's name on launch day. Exactly 0 for a build nobody
    /// publishes, which is every build a bot or a fixture ever ships.
    public func publisherLaunchHype(for product: Product, balance: BalanceConfig) -> Double {
        guard publisherIsActive(product) else { return 0 }
        return balance.launchEventHype * balance.publisher.launchHypeFactor
    }

    /// What buying the publisher out costs today, `nil` with none.
    public func publisherBuyoutPrice(for product: Product, balance: BalanceConfig) -> Int? {
        guard let publisher = product.publisher else { return nil }
        let price = Int((Double(publisher.advance) * balance.publisher.buyoutMultiple).rounded())
        return max(0, price - publisher.paidBack)
    }

    /// Why the publisher on `productID` cannot be bought out today.
    public func publisherBuyoutBlocker(productID: UUID, balance: BalanceConfig) -> String? {
        if gameOver != nil || epilogue != nil { return PublisherRefusal.ended.sentence }
        guard let product = product(id: productID),
              let price = publisherBuyoutPrice(for: product, balance: balance)
        else { return "Nobody publishes this one." }
        if company.cash < price {
            return "It costs \(price.dollars); the company has \(company.cash.dollars)."
        }
        return nil
    }

    /// Every product `rivalID` publishes, in the line's order.
    public func productsPublished(by rivalID: UUID) -> [Product] {
        products.filter { $0.publisher?.rivalID == rivalID }
    }
}

// MARK: end T4
