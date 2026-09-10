import Foundation

// Iteration 9 — L3. Everything that tunes a childhood.
//
// Kept as a computed default on `BalanceConfig` rather than a stored,
// JSON-decoded block: adding a stored property to `BalanceConfig` would
// mean hand-writing its whole Codable, and nothing here is a number the
// balance passes ever want to sweep — a child's stage and bond move no
// company number. The struct is public and the accessor is a `var`, so a
// future round can promote it to `Balance.json` without touching a caller.

/// The five ages, the bond, the summer at the studio.
public struct ChildhoodBalance: Equatable, Sendable {
    /// The first day of each stage after `baby`, as days since birth:
    /// baby → toddler → school → teen → grown. Four thresholds for five
    /// stages; past the last one they are grown.
    ///
    /// Kids grow faster than companies on purpose. At 364 days to the
    /// game year these read as: baby for a quarter, toddler until nine
    /// months, school until eighteen months, teen until two and a half
    /// years — so a child born in the garage is a teenager by the campus.
    ///
    /// Iteration 12 (J6): `[90, 270, 540, 900]`, halved from
    /// `[180, 540, 1100, 1800]`. The earliest births land around day 200,
    /// and at the old clock a teen arrived around day 1300 and a grown
    /// child around day 2000, so the intern summer, `kid_teen_door`,
    /// `kid_moves_out`, disowning and the grown vignettes almost never
    /// played. Ages are still read off the stage (`Child.stage(on:)`),
    /// never off a number of years.
    public var stageDays: [Int]
    /// The engine's year, for the age label.
    public var yearDays: Int

    // Bond

    /// Days of no attention before the bond starts sliding.
    public var bondGraceDays: Int
    /// Bond lost each day past the grace window.
    public var bondDecayPerDay: Double
    /// An evening spent on one child.
    public var bondPerEvening: Double
    /// Each child, for a weekend of family time.
    public var bondPerFamilyWeekend: Double
    /// A birthday the founder turned up to.
    public var bondPerBirthdayKept: Double
    /// A birthday answered with a present and a card somebody else wrote.
    public var bondPerBirthdayMissed: Double
    /// A `kid_*` beat answered the way the child hoped, and the other way.
    public var bondPerKidEventKept: Double
    public var bondPerKidEventMissed: Double
    /// What a burnout, a hospital stay or an eviction costs, once each.
    public var bondPerSourMemory: Double
    /// What a launch the press liked is worth to a child old enough to
    /// notice the party.
    public var bondPerLaunchMemory: Double
    /// Days between two evenings with the same child.
    public var eveningCooldownDays: Int

    // The ledger

    /// Memories kept per child; the oldest falls off the end.
    public var memoryCap: Int

    // The intern

    /// A teen needs this much bond before the studio is an option.
    public var internMinBond: Double
    /// Weeks a summer lasts.
    public var internWeeks: Int
    /// The bond a finished summer is worth, and what walking out costs.
    public var internBondBonus: Double
    public var internQuitBondPenalty: Double
    /// The skill sheet a teenager brings: enough to be useful in a corner,
    /// not enough to be a hire.
    public var internSkills: SkillSet

    public init(
        stageDays: [Int] = [90, 270, 540, 900], // J6: was [180, 540, 1100, 1800]
        yearDays: Int = 364,
        bondGraceDays: Int = 14,
        bondDecayPerDay: Double = 0.08,
        bondPerEvening: Double = 9,
        bondPerFamilyWeekend: Double = 2,
        bondPerBirthdayKept: Double = 10,
        bondPerBirthdayMissed: Double = -14,
        bondPerKidEventKept: Double = 6,
        bondPerKidEventMissed: Double = -6,
        bondPerSourMemory: Double = -4,
        bondPerLaunchMemory: Double = 2,
        eveningCooldownDays: Int = 5,
        memoryCap: Int = 12,
        internMinBond: Double = 60,
        internWeeks: Int = 8,
        internBondBonus: Double = 12,
        internQuitBondPenalty: Double = -15,
        internSkills: SkillSet = SkillSet(coding: 22, design: 18, marketing: 12)
    ) {
        self.stageDays = stageDays
        self.yearDays = yearDays
        self.bondGraceDays = bondGraceDays
        self.bondDecayPerDay = bondDecayPerDay
        self.bondPerEvening = bondPerEvening
        self.bondPerFamilyWeekend = bondPerFamilyWeekend
        self.bondPerBirthdayKept = bondPerBirthdayKept
        self.bondPerBirthdayMissed = bondPerBirthdayMissed
        self.bondPerKidEventKept = bondPerKidEventKept
        self.bondPerKidEventMissed = bondPerKidEventMissed
        self.bondPerSourMemory = bondPerSourMemory
        self.bondPerLaunchMemory = bondPerLaunchMemory
        self.eveningCooldownDays = eveningCooldownDays
        self.memoryCap = memoryCap
        self.internMinBond = internMinBond
        self.internWeeks = internWeeks
        self.internBondBonus = internBondBonus
        self.internQuitBondPenalty = internQuitBondPenalty
        self.internSkills = internSkills
    }

    public static let `default` = ChildhoodBalance()

    /// The day a summer that starts today would end.
    public func internEndDay(from day: Int) -> Int { day + internWeeks * 7 }
}

extension BalanceConfig {
    /// L3's numbers. The same on every difficulty: a childhood is not a
    /// difficulty setting.
    public var childhood: ChildhoodBalance { .default }
}
