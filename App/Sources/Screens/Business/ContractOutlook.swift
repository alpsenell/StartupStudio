import SwiftUI
import TycoonEngine

/// How a contract is going, in one phrase and a colour. The same grade the
/// contract card spells out in a sentence, shared with the desk so the
/// Business tab can say "on track" or "will be rejected" before the player
/// opens the section.
enum ContractOutlook {
    struct Grade {
        let label: String
        let tint: Color
    }

    static func grade(
        hasWork: Bool,
        projectedQuality: Int,
        balance: BalanceConfig
    ) -> Grade {
        let quality = balance.contractQuality
        if !hasWork {
            return Grade(label: "nobody on it", tint: Theme.warning)
        } else if projectedQuality >= quality.greatThreshold {
            return Grade(label: "on track", tint: Theme.positiveCash)
        } else if projectedQuality >= quality.okayThreshold {
            return Grade(label: "client will have notes", tint: Theme.warning)
        } else {
            return Grade(label: "will be rejected", tint: Theme.negativeCash)
        }
    }
}
