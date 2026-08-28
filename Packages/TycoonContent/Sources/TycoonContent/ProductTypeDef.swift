/// How a product earns: a one-off purchase per unit, or a recurring
/// subscription per customer per week.
public enum RevenueModel: String, Codable, Equatable, Sendable, CaseIterable {
    case oneTime, subscription
}

/// A kind of software product the studio can build (mobile app, game, ...).
///
/// Static content — game saves reference product types by their stable `id`.
public struct ProductTypeDef: Codable, Equatable, Sendable, Identifiable {
    /// Stable string id, e.g. "mobile_app".
    public var id: String
    /// Display name, e.g. "Mobile App".
    public var name: String
    /// SF Symbol name used for the type's icon.
    public var iconSystemName: String
    /// Required design points to complete a product of this type.
    public var designPts: Double
    /// Required code points.
    public var codePts: Double
    /// Required polish points.
    public var polishPts: Double
    /// Revenue per unit sold, in dollars.
    public var unitPrice: Double
    /// Baseline weekly peak units sold at quality 100.
    public var marketSize: Double
    /// Whether the type is available without research.
    public var unlockedFromStart: Bool
    /// One-line flavor text.
    public var blurb: String
    /// How the type earns: a one-off sale per unit, or a weekly
    /// subscription per customer. Defaults to `.oneTime`, the pre-revenue-
    /// model behavior.
    public var revenueModel: RevenueModel
    /// How demanding the type is, 1.0 = a mobile app. Raises what the press
    /// expects of a release. Defaults to 1.0.
    public var complexity: Double
    /// Servers, bandwidth and support desks the type costs per week while
    /// it is on the market. Defaults to 0 — success used to be free.
    public var hostingCostPerWeek: Double

    public init(
        id: String,
        name: String,
        iconSystemName: String,
        designPts: Double,
        codePts: Double,
        polishPts: Double,
        unitPrice: Double,
        marketSize: Double,
        unlockedFromStart: Bool,
        blurb: String,
        revenueModel: RevenueModel = .oneTime,
        complexity: Double = 1.0,
        hostingCostPerWeek: Double = 0
    ) {
        self.id = id
        self.name = name
        self.iconSystemName = iconSystemName
        self.designPts = designPts
        self.codePts = codePts
        self.polishPts = polishPts
        self.unitPrice = unitPrice
        self.marketSize = marketSize
        self.unlockedFromStart = unlockedFromStart
        self.blurb = blurb
        self.revenueModel = revenueModel
        self.complexity = complexity
        self.hostingCostPerWeek = hostingCostPerWeek
    }
}

// Hand-written decode so a catalog written before the revenue models
// existed still loads: every type reads as a one-off sale of mobile-app
// complexity that costs nothing to keep online.
extension ProductTypeDef {
    private enum CodingKeys: String, CodingKey {
        case id, name, iconSystemName, designPts, codePts, polishPts
        case unitPrice, marketSize, unlockedFromStart, blurb
        case revenueModel, complexity, hostingCostPerWeek
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try container.decode(String.self, forKey: .id),
            name: try container.decode(String.self, forKey: .name),
            iconSystemName: try container.decode(String.self, forKey: .iconSystemName),
            designPts: try container.decode(Double.self, forKey: .designPts),
            codePts: try container.decode(Double.self, forKey: .codePts),
            polishPts: try container.decode(Double.self, forKey: .polishPts),
            unitPrice: try container.decode(Double.self, forKey: .unitPrice),
            marketSize: try container.decode(Double.self, forKey: .marketSize),
            unlockedFromStart: try container.decode(Bool.self, forKey: .unlockedFromStart),
            blurb: try container.decode(String.self, forKey: .blurb),
            revenueModel: try container.decodeIfPresent(RevenueModel.self, forKey: .revenueModel)
                ?? .oneTime,
            complexity: try container.decodeIfPresent(Double.self, forKey: .complexity) ?? 1.0,
            hostingCostPerWeek: try container.decodeIfPresent(
                Double.self, forKey: .hostingCostPerWeek
            ) ?? 0
        )
    }
}
