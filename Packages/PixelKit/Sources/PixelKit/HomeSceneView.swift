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
        PixelSceneView(
            placements: placements,
            sceneSize: sceneSize,
            accessibilityLabel: "Home scene"
        )
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
