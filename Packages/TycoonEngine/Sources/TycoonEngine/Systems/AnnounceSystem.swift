import Foundation
import TycoonContent

// MARK: J5 (announce)

/// Iteration 12 — J5. The announced date, kept or missed.
///
/// Daily, after the builds have worked: a build still in development the
/// day after its announced date has slipped. The first slip costs
/// reputation and hype and the press prints a new date (today's ETA plus
/// `announce.redateDays`); the second costs more and voids the
/// announcement. A product that shipped on or before its date gets one
/// line in the paper the day after.
///
/// Draws nothing. The loop skips every product that was never announced,
/// which is every product in every run that never pressed the button.
enum AnnounceSystem {
    @Sendable
    static func run(
        _ state: inout GameState,
        _ balance: BalanceConfig,
        _ content: ContentCatalog
    ) -> [GameEvent] {
        var events: [GameEvent] = []
        var anyStanding = false
        for index in state.products.indices {
            let product = state.products[index]
            guard product.wasAnnounced, let date = product.announcedDay else { continue }
            switch product.stage {
            case .development:
                if state.day > date {
                    events.append(contentsOf: slip(at: index, state: &state, balance: balance, content: content))
                }
                if state.products[index].isAnnounced { anyStanding = true }
            case .released(let info):
                if info.launchDay == state.day - 1, info.launchDay <= date {
                    events.append(.announceKept(
                        productID: product.id, forDay: date, slips: product.slips, day: info.launchDay
                    ))
                }
            }
        }
        // `announce_live` stands while a date does, so the events about a
        // coming date stop once there is none. Only a run that announced
        // ever has a product past the guard above, so only it can get here
        // with anything to change.
        let flagged = state.narrative.flags.contains(Announce.liveFlag)
        if anyStanding != flagged {
            if anyStanding {
                state.narrative.flags.insert(Announce.liveFlag)
            } else {
                state.narrative.flags.remove(Announce.liveFlag)
            }
        }
        return events
    }

    // MARK: - Actions

    /// Names `day` as the ship date of a build in development. Refused for
    /// every reason `GameState.announceRefusal` names; a refusal returns no
    /// events, which is how the toast layer knows to say why.
    static func announce(
        productID: UUID,
        day announced: Int,
        state: inout GameState,
        balance: BalanceConfig,
        content: ContentCatalog
    ) -> [GameEvent] {
        guard state.announceRefusal(
            productID: productID, day: announced, balance: balance, content: content
        ) == nil,
            let index = state.products.firstIndex(where: { $0.id == productID })
        else { return [] }
        state.products[index].announcedDay = announced
        state.narrative.flags.insert(Announce.madeFlag)
        state.narrative.flags.insert(Announce.liveFlag)
        return [.announceMade(productID: productID, forDay: announced, day: state.day)]
    }

    /// `-autoAnnounce slip`: miss the standing date today, through the same
    /// slip a real miss takes. Debug builds only; nothing in the game
    /// sends it.
    static func forceSlip(
        productID: UUID,
        state: inout GameState,
        balance: BalanceConfig,
        content: ContentCatalog
    ) -> [GameEvent] {
        guard let index = state.products.firstIndex(where: { $0.id == productID }),
              state.products[index].isAnnounced,
              case .development = state.products[index].stage
        else { return [] }
        return slip(at: index, state: &state, balance: balance, content: content)
    }

    // MARK: - The slip

    private static func slip(
        at index: Int,
        state: inout GameState,
        balance: BalanceConfig,
        content: ContentCatalog
    ) -> [GameEvent] {
        var product = state.products[index]
        product.slips += 1
        let cost = Announce.slipCost(slipNumber: product.slips, balance: balance)
        state.company.reputation = min(100, max(0, state.company.reputation - cost.reputation))
        if case .development(var dev) = product.stage {
            dev.hype *= cost.hypeFactor
            product.stage = .development(dev)
        }

        let newDay: Int?
        if product.slips >= Announce.voidAfterSlips {
            product.announcedDay = nil
            newDay = nil
            state.narrative.flags.insert(Announce.voidFlag)
        } else {
            // The press prints a new date off the ETA as it stands today.
            // A build nobody is on is dated from today.
            let eta = state.shipETA(for: product, balance: balance, content: content)?.day ?? state.day
            let redated = max(eta, state.day) + max(1, balance.announce.redateDays)
            product.announcedDay = redated
            newDay = redated
        }
        state.narrative.flags.insert(Announce.slippedFlag)
        state.products[index] = product
        // MARK: T4 (publisher) — a published build's slip claws back
        // `publisher.clawbackPerSlip` of the advance. Nothing for a build
        // nobody published, which falls through to the line below.
        if let clawed = PublisherSystem.clawBack(at: index, state: &state, balance: balance) {
            return [
                .announceSlipped(productID: product.id, slips: product.slips, newDay: newDay, day: state.day),
                clawed,
            ]
        }
        // MARK: end T4
        return [.announceSlipped(
            productID: product.id, slips: product.slips, newDay: newDay, day: state.day
        )]
    }
}

// MARK: end J5
