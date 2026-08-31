import TycoonContent

/// The studio's standing in a category — "Hold the Category".
///
/// Standing is not a new thing to do; it is a ledger over the things the
/// studio already does. Shipping into a topic pays into it, what the press
/// made of that launch adjusts the payment, a patch pays a little and so
/// does a campaign. Every week the studio has something on the market in a
/// topic pays a small retainer, and every week it has nothing there costs
/// more than the retainer earns — so a category is rent, not a trophy, and
/// a back catalogue that goes quiet takes the standing with it.
///
/// Everything here is deterministic and draws no RNG words. In phase one
/// standing buys exactly one thing — sight of a topic's forward book at
/// `standing.forecastThreshold`, via `MarketState.forecast(for:above:)` —
/// so nothing in this file reaches the economy or the pacing bots.
enum StandingSystem {
    /// The weekly retainer and the weekly decay, run by `MarketSystem` on
    /// its shift beat. Topics are visited in catalog order rather than
    /// dictionary order: `Dictionary` iteration is not stable across
    /// processes and this is a simulation that has to replay.
    static func applyWeeklyDrift(
        _ state: inout GameState,
        _ balance: BalanceConfig,
        _ content: ContentCatalog
    ) {
        let config = balance.market.standing
        let live = liveTopicIDs(state)
        for topic in content.topics {
            let held = live.contains(topic.id)
            // A category nobody has ever entered stays at zero rather than
            // accumulating an entry that means nothing.
            if !held, state.market.standing[topic.id] == nil { continue }
            award(
                held ? config.presenceWeeklyGain : -config.decayWeeklyLoss,
                in: topic.id, &state, config
            )
        }
    }

    /// A launch: the flat ship fee plus what the reviews were worth.
    /// Called by `ProductSystem.ship` once the verdict is in.
    static func recordLaunch(
        topicID: String,
        averageReviewScore: Int,
        _ state: inout GameState,
        _ balance: BalanceConfig
    ) {
        let config = balance.market.standing
        award(config.launchGain(averageReviewScore: averageReviewScore), in: topicID, &state, config)
    }

    /// A patch landing on a product in the topic. Called by
    /// `LiveOpsSystem.completeUpdates`.
    static func recordPatch(
        topicID: String,
        _ state: inout GameState,
        _ balance: BalanceConfig
    ) {
        let config = balance.market.standing
        award(config.patchGain, in: topicID, &state, config)
    }

    /// A campaign starting on a product in the topic. Called by
    /// `MarketingSystem.startCampaign`.
    static func recordCampaign(
        topicID: String,
        _ state: inout GameState,
        _ balance: BalanceConfig
    ) {
        let config = balance.market.standing
        award(config.campaignGain, in: topicID, &state, config)
    }

    /// Topics the studio currently has something selling in.
    static func liveTopicIDs(_ state: GameState) -> Set<String> {
        var ids: Set<String> = []
        for product in state.products {
            guard case .released(let info) = product.stage, !info.offMarket else { continue }
            ids.insert(product.topicID)
        }
        return ids
    }

    /// Adds `amount` to a topic's standing, clamped to `0...maxStanding`.
    private static func award(
        _ amount: Double,
        in topicID: String,
        _ state: inout GameState,
        _ config: BalanceConfig.StandingBalance
    ) {
        let current = state.market.standing[topicID] ?? 0
        state.market.standing[topicID] = min(config.maxStanding, max(0, current + amount))
    }
}
