import Foundation

/// Thrown by `ContentCatalog.loadBundled()` when a resource is missing from the bundle.
public enum ContentLoadError: Error, Equatable, Sendable {
    case missingResource(String)
}

/// The full static content catalog: product types, topics, tech tree, events,
/// life events, name pools, and the workstream catalogs (traits, dialogue,
/// news, reviews, goals, investors) that ship empty in the scaffold.
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
    /// Employee personality traits (`Traits.json`, WS-F). Empty until WS-F
    /// writes them.
    public let traits: [TraitDef]
    /// Employee bios and spoken lines (`Dialogue.json`, WS-B). Empty until
    /// WS-B writes them.
    public let dialogue: DialogueCatalog
    /// Industry-news headline templates (`News.json`, WS-B). Empty until
    /// WS-B writes them.
    public let news: [NewsTemplate]
    /// Per-outlet review voices (`Reviews.json`, WS-B). `nil` only when the
    /// file is missing from the bundle entirely.
    public let reviews: ReviewCatalog?
    /// Chapter goals (`Goals.json`, WS-F). Empty until WS-F writes them.
    public let goals: [GoalDef]
    /// Investor personas (`Investors.json`, WS-F). Empty until WS-F writes
    /// them.
    public let investors: [InvestorDef]
    /// Staff moments (`StaffEvents.json`), one def per `StaffEventKind`.
    /// Empty falls back to the engine's balance numbers.
    public let staffEvents: [StaffEventDef]

    // MARK: Iteration 10 — M2 (pitch room)

    /// What the four people across the pitch table say (`Pitches.json`).
    /// `nil` without the file; the engine falls back to
    /// `PitchCatalog.fallback`, so the room still works.
    public let pitches: PitchCatalog?

    // MARK: end of Iteration 10 — M2

    private let productTypesByID: [String: ProductTypeDef]
    private let topicsByID: [String: TopicDef]
    private let techByID: [String: TechNode]
    private let lifeEventsByID: [String: LifeEventDef]
    private let eventsByID: [String: EventDef]
    private let staffEventsByID: [String: StaffEventDef]

    public init(
        productTypes: [ProductTypeDef],
        topics: [TopicDef],
        techTree: [TechNode],
        events: [EventDef],
        names: NamePools,
        lifeEvents: [LifeEventDef] = [],
        traits: [TraitDef] = [],
        dialogue: DialogueCatalog = .empty,
        news: [NewsTemplate] = [],
        reviews: ReviewCatalog? = nil,
        goals: [GoalDef] = [],
        investors: [InvestorDef] = [],
        staffEvents: [StaffEventDef] = [],
        // MARK: Iteration 10 — M2 (pitch room)
        pitches: PitchCatalog? = nil
        // MARK: end of Iteration 10 — M2
    ) {
        self.productTypes = productTypes
        self.topics = topics
        self.techTree = techTree
        self.events = events
        self.names = names
        self.lifeEvents = lifeEvents
        self.traits = traits
        self.dialogue = dialogue
        self.news = news
        self.reviews = reviews
        self.goals = goals
        self.investors = investors
        self.staffEvents = staffEvents
        // MARK: Iteration 10 — M2 (pitch room)
        self.pitches = pitches
        // MARK: end of Iteration 10 — M2
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
        self.eventsByID = Dictionary(
            events.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        self.staffEventsByID = Dictionary(
            staffEvents.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
    }

    /// Decodes the bundled content JSON files from `Bundle.module`.
    ///
    /// The six original files are required; the six workstream catalogs
    /// (traits, dialogue, news, reviews, goals, investors) are optional, so
    /// a build without them still loads — they simply read as empty.
    public static func loadBundled() throws -> ContentCatalog {
        let decoder = JSONDecoder()
        return ContentCatalog(
            productTypes: try decodeResource("ProductTypes", using: decoder),
            topics: try decodeResource("Topics", using: decoder),
            techTree: try decodeResource("TechTree", using: decoder),
            events: try decodeResource("Events", using: decoder),
            names: try decodeResource("Names", using: decoder),
            lifeEvents: try decodeResource("LifeEvents", using: decoder),
            traits: try decodeResourceIfPresent("Traits", using: decoder) ?? [],
            dialogue: try decodeResourceIfPresent("Dialogue", using: decoder) ?? .empty,
            news: try decodeResourceIfPresent("News", using: decoder) ?? [],
            reviews: try decodeResourceIfPresent("Reviews", using: decoder),
            goals: try decodeResourceIfPresent("Goals", using: decoder) ?? [],
            investors: try decodeResourceIfPresent("Investors", using: decoder) ?? [],
            staffEvents: try decodeResourceIfPresent("StaffEvents", using: decoder) ?? [],
            // MARK: Iteration 10 — M2 (pitch room)
            pitches: try decodeResourceIfPresent("Pitches", using: decoder)
            // MARK: end of Iteration 10 — M2
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

    /// O(1) lookup of a company event by id.
    public func event(_ id: String) -> EventDef? {
        eventsByID[id]
    }

    /// O(1) lookup of a staff-event definition by its kind raw value.
    public func staffEvent(_ id: String) -> StaffEventDef? {
        staffEventsByID[id]
    }

    // MARK: Iteration 10 — M2 (pitch room)

    /// The lines for one side of the pitch table, from `Pitches.json` when
    /// it is bundled and from the terse fallback when it is not — so a
    /// caller never has to handle "no catalog" itself.
    public func pitchCounterpart(_ id: String) -> PitchCounterpartDef? {
        pitches?.counterpart(id) ?? PitchCatalog.fallback.counterpart(id)
    }

    // MARK: end of Iteration 10 — M2

    private static func decodeResource<T: Decodable>(
        _ name: String,
        using decoder: JSONDecoder
    ) throws -> T {
        guard let url = Bundle.module.url(forResource: name, withExtension: "json") else {
            throw ContentLoadError.missingResource("\(name).json")
        }
        return try decoder.decode(T.self, from: Data(contentsOf: url))
    }

    /// Like `decodeResource`, but a file that isn't in the bundle reads as
    /// `nil` instead of throwing — the loader tolerates a workstream
    /// catalog that hasn't been written yet.
    private static func decodeResourceIfPresent<T: Decodable>(
        _ name: String,
        using decoder: JSONDecoder
    ) throws -> T? {
        guard let url = Bundle.module.url(forResource: name, withExtension: "json") else {
            return nil
        }
        return try decoder.decode(T.self, from: Data(contentsOf: url))
    }
}
