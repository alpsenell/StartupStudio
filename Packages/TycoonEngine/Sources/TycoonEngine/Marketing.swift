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

    public init(id: UUID, kindID: String, productID: UUID, endDay: Int) {
        self.id = id
        self.kindID = kindID
        self.productID = productID
        self.endDay = endDay
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
