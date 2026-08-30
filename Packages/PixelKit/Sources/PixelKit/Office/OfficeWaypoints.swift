import Foundation

/// A place in the office worth walking to.
public enum WaypointKind: String, Sendable, Equatable, Hashable, CaseIterable {
    /// The way in and out. Hires arrive here; leavers exit here.
    case door
    /// The coffee machine or, in the smaller tiers, the kitchenette.
    case coffee
    /// One of the standing spots around the flip-chart easel.
    case whiteboard
    /// Beside a plant — the classic "just stretching my legs" destination.
    case plant
    /// Against the back wall under a window, staring out of it.
    case window
    /// In front of the arcade cabinet / foosball table.
    case gameRoom
    /// At a cafeteria table.
    case cafeteria
    /// On the treadmill or by the weight rack.
    case gym
    /// A spot on the open floor with nothing in particular there — where
    /// people wander when they have nothing to do.
    case loiter
    /// Beside someone else's desk, close enough to talk.
    case deskside
}

/// One reservable standing spot.
///
/// `anchor` is a **feet** point: the x is the centre of the person's
/// 14-pixel-wide sprite and the y is the ground they stand on, so a sprite
/// is drawn at `(anchor.x - width/2, anchor.y - height)`. Anchors are whole
/// pixels because everything in this world is.
public struct Waypoint: Sendable, Equatable, Hashable, Identifiable {
    public var id: String
    public var kind: WaypointKind
    public var anchor: ScenePoint

    public init(id: String, kind: WaypointKind, anchor: ScenePoint) {
        self.id = id
        self.kind = kind
        self.anchor = anchor
    }
}

/// The office's walkable geography: where the corridor runs, where the
/// desks are, and every spot people go when they are not at one.
///
/// The layout it derives from is `SceneComposer.Layout`, so waypoints can
/// never drift away from the furniture they are named after.
public enum OfficeWaypoints {
    /// How fast people walk, in scene pixels per second. Slow enough to
    /// read as a stroll at 12 fps, fast enough that a campus crossing does
    /// not eat a whole minute.
    public static let walkSpeed: Double = 24

    /// Half a person's width — the offset from a feet anchor to the
    /// sprite's left edge.
    static let personHalfWidth = 7

    /// The one horizontal lane everybody travels along: the strip of floor
    /// at the very front of the room, clear of every desk, prop and amenity
    /// zone. Walking it puts people in front of the furniture, which is
    /// exactly where a walker should read.
    public static func corridorY(for tier: OfficeTierStyle) -> Double {
        Double(SceneComposer.sceneSize(for: tier).height - 1)
    }

    /// The clear vertical lanes between desk columns.
    ///
    /// A desk is 24 px wide inside a 30 px cell, so the boundary between
    /// two columns leaves a six-pixel channel — narrow, but wide enough for
    /// a person's *feet* (the four middle pixels of a 14-wide sprite) to
    /// pass without standing on a desk. Walking these instead of straight
    /// down through the rows is what keeps people out of the furniture.
    /// Only the interior boundaries are used: the outer edges are where the
    /// tiers park their plants, toolboxes and coffee machines.
    public static func lanes(for tier: OfficeTierStyle) -> [Double] {
        let l = SceneComposer.layout(for: tier)
        guard l.cols > 1 else { return [] }
        return (1..<l.cols).map {
            Double(SceneComposer.Layout.sideMargin + $0 * SceneComposer.Layout.cellWidth)
        }
    }

    /// Where a person stands when they get up from desk `index` — just
    /// below their own desk, in their row's gap.
    public static func deskAnchor(tier: OfficeTierStyle, index: Int) -> ScenePoint {
        let cell = SceneComposer.cellOrigin(tier: tier, index: index)
        return ScenePoint(
            x: cell.x + SceneComposer.Layout.cellWidth / 2,
            y: cell.y + SceneComposer.Layout.cellHeight - 1
        )
    }

    /// A spot beside desk `index`, close enough for a conversation without
    /// standing on top of the person sitting there.
    public static func desksideAnchor(tier: OfficeTierStyle, index: Int) -> ScenePoint {
        let anchor = deskAnchor(tier: tier, index: index)
        let size = SceneComposer.sceneSize(for: tier)
        // Prefer the right-hand side; hug the left when the desk is at the
        // very edge of the room.
        let x = anchor.x + 13 > Double(size.width - personHalfWidth)
            ? anchor.x - 13
            : anchor.x + 13
        return ScenePoint(x: x, y: anchor.y)
    }

    /// Where the coffee is, and whether the director has to draw it.
    ///
    /// The studio and campus have WS-D's wall coffee machine; the garage
    /// and the loft get the runtime's own kitchenette so a coffee run has
    /// somewhere to go in every tier.
    static func coffee(for tier: OfficeTierStyle) -> (anchor: ScenePoint, kitchenette: (x: Int, y: Int)?) {
        let l = SceneComposer.layout(for: tier)
        let size = SceneComposer.sceneSize(for: tier)
        switch tier {
        case .garage:
            // The one clear patch of back wall, left of the whiteboard.
            let origin = (x: 16, y: 4)
            return (ScenePoint(x: origin.x + 6, y: l.rowsStartY), origin)
        case .loft:
            // Between the whiteboard and the right-hand window.
            let origin = (x: 68, y: 3)
            return (ScenePoint(x: origin.x + 6, y: l.rowsStartY), origin)
        case .studio:
            // Machine at (width - 12, wallHeight + 3), 9×11.
            return (ScenePoint(x: size.width - 20, y: l.wallHeight + 20), nil)
        case .campus:
            // Machine at (width - 12, height - 20), 9×11.
            return (ScenePoint(x: size.width - 22, y: size.height - 7), nil)
        }
    }

    /// Where the huddle easel is parked when a huddle is on: centred in the
    /// front corridor, out of the desk grid entirely.
    static func easelOrigin(for tier: OfficeTierStyle) -> (x: Int, y: Int) {
        let size = SceneComposer.sceneSize(for: tier)
        return (x: size.width / 2 - 8, y: size.height - 23)
    }

    /// Every spot in the office, for a tier and its built amenities.
    ///
    /// Ordered and deterministic: the same arguments always produce the
    /// same list in the same order, which is what lets the director hand
    /// out waypoints by index without a tie-break.
    public static func all(for tier: OfficeTierStyle, amenities: Set<AmenityStyle>) -> [Waypoint] {
        let l = SceneComposer.layout(for: tier)
        let size = SceneComposer.sceneSize(for: tier)
        let rows = SceneComposer.deskRows(for: tier, cols: l.cols)
        let founderY = l.rowsStartY + rows * SceneComposer.Layout.cellHeight + SceneComposer.Layout.founderGap
        let corridor = corridorY(for: tier)
        var waypoints: [Waypoint] = []

        // The door. In the garage it is the roller door on the back wall;
        // everywhere else people come in from the front-left.
        let door: ScenePoint = tier == .garage
            ? ScenePoint(x: size.width - 20, y: l.wallHeight + 14)
            : ScenePoint(x: 10, y: corridor)
        waypoints.append(Waypoint(id: "door", kind: .door, anchor: door))

        waypoints.append(Waypoint(id: "coffee", kind: .coffee, anchor: coffee(for: tier).anchor))

        // Three standing spots around the easel, shoulder to shoulder.
        let easel = easelOrigin(for: tier)
        for (index, dx) in [-14, 16, 30].enumerated() {
            waypoints.append(Waypoint(
                id: "whiteboard.\(index)",
                kind: .whiteboard,
                anchor: ScenePoint(x: Double(easel.x + 8 + dx), y: corridor)
            ))
        }

        // Beside the plants, and under the windows on the back wall — the
        // two "I need to look at something that isn't a screen" spots.
        for (index, plant) in plantAnchors(for: tier, size: size, layout: l).enumerated() {
            waypoints.append(Waypoint(id: "plant.\(index)", kind: .plant, anchor: plant))
        }
        for (index, window) in windowAnchors(for: tier, size: size, layout: l).enumerated() {
            waypoints.append(Waypoint(id: "window.\(index)", kind: .window, anchor: window))
        }

        // Amenity zones, from the same rectangles the props are laid out in.
        let shown = SceneComposer.shownAmenities(for: tier, amenities: amenities)
        for frame in SceneComposer.zoneFrames(for: tier, shown: shown, size: size, founderY: founderY) {
            let kind: WaypointKind
            switch frame.amenity {
            case .gameRoom: kind = .gameRoom
            case .cafeteria: kind = .cafeteria
            case .gym: kind = .gym
            case .shuttle: continue // a window on the wall, not a place to stand
            }
            let slots = frame.amenity == .cafeteria ? 3 : 2
            for slot in 0..<slots {
                let x = frame.x + frame.width * (slot + 1) / (slots + 1)
                waypoints.append(Waypoint(
                    id: "\(kind.rawValue).\(slot)",
                    kind: kind,
                    anchor: ScenePoint(x: Double(x), y: corridor)
                ))
            }
        }

        // Somewhere to drift to when there is nothing to do.
        for slot in 0..<4 {
            let x = size.width * (slot + 1) / 5
            waypoints.append(Waypoint(
                id: "loiter.\(slot)",
                kind: .loiter,
                anchor: ScenePoint(x: Double(x), y: corridor)
            ))
        }
        return waypoints
    }

    /// Standing room beside each plant the tier puts on the floor.
    private static func plantAnchors(
        for tier: OfficeTierStyle, size: SceneComposer.SceneSize, layout l: SceneComposer.Layout
    ) -> [ScenePoint] {
        switch tier {
        case .garage:
            return [ScenePoint(x: 16, y: l.wallHeight + 22)]
        case .loft:
            return [
                ScenePoint(x: 16, y: l.wallHeight + 22),
                ScenePoint(x: size.width - 20, y: size.height - 2),
            ]
        case .studio:
            return [ScenePoint(x: 16, y: l.wallHeight + 22)]
        case .campus:
            return [
                ScenePoint(x: 16, y: l.wallHeight + 22),
                ScenePoint(x: size.width - 18, y: l.wallHeight + 22),
            ]
        }
    }

    /// Standing room against the back wall, under each window. The desks in
    /// front are drawn over the legs, which is what sells the depth.
    private static func windowAnchors(
        for tier: OfficeTierStyle, size: SceneComposer.SceneSize, layout l: SceneComposer.Layout
    ) -> [ScenePoint] {
        let y = Double(l.rowsStartY)
        switch tier {
        case .garage:
            return []
        case .loft:
            return [ScenePoint(x: 20, y: y), ScenePoint(x: Double(size.width - 20), y: y)]
        case .studio:
            return []
        case .campus:
            let step = (size.width - 44) / 3
            return (0..<4).map { ScenePoint(x: Double(22 + $0 * step), y: y) }
        }
    }

    /// Every rectangle a walker's feet must stay out of: desks, floor props
    /// and amenity furniture.
    ///
    /// People are 14 px wide and 22 px tall while the aisles between desk
    /// rows are 7 px — no sprite that size can avoid *overlapping* a desk
    /// somewhere in the room, and it should not: a walker passing a desk
    /// row is supposed to overlap it, with `zIndex` deciding who is in
    /// front. What must never happen is someone's **feet** landing inside a
    /// piece of furniture, because that reads as walking through it. These
    /// are the rectangles `OfficeDirectorTests` checks feet against.
    ///
    /// Amenity zones are deliberately *not* included. They sit in the strip
    /// between the founder's row and the front corridor, so the corridor
    /// runs along their base and a walker crossing the room passes in front
    /// of the arcade rather than through it — which is exactly what the
    /// depth sort draws.
    public static func furnitureRects(
        for tier: OfficeTierStyle, amenities: Set<AmenityStyle>
    ) -> [(x: Int, y: Int, width: Int, height: Int)] {
        let l = SceneComposer.layout(for: tier)
        let size = SceneComposer.sceneSize(for: tier)
        _ = amenities
        var rects: [(Int, Int, Int, Int)] = []

        let desk = SpriteLibrary.desk()
        for index in 0...tier.deskCapacity {
            let cell = SceneComposer.cellOrigin(tier: tier, index: index)
            rects.append((cell.x + 3, cell.y + 13, desk.width, desk.height))
        }
        for prop in SceneComposer.props(for: tier, size: size, layout: l) {
            rects.append((prop.x, prop.y, prop.sprite.width, prop.sprite.height))
        }
        return rects
    }
}
