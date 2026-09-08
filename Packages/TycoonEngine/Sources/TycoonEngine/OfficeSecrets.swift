import Foundation

// Iteration 11 — N5 owns this file and may reshape it freely. The slow-burn
// threads inside the office: a mole, a romance, embezzlement, a clique, a
// union drive, a coup. Each is a `SecretThread` with a stage, the clues it
// has dropped, and the people in it.

public struct SecretThread: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    /// What it is — N5 defines the kinds.
    public var kind: String
    public var startedDay: Int
    public var stage: Int
    public var employeeIDs: [UUID]

    public init(id: String, kind: String, startedDay: Int, stage: Int = 0, employeeIDs: [UUID] = []) {
        self.id = id
        self.kind = kind
        self.startedDay = startedDay
        self.stage = stage
        self.employeeIDs = employeeIDs
    }
}

public struct OfficeSecretsState: Codable, Equatable, Sendable {
    public var threads: [SecretThread]
    /// Kinds already run this company, so nothing repeats too soon.
    public var history: [String]

    public init(threads: [SecretThread] = [], history: [String] = []) {
        self.threads = threads
        self.history = history
    }

    public static let empty = OfficeSecretsState()
}
