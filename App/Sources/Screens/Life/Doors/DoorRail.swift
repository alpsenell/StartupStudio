import Foundation
import TycoonEngine

// MARK: Iteration 12 — J1 (doors)

/// What each open door wants on the notice rail: a `.deferred` notice
/// (priority 2), with its real countdown, built through the rail's own
/// `RailNotice.deferred(id:title:daysLeft:category:)` entry point.
///
/// `NoticeRail` builds its queue privately and is J6's file, so this is
/// the half J1 can ship: the hookup is one line in the rail's
/// `liveQueue` (`notices.append(contentsOf: DoorRail.notices(for: state))`)
/// and one in the deferred row's *Answer* (`DoorRail.route(forNoticeID:)`
/// to `onRoute`). Until then a door reaches the player as a phone message,
/// a journal line and toast, its coach tip, and the Life tab's card.
enum DoorRail {
    static let idPrefix = "door-"

    static func notices(for state: GameState) -> [RailNotice] {
        state.doors.open(on: state.day).map { record in
            .deferred(
                id: idPrefix + record.kind.rawValue,
                title: DoorCopy.railTitle(record.kind),
                daysLeft: record.daysLeft(on: state.day),
                category: DoorCopy.category(record.kind)
            )
        }
    }

    /// The open door whose rail line reads `title`, or `nil`. The deferred
    /// row is handed the title, not the notice id, so this is how its
    /// *Answer* finds the door without the row changing shape.
    static func route(forTitle title: String, state: GameState) -> Route? {
        state.doors.open(on: state.day)
            .first { DoorCopy.railTitle($0.kind) == title }
            .map { .door($0.kind) }
    }

    /// The door behind a rail notice id (`"deferred-door-shark"`), or `nil`
    /// for a notice that is not a door.
    static func route(forNoticeID id: String) -> Route? {
        let prefix = "deferred-" + idPrefix
        guard id.hasPrefix(prefix), let kind = DoorKind(rawValue: String(id.dropFirst(prefix.count)))
        else { return nil }
        return .door(kind)
    }
}
