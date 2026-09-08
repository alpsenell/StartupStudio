import Foundation
import TycoonEngine

// MARK: Iteration 8 — the share grid

/// A year of a company as a row of coloured squares, one per week — the
/// spoiler-free strip a result can be pasted anywhere as, with the seed
/// code after it so the reader can found the same company.
///
/// Read off the state alone: the financial ledger says whether a week
/// ended up or down, the event log says whether something bigger
/// happened in it. Both are capped, so a long run shows its last
/// fifty-two weeks and a week older than the ledger remembers is grey.
enum YearGrid {
    enum Square: Character, CaseIterable {
        /// A week that ended with more money than it started.
        case profit = "🟩"
        /// A week that ended with less.
        case loss = "🟥"
        /// A product shipped.
        case launch = "🟨"
        /// A market crashed.
        case crash = "⬛"
        /// A round closed.
        case round = "🟪"
        /// Nothing is known about the week (before the ledger's memory).
        case quiet = "⬜"

        var spoken: String {
            switch self {
            case .profit: "up"
            case .loss: "down"
            case .launch: "a launch"
            case .crash: "a crash"
            case .round: "a round"
            case .quiet: "quiet"
            }
        }
    }

    static let weeksInAYear = 52

    /// The last `weeks` weeks of the run, oldest first, ending with the
    /// week the run is in. A run younger than `weeks` shows only the
    /// weeks it has had.
    static func squares(state: GameState, weeks: Int = weeksInAYear) -> [Square] {
        let currentWeek = state.day / GameState.daysPerWeek
        let firstWeek = max(0, currentWeek - weeks + 1)
        guard currentWeek >= firstWeek else { return [] }

        var cash = [Int: Int]()
        var seen = Set<Int>()
        for entry in state.ledger.entries {
            let week = entry.day / GameState.daysPerWeek
            cash[week, default: 0] += entry.amount
            seen.insert(week)
        }
        var launches = Set<Int>()
        var crashes = Set<Int>()
        var rounds = Set<Int>()
        for event in state.eventLog {
            switch event {
            case .shipped(_, let day):
                launches.insert(day / GameState.daysPerWeek)
            case .marketCrash(_, let day):
                crashes.insert(day / GameState.daysPerWeek)
            case .investmentAccepted(_, _, _, let day):
                rounds.insert(day / GameState.daysPerWeek)
            default:
                break
            }
        }

        return (firstWeek...currentWeek).map { week in
            if crashes.contains(week) { return .crash }
            if rounds.contains(week) { return .round }
            if launches.contains(week) { return .launch }
            guard seen.contains(week) else { return .quiet }
            return (cash[week] ?? 0) >= 0 ? .profit : .loss
        }
    }

    /// The squares as one string.
    static func strip(_ squares: [Square]) -> String {
        String(squares.map(\.rawValue))
    }

    /// The strip, wrapped so a share sheet shows it as rows of thirteen —
    /// a quarter a row.
    static func wrapped(_ strip: String, perRow: Int = 13) -> String {
        let squares = Array(strip)
        guard !squares.isEmpty else { return "" }
        return stride(from: 0, to: squares.count, by: perRow)
            .map { String(squares[$0..<min($0 + perRow, squares.count)]) }
            .joined(separator: "\n")
    }

    /// The text the share sheet pastes: a title line, the strip, and the
    /// score line with the code on the end.
    ///
    /// Iteration 9 (L2): `life` appends " · Life NN" to the score line —
    /// the second number, in the one place a reader can paste. The daily
    /// and the season pass `nil`: their boards rank a company, and a life
    /// score on a 364-day sprint would be a different game's number.
    static func shareText(
        title: String, strip: String, scoreLine: String, code: String?, life: Int? = nil
    ) -> String {
        let score = life.map { "\(scoreLine) · Life \($0)" } ?? scoreLine
        var lines = [title, wrapped(strip), score]
        if let code { lines.append("Play it: \(code)") }
        return lines.joined(separator: "\n")
    }

    /// The strip read aloud: "52 weeks: 30 up, 12 down, 6 launches, …".
    static func spoken(_ strip: String) -> String {
        let squares = strip.compactMap(Square.init(rawValue:))
        guard !squares.isEmpty else { return "No weeks yet." }
        let counts = Square.allCases.compactMap { kind -> String? in
            let count = squares.filter { $0 == kind }.count
            return count > 0 ? "\(count) \(kind.spoken)" : nil
        }
        return "\(squares.count) weeks: " + counts.joined(separator: ", ") + "."
    }
}

// MARK: Iteration 10 — M4 (leagues): the challenge payload

extension YearGrid.Square {
    /// The letter this square travels as. A grid in a link or a pasted
    /// line has to survive URLs, keyboards and a copy that eats emoji,
    /// so the wire form is six ASCII letters and the squares are only
    /// ever what gets drawn.
    var letter: Character {
        switch self {
        case .profit: "U"
        case .loss: "D"
        case .launch: "L"
        case .crash: "C"
        case .round: "R"
        case .quiet: "Q"
        }
    }

    init?(letter: Character) {
        switch Character(letter.uppercased()) {
        case "U": self = .profit
        case "D": self = .loss
        case "L": self = .launch
        case "C": self = .crash
        case "R": self = .round
        case "Q": self = .quiet
        default: return nil
        }
    }
}

extension YearGrid {
    /// A strip of squares as the letters a challenge carries.
    static func letters(_ strip: String) -> String {
        String(strip.compactMap { Square(rawValue: $0)?.letter })
    }

    /// Letters back into squares. Anything unreadable is dropped, so a
    /// mangled link shows a shorter year rather than nothing.
    static func squares(fromLetters letters: String) -> [Square] {
        letters.compactMap(Square.init(letter:))
    }

    /// The strip a challenge's letters draw.
    static func strip(fromLetters letters: String) -> String {
        strip(squares(fromLetters: letters))
    }

    /// The text a *Beat my company* share pastes: the challenge line
    /// under the year, so the reader sees the shape of the year they are
    /// being asked to beat and taps the link to found it.
    static func challengeText(
        title: String, strip: String, scoreLine: String, link: String
    ) -> String {
        [title, wrapped(strip), scoreLine, "Beat it: " + link].joined(separator: "\n")
    }
}

// MARK: end of Iteration 10
