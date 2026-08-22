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
        blurb: String
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
    }
}
