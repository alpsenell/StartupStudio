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
        let threads = Array(state.life.phone.byRecency.prefix(3))
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
        let unread = state.life.phone.unreadCount
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

    private var unread: Bool { thread.unreadCount > 0 }

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
                Text("\(thread.unreadCount)")
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
            "\(name). \(preview). \(unread ? "\(thread.unreadCount) unread." : "Read.")"
        )
    }

    private var preview: String {
        guard let last = thread.lastMessage else { return "No messages" }
        if last.kind == .unanswered { return last.text }
        return last.fromFounder ? "You: \(last.text)" : last.text
    }

    /// "Today", "Yesterday", "4d" — a phone's own idea of time.
    private var agoLabel: String {
        let days = day - thread.lastDay
        return switch days {
        case ..<1: "Today"
        case 1: "1d"
        default: "\(days)d"
        }
    }
}

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
