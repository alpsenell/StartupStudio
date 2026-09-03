import PixelKit
import SwiftUI
import TycoonContent
import TycoonEngine

/// The pixel-art office scene card at the top of HQ — the game's face.
/// Shows the current office tier with every employee at a desk (and any
/// amenities built), a headcount pill against the tier's desk cap, the
/// amenities entry point, and — until the studio reaches campus — the
/// upgrade affordance for the next tier.
///
/// Mirrors `CardView`'s header styling by hand because this card carries
/// trailing accessories in the header row.
struct OfficeCard: View {
    let engine: GameEngine

    @State private var showingAmenities = false
    @State private var showingCityMap = false
    @State private var confirmingUpgrade = false
    /// The person a tap on the scene opened.
    @State private var tappedEmployeeID: UUID?

    @Environment(GameShell.self) private var injectedShell: GameShell?
    /// See `GameShell.shared`: read optionally, because SwiftUI
    /// updates this property for presented content before the
    /// environment is installed and the non-optional form traps there.
    private var shell: GameShell { injectedShell ?? .shared }

    var body: some View {
        let state = engine.state
        let cap = engine.balance.office(state.company.officeTier).headcountCap

        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "building.2.fill")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.accent)
                Text("Office")
                    .font(.system(.footnote, design: .rounded).weight(.semibold))
                    .textCase(.uppercase)
                    .kerning(0.6)
                    .foregroundStyle(.secondary)
                Spacer(minLength: Theme.Spacing.sm)
                if founderIsAway {
                    FounderAwayChip(reason: state.life.awayReason)
                }
                ForEach(ownedAmenities, id: \.self) { amenity in
                    AmenityChip(amenity: amenity)
                }
                HeadcountPill(headcount: state.headcount, cap: cap)
            }

            PixelPanel(contentPadding: Theme.Spacing.xs) {
                // Equatable input + EquatableView: HQ observes `state`,
                // which mutates 4x a second at 4x speed. Without this the
                // whole scene recomposes on every tick even when nothing
                // about the office changed.
                EquatableView(
                    content: OfficeScenePanel(
                        input: sceneInput,
                        sceneLabel: sceneAccessibilityLabel,
                        onTapOccupant: { id in
                            guard engine.state.employee(id: id) != nil else { return }
                            Haptics.tap()
                            tappedEmployeeID = id
                        }
                    )
                )
            }
            .frame(maxWidth: .infinity)

            Divider()
            AmenitiesRow(ownedCount: ownedAmenities.count) {
                showingAmenities = true
            }

            Divider()
            CityMapRow(
                district: state.city.district,
                owned: state.city.ownership.isOwned
            ) {
                showingCityMap = true
            }

            if let next = state.company.officeTier.next {
                Divider()
                UpgradeRow(
                    next: next,
                    def: engine.balance.office(next),
                    cash: state.company.cash
                ) {
                    confirmingUpgrade = true
                }
            }
        }
        .cardStyle()
        // Moving day: the scene above re-renders with the new tier; add a
        // success haptic so the moment lands.
        .sensoryFeedback(.success, trigger: state.company.officeTier)
        .confirmationDialog(
            "Move into the \(engine.state.company.officeTier.next?.displayName ?? "next office")?",
            isPresented: $confirmingUpgrade,
            titleVisibility: .visible
        ) {
            if let next = engine.state.company.officeTier.next {
                Button("Pay \(engine.balance.office(next).upgradeCost.money) and move") {
                    shell.toasts.send(
                        .upgradeOffice,
                        to: engine,
                        rejected: "The move fell through - check the cash."
                    )
                }
            }
            Button("Stay put", role: .cancel) {}
        } message: {
            if let next = engine.state.company.officeTier.next {
                Text(
                    "Rent goes from \(engine.balance.office(engine.state.company.officeTier).weeklyRent.money) to \(engine.balance.office(next).weeklyRent.money) a week, every week, and the old space is gone."
                )
            }
        }
        // The move itself is now WS-C's transition inside the scene — a
        // band of light sweeping down the new room — so the card no longer
        // drops a panel over it. The sound stays.
        .onChange(of: engine.state.company.officeTier) { _, _ in
            Sounds.play(.goal)
        }
        .sheet(isPresented: $showingAmenities) {
            AmenitiesSheet(engine: engine)
        }
        .fullScreenCover(isPresented: $showingCityMap) {
            CityMapScreen(engine: engine)
        }
        .sheet(item: Binding(get: { tappedEmployeeID.map(IdentifiedUUID.init) },
                             set: { tappedEmployeeID = $0?.id })) { picked in
            EmployeeManageSheet(engine: engine, employeeID: picked.id)
        }
    }

    /// Everything the scene needs, as one `Hashable` value: who is in the
    /// room and what mood they are in, who their friends are, what they
    /// would say if tapped, the weather and whether it is the weekend, and
    /// the celebration the last day or two earned.
    private var sceneInput: OfficeSceneInput {
        var input = OfficeSceneInput(
            tier: tierStyle,
            occupants: occupants,
            amenities: amenityStyles,
            ambience: ambience,
            celebration: celebration
        )
        input.pressure = pressure
        return input
    }

    /// What the company is under, for the room to show: the pace, the
    /// runway, the bugs in the builds, who is on their way out, and an
    /// offer on the table. All of it read from state the engine already
    /// keeps; none of it changes anything.
    private var pressure: OfficePressure {
        let state = engine.state
        let cash = state.company.cash
        let burn = engine.weeklyBurn
        let runway: Int? = burn > 0 && cash >= 0 ? cash / burn : nil

        // The worst build's bug count, in three steps.
        let worstBugs = state.productsInDevelopment.reduce(0) { worst, product in
            guard case .development(let dev) = product.stage else { return worst }
            return max(worst, dev.openBugs)
        }
        let bugLoad = worstBugs >= 12 ? 3 : worstBugs >= 6 ? 2 : worstBugs >= 2 ? 1 : 0

        var departing: Set<UUID> = []
        if let notice = state.economy.pendingResignation { departing.insert(notice.employeeID) }
        if let poach = state.rivals.pendingPoach { departing.insert(poach.employeeID) }
        let patience = engine.balance.staff.quitStreakDays
        for employee in state.employees where !employee.isFounder
            && patience - employee.lowMoraleStreakDays <= 3 && employee.lowMoraleStreakDays > 0 {
            departing.insert(employee.id)
        }

        return OfficePressure(
            crunch: state.economy.workPace == .crunch,
            runwayWeeks: runway,
            inDebt: cash < 0,
            bugLoad: bugLoad,
            departing: departing,
            pendingOffer: state.rivals.pendingBuyout != nil
        )
    }

    /// The room's own weather and light. WS-C's four-minute clock rolls the
    /// hours on its own; what the game supplies is where it starts, what is
    /// falling past the window, whether it is the weekend (the room thins
    /// out) and how the team is feeling.
    private var ambience: OfficeAmbience {
        let calendar = engine.state.calendar
        let weather: Weather = switch calendar.season {
        case .winter: .snow
        case .autumn: .rain
        case .spring, .summer: .clear
        }
        // Crunch is carried by `pressure` now (it pins the room to night);
        // the clock always starts on morning.
        return OfficeAmbience(
            timeOfDay: .morning,
            weather: weather,
            isWeekend: calendar.isWeekend,
            teamMood: Self.mood(averageMorale)
        )
    }

    /// The most recent thing worth a cheer, if it happened in the last day
    /// or two, with a token that only moves when a *new* one lands — so a
    /// view rebuild never replays a celebration.
    ///
    /// The token is `day × 100 + the event's position within that day`,
    /// which is monotonic and survives the event log being trimmed from the
    /// front (an index into the log would not).
    private var celebration: OfficeSceneInput.Celebration? {
        var latest: (kind: SceneCelebration, day: Int, ordinal: Int)?
        var day = -1
        var ordinal = 0
        for event in engine.state.eventLog {
            let eventDay = EventDay.of(event)
            if eventDay != day {
                day = eventDay
                ordinal = 0
            }
            guard let kind = Self.celebrationKind(event) else { continue }
            latest = (kind, eventDay, ordinal)
            ordinal += 1
        }
        guard let latest, engine.state.day - latest.day <= 1 else { return nil }
        return OfficeSceneInput.Celebration(
            kind: latest.kind,
            token: latest.day * 100 + latest.ordinal
        )
    }

    private static func celebrationKind(_ event: GameEvent) -> SceneCelebration? {
        switch event {
        case .reviewsIn(_, let averageScore, _): .shipped(score: averageScore)
        case .hired(let employeeID, _): .hired(employeeID)
        case .employeeQuit(let employeeID, _, _): .quit(employeeID)
        case .employeePoached(let employeeID, _, _, _): .quit(employeeID)
        case .officeUpgraded: .officeUpgraded
        case .researchCompleted: .researchComplete
        case .contractDelivered: .contractDelivered
        default: nil
        }
    }

    private var averageMorale: Double {
        let staff = engine.state.employees.filter { !$0.isFounder }
        guard !staff.isEmpty else { return 60 }
        return staff.reduce(0) { $0 + $1.morale } / Double(staff.count)
    }

    private static func mood(_ morale: Double) -> MoodLevel {
        switch morale {
        case ..<38: .low
        case ..<70: .okay
        default: .great
        }
    }

    /// `OfficeTier` and `OfficeTierStyle` share raw values by design;
    /// the fallback is defensive and should never trigger.
    private var tierStyle: OfficeTierStyle {
        OfficeTierStyle(rawValue: engine.state.company.officeTier.rawValue) ?? .garage
    }

    /// Built amenities in catalog order (a `Set` has no stable order).
    private var ownedAmenities: [Amenity] {
        Amenity.allCases.filter { engine.state.amenities.contains($0) }
    }

    /// `Amenity` and `AmenityStyle` share raw values by design; anything
    /// PixelKit can't draw is simply left out of the scene.
    private var amenityStyles: Set<AmenityStyle> {
        Set(engine.state.amenities.compactMap { AmenityStyle(rawValue: $0.rawValue) })
    }

    /// Travelling founder (vacation, conference, ...): their desk sits empty.
    private var founderIsAway: Bool {
        engine.state.life.isAway(day: engine.state.day)
    }

    /// Founder first, then by hire day, so desk placement stays stable as
    /// people come and go. An away founder keeps their desk — WS-C draws an
    /// empty chair with a note on the monitor rather than closing the gap.
    private var occupants: [Occupant] {
        let state = engine.state
        return state.employees
            .sorted { lhs, rhs in
                if lhs.isFounder != rhs.isFounder { return lhs.isFounder }
                return lhs.hiredDay < rhs.hiredDay
            }
            .map { employee in
                Occupant(
                    id: employee.id,
                    appearance: CharacterAppearance(seed: employee.appearanceSeed),
                    status: workStatus(for: employee),
                    isFounder: employee.isFounder,
                    mood: Self.mood(employee.morale),
                    friendIDs: friendIDs(of: employee.id),
                    speech: speech(for: employee),
                    role: roleLook(for: employee),
                    name: employee.name,
                    isAway: employee.isFounder && founderIsAway
                )
            }
    }

    /// Who this person will get up and go and talk to. Only real bonds —
    /// the director walks friends to each other's desks, and a room where
    /// everybody is everybody's friend is a room nobody sits down in.
    private func friendIDs(of id: UUID) -> [UUID] {
        engine.state.friendships
            .filter { $0.involves(id) && $0.strength >= 40 }
            .sorted { $0.strength > $1.strength }
            .compactMap { $0.other(than: id) }
    }

    /// The line on their name plate, out of WS-B's dialogue catalog, chosen
    /// for their traits, their mood and what they are doing. Seeded on the
    /// person and the day so it is stable for a day and different tomorrow.
    private func speech(for employee: Employee) -> String? {
        let context: DialogueContext = if engine.state.economy.workPace == .crunch {
            .crunch
        } else {
            switch employee.assignment {
            case .idle: .idle
            case .support: .coding
            default: .coding
            }
        }
        return engine.content.dialogue.line(
            for: employee.traits,
            mood: Int(employee.morale),
            context: context,
            seed: employee.appearanceSeed &+ UInt64(engine.state.day / 7)
        )
    }

    /// `EmployeeRole` and `RoleLook` share raw values by design; the
    /// founder always wears the hoodie.
    private func roleLook(for employee: Employee) -> RoleLook {
        employee.isFounder ? .founder : (RoleLook(rawValue: employee.role.rawValue) ?? .none)
    }

    /// Maps a simulation assignment onto a cosmetic desk status. Department
    /// staff (legal, HR, ops) work their department whenever they're not
    /// idle; builders show their role's bubble on a product or contract,
    /// the flask while researching.
    private func workStatus(for employee: Employee) -> WorkStatus {
        if case .idle = employee.assignment { return .idle }

        switch employee.role {
        case .lawyer: return .legal
        case .hr: return .peopleOps
        case .ops: return .operations
        case .founder, .frontend, .backend, .designer, .qa, .marketer: break
        }

        if case .research = employee.assignment { return .researching }

        return switch employee.role {
        case .qa: .testing
        case .designer: .designing
        case .marketer: .marketing
        case .frontend, .backend: .coding
        case .founder:
            employee.skills.coding >= employee.skills.design ? .coding : .designing
        case .lawyer, .hr, .ops: .idle // handled above
        }
    }

    private var sceneAccessibilityLabel: String {
        let tier = engine.state.company.officeTier.displayName
        let count = occupants.count
        var base = "\(tier) office scene, \(count) \(count == 1 ? "person" : "people") at work"
        if !ownedAmenities.isEmpty {
            base += ", with " + ownedAmenities.map(\.displayName).joined(separator: ", ")
        }
        return founderIsAway ? base + ", founder away" : base
    }
}

/// Icon-only capsule in the card header for each amenity already built.
private struct AmenityChip: View {
    let amenity: Amenity

    var body: some View {
        Image(systemName: amenity.systemImage)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(Theme.positiveCash)
            .padding(.horizontal, Theme.Spacing.xs + 2)
            .padding(.vertical, 3)
            .background(Theme.positiveCash.opacity(0.15), in: Capsule())
            .accessibilityLabel("\(amenity.displayName) built")
    }
}

/// In-card entry point for the amenities sheet (nav-bar toolbars sit
/// underneath the opaque top HUD in this design, so actions live in
/// content).
private struct AmenitiesRow: View {
    let ownedCount: Int
    let open: () -> Void

    private var summary: String {
        ownedCount == 0
            ? "Nothing built yet"
            : "\(ownedCount) of \(Amenity.allCases.count) built"
    }

    var body: some View {
        Button(action: open) {
            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: "sofa.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Amenities")
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(summary)
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: Theme.Spacing.sm)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressableRow)
        .accessibilityLabel("Amenities, \(summary.lowercased())")
        .accessibilityHint("Opens the amenities sheet")
    }
}

/// In-card entry point for the city map, mirroring `AmenitiesRow`.
private struct CityMapRow: View {
    let district: DistrictID
    let owned: Bool
    let open: () -> Void

    private var summary: String {
        "\(district.displayName) · \(owned ? "owned" : "renting")"
    }

    var body: some View {
        Button(action: open) {
            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: "map.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text("City map")
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: Theme.Spacing.sm)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressableRow)
        .accessibilityLabel("City map, office in \(summary.lowercased())")
        .accessibilityHint("Opens the city map")
    }
}

/// Small warning capsule in the card header while the founder is out of
/// the office.
private struct FounderAwayChip: View {
    let reason: String?

    var body: some View {
        Label("Founder away: \(reason ?? "out")", systemImage: "airplane.departure")
            .font(.caption2.weight(.semibold))
            .lineLimit(1)
            .foregroundStyle(Theme.warning)
            .padding(.horizontal, Theme.Spacing.xs + 2)
            .padding(.vertical, 2)
            .background(Theme.warning.opacity(0.15), in: Capsule())
            .accessibilityLabel("Founder away: \(reason ?? "out of the office")")
    }
}

/// The next-tier upgrade affordance: what you get, what it costs, and the
/// button that sends `.upgradeOffice`. Disabled with a subtle reason while
/// the studio can't afford the move.
private struct UpgradeRow: View {
    let next: OfficeTier
    let def: BalanceConfig.OfficeDef
    let cash: Int
    let upgrade: () -> Void

    private var canAfford: Bool { cash >= def.upgradeCost }
    private var shortfall: Int { def.upgradeCost - cash }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack(spacing: Theme.Spacing.md) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Next: \(next.displayName)")
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    Text("\(def.upgradeCost.money) · \(def.headcountCap) desks · \(def.weeklyRent.money)/wk rent")
                        .font(Theme.Typography.number(.caption, weight: .regular))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: Theme.Spacing.sm)
                Button("Upgrade", action: upgrade)
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                    .tint(Theme.accent)
                    .disabled(!canAfford)
            }
            if !canAfford {
                Text("Need \(shortfall.money) more")
                    .font(.footnote)
                    .monospacedDigit()
                    .foregroundStyle(.tertiary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        let summary = "Upgrade to the \(next.displayName) for \(def.upgradeCost.money): "
            + "\(def.headcountCap) desks, \(def.weeklyRent.money) weekly rent."
        return canAfford ? summary : summary + " Need \(shortfall.money) more."
    }
}

/// Compact "3/3 desks" capsule for the card header.
private struct HeadcountPill: View {
    let headcount: Int
    let cap: Int

    var body: some View {
        Text("\(headcount)/\(cap) desks")
            .font(Theme.Typography.number(.caption))
            .foregroundStyle(headcount >= cap ? Theme.warning : .secondary)
            .padding(.horizontal, Theme.Spacing.sm)
            .padding(.vertical, 2)
            .background(Theme.chipBackground, in: Capsule())
            .contentTransition(.numericText())
            .animation(Theme.Motion.valueChange, value: headcount)
            .accessibilityLabel("\(headcount) of \(cap) desks filled")
    }
}

/// The office scene inside an `EquatableView`, so it only recomposes when
/// the scene's own input actually changes.
private struct OfficeScenePanel: View, Equatable {
    let input: OfficeSceneInput
    let sceneLabel: String
    let onTapOccupant: (UUID) -> Void

    var body: some View {
        OfficeSceneView(input: input, onTapOccupant: onTapOccupant)
            .frame(maxWidth: .infinity)
            .accessibilityLabel(sceneLabel)
    }

    /// The closure is deliberately excluded: it is recreated on every body
    /// evaluation but always does the same thing, and comparing it would
    /// defeat the whole point of the `EquatableView`.
    nonisolated static func == (lhs: OfficeScenePanel, rhs: OfficeScenePanel) -> Bool {
        lhs.input == rhs.input && lhs.sceneLabel == rhs.sceneLabel
    }
}

/// `UUID` wrapper so a tapped person can drive a `sheet(item:)`.
private struct IdentifiedUUID: Identifiable {
    let id: UUID
}
