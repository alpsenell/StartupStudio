import Foundation

// MARK: Iteration 8 — stakes

/// One rung of the ladder: the same seed, one notch harder. Each stake
/// keeps every stake below it, so stake 4 is stakes 1, 2, 3 and 4.
public struct Stake: Identifiable, Equatable, Hashable, Sendable {
    public let level: Int
    public let title: String
    public let detail: String

    public var id: Int { level }
}

/// The ten stakes, and what each does to the balance or the rules.
///
/// Everything here is a change to a balance value the game already has,
/// or a refusal in the reducer keyed on `GameState.rules.stake`; stake 0
/// is the identity, so a standard run's balance is untouched and the
/// pacing suites cannot move. A stake never removes a screen or a way to
/// make money — only a cushion.
public enum StakeLadder {
    public static let count = 10

    public static let all: [Stake] = [
        Stake(level: 1, title: "Thin press", detail: "Every review expects five more points."),
        Stake(level: 2, title: "No credit", detail: "The bank will not lend — not on the company's name, not on yours."),
        Stake(level: 3, title: "Hungry rivals", detail: "Rivals found twenty points stronger and ship half again as often."),
        Stake(level: 4, title: "Short patience", detail: "A seated board's patience is halved."),
        Stake(level: 5, title: "No crunch", detail: "The crunch pace is gone; the team's evenings are theirs."),
        Stake(level: 6, title: "Jumpy market", detail: "Booms and crashes twice as often."),
        Stake(level: 7, title: "Poachers", detail: "Rivals come for your people twice as often, and twice as hard."),
        Stake(level: 8, title: "The giant", detail: "The incumbent founds the moment it notices you, not when you are worth it."),
        Stake(level: 9, title: "Cold rooms", detail: "Rapport fades twice as fast; call people or lose them."),
        Stake(level: 10, title: "Mortal", detail: "A chronic condition bites harder and takes twice as long to clear."),
    ]

    public static func stake(_ level: Int) -> Stake? {
        all.first { $0.level == level }
    }

    /// The stakes a run at `level` is under, lowest first.
    public static func stakes(upTo level: Int) -> [Stake] {
        all.filter { $0.level <= level }
    }

    /// The balance changes for every stake up to `level`. Stake 0 changes
    /// nothing. Stakes 2 and 5 live in the reducer (`Reducer.apply`
    /// refuses the loan and the crunch); the rest are numbers.
    static func apply(level: Int, to balance: inout BalanceConfig) {
        guard level > 0 else { return }
        if level >= 1 {
            balance.reviewExpectationBase += 5
        }
        if level >= 3 {
            balance.rivals.foundingStrengthMin = min(100, balance.rivals.foundingStrengthMin + 20)
            balance.rivals.foundingStrengthMax = min(100, balance.rivals.foundingStrengthMax + 20)
            balance.rivals.shipChance = min(1, balance.rivals.shipChance * 1.5)
        }
        if level >= 4 {
            balance.investors.patienceReferenceWeeks = max(1, balance.investors.patienceReferenceWeeks * 0.5)
        }
        if level >= 6 {
            balance.market.boomChance = min(1, balance.market.boomChance * 2)
            balance.market.crashChance = min(1, balance.market.crashChance * 2)
        }
        if level >= 7 {
            balance.rivals.poachChance = min(1, balance.rivals.poachChance * 2)
            balance.rivals.poachIntervalDays = max(7, balance.rivals.poachIntervalDays / 2)
        }
        if level >= 8 {
            balance.rivals.depth.incumbentValuationFloor = 0
        }
        if level >= 9 {
            balance.networking.rapportDecayPerDay *= 2
        }
        if level >= 10 {
            balance.economy.chronicMaxEnergy = min(balance.economy.chronicMaxEnergy, 60)
            balance.economy.chronicOutputFactor = min(balance.economy.chronicOutputFactor, 0.75)
            balance.economy.chronicCureWeeks *= 2
        }
    }

    /// Whether `action` is one a stake forbids: the loans at stake 2 (and,
    /// iteration 13, bought cash and the receiver's call with them), the
    /// crunch at stake 5.
    static func refuses(_ action: GameAction, at level: Int) -> Bool {
        switch action {
        case .takeLoan, .takeSecuredLoan:
            level >= 2
        case .setWorkPace(let pace):
            level >= 5 && pace == .crunch
        // MARK: K1 (founder money)
        // "No credit" covers the founder's own: at stake 2 the company
        // lives on what it earns.
        case .lendToCompany:
            level >= 2
        // MARK: end K1
        // MARK: P1 (purchases: engine)
        // "The bank won't lend, and neither will we." The veteran is not
        // money, so a stake leaves it alone.
        case .applyPurchase(let kind, _):
            switch kind {
            case .cash, .secondChance: level >= 2
            case .veteran: false
            }
        // MARK: end P1
        default:
            false
        }
    }
}
