import Foundation

// MARK: G8 (awards night, attended)

// Iteration 18 — G8. The ceremony: `"awards"` in `Balance.json`, appended
// at the end.
//
// Every number here is read only behind `.recordCeremony`, which only the
// ceremony sheet sends, or by the cutoff countdown the Now card and the
// ship sheet draw. No bot sends it; a balance file without the key reads
// these defaults.
//
// Two of the numbers are not the pre-vetted spec's, and both were moved by
// running the judge (a pure function) on the two late release fixtures
// before a line of this was written — the spec's own "how it fails" check.
// See `docs/product/iteration-18-lanes/awards.md` for the outputs.

extension BalanceConfig {
    public struct AwardsBalance: Codable, Equatable, Sendable {
        /// A table by office tier (`OfficeTier` raw value → dollars): the
        /// spec's $2,400 at the loft, ×2 at the studio, ×4 at the campus.
        /// A tier that is not listed falls back to the loft's price.
        public var tableByTier: [String: Int]
        /// Standing paid into the topic of a *Best in …* the team was in
        /// the room for.
        ///
        /// The spec says 15, with its own remedy: *if the player wins
        /// three-plus categories a year on the campus fixture, halve the
        /// standing*. The judge run on `release-campus-day900` returns 7
        /// and 8 player wins in its two years (4 and 6 of them topic
        /// categories), so the remedy fires and this is 7.5.
        public var winStanding: Double
        /// Hype added to the product that won a topic, with the team there.
        public var winHype: Double
        /// Morale for everyone on payroll on a night the studio took
        /// Studio of the Year home with the team in the room.
        ///
        /// The spec pays this on *any* win, with its own remedy: *if a
        /// rival never wins a topic the player is live in, the night has
        /// no loss and `lossMoraleAll` is dead weight — make Studio of the
        /// Year the only one the team cares about.* On both late fixtures
        /// no rival wins a topic the player is live in, so the remedy
        /// fires: both morale numbers key off Studio of the Year alone,
        /// and the night can be lost again.
        public var winMoraleAll: Double
        /// Reputation for Studio of the Year, with the team there.
        public var studioReputation: Double
        /// Morale for everyone on payroll on an attended night that did
        /// not take Studio of the Year: the floor sat through it.
        public var lossMoraleAll: Double
        /// A win collected from home: reputation, per envelope, and
        /// nothing else. You were not there to collect it.
        public var homeReputation: Double
        /// From this many days before the ceremony the Now card and the
        /// ship sheet print *Awards cutoff in N days*.
        public var cutoffNoticeDays: Int

        public init(
            tableByTier: [String: Int] = ["garage": 2_400, "loft": 2_400, "studio": 4_800, "campus": 9_600],
            winStanding: Double = 7.5,
            winHype: Double = 20,
            winMoraleAll: Double = 8,
            studioReputation: Double = 5,
            lossMoraleAll: Double = -3,
            homeReputation: Double = 2,
            cutoffNoticeDays: Int = 28
        ) {
            self.tableByTier = tableByTier
            self.winStanding = winStanding
            self.winHype = winHype
            self.winMoraleAll = winMoraleAll
            self.studioReputation = studioReputation
            self.lossMoraleAll = lossMoraleAll
            self.homeReputation = homeReputation
            self.cutoffNoticeDays = cutoffNoticeDays
        }

        /// The shipped numbers.
        public static let `default` = AwardsBalance()

        private enum CodingKeys: String, CodingKey {
            case tableByTier, winStanding, winHype, winMoraleAll, studioReputation
            case lossMoraleAll, homeReputation, cutoffNoticeDays
        }

        /// Every key optional, falling back to the default.
        public init(from decoder: any Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            let d = Self.default
            self.init(
                tableByTier: try c.decodeIfPresent([String: Int].self, forKey: .tableByTier) ?? d.tableByTier,
                winStanding: try c.decodeIfPresent(Double.self, forKey: .winStanding) ?? d.winStanding,
                winHype: try c.decodeIfPresent(Double.self, forKey: .winHype) ?? d.winHype,
                winMoraleAll: try c.decodeIfPresent(Double.self, forKey: .winMoraleAll) ?? d.winMoraleAll,
                studioReputation: try c.decodeIfPresent(Double.self, forKey: .studioReputation)
                    ?? d.studioReputation,
                lossMoraleAll: try c.decodeIfPresent(Double.self, forKey: .lossMoraleAll) ?? d.lossMoraleAll,
                homeReputation: try c.decodeIfPresent(Double.self, forKey: .homeReputation) ?? d.homeReputation,
                cutoffNoticeDays: try c.decodeIfPresent(Int.self, forKey: .cutoffNoticeDays)
                    ?? d.cutoffNoticeDays
            )
        }

        /// The table's price at `tier`; the loft's where a tier is not
        /// listed, so every office has a price and none is free.
        public func tablePrice(for tier: OfficeTier) -> Int {
            tableByTier[tier.rawValue] ?? tableByTier[OfficeTier.loft.rawValue] ?? 2_400
        }
    }
}

// Lets `BalanceConfig`'s synthesized decoder read a balance file with no
// `"awards"` object.
extension KeyedDecodingContainer {
    func decode(
        _ type: BalanceConfig.AwardsBalance.Type,
        forKey key: Key
    ) throws -> BalanceConfig.AwardsBalance {
        try decodeIfPresent(type, forKey: key) ?? .default
    }
}

// MARK: end G8
