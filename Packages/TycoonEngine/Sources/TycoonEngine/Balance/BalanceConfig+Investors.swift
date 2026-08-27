/// The `"investors"` block of `Balance.json` — round sizes, valuation
/// floors, board pressure, the IPO gate.
///
/// Scaffold placeholder: empty today, so `"investors": {}` decodes and
/// `.default` is what an older balance file without the block gets.
/// WS-F adds the tunables here and the matching numbers to the
/// `"investors"` object; no other workstream edits this file or that object.
extension BalanceConfig {
    public struct InvestorBalance: Codable, Equatable, Sendable {
        public init() {}

        public static let `default` = InvestorBalance()
    }
}

// Lets `BalanceConfig`'s synthesized decoder read a balance file that has
// no `"investors"` object at all: the concrete overload wins over the generic
// `decode(_:forKey:)`, turning the required key into
// `decodeIfPresent ?? .default`.
extension KeyedDecodingContainer {
    func decode(
        _ type: BalanceConfig.InvestorBalance.Type,
        forKey key: Key
    ) throws -> BalanceConfig.InvestorBalance {
        try decodeIfPresent(type, forKey: key) ?? .default
    }
}
