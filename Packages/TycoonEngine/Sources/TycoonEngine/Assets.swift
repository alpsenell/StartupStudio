import Foundation

// Iteration 11 — N3 owns this file. The founder's assets (cars, a second
// property, pets, the casino, the lottery, the crypto wallet), the
// doctor's office (named ailments, treatments, therapy) and the vices,
// all on one slot.
//
// **The identity rule.** Everything here is dormant until the player
// opens the Assets screen, which sends `.noticeAssetsOpened` and sets
// `opened`. Until then `state.assets == .empty`, the slot is not encoded,
// `AssetsSystem` returns on its first line, and not one word is drawn
// from `socialRNG`. A pacing bot never opens a screen, so a bot's run is
// byte-for-byte the run it was before this file existed.

/// The three kinds of thing the founder can own outright.
public enum AssetKind: String, Codable, Equatable, Sendable, CaseIterable {
    case car, property, pet

    /// The heading the garage, the deeds and the basket sit under.
    public var sectionTitle: String {
        switch self {
        case .car: "The garage"
        case .property: "Property"
        case .pet: "The household"
        }
    }
}

/// One thing the founder owns. The catalog id is the identity — you can
/// own a hatchback and a coupé, but not two hatchbacks.
public struct AssetOwned: Codable, Equatable, Sendable, Identifiable {
    public var id: String { catalogID }
    public var catalogID: String
    public var kind: AssetKind
    public var boughtDay: Int
    /// 0…100. A car's MOT, a flat's state of repair, a pet's health.
    public var condition: Double
    /// Pets only: what you called it.
    public var petName: String
    /// Off the road / uninhabitable until the bill is paid.
    public var needsRepair: Bool
    /// Properties only: somebody is paying rent for it.
    public var letOut: Bool

    public init(
        catalogID: String,
        kind: AssetKind,
        boughtDay: Int,
        condition: Double = 100,
        petName: String = "",
        needsRepair: Bool = false,
        letOut: Bool = false
    ) {
        self.catalogID = catalogID
        self.kind = kind
        self.boughtDay = boughtDay
        self.condition = condition
        self.petName = petName
        self.needsRepair = needsRepair
        self.letOut = letOut
    }

    private enum CodingKeys: String, CodingKey {
        case catalogID, kind, boughtDay, condition, petName, needsRepair, letOut
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            catalogID: try c.decode(String.self, forKey: .catalogID),
            kind: try c.decodeIfPresent(AssetKind.self, forKey: .kind) ?? .car,
            boughtDay: try c.decodeIfPresent(Int.self, forKey: .boughtDay) ?? 0,
            condition: try c.decodeIfPresent(Double.self, forKey: .condition) ?? 100,
            petName: try c.decodeIfPresent(String.self, forKey: .petName) ?? "",
            needsRepair: try c.decodeIfPresent(Bool.self, forKey: .needsRepair) ?? false,
            letOut: try c.decodeIfPresent(Bool.self, forKey: .letOut) ?? false
        )
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(catalogID, forKey: .catalogID)
        try c.encode(kind, forKey: .kind)
        try c.encode(boughtDay, forKey: .boughtDay)
        try c.encode(condition, forKey: .condition)
        if !petName.isEmpty { try c.encode(petName, forKey: .petName) }
        if needsRepair { try c.encode(needsRepair, forKey: .needsRepair) }
        if letOut { try c.encode(letOut, forKey: .letOut) }
    }
}

/// Something the founder is living with. A treatment sets `treatedUntilDay`
/// and the ailment clears on it; until then it is still drifting.
public struct AssetAilment: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var sinceDay: Int
    /// The day the course of treatment finishes, or `nil` while untreated.
    public var treatedUntilDay: Int?

    public init(id: String, sinceDay: Int, treatedUntilDay: Int? = nil) {
        self.id = id
        self.sinceDay = sinceDay
        self.treatedUntilDay = treatedUntilDay
    }

    public var isBeingTreated: Bool { treatedUntilDay != nil }
}

/// The founder's own money in something that moves. A random walk on
/// `socialRNG`, weekly, only while the wallet is open.
public struct AssetCryptoWallet: Codable, Equatable, Sendable {
    /// Units held.
    public var units: Double
    /// Dollars a unit, today.
    public var price: Double
    public var openedDay: Int
    /// Net dollars put in, so the screen can say what it has cost so far.
    public var invested: Int

    public init(units: Double = 0, price: Double = 1, openedDay: Int = 0, invested: Int = 0) {
        self.units = units
        self.price = price
        self.openedDay = openedDay
        self.invested = invested
    }

    /// What it is worth today, in whole dollars.
    public var value: Int { Int((units * price).rounded()) }
}

/// A ticket bought this week, resolved at the weekend.
public struct AssetLotteryTicket: Codable, Equatable, Sendable {
    public var boughtDay: Int

    public init(boughtDay: Int) { self.boughtDay = boughtDay }
}

/// A run of evenings spent not doing the thing.
public struct AssetQuit: Codable, Equatable, Sendable, Identifiable {
    public var id: String { viceID }
    public var viceID: String
    public var startedDay: Int
    public var eveningsDone: Int
    public var lastEveningDay: Int

    public init(viceID: String, startedDay: Int, eveningsDone: Int = 0, lastEveningDay: Int = 0) {
        self.viceID = viceID
        self.startedDay = startedDay
        self.eveningsDone = eveningsDone
        self.lastEveningDay = lastEveningDay
    }
}

/// One vice's dependency, in the save. A sorted array rather than a
/// dictionary so the JSON is stable byte for byte.
public struct AssetViceEntry: Codable, Equatable, Sendable {
    public var id: String
    public var dependency: Double

    public init(id: String, dependency: Double) {
        self.id = id
        self.dependency = dependency
    }
}

/// Everything on the founder's own balance sheet and in their own body.
public struct AssetsState: Codable, Equatable, Sendable {
    /// The player has been to the Assets screen. Nothing here runs until
    /// they have; see the note at the top of the file.
    public var opened: Bool
    /// Cars, properties and pets, sorted by catalog id.
    public var owned: [AssetOwned]
    /// Named ailments the founder currently has.
    public var ailments: [AssetAilment]
    /// Vice id → 0…100 dependency.
    public var vices: [String: Double]
    public var crypto: AssetCryptoWallet?
    public var ticket: AssetLotteryTicket?
    /// Runs of evenings currently being spent on quitting.
    public var quits: [AssetQuit]
    /// Dollars staked at the casino since the week turned.
    public var stakedThisWeek: Int
    /// The last evening spent on the couch in the therapist's office.
    public var lastTherapyDay: Int?
    /// Vices somebody has already staged an intervention over. One each.
    public var intervened: [String]
    /// Consecutive days under the mood and health lines the doctor cares
    /// about, and consecutive crunch weeks. The ailment causes read these
    /// instead of rolling dice, so a diagnosis is always something the
    /// player did.
    public var lowMoodDays: Int
    public var lowHealthDays: Int
    public var crunchWeeks: Int

    public init(
        opened: Bool = false,
        owned: [AssetOwned] = [],
        ailments: [AssetAilment] = [],
        vices: [String: Double] = [:],
        crypto: AssetCryptoWallet? = nil,
        ticket: AssetLotteryTicket? = nil,
        quits: [AssetQuit] = [],
        stakedThisWeek: Int = 0,
        lastTherapyDay: Int? = nil,
        intervened: [String] = [],
        lowMoodDays: Int = 0,
        lowHealthDays: Int = 0,
        crunchWeeks: Int = 0
    ) {
        self.opened = opened
        self.owned = owned
        self.ailments = ailments
        self.vices = vices
        self.crypto = crypto
        self.ticket = ticket
        self.quits = quits
        self.stakedThisWeek = stakedThisWeek
        self.lastTherapyDay = lastTherapyDay
        self.intervened = intervened
        self.lowMoodDays = lowMoodDays
        self.lowHealthDays = lowHealthDays
        self.crunchWeeks = crunchWeeks
    }

    public static let empty = AssetsState()

    /// Whether any of this has started. `GameState` encodes the slot only
    /// when it has, and `AssetsSystem` runs only when it has.
    public var isEngaged: Bool { self != .empty }

    // MARK: Queries

    public func owned(_ kind: AssetKind) -> [AssetOwned] {
        owned.filter { $0.kind == kind }
    }

    public func owns(_ catalogID: String) -> Bool {
        owned.contains { $0.catalogID == catalogID }
    }

    public func asset(_ catalogID: String) -> AssetOwned? {
        owned.first { $0.catalogID == catalogID }
    }

    public func dependency(_ viceID: String) -> Double {
        vices[viceID] ?? 0
    }

    public func hasAilment(_ id: String) -> Bool {
        ailments.contains { $0.id == id }
    }

    public func quit(_ viceID: String) -> AssetQuit? {
        quits.first { $0.viceID == viceID }
    }

    /// The worst vice, for the card's headline. `nil` when nothing is
    /// above zero.
    public var worstVice: (id: String, dependency: Double)? {
        vices.filter { $0.value > 0 }
            .sorted { ($0.value, $1.key) > ($1.value, $0.key) }
            .first
            .map { (id: $0.key, dependency: $0.value) }
    }

    // MARK: Codable

    private enum CodingKeys: String, CodingKey {
        case opened, owned, ailments, vices, crypto, ticket, quits
        case stakedThisWeek, lastTherapyDay, intervened
        case lowMoodDays, lowHealthDays, crunchWeeks
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let entries = try c.decodeIfPresent([AssetViceEntry].self, forKey: .vices) ?? []
        self.init(
            opened: try c.decodeIfPresent(Bool.self, forKey: .opened) ?? false,
            owned: try c.decodeIfPresent([AssetOwned].self, forKey: .owned) ?? [],
            ailments: try c.decodeIfPresent([AssetAilment].self, forKey: .ailments) ?? [],
            vices: Dictionary(entries.map { ($0.id, $0.dependency) }, uniquingKeysWith: { a, _ in a }),
            crypto: try c.decodeIfPresent(AssetCryptoWallet.self, forKey: .crypto),
            ticket: try c.decodeIfPresent(AssetLotteryTicket.self, forKey: .ticket),
            quits: try c.decodeIfPresent([AssetQuit].self, forKey: .quits) ?? [],
            stakedThisWeek: try c.decodeIfPresent(Int.self, forKey: .stakedThisWeek) ?? 0,
            lastTherapyDay: try c.decodeIfPresent(Int.self, forKey: .lastTherapyDay),
            intervened: try c.decodeIfPresent([String].self, forKey: .intervened) ?? [],
            lowMoodDays: try c.decodeIfPresent(Int.self, forKey: .lowMoodDays) ?? 0,
            lowHealthDays: try c.decodeIfPresent(Int.self, forKey: .lowHealthDays) ?? 0,
            crunchWeeks: try c.decodeIfPresent(Int.self, forKey: .crunchWeeks) ?? 0
        )
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        if opened { try c.encode(opened, forKey: .opened) }
        if !owned.isEmpty { try c.encode(owned.sorted { $0.catalogID < $1.catalogID }, forKey: .owned) }
        if !ailments.isEmpty { try c.encode(ailments.sorted { $0.id < $1.id }, forKey: .ailments) }
        if !vices.isEmpty {
            try c.encode(
                vices.keys.sorted().map { AssetViceEntry(id: $0, dependency: vices[$0] ?? 0) },
                forKey: .vices
            )
        }
        try c.encodeIfPresent(crypto, forKey: .crypto)
        try c.encodeIfPresent(ticket, forKey: .ticket)
        if !quits.isEmpty { try c.encode(quits.sorted { $0.viceID < $1.viceID }, forKey: .quits) }
        if stakedThisWeek != 0 { try c.encode(stakedThisWeek, forKey: .stakedThisWeek) }
        try c.encodeIfPresent(lastTherapyDay, forKey: .lastTherapyDay)
        if !intervened.isEmpty { try c.encode(intervened.sorted(), forKey: .intervened) }
        if lowMoodDays != 0 { try c.encode(lowMoodDays, forKey: .lowMoodDays) }
        if lowHealthDays != 0 { try c.encode(lowHealthDays, forKey: .lowHealthDays) }
        if crunchWeeks != 0 { try c.encode(crunchWeeks, forKey: .crunchWeeks) }
    }
}

// MARK: - Derived founder facts

extension GameState {
    /// What the founder's things would fetch if they sold them all today —
    /// the catalog's resale fraction of what they paid, docked while
    /// something is off the road. This is what `founderNetWorth` adds.
    public func assetResaleValue(balance: BalanceConfig) -> Int {
        assets.owned.reduce(0) { total, owned in
            guard let def = balance.assets.asset(owned.catalogID) else { return total }
            let base = Double(def.price) * def.resaleFraction
            let docked = owned.needsRepair ? base * balance.assets.brokenResaleFactor : base
            return total + Int(docked.rounded())
        } + (assets.crypto?.value ?? 0)
    }

    // MARK: Iteration 11, wave two — W2 (family drama): the split

    /// What one owned thing would fetch today — the single row of
    /// `assetResaleValue`, exposed so the divorce sheet can print a price
    /// next to every line it asks the player to drag.
    public func assetResaleValue(of owned: AssetOwned, balance: BalanceConfig) -> Int {
        guard let def = balance.assets.asset(owned.catalogID) else { return 0 }
        let base = Double(def.price) * def.resaleFraction
        let docked = owned.needsRepair ? base * balance.assets.brokenResaleFactor : base
        return Int(docked.rounded())
    }

    /// What a proposed settlement is worth to each side, before the roof
    /// and before the cheque: pure, so the sheet's running total and the
    /// engine's arithmetic can never disagree.
    public func assetSplitValue(
        keeping ids: Set<String>, balance: BalanceConfig
    ) -> (mine: Int, theirs: Int) {
        var mine = 0
        var theirs = 0
        for owned in assets.owned {
            let value = assetResaleValue(of: owned, balance: balance)
            let kept = ids.contains(owned.catalogID)
                || (ids.contains("pet") && !owned.petName.isEmpty)
            if kept { mine += value } else { theirs += value }
        }
        let crypto = assets.crypto?.value ?? 0
        mine += crypto / 2
        theirs += crypto - crypto / 2
        return (mine, theirs)
    }

    // MARK: end of Iteration 11, wave two — W2

    /// What the founder's things cost them every week, net of any rent
    /// coming the other way. Positive means the wallet is lighter.
    public func assetWeeklyCosts(balance: BalanceConfig) -> Int {
        assets.owned.reduce(0) { total, owned in
            guard let def = balance.assets.asset(owned.catalogID) else { return total }
            return total + def.weeklyCost - (owned.letOut ? def.weeklyRent : 0)
        }
    }

    // MARK: The refusals

    // Rule 7: every action shows its consequence on the button, and a
    // refused one says why. `AssetsSystem` is internal — the app cannot
    // see it — so each gate is published here in the founder's own words,
    // and the system's handler asks the same function before it does
    // anything. One rule, one sentence, no drift between the button and
    // the reducer.

    /// Why the founder cannot buy `catalogID` today, or `nil`.
    public func assetBuyBlocker(_ catalogID: String, balance: BalanceConfig) -> String? {
        AssetsSystem.buyBlocker(catalogID, state: self, balance: balance)
    }

    /// Why the bill cannot be paid today, or `nil`.
    public func assetRepairBlocker(_ catalogID: String, balance: BalanceConfig) -> String? {
        AssetsSystem.repairBlocker(catalogID, state: self, balance: balance)
    }

    /// What one owned thing would fetch today.
    public func assetSalePrice(_ catalogID: String, balance: BalanceConfig) -> Int {
        guard let owned = assets.asset(catalogID), let def = balance.assets.asset(catalogID) else { return 0 }
        return AssetsSystem.resalePrice(owned, def, balance)
    }

    /// Why the course of treatment cannot start today, or `nil`.
    public func assetTreatBlocker(_ ailmentID: String, balance: BalanceConfig) -> String? {
        AssetsSystem.treatBlocker(ailmentID, state: self, balance: balance)
    }

    /// Why there is no hour on the couch this week, or `nil`.
    public func assetTherapyBlocker(balance: BalanceConfig) -> String? {
        AssetsSystem.therapyBlocker(state: self, balance: balance)
    }

    /// Why tonight cannot be an evening off it, or `nil`.
    public func assetQuitBlocker(_ viceID: String, balance: BalanceConfig) -> String? {
        AssetsSystem.quitBlocker(viceID, state: self, balance: balance)
    }

    /// Why that stake cannot go on that table, or `nil`.
    public func assetGambleBlocker(_ gameID: String, stake: Int, balance: BalanceConfig) -> String? {
        AssetsSystem.gambleBlocker(gameID, stake: stake, state: self, balance: balance)
    }

    /// Why there is no ticket this week, or `nil`.
    public func assetTicketBlocker(balance: BalanceConfig) -> String? {
        AssetsSystem.ticketBlocker(state: self, balance: balance)
    }

    /// Why that trade cannot happen, or `nil`.
    public func assetTradeBlocker(dollars: Int, balance: BalanceConfig) -> String? {
        AssetsSystem.tradeBlocker(dollars: dollars, state: self, balance: balance)
    }

    /// The daily mood the founder's things are worth: a dog at the door, a
    /// cabin they can go to, a car that starts. Halved while the thing is
    /// off the road.
    public func assetMoodDrift(balance: BalanceConfig) -> Double {
        assets.owned.reduce(0.0) { total, owned in
            guard let def = balance.assets.asset(owned.catalogID) else { return total }
            return total + (owned.needsRepair ? def.moodDrift / 2 : def.moodDrift)
        }
    }
}
