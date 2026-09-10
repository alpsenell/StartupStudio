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

/// What the company is under, read by the room.
///
/// Each field owns exactly one prop or one lighting change, so the office
/// can show the four things a founder actually worries about — crunch,
/// runway, bugs and people about to leave — and the one offer on the table.
/// The engine already knows all of it; the scene used to know none of it,
/// and inferred crunch from its own cosmetic clock.
public struct OfficePressure: Sendable, Equatable, Hashable {
    /// The team is on crunch pace: the lights stay on night, a pizza box
    /// lands on the founder's desk, and the tempo reads crunch.
    public var crunch: Bool
    /// Weeks of runway, `nil` when there is no burn. Under four, an
    /// envelope pile lands on the founder's desk.
    public var runwayWeeks: Int?
    /// Cash is negative: the coffee machine gets the "out of order" note.
    public var inDebt: Bool
    /// 0…3. Bug bubbles over the coders, more of them the worse it is.
    public var bugLoad: Int
    /// People on notice or being poached: a flattened box under the desk.
    public var departing: Set<UUID>
    /// A buyout on the table: a courier waits at the door.
    public var pendingOffer: Bool

    public init(
        crunch: Bool = false,
        runwayWeeks: Int? = nil,
        inDebt: Bool = false,
        bugLoad: Int = 0,
        departing: Set<UUID> = [],
        pendingOffer: Bool = false
    ) {
        self.crunch = crunch
        self.runwayWeeks = runwayWeeks
        self.inDebt = inDebt
        self.bugLoad = min(3, max(0, bugLoad))
        self.departing = departing
        self.pendingOffer = pendingOffer
    }

    /// Nothing to show.
    public static let none = OfficePressure()

    /// Runway short enough to worry about.
    public var runwayIsShort: Bool { runwayWeeks.map { $0 <= 4 } ?? false }
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
    /// What the company is under. Defaults to nothing, so every existing
    /// caller and preview draws the room it always drew.
    public var pressure: OfficePressure = .none
    /// Honour Reduce Motion: nobody walks, the frame rate drops. Set by
    /// `OfficeSceneView` from the environment; part of the cache key.
    public var reduceMotion = false
    /// The celebration to play, with a token that changes when a *new*
    /// celebration starts.
    public var celebration: Celebration?
    /// What the player's finger is on: the figure or prop gets a one-pixel
    /// outline and, unless motion is reduced, a small bob. `OfficeSceneView`
    /// sets this from its own gesture; a caller sets it to draw the pressed
    /// state on demand (a snapshot). Defaults to nothing pressed.
    public var pressed: OfficeHitRegion.Kind?

    // MARK: Iteration 10 — M6 (the bug hunt)

    /// The bugs crawling in front of the desks right now, live and just
    /// squashed. Defaults to none, so every existing caller, preview and
    /// frame sheet draws exactly the room it always drew.
    public var bugs: [OfficeBug] = []

    // MARK: end Iteration 10 — M6

    // MARK: K6 (home and rooms)
    /// Whether the plants, the windows and the built amenities are things a
    /// finger can land on (iteration 15). Off by default, so every existing
    /// caller, preview, frame sheet and hit-region test sees the four props
    /// it always saw; the app's office card turns it on.
    public var roomRegions = false
    // MARK: end K6

    // MARK: S1 (seating)
    /// Who the player has put at which desk: occupant id → grid desk
    /// index. Empty by default, and then `OfficeBehaviors.seating(for:)`
    /// seats people by its own rule exactly as before; anybody the map does
    /// not name fills the free desks by that same rule.
    public var seats: [UUID: Int] = [:]
    /// Whether every desk in the grid is a thing a finger can land on (the
    /// office card's move mode). Off by default, so every existing caller,
    /// frame sheet and hit-region test sees the regions it always saw.
    public var seatRegions = false
    // MARK: end S1

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
    private let onTapRegion: ((OfficeHitRegion.Kind) -> Void)?
    private let accessibilityHint: ((OfficeHitRegion.Kind) -> String?)?
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
    /// What the player's finger is on right now, and when it landed.
    @State private var pressed: OfficeHitRegion.Kind?
    @State private var pressStart: TimeInterval = 0
    /// Scene-time origin, matching `PixelSceneView`'s own clock.
    @State private var epoch = Date.timeIntervalSinceReferenceDate

    /// How long a press outline may outlive its finger. A touch the system
    /// takes away (a phone call, a scroll that took over) never reports
    /// its end, and an outline round something nobody is pressing is a bug.
    static let pressTimeout: Duration = .seconds(2)

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
    ///   - onTapRegion: called with whatever was tapped — a person, the
    ///     coffee machine, the whiteboard, the door or the founder's desk.
    ///     A tap on a person reaches both callbacks.
    ///   - accessibilityHint: the VoiceOver hint for a region, so the app
    ///     can say what a tap does ("Opens hiring"). PixelKit knows what
    ///     things are, not what they do.
    public init(
        input: OfficeSceneInput,
        onTapOccupant: ((UUID) -> Void)? = nil,
        onTapRegion: ((OfficeHitRegion.Kind) -> Void)? = nil,
        accessibilityHint: ((OfficeHitRegion.Kind) -> String?)? = nil
    ) {
        self.input = input
        self.onTapOccupant = onTapOccupant
        self.onTapRegion = onTapRegion
        self.accessibilityHint = accessibilityHint
        self.sceneSize = SceneComposer.sceneSize(for: input.tier)
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled

    /// The input as drawn: the environment's motion preference folded in,
    /// and the press the view itself is tracking unless the caller pinned
    /// one (a snapshot of the pressed state).
    private var resolvedInput: OfficeSceneInput {
        var copy = input
        // VoiceOver reads the room as a list of things to tap. A list whose
        // entries walk about under the cursor is unusable, so VoiceOver
        // gets the seated, still room that Reduce Motion gets.
        copy.reduceMotion = reduceMotion || voiceOverEnabled
        if copy.pressed == nil { copy.pressed = pressed }
        return copy
    }

    private var timing: OfficeSceneTiming {
        OfficeSceneTiming(
            celebrationStart: celebrationStart,
            statusChanges: statusChanges,
            tap: tap,
            pressStart: pressStart
        )
    }

    public var body: some View {
        let resolved = resolvedInput
        let timing = timing
        PixelSceneView(
            sceneSize: (sceneSize.width, sceneSize.height),
            accessibilityLabel: accessibilityLabel,
            onTapScenePoint: { x, y, t in handleTap(x: x, y: y, at: t) },
            onPress: { press in handlePress(press) }
        ) { t in
            let room = OfficeDirector.compose(
                input: resolved.withHourOfDay(at: t),
                timing: timing,
                at: t
            )
            // MARK: Iteration 10 — M6 (the bug hunt)
            //
            // Merged rather than composed: the director memoizes the room
            // once a second, and a bug moves twelve times in that second.
            // `merging` slots each one in at its own depth, so an empty
            // list returns the director's list untouched — identity for
            // every caller that has never seen a bug.
            return OfficeFX.merging(
                bugs: resolved.bugs, into: room, tier: resolved.tier, at: t
            )
        }
        // To VoiceOver the canvas is one picture. The regions laid over it
        // are the things *in* the picture, so the picture steps aside and
        // the container carries the summary.
        .accessibilityHidden(true)
        .overlay { accessibilityRegions(input: resolved, timing: timing) }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityLabel)
        .task(id: pressed) { await releaseStalePress() }
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

    /// One accessibility element per hit region, laid over the scene where
    /// the region is and refreshed once a second, so the office is
    /// navigable without sight: VoiceOver lands on "Mara, backend dev,
    /// happy" and "Coffee machine" rather than on one picture. Touches
    /// pass straight through to the scene's own gesture.
    private func accessibilityRegions(input: OfficeSceneInput, timing: OfficeSceneTiming) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let t = max(0, context.date.timeIntervalSinceReferenceDate - epoch)
            GeometryReader { proxy in
                let geometry = PixelSceneGeometry(
                    sceneSize: (sceneSize.width, sceneSize.height), viewSize: proxy.size
                )
                let regions = OfficeDirector.hitRegions(
                    input: input.withHourOfDay(at: t), timing: timing, at: t
                )
                ForEach(regions) { region in
                    let rect = geometry.viewRect(
                        x: region.x, y: region.y, width: region.width, height: region.height
                    )
                    Color.clear
                        .frame(width: rect.width, height: rect.height)
                        .position(x: rect.midX, y: rect.midY)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(accessibilityLabel(for: region.kind))
                        .accessibilityHint(accessibilityHint?(region.kind) ?? "")
                        .accessibilityAddTraits(.isButton)
                        .accessibilityAction { activate(region.kind, at: t) }
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func accessibilityLabel(for kind: OfficeHitRegion.Kind) -> String {
        switch kind {
        case .person(let id):
            input.occupants.first { $0.id == id }?.accessibilityLabel ?? "Someone"
        case .coffeeMachine: "Coffee machine"
        case .whiteboard: "Whiteboard"
        case .door: "Door"
        case .founderDesk: "Founder's desk"
        // MARK: Iteration 10 — M6 (the bug hunt)
        case .bug: "A bug, crawling"
        // MARK: K6 (home and rooms)
        case .plant: "A plant"
        case .window: "The window"
        case .amenity(let amenity):
            switch amenity {
            case .gameRoom: "The game room"
            case .cafeteria: "The cafeteria"
            case .gym: "The gym"
            case .shuttle: "The shuttle"
            }
        // MARK: end K6
        // MARK: S1 (seating)
        case .desk(let index):
            OfficeBehaviors.seating(for: input).first { $0.index == index }
                .map { "Desk \(index + 1), \($0.occupant.name ?? "somebody")'s" } ?? "Desk \(index + 1), empty"
        // MARK: end S1
        }
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

    /// Hit-tests against the room as it is drawn — the resolved input, so
    /// that under Reduce Motion (everyone seated) the finger finds people
    /// where they are, not where their walking plan would have had them.
    private func region(x: Int, y: Int, at t: TimeInterval) -> OfficeHitRegion? {
        OfficeDirector.hitTest(
            input: resolvedInput.withHourOfDay(at: t), timing: timing, at: t, x: x, y: y
        )
    }

    private func handleTap(x: Int, y: Int, at t: TimeInterval) {
        guard let region = region(x: x, y: y, at: t) else { return }
        activate(region.kind, at: t)
    }

    private func handlePress(_ press: ScenePress) {
        switch press {
        case .began(let x, let y, let t):
            pressed = region(x: x, y: y, at: t)?.kind
            pressStart = t
        case .ended:
            pressed = nil
        }
    }

    private func activate(_ kind: OfficeHitRegion.Kind, at t: TimeInterval) {
        if case .person(let id) = kind {
            tap = OfficeSceneTiming.Tap(id: id, at: TimeInterval(AnimationClock.secondBucket(at: t)))
            onTapOccupant?(id)
        }
        onTapRegion?(kind)
    }

    /// Takes the outline off a press whose end never arrived.
    private func releaseStalePress() async {
        guard pressed != nil else { return }
        try? await Task.sleep(for: Self.pressTimeout)
        guard !Task.isCancelled else { return }
        pressed = nil
    }
}

extension OfficeSceneInput {
    /// The same input with the hour advanced by the scene's own cosmetic
    /// clock, so the room warms into morning, flattens at midday, goes
    /// amber at dusk and blue at night while the player watches.
    func withHourOfDay(at t: TimeInterval) -> OfficeSceneInput {
        var copy = self
        // Crunch pins the room to night: desk lamps on, windows dark, for
        // as long as the team is on that pace. When it ends the clock
        // resumes from wherever it would have been — the room exhales.
        copy.ambience.timeOfDay = pressure.crunch
            ? .night
            : OfficeAmbience.timeOfDay(
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
