import Foundation

// MARK: G8 (awards night, attended)

/// Iteration 18 — G8. The night the year is judged on.
///
/// The judging itself stays in the app (`AwardsJudge`), where it has lived
/// since iteration 8: it reads the player's launches and every rival's,
/// and it is a pure function of the state it is handed. The engine never
/// learns to judge. What the engine learns is one thing — that a ceremony
/// happened, whether the team was in the room, and what the envelopes
/// said — sent as a single `.recordCeremony` from the sheet after the
/// judge has run.
///
/// So everything here is written by exactly one action, which only the
/// ceremony sheet sends. No bot opens that sheet; no tick reaches this
/// file. A run that never attends a ceremony writes `ceremonies` empty and
/// `Company.encode` leaves the key out, so every old save and every
/// fixture stays byte-for-byte what it was.

/// One envelope the player's studio took home.
///
/// The app fills this in from the judged night: the category as it was
/// printed, plus the two things the payouts need to know — which topic it
/// was for, and which of the player's products won it.
public struct CeremonyWin: Codable, Equatable, Sendable {
    /// The category as the ceremony printed it: "Best in Finance",
    /// "Studio of the Year".
    public var title: String
    /// The topic a *Best in …* envelope was for; `nil` for the three
    /// categories that belong to no topic.
    public var topicID: String?
    /// The player product that won it, where one did. Studio of the Year
    /// is the company's, not a product's, so it carries none.
    public var productID: UUID?
    /// Studio of the Year: the only envelope the floor came for
    /// (see the note on `AwardsBalance.winMoraleAll`).
    public var isStudioOfTheYear: Bool

    public init(
        title: String,
        topicID: String? = nil,
        productID: UUID? = nil,
        isStudioOfTheYear: Bool = false
    ) {
        self.title = title
        self.topicID = topicID
        self.productID = productID
        self.isStudioOfTheYear = isStudioOfTheYear
    }
}

/// A night that happened: which year's, whether the team was there, and
/// what was won. One per year at most.
public struct CeremonyRecord: Codable, Equatable, Sendable {
    public var year: Int
    /// The team was in the room. False is *Stay home*, which still records
    /// the night — a year is only ever answered once.
    public var attended: Bool
    public var wins: [CeremonyWin]

    public init(year: Int, attended: Bool, wins: [CeremonyWin]) {
        self.year = year
        self.attended = attended
        self.wins = wins
    }
}

/// Why the night cannot be answered. Rule 7: a refused action says why.
public enum CeremonyRefusal: String, Equatable, Sendable, CaseIterable {
    case alreadyAnswered
    case notYet
    case noEvening
    case cantAfford

    public var sentence: String {
        switch self {
        case .alreadyAnswered: "That year's ceremony is already in the book."
        case .notYet: "That ceremony has not been held yet."
        case .noEvening: "No evenings left this week."
        case .cantAfford: "Not enough cash for the table."
        }
    }
}

extension GameState {
    /// The night for `year`, once it has been answered.
    public func ceremony(year: Int) -> CeremonyRecord? {
        company.ceremonies.first { $0.year == year }
    }

    /// What a table costs this company tonight: `awards.tableByTier`, with
    /// the loft's price standing in for a tier that is not listed (the
    /// garage has no team to take).
    public func ceremonyTablePrice(balance: BalanceConfig) -> Int {
        balance.awards.tablePrice(for: company.officeTier)
    }

    /// Why *Take the team* cannot be taken for `year` tonight, or `nil`
    /// when it can. *Stay home* is refused only by the first two.
    public func ceremonyRefusal(
        year: Int,
        attending: Bool,
        balance: BalanceConfig
    ) -> CeremonyRefusal? {
        if ceremony(year: year) != nil { return .alreadyAnswered }
        if year > self.year { return .notYet }
        guard attending else { return nil }
        if !hasEveningFree(balance) { return .noEvening }
        if company.cash < ceremonyTablePrice(balance: balance) { return .cantAfford }
        return nil
    }
}

// MARK: end G8
