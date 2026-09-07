import SwiftUI
import TycoonContent
import TycoonEngine

// MARK: Iteration 9 — L1 (the phone)

/// One conversation, scrolled back as far as it goes.
///
/// Bubbles sit on pixel paper: whoever is texting on the left, the founder
/// on the right in the accent, and the marker a deadline left — *Seen. No
/// reply.* — greyed on the right where the answer should have been. When
/// the pending question was asked in this thread, its options are the
/// reply buttons at the bottom and they dispatch the same
/// `resolveChoice` the decision sheet does.
struct ThreadView: View {
    let engine: GameEngine
    let counterpart: PhoneCounterpart

    @Environment(GameShell.self) private var injectedShell: GameShell?
    /// See `GameShell.shared`: read optionally, because SwiftUI updates
    /// this property for presented content before the environment is
    /// installed and the non-optional form traps there.
    private var shell: GameShell { injectedShell ?? .shared }
    @State private var sharing = false

    var body: some View {
        let state = engine.state
        ScrollViewReader { proxy in
            ScrollView {
                ThreadContent(
                    state: state, content: engine.content,
                    counterpart: counterpart, answer: answer
                )
                    .padding(Theme.Spacing.lg)
            }
            .onAppear {
                if DebugLaunch.opensPhoneThreadShareCard { sharing = true }
                markRead()
                proxy.scrollTo(ThreadContent.bottomAnchor, anchor: .bottom)
            }
        }
        .background(Theme.screenBackground)
        .navigationTitle(state.phoneName(for: counterpart))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Haptics.tap()
                    sharing = true
                } label: {
                    Label("Share this thread", systemImage: "square.and.arrow.up")
                }
                .disabled(state.life.phone.thread(with: counterpart)?.messages.isEmpty ?? true)
            }
        }
        .sheet(isPresented: $sharing) {
            ShareCardSheet(card: .phoneThread(engine: engine, counterpart: counterpart))
        }
    }

    /// Opening the thread is reading it: the badge drops by what was in it.
    private func markRead() {
        guard engine.state.life.phone.thread(with: counterpart)?.unreadCount ?? 0 > 0 else { return }
        _ = engine.send(.markPhoneThreadRead(counterpart: counterpart))
    }

    /// The same action the decision sheet sends, from the thread instead.
    private func answer(_ reply: PhoneReply) {
        shell.toasts.send(
            reply.action,
            to: engine,
            ack: reply.label,
            icon: "bubble.right.fill"
        )
    }
}

/// The thread's bubbles, free of the engine and the scroll view so a
/// renderer can draw them for the share card.
struct ThreadContent: View {
    let state: GameState
    let content: ContentCatalog
    let counterpart: PhoneCounterpart
    /// `nil` on the share card, where nothing is tappable.
    var answer: ((PhoneReply) -> Void)?
    /// Whether to draw the reply buttons at all.
    var showsReplies = true

    static let bottomAnchor = "thread-bottom"

    private var thread: PhoneThread? { state.life.phone.thread(with: counterpart) }

    /// What this thread is waiting on the founder to say, if anything.
    private var waiting: PhoneReply.Set? {
        PhoneReply.waiting(in: state, content: content, counterpart: counterpart)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            header
            if let thread, !thread.messages.isEmpty {
                VStack(spacing: Theme.Spacing.sm) {
                    ForEach(Array(grouped(thread.messages).enumerated()), id: \.offset) { _, group in
                        DayDivider(day: group.day, today: state.day)
                        ForEach(group.messages) { message in
                            MessageBubble(message: message)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text("Nothing here yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            if showsReplies, let waiting {
                replies(waiting)
            }
            Color.clear.frame(height: 1).id(Self.bottomAnchor)
        }
    }

    // MARK: Who this is

    private var header: some View {
        HStack(spacing: Theme.Spacing.md) {
            if let seed = state.phoneSeed(for: counterpart) {
                PixelPortrait(seed: seed, size: 48)
            } else {
                PixelIconTile(systemImage: "building.2.fill", size: 48)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(state.phoneName(for: counterpart))
                    .font(.system(.title3, design: .rounded).weight(.semibold))
                Text(state.phoneRelation(for: counterpart))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: The answer, in the thread

    private func replies(_ waiting: PhoneReply.Set) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(spacing: Theme.Spacing.sm) {
                PixelText(
                    text: String(localized: "Reply", comment: "Bitmap heading over the answer buttons inside a phone thread. Uppercase A-Z only: the pixel face has no lowercase and no accents"),
                    scale: 2,
                    color: Theme.pixelAccent
                )
                Spacer(minLength: 0)
                Text(deadlineLine(waiting.respondByDay))
                    .font(.caption2.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(Theme.warning)
            }
            ForEach(waiting.replies) { reply in
                Button {
                    answer?(reply)
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(reply.label)
                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                            .multilineTextAlignment(.leading)
                        // The consequence goes on the button, the way it
                        // does everywhere else in the game.
                        if let detail = reply.detail {
                            Text(detail)
                                .font(.caption2)
                                .opacity(0.85)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        if let reason = reply.disabledReason {
                            Text(reason)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(Theme.warning)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(PixelButtonStyle(fill: fill(for: reply)))
                .disabled(!reply.isEnabled)
                .accessibilityLabel(
                    "\(reply.label). \(reply.detail ?? "") \(reply.disabledReason ?? "")"
                )
            }
            Text("Say nothing and the thread keeps that too.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    /// The firm answer is red, an open one accent, a closed one grey —
    /// the decision sheet's own three fills.
    private func fill(for reply: PhoneReply) -> Color {
        guard reply.isEnabled else { return Theme.chipBackground }
        return reply.isFirm ? Theme.negativeCash : Theme.pixelAccent
    }

    /// "2 days left" — how long the founder has before silence answers.
    private func deadlineLine(_ respondByDay: Int) -> String {
        let left = respondByDay - state.day
        return switch left {
        case ..<0: "The deadline has gone"
        case 0: "Answer today"
        case 1: "1 day left"
        default: "\(left) days left"
        }
    }

    // MARK: Days

    private struct DayGroup {
        let day: Int
        let messages: [PhoneMessage]
    }

    /// Consecutive messages from the same day, so the thread reads as days
    /// rather than a wall.
    private func grouped(_ messages: [PhoneMessage]) -> [DayGroup] {
        var groups: [DayGroup] = []
        for message in messages {
            if let last = groups.last, last.day == message.day {
                groups[groups.count - 1] = DayGroup(day: last.day, messages: last.messages + [message])
            } else {
                groups.append(DayGroup(day: message.day, messages: [message]))
            }
        }
        return groups
    }
}

/// A day's rule across the thread, in the bitmap face.
private struct DayDivider: View {
    let day: Int
    let today: Int

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Rectangle().fill(Color.secondary.opacity(0.25)).frame(height: 1)
            PixelText(text: label, scale: 1, color: Color.secondary)
            Rectangle().fill(Color.secondary.opacity(0.25)).frame(height: 1)
        }
        .padding(.top, Theme.Spacing.sm)
        .accessibilityLabel(label)
    }

    private var label: String {
        let calendar = GameCalendar(day: day)
        return day == today ? "Today" : calendar.shortLabel
    }
}

/// One bubble. The founder's are right-aligned in the accent; everybody
/// else's are pixel paper on the left. The marker is neither: it is the
/// shape of a reply with nothing in it.
struct MessageBubble: View {
    let message: PhoneMessage

    private var isMarker: Bool { message.kind == .unanswered }

    var body: some View {
        HStack {
            if message.fromFounder { Spacer(minLength: 40) }
            Text(message.text)
                .font(.subheadline)
                .italic(isMarker)
                .foregroundStyle(ink)
                .multilineTextAlignment(message.fromFounder ? .trailing : .leading)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, Theme.Spacing.sm)
                .background(fill)
                .overlay {
                    PixelPanelBorder(thickness: 2, corner: 2)
                        .fill(Theme.pixelInk.opacity(isMarker ? 0.25 : 0.5))
                }
                .compositingGroup()
            if !message.fromFounder { Spacer(minLength: 40) }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            isMarker
                ? "You never replied."
                : "\(message.fromFounder ? "You said" : "They said"): \(message.text)"
        )
    }

    private var fill: Color {
        if isMarker { return Theme.chipBackground }
        return message.fromFounder ? Theme.pixelAccent : Theme.pixelPaper
    }

    private var ink: Color {
        if isMarker { return .secondary }
        return message.fromFounder ? Theme.ink(on: Theme.pixelAccent) : Theme.pixelInk
    }
}
