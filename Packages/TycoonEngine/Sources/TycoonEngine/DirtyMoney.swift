import Foundation

// Iteration 11, wave two — W1 owns this file and may reshape it freely.
// Shady money: the backer, the cheque, the strings and the heat.

public struct DirtyMoneyState: Codable, Equatable, Sendable {
    /// The backer's id — W1 defines the three. `nil` until a cheque is taken.
    public var backer: String?
    public var takenDay: Int?
    /// 0…100. How annoyed they are.
    public var heat: Double

    public init(backer: String? = nil, takenDay: Int? = nil, heat: Double = 0) {
        self.backer = backer
        self.takenDay = takenDay
        self.heat = heat
    }

    public static let empty = DirtyMoneyState()
}
