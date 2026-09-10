import SwiftUI
import TycoonContent
import TycoonEngine

/// One thing the rail can say.
///
/// The rail shows exactly one of these at a time, chosen by `priority`
/// (lower leads): the reason the clock stopped, a story question the
/// player deferred and its real countdown, the unread weekly report, the
/// loudest thing that just happened, and finally a coach tip. Everything
/// else the top band used to stack — the report chip, the pause banner,
/// the tip strip and the floating toasts — is one of these now.
struct RailNotice: Identifiable, Equatable {
    enum Kind: Equatable {
        /// The loudest event that stopped the clock, and how many more did.
        case pause(headline: GameEvent, more: Int)
        /// A narrative choice the player put off; `daysLeft` is real.
        case deferred(title: String, daysLeft: Int, category: String?)
        /// A weekly report waiting to be read.
        case report(week: Int)
        /// A transient acknowledgement: the newest toast.
        case event(Toast)
        /// A coach tip for the player's current goal.
        case tip(CoachTip)
        /// Iteration 7 (R1): the tour's current beat. Priority 1 — after a
        /// pause (a story question stops the clock and must lead), before
        /// a deferred question.
        case tour(TutorialStep)
    }

    let id: String
    let kind: Kind
    /// Lower leads.
    let priority: Int
    /// Iteration 12 (J6): what a queued question's button does — bring its
    /// sheet back, or walk into its room. `nil` is the original deferred
    /// story beat's recall, so `deferred(id:title:daysLeft:category:)`
    /// callers are unchanged.
    var answer: QueueRailAnswer? = nil

    static func pause(_ headline: GameEvent, more: Int) -> RailNotice {
        RailNotice(id: "pause", kind: .pause(headline: headline, more: more), priority: 0)
    }

    static func tour(_ step: TutorialStep) -> RailNotice {
        RailNotice(id: "tour-\(step.rawValue)", kind: .tour(step), priority: 1)
    }

    static func deferred(id: String, title: String, daysLeft: Int, category: String?) -> RailNotice {
        RailNotice(
            id: "deferred-\(id)",
            kind: .deferred(title: title, daysLeft: daysLeft, category: category),
            priority: 2
        )
    }

    /// Iteration 12 (J6): a question on the queue, drawn as a deferred row
    /// — its real deadline, or "waiting on you" when it has none — with
    /// the button that answers it.
    static func queued(_ entry: QueueEntry, day: Int, answer: QueueRailAnswer) -> RailNotice {
        RailNotice(
            id: "deferred-\(entry.id)",
            kind: .deferred(
                title: entry.title,
                daysLeft: entry.daysLeft(on: day) ?? -1,
                category: entry.category
            ),
            priority: 2,
            answer: answer
        )
    }

    static func report(week: Int) -> RailNotice {
        RailNotice(id: "report-\(week)", kind: .report(week: week), priority: 3)
    }

    static func event(_ toast: Toast) -> RailNotice {
        RailNotice(id: "toast-\(toast.id)", kind: .event(toast), priority: 4)
    }

    static func tip(_ tip: CoachTip) -> RailNotice {
        RailNotice(id: "tip-\(tip.id)", kind: .tip(tip), priority: 5)
    }
}

/// The one line under the HUD bar.
///
/// It replaces four rows that used to stack independently (the report chip,
/// the pause banner, the tip strip and the toast overlay) with a single
/// slot: the leading notice by priority, a "+N" counter when more are
/// queued (tap opens the journal, where everything lands anyway), and a
/// horizontal swipe to cycle through the queue. Because it is one row, a
/// busy day costs the player one line of chrome, not a third of the screen.
struct NoticeRail: View {
    let engine: GameEngine
    /// Deep links for the notices that have somewhere to go.
    var onRoute: ((Route) -> Void)?
    /// Preview and snapshot hook: a fixed queue instead of one read from
    /// the engine and the shell.
    var fixedQueue: [RailNotice]?

    @Environment(GameShell.self) private var injectedShell: GameShell?
    /// See `GameShell.shared`: read optionally, because SwiftUI
    /// updates this property for presented content before the
    /// environment is installed and the non-optional form traps there.
    private var shell: GameShell { injectedShell ?? .shared }
    /// Iteration 7 (R1): the tour, when a fresh install is on it. Optional
    /// so a snapshot renders the rail without a session behind it.
    @Environment(\.gameSession) private var session

    /// Which queued notice is showing, relative to the leader; a swipe
    /// moves it and a change of leader resets it.
    @State private var cycle = 0
    @State private var dismissedTips: Set<String> = GameSettings.dismissedTips
    // MARK: U1 (ux: the first-hour fixes)
    /// C3: the notice whose line is open to its full text; a tap on the
    /// line toggles it, and a change of notice closes it.
    @State private var expandedID: String?
    /// C3: the tab whose HUD this rail sits under; `nil` outside the tab
    /// bar (previews, snapshots), where every tip may show as before.
    @Environment(\.railTab) private var railTab
    /// C3: the tips already said this session.
    private var tipLedger: RailTipLedger { RailTipLedger.shared }
    // MARK: end U1

    private var copy: EventCopy {
        EventCopy(state: engine.state, content: engine.content, balance: engine.balance)
    }

    // MARK: - Queue

    private var queue: [RailNotice] {
        (fixedQueue ?? liveQueue).sorted { $0.priority < $1.priority }
    }

    private var liveQueue: [RailNotice] {
        var notices: [RailNotice] = []
        let state = engine.state

        // Why did time stop? The engine keeps the reasons until the
        // player changes speed.
        if state.speed == .paused,
           let headline = engine.lastPauseEvents.max(by: { severityRank($0.severity) < severityRank($1.severity) }) {
            notices.append(.pause(headline, more: engine.lastPauseEvents.count - 1))
        }

        // Iteration 12 (J6): every question the game is asking that is not
        // on screen — a sheet the founder put off (while the clock runs,
        // with the deadline that is really counting down), or a room with
        // a question in it. One row each, in the queue's order. The story
        // beat that used to be the only thing here is one of them.
        notices.append(contentsOf: queueNotices(state))
        // Iteration 12 (J6): the seam where another lane appends its own
        // `RailNotice.deferred` rows for the current state (J1's doors).
        notices.append(contentsOf: laneNotices(state))


        // Iteration 7 (R1): the tour's beat, after a pause and before a
        // deferred question. Silent across the ship beat's wait.
        if let step = session?.tutorial?.activeStep {
            notices.append(.tour(step))
        }

        if let week = shell.pendingReportWeek {
            notices.append(.report(week: week))
        }

        if let toast = shell.toasts.toasts.last {
            notices.append(.event(toast))
        }

        // Coach tips stay quiet while the tour runs: its beats say the
        // same things, and on completion the six ids are dismissed.
        if !tourIsRunning, let tip = activeTip {
            notices.append(.tip(tip))
        }
        return notices
    }

    /// Iteration 12 (J6): the queue's rows. A sheet is here only once it
    /// has been put off and only while the clock runs (a stopped clock is
    /// the sheet's own moment); a room is here whenever it is open.
    private func queueNotices(_ state: GameState) -> [RailNotice] {
        // MARK: V2 (ux: one inbox, one home per thing)
        // C5: J6's rule, unchanged, lives in `queueRows` so the inbox
        // ("Waiting on you") reads the very same rows.
        Self.queueRows(
            state, content: engine.content, balance: engine.balance,
            isDeferred: { shell.isDeferred($0) }
        )
        // MARK: end V2
    }

    /// Iteration 12 (J6), moved into a static by V2 (C5) so the rail and
    /// the inbox share it: the queue's rows for `state`. A sheet is here
    /// only once put off and only while the clock runs; a room whenever it
    /// is open.
    static func queueRows(
        _ state: GameState,
        content: ContentCatalog,
        balance: BalanceConfig,
        isDeferred: (String) -> Bool
    ) -> [RailNotice] {
        let items = DecisionPrompt.queueItems(in: state, content: content, balance: balance)
        return items.compactMap { item in
            if let prompt = item.prompt {
                guard isDeferred(prompt.id), state.speed != .paused else { return nil }
                return .queued(item.entry, day: state.day, answer: .recall(promptID: prompt.id))
            }
            guard let route = queueRoute(for: item.entry.kind) else { return nil }
            return .queued(item.entry, day: state.day, answer: .route(route))
        }
    }

    /// The room a queued question is answered in.
    private static func queueRoute(for kind: QueueKind) -> Route? {
        switch kind {
        case .dirtyMoneyOffer: .dirtyMoney
        case .funeral: .family
        case .legalCase: .crimeLedger
        case .hearing: .courtroom
        case .cancellation: .feed
        // MARK: K1 (founder money)
        // "Sell something": the question waits in the assets room.
        case .rescue: .assets
        // MARK: end K1
        default: nil
        }
    }

    private var tourIsRunning: Bool {
        guard let tutorial = session?.tutorial else { return false }
        return !tutorial.isComplete
    }

    /// The tip for the player's most recently activated goal, unless they
    /// dismissed it or finished the goal.
    private var activeTip: CoachTip? {
        // MARK: U1 (ux: the first-hour fixes)
        // C3: under a tab, only that tab's tips, each once a session.
        if railTab != nil { return firstHourTip }
        // MARK: end U1
        let activeGoals = ProgressionReader.activeGoalIDs(in: engine.state)
        let goalTip = activeGoals.isEmpty ? nil : CoachTip.all.first {
            activeGoals.contains($0.goalID) && !dismissedTips.contains($0.id)
        }
        // Iteration 12 (J6): when no goal has a tip, the fallback seam.
        return goalTip ?? fallbackTip
    }

    // MARK: - Lane seams (iteration 12, J6)

    // Three extension points for lanes that build on the rail without
    // owning it. Each returns nothing today, so the rail is exactly what it
    // was; a lane's lines go between its own markers inside.

    /// Rows another lane adds for the current state — build them with
    /// `RailNotice.deferred(id:title:daysLeft:category:)`, and give them a
    /// route through `laneRoute(forNoticeID:)` below.
    private func laneNotices(_ state: GameState) -> [RailNotice] {
        // MARK: J1 (doors)
        let doors = DoorRail.notices(for: state)
        // MARK: end J1
        // Iteration 12 merge — J5's announced-date countdown (wired here
        // because `AnnounceRail` did not exist on J6's branch).
        return doors + AnnounceRail.notices(state: state)
    }

    /// A tip for the current state, used only when no active goal has one.
    private var fallbackTip: CoachTip? {
        // MARK: J1 (doors)
        CoachTip.stateTip(in: engine.state, dismissed: dismissedTips)
        // MARK: end J1
    }

    /// Where a deferred row without a queue answer should walk the founder,
    /// by the notice's id (`"deferred-<id>"`); `nil` keeps the original
    /// behaviour, which brings the deferred story beat back.
    private func laneRoute(forNoticeID noticeID: String) -> Route? {
        // MARK: J1 (doors)
        DoorRail.route(forNoticeID: noticeID)
        // MARK: end J1
    }

    private var shown: RailNotice? {
        let queue = queue
        guard !queue.isEmpty else { return nil }
        let index = ((cycle % queue.count) + queue.count) % queue.count
        return queue[index]
    }

    // MARK: - Body

    var body: some View {
        // A container that is always present keeps the rail's entrance and
        // exit transitions attached to something that outlives them.
        ZStack(alignment: .top) {
            if let notice = shown {
                row(for: notice, queued: queue.count - 1)
                    .id(notice.id)
                    .transition(Theme.Motion.transition(.move(edge: .top).combined(with: .opacity)))
            }
        }
        .animation(Theme.Motion.weighted, value: shown?.id)
        .onChange(of: queue.first?.id) { _, _ in cycle = 0 }
        // MARK: U1 (ux: the first-hour fixes)
        .onChange(of: shown?.id) { _, _ in expandedID = nil }
        // MARK: end U1
        // The tour's exit dismisses the six tips in settings; the rail's
        // copy was read before that and has to catch up.
        .onChange(of: session?.tutorial?.isComplete) { _, complete in
            if complete == true { dismissedTips = GameSettings.dismissedTips }
        }
        // MARK: V2 (ux: one inbox, one home per thing)
        // C5: the +N no longer opens the journal from here; it opens
        // "Waiting on you" at the root (`GameShell.showingWaiting`), whose
        // footer carries the journal and the week's report.
        // MARK: end V2
    }

    private func row(for notice: RailNotice, queued: Int) -> some View {
        HStack(spacing: Theme.Spacing.sm) {
            content(for: notice)
            if queued > 0 {
                counter(queued)
            }
        }
        .padding(.horizontal, Theme.Spacing.lg)
        // U1 (C3): one line of text between the 34-point buttons, so the
        // rail keeps only a hairline of padding above and below them.
        .padding(.vertical, Theme.Spacing.xs)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint(for: notice).opacity(0.12))
        .overlay(alignment: .leading) {
            // A pixel-width ink bar in the notice's colour: the rail is
            // part of the HUD's chrome, not a system banner.
            Rectangle()
                .fill(tint(for: notice))
                .frame(width: 3)
        }
        .overlay(alignment: .bottom) { Divider() }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 24)
                .onEnded { value in
                    guard queued > 0 else { return }
                    Haptics.tap()
                    withAnimation(Theme.Motion.weighted) {
                        cycle += value.translation.width < 0 ? 1 : -1
                    }
                }
        )
        .accessibilityElement(children: .contain)
    }

    /// "+2": more is waiting. Tapping opens "Waiting on you" (V2, C5) —
    /// every open question in one list, with the journal at its foot;
    /// swiping the rail pages through the notices in place.
    private func counter(_ count: Int) -> some View {
        Button {
            Haptics.tap()
            // MARK: V2 (ux: one inbox, one home per thing)
            shell.showingWaiting = true
            // MARK: end V2
        } label: {
            Text("+\(count)")
                .font(.system(.caption, design: .rounded).weight(.bold).monospacedDigit())
                .foregroundStyle(Theme.accent)
                .padding(.horizontal, Theme.Spacing.sm)
                .frame(minHeight: 28)
                .background(Theme.chipBackground, in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.pressableRow)
        .accessibilityLabel("\(count) more notice\(count == 1 ? "" : "s")")
        .accessibilityHint("Opens what is waiting on you; swipe the notice to see the next one")
    }

    // MARK: - Rows

    @ViewBuilder
    private func content(for notice: RailNotice) -> some View {
        // U1 (C3): every line takes the notice's id, so a tap can open it.
        switch notice.kind {
        case .pause(let headline, let more):
            pauseRow(headline: headline, more: more, noticeID: notice.id)
        case .deferred(let title, let daysLeft, let category):
            deferredRow(
                title: title, daysLeft: daysLeft, category: category,
                answer: notice.answer, noticeID: notice.id
            )
        case .report(let week):
            reportRow(week: week)
        case .event(let toast):
            eventRow(toast, noticeID: notice.id)
        case .tip(let tip):
            tipRow(tip, noticeID: notice.id)
        case .tour(let step):
            tourRow(step, noticeID: notice.id)
        }
    }

    /// Iteration 7 (R1): the tour's line — the beat's sentence, with the
    /// card under the tab bar carrying the button. The line reads the
    /// state, because the ship beat says something different when nothing
    /// is building.
    private func tourRow(_ step: TutorialStep, noticeID: String) -> some View {
        let line = TutorialScript.railLine(for: step, state: engine.state)
        return HStack(alignment: .center, spacing: Theme.Spacing.sm) {
            Image(systemName: "hand.point.up.left.fill")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.accent)
                .frame(width: 22)
            oneLine(
                Text(line)
                    .font(.footnote)
                    .foregroundStyle(.primary),
                noticeID: noticeID
            )
            Spacer(minLength: 0)
        }
        .frame(minHeight: 34)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Tour, \(step.title): \(line)")
    }

    private func pauseRow(headline: GameEvent, more: Int, noticeID: String) -> some View {
        let line = copy.line(for: headline)
        // A story question's feed line ends "— 5 days to answer", which is
        // true in the journal and false here: the clock is stopped for
        // exactly that question, so the days cannot pass until it is
        // answered or deferred. The rail shows the headline alone.
        let message: String = if case .narrativeChoice = headline,
                                 let head = line.message.components(separatedBy: " — ").first {
            head
        } else {
            line.message
        }
        return HStack(spacing: Theme.Spacing.md) {
            Image(systemName: line.icon)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(line.tint)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 1) {
                oneLine(
                    Text(message)
                        .font(.system(.footnote, design: .rounded).weight(.semibold))
                        .multilineTextAlignment(.leading),
                    noticeID: noticeID
                )
                if more > 0 {
                    Text("+\(more) more this day")
                        .font(.caption2)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: Theme.Spacing.sm)

            if let route = route(for: headline), let onRoute {
                Button {
                    Haptics.tap()
                    Sounds.play(.tap)
                    onRoute(route)
                } label: {
                    Text("Details")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, Theme.Spacing.sm)
                        .frame(minHeight: 34)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
            }

            // MARK: U1 (ux: the first-hour fixes)
            // C3: the speed control is the one control for time. While its
            // dot already says something stopped the clock, the rail does
            // not carry a second play button.
            if !speedControlCarriesTheDot {
                Button {
                    Haptics.commit()
                    Sounds.play(.tap)
                    engine.setSpeed(.x1)
                } label: {
                    Label("Resume", systemImage: "play.fill")
                        .labelStyle(.iconOnly)
                        .font(.footnote.weight(.bold))
                        .padding(.horizontal, Theme.Spacing.md)
                        .padding(.vertical, Theme.Spacing.sm)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
                .accessibilityLabel("Resume time")
            }
            // MARK: end U1
        }
        .frame(minHeight: 34)
        .accessibilityLabel("Time is paused: \(message)")
    }

    private func deferredRow(
        title: String, daysLeft: Int, category: String?, answer: QueueRailAnswer? = nil,
        noticeID: String? = nil
    ) -> some View {
        let when = switch daysLeft {
        // Iteration 12 (J6): a question with no deadline — the partner
        // waiting up, a funeral, an old post — says so instead of counting.
        case ..<0: String(localized: "waiting on you", comment: "Notice rail: a question with no deadline, waiting for the founder")
        case 0: String(localized: "answers itself today", comment: "Notice rail: a deferred question whose deadline is today")
        case 1: String(localized: "1 day left", comment: "Notice rail: a deferred question with one day of its deadline left")
        default: String(localized: "\(daysLeft) days left", comment: "Notice rail: days left on a deferred question. Always 2 or more")
        }
        return HStack(spacing: Theme.Spacing.md) {
            Image(systemName: EventPresenter.icon(forCategory: category))
                .font(.subheadline.weight(.bold))
                .foregroundStyle(EventPresenter.tint(forCategory: category))
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 1) {
                oneLine(
                    Text(title)
                        .font(.system(.footnote, design: .rounded).weight(.semibold)),
                    noticeID: noticeID ?? title
                )
                Text(when)
                    .font(.caption2)
                    .monospacedDigit()
                    .foregroundStyle(daysLeft <= 1 ? Theme.warning : .secondary)
            }

            Spacer(minLength: Theme.Spacing.sm)

            Button {
                Haptics.commit()
                Sounds.play(.tap)
                // Iteration 12 (J6): the queued question's own answer.
                switch answer {
                case .recall(let promptID): shell.recall(promptID: promptID)
                case .route(let route): onRoute?(route)
                case nil:
                    // The lane route seam first (J1's doors), then the
                    // original recall of the deferred story beat.
                    if let noticeID, let route = laneRoute(forNoticeID: noticeID), let onRoute {
                        onRoute(route)
                    } else {
                        shell.recallDeferredChoice()
                    }
                }
            } label: {
                Text("Answer")
                    .font(.footnote.weight(.bold))
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.vertical, Theme.Spacing.sm)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.accent)
        }
        .accessibilityLabel("\(title), \(when)")
    }

    private func reportRow(week: Int) -> some View {
        HStack(spacing: Theme.Spacing.sm) {
            Button {
                shell.openWeeklyReport(engine: engine)
            } label: {
                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.footnote.weight(.bold))
                    Text("Week \(week) report")
                        .font(.system(.footnote, design: .rounded).weight(.semibold))
                        .monospacedDigit()
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                }
                .frame(minHeight: 34)
                .contentShape(Rectangle())
            }
            .buttonStyle(.pressableRow)
            .accessibilityHint("Opens the weekly report")

            // The report's companion: the same week as a front page (U2).
            if let onRoute {
                Button {
                    Haptics.tap()
                    onRoute(.newspaper)
                } label: {
                    Image(systemName: "newspaper.fill")
                        .font(.footnote.weight(.bold))
                        .frame(width: 34, height: 34)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.pressableRow)
                .accessibilityLabel("Front page")
                .accessibilityHint("Opens the week's newspaper")
            }
        }
        .foregroundStyle(Theme.accent)
    }

    /// The newest toast. The message stays in the system face because a
    /// full sentence in the 5×7 bitmap font does not fit a phone width;
    /// the ink bar, the icon and the tint are the rail's chrome.
    private func eventRow(_ toast: Toast, noticeID: String) -> some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: toast.icon)
                .font(.footnote.weight(.bold))
                .foregroundStyle(toast.tint)
                .frame(width: 22)
            oneLine(
                Text(toast.message)
                    .font(.system(.footnote, design: .rounded).weight(.medium))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading),
                noticeID: noticeID
            )
            Spacer(minLength: 0)
        }
        .frame(minHeight: 34)
        .accessibilityLabel(toast.message)
    }

    private func tipRow(_ tip: CoachTip, noticeID: String) -> some View {
        HStack(alignment: .center, spacing: Theme.Spacing.sm) {
            Image(systemName: tip.systemImage)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.accent)
                .frame(width: 22)
            oneLine(
                Text(tip.message)
                    .font(.footnote)
                    .foregroundStyle(.primary),
                noticeID: noticeID
            )
            Spacer(minLength: 0)
            if let route = tip.route, let label = tip.routeLabel, let onRoute {
                Button {
                    Haptics.tap()
                    onRoute(route)
                } label: {
                    Label(label, systemImage: "arrow.forward")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, Theme.Spacing.sm)
                        .frame(minHeight: 34)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
            }
            Button {
                Haptics.tap()
                dismiss(tip)
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 36, height: 34) // U1 (C3): the rail's 34-point line
                    .contentShape(Rectangle())
            }
            .buttonStyle(.pressableRow)
            .accessibilityLabel("Dismiss tip")
        }
        // MARK: U1 (ux: the first-hour fixes)
        // C3: a tip on screen for three seconds has been said; once it
        // leaves (another tab, another notice) it does not come back this
        // session. Only under a tab: a preview keeps its tip.
        .task(id: tip.id) {
            guard railTab != nil else { return }
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            tipLedger.markSeen(tip.id)
        }
        .onDisappear { tipLedger.left(tip.id) }
        // MARK: end U1
    }

    private func dismiss(_ tip: CoachTip) {
        withAnimation(Theme.Motion.entrance) {
            _ = dismissedTips.insert(tip.id)
        }
        GameSettings.dismissedTips = dismissedTips
    }

    // MARK: - Helpers

    private func tint(for notice: RailNotice) -> Color {
        switch notice.kind {
        case .pause(let headline, _): copy.line(for: headline).tint
        case .deferred(_, _, let category): EventPresenter.tint(forCategory: category)
        case .report: Theme.accent
        case .event(let toast): toast.tint
        case .tip: Theme.accent
        case .tour: Theme.accent
        }
    }

    /// Where "Details" should take the player for a pause reason.
    private func route(for event: GameEvent) -> Route? {
        switch event {
        case .reviewsIn(let productID, _, _),
             .shipped(let productID, _),
             .productOffMarket(let productID, _):
            .product(productID)
        case .marketBoom(let topicID, _), .marketCrash(let topicID, _):
            .marketReport(topicID: topicID)
        case .contractFailed, .contractDelivered, .contractCompleted:
            .contracts
        case .researchCompleted, .researchStarted:
            .research
        case .employeeQuit, .candidatesRefreshed:
            .hiring
        // Iteration 12 (J6): wave two's stops, which used to name a
        // reason and leave the room it was about three screens away.
        case .dirtyMoneyOffered: .dirtyMoney
        case .crimeCaseRaised: .crimeLedger
        case .crimeHearingDue, .crimeHearingOpened: .courtroom
        case .familyParentDied, .familyDivorced: .family
        case .fameCancellationRaised: .feed
        default:
            nil
        }
    }
}

/// Iteration 12 (J6): what a queued question's rail button does.
enum QueueRailAnswer: Equatable {
    /// Bring the sheet the founder put off back to the root.
    case recall(promptID: String)
    /// Walk into the room the question is answered in.
    case route(Route)
}

// MARK: U1 (ux: the first-hour fixes)

/// C3: the rail is one line. Each notice's text is clipped to a line,
/// and a tap on it opens the full text in place.
extension NoticeRail {
    fileprivate func oneLine(_ text: some View, noticeID: String) -> some View {
        let open = expandedID == noticeID
        return text
            .lineLimit(open ? nil : 1)
            .fixedSize(horizontal: false, vertical: open)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(Theme.Motion.selection) { expandedID = open ? nil : noticeID }
            }
            .accessibilityHint(open ? "" : "Shows the whole line")
    }

    /// The same three reasons `TopHUD` puts a dot on the speed control
    /// for: the clock stopped for something, a report is unread, a
    /// deferred question is counting down.
    fileprivate var speedControlCarriesTheDot: Bool {
        !engine.lastPauseEvents.isEmpty
            || shell.pendingReportWeek != nil
            || shell.deferredChoiceID != nil
    }

    /// C3: the tip for this tab. A tip shows on the tab its button goes to
    /// — HQ when it has none — at most once a session, and the office's
    /// first-time line is one of HQ's tips now. The goal tips lead, then
    /// the office, then J1's state and door tips, in their own order.
    fileprivate var firstHourTip: CoachTip? {
        guard let railTab else { return nil }
        let excluded = dismissedTips
            .union(GameSettings.dismissedTips)
            .union(tipLedger.said)
        func here(_ tip: CoachTip) -> Bool {
            RailTipLedger.tab(for: tip) == railTab && !excluded.contains(tip.id)
        }
        let activeGoals = Set(ProgressionReader.activeGoalIDs(in: engine.state))
        if let tip = CoachTip.all.first(where: { activeGoals.contains($0.goalID) && here($0) }) {
            return tip
        }
        if here(.officeTap) { return .officeTap }
        let elsewhere = (CoachTip.doorTips + CoachTip.stateKeyed).filter { !here($0) }.map(\.id)
        return CoachTip.stateTip(in: engine.state, dismissed: excluded.union(elsewhere))
    }
}

/// C3: which tab a rail sits under. Set per tab in `AppRootView`.
private struct RailTabKey: EnvironmentKey {
    static let defaultValue: GameTab? = nil
}

extension EnvironmentValues {
    var railTab: GameTab? {
        get { self[RailTabKey.self] }
        set { self[RailTabKey.self] = newValue }
    }
}

/// C3: the coach tips said this session. Not saved: a new launch may say
/// a tip again, until it is dismissed for good with its X.
@MainActor
@Observable
final class RailTipLedger {
    static let shared = RailTipLedger()

    /// Shown for long enough and then gone; these stay off the rail.
    private(set) var said: Set<String> = []
    /// On screen for three seconds; said once it leaves.
    @ObservationIgnored private var seen: Set<String> = []

    func markSeen(_ id: String) { seen.insert(id) }

    func left(_ id: String) {
        guard seen.contains(id) else { return }
        said.insert(id)
    }

    /// The tab a tip concerns: where its button goes, or HQ.
    static func tab(for tip: CoachTip) -> GameTab {
        tip.route?.tab ?? .hq
    }
}

extension CoachTip {
    /// The office's first-time line, which used to sit under the scene as a
    /// second tip strip. Same id, so an office already dismissed stays
    /// dismissed, and the first tap on the scene still dismisses it.
    static let officeTap = CoachTip(
        // `OfficeTapHint.tipID`, spelled out: that one is main-actor
        // isolated, and this catalog is not.
        id: "tip.office_tap",
        goalID: "office.tap",
        message: String(localized: "Tap anyone — or the whiteboard, the coffee machine, the door.", comment: "Coach tip on HQ's rail the first time: the office scene can be tapped"),
        systemImage: "hand.tap.fill"
    )
}

// MARK: end U1

extension NoticeRail {

    private func severityRank(_ severity: EventSeverity) -> Int {
        switch severity {
        case .quiet: 0
        case .info: 1
        case .notable: 2
        case .critical: 3
        }
    }
}
