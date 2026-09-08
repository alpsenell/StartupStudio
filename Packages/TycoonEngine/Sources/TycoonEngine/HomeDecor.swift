import Foundation

// Iteration 9 — L7 owns this file and may reshape it freely.

/// Where a piece of decor can go. Three kinds, because the pixel home has
/// three kinds of surface: a wall to hang things on, a shelf to stand
/// things on, and the floor.
public enum DecorSlotKind: String, Codable, Equatable, Sendable, CaseIterable {
    case wall, shelf, floor
    // MARK: Iteration 11 — N3 (assets, vices and the doctor)
    /// The space outside the window that a car stands in, and the corner
    /// of the room the animal has decided is theirs. Neither can be
    /// bought in the shop — only N3's catalog fills them — so a run that
    /// never opens the Assets screen sees two slots that are always
    /// empty, which is exactly what an empty driveway looks like.
    case driveway, basket
    // MARK: end of Iteration 11 — N3

    /// How the sheet names an empty one.
    public var emptyName: String {
        switch self {
        case .wall: "Empty wall"
        case .shelf: "Empty shelf"
        case .floor: "Empty corner"
        // MARK: Iteration 11 — N3
        case .driveway: "Empty driveway"
        case .basket: "No animal"
        // MARK: end of Iteration 11 — N3
        }
    }

    /// Where an item goes, said on the shop row.
    public var placementPhrase: String {
        switch self {
        case .wall: "hangs on the wall"
        case .shelf: "stands on a shelf"
        case .floor: "stands on the floor"
        // MARK: Iteration 11 — N3
        case .driveway: "sits on the drive"
        case .basket: "lives here now"
        // MARK: end of Iteration 11 — N3
        }
    }
}

/// One place in the home, named by the tier that has it.
///
/// The ids are shared with `PixelKit.HomeSceneComposer.decorSlots(for:)`,
/// which owns the pixel anchor for each one. Both lists are ordered
/// A → D and the letter is the tier that unlocks it: A comes with the
/// studio flat, D with the penthouse.
public struct DecorSlot: Identifiable, Equatable, Sendable {
    public let id: String
    public let kind: DecorSlotKind
    /// What the sheet calls it: "The wall over the couch".
    public let name: String

    public init(id: String, kind: DecorSlotKind, name: String) {
        self.id = id
        self.kind = kind
        self.name = name
    }
}

/// Where a piece of decor came from — the caption under it in the sheet.
public enum DecorSource: Equatable, Sendable {
    /// Bought in the shop; the id is also the `instantLife.items` key.
    case shop
    /// Everybody has one.
    case free
    /// A poster from a season that was finished.
    case season
    /// A trophy from an ending that was reached.
    case ending
    /// The pennant from a night the company won something.
    case award
    /// The record from the first product good enough for the hall.
    case hall
    // MARK: Iteration 10 — M5 (morning desk)
    /// Earned by a run of mornings at the desk.
    case streak
    // MARK: end of Iteration 10 — M5
    // MARK: Iteration 11 — N3 (assets, vices and the doctor)
    /// Bought with the founder's own money, off the Assets screen.
    case asset
    // MARK: end of Iteration 11 — N3

    public var caption: String {
        switch self {
        case .shop: "Bought"
        case .free: "Free — everybody gets one"
        case .season: "Earned in a season"
        case .ending: "Earned by an ending"
        case .award: "Earned at the awards"
        case .hall: "Earned by the Hall of Fame"
        // MARK: Iteration 10 — M5 (morning desk)
        case .streak: "Earned at the morning desk"
        // MARK: end of Iteration 10 — M5
        // MARK: Iteration 11 — N3
        case .asset: "Yours, and insured"
        // MARK: end of Iteration 11 — N3
        }
    }
}

/// A thing that can stand in a slot: the five shop possessions plus the
/// decor the ledger earns.
public struct DecorItem: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    /// The one kind of slot it fits.
    public let kind: DecorSlotKind
    public let source: DecorSource
    /// One line under the name in the furnish sheet.
    public let note: String

    public init(id: String, name: String, kind: DecorSlotKind, source: DecorSource, note: String) {
        self.id = id
        self.name = name
        self.kind = kind
        self.source = source
        self.note = note
    }
}

/// A decor item standing in a slot.
public struct PlacedDecor: Codable, Equatable, Sendable, Identifiable {
    /// One item per slot, so the slot is the identity.
    public var id: String { slot }
    public var slot: String
    public var itemID: String

    public init(slot: String, itemID: String) {
        self.slot = slot
        self.itemID = itemID
    }
}

/// What is standing where in the home, and which home it was arranged for.
///
/// Moving keeps the possessions and empties the slots: the new place has
/// its own walls. That is `arrangedFor` — a tier that no longer matches
/// reads as an empty home rather than dropping the record, so a save that
/// moves and moves back is not punished for it.
public struct HomeDecorState: Codable, Equatable, Sendable {
    public var placed: [PlacedDecor]
    /// The `HomeTier` raw value the arrangement belongs to.
    public var arrangedFor: String?

    public init(placed: [PlacedDecor] = [], arrangedFor: String? = nil) {
        self.placed = placed
        self.arrangedFor = arrangedFor
    }

    public static let empty = HomeDecorState()

    private enum CodingKeys: String, CodingKey {
        case placed, arrangedFor
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        placed = try container.decodeIfPresent([PlacedDecor].self, forKey: .placed) ?? []
        arrangedFor = try container.decodeIfPresent(String.self, forKey: .arrangedFor)
    }

    /// What is on show in `tier`: nothing at all once the founder has
    /// moved, because the boxes are not unpacked yet.
    public func placed(in tier: HomeTier) -> [PlacedDecor] {
        guard arrangedFor == tier.rawValue else { return [] }
        let ids = Set(HomeDecor.slots(for: tier).map(\.id))
        return placed.filter { ids.contains($0.slot) }
    }

    /// The item in one slot of `tier`, if any.
    public func item(in slot: String, tier: HomeTier) -> String? {
        placed(in: tier).first { $0.slot == slot }?.itemID
    }
}

/// The slot table, the catalog, and the two rules that decide whether a
/// thing can stand somewhere. Pure — no state, no randomness, no cost.
public enum HomeDecor {
    // MARK: Slots

    /// Every slot the game knows, in tier order. A tier gets every slot
    /// whose `tierRank` is at or below its own, so the studio has three
    /// and the penthouse twelve.
    static let allSlots: [(slot: DecorSlot, tierRank: Int)] = [
        (DecorSlot(id: "wallA", kind: .wall, name: "The wall by the door"), 0),
        (DecorSlot(id: "shelfA", kind: .shelf, name: "The kitchen shelf"), 0),
        (DecorSlot(id: "floorA", kind: .floor, name: "The corner by the window"), 0),
        (DecorSlot(id: "wallB", kind: .wall, name: "The wall over the couch"), 1),
        (DecorSlot(id: "shelfB", kind: .shelf, name: "The shelf over the bed"), 1),
        (DecorSlot(id: "floorB", kind: .floor, name: "The far corner"), 1),
        (DecorSlot(id: "wallC", kind: .wall, name: "The chimney breast"), 2),
        (DecorSlot(id: "shelfC", kind: .shelf, name: "The hallway shelf"), 2),
        (DecorSlot(id: "floorC", kind: .floor, name: "Beside the table"), 2),
        (DecorSlot(id: "wallD", kind: .wall, name: "The long wall"), 3),
        (DecorSlot(id: "shelfD", kind: .shelf, name: "The display shelf"), 3),
        (DecorSlot(id: "floorD", kind: .floor, name: "By the glass"), 3),
        // MARK: Iteration 11 — N3 (assets, vices and the doctor)
        // Every home has somewhere to park and somewhere for the animal,
        // including the studio flat — which parks on the street and puts
        // the basket by the radiator, but the founder would not put it
        // that way.
        (DecorSlot(id: "drivewayA", kind: .driveway, name: "The space outside"), 0),
        (DecorSlot(id: "basketA", kind: .basket, name: "The corner by the radiator"), 0),
        // MARK: end of Iteration 11 — N3
    ]

    /// The slots a home tier has, in reading order.
    public static func slots(for tier: HomeTier) -> [DecorSlot] {
        allSlots.filter { $0.tierRank <= tier.rank }.map(\.slot)
    }

    public static func slot(_ id: String) -> DecorSlot? {
        allSlots.first { $0.slot.id == id }?.slot
    }

    // MARK: Catalog

    /// The five shop possessions, as things that stand somewhere. The ids
    /// are the `instantLife.items` keys, so owning one is owning this.
    public static let shopItems: [DecorItem] = [
        DecorItem(
            id: "espressoMachine", name: "Espresso machine", kind: .shelf, source: .shop,
            note: "It hisses at seven every morning."
        ),
        DecorItem(
            id: "gamingConsole", name: "Gaming console", kind: .shelf, source: .shop,
            note: "Two controllers. One of them is never used."
        ),
        DecorItem(
            id: "roadBike", name: "Road bike", kind: .floor, source: .shop,
            note: "Indoors, because outdoors it would be gone."
        ),
        DecorItem(
            id: "designerWatch", name: "Designer watch", kind: .shelf, source: .shop,
            note: "On its stand, winding itself, saying nothing."
        ),
        DecorItem(
            id: "sportsCar", name: "The car, in model form", kind: .shelf, source: .shop,
            note: "The real one is downstairs. This one is the point."
        ),
    ]

    /// Decor that is earned rather than bought. Free to place.
    public static let earnedItems: [DecorItem] = [
        DecorItem(
            id: "plant", name: "House plant", kind: .floor, source: .free,
            note: "Water it or don't. It is not judging you."
        ),
        DecorItem(
            id: "recordPlayer", name: "Record player", kind: .shelf, source: .hall,
            note: "One good record, played until the household objected."
        ),
        DecorItem(
            id: "pennant", name: "Awards pennant", kind: .wall, source: .award,
            note: "You went up for it in a borrowed jacket."
        ),
    ] + seasonPosters + endingTrophies + deskItems

    // MARK: Iteration 10 — M5 (morning desk)

    /// The three things a streak of mornings puts on the wall and the
    /// shelf. The ids are `DeskRewards`' own, so the table in
    /// `MorningDesk.swift` is the only place a rung is written down; a
    /// ledger that has not earned one simply does not carry the id, and
    /// an id from a build that no longer knows it is ignored the way
    /// every other unknown decor id is.
    public static let deskItems: [DecorItem] = [
        DecorItem(
            id: "deskSunrise", name: "Sunrise over the desk", kind: .wall, source: .streak,
            note: "Three mornings running. The sun is doing its best."
        ),
        DecorItem(
            id: "deskPlaque", name: "The morning plaque", kind: .shelf, source: .streak,
            note: "Brass, small, and nobody has ever asked about it."
        ),
        DecorItem(
            id: "deskCentury", name: "One hundred mornings", kind: .wall, source: .streak,
            note: "A hundred of them. Nobody has to know what it means."
        ),
    ]

    // MARK: end of Iteration 10 — M5

    /// One poster per season twist — the season you lived through, on
    /// your wall.
    public static let seasonPosters: [DecorItem] = SeasonTwist.allCases.map { twist in
        DecorItem(
            id: posterID(for: twist), name: "\(posterTitle(twist)) poster", kind: .wall, source: .season,
            note: "A season you saw out."
        )
    }

    /// One trophy per ending — including the two nobody frames on purpose.
    public static let endingTrophies: [DecorItem] = [
        EndingKind.ipo, .acquired, .independent, .soldUp, .oustedByBoard, .bankruptcy,
    ].map { kind in
        DecorItem(
            id: trophyID(for: kind), name: trophyName(kind), kind: .shelf, source: .ending,
            note: trophyNote(kind)
        )
    }

    // MARK: Iteration 11 — N3 (assets, vices and the doctor)

    /// The id a bought asset takes in the decor catalog: `asset_coupe`,
    /// `asset_dog`. Prefixed so it can never collide with a shop
    /// possession's id (`sportsCar` is the model on the shelf; the real
    /// one is `asset_coupe` on the drive).
    public static func assetDecorID(_ catalogID: String) -> String { "asset_\(catalogID)" }

    /// The one slot each kind of asset stands in, or `nil` for the ones
    /// that stand nowhere (a second property is not in the room).
    public static func assetSlotID(for kind: AssetKind) -> String? {
        switch kind {
        case .car: "drivewayA"
        case .pet: "basketA"
        case .property: nil
        }
    }

    /// The driveway, by name, for the day the car is not there any more.
    public static let drivewaySlotID = "drivewayA"

    /// The cars and the pets as things that stand somewhere. Built off
    /// N3's shipped catalog ids so the two lists cannot drift apart; a
    /// balance file that renames a car simply leaves an unknown decor id,
    /// which is ignored the way every other unknown one is.
    public static let assetItems: [DecorItem] = [
        (id: "hatchback", name: "The hatchback", note: "Parked at an angle. It has always been parked at an angle."),
        (id: "estate", name: "The estate", note: "Boot full of things that live in the boot."),
        (id: "coupe", name: "The coupé", note: "Washed more often than the flat is cleaned."),
        (id: "supercar", name: "The one with the doors", note: "Takes up two spaces and knows it."),
    ].map {
        DecorItem(id: assetDecorID($0.id), name: $0.name, kind: .driveway, source: .asset, note: $0.note)
    } + [
        (id: "dog", name: "The dog", note: "Asleep in the one patch of sun."),
        (id: "cat", name: "The cat", note: "Awake. Watching. Unimpressed."),
        (id: "tortoise", name: "The tortoise", note: "Has moved four inches since Tuesday."),
    ].map {
        DecorItem(id: assetDecorID($0.id), name: $0.name, kind: .basket, source: .asset, note: $0.note)
    }

    // MARK: end of Iteration 11 — N3

    /// Everything, shop and earned.
    public static let catalog: [DecorItem] = shopItems + earnedItems + assetItems

    public static func item(_ id: String) -> DecorItem? {
        catalog.first { $0.id == id }
    }

    public static func posterID(for twist: SeasonTwist) -> String { "poster_\(twist.rawValue)" }
    public static func trophyID(for kind: EndingKind) -> String { "trophy_\(kind.rawValue)" }

    private static func posterTitle(_ twist: SeasonTwist) -> String {
        switch twist {
        case .platformLaunch: "Platform launch"
        case .fundingWinter: "Funding winter"
        case .crashSeason: "Crash season"
        case .poachingSeason: "Poaching season"
        case .pressYear: "Press year"
        }
    }

    private static func trophyName(_ kind: EndingKind) -> String {
        switch kind {
        case .ipo: "The bell"
        case .acquired: "The acquisition cube"
        case .independent: "The plain one"
        case .soldUp: "The paperweight"
        case .oustedByBoard: "The board's gift"
        case .bankruptcy: "The last invoice"
        // Iteration 9 — L2's seventh ending, the one L7 left room for.
        case .walkedAway: "The house keys"
        }
    }

    private static func trophyNote(_ kind: EndingKind) -> String {
        switch kind {
        case .ipo: "Engraved with a date you remember badly."
        case .acquired: "Perspex, heavy, somebody else's logo."
        case .independent: "No logo at all. That was the point."
        case .soldUp: "It holds paper down. It is good at that."
        case .oustedByBoard: "They had it made before the vote."
        case .bankruptcy: "Framed. Everyone should have one."
        case .walkedAway: "Still on the hook by the door. You never gave them back."
        }
    }

    // MARK: Rules

    /// Whether `item` may stand in `slot` of `tier` — the slot exists here
    /// and it is the right kind of slot for the thing.
    public static func fits(itemID: String, slot slotID: String, tier: HomeTier) -> Bool {
        guard let item = item(itemID), let slot = slot(slotID),
              slots(for: tier).contains(where: { $0.id == slotID })
        else { return false }
        return item.kind == slot.kind
    }

    /// The first empty slot in `tier` an item would fit, in reading order.
    /// This is what a purchase uses to put itself away.
    public static func firstEmptySlot(for itemID: String, tier: HomeTier, decor: HomeDecorState) -> String? {
        guard let item = item(itemID) else { return nil }
        let taken = Set(decor.placed(in: tier).map(\.slot))
        return slots(for: tier).first { $0.kind == item.kind && !taken.contains($0.id) }?.id
    }

    /// Puts `itemID` in `slotID`, moving it out of any slot it was already
    /// in and evicting whatever was standing there. Returns false — and
    /// changes nothing — when it does not fit.
    @discardableResult
    public static func place(itemID: String, slot slotID: String, tier: HomeTier, decor: inout HomeDecorState) -> Bool {
        guard fits(itemID: itemID, slot: slotID, tier: tier) else { return false }
        var placed = decor.placed(in: tier)
        placed.removeAll { $0.slot == slotID || $0.itemID == itemID }
        placed.append(PlacedDecor(slot: slotID, itemID: itemID))
        placed.sort { $0.slot < $1.slot }
        decor.placed = placed
        decor.arrangedFor = tier.rawValue
        return true
    }

    /// Empties one slot. False when there was nothing in it.
    @discardableResult
    public static func remove(slot slotID: String, tier: HomeTier, decor: inout HomeDecorState) -> Bool {
        var placed = decor.placed(in: tier)
        guard placed.contains(where: { $0.slot == slotID }) else { return false }
        placed.removeAll { $0.slot == slotID }
        decor.placed = placed
        decor.arrangedFor = tier.rawValue
        return true
    }
}
