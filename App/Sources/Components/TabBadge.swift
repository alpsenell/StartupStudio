import TycoonContent
import TycoonEngine

// MARK: U1 (ux: the first-hour fixes)

/// Iteration 13 — U1, C6. What the numbers on the tab bar count: the
/// things that need the founder, and nothing else.
///
/// - **Life:** phone threads waiting on an answer, doors waiting on one,
///   and the questions whose room is on Life (the partner who knows, a
///   funeral, a case, a hearing, an old post).
/// - **Business:** desk rows due inside a week.
/// - **Team:** unchanged (`EmployeeStatus.attentionCount`).
/// - **HQ and Products:** none.
///
/// App-side reads only; the engine and the save are untouched.
enum TabBadge {
    /// The queue's questions that are answered in a room on Life.
    static let lifeQueueKinds: Set<QueueKind> = [
        .confrontation, .funeral, .legalCase, .hearing, .cancellation,
        // MARK: K1 (founder money) — the landlord's question is answered on Life (merge glue).
        .rescue,
        // MARK: end K1
    ]

    /// How far ahead a desk row counts as needing the founder.
    static let deskHorizonDays = 7

    static func life(in state: GameState, content: ContentCatalog) -> Int {
        let asking = state.life.phone.threads.filter {
            PhoneReply.isWaiting($0.counterpart, in: state, content: content)
        }.count
        let doors = state.doors.open(on: state.day).count
        let questions = QueueBoard.entries(in: state).filter { lifeQueueKinds.contains($0.kind) }.count
        return asking + doors + questions
    }

    static func business(in state: GameState, balance: BalanceConfig, content: ContentCatalog) -> Int {
        Desk.items(in: state, balance: balance, content: content)
            .filter { ($0.daysLeft ?? .max) <= deskHorizonDays }
            .count
    }

    /// The office's Sunday line ("Week 128 closed. In $58,596…"). The
    /// weekly report is its delivery, so it does not count as unread in
    /// the phone's totals. The thread's own dot inside the phone is left
    /// as it was.
    static func isWeeklyClose(_ message: PhoneMessage, in thread: PhoneThread) -> Bool {
        thread.counterpart == .office
            && message.eventID == nil
            && message.text.hasPrefix("Week ")
            && message.text.contains(" closed. ")
    }

    /// `PhoneState.unreadCount`, without the weekly closes.
    static func unread(_ phone: PhoneState) -> Int {
        phone.threads.reduce(0) { total, thread in
            total + thread.messages.filter {
                !$0.fromFounder && $0.day > thread.lastReadDay && !isWeeklyClose($0, in: thread)
            }.count
        }
    }
}

// MARK: end U1
