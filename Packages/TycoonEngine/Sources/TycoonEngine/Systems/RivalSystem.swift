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
/// two name words and a quality jitter per copying rival) → incumbent
/// founding, the week it happens (two id words, name, reputation,
/// appearance seed, then its opener's id, two words and a jitter) →
/// challenge, share, price-war, bleed, settlement and retreat passes (no
/// draws) → poach check (one uniform, plus one premium uniform on a hit)
/// → buyout check (one uniform, plus one fraction-or-premium uniform on
/// a hit). Founding draws two id words, the name pick, strength,
/// reputation, the topic pick, the appearance seed and the personality.
/// An acquisition draws the absorbed hires' words and one word per
/// synthesised review on the absorbed shelf.
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

        // Iteration 8: real players' companies take the first slots. A
        // ghost draws nothing — its id, face and strength are its facts —
        // so the field is the same on every phone given the same scripts.
        if !state.ghosts.isEmpty, !state.rivals.rivals.contains(where: \.isGhost) {
            for (index, script) in state.ghosts.prefix(config.rivalCount).enumerated() {
                let rival = Rival(
                    id: script.rivalID,
                    name: script.name,
                    strength: clamp(script.strength, min: 5, max: 100),
                    reputation: 50,
                    focusTopicIDs: script.focusTopicIDs,
                    foundedDay: state.day,
                    appearanceSeed: script.appearanceSeed,
                    personality: .deepPockets,
                    ghostIndex: index
                )
                state.rivals.rivals.append(rival)
                events.append(.rivalFounded(rivalID: rival.id, name: rival.name, day: state.day))
            }
        }

        while state.rivals.rivals.count < config.rivalCount {
            let rival = found(&state, config, content)
            state.rivals.rivals.append(rival)
            events.append(.rivalFounded(rivalID: rival.id, name: rival.name, day: state.day))
        }

        if state.day % config.evolveIntervalDays == 0 {
            // The week's launches, read off the evolve and copycat events
            // so the challenge pass needs no second draw and no extra
            // state.
            // MARK: J3 (rivals and the market)
            // Booms bring company and crashes empty a topic — before the
            // week's launches, so a studio that moved in can ship there.
            // Returns at once until the market board has been opened.
            events.append(contentsOf: rivalMarketMoves(&state, balance, content))
            // MARK: end J3
            var launches: [GameEvent] = []
            launches.append(contentsOf: evolve(&state, balance, content))
            launches.append(contentsOf: copycatCheck(&state, balance, content))
            events.append(contentsOf: launches)
            // The giant, when the company is first worth having: it
            // opens its own challenge, so its launch is not in `launches`.
            events.append(contentsOf: incumbentCheck(&state, balance, content))
            events.append(contentsOf: challengeCheck(&state, launches: launches, balance))
            recomputeShare(&state, balance)
            events.append(contentsOf: priceWarCheck(&state, balance))
            bleedStrength(&state, balance)
            // MARK: J3 (rivals and the market)
            // A matched war costs the studio that started it.
            rivalMarketMatchBleed(&state, balance)
            // MARK: end J3
            events.append(contentsOf: settleChallenges(&state, balance))
            let retreat = incumbentRetreatCheck(&state, balance)
            events.append(contentsOf: retreat)
            // The giant's products leave the shelf with it; the week's
            // share should say so now rather than next week.
            if !retreat.isEmpty { recomputeShare(&state, balance) }
            // The week's closing strength, for the profile's sparkline:
            // after every settlement above, so the sample is the number
            // the rivals screen shows this week. No draws, and nothing in
            // the simulation reads it back.
            for index in state.rivals.rivals.indices {
                state.rivals.rivals[index].recordStrength()
            }
        }
        // Re-applied every day, not just on evolution days: `MarketSystem`
        // rebuilds each `TopicMarket` on its weekly shift, and this system
        // runs after it and before `ProductSystem` posts the week's sales.
        // MARK: J3 (rivals and the market)
        // An out-shipped war ends the day the patch lands; a matched one
        // gives the product its price back when it is over. Returns at
        // once while no war has ever been answered.
        events.append(contentsOf: rivalMarketDaily(&state, balance))
        // MARK: end J3
        mirrorShareIntoMarket(&state)

        events.append(contentsOf: poachCheck(&state, balance, content))
        events.append(contentsOf: buyoutCheck(&state, balance))
        // MARK: K4 (deals and exits)
        // The for-sale sign: after the approach, so a rival's own offer
        // on the same day keeps the desk. Returns at once unless listed.
        events.append(contentsOf: dealListingCheck(&state, balance))
        // MARK: end K4
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
        let name = studioName(&state, content)
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

    /// One name pick. Software studios, not bakeries: WS-B's
    /// `rivalStudios` pool once it exists, the built-in one until then.
    /// The client-company pool that used to name every rival is
    /// deliberately not in the mix — it is where "Moonbeam Dairy" came
    /// from.
    private static func studioName(_ state: inout GameState, _ content: ContentCatalog) -> String {
        let namePool = content.names.rivalStudios.isEmpty
            ? fallbackStudioNames
            : content.names.rivalStudios
        return pick(namePool, &state.worldRNG) ?? "Nimbus Labs"
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
            // Iteration 8: a ghost replays its launches for the days since
            // the last pass and never rolls.
            if let ghostIndex = state.rivals.rivals[index].ghostIndex {
                guard state.ghosts.indices.contains(ghostIndex) else { continue }
                let rival = state.rivals.rivals[index]
                let due = state.ghosts[ghostIndex].launches.filter {
                    $0.day <= state.day && $0.day > state.day - config.evolveIntervalDays
                }
                for launch in due {
                    var seed = SeededRNG(seed: rival.appearanceSeed ^ UInt64(launch.day))
                    let product = RivalProduct(
                        id: UUID(from: &seed),
                        name: launch.name,
                        topicID: launch.topicID,
                        typeID: launch.typeID,
                        quality: clamp(launch.quality, min: RivalDepthTuning.qualityMin, max: RivalDepthTuning.qualityMax),
                        launchDay: state.day,
                        weeklyUnits: Int((rival.strength * 40 * (0.5 + launch.quality / 200)).rounded())
                    )
                    appendProduct(product, to: index, in: &state)
                    state.rivals.rivals[index].lastShippedDay = state.day
                    events.append(.rivalShipped(rivalID: rival.id, topicID: launch.topicID, day: state.day))
                    events.append(.rivalProductLaunched(
                        rivalID: rival.id, productName: launch.name, topicID: launch.topicID,
                        quality: Int(launch.quality.rounded()), day: state.day
                    ))
                }
                continue
            }
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
                // MARK: J3 (rivals and the market)
                // The same one `worldRNG` word; once the market board has
                // been opened it is weighted by multiplier², and a studio
                // that moved in on a boom ships there first.
                if let topicID = rivalMarketLaunchTopic(rival, &state, balance) {
                // MARK: end J3
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
            // takes its beatings and keeps coming. A ghost never folds.
            guard rival.personality != .deepPockets, !rival.isGhost,
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
        // MARK: J3 (rivals and the market)
        // The type the topic suits best, once the market has been opened;
        // until then the first of the catalog, as it always was.
        let typeID = rivalMarketProductType(for: topicID, state, content)
            ?? content.productTypes.first?.id ?? "mobile_app"
        // MARK: end J3
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
    static func appendProduct(_ product: RivalProduct, to index: Int, in state: inout GameState) {
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
    ///
    /// Standing holds share: the floor rises to `shareFloorAtFullStanding
    /// × standing / maxStanding` — 0.55 at full standing — which only
    /// clears the 0.30 hard floor above standing ~55, so a category the
    /// studio has held for a year is sticky and one it has just entered
    /// reads exactly as before. At standing 0 the term is 0 and the
    /// clamp is the shipped clamp to the digit.
    private static func recomputeShare(_ state: inout GameState, _ balance: BalanceConfig) {
        // The best product's review score, and what it is priced at: a
        // topic is fought over on quality *and* on price, and undercutting
        // is the only thing that makes the budget tier worth choosing.
        var shares: [String: (quality: Double, tier: PriceTier)] = [:]
        let day = state.day
        let floorAtFull = balance.rivals.depth.shareFloorAtFullStanding
        let maxStanding = max(1, balance.market.standing.maxStanding)

        for product in state.products {
            guard case .released(let info) = product.stage, !info.offMarket else { continue }
            let topicID = product.topicID
            let playerQuality = max(1, Double(info.averageReviewScore))
            // The player's best product in the topic sets the standard.
            if let existing = shares[topicID], existing.quality >= playerQuality { continue }
            shares[topicID] = (playerQuality, info.priceTier)
        }

        var computed: [String: Double] = [:]
        for (topicID, entry) in shares {
            let playerQuality = entry.quality
            let competitors = state.rivals.competitors(in: topicID, on: day)
            guard !competitors.isEmpty else {
                computed[topicID] = RivalDepthTuning.shareMax
                continue
            }
            let playerWeight = pow(playerQuality, RivalDepthTuning.shareExponent)
                * balance.economy.priceTier(entry.tier).shareWeight
            let rivalWeight = competitors.reduce(0.0) { sum, entry in
                sum + pow(max(1, entry.product.quality), RivalDepthTuning.shareExponent)
            }
            var share = playerWeight / (playerWeight + rivalWeight)
            // MARK: J3 (rivals and the market)
            // A war the player matched takes nothing: they went budget too.
            if competitors.contains(where: {
                $0.rival.isInPriceWar(on: day) && $0.rival.priceWarTopicID == topicID
                    && !state.rivalMarket.isMatched($0.rival)
            }) {
            // MARK: end J3
                share -= RivalDepthTuning.priceWarSharePenalty
            }
            let standingFloor = floorAtFull * state.market.standing(for: topicID) / maxStanding
            computed[topicID] = clamp(
                share,
                min: max(RivalDepthTuning.shareMin, standingFloor),
                max: RivalDepthTuning.shareMax
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
            .compactMap { product -> (topicID: String, score: Int, product: Product)? in
                guard case .released(let info) = product.stage,
                      !info.offMarket,
                      info.launchDay <= announceRipeDay(ripeDay, for: product, balance) // MARK: J5 (announce)
                else { return nil }
                return (product.topicID, info.averageReviewScore, product)
            }
            .max { lhs, rhs in
                if lhs.score != rhs.score { return lhs.score < rhs.score }
                return lhs.topicID < rhs.topicID
            }
        guard let target else { return [] }

        // MARK: M1 (feature board)

        // What the copycat is actually copying. A player who never placed
        // a card is copied the way they always were — the clone lifts
        // nothing, and `copiedFeature` stays `nil` and unwritten.
        let copiedFeature = FeatureBoard.reading(
            for: target.product, state: state, content: content, balance: balance
        ).bestCard?.name

        // MARK: end M1 (feature board)

        // MARK: J3 (rivals and the market)
        // The card a studio fed false plans takes instead: the weakest on
        // the board. Read only when somebody has been fed them.
        let worstFeature: String? = state.rivalMarket.fedFalsePlans.isEmpty ? nil
            : FeatureBoard.reading(
                for: target.product, state: state, content: content, balance: balance
            ).cards.min { lhs, rhs in
                if lhs.value != rhs.value { return lhs.value < rhs.value }
                return lhs.cardID < rhs.cardID
            }?.name
        // MARK: end J3

        var events: [GameEvent] = []
        for index in state.rivals.rivals.indices {
            let rival = state.rivals.rivals[index]
            guard rival.personality == .copycat,
                  rival.bestProduct(in: target.topicID, on: state.day) == nil
            else { continue }
            if !state.rivals.rivals[index].focusTopicIDs.contains(target.topicID) {
                state.rivals.rivals[index].focusTopicIDs.append(target.topicID)
            }
            var clone = launchProduct(for: rival, in: target.topicID, &state, balance, content)
            // MARK: M1 (feature board)
            clone.copiedFeature = copiedFeature
            // MARK: end M1 (feature board)
            // MARK: J3 (rivals and the market)
            // Best card or, after false plans, worst; +4 for having copied
            // anything. Nothing moves for a board nobody placed a card on.
            rivalMarketCopy(
                &clone, rivalID: rival.id, best: copiedFeature, worst: worstFeature, &state, balance
            )
            // MARK: end J3
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
    private static func priceWarCheck(
        _ state: inout GameState,
        _ balance: BalanceConfig
    ) -> [GameEvent] {
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
            //
            // "Both": `share(for:)` reads 1.0 for a topic the player has
            // never entered, which used to count a rival's first launch
            // into an untouched topic as the player beating it — and two
            // weeks later a company with no products was at war. Only a
            // topic the share pass actually computed (the player has
            // something live there) can be a topic the player is winning.
            let contested = rival.competingProducts(on: day)
                .map(\.topicID)
                .filter { state.rivals.playerShare[$0] != nil && state.rivals.share(for: $0) > 0.5 }
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
        if !events.isEmpty { recomputeShare(&state, balance) }
        return events
    }

    // MARK: - The category fight

    /// Hold the Category, phase two: a rival launch into a category the
    /// player holds stops the clock for six weeks' worth of decision.
    ///
    /// For each launch this week, in event order: the topic has no fight
    /// in progress and is off its cooldown, the player's standing there
    /// clears `challengeMinStanding`, and the launch scores no more than
    /// `challengeQualityWindow` below the player's best live product —
    /// anything better is a challenge by definition. Deterministic, no
    /// draws; every input is a launch that already drew.
    private static func challengeCheck(
        _ state: inout GameState,
        launches: [GameEvent],
        _ balance: BalanceConfig
    ) -> [GameEvent] {
        let depth = balance.rivals.depth
        var events: [GameEvent] = []
        for event in launches {
            guard case let .rivalProductLaunched(rivalID, productName, topicID, quality, _) = event,
                  state.rivals.challenge(in: topicID) == nil,
                  state.rivals.lastChallengeDay[topicID].map({
                      state.day - $0 >= depth.challengeCooldownWeeks * GameState.daysPerWeek
                  }) ?? true,
                  state.market.standing(for: topicID) >= depth.challengeMinStanding,
                  let best = playerBestScore(in: topicID, state),
                  Double(quality) >= Double(best) - depth.challengeQualityWindow
            else { continue }
            events.append(openChallenge(
                rivalID: rivalID, topicID: topicID, productName: productName,
                quality: Double(quality), &state, depth
            ))
        }
        return events
    }

    /// Opens a fight in a topic: the record, the cooldown stamp, and the
    /// critical event that stops the clock.
    private static func openChallenge(
        rivalID: UUID,
        topicID: String,
        productName: String,
        quality: Double,
        _ state: inout GameState,
        _ depth: BalanceConfig.RivalBalance.DepthBalance
    ) -> GameEvent {
        let settlesDay = state.day + depth.challengeWeeks * GameState.daysPerWeek
        state.rivals.challenges.append(CategoryChallenge(
            rivalID: rivalID,
            topicID: topicID,
            productName: productName,
            quality: quality,
            startedDay: state.day,
            settlesDay: settlesDay
        ))
        state.rivals.lastChallengeDay[topicID] = state.day
        return .categoryChallenged(
            rivalID: rivalID,
            topicID: topicID,
            productName: productName,
            quality: Int(quality.rounded()),
            respondByDay: settlesDay,
            day: state.day
        )
    }

    /// Settles every fight that has reached its day, on the share the
    /// week's pass just computed. Held (share at or above
    /// `challengeHoldShare`): the rival loses `heldRivalStrengthLoss`, the
    /// player gains `heldStandingGain` there. Lost: the player loses
    /// `lostStandingLoss` — the retainer stops covering the decay and the
    /// category goes quiet — the rival gains `lostRivalStrengthGain` and
    /// adds the topic to its focus, so it keeps coming. A rival that has
    /// folded or been bought since still settles: the player out-sold it
    /// off the board, which is holding the category.
    ///
    /// The share table has an entry only where the player has something
    /// live, so a category the player walked out of mid-fight is lost
    /// rather than held by default. Deterministic, no draws.
    private static func settleChallenges(
        _ state: inout GameState,
        _ balance: BalanceConfig
    ) -> [GameEvent] {
        let depth = balance.rivals.depth
        let day = state.day
        let due = state.rivals.challenges.filter { $0.settlesDay <= day }
        guard !due.isEmpty else { return [] }
        state.rivals.challenges.removeAll { $0.settlesDay <= day }

        var events: [GameEvent] = []
        for challenge in due {
            let held = (state.rivals.playerShare[challenge.topicID] ?? 0) >= depth.challengeHoldShare
            let rivalIndex = state.rivals.rivals.firstIndex { $0.id == challenge.rivalID }
            if held {
                if let rivalIndex {
                    state.rivals.rivals[rivalIndex].strength = clamp(
                        state.rivals.rivals[rivalIndex].strength - depth.heldRivalStrengthLoss,
                        min: 1, max: 100
                    )
                }
                StandingSystem.adjust(depth.heldStandingGain, in: challenge.topicID, &state, balance)
                events.append(.categoryHeld(
                    rivalID: challenge.rivalID, topicID: challenge.topicID, day: day
                ))
            } else {
                StandingSystem.adjust(-depth.lostStandingLoss, in: challenge.topicID, &state, balance)
                if let rivalIndex {
                    state.rivals.rivals[rivalIndex].strength = clamp(
                        state.rivals.rivals[rivalIndex].strength + depth.lostRivalStrengthGain,
                        min: 1, max: 100
                    )
                    if !state.rivals.rivals[rivalIndex].focusTopicIDs.contains(challenge.topicID) {
                        state.rivals.rivals[rivalIndex].focusTopicIDs.append(challenge.topicID)
                    }
                }
                events.append(.categoryLost(
                    rivalID: challenge.rivalID, topicID: challenge.topicID, day: day
                ))
            }
        }
        return events
    }

    /// The first move: weekly, in every topic where the player has
    /// something live and a rival sells too, the side with the lower share
    /// pays. Every rival with a competing product there loses
    /// `strengthPerWeekBeaten` when the player holds more than half the
    /// market; the player loses `standingPerWeekBeaten` there when a
    /// rival does. An exact half costs nobody. A rival out-sold for a
    /// year reaches the fold threshold — shipping a strong product *into*
    /// a rival's topic is now a way to push it off the board.
    ///
    /// Gated on the player having a live product in the topic (that is
    /// what a share entry means), which is the same guard as the war fix
    /// and the reason the pacing suite never reaches this. Topics are
    /// visited in sorted order and rivals in array order, so it replays.
    /// Deterministic, no draws.
    private static func bleedStrength(_ state: inout GameState, _ balance: BalanceConfig) {
        let depth = balance.rivals.depth
        guard depth.strengthPerWeekBeaten > 0 || depth.standingPerWeekBeaten > 0 else { return }
        let day = state.day
        for topicID in state.rivals.playerShare.keys.sorted() {
            let share = state.rivals.playerShare[topicID] ?? 1
            let competing = state.rivals.rivals.indices.filter {
                state.rivals.rivals[$0].bestProduct(in: topicID, on: day) != nil
            }
            guard !competing.isEmpty else { continue }
            if share > 0.5 {
                for index in competing {
                    state.rivals.rivals[index].strength = clamp(
                        state.rivals.rivals[index].strength - depth.strengthPerWeekBeaten,
                        min: 1, max: 100
                    )
                }
            } else if share < 0.5 {
                StandingSystem.adjust(-depth.standingPerWeekBeaten, in: topicID, &state, balance)
            }
        }
    }

    /// The player's best live product in a topic: its id and its review
    /// score, the standard the share pass uses. Ties break on the id
    /// string so the pick replays identically.
    static func playerBestProduct(in topicID: String, _ state: GameState) -> (id: UUID, score: Int)? {
        state.products
            .compactMap { product -> (id: UUID, score: Int)? in
                guard product.topicID == topicID,
                      case .released(let info) = product.stage,
                      !info.offMarket
                else { return nil }
                return (product.id, info.averageReviewScore)
            }
            .max { lhs, rhs in
                if lhs.score != rhs.score { return lhs.score < rhs.score }
                return lhs.id.uuidString > rhs.id.uuidString
            }
    }

    private static func playerBestScore(in topicID: String, _ state: GameState) -> Int? {
        playerBestProduct(in: topicID, state)?.score
    }

    /// "Let it go": the pending challenge is answered and the sheet comes
    /// down. The settlement still runs at its day — six weeks decide the
    /// category whether or not the player fought for it. Ignored with
    /// nothing pending.
    static func concedeCategory(state: inout GameState) -> [GameEvent] {
        guard let index = state.rivals.challenges.firstIndex(where: \.isPending) else { return [] }
        state.rivals.challenges[index].answeredDay = state.day
        state.rivals.challenges[index].conceded = true
        return []
    }

    /// Answers a challenge with an action the game already has, routed to
    /// the player's best live product in the topic: the budget tier, a
    /// patch, or a social push. The challenge counts as answered only when
    /// the routed action took effect — a patch with no free build slot or
    /// a campaign on cooldown leaves it open, and returns nothing, so the
    /// sheet does not close on an answer that did nothing. Works on a
    /// fight already answered, too: a second defence is still a defence.
    /// Ignored with no fight in the topic.
    static func defendCategory(
        topicID: String,
        defense: CategoryDefense,
        state: inout GameState,
        balance: BalanceConfig,
        content: ContentCatalog
    ) -> [GameEvent] {
        guard let index = state.rivals.challenges.firstIndex(where: { $0.topicID == topicID }),
              let target = playerBestProduct(in: topicID, state)
        else { return [] }

        let events: [GameEvent]
        let applied: Bool
        switch defense {
        case .budgetPrice:
            events = ProductSystem.setPriceTier(
                productID: target.id, tier: .budget, state: &state, balance: balance
            )
            applied = !events.isEmpty
        case .patch:
            // `startUpdate` returns nothing on success; the patch on the
            // books is the evidence.
            events = ProductSystem.startUpdate(
                productID: target.id, state: &state, balance: balance, content: content
            )
            applied = state.economy.update(for: target.id) != nil
        case .campaign:
            events = MarketingSystem.startCampaign(
                kindID: CampaignKind.socialPush.rawValue, productID: target.id,
                state: &state, balance: balance, content: content
            )
            applied = !events.isEmpty
        }
        guard applied else { return [] }
        if state.rivals.challenges[index].answeredDay == nil {
            state.rivals.challenges[index].answeredDay = state.day
        }
        return events
    }

    // MARK: - The incumbent

    /// Once the company is worth having — valuation past
    /// `incumbentValuationFloor`, or `incumbentDominatedTopics` topics
    /// owned outright where that trigger is on — and no incumbent has
    /// ever been founded, a giant is
    /// founded into the player's two best markets: deep pockets (it never
    /// folds), strength `incumbentStrengthFactor × valuation /
    /// valuationPerStrength` clamped to its band, reputation rolled in
    /// its band, focus = the two topics where the player has the highest
    /// standing *and* something live. It ships into the higher at once
    /// and opens a challenge there, whatever the standing or the score:
    /// this one is the fight the late game was missing. Worth ~$600k at
    /// strength 95, it is also the buyer the strategic buyout was written
    /// for, and it can be bought.
    ///
    /// Draws, in order: two id words, the name pick, the reputation roll,
    /// the appearance seed, then the opener's id, two name words and a
    /// quality jitter — and only when it founds, so a world that never
    /// crosses the line never draws. Once per run, and never at
    /// `rivalCount = 0`, where there is no field for it to join.
    private static func incumbentCheck(
        _ state: inout GameState,
        _ balance: BalanceConfig,
        _ content: ContentCatalog
    ) -> [GameEvent] {
        let config = balance.rivals
        let depth = config.depth
        guard depth.incumbentEnabled,
              config.rivalCount > 0,
              state.rivals.incumbentFoundedDay == nil,
              state.rivals.incumbent == nil
        else { return [] }
        let valuation = state.companyValuation(balance: balance)
        // The second trigger is off at 0: see `DepthBalance` for why two
        // owned topics is not a size.
        let dominates = depth.incumbentDominatedTopics > 0
            && state.rivals.dominatedTopicCount >= depth.incumbentDominatedTopics
        guard valuation >= depth.incumbentValuationFloor || dominates else { return [] }

        // Its markets: the two the player holds highest and is live in.
        // "Highest standing" alone can name a category whose products are
        // long off the market; the live filter is what makes it a fight.
        let focus = Array(
            StandingSystem.liveTopicIDs(state)
                .sorted { lhs, rhs in
                    let left = state.market.standing(for: lhs)
                    let right = state.market.standing(for: rhs)
                    if left != right { return left > right }
                    return lhs < rhs
                }
                .prefix(2)
        )
        guard let opening = focus.first else { return [] }

        let id = UUID(from: &state.worldRNG)
        let name = studioName(&state, content)
        let strength = clamp(
            depth.incumbentStrengthFactor * Double(valuation) / config.valuationPerStrength,
            min: depth.incumbentStrengthMin, max: depth.incumbentStrengthMax
        )
        let reputation = depth.incumbentReputationMin
            + state.worldRNG.nextUniform() * (depth.incumbentReputationMax - depth.incumbentReputationMin)
        let appearanceSeed = state.worldRNG.next()
        var rival = Rival(
            id: id,
            name: name,
            strength: strength,
            reputation: reputation,
            focusTopicIDs: focus,
            foundedDay: state.day,
            appearanceSeed: appearanceSeed,
            personality: .deepPockets,
            isIncumbent: true
        )
        let opener = launchProduct(for: rival, in: opening, &state, balance, content)
        rival.products = [opener]
        rival.lastShippedDay = state.day
        state.rivals.rivals.append(rival)
        state.rivals.incumbentFoundedDay = state.day
        state.rivals.incumbentHeldSinceDay = nil

        var events: [GameEvent] = [
            .incumbentArrived(rivalID: id, name: name, day: state.day),
            .rivalProductLaunched(
                rivalID: id,
                productName: opener.name,
                topicID: opening,
                quality: Int(opener.quality.rounded()),
                day: state.day
            ),
        ]
        if state.rivals.challenge(in: opening) == nil {
            events.append(openChallenge(
                rivalID: id, topicID: opening, productName: opener.name,
                quality: opener.quality, &state, depth
            ))
        }
        return events
    }

    /// The incumbent can be beaten: hold `challengeHoldShare` in every
    /// topic on its list for `incumbentRetreatWeeks` running and it gives
    /// them up — drops the topics and its products in them, stops being
    /// the incumbent (an ordinary, large, buyable rival stays on the
    /// board), and pays the player `incumbentRetreatReputationGain` and
    /// `incumbentRetreatStandingGain` in each. The clock starts on the
    /// first weekly pass the player holds every topic and resets the
    /// first week they do not. A topic the player has nothing live in is
    /// not held. Deterministic, no draws.
    private static func incumbentRetreatCheck(
        _ state: inout GameState,
        _ balance: BalanceConfig
    ) -> [GameEvent] {
        let depth = balance.rivals.depth
        guard let index = state.rivals.rivals.firstIndex(where: \.isIncumbent) else {
            state.rivals.incumbentHeldSinceDay = nil
            return []
        }
        let topics = state.rivals.rivals[index].focusTopicIDs
        let holding = !topics.isEmpty && topics.allSatisfy {
            (state.rivals.playerShare[$0] ?? 0) >= depth.challengeHoldShare
        }
        guard holding else {
            state.rivals.incumbentHeldSinceDay = nil
            return []
        }
        let since = state.rivals.incumbentHeldSinceDay ?? state.day
        state.rivals.incumbentHeldSinceDay = since
        guard state.day - since >= depth.incumbentRetreatWeeks * GameState.daysPerWeek else { return [] }

        let rival = state.rivals.rivals[index]
        state.rivals.rivals[index].focusTopicIDs = []
        state.rivals.rivals[index].products.removeAll { topics.contains($0.topicID) }
        state.rivals.rivals[index].isIncumbent = false
        // A war over a market it just gave up ends with it.
        state.rivals.rivals[index].priceWarUntilDay = nil
        state.rivals.rivals[index].priceWarTopicID = nil
        state.rivals.rivals[index].weeksBeaten = 0
        state.rivals.incumbentHeldSinceDay = nil
        state.company.reputation = clamp(
            state.company.reputation + depth.incumbentRetreatReputationGain, min: 0, max: 100
        )
        for topicID in topics {
            StandingSystem.adjust(depth.incumbentRetreatStandingGain, in: topicID, &state, balance)
        }
        return [.incumbentRetreated(rivalID: rival.id, name: rival.name, day: state.day)]
    }

    // MARK: Iteration 11 — N1 (crime and the courtroom: the story, the suit)

    /// A story about a studio, placed with a desk that owed the founder a
    /// favour. Their reputation takes the hit; if it is traced back to
    /// you, they come back at it harder — a rival who knows who did it is
    /// a rival with something to prove.
    ///
    /// One `socialRNG` word for the trace, and only from `CrimeSystem`'s
    /// offence handler, which is only ever reached by a button press.
    static func crimePlantStory(
        against rivalID: UUID?,
        state: inout GameState,
        balance: BalanceConfig
    ) -> (name: String, traced: Bool)? {
        let config = balance.crime
        guard let index = rivalID.flatMap({ id in
            state.rivals.rivals.firstIndex { $0.id == id }
        }) ?? (state.rivals.rivals.isEmpty ? nil : 0) else { return nil }

        state.rivals.rivals[index].reputation = max(0,
            state.rivals.rivals[index].reputation - config.plantStoryReputationHit
        )
        let traced = state.socialRNG.nextUniform() < 0.35
        if traced {
            state.rivals.rivals[index].strength = min(100,
                state.rivals.rivals[index].strength + config.plantStoryStrengthGift
            )
        }
        return (state.rivals.rivals[index].name, traced)
    }

    /// A studio the founder has just beaten in court: damages out of their
    /// size, a dent in their standing, and — where the balance allows it —
    /// the newest thing on their shelf, withdrawn.
    ///
    /// Draws nothing.
    static func crimeAwardDamages(
        against rivalID: UUID,
        state: inout GameState,
        balance: BalanceConfig
    ) -> (damages: Int, productTaken: String?) {
        let config = balance.crime
        guard let index = state.rivals.rivals.firstIndex(where: { $0.id == rivalID })
        else { return (0, nil) }

        let damages = Int((state.rivals.rivals[index].strength
            * config.suitDamagesPerStrength / 10).rounded())
        state.rivals.rivals[index].reputation = max(0,
            state.rivals.rivals[index].reputation - 8
        )
        var taken: String?
        if config.suitTakesProduct,
           let productIndex = state.rivals.rivals[index].products.indices.last {
            taken = state.rivals.rivals[index].products[productIndex].name
            state.rivals.rivals[index].products.remove(at: productIndex)
            state.rivals.rivals[index].strength = max(5,
                state.rivals.rivals[index].strength - 6
            )
        }
        return (damages, taken)
    }

    /// The NDA poach lands: the studio it came out of is measurably
    /// smaller for it.
    static func crimeLostAnEngineer(_ rivalID: UUID?, state: inout GameState) {
        guard let index = rivalID.flatMap({ id in
            state.rivals.rivals.firstIndex { $0.id == id }
        }) else { return }
        state.rivals.rivals[index].strength = max(5, state.rivals.rivals[index].strength - 3)
    }

    // MARK: end of Iteration 11 — N1

    // MARK: Iteration 11, wave two — W3 (espionage)

    /// The grudge an operation earns, whether or not it was traced. Never
    /// downwards: a studio that has been done to does not forget because
    /// the next one went better.
    static func espionageGrudge(_ rivalID: UUID, to value: Double, state: inout GameState) {
        guard let index = state.rivals.rivals.firstIndex(where: { $0.id == rivalID })
        else { return }
        state.rivals.rivals[index].grudge = min(
            100, max(state.rivals.rivals[index].grudge, value)
        )
    }

    /// A sweep of your own office takes some of it back: they pulled the
    /// operation, and pulling an operation costs them something to be
    /// angry with.
    static func espionageCoolGrudge(_ rivalID: UUID, by relief: Double, state: inout GameState) {
        guard let index = state.rivals.rivals.firstIndex(where: { $0.id == rivalID })
        else { return }
        state.rivals.rivals[index].grudge = max(0, state.rivals.rivals[index].grudge - relief)
    }

    /// The dirty poach landed: the studio it came out of is measurably
    /// smaller, and it was their best person, not a spare one.
    static func espionageLostTheirBest(
        _ rivalID: UUID, state: inout GameState, balance: BalanceConfig
    ) {
        guard let index = state.rivals.rivals.firstIndex(where: { $0.id == rivalID })
        else { return }
        state.rivals.rivals[index].strength = max(
            5, state.rivals.rivals[index].strength - balance.espionage.poachStrengthHit
        )
    }

    /// Their roadmap walked out of the building: what is left is a year of
    /// work somebody else now also has.
    static func espionageRoadmapWalked(
        _ rivalID: UUID, state: inout GameState, balance: BalanceConfig
    ) {
        guard let index = state.rivals.rivals.firstIndex(where: { $0.id == rivalID })
        else { return }
        state.rivals.rivals[index].strength = max(
            5, state.rivals.rivals[index].strength - balance.espionage.roadmapStrengthHit
        )
    }

    /// A week of error pages: their newest competing product sells a
    /// fraction of what it was selling, and the shop's name takes the
    /// reputation for it. Returns the weekly units that stopped, for the
    /// journal line.
    @discardableResult
    static func espionageHackStorefront(
        _ rivalID: UUID, state: inout GameState, balance: BalanceConfig
    ) -> Int {
        guard let index = state.rivals.rivals.firstIndex(where: { $0.id == rivalID })
        else { return 0 }
        let config = balance.espionage
        let day = state.day
        guard let productIndex = state.rivals.rivals[index].products.lastIndex(where: {
            $0.isCompeting(on: day)
        }) else { return 0 }
        let before = state.rivals.rivals[index].products[productIndex].weeklyUnits
        let after = Int((Double(before) * (1 - config.hackUnitsFraction)).rounded())
        state.rivals.rivals[index].products[productIndex].weeklyUnits = after
        state.rivals.rivals[index].reputation = max(
            0, state.rivals.rivals[index].reputation - config.hackReputationHit
        )
        return before - after
    }

    /// The founder was waiting for the launch the mole reported: it lands
    /// into a market that already had somebody in it.
    static func espionageIntercepted(
        _ rivalID: UUID, state: inout GameState, balance: BalanceConfig
    ) {
        guard let index = state.rivals.rivals.firstIndex(where: { $0.id == rivalID })
        else { return }
        let penalty = balance.espionage.interceptQualityPenalty
        state.rivals.rivals[index].strength = max(
            5, state.rivals.rivals[index].strength - penalty / 4
        )
        if let productIndex = state.rivals.rivals[index].products.indices.last {
            state.rivals.rivals[index].products[productIndex].quality = max(
                10, state.rivals.rivals[index].products[productIndex].quality - penalty
            )
        }
    }

    /// The mole was fed the wrong plan: the studio spends its next quarter
    /// on the topic with the weakest demand on the board, and comes out of
    /// it smaller.
    @discardableResult
    static func espionageFalsePlans(
        _ rivalID: UUID, state: inout GameState, balance: BalanceConfig
    ) -> String? {
        guard let index = state.rivals.rivals.firstIndex(where: { $0.id == rivalID })
        else { return nil }
        let worst = state.market.topics
            .sorted { ($0.value.multiplier, $0.key) < ($1.value.multiplier, $1.key) }
            .first?.key
        if let worst {
            state.rivals.rivals[index].focusTopicIDs = [worst]
        }
        state.rivals.rivals[index].strength = max(
            5, state.rivals.rivals[index].strength - balance.espionage.falsePlansStrengthHit
        )
        // MARK: J3 (rivals and the market)
        // …and when it next copies you, it copies the wrong thing.
        rivalMarketFedFalsePlans(rivalID, state: &state)
        // MARK: end J3
        return worst
    }

    // MARK: end of Iteration 11, wave two — W3

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
        // MARK: Iteration 9 — L6 (sabbatical)
        // Recruiters read the trade press: an absent founder raises the
        // odds. Exactly 1 whenever nobody is away, and the draw itself is
        // unchanged either way, so the `worldRNG` stream never moves.
        let awayFactor = SabbaticalEffects.poachChanceFactor(state, balance: balance)
        // MARK: end Iteration 9 — L6
        // MARK: K4 (deals and exits)
        // A company with a for-sale sign up is a company recruiters call.
        // Exactly 1 while no sign stands, so the comparison is unchanged.
        let listedFactor = state.dealPoachFactor(balance: balance)
        // MARK: end K4
        let roll = state.worldRNG.nextUniform()
        guard roll < config.poachChance * resistance * appetite * awayFactor * listedFactor else { return [] }

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
        // MARK: S1 (seating) — the desk by the door; nil with no plan.
        let seatingDoorID = state.seatingDoorOccupantID()
        // MARK: end S1
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
                    // MARK: K3 (the ladder) — a holder's unvested options; 0 for everyone else.
                    + state.ladderPoachScoreDelta(employee, fairPay: fairPay, underpaidWeight: config.poachUnderpaidWeight, balance: balance)
                    // MARK: end K3
                    // MARK: S1 (seating) — the first desk a recruiter sees; 0 for everyone else.
                    + (employee.id == seatingDoorID ? balance.seating.doorPoachWeight : 0)
                    // MARK: end S1
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
        events.append(contentsOf: NetworkingSystem.departed(employee, reason: .poached, poachOffer: offer.offeredWeeklySalary, state: &state, balance: balance))
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
              // Iteration 7 (R5): nobody bids for a company that already
              // had its ending. The guard sits before the draw, so an
              // epilogue run's `worldRNG` differs from a hypothetical
              // continuation of the same seed — and no other run has an
              // epilogue, so every pinned suite is byte-identical.
              state.epilogue == nil,
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
        // The draw happens either way, so the grace period below cannot
        // shift `worldRNG` for anything else in the world.
        guard roll < config.buyoutChance,
              state.day >= (config.buyoutEarliestDay ?? 0)
        else { return [] }

        // Both paths draw exactly one more uniform, so the world stream
        // advances identically whichever approach this is.
        let multiplier: Double = if strong {
            exits.strategicPremiumMin
                + state.worldRNG.nextUniform() * (exits.strategicPremiumMax - exits.strategicPremiumMin)
        } else {
            // K4: extracted (`distressFraction`), the same draw and the
            // same arithmetic, so the sell-up can price the midpoint.
            distressFraction(config, uniform: state.worldRNG.nextUniform())
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

    /// Sells the company for cash today. The sale posts to the ledger and
    /// the run ends — as which ending depends on which kind of approach
    /// this was.
    ///
    /// A *strategic* offer (`lastBuyoutWasStrategic`) is somebody paying a
    /// premium for what was built: `.acquired`, a win. A *distress* bid is
    /// a rival picking up the name and the desks from a company that is
    /// broke or unknown: `.soldUp`, which is not. Both used to land on the
    /// same crowned screen, so a fire sale on day 56 with nothing shipped
    /// read as the best ending in the game. Ignored with nothing pending.
    static func acceptBuyout(state: inout GameState) -> [GameEvent] {
        guard let offer = state.rivals.pendingBuyout else { return [] }
        state.rivals.pendingBuyout = nil
        let buyerName = state.rivals.rival(id: offer.rivalID)?.name ?? "a rival"
        let strategic = state.rivals.lastBuyoutWasStrategic

        state.company.cash += offer.amount
        state.ledger.post(LedgerEntry(
            day: state.day,
            amount: offer.amount,
            category: .other,
            label: "Company sale to \(buyerName)"
        ))
        state.gameOver = GameOverInfo(
            day: state.day,
            reason: strategic
                ? "Acquired by \(buyerName) for \(offer.amount.dollars)."
                : "\(buyerName) bought the name and the desks for \(offer.amount.dollars).",
            kind: strategic ? .acquired : .soldUp
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
    /// seed) — then its shelf: every product still competing joins the
    /// player's line as released and on the market, in its topic, with
    /// reviews synthesised from its quality (one `worldRNG` word per
    /// review, for the blurb). Acquisition buys a category, not a
    /// reputation bump. The rival leaves the field for good.
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
        return absorbRival(at: rivalIndex, state: &state, balance: balance, content: content)
    }

    /// What every acquisition does once it is paid for, cash or paper:
    /// the reputation bonus, part of their team, the shelf that beats
    /// yours, and the rival off the board for good. Draws as
    /// `acquireRival` describes.
    private static func absorbRival(
        at rivalIndex: Int,
        state: inout GameState,
        balance: BalanceConfig,
        content: ContentCatalog
    ) -> [GameEvent] {
        let config = balance.rivals
        let rival = state.rivals.rivals[rivalIndex]
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
        absorbShelf(of: rival, state: &state, balance: balance, content: content)

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

    /// The shelf that comes with an acquired rival (WS-A, iteration 5): in
    /// every topic the player is live in, the rival's best product still
    /// on the market there — when it scores above the player's best —
    /// becomes a released player product in that topic, on the market
    /// from its own launch day, so an older app sells like an older app.
    /// Topics in sorted order, so it replays. Its reviews are synthesised
    /// from its quality: the score with a small fixed spread across the
    /// outlets so the average lands on the quality, and a blurb picked
    /// the way a launch picks one, one `worldRNG` word each.
    ///
    /// That is what "buys a category" means: the product that was beating
    /// you becomes yours; one worse than yours is shut down, and apps in
    /// categories you have nothing in are not what you paid for. It is
    /// also what keeps the investor suite honest. Measured with the whole
    /// shelf absorbed, a funded founder who had stopped growing could buy
    /// a minnow a quarter and have its month-old launches counted as
    /// their own ships, and the board never removed anybody; every
    /// absorbed app also counts as the studio's own recent release when
    /// its next launch in that topic is scaled for a crowded shelf.
    private static func absorbShelf(
        of rival: Rival,
        state: inout GameState,
        balance: BalanceConfig,
        content: ContentCatalog
    ) {
        guard balance.rivals.depth.acquisitionAbsorbsShelf else { return }
        let day = state.day
        let shelf = StandingSystem.liveTopicIDs(state).sorted().compactMap { topicID -> RivalProduct? in
            guard let theirs = rival.bestProduct(in: topicID, on: day),
                  let ours = playerBestProduct(in: topicID, state),
                  theirs.quality > Double(ours.score)
            else { return nil }
            return theirs
        }
        guard !shelf.isEmpty else { return }
        let outlets = balance.reviewOutlets.isEmpty ? ["The Trade"] : balance.reviewOutlets
        // Around the quality, summing to nothing over four outlets.
        let spread = [-2, 1, -1, 2]

        for item in shelf {
            let type = content.productType(item.typeID) ?? content.productTypes.first
            let context = ReviewContext(
                productName: item.name,
                typeName: type?.name ?? "app",
                topicName: content.topic(item.topicID)?.name ?? item.topicID,
                bugRatio: 0,
                polishRatio: 1,
                hype: 0,
                marketScale: 1
            )
            var reviews: [Review] = []
            for (index, outlet) in outlets.enumerated() {
                let score = min(
                    balance.reviewCeiling,
                    max(balance.reviewFloor, Int(item.quality.rounded()) + spread[index % spread.count])
                )
                reviews.append(Review(
                    outlet: outlet,
                    score: score,
                    blurb: ReviewBlurbs.pick(
                        for: score, rng: &state.worldRNG,
                        outlet: outlet, context: context, catalog: content.reviews
                    )
                ))
            }
            state.products.append(Product(
                id: item.id,
                name: item.name,
                typeID: type?.id ?? item.typeID,
                topicID: item.topicID,
                stage: .released(ReleaseInfo(
                    launchDay: item.launchDay,
                    quality: item.quality,
                    reviews: reviews,
                    weeklySales: [],
                    offMarket: false,
                    isSubscription: type?.revenueModel == .subscription
                ))
            ))
        }
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

    // MARK: K4 (deals and exits)

    /// The distress bid's fraction of valuation, `uniform` 0…1 across
    /// `offerFractionMin…Max`. `buyoutCheck` passes its draw; the sell-up
    /// passes the midpoint and draws nothing.
    static func distressFraction(_ config: BalanceConfig.RivalBalance, uniform: Double) -> Double {
        config.offerFractionMin + uniform * (config.offerFractionMax - config.offerFractionMin)
    }

    /// The for-sale sign's bids, daily while it stands (`Deals.swift`).
    /// Draws nothing: every `bidIntervalDays`, with nothing else on the
    /// desk, the bid lands on `pendingBuyout` and the board takes
    /// `deals.boardPressure`. (The morale drag is `EmployeeSystem`'s
    /// target; the poach odds are `poachCheck`'s; launch hype is the
    /// ship's.)
    private static func dealListingCheck(_ state: inout GameState, _ balance: BalanceConfig) -> [GameEvent] {
        guard var listing = state.rivals.listing, state.epilogue == nil else { return [] }
        let deals = balance.deals
        let elapsed = state.day - listing.sinceDay
        guard elapsed > 0 else { return [] }
        var events: [GameEvent] = []
        let interval = max(1, deals.bidIntervalDays)
        if elapsed % interval == 0, state.rivals.pendingBuyout == nil,
           let bid = state.dealListingBid(number: elapsed / interval, balance: balance) {
            let offer = BuyoutOffer(
                rivalID: bid.rivalID,
                amount: bid.amount,
                respondByDay: state.day + balance.rivals.buyoutResponseDays
            )
            state.rivals.pendingBuyout = offer
            state.rivals.lastBuyoutWasStrategic = bid.isStrategic
            listing.bids += 1
            listing.lastBid = bid.amount
            dealBoardPressure(&state, balance)
            events.append(.buyoutOffered(
                rivalID: bid.rivalID, amount: bid.amount, respondByDay: offer.respondByDay, day: state.day
            ))
        }
        state.rivals.listing = listing
        return events
    }

    /// The board reads the papers: `deals.boardPressure` when the sign goes
    /// up and with every bid, when there is a board.
    private static func dealBoardPressure(_ state: inout GameState, _ balance: BalanceConfig) {
        guard state.investors.hasBoard, balance.deals.boardPressure > 0 else { return }
        state.investors.boardPressure = min(
            balance.investors.boardOustPressure,
            state.investors.boardPressure + balance.deals.boardPressure
        )
    }

    /// Hangs the sign. Refused for the reasons `dealListingBlocker` says.
    static func dealListForSale(
        askMultiple: Double,
        state: inout GameState,
        balance: BalanceConfig
    ) -> [GameEvent] {
        guard state.dealListingBlocker(balance: balance) == nil else { return [] }
        let ask = GameState.dealClampedAsk(askMultiple, balance: balance)
        let price = Int((Double(state.companyValuation(balance: balance)) * ask).rounded())
        state.rivals.listing = DealListing(askingPrice: price, askMultiple: ask, sinceDay: state.day)
        dealBoardPressure(&state, balance)
        return [.dealListed(ask: price, multiple: ask, day: state.day)]
    }

    /// Takes the sign down. Ignored with no sign up.
    static func dealTakeDownSign(state: inout GameState) -> [GameEvent] {
        guard let listing = state.rivals.listing else { return [] }
        state.rivals.listing = nil
        return [.dealSignTakenDown(
            weeks: max(0, (state.day - listing.sinceDay) / GameState.daysPerWeek), day: state.day
        )]
    }

    /// Sells up before the receiver (`dealSellUpOffer`): the run ends as
    /// *Sold up* today, the wallet and the address book intact. Ignored
    /// out of the red.
    static func dealSellUp(state: inout GameState, balance: BalanceConfig) -> [GameEvent] {
        guard let offer = state.dealSellUpOffer(balance: balance) else { return [] }
        state.rivals.pendingBuyout = nil
        state.rivals.lastBuyoutWasStrategic = false
        state.company.cash += offer.amount
        state.ledger.post(LedgerEntry(
            day: state.day,
            amount: offer.amount,
            category: .other,
            label: "Company sale to \(offer.buyerName)"
        ))
        state.gameOver = GameOverInfo(
            day: state.day,
            reason: "Sold on day \(offer.daysInDebt) of \(offer.graceDays) in the red: "
                + "\(offer.buyerName) bought the name and the desks for \(offer.amount.dollars).",
            kind: .soldUp
        )
        var events: [GameEvent] = [.dealSoldUp(
            buyer: offer.buyerName, amount: offer.amount, daysInDebt: offer.daysInDebt, day: state.day
        )]
        if let rivalID = offer.rivalID {
            events.append(.companySold(rivalID: rivalID, amount: offer.amount, day: state.day))
        }
        events.append(.gameOver(day: state.day))
        return events
    }

    /// Buys a rival with paper (`dealStockTerms`): their founder takes the
    /// equity and a board seat — a round of `amount 0` that expects a ship
    /// every quarter, so the review, the pressure and the buyback treat
    /// them like any seated round — and joins the address book as a
    /// founder, minted from the rival's own seed on a private stream. Then
    /// the team and the shelf come over exactly as they do for cash.
    static func dealAcquireForStock(
        rivalID: UUID,
        state: inout GameState,
        balance: BalanceConfig,
        content: ContentCatalog
    ) -> [GameEvent] {
        guard let rivalIndex = state.rivals.rivals.firstIndex(where: { $0.id == rivalID }) else { return [] }
        let rival = state.rivals.rivals[rivalIndex]
        let terms = state.dealStockTerms(for: rival, balance: balance, content: content)
        guard terms.isOpen else { return [] }
        let deals = balance.deals
        let hadBoard = state.investors.hasBoard

        state.investors.equityRemaining = max(0, state.investors.equityRemaining - terms.equity)
        state.investors.rounds.append(RaisedRound(
            investorID: RaisedRound.dealPaperPrefix + rival.id.uuidString,
            investorName: "\(terms.founderName), ex-\(rival.name)",
            amount: 0,
            equity: terms.equity,
            valuation: state.companyValuation(balance: balance),
            day: state.day,
            takesBoardSeat: true,
            expects: .shipCadence,
            patienceWeeks: deals.stockPatienceWeeks
        ))
        // A first seat starts the clock from today's numbers, as a first
        // board-seat round does; a room that already sits keeps its own.
        // No cheque came with it, so no pressure is forgiven.
        if !hadBoard {
            state.investors.lastQuarterCash = state.company.cash
            state.investors.lastQuarterHeadcount = state.headcount
        }

        var stream = SeededRNG(seed: rival.appearanceSeed)
        let ceiling = clamp(20 + rival.strength * 0.6, min: 20, max: 90)
        let skills = SkillSet(coding: ceiling * 0.7, design: ceiling * 0.6, marketing: ceiling)
        let salary = (Double(balance.salaryBase) + balance.salaryPerSkillPoint * skills.total) * 1.15
        state.networking.contacts.append(Contact(
            id: UUID(from: &stream),
            name: terms.founderName,
            appearanceSeed: rival.appearanceSeed,
            archetype: .founder,
            skills: skills,
            askingSalary: Int(salary.rounded()),
            rapport: deals.stockFounderRapport,
            interest: 50,
            metDay: state.day,
            lastMetDay: state.day,
            isRevealed: true
        ))

        var events = absorbRival(at: rivalIndex, state: &state, balance: balance, content: content)
        events.append(.dealPaperSigned(
            rivalID: rival.id, name: rival.name, founder: terms.founderName, equity: terms.equity, day: state.day
        ))
        return events
    }

    // MARK: end K4

    // MARK: J3 (rivals and the market)
    /// The share pass, for `RivalSystem+RivalMarket.swift`: an answered
    /// war lands on this week's share, not next week's.
    static func rivalMarketRecomputeShare(_ state: inout GameState, _ balance: BalanceConfig) {
        recomputeShare(&state, balance)
    }
    // MARK: end J3

    private static func pick(_ pool: [String], _ rng: inout SeededRNG) -> String? {
        guard !pool.isEmpty else { return nil }
        return pool[rng.nextInt(in: 0...(pool.count - 1))]
    }

    private static func clamp(_ value: Double, min lower: Double, max upper: Double) -> Double {
        min(upper, max(lower, value))
    }
}
