import Foundation

// Iteration 11, wave two — W3 owns this file and may reshape it freely.
// Operations against rivals, dossiers, and what rivals run against you.

public struct EspionageState: Codable, Equatable, Sendable {
    /// Operation records — W3 defines the shape.
    public var operations: [String]

    public init(operations: [String] = []) {
        self.operations = operations
    }

    public static let empty = EspionageState()
}
