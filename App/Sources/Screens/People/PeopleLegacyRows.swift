import SwiftUI
import TycoonEngine

/// Iteration 11 — N2. The people actions the game already had, listed in
/// the new menu next to the new ones.
///
/// Nothing here is new behaviour: every row dispatches exactly the action
/// its old card dispatched (`praise`, `grabCoffee`, `oneOnOne`,
/// `giveGift`, `hangOutWith`, `mentorEmployee`, `spendTimeWithPartner`,
/// `spendTimeWithChild`, `callFriend`, `seeFriend`, `advanceRelationship`,
/// `fire`), reads the same blockers, and leaves the old cards where they
/// are. The menu is a second door onto the same room, which is why nothing
/// a pacing bot does changed.
struct PeopleLegacyRows: View {
    let engine: GameEngine
    let target: InteractionTarget
    let group: InteractionGroup

    @Environment(GameShell.self) private var injectedShell: GameShell?
    private var shell: GameShell { injectedShell ?? .shared }

    var body: some View {
        switch (target, group) {
        case (.partner, .nice):
            partnerActivities
        case (.partner, .serious):
            advanceRow
        case (.child(let id), .nice):
            childEvening(id)
        case (.friend(let id), .nice):
            friendRows(id)
        case (.employee(let id), .nice):
            employeeNiceRows(id)
        case (.employee(let id), .serious):
            fireRow(id)
        default:
            EmptyView()
        }
    }

    // MARK: Partner

    @ViewBuilder
    private var partnerActivities: some View {
        ForEach(PartnerActivity.allCases, id: \.self) { activity in
            if let def = engine.balance.relationships.partnerActivity(activity) {
                PeopleRow(
                    icon: activity.systemImage,
                    title: activity.displayName,
                    terms: "−\(def.cost.money) · affection +\(Int(def.affection))",
                    blocker: engine.state.partnerActivityBlocker(
                        activity, balance: engine.balance
                    )
                ) {
                    Haptics.tap()
                    shell.toasts.send(
                        .spendTimeWithPartner(activity),
                        to: engine,
                        rejected: "Not right now.",
                        icon: activity.systemImage
                    )
                }
            }
        }
    }

    /// The relationship ladder, as one row: ask them out, move in,
    /// propose. The gate is the same one the family card shows, said
    /// shorter because this is a menu rather than a card.
    @ViewBuilder
    private var advanceRow: some View {
        if let step = advanceStep() {
            PeopleRow(
                icon: "sparkles",
                title: step.title,
                terms: step.terms,
                footnote: "The step the family card takes, from here.",
                blocker: step.reason
            ) {
                Haptics.tap()
                shell.toasts.send(
                    .advanceRelationship, to: engine,
                    rejected: "Not yet — give it time.", icon: "sparkles"
                )
            }
        }
    }

    private struct AdvanceStep {
        var title: String
        var terms: String
        var reason: String?
    }

    /// The next rung of the relationship ladder and what is standing in
    /// its way — the same gate `FamilyCard` shows, said shorter because
    /// this is a menu row rather than a card.
    private func advanceStep() -> AdvanceStep? {
        let life = engine.state.life
        guard let next = life.family.stage.next, next != .single else { return nil }
        let config = engine.balance.life
        let title: String
        let minRel: Double
        let minDays: Int
        let cost: Int
        switch next {
        case .dating:
            (title, minRel, minDays, cost) =
                ("Ask them out", config.datingMinRelationships, 0, 0)
        case .partner:
            (title, minRel, minDays, cost) = (
                "Move in together", config.partnerMinRelationships,
                config.partnerMinDaysAtStage, 0
            )
        case .married:
            (title, minRel, minDays, cost) = (
                "Ask them to marry you", config.marriedMinRelationships,
                config.marriedMinDaysAtStage, config.weddingCost
            )
        case .single:
            return nil
        }
        let rel = life.meters.relationships
        let daysAtStage = engine.state.day - life.family.stageSinceDay
        let reason: String? = if rel < minRel {
            "Relationships need to reach \(Int(minRel))"
        } else if daysAtStage < minDays {
            "Give it \(minDays - daysAtStage) more day"
                + ((minDays - daysAtStage) == 1 ? "" : "s")
        } else if life.wallet < cost {
            "Need \((cost - life.wallet).money) more in your wallet"
        } else {
            nil
        }
        return AdvanceStep(
            title: cost > 0 ? "\(title) (\(cost.money))" : title,
            terms: cost > 0 ? "−\(cost.money) out of your own wallet" : "Free",
            reason: reason
        )
    }

    // MARK: Child

    @ViewBuilder
    private func childEvening(_ id: UUID) -> some View {
        let reason = ChildhoodSystem.eveningRefusal(
            childID: id, state: engine.state, balance: engine.balance
        )
        PeopleRow(
            icon: "moon.stars",
            title: "Spend the evening with them",
            terms: "−1 evening · bond +\(Int(engine.balance.childhood.bondPerEvening)) · mood +6",
            blocker: reason
        ) {
            Haptics.tap()
            shell.toasts.send(
                .spendTimeWithChild(childID: id), to: engine,
                rejected: reason ?? "Not tonight.", icon: "moon.stars"
            )
        }
    }

    // MARK: Friend

    @ViewBuilder
    private func friendRows(_ id: UUID) -> some View {
        let tuning = engine.state.friendTuning
        PeopleRow(
            icon: "phone.fill",
            title: "Give them a ring",
            terms: "Free · bond +\(Int(tuning.callBond)) · once a week",
            blocker: engine.state.friendCallBlocker(id, content: engine.content)
        ) {
            Haptics.tap()
            shell.toasts.send(
                .callFriend(friendID: id), to: engine,
                rejected: "Not right now.", icon: "phone.fill"
            )
        }
        PeopleRow(
            icon: "figure.2",
            title: "Spend an evening with them",
            terms: "−1 evening · −\(tuning.seeCost.money) · bond +\(Int(tuning.seeBond))",
            blocker: engine.state.friendEveningBlocker(
                id, balance: engine.balance, content: engine.content
            )
        ) {
            Haptics.tap()
            shell.toasts.send(
                .seeFriend(friendID: id), to: engine,
                rejected: "Not tonight.", icon: "figure.2"
            )
        }
    }

    // MARK: Employee

    @ViewBuilder
    private func employeeNiceRows(_ id: UUID) -> some View {
        let staff = engine.balance.staff
        let social = engine.balance.social
        let relationships = engine.balance.relationships
        let employee = engine.state.employees.first { $0.id == id }
        let praiseCooldown = employee?.lastPraisedDay.map {
            engine.state.day - $0 < staff.praiseCooldownDays
        } ?? false
        let socialCooldown = employee?.lastSocialDay.map {
            engine.state.day - $0 < social.socialCooldownDays
        } ?? false
        let cash = engine.state.company.cash

        PeopleRow(
            icon: "hands.clap.fill",
            title: "Praise their work",
            terms: "Free · morale up · once every \(staff.praiseCooldownDays)d",
            blocker: praiseCooldown ? "You praised them recently" : nil
        ) {
            Haptics.tap()
            shell.toasts.send(
                .praise(employeeID: id), to: engine,
                rejected: "Not right now.", icon: "hands.clap.fill"
            )
        }
        PeopleRow(
            icon: "cup.and.saucer.fill",
            title: "Grab a coffee",
            terms: "−\(social.coffeeCost.money) of the company's",
            blocker: socialCooldown
                ? "You've spent time together recently"
                : (cash < social.coffeeCost ? "The company can't afford it" : nil)
        ) {
            Haptics.tap()
            shell.toasts.send(
                .grabCoffee(employeeID: id), to: engine,
                rejected: "Not right now.", icon: "cup.and.saucer.fill"
            )
        }
        PeopleRow(
            icon: "bubble.left.and.bubble.right.fill",
            title: "Have a one-on-one",
            terms: "Free · loyalty and morale",
            blocker: socialCooldown ? "You've spent time together recently" : nil
        ) {
            Haptics.tap()
            shell.toasts.send(
                .oneOnOne(employeeID: id), to: engine,
                rejected: "Not right now.", icon: "bubble.left.and.bubble.right.fill"
            )
        }
        PeopleRow(
            icon: "gift.fill",
            title: "Give them a gift",
            terms: "−\(social.giftCost.money) of the company's",
            blocker: socialCooldown
                ? "You've spent time together recently"
                : (cash < social.giftCost ? "The company can't afford it" : nil)
        ) {
            Haptics.tap()
            shell.toasts.send(
                .giveGift(employeeID: id), to: engine,
                rejected: "Not right now.", icon: "gift.fill"
            )
        }
        PeopleRow(
            icon: "figure.2.arms.open",
            title: "Hang out after work",
            terms: "−1 evening · −\(relationships.hangOut.cost.money) of your own",
            blocker: engine.state.hangOutBlocker(employeeID: id, balance: engine.balance)
        ) {
            Haptics.tap()
            shell.toasts.send(
                .hangOutWith(employeeID: id), to: engine,
                rejected: "Not tonight.", icon: "figure.2.arms.open"
            )
        }
        PeopleRow(
            icon: "graduationcap.fill",
            title: "Mentor them on the code",
            terms: "−1 evening · coding up · bond up",
            blocker: engine.state.mentorBlocker(employeeID: id, balance: engine.balance)
        ) {
            Haptics.tap()
            shell.toasts.send(
                .mentorEmployee(employeeID: id, skill: .coding), to: engine,
                rejected: "Not tonight.", icon: "graduationcap.fill"
            )
        }
    }

    @ViewBuilder
    private func fireRow(_ id: UUID) -> some View {
        let employee = engine.state.employees.first { $0.id == id }
        // MARK: T3 (people)
        // The ordinary firing pays notice now, priced here as on their page.
        let notice = engine.state.severanceNotice(employeeID: id, balance: engine.balance)
        let blocker = employee?.isFounder == true
            ? "That's you"
            : engine.state.severanceNoticeBlocker(employeeID: id, balance: engine.balance)
        PeopleRow(
            icon: "door.left.hand.open",
            title: "Let them go",
            terms: "The ordinary firing · \(notice.map(SeveranceCopy.noticePrice) ?? "no notice owed") · they stay in the address book",
            footnote: "No cause named — they can come back through the book.",
            blocker: blocker,
            destructive: true
        ) {
            Haptics.tap()
            shell.toasts.send(
                .fire(employeeID: id, payNotice: true), to: engine,
                rejected: blocker ?? "Not right now.", icon: "door.left.hand.open"
            )
        }
        // MARK: end T3
    }
}
