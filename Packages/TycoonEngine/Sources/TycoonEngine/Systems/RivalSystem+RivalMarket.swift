import Foundation
import TycoonContent

// Iteration 12 — J3. The rival system's half of rivals following the
// money, the price war's answers and the copied card. Called from marked
// lines in `RivalSystem.swift`; see `RivalMarket.swift` for the gates.
//
// Draws: none. The launch topic is the single `worldRNG` word
// `RivalSystem.evolve` always took for it — `nextInt`'s one word before
// the market is opened, `nextUniform`'s one word after — so the stream
// advances exactly as it did.

extension RivalSystem {

    // MARK: - The launch topic and type

    /// A rival's launch topic. Before the market is opened, exactly the
    /// old pick (`pool[next() % count]`). After, the same one word read as
    /// a uniform and mapped through `multiplier ^ topicWeightExponent`, in
    /// focus-list order — except that a studio which moved in on a boom
    /// and has not shipped since ships *there*: that is what moving in
    /// means, and it is what makes "company within a quarter" true at a
    /// 10% weekly ship chance. Measured without it, the entrant collected
    /// every boom on the board (3–7 focus topics) and reached the shelf
    /// inside 26 weeks on 2 seeds of 7. The word is drawn either way.
    static func rivalMarketLaunchTopic(
        _ rival: Rival,
        _ state: inout GameState,
        _ balance: BalanceConfig
    ) -> String? {
        let pool = rival.focusTopicIDs
        guard !pool.isEmpty else { return nil }
        guard state.rivalMarket.noticed else {
            return pool[state.worldRNG.nextInt(in: 0...(pool.count - 1))]
        }
        let word = state.worldRNG.nextUniform()
        if let entry = state.rivalMarket.moves.last(where: { move in
            move.rivalID == rival.id && move.kind == .boomEntry
                && move.day > (rival.lastShippedDay ?? Int.min)
                && pool.contains(move.topicID)
                && rival.bestProduct(in: move.topicID, on: state.day) == nil
        }) {
            return entry.topicID
        }
        let exponent = balance.rivalMarket.topicWeightExponent
        let weights = pool.map {
            RivalMarket.weight(multiplier: state.market.multiplier(for: $0), exponent: exponent)
        }
        let total = weights.reduce(0, +)
        let target = word * total
        var running = 0.0
        for (index, weight) in weights.enumerated() {
            running += weight
            if target < running { return pool[index] }
        }
        return pool[pool.count - 1]
    }

    /// The type a rival ships into a topic, or `nil` to keep the old
    /// first-of-the-catalog type — which is what it is until the market
    /// has been opened, so every rival product already in a save, and
    /// every one in a run that never opens the market, keeps its bytes.
    static func rivalMarketProductType(
        for topicID: String,
        _ state: GameState,
        _ content: ContentCatalog
    ) -> String? {
        guard state.rivalMarket.noticed else { return nil }
        return RivalMarket.productTypeID(for: topicID, content: content)
    }

    // MARK: - Booms and crashes

    /// The weekly moves, before the week's launches: a studio into every
    /// topic that crossed the boom line on this shift, and out of every
    /// focus topic that has sat under the crash line for a month.
    ///
    /// Reads `MarketState.history`, which `MarketSystem` appended on this
    /// same weekly day, so "the week it crossed" needs no state of its
    /// own. Topics in catalog order, rivals in array order; no draws.
    static func rivalMarketMoves(
        _ state: inout GameState,
        _ balance: BalanceConfig,
        _ content: ContentCatalog
    ) -> [GameEvent] {
        guard state.rivalMarket.noticed else { return [] }
        let config = balance.rivalMarket
        let boomLine = balance.featureBoard.boomAppetiteThreshold
        let day = state.day
        var events: [GameEvent] = []
        let live = StandingSystem.liveTopicIDs(state)

        // The boom brings company: the strongest studio above the line
        // that is not already there. The incumbent is camped where it is;
        // a ghost replays its own launches.
        for topic in content.topics {
            let samples = state.market.history[topic.id] ?? []
            guard let now = samples.last, now >= boomLine else { continue }
            let before = samples.count >= 2 ? samples[samples.count - 2] : 1.0
            guard before < boomLine else { continue }
            let candidates = state.rivals.rivals.indices.filter { index in
                let rival = state.rivals.rivals[index]
                return !rival.isIncumbent && !rival.isGhost
                    && rival.strength > config.entrantMinStrength
                    && !rival.focusTopicIDs.contains(topic.id)
            }
            guard let index = candidates.max(by: { lhs, rhs in
                let left = state.rivals.rivals[lhs]
                let right = state.rivals.rivals[rhs]
                if left.strength != right.strength { return left.strength < right.strength }
                return left.id.uuidString > right.id.uuidString
            }) else { continue }
            let rival = state.rivals.rivals[index]
            state.rivals.rivals[index].focusTopicIDs.append(topic.id)
            rivalMarketRecord(RivalMarketMove(
                rivalID: rival.id, rivalName: rival.name, topicID: topic.id,
                day: day, kind: .boomEntry, multiplier: now
            ), &state, config)
            if live.contains(topic.id) {
                state.narrative.flags.insert(RivalMarket.companyFlag)
            }
            events.append(.rivalMarketEntered(rivalID: rival.id, topicID: topic.id, day: day))
        }

        // The crash empties it: a month under the line and the topic comes
        // off the list. Every studio keeps one topic — the least-bad one,
        // earliest in its list on a tie.
        let shifts = max(1, config.crashDropShifts)
        func crashed(_ topicID: String) -> Bool {
            let samples = state.market.history[topicID] ?? []
            return samples.count >= shifts
                && samples.suffix(shifts).allSatisfy { $0 < config.crashDropMultiplier }
        }
        for index in state.rivals.rivals.indices {
            let rival = state.rivals.rivals[index]
            guard !rival.isIncumbent, !rival.isGhost, rival.focusTopicIDs.count > 1 else { continue }
            var dropped = rival.focusTopicIDs.filter(crashed)
            guard !dropped.isEmpty else { continue }
            if dropped.count == rival.focusTopicIDs.count {
                var keep = dropped[0]
                for topicID in dropped.dropFirst()
                where state.market.multiplier(for: topicID) > state.market.multiplier(for: keep) {
                    keep = topicID
                }
                dropped.removeAll { $0 == keep }
            }
            guard !dropped.isEmpty else { continue }
            state.rivals.rivals[index].focusTopicIDs.removeAll { dropped.contains($0) }
            for topicID in dropped {
                rivalMarketRecord(RivalMarketMove(
                    rivalID: rival.id, rivalName: rival.name, topicID: topicID,
                    day: day, kind: .crashExit, multiplier: state.market.multiplier(for: topicID)
                ), &state, config)
                events.append(.rivalMarketLeft(rivalID: rival.id, topicID: topicID, day: day))
            }
        }
        return events
    }

    private static func rivalMarketRecord(
        _ move: RivalMarketMove,
        _ state: inout GameState,
        _ config: BalanceConfig.RivalMarketBalance
    ) {
        state.rivalMarket.moves.append(move)
        let overflow = state.rivalMarket.moves.count - max(1, config.moveLogCap)
        if overflow > 0 { state.rivalMarket.moves.removeFirst(overflow) }
    }

    // MARK: - The price war's answers

    /// Answers a rival's war. Returns the refusal, or the week's events.
    static func rivalMarketAnswer(
        rivalID: UUID,
        answer: RivalMarketPriceWarAnswer,
        state: inout GameState,
        balance: BalanceConfig,
        content: ContentCatalog
    ) -> (refusal: RivalMarketPriceWarRefusal?, events: [GameEvent]) {
        let config = balance.rivalMarket
        let day = state.day
        guard let index = state.rivals.rivals.firstIndex(where: { $0.id == rivalID }),
              state.rivals.rivals[index].isInPriceWar(on: day),
              let until = state.rivals.rivals[index].priceWarUntilDay,
              let topicID = state.rivals.rivals[index].priceWarTopicID
        else { return (.noWar, []) }
        let rival = state.rivals.rivals[index]
        guard state.rivalMarket.answer(to: rival) == nil else { return (.answered, []) }
        guard let deadline = RivalMarket.answerDeadline(rival, balance: balance), day <= deadline
        else { return (.windowClosed, []) }

        var record = RivalMarketWarAnswer(
            rivalID: rivalID, topicID: topicID, answer: answer, answeredDay: day, untilDay: until
        )
        var events: [GameEvent] = []
        switch answer {
        case .outlast:
            break
        case .match:
            guard let best = playerBestProduct(in: topicID, state) else { return (.nothingOnSale, []) }
            record.productID = best.id
            if let product = state.product(id: best.id),
               case .released(let info) = product.stage, info.priceTier != .budget {
                record.restoreTier = info.priceTier
                events += ProductSystem.setPriceTier(
                    productID: best.id, tier: .budget, state: &state, balance: balance
                )
            }
            state.rivals.rivals[index].grudge = min(
                100, state.rivals.rivals[index].grudge + config.matchGrudge
            )
            state.narrative.flags.insert(RivalMarket.matchedFlag)
        case .outship:
            guard let best = playerBestProduct(in: topicID, state) else { return (.nothingOnSale, []) }
            record.productID = best.id
            // A patch already underway is the answer; otherwise start one.
            if state.economy.update(for: best.id) == nil {
                guard state.hasFreeDevSlot else { return (.noFreeSlot, []) }
                events += ProductSystem.startUpdate(
                    productID: best.id, state: &state, balance: balance, content: content
                )
                guard state.economy.update(for: best.id) != nil else { return (.cannotPatch, []) }
            }
        }
        state.rivalMarket.answers.append(record)
        // A matched war takes no share from this week on.
        rivalMarketRecomputeShare(&state, balance)
        events.append(.priceWarAnswered(rivalID: rivalID, topicID: topicID, answer: answer, day: day))
        return (nil, events)
    }

    /// Daily, after the week's passes: a patch that landed inside an
    /// out-shipped war ends it; a finished war puts a matched product back
    /// on the tier it came from. Returns on its first line while no war
    /// has ever been answered.
    static func rivalMarketDaily(_ state: inout GameState, _ balance: BalanceConfig) -> [GameEvent] {
        guard !state.rivalMarket.answers.isEmpty else { return [] }
        let day = state.day
        var events: [GameEvent] = []
        var reshare = false
        var kept: [RivalMarketWarAnswer] = []

        for record in state.rivalMarket.answers {
            let index = state.rivals.rivals.firstIndex { $0.id == record.rivalID }
            let running = index.map {
                state.rivals.rivals[$0].isInPriceWar(on: day)
                    && state.rivals.rivals[$0].priceWarUntilDay == record.untilDay
            } ?? false

            if running, record.answer == .outship, let index,
               let productID = record.productID,
               let product = state.product(id: productID),
               case .released(let info) = product.stage,
               let landed = info.lastUpdateDay,
               landed >= record.untilDay - RivalMarket.warDays, landed <= day {
                state.rivals.rivals[index].priceWarUntilDay = nil
                state.rivals.rivals[index].priceWarTopicID = nil
                state.rivals.rivals[index].weeksBeaten = 0
                StandingSystem.adjust(balance.rivalMarket.outshipStanding, in: record.topicID, &state, balance)
                events.append(.priceWarOutshipped(rivalID: record.rivalID, topicID: record.topicID, day: day))
                reshare = true
                continue
            }
            if running {
                kept.append(record)
                continue
            }
            // Over, however it ended: a matched product goes back to what
            // it cost before, unless somebody has re-priced it since.
            if record.answer == .match, let tier = record.restoreTier,
               let productID = record.productID,
               let product = state.product(id: productID),
               case .released(let info) = product.stage, info.priceTier == .budget, !info.offMarket {
                events += ProductSystem.setPriceTier(
                    productID: productID, tier: tier, state: &state, balance: balance
                )
                reshare = true
            }
        }
        state.rivalMarket.answers = kept
        if reshare { rivalMarketRecomputeShare(&state, balance) }
        return events
    }

    /// Weekly, beside the ordinary bleed: a studio whose war you matched
    /// is losing money on every sale.
    static func rivalMarketMatchBleed(_ state: inout GameState, _ balance: BalanceConfig) {
        guard !state.rivalMarket.answers.isEmpty else { return }
        let loss = balance.rivalMarket.matchStrengthPerWeek
        for index in state.rivals.rivals.indices
        where state.rivalMarket.isMatched(state.rivals.rivals[index]) {
            state.rivals.rivals[index].strength = max(1, state.rivals.rivals[index].strength - loss)
        }
    }

    // MARK: - The copied card

    /// W3's false plans: this studio's next clone takes the worst card.
    static func rivalMarketFedFalsePlans(_ rivalID: UUID, state: inout GameState) {
        if !state.rivalMarket.fedFalsePlans.contains(rivalID) {
            state.rivalMarket.fedFalsePlans.append(rivalID)
        }
    }

    /// What a clone lifts and what it is worth. `best` and `worst` are the
    /// names on the target's board (both `nil` for an empty board, which
    /// is every bot's). A studio fed false plans takes the worst and is
    /// cured of it; anything copied makes the clone better.
    static func rivalMarketCopy(
        _ clone: inout RivalProduct,
        rivalID: UUID,
        best: String?,
        worst: String?,
        _ state: inout GameState,
        _ balance: BalanceConfig
    ) {
        if let at = state.rivalMarket.fedFalsePlans.firstIndex(of: rivalID), let worst {
            clone.copiedFeature = worst
            state.rivalMarket.fedFalsePlans.remove(at: at)
        } else {
            clone.copiedFeature = best
        }
        guard clone.copiedFeature != nil else { return }
        clone.quality = min(
            RivalDepthTuning.qualityMax,
            clone.quality + balance.rivalMarket.copiedCloneQualityBonus
        )
        state.narrative.flags.insert(RivalMarket.copiedFlag)
    }

    // MARK: - Debug seeds

    #if DEBUG
    /// `-autoRivalMarket boom|crash`, `-autoPriceWar`, `-autoCopied`: the
    /// world doing the thing a headless pass cannot wait a quarter for.
    /// Everything after the seed — the sheet, the answer, the chip — is the
    /// ordinary game. Debug builds only; nothing in the game sends it.
    static func rivalMarketDebugSeed(
        scenario: String,
        state: inout GameState,
        balance: BalanceConfig,
        content: ContentCatalog
    ) -> [GameEvent] {
        state.rivalMarket.noticed = true
        let day = state.day
        let topicID = state.products.last?.topicID ?? content.topics.first?.id ?? "fitness"
        switch scenario.lowercased() {
        case "boom":
            // The player's topic booms, the forecast is readable, and the
            // strongest studio is strong enough to come.
            let threshold = balance.market.standing.forecastThreshold
            state.market.standing[topicID] = max(state.market.standing(for: topicID), threshold + 6)
            state.market.history[topicID, default: []].append(1.2)
            state.market.history[topicID, default: []].append(1.46)
            let old = state.market.topics[topicID] ?? .neutral
            state.market.topics[topicID] = TopicMarket(
                multiplier: 1.46, lastChange: 0.26, playerShare: old.playerShare
            )
            if let index = state.rivals.rivals.indices
                .filter({ !state.rivals.rivals[$0].isIncumbent && !state.rivals.rivals[$0].isGhost })
                .max(by: { state.rivals.rivals[$0].strength < state.rivals.rivals[$1].strength }) {
                state.rivals.rivals[index].strength = max(state.rivals.rivals[index].strength, 58)
                state.rivals.rivals[index].focusTopicIDs.removeAll { $0 == topicID }
                if state.rivals.rivals[index].focusTopicIDs.isEmpty {
                    state.rivals.rivals[index].focusTopicIDs = [
                        content.topics.first { $0.id != topicID }?.id ?? topicID
                    ]
                }
            }
            return rivalMarketMoves(&state, balance, content)
        case "crash":
            guard let index = state.rivals.rivals.indices.first(where: {
                !state.rivals.rivals[$0].isIncumbent && !state.rivals.rivals[$0].isGhost
            }) else { return [] }
            let doomed = state.rivals.rivals[index].focusTopicIDs.first ?? topicID
            if state.rivals.rivals[index].focusTopicIDs.count < 2,
               let other = content.topics.first(where: { !state.rivals.rivals[index].focusTopicIDs.contains($0.id) }) {
                state.rivals.rivals[index].focusTopicIDs.append(other.id)
            }
            let shifts = max(1, balance.rivalMarket.crashDropShifts)
            state.market.history[doomed, default: []]
                .append(contentsOf: Array(repeating: 0.58, count: shifts))
            let old = state.market.topics[doomed] ?? .neutral
            state.market.topics[doomed] = TopicMarket(
                multiplier: 0.58, lastChange: -0.04, playerShare: old.playerShare
            )
            return rivalMarketMoves(&state, balance, content)
        case "pricewar":
            let productID = rivalMarketDebugReleasedProduct(&state, content)
            guard let product = state.product(id: productID),
                  let index = state.rivals.rivals.indices.first(where: { !state.rivals.rivals[$0].isGhost })
            else { return [] }
            var seed = SeededRNG(seed: state.seed ^ 0x5052_4943_4557_4152)
            let rival = state.rivals.rivals[index]
            appendProduct(RivalProduct(
                id: UUID(from: &seed), name: "Undercut Pro", topicID: product.topicID,
                typeID: product.typeID, quality: 52, launchDay: day - 21,
                weeklyUnits: Int(rival.strength * 40)
            ), to: index, in: &state)
            state.rivals.rivals[index].priceWarUntilDay = day + RivalMarket.warDays
            state.rivals.rivals[index].priceWarTopicID = product.topicID
            rivalMarketRecomputeShare(&state, balance)
            return [.priceWarStarted(
                rivalID: rival.id, topicID: product.topicID, untilDay: day + RivalMarket.warDays, day: day
            )]
        case "copied":
            // Every build's hand: its first card has been lifted — on the
            // board already, or not — so the chip, the slot badge and the
            // verdict are above the fold whichever board the route opens.
            guard let index = state.rivals.rivals.indices.first(where: { !state.rivals.rivals[$0].isGhost })
            else { return [] }
            let builds = state.products.filter {
                if case .development = $0.stage { return true }
                return false
            }
            var seed = SeededRNG(seed: state.seed ^ 0x434F_5059_4341_5421)
            var events: [GameEvent] = []
            for product in builds {
                guard let card = FeatureBoard.hand(
                    for: product, state: state, content: content, balance: balance
                ).first else { continue }
                let rival = state.rivals.rivals[index]
                var clone = RivalProduct(
                    id: UUID(from: &seed), name: "Echo \(card.name)", topicID: product.topicID,
                    typeID: product.typeID, quality: 55, launchDay: day - 7,
                    weeklyUnits: Int(rival.strength * 40)
                )
                clone.copiedFeature = card.name
                appendProduct(clone, to: index, in: &state)
                if !state.rivals.rivals[index].focusTopicIDs.contains(product.topicID) {
                    state.rivals.rivals[index].focusTopicIDs.append(product.topicID)
                }
                events.append(.rivalCopycat(rivalID: rival.id, topicID: product.topicID, day: day))
            }
            return events
        default:
            return []
        }
    }

    /// A product on the market for the price-war seed: the newest one
    /// released, or one conjured into the newest build's topic.
    private static func rivalMarketDebugReleasedProduct(
        _ state: inout GameState,
        _ content: ContentCatalog
    ) -> UUID {
        if let released = state.products.last(where: {
            if case .released(let info) = $0.stage { return !info.offMarket }
            return false
        }) { return released.id }
        var seed = SeededRNG(seed: state.seed ^ 0x5245_4C45_4153_4544)
        let topicID = state.products.last?.topicID ?? content.topics.first?.id ?? "fitness"
        let typeID = state.products.last?.typeID ?? content.productTypes.first?.id ?? "mobile_app"
        let product = Product(
            id: UUID(from: &seed),
            name: "Pulse",
            typeID: typeID,
            topicID: topicID,
            stage: .released(ReleaseInfo(
                launchDay: max(0, state.day - 42),
                quality: 74,
                reviews: [
                    Review(outlet: "Pocket Critic", score: 76, blurb: "Does the job, and then some."),
                    Review(outlet: "The Stack", score: 72, blurb: "Solid."),
                ],
                weeklySales: [],
                offMarket: false
            ))
        )
        state.products.append(product)
        return product.id
    }
    #endif
}
