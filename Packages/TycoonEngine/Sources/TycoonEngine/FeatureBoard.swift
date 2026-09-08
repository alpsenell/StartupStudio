import Foundation
import TycoonContent

// Iteration 10 — M1. The board a product is built from: feature cards
// placed in the type's slots, synergies between them, and what the market
// has an appetite for this quarter. `Product.features` holds the placed
// card ids (decode-if-present, encoded only when non-empty), so a save
// from before boards existed loads as a product nobody put a card on —
// which is exactly what it was.
//
// **Identity at the default.** `qualityMultiplier` is built from the sum
// of the placed cards' values divided by the slot count. An empty board
// sums to zero, so the multiplier is `1 + swing * 0` — exactly 1.0, by
// construction, whatever the balance says. The pacing bots never place a
// card and get the game that shipped.
//
// Nothing here draws from any RNG stream. The quarter's appetite is a pure
// function of the seed, the calendar and the live market.

/// One feature card as content. M1 defines the catalog in
/// `Features.json`; the type lives in TycoonContent because the catalog
/// does. This alias is the name the rest of the engine and the app use.
public typealias FeatureCard = FeatureCardDef

/// How well one placed card sits on the board it is on, and why.
///
/// Everything the board screen says in words comes from here, so the sheet
/// and the ship arithmetic can never disagree.
public struct FeatureCardReading: Equatable, Sendable, Identifiable {
    public var id: String { cardID }
    /// The placed card.
    public var cardID: String
    /// Its name, for the review token and the card face.
    public var name: String
    /// Which slot it sits in.
    public var slot: Int
    /// Whether the card belongs on this product type.
    public var fitsType: Bool
    /// Whether the card belongs on this topic.
    public var fitsTopic: Bool
    /// The other placed cards this one pairs with, by id.
    public var synergyPartners: [String]
    /// Whether the card's `appetiteTag` is one the quarter wants.
    public var ridesAppetite: Bool
    /// This card's contribution to the board total. Negative for a card
    /// that belongs on neither the type nor the topic.
    public var value: Double

    /// What the card is doing here, in the player's words.
    public var verdict: String {
        if !fitsType, !fitsTopic { return "Belongs on neither this type nor this topic." }
        var parts: [String] = []
        if fitsType, fitsTopic {
            parts.append("A natural fit here")
        } else if fitsType {
            parts.append("Fits the type, not the topic")
        } else {
            parts.append("Fits the topic, not the type")
        }
        if !synergyPartners.isEmpty {
            parts.append("pairs with \(synergyPartners.count)")
        }
        if ridesAppetite { parts.append("and the market wants it") }
        return parts.joined(separator: ", ") + "."
    }
}

/// A whole board, read.
public struct FeatureBoardReading: Equatable, Sendable {
    /// How many slots this product type gives the board.
    public var slots: Int
    /// The cards actually placed, in slot order.
    public var cards: [FeatureCardReading]
    /// The tags the market has an appetite for this quarter.
    public var appetite: [String]
    /// Whether the board can still be changed (design is still open).
    public var isOpen: Bool
    /// Why it cannot, when it cannot.
    public var closedReason: String?
    /// The 0…1 rating shown on the board, from fit, synergy, appetite and
    /// how much of the board is filled. Display only — `qualityMultiplier`
    /// is derived from the raw total, not from this, so the identity at an
    /// empty board is exact rather than nearly exact.
    public var score: Double
    /// What the board multiplies quality by at ship. Exactly 1.0 for an
    /// empty board.
    public var qualityMultiplier: Double

    public var filled: Int { cards.count }

    /// The strongest card on the board, for a review to praise.
    public var bestCard: FeatureCardReading? {
        cards.max { lhs, rhs in
            if lhs.value != rhs.value { return lhs.value < rhs.value }
            return lhs.cardID > rhs.cardID
        }
    }

    /// The weakest card on the board, for a review to complain about —
    /// `nil` unless something on it is actually a mistake.
    public var worstCard: FeatureCardReading? {
        guard let candidate = cards.min(by: { lhs, rhs in
            if lhs.value != rhs.value { return lhs.value < rhs.value }
            return lhs.cardID < rhs.cardID
        }), candidate.value < 0 else { return nil }
        return candidate
    }

    /// The board in one line, for the ship sheet and the forecast.
    public var summary: String {
        guard filled > 0 else { return "No features placed — the board is empty." }
        let pairs = cards.reduce(0) { $0 + $1.synergyPartners.count } / 2
        var line = "\(filled) of \(slots) slots"
        if pairs > 0 { line += ", \(pairs) synerg\(pairs == 1 ? "y" : "ies")" }
        let riding = cards.count(where: { $0.ridesAppetite })
        if riding > 0 { line += ", \(riding) riding the market" }
        return line + "."
    }
}

/// Why a `.placeFeature` or `.removeFeature` was refused. The app turns
/// this into the sentence on the button.
public enum FeatureBoardRefusal: String, Equatable, Sendable {
    case noSuchProduct
    case notInDevelopment
    case designClosed
    case noSuchCard
    case cardLocked
    case cardAlreadyPlaced
    case boardFull
    case emptySlot

    /// The refusal in the player's words.
    public var reason: String {
        switch self {
        case .noSuchProduct: "That product is not in the save."
        case .notInDevelopment: "It has shipped — the board is history now."
        case .designClosed: "Design is finished. The board is locked."
        case .noSuchCard: "That feature is not in the catalog."
        case .cardLocked: "Research it first — nobody here knows how to build it."
        case .cardAlreadyPlaced: "It is already on the board."
        case .boardFull: "Every slot is taken. Take one off first."
        case .emptySlot: "There is nothing in that slot."
        }
    }
}

/// The board: the hand, the slots, the arithmetic and the appetite.
public enum FeatureBoard {

    // MARK: - Slots

    /// How many cards a product of this type takes: four for the small
    /// ones, six for the big ones, from the type's own complexity. Clamped
    /// to the balance's `slotsMin...slotsMax` so a content edit can never
    /// hand out a board of nine.
    public static func slots(for type: ProductTypeDef, balance: BalanceConfig) -> Int {
        let config = balance.featureBoard
        let step = max(0.01, config.slotsComplexityStep)
        let extra = Int(((type.complexity - 1) / step).rounded(.down))
        return min(config.slotsMax, max(config.slotsMin, config.slotsMin + max(0, extra)))
    }

    // MARK: - The market's appetite

    /// The tags every card may ride. Fixed vocabulary: a card's
    /// `appetiteTag` outside this list simply never comes up.
    public static let appetiteTags = [
        "ai", "privacy", "social", "wellness", "money",
        "play", "speed", "design", "green", "offline",
    ]

    /// The tag a booming topic pushes into the quarter's appetite — a
    /// fitness boom is the quarter everybody wants wellness features.
    static let tagByTopic: [String: String] = [
        "fitness": "wellness", "finance": "money", "social": "social",
        "travel": "offline", "food_delivery": "speed", "education": "ai",
        "music": "play", "gaming": "play", "productivity": "speed",
        "health": "privacy", "dating": "social", "logistics": "green",
    ]

    /// What the market wants this quarter: two tags derived from the run's
    /// seed and the quarter number, plus the tag of any topic currently
    /// booming.
    ///
    /// A pure read — no draws, so it costs the simulation nothing and two
    /// players on the same seed see the same quarter.
    public static func appetite(state: GameState, balance: BalanceConfig) -> [String] {
        let config = balance.featureBoard
        let quarter = state.day / max(1, config.appetiteQuarterDays)
        var tags: [String] = []
        var hash = mix(state.seed &+ UInt64(bitPattern: Int64(quarter)) &* 0x9E37_79B9_7F4A_7C15)
        for _ in 0..<max(0, config.appetiteTagCount) {
            hash = mix(hash)
            let tag = appetiteTags[Int(hash % UInt64(appetiteTags.count))]
            if !tags.contains(tag) { tags.append(tag) }
        }
        // The hottest topics first, and only as many as the quarter has
        // room for: a market where everything is booming wants nothing in
        // particular, and a screen listing eight tags says nothing.
        let booming = state.market.topics
            .filter { $0.value.multiplier >= config.boomAppetiteThreshold }
            .sorted { lhs, rhs in
                if lhs.value.multiplier != rhs.value.multiplier {
                    return lhs.value.multiplier > rhs.value.multiplier
                }
                return lhs.key < rhs.key
            }
        for (topicID, _) in booming where tags.count < max(1, config.appetiteMaxTags) {
            if let tag = tagByTopic[topicID], !tags.contains(tag) { tags.append(tag) }
        }
        return tags
    }

    /// SplitMix64's finalizer. Deterministic, stateless, and not part of
    /// any RNG stream the simulation replays.
    private static func mix(_ value: UInt64) -> UInt64 {
        var z = value &+ 0x9E37_79B9_7F4A_7C15
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    // MARK: - The hand

    /// The cards this crew could put on this product today, best first.
    ///
    /// Three things shape it, exactly as the room would: the **tech tree**
    /// (a card behind an unresearched node is not in the hand at all), the
    /// **product** (a card that belongs on neither the type nor the topic
    /// is not offered), and the **team** (the hand is capped at
    /// `handSize`, and the ordering puts the pools this crew is strong in
    /// first — a studio of designers is shown a designer's hand).
    ///
    /// Cards already on the board are still returned; the screen greys
    /// them, and `place` refuses them.
    public static func hand(
        for product: Product,
        state: GameState,
        content: ContentCatalog,
        balance: BalanceConfig
    ) -> [FeatureCard] {
        let appetite = Set(appetite(state: state, balance: balance))
        let strength = poolStrength(state: state, balance: balance)
        let candidates = content.features.filter { card in
            guard isUnlocked(card, state: state) else { return false }
            return card.fits(typeID: product.typeID) || card.fits(topicID: product.topicID)
        }
        let ranked = candidates
            .map { card -> (card: FeatureCard, rank: Double) in
                var rank = 0.0
                if card.fits(typeID: product.typeID) { rank += 1 }
                if card.fits(topicID: product.topicID) { rank += 1 }
                // A card written *for* this topic beats a generic one.
                if !card.fitsTopics.isEmpty, card.fits(topicID: product.topicID) { rank += 0.75 }
                if let tag = card.appetiteTag, appetite.contains(tag) { rank += 0.9 }
                rank += (strength[card.leansOn] ?? 0) / 100
                return (card, rank)
            }
            .sorted { lhs, rhs in
                if lhs.rank != rhs.rank { return lhs.rank > rhs.rank }
                return lhs.card.id < rhs.card.id
            }
        return ranked.prefix(max(1, balance.featureBoard.handSize)).map(\.card)
    }

    /// Whether the tech behind a card has been researched (or there is
    /// none).
    public static func isUnlocked(_ card: FeatureCard, state: GameState) -> Bool {
        guard let node = card.unlockedBy else { return true }
        return state.research.unlocked.contains(node)
    }

    /// The crew's average skill behind each pool, 0…100. Design and coding
    /// come off the payroll; polish is the mean of both, the way
    /// `crewSkillSample` treats it.
    private static func poolStrength(
        state: GameState, balance: BalanceConfig
    ) -> [FeatureCard.Lean: Double] {
        guard !state.employees.isEmpty else { return [:] }
        let count = Double(state.employees.count)
        let design = state.employees.reduce(0.0) { $0 + $1.skills.design } / count
        let coding = state.employees.reduce(0.0) { $0 + $1.skills.coding } / count
        return [.design: design, .code: coding, .polish: (design + coding) / 2]
    }

    // MARK: - Reading a board

    /// Reads a product's board: every placed card scored, the appetite,
    /// the 0…1 rating and the quality multiplier.
    public static func reading(
        for product: Product,
        state: GameState,
        content: ContentCatalog,
        balance: BalanceConfig
    ) -> FeatureBoardReading {
        let config = balance.featureBoard
        let type = content.productType(product.typeID)
        let slotCount = type.map { slots(for: $0, balance: balance) } ?? config.slotsMin
        let appetite = Set(appetite(state: state, balance: balance))
        let placed = product.features.compactMap { content.featureCard($0) }
        let placedIDs = Set(placed.map(\.id))

        var readings: [FeatureCardReading] = []
        var total = 0.0
        for (slot, card) in placed.enumerated() {
            let fitsType = card.fits(typeID: product.typeID)
            let fitsTopic = card.fits(topicID: product.topicID)
            // A list the card left empty says nothing either way, so a
            // wholly generic card is exactly neutral: a board of them is
            // a board that neither helps nor hurts.
            let typeTerm = card.fitsTypes.isEmpty ? 0 : (fitsType ? 0.5 : -0.5)
            let topicTerm = card.fitsTopics.isEmpty ? 0 : (fitsTopic ? 0.5 : -0.5)
            var value = (typeTerm + topicTerm) * config.fitValue

            let partners = placed
                .filter { other in
                    other.id != card.id
                        && (card.synergies.contains(other.id) || other.synergies.contains(card.id))
                }
                .map(\.id)
            // Half a synergy each, so a pair is worth one `synergyValue`
            // however the two cards wrote it down.
            value += Double(partners.count) * config.synergyValue / 2

            let rides = card.appetiteTag.map { appetite.contains($0) } ?? false
            if rides { value += config.appetiteValue }

            total += value
            readings.append(FeatureCardReading(
                cardID: card.id,
                name: card.name,
                slot: slot,
                fitsType: fitsType,
                fitsTopic: fitsTopic,
                synergyPartners: partners.filter { placedIDs.contains($0) },
                ridesAppetite: rides,
                value: value
            ))
        }

        let perSlot = slotCount > 0 ? total / Double(slotCount) : 0
        let multiplier = min(
            1 + config.qualityBonusCap,
            max(1 - config.qualityPenaltyCap, 1 + config.qualitySwing * perSlot)
        )
        let open = isOpen(product: product, type: type, balance: balance)
        return FeatureBoardReading(
            slots: slotCount,
            cards: readings,
            appetite: appetite.sorted(),
            isOpen: open,
            closedReason: open ? nil : FeatureBoardRefusal.designClosed.reason,
            score: min(1, max(0, (perSlot + 1) / 2.5)),
            qualityMultiplier: multiplier
        )
    }

    /// The multiplier `ProductSystem.ship` applies. Exactly 1.0 for an
    /// empty board — the whole feature is neutral until a card is placed.
    public static func qualityMultiplier(
        for product: Product,
        state: GameState,
        content: ContentCatalog,
        balance: BalanceConfig
    ) -> Double {
        guard !product.features.isEmpty else { return 1 }
        return reading(for: product, state: state, content: content, balance: balance)
            .qualityMultiplier
    }

    // MARK: - The design window

    /// Whether the board can still be changed: while design is open, which
    /// is until the design pool is `lockDesignFraction` full. A product
    /// that has shipped is closed for good.
    public static func isOpen(
        product: Product, type: ProductTypeDef?, balance: BalanceConfig
    ) -> Bool {
        guard case .development(let dev) = product.stage else { return false }
        guard let type, type.designPts > 0 else { return true }
        return dev.designPts < balance.featureBoard.lockDesignFraction * type.designPts
    }

    // MARK: - Actions

    /// Places `cardID` in `slot` of `productID`'s board, or says why not.
    ///
    /// A slot past the end appends; a slot inside the board replaces
    /// whatever was there. Nothing else on the product moves, and no event
    /// is posted — a board is a plan, and the plan is not news.
    static func place(
        productID: UUID,
        cardID: String,
        slot: Int,
        state: inout GameState,
        content: ContentCatalog,
        balance: BalanceConfig
    ) -> FeatureBoardRefusal? {
        guard let index = state.products.firstIndex(where: { $0.id == productID })
        else { return .noSuchProduct }
        guard case .development = state.products[index].stage else { return .notInDevelopment }
        let type = content.productType(state.products[index].typeID)
        guard isOpen(product: state.products[index], type: type, balance: balance)
        else { return .designClosed }
        guard let card = content.featureCard(cardID) else { return .noSuchCard }
        guard isUnlocked(card, state: state) else { return .cardLocked }

        var features = state.products[index].features
        let slotCount = type.map { slots(for: $0, balance: balance) } ?? balance.featureBoard.slotsMin
        if let existing = features.firstIndex(of: cardID) {
            // Already on the board: only a move to a different slot, which
            // the screen does by dragging, is a real request.
            guard existing != slot, slot < features.count else { return .cardAlreadyPlaced }
            features.remove(at: existing)
            features.insert(cardID, at: min(slot, features.count))
        } else if slot < features.count {
            features[slot] = cardID
        } else {
            guard features.count < slotCount else { return .boardFull }
            features.append(cardID)
        }
        state.products[index].features = features
        return nil
    }

    /// Takes the card in `slot` off the board.
    static func remove(
        productID: UUID,
        slot: Int,
        state: inout GameState,
        content: ContentCatalog,
        balance: BalanceConfig
    ) -> FeatureBoardRefusal? {
        guard let index = state.products.firstIndex(where: { $0.id == productID })
        else { return .noSuchProduct }
        guard case .development = state.products[index].stage else { return .notInDevelopment }
        guard isOpen(
            product: state.products[index],
            type: content.productType(state.products[index].typeID),
            balance: balance
        ) else { return .designClosed }
        guard state.products[index].features.indices.contains(slot) else { return .emptySlot }
        state.products[index].features.remove(at: slot)
        return nil
    }

    // MARK: - Asking before sending

    /// Why `.placeFeature` would be refused, without sending it — so the
    /// board screen can put the reason on the button rather than in a
    /// toast after the fact. `nil` means it would land.
    ///
    /// A dry run of the real thing on a copy of the state, so the sentence
    /// on the screen can never disagree with what the reducer does.
    public static func refusal(
        placing cardID: String,
        slot: Int,
        productID: UUID,
        state: GameState,
        content: ContentCatalog,
        balance: BalanceConfig
    ) -> FeatureBoardRefusal? {
        var copy = state
        return place(
            productID: productID, cardID: cardID, slot: slot,
            state: &copy, content: content, balance: balance
        )
    }

    /// Why `.removeFeature` would be refused. `nil` means it would land.
    public static func refusal(
        removingSlot slot: Int,
        productID: UUID,
        state: GameState,
        content: ContentCatalog,
        balance: BalanceConfig
    ) -> FeatureBoardRefusal? {
        var copy = state
        return remove(
            productID: productID, slot: slot,
            state: &copy, content: content, balance: balance
        )
    }

    // MARK: - Sequels

    /// The board a sequel starts with: the parent codebase's last board,
    /// trimmed to the new type's slots and to cards the studio can still
    /// build. A codebase nobody put a card on hands over nothing, which is
    /// what keeps every pre-board save greenfield.
    static func inheritedBoard(
        codebaseID: String?,
        typeID: String,
        state: GameState,
        content: ContentCatalog,
        balance: BalanceConfig
    ) -> [String] {
        // A `Codebase.id` *is* a product type id (see `startProduct`), so
        // the thing a sequel inherits from is the studio's most recent
        // release of that type.
        guard let codebaseID, codebaseID == typeID,
              let type = content.productType(typeID),
              let parent = lastShipped(typeID: typeID, state: state)
        else { return [] }
        let slotCount = slots(for: type, balance: balance)
        return parent.features
            .filter { id in
                guard let card = content.featureCard(id) else { return false }
                return isUnlocked(card, state: state)
            }
            .prefix(slotCount)
            .map { $0 }
    }

    /// The studio's most recent release of a type — the thing a codebase
    /// of that type actually came from.
    private static func lastShipped(typeID: String, state: GameState) -> Product? {
        state.products
            .filter { product in
                guard case .released = product.stage else { return false }
                return product.typeID == typeID && !product.features.isEmpty
            }
            .max { lhs, rhs in
                guard case .released(let left) = lhs.stage,
                      case .released(let right) = rhs.stage else { return false }
                return left.launchDay < right.launchDay
            }
    }
}
