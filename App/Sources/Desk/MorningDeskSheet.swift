import SwiftUI
import TycoonEngine

// MARK: Iteration 10 — M5 (the morning desk)

/// The desk itself: three papers, a minute, and out.
///
/// One message to answer, one decision to make, one tap. A paper that is
/// dealt with flies off the desk and lies on the done pile at the bottom;
/// when the third goes, the day is stamped and the streak moves. Nothing
/// here advances the simulation — every button sends an ordinary
/// `GameAction` and the clock stays exactly where the player left it.
struct MorningDeskSheet: View {
    let session: GameSession
    /// Opens the thing the decision points at. The front door hands back
    /// a closure that goes into the company; the HUD's date hands one
    /// that routes to the section.
    var onOpen: ((Route) -> Void)?
    /// True when the desk was opened from the title screen, which changes
    /// only what the *Open it* button promises.
    var isAtFrontDoor = true
    var onClose: () -> Void = {}

    /// Bumped by every paper so the board is re-read off the engine.
    @State private var revision = 0
    /// The streak change to celebrate, once the third paper goes.
    @State private var finished: DeskStreakChange?
    /// The reminder button's own state, while the system is thinking.
    @State private var askingForReminder = false
    @State private var reminderRefused = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    if let board = session.deskBoard() {
                        header(board)
                        papers(board)
                        if board.isCleared { clearedNote(board) }
                        rewards
                        reminderRow
                    } else {
                        emptyDesk
                    }
                }
                .padding(Theme.Spacing.lg)
                .animation(Theme.Motion.weighted, value: revision)
            }
            .scrollBounceBehavior(.basedOnSize)
            .background(Theme.screenBackground.ignoresSafeArea())
            .navigationTitle("The desk")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: onClose)
                }
            }
        }
        .onAppear {
            // A paper with nothing on it is done by being empty: recorded
            // the moment the desk is opened, so what the state believes
            // and what the player sees are the same thing.
            if let board = session.deskBoard() {
                register(session.deskMarkEmpties(board))
            }
            #if DEBUG
            // `-autoDesk cleared`: the screenshot pass, and nothing else.
            if DebugLaunch.clearsMorningDesk, let board = session.deskBoard() {
                for part in DeskPart.allCases where !board.isDone(part) {
                    register(session.deskDo(nil, clearing: part, today: board.today))
                }
            }
            #endif
        }
    }

    // MARK: - The head of the desk

    private func header(_ board: MorningDeskBoard) -> some View {
        PixelPanel {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                PixelText(text: greeting, scale: 3, color: Theme.pixelAccent)
                Text(board.isCleared
                     ? "That is the desk. See you tomorrow."
                     : "One message, one decision, one tap. A minute, and out.")
                    .font(.footnote)
                    .foregroundStyle(Theme.pixelInk.opacity(0.8))
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: Theme.Spacing.sm) {
                    MorningDeskStreakPill(streak: session.deskLiveStreak, best: session.ledger.deskBestStreak)
                    Spacer(minLength: 0)
                    Text("\(board.doneCount) of 3")
                        .font(Theme.Typography.number(.caption))
                        .foregroundStyle(Theme.pixelInk.opacity(0.7))
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var greeting: String {
        let hour = DeskDay.hour()
        return switch hour {
        case 0..<5: "STILL UP"
        case 5..<12: "GOOD MORNING"
        case 12..<18: "GOOD AFTERNOON"
        default: "GOOD EVENING"
        }
    }

    // MARK: - The three papers

    @ViewBuilder
    private func papers(_ board: MorningDeskBoard) -> some View {
        VStack(spacing: Theme.Spacing.md) {
            ForEach(DeskPart.allCases.sorted { $0.order < $1.order }, id: \.self) { part in
                if board.isDone(part) {
                    MorningDeskDonePaper(part: part, line: doneLine(part, board))
                        .transition(.opacity)
                } else {
                    paper(part, board)
                        .transition(
                            Theme.Motion.transition(
                                .asymmetric(
                                    insertion: .opacity,
                                    removal: .move(edge: .trailing).combined(with: .opacity)
                                )
                            )
                        )
                }
            }
        }
    }

    @ViewBuilder
    private func paper(_ part: DeskPart, _ board: MorningDeskBoard) -> some View {
        switch part {
        case .message:
            if let message = board.message {
                MorningDeskPaper(part: .message, tilt: -1) {
                    MorningDeskMessageBody(message: message)
                } buttons: {
                    if message.isAsking {
                        ForEach(message.replies) { reply in
                            MorningDeskButton(
                                title: reply.label,
                                detail: reply.detail ?? reply.disabledReason,
                                isFirm: reply.isFirm,
                                isEnabled: reply.isEnabled
                            ) {
                                doPaper(.message, action: reply.action, board: board)
                            }
                        }
                    } else {
                        MorningDeskButton(
                            title: "Read it",
                            detail: "Marks the thread read. It stays in the phone."
                        ) {
                            doPaper(
                                .message,
                                action: .markPhoneThreadRead(counterpart: message.counterpart),
                                board: board
                            )
                        }
                    }
                }
            }
        case .decision:
            if let item = board.decision {
                MorningDeskPaper(part: .decision, tilt: 1) {
                    MorningDeskDecisionBody(item: item)
                } buttons: {
                    MorningDeskButton(
                        title: "Open it",
                        detail: isAtFrontDoor
                            ? "Goes back into \(session.engine.state.company.name)."
                            : "Opens \(sectionName(item.section))."
                    ) {
                        doPaper(.decision, action: nil, board: board)
                        onOpen?(item.route)
                    }
                    MorningDeskButton(
                        title: "Note it",
                        detail: "Leaves it where it is. It will still be there.",
                        isFirm: true
                    ) {
                        doPaper(.decision, action: nil, board: board)
                    }
                }
            }
        case .tap:
            MorningDeskPaper(part: .tap, tilt: -0.5) {
                MorningDeskTapBody(tap: board.tap)
            } buttons: {
                MorningDeskButton(title: board.tap.title, detail: board.tap.detail) {
                    doPaper(.tap, action: board.tap.action, board: board)
                }
            }
        }
    }

    private func doneLine(_ part: DeskPart, _ board: MorningDeskBoard) -> String {
        switch part {
        case .message:
            board.message == nil ? "Nobody needed anything." : "Answered."
        case .decision:
            board.decision == nil ? "Nothing on the desk." : "Seen."
        case .tap:
            "Done."
        }
    }

    private func sectionName(_ section: DeskSection) -> String {
        switch section {
        case .contracts: "Contracts"
        case .market: "the market"
        case .marketing: "Marketing"
        case .finances: "Finances"
        case .rivals: "Rivals"
        case .investors: "Investors"
        }
    }

    // MARK: - The day, stamped

    @ViewBuilder
    private func clearedNote(_ board: MorningDeskBoard) -> some View {
        PixelPanel(paper: Theme.pixelAccent) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                PixelText(
                    text: String(localized: "DESK CLEARED", comment: "Bitmap stamp on the morning desk once all three papers are done. Uppercase: the pixel face has no lowercase"),
                    scale: 2,
                    color: Theme.ink(on: Theme.pixelAccent)
                )
                Text(clearedLine)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.ink(on: Theme.pixelAccent))
                    .fixedSize(horizontal: false, vertical: true)
                if let finished, !finished.rewards.isEmpty {
                    ForEach(finished.rewards) { reward in
                        Text("Earned: \(reward.name) — \(reward.note)")
                            .font(.caption)
                            .foregroundStyle(Theme.ink(on: Theme.pixelAccent).opacity(0.9))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var clearedLine: String {
        let streak = session.deskLiveStreak
        if let finished, finished.usedSickDay {
            return "You missed one. The month's sick day covered it — day \(streak)."
        }
        if streak <= 1 { return "Day one. Come back tomorrow and it becomes two." }
        if let next = DeskRewards.next(after: streak) {
            return "\(streak) days running. \(next.days - streak) more for \(next.name)."
        }
        return "\(streak) days running."
    }

    // MARK: - The rewards

    private var rewards: some View {
        let best = session.ledger.deskBestStreak
        return VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            PixelSectionTitle(title: String(localized: "Streak rewards", comment: "Bitmap heading over the morning desk's reward ladder. Uppercased by the pixel face"))
            ForEach(DeskRewards.all) { reward in
                HStack(alignment: .top, spacing: Theme.Spacing.sm) {
                    Image(systemName: reward.days <= best ? "checkmark.seal.fill" : "lock")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(reward.days <= best ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(.tertiary))
                        .frame(width: 20)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("\(reward.days) days · \(reward.name)")
                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                            .foregroundStyle(reward.days <= best ? .primary : .secondary)
                        Text(reward.note)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(
                    "\(reward.days) days, \(reward.name). \(reward.days <= best ? "Earned" : "Locked")"
                )
            }
            Text("Never a number in the company: a thing for the wall, a face to found with, a sunrise on the door.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - The reminder

    private var reminderRow: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Button {
                Haptics.tap()
                if DeskReminder.isOn {
                    DeskReminder.turnOff()
                    reminderRefused = false
                    revision += 1
                } else {
                    askingForReminder = true
                    Task {
                        let granted = await DeskReminder.turnOn(at: DeskDay.hour())
                        askingForReminder = false
                        reminderRefused = !granted
                        revision += 1
                    }
                }
            } label: {
                Label(
                    DeskReminder.buttonTitle,
                    systemImage: DeskReminder.isOn ? "bell.fill" : "bell"
                )
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Spacing.xs)
            }
            .buttonStyle(.bordered)
            .tint(Theme.accent)
            .disabled(askingForReminder)
            Text(reminderRefused
                 ? "Notifications are off for Startup Studio in Settings. Nothing else will ask."
                 : DeskReminder.buttonDetail)
                .font(.caption)
                .foregroundStyle(reminderRefused ? AnyShapeStyle(Theme.warning) : AnyShapeStyle(.tertiary))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Nothing to do

    private var emptyDesk: some View {
        PixelPanel {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                PixelText(
                    text: String(localized: "NO DESK YET", comment: "Bitmap heading on the morning desk when there is no company to have a morning about. Uppercase: the pixel face has no lowercase"),
                    scale: 3,
                    color: Theme.pixelInk.opacity(0.5)
                )
                Text("The desk belongs to a company. Start one, or open a save, and it will be here in the morning.")
                    .font(.footnote)
                    .foregroundStyle(Theme.pixelInk.opacity(0.8))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Doing a paper

    private func doPaper(_ part: DeskPart, action: GameAction?, board: MorningDeskBoard) {
        Haptics.tap()
        Sounds.play(.tap)
        register(session.deskDo(action, clearing: part, today: board.today))
    }

    /// Keeps the celebration, moves the reminder to this hour, and asks
    /// the body to redraw off the engine.
    private func register(_ change: DeskStreakChange?) {
        if let change, change.after > 0 {
            finished = change
            DeskReminder.moveToClearedHour(DeskDay.hour())
            Haptics.success()
        }
        revision += 1
    }
}

// MARK: - One paper

/// A sheet of paper on the desk: the part's heading in the bitmap face,
/// what it says, and the buttons that deal with it. Tilted a degree or so
/// so three of them read as a pile rather than a form.
struct MorningDeskPaper<Body: View, Buttons: View>: View {
    let part: DeskPart
    /// Degrees, ±2 at most. Flat under Reduce Motion.
    var tilt: Double = 0
    @ViewBuilder var content: () -> Body
    @ViewBuilder var buttons: () -> Buttons

    var body: some View {
        PixelPanel {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                PixelText(text: part.title, scale: 2, color: Theme.pixelAccent)
                content()
                VStack(spacing: Theme.Spacing.sm) {
                    buttons()
                }
            }
        }
        .rotationEffect(.degrees(Theme.Motion.isReduced ? 0 : tilt))
        .accessibilityElement(children: .contain)
    }
}

/// A paper that has been dealt with: one line on the done pile.
struct MorningDeskDonePaper: View {
    let part: DeskPart
    let line: String

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "checkmark.circle.fill")
                .font(.footnote.weight(.bold))
                .foregroundStyle(Theme.accent)
            Text(part.title)
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .foregroundStyle(.secondary)
            Text(line)
                .font(.caption)
                .foregroundStyle(.tertiary)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
        .background(Theme.chipBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(part.title): \(line)")
    }
}

/// One button on a paper: what it does, and under it what it costs.
struct MorningDeskButton: View {
    let title: String
    var detail: String?
    var isFirm = false
    var isEnabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                if let detail {
                    Text(detail)
                        .font(.caption)
                        .opacity(0.8)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, Theme.Spacing.xs)
            .padding(.horizontal, Theme.Spacing.sm)
        }
        .buttonStyle(.bordered)
        .tint(isFirm ? Color.secondary : Theme.accent)
        .disabled(!isEnabled)
        .accessibilityLabel(title)
        .accessibilityHint(detail ?? "")
    }
}

// MARK: - The three bodies

private struct MorningDeskMessageBody: View {
    let message: MorningDeskMessage

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.md) {
            if let seed = message.seed {
                PixelPortrait(seed: seed, size: 34)
            } else {
                PixelIconTile(systemImage: "building.2.fill", size: 34)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(message.name)
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .foregroundStyle(Theme.pixelInk)
                Text(message.text)
                    .font(.footnote)
                    .foregroundStyle(Theme.pixelInk.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct MorningDeskDecisionBody: View {
    let item: DeskItem

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.md) {
            Image(systemName: item.systemImage)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(item.tint)
                .frame(width: 22)
            Text(item.text)
                .font(.footnote)
                .foregroundStyle(Theme.pixelInk.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            if let days = item.daysLeft {
                Text(days == 0 ? "today" : "\(days)d")
                    .font(Theme.Typography.number(.caption))
                    .foregroundStyle(days <= 3 ? Theme.negativeCash : Theme.pixelInk.opacity(0.7))
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct MorningDeskTapBody: View {
    let tap: DeskTapCard

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.md) {
            Image(systemName: icon)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.accent)
                .frame(width: 22)
            Text(line)
                .font(.footnote)
                .foregroundStyle(Theme.pixelInk.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }

    private var icon: String {
        switch tap.kind {
        case .praise: "hands.clap.fill"
        case .coffee: "cup.and.saucer.fill"
        case .plant: "leaf.fill"
        }
    }

    private var line: String {
        switch tap.kind {
        case .praise(_, let name): "\(name) has not heard anything from you in a while."
        case .coffee(_, let name, let cost): "\(name), and \(cost.money) of the company's money."
        case .plant: "The plant in the corner. Nobody else is going to."
        }
    }
}

// MARK: - The streak, as a pill

/// The streak in the bitmap face: today's run, and the best there has
/// been under it once they differ.
struct MorningDeskStreakPill: View {
    let streak: Int
    let best: Int

    var body: some View {
        HStack(spacing: Theme.Spacing.xs) {
            Image(systemName: streak > 0 ? "flame.fill" : "flame")
                .font(.caption2.weight(.bold))
            PixelText(
                text: streak > 0 ? "\(streak) DAY\(streak == 1 ? "" : "S")" : "NO STREAK",
                scale: 2,
                color: Theme.ink(on: Theme.pixelAccent)
            )
        }
        .foregroundStyle(Theme.ink(on: Theme.pixelAccent))
        .padding(.horizontal, Theme.Spacing.sm)
        .padding(.vertical, 4)
        .background(streak > 0 ? Theme.pixelAccent : Theme.pixelInk.opacity(0.25))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            streak > 0
                ? "Streak \(streak) day\(streak == 1 ? "" : "s"), best \(best)"
                : "No streak. Best \(best)"
        )
    }
}
