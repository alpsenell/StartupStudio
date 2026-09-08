import Foundation

// Iteration 11, wave two — W4 owns this file and may reshape it freely.
// Prison as a place; `nil` on `GameState` unless the founder is inside.

public struct PrisonState: Codable, Equatable, Sendable {
    public var sinceDay: Int
    public var untilDay: Int
    public var infractions: Int

    public init(sinceDay: Int, untilDay: Int, infractions: Int = 0) {
        self.sinceDay = sinceDay
        self.untilDay = untilDay
        self.infractions = infractions
    }
}
