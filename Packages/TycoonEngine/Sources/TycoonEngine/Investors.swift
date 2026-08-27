import Foundation

/// Everything the investor/board layer (WS-F) persists: raised rounds,
/// remaining equity, the pending offer and board pressure.
///
/// Scaffold placeholder: empty today, so it encodes as `{}` and a save
/// written before it existed decodes as `.initial`. WS-F adds fields here —
/// each one `Codable` with a `decodeIfPresent` default and, for sets and
/// dictionaries, a sorted encoding so identical states stay byte-identical.
/// Nothing outside WS-F writes to this struct.
public struct InvestorState: Codable, Equatable, Sendable {
    public init() {}

    /// A fresh company's investor state.
    public static let initial = InvestorState()
}
