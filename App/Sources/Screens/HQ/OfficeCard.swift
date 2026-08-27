import PixelKit
import SwiftUI
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
    /// Drives the "moving day" wipe when the tier changes.
    @State private var movingDay = false

    @Environment(GameShell.self) private var shell

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
                        sceneLabel: sceneAccessibilityLabel
                    )
                )
            }
            .overlay { movingDayWipe }
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
        .onChange(of: engine.state.company.officeTier) { _, _ in
            movingDay = true
            Sounds.play(.goal)
            Task {
                try? await Task.sleep(for: .milliseconds(1100))
                withAnimation(.easeOut(duration: 0.35)) { movingDay = false }
            }
        }
        .sheet(isPresented: $showingAmenities) {
            AmenitiesSheet(engine: engine)
        }
        .fullScreenCover(isPresented: $showingCityMap) {
            CityMapScreen(engine: engine)
        }
    }

    /// Everything the scene needs, as one `Hashable` value. WS-C's
    /// director reads `ambience` and `celebration`; until then they carry
    /// their defaults and the scene draws exactly as it did before.
    private var sceneInput: OfficeSceneInput {
        OfficeSceneInput(
            tier: tierStyle,
            occupants: occupants,
            amenities: amenityStyles
        )
    }

    /// The moving-day wipe: a panel drops over the card while the scene
    /// underneath swaps to the new tier.
    @ViewBuilder private var movingDayWipe: some View {
        if movingDay {
            ZStack {
                Theme.pixelInk.opacity(0.92)
                VStack(spacing: Theme.Spacing.sm) {
                    PixelText(text: "Moving day", scale: 3, color: Theme.pixelPaper)
                    Text("Welcome to the \(engine.state.company.officeTier.displayName)")
                        .font(.footnote)
                        .foregroundStyle(Theme.pixelPaper.opacity(0.8))
                }
            }
            .transition(.move(edge: .bottom))
            .allowsHitTesting(false)
            .accessibilityLabel(
                "Moving day. Welcome to the \(engine.state.company.officeTier.displayName)."
            )
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
    /// people come and go. The founder is left out while away.
    private var occupants: [Occupant] {
        engine.state.employees
            .filter { !($0.isFounder && founderIsAway) }
            .sorted { lhs, rhs in
                if lhs.isFounder != rhs.isFounder { return lhs.isFounder }
                return lhs.hiredDay < rhs.hiredDay
            }
            .map { employee in
                Occupant(
                    id: employee.id,
                    appearance: CharacterAppearance(seed: employee.appearanceSeed),
                    status: workStatus(for: employee),
                    isFounder: employee.isFounder
                )
            }
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
        .buttonStyle(.plain)
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
        .buttonStyle(.plain)
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
                        .font(.caption)
                        .monospacedDigit()
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
            .font(.system(.caption, design: .rounded).weight(.semibold))
            .monospacedDigit()
            .foregroundStyle(headcount >= cap ? Theme.warning : .secondary)
            .padding(.horizontal, Theme.Spacing.sm)
            .padding(.vertical, 2)
            .background(Theme.chipBackground, in: Capsule())
            .contentTransition(.numericText())
            .animation(.spring(duration: 0.35), value: headcount)
            .accessibilityLabel("\(headcount) of \(cap) desks filled")
    }
}

/// The office scene inside an `EquatableView`, so it only recomposes when
/// the scene's own input actually changes.
private struct OfficeScenePanel: View, Equatable {
    let input: OfficeSceneInput
    let sceneLabel: String

    var body: some View {
        OfficeSceneView(input: input)
            .frame(maxWidth: .infinity)
            .accessibilityLabel(sceneLabel)
    }

    nonisolated static func == (lhs: OfficeScenePanel, rhs: OfficeScenePanel) -> Bool {
        lhs.input == rhs.input && lhs.sceneLabel == rhs.sceneLabel
    }
}
