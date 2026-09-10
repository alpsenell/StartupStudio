import Foundation

/// A small, portable, deterministic random source.
///
/// `Hasher` is seeded per process, so anything built on `hashValue` would
/// give a different office every launch. SplitMix64 over the raw bytes of a
/// UUID gives the same answer on every machine, every run, forever — which
/// is what "same seed, same game" means for the scene as well as for the
/// simulation.
struct OfficeRandom {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed &+ 0x9E37_79B9_7F4A_7C15
    }

    /// Seeds from an occupant id and the office day, so one person's
    /// routine is stable within a day and different from tomorrow's.
    init(id: UUID, day: Int, salt: UInt64 = 0) {
        var folded: UInt64 = 0xCBF2_9CE4_8422_2325
        for byte in withUnsafeBytes(of: id.uuid, Array.init) {
            folded = (folded ^ UInt64(byte)) &* 0x0000_0100_0000_01B3
        }
        folded ^= UInt64(bitPattern: Int64(day)) &* 0x9E37_79B9_7F4A_7C15
        self.init(seed: folded ^ salt)
    }

    mutating func next() -> UInt64 {
        state = state &+ 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// A uniform integer in `range`.
    mutating func int(_ range: ClosedRange<Int>) -> Int {
        let span = UInt64(range.upperBound - range.lowerBound + 1)
        return range.lowerBound + Int(next() % span)
    }

    /// A uniform double in `0..<1`.
    mutating func unit() -> Double {
        Double(next() >> 11) * (1.0 / 9_007_199_254_740_992.0)
    }

    mutating func chance(_ probability: Double) -> Bool {
        unit() < probability
    }

    /// One element, or nil for an empty collection.
    mutating func pick<T>(_ values: [T]) -> T? {
        values.isEmpty ? nil : values[int(0...(values.count - 1))]
    }

    /// `count` distinct elements, in the collection's own order.
    mutating func sample<T>(_ values: [T], count: Int) -> [T] {
        guard count > 0, !values.isEmpty else { return [] }
        var indices = Array(values.indices)
        var chosen: [Int] = []
        for _ in 0..<min(count, values.count) {
            let pick = int(0...(indices.count - 1))
            chosen.append(indices.remove(at: pick))
        }
        return chosen.sorted().map { values[$0] }
    }
}

/// Turns a room full of occupants into a day's worth of plans.
///
/// The rules, in one place:
///
/// - Everybody has a desk and always comes back to it.
/// - Two to four times an "office day" (four real-time minutes) a person
///   gets up: a coffee run, a look out of the window, a stretch by the
///   plant, a turn on the arcade, lunch, the treadmill.
/// - Friends visit each other's desks and stand there talking.
/// - When something is in development, two or three people huddle at the
///   flip-chart in the middle of the floor.
/// - Nobody who is idle sits still for long; they drift around the floor.
/// - No two people ever stand on the same spot: waypoints are reserved,
///   and an excursion that cannot get a free one simply does not happen.
///
/// Every decision comes from `OfficeRandom(id:day:)`, so the same office on
/// the same day always plays out identically — including in tests and in
/// the PNG frame sheets.
public enum OfficeBehaviors {
    /// How long an "office day" is in real seconds before everyone's
    /// routine reshuffles. Four minutes, matching the ambience loop.
    public static let dayLength: TimeInterval = 240

    /// How long someone stands at a waypoint before heading back.
    static let dwellRange = 4...9
    /// How long a huddle at the flip-chart runs.
    static let huddleDuration: TimeInterval = 24
    /// How long two friends talk.
    static let chatDuration: TimeInterval = 16

    // MARK: - Seating

    /// Who sits where, following exactly the rule the static composer uses:
    /// the founder gets their own desk in front, everyone else fills the
    /// grid in order, and the overflow is not drawn.
    ///
    /// - Returns: desk index → occupant, for the people actually present.
    public static func seating(
        for input: OfficeSceneInput
    ) -> [(index: Int, occupant: Occupant)] {
        let tier = input.tier
        let founders = input.occupants.filter(\.isFounder)
        let employees = input.occupants.filter { !$0.isFounder }
        // MARK: S1 (seating)
        // The player's plan first; everybody it does not name fills the
        // free desks in the same order as below. With no plan this block
        // is skipped and the rule is exactly what it always was.
        if !input.seats.isEmpty {
            return planned(tier: tier, founders: founders, employees: employees, seats: input.seats)
        }
        // MARK: end S1
        let regulars = Array((founders.dropFirst() + employees).prefix(tier.deskCapacity))

        var seats: [(Int, Occupant)] = []
        for (index, occupant) in regulars.enumerated() {
            seats.append((index, occupant))
        }
        if let founder = founders.first {
            seats.append((tier.deskCapacity, founder))
        }
        return seats.map { (index: $0.0, occupant: $0.1) }
    }

    // MARK: S1 (seating)
    /// The seating with a plan: named occupants at their desks (a desk that
    /// does not exist, or one somebody earlier in desk order already took,
    /// is ignored), then the rest in order into the free desks, the
    /// overflow undrawn, the founder at their own desk. Sorted by desk, so
    /// the result is as deterministic as the rule it replaces.
    private static func planned(
        tier: OfficeTierStyle,
        founders: [Occupant],
        employees: [Occupant],
        seats plan: [UUID: Int]
    ) -> [(index: Int, occupant: Occupant)] {
        let regulars = Array(founders.dropFirst()) + employees
        var byDesk: [Int: Occupant] = [:]
        let named = regulars
            .compactMap { occupant in plan[occupant.id].map { (desk: $0, occupant: occupant) } }
            .sorted { ($0.desk, $0.occupant.id.uuidString) < ($1.desk, $1.occupant.id.uuidString) }
        for seat in named where seat.desk >= 0 && seat.desk < tier.deskCapacity && byDesk[seat.desk] == nil {
            byDesk[seat.desk] = seat.occupant
        }
        let seated = Set(byDesk.values.map(\.id))
        var next = 0
        for occupant in regulars where !seated.contains(occupant.id) {
            while next < tier.deskCapacity, byDesk[next] != nil { next += 1 }
            guard next < tier.deskCapacity else { break }
            byDesk[next] = occupant
        }
        var seats = byDesk.keys.sorted().map { (index: $0, occupant: byDesk[$0]!) }
        if let founder = founders.first {
            seats.append((index: tier.deskCapacity, occupant: founder))
        }
        return seats
    }
    // MARK: end S1

    /// Who is actually in the building.
    ///
    /// On a weekend the office is nearly empty: the founder is in (they
    /// always are), plus the one or two people whose deterministic draw
    /// makes them today's workhorses. Anyone flagged `isAway` is out
    /// whatever the day.
    public static func present(
        for input: OfficeSceneInput, dayIndex: Int
    ) -> Set<UUID> {
        let seated = seating(for: input).map(\.occupant).filter { !$0.isAway }
        guard input.ambience.isWeekend else { return Set(seated.map(\.id)) }

        var present = Set(seated.filter(\.isFounder).map(\.id))
        let others = seated.filter { !$0.isFounder }
        var rng = OfficeRandom(seed: UInt64(bitPattern: Int64(dayIndex)) &* 0x2545_F491_4F6C_DD1D)
        let workhorses = rng.sample(others.map(\.id), count: min(2, others.count))
        // One on a quiet weekend, two when the draw says so.
        present.formUnion(workhorses.prefix(rng.chance(0.5) ? 1 : 2))
        return present
    }

    // MARK: - Plans

    /// Everyone's day, keyed in the seating order the composer uses.
    public static func plans(for input: OfficeSceneInput, dayIndex: Int) -> [ActorPlan] {
        let tier = input.tier
        let seats = seating(for: input)
        let here = present(for: input, dayIndex: dayIndex)
        let attending = seats.filter { here.contains($0.occupant.id) }
        guard !attending.isEmpty else { return [] }

        let waypoints = OfficeWaypoints.all(for: tier, amenities: input.amenities)
        let corridor = OfficeWaypoints.corridorY(for: tier)
        var reservations: [String: [(start: TimeInterval, end: TimeInterval)]] = [:]

        func isFree(_ id: String, from start: TimeInterval, to end: TimeInterval) -> Bool {
            guard let taken = reservations[id] else { return true }
            return !taken.contains { start < $0.end + 1 && $0.start - 1 < end }
        }

        func reserve(_ id: String, from start: TimeInterval, to end: TimeInterval) {
            reservations[id, default: []].append((start, end))
        }

        // Deterministic processing order — the seating order, which is
        // itself a pure function of the input.
        var visits: [UUID: [PlannedVisit]] = [:]

        // 1. Huddles come first: they are the loudest thing in the room and
        //    should not lose a waypoint to a coffee run.
        let huddleSlots = waypoints.filter { $0.kind == .whiteboard }
        if isBuildingSomething(input), attending.count >= 3, !huddleSlots.isEmpty {
            var rng = OfficeRandom(seed: UInt64(bitPattern: Int64(dayIndex &* 7717)) &+ 0x51)
            let start = TimeInterval(rng.int(20...Int(dayLength - huddleDuration - 40)))
            let party = rng.sample(attending, count: min(huddleSlots.count, rng.int(2...3)))
            for (offset, seat) in party.enumerated() {
                let slot = huddleSlots[offset]
                guard isFree(slot.id, from: start, to: start + huddleDuration) else { continue }
                reserve(slot.id, from: start, to: start + huddleDuration)
                visits[seat.occupant.id, default: []].append(
                    plannedVisit(
                        tier: tier, seatIndex: seat.index, waypoint: slot,
                        arrive: start, dwell: huddleDuration,
                        pose: .chat, bubble: offset == 0 ? .chatter : nil,
                        corridor: corridor
                    )
                )
            }
        }

        // 2. Friends visiting friends. Only the lower id sets off, so a pair
        //    never walks past each other in opposite directions.
        let seatByID = Dictionary(uniqueKeysWithValues: attending.map { ($0.occupant.id, $0) })
        for seat in attending {
            let friends = seat.occupant.friendIDs
                .filter { seatByID[$0] != nil && $0.uuidString > seat.occupant.id.uuidString }
                .sorted { $0.uuidString < $1.uuidString }
            guard let friendID = friends.first, let friendSeat = seatByID[friendID] else { continue }
            var rng = OfficeRandom(id: seat.occupant.id, day: dayIndex, salt: 0xC4A7)
            guard rng.chance(0.6) else { continue }

            let start = TimeInterval(rng.int(15...Int(dayLength - chatDuration - 30)))
            let slotID = "deskside.\(friendSeat.index)"
            guard isFree(slotID, from: start, to: start + chatDuration) else { continue }
            reserve(slotID, from: start, to: start + chatDuration)

            let anchor = OfficeWaypoints.desksideAnchor(tier: tier, index: friendSeat.index)
            visits[seat.occupant.id, default: []].append(
                plannedVisit(
                    tier: tier, seatIndex: seat.index,
                    waypoint: Waypoint(id: slotID, kind: .deskside, anchor: anchor),
                    arrive: start, dwell: chatDuration,
                    pose: .chat, bubble: .chatter,
                    corridor: corridor
                )
            )
            // The friend turns away from the screen for the same window,
            // without leaving their chair.
            visits[friendID, default: []].append(
                PlannedVisit(
                    waypointID: "desk", anchor: OfficeWaypoints.deskAnchor(tier: tier, index: friendSeat.index),
                    pose: .chat, bubble: nil,
                    depart: start, arrive: start, leave: start + chatDuration, back: start + chatDuration,
                    outbound: nil, inbound: nil
                )
            )
        }

        // 3. Everything else: the ordinary comings and goings.
        for seat in attending {
            var rng = OfficeRandom(id: seat.occupant.id, day: dayIndex)
            let occupant = seat.occupant
            let wanted = occupant.status == .idle ? rng.int(4...6) : rng.int(2...4)
            let menu = excursionMenu(for: occupant, waypoints: waypoints)
            guard !menu.isEmpty else { continue }

            var attempts = 0
            var made = 0
            while made < wanted, attempts < wanted * 4 {
                attempts += 1
                guard let waypoint = rng.pick(menu) else { break }
                let dwell = TimeInterval(rng.int(dwellRange))
                let arrive = TimeInterval(rng.int(6...Int(dayLength - dwell - 40)))
                let visit = plannedVisit(
                    tier: tier, seatIndex: seat.index, waypoint: waypoint,
                    arrive: arrive, dwell: dwell,
                    pose: pose(for: waypoint.kind, mood: occupant.mood), bubble: bubble(for: waypoint.kind),
                    corridor: corridor
                )
                let existing = visits[occupant.id] ?? []
                guard !existing.contains(where: { $0.overlaps(visit) }) else { continue }
                guard isFree(waypoint.id, from: visit.arrive, to: visit.leave) else { continue }
                reserve(waypoint.id, from: visit.arrive, to: visit.leave)
                visits[occupant.id, default: []].append(visit)
                made += 1
            }

            // A stretch at the desk costs nothing and nobody has to queue.
            if rng.chance(0.7) {
                let start = TimeInterval(rng.int(8...Int(dayLength - 12)))
                let stretch = PlannedVisit(
                    waypointID: "desk",
                    anchor: OfficeWaypoints.deskAnchor(tier: tier, index: seat.index),
                    pose: .cheer, bubble: nil,
                    depart: start, arrive: start, leave: start + 3, back: start + 3,
                    outbound: nil, inbound: nil
                )
                if !(visits[occupant.id] ?? []).contains(where: { $0.overlaps(stretch) }) {
                    visits[occupant.id, default: []].append(stretch)
                }
            }
        }

        // 4. Lay the visits out on a timeline, desk time in between.
        return attending.map { seat in
            timeline(
                for: seat.occupant,
                seatIndex: seat.index,
                tier: tier,
                visits: (visits[seat.occupant.id] ?? []).sorted { $0.depart < $1.depart }
            )
        }
    }

    // MARK: - Visit plumbing

    /// One trip away from the desk, already timed.
    struct PlannedVisit {
        var waypointID: String
        var anchor: ScenePoint
        var pose: ActorPose
        var bubble: ActorBubble?
        /// Leaves the desk.
        var depart: TimeInterval
        /// Arrives at the waypoint.
        var arrive: TimeInterval
        /// Sets off back.
        var leave: TimeInterval
        /// Sits back down.
        var back: TimeInterval
        var outbound: Track?
        var inbound: Track?

        /// Trips overlap if their whole desk-to-desk spans touch, with a
        /// couple of seconds of slack so nobody teleports between them.
        func overlaps(_ other: PlannedVisit) -> Bool {
            depart < other.back + 2 && other.depart - 2 < back
        }
    }

    private static func plannedVisit(
        tier: OfficeTierStyle,
        seatIndex: Int,
        waypoint: Waypoint,
        arrive: TimeInterval,
        dwell: TimeInterval,
        pose: ActorPose,
        bubble: ActorBubble?,
        corridor: Double
    ) -> PlannedVisit {
        let desk = OfficeWaypoints.deskAnchor(tier: tier, index: seatIndex)
        let lanes = OfficeWaypoints.lanes(for: tier)
        let probe = Track.route(
            from: desk, to: waypoint.anchor, corridorY: corridor, lanes: lanes,
            departingAt: 0, speed: OfficeWaypoints.walkSpeed
        )
        let depart = max(0, arrive - probe.duration)
        let outbound = Track.route(
            from: desk, to: waypoint.anchor, corridorY: corridor, lanes: lanes,
            departingAt: depart, speed: OfficeWaypoints.walkSpeed
        )
        let leave = outbound.end + dwell
        let inbound = Track.route(
            from: waypoint.anchor, to: desk, corridorY: corridor, lanes: lanes,
            departingAt: leave, speed: OfficeWaypoints.walkSpeed
        )
        return PlannedVisit(
            waypointID: waypoint.id,
            anchor: waypoint.anchor,
            pose: pose,
            bubble: bubble,
            depart: depart,
            arrive: outbound.end,
            leave: leave,
            back: inbound.end,
            outbound: outbound,
            inbound: inbound
        )
    }

    /// Stitches the visits into a gapless list of segments over one day.
    private static func timeline(
        for occupant: Occupant,
        seatIndex: Int,
        tier: OfficeTierStyle,
        visits: [PlannedVisit]
    ) -> ActorPlan {
        let seat = SceneComposer.seatOrigin(tier: tier, index: seatIndex)
        let seatPoint = ScenePoint(x: seat.x, y: seat.y)
        let deskAnchor = OfficeWaypoints.deskAnchor(tier: tier, index: seatIndex)
        // Low morale reads through the cloud over the head *and* the
        // slumped shoulders — at the desk as well as away from it. WS-C
        // asked for this line the moment a seated slump existed; it does
        // now (`HomePersonArt.seatedSlumpA`, the standing slump above the
        // hip line over the office chair), so a miserable person no longer
        // types away happily under their own rain cloud.
        let deskPose: ActorPose = occupant.mood == .low ? .seatedSlump : .desk
        var segments: [ActorSegment] = []
        var cursor: TimeInterval = 0

        func deskSegment(from start: TimeInterval, to end: TimeInterval) -> ActorSegment {
            ActorSegment(
                start: start, end: end, pose: deskPose,
                track: Track(parkedAt: seatPoint, from: start),
                bubble: occupant.mood == .low ? .gloom : nil,
                waypointID: "desk"
            )
        }

        for visit in visits where visit.depart >= cursor {
            if visit.depart > cursor {
                segments.append(deskSegment(from: cursor, to: visit.depart))
            }
            if let outbound = visit.outbound, outbound.duration > 0 {
                segments.append(ActorSegment(
                    start: visit.depart, end: visit.arrive, pose: .walk,
                    track: outbound, bubble: visit.bubble, waypointID: visit.waypointID
                ))
            }
            segments.append(ActorSegment(
                start: visit.arrive, end: visit.leave, pose: visit.pose,
                track: Track(parkedAt: visit.anchor, from: visit.arrive),
                bubble: visit.bubble, waypointID: visit.waypointID
            ))
            if let inbound = visit.inbound, inbound.duration > 0 {
                segments.append(ActorSegment(
                    start: visit.leave, end: visit.back, pose: .walk,
                    track: inbound, bubble: nil, waypointID: visit.waypointID
                ))
            }
            cursor = visit.back
        }
        segments.append(deskSegment(from: cursor, to: dayLength))

        return ActorPlan(id: occupant.id, seatIndex: seatIndex, deskAnchor: deskAnchor, segments: segments)
    }

    // MARK: - Choosing what to do

    /// Whether anything is being built right now, inferred from what people
    /// are doing rather than from a field the scene input does not have.
    static func isBuildingSomething(_ input: OfficeSceneInput) -> Bool {
        input.occupants.filter {
            $0.status == .coding || $0.status == .designing || $0.status == .testing
        }.count >= 2
    }

    /// Where this person might go, weighted by repeating the good options.
    private static func excursionMenu(for occupant: Occupant, waypoints: [Waypoint]) -> [Waypoint] {
        var menu: [Waypoint] = []
        for waypoint in waypoints {
            let weight: Int
            switch waypoint.kind {
            case .coffee: weight = 4
            case .cafeteria: weight = 3
            case .gameRoom: weight = occupant.mood == .great ? 3 : 2
            case .gym: weight = 2
            case .window: weight = occupant.mood == .low ? 3 : 2
            case .plant: weight = 2
            case .loiter: weight = occupant.status == .idle ? 5 : 0
            case .door, .whiteboard, .deskside: weight = 0
            }
            menu.append(contentsOf: repeatElement(waypoint, count: weight))
        }
        return menu
    }

    private static func pose(for kind: WaypointKind, mood: MoodLevel) -> ActorPose {
        switch kind {
        case .coffee, .cafeteria: return .coffee
        case .whiteboard, .deskside: return .chat
        default: return mood == .low ? .slump : .stand
        }
    }

    private static func bubble(for kind: WaypointKind) -> ActorBubble? {
        switch kind {
        case .coffee, .cafeteria: .mug
        case .whiteboard, .deskside: .chatter
        default: nil
        }
    }
}
