import SwiftUI
import TycoonEngine

// MARK: Iteration 10 — M5 (the morning desk)

/// The desk at the front door: the streak, the three papers as three
/// ticks, and the one button that opens it.
///
/// Drawn from plain values rather than a session so the snapshot suite
/// can render the title screen without standing one up, and absent
/// entirely when there is no game behind the door — the desk belongs to a
/// company.
struct MorningDeskCard: View {
    /// Today's streak, 0 once it has lapsed.
    let streak: Int
    let best: Int
    /// The papers already dealt with today.
    let done: [DeskPart]
    /// The line under the heading: what is still waiting.
    let summary: String
    var onOpen: () -> Void = {}

    private var isCleared: Bool { DeskPart.allCases.allSatisfy(done.contains) }

    var body: some View {
        PixelPanel {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                HStack(alignment: .top, spacing: Theme.Spacing.md) {
                    VStack(alignment: .leading, spacing: 2) {
                        PixelText(
                            text: String(localized: "THE DESK", comment: "Bitmap heading on the front door's morning desk card. Uppercase: the pixel face has no lowercase"),
                            scale: 2,
                            color: Theme.pixelAccent
                        )
                        Text(summary)
                            .font(.caption)
                            .foregroundStyle(Theme.pixelInk.opacity(0.8))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                    MorningDeskStreakPill(streak: streak, best: best)
                }
                HStack(spacing: Theme.Spacing.sm) {
                    ForEach(DeskPart.allCases.sorted { $0.order < $1.order }, id: \.self) { part in
                        MorningDeskTick(part: part, isDone: done.contains(part))
                    }
                }
                Button(action: onOpen) {
                    Label(
                        isCleared ? "Look at the desk" : "Open the desk",
                        systemImage: isCleared ? "checkmark.circle.fill" : "tray.full.fill"
                    )
                    .font(.system(.headline, design: .rounded))
                }
                .buttonStyle(PixelButtonStyle())
                .accessibilityHint(isCleared
                    ? "Today is already cleared"
                    : "One message, one decision, one tap")
            }
        }
        .accessibilityElement(children: .contain)
    }
}

/// One of the three, ticked or not.
private struct MorningDeskTick: View {
    let part: DeskPart
    let isDone: Bool

    var body: some View {
        HStack(spacing: Theme.Spacing.xs) {
            Image(systemName: isDone ? "checkmark.square.fill" : "square")
                .font(.caption.weight(.bold))
                .foregroundStyle(isDone ? Theme.accent : Theme.pixelInk.opacity(0.4))
            Text(word)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Theme.pixelInk.opacity(isDone ? 0.5 : 0.85))
                .strikethrough(isDone, color: Theme.pixelInk.opacity(0.5))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(part.title): \(isDone ? "done" : "waiting")")
    }

    private var word: String {
        switch part {
        case .message: "Message"
        case .decision: "Decision"
        case .tap: "Tap"
        }
    }
}

extension MorningDeskCard {
    /// The card for a session, or `nil` when there is nothing behind the
    /// door to have a morning about.
    static func make(session: GameSession, onOpen: @escaping () -> Void) -> MorningDeskCard? {
        guard let board = session.deskBoard() else { return nil }
        return MorningDeskCard(
            streak: session.deskLiveStreak,
            best: session.ledger.deskBestStreak,
            done: DeskPart.allCases.filter(board.isDone),
            summary: summary(for: board),
            onOpen: onOpen
        )
    }

    /// One line about what is still waiting: the person who asked, then
    /// the thing with the clock on it, then the kind thing.
    private static func summary(for board: MorningDeskBoard) -> String {
        if board.isCleared { return "Cleared. Come back tomorrow." }
        if !board.isDone(.message), let message = board.message {
            return message.isAsking
                ? "\(message.name) is waiting on an answer."
                : "\(message.name) said something."
        }
        if !board.isDone(.decision), let decision = board.decision {
            return decision.text
        }
        return board.tap.title
    }
}
