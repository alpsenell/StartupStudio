import Foundation

// Iteration 15 — K6 (home and rooms): the engine-side reads the Home card,
// the weekend card, the city map and the amenities sheet print. Pure
// queries: nothing here draws, writes or ticks. The actions that change
// anything are in `Systems/HomeSystem.swift`.

/// What getting from home to the office costs the founder's week.
public struct HomeCommute: Equatable, Sendable {
    public let home: DistrictID
    public let office: DistrictID
    /// A pair in `home.farPairs`.
    public let isFar: Bool
    /// Evenings the commute takes off this week at the schedule in force:
    /// 0 when near, on a schedule it does not bite on, or when the week is
    /// already down to its last evening.
    public let eveningsLost: Int
    /// The schedule's evenings before the commute, `nil` without a budget.
    public let eveningsBase: Int?

    /// "near", or "far · −1 evening of 3" — the line every sheet prints.
    public var line: String {
        guard isFar else { return "near" }
        guard eveningsLost > 0, let base = eveningsBase else { return "far · no evening lost this week" }
        return "far · −\(eveningsLost) evening\(eveningsLost == 1 ? "" : "s") of \(base)"
    }
}

/// One district on the Home card's move sheet, both columns priced.
public struct HomeMoveQuote: Equatable, Sendable, Identifiable {
    public let district: DistrictID
    /// The founder's home tier here, a week.
    public let weeklyRent: Int
    /// `weeklyRent` as a share of the founder's weekly salary, in percent;
    /// `nil` on no salary.
    public let salaryPercent: Int?
    public let commute: HomeCommute
    /// What moving here costs today (`moveRentWeeks` of `weeklyRent`).
    public let moveCost: Int
    /// The founder lives here now.
    public let isCurrent: Bool
    /// Why the move is refused, in the player's words; `nil` when it is not.
    public let blocker: String?

    public var id: DistrictID { district }
}

// MARK: T6 (away)

extension NetworkingVenue {
    /// The district the city map draws this room in. Mirrors PixelKit's
    /// `CityVenueStyle.district` (the engine never imports PixelKit; the
    /// raw values are shared, and so is this table).
    public var district: DistrictID {
        switch self {
        case .coworkingMixer: .oldTown
        case .rooftopParty: .downtown
        case .demoDay: .techPark
        case .hackerHouse: .suburbs
        case .conferenceBar: .midtown
        }
    }
}

// MARK: end T6

/// The family holiday, priced for the household there is today.
public struct FamilyHolidayQuote: Equatable, Sendable {
    /// Partner (0 or 1) plus children.
    public let heads: Int
    public let cost: Int
    public let energy: Int
    public let affection: Int
    public let childBond: Int
    public let children: Int
    public let hasPartner: Bool
}

extension GameState {
    // MARK: - Rent

    /// The founder's weekly rent for `tier` (today's by default) in
    /// `district`. With no district the tier's rent exactly, which is every
    /// run that never moved.
    public func homeWeeklyRent(
        in district: DistrictID?, tier: HomeTier? = nil, balance: BalanceConfig
    ) -> Int {
        let base = balance.life.home(tier ?? life.home).weeklyRent
        guard let district else { return base }
        return Int((Double(base) * balance.city.district(district).rentMultiplier).rounded())
    }

    /// Today's rent where the founder actually lives.
    public func homeWeeklyRent(balance: BalanceConfig) -> Int {
        homeWeeklyRent(in: life.homeDistrict, balance: balance)
    }

    // MARK: - Commute

    /// The commute a home in `home` would mean with the office in `office`
    /// (today's office by default), at today's schedule. `nil` when `home`
    /// is `nil`: a home with no address has no commute.
    public func commute(
        home: DistrictID?, office: DistrictID? = nil, balance: BalanceConfig
    ) -> HomeCommute? {
        guard let home else { return nil }
        let office = office ?? city.district
        let far = balance.home.isFar(home, office)
        let base = balance.life.evenings(for: effectiveSchedule)
        let lost: Int
        if far, balance.home.commuteBites(on: effectiveSchedule), let base {
            lost = min(max(0, balance.home.commuteEvenings), max(0, base - 1))
        } else {
            lost = 0
        }
        return HomeCommute(home: home, office: office, isFar: far, eveningsLost: lost, eveningsBase: base)
    }

    /// The founder's own commute today, `nil` with no home district.
    public func homeCommute(balance: BalanceConfig) -> HomeCommute? {
        commute(home: life.homeDistrict, balance: balance)
    }

    /// Evenings the founder's commute takes off a week of `base`. Zero with
    /// no home district, which is every bot and every run before this
    /// round — so `eveningsPerWeek` reads exactly what it always read.
    func commuteEveningsLost(from base: Int, balance: BalanceConfig) -> Int {
        guard let home = life.homeDistrict,
              balance.home.isFar(home, city.district),
              balance.home.commuteBites(on: effectiveSchedule)
        else { return 0 }
        return min(max(0, balance.home.commuteEvenings), max(0, base - 1))
    }

    // MARK: - Moving

    /// What moving home to `district` costs today.
    public func homeMoveCost(to district: DistrictID, balance: BalanceConfig) -> Int {
        max(0, balance.home.moveRentWeeks) * homeWeeklyRent(in: district, balance: balance)
    }

    /// Why the founder cannot move home to `district` today, or `nil`.
    public func homeMoveBlocker(to district: DistrictID, balance: BalanceConfig) -> String? {
        if life.homeDistrict == district { return "You live here" }
        if life.isAway(day: day) { return "You are away" }
        if let evening = eveningBlocker(balance) { return evening }
        let cost = homeMoveCost(to: district, balance: balance)
        if life.wallet < cost { return "Need $\(cost - max(0, life.wallet)) more in your wallet" }
        return nil
    }

    /// Every district, both columns: the rent against the salary and the
    /// commute against the week's evenings.
    public func homeMoveQuotes(balance: BalanceConfig) -> [HomeMoveQuote] {
        DistrictID.allCases.map { district in
            let rent = homeWeeklyRent(in: district, balance: balance)
            let salary = life.founderSalary
            return HomeMoveQuote(
                district: district,
                weeklyRent: rent,
                salaryPercent: salary > 0 ? Int((Double(rent) / Double(salary) * 100).rounded()) : nil,
                commute: commute(home: district, balance: balance)
                    ?? HomeCommute(home: district, office: city.district, isFar: false, eveningsLost: 0, eveningsBase: nil),
                moveCost: homeMoveCost(to: district, balance: balance),
                isCurrent: life.homeDistrict == district,
                blocker: homeMoveBlocker(to: district, balance: balance)
            )
        }
    }

    // MARK: - The family holiday

    /// The household that would come along: the partner and the children.
    public var familyHolidayHeads: Int {
        (life.family.stage == .single ? 0 : 1) + life.family.children.count
    }

    /// The family holiday for today's household, or `nil` with nobody to
    /// take (a single founder's holiday is the vacation).
    public func familyHolidayQuote(balance: BalanceConfig) -> FamilyHolidayQuote? {
        let heads = familyHolidayHeads
        guard heads > 0 else { return nil }
        let config = balance.home
        return FamilyHolidayQuote(
            heads: heads,
            cost: config.familyHolidayCost + heads * config.familyHolidayPerHead,
            energy: Int(config.familyHolidayEnergy.rounded()),
            affection: Int(config.familyHolidayAffection.rounded()),
            childBond: Int(config.familyHolidayChildBond.rounded()),
            children: life.family.children.count,
            hasPartner: life.family.stage != .single
        )
    }

    /// What the solo vacation costs the partner's affection over the week
    /// away (the drift runs doubled while the founder is gone), as a whole
    /// number — `nil` for a single founder. The vacation row prints it.
    public func vacationAffectionCost(balance: BalanceConfig) -> Int? {
        guard life.family.stage != .single else { return nil }
        let perDay = 2 * balance.relationships.affectionDrift
        return Int((perDay * Double(balance.life.vacationDays)).rounded())
    }

    // MARK: T6 (away) — J6: what stands near each home

    /// What is a walk from a home in `district`: the networking room the
    /// map draws there and, in `away.schoolDistrict`, the park a
    /// school-age child walks past (+`schoolBondPerWeek` bond a week).
    public func homeNearby(_ district: DistrictID, balance: BalanceConfig) -> [String] {
        var parts: [String] = []
        if let venue = NetworkingVenue.allCases.first(where: { $0.district == district }) {
            parts.append("the \(venue.displayName.lowercased())")
        }
        if district.rawValue == balance.away.schoolDistrict {
            let bond = Int(balance.away.schoolBondPerWeek.rounded())
            parts.append("the park on the school run (a school-age child's bond +\(bond) a week)")
        }
        return parts
    }

    /// Whether tonight's networking room stands in the founder's home
    /// district: "a walk from home".
    public var tonightsRoomIsNearHome: Bool {
        guard let home = life.homeDistrict, let event = networking.pendingEvent else { return false }
        return event.venue.district == home
    }

    // MARK: end T6

    // MARK: - The break

    /// The amenities a break can be called in, in catalog order.
    public static let breakAmenities: [Amenity] = [.gameRoom, .cafeteria, .gym]

    /// Why a break in `amenity` cannot be called today, or `nil`.
    public func roomBreakBlocker(_ amenity: Amenity, balance: BalanceConfig) -> String? {
        guard Self.breakAmenities.contains(amenity) else { return "Nobody takes a break on the shuttle" }
        guard hasAmenity(amenity) else {
            let name = switch amenity {
            case .gameRoom: "game room"
            case .cafeteria: "cafeteria"
            case .shuttle: "shuttle"
            case .gym: "gym"
            }
            return "Build the \(name) first"
        }
        guard employees.contains(where: { !$0.isFounder }) else { return "Nobody to give a break to" }
        if life.isAway(day: day) { return "You are away" }
        if let next = nextBreakDay(balance: balance), next > day {
            let wait = next - day
            return "Next break in \(wait) day\(wait == 1 ? "" : "s")"
        }
        return nil
    }

    /// The first day another break can be called, `nil` before the first.
    public func nextBreakDay(balance: BalanceConfig) -> Int? {
        lastBreakDay.map { $0 + max(1, balance.home.breakCooldownDays) }
    }

    /// The factor on today's build progress: `breakDayFactor` on the day
    /// after a break was called (the day the reducer is working through
    /// when the player called it), exactly 1 on every other day — so a run
    /// that never calls one multiplies by 1.0 and moves no bit.
    func roomBreakDayFactor(_ balance: BalanceConfig) -> Double {
        guard let last = lastBreakDay, last == day - 1 else { return 1 }
        return balance.home.breakDayFactor
    }
}
