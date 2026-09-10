import Foundation

// MARK: K7 (partner and diary)

/// Iteration 15 — K7. The partner on payroll, the ex on the cap table, the
/// diary against the roadmap and the doctor's letter (`"partner"` in
/// `Balance.json`).
///
/// Every number here is read only after the player's own action: hiring
/// the partner, a divorce that gave equity, an announcement or a launch
/// with a date in the diary, or doors armed with health under the line.
/// No bot does any of those, so the block moves no pacing gate.
extension BalanceConfig {
    public struct PartnerBalance: Codable, Equatable, Sendable {
        // The partner on payroll.

        /// Morale-target points per affection point above (or below) 50,
        /// for the partner only: `(affection − 50) × 0.3`.
        public var moraleAffectionFactor: Double
        /// Affection per day while the company is on crunch pace and the
        /// partner is on payroll, on top of the schedule's own drift.
        public var crunchAffectionPerDay: Double
        /// Affection the day after a product ships: they were there.
        public var shipAffection: Double
        /// Affection the day the founder burns out: they were there too.
        public var burnoutAffection: Double

        // The ex on the cap table.

        /// The ex's price for their slice, over its value today.
        public var buyOutMultiple: Double
        /// A buy-out paid partly from company cash must leave this many
        /// weeks of burn behind.
        public var buyOutRunwayWeeks: Int

        // The diary against the roadmap.

        /// An announce row warns of a diary date this many days either
        /// side of it.
        public var announceWindowDays: Int
        /// A ship day this close to a diary date offers *Keep the date*.
        public var launchWindowDays: Int
        /// What keeping the date does to the launch's hype.
        public var keepDateHypeFactor: Double

        // The doctor's letter.

        /// The health line the letter is written at.
        public var letterHealth: Double
        /// Days from the letter being written to it landing.
        public var letterLeadDays: Int
        /// At most one letter in this many days.
        public var letterCooldownDays: Int

        public init(
            moraleAffectionFactor: Double = 0.3,
            crunchAffectionPerDay: Double = -0.6,
            shipAffection: Double = 6,
            burnoutAffection: Double = -8,
            buyOutMultiple: Double = 1.15,
            buyOutRunwayWeeks: Int = 4,
            announceWindowDays: Int = 2,
            launchWindowDays: Int = 1,
            keepDateHypeFactor: Double = 0.85,
            letterHealth: Double = 40,
            letterLeadDays: Int = 7,
            letterCooldownDays: Int = 180
        ) {
            self.moraleAffectionFactor = moraleAffectionFactor
            self.crunchAffectionPerDay = crunchAffectionPerDay
            self.shipAffection = shipAffection
            self.burnoutAffection = burnoutAffection
            self.buyOutMultiple = buyOutMultiple
            self.buyOutRunwayWeeks = buyOutRunwayWeeks
            self.announceWindowDays = announceWindowDays
            self.launchWindowDays = launchWindowDays
            self.keepDateHypeFactor = keepDateHypeFactor
            self.letterHealth = letterHealth
            self.letterLeadDays = letterLeadDays
            self.letterCooldownDays = letterCooldownDays
        }

        public static let `default` = PartnerBalance()

        private enum CodingKeys: String, CodingKey {
            case moraleAffectionFactor, crunchAffectionPerDay, shipAffection, burnoutAffection
            case buyOutMultiple, buyOutRunwayWeeks
            case announceWindowDays, launchWindowDays, keepDateHypeFactor
            case letterHealth, letterLeadDays, letterCooldownDays
        }

        /// Every key optional, falling back to the default.
        public init(from decoder: any Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            let d = PartnerBalance.default
            self.init(
                moraleAffectionFactor: try c.decodeIfPresent(Double.self, forKey: .moraleAffectionFactor)
                    ?? d.moraleAffectionFactor,
                crunchAffectionPerDay: try c.decodeIfPresent(Double.self, forKey: .crunchAffectionPerDay)
                    ?? d.crunchAffectionPerDay,
                shipAffection: try c.decodeIfPresent(Double.self, forKey: .shipAffection) ?? d.shipAffection,
                burnoutAffection: try c.decodeIfPresent(Double.self, forKey: .burnoutAffection)
                    ?? d.burnoutAffection,
                buyOutMultiple: try c.decodeIfPresent(Double.self, forKey: .buyOutMultiple) ?? d.buyOutMultiple,
                buyOutRunwayWeeks: try c.decodeIfPresent(Int.self, forKey: .buyOutRunwayWeeks)
                    ?? d.buyOutRunwayWeeks,
                announceWindowDays: try c.decodeIfPresent(Int.self, forKey: .announceWindowDays)
                    ?? d.announceWindowDays,
                launchWindowDays: try c.decodeIfPresent(Int.self, forKey: .launchWindowDays)
                    ?? d.launchWindowDays,
                keepDateHypeFactor: try c.decodeIfPresent(Double.self, forKey: .keepDateHypeFactor)
                    ?? d.keepDateHypeFactor,
                letterHealth: try c.decodeIfPresent(Double.self, forKey: .letterHealth) ?? d.letterHealth,
                letterLeadDays: try c.decodeIfPresent(Int.self, forKey: .letterLeadDays) ?? d.letterLeadDays,
                letterCooldownDays: try c.decodeIfPresent(Int.self, forKey: .letterCooldownDays)
                    ?? d.letterCooldownDays
            )
        }
    }
}

// Lets `BalanceConfig`'s synthesized decoder read a balance file with no
// `"partner"` object.
extension KeyedDecodingContainer {
    func decode(
        _ type: BalanceConfig.PartnerBalance.Type,
        forKey key: Key
    ) throws -> BalanceConfig.PartnerBalance {
        try decodeIfPresent(type, forKey: key) ?? .default
    }
}

// MARK: end K7
