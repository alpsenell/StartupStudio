/// The `"economy"` block of `Balance.json` — quality ceiling, revenue
/// models, hosting costs, team-size diminishing returns, work pace, pause
/// budget.
///
/// Scaffold placeholder: empty today, so `"economy": {}` decodes and
/// `.default` is what an older balance file without the block gets.
/// WS-A adds the tunables here and the matching numbers to the
/// `"economy"` object; no other workstream edits this file or that object.
extension BalanceConfig {
    public struct EconomyBalance: Codable, Equatable, Sendable {
        public init() {}

        public static let `default` = EconomyBalance()
    }
}

// Lets `BalanceConfig`'s synthesized decoder read a balance file that has
// no `"economy"` object at all: the concrete overload wins over the generic
// `decode(_:forKey:)`, turning the required key into
// `decodeIfPresent ?? .default`.
extension KeyedDecodingContainer {
    func decode(
        _ type: BalanceConfig.EconomyBalance.Type,
        forKey key: Key
    ) throws -> BalanceConfig.EconomyBalance {
        try decodeIfPresent(type, forKey: key) ?? .default
    }
}
