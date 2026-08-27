import Foundation

/// What a person is doing — controls the desk-side status bubble and the
/// animation choice. Purely cosmetic; the app maps simulation state onto it.
///
/// The role statuses (`testing`, `legal`, `peopleOps`, `operations`) get
/// their own bubbles: a bug, a set of scales, two people, and a wrench.
public enum WorkStatus: String, Sendable, Equatable, Codable, CaseIterable {
    case idle, coding, designing, marketing, researching
    case testing, legal, peopleOps, operations
}

/// One person to place in the office scene.
public struct Occupant: Sendable, Equatable, Identifiable {
    public var id: UUID
    public var appearance: CharacterAppearance
    public var status: WorkStatus
    public var isFounder: Bool

    public init(id: UUID, appearance: CharacterAppearance, status: WorkStatus, isFounder: Bool = false) {
        self.id = id
        self.appearance = appearance
        self.status = status
        self.isFounder = isFounder
    }
}
