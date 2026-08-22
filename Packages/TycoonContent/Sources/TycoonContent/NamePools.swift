/// Pools of fictional names used to generate employees, contract clients,
/// and the founder's family.
public struct NamePools: Codable, Equatable, Sendable {
    /// Gender-mixed, internationally diverse first names (>= 40).
    public var firstNames: [String]
    /// Internationally diverse last names (>= 40).
    public var lastNames: [String]
    /// Fictional client company names for contracts (>= 30).
    public var clientCompanies: [String]
    /// Gender-mixed, international first names for the founder's partner (>= 30).
    public var partnerNames: [String]
    /// First names for the founder's children (>= 30).
    public var childNames: [String]

    public init(
        firstNames: [String],
        lastNames: [String],
        clientCompanies: [String],
        partnerNames: [String] = [],
        childNames: [String] = []
    ) {
        self.firstNames = firstNames
        self.lastNames = lastNames
        self.clientCompanies = clientCompanies
        self.partnerNames = partnerNames
        self.childNames = childNames
    }
}
