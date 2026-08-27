/// One investor persona, loaded from `Investors.json`.
///
/// Scaffold shape: an id and a name. WS-F owns this file and adds the
/// terms (`checkSize`, `equityAsk`, `valuationFloor`, `boardSeat`,
/// `patienceWeeks`, `expects`) that `InvestorSystem` reads; the catalog
/// ships empty (`[]`).
public struct InvestorDef: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var name: String

    public init(id: String, name: String) {
        self.id = id
        self.name = name
    }
}
