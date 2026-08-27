import Foundation
import SwiftUI

/// Everything cosmetic about the room's hour and weather. Cosmetic only:
/// WS-C advances `timeOfDay` on its own real-time loop, never from a tick.
public struct OfficeAmbience: Sendable, Equatable, Hashable {
    public var timeOfDay: TimeOfDay
    public var weather: Weather
    public var isWeekend: Bool
    public var teamMood: MoodLevel

    public init(
        timeOfDay: TimeOfDay = .day,
        weather: Weather = .clear,
        isWeekend: Bool = false,
        teamMood: MoodLevel = .okay
    ) {
        self.timeOfDay = timeOfDay
        self.weather = weather
        self.isWeekend = isWeekend
        self.teamMood = teamMood
    }

    /// A bright, ordinary weekday — exactly what the scene draws today.
    public static let plain = OfficeAmbience()
}

/// A one-off moment the room reacts to. Paired with a token by
/// `OfficeSceneInput` so a view rebuild never replays the same celebration.
public enum SceneCelebration: Sendable, Equatable, Hashable {
    case shipped(score: Int)
    case hired(UUID)
    case quit(UUID)
    case officeUpgraded
    case researchComplete
    case contractDelivered
}

/// Everything the office scene is a function of.
///
/// `Hashable` so WS-C can memoize the director's output per input and the
/// app can wrap the card in an `EquatableView`. The scaffold's
/// `OfficeSceneView(input:)` reads only `tier`, `occupants` and
/// `amenities` — the same three things the old initializers pass — so the
/// composed scene is byte-for-byte what it was.
public struct OfficeSceneInput: Sendable, Equatable, Hashable {
    public var tier: OfficeTierStyle
    public var occupants: [Occupant]
    public var amenities: Set<AmenityStyle>
    public var ambience: OfficeAmbience
    /// The celebration to play, with a token that changes when a *new*
    /// celebration starts.
    public var celebration: Celebration?

    /// A celebration plus the token that makes it fire once.
    public struct Celebration: Sendable, Equatable, Hashable {
        public var kind: SceneCelebration
        public var token: Int

        public init(kind: SceneCelebration, token: Int) {
            self.kind = kind
            self.token = token
        }
    }

    public init(
        tier: OfficeTierStyle,
        occupants: [Occupant],
        amenities: Set<AmenityStyle> = [],
        ambience: OfficeAmbience = .plain,
        celebration: Celebration? = nil
    ) {
        self.tier = tier
        self.occupants = occupants
        self.amenities = amenities
        self.ambience = ambience
        self.celebration = celebration
    }
}

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

    /// The full-input initializer WS-E codes against and WS-C fills in.
    ///
    /// Scaffold behavior: delegates to the existing composer with the
    /// input's tier, occupants and amenities, and ignores `ambience`,
    /// `celebration` and `onTapOccupant` — so it draws exactly what the
    /// older initializers draw. The two of those are kept as wrappers.
    public init(input: OfficeSceneInput, onTapOccupant: ((UUID) -> Void)? = nil) {
        self.init(tier: input.tier, occupants: input.occupants, amenities: input.amenities)
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
