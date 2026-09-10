import Foundation
import TycoonContent

// Iteration 12 — J6. One queue for every question.
//
// The game asks the founder things from a dozen places: a story beat, a
// rival's poach, a term sheet, somebody's notice, a string the family
// office pulled, the partner who found the calendar, a case with a
// hearing on it. Each one used to have its own sheet, its own rule for
// stopping the clock and — for the wave-two rooms — no place on the rail
// at all, so the clock stopped and the question was three screens away.
//
// `QueueBoard` reads every one of them into a single ordered list of
// `QueueEntry`s: what it is, how loud, the last day an answer counts, and
// what happens if nobody answers. It is *derived*, never stored: the save
// carries nothing new, so a run that never meets a question writes the
// bytes it always wrote. The app draws the sheets from it (`DecisionPrompt`)
// and the rail draws the rest (`NoticeRail`).
//
// `QueueCap` is the one rule on top: past two critical stops in a week,
// the next question that *can* wait does — on the rail, with its real
// deadline — instead of stopping the clock a third time. It is applied by
// `GameEngine` on the live clock only; the headless tick, and every bot
// and fixture measured on it, grade the day exactly as before.
//
// `QueueStakes` and the campus rent are the two pacing keys
// (`BalanceConfig+Queue.swift`).

// MARK: - The queue

/// Where a question comes from.
public enum QueueKind: String, Codable, Equatable, Sendable, CaseIterable {
    case story, poach, buyout, challenge, staff, resignation, termSheet
    case dirtyMoneyOffer, dirtyMoneyDemand, confrontation, funeral
    case legalCase, hearing, cancellation
    // Iteration 12 merge — J3's price war, seated in J6's queue.
    case priceWar
    // MARK: K4 (deals and exits)
    /// Iteration 15 — K4 (A4): in the red, the sell-up against the grace
    /// period. Last in the kind order, so no older tie moves.
    case sellUp
    // MARK: end K4
}

/// How the app answers a question: a sheet over whatever tab is open, or a
/// room the rail's button walks the founder into.
public enum QueueSurface: String, Codable, Equatable, Sendable {
    case sheet, room
}

/// One question, in the shape of a `PendingChoice`: what, how loud, by
/// when, and what the deadline says if the founder does not.
public struct QueueEntry: Equatable, Sendable, Identifiable {
    /// Stable for as long as the question is open.
    public var id: String
    public var kind: QueueKind
    /// `.critical` for a question the deadline answers; `.notable` for
    /// one that waits for the founder however long they take.
    public var severity: EventSeverity
    public var title: String
    /// Icon and tint bucket, an `EventCategory` raw value.
    public var category: String
    public var raisedDay: Int?
    /// The last day an answer counts; `nil` when it waits.
    public var respondByDay: Int?
    /// What happens if nobody answers, in a sentence.
    public var defaultLine: String
    public var surface: QueueSurface

    public init(
        id: String,
        kind: QueueKind,
        severity: EventSeverity,
        title: String,
        category: String,
        raisedDay: Int?,
        respondByDay: Int?,
        defaultLine: String,
        surface: QueueSurface
    ) {
        self.id = id
        self.kind = kind
        self.severity = severity
        self.title = title
        self.category = category
        self.raisedDay = raisedDay
        self.respondByDay = respondByDay
        self.defaultLine = defaultLine
        self.surface = surface
    }

    /// Days left on `day`, never below zero; `nil` when it waits.
    public func daysLeft(on day: Int) -> Int? {
        respondByDay.map { max(0, $0 - day) }
    }
}

/// Reads every open question out of the state, in the order they should
/// be answered: the loud ones first, then the soonest deadline, then the
/// oldest, then a fixed order of kinds so two reads always agree.
public enum QueueBoard {
    /// `balance` is only needed for the questions whose deadline is a
    /// balance key (the price war's answer window); the rail passes
    /// none and never lists them, the decision sheet passes it.
    public static func entries(in state: GameState, balance: BalanceConfig? = nil) -> [QueueEntry] {
        var entries: [QueueEntry] = []
        let day = state.day

        // The company's questions, the ones that always had a sheet.
        if let poach = state.rivals.pendingPoach {
            let name = state.employee(id: poach.employeeID)?.name ?? "Somebody"
            let rival = state.rivals.rival(id: poach.rivalID)?.name ?? "A rival"
            entries.append(QueueEntry(
                id: "poach-\(poach.employeeID.uuidString)-\(poach.respondByDay)",
                kind: .poach, severity: .critical,
                title: "\(rival) wants \(name)", category: "team",
                raisedDay: nil, respondByDay: poach.respondByDay,
                defaultLine: "Unanswered, \(name) takes their offer.",
                surface: .sheet
            ))
        }
        if let buyout = state.rivals.pendingBuyout {
            let rival = state.rivals.rival(id: buyout.rivalID)?.name ?? "A rival"
            entries.append(QueueEntry(
                id: "buyout-\(buyout.rivalID.uuidString)-\(buyout.respondByDay)",
                kind: .buyout, severity: .critical,
                title: "\(rival) wants to buy you out", category: "investor",
                raisedDay: nil, respondByDay: buyout.respondByDay,
                defaultLine: "Unanswered, the offer lapses.",
                surface: .sheet
            ))
        }
        if let challenge = state.rivals.pendingChallenge {
            let rival = state.rivals.rival(id: challenge.rivalID)?.name ?? "A rival"
            entries.append(QueueEntry(
                id: "challenge-\(challenge.id)",
                kind: .challenge, severity: .critical,
                title: "\(rival) launched into your category", category: "market",
                raisedDay: nil, respondByDay: challenge.settlesDay,
                defaultLine: "Unanswered, the shelf settles it.",
                surface: .sheet
            ))
        }
        // Iteration 12 merge — J3's price war (I4), inside its answer week.
        if let balance, let rival = RivalMarket.pendingPriceWar(state: state, balance: balance),
           let deadline = RivalMarket.answerDeadline(rival, balance: balance) {
            entries.append(QueueEntry(
                id: "pricewar-\(rival.id.uuidString)-\(deadline)",
                kind: .priceWar, severity: .critical,
                title: "\(rival.name) started a price war", category: "market",
                raisedDay: nil, respondByDay: deadline,
                defaultLine: "Unanswered, you outlast it.",
                surface: .sheet
            ))
        }
        if let staff = state.pendingStaffEvent {
            let name = state.employee(id: staff.employeeID)?.name ?? "Somebody"
            entries.append(QueueEntry(
                id: "staff-\(staff.employeeID.uuidString)-\(staff.respondByDay)",
                kind: .staff, severity: .critical,
                title: "\(name) needs an answer", category: "team",
                raisedDay: nil, respondByDay: staff.respondByDay,
                defaultLine: "Unanswered, the deadline answers for you.",
                surface: .sheet
            ))
        }
        if let resignation = state.economy.pendingResignation {
            entries.append(QueueEntry(
                id: "resignation-\(resignation.employeeID)-\(resignation.sinceDay)",
                kind: .resignation, severity: .critical,
                title: "\(resignation.name) is leaving", category: "team",
                raisedDay: resignation.sinceDay, respondByDay: resignation.respondByDay,
                defaultLine: "Unanswered, they clear their desk.",
                surface: .sheet
            ))
        }
        if let offer = state.investors.pendingOffer {
            entries.append(QueueEntry(
                id: "investment-\(offer.investorID)-\(offer.respondByDay)",
                kind: .termSheet, severity: .critical,
                title: "\(offer.investorName) wants in", category: "investor",
                raisedDay: nil, respondByDay: offer.respondByDay,
                defaultLine: "Unanswered, the term sheet lapses.",
                surface: .sheet
            ))
        }
        if let pending = state.narrative.pendingChoice, !pending.options.isEmpty {
            let auto = pending.options.first { $0.index == pending.autoOptionIndex }?.label
                ?? pending.options.last?.label ?? ""
            entries.append(QueueEntry(
                id: "narrative-\(pending.id)-\(pending.raisedDay)",
                kind: .story, severity: .critical,
                title: pending.title, category: pending.category,
                raisedDay: pending.raisedDay, respondByDay: pending.respondByDay,
                defaultLine: "Unanswered: \u{201C}\(auto)\u{201D}.",
                surface: .sheet
            ))
        }

        // Wave two's questions, which never had a place on the rail.
        let money = state.dirtyMoney
        if money.hasOffer(on: day), let by = money.offerRespondByDay {
            entries.append(QueueEntry(
                id: "dirtyoffer-\(money.offeredBacker ?? "")-\(by)",
                kind: .dirtyMoneyOffer, severity: .critical,
                title: "\(money.offeredKind?.displayName ?? "Somebody") has a cheque for you",
                category: "money",
                raisedDay: nil, respondByDay: by,
                defaultLine: "Unanswered, the cheque goes back in the drawer.",
                surface: .room
            ))
        }
        if let demand = money.openDemand {
            entries.append(QueueEntry(
                id: "demand-\(demand.id)",
                kind: .dirtyMoneyDemand, severity: .critical,
                title: demand.kind.title, category: "money",
                raisedDay: demand.raisedDay, respondByDay: demand.dueDay,
                defaultLine: "Unanswered, the deadline refuses for you.",
                surface: .sheet
            ))
        }
        let drama = state.familyDrama
        if drama.isConfrontationOpen {
            entries.append(QueueEntry(
                id: "confrontation-\(drama.confrontedDay ?? 0)",
                kind: .confrontation, severity: .notable,
                title: "Your partner knows", category: "family",
                raisedDay: drama.confrontedDay, respondByDay: nil,
                defaultLine: "They wait up for you.",
                surface: .sheet
            ))
        }
        if drama.isFuneralOpen {
            entries.append(QueueEntry(
                id: "funeral-\(drama.funeralDay ?? 0)",
                kind: .funeral, severity: .notable,
                title: "The funeral", category: "family",
                raisedDay: drama.funeralDay, respondByDay: nil,
                defaultLine: "The family waits to hear from you.",
                surface: .room
            ))
        }
        if let hearing = state.crime.hearing {
            entries.append(QueueEntry(
                id: "hearing-\(hearing.caseID)",
                kind: .hearing, severity: .critical,
                title: "The court is sitting", category: "legal",
                raisedDay: hearing.openedDay, respondByDay: nil,
                defaultLine: "The bench waits for your next line.",
                surface: .room
            ))
        } else if let legalCase = state.crime.pendingCase {
            let due = day >= legalCase.hearingDay
            let charge = legalCase.offence?.chargeName ?? "the matter"
            entries.append(QueueEntry(
                id: "case-\(legalCase.id)",
                kind: due ? .hearing : .legalCase, severity: .critical,
                title: due
                    ? "The hearing on \(charge) is today"
                    : (legalCase.isFounderSuing ? "Your suit has a date" : "A case: \(charge)"),
                category: "legal",
                raisedDay: legalCase.raisedDay, respondByDay: legalCase.hearingDay,
                defaultLine: "On the day, the court hears whatever you have ready.",
                surface: .room
            ))
        }
        if let cancellation = state.fame.cancellation, cancellation.response == nil {
            entries.append(QueueEntry(
                id: "cancellation-\(cancellation.raisedDay)",
                kind: .cancellation, severity: .notable,
                title: "An old post has surfaced", category: "press",
                raisedDay: cancellation.raisedDay, respondByDay: nil,
                defaultLine: "It keeps travelling until you answer it.",
                surface: .room
            ))
        }

        // MARK: K4 (deals and exits)
        // From the first day in the red: sell up today, or ride the grace
        // period. Both numbers are balance keys, so only a caller with the
        // balance (the decision sheet, and the rail through it) lists it.
        if let balance, let offer = state.dealSellUpOffer(balance: balance) {
            let start = day - state.company.daysInDebt + 1
            entries.append(QueueEntry(
                id: "sellup-\(start)",
                kind: .sellUp, severity: .critical,
                title: "In the red: sell up or ride it", category: "money",
                raisedDay: start, respondByDay: day + offer.daysLeft,
                defaultLine: "Unanswered, the receiver calls when the grace runs out.",
                surface: .sheet
            ))
        }
        // MARK: end K4

        return entries.sorted(by: precedes)
    }

    /// The queue's order.
    static func precedes(_ lhs: QueueEntry, _ rhs: QueueEntry) -> Bool {
        let loud = { (entry: QueueEntry) in entry.severity == .critical ? 0 : 1 }
        if loud(lhs) != loud(rhs) { return loud(lhs) < loud(rhs) }
        let lhsBy = lhs.respondByDay ?? Int.max
        let rhsBy = rhs.respondByDay ?? Int.max
        if lhsBy != rhsBy { return lhsBy < rhsBy }
        let lhsRaised = lhs.raisedDay ?? Int.max
        let rhsRaised = rhs.raisedDay ?? Int.max
        if lhsRaised != rhsRaised { return lhsRaised < rhsRaised }
        let order = QueueKind.allCases
        return (order.firstIndex(of: lhs.kind) ?? 0) < (order.firstIndex(of: rhs.kind) ?? 0)
    }
}

// MARK: - The weekly cap

/// Two critical stops a week, and the third waits.
///
/// Only a question with somewhere to wait is held: one the deadline
/// answers, or one that waits for the founder. Money running out, a game
/// over, somebody walking out of the door and a room that has already
/// opened always stop the clock.
public enum QueueCap {
    public static let criticalPausesPerWeek = 2
    public static let windowDays = GameState.daysPerWeek

    /// Whether the question behind `event` can wait on the rail.
    public static func canWait(_ event: GameEvent) -> Bool {
        switch event {
        case .narrativeChoice, .poachAttempt, .buyoutOffered, .investmentOffered,
             .staffEventOccurred, .resignationNotice, .categoryChallenged,
             .dirtyMoneyOffered, .dirtyMoneyDemanded, .crimeCaseRaised,
             .familyAffairDiscovered, .fameCancellationRaised:
            true
        default:
            false
        }
    }

    /// Whether today's stop is the third critical one inside a week and
    /// every reason for it can wait.
    public static func holds(
        _ pausing: [GameEvent],
        recentCriticalPauseDays: [Int],
        day: Int
    ) -> Bool {
        guard !pausing.isEmpty,
              pausing.allSatisfy({ $0.severity == .critical && canWait($0) })
        else { return false }
        let recent = recentCriticalPauseDays.filter { day - $0 < windowDays }.count
        return recent >= criticalPausesPerWeek
    }
}

// MARK: - Late-game money has teeth

/// The event-stakes key: `max(1, burn / reference)^0.5`, exactly 1.0 under
/// the reference and when the key is off.
public enum QueueStakes {
    public static func multiplier(burn: Int, balance: BalanceConfig) -> Double {
        let reference = balance.queuePacing.eventCashReferenceBurn
        guard reference > 0, burn > reference else { return 1 }
        return (Double(burn) / Double(reference)).squareRoot()
    }

    /// `amount` at `multiplier`, to the nearest ten dollars; untouched at
    /// exactly 1.0, so the garage never so much as rounds.
    public static func scaled(_ amount: Int, by multiplier: Double) -> Int {
        guard multiplier != 1, amount != 0 else { return amount }
        return Int((Double(amount) * multiplier / 10).rounded()) * 10
    }
}

extension GameState {
    /// The week's fixed costs — the same sum as `GameEngine.weeklyBurn`,
    /// read off the state so the reducer can use it.
    public func queueWeeklyBurn(balance: BalanceConfig) -> Int {
        balance.weeklyOperatingCost
            + officeWeeklyRent(balance: balance)
            + employees.reduce(0) { $0 + $1.weeklySalary }
            + life.founderSalary
            + amenityWeeklyUpkeep(balance: balance)
    }

    /// Today's multiplier on a story's money.
    public func queueEventStakes(balance: BalanceConfig) -> Double {
        QueueStakes.multiplier(burn: queueWeeklyBurn(balance: balance), balance: balance)
    }

    /// The campus's rent under the second key, before the district and the
    /// Operations discount — or `nil` when the key is off or the company is
    /// not on the campus, and the office's listed rent applies. Scaled by
    /// the difficulty's office factor, as the listed rent is.
    func queueCampusRent(balance: BalanceConfig) -> Double? {
        let pacing = balance.queuePacing
        guard pacing.campusRentBase > 0, company.officeTier == .campus else { return nil }
        let above = max(0, headcount - pacing.campusRentFreeHeadcount)
        let normal = Double(pacing.campusRentBase + pacing.campusRentPerHead * above)
        return normal * (balance.difficulty[difficulty.rawValue]?.officeCostFactor ?? 1)
    }
}

// MARK: - Debug seeds

/// `-autoQueue`, `-autoChild <stage>`, `-autoCampus`, `-autoStakes <id>`:
/// one situation each, dressed for a screenshot. Reached only through
/// `.queueDebugSeed`, which the reducer applies in debug builds alone.
enum QueueDebugSeed {
    static func apply(
        kind: String,
        value: String,
        state: inout GameState,
        balance: BalanceConfig,
        content: ContentCatalog
    ) -> [GameEvent] {
        switch kind {
        case "queue":
            // A story in tomorrow's post and the partner already waiting up:
            // two questions, one with a deadline and one without.
            let eventID = value.isEmpty ? "patent_troll" : value
            if content.event(eventID) != nil {
                NarrativeSystem.schedule(eventID, source: .company, day: state.day + 1, state: &state)
            }
            state.familyDrama.confrontedDay = state.day
            state.familyDrama.confessionAnswer = nil
            return []
        case "child":
            guard let index = ChildStage.allCases.firstIndex(where: { "\($0)" == value })
            else { return [] }
            let thresholds = balance.childhood.stageDays
            let age = index == 0 ? 7 : thresholds[index - 1] + 7
            let child = Child(
                id: UUID(uuidString: "00000000-0000-0000-0000-0000000000A\(index)") ?? UUID(),
                name: "Robin",
                bornDay: state.day - age,
                appearanceSeed: state.seed &+ 0xC41D
            )
            state.life.family.children.append(child)
            return []
        case "campus":
            state.company.officeTier = .campus
            return []
        case "stakes":
            // The campus and a founder on the top of the pay band: a burn a
            // long way past the reference, and a story with money in it.
            state.company.officeTier = .campus
            state.life.founderSalary = max(state.life.founderSalary, 5_000)
            let eventID = value.isEmpty ? "patent_troll" : value
            if content.event(eventID) != nil {
                NarrativeSystem.schedule(eventID, source: .company, day: state.day + 1, state: &state)
            }
            return []
        default:
            return []
        }
    }
}
