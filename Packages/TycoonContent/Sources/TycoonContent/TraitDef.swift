/// One employee personality trait, loaded from `Traits.json`.
///
/// Scaffold shape: an id, a display name, and an optional one-liner. WS-F
/// owns this file and adds the `effects` block that `TraitEffects` reads;
/// the catalog ships empty (`[]`) until then, so nothing changes today.
public struct TraitDef: Codable, Equatable, Sendable, Identifiable {
    /// Stable id referenced by `Employee.traits`.
    public var id: String
    public var name: String
    /// Short description shown on trait chips.
    public var blurb: String?

    public init(id: String, name: String, blurb: String? = nil) {
        self.id = id
        self.name = name
        self.blurb = blurb
    }
}
