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
            guard case .development(var dev) = state.products[index].stage else { continue }
            dev.hype *= 1 - balance.hypeDecayRate
            state.products[index].stage = .development(dev)
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
                  let index = state.products.firstIndex(where: { $0.id == campaign.productID }),
                  case .development(var dev) = state.products[index].stage
            else { continue }

            state.company.cash -= balance.socialPushDailyCost
            state.ledger.post(LedgerEntry(
                day: state.day,
                amount: -balance.socialPushDailyCost,
                category: .marketing,
                label: CampaignKind.socialPush.ledgerLabel
            ))
            dev.hype += balance.socialPushDailyHype * hypeFactor
            state.products[index].stage = .development(dev)
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
              let productIndex = state.products.firstIndex(where: { $0.id == productID }),
              case .development(var dev) = state.products[productIndex].stage
        else { return [] }

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

        let duplicate = state.campaigns.contains { campaign in
            campaign.kindID == kind.rawValue
                && campaign.productID == productID
                && campaign.endDay >= state.day
        }
        if duplicate { return [] }

        if upfrontCost > 0 {
            state.company.cash -= upfrontCost
            state.ledger.post(LedgerEntry(
                day: state.day, amount: -upfrontCost, category: .marketing, label: kind.ledgerLabel
            ))
        }

        // Who is running marketing decides how far a one-shot carries.
        let hypeFactor = TraitEffects.campaignHypeFactor(state.employees, content: content)
        switch kind {
        case .socialPush:
            break // Hype accrues daily while the push runs.
        case .pressRelease:
            dev.hype += balance.pressReleaseHype * hypeFactor
        case .launchEvent:
            dev.hype += balance.launchEventHype * hypeFactor
        }
        state.products[productIndex].stage = .development(dev)

        let id = UUID(from: &state.rng)
        let endDay = kind == .socialPush
            ? state.day + balance.socialPushDurationDays
            : state.day
        state.campaigns.append(MarketingCampaign(
            id: id, kindID: kind.rawValue, productID: productID, endDay: endDay
        ))
        return [.campaignStarted(campaignID: id, day: state.day)]
    }
}
