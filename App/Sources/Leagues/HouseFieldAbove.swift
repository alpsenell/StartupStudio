import SwiftUI
import TycoonEngine

// MARK: J4 (house field)

/// Who finished directly above the player, and how they play — the one
/// line the league and daily result cards add, so the next rung is a way
/// of playing with a number on it rather than a blank.
enum HouseFieldAbove: Equatable {
    /// The player topped the table.
    case nobody(fieldSize: Int)
    /// The row directly above: their name, how they play (house founders
    /// only; `nil` for a real player), and by how much.
    case rival(name: String, line: String?, gap: Int, place: Int, fieldSize: Int)

    /// Read off a sorted table with the player's row in it; `nil` when the
    /// player is not in it or has nobody to compare with.
    static func make(standings: [LeagueStanding], lines: [String: String]) -> HouseFieldAbove? {
        guard standings.count > 1, let index = standings.firstIndex(where: \.isYou) else { return nil }
        guard index > 0 else { return .nobody(fieldSize: standings.count) }
        let row = standings[index - 1]
        return .rival(
            name: row.name, line: lines[row.name], gap: row.score - standings[index].score,
            place: index + 1, fieldSize: standings.count
        )
    }

    /// "Directly above you: Dale Pruitt. You came 10th of 20."
    var heading: String {
        switch self {
        case .nobody(let size):
            "Nobody finished above you. \(LeagueTable.placeText(rank: 1, fieldSize: size))."
        case .rival(let name, _, _, let place, let size):
            "Directly above you: \(name). You came \(LeagueTable.placeText(rank: place, fieldSize: size))."
        }
    }

    /// "Grinder — contracts only, never hired — finished $38,000 ahead."
    var sentence: String? {
        guard case .rival(_, let line, let gap, _, _) = self else { return nil }
        let ahead = gap > 0 ? "finished \(gap.money) ahead" : "finished level with you"
        guard let line else { return "They \(ahead)." }
        return "\(line) — \(ahead)."
    }
}

/// The line itself, as both result cards draw it.
struct HouseFieldAboveLine: View {
    let above: HouseFieldAbove

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.sm) {
            Image(systemName: above.sentence == nil ? "crown" : "arrow.up.circle")
                .font(.subheadline)
                .foregroundStyle(Theme.accent)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(above.heading)
                    .font(.system(.caption, design: .rounded).weight(.semibold))
                    .foregroundStyle(Theme.pixelInk)
                if let sentence = above.sentence {
                    Text(sentence)
                        .font(.caption)
                        .foregroundStyle(Theme.pixelInk.opacity(0.8))
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: end J4
