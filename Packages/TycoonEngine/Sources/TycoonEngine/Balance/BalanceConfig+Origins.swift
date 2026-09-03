import Foundation

extension BalanceConfig {
    /// The founding origins' day-0 deltas (WS-H, iteration 5). `.garage`
    /// applies none of them; every harness `newGame` call is a garage.
    public struct OriginBalance: Codable, Equatable, Sendable {
        public init() {}
        public static let `default` = OriginBalance()
    }
}
