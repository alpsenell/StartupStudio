import SwiftUI
import TycoonEngine

/// How a contract is going, in one phrase and a colour. The same grade the
/// contract card spells out in a sentence, shared with the desk so the
/// Business tab can say "on track" or "will be rejected" before the player
/// opens the section.
///
/// A rival-sponsored job carries a topic, and the grade knows it: it then
/// also carries what the sponsor will ship, and at what quality, because
/// that number is the whole decision.
enum ContractOutlook {
    struct Grade {
        let label: String
        let tint: Color
        /// "they ship Fitness at ~68" — only on a sponsored job somebody
        /// is actually working; the desk shows it in place of the label.
        var promise: String? = nil
    }

    static func grade(
        hasWork: Bool,
        projectedQuality: Int,
        balance: BalanceConfig,
        sponsoredTopic: String? = nil
    ) -> Grade {
        let quality = balance.contractQuality
        let base: Grade = if !hasWork {
            Grade(label: "nobody on it", tint: Theme.warning)
        } else if projectedQuality >= quality.greatThreshold {
            Grade(label: "on track", tint: Theme.positiveCash)
        } else if projectedQuality >= quality.okayThreshold {
            Grade(label: "client will have notes", tint: Theme.warning)
        } else {
            Grade(label: "will be rejected", tint: Theme.negativeCash)
        }
        guard let sponsoredTopic, hasWork else { return base }
        let promised = promisedQuality(projectedQuality: projectedQuality, balance: balance)
        return Grade(
            label: base.label,
            tint: base.tint,
            promise: "they ship \(sponsoredTopic) at ~\(promised)"
        )
    }

    /// The quality the sponsor's product would ship at if the job were
    /// delivered with the crew so far — the engine's own arithmetic.
    static func promisedQuality(projectedQuality: Int, balance: BalanceConfig) -> Int {
        Int(balance.sponsoredContracts.productQuality(forProjected: projectedQuality).rounded())
    }

    /// The sponsored offer's own sentence: what the rival does with the
    /// work, and where the player stands in that category today.
    /// `standing` is the player's standing in the topic, 0 for none.
    static func sponsorLine(
        client: String,
        topic: String,
        standing: Double,
        sponsorPresent: Bool
    ) -> String {
        guard sponsorPresent else {
            return "\(client) has since shut down — this is just a job now."
        }
        let held = standing > 0
            ? "You hold \(topic) at \(Int(standing.rounded()))."
            : "You hold nothing in \(topic) yet."
        return "On delivery \(client) ships a \(topic) product at the quality you build. \(held)"
    }

    /// The active sponsored job's sentence: what they will ship, at what
    /// quality, given the crew so far.
    static func sponsorProgressLine(
        client: String,
        topic: String,
        hasWork: Bool,
        projectedQuality: Int,
        balance: BalanceConfig,
        sponsorPresent: Bool
    ) -> String {
        guard sponsorPresent else {
            return "\(client) has since shut down — this is just a job now."
        }
        guard hasWork else {
            return "On delivery \(client) ships a \(topic) product at the quality you build."
        }
        let promised = promisedQuality(projectedQuality: projectedQuality, balance: balance)
        return "On delivery \(client) ships \(topic) at about \(promised) — a little under what you hand over."
    }
}
