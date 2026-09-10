import PixelKit
import SwiftUI
import TycoonEngine

/// Where a tap in the office goes.
///
/// The scene says what was touched (`OfficeHitRegion.Kind`); this says
/// what that means in the game, as a pure function of the state so a test
/// can pin the map: a person opens their page, the coffee machine its
/// menu, the whiteboard the build in flight (or the flow that starts one),
/// the door hiring, the founder's desk the work schedule.
enum OfficeTapDestination: Equatable, Identifiable {
    /// Somebody's page: morale, pay, the levers.
    case person(UUID)
    /// The coffee machine's menu: coffee with someone, or dinner for all.
    case coffee
    /// The build in flight.
    case product(UUID)
    /// Nothing in flight: start one.
    case newProduct
    /// The door: hiring.
    case hiring
    /// The founder's desk: the work schedule, theirs and the team's.
    case work
    // MARK: K6 (home and rooms)
    /// A plant: the morning papers, whose one tap the plant is the floor of.
    case morningDesk
    /// The window: the city map.
    case city
    /// A built amenity: the amenities sheet, where its break is.
    case amenities
    // MARK: end K6

    var id: String {
        switch self {
        case .person(let id): "person.\(id.uuidString)"
        case .coffee: "coffee"
        case .product(let id): "product.\(id.uuidString)"
        case .newProduct: "newProduct"
        case .hiring: "hiring"
        case .work: "work"
        // MARK: K6 (home and rooms)
        case .morningDesk: "morningDesk"
        case .city: "city"
        case .amenities: "amenities"
        // MARK: end K6
        }
    }

    /// The destination for a region, or `nil` for a tap on somebody who
    /// has since left.
    static func destination(for kind: OfficeHitRegion.Kind, state: GameState) -> OfficeTapDestination? {
        switch kind {
        case .person(let id):
            guard let employee = state.employee(id: id) else { return nil }
            // The founder's levers are not in the manage sheet (it says so
            // itself); their desk is the work schedule, and so are they.
            return employee.isFounder ? .work : .person(id)
        case .coffeeMachine:
            return .coffee
        case .whiteboard:
            return state.productInDevelopment.map { .product($0.id) } ?? .newProduct
        case .door:
            return .hiring
        case .founderDesk:
            return .work
        // MARK: Iteration 10 — M6 (the bug hunt)
        //
        // A bug opens nothing. It is the one thing in the room that is
        // finished by the tap itself, so `OfficeCard.handleTap` takes it
        // before it ever gets here.
        case .bug:
            return nil
        // MARK: K6 (home and rooms) — the room's other things answer too
        case .plant:
            return .morningDesk
        case .window:
            return .city
        case .amenity:
            return .amenities
        // MARK: end K6
        }
    }

    /// What VoiceOver says a tap does, after the scene has said what the
    /// thing is.
    static func accessibilityHint(for kind: OfficeHitRegion.Kind, state: GameState) -> String? {
        // MARK: Iteration 10 — M6 (the bug hunt)
        if case .bug = kind { return "Squashes it" }
        return switch destination(for: kind, state: state) {
        case .person: "Opens their page"
        case .coffee: "Coffee with someone, or dinner for the team"
        case .product(let id): "Opens \(state.product(id: id)?.name ?? "the build")"
        case .newProduct: "Starts a product"
        case .hiring: "Opens hiring"
        case .work: "Opens the work schedule"
        // MARK: K6 (home and rooms)
        case .morningDesk: "Opens the morning papers"
        case .city: "Opens the city map"
        case .amenities: "Opens the amenities, where a break is called"
        // MARK: end K6
        case nil: nil
        }
    }
}

// MARK: - The sheets a tap opens

/// The work schedule as a sheet — the card that carries both switches,
/// the founder's hours and the team's pace — so the founder's desk opens
/// it without leaving HQ.
struct WorkScheduleSheet: View {
    let engine: GameEngine

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                WorkScheduleCard(engine: engine)
                    .padding(Theme.Spacing.lg)
            }
            .background(Theme.screenBackground)
            .navigationTitle("Work")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

/// The product in development as a sheet, so the whiteboard opens it
/// where the player is instead of switching them to the Products tab.
struct ProductSheet: View {
    let engine: GameEngine
    let productID: UUID

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ProductDetailScreen(engine: engine, productID: productID)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                    }
                }
        }
    }
}

// MARK: - The first-time hint

/// The one line under the office the first time: the scene is the
/// interface now, and nothing about a picture says "tap me". Dismisses
/// like the coach tips — by its own X, remembered in `GameSettings` — and
/// on the first tap that lands, which is the proof it was read.
struct OfficeTapHint: View {
    /// The `GameSettings.dismissedTips` key.
    static let tipID = "tip.office_tap"

    let dismiss: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: Theme.Spacing.sm) {
            Image(systemName: "hand.tap.fill")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.accent)
                .frame(width: 22)
            Text("Tap anyone — or the whiteboard, the coffee machine, the door.")
                .font(.footnote)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Button {
                Haptics.tap()
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.pressableRow)
            .accessibilityLabel("Dismiss tip")
        }
        .accessibilityElement(children: .contain)
    }
}

// MARK: - Iteration 10 — M6 (the bug hunt)

/// One bug on the office floor, as HQ tracks it.
///
/// PixelKit's `OfficeBug` knows an id and a desk; this adds the build the
/// bug came off — which is what the engine needs to take one off
/// `openBugs` — and the moment it was squashed, which is what keeps the
/// splat on screen for half a second before the floor is clean again.
struct BugHuntBug: Identifiable, Equatable {
    let id: Int
    let seat: Int
    let productID: UUID
    var squashedAt: Date?

    var isSquashed: Bool { squashedAt != nil }

    /// The scene's view of it.
    var officeBug: OfficeBug {
        OfficeBug(id: id, seat: seat, isSquashed: isSquashed)
    }
}

/// Decides what is crawling on the office floor.
///
/// Every rule here is a rule about *drawing*: nothing in this type changes
/// a number, and nothing spawns unless a build in flight already has an
/// open bug on it. A run nobody opens HQ in is a run with no bugs in it,
/// which is exactly why the pacing bots never see one.
enum BugHuntSpawner {
    /// How long a splat sits on the floor before the bug is forgotten.
    static let splatLifetime: TimeInterval = 0.55

    /// How often HQ looks at the floor. Fast enough that a squash clears
    /// promptly, slow enough to be free.
    static let tick: Duration = .milliseconds(250)

    /// Which desk each person is at, by id — PixelKit's own seating rule,
    /// so a bug is at the desk the player can see that person sitting at.
    static func seats(in input: OfficeSceneInput) -> [UUID: Int] {
        var seats: [UUID: Int] = [:]
        for seat in OfficeBehaviors.seating(for: input) {
            seats[seat.occupant.id] = seat.index
        }
        return seats
    }

    /// The desks a build's bugs may crawl in front of: the people assigned
    /// to it who have a desk, and failing that the founder's own — a solo
    /// garage still has a floor.
    static func desks(
        for productID: UUID, state: GameState, seats: [UUID: Int], tier: OfficeTierStyle
    ) -> [Int] {
        let assigned = state.employees
            .filter { $0.assignment == .product(productID) }
            .compactMap { seats[$0.id] }
            .sorted()
        return assigned.isEmpty ? [tier.deskCapacity] : assigned
    }

    /// The floor one moment later: splats swept up, bugs whose build has
    /// gone clean or gone out of the door removed, and one new bug spawned
    /// while there is room for it.
    ///
    /// Spawning one at a time rather than filling the room is deliberate.
    /// Three bugs appearing together read as an infestation; one, then
    /// another, then another reads as a build going wrong while you watch.
    static func advance(
        _ bugs: [BugHuntBug],
        state: GameState,
        balance: BalanceConfig,
        input: OfficeSceneInput,
        nextID: inout Int,
        now: Date = Date(),
        splatLifetime: TimeInterval = splatLifetime,
        countingSplats: Bool = false
    ) -> [BugHuntBug] {
        let huntable = BugHunt.huntableBuilds(in: state)
        let byID = Dictionary(uniqueKeysWithValues: huntable.map { ($0.id, $0) })

        var live = bugs.filter { bug in
            if let squashedAt = bug.squashedAt {
                return now.timeIntervalSince(squashedAt) < splatLifetime
            }
            // A build that shipped, or that the team cleaned up while the
            // player watched, takes its bugs with it.
            return byID[bug.productID] != nil
        }

        // One bug per open bug on the board, never more than the balance's
        // ceiling — and they keep crawling after the day's cap is spent, so
        // the refusal has something to refuse.
        let openBugs = huntable.reduce(0) { total, product in
            total + Self.openBugs(product)
        }
        let wanted = min(balance.bugHunt.maxOnScreen, openBugs)
        let onFloor = countingSplats ? live.count : live.filter { !$0.isSquashed }.count
        guard onFloor < wanted, let build = spawnTarget(huntable, live: live) else { return live }

        let desks = desks(
            for: build.id, state: state, seats: seats(in: input), tier: input.tier
        )
        // Spread them over the desks on the build, and never two on one:
        // two bugs on one desk overlap into an unreadable smudge, and a
        // build with one person on it is a build with one bug out at a
        // time.
        let taken = Set(live.map(\.seat))
        guard let desk = desks.first(where: { !taken.contains($0) }) else { return live }
        nextID += 1
        live.append(BugHuntBug(id: nextID, seat: desk, productID: build.id))
        return live
    }

    /// Which build the next bug comes off: the one whose open bugs are
    /// least represented on the floor already.
    private static func spawnTarget(_ huntable: [Product], live: [BugHuntBug]) -> Product? {
        huntable.max { lhs, rhs in
            (openBugs(lhs) - live.filter { $0.productID == lhs.id }.count)
                < (openBugs(rhs) - live.filter { $0.productID == rhs.id }.count)
        }
    }

    private static func openBugs(_ product: Product) -> Int {
        guard case .development(let dev) = product.stage else { return 0 }
        return dev.openBugs
    }
}
