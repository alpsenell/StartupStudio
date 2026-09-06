import Foundation

// Iteration 9 — L2 owns this file.

/// The founder's life, graded 0...100 as a pure function of the state:
/// the second number next to net worth.
///
/// The game has always been able to say what the *company* was worth. It
/// has never had a word for whether the person came out of it. This is
/// that word, and it is deliberately a display number: no system reads
/// it, nothing balances on it, and a run that never opens the Life tab
/// ticks exactly as it did before. The one place it bites is the gate on
/// the *Walked away* ending, which the founder has to press themselves.
///
/// Six components and one penalty, each with a maximum, so the breakdown
/// can be drawn as bars and the screen can say the one true sentence a
/// score needs: *this is the thing that would raise it most*.
public enum LifeScore {
    /// One line of the breakdown: a label, what it earned, what it was
    /// out of, and the sentence under the bar.
    public struct Component: Equatable, Sendable, Identifiable {
        /// Stable across redraws and localisation; the UI keys on it.
        public let id: String
        public let label: String
        /// Points earned. Negative on the penalty line.
        public let points: Double
        /// Points available. Zero on the penalty line — there is nothing
        /// to earn there, only something to lose.
        public let max: Double
        /// One line of fact, with its number.
        public let detail: String
        /// What would raise this component, or `nil` when it is full (or
        /// when it is the penalty, which is not advice).
        public let advice: String?

        public init(
            id: String, label: String, points: Double, max: Double,
            detail: String, advice: String? = nil
        ) {
            self.id = id
            self.label = label
            self.points = points
            self.max = max
            self.detail = detail
            self.advice = advice
        }

        /// 0...1, for a bar. The penalty has no bar of its own.
        public var fraction: Double {
            max > 0 ? min(1, Swift.max(0, points / max)) : 0
        }

        /// Points still on the table here.
        public var headroom: Double { Swift.max(0, max - points) }
    }

    // MARK: - The number

    /// The founder's life, 0...100.
    public static func score(_ state: GameState, balance: BalanceConfig) -> Int {
        let total = breakdown(state: state, balance: balance).reduce(0) { $0 + $1.points }
        return Int(min(100, Swift.max(0, total)).rounded())
    }

    /// Every component, in the order the screen draws them, with the
    /// penalty last.
    public static func breakdown(state: GameState, balance: BalanceConfig) -> [Component] {
        let config = balance.lifeScore
        return [
            partner(state, config),
            children(state, config),
            body(state, config),
            friends(state, config),
            evenings(state, config),
            home(state, config),
            penalty(state, config),
        ]
    }

    /// The component with the most points still on the table, ignoring
    /// the penalty and anything already full. `nil` when the life is as
    /// good as this founder's circumstances allow.
    public static func biggestGap(
        state: GameState, balance: BalanceConfig
    ) -> Component? {
        breakdown(state: state, balance: balance)
            .filter { $0.max > 0 && $0.headroom > 0.5 && $0.advice != nil }
            .max { lhs, rhs in
                if lhs.headroom != rhs.headroom { return lhs.headroom < rhs.headroom }
                return lhs.id > rhs.id
            }
    }

    // MARK: - Partner

    private static func partner(
        _ state: GameState, _ config: BalanceConfig.LifeScoreBalance
    ) -> Component {
        let family = state.life.family
        let weight = config.partnerStageWeight[family.stage.rawValue] ?? 0
        let affection = min(100, Swift.max(0, family.affection)) / 100
        let points = config.partnerMax * weight * affection
        let name = family.partnerName ?? "them"
        let detail: String
        switch family.stage {
        case .single:
            detail = family.children.isEmpty
                ? "Nobody at home."
                : "Nobody at home. The kids are the whole of it."
        case .dating, .partner, .married:
            detail = "\(name) · affection \(Int(family.affection.rounded()))"
        }
        let advice: String? = switch family.stage {
        case .single: "Somebody in the address book is worth an evening."
        default: affection >= 0.98 && weight >= 1
            ? nil
            : (weight < 1
                ? "Ask \(name). The ladder is worth more than the number on it."
                : "An evening with \(name) is worth more than any of them.")
        }
        return Component(
            id: "partner", label: "Partner", points: points, max: config.partnerMax,
            detail: detail, advice: advice
        )
    }

    // MARK: - Children

    private static func children(
        _ state: GameState, _ config: BalanceConfig.LifeScoreBalance
    ) -> Component {
        let kids = state.life.family.children
        let count = kids.count
        let target = Swift.max(1, config.childrenForFullMarks)
        let countFactor = min(1, Double(count) / Double(target))
        // The bond proxy until L3's real bond lands: how long ago the
        // last dated family beat went unanswered. A missed birthday hurts
        // and then, slowly, stops hurting.
        let proxy = keptDaysFactor(state, config)
        let points = config.childrenMax * countFactor * proxy
        let detail: String
        if count == 0 {
            detail = "No children."
        } else if let missed = lastMissedFamilyDay(state) {
            let ago = Swift.max(0, state.day - missed)
            detail = "\(count) \(count == 1 ? "child" : "children") · last missed day \(ago) day"
                + (ago == 1 ? "" : "s") + " ago"
        } else {
            detail = "\(count) \(count == 1 ? "child" : "children") · every day kept"
        }
        let advice: String? = count == 0
            ? nil  // Having a child to raise a number is not advice this game gives.
            : (proxy >= 0.99 ? nil : "Keep the next date in the diary.")
        return Component(
            id: "children", label: "Children", points: points, max: config.childrenMax,
            detail: detail, advice: advice
        )
    }

    /// The day of the most recent unanswered family date, if there is one
    /// in the journal.
    static func lastMissedFamilyDay(_ state: GameState) -> Int? {
        state.eventLog.compactMap { event -> Int? in
            if case .familyDateMissed(_, let day) = event { return day }
            return nil
        }.max()
    }

    /// 1 when no family date was ever missed, `missedDateFloor` on the day
    /// one is, climbing back linearly over `missedDateRecoveryDays`.
    private static func keptDaysFactor(
        _ state: GameState, _ config: BalanceConfig.LifeScoreBalance
    ) -> Double {
        guard let missed = lastMissedFamilyDay(state) else { return 1 }
        let recovery = Double(Swift.max(1, config.missedDateRecoveryDays))
        let elapsed = Double(Swift.max(0, state.day - missed))
        let healed = min(1, elapsed / recovery)
        return config.missedDateFloor + (1 - config.missedDateFloor) * healed
    }

    // MARK: - Health and energy

    private static func body(
        _ state: GameState, _ config: BalanceConfig.LifeScoreBalance
    ) -> Component {
        let meters = state.life.meters
        let share = min(1, Swift.max(0, config.healthShare))
        let blended = (meters.health * share + meters.energy * (1 - share)) / 100
        let points = config.bodyMax * min(1, Swift.max(0, blended))
        let detail = "Health \(Int(meters.health.rounded())) · energy \(Int(meters.energy.rounded()))"
        let advice: String? = blended >= 0.95
            ? nil
            : (meters.health < meters.energy
                ? "A weekend at the gym or the doctor's."
                : "Sleep. The schedule is the lever.")
        return Component(
            id: "body", label: "Health and energy", points: points, max: config.bodyMax,
            detail: detail, advice: advice
        )
    }

    // MARK: - Friends

    private static func friends(
        _ state: GameState, _ config: BalanceConfig.LifeScoreBalance
    ) -> Component {
        let list = state.life.friends.friends
        let sum = list.reduce(0) { $0 + Swift.max(0, $1.bond) }
        let target = Swift.max(1, config.friendsBondForFullMarks)
        let points = config.friendsMax * min(1, sum / target)
        let detail = list.isEmpty
            ? "Nobody from before the company."
            : "\(list.count) friend\(list.count == 1 ? "" : "s") · bond \(Int(sum.rounded()))"
        let advice: String? = list.isEmpty
            ? nil  // There is nothing to tap yet; L4 gives this line teeth.
            : (points >= config.friendsMax - 0.5 ? nil : "Call the one you have seen least.")
        return Component(
            id: "friends", label: "Friends", points: points, max: config.friendsMax,
            detail: detail, advice: advice
        )
    }

    // MARK: - Evenings on people

    /// The day an event in the journal was an evening the founder gave to
    /// a *person*, or `nil` when it was not one. Training, the gym and the
    /// cinema are evenings too — they are just not evenings spent on
    /// anybody.
    ///
    /// The journal keeps the last `GameState.maxEventLogEntries` events,
    /// so on a busy year the window is really "as far back as the log
    /// reaches". That is fine for a display number with a low bar for
    /// full marks, and it is the only record of *who* an evening went to.
    static func eveningOnPeopleDay(_ event: GameEvent) -> Int? {
        switch event {
        case .partnerTime(_, _, let day): day
        case .hungOutWith(_, let day): day
        case .employeeMentored(_, _, let day): day
        case .weekendSpent(let activity, let day):
            activity == .dateNight || activity == .friends || activity == .familyTime ? day : nil
        default: nil
        }
    }

    /// How many of those there were inside the window.
    public static func eveningsOnPeople(
        _ state: GameState, balance: BalanceConfig
    ) -> Int {
        let since = state.day - Swift.max(1, balance.lifeScore.eveningsWindowDays)
        return state.eventLog.count { (eveningOnPeopleDay($0) ?? Int.min) > since }
    }

    private static func evenings(
        _ state: GameState, _ config: BalanceConfig.LifeScoreBalance
    ) -> Component {
        let since = state.day - Swift.max(1, config.eveningsWindowDays)
        let count = state.eventLog.count { (eveningOnPeopleDay($0) ?? Int.min) > since }
        let target = Swift.max(1, config.eveningsForFullMarks)
        let points = config.eveningsMax * min(1, Double(count) / Double(target))
        let detail = "\(count) evening\(count == 1 ? "" : "s") on somebody this year"
        let advice: String? = count >= target
            ? nil
            : "Nights out, date nights and the family weekend all count."
        return Component(
            id: "evenings", label: "Evenings on people", points: points, max: config.eveningsMax,
            detail: detail, advice: advice
        )
    }

    // MARK: - Home

    private static func home(
        _ state: GameState, _ config: BalanceConfig.LifeScoreBalance
    ) -> Component {
        let ladder = HomeTier.allCases
        let rank = Double(ladder.firstIndex(of: state.life.home) ?? 0)
        let top = Double(Swift.max(1, ladder.count - 1))
        let points = config.homeMax * (rank / top)
        let detail = "A \(state.life.home.displayName.lowercased())."
        let advice: String? = state.life.home.next == nil
            ? nil
            : "The wallet buys the next place up."
        return Component(
            id: "home", label: "Home", points: points, max: config.homeMax,
            detail: detail, advice: advice
        )
    }

    // MARK: - What it cost

    private static func penalty(
        _ state: GameState, _ config: BalanceConfig.LifeScoreBalance
    ) -> Component {
        let burnouts = state.economy.burnoutDays.count
        let stays = state.economy.hospitalizationDays.count
        let chronic = state.economy.chronicCondition
        var off = Double(burnouts) * config.burnoutPenalty
            + Double(stays) * config.hospitalPenalty
        if chronic { off += config.chronicPenalty }
        off = min(off, Swift.max(0, config.penaltyCap))

        var parts: [String] = []
        if burnouts > 0 { parts.append("\(burnouts) burnout\(burnouts == 1 ? "" : "s")") }
        if stays > 0 { parts.append("\(stays) hospital stay\(stays == 1 ? "" : "s")") }
        if chronic { parts.append("a chronic condition") }
        let detail = parts.isEmpty
            ? "Nothing broke this year."
            : parts.joined(separator: " · ")
        return Component(
            id: "cost", label: "What it cost", points: -off, max: 0, detail: detail
        )
    }
}

// MARK: - Walked away

extension GameState {
    /// Whether the founder can hand the company over and go, today.
    /// Gated exactly as `walkAwayBlocker` reports, so the button can
    /// explain a refusal before it is pressed.
    public func canWalkAway(balance: BalanceConfig) -> Bool {
        walkAwayBlocker(balance: balance) == nil
    }

    /// Why the founder cannot walk away yet, in one line, or `nil` when
    /// they can. Ordered by what the player can do least about first: the
    /// clock, then the company's debts, then the room, then the life.
    public func walkAwayBlocker(balance: BalanceConfig) -> String? {
        let config = balance.lifeScore
        if gameOver != nil { return "This company already had its ending." }
        if let epilogue { return "This company had its ending on day \(epilogue.day)." }
        if day < config.walkAwayMinDay {
            let years = Swift.max(1, config.walkAwayMinDay / Self.daysPerYear)
            return "Too soon. Walking out before \(years) year"
                + (years == 1 ? "" : "s") + " in is quitting, not leaving."
        }
        if company.cash < 0 || loanBalance > 0 {
            return loanBalance > 0
                ? "\(loanBalance.dollars) of debt outstanding. You do not hand somebody that."
                : "The company is overdrawn. You do not hand somebody that."
        }
        if investors.hasBoard {
            return "There is still a board in the room. Buy them out, or they decide this."
        }
        if headcount <= 1 {
            return "There is nobody to hand it to."
        }
        let netWorth = founderNetWorth(balance: balance)
        if netWorth < config.walkAwayMinNetWorth {
            return "\(netWorth.dollars) behind you. Leaving on that is not leaving, it is running out."
        }
        let life = LifeScore.score(self, balance: balance)
        if life < config.walkAwayMinLifeScore {
            return "Life \(life). You would be walking away from the company into nothing —"
                + " \(config.walkAwayMinLifeScore) is the line."
        }
        return nil
    }
}

extension LifeScore {
    /// The founder steps down on purpose, with both numbers good: the
    /// seventh ending, and the only one the founder chooses while nothing
    /// is going wrong.
    ///
    /// Nothing is sold and nobody is bought out — the company carries on
    /// without them, which is the point. Unlike *Public* and *Still
    /// yours*, this one cannot be played past (`Reducer.continueAfterEnding`
    /// takes those two only): the founder is not there any more, and a
    /// *Keep running it* button under this headline would be the screen
    /// arguing with itself.
    static func walkAway(state: inout GameState, balance: BalanceConfig) -> [GameEvent] {
        guard state.canWalkAway(balance: balance) else { return [] }
        let life = score(state, balance: balance)
        let netWorth = state.founderNetWorth(balance: balance)
        let years = state.day / GameState.daysPerYear
        let staff = Swift.max(0, state.headcount - 1)
        let successor = state.employees
            .filter { !$0.isFounder }
            .min { lhs, rhs in
                if lhs.hiredDay != rhs.hiredDay { return lhs.hiredDay < rhs.hiredDay }
                return lhs.id.uuidString < rhs.id.uuidString
            }

        state.ledger.post(LedgerEntry(
            day: state.day, amount: 0, category: .other, label: "Walked away"
        ))
        let yearWord: String = years == 1 ? "year" : "years"
        let peopleWord: String = staff == 1 ? "person" : "people"
        let keys: String = successor.map { ", \($0.name) holding the keys" } ?? ""
        var reason = "You left \(state.company.name) standing after \(years) \(yearWord), "
        reason += "\(staff) \(peopleWord) on payroll\(keys). "
        reason += "\(netWorth.dollars) behind you and a life at \(life). Nobody made you."
        state.gameOver = GameOverInfo(day: state.day, reason: reason, kind: .walkedAway)
        // No new `GameEvent` case: the ending's kind is what the feed, the
        // biography and Game Center all read, and a seventh case would
        // mean editing the shared severity switch outside L2's markers.
        return [.gameOver(day: state.day)]
    }
}
