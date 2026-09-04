import SwiftUI

/// How a scene's pixels land in a view: the integer scale and the letterbox
/// origin. `PixelSceneView` draws through it, and anything that has to map
/// a point in the view back to a scene pixel — a tap, an accessibility
/// frame — builds the same one from the view's size, so the two can never
/// disagree about where a sprite is.
public struct PixelSceneGeometry: Equatable, Sendable {
    public let sceneWidth: Int
    public let sceneHeight: Int
    /// Points per scene pixel.
    public let scale: Int
    /// Where scene pixel (0, 0) lands in the view, in points.
    public let origin: CGPoint

    public init(
        sceneSize: (width: Int, height: Int),
        viewSize: CGSize,
        mode: PixelSceneView.Scale = .fitWidth
    ) {
        sceneWidth = sceneSize.width
        sceneHeight = sceneSize.height
        switch mode {
        case .fitWidth: scale = max(1, Int(viewSize.width) / max(1, sceneSize.width))
        case .fixed(let fixed): scale = max(1, fixed)
        }
        let drawnWidth = CGFloat(sceneWidth * scale)
        let drawnHeight = CGFloat(sceneHeight * scale)
        origin = CGPoint(
            x: ((viewSize.width - drawnWidth) / 2).rounded(.down),
            y: ((viewSize.height - drawnHeight) / 2).rounded(.down)
        )
    }

    /// The scene pixel under a view point. Outside the drawn scene the
    /// result falls outside `0..<sceneWidth` / `0..<sceneHeight`.
    public func scenePoint(_ point: CGPoint) -> (x: Int, y: Int) {
        (
            Int(((point.x - origin.x) / CGFloat(scale)).rounded(.down)),
            Int(((point.y - origin.y) / CGFloat(scale)).rounded(.down))
        )
    }

    /// A scene rectangle in view points.
    public func viewRect(x: Int, y: Int, width: Int, height: Int) -> CGRect {
        CGRect(
            x: origin.x + CGFloat(x * scale),
            y: origin.y + CGFloat(y * scale),
            width: CGFloat(width * scale),
            height: CGFloat(height * scale)
        )
    }
}

/// A finger on a scene, reported in scene pixels.
public enum ScenePress: Sendable, Equatable {
    /// The finger landed, on this scene pixel, in this frame.
    case began(x: Int, y: Int, t: TimeInterval)
    /// The finger lifted, or moved far enough to be a scroll: either way
    /// the press is over. A lift without a move is also a tap, which
    /// `onTapScenePoint` reports separately.
    case ended
}

/// The shared renderer behind every pixel scene: nearest-neighbor drawing of
/// composed `PlacedSprite`s, animated by a cosmetic 12 fps timeline — never
/// by the game simulation.
///
/// Two ways to supply content:
///
/// - a fixed `[PlacedSprite]` (home, city, activity scenes) — the list never
///   changes and only frame indices advance;
/// - a `placements(at:)` closure (the office) — re-evaluated once per frame
///   with the scene clock, so the director can move people around. The
///   director memoizes per whole second, so this is cheap.
///
/// Scene time starts at zero when the view first appears and keeps running
/// across rebuilds, so an animation never jumps because SwiftUI re-created
/// the struct.
public struct PixelSceneView: View {
    /// How the scene maps to the view's space.
    public enum Scale: Sendable {
        /// Integer pixel scale floored to fit the width, letterboxed —
        /// the office/home card behavior. The view proposes its own
        /// aspect ratio.
        case fitWidth
        /// A fixed integer pixel scale; the view takes its exact drawn
        /// size (`sceneSize × scale`) — for pannable scenes inside a
        /// ScrollView, where tap points map exactly to scene pixels.
        case fixed(Int)
    }

    /// How far a finger may drift and still be a tap rather than a scroll.
    static let scrollSlop: CGFloat = 10

    private let placementsAt: @Sendable (TimeInterval) -> [PlacedSprite]
    private let sceneWidth: Int
    private let sceneHeight: Int
    private let scale: Scale
    private let accessibilityLabel: String
    private let onTapScenePoint: ((Int, Int, TimeInterval) -> Void)?
    private let onPress: ((ScenePress) -> Void)?

    /// Scene time origin. `@State` so it survives the view value being
    /// rebuilt — otherwise every parent update would restart the clock.
    @State private var epoch = Date.timeIntervalSinceReferenceDate

    /// The finger currently on the scene.
    @State private var press: Press?

    private struct Press {
        var start: CGPoint
        var cancelled: Bool
    }

    /// A scene whose placement list is fixed.
    public init(
        placements: [PlacedSprite],
        sceneSize: (width: Int, height: Int),
        scale: Scale = .fitWidth,
        accessibilityLabel: String = "Pixel scene"
    ) {
        let snapshot = placements
        self.placementsAt = { _ in snapshot }
        self.sceneWidth = sceneSize.width
        self.sceneHeight = sceneSize.height
        self.scale = scale
        self.accessibilityLabel = accessibilityLabel
        self.onTapScenePoint = nil
        self.onPress = nil
    }

    /// A scene that recomposes itself from the clock.
    ///
    /// - Parameters:
    ///   - placements: called with seconds since the view appeared; must be
    ///     cheap (memoized) because it runs every frame.
    ///   - onTapScenePoint: receives taps in *scene pixel* coordinates plus
    ///     the scene time of the tap, so the caller can hit-test moving
    ///     actors.
    ///   - onPress: the finger landing and leaving, so the caller can draw
    ///     something under it while it is there.
    public init(
        sceneSize: (width: Int, height: Int),
        scale: Scale = .fitWidth,
        accessibilityLabel: String = "Pixel scene",
        onTapScenePoint: ((Int, Int, TimeInterval) -> Void)? = nil,
        onPress: ((ScenePress) -> Void)? = nil,
        placements: @escaping @Sendable (TimeInterval) -> [PlacedSprite]
    ) {
        self.placementsAt = placements
        self.sceneWidth = sceneSize.width
        self.sceneHeight = sceneSize.height
        self.scale = scale
        self.accessibilityLabel = accessibilityLabel
        self.onTapScenePoint = onTapScenePoint
        self.onPress = onPress
    }

    public var body: some View {
        switch scale {
        case .fitWidth:
            canvas
                .aspectRatio(CGFloat(sceneWidth) / CGFloat(sceneHeight), contentMode: .fit)
                .accessibilityLabel(accessibilityLabel)
        case .fixed(let fixed):
            canvas
                .frame(
                    width: CGFloat(sceneWidth * max(1, fixed)),
                    height: CGFloat(sceneHeight * max(1, fixed))
                )
                .accessibilityLabel(accessibilityLabel)
        }
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var canvas: some View {
        // Under Reduce Motion the scene is a state display, not a motion
        // display: two frames a second is enough for a monitor to glow and
        // a bubble to appear, and nothing walks (the office director
        // seats everyone when the input says so).
        let interval = reduceMotion ? 0.5 : AnimationClock.frameInterval
        return TimelineView(.animation(minimumInterval: interval, paused: false)) { timeline in
            let t = max(0, timeline.date.timeIntervalSinceReferenceDate - epoch)
            Canvas { context, size in
                draw(into: &context, size: size, t: t)
            }
            .overlay { tapTarget(t: t) }
        }
    }

    private func geometry(in size: CGSize) -> PixelSceneGeometry {
        PixelSceneGeometry(sceneSize: (sceneWidth, sceneHeight), viewSize: size, mode: scale)
    }

    @ViewBuilder
    private func tapTarget(t: TimeInterval) -> some View {
        if onTapScenePoint != nil || onPress != nil {
            GeometryReader { proxy in
                Color.clear
                    .contentShape(Rectangle())
                    .simultaneousGesture(pressGesture(in: proxy.size, t: t))
            }
        }
    }

    /// A press that is also a tap.
    ///
    /// A zero-distance drag, attached *simultaneously* so a scroll view
    /// around the scene keeps scrolling: the finger landing is the press,
    /// lifting without having moved is the tap, and moving past
    /// `scrollSlop` is a scroll — the press ends and no tap fires. A plain
    /// `onTapGesture` cannot say when the finger lands, and a press
    /// highlight that only appears on release is not a press highlight.
    private func pressGesture(in size: CGSize, t: TimeInterval) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { value in
                // A new finger, or one the system took away without an
                // `onEnded` (a cancelled touch): start over.
                if press == nil || press?.start != value.startLocation {
                    press = Press(start: value.startLocation, cancelled: false)
                    let point = geometry(in: size).scenePoint(value.startLocation)
                    onPress?(.began(x: point.x, y: point.y, t: t))
                } else if press?.cancelled == false,
                          hypot(value.translation.width, value.translation.height) > Self.scrollSlop {
                    press?.cancelled = true
                    onPress?(.ended)
                }
            }
            .onEnded { value in
                let cancelled = press?.cancelled ?? true
                press = nil
                guard !cancelled else { return }
                let point = geometry(in: size).scenePoint(value.startLocation)
                onTapScenePoint?(point.x, point.y, t)
                onPress?(.ended)
            }
    }

    /// Draws one frame. Split out of the `Canvas` body so the office
    /// performance suite can measure exactly what ships.
    private func draw(into context: inout GraphicsContext, size: CGSize, t: TimeInterval) {
        let geometry = geometry(in: size)
        let visible = CGRect(origin: .zero, size: size)

        for placement in placementsAt(t) {
            guard placement.opacity > 0.004 else { continue }
            let point = placement.position(at: t)
            let rect = geometry.viewRect(
                x: point.x, y: point.y,
                width: placement.sprite.width, height: placement.sprite.height
            )
            // Off-screen sprites (a hire still outside the door) cost nothing.
            guard rect.intersects(visible) else { continue }

            let image = placement.sprite.cgImage(frame: placement.frameIndex(at: t))
            // Nearest-neighbor so pixels stay crisp at any scale.
            let sprite = Image(decorative: image, scale: 1).interpolation(.none)

            if placement.flipX {
                context.drawLayer { layer in
                    layer.opacity = placement.opacity
                    layer.translateBy(x: rect.midX, y: rect.midY)
                    layer.scaleBy(x: -1, y: 1)
                    layer.translateBy(x: -rect.midX, y: -rect.midY)
                    layer.draw(sprite, in: rect)
                }
            } else if placement.opacity < 1 {
                context.drawLayer { layer in
                    layer.opacity = placement.opacity
                    layer.draw(sprite, in: rect)
                }
            } else {
                context.draw(sprite, in: rect)
            }
        }
    }
}
