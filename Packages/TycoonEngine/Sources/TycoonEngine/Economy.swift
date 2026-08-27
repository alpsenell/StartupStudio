import Foundation

/// Everything the economy, live-ops and pacing pass (WS-A) persists.
///
/// Scaffold placeholder: empty today, so it encodes as `{}` and a save
/// written before it existed decodes as `.initial`. WS-A adds fields here —
/// each one `Codable` with a `decodeIfPresent` default and, for sets and
/// dictionaries, a sorted encoding so identical states stay byte-identical.
/// Nothing outside WS-A writes to this struct.
public struct EconomyState: Codable, Equatable, Sendable {
    public init() {}

    /// A fresh company's economy state.
    public static let initial = EconomyState()
}

/// The pace the whole company works at. WS-A attaches the effects (crunch:
/// output ×1.25, morale target −18, skill growth ×1.2, bugs ×1.3; relaxed:
/// output ×0.85, morale +6) and the `.setWorkPace` action; `.normal` — the
/// only pace today — changes nothing.
public enum WorkPace: String, Codable, Equatable, Sendable, CaseIterable {
    case relaxed, normal, crunch

    public var displayName: String {
        switch self {
        case .relaxed: "Relaxed"
        case .normal: "Normal"
        case .crunch: "Crunch"
        }
    }
}
