import Foundation
import TycoonContent

/// Daily marketing system, running after `ResearchSystem`: decays every
/// in-development product's hype, then bills active social pushes and adds
/// their daily hype. Expired or orphaned social pushes are removed; one-shot
/// campaign records stay in `campaigns` as history. Also hosts the
/// startCampaign action handler used by `Reducer.apply`.
///
/// Every hype figure a campaign adds is multiplied by the marketing team's
/// `hypeMult` traits — a showman's press release lands harder than a
/// loner's. With no marketers on payroll the factor is exactly 1.
enum MarketingSystem {
    @Sendable
    static func run(
        _ state: inout GameState,
        _ balance: BalanceConfig,
        _ content: ContentCatalog
    ) -> [GameEvent] {
        decayHype(&state, balance)
        // MARK: Iteration 11 — N4 (fame and the feed)
        //
        // Fame is a campaign nobody bills you for. It lands after the
        // decay and before the pushes, so a famous founder's build holds
        // a floor of hype rather than sliding to nothing between
        // campaigns. `Fame.dailyHype` is exactly zero at fame zero, and
        // the guard means a run that never posted does not even walk the
        // product array a second time.
        addFameHype(&state, balance)
        // MARK: end of Iteration 11 — N4
        runSocialPushes(&state, balance, content)
        return []
    }

    /// Hype erodes multiplicatively every day, before the day's campaign
    /// additions land.
    private static func decayHype(_ state: inout GameState, _ balance: BalanceConfig) {
        for index in state.products.indices {
            switch state.products[index].stage {
            case .development(var dev):
                // MARK: J5 (announce) — a date told to the press holds the
                // hype: 1% a day instead of 2%. The ordinary rate, returned
                // untouched, for every build nobody announced.
                dev.hype *= 1 - Announce.hypeDecayRate(for: state.products[index], balance)
                // MARK: end J5
                state.products[index].stage = .development(dev)
            case .released(var info) where info.liveHype > 0:
                // A post-launch push fades the same way, which is what
                // makes it a temporary bet against the launch's permanent
                // one.
                info.liveHype *= 1 - balance.hypeDecayRate
                state.products[index].stage = .released(info)
            default:
                continue
            }
        }
    }

    // MARK: Iteration 11 — N4 (fame and the feed)

    /// The hype a founder's own audience is worth, every day, on every
    /// build in development. A launch already on the market does not get
    /// it: `liveHype` is what a campaign buys, and fame is not a campaign.
    private static func addFameHype(_ state: inout GameState, _ balance: BalanceConfig) {
        let daily = Fame.dailyHype(state.fame.fame, balance: balance.fame)
        guard daily > 0 else { return }
        for index in state.products.indices {
            guard case .development(var dev) = state.products[index].stage else { continue }
            dev.hype += daily
            state.products[index].stage = .development(dev)
        }
    }

    // MARK: end of Iteration 11 — N4

    /// Bills each social push still attached to an in-development product
    /// and adds its daily hype, scaled by the marketing team's personalities
    /// (`TraitEffects.campaignHypeFactor`, exactly 1 with no marketers on
    /// payroll). A push past its `endDay`, or orphaned by its product
    /// shipping, is removed without billing. One-shot records pass through
    /// untouched.
    private static func runSocialPushes(
        _ state: inout GameState,
        _ balance: BalanceConfig,
        _ content: ContentCatalog
    ) {
        guard !state.campaigns.isEmpty else { return }

        let hypeFactor = TraitEffects.campaignHypeFactor(state.employees, content: content)

        var kept: [MarketingCampaign] = []
        kept.reserveCapacity(state.campaigns.count)
        for campaign in state.campaigns {
            guard campaign.kindID == CampaignKind.socialPush.rawValue else {
                kept.append(campaign)
                continue
            }
            guard state.day <= campaign.endDay,
                  let index = state.products.firstIndex(where: { $0.id == campaign.productID })
            else { continue }
            // A push bought before launch dies at the launch — its job
            // was the launch, and billing it on past that is charging the
            // player for something they did not buy. A push bought *on* a
            // release keeps running until its own end day.
            let target: ProductStage
            switch state.products[index].stage {
            case .development(var dev):
                // MARK: J5 (announce) — a push on an announced build lands
                // ×1.25; unannounced builds add exactly what they did.
                let announced = Announce.campaignFactor(for: state.products[index], balance)
                dev.hype += announced == 1
                    ? balance.socialPushDailyHype * hypeFactor
                    : balance.socialPushDailyHype * hypeFactor * announced
                // MARK: end J5
                target = .development(dev)
            case .released(var info) where campaign.startedOnRelease && !info.offMarket:
                info.liveHype += balance.socialPushDailyHype * hypeFactor
                target = .released(info)
            default:
                continue
            }

            state.company.cash -= balance.socialPushDailyCost
            state.ledger.post(LedgerEntry(
                day: state.day,
                amount: -balance.socialPushDailyCost,
                category: .marketing,
                label: CampaignKind.socialPush.ledgerLabel
            ))
            state.products[index].stage = target
            kept.append(campaign)
        }
        state.campaigns = kept
    }

    // MARK: - Actions

    /// Starts a campaign on an in-development product. Ignored for unknown
    /// kinds or products, research-locked kinds (social pushes are always
    /// available), an office tier below the kind's minimum, an unaffordable
    /// upfront cost, or an identical-kind campaign still active on that
    /// product. One-shots charge and apply their hype immediately and end
    /// the same day; social pushes bill daily from the next tick.
    static func startCampaign(
        kindID: String,
        productID: UUID,
        state: inout GameState,
        balance: BalanceConfig,
        content: ContentCatalog
    ) -> [GameEvent] {
        guard let kind = CampaignKind(rawValue: kindID),
              let productIndex = state.products.firstIndex(where: { $0.id == productID })
        else { return [] }
        // A released product is a valid target. It was not, while the
        // Marketing tab listed released products and told the player "a
        // push now keeps it in front of people" — so every post-launch
        // campaign was silently refused. A delisted one is still no target.
        if case .released(let info) = state.products[productIndex].stage, info.offMarket {
            return []
        }

        switch kind {
        case .socialPush:
            break // Never research-gated.
        case .pressRelease, .launchEvent:
            guard state.isCampaignKindUnlocked(kind.rawValue, content: content) else { return [] }
        }

        if kind == .launchEvent,
           let minTier = OfficeTier(rawValue: balance.launchEventMinTier),
           state.company.officeTier.rank < minTier.rank {
            return []
        }

        let upfrontCost = switch kind {
        case .socialPush: 0
        case .pressRelease: balance.pressReleaseCost
        case .launchEvent: balance.launchEventCost
        }
        if upfrontCost > 0, state.company.cash < upfrontCost { return [] }

        // Previous runs of this kind on this product, kept in `campaigns`
        // as history. They gate the repeat and price it.
        let previous = state.campaigns.filter {
            $0.kindID == kind.rawValue && $0.productID == productID
        }
        let cooldown = balance.economy.campaignCooldownDays
        // The old guard only refused a campaign still *running*, and a
        // one-shot ends the day it starts — so a press release could be
        // repeated every day, converging on 750 hype and +37 review
        // points for $500 a time.
        let blocked = previous.contains { state.day - $0.endDay < max(0, cooldown) || $0.endDay >= state.day }
        if blocked { return [] }

        if upfrontCost > 0 {
            state.company.cash -= upfrontCost
            state.ledger.post(LedgerEntry(
                day: state.day, amount: -upfrontCost, category: .marketing, label: kind.ledgerLabel
            ))
        }

        // Who is running marketing decides how far a one-shot carries —
        // and how often you have already told this story.
        let hypeFactor = TraitEffects.campaignHypeFactor(state.employees, content: content)
            * pow(balance.economy.campaignRepeatHypeDecay, Double(previous.count))
        let kindHype: Double = switch kind {
        case .socialPush: 0 // Hype accrues daily while the push runs.
        case .pressRelease: balance.pressReleaseHype * hypeFactor
        case .launchEvent: balance.launchEventHype * hypeFactor
        }
        // WS-G: the Press Contacts perk (chapter 2's "score 60") was
        // awarded and read by nothing. Journalists who take your calls
        // land every campaign harder — a flat bonus, whatever the kind.
        let perkHype = state.progression.hasPerk(.pressContacts)
            ? balance.progression.pressContactsHypeBonus
            : 0
        var oneShotHype = kindHype + perkHype
        // MARK: J5 (announce) — a campaign on an announced build lands
        // ×1.25. Unannounced builds, and every release, add what they did.
        let announcedFactor = Announce.campaignFactor(for: state.products[productIndex], balance)
        if announcedFactor != 1 { oneShotHype *= announcedFactor }
        // MARK: end J5
        if oneShotHype > 0 {
            switch state.products[productIndex].stage {
            case .development(var dev):
                dev.hype += oneShotHype
                state.products[productIndex].stage = .development(dev)
            case .released(var info):
                // After launch the press has already filed: this buys
                // attention, which is sales, not a better review.
                info.liveHype += oneShotHype
                state.products[productIndex].stage = .released(info)
            }
        }

        let id = UUID(from: &state.rng)
        let endDay = kind == .socialPush
            ? state.day + balance.socialPushDurationDays
            : state.day
        let onRelease: Bool = if case .released = state.products[productIndex].stage {
            true
        } else {
            false
        }
        state.campaigns.append(MarketingCampaign(
            id: id, kindID: kind.rawValue, productID: productID,
            endDay: endDay, startedOnRelease: onRelease
        ))
        // Money spent talking about a product is money spent on the
        // studio's name in that category.
        StandingSystem.recordCampaign(
            topicID: state.products[productIndex].topicID, &state, balance
        )
        return [.campaignStarted(campaignID: id, day: state.day)]
    }
}

// MARK: T5 (expo and pre-orders)

/// Iteration 17 — T5 (G2). The expo's hype. A stand is booked from the app
/// (`.showAtExpo`, paid then, re-pointable for free until the day) and the
/// demo happens on the day, with whatever the build is by then: open bugs
/// over `expo.crashBugs` crash it, a quality so far of `expo.goodQuality`
/// earns the press's nod. The hype is `expo.hype` × the marketing team's
/// traits (`TraitEffects.campaignHypeFactor`, exactly 1 with no
/// marketers), × `marketerFactor` when a marketer pitches instead of the
/// founder, × `hallwayFactor` for the hallway or an unstaffed stand.
extension MarketingSystem {
    static func showAtExpo(
        productID: UUID,
        booth: ExpoBooth,
        attendee: ExpoAttendee,
        state: inout GameState,
        balance: BalanceConfig,
        content: ContentCatalog
    ) -> [GameEvent] {
        guard state.expoRefusal(productID: productID, booth: booth, attendee: attendee, balance: balance) == nil,
              let price = state.expoPrice(booth, balance: balance)
        else { return [] }
        let existing = state.expoBooking
        let charged = existing == nil ? price : 0
        if charged > 0 {
            state.company.cash -= charged
            state.ledger.post(LedgerEntry(
                day: state.day, amount: -charged, category: .marketing,
                label: booth == .booth ? "Expo: a booth" : "Expo: a hallway pass"
            ))
        }
        var expo = state.expo ?? ExpoState()
        expo.booking = ExpoBooking(
            year: state.year, productID: productID, booth: booth, attendee: attendee,
            paid: existing?.paid ?? price
        )
        state.expo = expo
        var events: [GameEvent] = [.expoBooked(
            productID: productID, booth: booth, attendee: attendee, price: charged, day: state.day
        )]
        // Booked on the day itself: the show is on now.
        if state.day >= state.expoDay(balance: balance) {
            events += show(&state, balance, content)
        }
        return events
    }

    /// Lets this year's expo go. Refused outside the notice window and
    /// once the year is done; a booth already paid for is not refunded.
    static func skipExpo(state: inout GameState, balance: BalanceConfig) -> [GameEvent] {
        guard state.expoDaysLeft(balance: balance) != nil else { return [] }
        state.expo = ExpoState(lastYear: state.year, booking: nil)
        return [.expoSkipped(day: state.day)]
    }

    /// The daily pass: a booking whose day has come is shown. Returns on
    /// its first line with nothing booked.
    @Sendable
    static func runExpo(
        _ state: inout GameState,
        _ balance: BalanceConfig,
        _ content: ContentCatalog
    ) -> [GameEvent] {
        guard let booking = state.expo?.booking,
              state.day >= Expo.day(year: booking.year, balance: balance)
        else { return [] }
        return show(&state, balance, content)
    }

    private static func show(
        _ state: inout GameState,
        _ balance: BalanceConfig,
        _ content: ContentCatalog
    ) -> [GameEvent] {
        guard let booking = state.expo?.booking else { return [] }
        state.expo = ExpoState(lastYear: booking.year, booking: nil)
        guard let index = state.products.firstIndex(where: { $0.id == booking.productID }),
              case .development(var dev) = state.products[index].stage,
              let quote = state.expoQuote(
                  productID: booking.productID, booth: booking.booth, attendee: booking.attendee,
                  balance: balance, content: content
              )
        else { return [.expoEmptyBooth(productID: booking.productID, day: state.day)] }
        dev.hype += quote.hype
        state.products[index].stage = .development(dev)
        state.products[index].expoDay = state.day
        state.company.reputation = min(100, max(0, state.company.reputation + quote.reputation))
        if booking.attendee == .founder, quote.staffed {
            state.spendEvening(balance)
            state.life.meters.energy = max(0, state.life.meters.energy - balance.expo.founderEnergy)
        }
        return [.expoShown(
            productID: booking.productID, booth: booking.booth, attendee: booking.attendee,
            hype: quote.hype, reputation: quote.reputation, crashed: quote.crashed,
            staffed: quote.staffed, day: state.day
        )]
    }
}

// MARK: end T5
