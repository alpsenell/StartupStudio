import SwiftUI
import TycoonContent
import TycoonEngine

// Iteration 12 — J6. One queue for every question: the app's half.
//
// The engine's `QueueBoard` names every open question; `DecisionPrompt`
// turns the ones answered with a button into sheets (`queueItems`, in
// `DecisionSheet.swift`), and the rail carries the rest. This file holds
// the two sheets wave two never had at the root — the string the family
// office pulled, and the partner who found the calendar — and the debug
// flags that dress a screenshot.

/// One question on the queue, with its sheet when a button answers it.
struct QueueItem: Identifiable {
    let entry: QueueEntry
    let prompt: DecisionPrompt?
    var id: String { entry.id }
}

extension DecisionPrompt {
    /// W1's string, on the same sheet as every other question. The answers
    /// and their costs are the ones `DirtyMoneyDemandSheet` prints; a
    /// refused answer stays on the sheet, greyed, with the reason.
    static func queueDemandPrompt(state: GameState, balance: BalanceConfig) -> DecisionPrompt? {
        guard let demand = state.dirtyMoney.openDemand else { return nil }
        let config = balance.dirtyMoney
        let left = demand.daysLeft(from: state.day)

        func detail(_ answer: DirtyMoneyAnswer) -> String {
            switch answer {
            case .comply:
                let heat = Int(config.complyHeatRelief.rounded())
                if demand.amount > 0 {
                    return "\(demand.amount.money) · heat −\(heat) · it goes on your record as laundering"
                }
                return "\(demand.kind.complyLabel) · heat −\(heat)"
            case .stall:
                let heat = Int(DirtyMoney.heatDelta(.stall, kind: demand.kind, balance: config).rounded())
                return demand.stalled
                    ? "You have already asked once"
                    : "\(config.stallDays) more days · heat +\(heat)"
            case .refuse:
                let heat = Int(DirtyMoney.heatDelta(.refuse, kind: demand.kind, balance: config).rounded())
                return "Free today · heat +\(heat)"
            }
        }

        let options = DirtyMoneyAnswer.allCases.map { answer in
            Option(
                label: answer == .comply ? demand.kind.complyLabel : answer.displayName,
                detail: detail(answer),
                role: answer == .refuse ? .destructive : nil,
                disabledReason: state.dirtyMoneyAnswerRefusal(answer, balance: balance)?.sentence,
                action: .answerDirtyMoneyDemand(answer)
            )
        }
        return DecisionPrompt(
            id: "demand-\(demand.id)",
            systemImage: demand.kind.symbol,
            tint: Theme.warning,
            title: demand.kind.title,
            message: demand.kind.body
                + " Say nothing and the deadline refuses for you, which they read as a refusal with worse manners.",
            stats: [
                (String(localized: "From", comment: "Decision sheet stat label: who pulled the string"),
                 state.dirtyMoney.backerKind?.displayName ?? "—"),
                (String(localized: "Answer within", comment: "Decision sheet stat label: how long is left to reply"),
                 left == 0 ? "today" : "\(left) day\(left == 1 ? "" : "s")"),
            ],
            options: options,
            kicker: String(localized: "A STRING", comment: "Bitmap kicker: the people whose money you took want something. Uppercase A-Z only")
        )
    }

    /// W2's confrontation, at the root: it used to open only inside the
    /// family room, so the clock stopped for it and the question was three
    /// screens away. It has no deadline — the partner waits up — so
    /// "Let me think" leaves it on the rail as "waiting on you".
    static func queueConfrontationPrompt(state: GameState) -> DecisionPrompt? {
        let drama = state.familyDrama
        guard drama.isConfrontationOpen else { return nil }
        let since = max(0, state.day - (drama.confrontedDay ?? state.day))
        let waited = since == 0 ? "" : " It has been \(since) day\(since == 1 ? "" : "s")."
        return DecisionPrompt(
            id: "confrontation-\(drama.confrontedDay ?? 0)",
            systemImage: "heart.slash.fill",
            tint: Theme.warning,
            title: String(localized: "They know", comment: "Decision sheet title: the partner has found out about the affair"),
            message: "The calendar is open on the kitchen table, turned to face your chair. "
                + "Nobody has sat down yet." + waited,
            stats: [
                (String(localized: "Affection", comment: "Decision sheet stat label: how the partner feels"),
                 "\(Int(state.life.family.affection.rounded()))"),
                (String(localized: "Answer", comment: "Decision sheet stat label: when the confrontation needs an answer"),
                 String(localized: "when you come home", comment: "Decision sheet stat: the confrontation has no deadline")),
            ],
            options: FamilyConfession.allCases.map { confession in
                Option(
                    label: confession.label,
                    detail: confession.detail,
                    role: confession == .leave ? .destructive : nil,
                    action: .confrontFamily(confession)
                )
            },
            kicker: String(localized: "HOME", comment: "Bitmap kicker: a question at home. Uppercase A-Z only")
        )
    }
}

// MARK: - Debug flags

/// `-autoCampus` puts the company on the campus. `-autoChild <stage>` adds
/// a child a week into that stage (`baby`, `toddler`, `school`, `teen`,
/// `grown`). `-autoStakes [eventID]` puts a founder at the top of the pay
/// band on the campus and a story with money in it in tomorrow's post
/// (`patent_troll` unless named). `-autoQueue [eventID]` raises a story and
/// the confrontation and puts both off, so the rail carries the queue.
/// Debug builds only; nothing in the game sends the seed.
@MainActor
enum QueueDebug {
    static func startIfAsked(current: @escaping () -> GameEngine, shell: GameShell) async {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        var seeds: [(kind: String, value: String)] = []
        if arguments.contains("-autoCampus") { seeds.append(("campus", "")) }
        if let stage = DebugLaunch.value(after: "-autoChild") { seeds.append(("child", stage)) }
        if arguments.contains("-autoStakes") { seeds.append(("stakes", flagValue("-autoStakes"))) }
        if arguments.contains("-autoQueue") { seeds.append(("queue", flagValue("-autoQueue"))) }
        guard !seeds.isEmpty else { return }

        // A fresh launch takes a beat to put a running game behind the root.
        try? await Task.sleep(for: .milliseconds(800))
        let engine = current()
        for seed in seeds {
            engine.send(.queueDebugSeed(kind: seed.kind, value: seed.value))
        }

        // For the next minute, put every question off the moment it arrives,
        // the way "Let me think" does, so the rail carries the whole queue
        // — `-autoQueue`'s two and whatever the calendar adds — with the
        // clock running.
        guard arguments.contains("-autoQueue") else { return }
        for _ in 0..<300 {
            try? await Task.sleep(for: .milliseconds(200))
            let engine = current()
            let prompts = DecisionPrompt.queue(
                in: engine.state, content: engine.content, balance: engine.balance
            )
            for prompt in prompts where !shell.isDeferred(prompt.id) {
                shell.postpone(prompt, engine: engine)
            }
        }
        #endif
    }

    private static func flagValue(_ flag: String) -> String {
        guard let value = DebugLaunch.value(after: flag), !value.hasPrefix("-") else { return "" }
        return value
    }
}
