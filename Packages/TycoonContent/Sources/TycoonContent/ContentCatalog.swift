import Foundation

/// Thrown by `ContentCatalog.loadBundled()` when a resource is missing from the bundle.
public enum ContentLoadError: Error, Equatable, Sendable {
    case missingResource(String)
}

/// The full static content catalog: product types, topics, tech tree, events,
/// life events, and name pools.
///
/// Content, not state — game saves reference entries by stable string id and the
/// simulation engine consumes this catalog read-only.
public struct ContentCatalog: Sendable {
    /// All product types, in stable JSON order.
    public let productTypes: [ProductTypeDef]
    /// All topics, in stable JSON order.
    public let topics: [TopicDef]
    /// All tech tree nodes, in stable JSON order (grouped tier 1 -> 5).
    public let techTree: [TechNode]
    /// All random events, in stable JSON order.
    public let events: [EventDef]
    /// Name pools for employees, contract clients, and the founder's family.
    public let names: NamePools
    /// All founder life events, in stable JSON order.
    public let lifeEvents: [LifeEventDef]

    private let productTypesByID: [String: ProductTypeDef]
    private let topicsByID: [String: TopicDef]
    private let techByID: [String: TechNode]
    private let lifeEventsByID: [String: LifeEventDef]

    public init(
        productTypes: [ProductTypeDef],
        topics: [TopicDef],
        techTree: [TechNode],
        events: [EventDef],
        names: NamePools,
        lifeEvents: [LifeEventDef] = []
    ) {
        self.productTypes = productTypes
        self.topics = topics
        self.techTree = techTree
        self.events = events
        self.names = names
        self.lifeEvents = lifeEvents
        self.productTypesByID = Dictionary(
            productTypes.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        self.topicsByID = Dictionary(
            topics.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        self.techByID = Dictionary(
            techTree.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        self.lifeEventsByID = Dictionary(
            lifeEvents.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
    }

    /// Decodes the six content JSON files from `Bundle.module`.
    public static func loadBundled() throws -> ContentCatalog {
        let decoder = JSONDecoder()
        return ContentCatalog(
            productTypes: try decodeResource("ProductTypes", using: decoder),
            topics: try decodeResource("Topics", using: decoder),
            techTree: try decodeResource("TechTree", using: decoder),
            events: try decodeResource("Events", using: decoder),
            names: try decodeResource("Names", using: decoder),
            lifeEvents: try decodeResource("LifeEvents", using: decoder)
        )
    }

    /// O(1) lookup of a product type by id.
    public func productType(_ id: String) -> ProductTypeDef? {
        productTypesByID[id]
    }

    /// O(1) lookup of a topic by id.
    public func topic(_ id: String) -> TopicDef? {
        topicsByID[id]
    }

    /// O(1) lookup of a tech node by id.
    public func tech(_ id: String) -> TechNode? {
        techByID[id]
    }

    /// O(1) lookup of a life event by id.
    public func lifeEvent(_ id: String) -> LifeEventDef? {
        lifeEventsByID[id]
    }

    private static func decodeResource<T: Decodable>(
        _ name: String,
        using decoder: JSONDecoder
    ) throws -> T {
        guard let url = Bundle.module.url(forResource: name, withExtension: "json") else {
            throw ContentLoadError.missingResource("\(name).json")
        }
        return try decoder.decode(T.self, from: Data(contentsOf: url))
    }
}
