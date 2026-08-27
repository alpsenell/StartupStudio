/// The `"traits"` block of `Balance.json` — how strongly employee traits
/// move output, morale, growth and loyalty.
///
/// Scaffold placeholder: empty today, so `"traits": {}` decodes and
/// `.default` is what an older balance file without the block gets.
/// WS-F adds the tunables here and the matching numbers to the
/// `"traits"` object; no other workstream edits this file or that object.
extension BalanceConfig {
    public struct TraitBalance: Codable, Equatable, Sendable {
        public init() {}

        public static let `default` = TraitBalance()
    }
}

// Lets `BalanceConfig`'s synthesized decoder read a balance file that has
// no `"traits"` object at all: the concrete overload wins over the generic
// `decode(_:forKey:)`, turning the required key into
// `decodeIfPresent ?? .default`.
extension KeyedDecodingContainer {
    func decode(
        _ type: BalanceConfig.TraitBalance.Type,
        forKey key: Key
    ) throws -> BalanceConfig.TraitBalance {
        try decodeIfPresent(type, forKey: key) ?? .default
    }
}
