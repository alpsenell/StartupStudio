/// The `"narrative"` block of `Balance.json` — event cadences, choice
/// deadlines, storyline pacing.
///
/// Scaffold placeholder: empty today, so `"narrative": {}` decodes and
/// `.default` is what an older balance file without the block gets.
/// WS-B adds the tunables here and the matching numbers to the
/// `"narrative"` object; no other workstream edits this file or that object.
extension BalanceConfig {
    public struct NarrativeBalance: Codable, Equatable, Sendable {
        public init() {}

        public static let `default` = NarrativeBalance()
    }
}

// Lets `BalanceConfig`'s synthesized decoder read a balance file that has
// no `"narrative"` object at all: the concrete overload wins over the generic
// `decode(_:forKey:)`, turning the required key into
// `decodeIfPresent ?? .default`.
extension KeyedDecodingContainer {
    func decode(
        _ type: BalanceConfig.NarrativeBalance.Type,
        forKey key: Key
    ) throws -> BalanceConfig.NarrativeBalance {
        try decodeIfPresent(type, forKey: key) ?? .default
    }
}
