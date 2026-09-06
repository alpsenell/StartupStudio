import Foundation

// Iteration 9 — L1 owns this file. Every other lane may *post* to the phone
// through `PhoneState.post` (L3 a child's message, L4 a friend's, L5 a
// side-project beat, L6 the caretaker's daily log) and must not change its
// shape; L1 may extend it freely as long as `post` keeps its signature.

/// Who a phone thread is with. Thread identity: one thread per counterpart.
public enum PhoneCounterpart: Codable, Equatable, Hashable, Sendable {
    case partner
    case child(UUID)
    case friend(UUID)
    case employee(UUID)
    case contact(UUID)
    /// The office itself: the caretaker's log, the weekly numbers.
    case office
}

/// One bubble. `id` is the message's ordinal in its thread, so identical
/// states encode identically and nothing here draws from an RNG.
public struct PhoneMessage: Codable, Equatable, Sendable, Identifiable {
    public var id: Int
    public var day: Int
    public var fromFounder: Bool
    public var text: String
    /// The narrative event (or other source id) that produced it, if any.
    public var eventID: String?

    public init(id: Int, day: Int, fromFounder: Bool, text: String, eventID: String? = nil) {
        self.id = id
        self.day = day
        self.fromFounder = fromFounder
        self.text = text
        self.eventID = eventID
    }
}

public struct PhoneThread: Codable, Equatable, Sendable, Identifiable {
    public var id: PhoneCounterpart { counterpart }
    public var counterpart: PhoneCounterpart
    public var messages: [PhoneMessage]
    /// The day the founder last opened the thread; unread = newer messages.
    public var lastReadDay: Int

    public init(counterpart: PhoneCounterpart, messages: [PhoneMessage] = [], lastReadDay: Int = -1) {
        self.counterpart = counterpart
        self.messages = messages
        self.lastReadDay = lastReadDay
    }

    public var unreadCount: Int {
        messages.filter { !$0.fromFounder && $0.day > lastReadDay }.count
    }
}

/// The founder's phone: every thread, oldest first.
public struct PhoneState: Codable, Equatable, Sendable {
    public var threads: [PhoneThread]

    public init(threads: [PhoneThread] = []) {
        self.threads = threads
    }

    public static let empty = PhoneState()

    /// Appends a message to the counterpart's thread, creating the thread
    /// on first contact. Stable across lanes: call it, don't reshape it.
    @discardableResult
    public mutating func post(
        _ text: String,
        from counterpart: PhoneCounterpart,
        day: Int,
        fromFounder: Bool = false,
        eventID: String? = nil
    ) -> PhoneMessage {
        if let index = threads.firstIndex(where: { $0.counterpart == counterpart }) {
            let message = PhoneMessage(
                id: threads[index].messages.count, day: day,
                fromFounder: fromFounder, text: text, eventID: eventID
            )
            threads[index].messages.append(message)
            return message
        }
        let message = PhoneMessage(id: 0, day: day, fromFounder: fromFounder, text: text, eventID: eventID)
        threads.append(PhoneThread(counterpart: counterpart, messages: [message]))
        return message
    }

    public func thread(with counterpart: PhoneCounterpart) -> PhoneThread? {
        threads.first { $0.counterpart == counterpart }
    }

    public var unreadCount: Int { threads.reduce(0) { $0 + $1.unreadCount } }
}
