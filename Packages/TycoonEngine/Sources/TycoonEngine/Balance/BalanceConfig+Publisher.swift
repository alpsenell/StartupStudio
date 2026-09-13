import Foundation

// Iteration 17 — T4 (publisher). The publishing deal
// (docs/product/iteration-17-pm/genre.md §1, G1).
//
// Read only behind `.shopToPublisher` and `.buyOutPublisher`, which no bot
// sends, and on the weekly sales, the ship and the slips of a build
// somebody published. `"publisher"` is an optional key: a balance file
// without it reads these defaults.

extension BalanceConfig {

    // MARK: - Publisher

    public struct PublisherBalance: Codable, Equatable, Sendable {
        /// The weakest studio that publishes anyone: the strongest rival at
        /// or above this is the counterparty.
        public var minStrength: Double
        /// The publisher's share of the product's weekly revenue, for as
        /// long as it sells. The spec's 0.5 measured over 100% of the
        /// expected give-up on the campus, so its remedy ships: 0.4.
        public var share: Double
        /// Share of the advance clawed back with every missed date.
        public var clawbackPerSlip: Double
        /// Buying them out costs this × the advance, less the share
        /// already paid.
        public var buyoutMultiple: Double
        /// The publisher's name on launch day: `launchEventHype ×` this.
        public var launchHypeFactor: Double
        /// The advance's crew line is at least `salaryBase ×` this a week,
        /// so a founder working alone for nothing still has a cost worth
        /// advancing (the garage measured 18% of the give-up without it).
        public var crewFloorSalaryBases: Double
        /// The advance pays for this share of the weeks to the ETA (the
        /// spec's remedy for the campus: half).
        public var advanceWeeksFactor: Double
        /// The publisher's date: the ETA plus this many days.
        public var dateSlackDays: Int
        /// The sheet's estimate of their share covers this many weeks of
        /// sales.
        public var estimateWeeks: Int

        public init(
            minStrength: Double = 30,
            share: Double = 0.4,
            clawbackPerSlip: Double = 0.25,
            buyoutMultiple: Double = 1.5,
            launchHypeFactor: Double = 0.5,
            crewFloorSalaryBases: Double = 3,
            advanceWeeksFactor: Double = 0.5,
            dateSlackDays: Int = 14,
            estimateWeeks: Int = 42
        ) {
            self.minStrength = minStrength
            self.share = share
            self.clawbackPerSlip = clawbackPerSlip
            self.buyoutMultiple = buyoutMultiple
            self.launchHypeFactor = launchHypeFactor
            self.crewFloorSalaryBases = crewFloorSalaryBases
            self.advanceWeeksFactor = advanceWeeksFactor
            self.dateSlackDays = dateSlackDays
            self.estimateWeeks = estimateWeeks
        }

        /// The shipped numbers.
        public static let `default` = PublisherBalance()

        private enum CodingKeys: String, CodingKey {
            case minStrength, share, clawbackPerSlip, buyoutMultiple, launchHypeFactor
            case crewFloorSalaryBases, advanceWeeksFactor, dateSlackDays, estimateWeeks
        }

        /// Every key optional, falling back to the default.
        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let d = Self.default
            func double(_ key: CodingKeys, _ fallback: Double) throws -> Double {
                try container.decodeIfPresent(Double.self, forKey: key) ?? fallback
            }
            func int(_ key: CodingKeys, _ fallback: Int) throws -> Int {
                try container.decodeIfPresent(Int.self, forKey: key) ?? fallback
            }
            self.init(
                minStrength: try double(.minStrength, d.minStrength),
                share: try double(.share, d.share),
                clawbackPerSlip: try double(.clawbackPerSlip, d.clawbackPerSlip),
                buyoutMultiple: try double(.buyoutMultiple, d.buyoutMultiple),
                launchHypeFactor: try double(.launchHypeFactor, d.launchHypeFactor),
                crewFloorSalaryBases: try double(.crewFloorSalaryBases, d.crewFloorSalaryBases),
                advanceWeeksFactor: try double(.advanceWeeksFactor, d.advanceWeeksFactor),
                dateSlackDays: try int(.dateSlackDays, d.dateSlackDays),
                estimateWeeks: try int(.estimateWeeks, d.estimateWeeks)
            )
        }
    }
}

// Lets `BalanceConfig`'s synthesized decoder read a balance file with no
// `"publisher"` object.
extension KeyedDecodingContainer {
    func decode(
        _ type: BalanceConfig.PublisherBalance.Type,
        forKey key: Key
    ) throws -> BalanceConfig.PublisherBalance {
        try decodeIfPresent(type, forKey: key) ?? .default
    }
}
