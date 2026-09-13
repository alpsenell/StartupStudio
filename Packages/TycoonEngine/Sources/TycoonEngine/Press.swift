import Foundation
import TycoonContent

// Iteration 17 — T7 (press and stakes): the exclusive.
//
// The ship confirmation can give one of the four review outlets the
// exclusive (`.grantExclusive`, sent right after the ship action — so it
// composes with every way a build ships). That outlet's verdict leads the
// launch-day reveal and the paper; its standing with the studio rises and
// the other three fall. Every outlet's standing moves its score on later
// launches (`ProductSystem.ship`'s review loop reads
// `Company.pressScoreOffset`), and drifts back toward 0 with each launch.
//
// Identity: no bot sends `.grantExclusive`, so `pressStanding` stays empty,
// the offset is exactly 0.0 and the drift returns on its first line. The
// loop's draws are the same in count and order either way.

extension Company {
    /// Points added to `outlet`'s review score on a launch: its standing
    /// over `press.standingDivisor`. Exactly 0 for an outlet with no entry,
    /// which is every outlet in every run that never gave an exclusive.
    public func pressScoreOffset(for outlet: String, balance: BalanceConfig) -> Double {
        guard let standing = pressStanding[outlet], standing != 0 else { return 0 }
        return standing / max(1, balance.press.standingDivisor)
    }

    /// The outlet's standing, 0 when it has none.
    public func pressStanding(of outlet: String) -> Double {
        pressStanding[outlet] ?? 0
    }
}

/// An outlet's standing, in the words the byline prints.
public enum PressStandingBand: String, Sendable, CaseIterable {
    case warm, friendly, even, cool, cold

    public static func of(_ standing: Double) -> PressStandingBand {
        switch standing {
        case 10...: .warm
        case 3..<10: .friendly
        case -3..<3: .even
        case -10 ..< -3: .cool
        default: .cold
        }
    }
}

/// One outlet's standing as the save writes it: an outlet-sorted array,
/// because dictionary order is not stable and the determinism tests
/// compare bytes (`Company.encode`).
struct PressStandingEntry: Codable, Equatable {
    var outlet: String
    var standing: Double

    static func sorted(_ map: [String: Double]) -> [PressStandingEntry] {
        map.keys.sorted().map { PressStandingEntry(outlet: $0, standing: map[$0] ?? 0) }
    }
}

extension GameState {
    /// Why `outlet` cannot have `productID`'s exclusive today, or `nil`
    /// when it can: only on launch day, once, to one of the outlets that
    /// reviewed it.
    public func pressExclusiveRefusal(productID: UUID, outlet: String, balance: BalanceConfig) -> String? {
        guard let product = product(id: productID), case .released(let info) = product.stage else {
            return "It has not shipped."
        }
        if let already = info.exclusiveOutlet { return "\(already) already had it first." }
        if info.launchDay != day { return "The reviews are already out." }
        if !balance.reviewOutlets.contains(outlet) || !info.reviews.contains(where: { $0.outlet == outlet }) {
            return "\(outlet) did not review it."
        }
        return nil
    }
}

extension ReleaseInfo {
    /// Whether the other outlets' verdicts are still held back on `day`.
    /// False for every release nobody gave an exclusive.
    public func isEmbargoed(on day: Int) -> Bool {
        embargoUntilDay.map { day < $0 } ?? false
    }

    /// The reviews that are out on `day`: only the exclusive's during its
    /// embargo, all of them otherwise. `nil` reads as "after everything".
    public func visibleReviews(on day: Int?) -> [Review] {
        guard let day, isEmbargoed(on: day), let exclusive = exclusiveOutlet else { return reviews }
        return reviews.filter { $0.outlet == exclusive }
    }

    /// The mean of the reviews that are out on `day`.
    public func visibleAverageScore(on day: Int?) -> Int {
        let visible = visibleReviews(on: day)
        guard !visible.isEmpty else { return 0 }
        return Int((Double(visible.reduce(0) { $0 + $1.score }) / Double(visible.count)).rounded())
    }

    /// The outlets whose verdicts are held back on `day`.
    public func embargoedOutlets(on day: Int) -> [String] {
        guard isEmbargoed(on: day), let exclusive = exclusiveOutlet else { return [] }
        return reviews.map(\.outlet).filter { $0 != exclusive }
    }

    /// The score the week's review-driven demand reads (`postWeeklySales`):
    /// with an exclusive, its outlet's score alone for launch week — the
    /// first week posted, or any week while the others are embargoed — and
    /// the four-outlet average from then on. Exactly `averageReviewScore`
    /// on every release without an exclusive.
    public func demandReviewScore(on day: Int) -> Int {
        guard let exclusive = exclusiveOutlet, embargoUntilDay != nil,
              weeklySales.isEmpty || isEmbargoed(on: day),
              let review = reviews.first(where: { $0.outlet == exclusive })
        else { return averageReviewScore }
        return review.score
    }
}

enum PressSystem {
    /// The embargo lifting: on the day it ends, the other outlets publish.
    /// Finds nothing on a run that never gave an exclusive; draws nothing.
    @Sendable
    static func run(
        _ state: inout GameState,
        _ balance: BalanceConfig,
        _ content: ContentCatalog
    ) -> [GameEvent] {
        var events: [GameEvent] = []
        for product in state.products {
            guard case .released(let info) = product.stage, info.embargoUntilDay == state.day else { continue }
            events.append(.pressEmbargoLifted(productID: product.id, averageScore: info.averageReviewScore, day: state.day))
        }
        return events
    }

    /// Every standing moves `driftPerLaunch` toward 0; one that reaches it
    /// leaves the map. Called once per launch, after the review loop.
    /// Returns on its first line while the map is empty.
    static func driftAfterLaunch(_ state: inout GameState, _ balance: BalanceConfig) {
        guard !state.company.pressStanding.isEmpty else { return }
        let drift = max(0, balance.press.driftPerLaunch)
        for outlet in state.company.pressStanding.keys.sorted() {
            let standing = state.company.pressStanding[outlet] ?? 0
            let moved = standing > 0 ? max(0, standing - drift) : min(0, standing + drift)
            state.company.pressStanding[outlet] = moved == 0 ? nil : moved
        }
    }

    /// Gives `outlet` the exclusive on a product that shipped today: the
    /// release remembers it, the outlet warms by `exclusiveGain`, every
    /// other outlet cools by `snub`. Ignored when refused.
    static func grantExclusive(
        productID: UUID,
        outlet: String,
        state: inout GameState,
        balance: BalanceConfig
    ) -> [GameEvent] {
        guard state.pressExclusiveRefusal(productID: productID, outlet: outlet, balance: balance) == nil,
              let index = state.products.firstIndex(where: { $0.id == productID }),
              case .released(var info) = state.products[index].stage
        else { return [] }
        info.exclusiveOutlet = outlet
        // The other verdicts wait: launch week reads this outlet alone.
        info.embargoUntilDay = state.day + max(1, balance.press.embargoDays)
        state.products[index].stage = .released(info)

        let press = balance.press
        for name in balance.reviewOutlets {
            let standing = state.company.pressStanding(of: name)
            let moved = name == outlet
                ? min(press.cap, standing + press.exclusiveGain)
                : max(-press.cap, standing - press.snub)
            state.company.pressStanding[name] = moved == 0 ? nil : moved
        }
        return [.pressExclusive(productID: productID, outlet: outlet, day: state.day)]
    }
}
