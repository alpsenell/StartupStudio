import SwiftUI

/// The founder's evening at home: a tier-specific room, the household, and
/// the founder doing tonight's activity with a mood bubble overhead.
///
/// Same renderer as `OfficeSceneView`: integer pixel scaling (floored) to
/// fit the width, nearest-neighbor drawing, cosmetic ~4 fps timeline.
public struct HomeSceneView: View {
    private let placements: [PlacedSprite]
    private let sceneSize: (width: Int, height: Int)

    public init(tier: HomeTierStyle, occupants: HomeOccupants, activity: HomeActivity, mood: MoodLevel) {
        self.placements = HomeSceneComposer.compose(tier: tier, occupants: occupants, activity: activity, mood: mood)
        self.sceneSize = HomeSceneComposer.sceneSize(for: tier)
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
        .accessibilityLabel("Home scene")
    }
}

#Preview("Studio — sleeping") {
    HomeSceneView(
        tier: .studioFlat,
        occupants: HomeOccupants(founder: CharacterAppearance(seed: 7)),
        activity: .sleeping, mood: .okay
    )
    .padding()
}

#Preview("House — gaming with family") {
    HomeSceneView(
        tier: .house,
        occupants: HomeOccupants(
            founder: CharacterAppearance(seed: 7),
            partner: CharacterAppearance(seed: 21),
            children: [CharacterAppearance(seed: 31), CharacterAppearance(seed: 32)]
        ),
        activity: .gaming, mood: .great
    )
    .padding()
}
