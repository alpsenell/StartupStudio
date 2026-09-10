import SwiftUI
import TycoonEngine

// MARK: Iteration 9 — L1 (the phone)

/// The three newest threads, one line each, under the week. Unread is
/// bold; a question still waiting on an answer says so.
///
/// A founder with nobody in their life has no phone card at all — the
/// phone opens with the first person who texts, which is the same day the
/// engine first posts anything.
struct PhoneCard: View {
    let engine: GameEngine
    /// Opens the phone. `nil` in a snapshot.
    var onOpen: (() -> Void)?
    /// Opens one thread directly.
    var onOpenThread: ((PhoneCounterpart) -> Void)?

    var body: some View {
        let state = engine.state
        // V2 (C10): the order the phone shows, weekly closes left out.
        let threads = Array(state.life.phone.shownByRecency.prefix(3))
        if !threads.isEmpty {
            CardView("Phone", systemImage: "bubble.left.and.bubble.right.fill") {
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    ForEach(threads) { thread in
                        Button {
                            Haptics.tap()
                            onOpenThread?(thread.counterpart)
                        } label: {
                            PhoneThreadRow(
                                thread: thread,
                                name: state.phoneName(for: thread.counterpart),
                                seed: state.phoneSeed(for: thread.counterpart),
                                day: state.day,
                                isAsking: PhoneReply.isWaiting(
                                    thread.counterpart, in: state, content: engine.content
                                )
                            )
                        }
                        .buttonStyle(.pressableRow)
                    }
                    Button {
                        Haptics.tap()
                        onOpen?()
                    } label: {
                        Label(openLabel(state), systemImage: "chevron.right")
                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                            .labelStyle(.trailingIcon)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.pressable)
                    .tint(Theme.accent)
                }
            }
        }
    }

    private func openLabel(_ state: GameState) -> String {
        // MARK: U1 (ux: the first-hour fixes) — C6: weekly closes are read
        let unread = TabBadge.unread(state.life.phone)
        // MARK: end U1
        let threads = state.life.phone.threads.count
        if unread > 0 {
            return "Open the phone · \(unread) unread"
        }
        return "Open the phone · \(threads) thread\(threads == 1 ? "" : "s")"
    }
}

/// One line of the phone: a face, a name, the last thing said, and when.
struct PhoneThreadRow: View {
    let thread: PhoneThread
    let name: String
    let seed: UInt64?
    let day: Int
    /// Whether the pending question was asked here — the row that is
    /// actually waiting on the founder.
    var isAsking = false

    // MARK: V2 (ux: one inbox, one home per thing)
    // C10: the row reads the thread as the phone shows it — the office's
    // weekly closes are the report's, so they are not the preview, not the
    // time, and not the unread number.
    private var unreadCount: Int { thread.shownUnreadCount }
    private var unread: Bool { unreadCount > 0 }
    // MARK: end V2

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            if let seed {
                PixelPortrait(seed: seed, size: 34)
            } else {
                PixelIconTile(systemImage: "building.2.fill", size: 34)
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: Theme.Spacing.sm) {
                    Text(name)
                        .font(.system(.subheadline, design: .rounded).weight(unread ? .bold : .semibold))
                        .foregroundStyle(.primary)
                    if isAsking {
                        Text("WAITING")
                            .font(.system(size: 9, design: .rounded).weight(.heavy))
                            .kerning(0.6)
                            .foregroundStyle(Theme.ink(on: Theme.warning))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Theme.warning, in: Capsule())
                    }
                    Spacer(minLength: 0)
                    Text(agoLabel)
                        .font(.caption2)
                        .monospacedDigit()
                        .foregroundStyle(.tertiary)
                }
                Text(preview)
                    .font(.caption)
                    .foregroundStyle(unread ? .primary : .secondary)
                    .fontWeight(unread ? .semibold : .regular)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            if unread {
                Text("\(unreadCount)")
                    .font(Theme.Typography.number(.caption2))
                    .foregroundStyle(Theme.onTint)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Theme.accent, in: Capsule())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.md)
        .background(Theme.chipBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(name). \(preview). \(unread ? "\(unreadCount) unread." : "Read.")"
        )
    }

    private var preview: String {
        guard let last = thread.shownLastMessage else {
            // V2 (C10): a thread of weekly closes alone.
            return thread.messages.isEmpty
                ? "No messages"
                : String(localized: "The weekly closes are in the weekly report", comment: "Phone row: the office thread when it holds nothing but weekly closes")
        }
        if last.kind == .unanswered { return last.text }
        return last.fromFounder ? "You: \(last.text)" : last.text
    }

    /// "Today", "Yesterday", "4d" — a phone's own idea of time.
    private var agoLabel: String {
        let days = day - thread.shownLastDay
        return switch days {
        case ..<1: "Today"
        case 1: "1d"
        default: "\(days)d"
        }
    }
}

// MARK: V2 (ux: one inbox, one home per thing)

/// Iteration 14 — V2, C10. The phone as the player sees it: the office's
/// weekly closes ("Week 128 closed. In $58,596…") are the weekly report's
/// to deliver, so the thread list, the thread and the morning papers leave
/// them out. An app-side filter over the saved posts (U1's
/// `TabBadge.isWeeklyClose`); the save still holds every message, and
/// opening the thread still marks them read.
extension PhoneThread {
    /// The messages the phone draws.
    var shownMessages: [PhoneMessage] {
        messages.filter { !TabBadge.isWeeklyClose($0, in: self) }
    }

    /// Whether anything was left out of `shownMessages`.
    var hidesWeeklyCloses: Bool { shownMessages.count != messages.count }

    var shownLastMessage: PhoneMessage? { shownMessages.last }

    /// The day of the newest message shown; the thread's own last day
    /// when it holds only closes, so it sorts where it always did.
    var shownLastDay: Int { shownLastMessage?.day ?? lastDay }

    /// Unread, without the closes — `TabBadge.unread`, one thread.
    var shownUnreadCount: Int {
        shownMessages.filter { !$0.fromFounder && $0.day > lastReadDay }.count
    }
}

extension PhoneState {
    /// `byRecency`, sorted on what the phone shows: a thread of weekly
    /// closes stops rising to the top every Sunday.
    var shownByRecency: [PhoneThread] {
        threads.sorted {
            $0.shownLastDay == $1.shownLastDay
                ? $0.counterpart.sortKey < $1.counterpart.sortKey
                : $0.shownLastDay > $1.shownLastDay
        }
    }
}

// MARK: end V2

/// A `Label` with the icon on the right, for a "go there" row.
struct TrailingIconLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: Theme.Spacing.sm) {
            configuration.title
            configuration.icon.font(.caption.weight(.bold))
        }
    }
}

extension LabelStyle where Self == TrailingIconLabelStyle {
    static var trailingIcon: TrailingIconLabelStyle { TrailingIconLabelStyle() }
}
