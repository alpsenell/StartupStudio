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

    /// The person's id, for the four cases that name somebody.
    public var personID: UUID? {
        switch self {
        case .partner, .office: nil
        case let .child(id), let .friend(id), let .employee(id), let .contact(id): id
        }
    }

    /// A stable sort key, so two identical states list their threads in
    /// the same order however the array was built.
    public var sortKey: String {
        switch self {
        case .partner: "0"
        case .child(let id): "1\(id.uuidString)"
        case .friend(let id): "2\(id.uuidString)"
        case .employee(let id): "3\(id.uuidString)"
        case .contact(let id): "4\(id.uuidString)"
        case .office: "5"
        }
    }
}

/// What a bubble is. `said` is somebody talking; `unanswered` is the marker
/// the deadline leaves behind when the founder never replied, and it stays
/// in the thread forever.
public enum PhoneMessageKind: String, Codable, Equatable, Sendable {
    case said
    case unanswered
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
    /// A plain line, or the silence a deadline left. Absent in a save
    /// written before the marker existed, and reads as `.said`.
    public var kind: PhoneMessageKind

    public init(
        id: Int, day: Int, fromFounder: Bool, text: String,
        eventID: String? = nil, kind: PhoneMessageKind = .said
    ) {
        self.id = id
        self.day = day
        self.fromFounder = fromFounder
        self.text = text
        self.eventID = eventID
        self.kind = kind
    }

    private enum CodingKeys: String, CodingKey {
        case id, day, fromFounder, text, eventID, kind
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try container.decode(Int.self, forKey: .id),
            day: try container.decode(Int.self, forKey: .day),
            fromFounder: try container.decode(Bool.self, forKey: .fromFounder),
            text: try container.decode(String.self, forKey: .text),
            eventID: try container.decodeIfPresent(String.self, forKey: .eventID),
            kind: try container.decodeIfPresent(PhoneMessageKind.self, forKey: .kind) ?? .said
        )
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(day, forKey: .day)
        try container.encode(fromFounder, forKey: .fromFounder)
        try container.encode(text, forKey: .text)
        try container.encodeIfPresent(eventID, forKey: .eventID)
        // The ordinary bubble is the default, so it costs no bytes.
        if kind != .said { try container.encode(kind, forKey: .kind) }
    }
}

public struct PhoneThread: Codable, Equatable, Sendable, Identifiable {
    public var id: PhoneCounterpart { counterpart }
    public var counterpart: PhoneCounterpart
    public var messages: [PhoneMessage]
    /// The day the founder last opened the thread; unread = newer messages.
    public var lastReadDay: Int

    /// The most a thread keeps. Old texts scroll away on a real phone too,
    /// and this is what stops a ten-year run writing a novel into the save.
    public static let historyLimit = 60

    public init(counterpart: PhoneCounterpart, messages: [PhoneMessage] = [], lastReadDay: Int = -1) {
        self.counterpart = counterpart
        self.messages = messages
        self.lastReadDay = lastReadDay
    }

    public var unreadCount: Int {
        messages.filter { !$0.fromFounder && $0.day > lastReadDay }.count
    }

    /// The last thing anybody said here, for the card's one line.
    public var lastMessage: PhoneMessage? { messages.last }

    /// The day of the newest message, for sorting the thread list.
    public var lastDay: Int { messages.last?.day ?? -1 }
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
    ///
    /// The id is one past the last message's rather than the count, so it
    /// stays unique after a thread trims its oldest bubbles away.
    @discardableResult
    public mutating func post(
        _ text: String,
        from counterpart: PhoneCounterpart,
        day: Int,
        fromFounder: Bool = false,
        eventID: String? = nil
    ) -> PhoneMessage {
        post(
            text, from: counterpart, day: day,
            fromFounder: fromFounder, eventID: eventID, kind: .said
        )
    }

    /// The full form, with the bubble's kind. `post` above is the
    /// cross-lane API and forwards to this.
    @discardableResult
    public mutating func post(
        _ text: String,
        from counterpart: PhoneCounterpart,
        day: Int,
        fromFounder: Bool = false,
        eventID: String? = nil,
        kind: PhoneMessageKind
    ) -> PhoneMessage {
        guard let index = threads.firstIndex(where: { $0.counterpart == counterpart }) else {
            let message = PhoneMessage(
                id: 0, day: day, fromFounder: fromFounder,
                text: text, eventID: eventID, kind: kind
            )
            threads.append(PhoneThread(counterpart: counterpart, messages: [message]))
            return message
        }
        let message = PhoneMessage(
            id: (threads[index].messages.last?.id ?? -1) + 1, day: day,
            fromFounder: fromFounder, text: text, eventID: eventID, kind: kind
        )
        threads[index].messages.append(message)
        let overflow = threads[index].messages.count - PhoneThread.historyLimit
        if overflow > 0 { threads[index].messages.removeFirst(overflow) }
        return message
    }

    public func thread(with counterpart: PhoneCounterpart) -> PhoneThread? {
        threads.first { $0.counterpart == counterpart }
    }

    public var unreadCount: Int { threads.reduce(0) { $0 + $1.unreadCount } }

    /// Threads newest-first, the order the phone shows them in. Ties break
    /// on the counterpart's sort key, so the list is a pure function of
    /// the state.
    public var byRecency: [PhoneThread] {
        threads.sorted {
            $0.lastDay == $1.lastDay
                ? $0.counterpart.sortKey < $1.counterpart.sortKey
                : $0.lastDay > $1.lastDay
        }
    }

    /// Opening a thread: everything already in it counts as seen.
    public mutating func markRead(_ counterpart: PhoneCounterpart, day: Int) {
        guard let index = threads.firstIndex(where: { $0.counterpart == counterpart }) else { return }
        threads[index].lastReadDay = max(threads[index].lastReadDay, day)
    }

    /// Whether this thread is the one the pending question was asked in —
    /// which is where its answer buttons belong.
    public func isAsking(_ counterpart: PhoneCounterpart, pending: PendingChoice?) -> Bool {
        guard let pending, let thread = thread(with: counterpart) else { return false }
        return thread.messages.contains { $0.eventID == pending.id && !$0.fromFounder }
    }

    /// The thread a pending question was asked in, if it was asked on the
    /// phone at all.
    public func askingThread(for pending: PendingChoice?) -> PhoneCounterpart? {
        guard let pending else { return nil }
        return byRecency.first {
            $0.messages.contains { $0.eventID == pending.id && !$0.fromFounder }
        }?.counterpart
    }
}

// MARK: - Who a thread is with

extension GameState {
    /// The name at the top of a thread. Somebody the run no longer has (a
    /// contact the book evicted) reads as a generic label rather than an
    /// empty title.
    public func phoneName(for counterpart: PhoneCounterpart) -> String {
        switch counterpart {
        case .partner:
            life.family.partnerName ?? "Your partner"
        case .office:
            company.name
        case .child(let id):
            life.family.children.first { $0.id == id }?.name ?? "Your kid"
        case .friend(let id):
            life.friends.friends.first { $0.id == id }?.name ?? "A friend"
        case .employee(let id):
            employees.first { $0.id == id }?.name ?? "Someone at work"
        case .contact(let id):
            networking.contacts.first { $0.id == id }?.name ?? "An old colleague"
        }
    }

    /// The face for a thread, when the counterpart has one.
    public func phoneSeed(for counterpart: PhoneCounterpart) -> UInt64? {
        switch counterpart {
        case .partner:
            life.family.partnerAppearanceSeed
        case .office:
            nil
        case .child(let id):
            life.family.children.first { $0.id == id }?.appearanceSeed
        case .friend(let id):
            life.friends.friends.first { $0.id == id }?.appearanceSeed
        case .employee(let id):
            employees.first { $0.id == id }?.appearanceSeed
        case .contact(let id):
            networking.contacts.first { $0.id == id }?.appearanceSeed
        }
    }

    /// "Married", "Your kid", "Used to work here" — what this thread is,
    /// under the name.
    public func phoneRelation(for counterpart: PhoneCounterpart) -> String {
        switch counterpart {
        case .partner:
            switch life.family.stage {
            case .single: "Your ex"
            case .dating: "You're dating"
            case .partner: "Your partner"
            case .married: "Married"
            }
        case .office: "The office"
        case .child: "Your kid"
        case .friend: "A friend"
        case .employee: "On payroll"
        case .contact: "Used to work here"
        }
    }
}
