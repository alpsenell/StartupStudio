import Foundation

// Iteration 11 — N2 owns this file and may reshape it freely. The BitLife-
// sized interaction menu for every person in the game, and the per-person
// bookkeeping (cooldowns, the last outcome line) behind it. The bars it
// moves already exist: `Employee.founderBond`/`morale`, `FamilyState.
// affection`, `Child.bond`, `Friend.bond`, `Contact.rapport`.

/// Who the founder is interacting with.
public enum InteractionTarget: Codable, Equatable, Hashable, Sendable {
    case partner
    case child(UUID)
    case friend(UUID)
    case employee(UUID)
    case contact(UUID)
    case rival(UUID)
}

public struct InteractionState: Codable, Equatable, Sendable {
    /// Last day each (target, interaction id) was used — N2 defines the
    /// key format.
    public var cooldowns: [String: Int]

    public init(cooldowns: [String: Int] = [:]) {
        self.cooldowns = cooldowns
    }

    public static let empty = InteractionState()
}
