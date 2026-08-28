/// One industry-news headline template, loaded from `News.json`.
///
/// The template is a sentence with `{placeholder}` slots the narrative
/// system fills from the live world:
///
/// - `{rival}` — a rival studio's name (or a stealth-mode stand-in)
/// - `{product}` — two words from `names.productWords`
/// - `{topic}` — a topic name, lower-cased
/// - `{adjective}` — a critic's verdict
/// - `{number}` — a plausible small number (a percentage, a headcount)
///
/// News is cosmetic: it never changes state, never pauses the timeline, and
/// draws only from the world RNG stream.
///
/// JSON:
///
///     { "id": "rival_ships",
///       "template": "{rival} ships {product} — critics call it {adjective}.",
///       "weight": 4, "needsRival": true, "category": "rivals" }
public struct NewsTemplate: Codable, Equatable, Sendable, Identifiable {
    /// What corner of the industry the headline is about — the journal's
    /// filter bucket.
    public enum Category: String, Codable, Equatable, Sendable, CaseIterable {
        case rivals, funding, market, culture, hiring
    }

    public var id: String
    /// e.g. `"{rival} ships {product} — critics call it {adjective}"`.
    public var template: String
    /// Relative pick probability, >= 1.
    public var weight: Int
    /// Skipped while no rival studios exist, so the world never reports on
    /// competitors the player doesn't have.
    public var needsRival: Bool
    public var category: Category

    public init(
        id: String,
        template: String,
        weight: Int = 1,
        needsRival: Bool = false,
        category: Category = .culture
    ) {
        self.id = id
        self.template = template
        self.weight = weight
        self.needsRival = needsRival
        self.category = category
    }

    private enum CodingKeys: String, CodingKey {
        case id, template, weight, needsRival, category
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try container.decode(String.self, forKey: .id),
            template: try container.decode(String.self, forKey: .template),
            weight: try container.decodeIfPresent(Int.self, forKey: .weight) ?? 1,
            needsRival: try container.decodeIfPresent(Bool.self, forKey: .needsRival) ?? false,
            category: try container.decodeIfPresent(Category.self, forKey: .category) ?? .culture
        )
    }
}
