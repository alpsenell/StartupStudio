import Foundation

/// A marketing campaign on an in-development product. One-shot kinds
/// (press release, launch event) charge, apply their hype immediately, and
/// stay in `GameState.campaigns` as history with `endDay == start day`;
/// social pushes bill and add hype daily until `MarketingSystem` removes
/// them at `endDay` or when the product ships.
public struct MarketingCampaign: Codable, Equatable, Sendable, Identifiable {
    public let id: UUID
    /// "social_push" | "press_release" | "launch_event".
    public var kindID: String
    public var productID: UUID
    /// Absolute day the campaign stops (one-shots: endDay == start day).
    public var endDay: Int
    /// Whether this was bought for a product that had already shipped.
    ///
    /// A push bought to build launch hype ends *at* the launch: its job is
    /// done and the player should not keep being billed for it against a
    /// product that is already out. One bought deliberately on a release
    /// is a different purchase and keeps running. Without the distinction
    /// the two are indistinguishable once the product ships.
    public var startedOnRelease: Bool

    public init(
        id: UUID,
        kindID: String,
        productID: UUID,
        endDay: Int,
        startedOnRelease: Bool = false
    ) {
        self.id = id
        self.kindID = kindID
        self.productID = productID
        self.endDay = endDay
        self.startedOnRelease = startedOnRelease
    }
}

// Hand-written decode so campaigns saved before the flag existed load as
// launch campaigns, which is what every one of them was.
extension MarketingCampaign {
    private enum CodingKeys: String, CodingKey {
        case id, kindID, productID, endDay, startedOnRelease
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try container.decode(UUID.self, forKey: .id),
            kindID: try container.decode(String.self, forKey: .kindID),
            productID: try container.decode(UUID.self, forKey: .productID),
            endDay: try container.decode(Int.self, forKey: .endDay),
            startedOnRelease: try container.decodeIfPresent(
                Bool.self, forKey: .startedOnRelease
            ) ?? false
        )
    }
}

/// The three campaign kinds. Raw values are the stable `kindID` strings
/// stored in state and passed by `GameAction.startCampaign`.
enum CampaignKind: String, CaseIterable, Sendable {
    case socialPush = "social_push"
    case pressRelease = "press_release"
    case launchEvent = "launch_event"

    /// Label used for the kind's marketing ledger postings.
    var ledgerLabel: String {
        switch self {
        case .socialPush: "Social push"
        case .pressRelease: "Press release"
        case .launchEvent: "Launch event"
        }
    }
}
