import Foundation
import TycoonEngine

// MARK: K7 (partner and diary)

/// Iteration 15 — K7. The screenshot pass's hands.
///
/// `-autoPartner <stage>` (`partner`, `hired`, `leave`, `ex`, `oldex`,
/// `diary`, `launch`, `letter`) dresses one situation through the reducer
/// (`PartnerDebugSeed` in the engine), a beat after launch. `launch` also
/// opens the launch-day sheet on the build it shipped; `diary` puts the
/// anniversary the day after the date the announce sheet will propose, so
/// pair it with `-autoRoute announce`. Debug builds only.
@MainActor
enum PartnerDebug {
    static func startIfAsked(current: @escaping () -> GameEngine, shell: GameShell) async {
        #if DEBUG
        guard let stage = DebugLaunch.value(after: "-autoPartner")?.lowercased() else { return }
        // A fresh launch takes a beat to put a running game behind the root.
        try? await Task.sleep(for: .milliseconds(900))
        let engine = current()
        if stage == "diary" {
            guard let product = AnnounceRoute.candidate(in: engine),
                  let day = engine.state.announceProposal(
                      productID: product.id, slackDays: AnnounceSheet.defaultSlack,
                      balance: engine.balance, content: engine.content
                  )
            else { return }
            engine.send(.partnerDebugSeed(stage: "diary:\(day)"))
            return
        }
        let events = engine.send(.partnerDebugSeed(stage: stage))
        if stage == "launch" {
            for case .shipped(let productID, _) in events {
                shell.launchDayProductID = productID
            }
        }
        #endif
    }
}

// MARK: end K7
