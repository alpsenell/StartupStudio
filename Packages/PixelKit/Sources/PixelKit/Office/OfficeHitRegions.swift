import CoreGraphics
import Foundation

/// Something in the office a finger can land on, and where it is on a
/// given frame — in scene pixels, the same space `PlacedSprite` lives in.
///
/// The director derives these from exactly what it drew: a person's region
/// is their sprite this second, a prop's is the prop's own rectangle. The
/// app gives each kind a meaning (a person opens their page, the coffee
/// machine offers coffee); PixelKit only knows where things are.
public struct OfficeHitRegion: Sendable, Equatable, Hashable, Identifiable {
    /// What was hit. People carry their occupant id; the props are the four
    /// the app gives a meaning to.
    public enum Kind: Sendable, Equatable, Hashable {
        case person(UUID)
        case coffeeMachine
        case whiteboard
        case door
        case founderDesk
        // MARK: Iteration 10 — M6 (the bug hunt)
        /// A bug crawling in front of a desk, by `OfficeBug.id`. The only
        /// region that is not part of the furniture — it moves, it can be
        /// squashed, and it is gone a second later.
        case bug(Int)
        // MARK: K6 (home and rooms)
        /// A plant on the floor, by its place among the tier's plants (the
        /// campus has two). Only in `OfficeSceneInput.roomRegions` scenes.
        case plant(Int)
        /// A window on the back wall, by its place among the tier's windows.
        case window(Int)
        /// A built amenity's zone: the game room, the cafeteria, the gym.
        case amenity(AmenityStyle)
        // MARK: end K6
        // MARK: S1 (seating)
        /// A desk in the grid, by index — empty or not. Only in
        /// `OfficeSceneInput.seatRegions` scenes (the office's move mode).
        case desk(Int)
        // MARK: end S1

        public var isPerson: Bool {
            if case .person = self { return true }
            return false
        }
    }

    public var kind: Kind
    public var x: Int
    public var y: Int
    public var width: Int
    public var height: Int
    /// Painter's depth, for picking the figure nearest the viewer when two
    /// overlap.
    public var zIndex: Int
    /// Who wins an overlap before depth is consulted: figures (2) over
    /// furniture (1) over the floor (0). The doormat's region reaches up to
    /// where somebody would stand on it, which is also where the founder's
    /// desk ends; the desk is the thing you see, so the desk wins there.
    public var priority: Int

    /// One region per kind on any frame, so the kind is the identity.
    public var id: Kind { kind }

    public init(
        kind: Kind, x: Int, y: Int, width: Int, height: Int, zIndex: Int = 0, priority: Int? = nil
    ) {
        self.kind = kind
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.zIndex = zIndex
        self.priority = priority ?? (kind.isPerson ? 2 : 1)
    }

    public func contains(x px: Int, y py: Int) -> Bool {
        px >= x && px < x + width && py >= y && py < y + height
    }
}

extension OfficeDirector {
    // MARK: - Hit regions

    /// Every tappable thing on screen at scene time `t`: the fixed props,
    /// then every person where the director has them this second.
    public static func hitRegions(
        input: OfficeSceneInput,
        timing: OfficeSceneTiming = .none,
        at t: TimeInterval
    ) -> [OfficeHitRegion] {
        var regions = propRegions(for: input.tier)
        // MARK: K6 (home and rooms)
        if input.roomRegions { regions += roomRegions(input: input) }
        // MARK: end K6
        // MARK: S1 (seating)
        if input.seatRegions { regions += deskRegions(for: input.tier) }
        // MARK: end S1
        for actor in actorFrames(input: input, timing: timing, at: t) {
            regions.append(OfficeHitRegion(
                kind: .person(actor.id),
                x: actor.x, y: actor.y, width: actor.width, height: actor.height,
                zIndex: actor.zIndex
            ))
        }
        // MARK: Iteration 10 — M6 (the bug hunt)
        regions += bugRegions(input: input, at: t)
        return regions
    }

    /// Where the bugs are this instant, padded out to something a thumb can
    /// actually land on.
    ///
    /// The sprite is nine pixels by seven, which on a campus scene is nine
    /// points by seven — under half of Apple's 44-point target. So the
    /// region is grown around the sprite to at least 16×14 scene pixels and
    /// given the top priority: while a bug is out, the bug is what your
    /// finger meant, not the desk behind it. It is also the only region
    /// that disappears on its own, which is why it is worth over-reaching
    /// for: miss it and you have lost the moment, not opened the wrong
    /// sheet.
    static func bugRegions(input: OfficeSceneInput, at t: TimeInterval) -> [OfficeHitRegion] {
        guard !input.bugs.isEmpty else { return [] }
        let sprite = SpriteCache.shared("fx.bug", make: OfficeFXSprites.bug)
        let minWidth = 16
        let minHeight = 14
        return input.bugs.compactMap { bug in
            // A splat is scenery. Nothing to squash twice.
            guard !bug.isSquashed else { return nil }
            let frame = OfficeFX.bugFrame(bug, tier: input.tier, at: t)
            let anchor = frame.motion.position(at: t).rounded
            let padX = max(0, minWidth - sprite.width) / 2
            let padY = max(0, minHeight - sprite.height) / 2
            return OfficeHitRegion(
                kind: .bug(bug.id),
                x: anchor.x - padX,
                y: anchor.y - padY,
                width: sprite.width + padX * 2,
                height: sprite.height + padY * 2,
                zIndex: anchor.y + sprite.height,
                priority: 3
            )
        }
    }

    /// The region under scene pixel (`x`, `y`) at time `t`, or `nil` when
    /// the tap missed everything. Figures win over props — somebody
    /// standing at the coffee machine is the somebody — furniture wins
    /// over the floor, and among equals the one drawn nearest the viewer
    /// wins.
    public static func hitTest(
        input: OfficeSceneInput,
        timing: OfficeSceneTiming = .none,
        at t: TimeInterval,
        x: Int,
        y: Int
    ) -> OfficeHitRegion? {
        var best: OfficeHitRegion?
        for region in hitRegions(input: input, timing: timing, at: t) where region.contains(x: x, y: y) {
            guard let current = best else {
                best = region
                continue
            }
            if (region.priority, region.zIndex) > (current.priority, current.zIndex) { best = region }
        }
        return best
    }

    /// The region under a point in a `PixelSceneView`'s own coordinates,
    /// mapped back through the scale and the letterboxing the view drew
    /// with.
    public static func hitTest(
        input: OfficeSceneInput,
        timing: OfficeSceneTiming = .none,
        at t: TimeInterval,
        point: CGPoint,
        in size: CGSize,
        scale: PixelSceneView.Scale = .fitWidth
    ) -> OfficeHitRegion? {
        let scene = SceneComposer.sceneSize(for: input.tier)
        let pixel = PixelSceneGeometry(
            sceneSize: (scene.width, scene.height), viewSize: size, mode: scale
        ).scenePoint(point)
        return hitTest(input: input, timing: timing, at: t, x: pixel.x, y: pixel.y)
    }

    /// The occupant whose sprite covers scene-space point (`x`, `y`) at
    /// time `t`, or `nil` when the tap missed everybody. The person drawn
    /// closest to the viewer wins. The older seam; `hitTest(input:timing:
    /// at:x:y:)` also finds the props.
    public static func hitTest(
        input: OfficeSceneInput,
        t: TimeInterval,
        x: Int,
        y: Int
    ) -> UUID? {
        guard case .person(let id)? = hitTest(input: input, at: t, x: x, y: y)?.kind else { return nil }
        return id
    }

    // MARK: - Props

    /// The tappable props of a tier, which never move: the whiteboard, the
    /// coffee machine (WS-D's wall machine or the runtime's kitchenette),
    /// the door (the garage's roller door, or the doormat the other tiers
    /// get), and the founder's desk with its monitor.
    static func propRegions(for tier: OfficeTierStyle) -> [OfficeHitRegion] {
        let l = SceneComposer.layout(for: tier)
        let size = SceneComposer.sceneSize(for: tier)
        var regions: [OfficeHitRegion] = []

        for prop in SceneComposer.propPlacements(for: tier, size: size, layout: l) {
            guard let name = prop.name, let kind = pressKind(of: name) else { continue }
            let sprite = prop.sprite
            regions.append(OfficeHitRegion(
                kind: kind, x: prop.x, y: prop.y, width: sprite.width, height: sprite.height,
                zIndex: prop.y + sprite.height
            ))
        }

        if let origin = OfficeWaypoints.coffee(for: tier).kitchenette {
            let sprite = SpriteCache.shared("fx.kitchenette", make: OfficeFXSprites.kitchenette)
            regions.append(OfficeHitRegion(
                kind: .coffeeMachine, x: origin.x, y: origin.y,
                width: sprite.width, height: sprite.height, zIndex: origin.y + sprite.height
            ))
        }

        if let mat = doorMat(for: tier) {
            // The mat is two pixels tall; the region reaches up to where
            // somebody standing on it would be, so a thumb can find it. It
            // is the floor, so anything on it wins the overlap.
            let reach = 16
            regions.append(OfficeHitRegion(
                kind: .door, x: max(0, mat.x - 2), y: mat.y - reach,
                width: mat.width + 4, height: mat.height + reach,
                zIndex: mat.y + mat.height, priority: 0
            ))
        }

        // The founder's desk and monitor as one rectangle.
        let cell = SceneComposer.cellOrigin(tier: tier, index: tier.deskCapacity)
        let desk = SpriteCache.shared("desk", make: SpriteLibrary.desk)
        let monitor = SpriteCache.shared("monitor", make: SpriteLibrary.monitor)
        let top = min(cell.y + 13, cell.y + 7)
        let bottom = max(cell.y + 13 + desk.height, cell.y + 7 + monitor.height)
        regions.append(OfficeHitRegion(
            kind: .founderDesk, x: cell.x + 3, y: top, width: desk.width, height: bottom - top,
            zIndex: cell.y + SceneComposer.Layout.cellHeight
        ))
        return regions
    }

    // MARK: K6 (home and rooms)

    /// The room's other things — the plants, the windows on the back wall,
    /// the built amenity zones — exactly where they are drawn. Only for an
    /// input with `roomRegions` on (the app's office card): everywhere
    /// else the four props stay the only furniture a finger can find.
    ///
    /// The windows and the zones are the floor and the wall (priority 0),
    /// so a prop, a desk or anybody in front of them wins the tap.
    static func roomRegions(input: OfficeSceneInput) -> [OfficeHitRegion] {
        let tier = input.tier
        let l = SceneComposer.layout(for: tier)
        let size = SceneComposer.sceneSize(for: tier)
        var regions: [OfficeHitRegion] = []
        var plants = 0
        var windows = 0
        for prop in SceneComposer.propPlacements(for: tier, size: size, layout: l) {
            let sprite = prop.sprite
            switch prop.name {
            case .plant?:
                regions.append(OfficeHitRegion(
                    kind: .plant(plants), x: prop.x, y: prop.y,
                    width: sprite.width, height: sprite.height, zIndex: prop.y + sprite.height
                ))
                plants += 1
            case nil:
                regions.append(OfficeHitRegion(
                    kind: .window(windows), x: prop.x, y: prop.y,
                    width: sprite.width, height: sprite.height,
                    zIndex: prop.y + sprite.height, priority: 0
                ))
                windows += 1
            default:
                break
            }
        }
        let shown = SceneComposer.shownAmenities(for: tier, amenities: input.amenities)
        let frames = SceneComposer.zoneFrames(
            for: tier, shown: shown, size: size, founderY: SceneComposer.founderRowY(for: tier)
        )
        for frame in frames where frame.amenity != .shuttle {
            regions.append(OfficeHitRegion(
                kind: .amenity(frame.amenity), x: frame.x, y: frame.y,
                width: frame.width, height: frame.height,
                zIndex: frame.y + frame.height, priority: 0
            ))
        }
        return regions
    }
    // MARK: end K6

    // MARK: S1 (seating)

    /// Every desk in the grid as a whole cell: the chair, the desk and the
    /// monitor, where a thumb aiming at a desk actually lands. Furniture
    /// (priority 1): anybody standing or sitting in front of it still wins,
    /// and the move mode reads a tap on a seated person as their desk.
    static func deskRegions(for tier: OfficeTierStyle) -> [OfficeHitRegion] {
        (0..<tier.deskCapacity).map { index in
            let cell = SceneComposer.cellOrigin(tier: tier, index: index)
            return OfficeHitRegion(
                kind: .desk(index), x: cell.x, y: cell.y,
                width: SceneComposer.Layout.cellWidth, height: SceneComposer.Layout.cellHeight,
                zIndex: cell.y + SceneComposer.Layout.cellHeight
            )
        }
    }
    // MARK: end S1

    /// Which region a fixed prop is, if it is one.
    static func pressKind(of name: SpriteLibrary.PropName) -> OfficeHitRegion.Kind? {
        switch name {
        case .whiteboard: .whiteboard
        case .coffeeMachine: .coffeeMachine
        case .garageDoor: .door
        default: nil
        }
    }

    /// Where the runtime's own doormat goes.
    ///
    /// Only the garage draws a door; everywhere else the hires walk in at
    /// an unmarked spot in the front-left corner. Like the kitchenette the
    /// director lays down where a tier has no coffee machine, the mat marks
    /// that spot so "the door" is somewhere a finger can find. It sits
    /// under the feet of whoever stands at the door waypoint.
    static func doorMat(for tier: OfficeTierStyle) -> (x: Int, y: Int, width: Int, height: Int)? {
        guard tier != .garage else { return nil }
        let size = SceneComposer.sceneSize(for: tier)
        let sprite = SpriteCache.shared("fx.doormat", make: OfficeFXSprites.doorMat)
        return (x: 2, y: size.height - sprite.height, width: sprite.width, height: sprite.height)
    }
}
