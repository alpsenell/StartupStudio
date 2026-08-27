/// One kind of staff moment: someone on the team brings the founder a
/// problem, and the founder answers one of two ways.
///
/// The engine's `StaffEventKind` is the id space — a def's `id` is a kind's
/// raw value. Kinds with no def fall back to the generic balance numbers
/// (`supportCost` / `supportMorale` / `strictLoyaltyPenalty`), which is why
/// the tiny test catalogs still behave exactly as they did.
///
/// JSON:
///
///     {
///       "id": "raiseRequest",
///       "title": "{name} wants a raise",
///       "body": "They pulled the market data and they are not wrong...",
///       "weight": 5,
///       "requires": { "minTenureDays": 120, "minMorale": 20 },
///       "supportive": { "label": "Give the raise", "detail": "+15%/wk",
///                       "salaryPercent": 15, "loyalty": 14, "morale": 8 },
///       "strict":     { "label": "Not this quarter", "detail": "Free · loyalty −14",
///                       "loyalty": -14, "morale": -8 }
///     }
public struct StaffEventDef: Codable, Equatable, Sendable, Identifiable {
    /// What one answer does. Every field is optional and defaults to no
    /// change, so a def only lists what it moves.
    public struct Outcome: Codable, Equatable, Sendable {
        /// The button label.
        public var label: String
        /// One-line consequence under the label.
        public var detail: String?
        /// Company cash delta (negative = the founder pays).
        public var cash: Int
        /// Morale delta for the employee who raised it.
        public var morale: Double
        /// Loyalty delta for that employee.
        public var loyalty: Double
        /// Morale delta for everybody else on payroll.
        public var moraleAll: Double
        /// Company reputation delta.
        public var reputation: Double
        /// Percentage raise applied to that employee's weekly salary.
        public var salaryPercent: Double
        /// Clears the employee's assignment (they're out for a while).
        public var clearsAssignment: Bool
        /// The employee walks out on the spot.
        public var quits: Bool
        /// Skill growth for that employee, applied to every skill.
        public var skill: Double
        /// A narrative flag raised by this answer.
        public var setFlag: String?

        public init(
            label: String,
            detail: String? = nil,
            cash: Int = 0,
            morale: Double = 0,
            loyalty: Double = 0,
            moraleAll: Double = 0,
            reputation: Double = 0,
            salaryPercent: Double = 0,
            clearsAssignment: Bool = false,
            quits: Bool = false,
            skill: Double = 0,
            setFlag: String? = nil
        ) {
            self.label = label
            self.detail = detail
            self.cash = cash
            self.morale = morale
            self.loyalty = loyalty
            self.moraleAll = moraleAll
            self.reputation = reputation
            self.salaryPercent = salaryPercent
            self.clearsAssignment = clearsAssignment
            self.quits = quits
            self.skill = skill
            self.setFlag = setFlag
        }

        private enum CodingKeys: String, CodingKey {
            case label, detail, cash, morale, loyalty, moraleAll, reputation
            case salaryPercent, clearsAssignment, quits, skill, setFlag
        }

        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.init(
                label: try container.decode(String.self, forKey: .label),
                detail: try container.decodeIfPresent(String.self, forKey: .detail),
                cash: try container.decodeIfPresent(Int.self, forKey: .cash) ?? 0,
                morale: try container.decodeIfPresent(Double.self, forKey: .morale) ?? 0,
                loyalty: try container.decodeIfPresent(Double.self, forKey: .loyalty) ?? 0,
                moraleAll: try container.decodeIfPresent(Double.self, forKey: .moraleAll) ?? 0,
                reputation: try container.decodeIfPresent(Double.self, forKey: .reputation) ?? 0,
                salaryPercent: try container.decodeIfPresent(Double.self, forKey: .salaryPercent) ?? 0,
                clearsAssignment: try container.decodeIfPresent(Bool.self, forKey: .clearsAssignment) ?? false,
                quits: try container.decodeIfPresent(Bool.self, forKey: .quits) ?? false,
                skill: try container.decodeIfPresent(Double.self, forKey: .skill) ?? 0,
                setFlag: try container.decodeIfPresent(String.self, forKey: .setFlag)
            )
        }

        public func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(label, forKey: .label)
            try container.encodeIfPresent(detail, forKey: .detail)
            try container.encode(cash, forKey: .cash)
            try container.encode(morale, forKey: .morale)
            try container.encode(loyalty, forKey: .loyalty)
            try container.encode(moraleAll, forKey: .moraleAll)
            try container.encode(reputation, forKey: .reputation)
            try container.encode(salaryPercent, forKey: .salaryPercent)
            try container.encode(clearsAssignment, forKey: .clearsAssignment)
            try container.encode(quits, forKey: .quits)
            try container.encode(skill, forKey: .skill)
            try container.encodeIfPresent(setFlag, forKey: .setFlag)
        }
    }

    /// When this kind can come up. Every field is optional.
    public struct Gate: Codable, Equatable, Sendable {
        /// The employee must have at least one of these traits.
        public var anyTrait: [String]
        /// The employee must have none of these traits.
        public var noTrait: [String]
        /// Days since the employee was hired.
        public var minTenureDays: Int?
        public var minMorale: Double?
        public var maxMorale: Double?
        public var minLoyalty: Double?
        public var maxLoyalty: Double?
        /// The employee needs at least one friend on the team.
        public var requiresFriend: Bool?
        /// The company needs this department staffed ("hr", "legal", "ops").
        public var requiresDepartment: String?
        /// Total headcount, founder included.
        public var minHeadcount: Int?
        /// Office tier raw value the studio must have reached.
        public var minTier: String?

        public init(
            anyTrait: [String] = [],
            noTrait: [String] = [],
            minTenureDays: Int? = nil,
            minMorale: Double? = nil,
            maxMorale: Double? = nil,
            minLoyalty: Double? = nil,
            maxLoyalty: Double? = nil,
            requiresFriend: Bool? = nil,
            requiresDepartment: String? = nil,
            minHeadcount: Int? = nil,
            minTier: String? = nil
        ) {
            self.anyTrait = anyTrait
            self.noTrait = noTrait
            self.minTenureDays = minTenureDays
            self.minMorale = minMorale
            self.maxMorale = maxMorale
            self.minLoyalty = minLoyalty
            self.maxLoyalty = maxLoyalty
            self.requiresFriend = requiresFriend
            self.requiresDepartment = requiresDepartment
            self.minHeadcount = minHeadcount
            self.minTier = minTier
        }

        private enum CodingKeys: String, CodingKey {
            case anyTrait, noTrait, minTenureDays, minMorale, maxMorale
            case minLoyalty, maxLoyalty, requiresFriend, requiresDepartment
            case minHeadcount, minTier
        }

        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.init(
                anyTrait: try container.decodeIfPresent([String].self, forKey: .anyTrait) ?? [],
                noTrait: try container.decodeIfPresent([String].self, forKey: .noTrait) ?? [],
                minTenureDays: try container.decodeIfPresent(Int.self, forKey: .minTenureDays),
                minMorale: try container.decodeIfPresent(Double.self, forKey: .minMorale),
                maxMorale: try container.decodeIfPresent(Double.self, forKey: .maxMorale),
                minLoyalty: try container.decodeIfPresent(Double.self, forKey: .minLoyalty),
                maxLoyalty: try container.decodeIfPresent(Double.self, forKey: .maxLoyalty),
                requiresFriend: try container.decodeIfPresent(Bool.self, forKey: .requiresFriend),
                requiresDepartment: try container.decodeIfPresent(String.self, forKey: .requiresDepartment),
                minHeadcount: try container.decodeIfPresent(Int.self, forKey: .minHeadcount),
                minTier: try container.decodeIfPresent(String.self, forKey: .minTier)
            )
        }

        public func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            if !anyTrait.isEmpty { try container.encode(anyTrait, forKey: .anyTrait) }
            if !noTrait.isEmpty { try container.encode(noTrait, forKey: .noTrait) }
            try container.encodeIfPresent(minTenureDays, forKey: .minTenureDays)
            try container.encodeIfPresent(minMorale, forKey: .minMorale)
            try container.encodeIfPresent(maxMorale, forKey: .maxMorale)
            try container.encodeIfPresent(minLoyalty, forKey: .minLoyalty)
            try container.encodeIfPresent(maxLoyalty, forKey: .maxLoyalty)
            try container.encodeIfPresent(requiresFriend, forKey: .requiresFriend)
            try container.encodeIfPresent(requiresDepartment, forKey: .requiresDepartment)
            try container.encodeIfPresent(minHeadcount, forKey: .minHeadcount)
            try container.encodeIfPresent(minTier, forKey: .minTier)
        }
    }

    /// The `StaffEventKind` raw value this def drives.
    public var id: String
    /// Sheet title. `{name}` is replaced with the employee's name.
    public var title: String
    /// Sheet body. `{name}` and `{company}` are replaced.
    public var body: String
    /// The one-line journal sentence. `{name}` is replaced.
    public var headline: String
    /// Relative pick probability among the eligible kinds, >= 1.
    public var weight: Int
    /// When this kind can come up.
    public var requires: Gate?
    /// The generous answer.
    public var supportive: Outcome
    /// The firm answer — also what the deadline picks.
    public var strict: Outcome

    public init(
        id: String,
        title: String,
        body: String,
        headline: String,
        weight: Int,
        requires: Gate? = nil,
        supportive: Outcome,
        strict: Outcome
    ) {
        self.id = id
        self.title = title
        self.body = body
        self.headline = headline
        self.weight = weight
        self.requires = requires
        self.supportive = supportive
        self.strict = strict
    }
}
