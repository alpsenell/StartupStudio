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
        runSocialPushes(&state, balance, content)
        return []
    }

    /// Hype erodes multiplicatively every day, before the day's campaign
    /// additions land.
    private static func decayHype(_ state: inout GameState, _ balance: BalanceConfig) {
        for index in state.products.indices {
            switch state.products[index].stage {
            case .development(var dev):
                dev.hype *= 1 - balance.hypeDecayRate
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
                dev.hype += balance.socialPushDailyHype * hypeFactor
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
        let oneShotHype: Double = switch kind {
        case .socialPush: 0 // Hype accrues daily while the push runs.
        case .pressRelease: balance.pressReleaseHype * hypeFactor
        case .launchEvent: balance.launchEventHype * hypeFactor
        }
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
        return [.campaignStarted(campaignID: id, day: state.day)]
    }
}
