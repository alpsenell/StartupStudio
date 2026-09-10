import Foundation

// MARK: K2 (product lifecycle)

/// Iteration 15 — K2. What retiring a product, replacing it with its v2,
/// and moving its price are worth (`"lifecycle"` in `Balance.json`).
///
/// Every number here is read only by the three actions no bot sends
/// (`sunsetProduct`, `shipReplacing`, `repriceProduct`) and by the weekly
/// sales reads gated on the fields those actions write. So the defaults are
/// the feature's own numbers and nothing here can move a run that never
/// taps them.
extension BalanceConfig {
    public struct LifecycleBalance: Codable, Equatable, Sendable {
        /// The share of the parent's subscribers a replacing successor
        /// opens with. C1's "how it fails" check decides this number; see
        /// `docs/product/iteration-15-lanes/k2.md`.
        public var successorBookCarry: Double
        /// For one-time products, which have no book: the share of the
        /// parent's post-launch hype the successor opens with.
        public var successorHypeCarry: Double
        /// A rise on a subscription product churns this share of the book
        /// the day it lands.
        public var riseChurn: Double
        /// A rise on a one-time product sells this factor for `riseWeeks`:
        /// people wait for the sale.
        public var riseUnitsFactor: Double
        public var riseWeeks: Int
        /// A cut is a sale once per `saleIntervalDays`: one bumper week at
        /// this factor, and `saleStanding` in the product's topic.
        public var saleBump: Double
        public var saleIntervalDays: Int
        public var saleStanding: Double
        /// Price changes on one product are at least this far apart.
        public var changeCooldownDays: Int

        public init(
            successorBookCarry: Double = 0.4,
            successorHypeCarry: Double = 0.5,
            riseChurn: Double = 0.12,
            riseUnitsFactor: Double = 0.8,
            riseWeeks: Int = 4,
            saleBump: Double = 1.5,
            saleIntervalDays: Int = 91,
            saleStanding: Double = 2,
            changeCooldownDays: Int = 28
        ) {
            self.successorBookCarry = successorBookCarry
            self.successorHypeCarry = successorHypeCarry
            self.riseChurn = riseChurn
            self.riseUnitsFactor = riseUnitsFactor
            self.riseWeeks = riseWeeks
            self.saleBump = saleBump
            self.saleIntervalDays = saleIntervalDays
            self.saleStanding = saleStanding
            self.changeCooldownDays = changeCooldownDays
        }

        public static let `default` = LifecycleBalance()

        private enum CodingKeys: String, CodingKey {
            case successorBookCarry, successorHypeCarry
            case riseChurn, riseUnitsFactor, riseWeeks
            case saleBump, saleIntervalDays, saleStanding
            case changeCooldownDays
        }

        /// Every key optional, falling back to the default.
        public init(from decoder: any Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            let d = LifecycleBalance.default
            self.init(
                successorBookCarry: try c.decodeIfPresent(Double.self, forKey: .successorBookCarry)
                    ?? d.successorBookCarry,
                successorHypeCarry: try c.decodeIfPresent(Double.self, forKey: .successorHypeCarry)
                    ?? d.successorHypeCarry,
                riseChurn: try c.decodeIfPresent(Double.self, forKey: .riseChurn) ?? d.riseChurn,
                riseUnitsFactor: try c.decodeIfPresent(Double.self, forKey: .riseUnitsFactor)
                    ?? d.riseUnitsFactor,
                riseWeeks: try c.decodeIfPresent(Int.self, forKey: .riseWeeks) ?? d.riseWeeks,
                saleBump: try c.decodeIfPresent(Double.self, forKey: .saleBump) ?? d.saleBump,
                saleIntervalDays: try c.decodeIfPresent(Int.self, forKey: .saleIntervalDays)
                    ?? d.saleIntervalDays,
                saleStanding: try c.decodeIfPresent(Double.self, forKey: .saleStanding) ?? d.saleStanding,
                changeCooldownDays: try c.decodeIfPresent(Int.self, forKey: .changeCooldownDays)
                    ?? d.changeCooldownDays
            )
        }
    }
}

// The concrete overload wins over the generic `decode(_:forKey:)` in
// `BalanceConfig`'s synthesized decoder, so a balance file without the key
// still loads, with the defaults.
extension KeyedDecodingContainer {
    func decode(
        _ type: BalanceConfig.LifecycleBalance.Type,
        forKey key: Key
    ) throws -> BalanceConfig.LifecycleBalance {
        try decodeIfPresent(type, forKey: key) ?? .default
    }
}

// MARK: end K2
