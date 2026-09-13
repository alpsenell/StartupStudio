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

enum PressSystem {
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
