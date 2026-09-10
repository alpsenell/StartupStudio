import SwiftUI
import TycoonEngine

// MARK: J5 (announce)

/// Iteration 12 — J5. The announced date on the notice rail, through the
/// rail's existing `deferred` entry point: a deadline with a real
/// countdown, which is what a deferred question already is.
///
/// `NoticeRail.swift` is J6's this round, so the rail does not call this
/// yet. The one line that wires it — in `NoticeRail.liveQueue`, after the
/// deferred question — is:
///
///     notices.append(contentsOf: AnnounceRail.notices(state: state))
///
/// and it is a follow-up for the merge, in the lane report.
enum AnnounceRail {
    /// How close a date has to be before it takes a line on the rail. A
    /// promise three months out is not a notice; one in a fortnight is.
    static let windowDays = 14

    /// One notice per announced build inside the window, soonest first.
    /// Empty for every run that never announced.
    static func notices(state: GameState) -> [RailNotice] {
        state.announcedBuilds.compactMap { product in
            guard let left = state.announceDaysLeft(for: product), left <= windowDays else { return nil }
            return RailNotice.deferred(
                id: "announce-\(product.id.uuidString)",
                title: "\(product.name) ships \(AnnounceEventPresenter.dateLabel(product.announcedDay ?? state.day, today: state.day))",
                daysLeft: max(0, left),
                category: "press"
            )
        }
    }
}

// MARK: end J5
