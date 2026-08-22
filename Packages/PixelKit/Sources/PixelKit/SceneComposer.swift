/// What a placement is, for draw-order reasoning and testing.
public enum PlacementKind: Sendable, Equatable, Hashable {
    case room, prop, desk, monitor, person, bubble
    // Home scenes. The founder is `.person`; `.prop` is reused for small
    // hand-held extras (controller, book) and `.bubble` for mood/zzz.
    /// A piece of home furniture or decor, tagged so layouts can be inspected.
    case homeProp(SpriteLibrary.HomePropName)
    /// The founder's partner.
    case partner
    /// A small child sprite.
    case child
    /// The in-crib baby bundle.
    case baby
}

/// How a placed sprite animates. Cosmetic only — the scene view drives it
/// from a periodic timeline, never from the game simulation.
public enum SpriteAnimation: Sendable, Equatable, Hashable {
    case still
    /// 7-tick cycle A,B,A,B,A,B,blink. `slow` halves the tick rate (idle).
    case typing(slow: Bool)
    /// 2-frame screen glow.
    case glow
    /// Two frames alternating every `period` ticks — breathing, bouncing,
    /// rocking, controller wiggle.
    case toggle(period: Int)
}

/// One sprite positioned in scene pixel coordinates (origin top-left).
public struct PlacedSprite: Sendable, Equatable {
    public var sprite: PixelSprite
    public var x: Int
    public var y: Int
    public var kind: PlacementKind
    public var animation: SpriteAnimation
    /// Per-placement offset into the animation cycle so neighbours desync.
    public var phase: Int

    public init(sprite: PixelSprite, x: Int, y: Int, kind: PlacementKind, animation: SpriteAnimation, phase: Int) {
        self.sprite = sprite
        self.x = x
        self.y = y
        self.kind = kind
        self.animation = animation
        self.phase = phase
    }

    /// Which frame to draw at a global animation tick (~4 ticks/second).
    public func frameIndex(atTick tick: Int) -> Int {
        let t = max(0, tick)
        let index: Int
        switch animation {
        case .still:
            index = 0
        case .typing(let slow):
            let step = ((slow ? t / 2 : t) + phase) % 7
            index = [0, 1, 0, 1, 0, 1, 2][step]
        case .glow:
            index = (t / 2 + phase) % 2
        case .toggle(let period):
            index = (t / max(1, period) + phase) % 2
        }
        return min(index, sprite.frameCount - 1)
    }
}

/// Pure scene layout: turns a tier + occupants into an ordered (back-to-front)
/// list of placed sprites. `OfficeSceneView` and the PNG preview renderer both
/// draw exactly this list, so what tests see is what ships.
public enum SceneComposer {
    public struct SceneSize: Sendable, Equatable {
        public let width: Int
        public let height: Int
    }

    // MARK: Layout constants

    private struct Layout {
        let cols: Int
        let wallHeight: Int

        static let cellWidth = 30
        static let cellHeight = 27
        static let sideMargin = 10
        static let founderGap = 6
        static let bottomMargin = 6

        var rowsStartY: Int { wallHeight - 8 } // back row overlaps the wall line slightly
    }

    private static func layout(for tier: OfficeTierStyle) -> Layout {
        switch tier {
        case .garage: Layout(cols: 3, wallHeight: 30)
        case .loft: Layout(cols: 3, wallHeight: 32)
        case .studio: Layout(cols: 5, wallHeight: 32)
        case .campus: Layout(cols: 8, wallHeight: 36)
        }
    }

    private static func deskRows(for tier: OfficeTierStyle, cols: Int) -> Int {
        (tier.deskCapacity + cols - 1) / cols
    }

    public static func sceneSize(for tier: OfficeTierStyle) -> SceneSize {
        let l = layout(for: tier)
        let rows = deskRows(for: tier, cols: l.cols)
        return SceneSize(
            width: Layout.sideMargin * 2 + l.cols * Layout.cellWidth,
            height: l.rowsStartY + rows * Layout.cellHeight
                + Layout.founderGap + Layout.cellHeight + Layout.bottomMargin
        )
    }

    // MARK: Composition

    public static func compose(tier: OfficeTierStyle, occupants: [Occupant]) -> [PlacedSprite] {
        let l = layout(for: tier)
        let size = sceneSize(for: tier)
        let rows = deskRows(for: tier, cols: l.cols)

        var scene: [PlacedSprite] = []
        scene.append(PlacedSprite(
            sprite: RoomBuilder.room(tier: tier, width: size.width, height: size.height, wallHeight: l.wallHeight),
            x: 0, y: 0, kind: .room, animation: .still, phase: 0
        ))
        scene += props(for: tier, size: size, layout: l)

        // Founder first; everyone else in given order; overflow simply unseated.
        let founders = occupants.filter(\.isFounder)
        let employees = occupants.filter { !$0.isFounder }
        let founder = founders.first
        let regulars = Array((founders.dropFirst() + employees).prefix(tier.deskCapacity))

        for index in 0..<tier.deskCapacity {
            let row = index / l.cols
            let col = index % l.cols
            let cellX = Layout.sideMargin + col * Layout.cellWidth
            let cellY = l.rowsStartY + row * Layout.cellHeight
            scene += deskCell(x: cellX, y: cellY, occupant: index < regulars.count ? regulars[index] : nil, index: index)
        }

        // Founder desk: front row, left, slightly separated.
        let founderY = l.rowsStartY + rows * Layout.cellHeight + Layout.founderGap
        scene += deskCell(x: Layout.sideMargin, y: founderY, occupant: founder, index: tier.deskCapacity)

        return scene
    }

    private static func deskCell(x: Int, y: Int, occupant: Occupant?, index: Int) -> [PlacedSprite] {
        var cell: [PlacedSprite] = []
        if let occupant {
            cell.append(PlacedSprite(
                sprite: SpriteLibrary.person(appearance: occupant.appearance, isFounder: occupant.isFounder),
                x: x + 8, y: y,
                kind: .person,
                animation: .typing(slow: occupant.status == .idle),
                phase: (index * 3) % 7
            ))
        }
        cell.append(PlacedSprite(
            sprite: SpriteLibrary.desk(), x: x + 3, y: y + 13,
            kind: .desk, animation: .still, phase: 0
        ))
        cell.append(PlacedSprite(
            sprite: SpriteLibrary.monitor(), x: x + 10, y: y + 7,
            kind: .monitor, animation: .glow, phase: index % 2
        ))
        if let occupant, occupant.status != .idle {
            cell.append(PlacedSprite(
                sprite: SpriteLibrary.statusBubble(occupant.status), x: x + 16, y: y - 8,
                kind: .bubble, animation: .still, phase: 0
            ))
        }
        return cell
    }

    private static func props(for tier: OfficeTierStyle, size: SceneSize, layout l: Layout) -> [PlacedSprite] {
        func place(_ name: SpriteLibrary.PropName, _ x: Int, _ y: Int) -> PlacedSprite {
            PlacedSprite(sprite: SpriteLibrary.prop(name), x: x, y: y, kind: .prop, animation: .still, phase: 0)
        }

        switch tier {
        case .garage:
            return [
                place(.garageDoor, size.width - 34, l.wallHeight - 16),
                place(.toolbox, 2, l.wallHeight + 1),
            ]
        case .loft:
            return [
                place(.windowDay, 14, 3),
                place(.windowDay, size.width - 26, 3),
                place(.plant, 2, l.wallHeight + 2),
                place(.plant, size.width - 11, size.height - 14),
            ]
        case .studio:
            return [
                place(.whiteboard, (size.width - 22) / 2, 4),
                place(.coffeeMachine, size.width - 12, l.wallHeight + 3),
                place(.plant, 2, l.wallHeight + 2),
            ]
        case .campus:
            let step = (size.width - 44) / 3
            var props = (0..<4).map { place(.windowDay, 16 + $0 * step, 4) }
            props.append(place(.plant, 2, l.wallHeight + 2))
            props.append(place(.plant, size.width - 10, l.wallHeight + 2))
            props.append(place(.coffeeMachine, size.width - 12, size.height - 20))
            return props
        }
    }
}
