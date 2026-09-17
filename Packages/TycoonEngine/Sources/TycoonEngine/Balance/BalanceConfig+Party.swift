import Foundation

// MARK: X4 (the launch party)

/// Iteration 18 — X4. The launch party (`iteration-18-pm.md` §4) — `"party"`
/// in `Balance.json`.
///
/// Every number here is read only after the player's own `.throwLaunchParty`,
/// which no bot and no fixture sends, so a run that never parties reads none
/// of them and writes none of their consequences.
///
/// **The slope is the whole balance.** A party's hype is the venue's `hype`
/// times `(review − hypePivot) / hypeSlope`, clamped to
/// `hypeFloor…hypeCeiling`. At the pivot (60) the biggest party buys exactly
/// nothing, so its $6,000 and its evening are pure loss; under it the party
/// *costs* hype, because a rooftop for a build nobody liked reads as what it
/// is. That, with the once-per-launch cap, is the answer to "if the EV is
/// positive the biggest party is automatic" — measured on the studio fixture,
/// see `docs/product/iteration-18-lanes/party.md`.
extension BalanceConfig {
    public struct PartyBalance: Codable, Equatable, Sendable {
        /// One venue's price and what it buys.
        public struct Venue: Codable, Equatable, Sendable {
            /// Company cash, up front.
            public var cost: Int
            /// Morale for everybody on payroll (the `teamDinner` shape).
            public var morale: Double
            /// `liveHype` at the top of the slope; scaled by the review.
            public var hype: Double
            /// How many names fit on the guest list.
            public var guests: Int
            /// The review score this venue is earned at. A party thrown
            /// above it reads as a celebration; below it, as desperation —
            /// every outlet cools by `desperateStanding` and the paper says
            /// so.
            public var earnedAt: Int

            public init(cost: Int, morale: Double, hype: Double, guests: Int, earnedAt: Int) {
                self.cost = cost
                self.morale = morale
                self.hype = hype
                self.guests = guests
                self.earnedAt = earnedAt
            }
        }

        /// Days after the launch the party may still be thrown.
        public var windowDays: Int
        /// Pizza in the office.
        public var office: Venue
        /// The bar down the road.
        public var bar: Venue
        /// The roof, with a licence and a photographer.
        public var rooftop: Venue

        /// The review score a party's hype is worth nothing at.
        public var hypePivot: Double
        /// Review points per full unit of the venue's hype.
        public var hypeSlope: Double
        /// The worst the slope can read (a rooftop for a misfire).
        public var hypeFloor: Double
        /// The best it can read (a rooftop for a hit).
        public var hypeCeiling: Double

        /// Standing an invited outlet gains — they were in the room.
        public var outletStanding: Double
        /// Standing *every* outlet loses when the party reads desperate.
        /// Set so it more than cancels `outletStanding`: an outlet that
        /// stood on the roof of a company that had just shipped a 55 comes
        /// away a point *colder* (+2 − 3), which is the spec's "press
        /// standing −1", and one that stayed home is three points colder
        /// for having read about it.
        public var desperateStanding: Double
        /// Rapport an invited contact gains.
        public var bondPerGuest: Double

        /// What a party actually thrown adds to the week's launch-party
        /// vice pressure, as a multiple of the vice's own `perLaunch` —
        /// only while the founder is on crunch (`AssetsSystem.runViceWeek`).
        /// The door's own napkin line has always been about this party.
        public var viceCrunchFactor: Double

        public init(
            windowDays: Int = 7,
            office: Venue = Venue(cost: 300, morale: 2, hype: 6, guests: 2, earnedAt: 0),
            bar: Venue = Venue(cost: 1500, morale: 4, hype: 14, guests: 4, earnedAt: 55),
            rooftop: Venue = Venue(cost: 6000, morale: 6, hype: 30, guests: 8, earnedAt: 75),
            hypePivot: Double = 60,
            hypeSlope: Double = 25,
            hypeFloor: Double = -1.2,
            hypeCeiling: Double = 1.5,
            outletStanding: Double = 2,
            desperateStanding: Double = -3,
            bondPerGuest: Double = 6,
            viceCrunchFactor: Double = 1
        ) {
            self.windowDays = windowDays
            self.office = office
            self.bar = bar
            self.rooftop = rooftop
            self.hypePivot = hypePivot
            self.hypeSlope = hypeSlope
            self.hypeFloor = hypeFloor
            self.hypeCeiling = hypeCeiling
            self.outletStanding = outletStanding
            self.desperateStanding = desperateStanding
            self.bondPerGuest = bondPerGuest
            self.viceCrunchFactor = viceCrunchFactor
        }

        public static let `default` = PartyBalance()

        /// The venue's own numbers.
        public func venue(_ venue: PartyVenue) -> Venue {
            switch venue {
            case .office: office
            case .bar: bar
            case .rooftop: rooftop
            }
        }

        private enum CodingKeys: String, CodingKey {
            case windowDays, office, bar, rooftop
            case hypePivot, hypeSlope, hypeFloor, hypeCeiling
            case outletStanding, desperateStanding, bondPerGuest, viceCrunchFactor
        }

        /// Every key optional, falling back to the default.
        public init(from decoder: any Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            let d = PartyBalance.default
            self.init(
                windowDays: try c.decodeIfPresent(Int.self, forKey: .windowDays) ?? d.windowDays,
                office: try c.decodeIfPresent(Venue.self, forKey: .office) ?? d.office,
                bar: try c.decodeIfPresent(Venue.self, forKey: .bar) ?? d.bar,
                rooftop: try c.decodeIfPresent(Venue.self, forKey: .rooftop) ?? d.rooftop,
                hypePivot: try c.decodeIfPresent(Double.self, forKey: .hypePivot) ?? d.hypePivot,
                hypeSlope: try c.decodeIfPresent(Double.self, forKey: .hypeSlope) ?? d.hypeSlope,
                hypeFloor: try c.decodeIfPresent(Double.self, forKey: .hypeFloor) ?? d.hypeFloor,
                hypeCeiling: try c.decodeIfPresent(Double.self, forKey: .hypeCeiling) ?? d.hypeCeiling,
                outletStanding: try c.decodeIfPresent(Double.self, forKey: .outletStanding) ?? d.outletStanding,
                desperateStanding: try c.decodeIfPresent(Double.self, forKey: .desperateStanding)
                    ?? d.desperateStanding,
                bondPerGuest: try c.decodeIfPresent(Double.self, forKey: .bondPerGuest) ?? d.bondPerGuest,
                viceCrunchFactor: try c.decodeIfPresent(Double.self, forKey: .viceCrunchFactor) ?? d.viceCrunchFactor
            )
        }
    }
}

// Lets `BalanceConfig`'s synthesized decoder read a balance file with no
// `"party"` object.
extension KeyedDecodingContainer {
    func decode(
        _ type: BalanceConfig.PartyBalance.Type,
        forKey key: Key
    ) throws -> BalanceConfig.PartyBalance {
        try decodeIfPresent(type, forKey: key) ?? .default
    }
}

// MARK: end X4
