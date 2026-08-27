import SwiftUI

/// The office scene: floor and walls per tier, a desk grid, occupants at
/// desks (founder front-left), status bubbles, ambient props, and optional
/// amenity zones along the front row.
///
/// Scales to fit its width with integer pixel scaling (floored) and
/// letterboxes vertically as needed. Animation is purely cosmetic, driven by
/// a periodic timeline at ~4 fps — never by the game simulation.
public struct OfficeSceneView: View {
    private let placements: [PlacedSprite]
    private let sceneSize: SceneComposer.SceneSize

    public init(tier: OfficeTierStyle, occupants: [Occupant]) {
        self.init(tier: tier, occupants: occupants, amenities: [])
    }

    /// Office with amenity zones (game room, cafeteria, gym, shuttle). Zones
    /// the tier cannot host are skipped; the scene size never changes.
    public init(tier: OfficeTierStyle, occupants: [Occupant], amenities: Set<AmenityStyle>) {
        // Composed once per view value; per-frame CGImages are cached inside
        // each sprite, so the timeline only picks frame indices.
        self.placements = SceneComposer.compose(tier: tier, occupants: occupants, amenities: amenities)
        self.sceneSize = SceneComposer.sceneSize(for: tier)
    }

    public var body: some View {
        PixelSceneView(
            placements: placements,
            sceneSize: (sceneSize.width, sceneSize.height),
            accessibilityLabel: "Office scene"
        )
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

#Preview("Studio with amenities") {
    OfficeSceneView(
        tier: .studio,
        occupants: (0..<14).map { i in
            Occupant(
                id: UUID(),
                appearance: CharacterAppearance(seed: UInt64(i) &+ 70),
                status: WorkStatus.allCases[i % WorkStatus.allCases.count],
                isFounder: i == 0
            )
        },
        amenities: [.gameRoom, .cafeteria, .shuttle, .gym]
    )
    .padding()
}
