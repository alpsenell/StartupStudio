import SwiftUI
import TycoonEngine

// MARK: J5 (announce)

/// Iteration 12 — J5. The headless screenshot pass's hands: announce a
/// date, miss it, price something premium, all through the ordinary
/// reducer, so a picture is of the real thing. The flags are read in
/// `DebugLaunch` under its J5 marker; everything here is debug-only.
@MainActor
enum AnnounceDebug {
    /// `-autoPremium` is on.
    static var wantsPremium: Bool { DebugLaunch.autoPremium }

    /// Consumed once per launch, so a redraw does not start a second one.
    private static var started = false

    /// `-autoAnnounce [slip|void]`: announce the war room's build — or the
    /// soonest build that can take a date — at the sheet's usual slack,
    /// then miss it once (`slip`) or twice (`void`). `-autoPremium`: price
    /// the best-reviewed release premium.
    static func start(engine: GameEngine) {
        #if DEBUG
        let mode = DebugLaunch.autoAnnounceMode
        let premium = DebugLaunch.autoPremium
        guard !started, mode != nil || premium else { return }
        started = true
        if premium, let product = premiumCandidate(in: engine) {
            _ = engine.send(.setPriceTier(productID: product.id, tier: .premium))
        }
        guard let mode else { return }
        Task { @MainActor in
            // A fresh game may not have anybody on a build yet; the
            // fixtures do. Try for twenty seconds, then give up quietly.
            for _ in 0..<40 {
                if let product = announceTarget(in: engine),
                   let day = engine.state.announceProposal(
                       productID: product.id, slackDays: AnnounceSheet.defaultSlack,
                       balance: engine.balance, content: engine.content
                   ) {
                    _ = engine.send(.announceShipDate(productID: product.id, day: day))
                    if mode != .announce {
                        _ = engine.send(.announceForceSlip(productID: product.id))
                    }
                    if mode == .void {
                        _ = engine.send(.announceForceSlip(productID: product.id))
                    }
                    return
                }
                try? await Task.sleep(for: .milliseconds(500))
            }
        }
        #endif
    }

    /// The war room's build when it can take a date, else the route's.
    private static func announceTarget(in engine: GameEngine) -> Product? {
        if let room = WarRoomOffer.candidate(in: engine), case .development = room.stage,
           let day = engine.state.announceProposal(
               productID: room.id, slackDays: AnnounceSheet.defaultSlack,
               balance: engine.balance, content: engine.content
           ),
           engine.state.announceRefusal(
               productID: room.id, day: day, balance: engine.balance, content: engine.content
           ) == nil {
            return room
        }
        return AnnounceRoute.candidate(in: engine)
    }

    /// The on-market release with the best reviews.
    static func premiumCandidate(in engine: GameEngine) -> Product? {
        engine.state.products
            .compactMap { product -> (Product, Int)? in
                guard case .released(let info) = product.stage, !info.offMarket else { return nil }
                return (product, info.averageReviewScore)
            }
            .max { $0.1 < $1.1 }?.0
    }
}

// MARK: end J5
