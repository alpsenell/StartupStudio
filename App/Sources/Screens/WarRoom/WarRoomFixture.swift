import Foundation
import TycoonEngine

#if DEBUG
/// A game advanced to a moment the war room is for, without tapping
/// anything: a build a few days from its ETA, or one that shipped today.
///
/// Used by the `-autoRoute` headless pass (the simulator cannot be tapped,
/// and a live game stops at its first pausing event long before a build
/// is inside its last week) and by the snapshot tests, so the screenshot
/// and the PNGs show the same room. The game is the engine's own — a
/// fixed seed, the reducer ticked day by day — so the fixture is as
/// deterministic as the engine.
enum WarRoomFixture {
    enum Moment {
        /// Inside the launch window, `daysOut` days or fewer from the ETA.
        case countdown(daysOut: Int)
        /// Every pool full and shipped today: launch day, reviews in.
        case launchDay
        /// Every pool full, not yet shipped: the day the room's own ship
        /// button is for.
        case readyToShip
    }

    /// The most ticks the fixture will spend getting to a moment. A
    /// founder-only tool takes a few dozen days; this is a guard, not a
    /// target.
    private static let tickCap = 600

    @MainActor
    static func engine(_ moment: Moment, seed: UInt64 = 4242) -> GameEngine {
        let fresh = GameEngine.newGame(
            companyName: "Northgate Softworks",
            seed: seed,
            difficulty: .normal,
            founder: FounderProfile(name: "Mira Okafor", archetype: .hacker, appearanceSeed: 0x5EED)
        )
        let balance = fresh.balance
        let content = fresh.content
        var state = fresh.state

        guard let type = content.productTypes.first(where: { state.isProductTypeUnlocked($0.id, content: content) })
        else { return fresh }
        // The topic the catalog likes best for the type, so the forecast
        // band shows a launch worth watching.
        let topic = content.topics.max { ($0.fitByType[type.id] ?? 1) < ($1.fitByType[type.id] ?? 1) }
            ?? content.topics[0]
        Reducer.apply(
            .startProduct(typeID: type.id, topicID: topic.id, name: "Overcast", focus: .matching(type: type)),
            to: &state, balance: balance, content: content
        )
        guard let productID = state.productInDevelopment?.id else { return fresh }

        func eta() -> BuildETA? {
            state.buildETA(productID: productID, balance: balance, content: content)
        }

        /// One day, with the focus re-aimed at what the build still needs
        /// first — "Match the work", the way the pacing bots play — so the
        /// pools fill together and the whiteboard reads like a launch week
        /// rather than one bar lagging two that overshot.
        func day() {
            if case .development(let dev)? = state.product(id: productID)?.stage {
                Reducer.apply(
                    .setPhaseFocus(productID: productID, focus: .matching(progress: dev, type: type)),
                    to: &state, balance: balance, content: content
                )
            }
            Reducer.tick(&state, balance: balance, content: content)
        }

        var ticks = 0
        var pushed = false
        switch moment {
        case .countdown(let daysOut):
            while ticks < tickCap {
                guard let days = eta()?.daysToComplete else {
                    day()
                    ticks += 1
                    continue
                }
                if days <= daysOut { break }
                // A push a few days before the window, so the meter has
                // something on it and something feeding it.
                if !pushed, days <= daysOut + 3 {
                    Reducer.apply(.startCampaign(kindID: "social_push", productID: productID), to: &state, balance: balance, content: content)
                    pushed = true
                }
                day()
                ticks += 1
            }
        case .launchDay, .readyToShip:
            while ticks < tickCap {
                guard let now = eta() else {
                    day()
                    ticks += 1
                    continue
                }
                if now.isComplete { break }
                // Launch week: a push, so the launch carries some hype.
                if !pushed, let days = now.daysToComplete, days <= WarRoomOffer.windowDays {
                    Reducer.apply(.startCampaign(kindID: "social_push", productID: productID), to: &state, balance: balance, content: content)
                    pushed = true
                }
                day()
                ticks += 1
            }
            if case .launchDay = moment {
                Reducer.apply(.ship(productID: productID), to: &state, balance: balance, content: content)
            }
        }
        return GameEngine.resume(state: state)
    }
}

extension WarRoomRequest {
    /// Consumed once per launch, so a headless pass lands in the room and
    /// a later route change does not re-open it.
    @MainActor private static var consumedDebugLaunch = false

    /// The room a `-autoRoute warRoom` / `launchDay` / `shipInRoom` launch
    /// asked for, on a fixture engine advanced to that moment. `nil` on
    /// every other launch, and after the first call. `shipInRoom` opens a
    /// finished build and the room ships it itself a moment later, so the
    /// reveal that follows a *real* ship action — the shell's launch-day
    /// request included — can be watched headlessly.
    @MainActor
    static func debugLaunch() -> WarRoomRequest? {
        guard !consumedDebugLaunch, let route = DebugLaunch.launchRoute else { return nil }
        let moment: WarRoomFixture.Moment
        switch route {
        case "warroom": moment = .countdown(daysOut: 5)
        case "launchday": moment = .launchDay
        case "shipinroom": moment = .readyToShip
        default: return nil
        }
        consumedDebugLaunch = true
        let engine = WarRoomFixture.engine(moment)
        guard let product = engine.state.products.first else { return nil }
        return WarRoomRequest(engine: engine, productID: product.id)
    }
}
#endif
