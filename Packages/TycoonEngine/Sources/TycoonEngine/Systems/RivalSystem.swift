import Foundation
import TycoonContent

/// Weekly rival system, running after `MarketSystem` and before
/// `EmployeeSystem`: keeps the field of competitor studios populated,
/// evolves each rival's strength, lets rivals ship *named products* into a
/// topic or stumble, recomputes the player's share of every contested
/// topic from the quality of everything on the market, runs the
/// personalities (a copycat cloning the player's best topic, a rival
/// starting a price war after being out-sold twice, a poacher going after
/// the team twice as often, a deep-pockets studio that never folds), and —
/// on their cadences — makes poach and buyout offers the player answers
/// through `Reducer.apply`. Offers left past their deadline auto-resolve
/// here. Also hosts the offer and acquisition action handlers.
///
/// All randomness draws from `state.worldRNG`, never `state.rng`, so the
/// original systems' documented draw order stays byte-identical. World
/// draw order per tick: pending-poach auto-resolve (one uniform when due)
/// → founding (per new rival: two id words, name pick, strength,
/// reputation, topic pick, appearance seed) → weekly evolution (per
/// rival: one gaussian, one uniform event roll, one topic pick and — when
/// it launches — one product id, two name words and one quality jitter) →
/// fold replacements (founding draws each) → copycat pass (a clone's id,
/// two name words and a quality jitter per copying rival) → share and
/// price-war passes (no draws) → poach check (one uniform, plus one premium uniform
/// on a hit) → buyout check (one uniform, plus one fraction-or-premium
/// uniform on a hit). Founding draws two id words, the name pick, strength,
/// reputation, the topic pick, the appearance seed and the personality.
enum RivalSystem {
    /// Strength a rival gains by successfully hiring away an employee.
    private static let poachedStrengthGain: Double = 5

    @Sendable
    static func run(
        _ state: inout GameState,
        _ balance: BalanceConfig,
        _ content: ContentCatalog
    ) -> [GameEvent] {
        let config = balance.rivals
        var events: [GameEvent] = []

        events.append(contentsOf: resolveExpiredPoach(&state, balance))
        resolveExpiredBuyout(&state, &events)

        while state.rivals.rivals.count < config.rivalCount {
            let rival = found(&state, config, content)
            state.rivals.rivals.append(rival)
            events.append(.rivalFounded(rivalID: rival.id, name: rival.name, day: state.day))
        }

        if state.day % config.evolveIntervalDays == 0 {
            events.append(contentsOf: evolve(&state, balance, content))
            events.append(contentsOf: copycatCheck(&state, balance, content))
            recomputeShare(&state)
            events.append(contentsOf: priceWarCheck(&state))
        }
        // Re-applied every day, not just on evolution days: `MarketSystem`
        // rebuilds each `TopicMarket` on its weekly shift, and this system
        // runs after it and before `ProductSystem` posts the week's sales.
        mirrorShareIntoMarket(&state)

        events.append(contentsOf: poachCheck(&state, balance, content))
        events.append(contentsOf: buyoutCheck(&state, balance))
        return events
    }

    // MARK: - Founding

    /// Rolls one new rival. Draws, in order: two id words, the name pick,
    /// the strength roll, the reputation roll, the focus-topic pick (only
    /// when the catalog has topics at all), the appearance seed, and the
    /// personality.
    private static func found(
        _ state: inout GameState,
        _ config: BalanceConfig.RivalBalance,
        _ content: ContentCatalog
    ) -> Rival {
        let id = UUID(from: &state.worldRNG)
        // Software studios, not bakeries: WS-B's `rivalStudios` pool once
        // it exists, the built-in one until then. The client-company pool
        // that used to name every rival is deliberately not in the mix —
        // it is where "Moonbeam Dairy" came from.
        let namePool = content.names.rivalStudios.isEmpty
            ? fallbackStudioNames
            : content.names.rivalStudios
        let name = pick(namePool, &state.worldRNG) ?? "Nimbus Labs"
        let strength = config.foundingStrengthMin
            + state.worldRNG.nextUniform() * (config.foundingStrengthMax - config.foundingStrengthMin)
        let reputation = config.foundingReputationMin
            + state.worldRNG.nextUniform() * (config.foundingReputationMax - config.foundingReputationMin)
        let topics = content.topics.map(\.id)
        let focus: [String] = if let topic = pick(topics, &state.worldRNG) {
            [topic]
        } else {
            []
        }
        let appearanceSeed = state.worldRNG.next()
        let personality = RivalPersonality.allCases[
            state.worldRNG.nextInt(in: 0...(RivalPersonality.allCases.count - 1))
        ]
        return Rival(
            id: id,
            name: name,
            strength: strength,
            reputation: reputation,
            focusTopicIDs: focus,
            foundedDay: state.day,
            appearanceSeed: appearanceSeed,
            personality: personality
        )
    }

    /// Studio names used until WS-B fills `names.rivalStudios`. Software
    /// companies, so a competitor never reads as a dairy.
    private static let fallbackStudioNames = [
        "Lumen Labs", "Parallax", "Northwind Software", "Bitwise Union",
        "Cobalt Interactive", "Halcyon Systems", "Driftwood Digital",
        "Zenith Byte", "Silverline Studio", "Ember & Co", "Tessellate",
        "Ninefold", "Cardinal Works", "Aperture Stack", "Vermilion Code",
    ]

    // MARK: - Weekly evolution

    /// Per rival in array order: one gaussian strength step, then one
    /// uniform event roll — below the launch chance the rival ships a named
    /// product into one of its topics, below `shipChance + stumbleChance`
    /// it stumbles. Rivals that end below `foldThreshold` fold afterwards
    /// (except the deep-pockets studio, which never does) and are replaced
    /// with fresh foundings.
    private static func evolve(
        _ state: inout GameState,
        _ balance: BalanceConfig,
        _ content: ContentCatalog
    ) -> [GameEvent] {
        let config = balance.rivals
        var events: [GameEvent] = []

        for index in state.rivals.rivals.indices {
            let drift = state.worldRNG.nextGaussian(sigma: config.strengthDriftSigma)
            state.rivals.rivals[index].strength = clamp(
                state.rivals.rivals[index].strength + drift, min: 1, max: 100
            )

            let roll = state.worldRNG.nextUniform()
            // The visionary is quiet for months at a time, then ships
            // something very good.
            let launchChance = state.rivals.rivals[index].personality == .visionary
                ? config.shipChance * RivalDepthTuning.visionaryLaunchFactor
                : config.shipChance
            if roll < launchChance {
                let rival = state.rivals.rivals[index]
                if let topicID = pick(rival.focusTopicIDs, &state.worldRNG) {
                    let product = launchProduct(
                        for: rival, in: topicID, &state, balance, content
                    )
                    appendProduct(product, to: index, in: &state)
                    state.rivals.rivals[index].lastShippedDay = state.day
                    state.rivals.rivals[index].reputation = clamp(
                        rival.reputation + config.shipReputationGain, min: 0, max: 100
                    )
                    events.append(.rivalShipped(rivalID: rival.id, topicID: topicID, day: state.day))
                    events.append(.rivalProductLaunched(
                        rivalID: rival.id,
                        productName: product.name,
                        topicID: topicID,
                        quality: Int(product.quality.rounded()),
                        day: state.day
                    ))
                }
            } else if roll < config.shipChance + config.stumbleChance {
                state.rivals.rivals[index].strength = clamp(
                    state.rivals.rivals[index].strength - config.stumbleStrengthDrop, min: 1, max: 100
                )
                state.rivals.rivals[index].reputation = clamp(
                    state.rivals.rivals[index].reputation - config.stumbleReputationDrop, min: 0, max: 100
                )
            }
        }

        // Fold pass: collapsed rivals leave (their pending offers die with
        // them) and fresh studios take their slots.
        var folded: [Rival] = []
        state.rivals.rivals.removeAll { rival in
            // Somebody rich is patient about the deep-pockets studio: it
            // takes its beatings and keeps coming.
            guard rival.personality != .deepPockets,
                  rival.strength < config.foldThreshold
            else { return false }
            folded.append(rival)
            return true
        }
        for rival in folded {
            if state.rivals.pendingPoach?.rivalID == rival.id { state.rivals.pendingPoach = nil }
            if state.rivals.pendingBuyout?.rivalID == rival.id { state.rivals.pendingBuyout = nil }
            events.append(.rivalFolded(rivalID: rival.id, name: rival.name, day: state.day))
            let replacement = found(&state, config, content)
            state.rivals.rivals.append(replacement)
            events.append(.rivalFounded(rivalID: replacement.id, name: replacement.name, day: state.day))
        }
        return events
    }

    // MARK: - Named products

    /// One product a rival actually ships, with a name the player can lose
    /// to. Draws, in order: the id, two name words, and the quality jitter.
    ///
    /// Quality comes off the rival's strength — a 60-strength studio ships
    /// around a 51 — so a field of weak rivals is genuinely beatable and a
    /// strong one is not. A visionary ships better than its size suggests.
    private static func launchProduct(
        for rival: Rival,
        in topicID: String,
        _ state: inout GameState,
        _ balance: BalanceConfig,
        _ content: ContentCatalog
    ) -> RivalProduct {
        let id = UUID(from: &state.worldRNG)
        let name = productName(&state, content)
        let jitter = (state.worldRNG.nextUniform() * 2 - 1) * RivalDepthTuning.qualityJitter
        let bonus = rival.personality == .visionary ? RivalDepthTuning.visionaryQualityBonus : 0
        let quality = clamp(
            rival.strength * RivalDepthTuning.qualityPerStrength + jitter + bonus,
            min: RivalDepthTuning.qualityMin,
            max: RivalDepthTuning.qualityMax
        )
        // A readable stand-in for units until a rival's own economy exists;
        // the head-to-head panel shows it, nothing simulates against it.
        let weeklyUnits = Int((rival.strength * 40 * (0.5 + quality / 200)).rounded())
        let typeID = content.productTypes.first?.id ?? "mobile_app"
        return RivalProduct(
            id: id,
            name: name,
            topicID: topicID,
            typeID: typeID,
            quality: quality,
            launchDay: state.day,
            weeklyUnits: weeklyUnits
        )
    }

    /// Two words, from WS-B's `productWords` when it exists and the
    /// built-in pools until then. Always draws exactly two words, so the
    /// stream advances the same amount whichever pool is in play.
    private static func productName(
        _ state: inout GameState,
        _ content: ContentCatalog
    ) -> String {
        let firstPool = content.names.productWords.isEmpty
            ? fallbackProductPrefixes
            : content.names.productWords
        let secondPool = content.names.productWords.isEmpty
            ? fallbackProductSuffixes
            : content.names.productWords
        let first = pick(firstPool, &state.worldRNG) ?? "Nimbus"
        let second = pick(secondPool, &state.worldRNG) ?? "One"
        return first == second ? first : "\(first) \(second)"
    }

    private static let fallbackProductPrefixes = [
        "Nimbus", "Kite", "Lantern", "Orbit", "Pebble", "Quill", "Beacon",
        "Harbor", "Juniper", "Falcon", "Mosaic", "Anchor", "Tide", "Cinder",
        "Willow", "Vector",
    ]

    private static let fallbackProductSuffixes = [
        "Notes", "Flow", "Deck", "Studio", "Pilot", "Loop", "Hub", "Craft",
        "Base", "Signal", "Works", "Desk", "Lens", "Forge", "Track", "Post",
    ]

    /// Appends a launch to a rival's shelf, dropping the oldest beyond the
    /// cap so a long run can't grow the save without bound.
    private static func appendProduct(_ product: RivalProduct, to index: Int, in state: inout GameState) {
        state.rivals.rivals[index].products.append(product)
        let overflow = state.rivals.rivals[index].products.count - RivalDepthTuning.maxProductsPerRival
        if overflow > 0 {
            state.rivals.rivals[index].products.removeFirst(overflow)
        }
    }

    // MARK: - Market share

    /// Recomputes the player's slice of every contested topic — the model
    /// that replaced the flat `competitionDent`.
    ///
    /// In a topic where the player has something on the market and at least
    /// one rival product is still competing, share is quality-weighted:
    /// each side's weight is its score raised to `shareExponent`, so a 70
    /// against a 50 keeps roughly two thirds of the demand and a 40 against
    /// a 70 keeps about a quarter — before the floor, which guarantees
    /// every topic is worth *something*. A rival running a price war takes
    /// a further flat slice. Deterministic: no draws.
    private static func recomputeShare(_ state: inout GameState) {
        var shares: [String: Double] = [:]
        let day = state.day

        for product in state.products {
            guard case .released(let info) = product.stage, !info.offMarket else { continue }
            let topicID = product.topicID
            let playerQuality = max(1, Double(info.averageReviewScore))
            // The player's best product in the topic sets the standard.
            if let existing = shares[topicID], existing >= playerQuality { continue }
            shares[topicID] = playerQuality
        }

        var computed: [String: Double] = [:]
        for (topicID, playerQuality) in shares {
            let competitors = state.rivals.competitors(in: topicID, on: day)
            guard !competitors.isEmpty else {
                computed[topicID] = RivalDepthTuning.shareMax
                continue
            }
            let playerWeight = pow(playerQuality, RivalDepthTuning.shareExponent)
            let rivalWeight = competitors.reduce(0.0) { sum, entry in
                sum + pow(max(1, entry.product.quality), RivalDepthTuning.shareExponent)
            }
            var share = playerWeight / (playerWeight + rivalWeight)
            if competitors.contains(where: { $0.rival.isInPriceWar(on: day) && $0.rival.priceWarTopicID == topicID }) {
                share -= RivalDepthTuning.priceWarSharePenalty
            }
            computed[topicID] = clamp(
                share, min: RivalDepthTuning.shareMin, max: RivalDepthTuning.shareMax
            )
        }
        state.rivals.playerShare = computed
    }

    /// Copies the canonical share onto each topic's market entry, where
    /// `MarketState.shareMultiplier` — and so `ProductSystem` — reads it.
    /// Runs daily because `MarketSystem` rebuilds those entries weekly.
    private static func mirrorShareIntoMarket(_ state: inout GameState) {
        for (topicID, share) in state.rivals.playerShare {
            let existing = state.market.topics[topicID] ?? .neutral
            guard existing.playerShare != share else { continue }
            state.market.topics[topicID] = TopicMarket(
                multiplier: existing.multiplier,
                lastChange: existing.lastChange,
                playerShare: share
            )
        }
        // A topic that stopped being contested goes back to the whole
        // market rather than keeping a stale slice.
        for (topicID, market) in state.market.topics where market.playerShare != 1.0 {
            guard state.rivals.playerShare[topicID] == nil else { continue }
            state.market.topics[topicID] = TopicMarket(
                multiplier: market.multiplier, lastChange: market.lastChange, playerShare: 1.0
            )
        }
    }

    // MARK: - Personalities

    /// A copycat watches what the player ships and clones it a couple of
    /// months later, straight into the topic the player is doing best in —
    /// no waiting for a lucky launch roll, which is the whole point of the
    /// personality. Which topic and when are read off state; the clone
    /// itself draws an id, two name words and a quality jitter.
    private static func copycatCheck(
        _ state: inout GameState,
        _ balance: BalanceConfig,
        _ content: ContentCatalog
    ) -> [GameEvent] {
        let ripeDay = state.day - RivalDepthTuning.copycatDelayWeeks * GameState.daysPerWeek
        // The player's best product old enough to have been noticed.
        let target = state.products
            .compactMap { product -> (topicID: String, score: Int)? in
                guard case .released(let info) = product.stage,
                      !info.offMarket,
                      info.launchDay <= ripeDay
                else { return nil }
                return (product.topicID, info.averageReviewScore)
            }
            .max { lhs, rhs in
                if lhs.score != rhs.score { return lhs.score < rhs.score }
                return lhs.topicID < rhs.topicID
            }
        guard let target else { return [] }

        var events: [GameEvent] = []
        for index in state.rivals.rivals.indices {
            let rival = state.rivals.rivals[index]
            guard rival.personality == .copycat,
                  rival.bestProduct(in: target.topicID, on: state.day) == nil
            else { continue }
            if !state.rivals.rivals[index].focusTopicIDs.contains(target.topicID) {
                state.rivals.rivals[index].focusTopicIDs.append(target.topicID)
            }
            let clone = launchProduct(for: rival, in: target.topicID, &state, balance, content)
            appendProduct(clone, to: index, in: &state)
            state.rivals.rivals[index].lastShippedDay = state.day
            events.append(.rivalCopycat(rivalID: rival.id, topicID: target.topicID, day: state.day))
            events.append(.rivalProductLaunched(
                rivalID: rival.id,
                productName: clone.name,
                topicID: target.topicID,
                quality: Int(clone.quality.rounded()),
                day: state.day
            ))
        }
        return events
    }

    /// A rival the player keeps out-selling in a shared topic eventually
    /// cuts prices: the player's share drops for a few weeks. Beating a
    /// `marketDarling` company takes one extra week of humiliation first.
    /// Deterministic — no draws.
    private static func priceWarCheck(_ state: inout GameState) -> [GameEvent] {
        var events: [GameEvent] = []
        let day = state.day
        let darling = state.progression.hasPerk(.marketDarling)
        let trigger = RivalDepthTuning.priceWarTrigger + (darling ? 1 : 0)

        for index in state.rivals.rivals.indices {
            let rival = state.rivals.rivals[index]
            // Expire a finished war before considering a new one.
            if let until = rival.priceWarUntilDay, day >= until {
                state.rivals.rivals[index].priceWarUntilDay = nil
                state.rivals.rivals[index].priceWarTopicID = nil
            }
            guard !state.rivals.rivals[index].isInPriceWar(on: day) else { continue }

            // A topic they both sell into, where the player is ahead.
            let contested = rival.competingProducts(on: day)
                .map(\.topicID)
                .filter { state.rivals.share(for: $0) > 0.5 }
                .min()
            guard let topicID = contested else {
                state.rivals.rivals[index].weeksBeaten = 0
                continue
            }

            state.rivals.rivals[index].weeksBeaten += 1
            guard state.rivals.rivals[index].weeksBeaten >= trigger else { continue }

            let until = day + RivalDepthTuning.priceWarWeeks * GameState.daysPerWeek
            state.rivals.rivals[index].priceWarUntilDay = until
            state.rivals.rivals[index].priceWarTopicID = topicID
            state.rivals.rivals[index].weeksBeaten = 0
            events.append(.priceWarStarted(
                rivalID: rival.id, topicID: topicID, untilDay: until, day: day
            ))
        }
        // The war's bite lands on this week's share.
        if !events.isEmpty { recomputeShare(&state) }
        return events
    }

    // MARK: - Poaching

    /// On poach-check days (interval + offset, cooldown elapsed, no offer
    /// already pending, at least one rival and one hired employee): the
    /// target is picked deterministically — the highest score of
    /// `skillWeight × skills.total + underpaidWeight × underpayment +
    /// moraleWeight × (how far morale sits below 70)` — and one uniform
    /// decides whether the strongest rival makes the offer, resisted by
    /// the target's loyalty. A hit draws one more uniform for the salary
    /// premium and pauses the timeline via `.poachAttempt`.
    private static func poachCheck(
        _ state: inout GameState,
        _ balance: BalanceConfig,
        _ content: ContentCatalog
    ) -> [GameEvent] {
        let config = balance.rivals
        guard state.day % config.poachIntervalDays == config.poachOffsetDays,
              state.rivals.pendingPoach == nil,
              state.rivals.lastPoachDay.map({ state.day - $0 >= config.poachCooldownDays }) ?? true,
              let poacher = strongestRival(state),
              let target = poachTarget(state, balance)
        else { return [] }

        let resistance = clamp(1 - target.loyalty / config.loyaltyResistDivisor, min: 0, max: 1)
            / TraitEffects.poachResistance(target, content: content)
        // A poacher spends its time hiring your people, and it shows.
        let appetite = poacher.personality == .poacher
            ? RivalDepthTuning.poacherChanceFactor
            : 1
        let roll = state.worldRNG.nextUniform()
        guard roll < config.poachChance * resistance * appetite else { return [] }

        let fairPay = EmployeeSystem.fairWeeklyPay(for: target, balance: balance)
        let premium = config.poachPremiumMin
            + state.worldRNG.nextUniform() * (config.poachPremiumMax - config.poachPremiumMin)
        let offered = max(target.weeklySalary + 1, Int((fairPay * premium).rounded()))
        let offer = PoachOffer(
            rivalID: poacher.id,
            employeeID: target.id,
            offeredWeeklySalary: offered,
            respondByDay: state.day + config.poachResponseDays
        )
        state.rivals.pendingPoach = offer
        state.rivals.lastPoachDay = state.day
        return [.poachAttempt(
            rivalID: poacher.id,
            employeeID: target.id,
            offeredWeeklySalary: offered,
            respondByDay: offer.respondByDay,
            day: state.day
        )]
    }

    /// The non-founder employee a rival would most want: skilled,
    /// underpaid, unhappy. Deterministic — zero draws; ties break on the
    /// id string so the pick replays identically.
    private static func poachTarget(_ state: GameState, _ balance: BalanceConfig) -> Employee? {
        let config = balance.rivals
        return state.employees
            .filter { !$0.isFounder }
            .map { employee -> (score: Double, employee: Employee) in
                let fairPay = EmployeeSystem.fairWeeklyPay(for: employee, balance: balance)
                let underpaid = fairPay > 0
                    ? max(0, (fairPay - Double(employee.weeklySalary)) / fairPay)
                    : 0
                let lowMorale = max(0, (70 - employee.morale) / 70)
                let score = config.poachSkillWeight * employee.skills.total
                    + config.poachUnderpaidWeight * underpaid
                    + config.poachMoraleWeight * lowMorale
                return (score, employee)
            }
            .max { lhs, rhs in
                if lhs.score != rhs.score { return lhs.score < rhs.score }
                return lhs.employee.id.uuidString < rhs.employee.id.uuidString
            }?
            .employee
    }

    /// A pending poach past its deadline resolves against the employee's
    /// loyalty: one uniform — below `loyalty / 100` they turn the rival
    /// down on their own (shaken loyalty), otherwise they leave.
    private static func resolveExpiredPoach(
        _ state: inout GameState,
        _ balance: BalanceConfig
    ) -> [GameEvent] {
        guard let offer = state.rivals.pendingPoach, state.day > offer.respondByDay else { return [] }
        state.rivals.pendingPoach = nil

        guard let index = state.employees.firstIndex(where: { $0.id == offer.employeeID }) else {
            return []
        }
        let roll = state.worldRNG.nextUniform()
        if roll < state.employees[index].loyalty / 100 {
            state.employees[index].loyalty = clamp(
                state.employees[index].loyalty - 10, min: 0, max: 100
            )
            return [.poachDefeated(employeeID: offer.employeeID, day: state.day)]
        }
        return poachSucceeds(offer, &state, balance)
    }

    /// Removes the employee and credits the rival; friends left behind
    /// take the exit like a firing.
    private static func poachSucceeds(
        _ offer: PoachOffer,
        _ state: inout GameState,
        _ balance: BalanceConfig
    ) -> [GameEvent] {
        guard let index = state.employees.firstIndex(where: { $0.id == offer.employeeID }),
              !state.employees[index].isFounder
        else { return [] }
        let employee = state.employees.remove(at: index)
        if let rivalIndex = state.rivals.rivals.firstIndex(where: { $0.id == offer.rivalID }) {
            state.rivals.rivals[rivalIndex].strength = clamp(
                state.rivals.rivals[rivalIndex].strength + poachedStrengthGain, min: 1, max: 100
            )
        }
        var events: [GameEvent] = [.employeePoached(
            employeeID: employee.id, name: employee.name, rivalID: offer.rivalID, day: state.day
        )]
        events.append(contentsOf: SocialSystem.friendDeparted(
            employee.id, state: &state, balance: balance
        ))
        return events
    }

    // MARK: - Buyouts

    /// On buyout-check days (interval + offset, cooldown elapsed, nothing
    /// pending) a rival makes an approach — for one of two very different
    /// reasons.
    ///
    /// *Distress*: the company is in debt, out of cash, or unknown, and the
    /// offer is a fraction of what it is worth. That was the only path
    /// before, and it made selling out the reward for failing.
    ///
    /// *Strategic*: the company is worth at least
    /// `strategicDominanceFactor ×` the buyer and its reputation clears
    /// `strategicMinReputation` — somebody wants what you built, and pays a
    /// premium of 1.5–2.5× for it. Building something excellent now has an
    /// exit of its own.
    ///
    /// One uniform decides the approach; a hit draws one more for the
    /// fraction or premium and pauses the timeline via `.buyoutOffered`.
    private static func buyoutCheck(
        _ state: inout GameState,
        _ balance: BalanceConfig
    ) -> [GameEvent] {
        let config = balance.rivals
        let exits = balance.investors
        guard state.day % config.buyoutIntervalDays == config.buyoutOffsetDays,
              state.rivals.pendingBuyout == nil,
              state.rivals.lastBuyoutDay.map({ state.day - $0 >= config.buyoutCooldownDays }) ?? true,
              let buyer = strongestRival(state)
        else { return [] }

        let valuation = state.companyValuation(balance: balance)
        let weak = state.company.daysInDebt > 0
            || state.company.cash < config.weakCashThreshold
            || state.company.reputation < config.weakRepThreshold
        let strong = !weak
            && state.company.reputation >= exits.strategicMinReputation
            && Double(valuation)
                >= Double(buyer.valuation(balance: balance)) * exits.strategicDominanceFactor
        guard weak || strong else { return [] }

        let roll = state.worldRNG.nextUniform()
        guard roll < config.buyoutChance else { return [] }

        // Both paths draw exactly one more uniform, so the world stream
        // advances identically whichever approach this is.
        let multiplier: Double = if strong {
            exits.strategicPremiumMin
                + state.worldRNG.nextUniform() * (exits.strategicPremiumMax - exits.strategicPremiumMin)
        } else {
            config.offerFractionMin
                + state.worldRNG.nextUniform() * (config.offerFractionMax - config.offerFractionMin)
        }
        let amount = max(1000, Int((Double(valuation) * multiplier).rounded()))
        let offer = BuyoutOffer(
            rivalID: buyer.id,
            amount: amount,
            respondByDay: state.day + config.buyoutResponseDays
        )
        state.rivals.pendingBuyout = offer
        state.rivals.lastBuyoutDay = state.day
        state.rivals.lastBuyoutWasStrategic = strong
        return [.buyoutOffered(
            rivalID: buyer.id, amount: amount, respondByDay: offer.respondByDay, day: state.day
        )]
    }

    /// A pending buyout past its deadline is quietly withdrawn (no draws).
    private static func resolveExpiredBuyout(_ state: inout GameState, _ events: inout [GameEvent]) {
        guard let offer = state.rivals.pendingBuyout, state.day > offer.respondByDay else { return }
        state.rivals.pendingBuyout = nil
        events.append(.buyoutWithdrawn(rivalID: offer.rivalID, day: state.day))
    }

    // MARK: - Actions

    /// Matches a pending poach offer: the employee's salary rises to the
    /// rival's number (with the usual raise morale math) and their loyalty
    /// jumps. Ignored with nothing pending; a target who already left just
    /// clears the offer.
    static func matchPoachOffer(state: inout GameState, balance: BalanceConfig) -> [GameEvent] {
        guard let offer = state.rivals.pendingPoach else { return [] }
        state.rivals.pendingPoach = nil
        guard let index = state.employees.firstIndex(where: { $0.id == offer.employeeID }),
              !state.employees[index].isFounder
        else { return [] }

        var events = EmployeeSystem.adjustSalary(
            employeeID: offer.employeeID,
            weeklySalary: offer.offeredWeeklySalary,
            state: &state,
            balance: balance
        )
        state.employees[index].loyalty = clamp(
            state.employees[index].loyalty + balance.rivals.matchLoyaltyBoost, min: 0, max: 100
        )
        events.append(.poachDefeated(employeeID: offer.employeeID, day: state.day))
        return events
    }

    /// Lets the poached employee go to the rival. Ignored with nothing
    /// pending.
    static func declinePoachOffer(state: inout GameState, balance: BalanceConfig) -> [GameEvent] {
        guard let offer = state.rivals.pendingPoach else { return [] }
        state.rivals.pendingPoach = nil
        return poachSucceeds(offer, &state, balance)
    }

    /// Sells the company: the sale posts to the ledger and the run ends as
    /// a successful exit. Ignored with nothing pending.
    static func acceptBuyout(state: inout GameState) -> [GameEvent] {
        guard let offer = state.rivals.pendingBuyout else { return [] }
        state.rivals.pendingBuyout = nil
        let buyerName = state.rivals.rival(id: offer.rivalID)?.name ?? "a rival"

        state.company.cash += offer.amount
        state.ledger.post(LedgerEntry(
            day: state.day,
            amount: offer.amount,
            category: .other,
            label: "Company sale to \(buyerName)"
        ))
        state.gameOver = GameOverInfo(
            day: state.day,
            reason: "Acquired by \(buyerName) for $\(offer.amount).",
            kind: .acquired
        )
        return [
            .companySold(rivalID: offer.rivalID, amount: offer.amount, day: state.day),
            .gameOver(day: state.day),
        ]
    }

    /// Turns a pending buyout down. Ignored with nothing pending.
    static func declineBuyout(state: inout GameState) -> [GameEvent] {
        guard let offer = state.rivals.pendingBuyout else { return [] }
        state.rivals.pendingBuyout = nil
        return [.buyoutWithdrawn(rivalID: offer.rivalID, day: state.day)]
    }

    /// Buys a rival studio outright. Gated on affordability
    /// (`valuation × acquirePremium`) and dominance (player valuation at
    /// least `acquireDominanceFactor ×` the rival's). The rival's team
    /// partially joins — `strength / absorbDivisor` hires, capped by the
    /// office headroom, each rolled from `worldRNG` (two id words, first
    /// name, last name, three skill rolls, salary jitter, appearance
    /// seed) — and the rival leaves the field for good.
    static func acquireRival(
        rivalID: UUID,
        state: inout GameState,
        balance: BalanceConfig,
        content: ContentCatalog
    ) -> [GameEvent] {
        let config = balance.rivals
        guard let rivalIndex = state.rivals.rivals.firstIndex(where: { $0.id == rivalID })
        else { return [] }
        let rival = state.rivals.rivals[rivalIndex]
        let cost = Int((Double(rival.valuation(balance: balance)) * config.acquirePremium).rounded())
        guard state.company.cash >= cost,
              Double(state.companyValuation(balance: balance))
                >= Double(rival.valuation(balance: balance)) * config.acquireDominanceFactor
        else { return [] }

        state.company.cash -= cost
        state.ledger.post(LedgerEntry(
            day: state.day,
            amount: -cost,
            category: .other,
            label: "Acquired \(rival.name)"
        ))
        state.company.reputation = clamp(
            state.company.reputation + config.acquireRepBonus, min: 0, max: 100
        )

        let headroom = max(0, balance.office(state.company.officeTier).headcountCap - state.headcount)
        let joining = min(headroom, Int((rival.strength / config.absorbDivisor).rounded()))
        for hireIndex in 0..<joining {
            state.employees.append(absorbedHire(
                from: rival, index: hireIndex, state: &state, balance: balance, content: content
            ))
        }

        state.rivals.rivals.remove(at: rivalIndex)
        if state.rivals.pendingPoach?.rivalID == rival.id { state.rivals.pendingPoach = nil }
        if state.rivals.pendingBuyout?.rivalID == rival.id { state.rivals.pendingBuyout = nil }
        // Counted here rather than derived: an acquired rival leaves the
        // field for good, so nothing in state remembers it happened.
        state.progression.stats.rivalsAcquired += 1
        return [.rivalAcquired(
            rivalID: rival.id, name: rival.name, hiresAbsorbed: joining, day: state.day
        )]
    }

    /// One employee inherited from an acquired rival. Skills roll against
    /// a ceiling set by the rival's strength; the role rotates through the
    /// builder roles by index (no draw).
    private static func absorbedHire(
        from rival: Rival,
        index: Int,
        state: inout GameState,
        balance: BalanceConfig,
        content: ContentCatalog
    ) -> Employee {
        let id = UUID(from: &state.worldRNG)
        let first = pick(content.names.firstNames, &state.worldRNG) ?? "Alex"
        let last = pick(content.names.lastNames, &state.worldRNG) ?? "Doe"
        let ceiling = clamp(20 + rival.strength * 0.6, min: 20, max: 90)
        let skills = SkillSet(
            coding: 5 + state.worldRNG.nextUniform() * (ceiling - 5),
            design: 5 + state.worldRNG.nextUniform() * (ceiling - 5),
            marketing: 5 + state.worldRNG.nextUniform() * (ceiling - 5)
        )
        let jitter = 1 + (state.worldRNG.nextUniform() * 2 - 1) * balance.salaryJitter
        let salary = (Double(balance.salaryBase) + balance.salaryPerSkillPoint * skills.total) * jitter
        let roles: [EmployeeRole] = [.backend, .frontend, .designer]
        return Employee(
            id: id,
            name: "\(first) \(last)",
            skills: skills,
            weeklySalary: Int(salary.rounded()),
            assignment: .idle,
            isFounder: false,
            hiredDay: state.day,
            appearanceSeed: state.worldRNG.next(),
            morale: balance.staff.startingMorale,
            level: .forSkillTotal(skills.total),
            role: roles[index % roles.count]
        )
    }

    // MARK: - Helpers

    /// The strongest rival; ties break on the id string.
    private static func strongestRival(_ state: GameState) -> Rival? {
        state.rivals.rivals.max { lhs, rhs in
            if lhs.strength != rhs.strength { return lhs.strength < rhs.strength }
            return lhs.id.uuidString < rhs.id.uuidString
        }
    }

    private static func pick(_ pool: [String], _ rng: inout SeededRNG) -> String? {
        guard !pool.isEmpty else { return nil }
        return pool[rng.nextInt(in: 0...(pool.count - 1))]
    }

    private static func clamp(_ value: Double, min lower: Double, max upper: Double) -> Double {
        min(upper, max(lower, value))
    }
}
