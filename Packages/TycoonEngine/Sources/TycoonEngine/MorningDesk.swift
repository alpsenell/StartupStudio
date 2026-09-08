import Foundation

// Iteration 10 — M5 owns this file and may reshape it freely. The one-
// minute daily ritual: today's desk cards, derived from the run, and the
// per-run record of which days were answered. The streak across runs and
// its rewards live in the ledger (M5's markers in `Legacy.swift`).
//
// Two clocks meet here and it matters which is which. Everything else in
// the game runs on `state.day`, the simulation's own day count; the desk
// runs on the *player's* calendar, a `yyyymmdd` stamp the app hands in
// with every action. The engine never reads a wall clock — it is given
// the day — so a desk action stays as deterministic and replayable as
// every other action, and the desk never advances the simulation.

// MARK: - The three cards

/// The three things a morning asks for: one message to answer, one
/// decision to make, one tap. Clearing all three marks the day.
public enum DeskPart: String, Codable, Equatable, Hashable, Sendable, CaseIterable {
    /// The newest thread on the phone that is waiting on the founder.
    case message
    /// The most urgent thing on the Business tab's desk.
    case decision
    /// Praise somebody, buy a coffee, water the plant.
    case tap

    /// The heading on the paper.
    public var title: String {
        switch self {
        case .message: "One message"
        case .decision: "One decision"
        case .tap: "One tap"
        }
    }

    /// The order the papers lie in.
    public var order: Int {
        switch self {
        case .message: 0
        case .decision: 1
        case .tap: 2
        }
    }
}

// MARK: - What the run remembers

/// The desk's own record inside a run: which wall-clock days were cleared
/// here, and how far today has got.
///
/// Every field decodes as its default when absent and encodes only when
/// it is not, so a save from before the desk existed loads unchanged and
/// a run that never opens the desk writes no bytes for it.
public struct DeskState: Codable, Equatable, Sendable {
    /// Wall-clock days (yyyymmdd) on which the desk was cleared, oldest
    /// first. Capped: a decade of mornings is not worth carrying.
    public var clearedDays: [Int]
    /// The wall-clock day `doneParts` belongs to; 0 when nothing is in
    /// progress.
    public var progressDay: Int
    /// The parts already done on `progressDay`.
    public var doneParts: [DeskPart]

    /// How many cleared days a save keeps.
    public static let historyLimit = 200

    public init(clearedDays: [Int] = [], progressDay: Int = 0, doneParts: [DeskPart] = []) {
        self.clearedDays = clearedDays
        self.progressDay = progressDay
        self.doneParts = doneParts
    }

    public static let empty = DeskState()

    // MARK: Reading

    /// Whether `part` has been done today.
    public func isDone(_ part: DeskPart, on today: Int) -> Bool {
        isCleared(on: today) || (progressDay == today && doneParts.contains(part))
    }

    /// Whether all three were done today.
    public func isCleared(on today: Int) -> Bool { clearedDays.contains(today) }

    /// The parts done today, in the papers' own order.
    public func done(on today: Int) -> [DeskPart] {
        DeskPart.allCases.filter { isDone($0, on: today) }
    }

    /// The parts still open today.
    public func remaining(on today: Int) -> [DeskPart] {
        DeskPart.allCases.filter { !isDone($0, on: today) }
    }

    // MARK: Writing

    /// Records `part` as done on `today`. Returns true when that was the
    /// third paper and the day is now cleared — the one moment the ledger
    /// wants to hear about.
    ///
    /// Starting a new day drops yesterday's half-finished progress: the
    /// desk is today's, and a day left unfinished is a day missed.
    @discardableResult
    public mutating func mark(_ part: DeskPart, on today: Int) -> Bool {
        guard today > 0, !isCleared(on: today) else { return false }
        if progressDay != today {
            progressDay = today
            doneParts = []
        }
        if !doneParts.contains(part) { doneParts.append(part) }
        guard DeskPart.allCases.allSatisfy({ doneParts.contains($0) }) else { return false }
        clearedDays.append(today)
        let overflow = clearedDays.count - Self.historyLimit
        if overflow > 0 { clearedDays.removeFirst(overflow) }
        progressDay = 0
        doneParts = []
        return true
    }

    // MARK: Codable

    private enum CodingKeys: String, CodingKey {
        case clearedDays, progressDay, doneParts
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        clearedDays = try container.decodeIfPresent([Int].self, forKey: .clearedDays) ?? []
        progressDay = try container.decodeIfPresent(Int.self, forKey: .progressDay) ?? 0
        doneParts = try container.decodeIfPresent([DeskPart].self, forKey: .doneParts) ?? []
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if !clearedDays.isEmpty { try container.encode(clearedDays, forKey: .clearedDays) }
        if progressDay != 0 { try container.encode(progressDay, forKey: .progressDay) }
        if !doneParts.isEmpty { try container.encode(doneParts, forKey: .doneParts) }
    }
}

// MARK: - The player's calendar

/// `yyyymmdd` arithmetic, in the player's own calendar. The desk is the
/// one part of the game that lives on the phone's calendar rather than
/// the simulation's, and this is the whole of that dependency: the app
/// asks for today, hands the number in, and everything downstream is a
/// pure function of integers.
public enum DeskDay {
    /// Today as `yyyymmdd`, in the given calendar (the player's own by
    /// default — a morning is a local thing).
    public static func stamp(for date: Date = Date(), calendar: Calendar = .current) -> Int {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        guard let year = parts.year, let month = parts.month, let day = parts.day else { return 0 }
        return year * 10_000 + month * 100 + day
    }

    /// The month a stamp is in, as `yyyymm` — the unit the free sick day
    /// is rationed by.
    public static func month(_ stamp: Int) -> Int { stamp / 100 }

    /// The hour of `date`, for the reminder the player opts into.
    public static func hour(for date: Date = Date(), calendar: Calendar = .current) -> Int {
        calendar.component(.hour, from: date)
    }

    /// Whole days from one stamp to another, or `nil` if either is not a
    /// date. Counted in a fixed UTC gregorian calendar so the arithmetic
    /// is the same everywhere; the stamps themselves were made locally,
    /// which is the part that has to match the player's idea of a day.
    public static func days(from earlier: Int, to later: Int) -> Int? {
        guard let a = date(earlier), let b = date(later) else { return nil }
        return Int((b.timeIntervalSince(a) / 86_400).rounded())
    }

    /// The stamp `days` after `stamp`.
    public static func stamp(_ stamp: Int, plus days: Int) -> Int {
        guard let start = date(stamp),
              let moved = utc.date(byAdding: .day, value: days, to: start)
        else { return stamp }
        let parts = utc.dateComponents([.year, .month, .day], from: moved)
        guard let year = parts.year, let month = parts.month, let day = parts.day else { return stamp }
        return year * 10_000 + month * 100 + day
    }

    private static let utc: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    private static func date(_ stamp: Int) -> Date? {
        guard stamp > 0 else { return nil }
        var components = DateComponents()
        components.year = stamp / 10_000
        components.month = (stamp / 100) % 100
        components.day = stamp % 100
        return utc.date(from: components)
    }
}

// MARK: - The streak

/// Where a cleared day left the streak, so the app can say what changed
/// without diffing the ledger itself.
public struct DeskStreakChange: Equatable, Sendable {
    /// The streak before this morning.
    public var before: Int
    /// The streak after it.
    public var after: Int
    /// Whether the free monthly sick day covered a gap of one.
    public var usedSickDay: Bool
    /// Rewards this morning crossed. Empty on every ordinary day.
    public var rewards: [DeskReward]

    public init(before: Int, after: Int, usedSickDay: Bool, rewards: [DeskReward]) {
        self.before = before
        self.after = after
        self.usedSickDay = usedSickDay
        self.rewards = rewards
    }

    /// Nothing happened — the day was already counted.
    public static let none = DeskStreakChange(before: 0, after: 0, usedSickDay: false, rewards: [])

    public var isNewRecord: Bool { after > before && after >= 2 }
}

/// What a streak length is worth. Never a stat: a thing for the wall, a
/// face to found with, a flourish on the front door.
public enum DeskRewardKind: Equatable, Sendable {
    /// A decor id from `HomeDecor`'s M5 region, earned into the ledger.
    case decor(String)
    /// An appearance seed the new-game flow appends to the founder looks.
    case look(UInt64)
    /// The sunrise under the masthead on the title screen.
    case flourish
}

public struct DeskReward: Equatable, Sendable, Identifiable {
    /// The streak length that earns it.
    public let days: Int
    public let kind: DeskRewardKind
    public let name: String
    /// One line under the name.
    public let note: String

    public var id: Int { days }

    public init(days: Int, kind: DeskRewardKind, name: String, note: String) {
        self.days = days
        self.kind = kind
        self.name = name
        self.note = note
    }
}

/// The reward table. Six rungs, none of them a number in the simulation.
public enum DeskRewards {
    public static let all: [DeskReward] = [
        DeskReward(
            days: 3, kind: .decor("deskSunrise"), name: "Sunrise over the desk",
            note: "A poster for the wall. Three mornings in a row."
        ),
        DeskReward(
            days: 7, kind: .look(0x0DE5_0007_5EED_0A11), name: "The early riser",
            note: "A face for the founder picker. A full week."
        ),
        DeskReward(
            days: 14, kind: .decor("deskPlaque"), name: "The morning plaque",
            note: "Brass, small, on a shelf. A fortnight."
        ),
        DeskReward(
            days: 30, kind: .flourish, name: "The sunrise masthead",
            note: "The front door gets a sunrise under its name. A month."
        ),
        DeskReward(
            days: 60, kind: .look(0x0DE5_0060_5EED_0B22), name: "The regular",
            note: "Another face. Sixty mornings."
        ),
        DeskReward(
            days: 100, kind: .decor("deskCentury"), name: "One hundred mornings",
            note: "The last poster. Nobody has to know what it means."
        ),
    ]

    /// Everything a best streak of `bestStreak` has earned.
    public static func earned(bestStreak: Int) -> [DeskReward] {
        all.filter { $0.days <= bestStreak }
    }

    /// The next rung, and how many mornings away it is.
    public static func next(after streak: Int) -> DeskReward? {
        all.first { $0.days > streak }
    }

    /// The decor ids the table hands out, for `HomeDecor`'s catalog.
    public static var decorIDs: [String] {
        all.compactMap { if case .decor(let id) = $0.kind { id } else { nil } }
    }

    /// The looks, in the order they are earned.
    public static var looks: [(days: Int, seed: UInt64, name: String)] {
        all.compactMap { reward in
            if case .look(let seed) = reward.kind {
                (days: reward.days, seed: seed, name: reward.name)
            } else {
                nil
            }
        }
    }

    /// Whether the masthead flourish has been earned.
    public static func hasFlourish(bestStreak: Int) -> Bool {
        all.contains { $0.kind == .flourish && $0.days <= bestStreak }
    }
}

extension LegacyLedger {
    /// Records a cleared morning and moves the streak.
    ///
    /// The rules, all of them:
    ///
    /// * The first cleared day ever is a streak of one.
    /// * The day after the last one continues it.
    /// * Exactly one missed day is forgiven, once per calendar month —
    ///   the sick day. It continues the streak and spends the month's
    ///   forgiveness.
    /// * Anything longer, or a second gap inside the same month, starts
    ///   again at one.
    /// * A day already counted changes nothing, and a day *earlier* than
    ///   the last one recorded (a clock that went backwards, a device in
    ///   another time zone) is recorded without moving the streak.
    ///
    /// Decor rewards are written into `unlockedDecor` here; looks and the
    /// flourish are derived from `deskBestStreak` and cost no bytes.
    @discardableResult
    public mutating func recordDeskDay(_ today: Int) -> DeskStreakChange {
        guard today > 0, today != deskLastDay else { return .none }
        let before = deskStreak
        var usedSickDay = false
        if deskLastDay <= 0 {
            deskStreak = 1
        } else if let gap = DeskDay.days(from: deskLastDay, to: today) {
            if gap <= 0 {
                // An older day arriving late: kept as the record it is,
                // but the streak is not rewritten backwards.
                return .none
            } else if gap == 1 {
                deskStreak += 1
            } else if gap == 2, deskSickDayMonth != DeskDay.month(today) {
                deskSickDayMonth = DeskDay.month(today)
                deskStreak += 1
                usedSickDay = true
            } else {
                deskStreak = 1
            }
        } else {
            deskStreak = 1
        }
        deskLastDay = today
        let previousBest = deskBestStreak
        deskBestStreak = max(deskBestStreak, deskStreak)
        let rewards = DeskRewards.all.filter { $0.days > previousBest && $0.days <= deskBestStreak }
        for reward in rewards {
            if case .decor(let id) = reward.kind { unlockedDecor.insert(id) }
        }
        return DeskStreakChange(
            before: before, after: deskStreak, usedSickDay: usedSickDay, rewards: rewards
        )
    }

    /// Whether the streak is still alive as of `today` — the same day or
    /// the next one, or the one after with the month's sick day unspent.
    public func deskStreakIsLive(on today: Int) -> Bool {
        guard deskStreak > 0, deskLastDay > 0 else { return false }
        guard let gap = DeskDay.days(from: deskLastDay, to: today) else { return false }
        if gap <= 1 { return true }
        return gap == 2 && deskSickDayMonth != DeskDay.month(today)
    }
}

// MARK: - The one tap

/// The third paper: something small and kind that takes one tap.
public enum DeskTapKind: Equatable, Sendable {
    /// A word with somebody who has not had one lately.
    case praise(employeeID: UUID, name: String)
    /// Coffee with somebody, on the company.
    case coffee(employeeID: UUID, name: String, cost: Int)
    /// Nobody to talk to, or both cooled down: the plant, then.
    case plant
}

/// The tap, ready to draw: what it is, what it says, and the action it
/// sends — `nil` for the plant, which is a kindness and not a move.
public struct DeskTapCard: Equatable, Sendable {
    public let kind: DeskTapKind
    public let title: String
    /// The consequence, on the button, the way every other button says it.
    public let detail: String
    public let action: GameAction?

    public init(kind: DeskTapKind, title: String, detail: String, action: GameAction?) {
        self.kind = kind
        self.title = title
        self.detail = detail
        self.action = action
    }
}

/// The desk's engine-side queries. Pure reads: nothing here advances a
/// clock, spends a day or draws from an RNG.
public enum MorningDesk {
    /// Today's tap.
    ///
    /// Alternates by the day's parity so a week of mornings is not the
    /// same morning seven times: an even day looks for somebody to praise,
    /// an odd day for somebody to have a coffee with, and either falls
    /// through to the other and then to the plant. A solo founder always
    /// gets the plant, which is why the plant exists.
    public static func tap(in state: GameState, balance: BalanceConfig, on today: Int) -> DeskTapCard {
        let preferPraise = today % 2 == 0
        let order: [Bool] = preferPraise ? [true, false] : [false, true]
        for wantsPraise in order {
            if wantsPraise, let target = praiseTarget(in: state, balance: balance) {
                return DeskTapCard(
                    kind: .praise(employeeID: target.id, name: target.name),
                    title: "Say something to \(target.name)",
                    detail: "Morale up. Nobody has said anything for a while.",
                    action: .praise(employeeID: target.id)
                )
            }
            if !wantsPraise, let target = coffeeTarget(in: state, balance: balance) {
                return DeskTapCard(
                    kind: .coffee(
                        employeeID: target.id, name: target.name, cost: balance.social.coffeeCost
                    ),
                    title: "Coffee with \(target.name)",
                    detail: "Morale and loyalty up. The company pays.",
                    action: .grabCoffee(employeeID: target.id)
                )
            }
        }
        return DeskTapCard(
            kind: .plant,
            title: "Water the plant",
            detail: "Nothing happens. It is still worth doing.",
            action: nil
        )
    }

    /// The quietest hired employee who is off the praise cooldown.
    private static func praiseTarget(
        in state: GameState, balance: BalanceConfig
    ) -> (id: UUID, name: String)? {
        let eligible = state.employees.filter { employee in
            guard !employee.isFounder else { return false }
            guard let last = employee.lastPraisedDay else { return true }
            return state.day - last >= balance.staff.praiseCooldownDays
        }
        guard let pick = eligible.min(by: { lhs, rhs in
            lhs.morale == rhs.morale ? lhs.id.uuidString < rhs.id.uuidString : lhs.morale < rhs.morale
        }) else { return nil }
        return (pick.id, pick.name)
    }

    /// Somebody off the social cooldown, when the company can cover the
    /// round.
    private static func coffeeTarget(
        in state: GameState, balance: BalanceConfig
    ) -> (id: UUID, name: String)? {
        guard state.company.cash >= balance.social.coffeeCost else { return nil }
        let eligible = state.employees.filter { employee in
            guard !employee.isFounder else { return false }
            guard let last = employee.lastSocialDay else { return true }
            return state.day - last >= balance.social.socialCooldownDays
        }
        guard let pick = eligible.min(by: { lhs, rhs in
            lhs.loyalty == rhs.loyalty ? lhs.id.uuidString < rhs.id.uuidString : lhs.loyalty < rhs.loyalty
        }) else { return nil }
        return (pick.id, pick.name)
    }
}
