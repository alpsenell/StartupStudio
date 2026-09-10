import SwiftUI
import TycoonEngine

// MARK: - Iteration 13 — P3 (purchases: surfaces and copy)

/// The feed and journal line for `.purchaseApplied` — the one place the
/// story mentions the shop, after the fact, in the same flat voice as a
/// loan drawdown. `.info`: it never stops the clock.
enum ShopEventCopy {
    static func line(kind: PurchaseKind, amount: Int, day: Int) -> (icon: String, message: String, day: Int, tint: Color) {
        switch kind {
        case .cash(let weeks):
            let message: String = switch weeks {
            case 4: String(localized: "A month of runway came in from outside the story: \(ShopSurfaceCopy.grant(amount)).", comment: "Journal line after buying a month of cash. The argument is a dollar figure with a plus sign")
            case 13: String(localized: "A quarter of runway came in from outside the story: \(ShopSurfaceCopy.grant(amount)).", comment: "Journal line after buying a quarter of cash. The argument is a dollar figure with a plus sign")
            default: String(localized: "\(weeks) weeks of runway came in from outside the story: \(ShopSurfaceCopy.grant(amount)).", comment: "Journal line after buying cash. Arguments are a number of weeks and a dollar figure with a plus sign")
            }
            return ("banknote", message, day, Theme.positiveCash)
        case .secondChance:
            return (
                "arrow.uturn.backward",
                String(localized: "Back from the receiver: \(ShopSurfaceCopy.grant(amount)). The loan is still yours.", comment: "Journal line after the receiver's call reversed a bankruptcy. The argument is a dollar figure with a plus sign"),
                day,
                Theme.warning
            )
        case .veteran:
            return (
                "person.badge.plus",
                String(localized: "A veteran joined the hiring pool from outside the story.", comment: "Journal line after buying the veteran candidate"),
                day,
                Theme.accent
            )
        }
    }
}
