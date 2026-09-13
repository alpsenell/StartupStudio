import Foundation

// MARK: T6 (away)

/// Iteration 17 — T6. Away from the desk (`genre.md` §3), the launch that
/// reads the founder away (`systems.md` §4) and the home that reads the
/// map (`systems.md` §8) — `"away"` in `Balance.json`.
///
/// Every number here is read only after the player's own action — a
/// course sent, the holiday question answered (rolled only while
/// `doors.armed`), a launch with doors armed and the founder away, a home
/// district picked — so no bot and no fixture ever reads one.
extension BalanceConfig {
    public struct AwayBalance: Codable, Equatable, Sendable {
        // The course.

        /// What a course costs before People & HR's `hrTrainingCostFactor`.
        public var courseCost: Int
        /// Days away on a course.
        public var courseDays: Int
        /// Skill points in the chosen skill on the day they are back.
        public var courseSkillBoost: Double
        /// Morale-target points while away, for any reason.
        public var awayMoraleTarget: Double

        // The holiday rule.

        /// Days away a year under *Ten days a year, take them*, from each
        /// person's hiring anniversary.
        public var holidayDays: Int
        /// Morale-target points for everyone while the generous rule stands.
        public var holidayMoraleTarget: Double
        /// Loyalty, once, for everyone the generous rule answers for.
        public var holidayLoyalty: Double
        /// Morale-target points for everyone while the strict rule stands.
        public var strictMoraleTarget: Double
        /// `burnoutWarning`'s weight while the strict rule stands.
        public var strictBurnoutWeight: Double

        // The launch without its founder.

        /// Launch hype while the founder is away on ship day (doors armed).
        public var launchHypeFactor: Double

        // The home that reads the map.

        /// The district whose home puts a school-age child near the park
        /// (J6's check failed from the Suburbs office, so the bond moved to
        /// Midtown as the spec's remedy says).
        public var schoolDistrict: String
        /// Bond a week with each school-age child from a home there.
        public var schoolBondPerWeek: Double

        public init(
            courseCost: Int = 2400,
            courseDays: Int = 10,
            // The spec's +12 measured +8.4% weekly points on the studio's
            // whole crew for a 10-day slip — over the 8% line — so the
            // spec's remedy: +9.
            courseSkillBoost: Double = 9,
            awayMoraleTarget: Double = 2,
            holidayDays: Int = 10,
            holidayMoraleTarget: Double = 4,
            holidayLoyalty: Double = 8,
            strictMoraleTarget: Double = -3,
            strictBurnoutWeight: Double = 1.5,
            launchHypeFactor: Double = 0.85,
            schoolDistrict: String = "midtown",
            schoolBondPerWeek: Double = 1
        ) {
            self.courseCost = courseCost
            self.courseDays = courseDays
            self.courseSkillBoost = courseSkillBoost
            self.awayMoraleTarget = awayMoraleTarget
            self.holidayDays = holidayDays
            self.holidayMoraleTarget = holidayMoraleTarget
            self.holidayLoyalty = holidayLoyalty
            self.strictMoraleTarget = strictMoraleTarget
            self.strictBurnoutWeight = strictBurnoutWeight
            self.launchHypeFactor = launchHypeFactor
            self.schoolDistrict = schoolDistrict
            self.schoolBondPerWeek = schoolBondPerWeek
        }

        public static let `default` = AwayBalance()

        private enum CodingKeys: String, CodingKey {
            case courseCost, courseDays, courseSkillBoost, awayMoraleTarget
            case holidayDays, holidayMoraleTarget, holidayLoyalty, strictMoraleTarget, strictBurnoutWeight
            case launchHypeFactor, schoolDistrict, schoolBondPerWeek
        }

        /// Every key optional, falling back to the default.
        public init(from decoder: any Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            let d = AwayBalance.default
            self.init(
                courseCost: try c.decodeIfPresent(Int.self, forKey: .courseCost) ?? d.courseCost,
                courseDays: try c.decodeIfPresent(Int.self, forKey: .courseDays) ?? d.courseDays,
                courseSkillBoost: try c.decodeIfPresent(Double.self, forKey: .courseSkillBoost) ?? d.courseSkillBoost,
                awayMoraleTarget: try c.decodeIfPresent(Double.self, forKey: .awayMoraleTarget) ?? d.awayMoraleTarget,
                holidayDays: try c.decodeIfPresent(Int.self, forKey: .holidayDays) ?? d.holidayDays,
                holidayMoraleTarget: try c.decodeIfPresent(Double.self, forKey: .holidayMoraleTarget)
                    ?? d.holidayMoraleTarget,
                holidayLoyalty: try c.decodeIfPresent(Double.self, forKey: .holidayLoyalty) ?? d.holidayLoyalty,
                strictMoraleTarget: try c.decodeIfPresent(Double.self, forKey: .strictMoraleTarget)
                    ?? d.strictMoraleTarget,
                strictBurnoutWeight: try c.decodeIfPresent(Double.self, forKey: .strictBurnoutWeight)
                    ?? d.strictBurnoutWeight,
                launchHypeFactor: try c.decodeIfPresent(Double.self, forKey: .launchHypeFactor) ?? d.launchHypeFactor,
                schoolDistrict: try c.decodeIfPresent(String.self, forKey: .schoolDistrict) ?? d.schoolDistrict,
                schoolBondPerWeek: try c.decodeIfPresent(Double.self, forKey: .schoolBondPerWeek)
                    ?? d.schoolBondPerWeek
            )
        }
    }
}

// Lets `BalanceConfig`'s synthesized decoder read a balance file with no
// `"away"` object.
extension KeyedDecodingContainer {
    func decode(
        _ type: BalanceConfig.AwayBalance.Type,
        forKey key: Key
    ) throws -> BalanceConfig.AwayBalance {
        try decodeIfPresent(type, forKey: key) ?? .default
    }
}

// MARK: end T6
