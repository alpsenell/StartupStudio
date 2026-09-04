import PixelKit
import SwiftUI

/// One frame of the office scene, drawn once and never animated: the
/// photograph on the front page.
///
/// It asks `OfficeDirector` for the same placements the live scene draws
/// at a fixed scene time and blits them the way `PixelSceneView` does —
/// integer scale, nearest-neighbour, letterboxed — without the timeline,
/// so a page renders the same picture every time it is opened and a
/// snapshot test gets a stable PNG.
struct OfficePhotoView: View {
    let scene: OfficeSceneInput
    /// Scene time the frame is taken at.
    let moment: TimeInterval

    var body: some View {
        let size = SceneComposer.sceneSize(for: scene.tier)
        let placements = OfficeDirector.compose(input: scene, at: moment)
        Canvas(rendersAsynchronously: false) { context, canvasSize in
            let scale = max(1, Int(canvasSize.width) / size.width)
            let drawnWidth = CGFloat(size.width * scale)
            let drawnHeight = CGFloat(size.height * scale)
            let originX = ((canvasSize.width - drawnWidth) / 2).rounded(.down)
            let originY = ((canvasSize.height - drawnHeight) / 2).rounded(.down)

            for placement in placements where placement.opacity > 0.004 {
                let point = placement.position(at: moment)
                let rect = CGRect(
                    x: originX + CGFloat(point.x * scale),
                    y: originY + CGFloat(point.y * scale),
                    width: CGFloat(placement.sprite.width * scale),
                    height: CGFloat(placement.sprite.height * scale)
                )
                let image = Image(
                    decorative: placement.sprite.cgImage(frame: placement.frameIndex(at: moment)),
                    scale: 1
                )
                .interpolation(.none)

                if placement.flipX {
                    context.drawLayer { layer in
                        layer.opacity = placement.opacity
                        layer.translateBy(x: rect.midX, y: rect.midY)
                        layer.scaleBy(x: -1, y: 1)
                        layer.translateBy(x: -rect.midX, y: -rect.midY)
                        layer.draw(image, in: rect)
                    }
                } else if placement.opacity < 1 {
                    context.drawLayer { layer in
                        layer.opacity = placement.opacity
                        layer.draw(image, in: rect)
                    }
                } else {
                    context.draw(image, in: rect)
                }
            }
        }
        .aspectRatio(CGFloat(size.width) / CGFloat(size.height), contentMode: .fit)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        let people = scene.occupants.count
        return people == 1
            ? "Photograph of the \(scene.tier.rawValue), one person at a desk"
            : "Photograph of the \(scene.tier.rawValue), \(people) people at their desks"
    }
}
