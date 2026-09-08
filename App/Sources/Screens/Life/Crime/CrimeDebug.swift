import SwiftUI
import TycoonEngine

/// Iteration 11 — N1's debug-launch flags, in the lane's own file so
/// `DebugLaunch` needs one region rather than five.
///
/// Everything here is DEBUG-only and every step is a real `GameAction`
/// through the ordinary reducer: the screenshot pass commits an offence
/// and turns itself in exactly as a player would, then waits for the
/// hearing day the way a player waits for it. There is no back door into
/// `state.crime`.
enum CrimeDebug {

    /// `-autoCase <offence>`: commit one of the six, confess so the case
    /// is raised today rather than in some week the sweep chooses, and
    /// let the clock run to the hearing.
    ///
    /// Names are the `CrimeOffence` raw values — `cookBooks`, `dodgeTaxes`,
    /// `ndaPoach`, `bribeJournalist`, `fakeDemo`, `plantStory` — and
    /// `-autoCase` with no name takes the first one that is not refused.
    static var offenceArgument: String? {
        #if DEBUG
        guard ProcessInfo.processInfo.arguments.contains("-autoCase") else { return nil }
        return DebugLaunch.value(after: "-autoCase") ?? ""
        #else
        return nil
        #endif
    }

    static var raisesCase: Bool { offenceArgument != nil }

    /// `-autoCourtSay deny,explain`: the exchanges the screenshot pass
    /// plays once the room is open.
    static var courtScript: [String] {
        #if DEBUG
        guard let raw = DebugLaunch.value(after: "-autoCourtSay") else { return [] }
        return raw.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
        #else
        return []
        #endif
    }

    /// `-autoLawyer silk` / `-autoDefence itNeverHappened`: what the pass
    /// walks into the room with.
    static var lawyer: CrimeLawyer? {
        #if DEBUG
        return DebugLaunch.value(after: "-autoLawyer").flatMap(CrimeLawyer.init(rawValue:))
        #else
        return nil
        #endif
    }

    static var defence: CrimeDefence? {
        #if DEBUG
        return DebugLaunch.value(after: "-autoDefence").flatMap(CrimeDefence.init(rawValue:))
        #else
        return nil
        #endif
    }

    /// Runs the pass. Idempotent: the task is kept so a redraw of the card
    /// that started it does not start a second one.
    @MainActor
    static func startIfAsked(engine: GameEngine) {
        #if DEBUG
        guard raisesCase, task == nil else { return }
        // The pass has to wait weeks for a hearing, and a run left alone
        // for weeks stops at the first staff moment. `-autoAnswer` is
        // normally started from HQ's root task, which a pass that lands on
        // Life never reaches; starting it here is the same call, and it
        // no-ops without the flag.
        DebugLaunch.startAutoAnswering(engine: engine)
        task = Task { @MainActor in
            // 1. Do the thing — waiting, if need be, for a run in which
            //    it is possible. A garage on day one has nothing to
            //    overstate and nobody to write about; the gates say so,
            //    and the pass waits for them the way a founder would.
            let named = offenceArgument.flatMap { name in
                name.isEmpty ? nil : CrimeOffence(rawValue: name)
            }
            for _ in 0..<600 {
                if !engine.state.crime.record.isEmpty { break }
                let offence: CrimeOffence? = if let named,
                    engine.state.crimeRefusal(for: named, balance: engine.balance) == nil {
                    named
                } else if named == nil {
                    CrimeOffence.allCases.first {
                        engine.state.crimeRefusal(for: $0, balance: engine.balance) == nil
                    }
                } else {
                    nil
                }
                if let offence {
                    engine.send(.commitOffence(offence: offence))
                    break
                }
                answerAnythingInTheWay(engine: engine)
                try? await Task.sleep(for: .milliseconds(200))
            }
            guard !engine.state.crime.record.isEmpty else { return }
            // 2. Turn yourself in, so the case is on the books today and
            //    the pass is not waiting on a weekly roll.
            if engine.state.crime.pendingCase == nil {
                engine.send(.confessOffence())
            }
            if let lawyer { engine.send(.hireLawyer(tier: lawyer)) }
            if let defence { engine.send(.chooseDefence(defence)) }

            // 3. Wait for the hearing the way a founder waits for it. At
            //    x4 a four-to-eight week wait is seven to fifteen seconds;
            //    the cap is there so a paused pass gives up rather than
            //    spinning.
            for _ in 0..<900 {
                guard let pending = engine.state.crime.pendingCase else { return }
                if engine.state.day >= pending.hearingDay { break }
                answerAnythingInTheWay(engine: engine)
                try? await Task.sleep(for: .milliseconds(120))
            }
        }
        #endif
    }

    /// Clears whatever sheet is sitting between the pass and the hearing
    /// with its *last* open option, which every decision in this game
    /// writes as the passive one — the answer the deadline would give.
    ///
    /// `-autoAnswer` takes the *first* option instead, which on a long
    /// wait spends money the run does not have and occasionally settles
    /// on a beat it cannot clear. This is the same mechanism (a real
    /// `GameAction` through the reducer), pointed the other way, and it
    /// runs only while a `-autoCase` pass is waiting.
    @MainActor
    private static func answerAnythingInTheWay(engine: GameEngine) {
        #if DEBUG
        guard let prompt = DecisionPrompt.pending(
            in: engine.state, content: engine.content, balance: engine.balance
        ), let option = prompt.options.last(where: { option in
            guard option.disabledReason == nil else { return false }
            switch option.action {
            case .acceptBuyout, .acceptBuyoutEarnOut: return false
            default: return true
            }
        }) else {
            if engine.state.speed == .paused { engine.setSpeed(.x4) }
            return
        }
        engine.send(option.action)
        #endif
    }

    /// Opens the room the moment the case is actually listed, for
    /// `-autoRoute courtroom`. A headless pass lands on the ledger weeks
    /// before the hearing; this is the wait a player does, without the
    /// thumb.
    @MainActor
    static func openWhenListed(engine: GameEngine, open: @escaping () -> Void) async {
        #if DEBUG
        guard Route.launchRoute == .courtroom || raisesCase else { return }
        for _ in 0..<600 {
            if let pending = engine.state.crime.pendingCase,
               engine.state.day >= pending.hearingDay {
                open()
                return
            }
            try? await Task.sleep(for: .milliseconds(120))
        }
        #endif
    }

    #if DEBUG
    @MainActor private static var task: Task<Void, Never>?
    #endif
}
