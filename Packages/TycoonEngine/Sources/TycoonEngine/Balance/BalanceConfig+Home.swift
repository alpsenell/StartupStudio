import Foundation

// Iteration 15 — K6 (home and rooms). Where the founder lives, the family
// holiday, and the office's paid break
// (docs/product/iteration-15-pm/life.md §3 and §7, meta.md §8).
//
// Every number here is read only once the player has done the thing it
// prices: a home with no district (`LifeState.homeDistrict == nil`, every
// run before this round and every bot) pays the tier's rent unmultiplied
// and has no commute; nobody plans a family holiday or calls a break but a
// player. `"home"` is appended at the end of `Balance.json`; a balance file
// without it reads these defaults.
//
// - The rent is the tier's `weeklyRent × city.districts[home].rentMultiplier`.
// - A far home (a pair in `farPairs`, either way round) takes
//   `commuteEvenings` off the week on the schedules in `commuteSchedules`,
//   and never the week's last evening.
// - Moving costs `moveRentWeeks` of the new rent and an evening.
// - A family holiday is the vacation with company: `familyHolidayCost` +
//   `familyHolidayPerHead` for the partner and each child, the vacation's
//   meters with `familyHolidayEnergy` in place of its energy, the partner's
//   affection `+familyHolidayAffection`, each child's bond
//   `+familyHolidayChildBond`.
// - A break (game room, cafeteria, gym): every hired employee's morale
//   `+breakMorale`, the founder's energy `+breakGymEnergy` in the gym, the
//   next day's work on every build × `breakDayFactor`, once per
//   `breakCooldownDays`.

extension BalanceConfig {

    // MARK: - Home and rooms

    public struct HomeBalance: Codable, Equatable, Sendable {
        /// District pairs, by raw value, far enough apart that getting to
        /// the office eats an evening. Symmetric; everything else is near.
        public var farPairs: [[String]]
        /// Evenings a far commute takes off the week.
        public var commuteEvenings: Int
        /// The work schedules (raw values) a far commute bites on. The
        /// measured remedy (life.md §3 "how it fails") is to leave `chill`
        /// out: a relaxed week absorbs the train.
        public var commuteSchedules: [String]
        /// Weeks of the new rent a move costs.
        public var moveRentWeeks: Int
        /// The family holiday's base price, before heads.
        public var familyHolidayCost: Int
        /// Added for the partner and for each child.
        public var familyHolidayPerHead: Int
        /// The family holiday's energy, in place of the vacation's.
        public var familyHolidayEnergy: Double
        /// Affection the partner gains for coming along.
        public var familyHolidayAffection: Double
        /// Bond each child gains for coming along.
        public var familyHolidayChildBond: Double
        /// Morale every hired employee gains from a break.
        public var breakMorale: Double
        /// Founder energy a break in the gym is also worth.
        public var breakGymEnergy: Double
        /// Build progress on the day after a break, as a factor.
        public var breakDayFactor: Double
        /// Days between two breaks.
        public var breakCooldownDays: Int

        public init(
            farPairs: [[String]] = [["suburbs", "downtown"], ["suburbs", "techPark"], ["oldTown", "techPark"]],
            commuteEvenings: Int = 1,
            commuteSchedules: [String] = ["normal", "crunch"],
            moveRentWeeks: Int = 2,
            familyHolidayCost: Int = 1_500,
            familyHolidayPerHead: Int = 600,
            familyHolidayEnergy: Double = 25,
            familyHolidayAffection: Double = 20,
            familyHolidayChildBond: Double = 8,
            breakMorale: Double = 3,
            breakGymEnergy: Double = 5,
            breakDayFactor: Double = 0.5,
            breakCooldownDays: Int = 7
        ) {
            self.farPairs = farPairs
            self.commuteEvenings = commuteEvenings
            self.commuteSchedules = commuteSchedules
            self.moveRentWeeks = moveRentWeeks
            self.familyHolidayCost = familyHolidayCost
            self.familyHolidayPerHead = familyHolidayPerHead
            self.familyHolidayEnergy = familyHolidayEnergy
            self.familyHolidayAffection = familyHolidayAffection
            self.familyHolidayChildBond = familyHolidayChildBond
            self.breakMorale = breakMorale
            self.breakGymEnergy = breakGymEnergy
            self.breakDayFactor = breakDayFactor
            self.breakCooldownDays = breakCooldownDays
        }

        /// The shipped numbers.
        public static let `default` = HomeBalance()

        /// Whether a home in `a` and an office in `b` are a far commute.
        public func isFar(_ a: DistrictID, _ b: DistrictID) -> Bool {
            farPairs.contains { pair in
                pair.count == 2
                    && ((pair[0] == a.rawValue && pair[1] == b.rawValue)
                        || (pair[0] == b.rawValue && pair[1] == a.rawValue))
            }
        }

        /// Whether a far commute costs evenings on `schedule`.
        public func commuteBites(on schedule: WorkSchedule) -> Bool {
            commuteSchedules.contains(schedule.rawValue)
        }

        private enum CodingKeys: String, CodingKey {
            case farPairs, commuteEvenings, commuteSchedules, moveRentWeeks
            case familyHolidayCost, familyHolidayPerHead, familyHolidayEnergy
            case familyHolidayAffection, familyHolidayChildBond
            case breakMorale, breakGymEnergy, breakDayFactor, breakCooldownDays
        }

        /// Every key optional, falling back to the default.
        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let fallback = Self.default
            self.init(
                farPairs: try container.decodeIfPresent([[String]].self, forKey: .farPairs)
                    ?? fallback.farPairs,
                commuteEvenings: try container.decodeIfPresent(Int.self, forKey: .commuteEvenings)
                    ?? fallback.commuteEvenings,
                commuteSchedules: try container.decodeIfPresent([String].self, forKey: .commuteSchedules)
                    ?? fallback.commuteSchedules,
                moveRentWeeks: try container.decodeIfPresent(Int.self, forKey: .moveRentWeeks)
                    ?? fallback.moveRentWeeks,
                familyHolidayCost: try container.decodeIfPresent(Int.self, forKey: .familyHolidayCost)
                    ?? fallback.familyHolidayCost,
                familyHolidayPerHead: try container.decodeIfPresent(Int.self, forKey: .familyHolidayPerHead)
                    ?? fallback.familyHolidayPerHead,
                familyHolidayEnergy: try container.decodeIfPresent(Double.self, forKey: .familyHolidayEnergy)
                    ?? fallback.familyHolidayEnergy,
                familyHolidayAffection: try container.decodeIfPresent(Double.self, forKey: .familyHolidayAffection)
                    ?? fallback.familyHolidayAffection,
                familyHolidayChildBond: try container.decodeIfPresent(Double.self, forKey: .familyHolidayChildBond)
                    ?? fallback.familyHolidayChildBond,
                breakMorale: try container.decodeIfPresent(Double.self, forKey: .breakMorale)
                    ?? fallback.breakMorale,
                breakGymEnergy: try container.decodeIfPresent(Double.self, forKey: .breakGymEnergy)
                    ?? fallback.breakGymEnergy,
                breakDayFactor: try container.decodeIfPresent(Double.self, forKey: .breakDayFactor)
                    ?? fallback.breakDayFactor,
                breakCooldownDays: try container.decodeIfPresent(Int.self, forKey: .breakCooldownDays)
                    ?? fallback.breakCooldownDays
            )
        }
    }
}
