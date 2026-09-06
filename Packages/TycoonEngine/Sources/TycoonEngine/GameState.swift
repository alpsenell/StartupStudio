import Foundation
import TycoonContent

/// The player's company.
public struct Company: Codable, Equatable, Sendable {
    public var name: String
    public var cash: Int
    /// 0–100, starts at 10.
    public var reputation: Double
    public var officeTier: OfficeTier
    /// Consecutive days spent with negative cash. Resets to 0 on recovery.
    public var daysInDebt: Int
}

/// A single financial posting. Negative amounts are expenses.
public struct LedgerEntry: Codable, Equatable, Sendable {
    public enum Category: String, Codable, Equatable, Sendable, CaseIterable {
        case operating, rent, payroll, sales, contracts, marketing, research, other
        /// Servers, bandwidth and support desks for everything on the
        /// market — the cost of success (appended by WS-A).
        case hosting
    }

    public var day: Int
    public var amount: Int
    public var category: Category
    public var label: String

    public init(day: Int, amount: Int, category: Category, label: String) {
        self.day = day
        self.amount = amount
        self.category = category
        self.label = label
    }
}

/// Rolling financial ledger, capped to the most recent 500 entries.
public struct FinancialLedger: Codable, Equatable, Sendable {
    /// The maximum number of entries retained.
    static let maxEntries = 500

    public var entries: [LedgerEntry]

    /// Appends an entry, dropping the oldest entries beyond the cap.
    mutating func post(_ entry: LedgerEntry) {
        entries.append(entry)
        if entries.count > Self.maxEntries {
            entries.removeFirst(entries.count - Self.maxEntries)
        }
    }
}

/// How a run ended.
public enum EndingKind: String, Codable, Equatable, Sendable {
    case bankruptcy
    /// The founder sold the company to a rival — a successful exit.
    case acquired

    // MARK: WS-F

    /// The company went public and the founder rang the bell — the best
    /// ending in the game.
    case ipo
    /// The board lost patience and replaced the founder with a hire.
    case oustedByBoard

    // MARK: Iteration 5

    /// A distress buyout: somebody bought the name and the desks. Not a
    /// win — the post-mortem shows (WS-B, exit terms).
    case soldUp
    /// The founder kept every share and built something that lasts —
    /// the independent ladder's ending, "Still yours" (WS-G).
    case independent

    /// Whether the run ended somewhere the founder would call a win. The
    /// endings screen picks its tone from this.
    public var isSuccess: Bool {
        switch self {
        case .acquired, .ipo, .independent: true
        case .bankruptcy, .oustedByBoard, .soldUp: false
        }
    }

    /// The headline the founder biography leads with.
    public var headline: String {
        switch self {
        case .bankruptcy: "Bankrupt"
        case .acquired: "Acquired"
        case .ipo: "Public"
        case .oustedByBoard: "Replaced"
        case .soldUp: "Sold up"
        case .independent: "Still yours"
        }
    }
}

/// Terminal state details once the run has ended.
public struct GameOverInfo: Codable, Equatable, Sendable {
    public var day: Int
    public var reason: String
    /// Saves written before endings existed decode as `.bankruptcy`.
    public var kind: EndingKind

    init(day: Int, reason: String, kind: EndingKind = .bankruptcy) {
        self.day = day
        self.reason = reason
        self.kind = kind
    }
}

extension GameOverInfo {
    private enum CodingKeys: String, CodingKey {
        case day, reason, kind
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            day: try container.decode(Int.self, forKey: .day),
            reason: try container.decode(String.self, forKey: .reason),
            kind: try container.decodeIfPresent(EndingKind.self, forKey: .kind) ?? .bankruptcy
        )
    }
}

/// Notable simulation events surfaced to the UI.
public enum GameEvent: Codable, Equatable, Sendable {
    case bankruptcyWarning(day: Int)
    case gameOver(day: Int)
    case productStarted(productID: UUID, day: Int)
    case shipped(productID: UUID, day: Int)
    case reviewsIn(productID: UUID, averageScore: Int, day: Int)
    case productOffMarket(productID: UUID, day: Int)
    case hired(employeeID: UUID, day: Int)
    case fired(employeeID: UUID, day: Int)
    case candidatesRefreshed(day: Int)
    case researchStarted(nodeID: String, day: Int)
    case researchCompleted(nodeID: String, day: Int)
    case contractOffersRefreshed(day: Int)
    case contractAccepted(contractID: UUID, day: Int)
    case contractCompleted(contractID: UUID, payout: Int, day: Int)
    case contractFailed(contractID: UUID, penalty: Int, day: Int)
    case campaignStarted(campaignID: UUID, day: Int)
    case officeUpgraded(tier: OfficeTier, day: Int)
    case randomEvent(eventID: String, day: Int)
    case lifeEvent(eventID: String, day: Int)
    case founderAway(reason: String, untilDay: Int, day: Int)
    case founderBack(day: Int)
    case relationshipChanged(stage: RelationshipStage, day: Int)
    case breakup(day: Int)
    case childBorn(name: String, day: Int)
    case homeUpgraded(tier: HomeTier, day: Int)
    case weekendSpent(activity: WeekendActivity, day: Int)
    case marketBoom(topicID: String, day: Int)
    case marketCrash(topicID: String, day: Int)
    case employeeQuit(employeeID: UUID, name: String, day: Int)
    case employeePromoted(employeeID: UUID, level: SeniorityLevel, day: Int)
    case employeeDemoted(employeeID: UUID, level: SeniorityLevel, day: Int)
    case salaryChanged(employeeID: UUID, weeklySalary: Int, day: Int)
    case employeeTrained(employeeID: UUID, day: Int)
    /// Replaces `.contractCompleted` for deliveries graded on quality
    /// (0...100). The payout is the amount actually paid after any
    /// quality docking.
    case contractDelivered(contractID: UUID, quality: Int, payout: Int, day: Int)
    case loanTaken(amount: Int, day: Int)
    case loanRepaid(amount: Int, day: Int)
    case amenityBuilt(amenity: Amenity, day: Int)
    /// A department's first staffer arrived / its last one left (detected
    /// on the daily tick).
    case departmentFormed(department: Department, day: Int)
    case departmentDissolved(department: Department, day: Int)
    case rivalFounded(rivalID: UUID, name: String, day: Int)
    case rivalShipped(rivalID: UUID, topicID: String, day: Int)
    case rivalFolded(rivalID: UUID, name: String, day: Int)
    /// A rival made one of the player's employees an offer; the player can
    /// match it or let them go until `respondByDay`.
    case poachAttempt(rivalID: UUID, employeeID: UUID, offeredWeeklySalary: Int, respondByDay: Int, day: Int)
    /// The player matched a poach offer and the employee stayed.
    case poachDefeated(employeeID: UUID, day: Int)
    /// An employee left for a rival (declined counter, or auto-resolved).
    case employeePoached(employeeID: UUID, name: String, rivalID: UUID, day: Int)
    /// A rival offered to buy the company; open until `respondByDay`.
    case buyoutOffered(rivalID: UUID, amount: Int, respondByDay: Int, day: Int)
    case buyoutWithdrawn(rivalID: UUID, day: Int)
    /// The player accepted a buyout — the run ends as a successful exit.
    case companySold(rivalID: UUID, amount: Int, day: Int)
    /// The player acquired a rival studio.
    case rivalAcquired(rivalID: UUID, name: String, hiresAbsorbed: Int, day: Int)
    /// The office moved to a new district (pauses so the player sees the
    /// new terms).
    case officeRelocated(district: DistrictID, day: Int)
    case officeBought(district: DistrictID, price: Int, day: Int)
    case officeSold(district: DistrictID, price: Int, day: Int)
    case instantActivityDone(activity: InstantActivity, day: Int)
    case itemPurchased(itemID: String, day: Int)
    /// A one-on-one social action (or the team dinner, employeeID nil).
    case socialActivity(kind: SocialActivityKind, employeeID: UUID?, day: Int)
    /// Two employees became friends.
    case friendshipFormed(a: UUID, b: UUID, day: Int)
    /// A surviving friend took the departure hard.
    case friendLostMorale(employeeID: UUID, day: Int)
    case staffBirthday(employeeID: UUID, day: Int)
    /// A staff moment needs an answer by `respondByDay` (pauses).
    case staffEventOccurred(employeeID: UUID, kind: StaffEventKind, respondByDay: Int, day: Int)
    case staffEventResolved(employeeID: UUID, choice: StaffEventChoice, day: Int)

    // Reserved regions — each workstream appends its new cases inside its
    // own region and nowhere else, so six branches never touch the same
    // line. Keep the regions in this order; never reorder existing cases
    // (the case order is not persisted, but a stable diff is the point).

    // MARK: WS-A

    /// Live bugs on a released product crossed the alarm threshold: the
    /// wild is eating its sales until someone is put on support.
    case liveBugsSpiking(productID: UUID, liveBugs: Int, day: Int)
    /// A patch landed: the product's quality and reviews were revised.
    case updateShipped(productID: UUID, newScore: Int, day: Int)
    /// The player moved a released product to a new price tier.
    case priceChanged(productID: UUID, tier: PriceTier, day: Int)
    /// An employee handed in their notice; a raise or promotion before
    /// `respondByDay` still keeps them.
    case resignationNotice(employeeID: UUID, name: String, respondByDay: Int, day: Int)
    /// The founder's landlord has had enough of the overdrawn rent.
    case evictionWarning(untilDay: Int, day: Int)
    /// The founder was forced out of their home into a cheaper one.
    case homeDowngraded(tier: HomeTier, day: Int)
    /// Two hospital stays in a year: the founder now lives with a chronic
    /// condition.
    case chronicConditionDiagnosed(day: Int)
    /// Three restorative weekends in a row cleared it.
    case chronicConditionCleared(day: Int)
    /// Burning out twice in a year made the trade press.
    case founderMeltdown(day: Int)

    // MARK: WS-B

    /// A story beat is waiting on the founder's answer until
    /// `respondByDay`. Pauses the timeline.
    case narrativeChoice(eventID: String, respondByDay: Int, day: Int)
    /// A story beat was answered — by the player, or by the deadline
    /// (`automatic`).
    case narrativeResolved(eventID: String, optionID: String, automatic: Bool, day: Int)
    /// A headline from the wider industry. Flavor only: never pauses,
    /// changes nothing.
    case industryNews(headline: String, day: Int)

    // MARK: WS-F

    /// A chapter goal was finished (and its reward paid).
    case goalCompleted(goalID: String, day: Int)
    /// A new chapter opened.
    case chapterReached(chapter: Int, day: Int)
    /// An investor put a term sheet on the table; open until
    /// `respondByDay`.
    case investmentOffered(investorID: String, amount: Int, equity: Double, respondByDay: Int, day: Int)
    /// The founder took the money.
    case investmentAccepted(investorID: String, amount: Int, equity: Double, day: Int)
    /// The founder turned it down.
    case investmentDeclined(investorID: String, day: Int)
    /// The offer expired unanswered.
    case investmentWithdrawn(investorID: String, day: Int)
    /// A quarterly board review landed.
    case boardReviewed(met: Bool, pressure: Double, day: Int)
    /// Board pressure crossed the warning line: they want a plan.
    case boardDemandedPlan(pressure: Double, day: Int)
    /// The board replaced the founder — the run ends.
    case founderOusted(day: Int)
    /// The company filed to go public — the run ends.
    case wentPublic(proceeds: Int, day: Int)
    /// A rival shipped a *named* product into a topic.
    case rivalProductLaunched(rivalID: UUID, productName: String, topicID: String, quality: Int, day: Int)
    /// A rival started a price war in a topic the player leads.
    case priceWarStarted(rivalID: UUID, topicID: String, untilDay: Int, day: Int)
    /// A rival cloned the player's best topic.
    case rivalCopycat(rivalID: UUID, topicID: String, day: Int)
    /// The player was interviewed a candidate and learned their second
    /// trait.
    case candidateInterviewed(candidateID: UUID, day: Int)

    // MARK: Founder & people

    /// The founder trained one of their own attributes.
    case founderTrained(skill: FounderSkill, method: TrainingMethod, gained: Double, day: Int)
    /// A networking weekend opened a room.
    case networkingEventStarted(venue: NetworkingVenue, contactCount: Int, day: Int)
    /// One exchange with somebody in the room. `landed` is whether it went
    /// well; a miss costs rapport.
    case networkingTalk(contactID: UUID, topic: ConversationTopic, landed: Bool, day: Int)
    /// The founder walked out, or the room closed.
    case networkingEventEnded(day: Int)
    /// Somebody from the address book took a salaried job.
    case contactRecruited(contactID: UUID, name: String, day: Int)
    /// Somebody from the address book joined as an owner, for equity out
    /// of the founder's own stake.
    case contactJoinedForEquity(contactID: UUID, name: String, equity: Double, day: Int)
    /// The founder put their own money into somebody else's startup.
    case stakeAcquired(contactID: UUID, companyName: String, stakePercent: Double, amount: Int, day: Int)
    /// One of those startups was bought. The proceeds land in the wallet.
    case stakeExited(companyName: String, proceeds: Int, day: Int)
    /// One of those startups folded.
    case stakeLost(companyName: String, invested: Int, day: Int)
    /// A contact put money into the founder's company.
    case angelInvestment(contactID: UUID, name: String, amount: Int, equity: Double, day: Int)
    /// A contact became the founder's partner.
    case romanceStarted(contactID: UUID, name: String, day: Int)
    /// The founder spent time with their partner.
    case partnerTime(activity: PartnerActivity, affection: Double, day: Int)
    /// The partner has had enough of being an afterthought — a warning
    /// before the breakup, and the only one there is.
    case partnerDrifting(affection: Double, day: Int)
    /// The company is in debt with a personal guarantee outstanding: the
    /// founder's savings and home go on `callOnDay` unless it is cleared.
    /// The warning the flat trigger never gave.
    case guaranteeAtRisk(amount: Int, callOnDay: Int, day: Int)
    /// The bank called the founder's personal guarantee in: `amount` of
    /// the company's debt was paid off with the founder's own savings, or
    /// — with `tookHome` — by taking their home. Never silent: this is the
    /// player's money, and it leaves without them pressing anything.
    case guaranteeCalled(amount: Int, tookHome: Bool, day: Int)
    /// The founder spent their own evening with somebody on the team.
    case hungOutWith(employeeID: UUID, day: Int)
    /// The founder taught somebody something.
    case employeeMentored(employeeID: UUID, skill: TrainableSkill, day: Int)

    // MARK: Iteration 5

    // Appended by the scaffold so eight lanes never edit the same line.
    // Each lane emits its own; the copy lives in `EventCopy` / `EventPresenter`.

    // WS-A — the category fight and the incumbent.
    /// A rival launched into a category the player holds; the clock stops
    /// for six weeks' worth of decision.
    case categoryChallenged(
        rivalID: UUID, topicID: String, productName: String, quality: Int, respondByDay: Int, day: Int
    )
    /// The challenge settled in the player's favour.
    case categoryHeld(rivalID: UUID, topicID: String, day: Int)
    /// The challenge settled against the player.
    case categoryLost(rivalID: UUID, topicID: String, day: Int)
    /// A deep-pockets rival founded into the player's best categories.
    case incumbentArrived(rivalID: UUID, name: String, day: Int)
    /// The incumbent gave up the player's categories.
    case incumbentRetreated(rivalID: UUID, name: String, day: Int)

    // WS-B — buy back the board, and exit terms.
    /// A seated round was bought out and its ask left the room.
    case roundBoughtBack(investorID: String, amount: Int, day: Int)
    /// An earn-out review settled: `paid` this quarter, `remainingReviews` to go.
    case earnOutReviewed(met: Bool, paid: Int, remainingReviews: Int, day: Int)
    /// A strategic buyout was signed as an earn-out: `upfront` landed
    /// today against a `price` the next reviews decide.
    case earnOutSigned(rivalID: UUID, upfront: Int, price: Int, day: Int)

    // WS-C — rival-sponsored contracts.
    /// A white-label job was delivered and the sponsoring rival shipped it.
    case sponsoredContractDelivered(rivalID: UUID, topicID: String, quality: Int, day: Int)

    // WS-D — the answer becomes the policy.
    /// A supportive answer became the rule.
    case staffPolicySet(flag: String, employeeID: UUID, day: Int)
    /// The rule answered for somebody, no sheet.
    case staffPolicyApplied(flag: String, employeeID: UUID, day: Int)
    /// The rule was reversed, publicly.
    case staffPolicyReversed(flag: String, day: Int)

    // WS-E — the date in the diary.
    /// A dated family beat went unanswered.
    case familyDateMissed(eventID: String, day: Int)

    // WS-F — the boomerang.
    /// Somebody who left the company went into the address book.
    case alumnusJoinedBook(contactID: UUID, name: String, day: Int)

    // WS-G — two ladders.
    /// The founder declared the company built, still owning all of it.
    case stayedIndependent(day: Int)

    // MARK: Iteration 7

    // Appended by the scaffold; the copy lives in `EventCopy`.

    /// R5: the founder kept running the company past `ending`.
    case continuedAfterEnding(ending: EndingKind, day: Int)
    /// R2: the one thing carried from the last company landed on day 0.
    /// `kind` is `Heirloom.kind` — person, perk or deed.
    case heirloomApplied(kind: String, day: Int)
}

extension GameEvent {
    /// Whether this event is loud enough to stop the clock at all —
    /// `.notable` or `.critical`. This is the *static* grade; whether a
    /// given occurrence actually pauses also depends on the state and the
    /// pause budget, which is `PausePolicy`'s job.
    public var pausesTimeline: Bool {
        // Derived from `severity` in place: WS-A grades every case, and the
        // grade is the single source of truth for whether the clock can stop.
        switch severity {
        case .quiet, .info: false
        case .notable, .critical: true
        }
    }

    /// How loudly an event should interrupt the player.
    ///
    /// `.critical` always stops the clock: money running out, an offer with
    /// a deadline, somebody leaving, the founder in hospital. `.notable`
    /// stops it too, but within the pause budget — one non-critical
    /// interruption every `economy.pauseBudgetDays`. `.info` and `.quiet`
    /// never stop it; they are there for the feed and the log.
    public var severity: EventSeverity {
        switch self {

        // MARK: WS-A

        // Money, deadlines, and people walking out the door: always stop.
        case .bankruptcyWarning, .gameOver, .companySold, .rivalAcquired,
             .poachAttempt, .buyoutOffered, .staffEventOccurred,
             .resignationNotice, .employeeQuit, .employeePoached, .breakup:
            .critical
        // The founder's own body only interrupts when it is serious.
        case .founderAway(let reason, _, _):
            reason == "Burnout" || reason == "Hospital" ? .critical : .notable
        // Worth looking up for, once the budget allows.
        case .reviewsIn, .updateShipped, .contractFailed, .productOffMarket,
             .liveBugsSpiking, .childBorn, .relationshipChanged, .officeUpgraded,
             .officeRelocated, .homeUpgraded, .homeDowngraded, .researchCompleted,
             .marketBoom, .marketCrash,
             .evictionWarning, .chronicConditionDiagnosed, .chronicConditionCleared,
             .founderMeltdown:
            .notable
        // A story beat that asked the player nothing. It happened, its
        // effects are applied, the feed and the journal have it — but
        // there is no answer to give, so the clock does not stop for it.
        //
        // These graded `.notable` when the scaffold's ten one-line events
        // were the only events in the game. WS-B's catalog then made every
        // beat that *does* want an answer a `.narrativeChoice`, which is
        // critical and always pauses; what is left in these two cases is
        // by definition the news you cannot act on. Together they were
        // nineteen of a solo run's forty-four annual stops.
        case .randomEvent, .lifeEvent:
            .info
        // Background texture: the feed shows it, the clock keeps running.
        case .weekendSpent, .instantActivityDone, .socialActivity, .staffBirthday,
             .friendshipFormed, .candidatesRefreshed, .contractOffersRefreshed:
            .quiet

        // MARK: WS-B

        case .narrativeChoice:
            .critical
        case .narrativeResolved:
            .info
        case .industryNews:
            .quiet

        // MARK: WS-F

        case .founderOusted, .wentPublic, .investmentOffered:
            .critical
        case .boardDemandedPlan, .chapterReached, .priceWarStarted:
            .notable
        case .goalCompleted, .investmentAccepted, .rivalProductLaunched, .rivalCopycat:
            .info
        case .investmentDeclined, .investmentWithdrawn, .boardReviewed, .candidateInterviewed:
            .quiet

        // MARK: Founder & people

        // The founder's own money coming back — or not — is worth stopping
        // for, and a partner who is drifting is the last warning before a
        // breakup that ends the same way a bankruptcy does: suddenly, and
        // with the player saying they never saw it.
        // The founder's own money leaving without them pressing anything,
        // and the notice that it is about to.
        case .guaranteeCalled, .guaranteeAtRisk:
            .critical
        case .stakeExited, .stakeLost, .partnerDrifting:
            .notable
        case .networkingEventStarted, .contactRecruited, .contactJoinedForEquity,
             .stakeAcquired, .angelInvestment, .romanceStarted:
            .info
        case .founderTrained, .networkingTalk, .networkingEventEnded, .partnerTime,
             .hungOutWith, .employeeMentored:
            .quiet

        // MARK: Iteration 5

        // A challenge with a deadline and the end of a run always stop.
        case .categoryChallenged, .stayedIndependent:
            .critical
        // Settlements and arrivals: worth looking up for.
        case .categoryHeld, .categoryLost, .incumbentArrived, .incumbentRetreated,
             .roundBoughtBack, .earnOutReviewed, .familyDateMissed:
            .notable
        // Signing the earn-out is the player's own act; the sheet just
        // closed on it.
        case .earnOutSigned:
            .info
        // A policy answering for somebody is the pause that did *not*
        // happen; the ledger and the feed carry it.
        case .sponsoredContractDelivered, .staffPolicySet, .staffPolicyApplied,
             .staffPolicyReversed:
            .info
        case .alumnusJoinedBook:
            .quiet

        // MARK: Iteration 7

        // Choosing to keep going is the player's own act; the day-0 gift
        // is worth a line in the feed and nothing more.
        case .continuedAfterEnding, .heirloomApplied:
            .info

        default:
            .info
        }
    }
}

/// Decides which of a tick's events actually stop the clock.
///
/// Grading alone is not enough: a market boom in a topic the studio has
/// nothing in is somebody else's news, and a run of `.notable` events in
/// one week would put the player back where they started — one pause every
/// four days at 4× speed, with no idea why. So on top of the severity:
///
/// - `.critical` always pauses;
/// - `.marketBoom` / `.marketCrash` only pause for a topic the studio has
///   something on the market in;
/// - everything else `.notable` pauses at most once every
///   `economy.pauseBudgetDays`, and is otherwise left as a feed line.
public enum PausePolicy {
    /// The events from this tick that should stop the clock, in order.
    public static func pausingEvents(
        _ events: [GameEvent],
        state: GameState,
        balance: BalanceConfig
    ) -> [GameEvent] {
        var pausing: [GameEvent] = []
        var budgetSpent = false
        let budgetDays = balance.economy.pauseBudgetDays
        let sinceLast = state.economy.lastNonCriticalPauseDay.map { state.day - $0 }

        for event in events {
            switch event.severity {
            case .quiet, .info:
                continue
            case .critical:
                pausing.append(event)
            case .notable:
                guard isRelevant(event, to: state) else { continue }
                guard budgetDays <= 0 || (!budgetSpent && (sinceLast ?? Int.max) >= budgetDays)
                else { continue }
                budgetSpent = true
                pausing.append(event)
            }
        }
        return pausing
    }

    /// Whether a notable event is about this studio at all.
    private static func isRelevant(_ event: GameEvent, to state: GameState) -> Bool {
        switch event {
        case .marketBoom(let topicID, _), .marketCrash(let topicID, _):
            state.products.contains { product in
                guard case .released(let info) = product.stage else { return false }
                return product.topicID == topicID && !info.offMarket
            }
        default:
            true
        }
    }
}

/// How loudly an event interrupts the player, from background noise to a
/// full stop. WS-A's pause policy grades every `GameEvent` with one of
/// these and budgets non-critical pauses; WS-E picks banner and haptic
/// strength from it.
public enum EventSeverity: String, Codable, Equatable, Sendable, CaseIterable {
    case quiet, info, notable, critical
}

/// The complete, serializable simulation state. A pure value: the reducer is
/// the only thing that advances it, one game day per tick.
public struct GameState: Codable, Equatable, Sendable {
    /// Days per game year (52 weeks of 7 days).
    static let daysPerYear = 364
    /// Days per game week.
    public static let daysPerWeek = 7
    /// The maximum number of `eventLog` entries retained (mirrors
    /// `FinancialLedger.maxEntries`).
    static let maxEventLogEntries = 500

    public var schemaVersion: Int
    /// Chosen once at `newGame`; the engine rescales the balance with it.
    /// Saves written before difficulty existed decode as `.normal`.
    public var difficulty: Difficulty
    /// The seed this game was started from. Kept so an ending can offer
    /// the same year again — same events, same candidates — with the
    /// knowledge of how it went. Saves from before it was recorded read 0.
    public var seed: UInt64 = 0
    /// How the company was founded (WS-H). Saves from before origins
    /// existed decode as `.garage`, which is byte-identical to today.
    public var origin: FoundingOrigin = .garage

    // MARK: Iteration 7

    // Four per-run facts, every one of them absent from a standard run's
    // save: encoded only when non-default, decoded with the default, so a
    // save from before they existed and a pacing run's save are the same
    // bytes they were.

    /// How the run was entered (standard, custom, the daily). R3/R4.
    public var mode: RunMode = .standard
    /// The custom company's overrides; `.standard` is the identity. R4.
    public var rules: GameRules = .standard
    /// The one thing carried from the last company, if any. R2.
    public var heirloom: Heirloom? = nil
    /// Set once the founder keeps running the company past an ending. R5.
    public var epilogue: Epilogue? = nil
    /// Iteration 8: who this founder is to the last company's, when the
    /// founder came from the ledger. Encoded only when set.
    public var lineage: Lineage? = nil
    /// Iteration 8: real players' companies standing in for rivals in a
    /// daily. Encoded only when non-empty; `RivalSystem` founds one rival
    /// per script and replays its launches.
    public var ghosts: [GhostScript] = []
    public var rng: SeededRNG
    /// A second RNG stream feeding the "world" systems added after launch
    /// (rivals, city, social). Kept separate so those systems' draws never
    /// shift the long-established `rng` stream that the original systems
    /// (and their determinism tests) document word by word.
    public var worldRNG: SeededRNG
    /// A third stream, for the investor and board layer alone.
    ///
    /// Same reasoning as `worldRNG`, one level down. Whether a term sheet
    /// is on the table on a given day depends on `Investors.json`'s
    /// valuation floors, so every time those floors are retuned the number
    /// of draws taken before day N changes — and if the investors drew
    /// from `worldRNG` that would reshuffle rivals, the city, the social
    /// round and every life event for every seed. It did: halving the
    /// floors in this pass moved `NeglectfulBot`'s worst wallet from
    /// −$7,610 to −$8,647 without a single number in the founder's life
    /// changing, purely by shifting the stream underneath it. Pricing the
    /// board is now orthogonal to the rest of the world by construction.
    public var investorRNG: SeededRNG = SeededRNG(seed: 0x1D0B_E5EE_D1D0_B5EE)
    /// A fourth stream, for the people the founder meets: who is standing
    /// in the networking room, whether a chat lands, and how the founder's
    /// personal stakes in other studios move.
    ///
    /// The same argument as `investorRNG`, and it matters more here: the
    /// venue is rolled the moment a networking weekend resolves, which is
    /// mid-`LifeSystem`, in the middle of the original `rng` stream. Drawn
    /// from there, every founder who ever plans a Friday night would
    /// reshuffle their own life events, contract offers and candidate
    /// pools for the rest of the run.
    public var socialRNG: SeededRNG = SeededRNG(seed: 0x50C1_A150_C1A1_50C1)
    /// Ticks since founding; starts at 0.
    public var day: Int
    public var speed: SimSpeed
    public var company: Company
    public var ledger: FinancialLedger
    public var products: [Product]
    public var employees: [Employee]
    public var candidatePool: [Candidate]
    public var research: ResearchState
    public var contractOffers: [ContractOffer]
    public var activeContracts: [ContractJob]
    public var campaigns: [MarketingCampaign]
    public var eventLog: [GameEvent]
    /// Reached office-tier raw values, e.g. "loft". Recorded by
    /// `upgradeOffice` and never removed.
    public var milestonesReached: Set<String>
    /// The founder's personal life, advanced by `LifeSystem`.
    public var life: LifeState
    /// Per-topic market conditions, advanced by `MarketSystem`.
    public var market: MarketState
    /// Competitor studios and their standing offers, advanced by
    /// `RivalSystem`.
    public var rivals: RivalsState
    /// Office district and rent-vs-own terms, advanced by `CitySystem`.
    public var city: CityState
    /// Bonds between employees, advanced by `SocialSystem` (canonical pair
    /// order, kept sorted by (a, b) for deterministic encoding).
    public var friendships: [Friendship]
    /// A staff moment awaiting the founder's answer.
    public var pendingStaffEvent: StaffEvent?
    /// The last day the whole team went to dinner (global cooldown).
    public var lastTeamDinnerDay: Int?
    /// Outstanding company loan principal. Interest posts weekly.
    public var loanBalance: Int
    /// Office amenities bought so far; kept across office upgrades.
    public var amenities: Set<Amenity>
    /// The departments seen active on the last daily tick, so the tick can
    /// emit formed/dissolved events on transitions. `activeDepartments` is
    /// the live truth.
    public var knownDepartments: Set<Department>
    /// Economy, live-ops and pacing state (WS-A). Empty in the scaffold.
    public var economy: EconomyState
    /// Narrative engine state — pending choice, flags, cooldowns (WS-B).
    /// Empty in the scaffold.
    public var narrative: NarrativeState
    /// Chapters, goals and perks (WS-F). Empty in the scaffold.
    public var progression: ProgressionState
    /// Rounds raised, equity and board pressure (WS-F). Empty in the
    /// scaffold.
    public var investors: InvestorState
    /// The address book, the room the founder is standing in, and the
    /// stakes they hold in other people's startups.
    public var networking: NetworkingState = .empty
    /// What the studio's shipped products left behind, one per product
    /// type: filled pools to start the next build from, and the debt that
    /// comes with them. Empty until something ships.
    public var codebases: [Codebase] = []
    /// Topics under a non-compete (WS-H, the spin-out origin): topic id →
    /// the first day a product may be started there. `startProduct`
    /// refuses a locked topic; the flow greys it with the date. Empty for
    /// every other origin and for every save from before origins.
    public var lockedTopics: [String: Int] = [:]
    /// What the staff remember about the founder's answers: the rules
    /// they became and who was told no (WS-D). Empty until somebody asks.
    public var staffMemory: StaffMemory = .initial
    public var gameOver: GameOverInfo?

    /// Starts a fresh company. `balance` is used as given — pass the
    /// difficulty-adjusted balance (`GameEngine.newGame` does); `difficulty`
    /// is only recorded so a resume can re-derive that adjustment.
    ///
    /// `content` is read by the non-garage origins alone (a co-founder's
    /// name, a spin-out's client and locked topic come from the catalog's
    /// pools); a garage never looks at it, so callers that predate origins
    /// pass nothing and get exactly the game they always got.
    public static func newGame(
        companyName: String,
        seed: UInt64,
        balance: BalanceConfig,
        difficulty: Difficulty = .normal,
        founder: FounderProfile = .default,
        origin: FoundingOrigin = .garage,
        content: ContentCatalog? = nil,
        heirloom: Heirloom? = nil,
        rules: GameRules = .standard,
        mode: RunMode = .standard,
        lineage: Lineage? = nil,
        ghosts: [GhostScript] = []
    ) -> GameState {
        var rng = SeededRNG(seed: seed)
        // The id and the appearance word are drawn in this order, always —
        // a profile that pins the appearance still burns the draw, so the
        // stream walks the same path whatever the new-game flow chose.
        let founderID = UUID(from: &rng)
        let drawnAppearanceSeed = rng.next()
        let founderEmployee = Employee(
            id: founderID,
            name: founder.displayName,
            // The chosen archetype's spread from the progression balance.
            // The default founder — and any archetype the balance does not
            // list — falls back to the flat founder skills, which is
            // exactly the pre-archetype founder.
            skills: founder.startingSkills(
                balance: balance,
                fallback: SkillSet(
                    coding: balance.founderCoding,
                    design: balance.founderDesign,
                    marketing: balance.founderMarketing
                )
            ),
            weeklySalary: 0,
            assignment: .idle,
            isFounder: true,
            hiredDay: 0,
            appearanceSeed: founder.appearanceSeed ?? drawnAppearanceSeed,
            role: .founder
        )
        var state = GameState(
            schemaVersion: 1,
            difficulty: difficulty,
            seed: seed,
            rng: rng,
            // Derived from the seed (not drawn from `rng`) so the original
            // stream's draw count at newGame is unchanged.
            worldRNG: SeededRNG(seed: seed &* 0x9E37_79B9_7F4A_7C15 &+ 1),
            // Likewise derived, with a different odd multiplier so the two
            // world streams never run in lockstep.
            investorRNG: SeededRNG(seed: seed &* 0xD1B5_4A32_D192_ED03 &+ 2),
            // A third derived stream, a third odd multiplier.
            socialRNG: SeededRNG(seed: seed &* 0xA24B_AED4_963E_E407 &+ 3),
            day: 0,
            speed: .paused,
            company: Company(
                name: companyName,
                cash: balance.startingCash,
                reputation: 10,
                officeTier: .garage,
                daysInDebt: 0
            ),
            ledger: FinancialLedger(entries: []),
            products: [],
            employees: [founderEmployee],
            candidatePool: [],
            research: .initial,
            contractOffers: [],
            activeContracts: [],
            campaigns: [],
            eventLog: [],
            milestonesReached: [],
            life: LifeState.newGame(balance: balance),
            market: .neutral,
            rivals: .empty,
            city: .legacy,
            friendships: [],
            pendingStaffEvent: nil,
            lastTeamDinnerDay: nil,
            loanBalance: 0,
            amenities: [],
            knownDepartments: [],
            economy: .initial,
            narrative: .initial,
            progression: .initial(founder: founder),
            investors: .initial,
            networking: .empty,
            gameOver: nil
        )
        state.origin = origin
        // The origin's deltas land here, after every draw above, so
        // `.garage` stays byte-identical and no origin moves the streams:
        // `applyOrigin` derives what it needs from the seed and never
        // touches `rng`, `worldRNG`, `investorRNG` or `socialRNG`.
        state.applyOrigin(origin, seed: seed, founder: founder, balance: balance, content: content)
        // Iteration 7: the run's mode and rules are recorded (the balance
        // was already rescaled for the rules by the engine); the heirloom
        // lands last, after every draw, as a pure delta.
        state.mode = mode
        state.rules = rules
        state.heirloom = heirloom
        state.lineage = lineage
        state.ghosts = ghosts
        if let heirloom {
            state.applyHeirloom(heirloom, balance: balance)
        }
        return state
    }

    /// Departments staffed right now: any employee whose role staffs one.
    public var activeDepartments: Set<Department> {
        Set(employees.compactMap(\.role.department))
    }

    public func hasDepartment(_ department: Department) -> Bool {
        employees.contains { $0.role.department == department }
    }

    public func hasAmenity(_ amenity: Amenity) -> Bool {
        amenities.contains(amenity)
    }

    /// Owned amenities in `Amenity.allCases` order, so sums over their
    /// bonuses accumulate in a fixed order (set iteration order is not).
    var ownedAmenities: [Amenity] {
        Amenity.allCases.filter { amenities.contains($0) }
    }

    /// This week's office rent: the tier's rent scaled by the district,
    /// after the Operations discount. An owned office pays no rent
    /// (`CitySystem` posts property tax instead).
    public func officeWeeklyRent(balance: BalanceConfig) -> Int {
        guard !city.ownership.isOwned else { return 0 }
        let rent = Double(balance.office(company.officeTier).weeklyRent)
            * balance.city.district(city.district).rentMultiplier
        guard hasDepartment(.ops) else { return Int(rent.rounded()) }
        return Int((rent * balance.company.opsRentFactor).rounded())
    }

    /// What buying the current tier's space in a district costs:
    /// `buyPriceFactor` weeks of that district's rent (a garage's free rent
    /// reads as a small baseline so even it has a price).
    public func officePurchasePrice(in district: DistrictID, balance: BalanceConfig) -> Int {
        let weekly = Double(max(balance.office(company.officeTier).weeklyRent, 50))
            * balance.city.district(district).rentMultiplier
        return Int((weekly * balance.city.buyPriceFactor).rounded())
    }

    /// This week's amenity upkeep after the Operations discount.
    func amenityWeeklyUpkeep(balance: BalanceConfig) -> Int {
        let upkeep = ownedAmenities.reduce(0) { $0 + balance.company.amenity($1).weeklyCost }
        guard hasDepartment(.ops) else { return upkeep }
        return Int((Double(upkeep) * balance.company.opsUpkeepFactor).rounded())
    }

    /// The single product currently in development, if any.
    public var productInDevelopment: Product? {
        products.first { product in
            if case .development = product.stage { return true }
            return false
        }
    }

    /// Every product currently in development. The office tier sets how
    /// many there may be; `productInDevelopment` stays as the
    /// first-of-these shorthand for the UI.
    public var productsInDevelopment: [Product] {
        products.filter { product in
            if case .development = product.stage { return true }
            return false
        }
    }

    /// How many products may be in development at once: garage 1, loft 2,
    /// studio 3, campus 5.
    public var devSlots: Int { company.officeTier.concurrentDevSlots }

    /// Whether there is room to start another product right now.
    /// Builds under way right now: products in development *and* patches
    /// in flight.
    ///
    /// A patch is a build — it draws on the same pools, occupies the same
    /// people, and ships the same way — so it takes a slot like one. It
    /// did not, which made patching free: no slot, no cash, no cooldown,
    /// and twelve of them took any product to the review ceiling however
    /// it had shipped.
    public var buildsInFlight: Int {
        productsInDevelopment.count + economy.updates.count
    }

    public var hasFreeDevSlot: Bool { buildsInFlight < devSlots }

    /// Looks up a product by id.
    public func product(id: UUID) -> Product? {
        products.first { $0.id == id }
    }

    /// Everyone on payroll, founder included.
    public var headcount: Int { employees.count }

    /// Looks up an employee by id.
    public func employee(id: UUID) -> Employee? {
        employees.first { $0.id == id }
    }

    /// Looks up an accepted, still-running contract by id.
    public func activeContract(id: UUID) -> ContractJob? {
        activeContracts.first { $0.id == id }
    }

    /// Appends events to the rolling event log, dropping the oldest entries
    /// beyond the cap. The reducer is the only caller.
    mutating func logEvents(_ events: [GameEvent]) {
        eventLog.append(contentsOf: events)
        if eventLog.count > Self.maxEventLogEntries {
            eventLog.removeFirst(eventLog.count - Self.maxEventLogEntries)
        }
    }

    /// 1-based game year.
    public var year: Int { day / Self.daysPerYear + 1 }

    /// 1-based week within the current year (1...52).
    public var weekOfYear: Int { (day % Self.daysPerYear) / Self.daysPerWeek + 1 }

    /// 1-based day within the current week (1...7).
    public var dayOfWeek: Int { day % Self.daysPerWeek + 1 }

    /// Compact date label, e.g. "W3 · Y1".
    public var dateLabel: String { "W\(weekOfYear) · Y\(year)" }

    /// The same label for any day — what a deadline or an unlock reads as.
    public static func dateLabel(forDay day: Int) -> String {
        "W\((day % daysPerYear) / daysPerWeek + 1) · Y\(day / daysPerYear + 1)"
    }

    /// What the company is worth to an acquirer: cash on hand, a revenue
    /// multiple over each on-market product's recent sales, and a premium
    /// per reputation point. Deterministic — no RNG.
    public func companyValuation(balance: BalanceConfig) -> Int {
        let rivalBalance = balance.rivals
        var value = Double(company.cash - loanBalance)
        for product in products {
            guard case .released(let info) = product.stage, !info.offMarket else { continue }
            let recent = info.weeklySales.suffix(4).reduce(0) { $0 + $1.revenue }
            value += Double(recent) * rivalBalance.valuationRevenueMultiple
        }
        value += company.reputation * rivalBalance.valuationPerReputation
        return max(0, Int(value.rounded()))
    }
}

// MARK: - Codable

// Hand-written (in an extension, preserving the memberwise initializer) so
// the sets (`milestonesReached`, `amenities`, `knownDepartments`) encode in
// sorted order: `Set` iteration order is not stable across processes, and
// saves (like the determinism tests) rely on byte-identical JSON for
// identical states. The set, `life`, `market`, `loanBalance`, and
// `difficulty` keys also decode as optional so saves written before the
// fields existed keep loading (a missing life starts fresh with an empty
// wallet; a missing difficulty is Normal). The four workstream sub-states
// (`economy`, `narrative`, `progression`, `investors`) follow the same
// rule: absent keys decode as `.initial`, so `saveFormatVersion` stays 1.

extension GameState {
    private enum CodingKeys: String, CodingKey {
        case schemaVersion, rng, day, speed, company, ledger, products, employees
        case candidatePool, research, contractOffers, activeContracts, campaigns
        case eventLog, milestonesReached, life, market, loanBalance, gameOver
        case amenities, knownDepartments, difficulty
        case seed
        case origin, lockedTopics
        case worldRNG, investorRNG, rivals, city, friendships, pendingStaffEvent
        case lastTeamDinnerDay
        case economy, narrative, progression, investors
        case socialRNG, networking
        case codebases
        case staffMemory
        case mode, rules, heirloom, epilogue
        case lineage
        case ghosts
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            schemaVersion: try container.decode(Int.self, forKey: .schemaVersion),
            difficulty: try container.decodeIfPresent(Difficulty.self, forKey: .difficulty) ?? .normal,
            rng: try container.decode(SeededRNG.self, forKey: .rng),
            // Pre-rivals saves get a fixed-seed world stream; determinism
            // only needs encode/decode round-trips to be stable, which a
            // constant is.
            worldRNG: try container.decodeIfPresent(SeededRNG.self, forKey: .worldRNG)
                ?? SeededRNG(seed: 0xC0FF_EE00_C0FF_EE00),
            // Same rule for saves written before the investors had their
            // own stream: a constant is stable across round-trips, which
            // is all determinism asks of it.
            investorRNG: try container.decodeIfPresent(SeededRNG.self, forKey: .investorRNG)
                ?? SeededRNG(seed: 0x1D0B_E5EE_D1D0_B5EE),
            // And again for the people stream.
            socialRNG: try container.decodeIfPresent(SeededRNG.self, forKey: .socialRNG)
                ?? SeededRNG(seed: 0x50C1_A150_C1A1_50C1),
            day: try container.decode(Int.self, forKey: .day),
            speed: try container.decode(SimSpeed.self, forKey: .speed),
            company: try container.decode(Company.self, forKey: .company),
            ledger: try container.decode(FinancialLedger.self, forKey: .ledger),
            products: try container.decode([Product].self, forKey: .products),
            employees: try container.decode([Employee].self, forKey: .employees),
            candidatePool: try container.decode([Candidate].self, forKey: .candidatePool),
            research: try container.decode(ResearchState.self, forKey: .research),
            contractOffers: try container.decode([ContractOffer].self, forKey: .contractOffers),
            activeContracts: try container.decode([ContractJob].self, forKey: .activeContracts),
            campaigns: try container.decode([MarketingCampaign].self, forKey: .campaigns),
            eventLog: try container.decode([GameEvent].self, forKey: .eventLog),
            milestonesReached: Set(
                try container.decodeIfPresent([String].self, forKey: .milestonesReached) ?? []
            ),
            life: try container.decodeIfPresent(LifeState.self, forKey: .life)
                ?? LifeState.newGame(wallet: 0, founderSalary: 0),
            market: try container.decodeIfPresent(MarketState.self, forKey: .market) ?? .neutral,
            rivals: try container.decodeIfPresent(RivalsState.self, forKey: .rivals) ?? .empty,
            city: try container.decodeIfPresent(CityState.self, forKey: .city) ?? .legacy,
            friendships: try container.decodeIfPresent([Friendship].self, forKey: .friendships) ?? [],
            pendingStaffEvent: try container.decodeIfPresent(StaffEvent.self, forKey: .pendingStaffEvent),
            lastTeamDinnerDay: try container.decodeIfPresent(Int.self, forKey: .lastTeamDinnerDay),
            loanBalance: try container.decodeIfPresent(Int.self, forKey: .loanBalance) ?? 0,
            amenities: Set(try container.decodeIfPresent([Amenity].self, forKey: .amenities) ?? []),
            knownDepartments: Set(
                try container.decodeIfPresent([Department].self, forKey: .knownDepartments) ?? []
            ),
            economy: try container.decodeIfPresent(EconomyState.self, forKey: .economy) ?? .initial,
            narrative: try container.decodeIfPresent(NarrativeState.self, forKey: .narrative) ?? .initial,
            progression: try container.decodeIfPresent(ProgressionState.self, forKey: .progression)
                ?? .initial,
            investors: try container.decodeIfPresent(InvestorState.self, forKey: .investors) ?? .initial,
            networking: try container.decodeIfPresent(NetworkingState.self, forKey: .networking)
                ?? .empty,
            // A save written before codebases existed has none, so every
            // product in it is greenfield and behaves exactly as it did.
            codebases: try container.decodeIfPresent([Codebase].self, forKey: .codebases) ?? [],
            // Absent in every save from before rules existed, and in every
            // save where nobody ever asked; both read as nothing remembered.
            staffMemory: try container.decodeIfPresent(StaffMemory.self, forKey: .staffMemory)
                ?? .initial,
            gameOver: try container.decodeIfPresent(GameOverInfo.self, forKey: .gameOver)
        )
        seed = try container.decodeIfPresent(UInt64.self, forKey: .seed) ?? 0
        origin = try container.decodeIfPresent(FoundingOrigin.self, forKey: .origin) ?? .garage
        mode = try container.decodeIfPresent(RunMode.self, forKey: .mode) ?? .standard
        rules = try container.decodeIfPresent(GameRules.self, forKey: .rules) ?? .standard
        heirloom = try container.decodeIfPresent(Heirloom.self, forKey: .heirloom)
        epilogue = try container.decodeIfPresent(Epilogue.self, forKey: .epilogue)
        lineage = try container.decodeIfPresent(Lineage.self, forKey: .lineage)
        ghosts = try container.decodeIfPresent([GhostScript].self, forKey: .ghosts) ?? []
        lockedTopics = Dictionary(
            (try container.decodeIfPresent([TopicLockEntry].self, forKey: .lockedTopics) ?? [])
                .map { ($0.topicID, $0.unlockDay) },
            uniquingKeysWith: { first, _ in first }
        )
    }

    /// One locked topic on the wire. A dictionary would encode in hash
    /// order; a sorted array of entries is byte-identical for identical
    /// states, the same argument as `LifeState.instantCooldowns`.
    private struct TopicLockEntry: Codable {
        var topicID: String
        var unlockDay: Int
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(seed, forKey: .seed)
        try container.encode(origin, forKey: .origin)
        // Written only when something is locked, so a save with no
        // non-compete encodes byte-for-byte as the scaffold wrote it.
        if !lockedTopics.isEmpty {
            try container.encode(
                lockedTopics.keys.sorted().map {
                    TopicLockEntry(topicID: $0, unlockDay: lockedTopics[$0] ?? 0)
                },
                forKey: .lockedTopics
            )
        }
        try container.encode(difficulty, forKey: .difficulty)
        try container.encode(rng, forKey: .rng)
        try container.encode(worldRNG, forKey: .worldRNG)
        try container.encode(investorRNG, forKey: .investorRNG)
        try container.encode(socialRNG, forKey: .socialRNG)
        try container.encode(day, forKey: .day)
        try container.encode(speed, forKey: .speed)
        try container.encode(company, forKey: .company)
        try container.encode(ledger, forKey: .ledger)
        try container.encode(products, forKey: .products)
        try container.encode(employees, forKey: .employees)
        try container.encode(candidatePool, forKey: .candidatePool)
        try container.encode(research, forKey: .research)
        try container.encode(contractOffers, forKey: .contractOffers)
        try container.encode(activeContracts, forKey: .activeContracts)
        try container.encode(campaigns, forKey: .campaigns)
        try container.encode(eventLog, forKey: .eventLog)
        try container.encode(milestonesReached.sorted(), forKey: .milestonesReached)
        try container.encode(life, forKey: .life)
        try container.encode(market, forKey: .market)
        try container.encode(rivals, forKey: .rivals)
        try container.encode(city, forKey: .city)
        try container.encode(
            friendships.sorted {
                ($0.a.uuidString, $0.b.uuidString) < ($1.a.uuidString, $1.b.uuidString)
            },
            forKey: .friendships
        )
        try container.encodeIfPresent(pendingStaffEvent, forKey: .pendingStaffEvent)
        try container.encodeIfPresent(lastTeamDinnerDay, forKey: .lastTeamDinnerDay)
        try container.encode(loanBalance, forKey: .loanBalance)
        try container.encode(amenities.sorted { $0.rawValue < $1.rawValue }, forKey: .amenities)
        try container.encode(
            knownDepartments.sorted { $0.rawValue < $1.rawValue }, forKey: .knownDepartments
        )
        try container.encode(economy, forKey: .economy)
        try container.encode(narrative, forKey: .narrative)
        try container.encode(progression, forKey: .progression)
        try container.encode(investors, forKey: .investors)
        try container.encode(networking, forKey: .networking)
        try container.encode(codebases, forKey: .codebases)
        // Written only once there is something to remember, so a run in
        // which nobody was ever answered — every pacing run — encodes to
        // the same bytes it did before the key existed.
        if !staffMemory.isEmpty {
            try container.encode(staffMemory, forKey: .staffMemory)
        }
        try container.encodeIfPresent(gameOver, forKey: .gameOver)
        // Iteration 7: written only when set, so a standard run's save is
        // byte-identical to one written before the keys existed.
        if mode != .standard {
            try container.encode(mode, forKey: .mode)
        }
        if !rules.isStandard {
            try container.encode(rules, forKey: .rules)
        }
        try container.encodeIfPresent(heirloom, forKey: .heirloom)
        try container.encodeIfPresent(epilogue, forKey: .epilogue)
        try container.encodeIfPresent(lineage, forKey: .lineage)
        if !ghosts.isEmpty {
            try container.encode(ghosts, forKey: .ghosts)
        }
    }
}
