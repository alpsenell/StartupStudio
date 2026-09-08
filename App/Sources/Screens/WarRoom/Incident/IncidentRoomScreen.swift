import PixelKit
import SwiftUI
import TycoonContent
import TycoonEngine

/// The incident room: a full-screen, stopped-clock mode for the hours after
/// a live product breaks (iteration 10, M3).
///
/// The war room's shape, turned the other way round. There the player
/// watches a week they have already decided; here they run a day they did
/// not ask for. The status page at the top says what the public sees; the
/// board underneath is three lanes — mitigate, communicate, fix — and the
/// whole team to put on them; the hour button spends an hour of everybody's
/// attention and shows what it will buy before it does; the countdown says
/// how many users have walked out while they argued; and the statement is
/// three story-sheet buttons, one of which will be the front page.
///
/// Nothing here reads a wall clock. Every button is a `GameAction`, the
/// room's own hour hand included, so an incident replays exactly.
///
/// Presented from `AppRootView`'s M3 region for as long as
/// `state.incident != nil`. The way out is `Call it` — the room is the
/// interruption, not a screen over one.
struct IncidentRoomScreen: View {
    let engine: GameEngine

    @Environment(\.dismiss) private var dismiss
    @Environment(GameShell.self) private var injectedShell: GameShell?
    /// See `GameShell.shared` and `WarRoomScreen`: read optionally, because
    /// SwiftUI updates a cover's content before the environment is
    /// installed and the non-optional form traps there.
    private var shell: GameShell { injectedShell ?? .shared }

    /// The lane the next tapped portrait joins. The board is a two-tap
    /// assignment rather than a drag: a drag onto a 44-point lane on a
    /// phone, with the room's own scroll view underneath, loses more taps
    /// than it wins.
    @State private var armedThread: IncidentThread?
    /// The statement being read before it is chosen.
    @State private var expandedStatement: String?

    private var incident: IncidentState? { engine.state.incident }
    private var product: Product? {
        incident.flatMap { engine.state.product(id: $0.productID) }
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            ScrollViewReader { scroll in
            ScrollView {
                if let incident, let product {
                    IncidentRoomContent(
                        engine: engine,
                        incident: incident,
                        product: product,
                        armedThread: $armedThread,
                        expandedStatement: $expandedStatement,
                        onAssign: assign,
                        onAdvance: advance,
                        onStatement: chooseStatement,
                        onResolve: resolve
                    )
                    .padding(Theme.Spacing.lg)
                    // `-autoIncidentPlay` photographs the bottom of the
                    // room: a headless pass cannot scroll to it.
                    .task {
                        #if DEBUG
                        guard IncidentDebug.scrollsToStatement else { return }
                        try? await Task.sleep(for: .seconds(2))
                        withAnimation { scroll.scrollTo(IncidentRoomContent.statementAnchor, anchor: .top) }
                        #endif
                    }
                } else {
                    ContentUnavailableView(
                        "All clear",
                        systemImage: "checkmark.shield.fill",
                        description: Text("Nothing is on fire.")
                    )
                    .padding(.top, Theme.Spacing.xl)
                }
            }
            }
        }
        .gameColumn()
        .onAppear {
            Sounds.play(.tap)
            Haptics.commit()
            #if DEBUG
            IncidentDebug.autoplayIfAsked(engine: engine)
            #endif
        }
    }

    // MARK: - Chrome

    /// The room's name, the date, and the hours left. No speed control:
    /// the clock is stopped and the room is what stopped it.
    private var topBar: some View {
        HStack(alignment: .center, spacing: Theme.Spacing.sm) {
            Button {
                Haptics.tap()
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.body.weight(.semibold))
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.pressable)
            .accessibilityLabel("Put the room aside")
            .accessibilityHint("The incident stays open and the clock stays stopped")

            VStack(spacing: 3) {
                PixelText(text: String(localized: "INCIDENT ROOM", comment: "Pixel-font title of the incident room, the stopped-clock screen for a live product that has broken. Uppercase A-Z only — the bitmap font has no accents."), scale: 2, color: Theme.pixelAccent, shadow: true)
                PixelText(text: engine.state.calendar.hudLabel, scale: 1, color: .secondary)
            }
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Incident room, \(engine.state.calendar.longLabel)")

            hoursPill
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.vertical, Theme.Spacing.sm)
        .background(.bar)
        .overlay(alignment: .bottom) { Divider() }
    }

    private var hoursPill: some View {
        let left = max(0, engine.balance.incidents.hoursPerIncident - (incident?.hoursSpent ?? 0))
        return StatPill(
            systemImage: "clock.fill",
            value: "\(left)h",
            tint: left <= 2 ? Theme.warning : .secondary
        )
        .accessibilityLabel(left == 1 ? "One hour left" : "\(left) hours left")
    }

    // MARK: - The actions

    private func assign(_ employeeID: UUID, _ thread: IncidentThread?) {
        Haptics.tap()
        Sounds.play(.tap)
        engine.send(.assignToIncident(employeeID: employeeID, thread: thread))
    }

    private func advance() {
        guard let incident else { return }
        guard incident.hasHoursLeft(engine.balance) else {
            shell.toasts.show(
                "The day is gone. Say something and call it.",
                icon: "clock.badge.exclamationmark",
                tint: Theme.warning,
                severity: .notable
            )
            return
        }
        Haptics.commit()
        Sounds.play(.tap)
        engine.send(.advanceIncident)
    }

    private func chooseStatement(_ id: String) {
        Haptics.commit()
        Sounds.play(.tap)
        engine.send(.chooseIncidentStatement(id: id))
    }

    private func resolve() {
        if let reason = IncidentSystem.resolveBlocker(state: engine.state) {
            shell.toasts.show(
                reason, icon: "exclamationmark.bubble.fill",
                tint: Theme.warning, severity: .notable
            )
            return
        }
        Haptics.commit()
        Sounds.play(.ship)
        shell.toasts.send(.resolveIncident, to: engine, rejected: "The room is not ready to close.")
    }
}

// MARK: - Content

/// Everything in the room below the top bar. Takes the incident rather than
/// reading it, so a static frame can be rendered from a fixture.
struct IncidentRoomContent: View {
    let engine: GameEngine
    let incident: IncidentState
    let product: Product
    @Binding var armedThread: IncidentThread?
    @Binding var expandedStatement: String?
    var onAssign: (UUID, IncidentThread?) -> Void = { _, _ in }
    var onAdvance: () -> Void = {}
    var onStatement: (String) -> Void = { _ in }
    var onResolve: () -> Void = {}

    /// Scroll anchor for the statement panel, so a headless pass can be
    /// pointed at the bottom half of the room.
    static let statementAnchor = "m3.statement"

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            IncidentStatusPage(incident: incident, product: product)
            IncidentBoard(
                engine: engine,
                incident: incident,
                armedThread: $armedThread,
                onAssign: onAssign
            )
            IncidentHourPanel(engine: engine, incident: incident, onAdvance: onAdvance)
            IncidentStatementPanel(
                engine: engine,
                incident: incident,
                product: product,
                expanded: $expandedStatement,
                onChoose: onStatement
            )
            .id(Self.statementAnchor)
            IncidentClosePanel(engine: engine, incident: incident, product: product, onResolve: onResolve)
        }
    }
}

// MARK: - The status page

/// What the public sees: a pixel status band that changes colour as the
/// room works, the kind's headline, and the count of people who have
/// walked out since it started.
struct IncidentStatusPage: View {
    let incident: IncidentState
    let product: Product

    private var tint: Color {
        switch incident.status {
        case .red: Theme.negativeCash
        case .amber: Theme.warning
        case .green: Theme.positiveCash
        }
    }

    /// "<product> STATUS", the heading on the pixel status page.
    private var statusLine: String {
        String(
            format: String(
                localized: "%@ STATUS",
                comment: "Pixel-font heading on a product's public status page during an incident; %@ is the product name. Uppercase A-Z only — the bitmap font has no accents."
            ),
            product.name
        )
    }

    private var headline: String {
        switch incident.status {
        case .red: incident.kind.statusHeadline
        case .amber: "PARTIAL SERVICE"
        case .green: "ALL SYSTEMS GO"
        }
    }

    var body: some View {
        PixelPanel {
            VStack(spacing: Theme.Spacing.sm) {
                HStack(spacing: Theme.Spacing.sm) {
                    Circle()
                        .fill(tint)
                        .frame(width: 14, height: 14)
                        .overlay(Circle().stroke(Theme.pixelInk.opacity(0.4), lineWidth: 2))
                    PixelText(text: statusLine, scale: 2, color: Theme.pixelInk)
                    Spacer(minLength: 0)
                }
                Rectangle()
                    .fill(tint)
                    .frame(height: 6)
                PixelText(text: headline, scale: 3, color: tint, shadow: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(incident.kind.summary)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Divider()
                HStack(alignment: .lastTextBaseline, spacing: Theme.Spacing.sm) {
                    PixelText(text: "\(incident.usersLost)", scale: 5, color: Theme.negativeCash)
                        .id(incident.usersLost)
                        .animation(Theme.Motion.valueChange, value: incident.usersLost)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(incident.usersLost == 1 ? "user gone" : "users gone")
                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        Text("of \(incident.reach.formatted(.number.locale(Theme.gameLocale))) using it")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(product.name) status: \(incident.status.displayName). "
                + "\(incident.usersLost) of \(incident.reach) users gone."
        )
    }
}

// MARK: - The board

/// Three lanes and the whole team. Tap a lane to arm it, then tap anybody
/// to put them on it; tap somebody already on it to take them off.
struct IncidentBoard: View {
    let engine: GameEngine
    let incident: IncidentState
    @Binding var armedThread: IncidentThread?
    var onAssign: (UUID, IncidentThread?) -> Void

    /// Everyone who could be put on a lane: the payroll, founder first,
    /// then by hire day — the same desk order the office uses.
    private var roster: [Employee] {
        engine.state.employees.sorted { lhs, rhs in
            if lhs.isFounder != rhs.isFounder { return lhs.isFounder }
            return lhs.hiredDay < rhs.hiredDay
        }
    }

    var body: some View {
        PixelPanel {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                PixelSectionTitle(title: "The board")
                ForEach(IncidentThread.allCases) { thread in
                    IncidentLaneRow(
                        engine: engine,
                        incident: incident,
                        thread: thread,
                        isArmed: armedThread == thread,
                        onTap: {
                            Haptics.tap()
                            armedThread = armedThread == thread ? nil : thread
                        },
                        onDropPerson: { onAssign($0, thread) }
                    )
                }
                Divider()
                Text(benchHint)
                    .font(.caption)
                    .foregroundStyle(armedThread == nil ? .secondary : Theme.accent)
                    .fixedSize(horizontal: false, vertical: true)
                IncidentBenchRow(
                    engine: engine,
                    incident: incident,
                    roster: roster,
                    armedThread: armedThread,
                    onAssign: onAssign
                )
            }
        }
    }

    private var benchHint: String {
        if let armed = armedThread {
            return "Tap somebody to put them on \(armed.displayName.lowercased()). Tap them again to take them off."
        }
        return "Tap a lane, then tap the people you want on it."
    }
}

/// One lane: its name, what it is for, the bar, and the portraits on it.
private struct IncidentLaneRow: View {
    let engine: GameEngine
    let incident: IncidentState
    let thread: IncidentThread
    let isArmed: Bool
    let onTap: () -> Void
    let onDropPerson: (UUID) -> Void

    private var progress: Double { incident.progress(thread) }

    private var tint: Color {
        switch thread {
        case .mitigate: Theme.warning
        case .communicate: Theme.designPhase
        case .fix: Theme.codePhase
        }
    }

    private var crew: [Employee] {
        let ids = Set(incident.crew(on: thread))
        return engine.state.employees
            .filter { ids.contains($0.id) }
            .sorted { lhs, rhs in
                if lhs.isFounder != rhs.isFounder { return lhs.isFounder }
                return lhs.hiredDay < rhs.hiredDay
            }
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                HStack(spacing: Theme.Spacing.sm) {
                    Text(thread.displayName)
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(thread.blurb)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                    Text("\(Int(progress.rounded()))%")
                        .font(Theme.Typography.number(.caption, weight: .semibold))
                        .foregroundStyle(progress >= 100 ? Theme.positiveCash : tint)
                }
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Theme.chipBackground)
                        Rectangle()
                            .fill(progress >= 100 ? Theme.positiveCash : tint)
                            .frame(width: geometry.size.width * min(1, progress / 100))
                    }
                }
                .frame(height: 10)
                .animation(Theme.Motion.valueChange, value: progress)
                HStack(spacing: Theme.Spacing.xs) {
                    if crew.isEmpty {
                        Text("Nobody on it")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    } else {
                        ForEach(crew, id: \.id) { employee in
                            PixelPortrait(
                                seed: employee.appearanceSeed,
                                isFounder: employee.isFounder,
                                role: RoleLook(rawValue: employee.role.rawValue) ?? .none,
                                size: 26
                            )
                        }
                    }
                    Spacer(minLength: 0)
                }
            }
            .padding(Theme.Spacing.sm)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isArmed ? tint.opacity(0.14) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isArmed ? tint : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.pressableRow)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(thread.displayName), \(Int(progress.rounded())) percent, "
                + (crew.isEmpty ? "nobody on it" : "\(crew.count) on it")
        )
        .accessibilityHint(isArmed ? "Selected. Tap somebody below to put them here." : thread.blurb)
        .accessibilityAddTraits(isArmed ? [.isSelected] : [])
        // Dropping a portrait works too, for anybody who reaches for it.
        .dropDestination(for: String.self) { items, _ in
            guard let id = items.first.flatMap(UUID.init(uuidString:)) else { return false }
            onDropPerson(id)
            return true
        }
    }
}

/// Everybody on the payroll, with the lane they are on written under them.
private struct IncidentBenchRow: View {
    let engine: GameEngine
    let incident: IncidentState
    let roster: [Employee]
    let armedThread: IncidentThread?
    var onAssign: (UUID, IncidentThread?) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.sm) {
                ForEach(roster, id: \.id) { employee in
                    person(employee)
                }
            }
            .padding(.vertical, 2)
        }
    }

    @ViewBuilder
    private func person(_ employee: Employee) -> some View {
        let on = incident.assignments[employee.id]
        let blocker = IncidentSystem.assignBlocker(employeeID: employee.id, state: engine.state)
        Button {
            guard blocker == nil else { return }
            if let armedThread {
                onAssign(employee.id, on == armedThread ? nil : armedThread)
            } else {
                onAssign(employee.id, nil)
            }
        } label: {
            VStack(spacing: 2) {
                PixelPortrait(
                    seed: employee.appearanceSeed,
                    isFounder: employee.isFounder,
                    role: RoleLook(rawValue: employee.role.rawValue) ?? .none,
                    size: 38
                )
                Text(employee.name.split(separator: " ").first.map(String.init) ?? employee.name)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(blocker ?? on?.displayName ?? "Free")
                    .font(.caption2)
                    .foregroundStyle(blocker != nil ? Theme.warning : (on == nil ? .secondary : Theme.accent))
                    .lineLimit(1)
            }
            .frame(width: 66)
            .padding(.vertical, Theme.Spacing.xs)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(on == nil ? Color.clear : Theme.chipBackground)
            )
            .opacity(blocker == nil ? 1 : 0.5)
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressable)
        .disabled(blocker != nil)
        .draggable(employee.id.uuidString)
        .accessibilityLabel("\(employee.name), \(employee.role.displayName)")
        .accessibilityValue(blocker ?? on?.displayName ?? "not assigned")
        .accessibilityHint(
            armedThread.map { "Tap to put them on \($0.displayName.lowercased())" }
                ?? "Pick a lane first"
        )
    }
}

// MARK: - The hour

/// The room's clock, as a button that says what the hour will buy before
/// it is spent.
struct IncidentHourPanel: View {
    let engine: GameEngine
    let incident: IncidentState
    var onAdvance: () -> Void

    private var hoursLeft: Int {
        max(0, engine.balance.incidents.hoursPerIncident - incident.hoursSpent)
    }

    /// What one hour lands on each lane at the current staffing.
    private var gains: [(IncidentThread, Double)] {
        IncidentThread.allCases.map { thread in
            let points = incident.crew(on: thread)
                .compactMap { id in engine.state.employees.first { $0.id == id } }
                .reduce(0.0) { total, employee in
                    total + IncidentSystem.contribution(
                        of: employee, on: thread, state: engine.state, balance: engine.balance
                    )
                }
            return (thread, min(points, max(0, 100 - incident.progress(thread))))
        }
    }

    private var leaving: Int {
        IncidentSystem.leaving(incident, balance: engine.balance)
    }

    private var consequence: String {
        let moves = gains.filter { $0.1 >= 0.5 }
            .map { "+\(Int($0.1.rounded())) \($0.0.displayName.lowercased())" }
        let cost = leaving == 1 ? "1 more user goes" : "\(leaving) more users go"
        guard !moves.isEmpty else { return "Nobody is on anything — \(cost) and nothing moves." }
        return moves.joined(separator: " · ") + " · " + cost
    }

    var body: some View {
        PixelPanel {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                PixelSectionTitle(title: "The hour")
                Text(consequence)
                    .font(.footnote)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button(action: onAdvance) {
                    Label(
                        hoursLeft > 0 ? "Work an hour" : "The day is gone",
                        systemImage: "clock.arrow.circlepath"
                    )
                    .font(.system(.headline, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Spacing.xs)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
                .disabled(hoursLeft == 0)
                if hoursLeft == 0 {
                    Text("Eight hours is all anyone has. Say something and call it.")
                        .font(.footnote)
                        .foregroundStyle(Theme.warning)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

// MARK: - The statement

/// Three story-sheet buttons. One of them is the front page.
struct IncidentStatementPanel: View {
    let engine: GameEngine
    let incident: IncidentState
    let product: Product
    @Binding var expanded: String?
    var onChoose: (String) -> Void

    private var statements: [IncidentStatement] {
        IncidentStatements.all(for: incident.kind, productName: product.name)
    }

    /// How much of a statement the room has earned the right to be
    /// believed for.
    private var credibility: Int {
        let floor = engine.balance.incidents.credibilityFloor
        return Int(((floor + (1 - floor) * incident.communicate / 100) * 100).rounded())
    }

    var body: some View {
        PixelPanel {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                HStack {
                    PixelSectionTitle(title: "The statement")
                    Spacer(minLength: Theme.Spacing.sm)
                    StatPill(
                        systemImage: "quote.bubble.fill",
                        value: "\(credibility)% believed",
                        tint: credibility >= 80 ? Theme.positiveCash : .secondary
                    )
                }
                Text("Whatever you say, communication decides how much of it lands.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                ForEach(statements) { statement in
                    row(statement)
                }
            }
        }
    }

    @ViewBuilder
    private func row(_ statement: IncidentStatement) -> some View {
        let chosen = incident.statementID == statement.id
        Button {
            expanded = expanded == statement.id ? nil : statement.id
            onChoose(statement.id)
        } label: {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                HStack(alignment: .top, spacing: Theme.Spacing.sm) {
                    Image(systemName: chosen ? "largecircle.fill.circle" : "circle")
                        .font(.subheadline)
                        .foregroundStyle(chosen ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(.tertiary))
                    Text(statement.headline)
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
                Text(statement.body)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(effect(statement))
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(effectTint(statement))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(Theme.Spacing.sm)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(chosen ? Theme.accent.opacity(0.12) : Color.clear)
            )
        }
        .buttonStyle(.pressableRow)
        .accessibilityLabel(statement.headline)
        .accessibilityValue(chosen ? "Chosen" : "Not chosen")
        .accessibilityHint(effect(statement))
    }

    /// A promise the room has not kept yet is the warning colour, whatever
    /// the reputation on the line says.
    private func effectTint(_ statement: IncidentStatement) -> Color {
        if statement.promisesFix, incident.fix < 100 { return Theme.warning }
        return statement.reputationDelta >= 0 ? Theme.positiveCash : Theme.negativeCash
    }

    /// The consequence, on the button, in the room's own numbers.
    private func effect(_ statement: IncidentStatement) -> String {
        let churn = Int(((statement.churnFactor - 1) * 100).rounded())
        let reputation = Int((statement.reputationDelta * Double(credibility) / 100).rounded())
        var parts: [String] = []
        parts.append(reputation == 0 ? "reputation unchanged" : "\(reputation > 0 ? "+" : "")\(reputation) reputation")
        if churn != 0 {
            parts.append(churn > 0 ? "\(churn)% more leave" : "\(-churn)% fewer leave")
        }
        if statement.promisesFix, incident.fix < 100 {
            parts.append("promises a fix you have not shipped")
        }
        return parts.joined(separator: " · ")
    }
}

// MARK: - Calling it

/// The way out, with what the room is about to cost written on it.
struct IncidentClosePanel: View {
    let engine: GameEngine
    let incident: IncidentState
    let product: Product
    var onResolve: () -> Void

    private var blocker: String? { IncidentSystem.resolveBlocker(state: engine.state) }

    private var statement: IncidentStatement? {
        incident.statementID.flatMap {
            IncidentStatements.statement($0, for: incident.kind, productName: product.name)
        }
    }

    private var leaving: Int {
        guard let statement else { return incident.usersLost }
        return Int((Double(incident.usersLost) * statement.churnFactor).rounded())
    }

    private var bugLine: String {
        let unfixed = max(0, 1 - incident.fix / 100)
        if unfixed <= 0 { return "the fix is in and half the live bugs go with it" }
        let left = Int((incident.kind.bugLoad * unfixed).rounded())
        return "\(left) more live bug\(left == 1 ? "" : "s") left in the wild"
    }

    var body: some View {
        PixelPanel {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                PixelSectionTitle(title: "Call it")
                Text(
                    "\(leaving == 1 ? "1 user leaves" : "\(leaving) users leave") · \(bugLine)"
                )
                .font(.footnote)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                Button(action: onResolve) {
                    Label("Close the incident", systemImage: "checkmark.shield.fill")
                        .font(.system(.headline, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Theme.Spacing.xs)
                }
                .buttonStyle(.borderedProminent)
                .tint(incident.isHandled ? Theme.positiveCash : Theme.warning)
                .disabled(blocker != nil)
                if let blocker {
                    Text("\(blocker). The clock stays stopped until you do.")
                        .font(.footnote)
                        .foregroundStyle(Theme.warning)
                        .fixedSize(horizontal: false, vertical: true)
                } else if incident.fix < 100 {
                    Text("The fix is not finished. Closing now leaves it broken.")
                        .font(.footnote)
                        .foregroundStyle(Theme.warning)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}
