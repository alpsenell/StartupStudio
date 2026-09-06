import Foundation

// Iteration 9 — L6 owns this file and may reshape it freely.

/// The founder away with the company in somebody else's hands. `nil` on
/// `LifeState` when the founder is running it.
public struct SabbaticalState: Codable, Equatable, Sendable {
    public var caretakerID: UUID
    public var sinceDay: Int
    public var untilDay: Int

    public init(caretakerID: UUID, sinceDay: Int, untilDay: Int) {
        self.caretakerID = caretakerID
        self.sinceDay = sinceDay
        self.untilDay = untilDay
    }
}
