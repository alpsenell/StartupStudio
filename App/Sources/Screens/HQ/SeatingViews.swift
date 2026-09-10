import PixelKit
import SwiftUI
import TycoonEngine

// MARK: S1 (seating)

// Iteration 16 — S1: who sits next to whom
// (docs/product/iteration-15-pm/meta.md §3). Tap a person in the office,
// then a desk; the manage sheet's Desk section is the same move for a
// finger that would rather not aim at pixels. Every line printed here is
// read off the engine (`SeatingPreview`, `SeatingEffect`), so a screen can
// never promise what the tick will not do.

/// What the office card's move mode has in hand: somebody picked, and the
/// desk they would go to.
struct SeatingMoveState: Equatable {
    var picked: UUID?
    var target: Int?

    /// The move mode's reading of a tap. People and desks only; everything
    /// else in the room is scenery while desks are being moved.
    mutating func tap(_ kind: OfficeHitRegion.Kind, state: GameState) {
        switch kind {
        case .person(let id):
            guard let person = state.employee(id: id), !person.isFounder else { return }
            if picked == nil || picked == id {
                picked = picked == id ? nil : id
                target = nil
            } else if let desk = state.seatingDesk(of: id) {
                target = desk
            }
        case .desk(let desk):
            if picked != nil {
                target = desk
            } else if let occupant = state.seatingOccupant(of: desk) {
                picked = occupant.id
            }
        default:
            return
        }
    }

    /// What the scene draws pressed: the desk if one is picked, else the
    /// person.
    var pressed: OfficeHitRegion.Kind? {
        if let target { return .desk(target) }
        return picked.map { .person($0) }
    }
}

/// Words shared by the office, the manage sheet, the crew line and the
/// journal.
enum SeatingCopy {
    static func firstName(_ name: String) -> String {
        name.split(separator: " ").first.map(String.init) ?? name
    }

    /// "desk 4", "desk 11 (by the door)", "desk 10 (behind yours)".
    static func desk(_ desk: Int, tier: OfficeTier) -> String {
        var label = "desk \(desk + 1)"
        if desk == SeatingLayout.doorDesk(for: tier) { label += " (by the door)" }
        if desk == SeatingLayout.founderNeighbourDesk(for: tier) { label += " (behind yours)" }
        return label
    }

    /// "beside Sam and Lee", "beside Sam", "nobody beside them".
    static func beside(_ ids: [UUID], state: GameState) -> String {
        let names = ids.compactMap { state.employee(id: $0).map { firstName($0.name) } }
        switch names.count {
        case 0: return "nobody beside them"
        case 1: return "beside \(names[0])"
        default: return "beside \(names.dropLast().joined(separator: ", ")) and \(names.last!)"
        }
    }

    /// The office card's row: what the room's seating is doing today.
    static func summary(state: GameState, balance: BalanceConfig) -> String {
        guard state.seatingIsSet else {
            return "Where they sat down. Seat somebody and neighbours start to matter."
        }
        let effects = state.seatingEffects(balance: balance)
        var teaching = Set<UUID>(), grumbled = Set<UUID>(), pairs = 0
        var door: UUID?
        for effect in effects {
            switch effect {
            case let .lesson(mentor, _, _): teaching.insert(mentor)
            case let .grumble(_, neighbour): grumbled.insert(neighbour)
            case .friends: pairs += 1
            case let .door(id): door = id
            case .founderNeighbour: break
            }
        }
        var parts: [String] = []
        if !teaching.isEmpty { parts.append("\(teaching.count) teaching") }
        if !grumbled.isEmpty { parts.append("\(grumbled.count) beside a grumbler") }
        if pairs > 0 { parts.append("\(pairs) pair\(pairs == 1 ? "" : "s") of friends together") }
        if let door, let person = state.employee(id: door) { parts.append("\(firstName(person.name)) by the door") }
        return parts.isEmpty ? "Seated. Nobody's neighbours do anything yet." : parts.joined(separator: " · ")
    }

    /// The crew line's second factor (K3 prints the first): who on this
    /// build is teaching and paying for it. `nil` when nobody is.
    static func crewSuffix(state: GameState, productID: UUID, balance: BalanceConfig) -> String? {
        let mentors = state.seatingMentorIDs(balance: balance)
        guard !mentors.isEmpty else { return nil }
        let teaching = state.employees.filter {
            mentors.contains($0.id) && $0.assignment == .product(productID)
        }
        guard !teaching.isEmpty else { return nil }
        let factor = String(format: "%.2f", 1 - balance.seating.mentorOutputCost)
        let names = teaching.map { firstName($0.name) }.joined(separator: ", ")
        return " · teaching: \(names) ×\(factor)"
    }

    /// The journal's lines for the two S1 events.
    static func eventLine(_ event: GameEvent, state: GameState) -> (icon: String, message: String, day: Int, tint: Color)? {
        switch event {
        case let .seatingMoved(employeeID, desk, swappedWithID, day):
            let who = state.employee(id: employeeID).map { firstName($0.name) } ?? "Someone"
            var text = "Moved \(who) to \(Self.desk(desk, tier: state.company.officeTier))"
            if let swap = swappedWithID, let other = state.employee(id: swap) {
                text += ". \(firstName(other.name)) took the old desk"
            }
            return ("arrow.left.arrow.right", text, day, Theme.accent)
        case let .seatingCleared(day):
            return ("rectangle.3.group", "Tore up the seating plan. People sit where they like, and nobody's neighbours matter", day, Color.secondary)
        default:
            return nil
        }
    }

    static func color(_ tone: SeatingLine.Tone) -> Color {
        switch tone {
        case .good: Theme.positiveCash
        case .bad: Theme.warning
        case .plain: Theme.pixelInk.opacity(0.8)
        }
    }
}

/// The lines of a preview, each with its tone.
struct SeatingLinesView: View {
    let lines: [SeatingLine]
    var limit = 6
    var ink: Color = Theme.pixelInk

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            ForEach(Array(lines.prefix(limit).enumerated()), id: \.offset) { _, line in
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Rectangle()
                        .fill(SeatingCopy.color(line.tone))
                        .frame(width: 5, height: 5)
                        .accessibilityHidden(true)
                    Text(line.text)
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            if lines.count > limit {
                Text("… and \(lines.count - limit) more")
                    .font(.caption2)
                    .foregroundStyle(ink.opacity(0.7))
            }
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - The office card

/// The office card's row that turns the move mode on and off, with what
/// the room's seating is doing today.
struct SeatingRow: View {
    let engine: GameEngine
    let moving: Bool
    let toggle: () -> Void

    var body: some View {
        Button(action: toggle) {
            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: "chair.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text(moving ? "Done moving desks" : "Desks")
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(SeatingCopy.summary(state: engine.state, balance: engine.balance))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: Theme.Spacing.sm)
                Image(systemName: moving ? "checkmark" : "arrow.left.arrow.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressableRow)
        .accessibilityHint(moving ? "Leaves the move mode" : "Tap a person in the office, then a desk")
    }
}

/// Under the scene while desks are being moved: what to tap next, and
/// once a desk is picked, what the move would do — the same lines the
/// manage sheet prints — on the button that makes it.
struct SeatingMoveStrip: View {
    let engine: GameEngine
    @Binding var move: SeatingMoveState

    @Environment(GameShell.self) private var injectedShell: GameShell?
    private var shell: GameShell { injectedShell ?? .shared }
    @State private var confirmingClear = false

    var body: some View {
        let state = engine.state
        PixelPanel(contentPadding: Theme.Spacing.md) {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                PixelSectionTitle(title: "Moving desks")
                if let picked = move.picked, let person = state.employee(id: picked) {
                    if let target = move.target {
                        preview(person: person, desk: target, state: state)
                    } else {
                        Text("\(SeatingCopy.firstName(person.name)) sits at \(state.seatingDesk(of: picked).map { SeatingCopy.desk($0, tier: state.company.officeTier) } ?? "no desk"), \(SeatingCopy.beside(state.seatingNeighbours(of: picked).map(\.id), state: state)). Tap a desk, or somebody to swap with.")
                            .font(.callout)
                            .foregroundStyle(Theme.pixelInk)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } else {
                    Text("Tap somebody, then the desk you want them at. Beside a mentor people learn; beside a grumbler they sulk; the desk by the door is the one a recruiter sees first.")
                        .font(.callout)
                        .foregroundStyle(Theme.pixelInk)
                        .fixedSize(horizontal: false, vertical: true)
                    if state.seatingIsSet {
                        Button(role: .destructive) { confirmingClear = true } label: {
                            Text("Let everyone sit anywhere")
                                .font(.system(.footnote, design: .rounded).weight(.semibold))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(Theme.warning)
                    }
                }
            }
        }
        .confirmationDialog("Tear up the seating plan?", isPresented: $confirmingClear, titleVisibility: .visible) {
            Button("Tear it up", role: .destructive) {
                shell.toasts.send(.seatingClear, to: engine)
                move = SeatingMoveState()
            }
            Button("Keep the plan", role: .cancel) {}
        } message: {
            Text(clearMessage(state))
        }
    }

    @ViewBuilder
    private func preview(person: Employee, desk: Int, state: GameState) -> some View {
        let preview = state.seatingPreview(employeeID: person.id, desk: desk, balance: engine.balance)
        let name = SeatingCopy.firstName(person.name)
        let tier = state.company.officeTier
        Text("\(SeatingCopy.desk(desk, tier: tier).seatingCapitalized): \(SeatingCopy.beside(preview.neighbourIDs, state: state)).")
            .font(.callout)
            .foregroundStyle(Theme.pixelInk)
            .fixedSize(horizontal: false, vertical: true)
        SeatingLinesView(lines: preview.lines)
        if preview.startsThePlan {
            Text("The first seat: from now on everybody's neighbours matter, and the room stays as you leave it.")
                .font(.caption2)
                .foregroundStyle(Theme.pixelInk.opacity(0.7))
                .fixedSize(horizontal: false, vertical: true)
        }
        if let blocker = preview.blocker {
            Text(blocker)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.warning)
        }
        HStack(spacing: Theme.Spacing.sm) {
            Button {
                Haptics.commit()
                shell.toasts.send(
                    .seatingMove(employeeID: person.id, desk: desk), to: engine,
                    rejected: preview.blocker ?? "\(name) stayed where they were."
                )
                move = SeatingMoveState()
            } label: {
                Text("Move \(name) to desk \(desk + 1)")
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
            }
            .buttonStyle(PixelButtonStyle())
            .disabled(preview.blocker != nil)
            Button {
                move.target = nil
            } label: {
                Text("Not there")
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
            }
            .buttonStyle(PixelButtonStyle(fill: Theme.pixelPaper))
        }
    }

    private func clearMessage(_ state: GameState) -> String {
        let count = state.seatingEffects(balance: engine.balance).count
        return count == 0
            ? "People go back to the desks they would take on their own."
            : "People go back to the desks they would take on their own, and all \(count) things their neighbours do stop."
    }
}

// MARK: - The manage sheet

/// The Desk section of a person's page: where they sit, what their
/// neighbours do to them, and every desk in the room to move them to —
/// the move mode's accessible twin, with the same consequence on the
/// button.
struct SeatingDeskSection: View {
    let engine: GameEngine
    let employee: Employee

    @State private var picked: Int?
    @Environment(GameShell.self) private var injectedShell: GameShell?
    private var shell: GameShell { injectedShell ?? .shared }

    var body: some View {
        let state = engine.state
        let tier = state.company.officeTier
        let plan = state.seatingPlan()
        let desk = plan[employee.id]
        let name = SeatingCopy.firstName(employee.name)
        Section {
            LabeledContent("Desk") {
                Text(desk.map { SeatingCopy.desk($0, tier: tier).seatingCapitalized } ?? "None: the office is full")
                    .multilineTextAlignment(.trailing)
            }
            Text(desk == nil ? "Nobody beside them." : SeatingCopy.beside(state.seatingNeighbours(of: employee.id).map(\.id), state: state).seatingCapitalized + ".")
                .font(.caption)
                .foregroundStyle(.secondary)
            let own = state.seatingEffects(balance: engine.balance)
                .filter { $0.people.contains(employee.id) }
                .sorted { "\($0)" < "\($1)" }
                .flatMap { state.seatingLines(for: $0, starting: true, balance: engine.balance) }
            if !own.isEmpty {
                SeatingLinesView(lines: own, ink: .primary)
            }
            deskGrid(plan: plan, tier: tier, state: state)
            if let picked {
                let preview = state.seatingPreview(employeeID: employee.id, desk: picked, balance: engine.balance)
                Button {
                    Haptics.commit()
                    shell.toasts.send(
                        .seatingMove(employeeID: employee.id, desk: picked), to: engine,
                        rejected: preview.blocker ?? "\(name) stayed where they were."
                    )
                    self.picked = nil
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Label("Move \(name) to \(SeatingCopy.desk(picked, tier: tier))", systemImage: "arrow.left.arrow.right")
                        Text(SeatingCopy.beside(preview.neighbourIDs, state: state).seatingCapitalized + ".")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        SeatingLinesView(lines: preview.lines, ink: .primary)
                        if let blocker = preview.blocker {
                            Text(blocker)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Theme.warning)
                        }
                    }
                }
                .disabled(preview.blocker != nil)
            }
        } header: {
            Text("Desk")
        } footer: {
            Text(state.seatingIsSet
                ? "Beside a mentor people learn; beside a grumbler they sulk; friends together get closer; the desk by the door is the one a recruiter sees first."
                : "Nobody's neighbours matter until you seat somebody. The first move keeps everyone else where they are.")
        }
        .task {
            // DEBUG `-autoRoute s1-desk`: the demo's desk already picked.
            if SeatingDebug.liftsDeskSection, picked == nil,
               let demo = DebugLaunch.seatingDemo(engine.state, balance: engine.balance),
               demo.studentID == employee.id {
                picked = demo.desk
            }
        }
    }

    /// The room as a grid of desks, in the office's own columns. The
    /// founder's desk is not in it: it is theirs.
    private func deskGrid(plan: [UUID: Int], tier: OfficeTier, state: GameState) -> some View {
        let byDesk = Dictionary(plan.map { ($0.value, $0.key) }, uniquingKeysWith: { first, _ in first })
        let columns = Array(
            repeating: GridItem(.flexible(), spacing: 4),
            count: SeatingLayout.columns(for: tier)
        )
        return LazyVGrid(columns: columns, spacing: 4) {
            ForEach(0..<SeatingLayout.deskCount(for: tier), id: \.self) { index in
                let occupant = byDesk[index].flatMap { state.employee(id: $0) }
                let isOwn = occupant?.id == employee.id
                Button {
                    Haptics.tap()
                    picked = isOwn ? nil : index
                } label: {
                    VStack(spacing: 0) {
                        Text("\(index + 1)")
                            .font(.caption2.weight(.bold))
                            .monospacedDigit()
                        Text(occupant.map { initials($0.name) } ?? "·")
                            .font(.caption2)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, minHeight: 36)
                    .foregroundStyle(isOwn ? Theme.onTint : Theme.pixelInk)
                    .background(background(isOwn: isOwn, isPicked: picked == index, index: index, tier: tier))
                    .overlay {
                        PixelPanelBorder(thickness: 2, corner: 2)
                            .fill(Theme.pixelInk.opacity(picked == index ? 0.9 : 0.35))
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(deskLabel(index, occupant: occupant, tier: tier, state: state))
                .accessibilityHint(isOwn ? "Their desk" : "Shows what moving them here would do")
            }
        }
        .padding(.vertical, 2)
    }

    private func background(isOwn: Bool, isPicked: Bool, index: Int, tier: OfficeTier) -> Color {
        if isOwn { return Theme.pixelAccent }
        if isPicked { return Theme.pixelAccent.opacity(0.35) }
        if index == SeatingLayout.doorDesk(for: tier) { return Theme.warning.opacity(0.18) }
        return Theme.pixelPaper
    }

    private func initials(_ name: String) -> String {
        name.split(separator: " ").compactMap(\.first).prefix(2).map(String.init).joined()
    }

    private func deskLabel(_ index: Int, occupant: Employee?, tier: OfficeTier, state: GameState) -> String {
        var label = SeatingCopy.desk(index, tier: tier).seatingCapitalized
        if let occupant { label += ", \(occupant.name)'s" } else { label += ", empty" }
        return label
    }
}

private extension String {
    /// "desk 4" → "Desk 4".
    var seatingCapitalized: String { prefix(1).uppercased() + dropFirst() }
}

// MARK: - Debug

/// `-autoRoute s1-…` and `-autoSeating`, read by the office card and the
/// manage sheet (see `DebugLaunch.startSeating`). Debug only.
@MainActor
enum SeatingDebug {
    static var route: String? {
        #if DEBUG
        DebugLaunch.launchRoute.flatMap { $0.hasPrefix("s1-") ? $0 : nil }
        #else
        nil
        #endif
    }

    /// `s1-desk`: the Desk section first in the manage sheet.
    static var liftsDeskSection: Bool { route == "s1-desk" }

    /// The id HQ scrolls to for an `s1-…` screenshot.
    static let officeID = "s1-office"
}

// MARK: end S1
