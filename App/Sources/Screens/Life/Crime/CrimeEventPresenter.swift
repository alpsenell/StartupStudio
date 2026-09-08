import SwiftUI
import TycoonContent
import TycoonEngine

/// Iteration 11 — N1. The journal, feed and newspaper lines for the
/// lane's own events.
///
/// `EventCopy`'s big switch is a shared file with no region of mine in it,
/// so the lane's copy lives here and `EventPresenter` calls it from its
/// own N1 region — one line there, all the words here. That also means
/// the newspaper's lead, which is picked by severity and printed from the
/// journal line, gets a real sentence rather than "Something happened".
enum CrimeEventPresenter {
    static func describe(
        _ event: GameEvent,
        state: GameState,
        content: ContentCatalog
    ) -> EventLine? {
        switch event {
        case let .crimeCommitted(offence, gain, notoriety, day):
            let name = CrimeOffence(rawValue: offence)?.displayName ?? "Something"
            return EventLine(
                icon: CrimeOffence(rawValue: offence)?.symbol ?? "questionmark",
                message: gain > 0
                    ? "\(name): \(gain.money) of it, and notoriety at \(Int(notoriety.rounded()))"
                    : "\(name) — and nothing to show for it",
                day: day,
                tint: Theme.warning
            )

        case let .crimeCaseRaised(offence, accuser, hearingDay, day):
            let charge = CrimeOffence(rawValue: offence)?.chargeName ?? "the matter"
            return EventLine(
                icon: "building.columns.fill",
                message: "\(accuser) has brought a charge of \(charge) — heard \(GameState.dateLabel(forDay: hearingDay))",
                day: day,
                tint: Theme.negativeCash
            )

        case let .crimeConfessed(offence, day):
            let charge = CrimeOffence(rawValue: offence)?.chargeName ?? "it"
            return EventLine(
                icon: "figure.walk.motion",
                message: "You told them about the \(charge) before they found it",
                day: day,
                tint: Theme.warning
            )

        case let .crimeHearingDue(offence, isFounderSuing, day):
            let charge = CrimeOffence(rawValue: offence)?.chargeName ?? "the matter"
            return EventLine(
                icon: "clock.badge.exclamationmark",
                message: isFounderSuing
                    ? "Your suit is called this morning"
                    : "The \(charge) hearing is this morning",
                day: day,
                tint: Theme.negativeCash
            )

        case let .crimeHearingOpened(_, day):
            return EventLine(
                icon: "figure.stand",
                message: "You stood up in court",
                day: day,
                tint: Theme.accent
            )

        case let .crimeSettled(amount, day):
            return EventLine(
                icon: "banknote.fill",
                message: "Settled for \(amount.money). Nobody admitted anything and nobody may say so",
                day: day,
                tint: Theme.negativeCash
            )

        case let .crimeLawyerHired(tier, fee, day):
            let name = CrimeLawyer(rawValue: tier)?.displayName ?? "A lawyer"
            return EventLine(
                icon: "person.text.rectangle.fill",
                message: fee > 0
                    ? "Retained \(name.lowercasedFirstLetter) for \(fee.money) of your own money"
                    : "You are being represented by the duty solicitor",
                day: day,
                tint: Color.secondary
            )

        case let .crimeVerdict(offence, verdict, penalty, weeks, day):
            let charge = CrimeOffence(rawValue: offence)?.chargeName ?? "the charge"
            let message: String = switch CrimeVerdict(rawValue: verdict) {
            case .acquitted: "Acquitted of \(charge)"
            case .fine: "Guilty of \(charge) — fined \(penalty.money)"
            case .settlement: "\(charge.capitalizedFirstLetter): settled at the door for \(penalty.money)"
            case .sentence: "Guilty of \(charge) — \(weeks) weeks, custodial"
            case nil: "The court dealt with it"
            }
            return EventLine(
                icon: "gavel.fill",
                message: message,
                day: day,
                tint: CrimeVerdict(rawValue: verdict)?.isGood == true
                    ? Theme.positiveCash : Theme.negativeCash
            )

        case let .crimeReleased(day):
            return EventLine(
                icon: "door.left.hand.open",
                message: "You are out, and the company is somebody else's habit now",
                day: day,
                tint: Theme.accent
            )

        case let .crimeFavourCalled(what, day):
            return EventLine(icon: "envelope.badge.fill", message: what, day: day, tint: Theme.warning)

        case let .crimeDemoCollapsed(productID, liveBugs, day):
            let name = state.product(id: productID)?.name ?? "the launch"
            return EventLine(
                icon: "play.slash.fill",
                message: "\(name) shipped without the bit from the video — \(liveBugs) live bugs and counting",
                day: day,
                tint: Theme.negativeCash
            )

        case let .crimeNDAPoach(name, landed, day):
            return EventLine(
                icon: "person.badge.shield.checkmark.fill",
                message: landed
                    ? "\(name) is on your hiring desk, non-compete and all"
                    : "\(name) said no, and kept the email",
                day: day,
                tint: landed ? Theme.warning : Color.secondary
            )

        case let .crimeSuitFiled(rivalID, hearingDay, day):
            let name = state.rivals.rival(id: rivalID)?.name ?? "a studio"
            return EventLine(
                icon: "doc.text.magnifyingglass",
                message: "You filed against \(name) — heard \(GameState.dateLabel(forDay: hearingDay))",
                day: day,
                tint: Theme.accent
            )

        case let .crimeSuitResolved(won, damages, productTaken, day):
            let taken = productTaken.isEmpty ? "" : ", and \(productTaken) is off their shelf"
            return EventLine(
                icon: won ? "checkmark.seal.fill" : "xmark.seal.fill",
                message: won
                    ? "You won: \(damages.money) in damages\(taken)"
                    : "Your suit failed, and the filing fee went with it",
                day: day,
                tint: won ? Theme.positiveCash : Theme.negativeCash
            )

        default:
            return nil
        }
    }
}

extension String {
    /// "High-street firm" → "high-street firm", so it reads inside a
    /// sentence.
    var lowercasedFirstLetter: String {
        guard let first else { return self }
        return first.lowercased() + dropFirst()
    }
}
