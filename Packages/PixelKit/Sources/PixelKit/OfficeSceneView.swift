import SwiftUI

/// The office scene: floor and walls per tier, a desk grid, occupants at
/// desks (founder front-left), status bubbles, and ambient props.
///
/// Scales to fit its width with integer pixel scaling (floored) and
/// letterboxes vertically as needed. Animation is purely cosmetic, driven by
/// a periodic timeline at ~4 fps — never by the game simulation.
public struct OfficeSceneView: View {
    private let placements: [PlacedSprite]
    private let sceneSize: SceneComposer.SceneSize

    public init(tier: OfficeTierStyle, occupants: [Occupant]) {
        // Composed once per view value; per-frame CGImages are cached inside
        // each sprite, so the timeline only picks frame indices.
        self.placements = SceneComposer.compose(tier: tier, occupants: occupants)
        self.sceneSize = SceneComposer.sceneSize(for: tier)
    }

    public var body: some View {
        TimelineView(.periodic(from: .init(timeIntervalSinceReferenceDate: 0), by: 0.25)) { timeline in
            Canvas { context, size in
                let tick = Int(timeline.date.timeIntervalSinceReferenceDate * 4) & 0x3FFF_FFFF
                let scale = max(1, Int(size.width) / sceneSize.width)
                let drawnWidth = CGFloat(sceneSize.width * scale)
                let drawnHeight = CGFloat(sceneSize.height * scale)
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
        .aspectRatio(CGFloat(sceneSize.width) / CGFloat(sceneSize.height), contentMode: .fit)
        .accessibilityLabel("Office scene")
    }
}

#Preview("Garage") {
    OfficeSceneView(
        tier: .garage,
        occupants: [
            Occupant(id: UUID(), appearance: CharacterAppearance(seed: 1), status: .coding, isFounder: true),
            Occupant(id: UUID(), appearance: CharacterAppearance(seed: 2), status: .designing),
            Occupant(id: UUID(), appearance: CharacterAppearance(seed: 3), status: .idle),
        ]
    )
    .padding()
}

#Preview("Studio") {
    OfficeSceneView(
        tier: .studio,
        occupants: (0..<9).map { i in
            Occupant(
                id: UUID(),
                appearance: CharacterAppearance(seed: UInt64(i) &+ 40),
                status: WorkStatus.allCases[i % WorkStatus.allCases.count],
                isFounder: i == 0
            )
        }
    )
    .padding()
}
