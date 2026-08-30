/// One investor persona, loaded from `Investors.json`.
///
/// Personas are the people who might write the cheque: an angel who takes
/// five percent and stays out of the way, a growth fund that wants a fifth
/// of the company and a seat on the board. Each approaches once, when the
/// company clears their valuation floor and their reputation bar.
public struct InvestorDef: Codable, Equatable, Sendable, Identifiable {
    /// What kind of money it is — shown as a badge, and the reason the
    /// terms look the way they do.
    public enum Flavor: String, Codable, Equatable, Sendable, CaseIterable {
        case angel
        case seedFund
        case growthFund
        case strategicCorp

        public var displayName: String {
            switch self {
            case .angel: "Angel"
            case .seedFund: "Seed fund"
            case .growthFund: "Growth fund"
            case .strategicCorp: "Strategic"
            }
        }

        public var systemImageName: String {
            switch self {
            case .angel: "figure.wave"
            case .seedFund: "leaf.fill"
            case .growthFund: "chart.line.uptrend.xyaxis"
            case .strategicCorp: "building.2.fill"
            }
        }
    }

    public var id: String
    public var name: String
    public var flavor: Flavor
    /// The **largest** cheque they will write. The offer itself is
    /// `equityAsk` per cent of what the company is worth to an investor
    /// (`companyValuation` × `investors.roundValuationPremium`), and this
    /// is the ceiling on it — the most this fund puts into one company.
    ///
    /// It used to be the *floor*, which is how a seed fund came to put
    /// $250,000 into a company worth $250,000 for twelve per cent: an
    /// implied valuation four times the real one, a burn rate the round
    /// had just quintupled, and a board arriving next quarter expecting
    /// growth to match. Taking money was not a trade-off, it was a trap.
    public var checkSize: Int
    /// Percentage points of equity they ask for.
    public var equityAsk: Double
    /// The company valuation below which they won't return a call.
    public var valuationFloor: Int
    /// The company reputation below which they won't return a call.
    public var minReputation: Double
    /// Whether taking their money puts them on the board.
    public var boardSeat: Bool
    /// How many weeks of missed expectations they'll tolerate before the
    /// board room gets uncomfortable. Flavor for the UI; the pressure
    /// arithmetic lives in the balance.
    public var patienceWeeks: Int
    /// The one thing they watch, once they have a seat. Stored as the
    /// engine's `BoardExpectation` raw value.
    public var expects: String
    /// One line in their own voice, shown on the term sheet.
    public var pitch: String?

    public init(
        id: String,
        name: String,
        flavor: Flavor = .angel,
        checkSize: Int = 25_000,
        equityAsk: Double = 5,
        valuationFloor: Int = 100_000,
        minReputation: Double = 25,
        boardSeat: Bool = false,
        patienceWeeks: Int = 26,
        expects: String = "shipCadence",
        pitch: String? = nil
    ) {
        self.id = id
        self.name = name
        self.flavor = flavor
        self.checkSize = checkSize
        self.equityAsk = equityAsk
        self.valuationFloor = valuationFloor
        self.minReputation = minReputation
        self.boardSeat = boardSeat
        self.patienceWeeks = patienceWeeks
        self.expects = expects
        self.pitch = pitch
    }
}

// MARK: - Codable

// Hand-written so an `Investors.json` entry that lists only the terms it
// cares about still decodes, with the rest reading as an ordinary angel.

extension InvestorDef {
    private enum CodingKeys: String, CodingKey {
        case id, name, flavor, checkSize, equityAsk, valuationFloor, minReputation
        case boardSeat, patienceWeeks, expects, pitch
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try container.decode(String.self, forKey: .id),
            name: try container.decode(String.self, forKey: .name),
            flavor: try container.decodeIfPresent(Flavor.self, forKey: .flavor) ?? .angel,
            checkSize: try container.decodeIfPresent(Int.self, forKey: .checkSize) ?? 25_000,
            equityAsk: try container.decodeIfPresent(Double.self, forKey: .equityAsk) ?? 5,
            valuationFloor: try container.decodeIfPresent(Int.self, forKey: .valuationFloor) ?? 100_000,
            minReputation: try container.decodeIfPresent(Double.self, forKey: .minReputation) ?? 25,
            boardSeat: try container.decodeIfPresent(Bool.self, forKey: .boardSeat) ?? false,
            patienceWeeks: try container.decodeIfPresent(Int.self, forKey: .patienceWeeks) ?? 26,
            expects: try container.decodeIfPresent(String.self, forKey: .expects) ?? "shipCadence",
            pitch: try container.decodeIfPresent(String.self, forKey: .pitch)
        )
    }
}
