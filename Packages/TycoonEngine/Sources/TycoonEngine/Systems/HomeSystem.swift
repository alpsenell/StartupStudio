import Foundation

/// Iteration 15 — K6 (home and rooms): the three actions and the family
/// holiday's weekend.
///
/// Every function here runs only on an action a player sends from the app
/// (`.moveHome`, `.planFamilyHoliday`, `.callBreak`) or on a weekend that
/// action planned. No bot sends any of them, and nothing here draws from
/// `rng` or `worldRNG`. None of them posts a `GameEvent`: the app reads the
/// state it changed and says so, and the one event it could have used for a
/// journal line would have needed a case in `GameEvent.severity`, which has
/// no K6 region (a follow-up in the lane report).
enum HomeSystem {
    static let familyHolidayReason = "Family holiday"

    // MARK: - Moving home

    /// Moves the founder's home to `district`: `moveRentWeeks` of the new
    /// rent from the wallet and an evening; from next week the rent reads
    /// the district and a far commute costs an evening. A child at school
    /// or a teenager remembers it. Refused with the reasons
    /// `homeMoveBlocker` gives.
    static func moveHome(
        district: DistrictID,
        state: inout GameState,
        balance: BalanceConfig
    ) -> [GameEvent] {
        guard state.homeMoveBlocker(to: district, balance: balance) == nil else { return [] }
        state.life.wallet -= state.homeMoveCost(to: district, balance: balance)
        state.spendEvening(balance)
        state.life.homeDistrict = district
        ChildhoodSystem.rememberHome(
            &state,
            kind: "moved",
            note: { name in "Moved to \(district.displayName). New school, new everybody. \(name) kept the old key." },
            stages: [.school, .teen],
            bond: 0,
            balance: balance
        )
        return []
    }

    // MARK: - The family holiday

    /// Plans the coming weekend as the vacation with the partner and the
    /// children along. Refused with nobody to take.
    static func planFamilyHoliday(state: inout GameState, balance: BalanceConfig) -> [GameEvent] {
        guard state.familyHolidayHeads > 0 else { return [] }
        state.life.plannedActivity = .vacation
        state.life.familyHoliday = true
        return []
    }

    /// The weekend a family holiday was planned for, in place of the solo
    /// vacation: the vacation's health, mood and relationships with
    /// `familyHolidayEnergy` for energy, the price for the household, the
    /// partner's affection and every child's bond and memory, and the same
    /// week away. Called by `LifeSystem.runWeekly` only when the plan and a
    /// household are both there; the plan resets to rest like the
    /// vacation's.
    static func resolveFamilyHoliday(_ state: inout GameState, _ balance: BalanceConfig) -> [GameEvent] {
        let config = balance.home
        let day = state.day
        let vacation = balance.life.activity(.vacation)
        let cost = state.familyHolidayQuote(balance: balance)?.cost ?? vacation.cost

        state.life.meters.apply(
            energy: config.familyHolidayEnergy,
            health: vacation.health,
            mood: vacation.mood,
            relationships: vacation.relationships
        )
        state.life.wallet -= cost
        if state.life.family.stage != .single {
            state.life.family.affection = min(
                100, state.life.family.affection + config.familyHolidayAffection
            )
            state.life.family.lastPartnerDay = day
        }
        ChildhoodSystem.rememberHome(
            &state,
            kind: "holiday",
            note: { name in "The holiday. Everybody in one car, and \(name) chose the music." },
            stages: nil,
            bond: config.familyHolidayChildBond,
            balance: balance
        )

        let until = day + balance.life.vacationDays
        state.life.awayUntilDay = until
        state.life.awaySinceDay = day
        state.life.awayReason = familyHolidayReason
        state.life.plannedActivity = .rest
        state.life.familyHoliday = false
        return [
            .weekendSpent(activity: .vacation, day: day),
            .founderAway(reason: familyHolidayReason, untilDay: until, day: day),
        ]
    }

    // MARK: - The break

    /// A paid break in `amenity`: every hired employee's morale
    /// `+breakMorale`, the founder's energy `+breakGymEnergy` in the gym,
    /// and the next day's work on every build at `breakDayFactor` (read by
    /// `ProductSystem.applyDailyProgress` through `roomBreakDayFactor`).
    /// Once per `breakCooldownDays`, only with the amenity built.
    static func callBreak(
        amenity: Amenity,
        state: inout GameState,
        balance: BalanceConfig
    ) -> [GameEvent] {
        guard state.roomBreakBlocker(amenity, balance: balance) == nil else { return [] }
        let config = balance.home
        for index in state.employees.indices where !state.employees[index].isFounder {
            state.employees[index].morale = min(100, max(0,
                state.employees[index].morale + config.breakMorale
            ))
        }
        if amenity == .gym {
            state.life.meters.apply(energy: config.breakGymEnergy)
        }
        state.lastBreakDay = state.day
        return []
    }
}
