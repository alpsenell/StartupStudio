import Foundation

// Iteration 10 — M3 owns this file and may reshape it freely. A live
// product breaking, handled in the incident room with the clock stopped;
// `nil` on `GameState` when nothing is on fire.

public struct IncidentState: Codable, Equatable, Sendable {
    public var productID: UUID
    /// What broke — M3 defines the kinds (bad patch, viral spike, leak…).
    public var kind: String
    public var startedDay: Int

    public init(productID: UUID, kind: String, startedDay: Int) {
        self.productID = productID
        self.kind = kind
        self.startedDay = startedDay
    }
}
