import Foundation

extension BalanceConfig {
    /// Rival-sponsored white-label contracts (WS-C, iteration 5). Every
    /// knob must read neutral at its default: no sponsored offer rolls in
    /// a game with `rivals.rivalCount == 0`, which is what the pacing
    /// suite runs, so the baseline table cannot move.
    public struct SponsoredContractBalance: Codable, Equatable, Sendable {
        public init() {}
        public static let `default` = SponsoredContractBalance()
    }
}
