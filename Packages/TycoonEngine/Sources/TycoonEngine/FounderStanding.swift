import Foundation

// Iteration 12 — J2 (the record crosses over). This whole file is J2's.
//
// The founder's record reaching the company, in three pure reads:
//
// - **The board reads the papers.** A key-person line at every quarterly
//   review with a seated board: open cases, a guilty verdict inside the
//   quarter, a beef still running and a cancellation nobody answered.
//   With no board, a term sheet that lands during an open case carries a
//   key-person clause instead.
// - **Your name gets around.** A 0…100 score recruiters hear: notoriety,
//   firings with cause, mean acts on staff, guilty verdicts, less fame and
//   less every alumnus who still vouches. It marks up every ask and, past
//   a line, keeps the best candidate from coming in at all.
// - **Fame is a spotlight.** `1 + 0.25 × fame level` on every discovery
//   and trace roll.
//
// Identity: a founder with no case, no beef, no cancellation, no mean act
// on staff, no firing with cause, no guilty verdict and no fame reads a
// board line of exactly +0, a name of exactly 0 (the clamp matters —
// alumni alone would take it below zero), asks at exactly the rolled
// salary and a spotlight of exactly 1. Nothing here draws or mutates.

/// The board's reading of the founder's quarter.
public struct StandingBoardLine: Equatable, Sendable {
    /// Open cases with the founder as the defendant.
    public var openCases: Int
    /// Guilty verdicts handed down inside the quarter.
    public var guiltyVerdicts: Int
    /// Rounds of the beef still running.
    public var beefRounds: Int
    /// A cancellation nobody has answered.
    public var unansweredCancellation: Bool
    /// Board pressure the line adds, after the cap.
    public var points: Double

    public static let zero = StandingBoardLine(
        openCases: 0, guiltyVerdicts: 0, beefRounds: 0,
        unansweredCancellation: false, points: 0
    )
}

/// What recruiters hear about the founder.
public struct StandingName: Equatable, Sendable {
    /// 0…100.
    public var score: Double
    /// The fraction every ask is marked up by: `score / askDivisor`.
    public var askPremium: Double
    /// Alumni who still vouch for the founder.
    public var vouching: Int
    /// Whether the best candidate in the pool will not come in.
    public var refuses: Bool

    public static let clean = StandingName(score: 0, askPremium: 0, vouching: 0, refuses: false)
}

public enum FounderStanding {

    // MARK: The court record

    /// A case the world raised against the founder: an offence, not a
    /// suit they brought and not a custody hearing.
    static func isAgainstFounder(_ legalCase: LegalCase) -> Bool {
        !legalCase.isFounderSuing && legalCase.offence != nil
    }

    /// A verdict against the founder handed down by a court. Paying the
    /// other side off before the hearing (`settledDay`) is not one; a
    /// court-ordered settlement is, the same as a fine or a sentence —
    /// they are the verdicts that raise `crime_convicted`.
    static func isGuilty(_ legalCase: LegalCase) -> Bool {
        guard isAgainstFounder(legalCase), legalCase.settledDay == nil,
              let verdict = legalCase.verdict
        else { return false }
        return verdict != .acquitted
    }

    /// Open cases with the founder as the defendant.
    public static func openCases(_ state: GameState) -> Int {
        state.crime.cases.count { $0.isPending && isAgainstFounder($0) }
    }

    /// Guilty verdicts on the books; with `since`, only those heard after
    /// that day.
    public static func guiltyVerdicts(_ state: GameState, since: Int? = nil) -> Int {
        state.crime.cases.count { legalCase in
            guard isGuilty(legalCase) else { return false }
            guard let since else { return true }
            return legalCase.hearingDay > since && legalCase.hearingDay <= state.day
        }
    }

    // MARK: The board reads the papers

    /// The key-person line at a review. Exactly `.zero` for a founder with
    /// no case, no verdict, no beef and no unanswered cancellation.
    public static func boardLine(_ state: GameState, balance: BalanceConfig) -> StandingBoardLine {
        let config = balance.founderStanding
        let interval = max(1, balance.investors.reviewIntervalDays)
        let open = openCases(state)
        let guilty = guiltyVerdicts(state, since: state.day - interval)
        let rounds = state.fame.beef?.rounds ?? 0
        let unanswered = state.fame.cancellation.map { $0.response == nil } ?? false
        guard open > 0 || guilty > 0 || rounds > 0 || unanswered else { return .zero }
        let raw = Double(open) * config.boardOpenCase
            + Double(guilty) * config.boardGuiltyVerdict
            + Double(rounds) * config.boardBeefRound
            + (unanswered ? config.boardCancellation : 0)
        return StandingBoardLine(
            openCases: open,
            guiltyVerdicts: guilty,
            beefRounds: rounds,
            unansweredCancellation: unanswered,
            points: min(config.boardCap, max(0, raw))
        )
    }

    /// With nobody on the board to read the papers, the next investor
    /// prices them in: a term sheet that arrives while a case is open.
    public static func keyPersonClauseApplies(_ state: GameState) -> Bool {
        !state.investors.hasBoard && openCases(state) > 0
    }

    /// A rolled cheque with the key-person clause taken off it.
    public static func keyPersonPrice(_ amount: Int, balance: BalanceConfig) -> Int {
        max(1, Int((Double(amount) * balance.founderStanding.keyPersonClauseFactor).rounded()))
    }

    // MARK: Your name gets around

    /// Alumni who left on good enough terms to say so when a recruiter
    /// rings: still in the book (no outcome), rapport at the line.
    public static func vouchingAlumni(_ state: GameState, balance: BalanceConfig) -> Int {
        state.networking.contacts.count {
            $0.isAlumnus && $0.outcome == nil && $0.rapport >= balance.founderStanding.vouchRapport
        }
    }

    /// The founder's name, 0…100.
    public static func name(_ state: GameState, balance: BalanceConfig) -> StandingName {
        let config = balance.founderStanding
        let vouching = vouchingAlumni(state, balance: balance)
        let meanActs = state.interactions.standingMeanActs(
            since: state.day - config.nameMeanActWindowDays
        )
        let fameLevel = Fame.level(state.fame.fame, balance: balance.fame).rawValue
        var score = state.crime.notoriety * config.nameNotorietyWeight
        score += Double(state.interactions.firedWithCauseIDs.count) * config.nameFiredWithCause
        score += min(config.nameMeanActCap, Double(meanActs) * config.nameMeanAct)
        score += Double(guiltyVerdicts(state)) * config.nameGuiltyVerdict
        score -= Double(fameLevel) * config.nameFameLevel
        score -= Double(vouching) * config.nameAlumnusVouch
        // The clamp is the identity: a clean founder with alumni who like
        // them reads zero, not below it.
        let clamped = min(100, max(0, score))
        return StandingName(
            score: clamped,
            askPremium: config.askDivisor > 0 ? clamped / config.askDivisor : 0,
            vouching: vouching,
            refuses: clamped > 0 && clamped >= config.refuseAt
        )
    }

    /// What a candidate asks once they have heard about the founder.
    /// Exactly `salary` at a name of zero.
    public static func ask(_ salary: Int, name: StandingName) -> Int {
        guard name.askPremium > 0 else { return salary }
        return Int((Double(salary) * (1 + name.askPremium)).rounded())
    }

    /// The candidate who rang somebody who used to work here, and will
    /// not come in: the best CV on the desk, once the name is past the
    /// line. Friends are never it — they already know you.
    public static func refusingCandidateID(_ state: GameState, balance: BalanceConfig) -> UUID? {
        guard name(state, balance: balance).refuses else { return nil }
        let friends = Set(state.life.friends.friends.map(\.id))
        // MARK: P1 (purchases: engine)
        // A bought veteran said yes before the money changed hands; the
        // refusal falls on the best CV the pool itself rolled. Empty on
        // every run that bought nothing.
        let bought = PurchaseVeteran.boughtIDs(state)
        // MARK: end P1
        return state.candidatePool
            .filter { !friends.contains($0.id) && !bought.contains($0.id) }
            .max { $0.skills.total < $1.skills.total }?
            .id
    }

    // MARK: Fame is a spotlight

    /// `1 + spotlightPerRung × fame level`: exactly 1 at *unknown*.
    public static func spotlight(fame: Double, balance: BalanceConfig) -> Double {
        let level = Fame.level(fame, balance: balance.fame).rawValue
        guard level > 0 else { return 1 }
        return 1 + balance.founderStanding.spotlightPerRung * Double(level)
    }

    // MARK: Copy

    /// `THE FOUNDER'S QUARTER: +20`.
    public static func boardLineText(points: Double) -> String {
        "THE FOUNDER'S QUARTER: +\(Int(points.rounded()))"
    }

    /// `YOUR NAME: +14% ON ASKS · 2 ALUMNI VOUCH`.
    public static func nameLineText(_ name: StandingName) -> String {
        let percent = Int((name.askPremium * 100).rounded())
        let asks = percent > 0 ? "YOUR NAME: +\(percent)% ON ASKS" : "YOUR NAME: CLEAN"
        guard name.vouching > 0 else { return asks }
        return asks + " · \(name.vouching) ALUMN\(name.vouching == 1 ? "US VOUCHES" : "I VOUCH")"
    }

    /// The refusal on the button.
    public static let refusalLine = "They rang someone who used to work for you."
}

// MARK: - What the app asks

extension GameState {
    /// The founder's name, for the hiring sheet.
    public func standingName(balance: BalanceConfig) -> StandingName {
        FounderStanding.name(self, balance: balance)
    }

    /// What this candidate asks today — the number on the card and the
    /// number `EmployeeSystem.hire` pays.
    /// A friend walking in through `FriendSystem` asks what they asked:
    /// they already know you.
    public func standingAsk(for candidate: Candidate, balance: BalanceConfig) -> Int {
        guard !life.friends.friends.contains(where: { $0.id == candidate.id }) else {
            return candidate.weeklySalary
        }
        return FounderStanding.ask(candidate.weeklySalary, name: standingName(balance: balance))
    }

    /// Whether this candidate will not come in.
    public func standingRefuses(_ candidateID: UUID, balance: BalanceConfig) -> Bool {
        FounderStanding.refusingCandidateID(self, balance: balance) == candidateID
    }

    /// Fame's multiplier on every discovery and trace roll.
    public func standingSpotlight(balance: BalanceConfig) -> Double {
        FounderStanding.spotlight(fame: fame.fame, balance: balance)
    }

    /// The weekly chance this entry is found, as the sweep rolls it: the
    /// crime block's odds, the laundering key and fame's spotlight.
    public func standingDiscoveryChance(_ entry: CrimeRecordEntry, balance: BalanceConfig) -> Double {
        Crime.discoveryChance(
            entry,
            notoriety: crime.notoriety,
            hasLegal: knownDepartments.contains(.legal),
            day: day,
            balance: balance.crime,
            launderDiscovery: balance.founderStanding.launderDiscovery,
            spotlight: standingSpotlight(balance: balance)
        )
    }

    /// The line the board would add if it met today.
    public func standingBoardLine(balance: BalanceConfig) -> StandingBoardLine {
        FounderStanding.boardLine(self, balance: balance)
    }
}
