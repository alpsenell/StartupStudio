import Foundation
import TycoonContent

// Iteration 13 — P1 (purchases: engine). The contract the app lanes (P2,
// P3) build against, and the rules behind it. See
// docs/product/iteration-13-iap.md §3.
//
// The engine does not know the store exists: no prices, no product ids.
// A run that never bought anything carries `PurchaseLog.empty`, which is
// never encoded, so every fixture and every bot's save is byte-identical.
// Nothing here draws from `rng`, `worldRNG`, `investorRNG` or `socialRNG`:
// the veteran has a private stream of his own.

/// What a purchase grants, in game terms.
public enum PurchaseKind: Codable, Equatable, Hashable, Sendable {
    /// `weeks` is 4 or 13 today; the amount is computed from state, not carried.
    case cash(weeks: Int)
    case secondChance
    case veteran
}

/// One applied transaction. `transactionID` is StoreKit's `Transaction.id`.
public struct PurchaseGrant: Codable, Equatable, Hashable, Sendable {
    public var transactionID: UInt64
    public var kind: PurchaseKind
    public var day: Int
    /// Dollars posted, for the biography's money card. 0 for the veteran;
    /// for the receiver's call, the overdraft written off plus the month
    /// of cash that went in.
    public var amount: Int

    public init(transactionID: UInt64, kind: PurchaseKind, day: Int, amount: Int) {
        self.transactionID = transactionID
        self.kind = kind
        self.day = day
        self.amount = amount
    }
}

/// The run's record of bought things. `.empty` on every run that never
/// bought anything, encoded only when it is not.
public struct PurchaseLog: Codable, Equatable, Sendable {
    /// Sorted by `transactionID`, so identical states encode identically.
    public var grants: [PurchaseGrant] = []
    /// The day the receiver's call was taken; one per company.
    public var secondChanceDay: Int? = nil

    public init(grants: [PurchaseGrant] = [], secondChanceDay: Int? = nil) {
        self.grants = grants
        self.secondChanceDay = secondChanceDay
    }

    public static let empty = PurchaseLog()
    public var isEmpty: Bool { grants.isEmpty && secondChanceDay == nil }
    /// Cash, the veteran and the second chance all unrank; nothing else lives here.
    public var affectsRanking: Bool { !isEmpty }
    public func contains(_ id: UInt64) -> Bool { grants.contains { $0.transactionID == id } }
}

/// The one rule the UI and the reducer share, so a button is never shown
/// for a purchase the reducer would refuse.
public enum PurchaseRule {
    /// The button's word in a daily, season or league company (§2).
    public static let sharedCompanyRefusal = "Not in a shared company"
    /// The button's word at stake 2 or higher, "No credit" (§2).
    public static let stakeRefusal = "Not at this stake"

    public static func allows(_ kind: PurchaseKind, state: GameState) -> Bool {
        refusal(kind, state: state) == nil
    }

    /// Why not, in one line, or nil.
    ///
    /// - Any item: never in a shared company (daily, season, league) —
    ///   those submit their score and leave a ghost regardless of ranking.
    /// - Cash: a running company, below stake 2, a month or a quarter.
    /// - The receiver's call: a bankruptcy ending, once per company, never
    ///   in a scenario (its failure is its recorded outcome), below stake 2.
    /// - The veteran: a running company with a hiring pool, one a
    ///   fortnight, and not already on the desk or the team.
    ///
    /// A repeated transaction id is the reducer's check, not this one's.
    public static func refusal(_ kind: PurchaseKind, state: GameState) -> String? {
        if state.mode.isDaily || state.mode.isSeason || state.mode.isLeague {
            return sharedCompanyRefusal
        }
        switch kind {
        case .cash(let weeks):
            if state.rules.stake >= 2 { return stakeRefusal }
            if state.gameOver != nil { return "The company has ended." }
            if weeks != 4 && weeks != 13 { return "Not an item in the shop." }
            return nil

        case .secondChance:
            if state.mode.isScenario { return "Not in a scenario" }
            if state.rules.stake >= 2 { return stakeRefusal }
            if state.purchases.secondChanceDay != nil { return "The receiver only calls once." }
            guard state.gameOver?.kind == .bankruptcy else { return "Only after a bankruptcy." }
            return nil

        case .veteran:
            if state.gameOver != nil { return "The company has ended." }
            if state.candidatePool.isEmpty { return "Nobody is looking for work this fortnight." }
            let fortnight = PurchaseVeteran.fortnight(state.day)
            if state.purchases.grants.contains(where: {
                $0.kind == .veteran && PurchaseVeteran.fortnight($0.day) == fortnight
            }) {
                return "One veteran a fortnight."
            }
            let id = PurchaseVeteran.id(seed: state.seed, day: state.day)
            if state.candidatePool.contains(where: { $0.id == id }) { return "Already on the hiring desk." }
            if state.employees.contains(where: { $0.id == id }) { return "Already on the team." }
            return nil
        }
    }

    /// What `.cash(weeks:)` would post right now:
    /// `weeks × max(weeklyBurn, floor)`, capped at the month's cap for up
    /// to four weeks and the quarter's beyond.
    public static func cashAmount(weeks: Int, state: GameState, balance: BalanceConfig) -> Int {
        guard weeks > 0 else { return 0 }
        let tuning = balance.purchase
        let perWeek = max(state.weeklyBurn(balance: balance), tuning.cashFloorPerWeek)
        let cap = weeks <= 4 ? tuning.cashCapMonth : tuning.cashCapQuarter
        return min(weeks * perWeek, cap)
    }

    /// The veteran on offer this fortnight, or nil while the pool is empty.
    ///
    /// Derived from `(seed, day / 14)` alone through a private stream, so
    /// the hire sheet shows *the* person the purchase adds — the same
    /// `Candidate` all fortnight while the office tier holds — and no
    /// state stream moves. Skills at the tier's candidate ceiling plus the
    /// bonus (capped), both traits revealed once bought, salary 1.4× the
    /// pool's formula.
    public static func veteranOnOffer(state: GameState, balance: BalanceConfig, content: ContentCatalog) -> Candidate? {
        guard !state.candidatePool.isEmpty else { return nil }
        return PurchaseVeteran.candidate(state: state, balance: balance, content: content)
    }
}

// MARK: - The veteran's private stream

enum PurchaseVeteran {
    /// The fortnight a day falls in: the veteran's rotation.
    static func fortnight(_ day: Int) -> Int { max(0, day) / 14 }

    /// `seed ^ (fortnight × golden gamma)`: never `state.rng`.
    static func stream(seed: UInt64, day: Int) -> SeededRNG {
        SeededRNG(seed: seed ^ (UInt64(fortnight(day)) &* 0x9E37_79B9_7F4A_7C15))
    }

    /// The office tier's candidate ceiling, without reputation, district
    /// or perks — the part of the pool's ceiling that holds for a
    /// fortnight, so the offer does not drift day to day.
    static func tierCeiling(_ state: GameState, _ balance: BalanceConfig) -> Double {
        let tierBonus = balance.candidateSkillTierBonus[state.company.officeTier.rawValue] ?? 0
        return min(100, max(5, balance.candidateSkillBase + tierBonus))
    }

    static func candidate(state: GameState, balance: BalanceConfig, content: ContentCatalog) -> Candidate {
        var rng = stream(seed: state.seed, day: state.day)
        let tuning = balance.purchase
        let ceiling = min(tuning.veteranSkillCap, tierCeiling(state, balance) + tuning.veteranSkillBonus)
        return EmployeeSystem.rollCandidate(
            roles: EmployeeSystem.candidateRoles(state, balance),
            ceiling: ceiling,
            skillSpread: tuning.veteranSkillSpread,
            skillCap: tuning.veteranSkillCap,
            askFactor: EmployeeSystem.candidateAskFactor(state, balance) * tuning.veteranSalaryFactor,
            balance: balance,
            content: content,
            rng: &rng
        )
    }

    /// The veteran's id for a fortnight: the stream's first draw, as
    /// `rollCandidate` takes it. Cheap — no names, no skills.
    static func id(seed: UInt64, day: Int) -> UUID {
        var rng = stream(seed: seed, day: day)
        return UUID(from: &rng)
    }

    /// Every veteran this company bought, by id. Empty — and no work — on
    /// a run that bought nothing.
    static func boughtIDs(_ state: GameState) -> Set<UUID> {
        guard !state.purchases.grants.isEmpty else { return [] }
        return Set(state.purchases.grants.lazy
            .filter { $0.kind == .veteran }
            .map { id(seed: state.seed, day: $0.day) })
    }
}

// MARK: - The reducer arm

/// Applies a verified App Store transaction (§3.3). Called from
/// `Reducer.apply` before the game-over guard, because the receiver's
/// call is only legal on an ended game.
enum PurchaseSystem {
    static let monthLabel = "App Store · a month of runway"
    static let quarterLabel = "App Store · a quarter of runway"
    static let writeOffLabel = "App Store · overdraft written off"
    static let receiverLabel = "App Store · the receiver's call"

    static func apply(
        _ kind: PurchaseKind,
        transactionID: UInt64,
        to state: inout GameState,
        balance: BalanceConfig,
        content: ContentCatalog
    ) -> [GameEvent] {
        // A replayed transaction grants nothing; the session finishes it anyway.
        guard !state.purchases.contains(transactionID) else { return [] }
        guard PurchaseRule.allows(kind, state: state) else { return [] }

        let amount: Int
        switch kind {
        case .cash(let weeks):
            amount = PurchaseRule.cashAmount(weeks: weeks, state: state, balance: balance)
            FinanceSystem.postPurchase(
                amount: amount, label: weeks == 4 ? monthLabel : quarterLabel, to: &state
            )

        case .secondChance:
            // Pulled back before the ending, not played past it: `epilogue`
            // stays nil. The loan, the guarantee (and whatever the bank
            // already took), the board and the resignations all stand.
            let overdraft = max(0, -state.company.cash)
            if overdraft > 0 {
                FinanceSystem.postPurchase(amount: overdraft, label: writeOffLabel, to: &state)
            }
            let month = PurchaseRule.cashAmount(weeks: 4, state: state, balance: balance)
            FinanceSystem.postPurchase(amount: month, label: receiverLabel, to: &state)
            amount = overdraft + month
            state.company.daysInDebt = 0
            state.company.reputation = max(
                0, state.company.reputation - balance.purchase.secondChanceReputationCost
            )
            state.gameOver = nil
            state.economy.pauseEvents = []
            state.speed = .paused
            state.purchases.secondChanceDay = state.day

        case .veteran:
            guard let veteran = PurchaseRule.veteranOnOffer(state: state, balance: balance, content: content)
            else { return [] }
            state.candidatePool.append(veteran)
            // Both traits on the card without an interview day.
            state.progression.interviewedCandidateIDs.insert(veteran.id)
            amount = 0
        }

        state.purchases.grants.append(
            PurchaseGrant(transactionID: transactionID, kind: kind, day: state.day, amount: amount)
        )
        state.purchases.grants.sort { $0.transactionID < $1.transactionID }
        return [.purchaseApplied(kind: kind, amount: amount, day: state.day)]
    }
}
