import Foundation

/// Everything the narrative engine (WS-B) persists: the pending choice,
/// story flags, cooldowns, scheduled follow-ups and once-only bookkeeping.
///
/// Scaffold placeholder: empty today, so it encodes as `{}` and a save
/// written before it existed decodes as `.initial`. WS-B adds fields here —
/// each one `Codable` with a `decodeIfPresent` default and, for sets and
/// dictionaries, a sorted encoding so identical states stay byte-identical.
/// Nothing outside WS-B writes to this struct.
public struct NarrativeState: Codable, Equatable, Sendable {
    public init() {}

    /// A fresh company's narrative state.
    public static let initial = NarrativeState()
}
