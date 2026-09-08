import Foundation

// Iteration 11 — N1 owns this file and may reshape it freely. The founder's
// notoriety, the shady things they did, the case against them and the
// courtroom. Wave two (dirty money, espionage, family drama, prison) reads
// `notoriety` and raises cases through `CrimeState`, so keep those two
// names and their meaning; everything else is N1's.

/// A pending legal case: who brought it, what for, and when it is heard.
public struct LegalCase: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    /// What it is about — N1 defines the kinds (audit, whistleblower, NDA…).
    public var kind: String
    public var raisedDay: Int
    public var hearingDay: Int

    public init(id: String, kind: String, raisedDay: Int, hearingDay: Int) {
        self.id = id
        self.kind = kind
        self.raisedDay = raisedDay
        self.hearingDay = hearingDay
    }
}

public struct CrimeState: Codable, Equatable, Sendable {
    /// 0…100. How much the world suspects the founder. Decays slowly.
    public var notoriety: Double
    /// Cases raised and not yet heard.
    public var cases: [LegalCase]
    /// What was done and when — the record the courtroom reads.
    public var record: [String]

    public init(notoriety: Double = 0, cases: [LegalCase] = [], record: [String] = []) {
        self.notoriety = notoriety
        self.cases = cases
        self.record = record
    }

    public static let empty = CrimeState()
}
