import Foundation

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
    /// A piece of office amenity furniture (game room, cafeteria, gym, shuttle).
    case amenityProp(SpriteLibrary.AmenityPropName)
    /// A city-map element (building, landmark, marker, selection border),
    /// tagged by a short name so layouts can be inspected.
    case cityProp(String)
    /// The press outline the office draws around a tapped figure or prop.
    /// Drawn just above what it outlines, below the bubbles.
    case highlight
}

/// How a placed sprite animates. Cosmetic only — the scene view drives it
/// from a timeline, never from the game simulation.
///
/// The first four modes run on the original 4-ticks-per-second modulo
/// clock and are unchanged. `.sequence` and `.once` are the animation
/// runtime's own modes: they run at an arbitrary frame rate off scene
/// *time*, anchored to `PlacedSprite.start`.
public enum SpriteAnimation: Sendable, Equatable, Hashable {
    case still
    /// 7-tick cycle A,B,A,B,A,B,blink. `slow` halves the tick rate (idle).
    case typing(slow: Bool)
    /// 2-frame screen glow.
    case glow
    /// Two frames alternating every `period` ticks — breathing, bouncing,
    /// rocking, controller wiggle.
    case toggle(period: Int)
    /// An explicit frame list played at `fps` from `PlacedSprite.start`,
    /// looping forever or holding on the last frame.
    case sequence(frames: [Int], fps: Double, loop: Bool)
    /// An explicit frame list played through exactly once from
    /// `PlacedSprite.start`, then held. Shorthand for a non-looping
    /// `.sequence` — celebrations and pops.
    case once(frames: [Int], fps: Double)
}

/// One sprite positioned in scene pixel coordinates (origin top-left).
///
/// A placement is a *value evaluated at a time*: `position(at:)` and
/// `frameIndex(at:)` take the scene clock, so the office director can hand
/// the view one list per second and still get smooth 12 fps movement out of
/// it. Placements with no `motion` sit at `(x, y)` forever, which is what
/// every first-iteration composer produces.
public struct PlacedSprite: Sendable, Equatable {
    public var sprite: PixelSprite
    public var x: Int
    public var y: Int
    public var kind: PlacementKind
    public var animation: SpriteAnimation
    /// Per-placement offset into the animation cycle so neighbours desync.
    public var phase: Int
    /// Scene time this placement's `.sequence` / `.once` animation and its
    /// `motion` are anchored to.
    public var start: TimeInterval
    /// Optional travel. When present it overrides `(x, y)` at draw time.
    public var motion: Motion?
    /// Painter's-algorithm depth. Higher draws later (in front). The default
    /// is the sprite's baseline (`y + height`) so a walker crossing the
    /// floor slides in front of the desks behind them and behind the ones in
    /// front — rooms sink to the back, bubbles float to the top.
    public var zIndex: Int
    /// 0...1 alpha, for fades (a leaver walking out, a wipe).
    public var opacity: Double
    /// Mirrors the sprite horizontally — one walk cycle serves both ways.
    public var flipX: Bool

    public init(
        sprite: PixelSprite,
        x: Int,
        y: Int,
        kind: PlacementKind,
        animation: SpriteAnimation,
        phase: Int,
        start: TimeInterval = 0,
        motion: Motion? = nil,
        zIndex: Int? = nil,
        opacity: Double = 1,
        flipX: Bool = false
    ) {
        self.sprite = sprite
        self.x = x
        self.y = y
        self.kind = kind
        self.animation = animation
        self.phase = phase
        self.start = start
        self.motion = motion
        self.zIndex = zIndex ?? Self.defaultZIndex(kind: kind, y: y, height: sprite.height)
        self.opacity = opacity
        self.flipX = flipX
    }

    /// Baseline depth for a placement that does not name its own.
    static func defaultZIndex(kind: PlacementKind, y: Int, height: Int) -> Int {
        switch kind {
        case .room: -100_000
        case .bubble: y + height + 1_000
        default: y + height
        }
    }

    /// Top-left corner at scene time `t`, snapped to whole pixels.
    public func position(at t: TimeInterval) -> (x: Int, y: Int) {
        guard let motion else { return (x, y) }
        return motion.position(at: t).rounded
    }

    /// Which frame to draw at a global animation tick (~4 ticks/second).
    ///
    /// The tick clock only drives the four original modes; `.sequence` and
    /// `.once` are time-based, so this converts the tick back into seconds
    /// for them.
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
        case .sequence, .once:
            return frameIndex(at: TimeInterval(t) / AnimationClock.legacyTicksPerSecond)
        }
        return min(index, sprite.frameCount - 1)
    }

    /// Which frame to draw at scene time `t` (seconds since the scene
    /// appeared). The single entry point the 12 fps renderer uses.
    public func frameIndex(at t: TimeInterval) -> Int {
        switch animation {
        case .still, .typing, .glow, .toggle:
            return frameIndex(atTick: AnimationClock.tick(at: t))
        case .sequence(let frames, let fps, let loop):
            return sequenceFrame(frames: frames, fps: fps, loop: loop, at: t)
        case .once(let frames, let fps):
            return sequenceFrame(frames: frames, fps: fps, loop: false, at: t)
        }
    }

    private func sequenceFrame(frames: [Int], fps: Double, loop: Bool, at t: TimeInterval) -> Int {
        guard !frames.isEmpty else { return 0 }
        let elapsed = max(0, t - start)
        let step = Int((elapsed * max(0.0001, fps)).rounded(.down)) + phase
        let index = loop
            ? frames[((step % frames.count) + frames.count) % frames.count]
            : frames[min(max(0, step), frames.count - 1)]
        return min(max(0, index), sprite.frameCount - 1)
    }

    /// Whether the placement has finished playing a `.once` animation at `t`.
    public func hasFinished(at t: TimeInterval) -> Bool {
        guard case .once(let frames, let fps) = animation, !frames.isEmpty else { return false }
        return t - start >= TimeInterval(frames.count) / max(0.0001, fps)
    }
}

/// Pure scene layout: turns a tier + occupants (+ amenities) into an ordered
/// (back-to-front) list of placed sprites. `OfficeSceneView` and the PNG
/// preview renderer both draw exactly this list, so what tests see is what
/// ships.
///
/// Amenities render as prop zones in the front row, to the right of the
/// founder's desk, and the shuttle as a back-wall window; see
/// `SceneComposer+Amenities.swift`. Scene size is fixed per tier — amenities
/// fill space the layout already reserves.
public enum SceneComposer {
    public struct SceneSize: Sendable, Equatable {
        public let width: Int
        public let height: Int
    }

    // MARK: Layout constants

    struct Layout {
        let cols: Int
        let wallHeight: Int

        static let cellWidth = 30
        static let cellHeight = 27
        static let sideMargin = 10
        static let founderGap = 6
        static let bottomMargin = 6

        var rowsStartY: Int { wallHeight - 8 } // back row overlaps the wall line slightly
    }

    static func layout(for tier: OfficeTierStyle) -> Layout {
        switch tier {
        case .garage: Layout(cols: 3, wallHeight: 30)
        case .loft: Layout(cols: 3, wallHeight: 32)
        case .studio: Layout(cols: 5, wallHeight: 32)
        case .campus: Layout(cols: 8, wallHeight: 36)
        }
    }

    static func deskRows(for tier: OfficeTierStyle, cols: Int) -> Int {
        (tier.deskCapacity + cols - 1) / cols
    }

    /// Top-left corner of a desk cell. `index` runs `0..<deskCapacity` for
    /// the regular grid; `deskCapacity` itself is the founder's own desk in
    /// the front row, left, separated from the rest.
    ///
    /// The director needs this to seat people and to work out where they
    /// stand when they get up, so it lives next to the layout constants it
    /// is derived from rather than being recomputed elsewhere.
    static func cellOrigin(tier: OfficeTierStyle, index: Int) -> (x: Int, y: Int) {
        let l = layout(for: tier)
        let rows = deskRows(for: tier, cols: l.cols)
        guard index < tier.deskCapacity else {
            return (Layout.sideMargin, l.rowsStartY + rows * Layout.cellHeight + Layout.founderGap)
        }
        return (
            Layout.sideMargin + (index % l.cols) * Layout.cellWidth,
            l.rowsStartY + (index / l.cols) * Layout.cellHeight
        )
    }

    /// Where a seated person's sprite is drawn for a desk index.
    static func seatOrigin(tier: OfficeTierStyle, index: Int) -> (x: Int, y: Int) {
        let cell = cellOrigin(tier: tier, index: index)
        return (cell.x + 8, cell.y)
    }

    /// Top of the founder's own desk cell — the front row, and the line the
    /// amenity zones sit on. Extracted so `floorZoneReserve` can lay the
    /// zones out without composing a whole scene.
    static func founderRowY(for tier: OfficeTierStyle) -> Int {
        let l = layout(for: tier)
        return l.rowsStartY + deskRows(for: tier, cols: l.cols) * Layout.cellHeight
            + Layout.founderGap
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
        compose(tier: tier, occupants: occupants, amenities: [])
    }

    /// Composes the office with amenity zones. Amenities the tier cannot host
    /// are silently skipped (see `shownAmenities(for:amenities:)`); an empty
    /// set yields exactly the two-argument composition.
    public static func compose(
        tier: OfficeTierStyle, occupants: [Occupant], amenities: Set<AmenityStyle>
    ) -> [PlacedSprite] {
        let l = layout(for: tier)
        let size = sceneSize(for: tier)
        let shown = shownAmenities(for: tier, amenities: amenities)
        let founderY = founderRowY(for: tier)
        // The room needs to know where the zones are going: its baked floor
        // dressing is drawn under them, so it skips whatever they cover.
        let zones = zoneFrames(for: tier, shown: shown, size: size, founderY: founderY)
            .map { (x: $0.x, y: $0.y, width: $0.width, height: $0.height) }

        var scene: [PlacedSprite] = []
        scene.append(PlacedSprite(
            sprite: RoomBuilder.room(
                tier: tier, width: size.width, height: size.height,
                wallHeight: l.wallHeight, amenityRects: zones
            ),
            x: 0, y: 0, kind: .room, animation: .still, phase: 0
        ))
        scene += props(for: tier, size: size, layout: l)

        // Founder first; everyone else in given order; overflow simply unseated.
        let founders = occupants.filter(\.isFounder)
        let employees = occupants.filter { !$0.isFounder }
        let founder = founders.first
        let regulars = Array((founders.dropFirst() + employees).prefix(tier.deskCapacity))

        // With a cafeteria, the first idle regular takes a break at a table
        // instead of sitting at their desk.
        let breakIndex = shown.contains(.cafeteria) ? regulars.firstIndex { $0.status == .idle } : nil

        for index in 0..<tier.deskCapacity {
            let row = index / l.cols
            let col = index % l.cols
            let cellX = Layout.sideMargin + col * Layout.cellWidth
            let cellY = l.rowsStartY + row * Layout.cellHeight
            let seated = index < regulars.count && index != breakIndex ? regulars[index] : nil
            scene += deskCell(x: cellX, y: cellY, occupant: seated, index: index)
        }

        // Founder desk: front row, left, slightly separated.
        scene += deskCell(x: Layout.sideMargin, y: founderY, occupant: founder, index: tier.deskCapacity)

        scene += amenityZones(
            for: tier, shown: shown, size: size, founderY: founderY,
            onBreak: breakIndex.map { regulars[$0] }
        )
        return scene
    }

    private static func deskCell(x: Int, y: Int, occupant: Occupant?, index: Int) -> [PlacedSprite] {
        var cell: [PlacedSprite] = []
        if let occupant {
            cell.append(PlacedSprite(
                sprite: SpriteCache.person(appearance: occupant.appearance, pose: .seated, isFounder: occupant.isFounder, role: occupant.role),
                x: x + 8, y: y,
                kind: .person,
                animation: .typing(slow: occupant.status == .idle),
                phase: (index * 3) % 7
            ))
        }
        cell.append(PlacedSprite(
            sprite: SpriteCache.shared("desk", make: SpriteLibrary.desk), x: x + 3, y: y + 13,
            kind: .desk, animation: .still, phase: 0
        ))
        cell.append(PlacedSprite(
            sprite: SpriteCache.shared("monitor", make: SpriteLibrary.monitor), x: x + 10, y: y + 7,
            kind: .monitor, animation: .glow, phase: index % 2
        ))
        if let occupant, occupant.status != .idle {
            cell.append(PlacedSprite(
                sprite: SpriteCache.shared("bubble.\(occupant.status.rawValue)") { SpriteLibrary.statusBubble(occupant.status) },
                x: x + 16, y: y - 8,
                kind: .bubble, animation: .still, phase: 0
            ))
        }
        return cell
    }

    /// One fixed prop on a tier's walls or floor, by name and top-left
    /// corner. A `nil` name is a window: its art depends on the hour and
    /// the weather, so it is looked up through the ambience seam.
    ///
    /// The single source of where the whiteboard, the coffee machine and
    /// the garage door are. `props(for:)` draws this list and the office's
    /// hit regions read it, so a tap on the coffee machine can never drift
    /// away from the coffee machine.
    struct PropPlacement: Equatable {
        var name: SpriteLibrary.PropName?
        var x: Int
        var y: Int

        var sprite: PixelSprite {
            name.map(SceneComposer.propSprite) ?? SceneComposer.windowSprite(ambience: .plain)
        }
    }

    /// The tier's fixed props, in draw order.
    static func propPlacements(
        for tier: OfficeTierStyle,
        size: SceneSize,
        layout l: Layout
    ) -> [PropPlacement] {
        let boardX = (size.width - 22) / 2
        switch tier {
        case .garage:
            return [
                PropPlacement(name: .garageDoor, x: size.width - 34, y: l.wallHeight - 16),
                PropPlacement(name: .whiteboard, x: boardX, y: 4),
                PropPlacement(name: .toolbox, x: 2, y: l.wallHeight + 1),
            ]
        case .loft:
            return [
                PropPlacement(name: nil, x: 14, y: 3),
                PropPlacement(name: nil, x: size.width - 26, y: 3),
                PropPlacement(name: .whiteboard, x: boardX, y: 3),
                PropPlacement(name: .plant, x: 2, y: l.wallHeight + 2),
                PropPlacement(name: .plant, x: size.width - 11, y: size.height - 14),
            ]
        case .studio:
            return [
                PropPlacement(name: .whiteboard, x: boardX, y: 4),
                PropPlacement(name: .coffeeMachine, x: size.width - 12, y: l.wallHeight + 3),
                PropPlacement(name: .plant, x: 2, y: l.wallHeight + 2),
            ]
        case .campus:
            let step = (size.width - 44) / 3
            var props = (0..<4).map { PropPlacement(name: nil, x: 16 + $0 * step, y: 4) }
            props.append(PropPlacement(name: .whiteboard, x: boardX, y: 4))
            props.append(PropPlacement(name: .plant, x: 2, y: l.wallHeight + 2))
            props.append(PropPlacement(name: .plant, x: size.width - 10, y: l.wallHeight + 2))
            props.append(PropPlacement(name: .coffeeMachine, x: size.width - 12, y: size.height - 20))
            return props
        }
    }

    /// The shared, cached sprite for a fixed prop.
    static func propSprite(_ name: SpriteLibrary.PropName) -> PixelSprite {
        SpriteCache.shared("prop.\(name.rawValue)") { SpriteLibrary.prop(name) }
    }

    /// The shared, cached office window at an hour, in a weather.
    static func windowSprite(ambience: OfficeAmbience) -> PixelSprite {
        SpriteCache.shared(
            "window.office.\(ambience.timeOfDay.rawValue).\(ambience.weather.rawValue)"
        ) {
            SpriteLibrary.window(
                style: .office, time: ambience.timeOfDay, weather: ambience.weather
            )
        }
    }

    /// A fixed prop as the sprite the renderer draws. Windows carry the
    /// hour and the weather (WS-D's art), so they go through the ambience.
    static func placed(_ prop: PropPlacement, ambience: OfficeAmbience) -> PlacedSprite {
        PlacedSprite(
            sprite: prop.name.map(propSprite) ?? windowSprite(ambience: ambience),
            x: prop.x, y: prop.y, kind: .prop, animation: .still, phase: 0
        )
    }

    static func props(
        for tier: OfficeTierStyle,
        size: SceneSize,
        layout l: Layout,
        ambience: OfficeAmbience = .plain
    ) -> [PlacedSprite] {
        propPlacements(for: tier, size: size, layout: l).map { placed($0, ambience: ambience) }
    }
}
