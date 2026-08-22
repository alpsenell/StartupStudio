/// A market topic a product can target (fitness, finance, ...).
///
/// Static content — game saves reference topics by their stable `id`.
public struct TopicDef: Codable, Equatable, Sendable, Identifiable {
    /// Stable string id, e.g. "fitness".
    public var id: String
    /// Display name.
    public var name: String
    /// SF Symbol name used for the topic's icon.
    public var iconSystemName: String
    /// Fit multiplier per product type id: 0.8 (poor) | 1.0 (ok) | 1.15 (great).
    /// A missing key means 1.0; only non-1.0 fits are listed in the JSON.
    public var fitByType: [String: Double]

    public init(
        id: String,
        name: String,
        iconSystemName: String,
        fitByType: [String: Double]
    ) {
        self.id = id
        self.name = name
        self.iconSystemName = iconSystemName
        self.fitByType = fitByType
    }
}
