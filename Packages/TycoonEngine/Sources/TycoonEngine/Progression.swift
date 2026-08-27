import Foundation

/// The founder's starting identity, chosen in the new-game flow.
///
/// Scaffold shape: `GameState.newGame` / `GameEngine.newGame` take one with
/// a `.default` that reproduces today's founder exactly (the name
/// "Founder", the balance's founder skills, and an appearance drawn from
/// the seeded RNG). WS-F gives the archetypes their own skill spreads and
/// persists the profile in `ProgressionState`.
public struct FounderProfile: Codable, Equatable, Sendable {
    public var name: String
    public var archetype: FounderArchetype
    /// Pins the founder's pixel-art look. `nil` draws it from the game's
    /// seeded RNG, which is what every game did before archetypes existed.
    public var appearanceSeed: UInt64?

    public init(name: String, archetype: FounderArchetype, appearanceSeed: UInt64? = nil) {
        self.name = name
        self.archetype = archetype
        self.appearanceSeed = appearanceSeed
    }

    /// Today's founder: named "Founder", skills straight from the balance,
    /// appearance drawn from the seed. Keeps every existing number and
    /// every existing RNG draw exactly where it was.
    public static let `default` = FounderProfile(
        name: "Founder", archetype: .hacker, appearanceSeed: nil
    )
}

/// What the founder is good at. WS-F attaches the skill spreads
/// (hacker 55/25/20, designer 25/55/20, hustler 30/25/55); until then every
/// archetype starts from the balance's founder skills.
public enum FounderArchetype: String, Codable, Equatable, Sendable, CaseIterable {
    case hacker, designer, hustler

    public var displayName: String {
        switch self {
        case .hacker: "Hacker"
        case .designer: "Designer"
        case .hustler: "Hustler"
        }
    }
}

/// Everything the progression layer (WS-F) persists: chapter, goal
/// progress, completed goals and earned perks.
///
/// Scaffold placeholder: empty today, so it encodes as `{}` and a save
/// written before it existed decodes as `.initial`. WS-F adds fields here —
/// each one `Codable` with a `decodeIfPresent` default and, for sets and
/// dictionaries, a sorted encoding so identical states stay byte-identical.
/// Nothing outside WS-F writes to this struct.
public struct ProgressionState: Codable, Equatable, Sendable {
    public init() {}

    /// A fresh company's progression state.
    public static let initial = ProgressionState()
}
