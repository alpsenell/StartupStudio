/// Employee bios and spoken lines, loaded from `Dialogue.json`.
///
/// Scaffold shape: an empty catalog whose only entry point,
/// `line(for:mood:context:seed:)`, returns `nil` — so every caller already
/// has the fallback path it will keep using when a combination has no
/// written line. WS-B owns this file and fills the catalog in.
public struct DialogueCatalog: Codable, Equatable, Sendable {
    public init() {}

    /// The catalog a missing or empty `Dialogue.json` yields.
    public static let empty = DialogueCatalog()

    /// A line for this person in this moment, or `nil` when nothing is
    /// written for the combination (always, for now). `seed` picks
    /// deterministically among the candidates — never a system RNG.
    public func line(
        for traits: [String],
        mood: Int,
        context: DialogueContext,
        seed: UInt64
    ) -> String? {
        nil
    }
}

/// Where a line is spoken. WS-B may append cases; consumers switch with a
/// `default`.
public enum DialogueContext: String, Codable, Equatable, Sendable, CaseIterable {
    case coding, shipped, quit, hired, coffee
}
