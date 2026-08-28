import SwiftUI
import TycoonContent
import TycoonEngine

/// Which part of the run an event belongs to. Drives the journal's filter
/// chips and the toast tint.
enum JournalCategory: String, CaseIterable, Identifiable, Sendable {
    case company, life, team, market, rivals

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .company: "Company"
        case .life: "Life"
        case .team: "Team"
        case .market: "Market"
        case .rivals: "Rivals"
        }
    }

    var systemImage: String {
        switch self {
        case .company: "building.2.fill"
        case .life: "heart.fill"
        case .team: "person.2.fill"
        case .market: "chart.line.uptrend.xyaxis"
        case .rivals: "flag.fill"
        }
    }
}

/// The single place a `GameEvent` becomes English.
///
/// Every surface that shows an event — the journal, the toasts, the pause
/// banner, the weekly report — asks this type, so one event reads the same
/// everywhere and a new case only has to be written once. Cases added by
/// another workstream fall through to `EventPresenter`, which WS-B owns.
struct EventCopy {
    let state: GameState
    let content: ContentCatalog
    let balance: BalanceConfig

    /// The rendered line for `event`.
    func line(for event: GameEvent) -> EventLine {
        let parts = entry(for: event)
        return EventLine(icon: parts.icon, message: parts.message, day: parts.day, tint: parts.tint)
    }

    /// Which journal bucket the event belongs in.
    func category(of event: GameEvent) -> JournalCategory {
        switch event {
        case .lifeEvent, .founderAway, .founderBack, .relationshipChanged, .breakup,
             .childBorn, .homeUpgraded, .weekendSpent, .instantActivityDone, .itemPurchased:
            .life
        case .hired, .fired, .candidatesRefreshed, .employeeQuit, .employeePromoted,
             .employeeDemoted, .salaryChanged, .employeeTrained, .socialActivity,
             .friendshipFormed, .friendLostMorale, .staffBirthday, .staffEventOccurred,
             .staffEventResolved:
            .team
        case .marketBoom, .marketCrash:
            .market
        case .rivalFounded, .rivalShipped, .rivalFolded, .poachAttempt, .poachDefeated,
             .employeePoached, .buyoutOffered, .buyoutWithdrawn, .companySold, .rivalAcquired:
            .rivals
        default:
            .company
        }
    }

    private func entry(for event: GameEvent) -> (icon: String, message: String, day: Int, tint: Color) {
        switch event {
        case .bankruptcyWarning(let day):
            ("exclamationmark.triangle.fill", "Bankruptcy warning — cash has run dry", day, Theme.warning)
        case .gameOver(let day):
            ("xmark.octagon.fill", "The company went bankrupt", day, Theme.negativeCash)
        case .productStarted(let productID, let day):
            ("hammer.fill", "Started building \(productName(productID))", day, Theme.accent)
        case .shipped(let productID, let day):
            ("shippingbox.fill", "Shipped \(productName(productID))!", day, Theme.positiveCash)
        case .reviewsIn(let productID, let averageScore, let day):
            (
                "star.fill",
                "Reviews are in for \(productName(productID)): \(averageScore)",
                day,
                Theme.scoreTint(averageScore)
            )
        case .productOffMarket(let productID, let day):
            ("archivebox.fill", "\(productName(productID)) left the market", day, Color.secondary)
        case .hired(let employeeID, let day):
            ("person.badge.plus", "Hired \(employeeName(employeeID))", day, Theme.positiveCash)
        case .fired(let employeeID, let day):
            ("person.badge.minus", "\(employeeName(employeeID, fallback: "Someone")) left the company", day, Color.secondary)
        case .candidatesRefreshed(let day):
            ("person.2.wave.2", "New candidates are looking for work", day, Theme.accent)
        case .researchStarted(let nodeID, let day):
            ("flask", "Research started: \(techName(nodeID))", day, Theme.accent)
        case .researchCompleted(let nodeID, let day):
            ("flask.fill", "Research complete: \(techName(nodeID))!", day, Theme.positiveCash)
        case .contractAccepted(let contractID, let day):
            ("briefcase", "Signed a contract with \(clientName(contractID))", day, Theme.accent)
        case .contractCompleted(let contractID, let payout, let day):
            ("briefcase.fill", "Delivered for \(clientName(contractID)): +\(payout.money)", day, Theme.positiveCash)
        case .contractFailed(let contractID, let penalty, let day):
            ("exclamationmark.triangle.fill", "Blew the \(clientName(contractID)) deadline: −\(penalty.money)", day, Theme.warning)
        case .campaignStarted(_, let day):
            ("megaphone.fill", "Marketing campaign launched", day, Theme.accent)
        case .contractOffersRefreshed(let day):
            ("phone.fill", "New clients are asking around", day, Theme.accent)
        case .officeUpgraded(let tier, let day):
            ("building.2.fill", "Moved into the \(tier.displayName)!", day, Theme.positiveCash)
        case .amenityBuilt(let amenity, let day):
            (amenity.systemImage, "Opened the \(amenity.displayName)!", day, Theme.positiveCash)
        case .departmentFormed(let department, let day):
            (department.systemImage, "\(department.displayName) department formed", day, Theme.positiveCash)
        case .departmentDissolved(let department, let day):
            (department.systemImage, "\(department.displayName) department has no staff", day, Theme.warning)
        case .randomEvent(let eventID, let day):
            ("sparkles", eventHeadline(eventID), day, Theme.accent)
        case .lifeEvent(let eventID, let day):
            ("heart.text.square.fill", lifeEventHeadline(eventID), day, Theme.accent)
        case .founderAway(let reason, let untilDay, let day):
            (
                "person.crop.circle.badge.exclamationmark",
                "Founder out: \(reason) until day \(untilDay)",
                day,
                Theme.warning
            )
        case .founderBack(let day):
            ("person.crop.circle.badge.checkmark", "Founder is back at the office", day, Theme.positiveCash)
        case .relationshipChanged(let stage, let day):
            ("heart.fill", relationshipMessage(stage), day, Theme.positiveCash)
        case .breakup(let day):
            ("heart.slash.fill", "It's over — you're single again", day, Theme.negativeCash)
        case .childBorn(let name, let day):
            ("sparkles", "Welcome, \(name)!", day, Theme.positiveCash)
        case .homeUpgraded(let tier, let day):
            ("house.fill", "Moved into the \(tier.displayName.lowercased())!", day, Theme.positiveCash)
        case .weekendSpent(let activity, let day):
            (activity.systemImage, "Weekend: \(activity.displayName)", day, Color.secondary.opacity(0.6))
        case .marketBoom(let topicID, let day):
            ("chart.line.uptrend.xyaxis", "\(topicName(topicID)) market is booming!", day, Theme.positiveCash)
        case .marketCrash(let topicID, let day):
            ("chart.line.downtrend.xyaxis", "\(topicName(topicID)) market crashed", day, Theme.negativeCash)
        case .employeeQuit(_, let name, let day):
            ("figure.walk.departure", "\(name) quit — morale hit rock bottom", day, Theme.negativeCash)
        case .employeePromoted(let employeeID, let level, let day):
            ("arrow.up.circle.fill", "\(employeeName(employeeID)) promoted to \(level.displayName)", day, Theme.positiveCash)
        case .employeeDemoted(let employeeID, let level, let day):
            ("arrow.down.circle.fill", "\(employeeName(employeeID)) demoted to \(level.displayName)", day, Theme.warning)
        case .salaryChanged(let employeeID, let weeklySalary, let day):
            ("dollarsign.arrow.circlepath", "\(employeeName(employeeID)) now earns \(weeklySalary.money)/wk", day, Theme.accent)
        case .employeeTrained(let employeeID, let day):
            ("book.fill", "\(employeeName(employeeID)) finished a training course", day, Theme.accent)
        case .contractDelivered(let contractID, let quality, let payout, let day):
            (
                "briefcase.fill",
                quality >= 80
                    ? "Delivered for \(clientName(contractID)): +\(payout.money) — client delighted"
                    : quality >= 60
                        ? "Delivered for \(clientName(contractID)): +\(payout.money) — client had notes"
                        : "Client rejected the quality: only +\(payout.money) paid",
                day,
                Theme.scoreTint(quality)
            )
        case .loanTaken(let amount, let day):
            ("banknote.fill", "Took a \(amount.money) loan", day, Theme.warning)
        case .loanRepaid(let amount, let day):
            ("banknote", "Repaid \(amount.money) of the loan", day, Theme.positiveCash)
        case .rivalFounded(_, let name, let day):
            ("flag.fill", "\(name) entered the scene", day, Theme.accent)
        case .rivalShipped(let rivalID, let topicID, let day):
            ("shippingbox", "\(rivalName(rivalID)) shipped a \(topicName(topicID)) product", day, Theme.warning)
        case .rivalFolded(_, let name, let day):
            ("flag.slash.fill", "\(name) shut down", day, Color.secondary)
        case .poachAttempt(let rivalID, let employeeID, let offered, _, let day):
            (
                "person.fill.questionmark",
                "\(rivalName(rivalID)) wants \(employeeName(employeeID)) — offering \(offered.money)/wk",
                day,
                Theme.warning
            )
        case .poachDefeated(let employeeID, let day):
            ("person.fill.checkmark", "\(employeeName(employeeID)) is staying with you", day, Theme.positiveCash)
        case .employeePoached(_, let name, let rivalID, let day):
            ("person.fill.xmark", "\(name) left for \(rivalName(rivalID))", day, Theme.negativeCash)
        case .buyoutOffered(let rivalID, let amount, _, let day):
            ("envelope.badge.fill", "\(rivalName(rivalID)) offered \(amount.money) for the company", day, Theme.warning)
        case .buyoutWithdrawn(let rivalID, let day):
            ("envelope", "\(rivalName(rivalID)) withdrew its buyout offer", day, Color.secondary)
        case .companySold(let rivalID, let amount, let day):
            ("crown.fill", "Sold the company to \(rivalName(rivalID)) for \(amount.money)!", day, Theme.positiveCash)
        case .rivalAcquired(_, let name, let hires, let day):
            (
                "building.2.crop.circle.fill",
                hires > 0 ? "Acquired \(name) — \(hires) joined the team" : "Acquired \(name)",
                day,
                Theme.positiveCash
            )
        case .officeRelocated(let district, let day):
            ("map.fill", "Moved the office to \(district.displayName)", day, Theme.accent)
        case .officeBought(let district, let price, let day):
            ("signature", "Bought the \(district.displayName) office for \(price.money)", day, Theme.positiveCash)
        case .officeSold(let district, let price, let day):
            ("signature", "Sold the \(district.displayName) office for \(price.money)", day, Theme.accent)
        case .instantActivityDone(let activity, let day):
            (activity.systemImage, activity.displayName, day, Color.secondary.opacity(0.6))
        case .itemPurchased(let itemID, let day):
            ("bag.fill", "Bought a \(itemName(itemID).lowercased())", day, Theme.accent)
        case .socialActivity(let kind, let employeeID, let day):
            (
                kind.systemImage,
                socialMessage(kind, employeeID: employeeID),
                day,
                Theme.accent
            )
        case .friendshipFormed(let a, let b, let day):
            (
                "person.2.fill",
                "\(employeeName(a)) and \(employeeName(b)) became friends",
                day,
                Theme.positiveCash
            )
        case .friendLostMorale(let employeeID, let day):
            ("heart.slash", "\(employeeName(employeeID)) misses their friend", day, Theme.warning)
        case .staffBirthday(let employeeID, let day):
            ("birthday.cake.fill", "It's \(employeeName(employeeID))'s birthday!", day, Theme.positiveCash)
        case .staffEventOccurred(let employeeID, let kind, _, let day):
            (
                "person.crop.circle.badge.questionmark",
                kind == .familyEmergency
                    ? "\(employeeName(employeeID)) has a family emergency"
                    : "\(employeeName(employeeID)) is being courted by a rival",
                day,
                Theme.warning
            )
        case .staffEventResolved(let employeeID, let choice, let day):
            (
                choice == .supportive ? "hand.raised.fill" : "briefcase.fill",
                choice == .supportive
                    ? "You backed \(employeeName(employeeID)) — they'll remember"
                    : "Business came first for \(employeeName(employeeID))",
                day,
                choice == .supportive ? Theme.positiveCash : Color.secondary
            )

        // Events added after the scaffold land here instead of breaking
        // the build: `@unknown default` keeps this switch compiling (with
        // a warning naming the new case) when a workstream appends one.
        // `EventPresenter` (WS-B) describes it; anything it doesn't know
        // still gets a line rather than vanishing.
        @unknown default:
            fallbackEntry(for: event)
        }
    }

    private func fallbackEntry(for event: GameEvent) -> (icon: String, message: String, day: Int, tint: Color) {
        if let line = EventPresenter.describe(
            event, state: state, content: content, balance: balance
        ) {
            return (line.icon, line.message, line.day, line.tint)
        }
        return ("sparkles", "Something happened", state.day, Color.secondary)
    }

    private func socialMessage(_ kind: SocialActivityKind, employeeID: UUID?) -> String {
        let name = employeeID.map { employeeName($0) } ?? "the team"
        return switch kind {
        case .coffee: "Coffee with \(name)"
        case .oneOnOne: "1-on-1 with \(name)"
        case .gift: "A gift for \(name)"
        case .teamDinner: "The whole team went to dinner"
        }
    }

    /// Defensive name lookup — saves can reference item ids the balance no
    /// longer knows.
    private func itemName(_ id: String) -> String {
        balance.instantLife.items[id]?.name ?? "little something"
    }

    /// Defensive name lookup — folded and acquired rivals are gone from
    /// state, so their events fall back.
    private func rivalName(_ id: UUID) -> String {
        state.rivals.rival(id: id)?.name ?? "a rival"
    }

    /// Defensive name lookup — saves can reference topic ids the catalog no
    /// longer knows.
    private func topicName(_ id: String) -> String {
        content.topic(id)?.name ?? "A niche"
    }

    /// Defensive headline lookup — saves can reference life event ids the
    /// catalog no longer knows.
    private func lifeEventHeadline(_ id: String) -> String {
        content.lifeEvent(id)?.headline ?? "Something happened at home"
    }

    /// The partner's name is read from live state: by the time a breakup
    /// logs, it's gone (that event has its own copy).
    private func relationshipMessage(_ stage: RelationshipStage) -> String {
        let partner = state.life.family.partnerName ?? "someone"
        return switch stage {
        case .single: "Single again"
        case .dating: "Now dating \(partner)"
        case .partner: "Moved in with \(partner)"
        case .married: "Married \(partner)!"
        }
    }

    /// Defensive headline lookup — saves can reference event ids the catalog
    /// no longer knows.
    private func eventHeadline(_ id: String) -> String {
        content.events.first(where: { $0.id == id })?.headline ?? "Something happened"
    }

    /// Defensive name lookup — completed and failed jobs are removed from
    /// state, so their events fall back to a generic client.
    private func clientName(_ id: UUID) -> String {
        state.activeContract(id: id)?.clientName ?? "a client"
    }

    /// Defensive name lookup — events can outlive their products.
    private func productName(_ id: UUID) -> String {
        state.product(id: id)?.name ?? "a product"
    }

    /// Defensive name lookup — fired employees are gone from state, so
    /// their events fall back.
    private func employeeName(_ id: UUID, fallback: String = "someone") -> String {
        state.employee(id: id)?.name ?? fallback
    }

    /// Defensive name lookup — saves can reference tech ids the catalog no
    /// longer knows.
    private func techName(_ id: String) -> String {
        content.tech(id)?.name ?? "a technology"
    }
}
