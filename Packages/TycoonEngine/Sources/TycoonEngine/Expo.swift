import Foundation
import TycoonContent

// MARK: T5 (expo and pre-orders)

/// Iteration 17 — T5 (genre G2). The expo: a dated show on day 182 of every
/// year, the way `AwardsJudge.ceremonyDay` is day 350.
///
/// From `expo.noticeDays` (28) before the show the Now card and the queue
/// say *Expo in N days*, and a booth can be booked for one build in
/// development — or the hallway worked, or the show skipped. The booking is
/// paid when it is made and can be pointed at another build, or another
/// person, for free until the day; on the day (`MarketingSystem.runExpo`)
/// the demo happens with whatever the build is by then: its open bugs
/// decide whether it crashes, its quality so far whether the press liked
/// it. Either way the build is public from then: the copycat is ready four
/// weeks after its launch instead of eight, and reviewers expect +3.
///
/// State is `GameState.expo` (the last year shown or skipped, and the
/// booking) and `Product.expoDay`, both written only by the two actions,
/// which no bot sends. The date is arithmetic and nothing is drawn.

/// A booth or the hallway.
public enum ExpoBooth: String, Codable, Equatable, Sendable, CaseIterable {
    case booth, hallway
}

/// Who stands at it.
public enum ExpoAttendee: String, Codable, Equatable, Sendable, CaseIterable {
    case founder, marketer
}

/// This year's booking: paid, pointed at one build, shown on the day.
public struct ExpoBooking: Codable, Equatable, Sendable {
    public var year: Int
    public var productID: UUID
    public var booth: ExpoBooth
    public var attendee: ExpoAttendee
    /// What the booking cost the day it was made.
    public var paid: Int

    public init(year: Int, productID: UUID, booth: ExpoBooth, attendee: ExpoAttendee, paid: Int) {
        self.year = year
        self.productID = productID
        self.booth = booth
        self.attendee = attendee
        self.paid = paid
    }
}

/// `GameState.expo`: `nil` on every run that never touched the show.
public struct ExpoState: Codable, Equatable, Sendable {
    /// The last year the company showed at the expo or skipped it; 0 for
    /// never.
    public var lastYear: Int
    /// A booth paid for and not yet shown.
    public var booking: ExpoBooking?

    public init(lastYear: Int = 0, booking: ExpoBooking? = nil) {
        self.lastYear = lastYear
        self.booking = booking
    }

    private enum CodingKeys: String, CodingKey {
        case lastYear, booking
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            lastYear: try c.decodeIfPresent(Int.self, forKey: .lastYear) ?? 0,
            booking: try c.decodeIfPresent(ExpoBooking.self, forKey: .booking)
        )
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        if lastYear != 0 { try c.encode(lastYear, forKey: .lastYear) }
        try c.encodeIfPresent(booking, forKey: .booking)
    }
}

/// Why a booth cannot be booked. Rule 7: a refused action says why.
public enum ExpoRefusal: String, Equatable, Sendable, CaseIterable {
    case notYet
    case over
    case alreadyDone
    case noSuchBuild
    case notInDevelopment
    case noBooth
    case boothBooked
    case noMarketer
    case cantAfford

    public var sentence: String {
        switch self {
        case .notYet: "The expo is not taking bookings yet."
        case .over: "The expo is over for this year."
        case .alreadyDone: "You have been to this year's expo, or chose not to go."
        case .noSuchBuild: "There is no build by that name."
        case .notInDevelopment: "Only a build still in development can be shown. A released one is a product, not a demo."
        case .noBooth: "A booth is for companies with an office. The hallway is free to walk."
        case .boothBooked: "What you paid for is booked. You can change the build or who goes, not the stand."
        case .noMarketer: "Nobody on payroll markets anything. The founder can go."
        case .cantAfford: "Not enough cash for that."
        }
    }
}

/// What a demo would do today, as the sheet prints it and as the day
/// applies it.
public struct ExpoQuote: Equatable, Sendable {
    /// Hype the shown build gains.
    public var hype: Double
    /// Reputation, + for a good demo, − for a crash, 0 in between.
    public var reputation: Double
    /// More open bugs than `expo.crashBugs`.
    public var crashed: Bool
    /// Somebody from the company is at the stand. When nobody is (the
    /// founder has no evening left, the marketer left), a booth works as
    /// the hallway.
    public var staffed: Bool
    /// The build's quality so far and its open bugs, as the demo reads them.
    public var quality: Double
    public var openBugs: Int
}

/// The pure half: the date and the price.
public enum Expo {
    /// The show's day in `year` (1-based).
    public static func day(year: Int, balance: BalanceConfig) -> Int {
        day(year: year, config: balance.expo)
    }

    /// The same, off the expo block alone (the queue reads it without a
    /// balance for the tab badge).
    public static func day(year: Int, config: BalanceConfig.ExpoBalance) -> Int {
        (year - 1) * GameState.daysPerYear + config.dayOfYear
    }
}

extension GameState {
    /// This year's show.
    public func expoDay(balance: BalanceConfig) -> Int {
        Expo.day(year: year, balance: balance)
    }

    /// Whether the company already showed at, or skipped, this year's
    /// expo.
    public func expoDoneThisYear() -> Bool {
        expo?.lastYear == year
    }

    /// Days to this year's show while the notice window is open and the
    /// company has not been or skipped: 0 on the day, `nil` otherwise.
    public func expoDaysLeft(balance: BalanceConfig) -> Int? {
        expoDaysLeft(config: balance.expo)
    }

    /// The same, off the expo block alone.
    public func expoDaysLeft(config: BalanceConfig.ExpoBalance) -> Int? {
        let show = Expo.day(year: year, config: config)
        guard day <= show, day >= show - max(0, config.noticeDays), !expoDoneThisYear() else {
            return nil
        }
        return show - day
    }

    /// This year's booking, if one is paid for.
    public var expoBooking: ExpoBooking? {
        guard let booking = expo?.booking, booking.year == year else { return nil }
        return booking
    }

    /// The price of `booth` for this company today; `nil` for a booth the
    /// office tier cannot take.
    public func expoPrice(_ booth: ExpoBooth, balance: BalanceConfig) -> Int? {
        switch booth {
        case .booth: balance.expo.boothPrice(for: company.officeTier)
        case .hallway: balance.expo.hallway
        }
    }

    /// Whether a marketer is on payroll.
    public var expoHasMarketer: Bool {
        employees.contains { $0.role == .marketer }
    }

    /// Why `booth` with `attendee` cannot be booked for `productID` today,
    /// or `nil` when it can.
    public func expoRefusal(
        productID: UUID,
        booth: ExpoBooth,
        attendee: ExpoAttendee,
        balance: BalanceConfig
    ) -> ExpoRefusal? {
        let show = expoDay(balance: balance)
        if expoDoneThisYear() { return .alreadyDone }
        if day < show - max(0, balance.expo.noticeDays) { return .notYet }
        if day > show { return .over }
        guard let product = product(id: productID) else { return .noSuchBuild }
        guard case .development = product.stage else { return .notInDevelopment }
        guard let price = expoPrice(booth, balance: balance) else { return .noBooth }
        if attendee == .marketer, !expoHasMarketer { return .noMarketer }
        if let booking = expoBooking {
            // Paid for: the stand is fixed, the build and the person are not.
            return booking.booth == booth ? nil : .boothBooked
        }
        return company.cash < price ? .cantAfford : nil
    }

    /// What showing `productID` would do today. `nil` for anything not in
    /// development.
    public func expoQuote(
        productID: UUID,
        booth: ExpoBooth,
        attendee: ExpoAttendee,
        balance: BalanceConfig,
        content: ContentCatalog
    ) -> ExpoQuote? {
        guard let product = product(id: productID),
              case .development(let dev) = product.stage,
              let forecast = shipForecast(productID: productID, balance: balance, content: content)
        else { return nil }
        let config = balance.expo
        let crashed = dev.openBugs > config.crashBugs
        let staffed = attendee == .founder ? hasEveningFree(balance) : expoHasMarketer
        // The hallway, or a stand nobody from the company is at, works at
        // half of everything.
        let share = booth == .hallway || !staffed ? config.hallwayFactor : 1
        let pitch = attendee == .marketer && staffed ? config.marketerFactor : 1
        var hype = config.hype * TraitEffects.campaignHypeFactor(employees, content: content) * pitch * share
        if crashed { hype *= config.crashHypeFactor }
        let reputation: Double = if crashed {
            -config.reputationCrash * share
        } else if forecast.quality >= config.goodQuality {
            config.reputationGood * share
        } else {
            0
        }
        return ExpoQuote(
            hype: hype, reputation: reputation, crashed: crashed, staffed: staffed,
            quality: forecast.quality, openBugs: dev.openBugs
        )
    }
}

extension Product {
    /// Shown at an expo while in development: the copycat and the
    /// reviewers both saw the demo.
    public var wasShownAtExpo: Bool { expoDay != nil }
}

/// The review expectation a build carries into its launch: +`expo.
/// expectationBump` for one shown at the expo, exactly 0 for every other.
enum ExpoRules {
    static func expectationBump(for product: Product, balance: BalanceConfig) -> Double {
        product.expoDay == nil ? 0 : balance.expo.expectationBump
    }
}

// MARK: - Debug seeds

/// `-autoExpo <step[,step…]>`: dresses a loaded save for a screenshot.
///
/// - `window`: runs the clock into the notice window of the next show.
/// - `day`: runs it to the show's day.
/// - `crash`: the best build carries more open bugs than a demo survives.
/// - `booked`: a stand for the best build — a booth where the office can
///   take one, the founder at it (topping the cash up to afford it).
/// - `shown`: `booked`, then the clock to the day: the demo happens.
///
/// Reached only through `.expoDebugSeed`, which the reducer applies in
/// debug builds alone.
enum ExpoDebugSeed {
    static func apply(
        scenario: String,
        state: inout GameState,
        balance: BalanceConfig,
        content: ContentCatalog
    ) -> [GameEvent] {
        let steps = Set(scenario.split(separator: ",").map(String.init))
        let config = balance.expo
        var show = state.expoDay(balance: balance)
        if state.day > show { show = Expo.day(year: state.year + 1, config: config) }

        func runClock(to target: Int) {
            var budget = 800
            while state.day < target, state.gameOver == nil, budget > 0 {
                _ = Reducer.tick(&state, balance: balance, content: content)
                budget -= 1
            }
        }

        if steps.contains("window") { runClock(to: show - config.noticeDays) }
        if steps.contains("day") { runClock(to: show) }

        let best = state.productsInDevelopment.max { lhs, rhs in
            let l = state.shipForecast(productID: lhs.id, balance: balance, content: content)?.quality ?? 0
            let r = state.shipForecast(productID: rhs.id, balance: balance, content: content)?.quality ?? 0
            return l != r ? l < r : lhs.name > rhs.name
        }
        if steps.contains("crash"), let best,
           let index = state.products.firstIndex(where: { $0.id == best.id }),
           case .development(var dev) = state.products[index].stage {
            dev.openBugs = config.crashBugs + 6
            state.products[index].stage = .development(dev)
        }
        var events: [GameEvent] = []
        if steps.contains("booked") || steps.contains("shown"), let best {
            let booth: ExpoBooth = state.expoPrice(.booth, balance: balance) == nil ? .hallway : .booth
            state.company.cash = max(state.company.cash, (state.expoPrice(booth, balance: balance) ?? 0) + 1_000)
            events += MarketingSystem.showAtExpo(
                productID: best.id, booth: booth, attendee: .founder,
                state: &state, balance: balance, content: content
            )
        }
        if steps.contains("shown") { runClock(to: show) }
        return events
    }
}

// MARK: end T5
