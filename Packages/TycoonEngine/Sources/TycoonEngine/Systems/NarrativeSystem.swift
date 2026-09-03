import Foundation
import TycoonContent

/// The story generator.
///
/// One machine drives every narrative beat — company events, founder life
/// events and the follow-ups they schedule:
///
/// 1. **Eligibility.** A def is drawable when nothing is already pending,
///    it isn't a follow-up-only half of a storyline, it hasn't fired (for
///    `once` defs), its cooldown has expired, enough days have passed since
///    the last beat, and its `requires` gate reads true against the state.
/// 2. **Weighted pick** over the eligible defs, in catalog order.
/// 3. **Apply or ask.** With no choices the def's effects land immediately.
///    With choices the beat becomes `state.narrative.pendingChoice` and a
///    `.narrativeChoice` event pauses the timeline; the deadline answers
///    for a founder who never got back to it.
///
/// ### Determinism
///
/// The RNG budget is *identical to the pre-narrative engine for
/// pre-narrative content*: one `nextUniform()` hit roll on an interval day
/// with a non-empty catalog, then one `nextInt(in:)` weighted pick on a
/// hit. Everything the version-2 fields add — requirements, cooldowns,
/// flags, choices, follow-ups — is a pure function of the state. Only
/// `EmployeePick.random` effects draw, and only the defs that use them pay
/// for it. Industry news draws exclusively from `worldRNG`, and only when
/// `News.json` is non-empty, so it cannot shift the long-established `rng`
/// stream.
enum NarrativeSystem {

    // MARK: - Daily system

    /// Runs after every other system: retires expired cooldowns, answers a
    /// choice whose deadline passed, fires anything an earlier answer
    /// scheduled, and beats the industry-news drum.
    @Sendable
    static func run(
        _ state: inout GameState,
        _ balance: BalanceConfig,
        _ content: ContentCatalog
    ) -> [GameEvent] {
        var events: [GameEvent] = []
        events.append(contentsOf: autoResolveExpiredChoice(&state, balance, content))
        events.append(contentsOf: fireScheduled(&state, balance, content))
        events.append(contentsOf: rollIndustryNews(&state, balance, content))
        return events
    }

    // MARK: - Company events

    /// The company-event roll, called from `EventSystem` so it keeps its
    /// position (and its `rng` draw order) in the fixed system order.
    static func rollCompanyEvent(
        _ state: inout GameState,
        _ balance: BalanceConfig,
        _ content: ContentCatalog
    ) -> [GameEvent] {
        let narrative = balance.narrative
        let interval = narrative.companyEventIntervalDays ?? balance.eventCheckIntervalDays
        let chance = narrative.companyEventChance ?? balance.eventChance
        guard interval > 0, state.day % interval == 0, !content.events.isEmpty else { return [] }

        // 1. The hit roll — one word, exactly as before.
        guard state.rng.nextUniform() < chance else { return [] }

        guard canFireBeat(state, balance) else { return [] }
        let eligible = content.events.filter {
            isEligible($0.id, $0.requires, $0.once, $0.cooldownDays, $0.followUpOnly, state: state)
        }
        guard !eligible.isEmpty else { return [] }

        // 2. The weighted pick — one word, exactly as before.
        let picked = weightedPick(eligible, weight: { max(1, $0.weight) }, rng: &state.rng)

        // 3. Apply, or ask.
        return fireCompany(picked, state: &state, balance: balance)
    }

    /// Applies a company def: raises its choice sheet, or lands its
    /// effects and logs the headline.
    static func fireCompany(
        _ def: EventDef,
        state: inout GameState,
        balance: BalanceConfig
    ) -> [GameEvent] {
        markFired(def.id, once: def.once, cooldownDays: def.cooldownDays, state: &state, balance: balance)

        let options = availableOptions(def.choices, state: state, balance: balance)
        if !options.isEmpty {
            let respondBy = state.day + max(1, def.respondByDays)
            state.narrative.pendingChoice = PendingChoice(
                id: def.id,
                source: .company,
                title: def.headline,
                body: def.body ?? def.headline,
                options: options,
                respondByDay: respondBy,
                autoOptionIndex: autoIndex(def.autoChoiceIndex, among: options),
                category: def.category.rawValue,
                raisedDay: state.day
            )
            return [.narrativeChoice(eventID: def.id, respondByDay: respondBy, day: state.day)]
        }

        var events: [GameEvent] = [.randomEvent(eventID: def.id, day: state.day)]
        events.append(contentsOf: apply(
            def.unconditionalEffects, label: def.headline, state: &state, balance: balance
        ))
        return events
    }

    // MARK: - Life events

    /// The founder's life-event roll, called from `LifeEventSystem` so it
    /// keeps `LifeSystem`'s position in the draw order.
    static func rollLifeEvent(
        _ state: inout GameState,
        _ balance: BalanceConfig,
        _ content: ContentCatalog
    ) -> [GameEvent] {
        let narrative = balance.narrative
        let interval = narrative.lifeEventIntervalDays ?? balance.life.lifeEventIntervalDays
        let chance = narrative.lifeEventChance ?? balance.life.lifeEventChance
        guard interval > 0, state.day % interval == 0, !content.lifeEvents.isEmpty else { return [] }

        // 1. The hit roll — one word, exactly as before.
        guard state.rng.nextUniform() < chance else { return [] }

        guard canFireBeat(state, balance) else { return [] }
        let eligible = content.lifeEvents.filter { isEligible($0, state: state) }
        guard !eligible.isEmpty else { return [] }

        // 2. The weighted pick — one word, exactly as before.
        let picked = weightedPick(eligible, weight: { max(1, $0.weight) }, rng: &state.rng)

        // 3. Apply, or ask.
        return fireLife(picked, state: &state, balance: balance)
    }

    /// Applies a life def: raises its choice sheet, or lands its impact.
    static func fireLife(
        _ def: LifeEventDef,
        state: inout GameState,
        balance: BalanceConfig
    ) -> [GameEvent] {
        markFired(def.id, once: def.once, cooldownDays: def.cooldownDays, state: &state, balance: balance)

        let options = availableOptions(def.choices, state: state, balance: balance)
        if !options.isEmpty {
            let respondBy = state.day + max(1, def.respondByDays)
            state.narrative.pendingChoice = PendingChoice(
                id: def.id,
                source: .life,
                title: def.headline,
                body: def.body ?? def.headline,
                options: options,
                respondByDay: respondBy,
                autoOptionIndex: autoIndex(def.autoChoiceIndex, among: options),
                category: def.category.rawValue,
                raisedDay: state.day
            )
            return [.narrativeChoice(eventID: def.id, respondByDay: respondBy, day: state.day)]
        }

        var events: [GameEvent] = [.lifeEvent(eventID: def.id, day: state.day)]
        events.append(contentsOf: apply(
            def.unconditionalEffects, label: def.headline, state: &state, balance: balance
        ))
        // The cold and away windows ride on the version-1 impact.
        if def.impact.coldDays > 0 {
            state.life.coldUntilDay = state.day + def.impact.coldDays
        }
        if def.impact.awayDays > 0 {
            events.append(contentsOf: sendFounderAway(
                days: def.impact.awayDays,
                reason: def.impact.awayReason ?? def.headline,
                state: &state
            ))
        }
        return events
    }

    // MARK: - Answering

    /// The player's answer. Ignored when nothing is pending, when the id
    /// doesn't match what's on screen, when the index isn't offered, or
    /// when the option is offered greyed (WS-E) — the sheet never sends
    /// those, and the engine holds the line if something else does.
    static func resolveChoice(
        eventID: String,
        optionIndex: Int,
        state: inout GameState,
        balance: BalanceConfig,
        content: ContentCatalog
    ) -> [GameEvent] {
        guard let pending = state.narrative.pendingChoice, pending.id == eventID,
              pending.options.contains(where: { $0.index == optionIndex && $0.isEnabled })
        else { return [] }
        return resolve(pending, optionIndex: optionIndex, automatic: false,
                       state: &state, balance: balance, content: content)
    }

    /// The deadline answering for a founder who never did.
    private static func autoResolveExpiredChoice(
        _ state: inout GameState,
        _ balance: BalanceConfig,
        _ content: ContentCatalog
    ) -> [GameEvent] {
        guard let pending = state.narrative.pendingChoice, state.day > pending.respondByDay else {
            return []
        }
        let index = autoIndex(pending.autoOptionIndex, among: pending.options)
        return resolve(pending, optionIndex: index, automatic: true,
                       state: &state, balance: balance, content: content)
    }

    /// The option the deadline picks: the definition's choice when it is
    /// offered and open, else the last open option — a greyed option is
    /// never the silent answer, whatever the definition says.
    private static func autoIndex(_ preferred: Int?, among options: [ChoiceOption]) -> Int {
        if let preferred, options.contains(where: { $0.index == preferred && $0.isEnabled }) {
            return preferred
        }
        return options.last(where: \.isEnabled)?.index ?? options.last?.index ?? 0
    }

    private static func resolve(
        _ pending: PendingChoice,
        optionIndex: Int,
        automatic: Bool,
        state: inout GameState,
        balance: BalanceConfig,
        content: ContentCatalog
    ) -> [GameEvent] {
        state.narrative.pendingChoice = nil

        let choice: EventChoice?
        let unconditional: [EventEffect]
        let headline: String
        switch pending.source {
        case .company:
            let def = content.event(pending.id)
            choice = def.flatMap { optionIndex < $0.choices.count ? $0.choices[optionIndex] : nil }
            unconditional = def?.unconditionalEffects ?? []
            headline = def?.headline ?? pending.title
        case .life:
            let def = content.lifeEvent(pending.id)
            choice = def.flatMap { optionIndex < $0.choices.count ? $0.choices[optionIndex] : nil }
            unconditional = def?.unconditionalEffects ?? []
            headline = def?.headline ?? pending.title
        case .staff:
            // WS-D: a staff second act is answered through
            // `resolveStaffEvent`, not here. Scaffold: nothing to resolve.
            choice = nil
            unconditional = []
            headline = pending.title
        }
        guard let choice else {
            // The definition vanished under an old save: close the beat
            // rather than wedging the sheet open forever.
            return [.narrativeResolved(
                eventID: pending.id, optionID: "", automatic: automatic, day: state.day
            )]
        }

        var events: [GameEvent] = [
            pending.source == .company
                ? .randomEvent(eventID: pending.id, day: state.day)
                : .lifeEvent(eventID: pending.id, day: state.day)
        ]
        events.append(contentsOf: apply(
            unconditional, label: headline, state: &state, balance: balance
        ))
        events.append(contentsOf: apply(
            choice.effects, label: "\(headline) — \(choice.label)", state: &state, balance: balance
        ))
        for flag in choice.setFlags { state.narrative.flags.insert(flag) }
        for flag in choice.clearFlags { state.narrative.flags.remove(flag) }
        if let followUp = choice.followUpEventID {
            schedule(
                followUp, source: pending.source,
                day: state.day + max(1, choice.followUpDelayDays), state: &state
            )
        }
        events.append(.narrativeResolved(
            eventID: pending.id, optionID: choice.id, automatic: automatic, day: state.day
        ))
        return events
    }

    // MARK: - Follow-ups

    private static func schedule(
        _ eventID: String,
        source: NarrativeSource,
        day: Int,
        state: inout GameState
    ) {
        state.narrative.scheduled.append(
            ScheduledNarrativeEvent(day: day, eventID: eventID, source: source)
        )
        state.narrative.scheduled.sort {
            ($0.day, $0.eventID, $0.source.rawValue) < ($1.day, $1.eventID, $1.source.rawValue)
        }
    }

    /// Fires the first due follow-up (at most one a day, and never on top
    /// of a pending choice — the rest wait their turn).
    private static func fireScheduled(
        _ state: inout GameState,
        _ balance: BalanceConfig,
        _ content: ContentCatalog
    ) -> [GameEvent] {
        guard state.narrative.pendingChoice == nil,
              let index = state.narrative.scheduled.firstIndex(where: { $0.day <= state.day })
        else { return [] }
        let due = state.narrative.scheduled.remove(at: index)
        switch due.source {
        case .company:
            guard let def = content.event(due.eventID) else { return [] }
            return fireCompany(def, state: &state, balance: balance)
        case .life:
            guard let def = content.lifeEvent(due.eventID) else { return [] }
            return fireLife(def, state: &state, balance: balance)
        case .staff:
            // WS-D fires the scheduled staff follow-up as a pending staff
            // event for `due.employeeID`. Scaffold: dropped.
            return []
        }
    }

    // MARK: - Industry news

    /// A weekly headline about the world outside the studio. Cosmetic:
    /// `.industryNews` carries the rendered sentence, changes no state, and
    /// draws only from `worldRNG` — and only when `News.json` has
    /// templates, so a test catalog without them draws nothing at all.
    private static func rollIndustryNews(
        _ state: inout GameState,
        _ balance: BalanceConfig,
        _ content: ContentCatalog
    ) -> [GameEvent] {
        let config = balance.narrative
        guard config.newsIntervalDays > 0,
              state.day % config.newsIntervalDays == 0,
              state.day > state.narrative.lastNewsDay,
              !content.news.isEmpty
        else { return [] }

        guard state.worldRNG.nextUniform() < config.newsChance else { return [] }

        let usable = content.news.filter { template in
            template.needsRival ? !state.rivals.rivals.isEmpty : true
        }
        guard !usable.isEmpty else { return [] }
        let picked = weightedPick(usable, weight: { max(1, $0.weight) }, rng: &state.worldRNG)
        let headline = render(picked, state: &state, content: content)
        state.narrative.lastNewsDay = state.day
        return [.industryNews(headline: headline, day: state.day)]
    }

    /// Fills a template's `{rival}`, `{product}`, `{topic}`, `{adjective}`
    /// and `{number}` slots. Each slot that needs a choice draws one word
    /// from `worldRNG`, in the order the placeholders are listed here, so
    /// the same seed always renders the same sentence.
    private static func render(
        _ template: NewsTemplate,
        state: inout GameState,
        content: ContentCatalog
    ) -> String {
        var text = template.template
        if text.contains("{rival}") {
            let rivals = state.rivals.rivals.sorted { $0.id.uuidString < $1.id.uuidString }
            let name = rivals.isEmpty
                ? "A stealth-mode studio"
                : rivals[Int(state.worldRNG.next() % UInt64(rivals.count))].name
            text = text.replacingOccurrences(of: "{rival}", with: name)
        }
        if text.contains("{product}") {
            // Prefer something a rival has actually shipped (WS-F's
            // `Rival.products`, wired at integration) so the ticker names
            // the app the player can see on the Rivals screen; fall back to
            // two words from the pool when nobody has launched yet. Both
            // paths draw the same two words, in the same order, so the
            // sentence stays a pure function of the seed either way.
            let words = content.names.productWords
            let shipped = state.rivals.rivals
                .sorted { $0.id.uuidString < $1.id.uuidString }
                .flatMap(\.products)
            let product: String
            if shipped.isEmpty, words.count < 2 {
                product = "an unnamed app"
            } else {
                let first = state.worldRNG.next()
                let second = state.worldRNG.next()
                product = if shipped.isEmpty {
                    "\(words[Int(first % UInt64(words.count))]) "
                        + "\(words[Int(second % UInt64(words.count))])"
                } else {
                    shipped[Int(first % UInt64(shipped.count))].name
                }
            }
            text = text.replacingOccurrences(of: "{product}", with: product)
        }
        if text.contains("{topic}") {
            let topics = content.topics
            let name = topics.isEmpty
                ? "software"
                : topics[Int(state.worldRNG.next() % UInt64(topics.count))].name.lowercased()
            text = text.replacingOccurrences(of: "{topic}", with: name)
        }
        if text.contains("{adjective}") {
            let word = Self.newsAdjectives[Int(state.worldRNG.next() % UInt64(Self.newsAdjectives.count))]
            text = text.replacingOccurrences(of: "{adjective}", with: word)
        }
        if text.contains("{number}") {
            let value = 2 + Int(state.worldRNG.next() % 90)
            text = text.replacingOccurrences(of: "{number}", with: String(value))
        }
        return text
    }

    private static let newsAdjectives = [
        "derivative", "inevitable", "overdue", "competent", "unfinished",
        "quietly brilliant", "expensive", "confusing", "the year's best",
        "a rounding error", "hard to argue with", "a nice idea, badly timed",
    ]

    // MARK: - Eligibility

    /// Whether the narrative layer may fire anything today: nothing is
    /// pending, the game is live, and the last beat is far enough back.
    private static func canFireBeat(_ state: GameState, _ balance: BalanceConfig) -> Bool {
        state.gameOver == nil
            && state.narrative.pendingChoice == nil
            && state.day - state.narrative.lastFiredDay >= balance.narrative.minDaysBetweenBeats
    }

    private static func isEligible(_ def: LifeEventDef, state: GameState) -> Bool {
        // The version-1 gates first, so a legacy catalog behaves exactly as
        // it did.
        if let minStage = def.minStage {
            guard let stage = RelationshipStage(rawValue: minStage),
                  state.life.family.stage.rank >= stage.rank
            else { return false }
        }
        if def.requiresChildren, state.life.family.children.isEmpty { return false }
        if let cap = def.maxRelationships, state.life.meters.relationships >= cap { return false }
        return isEligible(
            def.id, def.requires, def.once, def.cooldownDays, def.followUpOnly, state: state
        )
    }

    private static func isEligible(
        _ id: String,
        _ requires: EventRequirements?,
        _ once: Bool,
        _ cooldownDays: Int,
        _ followUpOnly: Bool,
        state: GameState
    ) -> Bool {
        if followUpOnly { return false }
        if once, state.narrative.firedOnce.contains(id) { return false }
        if let available = state.narrative.cooldowns[id], state.day < available { return false }
        guard let requires else { return true }
        return meets(requires, state: state)
    }

    /// Evaluates a content requirement gate against the live state.
    /// `TycoonContent` holds the data; the meaning lives here.
    static func meets(_ requires: EventRequirements, state: GameState) -> Bool {
        // Company
        if let minTier = requires.minTier,
           let tier = OfficeTier(rawValue: minTier),
           state.company.officeTier.rank < tier.rank { return false }
        if let maxTier = requires.maxTier,
           let tier = OfficeTier(rawValue: maxTier),
           state.company.officeTier.rank > tier.rank { return false }
        if let value = requires.minHeadcount, state.headcount < value { return false }
        if let value = requires.maxHeadcount, state.headcount > value { return false }
        if let value = requires.minReputation, state.company.reputation < value { return false }
        if let value = requires.maxReputation, state.company.reputation > value { return false }
        if let value = requires.minCash, state.company.cash < value { return false }
        if let value = requires.maxCash, state.company.cash > value { return false }
        if let value = requires.minYear, state.year < value { return false }
        if let value = requires.maxYear, state.year > value { return false }
        if let value = requires.hasProductInDev,
           (state.productInDevelopment != nil) != value { return false }
        if let value = requires.hasLiveProduct, hasLiveProduct(state) != value { return false }
        if let topicID = requires.topicID,
           !state.products.contains(where: { $0.topicID == topicID }) { return false }
        if let value = requires.hasLoan, (state.loanBalance > 0) != value { return false }
        if let raw = requires.requiresDepartment {
            guard let department = Department(rawValue: raw),
                  state.hasDepartment(department) else { return false }
        }
        if let value = requires.hasFriendship, state.friendships.isEmpty == value { return false }

        // Founder life
        if let raw = requires.minStage {
            guard let stage = RelationshipStage(rawValue: raw),
                  state.life.family.stage.rank >= stage.rank else { return false }
        }
        if let raw = requires.maxStage {
            guard let stage = RelationshipStage(rawValue: raw),
                  state.life.family.stage.rank <= stage.rank else { return false }
        }
        if let value = requires.requiresChildren,
           state.life.family.children.isEmpty == value { return false }
        if let value = requires.minChildren,
           state.life.family.children.count < value { return false }
        if let raw = requires.minHome {
            guard let home = HomeTier(rawValue: raw),
                  state.life.home.rank >= home.rank else { return false }
        }
        if let value = requires.minWallet, state.life.wallet < value { return false }
        if let value = requires.maxWallet, state.life.wallet > value { return false }
        if let value = requires.maxRelationships,
           state.life.meters.relationships >= value { return false }
        if let value = requires.minRelationships,
           state.life.meters.relationships < value { return false }
        if let value = requires.maxEnergy, state.life.meters.energy > value { return false }
        if let value = requires.maxMood, state.life.meters.mood > value { return false }
        if let raw = requires.schedule, state.life.schedule.rawValue != raw { return false }

        // Story
        for flag in requires.flagsAll where !state.narrative.flags.contains(flag) { return false }
        for flag in requires.flagsNone where state.narrative.flags.contains(flag) { return false }
        return true
    }

    private static func hasLiveProduct(_ state: GameState) -> Bool {
        state.products.contains { product in
            if case .released(let info) = product.stage { return !info.offMarket }
            return false
        }
    }

    /// Options whose own `requires` gate reads true, carrying their
    /// definition index so `resolveChoice` addresses the right one.
    ///
    /// `minEveningsLeft` is the one gate that greys instead of hiding
    /// (WS-E): an option the founder *could* have taken, had the week not
    /// already been spent, stays on the sheet with the reason under it.
    /// Everything else in `requires` hides the option as before.
    private static func availableOptions(
        _ choices: [EventChoice],
        state: GameState,
        balance: BalanceConfig
    ) -> [ChoiceOption] {
        choices.enumerated().compactMap { index, choice in
            if let gate = choice.requires, !meets(gate, state: state) { return nil }
            return ChoiceOption(
                id: choice.id,
                label: choice.label,
                detail: choice.detail ?? defaultDetail(for: choice),
                index: index,
                disabledReason: eveningBlocker(for: choice, state: state, balance: balance)
            )
        }
    }

    /// Why an option that asks for an evening cannot have one, or `nil`.
    /// A balance with no evening budget never blocks.
    private static func eveningBlocker(
        for choice: EventChoice,
        state: GameState,
        balance: BalanceConfig
    ) -> String? {
        guard let needed = choice.requires?.minEveningsLeft, needed > 0,
              let left = state.eveningsLeftThisWeek(balance)
        else { return nil }
        if state.life.isAway(day: state.day) { return "You're away" }
        return left >= needed ? nil : "No evenings left this week"
    }

    /// A consequence line assembled from the effects when the writer
    /// didn't hand-write one.
    private static func defaultDetail(for choice: EventChoice) -> String? {
        guard !choice.effects.isEmpty else { return nil }
        return choice.effects.prefix(3).map(\.summary).joined(separator: " · ")
    }

    private static func markFired(
        _ id: String,
        once: Bool,
        cooldownDays: Int,
        state: inout GameState,
        balance: BalanceConfig
    ) {
        state.narrative.lastFiredDay = state.day
        if once { state.narrative.firedOnce.insert(id) }
        let cooldown = cooldownDays > 0 ? cooldownDays : balance.narrative.defaultCooldownDays
        if cooldown > 0 { state.narrative.cooldowns[id] = state.day + cooldown }
    }

    // MARK: - Effects

    /// Applies a list of effects in order. Only `EmployeePick.random`
    /// draws from the RNG; every other effect is a pure state edit, which
    /// is what keeps a legacy-shaped catalog's draw count unchanged.
    @discardableResult
    static func apply(
        _ effects: [EventEffect],
        label: String,
        state: inout GameState,
        balance: BalanceConfig
    ) -> [GameEvent] {
        var events: [GameEvent] = []
        for effect in effects {
            switch effect {
            case .cash(let amount):
                guard amount != 0 else { continue }
                state.company.cash += amount
                state.ledger.post(LedgerEntry(
                    day: state.day, amount: amount, category: .other, label: label
                ))
            case .reputation(let amount):
                state.company.reputation = clamp(state.company.reputation + amount)
            case .hype(let amount):
                applyHype(amount, state: &state)
            case .moraleAll(let amount):
                for index in state.employees.indices where !state.employees[index].isFounder {
                    state.employees[index].morale = clamp(state.employees[index].morale + amount)
                }
            case .morale(let amount, let pick):
                for index in indices(for: pick, state: &state) {
                    state.employees[index].morale = clamp(state.employees[index].morale + amount)
                }
            case .loyalty(let amount, let pick):
                for index in indices(for: pick, state: &state) {
                    state.employees[index].loyalty = clamp(state.employees[index].loyalty + amount)
                }
            case .market(let topicID, let amount):
                let current = state.market.multiplier(for: topicID)
                var topic = state.market.topics[topicID] ?? .neutral
                topic.multiplier = max(0.1, current + amount)
                topic.lastChange = amount
                state.market.topics[topicID] = topic
            case .loan(let amount):
                state.loanBalance = max(0, state.loanBalance + amount)
                state.company.cash += amount
                state.ledger.post(LedgerEntry(
                    day: state.day, amount: amount, category: .other, label: label
                ))
            case .founderMeters(let energy, let health, let mood, let relationships, let wallet):
                state.life.meters.apply(
                    energy: energy, health: health, mood: mood, relationships: relationships
                )
                state.life.wallet += wallet
            case .away(let days, let reason):
                guard days > 0 else { continue }
                events.append(contentsOf: sendFounderAway(
                    days: days, reason: reason, state: &state
                ))
            case .cold(let days):
                guard days > 0 else { continue }
                state.life.coldUntilDay = state.day + days
            case .flag(let flag):
                state.narrative.flags.insert(flag)
            case .clearFlag(let flag):
                state.narrative.flags.remove(flag)
            case .skill(let skill, let amount, let pick):
                for index in indices(for: pick, state: &state) {
                    switch skill {
                    case .coding:
                        state.employees[index].skills.coding =
                            clamp(state.employees[index].skills.coding + amount)
                    case .design:
                        state.employees[index].skills.design =
                            clamp(state.employees[index].skills.design + amount)
                    case .marketing:
                        state.employees[index].skills.marketing =
                            clamp(state.employees[index].skills.marketing + amount)
                    }
                }
            case .research(let amount):
                state.research.banked = max(0, state.research.banked + amount)

            // MARK: WS-E — the date in the diary

            case .affection(let amount):
                // A silent no-op while single: the number is not simulated.
                guard state.life.family.stage != .single else { continue }
                state.life.family.affection = clamp(state.life.family.affection + amount)
                // Showing up counts as showing up — the neglect clock
                // restarts the way a date night restarts it.
                if amount > 0 { state.life.family.lastPartnerDay = state.day }
            case .evening:
                state.spendEvening(balance)
            case .bond(let amount, let pick):
                for index in indices(for: pick, state: &state) {
                    state.employees[index].founderBond =
                        clamp(state.employees[index].founderBond + amount)
                }
            }
        }
        return events
    }

    private static func applyHype(_ amount: Double, state: inout GameState) {
        guard let index = state.products.firstIndex(where: { product in
            if case .development = product.stage { return true }
            return false
        }), case .development(var dev) = state.products[index].stage else { return }
        dev.hype = max(0, dev.hype + amount)
        state.products[index].stage = .development(dev)
    }

    private static func sendFounderAway(
        days: Int,
        reason: String,
        state: inout GameState
    ) -> [GameEvent] {
        guard !state.life.isAway(day: state.day) else { return [] }
        let until = state.day + days
        state.life.awayUntilDay = until
        // WS-A: the team notices a long absence, so every absence records
        // the day it started. Carried over at merge from the old
        // LifeEventSystem.apply, which this replaced.
        state.life.awaySinceDay = state.day
        state.life.awayReason = reason
        return [.founderAway(reason: reason, untilDay: until, day: state.day)]
    }

    /// The employee indices an `EmployeePick` resolves to. Everything but
    /// `.random` is a pure function of the roster; ties break on id so the
    /// choice never depends on array order.
    private static func indices(for pick: EmployeePick, state: inout GameState) -> [Int] {
        let hired = state.employees.indices.filter { !state.employees[$0].isFounder }
        guard !hired.isEmpty else { return [] }
        switch pick {
        case .everyone:
            return hired
        case .random:
            return [hired[Int(state.rng.next() % UInt64(hired.count))]]
        case .lowestMorale:
            return [hired.min {
                (state.employees[$0].morale, state.employees[$0].id.uuidString)
                    < (state.employees[$1].morale, state.employees[$1].id.uuidString)
            }!]
        case .highestSkill:
            return [hired.max {
                (state.employees[$0].skills.total, state.employees[$1].id.uuidString)
                    < (state.employees[$1].skills.total, state.employees[$0].id.uuidString)
            }!]
        case .longestServing:
            return [hired.min {
                (state.employees[$0].hiredDay, state.employees[$0].id.uuidString)
                    < (state.employees[$1].hiredDay, state.employees[$1].id.uuidString)
            }!]
        }
    }

    private static func clamp(_ value: Double) -> Double { min(100, max(0, value)) }

    // MARK: - Weighted pick

    /// One `nextInt(in:)` word over cumulative weights in catalog order —
    /// the draw shape every roll in this engine uses.
    private static func weightedPick<T>(
        _ items: [T],
        weight: (T) -> Int,
        rng: inout SeededRNG
    ) -> T {
        let total = items.reduce(0) { $0 + weight($1) }
        var remaining = rng.nextInt(in: 0...(total - 1))
        for item in items {
            remaining -= weight(item)
            if remaining < 0 { return item }
        }
        return items[items.count - 1]
    }
}
