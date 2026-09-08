import Foundation
import SwiftUI
import TycoonContent
import TycoonEngine

// MARK: Iteration 10 — M5 (the morning desk)

/// The three papers on the desk, read off the slot's state without
/// advancing anything.
///
/// The message and the tap come from the engine (`PhoneReply`,
/// `MorningDesk.tap`); the decision is the Business tab's own desk list
/// (`Desk.items`), which is why the board is assembled here rather than
/// in the engine. Nothing in this file ticks a clock, spends a day or
/// draws from an RNG: every value is a pure read of the state, and the
/// only things that change anything are the actions the papers carry.
struct MorningDeskBoard {
    /// Today, as `yyyymmdd` in the player's own calendar.
    let today: Int
    /// The message waiting, or `nil` when nobody has texted.
    let message: MorningDeskMessage?
    /// The most urgent thing on the business desk, or `nil` when the desk
    /// is clear.
    let decision: DeskItem?
    /// The one tap. Always present — the plant is the floor of it.
    let tap: DeskTapCard
    /// The parts already done today.
    let done: [DeskPart]

    /// Everything the state needs to say about a paper that has no work
    /// on it: an empty inbox and an empty desk are cleared by being empty,
    /// so a solo founder on a quiet Tuesday can still keep a streak.
    func isDone(_ part: DeskPart) -> Bool {
        if done.contains(part) { return true }
        switch part {
        case .message: return message == nil
        case .decision: return decision == nil
        case .tap: return false
        }
    }

    var isCleared: Bool { DeskPart.allCases.allSatisfy(isDone) }

    /// How many of the three are behind them.
    var doneCount: Int { DeskPart.allCases.filter(isDone).count }

    /// The parts that are done *because there is nothing there* — the
    /// desk marks these itself the moment it is opened, so the state
    /// agrees with what the player sees.
    var emptyParts: [DeskPart] {
        DeskPart.allCases.filter { !done.contains($0) && isDone($0) }
    }

    /// Builds today's board.
    static func make(
        state: GameState,
        content: ContentCatalog,
        balance: BalanceConfig,
        today: Int
    ) -> MorningDeskBoard {
        MorningDeskBoard(
            today: today,
            message: MorningDeskMessage.waiting(in: state, content: content),
            decision: Desk.items(in: state, balance: balance, content: content).first,
            tap: MorningDesk.tap(in: state, balance: balance, on: today),
            done: state.desk.done(on: today)
        )
    }
}

/// The one message: who it is from, what they said, and — when they asked
/// something — the answers, which are exactly the buttons the decision
/// sheet and the phone thread show.
struct MorningDeskMessage {
    let counterpart: PhoneCounterpart
    let name: String
    /// The portrait seed, or `nil` for the office thread.
    let seed: UInt64?
    let text: String
    /// The day it was said, for "today"/"3d".
    let day: Int
    /// The answers, when a question is waiting. Empty when the thread is
    /// simply unread, and the paper is cleared by reading it.
    let replies: [PhoneReply]

    var isAsking: Bool { !replies.isEmpty }

    /// The thread the founder owes an answer to, or failing that the
    /// newest unread one. `nil` when the phone is quiet.
    static func waiting(in state: GameState, content: ContentCatalog) -> MorningDeskMessage? {
        let asking = PhoneReply.waitingThread(in: state, content: content)
        let counterpart = asking
            ?? state.life.phone.byRecency.first { $0.unreadCount > 0 }?.counterpart
        guard let counterpart, let thread = state.life.phone.thread(with: counterpart) else {
            return nil
        }
        let last = thread.messages.last { !$0.fromFounder } ?? thread.messages.last
        return MorningDeskMessage(
            counterpart: counterpart,
            name: state.phoneName(for: counterpart),
            seed: state.phoneSeed(for: counterpart),
            text: last?.text ?? "",
            day: last?.day ?? state.day,
            replies: PhoneReply.waiting(in: state, content: content, counterpart: counterpart)?
                .replies ?? []
        )
    }
}

// MARK: - The session's side

extension GameSession {
    /// Today, the way every desk surface asks for it.
    var deskToday: Int { DeskDay.stamp() }

    /// Today's board for the slot's game, or `nil` when there is no game
    /// behind the front door yet.
    func deskBoard(today: Int? = nil) -> MorningDeskBoard? {
        guard hasCurrentGame, engine.state.gameOver == nil else { return nil }
        return MorningDeskBoard.make(
            state: engine.state,
            content: engine.content,
            balance: engine.balance,
            today: today ?? deskToday
        )
    }

    /// Does a paper: sends the action it carries (if any), records the
    /// paper, saves the slot, and — when that was the third — moves the
    /// ledger's streak and hands back what changed.
    ///
    /// `.clearDeskCard` produces no events on purpose (it is bookkeeping,
    /// not news), so the save is asked for here rather than left to the
    /// engine's event-driven autosave.
    @discardableResult
    func deskDo(_ action: GameAction?, clearing part: DeskPart, today: Int) -> DeskStreakChange? {
        guard hasCurrentGame else { return nil }
        if let action { engine.send(action) }
        engine.send(.clearDeskCard(part: part, today: today))
        engine.autosave?(engine.state)
        guard engine.state.desk.isCleared(on: today), ledger.deskLastDay != today else { return nil }
        let change = ledger.recordDeskDay(today)
        saveLedger()
        return change
    }

    /// Marks the papers that had nothing on them, so opening a quiet desk
    /// and doing the one thing that *is* there clears the day.
    @discardableResult
    func deskMarkEmpties(_ board: MorningDeskBoard) -> DeskStreakChange? {
        var change: DeskStreakChange?
        for part in board.emptyParts {
            change = deskDo(nil, clearing: part, today: board.today) ?? change
        }
        return change
    }

    /// The streak as the door should show it: the ledger's number while it
    /// is still alive, and 0 once it has lapsed.
    var deskLiveStreak: Int {
        ledger.deskStreakIsLive(on: deskToday) ? ledger.deskStreak : 0
    }
}
