import Foundation
import TycoonContent

// Iteration 12 — J2 (the record crosses over). This whole file is J2's.
//
// Screenshot dressing for `GameAction.standingDebug`, debug builds only:
// the founder's record set up in one action so a headless pass needs no
// play-through. Nothing in the game sends it, and a release build does
// not contain it.

#if DEBUG
enum StandingDebug {
    static func apply(
        _ scenario: String,
        state: inout GameState,
        balance: BalanceConfig,
        content: ContentCatalog
    ) -> [GameEvent] {
        let words = scenario.lowercased().split(separator: " ").map(String.init)
        guard let head = words.first else { return [] }
        let argument = words.count > 1 ? words[1] : ""
        switch head {
        case "name":
            seedName(Double(argument) ?? 40, state: &state, balance: balance)
            return []
        case "boardcase":
            seatBoard(&state, balance: balance, content: content)
            var events = openCase(&state, balance: balance)
            // Three rounds of a beef with the first studio on the board:
            // with the case, THE FOUNDER'S QUARTER: +20.
            state.fame.beef = FameBeef(
                rivalName: state.rivals.rivals.first?.name ?? "a certain studio",
                openedDay: max(0, state.day - 10),
                rounds: 3,
                theirLine: "Some of us ship.",
                yourLine: "Some of us get sued for it.",
                waitingOnYou: true
            )
            events += InvestorSystem.standingDebugReview(&state, balance)
            return events
        case "offercase":
            var events = openCase(&state, balance: balance)
            state.investors.pendingOffer = nil
            events += InvestorSystem.standingDebugOffer(&state, balance, content)
            return events
        case "spotlight":
            seedSpotlight(argument, state: &state, balance: balance)
            return []
        default:
            return []
        }
    }

    /// Notoriety first (it carries half the name), then mean acts on
    /// staff up to their cap, then firings with cause — enough to read
    /// about `target` after whatever fame and alumni take off.
    private static func seedName(_ target: Double, state: inout GameState, balance: BalanceConfig) {
        let config = balance.founderStanding
        let fameLevel = Fame.level(state.fame.fame, balance: balance.fame).rawValue
        let credit = Double(fameLevel) * config.nameFameLevel
            + Double(FounderStanding.vouchingAlumni(state, balance: balance)) * config.nameAlumnusVouch
        var needed = min(100, max(0, target)) + credit
        let fromNotoriety = min(needed, 100 * config.nameNotorietyWeight)
        state.crime.notoriety = config.nameNotorietyWeight > 0
            ? fromNotoriety / config.nameNotorietyWeight : 0
        needed -= fromNotoriety
        guard needed > 0, config.nameMeanAct > 0 else { return }
        let maxActs = Int((config.nameMeanActCap / config.nameMeanAct).rounded(.down))
        let acts = min(maxActs, Int((needed / config.nameMeanAct).rounded(.up)))
        for offset in stride(from: acts - 1, through: 0, by: -1) {
            state.interactions.standingMeanDays.append(state.day - offset * 3)
        }
        needed -= Double(acts) * config.nameMeanAct
        guard needed > 0, config.nameFiredWithCause > 0 else { return }
        let firings = Int((needed / config.nameFiredWithCause).rounded(.up))
        for index in 0..<firings {
            let id = UUID(uuidString: String(format: "00000000-0000-4000-8000-%012d", index + 1))
            if let id { state.interactions.firedWithCauseIDs.append(id) }
        }
    }

    /// A seat at the table, from a real persona when the catalog has one.
    private static func seatBoard(
        _ state: inout GameState, balance: BalanceConfig, content: ContentCatalog
    ) {
        guard !state.investors.hasBoard else { return }
        let persona = content.investors.first { $0.boardSeat }
        let equity = persona?.equityAsk ?? 15
        let amount = max(1, Int(Double(state.companyValuation(balance: balance)) * equity / 100))
        state.investors.rounds.append(RaisedRound(
            investorID: persona?.id ?? "standing_debug_board",
            investorName: persona?.name ?? "Harrow Capital",
            amount: amount,
            equity: equity,
            valuation: Int((Double(amount) * 100 / max(1, equity)).rounded()),
            day: state.day,
            takesBoardSeat: true,
            expects: persona?.expectation ?? .shipCadence,
            patienceWeeks: persona?.patienceWeeks ?? 20
        ))
        if let persona { state.investors.approachedInvestorIDs.insert(persona.id) }
        state.investors.equityRemaining = max(0, state.investors.equityRemaining - equity)
    }

    /// A cooked quarter from three weeks ago, found today, through the one
    /// door every case comes through.
    private static func openCase(_ state: inout GameState, balance: BalanceConfig) -> [GameEvent] {
        guard state.crime.pendingCase == nil else { return [] }
        let entry = CrimeRecordEntry(
            id: "standing-debug-\(state.day)",
            offence: .cookBooks,
            day: max(0, state.day - 21),
            gain: 40_000,
            note: "Revenue booked a quarter before anybody paid it."
        )
        state.crime.record.append(entry)
        state.crime.notoriety = max(state.crime.notoriety, 20)
        return CrimeSystem.raiseCase(against: entry, state: &state, balance: balance)
    }

    /// Fame at the foot of a level, with the followers that hold it there.
    private static func seedSpotlight(_ name: String, state: inout GameState, balance: BalanceConfig) {
        let level = FameLevel.allCases.first {
            $0.displayName.lowercased() == name || "\($0)" == name || "\($0.rawValue)" == name
        } ?? .famous
        let fame = Fame.threshold(level, balance: balance.fame) + 1
        state.fame.fame = fame
        let perRoot = max(0.01, balance.fame.famePerRootFollower)
        state.fame.followers = max(state.fame.followers, Int((fame / perRoot) * (fame / perRoot)))
        state.fame.highWaterLevel = max(state.fame.highWaterLevel, level.rawValue)
    }
}
#endif
