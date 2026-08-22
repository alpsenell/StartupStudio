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

/// The design formula for the founder's output multiplier:
/// schedule factor × wellbeing (0.5–1.0 from weighted meters) × cold
/// penalty × presence. Mirrors the engine for the meters card estimate.
func founderOutputEstimate(life: LifeState, day: Int) -> Double {
    guard !life.isAway(day: day) else { return 0 }
    let meters = life.meters
    let wellbeing = (0.4 * meters.energy + 0.3 * meters.health + 0.3 * meters.mood) / 100
    let coldFactor = life.hasCold(day: day) ? 0.6 : 1.0
    return life.schedule.outputFactor * (0.5 + 0.5 * wellbeing) * coldFactor
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
