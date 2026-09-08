import Foundation

// Iteration 11 — N5. What the office keeps from the founder: when a thread
// may start, how fast it burns, and what each answer costs.
//
// Every number here is read behind `OfficeSecretsState.watching`, which
// only the Team tab sets, so a run that never looks at the team is
// bit-for-bit the run it was before this file existed whatever the values
// say. The balance argument is the *pace*: a thread that lands three clues
// a month and ends in a season is a story; one that lands weekly is a
// nuisance, and one that ends in a year is scenery.

extension BalanceConfig {

    // MARK: - Office secrets

    public struct OfficeSecretsBalance: Codable, Equatable, Sendable {
        /// Nothing before this day: the garage has no room for a secret.
        public var minDay: Int
        /// And nothing under this headcount, for the same reason.
        public var minHeadcount: Int
        /// Weekly chance a thread starts, once everything else allows one.
        public var startChance: Double
        /// Days between one thread closing and the next being allowed.
        public var gapDays: Int
        /// Days between stages. Three stages plus an ending is roughly a
        /// season of slow burn.
        public var stageDays: Int
        /// The PI's retainer, out of the founder's own wallet.
        public var privateEyeCost: Int
        /// What a deal costs the company, scaled per kind by `dealFactor`.
        public var dealCost: Int
        /// What the expense line takes each stage.
        public var embezzledPerStage: Int
        /// Morale the whole team loses when a thread ends badly.
        public var badEndingMoraleAll: Double
        /// Reputation the company loses with it.
        public var badEndingReputation: Double
        /// Morale the team gains when HR ends one cleanly.
        public var handledMoraleAll: Double
        /// The raise a recognised union wins for everybody, as a percent.
        public var unionRaisePercent: Double
        /// Board pressure a survived coup leaves behind.
        public var coupBoardPressure: Double

        public init(
            minDay: Int = 120,
            minHeadcount: Int = 4,
            startChance: Double = 0.14,
            gapDays: Int = 90,
            stageDays: Int = 12,
            privateEyeCost: Int = 2200,
            dealCost: Int = 4000,
            embezzledPerStage: Int = 1400,
            badEndingMoraleAll: Double = -8,
            badEndingReputation: Double = -5,
            handledMoraleAll: Double = 4,
            unionRaisePercent: Double = 6,
            coupBoardPressure: Double = 12
        ) {
            self.minDay = minDay
            self.minHeadcount = minHeadcount
            self.startChance = startChance
            self.gapDays = gapDays
            self.stageDays = stageDays
            self.privateEyeCost = privateEyeCost
            self.dealCost = dealCost
            self.embezzledPerStage = embezzledPerStage
            self.badEndingMoraleAll = badEndingMoraleAll
            self.badEndingReputation = badEndingReputation
            self.handledMoraleAll = handledMoraleAll
            self.unionRaisePercent = unionRaisePercent
            self.coupBoardPressure = coupBoardPressure
        }

        /// The shipped office. Like `bugHunt`, the default is not "switched
        /// off" — there is nothing to switch off until the founder looks at
        /// the team — so a balance file with no `"officeSecrets"` object
        /// still gets the game that ships.
        public static let `default` = OfficeSecretsBalance()
    }
}

// Lets `BalanceConfig`'s synthesized decoder read a balance file with no
// `"officeSecrets"` object.
extension KeyedDecodingContainer {
    func decode(
        _ type: BalanceConfig.OfficeSecretsBalance.Type,
        forKey key: Key
    ) throws -> BalanceConfig.OfficeSecretsBalance {
        try decodeIfPresent(type, forKey: key) ?? .default
    }
}
