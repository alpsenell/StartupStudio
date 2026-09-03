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
    }

    let id: String
    let kind: Kind
    /// Lower leads.
    let priority: Int

    static func pause(_ headline: GameEvent, more: Int) -> RailNotice {
        RailNotice(id: "pause", kind: .pause(headline: headline, more: more), priority: 0)
    }

    static func deferred(id: String, title: String, daysLeft: Int, category: String?) -> RailNotice {
        RailNotice(
            id: "deferred-\(id)",
            kind: .deferred(title: title, daysLeft: daysLeft, category: category),
            priority: 1
        )
    }

    static func report(week: Int) -> RailNotice {
        RailNotice(id: "report-\(week)", kind: .report(week: week), priority: 2)
    }

    static func event(_ toast: Toast) -> RailNotice {
        RailNotice(id: "toast-\(toast.id)", kind: .event(toast), priority: 3)
    }

    static func tip(_ tip: CoachTip) -> RailNotice {
        RailNotice(id: "tip-\(tip.id)", kind: .tip(tip), priority: 4)
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

    /// Which queued notice is showing, relative to the leader; a swipe
    /// moves it and a change of leader resets it.
    @State private var cycle = 0
    @State private var dismissedTips: Set<String> = GameSettings.dismissedTips
    @State private var showingJournal = false

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

        // A story question the player put off: the clock is running and the
        // deadline is real, so the countdown belongs on the rail.
        if shell.deferredChoiceID != nil, state.speed != .paused,
           let pending = state.narrative.pendingChoice {
            notices.append(
                .deferred(
                    id: pending.id,
                    title: pending.title,
                    daysLeft: max(0, pending.respondByDay - state.day),
                    category: pending.category
                )
            )
        }

        if let week = shell.pendingReportWeek {
            notices.append(.report(week: week))
        }

        if let toast = shell.toasts.toasts.last {
            notices.append(.event(toast))
        }

        if let tip = activeTip {
            notices.append(.tip(tip))
        }
        return notices
    }

    /// The tip for the player's most recently activated goal, unless they
    /// dismissed it or finished the goal.
    private var activeTip: CoachTip? {
        let activeGoals = ProgressionReader.activeGoalIDs(in: engine.state)
        guard !activeGoals.isEmpty else { return nil }
        return CoachTip.all.first {
            activeGoals.contains($0.goalID) && !dismissedTips.contains($0.id)
        }
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
        .sheet(isPresented: $showingJournal) {
            NavigationStack {
                JournalScreen(engine: engine)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") { showingJournal = false }
                        }
                    }
            }
        }
    }

    private func row(for notice: RailNotice, queued: Int) -> some View {
        HStack(spacing: Theme.Spacing.sm) {
            content(for: notice)
            if queued > 0 {
                counter(queued)
            }
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.vertical, Theme.Spacing.sm)
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

    /// "+2": more is waiting. Tapping opens the journal, where every
    /// notice ends up; swiping the rail pages through them in place.
    private func counter(_ count: Int) -> some View {
        Button {
            Haptics.tap()
            showingJournal = true
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
        .accessibilityHint("Opens the journal; swipe the notice to see the next one")
    }

    // MARK: - Rows

    @ViewBuilder
    private func content(for notice: RailNotice) -> some View {
        switch notice.kind {
        case .pause(let headline, let more):
            pauseRow(headline: headline, more: more)
        case .deferred(let title, let daysLeft, let category):
            deferredRow(title: title, daysLeft: daysLeft, category: category)
        case .report(let week):
            reportRow(week: week)
        case .event(let toast):
            eventRow(toast)
        case .tip(let tip):
            tipRow(tip)
        }
    }

    private func pauseRow(headline: GameEvent, more: Int) -> some View {
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
                Text(message)
                    .font(.system(.footnote, design: .rounded).weight(.semibold))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
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
        .accessibilityLabel("Time is paused: \(message)")
    }

    private func deferredRow(title: String, daysLeft: Int, category: String?) -> some View {
        let when = switch daysLeft {
        case 0: "answers itself today"
        case 1: "1 day left"
        default: "\(daysLeft) days left"
        }
        return HStack(spacing: Theme.Spacing.md) {
            Image(systemName: EventPresenter.icon(forCategory: category))
                .font(.subheadline.weight(.bold))
                .foregroundStyle(EventPresenter.tint(forCategory: category))
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(.footnote, design: .rounded).weight(.semibold))
                    .lineLimit(1)
                Text(when)
                    .font(.caption2)
                    .monospacedDigit()
                    .foregroundStyle(daysLeft <= 1 ? Theme.warning : .secondary)
            }

            Spacer(minLength: Theme.Spacing.sm)

            Button {
                Haptics.commit()
                Sounds.play(.tap)
                shell.recallDeferredChoice()
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
        .foregroundStyle(Theme.accent)
        .accessibilityHint("Opens the weekly report")
    }

    /// The newest toast. The message stays in the system face because a
    /// full sentence in the 5×7 bitmap font does not fit a phone width;
    /// the ink bar, the icon and the tint are the rail's chrome.
    private func eventRow(_ toast: Toast) -> some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: toast.icon)
                .font(.footnote.weight(.bold))
                .foregroundStyle(toast.tint)
                .frame(width: 22)
            Text(toast.message)
                .font(.system(.footnote, design: .rounded).weight(.medium))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            Spacer(minLength: 0)
        }
        .frame(minHeight: 34)
        .accessibilityLabel(toast.message)
    }

    private func tipRow(_ tip: CoachTip) -> some View {
        HStack(alignment: .center, spacing: Theme.Spacing.sm) {
            Image(systemName: tip.systemImage)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.accent)
                .frame(width: 22)
            Text(tip.message)
                .font(.footnote)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
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
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.pressableRow)
            .accessibilityLabel("Dismiss tip")
        }
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
        default:
            nil
        }
    }

    private func severityRank(_ severity: EventSeverity) -> Int {
        switch severity {
        case .quiet: 0
        case .info: 1
        case .notable: 2
        case .critical: 3
        }
    }
}
