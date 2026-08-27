import SwiftUI

/// The shared renderer behind every pixel scene: nearest-neighbor drawing
/// of composed `PlacedSprite`s, animated by a cosmetic ~4 fps timeline —
/// never by the game simulation.
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

    private let placements: [PlacedSprite]
    private let sceneWidth: Int
    private let sceneHeight: Int
    private let scale: Scale
    private let accessibilityLabel: String

    public init(
        placements: [PlacedSprite],
        sceneSize: (width: Int, height: Int),
        scale: Scale = .fitWidth,
        accessibilityLabel: String = "Pixel scene"
    ) {
        self.placements = placements
        self.sceneWidth = sceneSize.width
        self.sceneHeight = sceneSize.height
        self.scale = scale
        self.accessibilityLabel = accessibilityLabel
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
        TimelineView(.periodic(from: .init(timeIntervalSinceReferenceDate: 0), by: 0.25)) { timeline in
            Canvas { context, size in
                let tick = Int(timeline.date.timeIntervalSinceReferenceDate * 4) & 0x3FFF_FFFF
                let scale = scaleFor(size)
                let drawnWidth = CGFloat(sceneWidth * scale)
                let drawnHeight = CGFloat(sceneHeight * scale)
                let originX = ((size.width - drawnWidth) / 2).rounded(.down)
                let originY = ((size.height - drawnHeight) / 2).rounded(.down)

                for placement in placements {
                    let image = placement.sprite.cgImage(frame: placement.frameIndex(atTick: tick))
                    // Nearest-neighbor so pixels stay crisp at any scale.
                    let sprite = Image(decorative: image, scale: 1).interpolation(.none)
                    context.draw(sprite, in: CGRect(
                        x: originX + CGFloat(placement.x * scale),
                        y: originY + CGFloat(placement.y * scale),
                        width: CGFloat(placement.sprite.width * scale),
                        height: CGFloat(placement.sprite.height * scale)
                    ))
                }
            }
        }
    }
}
