/// The `"progression"` block of `Balance.json` — chapter gates, goal
/// rewards, founder archetypes.
///
/// Scaffold placeholder: empty today, so `"progression": {}` decodes and
/// `.default` is what an older balance file without the block gets.
/// WS-F adds the tunables here and the matching numbers to the
/// `"progression"` object; no other workstream edits this file or that object.
extension BalanceConfig {
    public struct ProgressionBalance: Codable, Equatable, Sendable {
        public init() {}

        public static let `default` = ProgressionBalance()
    }
}

// Lets `BalanceConfig`'s synthesized decoder read a balance file that has
// no `"progression"` object at all: the concrete overload wins over the generic
// `decode(_:forKey:)`, turning the required key into
// `decodeIfPresent ?? .default`.
extension KeyedDecodingContainer {
    func decode(
        _ type: BalanceConfig.ProgressionBalance.Type,
        forKey key: Key
    ) throws -> BalanceConfig.ProgressionBalance {
        try decodeIfPresent(type, forKey: key) ?? .default
    }
}
