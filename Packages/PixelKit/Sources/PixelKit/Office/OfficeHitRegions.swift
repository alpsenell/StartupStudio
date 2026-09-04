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
        for actor in actorFrames(input: input, timing: timing, at: t) {
            regions.append(OfficeHitRegion(
                kind: .person(actor.id),
                x: actor.x, y: actor.y, width: actor.width, height: actor.height,
                zIndex: actor.zIndex
            ))
        }
        return regions
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
