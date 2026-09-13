import Foundation

// MARK: S1 (seating)

// Iteration 16 — S1. Who sits next to whom
// (docs/product/iteration-15-pm/meta.md §3, A3 Seating).
//
// The office grid, the plan that says who sits at which desk, and the
// effects a neighbour has — read by `SeatingSystem` (the tick), by
// `EmployeeSystem` (a mentor's output), `RivalSystem` (the door desk),
// `OfficeSecretsSystem` (where the romance and the clique start) and by
// the app, which prints every one of them before the player moves anyone.
//
// **Identity.** Everything here is inert while `Company.seating` is empty:
// `seatingIsSet` is false, no effect is computed, and the app hands
// PixelKit no seats, so the room is drawn by PixelKit's own rule. No bot
// sends `.seatingMove`, so no fixture ever has a seat. No function here
// draws a random number.

/// One seat in the saved plan. `Company.seating` is a dictionary in memory
/// and a desk-sorted array of these on disk, so the bytes never depend on
/// a hash seed.
public struct SeatingEntry: Codable, Equatable, Sendable {
    public var employeeID: UUID
    public var desk: Int

    public init(employeeID: UUID, desk: Int) {
        self.employeeID = employeeID
        self.desk = desk
    }

    /// The plan as the save writes it: by desk, then by id.
    static func sorted(_ seating: [UUID: Int]) -> [SeatingEntry] {
        seating
            .map { SeatingEntry(employeeID: $0.key, desk: $0.value) }
            .sorted { ($0.desk, $0.employeeID.uuidString) < ($1.desk, $1.employeeID.uuidString) }
    }
}

/// The office grid as the engine sees it.
///
/// Mirrors PixelKit, which the engine does not import: the desk counts are
/// `OfficeTierStyle.deskCapacity` and the columns `SceneComposer.layout`'s
/// `cols`, garage to campus. Desk `i` sits in row `i / columns`, column
/// `i % columns`; the founder's own desk is not in the grid — it stands in
/// front of the last row, under its first column.
public enum SeatingLayout {
    /// Desks in the grid (the founder's own desk is extra).
    public static func deskCount(for tier: OfficeTier) -> Int {
        switch tier {
        case .garage: 3
        case .loft: 6
        case .studio: 14
        case .campus: 40
        }
    }

    /// Desks per row.
    public static func columns(for tier: OfficeTier) -> Int {
        switch tier {
        case .garage, .loft: 3
        case .studio: 5
        case .campus: 8
        }
    }

    static func rows(for tier: OfficeTier) -> Int {
        let columns = columns(for: tier)
        return (deskCount(for: tier) + columns - 1) / columns
    }

    /// The desks beside `desk`: left and right in the same row. Nobody
    /// talks across a monitor.
    public static func neighbours(of desk: Int, tier: OfficeTier) -> [Int] {
        let count = deskCount(for: tier)
        let columns = columns(for: tier)
        guard desk >= 0, desk < count else { return [] }
        var result: [Int] = []
        if desk % columns > 0 { result.append(desk - 1) }
        if desk % columns < columns - 1, desk + 1 < count { result.append(desk + 1) }
        return result
    }

    /// The desk right behind the founder's: the last row, first column.
    public static func founderNeighbourDesk(for tier: OfficeTier) -> Int {
        (rows(for: tier) - 1) * columns(for: tier)
    }

    /// The desk a recruiter walks past first. In the garage the door is
    /// the roller door at the back, by the last desk of the only row;
    /// everywhere else people come in at the front left, past the
    /// founder's desk, and the first desk off that aisle is the second in
    /// the last row.
    public static func doorDesk(for tier: OfficeTier) -> Int {
        let columns = columns(for: tier)
        if tier == .garage { return columns - 1 }
        return min(deskCount(for: tier) - 1, founderNeighbourDesk(for: tier) + 1)
    }

    /// "Desk 4": desks are counted from one for people.
    public static func label(_ desk: Int) -> String { "Desk \(desk + 1)" }
}

/// Something a neighbour does, as the engine applies it and the app prints
/// it. Two plans are compared effect by effect to say what a move changes.
public enum SeatingEffect: Equatable, Hashable, Sendable {
    /// A mentor beside somebody weaker in the mentor's best skill.
    case lesson(mentorID: UUID, studentID: UUID, skill: TrainableSkill)
    /// A grumbler's neighbour.
    case grumble(grumblerID: UUID, neighbourID: UUID)
    /// Two neighbours with a bond of `SeatingEffect.friendBondFloor` or more.
    case friends(UUID, UUID)
    /// Whoever sits right behind the founder.
    case founderNeighbour(UUID)
    /// Whoever sits at the desk by the door.
    case door(UUID)

    /// The bond two neighbours need before their desks do anything.
    public static let friendBondFloor = 60.0

    /// Everybody the effect is about.
    public var people: [UUID] {
        switch self {
        case let .lesson(mentor, student, _): [mentor, student]
        case let .grumble(grumbler, neighbour): [grumbler, neighbour]
        case let .friends(a, b): [a, b]
        case let .founderNeighbour(id), let .door(id): [id]
        }
    }
}

/// One line of what a move would do, with whether it is good news.
public struct SeatingLine: Equatable, Hashable, Sendable {
    public enum Tone: Sendable { case good, bad, plain }
    public var text: String
    public var tone: Tone

    public init(_ text: String, tone: Tone) {
        self.text = text
        self.tone = tone
    }
}

/// What putting somebody at a desk would do, before they are moved: who
/// ends up beside them, who swaps with them, and every effect that starts
/// or stops across the whole room.
public struct SeatingPreview: Equatable, Sendable {
    public var employeeID: UUID
    public var desk: Int
    /// Who sits there now and would take the mover's old desk.
    public var swapWithID: UUID?
    /// The mover's old desk, if they had one.
    public var fromDesk: Int?
    /// Who would be beside them.
    public var neighbourIDs: [UUID]
    /// What starts and what stops, the mover's own first.
    public var lines: [SeatingLine]
    /// Why the move cannot be made, or `nil`.
    public var blocker: String?
    /// The first seat of the run: from this move on, neighbours matter.
    public var startsThePlan: Bool
}

extension GameState {
    // MARK: - The plan

    /// Whether the player has seated anybody. Every seating effect reads
    /// this first; false on every bot and every fixture.
    public var seatingIsSet: Bool { !company.seating.isEmpty }

    /// Who sits at which desk today: everybody the saved plan names at a
    /// desk that exists, then everybody else filling the free desks in
    /// hire order — which, with an empty plan, is exactly PixelKit's own
    /// rule (the founder aside, by hire day). The founder is never in it;
    /// anybody past the last desk has none.
    public func seatingPlan() -> [UUID: Int] {
        let count = SeatingLayout.deskCount(for: company.officeTier)
        // By hire day, ties in payroll order: the order HQ hands PixelKit.
        let staff = employees.enumerated()
            .filter { !$0.element.isFounder }
            .sorted { ($0.element.hiredDay, $0.offset) < ($1.element.hiredDay, $1.offset) }
            .map(\.element.id)
        let onStaff = Set(staff)
        var plan: [UUID: Int] = [:]
        var taken = Set<Int>()
        for entry in SeatingEntry.sorted(company.seating)
        where onStaff.contains(entry.employeeID) && entry.desk >= 0 && entry.desk < count
            && !taken.contains(entry.desk) {
            plan[entry.employeeID] = entry.desk
            taken.insert(entry.desk)
        }
        var next = 0
        for id in staff where plan[id] == nil {
            while next < count, taken.contains(next) { next += 1 }
            guard next < count else { break }
            plan[id] = next
            taken.insert(next)
        }
        return plan
    }

    /// The plan the other way round: desk → who sits there.
    static func seatingByDesk(_ plan: [UUID: Int]) -> [Int: UUID] {
        Dictionary(plan.map { ($0.value, $0.key) }, uniquingKeysWith: { first, _ in first })
    }

    /// The desk `employeeID` sits at today, if any.
    public func seatingDesk(of employeeID: UUID) -> Int? {
        seatingPlan()[employeeID]
    }

    /// Who sits at `desk` today.
    public func seatingOccupant(of desk: Int) -> Employee? {
        Self.seatingByDesk(seatingPlan())[desk].flatMap { employee(id: $0) }
    }

    /// The people beside `employeeID` in `plan`, left then right.
    func seatingNeighbourIDs(of employeeID: UUID, in plan: [UUID: Int]) -> [UUID] {
        guard let desk = plan[employeeID] else { return [] }
        let byDesk = Self.seatingByDesk(plan)
        return SeatingLayout.neighbours(of: desk, tier: company.officeTier).compactMap { byDesk[$0] }
    }

    /// The people beside `employeeID` today.
    public func seatingNeighbours(of employeeID: UUID) -> [Employee] {
        seatingNeighbourIDs(of: employeeID, in: seatingPlan()).compactMap { employee(id: $0) }
    }

    // MARK: - The effects

    /// The skill a mentor teaches: their best of the three.
    static func seatingSubject(of mentor: Employee) -> TrainableSkill {
        let skills = mentor.skills
        if skills.coding >= skills.design, skills.coding >= skills.marketing { return .coding }
        return skills.design >= skills.marketing ? .design : .marketing
    }

    static func seatingSkill(_ skill: TrainableSkill, of employee: Employee) -> Double {
        switch skill {
        case .coding: employee.skills.coding
        case .design: employee.skills.design
        case .marketing: employee.skills.marketing
        }
    }

    /// A week's lesson from `mentor` to `student`:
    /// `mentorSkillGain × mentorGainScale × gap / 100`, never past the gap.
    /// Zero when the student is not weaker.
    public static func seatingWeeklyLesson(
        mentor: Employee, student: Employee, balance: BalanceConfig
    ) -> Double {
        let skill = seatingSubject(of: mentor)
        let gap = seatingSkill(skill, of: mentor) - seatingSkill(skill, of: student)
        guard gap >= 1 else { return 0 }
        let gain = balance.relationships.mentorSkillGain * balance.seating.mentorGainScale * gap / 100
        return min(gap, gain)
    }

    /// Every effect `plan` would have on this roster. Pure.
    func seatingEffects(in plan: [UUID: Int], balance: BalanceConfig) -> Set<SeatingEffect> {
        let tier = company.officeTier
        let byDesk = Self.seatingByDesk(plan)
        let byID = Dictionary(employees.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var effects = Set<SeatingEffect>()
        for (id, desk) in plan {
            guard let person = byID[id] else { continue }
            for neighbourDesk in SeatingLayout.neighbours(of: desk, tier: tier) {
                guard let otherID = byDesk[neighbourDesk], let other = byID[otherID] else { continue }
                if person.traits.contains("mentor"),
                   Self.seatingWeeklyLesson(mentor: person, student: other, balance: balance) > 0 {
                    effects.insert(.lesson(mentorID: id, studentID: otherID, skill: Self.seatingSubject(of: person)))
                }
                if person.traits.contains("grumbler") {
                    effects.insert(.grumble(grumblerID: id, neighbourID: otherID))
                }
                if id.uuidString < otherID.uuidString,
                   seatingBond(id, otherID) >= SeatingEffect.friendBondFloor {
                    effects.insert(.friends(id, otherID))
                }
            }
        }
        if let id = byDesk[SeatingLayout.founderNeighbourDesk(for: tier)] {
            effects.insert(.founderNeighbour(id))
        }
        if let id = byDesk[SeatingLayout.doorDesk(for: tier)] {
            effects.insert(.door(id))
        }
        return effects
    }

    /// Today's effects: none at all until the player has seated somebody.
    public func seatingEffects(balance: BalanceConfig) -> Set<SeatingEffect> {
        guard seatingIsSet else { return [] }
        return seatingEffects(in: seatingPlan(), balance: balance)
    }

    /// The bond between two people on payroll (0 when they have none).
    func seatingBond(_ a: UUID, _ b: UUID) -> Double {
        friendships.first { $0.involves(a) && $0.involves(b) }?.strength ?? 0
    }

    /// Everybody teaching somebody today, who therefore gives up
    /// `seating.mentorOutputCost` of their own output. Empty while the plan
    /// is empty.
    public func seatingMentorIDs(balance: BalanceConfig) -> Set<UUID> {
        guard seatingIsSet else { return [] }
        var mentors = Set<UUID>()
        for case let .lesson(mentorID, _, _) in seatingEffects(balance: balance) {
            mentors.insert(mentorID)
        }
        return mentors
    }

    /// The factor a seating puts on one person's daily output: exactly 1
    /// for everybody who is not teaching (and everybody at all while the
    /// plan is empty).
    static func seatingOutputFactor(
        _ employeeID: UUID, mentors: Set<UUID>, balance: BalanceConfig
    ) -> Double {
        mentors.contains(employeeID) ? 1 - balance.seating.mentorOutputCost : 1
    }

    /// Whoever sits at the desk by the door, while there is a plan.
    func seatingDoorOccupantID() -> UUID? {
        guard seatingIsSet else { return nil }
        return Self.seatingByDesk(seatingPlan())[SeatingLayout.doorDesk(for: company.officeTier)]
    }

    /// Pairs of neighbours with a bond of 60 or more, strongest first —
    /// where the office's romance and clique threads start. Empty while
    /// there is no plan.
    func seatingFriendPairs() -> [(a: UUID, b: UUID, strength: Double)] {
        guard seatingIsSet else { return [] }
        let plan = seatingPlan()
        let byDesk = Self.seatingByDesk(plan)
        var pairs: [(a: UUID, b: UUID, strength: Double)] = []
        for (id, desk) in plan {
            for neighbourDesk in SeatingLayout.neighbours(of: desk, tier: company.officeTier) {
                guard let other = byDesk[neighbourDesk], id.uuidString < other.uuidString else { continue }
                let strength = seatingBond(id, other)
                if strength >= SeatingEffect.friendBondFloor { pairs.append((id, other, strength)) }
            }
        }
        return pairs.sorted {
            $0.strength != $1.strength ? $0.strength > $1.strength : $0.a.uuidString < $1.a.uuidString
        }
    }

    // MARK: - Moving somebody

    /// Why `employeeID` cannot be put at `desk`, or `nil`.
    public func seatingMoveBlocker(employeeID: UUID, desk: Int) -> String? {
        guard gameOver == nil else { return "The office is closed." }
        guard let person = employee(id: employeeID) else { return "They have left." }
        if person.isFounder { return "The founder's desk is at the front, and it is theirs." }
        let count = SeatingLayout.deskCount(for: company.officeTier)
        guard desk >= 0, desk < count else {
            return "The \(company.officeTier.displayName) has \(count) desks."
        }
        if seatingPlan()[employeeID] == desk { return "They already sit there." }
        return nil
    }

    /// The plan after the move: the whole room as it sits today, the mover
    /// at `desk`, whoever sat there at the mover's old desk (or without a
    /// desk, if the mover had none).
    func seatingPlanAfterMove(employeeID: UUID, desk: Int) -> (plan: [UUID: Int], swapWithID: UUID?) {
        var plan = seatingPlan()
        let from = plan[employeeID]
        let swap = Self.seatingByDesk(plan)[desk].flatMap { $0 == employeeID ? nil : $0 }
        plan[employeeID] = desk
        if let swap { plan[swap] = from }
        return (plan, swap)
    }

    /// What putting `employeeID` at `desk` would do — the words on the
    /// button in the manage sheet and in the office's move mode. Every
    /// effect that would start and every one that would stop, across the
    /// room, the mover's own first; the first seat of a run turns every
    /// neighbour in the room on at once, and says so.
    public func seatingPreview(
        employeeID: UUID, desk: Int, balance: BalanceConfig
    ) -> SeatingPreview {
        let blocker = seatingMoveBlocker(employeeID: employeeID, desk: desk)
        let before = seatingEffects(balance: balance)
        let move = seatingPlanAfterMove(employeeID: employeeID, desk: desk)
        let after = seatingEffects(in: move.plan, balance: balance)

        var afterState = self
        afterState.company.seating = move.plan
        let started = after.subtracting(before)
        let stopped = before.subtracting(after)

        var lines: [SeatingLine] = []
        if let swap = move.swapWithID {
            let name = seatingFirstName(swap)
            if let from = seatingPlan()[employeeID] {
                lines.append(SeatingLine("\(name) moves to \(SeatingLayout.label(from).lowercased()).", tone: .plain))
            } else {
                lines.append(SeatingLine("\(name) loses their desk: the room is full.", tone: .bad))
            }
        }
        let ordered = { (effects: Set<SeatingEffect>) -> [SeatingEffect] in
            effects.sorted { lhs, rhs in
                let l = lhs.people.contains(employeeID) ? 0 : 1
                let r = rhs.people.contains(employeeID) ? 0 : 1
                if l != r { return l < r }
                return Self.seatingSortKey(lhs) < Self.seatingSortKey(rhs)
            }
        }
        for effect in ordered(started) {
            lines.append(contentsOf: afterState.seatingLines(for: effect, starting: true, balance: balance))
        }
        for effect in ordered(stopped) {
            lines.append(contentsOf: seatingLines(for: effect, starting: false, balance: balance))
        }
        // A mentor who starts or stops teaching pays or stops paying, once.
        let mentorsBefore = Set(before.compactMap { effect -> UUID? in
            if case let .lesson(mentor, _, _) = effect { return mentor }
            return nil
        })
        let mentorsAfter = Set(after.compactMap { effect -> UUID? in
            if case let .lesson(mentor, _, _) = effect { return mentor }
            return nil
        })
        let cost = Int((balance.seating.mentorOutputCost * 100).rounded())
        for mentor in mentorsAfter.subtracting(mentorsBefore).sorted(by: { $0.uuidString < $1.uuidString }) {
            lines.append(SeatingLine("\(seatingFirstName(mentor)) gives up \(cost)% of their own output to teach.", tone: .bad))
        }
        for mentor in mentorsBefore.subtracting(mentorsAfter).sorted(by: { $0.uuidString < $1.uuidString }) {
            lines.append(SeatingLine("\(seatingFirstName(mentor)) gets their \(cost)% back: nobody to teach.", tone: .good))
        }
        if lines.isEmpty {
            lines.append(SeatingLine("Nobody beside them changes anything.", tone: .plain))
        }
        return SeatingPreview(
            employeeID: employeeID,
            desk: desk,
            swapWithID: move.swapWithID,
            fromDesk: seatingPlan()[employeeID],
            neighbourIDs: afterState.seatingNeighbourIDs(of: employeeID, in: move.plan),
            lines: lines,
            blocker: blocker,
            startsThePlan: !seatingIsSet
        )
    }

    /// What one effect means, in words: starting (read against the plan
    /// after the move) or stopping (against today's).
    public func seatingLines(
        for effect: SeatingEffect, starting: Bool, balance: BalanceConfig
    ) -> [SeatingLine] {
        let config = balance.seating
        switch effect {
        case let .lesson(mentorID, studentID, skill):
            guard let mentor = employee(id: mentorID), let student = employee(id: studentID) else { return [] }
            let gain = Self.seatingWeeklyLesson(mentor: mentor, student: student, balance: balance)
            // MARK: T3 (people)
            // J5: the lesson's price, printed under the lesson — what the
            // quarter's skill does to their fair pay and to the recruiters'
            // list, and whether it carries them to the next rung.
            return starting
                ? [SeatingLine("\(seatingFirstName(mentorID)) teaches \(seatingFirstName(studentID)) \(skill.rawValue): +\(Self.seatingNumber(gain)) a week.", tone: .good)]
                    + lessonPriceLines(mentor: mentor, student: student, skill: skill, balance: balance)
                : [SeatingLine("\(seatingFirstName(studentID)) stops learning \(skill.rawValue) from \(seatingFirstName(mentorID)).", tone: .bad)]
            // MARK: end T3
        case let .grumble(grumblerID, neighbourID):
            let delta = Self.seatingNumber(abs(config.grumblerMoraleDelta))
            return starting
                ? [SeatingLine("\(seatingFirstName(neighbourID)) hears \(seatingFirstName(grumblerID)) grumble all day: −\(delta) morale a day.", tone: .bad)]
                : [SeatingLine("\(seatingFirstName(neighbourID)) is out of \(seatingFirstName(grumblerID))'s earshot.", tone: .good)]
        case let .friends(a, b):
            let bond = Int(seatingBond(a, b).rounded())
            return starting
                ? [SeatingLine("\(seatingFirstName(a)) and \(seatingFirstName(b)) (bond \(bond)) sit together: +\(Self.seatingNumber(config.friendBondGain)) bond a week, and it is where office romances start.", tone: .good)]
                : [SeatingLine("\(seatingFirstName(a)) and \(seatingFirstName(b)) no longer sit together.", tone: .plain)]
        case let .founderNeighbour(id):
            return starting
                ? [SeatingLine("\(seatingFirstName(id)) sits behind your desk: +\(Self.seatingNumber(config.founderBondGain)) bond with you a week.", tone: .good)]
                : [SeatingLine("\(seatingFirstName(id)) leaves the desk behind yours.", tone: .plain)]
        case let .door(id):
            return starting
                ? [SeatingLine("\(seatingFirstName(id)) sits by the door: the first desk a recruiter sees.", tone: .bad)]
                : [SeatingLine("\(seatingFirstName(id)) leaves the desk by the door.", tone: .good)]
        }
    }

    func seatingFirstName(_ id: UUID) -> String {
        guard let name = employee(id: id)?.name else { return "Someone" }
        return name.split(separator: " ").first.map(String.init) ?? name
    }

    static func seatingNumber(_ value: Double) -> String {
        value == value.rounded() ? "\(Int(value))" : String(format: "%.1f", value)
    }

    static func seatingSortKey(_ effect: SeatingEffect) -> String {
        switch effect {
        case let .lesson(m, s, _): "0\(m.uuidString)\(s.uuidString)"
        case let .grumble(g, n): "1\(g.uuidString)\(n.uuidString)"
        case let .friends(a, b): "2\(a.uuidString)\(b.uuidString)"
        case let .founderNeighbour(id): "3\(id.uuidString)"
        case let .door(id): "4\(id.uuidString)"
        }
    }
}

// MARK: end S1
