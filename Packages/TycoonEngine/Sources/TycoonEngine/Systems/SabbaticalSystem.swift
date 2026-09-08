import Foundation
import TycoonContent

/// Iteration 9 — L6. The founder hands the company to somebody they trust
/// and goes away for a month or a summer.
///
/// Three things happen while they are gone, and none of them happen at all
/// when `state.life.sabbatical` is nil or finished — which is every run
/// that never takes one, so this file is exactly neutral by construction:
///
/// 1. **The founder recovers.** Health, energy, mood and the partner's
///    affection all move the right way, faster than a weekend ever does.
///    The founder's *output* is already zero: `awayUntilDay` is the
///    engine's existing "signed off" flag and every system that asks
///    `life.isAway` answers it the same way it does for a hospital stay.
/// 2. **The caretaker runs it.** Once a week, at most, they make one call
///    — ship, hire, start the next build, teach somebody something, or
///    tell the room it did well — and the call is a real `GameAction`
///    applied through `Reducer.apply`, so the ledger, the journal and the
///    event log record it exactly as they would have recorded the
///    founder's. Which decision it is comes from their revealed traits.
/// 3. **The phone buzzes.** One line a day to the `.office` thread, and
///    the decisions accumulate into a `SabbaticalReport` the founder reads
///    when they land.
///
/// **Double-logging.** `Reducer.apply` calls `state.logEvents` itself, so
/// every event a caretaker decision produces is already in the log by the
/// time `apply` returns. This system therefore **returns those events to
/// nobody**: `decide` discards `apply`'s return value and `run` returns
/// only the events it raises itself (`.founderAway`, `.founderBack`,
/// `.employeeQuit` and friends), which `Reducer.tick` logs once. The
/// consequence to know: a caretaker's ship does not enter the day's
/// `events` array, so it cannot pause the timeline. That is deliberate —
/// the player is on a beach, and a sabbatical that stops the clock every
/// week is not a sabbatical.
///
/// **Draws.** One or two uniforms from `state.socialRNG` on a decision day
/// (never on any other day, never from `rng` or `worldRNG`). The one
/// exception is `ProductSystem.startProduct`, which mints the product's id
/// from `rng` the way it does for every product anybody has ever started;
/// a caretaker starting a build is a player action taken by proxy, and it
/// draws where a player action draws.
enum SabbaticalSystem {
    /// The reason string on `life.awayReason` while a sabbatical runs.
    /// The office and home scenes already read it.
    static let awayReason = "Sabbatical"

    // MARK: - Daily

    @Sendable
    static func run(
        _ state: inout GameState,
        _ balance: BalanceConfig,
        _ content: ContentCatalog
    ) -> [GameEvent] {
        guard let current = state.life.sabbatical, current.isActive else { return [] }
        let config = balance.sabbatical

        // The trip is over. `LifeSystem` ran first and has already cleared
        // the away window and raised `.founderBack`, so all that is left is
        // the sheet the founder reads on the plane home.
        if state.day >= current.untilDay {
            finish(&state, balance: balance, endedEarly: false, reason: nil)
            return []
        }

        // The caretaker walked out from under it (poached, quit in the
        // daily sweep, fired by a life event). The founder comes home.
        guard let caretaker = state.employee(id: current.caretakerID), !caretaker.isFounder else {
            var sabbatical = current
            sabbatical.note(
                "Your caretaker is gone. You booked the first flight back.",
                day: state.day, isDecision: false
            )
            sabbatical.lost.append(current.caretakerName)
            state.life.sabbatical = sabbatical
            state.life.phone.post(
                "\(current.caretakerName) is gone. Somebody should probably call you.",
                from: .office, day: state.day
            )
            return comeHome(&state, balance: balance, reason: "\(current.caretakerName) left")
        }

        var events: [GameEvent] = []

        // 1. What a month off actually does.
        state.life.meters.apply(
            energy: config.energyPerDay,
            health: config.healthPerDay,
            mood: config.moodPerDay
        )
        if state.life.family.stage != .single {
            state.life.family.affection = min(
                100, state.life.family.affection + config.affectionPerDay
            )
        }

        // 2. A Grumbler in charge is a room nobody is tidying.
        if caretaker.traits.contains("grumbler"), config.grumblerMoralePerDay != 0 {
            for index in state.employees.indices
            where !state.employees[index].isFounder
                && state.employees[index].id != caretaker.id {
                state.employees[index].morale = max(
                    0, state.employees[index].morale + config.grumblerMoralePerDay
                )
            }
        }

        // 3. The week's one call.
        var line: String?
        var sabbatical = state.life.sabbatical ?? current
        if state.day - sabbatical.lastDecisionDay >= config.decisionIntervalDays {
            sabbatical.lastDecisionDay = state.day
            state.life.sabbatical = sabbatical
            let outcome = decide(
                caretaker: caretaker, state: &state, balance: balance, content: content
            )
            events.append(contentsOf: outcome.events)
            line = outcome.line
            // `decide` writes through `state.life.sabbatical`; re-read it
            // rather than clobbering it with the copy taken above.
            sabbatical = state.life.sabbatical ?? sabbatical
            if outcome.endedTrip {
                return events
            }
        }

        // 4. The daily one-liner.
        state.life.phone.post(
            line ?? weather(caretaker: caretaker, state: state, sabbatical: sabbatical),
            from: .office, day: state.day
        )
        state.life.sabbatical = sabbatical
        return events
    }

    // MARK: - The caretaker's week

    private struct Outcome {
        var line: String?
        var events: [GameEvent] = []
        /// The decision ended the sabbatical (the caretaker walked).
        var endedTrip = false
    }

    /// One call, chosen by the caretaker's traits and the state of the
    /// company, applied as an ordinary player action.
    ///
    /// The ladder, in order: a build that is finished enough ships; a
    /// Flight Risk might not be here to see it; a hire when the runway is
    /// long and the dice say so; the next build when the bench is idle; a
    /// course for whoever is furthest behind (a Mentor's first instinct);
    /// and, failing all of that, telling somebody they did well, which is
    /// free and is what a caretaker mostly does.
    private static func decide(
        caretaker: Employee,
        state: inout GameState,
        balance: BalanceConfig,
        content: ContentCatalog
    ) -> Outcome {
        let config = balance.sabbatical
        let name = caretaker.name
        let roll = state.socialRNG.nextUniform()

        // The one they had been half-listening to.
        if caretaker.traits.contains("flightRisk"), roll < config.flightRiskLeaveChance {
            return leave(caretaker, state: &state, balance: balance)
        }

        // Ship.
        let shipFactor = caretaker.traits.contains("speedster")
            ? config.speedsterShipFactor
            : config.shipFactor
        if let product = shippable(state, balance: balance, content: content, factor: shipFactor) {
            _ = Reducer.apply(.ship(productID: product.id), to: &state, balance: balance, content: content)
            var sabbatical = state.life.sabbatical
            sabbatical?.shipped.append(product.name)
            sabbatical?.note("\(name) shipped \(product.name).", day: state.day, isDecision: true)
            state.life.sabbatical = sabbatical
            return Outcome(line: "\(name) shipped \(product.name) without you. It's out.")
        }

        // Hire.
        let payroll = state.employees.reduce(0) { $0 + $1.weeklySalary }
        if state.socialRNG.nextUniform() < config.hireChance,
           let candidate = state.candidatePool.max(by: { lhs, rhs in
               if lhs.skills.total != rhs.skills.total { return lhs.skills.total < rhs.skills.total }
               return lhs.id.uuidString > rhs.id.uuidString
           }),
           state.headcount < balance.office(state.company.officeTier).headcountCap,
           state.company.cash >= (payroll + candidate.weeklySalary) * config.hireRunwayWeeks {
            let before = state.headcount
            _ = Reducer.apply(.hire(candidateID: candidate.id), to: &state, balance: balance, content: content)
            if state.headcount > before {
                var sabbatical = state.life.sabbatical
                sabbatical?.hired.append(candidate.name)
                sabbatical?.note("\(name) hired \(candidate.name).", day: state.day, isDecision: true)
                state.life.sabbatical = sabbatical
                return Outcome(line: "\(name) hired \(candidate.name). You'll meet them when you land.")
            }
        }

        // Start the next one.
        if state.productInDevelopment == nil, state.hasFreeDevSlot,
           let pitch = nextBuild(state: &state, content: content) {
            let before = state.products.count
            _ = Reducer.apply(
                .startProduct(
                    typeID: pitch.typeID, topicID: pitch.topicID,
                    name: pitch.name, focus: .balanced
                ),
                to: &state, balance: balance, content: content
            )
            if state.products.count > before {
                var sabbatical = state.life.sabbatical
                sabbatical?.started.append(pitch.name)
                sabbatical?.note("\(name) started \(pitch.name).", day: state.day, isDecision: true)
                state.life.sabbatical = sabbatical
                return Outcome(line: "\(name) started something called \(pitch.name). Don't panic.")
            }
        }

        // Teach.
        if let student = weakest(state, excluding: caretaker.id),
           state.company.cash >= EmployeeSystem.trainingCost(state, balance),
           state.employees.first(where: { $0.id == student.id })?.lastTrainedDay
               .map({ state.day - $0 >= balance.staff.trainingCooldownDays }) ?? true {
            let skill = weakestSkill(student)
            _ = Reducer.apply(
                .train(employeeID: student.id, skill: skill),
                to: &state, balance: balance, content: content
            )
            // A Mentor teaches on top of the course they paid for.
            if caretaker.traits.contains("mentor"),
               let index = state.employees.firstIndex(where: { $0.id == student.id }) {
                grow(&state.employees[index], skill, by: config.mentorSkillGain)
            }
            var sabbatical = state.life.sabbatical
            sabbatical?.note(
                "\(name) put \(student.name) through a \(skill.rawValue) course.",
                day: state.day, isDecision: true
            )
            state.life.sabbatical = sabbatical
            return Outcome(line: "\(name) sent \(student.name) on a course. Billed to the company.")
        }

        // Say something nice.
        if let quietest = state.employees
            .filter({ !$0.isFounder && $0.id != caretaker.id })
            .min(by: { lhs, rhs in
                if lhs.morale != rhs.morale { return lhs.morale < rhs.morale }
                return lhs.id.uuidString < rhs.id.uuidString
            }),
           quietest.lastPraisedDay.map({ state.day - $0 >= balance.staff.praiseCooldownDays }) ?? true {
            _ = Reducer.apply(
                .praise(employeeID: quietest.id), to: &state, balance: balance, content: content
            )
            var sabbatical = state.life.sabbatical
            sabbatical?.note("\(name) told \(quietest.name) they were doing well.", day: state.day, isDecision: true)
            state.life.sabbatical = sabbatical
            return Outcome(line: "\(name): \"Told \(quietest.name) they're doing well. They are.\"")
        }

        return Outcome(line: nil)
    }

    /// The caretaker takes the call and goes. The run-ending version of
    /// "what happened while you were gone": the founder flies home to an
    /// empty chair, the sabbatical ends today, and the departure is a
    /// normal one — the same events, the same alumni entry, as any other
    /// person who leaves.
    private static func leave(
        _ caretaker: Employee,
        state: inout GameState,
        balance: BalanceConfig
    ) -> Outcome {
        guard let index = state.employees.firstIndex(where: { $0.id == caretaker.id }) else {
            return Outcome(line: nil)
        }
        let employee = state.employees.remove(at: index)
        state.economy.lastRecognitionDay[employee.id] = nil
        var events: [GameEvent] = [
            .employeeQuit(employeeID: employee.id, name: employee.name, day: state.day)
        ]
        events.append(contentsOf: SocialSystem.friendDeparted(
            employee.id, state: &state, balance: balance
        ))
        events.append(contentsOf: NetworkingSystem.departed(
            employee, reason: .poached, state: &state, balance: balance
        ))

        var sabbatical = state.life.sabbatical
        sabbatical?.lost.append(employee.name)
        sabbatical?.note(
            "\(employee.name) took a rival's call and took the job with it.",
            day: state.day, isDecision: true
        )
        state.life.sabbatical = sabbatical
        state.life.phone.post(
            "\(employee.name) resigned. They left the keys with reception.",
            from: .office, day: state.day
        )
        events.append(contentsOf: comeHome(
            &state, balance: balance, reason: "\(employee.name) left"
        ))
        return Outcome(line: nil, events: events, endedTrip: true)
    }

    // MARK: - Actions

    /// Hands the company to `caretakerID` for `weeks` and books the
    /// flights. Every gate is `GameState.sabbaticalBlocker` /
    /// `caretakerBlocker`, so the button and the engine cannot disagree.
    static func start(
        caretakerID: UUID,
        weeks: Int,
        state: inout GameState,
        balance: BalanceConfig,
        content: ContentCatalog
    ) -> [GameEvent] {
        guard let caretaker = state.employee(id: caretakerID),
              state.sabbaticalBlocker(weeks: weeks, balance: balance, content: content) == nil,
              state.caretakerBlocker(caretaker, balance: balance) == nil
        else { return [] }

        let config = balance.sabbatical
        let cost = weeks * config.weeklyCost
        let until = state.day + weeks * GameState.daysPerWeek

        state.life.wallet -= cost
        state.life.awayUntilDay = until
        state.life.awaySinceDay = state.day
        state.life.awayReason = awayReason

        var sabbatical = SabbaticalState(
            caretakerID: caretakerID,
            caretakerName: caretaker.name,
            sinceDay: state.day,
            untilDay: until,
            weeks: weeks,
            weeklyCost: config.weeklyCost,
            opening: SabbaticalSnapshot(state),
            lastDecisionDay: state.day
        )
        sabbatical.note(
            "You handed \(caretaker.name) the keys and left.", day: state.day, isDecision: true
        )
        state.life.sabbatical = sabbatical

        state.life.phone.post(
            "\(caretaker.name): \"Go. I've got it. I'll text you if the building is on fire.\"",
            from: .office, day: state.day
        )
        return [.founderAway(reason: awayReason, untilDay: until, day: state.day)]
    }

    // MARK: Iteration 11 — N1 (crime and the courtroom: the caretaker while inside)

    /// The reason string on `life.awayReason` while the founder is
    /// serving a sentence. The office and home scenes already read
    /// `awayReason`, so they say it without being told.
    static let prisonAwayReason = "Inside"

    /// A verdict takes the founder away for `weeks`.
    ///
    /// This is a sabbatical nobody booked: the same away window, the same
    /// caretaker autopilot, the same weekly decisions and the same report
    /// on the way out — because that machinery is exactly "somebody else
    /// runs the company while the founder is not there", and a sentence is
    /// that with the choice removed. What is different is written here:
    /// no flights, no weekly cost, no gates (a court does not ask whether
    /// you can afford to be away), and the caretaker is whoever the
    /// founder trusts most rather than whoever they picked. `CrimeSystem`
    /// adds what the absence *costs* — affection every day, board patience
    /// every week — because those are the sentence's, not the trip's.
    ///
    /// Wave two's *Inside* lane replaces the middle of this with a place.
    /// Until then the founder is away, and the company keeps going without
    /// them.
    ///
    /// Draws nothing.
    static func crimeBeginSentence(
        weeks: Int,
        state: inout GameState,
        balance: BalanceConfig
    ) -> [GameEvent] {
        let until = state.day + max(1, weeks) * GameState.daysPerWeek
        state.life.awayUntilDay = until
        state.life.awaySinceDay = state.day
        state.life.awayReason = prisonAwayReason

        // Whoever is left holding it: the most loyal person in the room.
        let caretaker = state.employees
            .filter { !$0.isFounder }
            .max { $0.founderBond < $1.founderBond }

        if let caretaker {
            var sabbatical = SabbaticalState(
                caretakerID: caretaker.id,
                caretakerName: caretaker.name,
                sinceDay: state.day,
                untilDay: until,
                weeks: max(1, weeks),
                weeklyCost: 0,
                opening: SabbaticalSnapshot(state),
                lastDecisionDay: state.day
            )
            sabbatical.note(
                "You did not hand \(caretaker.name) the keys. Somebody else did.",
                day: state.day, isDecision: true
            )
            state.life.sabbatical = sabbatical
            state.life.phone.post(
                "\(caretaker.name): \"I've got it. Don't worry about the building.\"",
                from: .office, day: state.day
            )
        } else {
            state.life.phone.post(
                "The office is dark. There was nobody to give the keys to.",
                from: .office, day: state.day
            )
        }
        state.life.phone.post(
            "I'll bring the children on the first weekend they allow it.",
            from: .partner, day: state.day
        )
        return [.founderAway(reason: prisonAwayReason, untilDay: until, day: state.day)]
    }

    // MARK: end of Iteration 11 — N1

    /// The founder cuts it short. Costs the caretaker's bond — being
    /// trusted and then checked on is worse than not being trusted — and
    /// refunds nothing: the weeks were paid for in advance.
    static func endEarly(
        state: inout GameState,
        balance: BalanceConfig
    ) -> [GameEvent] {
        guard let sabbatical = state.life.sabbatical, sabbatical.isActive else { return [] }
        if let index = state.employees.firstIndex(where: { $0.id == sabbatical.caretakerID }) {
            state.employees[index].founderBond = max(
                0, state.employees[index].founderBond - balance.sabbatical.earlyEndBondPenalty
            )
        }
        var updated = sabbatical
        updated.note("You came back early. Nobody said anything.", day: state.day, isDecision: true)
        state.life.sabbatical = updated
        state.life.phone.post(
            "You're back. \(sabbatical.caretakerName) had the desk cleared by lunchtime.",
            from: .office, day: state.day
        )
        return comeHome(&state, balance: balance, reason: "You came home early")
    }

    // MARK: - Ending it

    /// Clears the away window today and writes the report.
    private static func comeHome(
        _ state: inout GameState,
        balance: BalanceConfig,
        reason: String
    ) -> [GameEvent] {
        state.life.awayUntilDay = nil
        state.life.awaySinceDay = nil
        state.life.awayReason = nil
        finish(&state, balance: balance, endedEarly: true, reason: reason)
        return [.founderBack(day: state.day)]
    }

    /// Seals the trip: the closing snapshot, the report, `endedDay`. From
    /// here on the slot is a memory — `isActive` is false and nothing in
    /// this file reads it again.
    private static func finish(
        _ state: inout GameState,
        balance: BalanceConfig,
        endedEarly: Bool,
        reason: String?
    ) {
        guard var sabbatical = state.life.sabbatical, sabbatical.isActive else { return }
        sabbatical.endedDay = state.day
        sabbatical.report = SabbaticalReport(
            caretakerID: sabbatical.caretakerID,
            caretakerName: sabbatical.caretakerName,
            sinceDay: sabbatical.sinceDay,
            endedDay: state.day,
            weeks: sabbatical.weeks,
            endedEarly: endedEarly,
            earlyReason: reason,
            cost: sabbatical.totalCost,
            opening: sabbatical.opening,
            closing: SabbaticalSnapshot(state),
            started: sabbatical.started,
            shipped: sabbatical.shipped,
            hired: sabbatical.hired,
            lost: sabbatical.lost,
            log: sabbatical.log
        )
        state.life.sabbatical = sabbatical
        state.life.phone.post(
            endedEarly
                ? "You're home. \(sabbatical.report?.headline ?? "")"
                : "You're back tomorrow. \(sabbatical.report?.headline ?? "")",
            from: .office, day: state.day
        )
    }

    // MARK: - Small helpers

    /// A build finished enough for somebody who is not its author to press
    /// the button: the founder's own code gate, times `factor`.
    private static func shippable(
        _ state: GameState,
        balance: BalanceConfig,
        content: ContentCatalog,
        factor: Double
    ) -> Product? {
        state.productsInDevelopment.first { product in
            guard case .development(let dev) = product.stage,
                  let type = content.productType(product.typeID)
            else { return false }
            return dev.codePts >= balance.shipCodeThreshold * type.codePts * factor
        }
    }

    private struct Pitch {
        var typeID: String
        var topicID: String
        var name: String
    }

    /// What the caretaker starts: one of the three best type-and-topic
    /// pairings they can reach, picked with one `socialRNG` draw so two
    /// sabbaticals in the same run are not the same sabbatical.
    private static func nextBuild(state: inout GameState, content: ContentCatalog) -> Pitch? {
        var options: [(score: Double, typeID: String, topicID: String, name: String)] = []
        for type in content.productTypes
        where state.isProductTypeUnlocked(type.id, content: content) {
            for topic in content.topics where !state.isTopicLocked(topic.id) {
                let fit = topic.fitByType[type.id] ?? 1
                options.append((
                    score: fit * state.market.multiplier(for: topic.id),
                    typeID: type.id,
                    topicID: topic.id,
                    name: "\(topic.name) \(type.name)"
                ))
            }
        }
        guard !options.isEmpty else { return nil }
        options.sort { lhs, rhs in
            if lhs.score != rhs.score { return lhs.score > rhs.score }
            return (lhs.typeID, lhs.topicID) < (rhs.typeID, rhs.topicID)
        }
        let shortlist = Array(options.prefix(3))
        let pick = min(shortlist.count - 1, Int(state.socialRNG.nextUniform() * Double(shortlist.count)))
        let chosen = shortlist[pick]
        return Pitch(typeID: chosen.typeID, topicID: chosen.topicID, name: chosen.name)
    }

    private static func weakest(_ state: GameState, excluding id: UUID) -> Employee? {
        state.employees
            .filter { !$0.isFounder && $0.id != id }
            .min { lhs, rhs in
                if lhs.skills.total != rhs.skills.total { return lhs.skills.total < rhs.skills.total }
                return lhs.id.uuidString < rhs.id.uuidString
            }
    }

    private static func weakestSkill(_ employee: Employee) -> TrainableSkill {
        let skills = employee.skills
        if skills.coding <= skills.design, skills.coding <= skills.marketing { return .coding }
        if skills.design <= skills.marketing { return .design }
        return .marketing
    }

    private static func grow(_ employee: inout Employee, _ skill: TrainableSkill, by points: Double) {
        switch skill {
        case .coding: employee.skills.coding = min(100, employee.skills.coding + points)
        case .design: employee.skills.design = min(100, employee.skills.design + points)
        case .marketing: employee.skills.marketing = min(100, employee.skills.marketing + points)
        }
    }

    /// A quiet day, in four flavours, keyed off the day so it never draws.
    private static func weather(
        caretaker: Employee,
        state: GameState,
        sabbatical: SabbaticalState
    ) -> String {
        let left = sabbatical.daysLeft(from: state.day)
        let morale = state.employees.filter { !$0.isFounder }
        let average = morale.isEmpty
            ? 0
            : morale.reduce(0) { $0 + $1.morale } / Double(morale.count)
        switch (state.day - sabbatical.sinceDay) % 4 {
        case 0:
            return "\(caretaker.name): \"Quiet. Cash is $\(state.company.cash). Enjoy yourself.\""
        case 1:
            return "\(caretaker.name): \"Room's at \(Int(average.rounded())) morale. Nobody's asked where you are.\""
        case 2:
            return state.company.cash < 0
                ? "\(caretaker.name): \"We're in the red. I'm on it. Don't come back.\""
                : "\(caretaker.name): \"Nothing on fire. Photos, please.\""
        default:
            return "\(caretaker.name): \"\(left) day\(left == 1 ? "" : "s") left. Take them.\""
        }
    }
}
