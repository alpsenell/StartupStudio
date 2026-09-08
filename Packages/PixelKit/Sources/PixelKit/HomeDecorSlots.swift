import Foundation

// MARK: - Iteration 9 — L7: where a founder's things can go

/// The three kinds of place a home has for a thing: a wall to hang it on,
/// a shelf to stand it on, and the floor.
public enum HomeDecorSlotKind: String, Sendable, Equatable, Hashable, CaseIterable {
    case wall, shelf, floor
    // MARK: Iteration 11 — N3 (assets, vices and the doctor)
    /// The strip below the room, outside the window, where a car stands;
    /// and the spot on the floor the animal has claimed. Both are drawn
    /// only when something is in them, so a home with no car and no dog
    /// is the room it always was.
    case driveway, basket
    // MARK: end of Iteration 11 — N3
}

/// One slot in one tier's room, with its pixel anchor.
///
/// The ids match `TycoonEngine.HomeDecor.slots(for:)` — A comes with the
/// studio flat, D with the penthouse — so the engine can say what is
/// placed without knowing a single coordinate.
public struct HomeDecorSlotFrame: Sendable, Equatable, Hashable, Identifiable {
    public let id: String
    public let kind: HomeDecorSlotKind
    /// Wall: the sprite's top-left. Shelf: the plank's top-left, the item
    /// standing on top of it. Floor: the point the item stands on, so
    /// anything tall grows upward from the same line.
    public let x: Int
    public let y: Int

    init(_ id: String, _ kind: HomeDecorSlotKind, _ x: Int, _ y: Int) {
        self.id = id
        self.kind = kind
        self.x = x
        self.y = y
    }

    /// The box a finger lands on and the furnish sheet draws a marker in,
    /// in scene pixels. Generous on purpose: an empty slot has nothing in
    /// it to aim at.
    public var tapRect: (x: Int, y: Int, width: Int, height: Int) {
        switch kind {
        case .wall: (x, y, 14, 18)
        case .shelf: (x, y - 14, 16, 17)
        case .floor: (x, y - 14, 20, 14)
        // MARK: Iteration 11 — N3
        case .driveway: (x, y - 10, 24, 12)
        case .basket: (x, y - 10, 16, 11)
        // MARK: end of Iteration 11 — N3
        }
    }
}

extension HomeSceneComposer {
    /// Every slot the tier has, in reading order: the wall first, then the
    /// shelves, then the floor.
    ///
    /// Chosen by hand against each tier's `Layout` so nothing lands on the
    /// window, the stove, the bed or a child's rug: three in the studio,
    /// six in the apartment, nine in the house, twelve in the penthouse.
    public static func decorSlots(for tier: HomeTierStyle) -> [HomeDecorSlotFrame] {
        switch tier {
        case .studioFlat:
            [
                HomeDecorSlotFrame("wallA", .wall, 60, 2),
                HomeDecorSlotFrame("shelfA", .shelf, 60, 31),
                HomeDecorSlotFrame("floorA", .floor, 84, 69),
                // MARK: Iteration 11 — N3
                HomeDecorSlotFrame("drivewayA", .driveway, 2, 69),
                HomeDecorSlotFrame("basketA", .basket, 60, 69),
                // MARK: end of Iteration 11 — N3
            ]
        case .apartment:
            [
                HomeDecorSlotFrame("wallA", .wall, 26, 2),
                HomeDecorSlotFrame("wallB", .wall, 48, 2),
                HomeDecorSlotFrame("shelfA", .shelf, 18, 33),
                HomeDecorSlotFrame("shelfB", .shelf, 46, 25),
                HomeDecorSlotFrame("floorA", .floor, 8, 79),
                HomeDecorSlotFrame("floorB", .floor, 120, 79),
                // MARK: Iteration 11 — N3
                HomeDecorSlotFrame("drivewayA", .driveway, 2, 79),
                HomeDecorSlotFrame("basketA", .basket, 96, 79),
                // MARK: end of Iteration 11 — N3
            ]
        case .house:
            [
                HomeDecorSlotFrame("wallA", .wall, 24, 2),
                HomeDecorSlotFrame("wallB", .wall, 96, 2),
                HomeDecorSlotFrame("wallC", .wall, 52, 2),
                HomeDecorSlotFrame("shelfA", .shelf, 96, 41),
                HomeDecorSlotFrame("shelfB", .shelf, 14, 37),
                HomeDecorSlotFrame("shelfC", .shelf, 120, 41),
                HomeDecorSlotFrame("floorA", .floor, 6, 87),
                HomeDecorSlotFrame("floorB", .floor, 30, 87),
                HomeDecorSlotFrame("floorC", .floor, 60, 87),
                // MARK: Iteration 11 — N3
                HomeDecorSlotFrame("drivewayA", .driveway, 150, 87),
                HomeDecorSlotFrame("basketA", .basket, 120, 87),
                // MARK: end of Iteration 11 — N3
            ]
        case .penthouse:
            [
                HomeDecorSlotFrame("wallA", .wall, 10, 24),
                HomeDecorSlotFrame("wallB", .wall, 58, 24),
                HomeDecorSlotFrame("wallC", .wall, 76, 24),
                HomeDecorSlotFrame("wallD", .wall, 134, 24),
                HomeDecorSlotFrame("shelfA", .shelf, 58, 56),
                HomeDecorSlotFrame("shelfB", .shelf, 76, 56),
                HomeDecorSlotFrame("shelfC", .shelf, 130, 56),
                HomeDecorSlotFrame("shelfD", .shelf, 176, 58),
                HomeDecorSlotFrame("floorA", .floor, 10, 88),
                HomeDecorSlotFrame("floorB", .floor, 36, 88),
                HomeDecorSlotFrame("floorC", .floor, 62, 88),
                HomeDecorSlotFrame("floorD", .floor, 180, 88),
                // MARK: Iteration 11 — N3
                HomeDecorSlotFrame("drivewayA", .driveway, 172, 89),
                HomeDecorSlotFrame("basketA", .basket, 140, 89),
                // MARK: end of Iteration 11 — N3
            ]
        }
    }

    public static func decorSlot(_ id: String, tier: HomeTierStyle) -> HomeDecorSlotFrame? {
        decorSlots(for: tier).first { $0.id == id }
    }
}
