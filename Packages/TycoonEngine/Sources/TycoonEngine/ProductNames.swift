import Foundation
import TycoonContent

// MARK: S3 (product names)

/// Iteration 16 — S3. Who already has a product called that, for the
/// new-product flow's inline refusal.
public enum ProductNameClaim: Equatable, Sendable {
    /// One of the player's own products — live, in development, retired.
    case yours(product: String)
    /// A product on a rival studio's shelf.
    case rival(studio: String, product: String)
}

/// Iteration 16 — S3. The run's side of product naming: which names are in
/// use, the seed a suggestion is drawn from, and the names a v2 is offered.
///
/// Reads only. Nothing here draws from `rng` or `worldRNG`, sends an
/// action or stores a field: the seed is a hash of `seed`, the product
/// count and the flow's reroll index, so the same run on the same day
/// offers the same names and a new product moves them on.
extension GameState {
    /// Every product name in the run: the player's (live, in development,
    /// retired) and every rival's shelf.
    public var productNamesInUse: Set<String> {
        var names = Set(products.map(\.name))
        for rival in rivals.rivals {
            names.formUnion(rival.products.map(\.name))
        }
        return names
    }

    /// Who holds `name` (compared by `ProductNameGenerator.key`), `nil` when
    /// it is free. The player's own products answer first.
    public func productNameClaim(_ name: String) -> ProductNameClaim? {
        let key = ProductNameGenerator.key(name)
        guard !key.isEmpty else { return nil }
        if let mine = products.first(where: { ProductNameGenerator.key($0.name) == key }) {
            return .yours(product: mine.name)
        }
        for rival in rivals.rivals {
            if let theirs = rival.products.first(where: { ProductNameGenerator.key($0.name) == key }) {
                return .rival(studio: rival.name, product: theirs.name)
            }
        }
        return nil
    }

    /// The seed the `reroll`-th batch of suggestions is drawn from.
    public func productNameSeed(reroll: Int) -> UInt64 {
        var value = Self.nameMix(seed ^ 0x5333_5F4E_414D_4553)
        value = Self.nameMix(value ^ UInt64(products.count))
        return Self.nameMix(value ^ UInt64(truncatingIfNeeded: reroll))
    }

    /// `count` free names for a new product of this type and topic.
    ///
    /// - Parameter alsoTaken: names to keep out besides the run's own —
    ///   the Hall of Fame, and the batch the player just shuffled away.
    public func productNameSuggestions(
        typeID: String,
        topicID: String,
        reroll: Int,
        count: Int = 3,
        content: ContentCatalog,
        alsoTaken: Set<String> = []
    ) -> [String] {
        ProductNameGenerator.suggest(
            typeID: typeID,
            topicID: topicID,
            seed: productNameSeed(reroll: reroll),
            taken: productNamesInUse.union(alsoTaken),
            count: count,
            pools: content.productNamePools,
            topicName: content.topic(topicID)?.name
        )
    }

    /// What a successor to `parentID` is offered first: "Round 2",
    /// "Round II", "Round Next" — the generation after the parent's, when
    /// the parent is itself a successor ("Round 2" → "Round 3"). A name
    /// ending in a digit takes "v3" rather than "Round 6 3". Taken names are
    /// skipped; up to `count`.
    public func sequelNameSuggestions(
        parentID: UUID,
        count: Int = 3,
        content: ContentCatalog,
        alsoTaken: Set<String> = []
    ) -> [String] {
        guard let parent = product(id: parentID) else { return [] }
        let tails = content.productNamePools.sequelTails.isEmpty
            ? ["Next"] : content.productNamePools.sequelTails
        let (base, generation, usedTail) = Self.sequelBase(
            of: parent.name, isSequel: parent.parentID != nil, tails: tails
        )
        let next = generation + 1
        let endsInDigit = base.last?.isNumber ?? false
        let freshTails = tails.filter { $0 != usedTail }
        var candidates = [
            endsInDigit ? "\(base) v\(next)" : "\(base) \(next)",
            "\(base) \(Self.roman(next))",
        ]
        candidates += freshTails.map { "\(base) \($0)" }
        candidates.append("\(base) v\(next)")

        let takenKeys = Set(productNamesInUse.union(alsoTaken).map(ProductNameGenerator.key))
        var seen: Set<String> = []
        var result: [String] = []
        for name in candidates where result.count < count {
            let key = ProductNameGenerator.key(name)
            guard !takenKeys.contains(key), seen.insert(key).inserted else { continue }
            result.append(name)
        }
        return result
    }

    /// The name without its generation marker, the generation it was, and
    /// the sequel tail it wore. Only a successor's trailing number counts
    /// as a generation — "Round 6" as a first product is called that.
    static func sequelBase(
        of name: String, isSequel: Bool, tails: [String]
    ) -> (base: String, generation: Int, tail: String?) {
        let parts = name.split(separator: " ").map(String.init)
        guard parts.count > 1, let last = parts.last else { return (name, 1, nil) }
        let base = parts.dropLast().joined(separator: " ")
        // "v3" — K2's own form, a marker whether or not the link survives.
        if last.hasPrefix("v"), let number = Int(last.dropFirst()), number >= 2 {
            return (base, number, nil)
        }
        guard isSequel else { return (name, 1, nil) }
        if let number = Int(last), number >= 2, number < 100 { return (base, number, nil) }
        if let number = (2...20).first(where: { roman($0) == last }) { return (base, number, nil) }
        if tails.contains(last) { return (base, 2, last) }
        return (name, 1, nil)
    }

    static func roman(_ number: Int) -> String {
        let table: [(Int, String)] = [(10, "X"), (9, "IX"), (5, "V"), (4, "IV"), (1, "I")]
        var rest = max(1, number)
        var out = ""
        for (value, glyph) in table {
            while rest >= value {
                out += glyph
                rest -= value
            }
        }
        return out
    }

    /// SplitMix64's finalizer: stateless, part of no stream the simulation
    /// replays.
    private static func nameMix(_ value: UInt64) -> UInt64 {
        var z = value &+ 0x9E37_79B9_7F4A_7C15
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

// MARK: end S3
