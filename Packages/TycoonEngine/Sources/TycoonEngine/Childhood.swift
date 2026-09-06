import Foundation

// Iteration 9 — L3 owns this file: the five ages of a child, what they
// remember, and the shape of a summer spent at the studio.
//
// Kids in this game grow faster than companies. A child born in the garage
// is a teenager by the campus, which is the only way a run that lasts three
// or four game years can hold a childhood in it at all. The thresholds live
// in `ChildhoodBalance` and the copy says the convention out loud.

/// The five ages of a founder's child, derived from `bornDay` and the day —
/// nothing is stored, so an old save's children have a stage the moment it
/// loads.
public enum ChildStage: String, Codable, Equatable, Sendable, CaseIterable {
    case baby, toddler, school, teen, grown

    public var displayName: String {
        switch self {
        case .baby: "Baby"
        case .toddler: "Toddler"
        case .school: "At school"
        case .teen: "Teenager"
        case .grown: "Grown"
        }
    }

    /// Position on the baby → grown ladder.
    public var rank: Int { Self.allCases.firstIndex(of: self) ?? 0 }

    /// Old enough to notice what the company is doing to the house. Babies
    /// remember nothing; everyone else keeps a ledger.
    public var remembers: Bool { rank >= ChildStage.toddler.rank }

    /// The one line the Family card shows under the name.
    public var note: String {
        switch self {
        case .baby: "Sleeps in bursts. Remembers nothing yet."
        case .toddler: "Repeats everything you say on calls."
        case .school: "Has opinions about your logo."
        case .teen: "Out most evenings. Could intern for a summer."
        case .grown: "Gone. Still yours."
        }
    }
}

/// What a child remembers, as a tag. `ChildMemory.kind` is one of these raw
/// values; `Successors` reads them to grow the next founder.
public enum ChildMemoryKind: String, Codable, Equatable, Sendable, CaseIterable {
    /// A launch the reviewers liked — the night the house celebrated.
    case launch
    case burnout
    case hospital
    case eviction
    case missedBirthday
    case birthdayKept
    /// The company ended: an IPO, a sale, a folding.
    case exit
    /// A chapter of the company's story turned over.
    case chapter
    case sabbatical
    /// A wedding the founder took them to.
    case wedding
    case internSummer
    case internQuit
    /// An evening that was theirs.
    case evening
    /// The day they moved up a stage.
    case grewUp

    /// The SF Symbol the ledger row uses.
    public var symbolName: String {
        switch self {
        case .launch, .chapter: "sparkles"
        case .burnout, .hospital: "bandage"
        case .eviction: "shippingbox"
        case .missedBirthday: "clock.badge.exclamationmark"
        case .birthdayKept: "birthday.cake"
        case .exit: "flag.checkered"
        case .sabbatical: "sun.max"
        case .wedding: "heart"
        case .internSummer: "briefcase"
        case .internQuit: "briefcase.fill"
        case .evening: "moon.stars"
        case .grewUp: "figure.child"
        }
    }

    /// Whether this is a memory the child would rather not have.
    public var isSour: Bool {
        switch self {
        case .burnout, .hospital, .eviction, .missedBirthday, .internQuit: true
        default: false
        }
    }
}

// MARK: - Stage & bond, read off a child

extension Child {
    /// The bond a newborn starts with, and the value the hand-written
    /// Codable treats as "nothing to write".
    public static let defaultBond: Double = 50

    /// How old they are, in days.
    public func ageDays(on day: Int) -> Int { max(0, day - bornDay) }

    /// Their stage on `day`, from the balance's thresholds.
    public func stage(on day: Int, balance: ChildhoodBalance = .default) -> ChildStage {
        let age = ageDays(on: day)
        for (index, threshold) in balance.stageDays.enumerated() where age < threshold {
            return ChildStage.allCases[index]
        }
        return .grown
    }

    /// The stage, as the card's headline. Deliberately *not* a number of
    /// years: a child in this game is a teenager three game years after
    /// they were born, and "3 · teenager" reads as a mistake rather than
    /// as the convention. The convention is said in words instead, and
    /// the actual date is on the sheet.
    public func ageLabel(on day: Int, balance: ChildhoodBalance = .default) -> String {
        stage(on: day, balance: balance).displayName
    }

    /// "Born 12 Mar · Y1, three years ago" — the honest version, for the
    /// one place that has room for it.
    public func bornLabel(on day: Int, balance: ChildhoodBalance = .default) -> String {
        let years = ageDays(on: day) / balance.yearDays
        let born = GameCalendar(day: bornDay).shortLabel
        guard years > 0 else { return "Born \(born)" }
        return "Born \(born) · \(years) game year\(years == 1 ? "" : "s") ago"
    }

    /// A word for the bond number, so no card shows a bare integer.
    public var bondLabel: String {
        switch bond {
        case ..<20: "Distant"
        case ..<40: "Polite"
        case ..<60: "Close enough"
        case ..<80: "Close"
        default: "Thick as thieves"
        }
    }

    /// Whether a summer at the studio is being served right now.
    public func isInterning(on day: Int) -> Bool {
        guard let until = internUntilDay else { return false }
        return day < until
    }

    /// The two newest memories, newest first — what the Family card shows.
    public var latestMemories: [ChildMemory] {
        Array(memories.suffix(2).reversed())
    }
}
