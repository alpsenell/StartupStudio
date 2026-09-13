import Foundation

// MARK: T2 (the build)

/// Iteration 17 — T2. What the build's two ways out cost (shelve it, scrap
/// it) and what a declared v2 does to the parent it ships beside
/// (`"build"` in `Balance.json`).
///
/// Every number here is read only behind actions no bot sends
/// (`shelveBuild`, `unshelveBuild`, `scrapBuild`, `startProductAsV2`) or
/// behind the state those actions write (`GameState.shelf`, a `parentID`
/// on a product that did not replace anything). A run that never taps
/// them never reads a key here.
extension BalanceConfig {
    public struct BuildBalance: Codable, Equatable, Sendable {
        /// J4: a live parent whose declared v2 is on the market signs this
        /// share of the subscribers (sells this share of the units) it
        /// otherwise would. Exactly ×1 while it has no live v2.
        public var parentAcquisition: Double
        /// J4: …and its subscription book churns at this multiple.
        public var parentChurn: Double
        /// O3: morale each person on a build loses the day it is shelved.
        public var shelveCrewMorale: Double
        /// O3: the share of a shelved build's points lost per quarter in
        /// the drawer, taken a thirteenth each week.
        public var shelveDecayPerQuarter: Double
        /// P2: the share of a scrapped build's points the type's codebase
        /// keeps (never above the type's pools, never stacked on the
        /// codebase's own points — see `GameState.buildScrapQuote`).
        public var scrapBankFraction: Double
        /// P2: morale each person on a build loses the day it is scrapped.
        public var scrapCrewMorale: Double
        /// P2: a build this many days or fewer from done cannot be scrapped.
        public var scrapLastDays: Int

        public init(
            parentAcquisition: Double = 0.5,
            parentChurn: Double = 1.5,
            shelveCrewMorale: Double = -3,
            shelveDecayPerQuarter: Double = 0.1,
            scrapBankFraction: Double = 0.5,
            scrapCrewMorale: Double = -4,
            scrapLastDays: Int = 7
        ) {
            self.parentAcquisition = parentAcquisition
            self.parentChurn = parentChurn
            self.shelveCrewMorale = shelveCrewMorale
            self.shelveDecayPerQuarter = shelveDecayPerQuarter
            self.scrapBankFraction = scrapBankFraction
            self.scrapCrewMorale = scrapCrewMorale
            self.scrapLastDays = scrapLastDays
        }

        public static let `default` = BuildBalance()

        private enum CodingKeys: String, CodingKey {
            case parentAcquisition, parentChurn
            case shelveCrewMorale, shelveDecayPerQuarter
            case scrapBankFraction, scrapCrewMorale, scrapLastDays
        }

        /// Every key optional, falling back to the default.
        public init(from decoder: any Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            let d = BuildBalance.default
            self.init(
                parentAcquisition: try c.decodeIfPresent(Double.self, forKey: .parentAcquisition)
                    ?? d.parentAcquisition,
                parentChurn: try c.decodeIfPresent(Double.self, forKey: .parentChurn) ?? d.parentChurn,
                shelveCrewMorale: try c.decodeIfPresent(Double.self, forKey: .shelveCrewMorale)
                    ?? d.shelveCrewMorale,
                shelveDecayPerQuarter: try c.decodeIfPresent(Double.self, forKey: .shelveDecayPerQuarter)
                    ?? d.shelveDecayPerQuarter,
                scrapBankFraction: try c.decodeIfPresent(Double.self, forKey: .scrapBankFraction)
                    ?? d.scrapBankFraction,
                scrapCrewMorale: try c.decodeIfPresent(Double.self, forKey: .scrapCrewMorale)
                    ?? d.scrapCrewMorale,
                scrapLastDays: try c.decodeIfPresent(Int.self, forKey: .scrapLastDays) ?? d.scrapLastDays
            )
        }
    }
}

// The concrete overload wins over the generic `decode(_:forKey:)` in
// `BalanceConfig`'s synthesized decoder, so a balance file without the key
// still loads, with the defaults.
extension KeyedDecodingContainer {
    func decode(
        _ type: BalanceConfig.BuildBalance.Type,
        forKey key: Key
    ) throws -> BalanceConfig.BuildBalance {
        try decodeIfPresent(type, forKey: key) ?? .default
    }
}

// MARK: end T2
