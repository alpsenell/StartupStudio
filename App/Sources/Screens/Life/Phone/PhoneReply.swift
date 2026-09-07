import SwiftUI
import TycoonContent
import TycoonEngine

// MARK: Iteration 9 — L1 (the phone)

/// One answer the founder can send from inside a thread.
///
/// Two things ask the founder questions and both of them text: a narrative
/// beat (`narrative.pendingChoice`, answered with `resolveChoice`) and
/// somebody on the team (`pendingStaffEvent`, answered with
/// `resolveStaffEvent`). The thread does not care which; it wants a label,
/// a consequence, and an action. The engine is still the authority —
/// these are exactly the actions the decision sheet sends, so answering
/// from the phone and answering from the sheet are the same move.
struct PhoneReply: Identifiable {
    let id: String
    let label: String
    /// The consequence under the label — the game's rule that every
    /// button says what it costs.
    let detail: String?
    /// Why it cannot be sent, if it cannot.
    let disabledReason: String?
    /// The firm answer, drawn the way the decision sheet draws it: the two
    /// buttons are not the same button.
    var isFirm = false
    let action: GameAction

    var isEnabled: Bool { disabledReason == nil }

    /// The whole question: its answers and the day silence takes over.
    struct Set {
        let replies: [PhoneReply]
        let respondByDay: Int
    }

    /// The thread that is waiting on the founder right now, if one is.
    static func waitingThread(
        in state: GameState,
        content: ContentCatalog
    ) -> PhoneCounterpart? {
        state.life.phone.byRecency
            .map(\.counterpart)
            .first { waiting(in: state, content: content, counterpart: $0) != nil }
    }

    /// Whether this thread is waiting on an answer.
    static func isWaiting(
        _ counterpart: PhoneCounterpart,
        in state: GameState,
        content: ContentCatalog
    ) -> Bool {
        waiting(in: state, content: content, counterpart: counterpart) != nil
    }

    /// What `counterpart`'s thread is waiting on, if anything.
    static func waiting(
        in state: GameState,
        content: ContentCatalog,
        counterpart: PhoneCounterpart
    ) -> Set? {
        if let narrative = narrativeReplies(in: state, counterpart: counterpart) {
            return narrative
        }
        return staffReplies(in: state, content: content, counterpart: counterpart)
    }

    // MARK: A story beat

    private static func narrativeReplies(
        in state: GameState,
        counterpart: PhoneCounterpart
    ) -> Set? {
        guard let pending = state.narrative.pendingChoice,
              state.life.phone.isAsking(counterpart, pending: pending)
        else { return nil }
        return Set(
            replies: pending.options.map { option in
                PhoneReply(
                    id: "\(pending.id)-\(option.index)",
                    label: option.label,
                    detail: option.detail,
                    disabledReason: option.disabledReason,
                    action: .resolveChoice(eventID: pending.id, optionIndex: option.index)
                )
            },
            respondByDay: pending.respondByDay
        )
    }

    // MARK: Somebody on the team

    /// The staff moment's two (or three) answers, with the def's own
    /// labels and details so the thread and the sheet say the same thing.
    private static func staffReplies(
        in state: GameState,
        content: ContentCatalog,
        counterpart: PhoneCounterpart
    ) -> Set? {
        guard case .employee(let employeeID) = counterpart,
              let event = state.pendingStaffEvent, event.employeeID == employeeID,
              let employee = state.employee(id: employeeID)
        else { return nil }
        let def = content.staffEvent(event.definitionID)

        func fill(_ text: String) -> String {
            text
                .replacingOccurrences(of: "{name}", with: employee.name)
                .replacingOccurrences(of: "{company}", with: state.company.name)
        }

        var replies: [PhoneReply] = [
            PhoneReply(
                id: "staff-supportive",
                label: def?.supportive?.label ?? "Be supportive",
                detail: (def?.supportive?.detail).map(fill) ?? "Loyalty way up",
                disabledReason: nil,
                action: .resolveStaffEvent(choice: .supportive)
            ),
            PhoneReply(
                id: "staff-strict",
                label: def?.strict.label ?? "Business first",
                detail: (def?.strict.detail).map(fill) ?? "Free, but loyalty takes a hit",
                disabledReason: nil,
                isFirm: true,
                action: .resolveStaffEvent(choice: .strict)
            ),
        ]
        // A rolled kind with a policy block can become the rule; a second
        // act never can, and neither can a kind that already has one.
        if event.defID == nil, state.staffMemory.policy(for: event.kind) == nil,
           let policy = def?.policy {
            replies.append(PhoneReply(
                id: "staff-policy",
                label: "…and make that the rule",
                detail: "\(policy.name): the same answer for everyone who asks",
                disabledReason: nil,
                isFirm: true,
                action: .resolveStaffEvent(choice: .strictAsPolicy)
            ))
        }
        return Set(replies: replies, respondByDay: event.respondByDay)
    }
}
