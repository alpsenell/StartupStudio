import Foundation
import TycoonContent

// Iteration 13 — P1 (purchases: engine). The scaffold declares the contract
// the app lanes (P2, P3) build against; P1 owns this file and fills in
// `PurchaseRule`. See docs/product/iteration-13-iap.md §3.
//
// The engine does not know the store exists: no prices, no product ids.
// A run that never bought anything carries `PurchaseLog.empty`, which is
// never encoded, so every fixture and every bot's save is byte-identical.

/// What a purchase grants, in game terms.
public enum PurchaseKind: Codable, Equatable, Hashable, Sendable {
    /// `weeks` is 4 or 13 today; the amount is computed from state, not carried.
    case cash(weeks: Int)
    case secondChance
    case veteran
}

/// One applied transaction. `transactionID` is StoreKit's `Transaction.id`.
public struct PurchaseGrant: Codable, Equatable, Hashable, Sendable {
    public var transactionID: UInt64
    public var kind: PurchaseKind
    public var day: Int
    /// Dollars posted, for the biography's money card. 0 for the veteran.
    public var amount: Int

    public init(transactionID: UInt64, kind: PurchaseKind, day: Int, amount: Int) {
        self.transactionID = transactionID
        self.kind = kind
        self.day = day
        self.amount = amount
    }
}

/// The run's record of bought things. `.empty` on every run that never
/// bought anything, encoded only when it is not.
public struct PurchaseLog: Codable, Equatable, Sendable {
    /// Sorted by `transactionID`, so identical states encode identically.
    public var grants: [PurchaseGrant] = []
    /// The day the receiver's call was taken; one per company.
    public var secondChanceDay: Int? = nil

    public init(grants: [PurchaseGrant] = [], secondChanceDay: Int? = nil) {
        self.grants = grants
        self.secondChanceDay = secondChanceDay
    }

    public static let empty = PurchaseLog()
    public var isEmpty: Bool { grants.isEmpty && secondChanceDay == nil }
    /// Cash, the veteran and the second chance all unrank; nothing else lives here.
    public var affectsRanking: Bool { !isEmpty }
    public func contains(_ id: UInt64) -> Bool { grants.contains { $0.transactionID == id } }
}

/// The one rule the UI and the reducer share, so a button is never shown
/// for a purchase the reducer would refuse.
///
/// SCAFFOLD STUB: every purchase is refused until P1 lands. P2 and P3
/// compile against these signatures and must not change them.
public enum PurchaseRule {
    public static func allows(_ kind: PurchaseKind, state: GameState) -> Bool {
        refusal(kind, state: state) == nil
    }

    /// Why not, in one line, or nil.
    public static func refusal(_ kind: PurchaseKind, state: GameState) -> String? {
        "The shop is not open yet."
    }

    /// What `.cash(weeks:)` would post right now.
    public static func cashAmount(weeks: Int, state: GameState, balance: BalanceConfig) -> Int {
        0
    }

    /// The veteran on offer this fortnight, or nil while the pool is empty.
    public static func veteranOnOffer(state: GameState, balance: BalanceConfig, content: ContentCatalog) -> Candidate? {
        nil
    }
}
