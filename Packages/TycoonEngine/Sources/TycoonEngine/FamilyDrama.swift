import Foundation

// Iteration 11, wave two — W2 owns this file and may reshape it freely.
// Discovery, divorce, custody, in-laws, the sibling, the parents, the will.

public struct FamilyDramaState: Codable, Equatable, Sendable {
    public var divorcedDay: Int?
    /// Who inherits the company — W2 defines the choices.
    public var heir: String?

    public init(divorcedDay: Int? = nil, heir: String? = nil) {
        self.divorcedDay = divorcedDay
        self.heir = heir
    }

    public static let empty = FamilyDramaState()
}
