import PixelKit
import SwiftUI
import TycoonEngine

/// Iteration 11, wave two — W4. Inside: a full-screen mode for the weeks a
/// sentence is made of.
///
/// Presented from `AppRootView`'s W4 region for as long as the founder is
/// in a cell, the way the war room and the incident room are presented —
/// full screen, at window level, over whichever tab the player was on.
/// Unlike the incident room the clock is *not* stopped: a sentence passes
/// whether or not the founder does anything with it, and the whole point
/// of the room is that they can only do one small thing a day.
///
/// The day's menu is the room. Everything else on the screen — the
/// calendar, the wing, the board, the wall, the phone — says what that one
/// choice a day is buying.
struct InsideScreen: View {
    let engine: GameEngine

    @Environment(GameShell.self) private var injectedShell: GameShell?
    /// See `GameShell.shared` and `IncidentRoomScreen`: read optionally,
    /// because SwiftUI updates a cover's content before the environment is
    /// installed and the non-optional form traps there.
    private var shell: GameShell { injectedShell ?? .shared }

    @State private var showingParole = false
    /// The cover takes a moment to arrive, and a sheet presented into that
    /// moment wedges the transition. Nothing presents itself until the
    /// room is actually on screen.
    @State private var settled = false
    @State private var showingPhone = false
    @State private var threadInPhone: PhoneCounterpart?

    private var prison: PrisonState? { engine.state.prison }

    /// Scroll anchors, so a headless pass can be pointed at the half of
    /// the room below the fold.
    static let wingAnchor = "w4.wing"
    static let waysOutAnchor = "w4.waysout"

    var body: some View {
        VStack(spacing: 0) {
            topBar
            ScrollViewReader { scroll in
            ScrollView {
                if let prison, prison.isInside {
                    VStack(spacing: Theme.Spacing.lg) {
                        InsideDayPanel(engine: engine, prison: prison, onChoose: choose)
                        InsideWingPanel(engine: engine, prison: prison, onAnswer: answerGang)
                            .id(Self.wingAnchor)
                        InsideCalendarPanel(engine: engine, prison: prison)
                        InsideOutPanel(
                            engine: engine,
                            prison: prison,
                            onParole: { showingParole = true },
                            onEscape: escape
                        )
                        .id(Self.waysOutAnchor)
                        InsideWindowPanel(prison: prison) { showingPhone = true }
                    }
                    .padding(Theme.Spacing.lg)
                    // `-autoInsideScroll wing|out` photographs the bottom
                    // of the room: a headless pass cannot scroll to it.
                    .task {
                        #if DEBUG
                        guard let anchor = InsideDebug.scrollAnchor else { return }
                        try? await Task.sleep(for: .seconds(3))
                        withAnimation { scroll.scrollTo(anchor, anchor: .top) }
                        #endif
                    }
                } else {
                    ContentUnavailableView(
                        "The gate is open",
                        systemImage: "door.left.hand.open",
                        description: Text("Nobody is holding you.")
                    )
                    .padding(.top, Theme.Spacing.xl)
                }
            }
            }
        }
        .background(Theme.screenBackground)
        .safeAreaInset(edge: .top, spacing: 0) { cell }
        .gameColumn()
        .sheet(isPresented: $showingParole) {
            InsideParoleSheet(engine: engine)
        }
        .sheet(isPresented: $showingPhone) {
            insidePhone
        }
        // The clock is running in here, so the founder's life keeps
        // happening: a letter, a visit, a birthday at home. Those beats are
        // presented from `AppRootView`, which is *behind* this cover and
        // cannot show a sheet over it — so the room presents them itself,
        // from the same `DecisionPrompt.pending` the root reads.
        .sheet(item: insidePrompt) { prompt in
            DecisionSheet(prompt: prompt, engine: engine)
        }
        .onAppear {
            Sounds.play(.tap)
            Haptics.commit()
        }
        .task {
            try? await Task.sleep(for: .milliseconds(700))
            settled = true
        }
        // The board lets itself in the day it is listed: a hearing is not
        // something the player can be trusted to remember, and it happens
        // once.
        .onChange(of: prison?.parole != nil) { _, sitting in
            if sitting, settled { showingParole = true }
        }
        .task {
            #if DEBUG
            await InsideDebug.play(engine: engine, openParole: { showingParole = true })
            #endif
        }
    }

    // MARK: - Chrome

    /// The room's name, the date, and how long is left. The speed control
    /// is here because the clock *is* running — the way out of this screen
    /// is time.
    private var topBar: some View {
        HStack(alignment: .center, spacing: Theme.Spacing.sm) {
            SpeedControl(engine: engine)
            VStack(spacing: 3) {
                PixelText(text: String(localized: "INSIDE", comment: "Pixel-font title of the prison screen, the full-screen mode while the founder is serving a sentence. Uppercase A-Z only — the bitmap font has no accents."), scale: 2, color: Theme.pixelAccent, shadow: true)
                PixelText(text: engine.state.calendar.hudLabel, scale: 1, color: .secondary)
            }
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Inside, \(engine.state.calendar.longLabel)")
            leftPill
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.vertical, Theme.Spacing.sm)
        .background(.bar)
        .overlay(alignment: .bottom) { Divider() }
    }

    private var leftPill: some View {
        let left = prison?.daysLeft(from: engine.state.day) ?? 0
        return StatPill(
            systemImage: "calendar",
            value: "\(left)d",
            tint: left <= 7 ? Theme.positiveCash : .secondary
        )
        .accessibilityLabel(left == 1 ? "One day left" : "\(left) days left")
    }

    private var cell: some View {
        InsideCellView(
            founderSeed: engine.state.employees.first(where: \.isFounder)?.appearanceSeed ?? 7,
            cellmateSeed: prison?.cellmateSeed ?? 0,
            cellmateName: prison?.cellmateName ?? "",
            line: prison?.log.last?.text ?? "",
            served: prison?.daysServed(on: engine.state.day) ?? 0,
            total: prison?.lengthDays ?? 1
        )
        .frame(height: 260)
    }

    /// The phone, which is the only window. The Life tab's own screens,
    /// in a sheet, because the tab itself is behind a locked door.
    private var insidePhone: some View {
        NavigationStack {
            PhoneScreen(engine: engine) { threadInPhone = $0 }
                .navigationTitle("The phone")
                .navigationBarTitleDisplayMode(.inline)
                .navigationDestination(item: $threadInPhone) { counterpart in
                    ThreadView(engine: engine, counterpart: counterpart)
                }
        }
    }

    /// The beat waiting on an answer, if any. Deliberately simpler than
    /// the root's binding: there is no weekly report, no launch day and no
    /// paywall behind this cover, and a beat that arrives while the founder
    /// is inside is not one they can put off by walking away from it.
    private var insidePrompt: Binding<DecisionPrompt?> {
        Binding(
            get: {
                guard settled, engine.state.gameOver == nil, !showingParole else { return nil }
                return DecisionPrompt.pending(
                    in: engine.state, content: engine.content, balance: engine.balance
                )
            },
            set: { _ in }
        )
    }

    // MARK: - The actions

    private func choose(_ choice: PrisonDayChoice) {
        Haptics.tap()
        Sounds.play(.tap)
        engine.send(.chooseInsideDay(choice: choice))
    }

    private func answerGang(_ joining: Bool) {
        Haptics.commit()
        Sounds.play(.tap)
        engine.send(.answerPrisonGang(joining: joining))
    }

    private func escape() {
        Haptics.commit()
        Sounds.play(.tap)
        let before = engine.state.prison?.untilDay
        engine.send(.attemptEscape)
        let after = engine.state.prison
        if after?.onTheRun == true {
            shell.toasts.show(
                "You are outside, and you are not free.",
                icon: "figure.run", tint: Theme.warning, severity: .critical
            )
        } else if let after, after.untilDay != before {
            shell.toasts.show(
                "They found you at the second gate. It is longer now.",
                icon: "lock.fill", tint: Theme.negativeCash, severity: .notable
            )
        }
    }
}

// MARK: - The day

/// Five things to do with today, each carrying what it will spend and what
/// it will buy. The chosen one is filled in; nothing is spent until the
/// day ticks, so the founder can change their mind all morning.
struct InsideDayPanel: View {
    let engine: GameEngine
    let prison: PrisonState
    var onChoose: (PrisonDayChoice) -> Void

    var body: some View {
        PixelPanel {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                HStack {
                    PixelSectionTitle(title: "Today")
                    Spacer(minLength: Theme.Spacing.sm)
                    StatPill(
                        systemImage: "exclamationmark.triangle.fill",
                        value: prison.infractions == 0 ? "clean" : "\(prison.infractions) on file",
                        tint: prison.infractions == 0 ? Theme.positiveCash : Theme.warning
                    )
                }
                Text(prison.todayChoice == nil
                    ? "Pick one. A day nobody picks is a day with your head down."
                    : "Chosen. It is spent when the day turns over.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                ForEach(PrisonDayChoice.allCases, id: \.self) { choice in
                    InsideDayRow(
                        choice: choice,
                        chosen: prison.todayChoice == choice,
                        consequence: Prison.consequence(
                            choice, state: prison, balance: engine.balance.prison
                        ),
                        onTap: { onChoose(choice) }
                    )
                }
            }
        }
    }
}

private struct InsideDayRow: View {
    let choice: PrisonDayChoice
    let chosen: Bool
    let consequence: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: Theme.Spacing.md) {
                Image(systemName: choice.symbol)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(chosen ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(.secondary))
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 3) {
                    Text(choice.displayName)
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(choice.blurb)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(consequence)
                        .font(.caption2.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(choice.canGoWrong ? Theme.warning : Theme.accent)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                if chosen {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Theme.accent)
                }
            }
            .padding(Theme.Spacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(chosen ? Theme.accent.opacity(0.12) : Theme.chipBackground)
            )
        }
        .buttonStyle(.pressableRow)
        .accessibilityLabel(choice.displayName)
        .accessibilityValue(chosen ? "Chosen" : "Not chosen")
        .accessibilityHint(consequence)
    }
}

// MARK: - The wing

/// The people who run the landing, and the person on the top bunk.
struct InsideWingPanel: View {
    let engine: GameEngine
    let prison: PrisonState
    var onAnswer: (Bool) -> Void

    var body: some View {
        PixelPanel {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                HStack {
                    PixelSectionTitle(title: "The wing")
                    Spacer(minLength: Theme.Spacing.sm)
                    StatPill(
                        systemImage: "person.3.fill",
                        value: prison.standingLabel,
                        tint: prison.gangStanding >= 55 ? Theme.accent : .secondary
                    )
                }
                if !prison.cellmateName.isEmpty {
                    HStack(spacing: Theme.Spacing.md) {
                        PixelPortrait(seed: prison.cellmateSeed, size: 40)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(prison.cellmateName)
                                .font(.subheadline.weight(.semibold))
                            Text("Cellmate · \(Int(prison.cellmateBond.rounded())) rapport. Yours in the address book when you leave.")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                    }
                }
                switch prison.gang {
                case .offered:
                    Text("\(Prison.gangName(sinceDay: prison.sinceDay)) would like an answer about protection. In means the yard stops being a problem and somebody outside will want a favour. Out means neither.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: Theme.Spacing.sm) {
                        Button("Go in with them", systemImage: "hand.raised.fill") { onAnswer(true) }
                            .buttonStyle(.borderedProminent)
                            .tint(Theme.accent)
                        Button("Say no") { onAnswer(false) }
                            .buttonStyle(.bordered)
                    }
                    .font(.footnote.weight(.semibold))
                case .joined:
                    Text("You are in with \(Prison.gangName(sinceDay: prison.sinceDay)). The yard is a quieter place and there is a favour with your name on it for the outside.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                case .refused:
                    Text("You said no. Nothing is owed and nothing is offered; the yard is a longer forty minutes than it was.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                case .unasked:
                    Text("Nobody has asked you for anything yet. They will.")
                        .font(.footnote)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }
}

// MARK: - The calendar

/// The sentence as a row of days, and the two or three things that have
/// happened in it.
struct InsideCalendarPanel: View {
    let engine: GameEngine
    let prison: PrisonState

    private var served: Int { prison.daysServed(on: engine.state.day) }

    var body: some View {
        PixelPanel {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                PixelSectionTitle(title: "The sentence")
                HStack(alignment: .lastTextBaseline, spacing: Theme.Spacing.sm) {
                    PixelText(
                        text: "\(prison.daysLeft(from: engine.state.day))" as String,
                        scale: 5,
                        color: Theme.pixelInk
                    )
                    VStack(alignment: .leading, spacing: 2) {
                        Text("days left")
                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        Text("of \(prison.sentenceWeeks) week\(prison.sentenceWeeks == 1 ? "" : "s") handed down")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
                ProgressView(value: prison.progress(on: engine.state.day))
                    .tint(Theme.accent)
                HStack(spacing: Theme.Spacing.lg) {
                    tally("Library", prison.libraryDays)
                    tally("Yard", prison.yardDays)
                    tally("Calls", prison.callsHome)
                    tally("Deals", prison.dealDays)
                }
                Divider()
                ForEach(prison.log.suffix(3)) { entry in
                    HStack(alignment: .top, spacing: Theme.Spacing.sm) {
                        Image(systemName: entry.isIncident ? "exclamationmark.bubble.fill" : "circle.fill")
                            .font(.system(size: entry.isIncident ? 11 : 5))
                            .foregroundStyle(entry.isIncident ? Theme.warning : Color.secondary.opacity(0.55))
                            .frame(width: 14, alignment: .center)
                            .padding(.top, entry.isIncident ? 2 : 6)
                        Text(entry.text)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                }
            }
        }
    }

    private func tally(_ name: String, _ value: Int) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("\(value)")
                .font(Theme.Typography.number(.subheadline, weight: .semibold))
            Text(name)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - The ways out

/// The board and the wall, each with its real odds on the button.
struct InsideOutPanel: View {
    let engine: GameEngine
    let prison: PrisonState
    var onParole: () -> Void
    var onEscape: () -> Void

    private var config: BalanceConfig.PrisonBalance { engine.balance.prison }

    var body: some View {
        PixelPanel {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                PixelSectionTitle(title: "The ways out")

                // Parole.
                if prison.isParoleEligible(on: engine.state.day, balance: config) {
                    let standing = Prison.paroleOpeningStanding(
                        prison, day: engine.state.day, balance: config
                    )
                    Text("The board sits at the halfway mark. It has read your file: \(fileLine).")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Button("Go before the board", systemImage: "person.crop.square.filled.and.at.rectangle") {
                        onParole()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.accent)
                    .font(.footnote.weight(.semibold))
                    Text("Walking in at \(Int(standing.rounded())) · they let people out at \(Int(config.paroleGrantStanding.rounded()))")
                        .font(.caption2)
                        .monospacedDigit()
                        .foregroundStyle(.tertiary)
                } else if let heard = prison.paroleHeardDay {
                    Text(prison.paroleGranted
                        ? "The board let you out on day \(heard)."
                        : "The board heard you on day \(heard) and said no. There is no second board.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("The board sits when you are halfway through. \(daysToBoard) day\(daysToBoard == 1 ? "" : "s") from now.")
                        .font(.footnote)
                        .foregroundStyle(.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Divider()

                // The wall.
                if prison.escapeAttempted {
                    Text("You have had your go at the wall. There is not a second one.")
                        .font(.footnote)
                        .foregroundStyle(.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    let chance = Prison.escapeChance(prison, day: engine.state.day, balance: config)
                    Text("There is a laundry van on Thursdays. If it works you are outside and never off the list; if it does not, what is left of the sentence doubles.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Button("Go over the wall", systemImage: "figure.run") { onEscape() }
                        .buttonStyle(.bordered)
                        .tint(Theme.warning)
                        .font(.footnote.weight(.semibold))
                    Text("\(Int((chance * 100).rounded()))% it works · \(prison.daysLeft(from: engine.state.day) * 2) days if it does not")
                        .font(.caption2)
                        .monospacedDigit()
                        .foregroundStyle(Theme.warning)
                }
            }
        }
    }

    private var daysToBoard: Int {
        let mark = prison.sinceDay + Int((Double(prison.lengthDays) * config.paroleAtProgress).rounded())
        return max(0, mark - engine.state.day)
    }

    private var fileLine: String {
        var parts: [String] = []
        parts.append(prison.infractions == 0 ? "nothing on your record" : "\(prison.infractions) on your record")
        if prison.libraryDays > 0 { parts.append("\(prison.libraryDays) days in the library") }
        if prison.gang == .joined { parts.append("who you sit with") }
        return parts.joined(separator: ", ")
    }
}

// MARK: - The window

/// The phone: the only thing in here that reaches the outside.
struct InsideWindowPanel: View {
    let prison: PrisonState
    var onOpen: () -> Void

    var body: some View {
        PixelPanel {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                PixelSectionTitle(title: "The only window")
                Text("The caretaker still texts. So does everybody else, and you can read all of it and answer almost none of it.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Open the phone", systemImage: "iphone") { onOpen() }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.accent)
                    .font(.footnote.weight(.semibold))
            }
        }
    }
}
