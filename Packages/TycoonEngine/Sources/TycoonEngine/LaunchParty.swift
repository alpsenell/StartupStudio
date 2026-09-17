import Foundation

// MARK: X4 (the launch party)

/// Iteration 18 — X4. The launch party: the model, and every read the app
/// makes before it sends `.throwLaunchParty`.
///
/// The game has talked about launch parties since iteration 11 — J1's vices
/// door arrives as a number on a napkin from one, T6's away launch and K7's
/// kept date are both priced as a party *not* thrown — without ever letting
/// anybody throw one. This is the verb under all three.
///
/// Nothing here draws. A run that never parties leaves `GameState.parties`
/// empty, which is not encoded, so every bot, fixture and replay is byte for
/// byte what it was.

/// Where the party is.
public enum PartyVenue: String, Codable, Equatable, Sendable, CaseIterable {
    /// Pizza and the good monitor turned round.
    case office
    /// The bar down the road, a tab behind it.
    case bar
    /// A roof, a licence, and somebody taking photographs.
    case rooftop

    public var displayName: String {
        switch self {
        case .office: "The office"
        case .bar: "The bar"
        case .rooftop: "The rooftop"
        }
    }

    /// What the invitation says it is.
    public var note: String {
        switch self {
        case .office: "Pizza, the good monitor turned round, everyone home by ten."
        case .bar: "A tab down the road. Somebody will make a speech."
        case .rooftop: "A roof, a licence and a photographer. People will hear about it."
        }
    }
}

/// Somebody on the guest list: one of the four review outlets, or somebody
/// out of the address book.
public enum PartyGuest: Codable, Equatable, Sendable, Hashable {
    case outlet(String)
    case contact(UUID)
}

/// A party that happened, kept so the launch can only have one and the
/// week's vice pressure can read it.
public struct LaunchParty: Codable, Equatable, Sendable {
    public var productID: UUID
    public var venue: PartyVenue
    public var day: Int
    /// The list as it was sent, in the order the sheet had it.
    public var guests: [PartyGuest]
    /// The review score the night was thrown against — what makes it a
    /// celebration or a wake.
    public var reviewScore: Int
    /// The `liveHype` the party actually moved (negative when it read
    /// desperate), so launch day and the paper can say the number.
    public var hype: Double
    /// Whether the venue was above what the reviews earned.
    public var desperate: Bool

    public init(
        productID: UUID,
        venue: PartyVenue,
        day: Int,
        guests: [PartyGuest],
        reviewScore: Int,
        hype: Double,
        desperate: Bool
    ) {
        self.productID = productID
        self.venue = venue
        self.day = day
        self.guests = guests
        self.reviewScore = reviewScore
        self.hype = hype
        self.desperate = desperate
    }
}

/// What a party would do, before it is thrown: the sheet prints every line
/// of this and the reducer recomputes it from the same function, so the
/// button never promises a number the engine will not pay.
public struct PartyQuote: Equatable, Sendable {
    public var venue: PartyVenue
    public var cost: Int
    public var morale: Double
    /// `liveHype` the party adds — negative under the pivot.
    public var hype: Double
    public var reviewScore: Int
    public var desperate: Bool
    /// Standing each invited outlet gains, before the desperate penalty.
    public var outletStanding: Double
    /// Standing every outlet loses because the venue was not earned.
    public var desperatePenalty: Double
    /// Rapport each invited contact gains.
    public var bond: Double
    /// How many names the list takes.
    public var guestLimit: Int
}

// MARK: - Queries

extension GameState {
    /// The party thrown for `productID`, if one was.
    public func party(for productID: UUID) -> LaunchParty? {
        parties.first { $0.productID == productID }
    }

    /// Whether `productID` is inside its party window today.
    public func partyWindowIsOpen(productID: UUID, balance: BalanceConfig) -> Bool {
        guard let product = product(id: productID), case .released(let info) = product.stage else { return false }
        let since = day - info.launchDay
        return since >= 0 && since <= max(0, balance.party.windowDays)
    }

    /// Why a party for `productID` at `venue` would be refused, in the
    /// player's words, or `nil` when it would go ahead. The reducer enforces
    /// exactly this, so a stale sheet can never spend anything.
    public func launchPartyBlocker(
        productID: UUID,
        venue: PartyVenue,
        balance: BalanceConfig
    ) -> String? {
        guard let product = product(id: productID), case .released(let info) = product.stage else {
            return "It has not shipped"
        }
        if gameOver != nil { return "The run is over" }
        // T6: the founder is not in the building. The launch already said so.
        if life.isAway(day: day) { return awayPartyReason }
        if party(for: productID) != nil { return "You already had one" }
        let since = day - info.launchDay
        if since < 0 { return "It has not shipped" }
        if since > max(0, balance.party.windowDays) { return "Launch week is over" }
        // K7: the date was kept instead, which is the party not happening.
        if diaryDateWasKept(productID: productID) { return "You kept the date instead" }
        let cost = balance.party.venue(venue).cost
        if company.cash < cost { return "Not enough cash — you have \(company.cash)" }
        if let evening = eveningBlocker(balance) { return evening }
        return nil
    }

    /// The line the sheet shows instead of the venues while the founder is
    /// somewhere else. T6's launch row says the same thing about the launch;
    /// this says it about the party the player came looking for.
    public var awayPartyReason: String {
        let reason = life.awayReason.map { $0.lowercased() } ?? "away"
        return "You are \(reason). There is no party without you"
    }

    /// K7: whether the player kept the diary date on this launch, which is
    /// the launch party skipped.
    public func diaryDateWasKept(productID: UUID) -> Bool {
        eventLog.contains {
            if case .diaryDateKept(let id, _, _) = $0 { id == productID } else { false }
        }
    }

    /// What a party at `venue` for `productID` would do today. Computed the
    /// same way whoever asks — the sheet, the reducer, a balance script.
    public func partyQuote(
        productID: UUID,
        venue: PartyVenue,
        balance: BalanceConfig
    ) -> PartyQuote {
        let config = balance.party
        let tier = config.venue(venue)
        let score = partyReviewScore(productID: productID)
        let desperate = score < tier.earnedAt
        return PartyQuote(
            venue: venue,
            cost: tier.cost,
            morale: tier.morale,
            hype: tier.hype * LaunchPartyMath.slope(reviewScore: score, balance: balance),
            reviewScore: score,
            desperate: desperate,
            outletStanding: config.outletStanding,
            desperatePenalty: desperate ? config.desperateStanding : 0,
            bond: config.bondPerGuest,
            guestLimit: tier.guests
        )
    }

    /// The score the room is reading tonight: the verdicts that are out
    /// (T7's exclusive holds three of them back, and the party reads what
    /// the guests have actually seen), 0 before any of them file.
    public func partyReviewScore(productID: UUID) -> Int {
        guard let product = product(id: productID), case .released(let info) = product.stage else { return 0 }
        return info.visibleAverageScore(on: day)
    }

    /// Who could come: the outlets that reviewed it, then the open contacts
    /// the founder has actually met, closest first. The sheet cuts this to
    /// the venue's `guests`.
    public func partyGuestPool(productID: UUID, balance: BalanceConfig) -> [PartyGuest] {
        var pool: [PartyGuest] = []
        if let product = product(id: productID), case .released(let info) = product.stage {
            // The outlets in the order the press filed, so the list is stable.
            for review in info.visibleReviews(on: day) where balance.reviewOutlets.contains(review.outlet) {
                pool.append(.outlet(review.outlet))
            }
        }
        let contacts = networking.contacts
            .filter(\.isOpen)
            .sorted { lhs, rhs in
                if lhs.rapport != rhs.rapport { return lhs.rapport > rhs.rapport }
                return lhs.id.uuidString < rhs.id.uuidString
            }
        pool.append(contentsOf: contacts.map { PartyGuest.contact($0.id) })
        return pool
    }

    /// The products whose party window is open today and who have not had
    /// one — what the war room's aftermath and the launch sheet offer.
    public func productsAwaitingParty(balance: BalanceConfig) -> [Product] {
        products.filter {
            partyWindowIsOpen(productID: $0.id, balance: balance)
                && party(for: $0.id) == nil
                && !diaryDateWasKept(productID: $0.id)
        }
    }
}

/// The party's arithmetic, in one place so the sheet, the reducer and any
/// balance pass read the identical number.
public enum LaunchPartyMath {
    /// How much of a venue's hype the reviews justify:
    /// `(review − hypePivot) / hypeSlope`, clamped.
    ///
    /// Zero at the pivot — which is the whole point. A rooftop for a 60 buys
    /// nothing at all for $6,000 and the week's scarcest evening, and a
    /// rooftop for a 55 *takes hype away*, because everybody in the room can
    /// read.
    public static func slope(reviewScore: Int, balance: BalanceConfig) -> Double {
        let config = balance.party
        let divisor = config.hypeSlope == 0 ? 1 : config.hypeSlope
        let raw = (Double(reviewScore) - config.hypePivot) / divisor
        return min(config.hypeCeiling, max(config.hypeFloor, raw))
    }

    /// Parties actually thrown in the last week, for the vices' weekly
    /// count. Zero on every run nobody threw one in.
    static func thrownThisWeek(_ state: GameState) -> Int {
        state.parties.count { state.day - $0.day < GameState.daysPerWeek }
    }
}

// MARK: end X4
