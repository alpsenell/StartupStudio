import SwiftUI
import TycoonContent
import TycoonEngine

// MARK: Iteration 12 — J1 (doors)

/// Every word the four doors say: the letter, who it is from, each
/// answer and what it costs, what happened after, and the journal line.
/// Dark, not cruel; the consequence is always on the button.
enum DoorCopy {

    // MARK: - The door itself

    static func title(_ kind: DoorKind) -> String {
        switch kind {
        case .shark: "The shark"
        case .vices: "The launch party"
        case .fame: "On the record"
        case .care: "The care bill"
        }
    }

    static func icon(_ kind: DoorKind) -> String {
        switch kind {
        case .shark: "phone.fill"
        case .vices: "wineglass.fill"
        case .fame: "quote.bubble.fill"
        case .care: "cross.case.fill"
        }
    }

    /// The narrative category each door files under, so the rail's
    /// deferred row picks its icon and tint the way a story beat does.
    static func category(_ kind: DoorKind) -> String {
        switch kind {
        case .shark: EventCategory.money.rawValue
        case .vices: EventCategory.personal.rawValue
        case .fame: EventCategory.press.rawValue
        case .care: EventCategory.family.rawValue
        }
    }

    static func tint(_ kind: DoorKind) -> Color {
        EventPresenter.tint(forCategory: category(kind))
    }

    /// The one-line version, for the rail and the card.
    static func railTitle(_ kind: DoorKind) -> String {
        switch kind {
        case .shark: "Denny wants twenty minutes"
        case .vices: "Somebody from the launch party"
        case .fame: "A journalist wants your take"
        case .care: "The home wants a number"
        }
    }

    /// Where a yes leads.
    static func destination(_ kind: DoorKind) -> Route {
        switch kind {
        case .shark: .dirtyMoney
        case .vices: .assets
        case .fame: .feed
        case .care: .family
        }
    }

    static func sender(_ kind: DoorKind, record: DoorRecord?, state: GameState, content: ContentCatalog) -> String {
        switch kind {
        case .shark: return "Denny · you met at demo day, apparently"
        case .vices: return "A napkin in your coat pocket"
        case .fame: return "A journalist at The Ledger"
        case .care:
            let about = careName(record, state: state, content: content)
            if state.life.family.stage != .single, let partner = state.life.family.partnerName {
                return "\(partner) · about \(about)"
            }
            return "The home · about \(about)"
        }
    }

    @MainActor
    static func letter(_ kind: DoorKind, record: DoorRecord?, engine: GameEngine) -> String {
        let state = engine.state
        switch kind {
        case .shark:
            let burn = DoorRules.weeklyBurn(state, engine.balance)
            let weeks = state.company.cash < 0 || burn <= 0 ? 0 : state.company.cash / burn
            let runway = weeks == 0 ? "none" : "\(weeks) week\(weeks == 1 ? "" : "s")"
            return "He knows the runway to the week — \(runway) — which nobody outside the building "
                + "does. He has a cheque, and a way of saying \"flexible\" that makes it sound like "
                + "weather. Twenty minutes, he says. You'll want them."
        case .vices:
            return "Twenty-one of the last twenty-eight nights ended late. Somebody at the launch "
                + "party noticed, and has something that helps with that. It is small, and it is "
                + "already in your coat."
        case .fame:
            return "They liked the launch. They want your take — two paragraphs, on the record, by "
                + "Friday. After that you are a person people have opinions about."
        case .care:
            let name = careName(record, state: state, content: engine.content)
            let age = careAge(record, state: state, content: engine.content)
            let sibling = siblingName(state: state, content: engine.content)
            return "\(name)\(age.map { ", \($0)," } ?? "") had a fall. It's not serious. The home "
                + "wants a number by Friday, and \(sibling) has already said this month is difficult."
        }
    }

    // MARK: - The answers

    static func label(_ choice: DoorChoice, kind: DoorKind, state: GameState, content: ContentCatalog) -> String {
        switch (kind, choice) {
        case (.shark, .accept): "Take the meeting"
        case (.shark, _): "Let it ring"
        case (.vices, .accept): "Say yes"
        case (.vices, _): "Go home"
        case (.fame, .accept): "Give them a quote"
        case (.fame, _): "No comment"
        case (.care, .careHome): "Pay for the home"
        case (.care, .careSpareRoom): "Give them the spare room"
        case (.care, .careSibling): "Leave it to \(siblingName(state: state, content: content))"
        case (.care, _): "Not now"
        }
    }

    /// What the answer does, printed under it (rule 7).
    @MainActor
    static func consequence(_ choice: DoorChoice, kind: DoorKind, engine: GameEngine) -> String {
        switch (kind, choice) {
        case (.shark, .accept):
            return "His offer goes on the table in Finances. Nothing is signed yet."
        case (.shark, _):
            return "He doesn't call twice. Finances stays quiet."
        case (.vices, .accept):
            if let vice = engine.balance.assets.vices.max(by: { $0.perLaunch < $1.perLaunch }) {
                return "Opens Assets · \(vice.name.lowercased()) +\(Int(vice.perLaunch.rounded())) · the habits start counting"
            }
            return "Opens Assets · the habits start counting"
        case (.vices, _):
            return "Nothing happens. That is the point."
        case (.fame, .accept):
            return "+\(DoorRules.fameFollowers) followers · opens the feed with your first post drafted"
        case (.fame, _):
            return "The piece runs without you. The feed stays empty."
        case (.care, .careHome):
            return "Wallet −\(engine.balance.familyDrama.careWeeklyBill.money) a week · opens the family room"
        case (.care, .careSpareRoom):
            return "One evening a week, every week · no bill · opens the family room"
        case (.care, .careSibling):
            let sibling = siblingName(state: engine.state, content: engine.content)
            return "\(sibling)'s bond \(Int(DoorRules.careSiblingBond)) · no bill · opens the family room"
        case (.care, _):
            return "The home sorts something out. The family room stays shut."
        }
    }

    /// What happened, once the door has closed.
    @MainActor
    static func outcome(_ record: DoorRecord, engine: GameEngine) -> String {
        let state = engine.state
        let when = GameCalendar(day: record.answeredDay ?? record.respondByDay).longLabel
        switch record.answer {
        case .lapsed, nil:
            return "Nobody answered. On \(when) the deadline said no for you, and the room went back to sleep."
        case .decline:
            return "You said no on \(when). The room stays shut."
        case .accept:
            let after = switch record.kind {
            case .shark: "His offer is in Finances."
            case .vices: "The habits are counting, under Assets."
            case .fame: "The feed is yours now. So are the replies."
            case .care: ""
            }
            return "You said yes on \(when). \(after)"
        case .careHome:
            return "You pay the home, on Fridays, from the wallet. They send a photo sometimes."
        case .careSpareRoom:
            return "They have the spare room. One evening a week is theirs now."
        case .careSibling:
            return "\(siblingName(state: state, content: engine.content)) is doing it. "
                + "They have mentioned it twice."
        }
    }

    // MARK: - The journal

    /// The journal's line for a door event (`EventCopy`'s J1 region).
    static func journal(
        for event: GameEvent, state: GameState, content: ContentCatalog
    ) -> (icon: String, message: String, day: Int, tint: Color)? {
        switch event {
        case let .doorOpened(raw, respondByDay, day):
            guard let kind = DoorKind(rawValue: raw) else { return nil }
            let left = max(0, respondByDay - day)
            return (icon(kind), "\(railTitle(kind)) — \(left) days to answer", day, tint(kind))
        case let .doorAnswered(raw, choiceRaw, day):
            guard let kind = DoorKind(rawValue: raw), let choice = DoorChoice(rawValue: choiceRaw)
            else { return nil }
            let message: String = switch choice {
            case .lapsed: "\(title(kind)): nobody answered, so no"
            case .decline: "\(title(kind)): you said no"
            default: "\(title(kind)): \(label(choice, kind: kind, state: state, content: content).lowercased())"
            }
            return (
                choice.opens ? "door.left.hand.open" : "door.left.hand.closed",
                message, day, choice.opens ? tint(kind) : Color.secondary
            )
        default:
            return nil
        }
    }

    // MARK: - The family

    private static func careRelation(_ record: DoorRecord?) -> FamilyRelation {
        record?.subject.flatMap(FamilyRelation.init(rawValue:)) ?? .mother
    }

    static func careName(_ record: DoorRecord?, state: GameState, content: ContentCatalog) -> String {
        firstName(state.familyRelativeName(careRelation(record), content: content))
    }

    private static func careAge(_ record: DoorRecord?, state: GameState, content: ContentCatalog) -> Int? {
        let relation = careRelation(record)
        return state.familyRelatives(names: content.names).first { $0.relation == relation }?.age
    }

    static func siblingName(state: GameState, content: ContentCatalog) -> String {
        firstName(state.familyRelativeName(.sibling, content: content))
    }

    private static func firstName(_ full: String) -> String {
        full.split(separator: " ").first.map(String.init) ?? full
    }
}
