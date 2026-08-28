import SwiftUI
import TycoonEngine

// Presentation helpers for the Life tab: display names, icons, balance
// lookups, and the mirrored engine rules the UI uses for button states.
// The engine enforces every rule; these only explain and predict.

// MARK: - Balance lookups

/// The ONE place the UI reads weekend-activity costs from balance. If a key
/// is named differently when the engine lands, this switch is the one-line
/// fix.
func weekendActivityCost(_ activity: WeekendActivity, balance: BalanceConfig) -> Int {
    balance.life.activity(activity).cost
}

/// Home definitions are keyed by `HomeTier` raw value. Missing keys read as
/// zero-cost — defensive only; balance should always define every tier.
func homeUpgradeCost(_ tier: HomeTier, balance: BalanceConfig) -> Int {
    balance.life.homes[tier.rawValue]?.upgradeCost ?? 0
}

func homeWeeklyRent(_ tier: HomeTier, balance: BalanceConfig) -> Int {
    balance.life.homes[tier.rawValue]?.weeklyRent ?? 0
}

// MARK: - Founder output

/// The founder's output multiplier, asked of the engine rather than
/// re-derived here.
///
/// This used to be a hand-copied version of the formula, which was already
/// a little out of date (it knew nothing about a chronic condition) and
/// would have gone further out the moment the founder's own attributes
/// started scaling it. The engine's own number is public; use it, and the
/// line on the Wellbeing card can never quote a multiplier the simulation
/// is not applying.
func founderOutputEstimate(state: GameState, balance: BalanceConfig) -> Double {
    state.founderOutputMultiplier(balance: balance)
}

/// Tint for a 0–100 life meter: red below 25, warning below 50, healthy
/// otherwise.
func lifeMeterTint(_ value: Double) -> Color {
    if value < 25 {
        Theme.negativeCash
    } else if value < 50 {
        Theme.warning
    } else {
        Theme.positiveCash
    }
}

// MARK: - Ages

/// "3 wks old" under a year, "2 yrs old" from 52 weeks on. Mirrors the
/// engine's calendar: 364-day years of 52 seven-day weeks.
func ageLabel(bornDay: Int, day: Int) -> String {
    let weeks = max(0, (day - bornDay) / 7)
    if weeks >= 52 {
        let years = weeks / 52
        return "\(years) yr\(years == 1 ? "" : "s") old"
    }
    return "\(weeks) wk\(weeks == 1 ? "" : "s") old"
}

// MARK: - Work schedule

extension WorkSchedule {
    var displayName: String {
        switch self {
        case .chill: "Chill"
        case .normal: "Normal"
        case .crunch: "Crunch"
        }
    }

    /// Design-formula output factor per schedule.
    var outputFactor: Double {
        switch self {
        case .chill: 0.8
        case .normal: 1.0
        case .crunch: 1.3
        }
    }

    /// One-line consequence shown under the picker.
    var consequence: String {
        switch self {
        case .chill:
            "×0.8 output. Energy and mood recover; more time for everyone at home."
        case .normal:
            "×1.0 output. Meters hold steady with a decent weekend."
        case .crunch:
            "×1.3 output. Energy and health drain fast; relationships suffer."
        }
    }
}

// MARK: - Weekend activities

extension WeekendActivity {
    var displayName: String {
        switch self {
        case .rest: "Rest"
        case .gym: "Gym"
        case .dateNight: "Date night"
        case .friends: "Friends"
        case .hobby: "Hobby"
        case .familyTime: "Family time"
        case .vacation: "Vacation"
        case .doctor: "Doctor"
        case .spa: "Spa day"
        case .networking: "Networking"
        }
    }

    var systemImage: String {
        switch self {
        case .rest: "bed.double.fill"
        case .gym: "dumbbell.fill"
        case .dateNight: "wineglass.fill"
        case .friends: "person.3.fill"
        case .hobby: "gamecontroller.fill"
        case .familyTime: "figure.2.and.child.holdinghands"
        case .vacation: "airplane"
        case .doctor: "cross.case.fill"
        case .spa: "drop.circle.fill"
        case .networking: "person.line.dotted.person.fill"
        }
    }

    /// Qualitative effect summary — the engine owns the numbers.
    var effectSummary: String {
        switch self {
        case .rest: "Energy up"
        case .gym: "Health up, costs energy"
        case .dateNight: "Relationships and mood up"
        case .friends: "Mood up"
        case .hobby: "Mood and energy up"
        case .familyTime: "Relationships up with the family"
        case .vacation: "Big reset — away for a week"
        case .doctor: "Cures a cold, health up"
        case .spa: "Energy and mood up, pricey"
        case .networking: "Opens a room full of people you could deal with"
        }
    }
}

// MARK: - Relationships

extension RelationshipStage {
    var displayName: String {
        switch self {
        case .single: "Single"
        case .dating: "Dating"
        case .partner: "Living together"
        case .married: "Married"
        }
    }
}

// MARK: - Homes

extension HomeTier {
    /// Position in the upgrade ladder (studio flat = 0) for "at least an
    /// apartment" style comparisons.
    var rank: Int {
        HomeTier.allCases.firstIndex(of: self) ?? 0
    }

    /// Kids need at least an apartment — mirrors the engine's `haveChild`
    /// gate.
    var allowsChildren: Bool {
        rank >= HomeTier.apartment.rank
    }

    var systemImage: String {
        switch self {
        case .studioFlat: "door.left.hand.closed"
        case .apartment: "building.fill"
        case .house: "house.fill"
        case .penthouse: "building.2.crop.circle.fill"
        }
    }
}
