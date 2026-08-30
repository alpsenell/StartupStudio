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
    /// Software-studio names for rivals ("Lumen Labs", "Parallax"). Empty
    /// until WS-B writes the pool; `RivalSystem` keeps naming rivals from
    /// `clientCompanies` until then.
    public var rivalStudios: [String]
    /// Words rival products are named from. Empty until WS-B writes the
    /// pool.
    public var productWords: [String]

    public init(
        firstNames: [String],
        lastNames: [String],
        clientCompanies: [String],
        partnerNames: [String] = [],
        childNames: [String] = [],
        rivalStudios: [String] = [],
        productWords: [String] = []
    ) {
        self.firstNames = firstNames
        self.lastNames = lastNames
        self.clientCompanies = clientCompanies
        self.partnerNames = partnerNames
        self.childNames = childNames
        self.rivalStudios = rivalStudios
        self.productWords = productWords
    }
}

// MARK: - Codable

// Hand-written decode so a `Names.json` written before the rival pools
// existed keeps loading: the two new keys read as empty arrays.

extension NamePools {
    private enum CodingKeys: String, CodingKey {
        case firstNames, lastNames, clientCompanies, partnerNames, childNames
        case rivalStudios, productWords
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            firstNames: try container.decode([String].self, forKey: .firstNames),
            lastNames: try container.decode([String].self, forKey: .lastNames),
            clientCompanies: try container.decode([String].self, forKey: .clientCompanies),
            partnerNames: try container.decodeIfPresent([String].self, forKey: .partnerNames) ?? [],
            childNames: try container.decodeIfPresent([String].self, forKey: .childNames) ?? [],
            rivalStudios: try container.decodeIfPresent([String].self, forKey: .rivalStudios) ?? [],
            productWords: try container.decodeIfPresent([String].self, forKey: .productWords) ?? []
        )
    }
}
