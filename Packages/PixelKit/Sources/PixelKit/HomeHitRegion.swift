import Foundation

/// A piece of the home a finger — or VoiceOver's cursor — can land on, and
/// where it is in the scene, in the same pixel space `PlacedSprite` lives
/// in.
///
/// The office's `OfficeHitRegion` is the pattern. The difference is that
/// the home does not move: `HomeSceneComposer.compose` is a pure function
/// of the tier, the household, the activity, the mood, the hour and the
/// signals, with no walking and no director clock. So the regions are a
/// pure function of the same six things, computed once when the view is
/// built and never again — which is what keeps VoiceOver's focus still.
public struct HomeHitRegion: Sendable, Equatable, Hashable, Identifiable {
    /// What was hit: one of the people who live here, or a fixture.
    public enum Kind: Sendable, Equatable, Hashable {
        /// The founder — the player.
        case founder
        /// The founder's partner.
        case partner
        /// One of the children, by the id the app gave them.
        case child(UUID)
        /// A piece of the room.
        case furniture(HomeFixture)

        public var isPerson: Bool {
            switch self {
            case .founder, .partner, .child: true
            case .furniture: false
            }
        }
    }

    public var kind: Kind
    public var x: Int
    public var y: Int
    public var width: Int
    public var height: Int
    /// Higher is read first. People come before the furniture they are
    /// sitting on, so VoiceOver's first stop in the room is somebody in it.
    public var sortPriority: Double

    /// At most one region per kind in a scene, so the kind is the identity.
    public var id: Kind { kind }

    public init(kind: Kind, x: Int, y: Int, width: Int, height: Int, sortPriority: Double? = nil) {
        self.kind = kind
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.sortPriority = sortPriority ?? (kind.isPerson ? 1 : 0)
    }

    public func contains(x px: Int, y py: Int) -> Bool {
        px >= x && px < x + width && py >= y && py < y + height
    }
}

/// A fixture in the home, named. The composer tags every piece of
/// furniture it places with a `SpriteLibrary.HomePropName`; this is the
/// subset a person would name out loud, plus the words to name it with.
///
/// PixelKit knows what things *are*. What they mean — that the laundry is
/// a mood reading and the sticky note is the rent — is the app's to say,
/// through `HomeSceneView`'s hint closure.
public enum HomeFixture: String, Sendable, Equatable, Hashable, CaseIterable {
    case bed, couch, armchair, diningTable, television, fridge, stove, crib
    case lamp, window, bookshelf, fireplace, plant, deadPlant, flowers
    case laundry, takeaway, yogaMat, dumbbells, suitcase

    /// How VoiceOver names it.
    public var accessibilityName: String {
        switch self {
        case .bed: "The bed"
        case .couch: "The sofa"
        case .armchair: "The armchair"
        case .diningTable: "The dining table"
        case .television: "The television"
        case .fridge: "The fridge"
        case .stove: "The cooker"
        case .crib: "The crib"
        case .lamp: "The lamp"
        case .window: "The window"
        case .bookshelf: "The bookshelf"
        case .fireplace: "The fireplace"
        case .plant: "A house plant"
        case .deadPlant: "A dead house plant"
        case .flowers: "Fresh flowers"
        case .laundry: "A pile of laundry"
        case .takeaway: "Takeaway cartons"
        case .yogaMat: "The yoga mat"
        case .dumbbells: "The dumbbells"
        case .suitcase: "A packed suitcase"
        }
    }

    /// The fixture a placed home prop is, or `nil` for the ones nobody
    /// would point at (the cat bed the composer never places).
    static func of(_ name: SpriteLibrary.HomePropName) -> HomeFixture? {
        switch name {
        case .bed: .bed
        case .couch: .couch
        case .armchair: .armchair
        case .diningTable: .diningTable
        case .tv: .television
        case .fridge: .fridge
        case .stove: .stove
        case .crib: .crib
        case .lamp: .lamp
        case .windowNight, .skylineWindow: .window
        case .bookshelf: .bookshelf
        case .fireplace: .fireplace
        case .plantHome: .plant
        case .deadPlant: .deadPlant
        case .flowerVase: .flowers
        case .laundryPile: .laundry
        case .takeoutBoxes: .takeaway
        case .yogaMat: .yogaMat
        case .dumbbells: .dumbbells
        case .suitcase: .suitcase
        case .catBed: nil
        }
    }
}

extension HomeTierStyle {
    /// The home as a phrase, for the scene's own summary.
    public var accessibilityName: String {
        switch self {
        case .studioFlat: "studio flat"
        case .apartment: "apartment"
        case .house: "house"
        case .penthouse: "penthouse"
        }
    }
}

extension HomeActivity {
    /// What the founder is doing, as a phrase that follows their name.
    /// `nil` for the two `away` variants, where they are not in the room.
    public var accessibilityPhrase: String? {
        switch self {
        case .relaxing: "on the sofa"
        case .sleeping: "asleep in bed"
        case .gaming: "playing a game on the sofa"
        case .dinner: "at dinner"
        case .exercising: "working out on the mat"
        case .reading: "reading"
        case .withBaby: "holding the baby"
        case .crunching: "crashed out on the sofa after a crunch week"
        case .away, .awayPartnerAlone: nil
        }
    }
}

extension MoodLevel {
    /// The founder's mood as a phrase, or `nil` when there is nothing to
    /// say — the bubble over their head is absent for exactly the same
    /// reason.
    public var accessibilityPhrase: String? {
        switch self {
        case .great: "in good spirits"
        case .okay: nil
        case .low: "worn down"
        }
    }
}

extension HomeSceneComposer {
    // MARK: - Hit regions

    /// Everything in the room worth naming: the founder, the partner, every
    /// child, and one region per fixture, in reading order (people first).
    ///
    /// Derived from exactly the placement list `compose` returns, so a
    /// region can never be somewhere the sprite is not. The scene has no
    /// clock, so neither does this.
    public static func hitRegions(
        tier: HomeTierStyle,
        occupants: HomeOccupants,
        activity: HomeActivity,
        mood: MoodLevel,
        ambience: HomeAmbience = .evening,
        signals: HomeSignals = .none
    ) -> [HomeHitRegion] {
        let placements = compose(
            tier: tier, occupants: occupants, activity: activity, mood: mood,
            ambience: ambience, signals: signals
        )
        var people: [HomeHitRegion] = []
        var furniture: [HomeHitRegion] = []
        var seen: Set<HomeHitRegion.Kind> = []
        var childIndex = 0

        func add(_ kind: HomeHitRegion.Kind, _ placement: PlacedSprite, priority: Double) {
            guard !seen.contains(kind) else { return }
            seen.insert(kind)
            let region = HomeHitRegion(
                kind: kind, x: placement.x, y: placement.y,
                width: placement.sprite.width, height: placement.sprite.height,
                sortPriority: priority
            )
            if kind.isPerson { people.append(region) } else { furniture.append(region) }
        }

        for placement in placements {
            switch placement.kind {
            case .person:
                add(.founder, placement, priority: 100)
            case .partner:
                add(.partner, placement, priority: 90)
            case .child:
                // The composer draws children in `occupants.children`
                // order, capped at the tier's spots, so the nth child
                // sprite is the nth child.
                guard childIndex < occupants.childList.count else { break }
                let id = occupants.childList[childIndex].id
                childIndex += 1
                add(.child(id), placement, priority: 80 - Double(childIndex))
            case .homeProp(let name):
                guard let fixture = HomeFixture.of(name) else { break }
                add(.furniture(fixture), placement, priority: 0)
            // The room, the lighting overlay, the mood bubbles, the crib
            // baby and the hand-held extras (controller, book, laptop,
            // cat) are part of the picture, not things in it.
            case .room, .prop, .bubble, .baby, .desk, .monitor,
                 .amenityProp, .cityProp, .highlight:
                break
            }
        }
        // Reading order, which is also the order VoiceOver puts them in
        // from `sortPriority`: the founder, their partner, the children,
        // then the room.
        return people.sorted { $0.sortPriority > $1.sortPriority } + furniture
    }

    /// The region under scene pixel (`x`, `y`), or `nil` when the point
    /// missed everything. People win over the furniture they are on.
    public static func hitTest(
        tier: HomeTierStyle,
        occupants: HomeOccupants,
        activity: HomeActivity,
        mood: MoodLevel,
        ambience: HomeAmbience = .evening,
        signals: HomeSignals = .none,
        x: Int,
        y: Int
    ) -> HomeHitRegion? {
        hitRegions(
            tier: tier, occupants: occupants, activity: activity, mood: mood,
            ambience: ambience, signals: signals
        )
        .filter { $0.contains(x: x, y: y) }
        .max { $0.sortPriority < $1.sortPriority }
    }
}
