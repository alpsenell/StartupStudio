/// One feature card on a product's board (`Features.json`, iteration 10 /
/// M1).
///
/// A card is content, not state: a product stores the ids it has placed
/// and the engine's `FeatureBoard` reads the definitions back out of the
/// catalog. Everything here is descriptive — what the card is called, what
/// it belongs on, what unlocks it, what it pairs with — and the arithmetic
/// that turns a placed board into a quality multiplier lives in the engine
/// so the balance can move without a content edit.
///
/// Both `fitsTypes` and `fitsTopics` are *empty means every one*: a card
/// with neither list is a generic one that sits neutrally on any board.
public struct FeatureCardDef: Codable, Equatable, Sendable, Identifiable {
    /// Which of the three build pools the card is mostly work in. Used to
    /// order the hand by the crew's strengths, and to say in words what
    /// kind of work the card is.
    public enum Lean: String, Codable, Equatable, Sendable, CaseIterable {
        case design, code, polish

        public var displayName: String {
            switch self {
            case .design: "Design"
            case .code: "Code"
            case .polish: "Polish"
            }
        }
    }

    /// Stable id, referenced by `Product.features` and by other cards'
    /// `synergies`.
    public var id: String
    /// The card's face, and the word a review quotes.
    public var name: String
    /// One line of what it is, for the card's back and the storefront.
    public var blurb: String
    /// `ProductTypeDef.id`s this card belongs on. Empty = every type.
    public var fitsTypes: [String]
    /// `TopicDef.id`s this card belongs on. Empty = every topic.
    public var fitsTopics: [String]
    /// A `TechNode.id` that has to be researched before the card is in the
    /// hand. `nil` = available from day one.
    public var unlockedBy: String?
    /// The pool the work mostly lands in.
    public var leansOn: Lean
    /// Other card ids this one is better next to. Read symmetrically by
    /// the engine, so a pair only has to be written once.
    public var synergies: [String]
    /// The market-appetite tag this card rides. When the quarter wants
    /// that tag, the card is worth more; `nil` rides nothing.
    public var appetiteTag: String?

    public init(
        id: String,
        name: String,
        blurb: String,
        fitsTypes: [String] = [],
        fitsTopics: [String] = [],
        unlockedBy: String? = nil,
        leansOn: Lean = .design,
        synergies: [String] = [],
        appetiteTag: String? = nil
    ) {
        self.id = id
        self.name = name
        self.blurb = blurb
        self.fitsTypes = fitsTypes
        self.fitsTopics = fitsTopics
        self.unlockedBy = unlockedBy
        self.leansOn = leansOn
        self.synergies = synergies
        self.appetiteTag = appetiteTag
    }

    // Hand-written decode so every field but `id` and `name` is optional
    // in the JSON — a card that fits everything and pairs with nothing is
    // two keys long.
    private enum CodingKeys: String, CodingKey {
        case id, name, blurb, fitsTypes, fitsTopics, unlockedBy, leansOn, synergies, appetiteTag
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try container.decode(String.self, forKey: .id),
            name: try container.decode(String.self, forKey: .name),
            blurb: try container.decodeIfPresent(String.self, forKey: .blurb) ?? "",
            fitsTypes: try container.decodeIfPresent([String].self, forKey: .fitsTypes) ?? [],
            fitsTopics: try container.decodeIfPresent([String].self, forKey: .fitsTopics) ?? [],
            unlockedBy: try container.decodeIfPresent(String.self, forKey: .unlockedBy),
            leansOn: try container.decodeIfPresent(Lean.self, forKey: .leansOn) ?? .design,
            synergies: try container.decodeIfPresent([String].self, forKey: .synergies) ?? [],
            appetiteTag: try container.decodeIfPresent(String.self, forKey: .appetiteTag)
        )
    }

    /// Whether this card belongs on a product of `typeID`. An empty list
    /// means "any".
    public func fits(typeID: String) -> Bool {
        fitsTypes.isEmpty || fitsTypes.contains(typeID)
    }

    /// Whether this card belongs on a product about `topicID`.
    public func fits(topicID: String) -> Bool {
        fitsTopics.isEmpty || fitsTopics.contains(topicID)
    }
}
