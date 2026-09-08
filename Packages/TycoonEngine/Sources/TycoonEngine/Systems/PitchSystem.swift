import Foundation
import TycoonContent

/// The pitch room: opening one, saying something in it, and pricing what
/// was said back into the paperwork.
///
/// Nothing in this file runs unless `state.pitch` exists, and `state.pitch`
/// only ever comes into existence because the player pressed *Talk first*.
/// A run that never does that — every pacing bot, every byte-identical
/// fixture, every save written before this iteration — takes exactly the
/// accept and decline paths it always took, because the settle step below
/// is the only thing that ever writes a revised term, and it revises by
/// `PitchRoom.swing`, which is the identity at warmth zero.
///
/// Draws: every exchange takes exactly one word from `state.socialRNG`,
/// including the two topics that cannot fail, so the stream advances by
/// the same amount whatever the player says. Opening a room takes one
/// more (the want) and one (the opener). `worldRNG` and `rng` are never
/// touched — except `state.socialRNG` again when an interview's notch
/// rewrites a blurb, which only happens on a launch the player
/// interviewed for.
enum PitchSystem {

    // MARK: - The tick

    /// Closes a conversation the player walked away from, and spends any
    /// interview notch on the launch it was for.
    @Sendable
    static func run(
        _ state: inout GameState,
        _ balance: BalanceConfig,
        _ content: ContentCatalog
    ) -> [GameEvent] {
        guard state.pitch != nil else { return [] }
        var events: [GameEvent] = []

        // A room left open overnight settles itself on whatever was said.
        // The default outcome of a room nobody spoke in is warmth zero,
        // which is the paper as written.
        if let session = state.pitch?.session, state.day > session.openedDay {
            events.append(contentsOf: settle(state: &state, balance: balance, content: content))
        }

        events.append(contentsOf: spendPressBumps(&state, balance, content))
        tidy(&state)
        return events
    }

    // MARK: - Opening

    /// Sits the founder down. Two draws: the want, then the opener.
    static func open(
        counterpart: PitchCounterpart,
        subjectID: UUID?,
        state: inout GameState,
        balance: BalanceConfig,
        content: ContentCatalog
    ) -> [GameEvent] {
        guard state.pitchBlocker(
            for: counterpart, subjectID: subjectID, balance: balance, content: content
        ) == nil,
            let found = state.pitchSubject(
                for: counterpart, balance: balance, content: content
            )
        else { return [] }
        let resolved = subjectID ?? found

        let def = content.pitchCounterpart(counterpart.rawValue)
        let wants = def?.wants ?? []
        let wantID = wants.isEmpty
            ? ""
            : wants[state.socialRNG.nextInt(in: 0...(wants.count - 1))].id
        let openers = def?.openers ?? []
        let opener = openers.isEmpty
            ? ""
            : openers[state.socialRNG.nextInt(in: 0...(openers.count - 1))]

        let config = balance.pitch
        let extra = config.exchangesPerConversationPoint > 0
            ? Int(state.life.skills.conversation / config.exchangesPerConversationPoint)
            : 0
        let exchanges = max(1, min(config.exchangesMax, config.exchangesBase + extra))

        var pitch = state.pitch ?? .empty
        pitch.session = PitchSession(
            counterpart: counterpart,
            subjectID: resolved,
            openedDay: state.day,
            exchangesLeft: exchanges,
            wantID: wantID,
            lastLine: opener
        )
        state.pitch = pitch
        return [.pitchOpened(counterpart: counterpart.rawValue, day: state.day)]
    }

    // MARK: - Saying something

    /// One exchange. Costs an exchange, a little energy, and exactly one
    /// word from `socialRNG` whatever the topic.
    static func say(
        topic: ConversationTopic,
        state: inout GameState,
        balance: BalanceConfig,
        content: ContentCatalog
    ) -> [GameEvent] {
        guard var session = state.pitch?.session, session.exchangesLeft > 0 else { return [] }
        let config = balance.pitch
        let def = content.pitchCounterpart(session.counterpart.rawValue)
        let want = def?.wants.first { $0.id == session.wantID }

        let roll = state.socialRNG.nextUniform()
        let charm = state.founderCharmFactor(balance)

        var landed = true
        var factor: Double
        switch topic {
        case .smallTalk:
            factor = config.smallTalkFactor
        case .listen:
            factor = config.listenFactor
            session.wantRevealed = true
        case .shopTalk:
            let skill = state.life.skills.value(for: session.counterpart.gradedOn)
            landed = roll < min(
                config.landCeiling,
                config.landBase + skill / max(1, config.landSkillDivisor)
            )
            factor = config.shopTalkFactor
        case .pitch:
            // The deck is a swing: it needs the room to be with you
            // already, and the founder's conversation to sell it.
            let warmthHelp = max(0, session.warmth) / 250
            landed = roll < min(
                config.landCeiling,
                config.landBase * 0.75
                    + state.life.skills.conversation / max(1, config.landSkillDivisor)
                    + warmthHelp
            )
            factor = config.pitchFactor
        }

        // Aiming at what they came for is worth double — but only once
        // the founder has listened. Guessing right blind is still worth
        // what the topic is worth.
        let onTarget = want?.favors == topic.rawValue
        if onTarget, session.wantRevealed { factor *= config.wantFactor }

        let swing = config.warmthPerLandedTurn * factor * charm
        session.warmth = min(PitchRoom.warmthLimit, max(-PitchRoom.warmthLimit,
            session.warmth + (landed ? swing : -swing * config.missFactor)
        ))
        session.lastLanded = landed
        session.lastLine = line(
            topic: topic, landed: landed, onTarget: onTarget && session.wantRevealed,
            want: want, def: def, roll: roll
        )
        session.exchangesLeft -= 1
        session.exchangesTaken += 1

        state.pitch?.session = session
        state.life.meters.apply(
            energy: -config.energyPerTurn,
            mood: landed ? config.moodPerGoodTurn : -config.moodPerGoodTurn
        )
        FounderSystem.practice(.conversation, state: &state, balance: balance)
        switch topic {
        case .shopTalk:
            FounderSystem.practice(
                session.counterpart.gradedOn, multiplier: 0.5, state: &state, balance: balance
            )
        case .pitch:
            FounderSystem.practice(.marketKnowledge, state: &state, balance: balance)
        case .smallTalk, .listen:
            break
        }

        if session.exchangesLeft == 0 {
            return settle(state: &state, balance: balance, content: content)
        }
        return []
    }

    /// What they say back. Deterministic in the roll that graded the
    /// exchange, so no extra draw is needed to pick a line.
    private static func line(
        topic: ConversationTopic,
        landed: Bool,
        onTarget: Bool,
        want: PitchWantDef?,
        def: PitchCounterpartDef?,
        roll: Double
    ) -> String {
        if onTarget, landed, let hit = want?.hit { return hit }
        if topic == .listen, let reveal = want?.reveal { return reveal }
        let set = def?.lines[topic.rawValue]
        let pool = landed ? (set?.land ?? []) : (set?.miss ?? [])
        guard !pool.isEmpty else {
            return landed ? "That landed." : "That landed badly."
        }
        let index = min(pool.count - 1, Int(roll * Double(pool.count)))
        return pool[index]
    }

    // MARK: - Leaving

    /// The founder gets up. Whatever was said is priced in.
    static func leave(
        state: inout GameState,
        balance: BalanceConfig,
        content: ContentCatalog
    ) -> [GameEvent] {
        guard state.pitch?.session != nil else { return [] }
        return settle(state: &state, balance: balance, content: content)
    }

    // MARK: - Settling

    /// Writes the conversation into the paperwork and clears the room.
    ///
    /// This is the only place in the lane that changes anything outside
    /// `state.pitch`, and every change goes through `PitchRoom`, whose
    /// revisions are the identity at warmth zero.
    @discardableResult
    private static func settle(
        state: inout GameState,
        balance: BalanceConfig,
        content: ContentCatalog
    ) -> [GameEvent] {
        guard let session = state.pitch?.session else { return [] }
        let config = balance.pitch
        let band = session.band
        let warmth = session.warmth

        switch session.counterpart {
        case .investor:
            if let offer = state.investors.pendingOffer {
                state.investors.pendingOffer = PitchRoom.revised(
                    offer, warmth: warmth, balance: config
                )
            }
        case .client:
            if let id = session.subjectID,
               let index = state.contractOffers.firstIndex(where: { $0.id == id }) {
                state.contractOffers[index] = PitchRoom.revised(
                    state.contractOffers[index], warmth: warmth, balance: config
                )
            }
        case .journalist:
            if let id = session.subjectID {
                applyInterview(productID: id, warmth: warmth, state: &state, balance: balance)
            }
        case .board:
            state.investors.boardPressure = min(100, max(0,
                state.investors.boardPressure + PitchRoom.pressureDelta(warmth, balance: config)
            ))
            if var review = state.investors.reviews.last, review.day == state.investors.lastReviewDay {
                review.pressure = state.investors.boardPressure
                review.note = PitchRoom.closing(
                    counterpart: .board, band: band, content: content
                )
                state.investors.reviews[state.investors.reviews.count - 1] = review
            }
        }

        let summary = PitchRoom.summary(
            counterpart: session.counterpart, band: band, warmth: warmth, balance: config
        )
        var pitch = state.pitch ?? .empty
        pitch.session = nil
        let spentKey = key(session.counterpart, session.subjectID)
        if !pitch.spent.contains(spentKey) { pitch.spent.append(spentKey) }
        pitch.log.append(PitchRecord(
            counterpart: session.counterpart, day: state.day, band: band, summary: summary
        ))
        if pitch.log.count > PitchState.maxLog {
            pitch.log.removeFirst(pitch.log.count - PitchState.maxLog)
        }
        state.pitch = pitch
        tidy(&state)

        return [.pitchClosed(
            counterpart: session.counterpart.rawValue,
            band: band.rawValue,
            summary: summary,
            day: state.day
        )]
    }

    // MARK: - The press

    /// An interview moves the buzz now and books a notch on the review
    /// for launch day. A product already on the market takes the notch on
    /// the spot, because its reviews are already printed.
    private static func applyInterview(
        productID: UUID,
        warmth: Double,
        state: inout GameState,
        balance: BalanceConfig
    ) {
        let config = balance.pitch
        let notch = PitchRoom.pressNotch(warmth, balance: config)
        guard let index = state.products.firstIndex(where: { $0.id == productID }) else { return }

        switch state.products[index].stage {
        case .development(var dev):
            dev.hype = max(0, dev.hype + PitchRoom.hypeDelta(warmth, balance: config))
            state.products[index].stage = .development(dev)
            if notch != 0 {
                var pitch = state.pitch ?? .empty
                pitch.pressBumps[productID.uuidString] = notch
                state.pitch = pitch
            }
        case .released:
            guard notch != 0 else { return }
            shiftReviews(productIndex: index, notch: notch, state: &state, balance: balance)
        }
    }

    /// Spends a booked notch on the day its product reaches the market.
    private static func spendPressBumps(
        _ state: inout GameState,
        _ balance: BalanceConfig,
        _ content: ContentCatalog
    ) -> [GameEvent] {
        guard let bumps = state.pitch?.pressBumps, !bumps.isEmpty else { return [] }
        for (key, notch) in bumps.sorted(by: { $0.key < $1.key }) {
            guard let id = UUID(uuidString: key),
                  let index = state.products.firstIndex(where: { $0.id == id })
            else {
                state.pitch?.pressBumps[key] = nil
                continue
            }
            guard case .released = state.products[index].stage else { continue }
            shiftReviews(productIndex: index, notch: notch, state: &state, balance: balance)
            state.pitch?.pressBumps[key] = nil
        }
        return []
    }

    /// One outlet — the one the founder gave the interview to, which is
    /// the first on the list — moves a band, and its line is rewritten to
    /// match. One `socialRNG` word, and only ever on a launch the player
    /// interviewed for.
    private static func shiftReviews(
        productIndex: Int,
        notch: Int,
        state: inout GameState,
        balance: BalanceConfig
    ) {
        guard case .released(var info) = state.products[productIndex].stage,
              !info.reviews.isEmpty
        else { return }
        var review = info.reviews[0]
        let shifted = min(balance.reviewCeiling, max(
            balance.reviewFloor, review.score + notch * balance.pitch.pressNotchPoints
        ))
        guard shifted != review.score else { return }
        review.score = shifted
        review.blurb = ReviewBlurbs.pick(for: shifted, rng: &state.socialRNG, outlet: review.outlet)
        info.reviews[0] = review
        state.products[productIndex].stage = .released(info)
    }

    // MARK: - Bookkeeping

    private static func key(_ counterpart: PitchCounterpart, _ subjectID: UUID?) -> String {
        PitchRoom.spentKey(counterpart, subjectID)
    }

    /// Puts the slot back to `nil` once there is nothing left in it, so a
    /// run whose one pitch has fully landed encodes like a run that never
    /// pitched at all.
    private static func tidy(_ state: inout GameState) {
        if state.pitch?.isEmpty == true { state.pitch = nil }
    }
}
