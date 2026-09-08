import Foundation
import TycoonContent

// Iteration 11 — N4. The feed, the follower count, and the weather that
// comes with them.

/// Fame's day.
///
/// `run` returns on its first line for every run whose `state.fame` is
/// still `.empty`, which is every run in which nobody has pressed *Post* —
/// every pacing bot, every fixture, every replay of a save written before
/// this lane existed. Nothing here draws from `rng` or `worldRNG` ever;
/// the reach roll, the rival's answer and the weekly cancellation roll are
/// `socialRNG`, and each of them happens only inside a run that has
/// already engaged.
enum FameSystem {

    // MARK: - The day

    @Sendable
    static func run(
        _ state: inout GameState,
        _ balance: BalanceConfig,
        _ content: ContentCatalog
    ) -> [GameEvent] {
        // The whole lane's identity gate.
        guard state.fame != .empty else { return [] }

        var events: [GameEvent] = []
        drift(&state, balance)
        events.append(contentsOf: raiseLevels(&state, balance))
        events.append(contentsOf: fadeBeef(&state, balance))
        widenPool(&state, balance, content)
        events.append(contentsOf: rollCancellation(&state, balance, content))
        return events
    }

    /// The fame curve: approach the target, then leak. See
    /// `Fame.target(followers:recentReach:balance:)` for the formula.
    private static func drift(_ state: inout GameState, _ balance: BalanceConfig) {
        let config = balance.fame
        let recent = state.fame.recentReach(day: state.day, window: config.recentReachWindow)
        let target = Fame.target(
            followers: state.fame.followers, recentReach: recent, balance: config
        )
        let moved = state.fame.fame + (target - state.fame.fame) * config.approach
        state.fame.fame = min(100, max(0, moved - config.dailyDecay))
    }

    /// Raises the story flag for every step of fame reached, once. The
    /// flags are what the `fame_*` life events gate on: a run that never
    /// posts never raises one, so those defs are never eligible and the
    /// life roll's weighted pick draws exactly the word it drew before.
    private static func raiseLevels(
        _ state: inout GameState, _ balance: BalanceConfig
    ) -> [GameEvent] {
        let level = Fame.level(state.fame.fame, balance: balance.fame)
        guard level.rawValue > state.fame.highWaterLevel else { return [] }

        var events: [GameEvent] = []
        var step = state.fame.highWaterLevel + 1
        while step <= level.rawValue {
            guard let reached = FameLevel(rawValue: step) else { break }
            if let flag = reached.flag { state.narrative.flags.insert(flag) }
            if let perk = Fame.perk(for: reached), !state.fame.perks.contains(perk) {
                state.fame.perks.append(perk)
            }
            events.append(.fameLevelReached(
                level: reached.rawValue, followers: state.fame.followers, day: state.day
            ))
            step += 1
        }
        state.fame.highWaterLevel = level.rawValue
        return events
    }

    /// A beef nobody answered stops being a beef. Two weeks of silence is
    /// the same answer as letting it go, said slower.
    private static func fadeBeef(
        _ state: inout GameState, _ balance: BalanceConfig
    ) -> [GameEvent] {
        guard let beef = state.fame.beef else { return [] }
        let lastRound = beef.openedDay + (beef.rounds - 1) * 2
        guard state.day - lastRound >= balance.fame.beefFadeDays else { return [] }
        state.fame.beef = nil
        return [.fameBeefSettled(
            rival: beef.rivalName, escalated: false, followerDelta: 0, day: state.day
        )]
    }

    /// Once a week, fame puts people in the hiring pool who were never
    /// asked. The work is in `HiringSystem`'s N4 region, which is where
    /// the hiring desk's own rules live.
    private static func widenPool(
        _ state: inout GameState, _ balance: BalanceConfig, _ content: ContentCatalog
    ) {
        let week = state.day / 7
        guard week != state.fame.lastInboundWeek, state.day % 7 == 1 else { return }
        let added = HiringSystem.fameInbound(
            state: &state, balance: balance, content: content
        )
        guard added > 0 else { return }
        state.fame.lastInboundWeek = week
    }

    // MARK: - Posting

    /// Why the founder cannot post right now, or `nil`. The app prints
    /// this on the button, which is rule 7: an action that is refused says
    /// why before it is tapped.
    static func postBlocker(
        kind: FamePostKind, state: GameState, content: ContentCatalog
    ) -> String? {
        if state.gameOver != nil { return "The company is closed." }
        if let last = state.fame.lastPostDay, last >= state.day {
            return "One post a day. You already had your say."
        }
        if state.life.isAway(day: state.day) { return "You are away." }
        if kind == .subtweet, state.rivals.rivals.isEmpty {
            return "Nobody to subtweet. The board is empty."
        }
        if kind == .launch, state.products.isEmpty {
            return "Nothing to announce yet."
        }
        if eligibleTemplates(kind: kind, state: state, content: content).isEmpty {
            return "Nothing to say about that today."
        }
        return nil
    }

    /// **Posting.** One `socialRNG` word for the template, one for the
    /// reach roll, and one per reply drawn — and nothing at all unless the
    /// player taps the button.
    static func post(
        kind: FamePostKind,
        subject: String?,
        state: inout GameState,
        balance: BalanceConfig,
        content: ContentCatalog
    ) -> [GameEvent] {
        guard postBlocker(kind: kind, state: state, content: content) == nil else { return [] }
        let config = balance.fame
        let catalog = content.feedCatalog

        // 1. The template — one word.
        let pool = eligibleTemplates(kind: kind, state: state, content: content)
        guard !pool.isEmpty else { return [] }
        let template = weighted(pool, &state.socialRNG)

        // The rival a subtweet names: the one asked for, else the
        // strongest on the board, so the button is never a blank.
        let rivalName = subject
            ?? state.rivals.rivals.max(by: { $0.strength < $1.strength })?.name
            ?? ""
        let text = fill(template.text, state: state, rival: rivalName)

        // 2. The reach roll — one word.
        let roll = config.rollFloor
            + state.socialRNG.nextUniform() * max(0, config.rollCeiling - config.rollFloor)
        let (reach, viral) = Fame.reach(
            followers: state.fame.followers,
            fame: state.fame.fame,
            kindMultiplier: config.reachMultiplier(kind),
            newsMultiplier: newsMultiplier(state, config),
            roll: roll,
            balance: config
        )
        let gained = Fame.followerGain(reach: reach, balance: config)

        // 3. The replies — one word each.
        let replies = drawReplies(
            kind: kind, viral: viral, roll: roll,
            state: &state, catalog: catalog, rival: rivalName
        )

        let post = FeedPost(
            id: state.fame.nextPostID,
            day: state.day,
            text: text,
            reach: reach,
            kind: kind,
            templateID: template.id,
            subject: kind == .subtweet ? rivalName : "",
            followerGain: gained,
            viral: viral,
            replies: replies
        )
        state.fame.posts.append(post)
        state.fame.nextPostID += 1
        state.fame.lastPostDay = state.day
        state.fame.followers += gained

        var events: [GameEvent] = [.famePosted(
            kind: kind.rawValue, reach: reach, viral: viral,
            followers: state.fame.followers, day: state.day
        )]

        // A subtweet is the only kind with a person on the other end.
        if kind == .subtweet, !rivalName.isEmpty {
            events.append(contentsOf: openBeef(
                rival: rivalName, state: &state, balance: balance, catalog: catalog
            ))
        }

        state.life.phone.post(
            viral
                ? "That one got away from you. \(PhoneSystem.money(reach).dropFirst()) people saw it."
                : "Posted. \(PhoneSystem.money(reach).dropFirst()) reached, \(gained) new followers.",
            from: .office,
            day: state.day,
            fromFounder: true
        )
        return events
    }

    /// Every template of a kind whose gates the state meets, in file
    /// order — so the weighted pick is stable.
    static func eligibleTemplates(
        kind: FamePostKind, state: GameState, content: ContentCatalog
    ) -> [FeedTemplateDef] {
        let hasBuild = !state.productsInDevelopment.isEmpty
        let hasLive = state.products.contains { product in
            if case .released(let info) = product.stage { return !info.offMarket }
            return false
        }
        let hasTeam = state.headcount > 1
        return content.feedCatalog.templates(kind: kind.rawValue).filter { def in
            if def.minFame > state.fame.fame { return false }
            if def.requiresBuild, !hasBuild { return false }
            if def.requiresLiveProduct, !hasLive { return false }
            if def.requiresTeam, !hasTeam { return false }
            return true
        }
    }

    /// Loud news week: a post that lands while the industry is already
    /// talking travels further. Exactly 1 on a quiet week.
    private static func newsMultiplier(
        _ state: GameState, _ config: BalanceConfig.FameBalance
    ) -> Double {
        let cutoff = state.day - config.newsDayWindow
        for event in state.eventLog.suffix(40) {
            if case .industryNews(_, let day) = event, day > cutoff {
                return config.newsDayMultiplier
            }
        }
        return 1
    }

    /// Up to three replies: warm on a long roll, cold on a short one, and
    /// one weird one always, because the internet is.
    private static func drawReplies(
        kind: FamePostKind,
        viral: Bool,
        roll: Double,
        state: inout GameState,
        catalog: FeedCatalog,
        rival: String
    ) -> [FameReply] {
        let wantedTones = roll >= 1.2
            ? ["warm", "warm", "weird"]
            : (roll <= 0.8 ? ["cold", "cold", "weird"] : ["warm", "cold", "weird"])
        let count = viral ? 3 : (roll >= 1.2 ? 3 : 2)

        var replies: [FameReply] = []
        var used: Set<String> = []
        for tone in wantedTones.prefix(count) {
            // Kind-specific lines first, then the general pool.
            let specific = catalog.replies.filter {
                $0.tone == tone && $0.kind == kind.rawValue && !used.contains($0.id)
            }
            let general = catalog.replies.filter {
                $0.tone == tone && $0.kind.isEmpty && !used.contains($0.id)
            }
            let pool = specific.isEmpty ? general : specific + general
            guard !pool.isEmpty else { continue }
            let picked = pool[state.socialRNG.nextInt(in: 0...(pool.count - 1))]
            used.insert(picked.id)
            replies.append(FameReply(
                id: replies.count,
                handle: picked.handle,
                text: fill(picked.text, state: state, rival: rival)
            ))
        }
        return replies
    }

    // MARK: - The beef

    /// A subtweet lands and the rival answers. One `socialRNG` word for
    /// which line they pick.
    private static func openBeef(
        rival: String,
        state: inout GameState,
        balance: BalanceConfig,
        catalog: FeedCatalog
    ) -> [GameEvent] {
        let lines = catalog.beefLines.isEmpty ? FeedCatalog.fallback.beefLines : catalog.beefLines
        let line = lines[state.socialRNG.nextInt(in: 0...(lines.count - 1))]

        if var beef = state.fame.beef, beef.rivalName == rival {
            guard beef.rounds < balance.fame.beefMaxRounds else { return [] }
            beef.rounds += 1
            beef.theirLine = line
            beef.waitingOnYou = true
            state.fame.beef = beef
            return []
        }
        state.fame.beef = FameBeef(rivalName: rival, openedDay: state.day, theirLine: line)
        // Iteration 11 — N2 adds `Rival.grudge` in a marked region of
        // `Rival.swift`. It is not on this branch, so a subtweet costs the
        // rival nothing but a press line for now; once N2 has merged, the
        // one line to add here is `state.rivals.bumpGrudge(rival, by:)`.
        // Follow-up, recorded in `docs/product/iteration-11-lanes/n4.md`.
        return [.fameBeefOpened(rival: rival, line: line, day: state.day)]
    }

    /// Escalate, or let it go. Escalating buys followers and costs the
    /// company reputation and the founder mood; letting it go costs
    /// nothing but the last word.
    static func answerBeef(
        escalate: Bool,
        state: inout GameState,
        balance: BalanceConfig,
        content: ContentCatalog
    ) -> [GameEvent] {
        guard var beef = state.fame.beef, beef.waitingOnYou else { return [] }
        let config = balance.fame
        let catalog = content.feedCatalog

        guard escalate else {
            state.fame.beef = nil
            state.life.meters.apply(mood: config.beefMoodPerRound / 2)
            return [.fameBeefSettled(
                rival: beef.rivalName, escalated: false, followerDelta: 0, day: state.day
            )]
        }

        let replies = catalog.beefReplies.isEmpty
            ? FeedCatalog.fallback.beefReplies
            : catalog.beefReplies
        let index = state.socialRNG.nextInt(in: 0...(replies.count - 1))
        let mine = fill(replies[index], state: state, rival: beef.rivalName)

        let gained = config.beefFollowersPerRound * beef.rounds
        state.fame.followers += gained
        state.company.reputation = max(
            0, state.company.reputation - config.beefReputationPerRound * Double(beef.rounds)
        )
        state.life.meters.apply(mood: -config.beefMoodPerRound)

        beef.yourLine = mine
        beef.waitingOnYou = false
        let reach = Fame.reach(
            followers: state.fame.followers, fame: state.fame.fame,
            kindMultiplier: config.reachMultiplier(.reply), newsMultiplier: 1,
            roll: config.rollCeiling * 0.8, balance: config
        ).reach
        state.fame.posts.append(FeedPost(
            id: state.fame.nextPostID, day: state.day, text: mine, reach: reach,
            kind: .reply, templateID: "beef", subject: beef.rivalName, followerGain: gained
        ))
        state.fame.nextPostID += 1

        // The last round is the one the world stops watching.
        if beef.rounds >= config.beefMaxRounds {
            state.fame.beef = nil
            return [.fameBeefSettled(
                rival: beef.rivalName, escalated: true, followerDelta: gained, day: state.day
            )]
        }
        // They come back in two days, with the next line down the list.
        beef.rounds += 1
        let lines = catalog.beefLines.isEmpty ? FeedCatalog.fallback.beefLines : catalog.beefLines
        beef.theirLine = lines[(beef.rounds - 1) % lines.count]
        beef.waitingOnYou = true
        state.fame.beef = beef
        return [.fameBeefOpened(rival: beef.rivalName, line: beef.theirLine, day: state.day)]
    }

    // MARK: - The cancellation

    /// Weekly, above `notableAt`, with enough on the record to dig
    /// through: an old line surfaces. One `socialRNG` word for the roll
    /// and one for the quote.
    private static func rollCancellation(
        _ state: inout GameState,
        _ balance: BalanceConfig,
        _ content: ContentCatalog
    ) -> [GameEvent] {
        let config = balance.fame
        guard state.day % 7 == 4,
              state.fame.cancellation == nil,
              state.fame.fame >= config.notableAt,
              state.fame.posts.count >= config.cancelMinPosts
        else { return [] }
        // One at a time, and never two in a season.
        if let last = state.fame.posts.last(where: { $0.templateID == "cancelled" }),
           state.day - last.day < config.cancelCooldownWeeks * 7 {
            return []
        }

        let over = state.fame.fame - config.notableAt
        let chance = config.cancelWeeklyChance * (1 + over / 100 * config.cancelFameSpan)
        guard state.socialRNG.nextUniform() < chance else { return [] }

        let quotes = content.feedCatalog.cancelQuotes.isEmpty
            ? FeedCatalog.fallback.cancelQuotes
            : content.feedCatalog.cancelQuotes
        let quote = quotes[state.socialRNG.nextInt(in: 0...(quotes.count - 1))]
        state.fame.cancellation = FameCancellation(raisedDay: state.day, quote: quote)
        state.life.phone.post(
            "Somebody found a four-year-old post of yours. It is doing numbers.",
            from: .office,
            day: state.day
        )
        return [.fameCancellationRaised(quote: quote, day: state.day)]
    }

    /// Apologise, double down, or delete it. Every answer costs
    /// followers, fame, reputation and mood; the balance says how much of
    /// each, and none of them is free.
    static func answerCancellation(
        response: FameCancelResponse,
        state: inout GameState,
        balance: BalanceConfig,
        content: ContentCatalog
    ) -> [GameEvent] {
        guard var cancellation = state.fame.cancellation, cancellation.response == nil
        else { return [] }
        let cost = balance.fame.cancelCost(response)

        let lost = Int((Double(state.fame.followers) * cost.followerLoss).rounded())
        state.fame.followers = max(0, state.fame.followers - lost)
        state.fame.fame = max(0, state.fame.fame - cost.fame)
        state.company.reputation = max(0, state.company.reputation + cost.reputation)
        state.life.meters.apply(mood: cost.mood)

        cancellation.response = response
        state.fame.cancellation = cancellation
        // A marker on the record, so the cooldown has something to read
        // and the feed shows the week it happened.
        state.fame.posts.append(FeedPost(
            id: state.fame.nextPostID,
            day: state.day,
            text: cancellationLine(response, quote: cancellation.quote),
            reach: 0,
            kind: .reply,
            templateID: "cancelled",
            followerGain: -lost
        ))
        state.fame.nextPostID += 1
        return [.fameCancellationAnswered(response: response.rawValue, day: state.day)]
    }

    private static func cancellationLine(
        _ response: FameCancelResponse, quote: String
    ) -> String {
        switch response {
        case .apologise:
            "I said it, I meant it at the time, and I was wrong. No thread, no context, no lawyer."
        case .doubleDown:
            "Still true. Sorry it reads badly in a screenshot."
        case .delete:
            "[post deleted] — which everybody had already screenshotted, obviously."
        }
    }

    // MARK: - Helpers

    /// `{company}`, `{product}`, `{topic}`, `{rival}`, `{followers}`.
    /// Forwards to `Fame.fill`, which the newspaper's beef column calls
    /// from the app.
    static func fill(_ text: String, state: GameState, rival: String) -> String {
        Fame.fill(text, state: state, rival: rival)
    }

    /// Weighted pick over templates. One `socialRNG` word, and no draw at
    /// all when there is nothing to choose between.
    private static func weighted(
        _ defs: [FeedTemplateDef], _ rng: inout SeededRNG
    ) -> FeedTemplateDef {
        guard defs.count > 1 else { return defs[0] }
        let total = defs.reduce(0) { $0 + max(1, $1.weight) }
        var roll = rng.nextInt(in: 0...(total - 1))
        for def in defs {
            roll -= max(1, def.weight)
            if roll < 0 { return def }
        }
        return defs[defs.count - 1]
    }
}
