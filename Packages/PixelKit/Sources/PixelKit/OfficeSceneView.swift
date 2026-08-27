import Foundation
import SwiftUI

/// Everything cosmetic about the room's hour and weather. Cosmetic only:
/// the scene advances `timeOfDay` on its own real-time loop, never from a
/// tick.
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

    /// A bright, ordinary weekday.
    public static let plain = OfficeAmbience()

    /// How long the room takes to go round the clock once, in real seconds.
    ///
    /// Four minutes, matching the office day the director's behaviour plans
    /// run on: morning, day, dusk and night each get a quarter of it. This
    /// is deliberately *not* the simulation's day — the room breathing
    /// through the hours is set dressing, and tying it to the tick would
    /// make it lurch at 4× speed and freeze when paused.
    public static let clockPeriod: TimeInterval = 240

    /// The hour the room is at, `dayStart` seconds into the loop.
    ///
    /// The caller's `timeOfDay` picks where the loop *starts*, so an app
    /// that knows it is evening opens on dusk and rolls forward from there;
    /// the default (`.day`) opens at midday. `offset` shifts the phase —
    /// the office view passes the weekday so two consecutive days don't
    /// hit dusk at exactly the same second.
    public static func timeOfDay(
        at t: TimeInterval, startingAt start: TimeOfDay = .day, offset: Int = 0
    ) -> TimeOfDay {
        let order: [TimeOfDay] = [.morning, .day, .dusk, .night]
        let quarter = clockPeriod / 4
        let base = order.firstIndex(of: start) ?? 1
        let steps = Int((max(0, t) + TimeInterval(offset) * quarter / 4) / quarter)
        return order[(base + steps) % order.count]
    }
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
/// `Hashable` so the director can memoize its output per input and the app
/// can wrap the card in an `EquatableView`.
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

/// The office scene: floor and walls per tier, a desk grid, and a room full
/// of people who get up, walk, queue for the coffee machine, huddle at the
/// flip-chart, take a turn on the arcade, cheer when something ships and
/// carry a box out when they quit.
///
/// Scales to fit its width with integer pixel scaling (floored) and
/// letterboxes vertically as needed. Animation is purely cosmetic, driven
/// by a 12 fps timeline — never by the game simulation. The layout comes
/// from `OfficeDirector`, which is a pure function of `(input, timing, t)`,
/// so what the PNG frame sheets show is exactly what ships.
public struct OfficeSceneView: View {
    private let input: OfficeSceneInput
    private let onTapOccupant: ((UUID) -> Void)?
    private let sceneSize: SceneComposer.SceneSize

    /// When the current celebration token first appeared, in scene time.
    @State private var celebrationStart: TimeInterval = 0
    /// The token that `celebrationStart` belongs to.
    @State private var celebrationToken: Int?
    /// When each occupant's status last changed, in scene time.
    @State private var statusChanges: [UUID: TimeInterval] = [:]
    /// The statuses the change map was computed against.
    @State private var knownStatuses: [UUID: WorkStatus] = [:]
    /// The name plate currently on screen.
    @State private var tap: OfficeSceneTiming.Tap?
    /// Scene-time origin, matching `PixelSceneView`'s own clock.
    @State private var epoch = Date.timeIntervalSinceReferenceDate

    /// The plainest office: a tier and the people in it.
    public init(tier: OfficeTierStyle, occupants: [Occupant]) {
        self.init(input: OfficeSceneInput(tier: tier, occupants: occupants))
    }

    /// Office with amenity zones (game room, cafeteria, gym, shuttle). Zones
    /// the tier cannot host are skipped; the scene size never changes.
    public init(tier: OfficeTierStyle, occupants: [Occupant], amenities: Set<AmenityStyle>) {
        self.init(input: OfficeSceneInput(tier: tier, occupants: occupants, amenities: amenities))
    }

    /// The full-input initializer.
    ///
    /// - Parameters:
    ///   - input: tier, occupants, amenities, ambience and the celebration
    ///     to play (with the token that keeps it from replaying on a view
    ///     rebuild).
    ///   - onTapOccupant: called with the id of the person tapped. The
    ///     scene also puts their name plate up for four seconds.
    public init(input: OfficeSceneInput, onTapOccupant: ((UUID) -> Void)? = nil) {
        self.input = input
        self.onTapOccupant = onTapOccupant
        self.sceneSize = SceneComposer.sceneSize(for: input.tier)
    }

    public var body: some View {
        let resolved = input
        let timing = OfficeSceneTiming(
            celebrationStart: celebrationStart,
            statusChanges: statusChanges,
            tap: tap
        )
        PixelSceneView(
            sceneSize: (sceneSize.width, sceneSize.height),
            accessibilityLabel: accessibilityLabel,
            onTapScenePoint: { x, y, t in handleTap(x: x, y: y, at: t) }
        ) { t in
            OfficeDirector.compose(
                input: resolved.withHourOfDay(at: t),
                timing: timing,
                at: t
            )
        }
        .onAppear { syncStatuses() }
        .onChange(of: input.occupants) { syncStatuses() }
        .onChange(of: input.celebration?.token) { startCelebration() }
    }

    private var accessibilityLabel: String {
        let people = input.occupants.count
        let tier = input.tier.rawValue
        return people == 1
            ? "Office scene: the \(tier), one person at work"
            : "Office scene: the \(tier), \(people) people at work"
    }

    /// Scene time right now, on the same clock `PixelSceneView` draws with.
    private var now: TimeInterval {
        max(0, Date.timeIntervalSinceReferenceDate - epoch)
    }

    private func startCelebration() {
        guard let token = input.celebration?.token else {
            celebrationToken = nil
            return
        }
        guard token != celebrationToken else { return }
        celebrationToken = token
        celebrationStart = TimeInterval(AnimationClock.secondBucket(at: now))
    }

    /// Notes which statuses just changed so their bubbles pop for three
    /// seconds. A person who was always doing this gets no bubble — only
    /// the change is worth interrupting the player for.
    private func syncStatuses() {
        let stamp = TimeInterval(AnimationClock.secondBucket(at: now))
        var known = knownStatuses
        var changes = statusChanges
        var present: Set<UUID> = []
        for occupant in input.occupants {
            present.insert(occupant.id)
            if let previous = known[occupant.id], previous != occupant.status {
                changes[occupant.id] = stamp
            }
            known[occupant.id] = occupant.status
        }
        known = known.filter { present.contains($0.key) }
        changes = changes.filter { present.contains($0.key) && stamp - $0.value < OfficeDirector.statusBubbleDuration }
        knownStatuses = known
        statusChanges = changes
    }

    private func handleTap(x: Int, y: Int, at t: TimeInterval) {
        guard let id = OfficeDirector.hitTest(
            input: input.withHourOfDay(at: t), t: t, x: x, y: y
        ) else { return }
        tap = OfficeSceneTiming.Tap(id: id, at: TimeInterval(AnimationClock.secondBucket(at: t)))
        onTapOccupant?(id)
    }
}

private extension OfficeSceneInput {
    /// The same input with the hour advanced by the scene's own cosmetic
    /// clock, so the room warms into morning, flattens at midday, goes
    /// amber at dusk and blue at night while the player watches.
    func withHourOfDay(at t: TimeInterval) -> OfficeSceneInput {
        var copy = self
        copy.ambience.timeOfDay = OfficeAmbience.timeOfDay(
            at: t, startingAt: ambience.timeOfDay,
            offset: ambience.isWeekend ? 2 : 0
        )
        return copy
    }
}

// MARK: - Previews

private func previewID(_ index: Int) -> UUID {
    UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", index))!
}

private func previewOccupants(_ count: Int, seed: UInt64 = 40, moods: [MoodLevel] = [.okay]) -> [Occupant] {
    let names = ["Mara", "Dev", "Nils", "Ines", "Otto", "Suki", "Rafa", "Wren"]
    var people: [Occupant] = []
    for index in 0..<count {
        let friends: [UUID] = index % 3 == 0 && count > 2 ? [previewID((index + 1) % count)] : []
        let appearance = CharacterAppearance(seed: UInt64(index) &+ seed)
        let status = WorkStatus.allCases[index % WorkStatus.allCases.count]
        people.append(Occupant(
            id: previewID(index),
            appearance: appearance,
            status: status,
            isFounder: index == 0,
            mood: moods[index % moods.count],
            friendIDs: friends,
            name: names[index % names.count]
        ))
    }
    return people
}

#Preview("Garage") {
    OfficeSceneView(tier: .garage, occupants: previewOccupants(3, seed: 1))
        .padding()
}

#Preview("Studio, amenities") {
    OfficeSceneView(
        input: OfficeSceneInput(
            tier: .studio,
            occupants: previewOccupants(14, seed: 70, moods: [.okay, .great, .low]),
            amenities: [.gameRoom, .cafeteria, .shuttle, .gym]
        )
    )
    .padding()
}

#Preview("Celebration: shipped") {
    OfficeSceneView(
        input: OfficeSceneInput(
            tier: .studio,
            occupants: previewOccupants(9),
            celebration: .init(kind: .shipped(score: 84), token: 1)
        )
    )
    .padding()
}

#Preview("Celebration: hired") {
    let people = previewOccupants(6)
    return OfficeSceneView(
        input: OfficeSceneInput(
            tier: .loft,
            occupants: people,
            celebration: .init(kind: .hired(people[5].id), token: 1)
        )
    )
    .padding()
}

#Preview("Celebration: quit") {
    let people = previewOccupants(6)
    return OfficeSceneView(
        input: OfficeSceneInput(
            tier: .loft,
            occupants: people,
            celebration: .init(kind: .quit(people[3].id), token: 1)
        )
    )
    .padding()
}

#Preview("Celebration: office upgraded") {
    OfficeSceneView(
        input: OfficeSceneInput(
            tier: .campus,
            occupants: previewOccupants(20, seed: 900),
            celebration: .init(kind: .officeUpgraded, token: 1)
        )
    )
    .padding()
}

#Preview("Celebration: research complete") {
    OfficeSceneView(
        input: OfficeSceneInput(
            tier: .studio,
            occupants: previewOccupants(9),
            celebration: .init(kind: .researchComplete, token: 1)
        )
    )
    .padding()
}

#Preview("Celebration: contract delivered") {
    OfficeSceneView(
        input: OfficeSceneInput(
            tier: .studio,
            occupants: previewOccupants(9),
            celebration: .init(kind: .contractDelivered, token: 1)
        )
    )
    .padding()
}

#Preview("Night, rain") {
    OfficeSceneView(
        input: OfficeSceneInput(
            tier: .campus,
            occupants: previewOccupants(24, seed: 900),
            amenities: [.gameRoom, .cafeteria, .gym],
            ambience: OfficeAmbience(timeOfDay: .night, weather: .rain)
        )
    )
    .padding()
}

#Preview("Weekend") {
    OfficeSceneView(
        input: OfficeSceneInput(
            tier: .studio,
            occupants: previewOccupants(12),
            ambience: OfficeAmbience(timeOfDay: .dusk, isWeekend: true)
        )
    )
    .padding()
}
