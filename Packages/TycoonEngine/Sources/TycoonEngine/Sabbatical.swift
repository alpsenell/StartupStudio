import Foundation
import TycoonContent

// Iteration 9 — L6 owns this file and may reshape it freely.

/// A number the company was at, taken twice: the morning the founder left
/// and the morning they came back. The return sheet is the difference.
public struct SabbaticalSnapshot: Codable, Equatable, Sendable {
    public var cash: Int
    public var reputation: Double
    public var headcount: Int
    /// Average morale across the non-founder roster, 0 on an empty one.
    public var morale: Double
    /// Products on the market.
    public var live: Int

    public init(cash: Int, reputation: Double, headcount: Int, morale: Double, live: Int) {
        self.cash = cash
        self.reputation = reputation
        self.headcount = headcount
        self.morale = morale
        self.live = live
    }

    /// The company as it stands today.
    public init(_ state: GameState) {
        let staff = state.employees.filter { !$0.isFounder }
        self.init(
            cash: state.company.cash,
            reputation: state.company.reputation,
            headcount: staff.count,
            morale: staff.isEmpty
                ? 0
                : staff.reduce(0) { $0 + $1.morale } / Double(staff.count),
            live: state.products.count { product in
                if case .released = product.stage { return true }
                return false
            }
        )
    }
}

/// One line of the caretaker's log — what the phone said that day.
///
/// `ordinal` is the entry's position in the log, so the identity is stable,
/// encodes identically, and draws from nothing.
public struct SabbaticalLogEntry: Codable, Equatable, Sendable, Identifiable {
    public var ordinal: Int
    public var day: Int
    public var text: String
    /// Whether the line is a decision the caretaker took (rather than a
    /// quiet day's weather).
    public var isDecision: Bool

    public var id: Int { ordinal }

    public init(ordinal: Int, day: Int, text: String, isDecision: Bool) {
        self.ordinal = ordinal
        self.day = day
        self.text = text
        self.isDecision = isDecision
    }
}

/// What the caretaker did with the company while the founder was gone.
/// Kept on `SabbaticalState` after the trip ends so the return sheet, the
/// card and the biography can all quote the same numbers.
public struct SabbaticalReport: Codable, Equatable, Sendable {
    public var caretakerID: UUID
    public var caretakerName: String
    public var sinceDay: Int
    public var endedDay: Int
    /// Weeks asked for, which is not always weeks taken.
    public var weeks: Int
    public var endedEarly: Bool
    /// Why it ended early, in the player's words. `nil` on a full trip.
    public var earlyReason: String?
    /// Wallet money the trip actually cost.
    public var cost: Int
    public var opening: SabbaticalSnapshot
    public var closing: SabbaticalSnapshot
    public var started: [String]
    public var shipped: [String]
    public var hired: [String]
    public var lost: [String]
    public var log: [SabbaticalLogEntry]

    public init(
        caretakerID: UUID,
        caretakerName: String,
        sinceDay: Int,
        endedDay: Int,
        weeks: Int,
        endedEarly: Bool,
        earlyReason: String?,
        cost: Int,
        opening: SabbaticalSnapshot,
        closing: SabbaticalSnapshot,
        started: [String],
        shipped: [String],
        hired: [String],
        lost: [String],
        log: [SabbaticalLogEntry]
    ) {
        self.caretakerID = caretakerID
        self.caretakerName = caretakerName
        self.sinceDay = sinceDay
        self.endedDay = endedDay
        self.weeks = weeks
        self.endedEarly = endedEarly
        self.earlyReason = earlyReason
        self.cost = cost
        self.opening = opening
        self.closing = closing
        self.started = started
        self.shipped = shipped
        self.hired = hired
        self.lost = lost
        self.log = log
    }

    /// Days actually away.
    public var days: Int { max(0, endedDay - sinceDay) }

    /// The one line the card and the biography lead with.
    public var headline: String {
        if !shipped.isEmpty { return "\(caretakerName) shipped \(shipped[0])." }
        if !lost.isEmpty { return "You came back to an empty chair." }
        if !started.isEmpty { return "\(caretakerName) started \(started[0])." }
        if closing.cash < opening.cash { return "\(caretakerName) held it together." }
        return "Nothing broke."
    }
}

/// The founder away with the company in somebody else's hands.
///
/// `nil` on `LifeState` until the founder takes their first sabbatical, and
/// non-`nil` for the rest of the run afterwards: the slot holds the trip
/// that is running, or the last one that ran (`endedDay` set, `report`
/// filled). Nothing here is read by any system while `endedDay != nil`, so
/// a finished sabbatical is a memory and not a modifier.
public struct SabbaticalState: Codable, Equatable, Sendable {
    public var caretakerID: UUID
    public var caretakerName: String
    public var sinceDay: Int
    public var untilDay: Int
    /// Weeks the founder booked.
    public var weeks: Int
    /// Wallet money charged per week, pinned at departure so a balance
    /// change mid-trip cannot re-price a holiday already paid for.
    public var weeklyCost: Int
    public var opening: SabbaticalSnapshot
    public var log: [SabbaticalLogEntry]
    public var started: [String]
    public var shipped: [String]
    public var hired: [String]
    public var lost: [String]
    /// The last day the caretaker made a call — one a week, at most.
    public var lastDecisionDay: Int
    /// `nil` while the founder is away.
    public var endedDay: Int?
    public var report: SabbaticalReport?

    public init(
        caretakerID: UUID,
        caretakerName: String = "",
        sinceDay: Int,
        untilDay: Int,
        weeks: Int = 0,
        weeklyCost: Int = 0,
        opening: SabbaticalSnapshot = SabbaticalSnapshot(
            cash: 0, reputation: 0, headcount: 0, morale: 0, live: 0
        ),
        log: [SabbaticalLogEntry] = [],
        started: [String] = [],
        shipped: [String] = [],
        hired: [String] = [],
        lost: [String] = [],
        lastDecisionDay: Int = 0,
        endedDay: Int? = nil,
        report: SabbaticalReport? = nil
    ) {
        self.caretakerID = caretakerID
        self.caretakerName = caretakerName
        self.sinceDay = sinceDay
        self.untilDay = untilDay
        self.weeks = weeks
        self.weeklyCost = weeklyCost
        self.opening = opening
        self.log = log
        self.started = started
        self.shipped = shipped
        self.hired = hired
        self.lost = lost
        self.lastDecisionDay = lastDecisionDay
        self.endedDay = endedDay
        self.report = report
    }

    /// The founder is away *now*.
    public var isActive: Bool { endedDay == nil }

    /// Days left, from `day`.
    public func daysLeft(from day: Int) -> Int { max(0, untilDay - day) }

    /// Total wallet cost of the booked trip.
    public var totalCost: Int { weeks * weeklyCost }

    /// Appends a line to the caretaker's log, keeping the ordinals honest.
    mutating func note(_ text: String, day: Int, isDecision: Bool) {
        log.append(SabbaticalLogEntry(
            ordinal: log.count, day: day, text: text, isDecision: isDecision
        ))
    }

    // Every field but the scaffold's three decodes if present, so a save
    // written against an earlier shape (or none at all) loads.
    private enum CodingKeys: String, CodingKey {
        case caretakerID, caretakerName, sinceDay, untilDay, weeks, weeklyCost
        case opening, log, started, shipped, hired, lost
        case lastDecisionDay, endedDay, report
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            caretakerID: try container.decode(UUID.self, forKey: .caretakerID),
            caretakerName: try container.decodeIfPresent(String.self, forKey: .caretakerName) ?? "",
            sinceDay: try container.decode(Int.self, forKey: .sinceDay),
            untilDay: try container.decode(Int.self, forKey: .untilDay),
            weeks: try container.decodeIfPresent(Int.self, forKey: .weeks) ?? 0,
            weeklyCost: try container.decodeIfPresent(Int.self, forKey: .weeklyCost) ?? 0,
            opening: try container.decodeIfPresent(SabbaticalSnapshot.self, forKey: .opening)
                ?? SabbaticalSnapshot(cash: 0, reputation: 0, headcount: 0, morale: 0, live: 0),
            log: try container.decodeIfPresent([SabbaticalLogEntry].self, forKey: .log) ?? [],
            started: try container.decodeIfPresent([String].self, forKey: .started) ?? [],
            shipped: try container.decodeIfPresent([String].self, forKey: .shipped) ?? [],
            hired: try container.decodeIfPresent([String].self, forKey: .hired) ?? [],
            lost: try container.decodeIfPresent([String].self, forKey: .lost) ?? [],
            lastDecisionDay: try container.decodeIfPresent(Int.self, forKey: .lastDecisionDay) ?? 0,
            endedDay: try container.decodeIfPresent(Int.self, forKey: .endedDay),
            report: try container.decodeIfPresent(SabbaticalReport.self, forKey: .report)
        )
    }
}

// MARK: - What being away does to the rest of the game

/// The two dials the sabbatical turns outside its own system, read from
/// `InvestorSystem` and `RivalSystem`. Both are exactly 1× whenever the
/// founder is at their desk, which is every run that never takes one.
public enum SabbaticalEffects {
    /// Whether a sabbatical is running right now.
    public static func isOnSabbatical(_ state: GameState) -> Bool {
        state.life.sabbatical?.isActive == true
    }

    /// The board's patience, in weeks, as the quarterly review should read
    /// it: a fund that gave the founder six months gives the caretaker
    /// half that. `weeks` unchanged when nobody is away.
    public static func boardPatienceWeeks(
        _ weeks: Int, state: GameState, balance: BalanceConfig
    ) -> Int {
        guard isOnSabbatical(state) else { return weeks }
        return max(1, Int((Double(weeks) * balance.sabbatical.boardPatienceFactor).rounded()))
    }

    /// The multiplier on a rival's poach odds. Recruiters read the trade
    /// press too, and they know who is not in the building.
    public static func poachChanceFactor(_ state: GameState, balance: BalanceConfig) -> Double {
        isOnSabbatical(state) ? balance.sabbatical.poachChanceFactor : 1
    }
}

// MARK: - Queries the Life tab asks

extension GameState {
    /// Whether this run is on a sabbatical today.
    public var isOnSabbatical: Bool { SabbaticalEffects.isOnSabbatical(self) }

    /// Everybody who could be handed the company, best first (bond, then
    /// tenure). Includes people who do not clear the gates yet — the card
    /// shows them greyed with the reason, which is the only way a player
    /// learns that a caretaker is something you build toward.
    public func sabbaticalCandidates(balance: BalanceConfig) -> [Employee] {
        employees
            .filter { !$0.isFounder }
            .sorted { lhs, rhs in
                if lhs.founderBond != rhs.founderBond { return lhs.founderBond > rhs.founderBond }
                if lhs.hiredDay != rhs.hiredDay { return lhs.hiredDay < rhs.hiredDay }
                return lhs.id.uuidString < rhs.id.uuidString
            }
    }

    /// Weeks of tenure an employee has, in the company's own weeks.
    public func tenureWeeks(_ employee: Employee) -> Int {
        max(0, (day - employee.hiredDay) / GameState.daysPerWeek)
    }

    /// Why this person cannot mind the shop, in the player's words, or
    /// `nil` when they can. The card's disabled rows read this rather than
    /// re-deriving the gates in SwiftUI.
    public func caretakerBlocker(
        _ employee: Employee, balance: BalanceConfig
    ) -> String? {
        let config = balance.sabbatical
        if employee.isFounder { return "That's you" }
        let tenure = tenureWeeks(employee)
        if tenure < config.minTenureWeeks {
            return "\(tenure)/\(config.minTenureWeeks) weeks here"
        }
        if employee.founderBond < config.minBond {
            return "Bond \(Int(employee.founderBond))/\(Int(config.minBond)) — they barely know you"
        }
        return nil
    }

    /// Why the founder cannot leave at all, whoever they hand it to, or
    /// `nil`. Reasons the caretaker is wrong belong to `caretakerBlocker`.
    public func sabbaticalBlocker(
        weeks: Int, balance: BalanceConfig, content: ContentCatalog
    ) -> String? {
        let config = balance.sabbatical
        if let sabbatical = life.sabbatical, sabbatical.isActive { return "You're already away" }
        if life.isAway(day: day) { return "You're already signed off" }
        if gameOver != nil { return "The company is finished" }
        if weeks < config.minWeeks || weeks > config.maxWeeks {
            return "\(config.minWeeks)–\(config.maxWeeks) weeks"
        }
        if employees.count(where: { !$0.isFounder }) < config.minHeadcount {
            return "Somebody has to be here — \(config.minHeadcount) on the team"
        }
        // A launch inside the fortnight keeps the founder home — unless
        // the build is already finished, in which case the answer is
        // "ship it, then go", and the button says so.
        if let eta = shipETAs(balance: balance, content: content)
            .first(where: { $0.daysAway <= config.shipLockoutDays && !$0.isReady }) {
            return "\(eta.productName) lands in \(eta.daysAway) day\(eta.daysAway == 1 ? "" : "s")"
        }
        let cost = weeks * config.weeklyCost
        if life.wallet < cost {
            return "Need $\(cost - life.wallet) more in your wallet"
        }
        return nil
    }
}
