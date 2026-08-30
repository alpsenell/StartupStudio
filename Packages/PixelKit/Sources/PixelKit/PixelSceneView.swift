import SwiftUI

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
    public enum Scale {
        /// Integer pixel scale floored to fit the width, letterboxed —
        /// the office/home card behavior. The view proposes its own
        /// aspect ratio.
        case fitWidth
        /// A fixed integer pixel scale; the view takes its exact drawn
        /// size (`sceneSize × scale`) — for pannable scenes inside a
        /// ScrollView, where tap points map exactly to scene pixels.
        case fixed(Int)
    }

    private let placementsAt: @Sendable (TimeInterval) -> [PlacedSprite]
    private let sceneWidth: Int
    private let sceneHeight: Int
    private let scale: Scale
    private let accessibilityLabel: String
    private let onTapScenePoint: ((Int, Int, TimeInterval) -> Void)?

    /// Scene time origin. `@State` so it survives the view value being
    /// rebuilt — otherwise every parent update would restart the clock.
    @State private var epoch = Date.timeIntervalSinceReferenceDate

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
    }

    /// A scene that recomposes itself from the clock.
    ///
    /// - Parameters:
    ///   - placements: called with seconds since the view appeared; must be
    ///     cheap (memoized) because it runs every frame.
    ///   - onTapScenePoint: receives taps in *scene pixel* coordinates plus
    ///     the scene time of the tap, so the caller can hit-test moving
    ///     actors.
    public init(
        sceneSize: (width: Int, height: Int),
        scale: Scale = .fitWidth,
        accessibilityLabel: String = "Pixel scene",
        onTapScenePoint: ((Int, Int, TimeInterval) -> Void)? = nil,
        placements: @escaping @Sendable (TimeInterval) -> [PlacedSprite]
    ) {
        self.placementsAt = placements
        self.sceneWidth = sceneSize.width
        self.sceneHeight = sceneSize.height
        self.scale = scale
        self.accessibilityLabel = accessibilityLabel
        self.onTapScenePoint = onTapScenePoint
    }

    public var body: some View {
        switch scale {
        case .fitWidth:
            canvas { size in max(1, Int(size.width) / sceneWidth) }
                .aspectRatio(CGFloat(sceneWidth) / CGFloat(sceneHeight), contentMode: .fit)
                .accessibilityLabel(accessibilityLabel)
        case .fixed(let fixed):
            canvas { _ in max(1, fixed) }
                .frame(
                    width: CGFloat(sceneWidth * max(1, fixed)),
                    height: CGFloat(sceneHeight * max(1, fixed))
                )
                .accessibilityLabel(accessibilityLabel)
        }
    }

    private func canvas(scaleFor: @escaping (CGSize) -> Int) -> some View {
        TimelineView(.animation(minimumInterval: AnimationClock.frameInterval, paused: false)) { timeline in
            let t = max(0, timeline.date.timeIntervalSinceReferenceDate - epoch)
            Canvas { context, size in
                draw(into: &context, size: size, scale: scaleFor(size), t: t)
            }
            .overlay { tapTarget(scaleFor: scaleFor, t: t) }
        }
    }

    @ViewBuilder
    private func tapTarget(scaleFor: @escaping (CGSize) -> Int, t: TimeInterval) -> some View {
        if let onTapScenePoint {
            GeometryReader { geometry in
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { location in
                        let size = geometry.size
                        let scale = CGFloat(scaleFor(size))
                        let originX = ((size.width - CGFloat(sceneWidth) * scale) / 2).rounded(.down)
                        let originY = ((size.height - CGFloat(sceneHeight) * scale) / 2).rounded(.down)
                        onTapScenePoint(
                            Int(((location.x - originX) / scale).rounded(.down)),
                            Int(((location.y - originY) / scale).rounded(.down)),
                            t
                        )
                    }
            }
        }
    }

    /// Draws one frame. Split out of the `Canvas` body so the office
    /// performance suite can measure exactly what ships.
    private func draw(into context: inout GraphicsContext, size: CGSize, scale: Int, t: TimeInterval) {
        let drawnWidth = CGFloat(sceneWidth * scale)
        let drawnHeight = CGFloat(sceneHeight * scale)
        let originX = ((size.width - drawnWidth) / 2).rounded(.down)
        let originY = ((size.height - drawnHeight) / 2).rounded(.down)
        let visible = CGRect(origin: .zero, size: size)

        for placement in placementsAt(t) {
            guard placement.opacity > 0.004 else { continue }
            let point = placement.position(at: t)
            let rect = CGRect(
                x: originX + CGFloat(point.x * scale),
                y: originY + CGFloat(point.y * scale),
                width: CGFloat(placement.sprite.width * scale),
                height: CGFloat(placement.sprite.height * scale)
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
