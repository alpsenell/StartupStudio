import Foundation
import PixelKit
import TycoonContent
import TycoonEngine

/// One front page: everything the newspaper screen draws for a week of the
/// run, composed from state alone.
///
/// A value, not a view model: the composer builds it once per week and the
/// page only lays it out, so two renders of the same state are the same
/// page and a unit test can read the paper without a screen.
struct NewspaperIssue: Identifiable, Equatable {
    /// 1-based week of the run this issue covers (week 1 = days 0…6).
    let week: Int
    /// The days the issue reports on. Shorter than seven for the week
    /// still in progress.
    let dayRange: ClosedRange<Int>
    /// The day the issue went to print: the Monday after the week, or
    /// today for the week in progress.
    let publishedDay: Int
    /// Whether the week is still being lived. The masthead says so.
    let isInProgress: Bool

    /// The paper's name, in the bitmap face.
    let masthead: String
    /// "Monday, March 12, Year 1".
    let dateline: String
    /// "Vol. 1 · No. 10".
    let edition: String

    /// The story above the fold.
    let lead: Story
    /// What the competition did this week.
    let rivalColumn: Column
    /// Booms, crashes and the forward book.
    let marketColumn: Column
    /// The quiet events, one strip along the bottom.
    let smallPrint: [String]

    // MARK: Iteration 11 — N4 (fame and the feed)

    /// The beef column: what the founder said in public this week and who
    /// answered. `nil` in every week nothing was posted, which is every
    /// week of every run that never opened the feed — so the page is
    /// exactly the page it was.
    let beefColumn: Column?

    // MARK: end of Iteration 11 — N4
    /// The office, as it stood that week.
    let photo: Photo

    var id: Int { week }

    /// The lead story: a kicker naming the strand, a headline short
    /// enough for the bitmap face, and a deck under it that says something
    /// the headline did not — never the sentence the headline was
    /// compressed from.
    struct Story: Equatable {
        let kicker: String
        let headline: String
        let body: String
        let day: Int
        let severity: EventSeverity
        /// The SF Symbol the journal draws for the event.
        let icon: String
    }

    /// A titled column of short lines.
    struct Column: Equatable {
        let title: String
        let lines: [String]
    }

    /// One frame of the office scene, plus its caption. The scene input
    /// is the same value the office card feeds `OfficeSceneView`, cut down
    /// to the people who were there that week.
    struct Photo: Equatable {
        let scene: OfficeSceneInput
        let caption: String
        /// Scene time the frame is taken at, so a page renders the same
        /// frame every time.
        let moment: TimeInterval
    }
}

/// Composes the weekly front page from `eventLog`, the market, the rivals
/// and the office.
///
/// Pure: a function of the state it is handed, the content catalog and the
/// balance. No RNG, no clock. The copy comes through `EventCopy`, so an
/// event reads on the front page exactly as it reads in the journal.
struct NewspaperComposer {
    let state: GameState
    let content: ContentCatalog
    let balance: BalanceConfig

    /// How many issues stay on the newsstand.
    static let issueCount = 4
    /// The paper's name. One paper for the whole industry, so the masthead
    /// never changes under the player.
    static let masthead = "THE DAILY BUILD"

    private var copy: EventCopy {
        EventCopy(state: state, content: content, balance: balance)
    }

    // MARK: - Which weeks

    /// The most recent week with an issue: the last completed week, or
    /// week 1 while the first is still under way.
    var latestWeek: Int { max(1, state.day / 7) }

    /// The weeks on the newsstand, oldest first.
    var availableWeeks: [Int] {
        Array(max(1, latestWeek - Self.issueCount + 1)...latestWeek)
    }

    /// The last four issues, oldest first.
    func issues() -> [NewspaperIssue] {
        let days = state.eventLog.map(EventDay.of)
        return availableWeeks.map { issue(forWeek: $0, eventDays: days) }
    }

    /// The front page for one week of the run.
    func issue(forWeek week: Int) -> NewspaperIssue {
        issue(forWeek: week, eventDays: state.eventLog.map(EventDay.of))
    }

    // MARK: - One issue

    private func issue(forWeek week: Int, eventDays: [Int]) -> NewspaperIssue {
        let start = max(0, (week - 1) * 7)
        let fullEnd = start + 6
        let end = min(fullEnd, max(start, state.day))
        let range = start...end
        let inProgress = state.day < fullEnd + 1
        let publishedDay = inProgress ? state.day : fullEnd + 1

        let events: [Dated] = zip(state.eventLog, eventDays)
            .filter { range.contains($0.1) }
            .map { Dated(event: $0.0, day: $0.1, line: copy.line(for: $0.0), category: copy.category(of: $0.0)) }

        let (lead, leadSource) = leadStory(from: events, week: week)
        let isLatest = week == latestWeek

        return NewspaperIssue(
            week: week,
            dayRange: range,
            publishedDay: publishedDay,
            isInProgress: inProgress,
            masthead: Self.masthead,
            dateline: dateline(day: publishedDay),
            edition: edition(weekStarting: start),
            lead: lead,
            rivalColumn: rivalColumn(from: events),
            marketColumn: marketColumn(from: events, includeForecast: isLatest),
            // MARK: J5 (announce) — the latest issue prints every standing date.
            smallPrint: smallPrint(from: events, excluding: leadSource)
                + (isLatest ? announceDates() : []),
            // MARK: end J5
            // MARK: Iteration 11 — N4 (fame and the feed)
            beefColumn: beefColumn(in: range),
            // MARK: end of Iteration 11 — N4
            photo: photo(endingDay: end, lead: lead, isLatest: isLatest)
        )
    }

    /// One event with everything the page needs to place it.
    private struct Dated {
        let event: GameEvent
        let day: Int
        let line: EventLine
        let category: JournalCategory

        var severity: EventSeverity { event.severity }
    }

    // MARK: - Dateline

    private static let weekdayNames = [
        "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday",
    ]

    private func dateline(day: Int) -> String {
        let calendar = GameCalendar(day: day)
        let weekday = Self.weekdayNames[(calendar.dayOfWeek - 1) % 7]
        return "\(weekday), \(calendar.monthName) \(calendar.dayOfMonth), Year \(calendar.year)"
    }

    /// The volume is the year and the number is the week *covered*, so
    /// the issue for week 1 is No. 1 even though it prints in week 2.
    private func edition(weekStarting start: Int) -> String {
        let calendar = GameCalendar(day: start)
        return "Vol. \(calendar.year) · No. \(calendar.weekOfYear)"
    }

    // MARK: - The lead

    /// The loudest thing that happened to the company: the company's own
    /// strands (company, team) first, by severity and then recency; only
    /// a week with nothing of its own leads with the world's news, which
    /// otherwise stays in its columns. A week with nothing worth a
    /// headline gets the quiet-week story rather than a blank.
    // l10n: NOT LOCALIZED, deliberately (R9, iteration 7). The composer does
    // not write copy - it selects an `EventCopy` line and compresses it into a
    // headline (`Headline.compress`, which uppercases and drops stop words).
    // So it localizes only after EventCopy does, and then as
    //   "news.lead.headline" = "%@" / "news.lead.body" = "%@"
    // over already-localized strings, plus per-column kickers
    // ("news.kicker.company" = "THE COMPANY") - which the bitmap face can only
    // draw in A-Z. Wave 2.
    ///
    /// Returns the story and the event's own line, which the small print
    /// needs to leave out — the body is no longer that line, so equality
    /// on it would print the lead twice.
    private func leadStory(from events: [Dated], week: Int) -> (NewspaperIssue.Story, String?) {
        let newsworthy = events.filter {
            !Self.isRoutine($0.event) && !Self.isDrumbeat($0.event) && $0.category != .life
        }
        let own = newsworthy.filter { $0.category == .company || $0.category == .team }
        let candidates = own.isEmpty ? newsworthy : own
        let best = candidates.enumerated().max { lhs, rhs in
            let l = leadRank(lhs.element), r = leadRank(rhs.element)
            if l != r { return l < r }
            return lhs.offset < rhs.offset
        }
        guard let best else {
            return (quietWeekStory(week: week), nil)
        }
        let dated = best.element
        return (
            NewspaperIssue.Story(
                kicker: kicker(for: dated.category),
                headline: Headline.compress(dated.line.message),
                body: leadBody(for: dated),
                day: dated.day,
                severity: dated.severity,
                icon: dated.line.icon
            ),
            dated.line.message
        )
    }

    /// The sub-line under the headline.
    ///
    /// It used to be the journal's sentence — the *same* sentence the
    /// headline was compressed from, so the front page said one thing
    /// twice ("Reviews are in for Overcast" / "Reviews are in for
    /// Overcast: 72"). A newspaper's deck adds something the headline did
    /// not have: the rest of the copy when there is any, and otherwise the
    /// day's numbers, which is what a reader would ask next.
    private func leadBody(for dated: Dated) -> String {
        Self.afterTheFirstSentence(dated.line.message) ?? numbersLine(for: dated)
    }

    /// Everything after the first sentence of `message`, or `nil` when the
    /// copy is a single sentence (most of it is) or the remainder is too
    /// thin to set as a paragraph.
    static func afterTheFirstSentence(_ message: String) -> String? {
        var cut: String.Index?
        for terminator in [". ", "! ", "? "] {
            guard let range = message.range(of: terminator) else { continue }
            if cut.map({ range.upperBound < $0 }) ?? true { cut = range.upperBound }
        }
        guard let cut else { return nil }
        let rest = message[cut...].trimmingCharacters(in: .whitespaces)
        guard rest.split(separator: " ").count >= 3 else { return nil }
        return rest
    }

    /// The day's money, and where the company stood at the end of it: the
    /// deck for a headline whose copy is one sentence long.
    private func numbersLine(for dated: Dated) -> String {
        let entries = state.ledger.entries.filter { $0.day == dated.day }
        let inflow = entries.filter { $0.amount > 0 }.reduce(0) { $0 + $1.amount }
        let outflow = entries.filter { $0.amount < 0 }.reduce(0) { $0 - $1.amount }
        var parts: [String] = []
        if inflow > 0 { parts.append("+\(inflow.money) in") }
        if outflow > 0 { parts.append("−\(outflow.money) out") }
        parts.append("\(state.company.cash.money) in the account")
        parts.append("reputation \(Int(state.company.reputation.rounded()))")
        return "Day \(dated.day): " + parts.joined(separator: " · ")
    }

    /// Severity in tens, the company's own strands in ones: a notable
    /// company event beats an info team event, and a critical anything
    /// beats both.
    private func leadRank(_ dated: Dated) -> Int {
        let severity: Int = switch dated.severity {
        case .quiet: 0
        case .info: 1
        case .notable: 2
        case .critical: 3
        }
        let strand: Int = switch dated.category {
        case .company: 2
        case .team: 1
        case .market, .rivals, .life: 0
        }
        // MARK: Iteration 10 — M2 (pitch room)
        // An interview the founder actually gave is the week's lead: it
        // is the one event on this page they sat in a room and earned.
        // A conversation that went nowhere gets no boost, which keeps a
        // week the player did not engage with ranked exactly as before.
        if case let .pitchClosed(counterpart, band, _, _) = dated.event,
           counterpart == PitchCounterpart.journalist.rawValue,
           PitchBand(rawValue: band)?.isGood == true {
            return severity * 10 + strand + 25
        }
        // MARK: end of Iteration 10 — M2
        // MARK: J5 (announce)
        // A missed date is the lead whatever else happened that week; a
        // date told to the press is front-page news the week it is told.
        switch dated.event {
        case .announceSlipped: return severity * 10 + strand + 25
        case .announceMade: return severity * 10 + strand + 15
        default: break
        }
        // MARK: end J5
        // MARK: K4 (deals and exits)
        // The paper leads with a company for sale: the sign going up, a
        // bid it brought, the paper deal and the sell-up.
        switch dated.event {
        case .dealListed, .dealSoldUp: return severity * 10 + strand + 25
        case .dealPaperSigned: return severity * 10 + strand + 20
        case .buyoutOffered where state.rivals.listing != nil: return severity * 10 + strand + 15
        case .dealSignTakenDown: return severity * 10 + strand + 10
        default: break
        }
        // MARK: end K4
        // MARK: K2 (product lifecycle)
        // A v2 replacing its parent is the week's product news; a
        // retirement, a rise or a sale is news too — a price change the
        // paper prints is a price change the customers read.
        switch dated.event {
        case .lifecycleReplaced: return severity * 10 + strand + 15
        case .lifecycleSunset, .lifecyclePriceMoved: return severity * 10 + strand + 10
        default: break
        }
        // MARK: end K2
        return severity * 10 + strand
    }

    private func quietWeekStory(week: Int) -> NewspaperIssue.Story {
        let company = state.company.name
        let body = week == 1 && state.eventLog.isEmpty
            ? "\(company) opened its doors this week. Nobody has heard of it yet, which is the plan."
            : "Nothing at \(company) made the front page this week. The team kept building, which is the plan."
        return NewspaperIssue.Story(
            kicker: "Company",
            headline: Headline.compress("A quiet week at \(company)"),
            body: body,
            day: state.day,
            severity: .quiet,
            icon: "moon.zzz.fill"
        )
    }

    private func kicker(for category: JournalCategory) -> String {
        category.displayName
    }

    // MARK: - Columns

    /// The rival events of the week, then the standing of the field. An
    /// empty board says so.
    private func rivalColumn(from events: [Dated]) -> NewspaperIssue.Column {
        var lines = events
            .filter { $0.category == .rivals && !Self.isRoutine($0.event) }
            .map(\.line.message)
        lines = Array(unique(lines).prefix(3))

        if lines.count < 3 {
            let field = state.rivals.rivals.sorted { $0.strength > $1.strength }
            if let incumbent = state.rivals.incumbent {
                lines.append("\(incumbent.name) is still camped in your best markets.")
            } else if let leader = field.first {
                let count = field.count
                lines.append(
                    count == 1
                        ? "\(leader.name) is the only other studio in town."
                        : "\(leader.name) leads a field of \(count)."
                )
            } else {
                lines.append("No rival studios on the board yet.")
            }
        }
        return NewspaperIssue.Column(title: "Rivals", lines: lines)
    }

    /// Booms and crashes first, then — for the issue on the stands — the
    /// forward book in the categories the studio holds. A week with no
    /// movement says the markets held.
    private func marketColumn(from events: [Dated], includeForecast: Bool) -> NewspaperIssue.Column {
        var lines = events
            .filter { $0.category == .market && !Self.isRoutine($0.event) }
            .filter {
                if case .industryNews = $0.event { return false }
                return true
            }
            .map(\.line.message)
        lines = Array(unique(lines).prefix(3))

        if includeForecast {
            let threshold = balance.market.driftSigma / 2
            let held = state.market.standing.keys.sorted().compactMap { topicID -> String? in
                guard let forecast = state.market.forecast(for: topicID, market: balance.market),
                      let topic = content.topic(topicID)
                else { return nil }
                let verb = switch forecast.lean(threshold: threshold) {
                case .warming: "warming"
                case .cooling: "cooling"
                case .steady: "steady"
                }
                let band = forecast.expected.formatted(.number.precision(.fractionLength(2)).locale(Theme.gameLocale))
                return "\(topic.name) looks \(verb): ×\(band) in \(forecast.weeksAhead) weeks."
            }
            lines.append(contentsOf: held.prefix(2))
            // MARK: J3 (rivals and the market)
            // Who is moving into a category the studio holds. Empty until
            // the market board has been opened; the moves themselves reach
            // the column above as market events.
            let threshold12 = balance.market.standing.forecastThreshold
            let circling = state.market.standing.keys.sorted().compactMap { topicID -> String? in
                guard state.market.holdsCategory(topicID, above: threshold12),
                      let topic = content.topic(topicID),
                      let entrant = RivalMarket.circling(topicID: topicID, state: state)
                          .first(where: { $0.reason == .boom && !$0.isSelling })
                else { return nil }
                return "\(entrant.name) is circling \(topic.name) and has not shipped yet."
            }
            lines.append(contentsOf: circling.prefix(1))
            // MARK: end J3
        }

        if lines.isEmpty {
            lines.append("Markets held steady. Nothing boomed, nothing crashed.")
        }
        return NewspaperIssue.Column(title: "Market", lines: lines)
    }

    // MARK: Iteration 11 — N4 (fame and the feed)

    /// The beef column. Everything the founder put in public inside the
    /// week — the posts that travelled, the rival who answered, the old
    /// line somebody dug up — plus one headline from `Feed.json` that
    /// says what the trade made of it.
    ///
    /// Returns `nil` when nothing was posted in the week, and the page
    /// simply has no such column. So a run that never opened the feed
    /// prints the paper it printed before this lane existed, byte for
    /// byte, and a run that did gets a column that is only ever about
    /// things the player chose to say.
    private func beefColumn(in range: ClosedRange<Int>) -> NewspaperIssue.Column? {
        let posts = state.fame.posts
            .filter { range.contains($0.day) }
            .sorted { ($0.day, $0.id) > ($1.day, $1.id) }
        guard !posts.isEmpty else { return nil }

        var lines: [String] = []
        // The week's loudest post, quoted.
        if let loudest = posts.max(by: { $0.reach < $1.reach }) {
            let reach = FeedFormat.count(loudest.reach)
            lines.append(loudest.viral
                ? "“\(loudest.text)” — \(reach) saw it, which nobody planned."
                : "“\(loudest.text)” — \(reach) reached.")
        }
        // Who answered.
        if let beef = state.fame.beef {
            lines.append(beef.waitingOnYou
                ? "\(beef.rivalName) answered, at round \(beef.rounds), and is waiting."
                : "\(beef.rivalName) and \(state.company.name) are at round \(beef.rounds).")
        } else if let subtweet = posts.first(where: { !$0.subject.isEmpty }) {
            lines.append("\(subtweet.subject) has not replied, which is its own reply.")
        }
        // The archive, if it opened this week.
        if let cancellation = state.fame.cancellation, range.contains(cancellation.raisedDay) {
            lines.append("An older line resurfaced: “\(cancellation.quote)”")
        }
        // And what the trade made of it.
        if let headline = fameHeadline(hasBeef: state.fame.beef != nil) {
            lines.append(headline)
        }
        return NewspaperIssue.Column(title: "The feed", lines: Array(lines.prefix(4)))
    }

    /// One `Feed.json` headline for the week, picked without a draw: the
    /// beef strand while there is a beef, otherwise the highest fame
    /// headline the founder has earned. Deterministic, because the paper
    /// is composed fresh every time it is opened.
    private func fameHeadline(hasBeef: Bool) -> String? {
        let catalog = content.feedCatalog
        let level = Fame.level(state.fame.fame, balance: balance.fame)
        let strand = hasBeef ? "beef" : "fame"
        let pool = catalog.headlines.filter {
            $0.strand == strand && $0.minLevel <= level.rawValue
        }
        guard let def = pool.max(by: { $0.minLevel < $1.minLevel }) else { return nil }
        return Fame.fill(
            def.text, state: state, rival: state.fame.beef?.rivalName ?? ""
        )
        .replacingOccurrences(
            of: "{followers}", with: FeedFormat.count(state.fame.followers)
        )
    }

    // MARK: end of Iteration 11 — N4

    // MARK: - Small print

    /// The quiet events, oldest first, that did not make the lead. The
    /// industry drumbeat lands here too.
    private func smallPrint(from events: [Dated], excluding leadMessage: String?) -> [String] {
        let quiet = events.filter { dated in
            switch dated.severity {
            case .quiet, .info: break
            case .notable, .critical: return false
            }
            if case .networkingTalk = dated.event { return false }
            return dated.line.message != leadMessage
        }
        let lines = quiet.map { dated -> String in
            var message = dated.line.message
            if message.hasPrefix("Weekend: ") {
                message = "Weekend spent on " + message.dropFirst("Weekend: ".count).lowercased()
            }
            return message
        }
        return Array(unique(lines).prefix(6))
    }

    // MARK: J5 (announce)

    /// Every standing ship date, in the paper's own hand: the date is a
    /// promise the paper remembers. Empty for a run that never announced.
    private func announceDates() -> [String] {
        state.announcedBuilds.compactMap { product in
            guard let date = product.announcedDay else { return nil }
            let left = date - state.day
            let when = AnnounceEventPresenter.dateLabel(date, today: state.day)
            let slipped = product.slips > 0 ? " (the second date)" : ""
            return left <= 0
                ? "\(product.name) is due today\(slipped). We will be checking."
                : "\(product.name) is promised for \(when)\(slipped), \(left) day\(left == 1 ? "" : "s") away."
        }
    }

    // MARK: end J5

    // MARK: - The photo

    /// The office at the end of the week: the tier, the amenities, and
    /// everyone who had been hired by then at their desks. The hour is the
    /// week's own — dusk after a critical week, night on crunch, day
    /// otherwise — and the weather is the season's.
    private func photo(endingDay day: Int, lead: NewspaperIssue.Story, isLatest: Bool) -> NewspaperIssue.Photo {
        let tier = OfficeTierStyle(rawValue: state.company.officeTier.rawValue) ?? .garage
        let calendar = GameCalendar(day: day)
        let weather: Weather = switch calendar.season {
        case .winter: .snow
        case .autumn: .rain
        case .spring, .summer: .clear
        }
        let onCrunch = isLatest && state.economy.workPace == .crunch
        let hour: TimeOfDay = onCrunch ? .night : (lead.severity == .critical ? .dusk : .day)

        let staff = state.employees.filter { $0.isFounder || $0.hiredDay <= day }
        let morale = staff.filter { !$0.isFounder }
        let average = morale.isEmpty ? 60.0 : morale.reduce(0) { $0 + $1.morale } / Double(morale.count)
        let mood: MoodLevel = switch average {
        case ..<38: .low
        case ..<70: .okay
        default: .great
        }

        let occupants = staff
            .sorted { lhs, rhs in
                if lhs.isFounder != rhs.isFounder { return lhs.isFounder }
                return lhs.hiredDay < rhs.hiredDay
            }
            .map { employee in
                Occupant(
                    id: employee.id,
                    appearance: CharacterAppearance(seed: employee.appearanceSeed),
                    status: Self.status(for: employee),
                    isFounder: employee.isFounder,
                    mood: mood,
                    role: employee.isFounder ? .founder : (RoleLook(rawValue: employee.role.rawValue) ?? .none),
                    name: employee.name
                )
            }

        var scene = OfficeSceneInput(
            tier: tier,
            occupants: occupants,
            amenities: Set(state.amenities.compactMap { AmenityStyle(rawValue: $0.rawValue) }),
            ambience: OfficeAmbience(timeOfDay: hour, weather: weather, isWeekend: false, teamMood: mood)
        )
        // A photograph is a still: everybody is where they sit.
        scene.reduceMotion = true
        // MARK: S1 (seating) — where the player seated them; nothing with no plan.
        if state.seatingIsSet { scene.seats = state.seatingPlan() }
        // MARK: end S1

        let count = occupants.count
        let place = "The \(state.company.officeTier.displayName.lowercased()), "
            + "\(calendar.shortMonthName) \(calendar.dayOfMonth)"
        let who = count == 1 ? "the founder alone at the desk" : "\(count) at their desks"
        let spirits: String = switch mood {
        case .great: "Spirits high."
        case .okay: "Heads down."
        case .low: "A long week."
        }
        let caption = "\(place): \(who). \(spirits)"

        // Twenty seconds in: the monitors are on, the first cup is poured.
        return NewspaperIssue.Photo(scene: scene, caption: caption, moment: 20)
    }

    /// A still photograph needs a pose, not a plan: the role's own desk
    /// pose, idle when they have nothing on.
    private static func status(for employee: Employee) -> WorkStatus {
        if case .idle = employee.assignment { return .idle }
        return switch employee.role {
        case .qa: .testing
        case .designer: .designing
        case .marketer: .marketing
        case .lawyer: .legal
        case .hr: .peopleOps
        case .ops: .operations
        case .frontend, .backend: .coding
        case .founder: employee.skills.coding >= employee.skills.design ? .coding : .designing
        }
    }

    // MARK: - Helpers

    /// Weekends, errands and small talk: real, but not news.
    static func isRoutine(_ event: GameEvent) -> Bool {
        switch event {
        case .weekendSpent, .instantActivityDone, .itemPurchased, .networkingTalk:
            true
        default:
            false
        }
    }

    /// The weekly refresh notices: small print, never a headline. A week
    /// in which the only company news is that the phone rang is a quiet
    /// week, and the page should say so.
    static func isDrumbeat(_ event: GameEvent) -> Bool {
        switch event {
        case .candidatesRefreshed, .contractOffersRefreshed:
            true
        default:
            false
        }
    }

    private func unique(_ lines: [String]) -> [String] {
        var seen: Set<String> = []
        return lines.filter { seen.insert($0).inserted }
    }
}

// MARK: - Headlines

/// Turns a journal sentence into a front-page headline the bitmap face can
/// set: the first clause, in the glyphs the font has.
///
/// "Priya quit — morale hit rock bottom" becomes "Priya quit"; "Reviews
/// are in for Overcast: 72" becomes "Reviews are in for Overcast". The
/// page uppercases it; this only decides where the sentence stops.
enum Headline {
    /// The longest headline worth setting at scale 3 on a phone.
    static let maxLength = 44

    static func compress(_ message: String) -> String {
        var text = message
            .replacingOccurrences(of: "—", with: " - ")
            .replacingOccurrences(of: "–", with: " - ")
            .replacingOccurrences(of: "’", with: "'")
            .replacingOccurrences(of: "‘", with: "'")
            .replacingOccurrences(of: "…", with: "...")

        // The first clause: up to a dash, a colon, or the end of the first
        // sentence.
        for separator in [" - ", ": ", ". ", "! ", "? ", ", and "] {
            if let range = text.range(of: separator) {
                let keepsBang = separator == "! "
                text = String(text[..<range.lowerBound]) + (keepsBang ? "!" : "")
            }
        }

        // Only glyphs the face has. Anything else would draw as a box.
        let kept = text.filter { PixelFont.hasGlyph(for: $0) }
        var words = kept
            .split(separator: " ", omittingEmptySubsequences: true)
            .map(String.init)

        // Trailing full stops read as a typo in a headline.
        if var last = words.last, last.hasSuffix(".") {
            while last.hasSuffix(".") { last.removeLast() }
            if last.isEmpty { words.removeLast() } else { words[words.count - 1] = last }
        }

        // Trim to the length the face can carry, on a word boundary.
        var headline = ""
        for word in words {
            let candidate = headline.isEmpty ? word : headline + " " + word
            if candidate.count > maxLength, !headline.isEmpty { break }
            headline = candidate
        }
        return headline.isEmpty ? "News" : headline
    }
}
