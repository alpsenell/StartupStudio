import SwiftUI
import TycoonContent
import TycoonEngine

// MARK: V2 (ux: one inbox, one home per thing)

// Iteration 14 — V2, C5. One inbox.
//
// A question used to reach the founder seven ways (the audit's problem 3)
// and the rail's +N opened the journal, which is a log, not an inbox. This
// file is the one list of what is waiting on the founder, read from the
// sources that already exist and never stored:
//
// - **Questions**: the rail's own rows — the queue (`QueueBoard`, through
//   `NoticeRail.queueRows`, with J6's rule that a sheet is listed only once
//   put off and only while the clock runs; a room whenever it is open) and
//   J1's doors (`DoorRail`, their 14-day rows as they are).
// - **On the phone**: threads asking for an answer (`PhoneReply`) whose
//   question is not already a row above.
// - **On the desk**: `Desk.items` due inside a week — the rows the Business
//   badge counts (`TabBadge.deskHorizonDays`).
//
// Each row carries its deadline and a button that goes where the rail's
// button would. The desk card on Business and the morning papers read the
// same `Desk.items` and the same `PhoneReply` threads, so the three cannot
// disagree. Nothing here sells anything: the shop is never a row (the
// anti-nag rule of `iteration-13-iap.md`).

/// One thing waiting on the founder.
struct WaitingItem: Identifiable, Equatable {
    enum Source: Equatable {
        case question, phone, desk
    }

    /// What the row's button does — the rail's own answers.
    enum Action: Equatable {
        /// A queued question's answer: bring its sheet back, or walk into
        /// its room (`QueueRailAnswer`, J6).
        case answer(QueueRailAnswer)
        /// Somewhere to go: a door, a thread, the desk row's section.
        case route(Route)
        /// The original deferred story beat's recall, for a rail row with
        /// neither (what the rail's button does in that case).
        case recallStoryBeat
    }

    let id: String
    let source: Source
    let title: String
    let systemImage: String
    let tint: Color
    /// Days left to answer; negative when it waits for the founder.
    let daysLeft: Int
    let action: Action

    static func == (lhs: WaitingItem, rhs: WaitingItem) -> Bool {
        lhs.id == rhs.id && lhs.daysLeft == rhs.daysLeft && lhs.title == rhs.title
    }
}

/// Everything waiting, in three groups: questions, the phone, the desk.
struct WaitingList: Equatable {
    var questions: [WaitingItem]
    var phone: [WaitingItem]
    var desk: [WaitingItem]

    var all: [WaitingItem] { questions + phone + desk }
    var count: Int { questions.count + phone.count + desk.count }
    var isEmpty: Bool { count == 0 }

    /// The rows that are not on the Business desk: what the desk card
    /// points at when it says "more waiting on you".
    var elsewhere: Int { questions.count + phone.count }

    /// The inbox for the live game, with the shell's put-off questions.
    @MainActor
    static func make(engine: GameEngine, shell: GameShell) -> WaitingList {
        make(
            state: engine.state,
            content: engine.content,
            balance: engine.balance,
            questionRows: NoticeRail.queueRows(
                engine.state, content: engine.content, balance: engine.balance,
                isDeferred: shell.isDeferred
            ) + DoorRail.notices(for: engine.state)
        )
    }

    /// The inbox for `state`, given the rail rows that are questions.
    static func make(
        state: GameState,
        content: ContentCatalog,
        balance: BalanceConfig,
        questionRows: [RailNotice]
    ) -> WaitingList {
        let questions = questionRows.compactMap { question($0) }
        let listed = Set(questions.map(\.id))

        // A thread asking is the phone's copy of a story beat or a staff
        // moment; when that question is already a row, the row is enough.
        let phone = state.life.phone.byRecency.compactMap { thread -> WaitingItem? in
            guard let waiting = PhoneReply.waiting(
                in: state, content: content, counterpart: thread.counterpart
            ) else { return nil }
            let echoes = listed.contains { id in
                switch thread.counterpart {
                case .employee: id.hasPrefix("deferred-staff-")
                default: id.hasPrefix("deferred-narrative-")
                }
            }
            guard !echoes else { return nil }
            let name = state.phoneName(for: thread.counterpart)
            return WaitingItem(
                id: "phone-\(thread.id)",
                source: .phone,
                title: String(localized: "\(name) is waiting on an answer", comment: "Waiting on you: a phone thread with a question in it"),
                systemImage: "bubble.left.fill",
                tint: Theme.accent,
                daysLeft: max(0, waiting.respondByDay - state.day),
                action: .route(.phoneThread(counterpart: thread.counterpart))
            )
        }

        let desk = dueDeskItems(in: state, balance: balance, content: content).map { item in
            WaitingItem(
                id: "desk-\(item.id)",
                source: .desk,
                title: item.text,
                systemImage: item.systemImage,
                tint: item.tint,
                daysLeft: item.daysLeft ?? 0,
                action: .route(item.route)
            )
        }
        return WaitingList(questions: questions, phone: phone, desk: desk)
    }

    /// The desk rows that need the founder this week: dated, and due
    /// inside `TabBadge.deskHorizonDays` — what the Business badge and the
    /// pill badges count.
    static func dueDeskItems(in state: GameState, balance: BalanceConfig, content: ContentCatalog) -> [DeskItem] {
        Desk.items(in: state, balance: balance, content: content)
            .filter { ($0.daysLeft ?? .max) <= TabBadge.deskHorizonDays }
    }

    /// A rail row as an inbox row. Only the deferred rows are questions;
    /// J5's announced-date countdown is a promise, not a question, and
    /// stays on the rail alone.
    private static func question(_ notice: RailNotice) -> WaitingItem? {
        guard case .deferred(let title, let daysLeft, let category) = notice.kind,
              !notice.id.hasPrefix("deferred-announce-")
        else { return nil }
        let action: WaitingItem.Action
        if let answer = notice.answer {
            action = .answer(answer)
        } else if let route = DoorRail.route(forNoticeID: notice.id) {
            action = .route(route)
        } else {
            action = .recallStoryBeat
        }
        return WaitingItem(
            id: notice.id,
            source: .question,
            title: title,
            systemImage: EventPresenter.icon(forCategory: category),
            tint: EventPresenter.tint(forCategory: category),
            daysLeft: daysLeft,
            action: action
        )
    }
}

/// "Waiting on you": the rail's +N, and the desk card's "more" line.
///
/// Presented at the root (`AppRootView`), so any surface can open it with
/// `GameShell.showingWaiting`. A row's button closes the sheet and then does
/// what the rail's button would; the footer keeps the log — the journal and
/// the week's report, which a closed report can be reopened from.
struct WaitingSheet: View {
    let engine: GameEngine
    /// Hands the chosen action back; the presenter runs it once the sheet
    /// is down, so a recalled question can come up in its place.
    let onPick: (WaitingSheetPick) -> Void

    @Environment(GameShell.self) private var injectedShell: GameShell?
    private var shell: GameShell { injectedShell ?? .shared }

    private var list: WaitingList { WaitingList.make(engine: engine, shell: shell) }

    var body: some View {
        let list = list
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    header(list)
                    if !list.questions.isEmpty {
                        section(String(localized: "Questions", comment: "Waiting on you: heading over the queue's questions and the doors"), list.questions)
                    }
                    if !list.phone.isEmpty {
                        section(String(localized: "On the phone", comment: "Waiting on you: heading over the phone threads asking something"), list.phone)
                    }
                    if !list.desk.isEmpty {
                        section(String(localized: "On the desk this week", comment: "Waiting on you: heading over the Business desk's rows due within seven days"), list.desk)
                    }
                    footer
                }
                .padding(Theme.Spacing.lg)
            }
            .scrollBounceBehavior(.basedOnSize)
            .background(Theme.screenBackground.ignoresSafeArea())
            .navigationTitle("Waiting on you")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { onPick(.none) }
                }
            }
        }
    }

    // MARK: The head

    private func header(_ list: WaitingList) -> some View {
        PixelPanel {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                PixelText(
                    text: String(localized: "WAITING ON YOU", comment: "Bitmap heading on the inbox sheet. Uppercase: the pixel face has no lowercase"),
                    scale: 2,
                    color: Theme.pixelAccent
                )
                Text(summary(list))
                    .font(.footnote)
                    .foregroundStyle(Theme.pixelInk.opacity(0.8))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }

    private func summary(_ list: WaitingList) -> String {
        if list.isEmpty {
            return String(localized: "Nothing is waiting on you. The clock can run.", comment: "Waiting on you: the empty inbox")
        }
        return String(localized: "\(list.count) things need an answer from you. The soonest is first in each group.", comment: "Waiting on you: how many things are in the inbox")
    }

    // MARK: A group

    private func section(_ title: String, _ items: [WaitingItem]) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            PixelSectionTitle(title: title)
            VStack(spacing: 0) {
                ForEach(items) { item in
                    row(item)
                    if item.id != items.last?.id { Divider() }
                }
            }
            .padding(.horizontal, Theme.Spacing.md)
            .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private func row(_ item: WaitingItem) -> some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: item.systemImage)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(item.tint)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Text(when(item))
                    .font(.caption2)
                    .monospacedDigit()
                    .foregroundStyle(item.daysLeft >= 0 && item.daysLeft <= 1 ? Theme.warning : .secondary)
            }
            Spacer(minLength: Theme.Spacing.sm)
            Button {
                Haptics.commit()
                Sounds.play(.tap)
                onPick(.item(item.action))
            } label: {
                Text(item.source == .question ? "Answer" : "Open")
                    .font(.footnote.weight(.bold))
                    .padding(.horizontal, Theme.Spacing.xs)
            }
            .buttonStyle(.borderedProminent)
            .tint(item.source == .question ? Theme.accent : Theme.accent.opacity(0.75))
        }
        .padding(.vertical, Theme.Spacing.sm)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.title), \(when(item))")
    }

    /// The rail's own words for a deadline.
    private func when(_ item: WaitingItem) -> String {
        switch item.daysLeft {
        case ..<0: String(localized: "waiting on you", comment: "Notice rail: a question with no deadline, waiting for the founder")
        case 0: item.source == .question
            ? String(localized: "answers itself today", comment: "Notice rail: a deferred question whose deadline is today")
            : String(localized: "due today", comment: "Waiting on you: a desk row or a phone thread due today")
        case 1: String(localized: "1 day left", comment: "Notice rail: a deferred question with one day of its deadline left")
        default: String(localized: "\(item.daysLeft) days left", comment: "Notice rail: days left on a deferred question. Always 2 or more")
        }
    }

    // MARK: The log

    /// The journal stays on HQ as the log; from here it is one push away,
    /// with the week's report beside it (C10: a closed report reopens).
    private var footer: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            PixelSectionTitle(title: String(localized: "The log", comment: "Waiting on you: heading over the journal and the weekly report links"))
            VStack(spacing: 0) {
                if let week = shell.reopenableReportWeek(engine: engine) {
                    Button {
                        Haptics.tap()
                        onPick(.reopenReport(week: week))
                    } label: {
                        footerRow(String(localized: "Week \(week) report", comment: "Waiting on you: reopens the latest weekly report"), systemImage: "calendar.badge.clock")
                    }
                    .buttonStyle(.pressableRow)
                    .accessibilityHint("Opens the weekly report again")
                    Divider()
                }
                NavigationLink {
                    JournalScreen(engine: engine)
                } label: {
                    footerRow(String(localized: "Journal", comment: "Waiting on you: opens the full journal"), systemImage: "book.closed.fill")
                }
                .buttonStyle(.pressableRow)
            }
            .padding(.horizontal, Theme.Spacing.md)
            .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private func footerRow(_ title: String, systemImage: String) -> some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: systemImage)
                .font(.footnote.weight(.bold))
                .foregroundStyle(Theme.accent)
                .frame(width: 22)
            Text(title)
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .foregroundStyle(.primary)
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.tertiary)
        }
        .frame(minHeight: 44)
        .contentShape(Rectangle())
    }
}

/// What the inbox hands its presenter.
enum WaitingSheetPick: Equatable {
    /// Closed with nothing chosen.
    case none
    case item(WaitingItem.Action)
    case reopenReport(week: Int)
}

#if DEBUG
/// `-autoWaiting` and `-autoReopenReport` (DebugLaunch, V2). The dump is
/// the lane's measurement: what the inbox, the Business desk and the
/// morning papers each show for the same state.
@MainActor
enum WaitingDebug {
    static func startIfAsked(session: GameSession, shell: GameShell) async {
        guard DebugLaunch.opensWaiting || DebugLaunch.reopensReport else { return }
        try? await Task.sleep(for: .seconds(4))
        let engine = session.engine
        if DebugLaunch.opensWaiting {
            dump(session: session, shell: shell)
            shell.showingWaiting = true
        }
        if DebugLaunch.reopensReport {
            shell.reopenWeeklyReport(engine: engine)
        }
    }

    static func dump(session: GameSession, shell: GameShell) {
        let engine = session.engine
        let list = WaitingList.make(engine: engine, shell: shell)
        let desk = Desk.items(in: engine.state, balance: engine.balance, content: engine.content)
        let board = MorningDeskBoard.make(
            state: engine.state, content: engine.content, balance: engine.balance,
            today: session.deskToday
        )
        func line(_ item: WaitingItem) -> String { "\(item.title) [\(item.daysLeft)]" }
        print("[V2] day \(engine.state.day)")
        print("[V2] inbox questions (\(list.questions.count)): \(list.questions.map(line))")
        print("[V2] inbox phone (\(list.phone.count)): \(list.phone.map(line))")
        print("[V2] inbox desk (\(list.desk.count)): \(list.desk.map(line))")
        print("[V2] desk card (\(desk.count)): \(desk.map { "\($0.text) [\($0.daysLeft.map(String.init) ?? "-")]" })")
        print("[V2] desk card due in 7d (\(WaitingList.dueDeskItems(in: engine.state, balance: engine.balance, content: engine.content).count)), elsewhere \(list.elsewhere)")
        print("[V2] papers message: \(board.message.map { "\($0.name): \($0.text) asking=\($0.isAsking)" } ?? "none")")
        print("[V2] papers decision: \(board.decision.map { "\($0.text) [\($0.daysLeft.map(String.init) ?? "-")]" } ?? "none")")
        print("[V2] badges life \(TabBadge.life(in: engine.state, content: engine.content)) business \(TabBadge.business(in: engine.state, balance: engine.balance, content: engine.content))")
    }
}
#endif

// MARK: end V2
