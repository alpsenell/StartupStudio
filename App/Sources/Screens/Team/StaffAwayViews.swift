import PixelKit
import SwiftUI
import TycoonEngine

// MARK: T6 (away)

// Iteration 17 — T6 (genre.md §3): people away from the desk. Every number
// here is read off the engine (`courseCost`, `courseBlocker`,
// `courseShipPreview`, `awayCrewLine`), so the button never promises what
// the tick will not do.

/// *Send them on a course*: beside the instant workshop, the slower answer
/// — the price now, the days away and the ship date they move, the skill on
/// the day they are back.
struct StaffCourseSection: View {
    let engine: GameEngine
    let employee: Employee

    var body: some View {
        if !employee.isFounder {
            let state = engine.state
            let config = engine.balance.away
            let cost = state.courseCost(balance: engine.balance)
            let blocker = state.courseBlocker(employeeID: employee.id, balance: engine.balance)
            Section {
                if employee.isAway(on: state.day), let until = employee.awayUntilDay {
                    Label(awayText(until: until), systemImage: "airplane.departure")
                        .font(.subheadline)
                } else {
                    ForEach(TrainableSkill.allCases, id: \.self) { skill in
                        Button {
                            engine.send(.sendOnCourse(employeeID: employee.id, skill: skill))
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Label("Send on a \(skill.displayName.lowercased()) course", systemImage: skill.systemImage)
                                Text("\(cost.money) · away \(config.courseDays) days · \(skill.displayName) +\(Int(config.courseSkillBoost)) when back")
                                    .font(.caption)
                                    .monospacedDigit()
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .disabled(blocker != nil)
                    }
                }
            } header: {
                Text("A course")
            } footer: {
                Text(footer(blocker: blocker))
                    .monospacedDigit()
            }
        }
    }

    private var firstName: String {
        employee.name.split(separator: " ").first.map(String.init) ?? employee.name
    }

    private func awayText(until: Int) -> String {
        let back = GameState.awayDateLabel(until)
        switch employee.awayReason {
        case .course(let skill): return "On a \(skill.displayName.lowercased()) course · back \(back)"
        case .holiday: return "On holiday · back \(back)"
        case nil: return "Away · back \(back)"
        }
    }

    /// What it closes later: the build they are on, and the raise their
    /// new skill will argue for.
    private func footer(blocker: String?) -> String {
        if let blocker, !employee.isAway(on: engine.state.day) { return blocker }
        var parts: [String] = []
        if let preview = engine.state.courseShipPreview(
            employeeID: employee.id, balance: engine.balance, content: engine.content
        ), preview.courseDay > preview.nowDay {
            parts.append(
                "\(preview.productName) reaches ship no later than \(GameState.awayDateLabel(preview.courseDay)) instead of \(GameState.awayDateLabel(preview.nowDay))."
            )
        } else {
            parts.append("No points, no research while they are away.")
        }
        parts.append("The skill stays; so does the fair pay it earns them — expect the raise talk.")
        return parts.joined(separator: " ")
    }
}

extension EmployeeAway {
    /// "on a coding course", "on holiday" — the feed's words.
    var awayPhrase: String {
        switch self {
        case .course(let skill): "on a \(skill.displayName.lowercased()) course"
        case .holiday: "on holiday"
        }
    }

    /// "the coding course (coding +12)", "holiday".
    var backPhrase: String {
        switch self {
        case .course(let skill): "the \(skill.displayName.lowercased()) course, \(skill.displayName.lowercased()) sharper for it"
        case .holiday: "holiday"
        }
    }
}

/// The Team row's chip: *AWAY*, with who and until when for VoiceOver.
struct AwayChip: View {
    let employee: Employee
    let day: Int

    var body: some View {
        if employee.isAway(on: day), let until = employee.awayUntilDay {
            PixelText(
                text: String(localized: "AWAY", comment: "Pixel-font chip on a Team row: this person is on a course or on holiday. Uppercase A-Z only — the bitmap font has no lowercase and no accents."),
                scale: 1, color: Theme.pixelInk
            )
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(Theme.warning.opacity(0.35), in: RoundedRectangle(cornerRadius: 3, style: .continuous))
                .accessibilityLabel(
                    employee.awayReason == .holiday
                        ? "On holiday until \(GameState.awayDateLabel(until - 1))"
                        : "On a course until \(GameState.awayDateLabel(until - 1))"
                )
        }
    }
}

// MARK: end T6
