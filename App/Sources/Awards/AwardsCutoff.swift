import SwiftUI
import TycoonEngine

// MARK: G8 (awards night, attended)

/// Iteration 18 — G8. The date December bends around.
///
/// The ceremony has been held on day 350 of every year since iteration 8
/// (`AwardsJudge.ceremonyDay`), and until now it was invisible until it
/// had passed. From `awards.cutoffNoticeDays` before it, the Now card and
/// the ship sheet say how long is left — so *ship at 76 for the window or
/// polish to 80 and miss it* is a question with a date on it.
///
/// Pure arithmetic over the day and the balance. Nothing here writes
/// state, and outside the window every entry point returns `nil`, so a
/// card in January reads exactly as it read before this lane.
enum AwardsCutoff {
    /// Days until this year's ceremony while the notice window is open and
    /// the night has not been answered: 0 on the day, `nil` otherwise.
    static func daysLeft(state: GameState, balance: BalanceConfig) -> Int? {
        let year = AwardsJudge.year(of: state.day)
        let ceremony = AwardsJudge.ceremonyDay(year: year)
        let notice = max(0, balance.awards.cutoffNoticeDays)
        guard state.day <= ceremony, state.day >= ceremony - notice else { return nil }
        // A night already answered is over, whatever the calendar says.
        guard state.ceremony(year: year) == nil else { return nil }
        return ceremony - state.day
    }

    /// This year's ceremony day.
    static func day(state: GameState) -> Int {
        AwardsJudge.ceremonyDay(year: AwardsJudge.year(of: state.day))
    }

    /// "Awards cutoff in 9 days" — the headline both surfaces use.
    static func headline(daysLeft: Int) -> String {
        switch daysLeft {
        case 0: return String(localized: "The awards are tonight", comment: "Awards cutoff countdown on the day of the ceremony")
        case 1: return String(localized: "Awards cutoff tomorrow", comment: "Awards cutoff countdown with one day left")
        default: return String(localized: "Awards cutoff in \(daysLeft) days", comment: "Awards cutoff countdown, more than a day out")
        }
    }

    /// The sentence under it: what the cutoff is for.
    static let explanation = String(
        localized: "Anything shipped after it is judged next year instead.",
        comment: "What the awards cutoff means, under the countdown"
    )
}

/// The cutoff on the Now card, beside T5's expo countdown. Renders nothing
/// outside the notice window — which is 28 of 364 days — so the card reads
/// as it did for eleven months of every year.
struct AwardsCutoffRow: View {
    let engine: GameEngine

    var body: some View {
        if let left = AwardsCutoff.daysLeft(state: engine.state, balance: engine.balance) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                HStack(alignment: .firstTextBaseline) {
                    Label(AwardsCutoff.headline(daysLeft: left), systemImage: "trophy.fill")
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    Spacer(minLength: Theme.Spacing.sm)
                    // The same slot as T5's expo countdown, so the same
                    // grammar: "July 1", not "W50 · Y2".
                    Text(AnnounceEventPresenter.dateLabel(
                        AwardsCutoff.day(state: engine.state), today: engine.state.day
                    ))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(AwardsCutoff.explanation)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
        }
    }
}

// MARK: end G8
