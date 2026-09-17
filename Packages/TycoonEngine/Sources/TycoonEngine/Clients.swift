import Foundation

// MARK: The client book

// Contracts stop being anonymous one-shots: once the founder has looked
// at the client book, the studio remembers everyone it settles a job
// with — how much they trust it, what was delivered, and who has gone
// cold — and a trusted client's next offer arrives pre-warmed.
//
// **Identity at the default.** Everything here is inert while
// `ClientBook.noticed` is false: `settleContracts` records nothing,
// `refreshOffers` warms nothing, and `GameState` encodes the book only
// when it is not `.empty` — so a pacing bot's save, which accepts
// contracts but never opens the Business tab, keeps its bytes. Only
// `.noticeClientBookOpened` sets the flag, and only the app sends it
// (the `noticeFinancesOpened` pattern). Nothing in the lane draws from
// any RNG stream: trust is arithmetic on the delivery grade the settle
// already computed, and a warmed offer rewrites a rolled offer after
// the sheet's documented draws, the way `sponsorOneOffer` does.

/// One client the studio has settled a job with, keyed by the company
/// name the offer sheet drew.
public struct Client: Codable, Equatable, Sendable, Identifiable {
    public var id: String { name }
    /// The client company's name — the identity the offer sheet rolls.
    public var name: String
    /// 0...100, moved by every settlement. A client at or above the
    /// balance's `trustedThreshold` warms their next offers.
    public var trust: Double
    /// Jobs delivered, at any grade.
    public var jobsDelivered: Int
    /// Jobs that blew their deadline.
    public var jobsFailed: Int
    /// The last day a job for them settled, either way.
    public var lastSettledDay: Int
    /// Set by a botched or failed job: no warmed offers until this day.
    public var coldUntilDay: Int?

    public init(
        name: String,
        trust: Double,
        jobsDelivered: Int = 0,
        jobsFailed: Int = 0,
        lastSettledDay: Int = 0,
        coldUntilDay: Int? = nil
    ) {
        self.name = name
        self.trust = trust
        self.jobsDelivered = jobsDelivered
        self.jobsFailed = jobsFailed
        self.lastSettledDay = lastSettledDay
        self.coldUntilDay = coldUntilDay
    }

    /// Whether the client is still smarting from a bad delivery.
    public func isCold(day: Int) -> Bool {
        coldUntilDay.map { day < $0 } ?? false
    }
}

extension Client {
    private enum CodingKeys: String, CodingKey {
        case name, trust, jobsDelivered, jobsFailed, lastSettledDay, coldUntilDay
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            name: try container.decode(String.self, forKey: .name),
            trust: try container.decode(Double.self, forKey: .trust),
            jobsDelivered: try container.decodeIfPresent(Int.self, forKey: .jobsDelivered) ?? 0,
            jobsFailed: try container.decodeIfPresent(Int.self, forKey: .jobsFailed) ?? 0,
            lastSettledDay: try container.decodeIfPresent(Int.self, forKey: .lastSettledDay) ?? 0,
            coldUntilDay: try container.decodeIfPresent(Int.self, forKey: .coldUntilDay)
        )
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(trust, forKey: .trust)
        try container.encode(jobsDelivered, forKey: .jobsDelivered)
        try container.encode(jobsFailed, forKey: .jobsFailed)
        try container.encode(lastSettledDay, forKey: .lastSettledDay)
        try container.encodeIfPresent(coldUntilDay, forKey: .coldUntilDay)
    }
}

/// The book itself: whether it has ever been opened, and everyone in it.
public struct ClientBook: Codable, Equatable, Sendable {
    /// The player has opened the contracts section; set once, by
    /// `.noticeClientBookOpened`, and never by a bot.
    public var noticed: Bool
    /// Every client a job has settled with since the book was opened,
    /// first-met first — a stable order, so identical states encode to
    /// identical bytes.
    public var clients: [Client]

    public init(noticed: Bool = false, clients: [Client] = []) {
        self.noticed = noticed
        self.clients = clients
    }

    /// The state every run starts in, and the one that is never encoded.
    public static let empty = ClientBook()

    public func client(named name: String) -> Client? {
        clients.first { $0.name == name }
    }

    /// The clients whose offers arrive warmed today: trusted, and not
    /// cold. Best-trusted first, ties on the name, so the pick replays.
    public func warmClients(day: Int, trustedThreshold: Double) -> [Client] {
        clients
            .filter { $0.trust >= trustedThreshold && !$0.isCold(day: day) }
            .sorted { lhs, rhs in
                if lhs.trust != rhs.trust { return lhs.trust > rhs.trust }
                return lhs.name < rhs.name
            }
    }

    /// Looks a client up, or opens their page at `baseTrust`, and lets
    /// `mutate` write the settlement onto it. Trust stays 0...100.
    public mutating func record(
        clientName: String,
        baseTrust: Double,
        mutate: (inout Client) -> Void
    ) {
        var client = self.client(named: clientName) ?? Client(name: clientName, trust: baseTrust)
        mutate(&client)
        client.trust = min(100, max(0, client.trust))
        if let index = clients.firstIndex(where: { $0.name == clientName }) {
            clients[index] = client
        } else {
            clients.append(client)
        }
    }
}

extension ClientBook {
    private enum CodingKeys: String, CodingKey {
        case noticed, clients
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            noticed: try container.decodeIfPresent(Bool.self, forKey: .noticed) ?? false,
            clients: try container.decodeIfPresent([Client].self, forKey: .clients) ?? []
        )
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if noticed { try container.encode(noticed, forKey: .noticed) }
        if !clients.isEmpty { try container.encode(clients, forKey: .clients) }
    }
}
