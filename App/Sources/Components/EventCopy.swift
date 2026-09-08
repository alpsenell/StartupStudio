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
             .childBorn, .homeUpgraded, .weekendSpent, .instantActivityDone, .itemPurchased,
             .familyDateMissed:
            .life
        case .hired, .fired, .candidatesRefreshed, .employeeQuit, .employeePromoted,
             .employeeDemoted, .salaryChanged, .employeeTrained, .socialActivity,
             .friendshipFormed, .friendLostMorale, .staffBirthday, .staffEventOccurred,
             .staffEventResolved:
            .team
        case .marketBoom, .marketCrash, .industryNews:
            .market
        case .rivalFounded, .rivalShipped, .rivalFolded, .poachAttempt, .poachDefeated,
             .employeePoached, .buyoutOffered, .buyoutWithdrawn, .companySold, .rivalAcquired,
             .rivalProductLaunched, .priceWarStarted, .rivalCopycat, .sponsoredContractDelivered,
             // WS-A: the category fight and the incumbent.
             .categoryChallenged, .categoryHeld, .categoryLost, .incumbentArrived, .incumbentRetreated:
            .rivals
        // WS-A's founder consequences are life, not company: the landlord,
        // the diagnosis and the meltdown all happen to the person.
        case .evictionWarning, .homeDowngraded, .chronicConditionDiagnosed,
             .chronicConditionCleared, .founderMeltdown:
            .life
        // The founder as a person: what they're learning, who they've met,
        // the money that is theirs rather than the company's, and how the
        // person they go home to is doing.
        case .founderTrained, .networkingEventStarted, .networkingTalk, .networkingEventEnded,
             .stakeAcquired, .stakeExited, .stakeLost, .romanceStarted,
             .partnerTime, .partnerDrifting:
            .life
        // Somebody joining, from wherever, is team news.
        case .contactRecruited, .contactJoinedForEquity, .hungOutWith, .employeeMentored:
            .team
        // The bank taking the founder's savings is company news and life
        // news at once; it belongs with the money.
        case .guaranteeCalled, .guaranteeAtRisk:
            .company
        // Somebody handing in notice, and somebody being interviewed, are
        // team news wherever they were raised.
        case .resignationNotice, .candidateInterviewed:
            .team
        // Somebody leaving into the address book is team news however
        // they left — the team is where the player last saw them.
        case .alumnusJoinedBook:
            .team
        // WS-B: the cap table and the sale of the company are company news.
        case .roundBoughtBack, .earnOutSigned, .earnOutReviewed:
            .company
        // A rule the team lives by, made, applied or taken back (WS-D).
        case .staffPolicySet, .staffPolicyApplied, .staffPolicyReversed:
            .team
        default:
            .company
        }
    }

    /// Iteration 7 (R2): the feed line for the thing that came along.
    private func heirloomMessage(_ kind: String) -> String {
        switch kind {
        case "person": "Somebody from the last company is in your address book"
        case "perk": "A perk from the last company is yours from day one"
        case "deed": "The last company's office is yours — deed and all"
        default: "Something from the last company came with you"
        }
    }

    // l10n: NOT LOCALIZED, deliberately (R9, iteration 7). Every arm below
    // builds an English sentence by concatenation and interpolation, so a
    // String(localized:) per arm would hand a translator ~200 fragments with
    // no sentence to put them in. The conversion is one format string per
    // GameEvent case, named after the case and keyed by it -
    //   "event.hired"          = "%1$@ joined as %2$@ on %3$@/wk."
    //   "event.productShipped" = "%1$@ shipped. The press has it now."
    // - with `.stringsdict`-style plural variants for every `day/days`,
    // `bug/bugs`, `week/weeks` ternary in here, since no other language
    // pluralises with a trailing s. Wave 2; see docs/product/iteration-7-release.md.

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
        case .sponsoredContractDelivered(let rivalID, let topicID, let quality, let day):
            (
                "flag.fill",
                "\(rivalName(rivalID)) shipped the \(topicName(topicID)) app you built for them at \(quality) — the press knows whose work it was",
                day,
                Theme.warning
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
            // A distress sale is the same event with a different ending
            // behind it; the line should not crown a fire sale.
            state.gameOver?.kind == .soldUp
                ? ("tag.fill", "Sold up: \(rivalName(rivalID)) bought the name and the desks for \(amount.money)", day, Theme.warning)
                : ("crown.fill", "Sold the company to \(rivalName(rivalID)) for \(amount.money)!", day, Theme.positiveCash)
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
                staffMomentTitle(kind, employeeID: employeeID),
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

        // MARK: WS-A — live ops, resignations, the founder's own life

        case .liveBugsSpiking(let productID, let liveBugs, let day):
            (
                "ant.fill",
                "\(liveBugs) live bug\(liveBugs == 1 ? "" : "s") in \(productName(productID)) — "
                    + "sales are bleeding until somebody works the queue",
                day,
                Theme.warning
            )
        case .updateShipped(let productID, let newScore, let day):
            (
                "arrow.triangle.2.circlepath",
                "Update out for \(productName(productID)) — it reviews \(newScore) now",
                day,
                Theme.scoreTint(newScore)
            )
        case .priceChanged(let productID, let tier, let day):
            (
                "tag.fill",
                "\(productName(productID)) moved to \(tier.displayName) pricing",
                day,
                Theme.accent
            )
        case .resignationNotice(_, let name, let respondByDay, let day):
            (
                "figure.walk.departure",
                "\(name) handed in notice — \(max(0, respondByDay - state.day)) day"
                    + "\(max(0, respondByDay - state.day) == 1 ? "" : "s") to answer with a raise "
                    + "or a promotion",
                day,
                Theme.warning
            )
        case .evictionWarning(let untilDay, let day):
            (
                "house.badge.exclamationmark",
                "The landlord wants the arrears cleared by day \(untilDay)",
                day,
                Theme.negativeCash
            )
        case .homeDowngraded(let tier, let day):
            ("box.truck.fill", "Moved somewhere cheaper: \(tier.displayName)", day, Theme.negativeCash)
        case .chronicConditionDiagnosed(let day):
            (
                "cross.case.fill",
                "Second hospital stay this year — the doctor calls it chronic. "
                    + "Energy is capped until three weekends are properly off.",
                day,
                Theme.negativeCash
            )
        case .chronicConditionCleared(let day):
            ("heart.fill", "Three restful weekends did it — the cap is off", day, Theme.positiveCash)
        case .founderMeltdown(let day):
            (
                "flame.fill",
                "Burning out twice in a year made the trade press",
                day,
                Theme.warning
            )

        // MARK: Founder & people

        case .founderTrained(let skill, let method, let gained, let day):
            (
                "brain.head.profile",
                "\(method.displayName): \(skill.displayName) "
                    + "+\(gained.formatted(.number.precision(.fractionLength(1)).locale(Theme.gameLocale)))",
                day,
                Theme.accent
            )
        case .networkingEventStarted(let venue, let contactCount, let day):
            (
                "person.2.wave.2.fill",
                "\(venue.displayName) — \(contactCount) people worth talking to",
                day,
                Theme.accent
            )
        case .networkingEventEnded(let day):
            ("moon.fill", "You called it a night", day, Color.secondary)
        case .contactRecruited(_, let name, let day):
            ("person.badge.plus", "\(name) is joining you", day, Theme.positiveCash)
        case .contactJoinedForEquity(_, let name, let equity, let day):
            (
                "person.2.badge.key.fill",
                "\(name) came in as a partner for "
                    + "\(equity.formatted(.number.precision(.fractionLength(1)).locale(Theme.gameLocale)))%",
                day,
                Theme.positiveCash
            )
        case .stakeAcquired(_, let companyName, let stakePercent, let amount, let day):
            (
                "chart.pie.fill",
                "Bought \(stakePercent.formatted(.number.precision(.fractionLength(1)).locale(Theme.gameLocale)))% "
                    + "of \(companyName) for \(amount.money)",
                day,
                Theme.accent
            )
        case .stakeExited(let companyName, let proceeds, let day):
            (
                "sparkles",
                "\(companyName) got bought — your stake paid \(proceeds.money)",
                day,
                Theme.positiveCash
            )
        case .stakeLost(let companyName, let invested, let day):
            (
                "xmark.circle.fill",
                "\(companyName) folded. Your \(invested.money) went with it.",
                day,
                Theme.negativeCash
            )
        case .angelInvestment(_, let name, let amount, let equity, let day):
            (
                "banknote.fill",
                "\(name) put \(amount.money) in for "
                    + "\(equity.formatted(.number.precision(.fractionLength(1)).locale(Theme.gameLocale)))%",
                day,
                Theme.positiveCash
            )
        case .romanceStarted(_, let name, let day):
            ("heart.fill", "You and \(name) are seeing each other", day, Theme.positiveCash)
        case .partnerTime(_, _, let day):
            ("heart.circle.fill", "An evening that wasn't about work", day, Theme.positiveCash)
        case .partnerDrifting(_, let day):
            (
                "heart.slash.fill",
                "Your partner has stopped expecting you home. Do something about it.",
                day,
                Theme.warning
            )
        case .guaranteeAtRisk(let amount, let callOnDay, let day):
            (
                "exclamationmark.triangle.fill",
                "The company is in the red and you guaranteed \(amount.money) of its debt. "
                    + "Clear it by day \(callOnDay) or the bank takes your savings and your home.",
                day,
                Theme.negativeCash
            )
        case .guaranteeCalled(let amount, let tookHome, let day):
            (
                "house.fill",
                tookHome
                    ? "The bank took your home against the company's debt (\(amount.money))"
                    : "Your guarantee was called — \(amount.money) of your savings went to the bank",
                day,
                Theme.negativeCash
            )
        case .hungOutWith(let employeeID, let day):
            (
                "figure.2",
                "A night out with \(employeeName(employeeID))",
                day,
                Theme.accent
            )
        case .employeeMentored(let employeeID, let skill, let day):
            (
                "graduationcap.fill",
                "Taught \(employeeName(employeeID)) some \(skill.displayName.lowercased())",
                day,
                Theme.accent
            )
        // One line per exchange would bury the feed under an evening's
        // small talk; the conversation sheet is where that feedback lives.
        case .networkingTalk:
            fallbackEntry(for: event)

        // MARK: WS-B and WS-F
        //
        // Both workstreams ship a presenter that already renders their own
        // events — the story beats read out of the catalog, the chapter and
        // board lines out of the progression state. Spelling the cases out
        // here keeps the switch exhaustive (so the *next* appended case is
        // a compiler error, not a silent "Something happened") while the
        // copy stays in the one place its owner maintains.

        case .narrativeChoice, .narrativeResolved, .industryNews,
             .goalCompleted, .chapterReached,
             .investmentOffered, .investmentAccepted, .investmentDeclined, .investmentWithdrawn,
             .boardReviewed, .boardDemandedPlan, .founderOusted, .wentPublic,
             .rivalProductLaunched, .priceWarStarted, .rivalCopycat, .candidateInterviewed:
            fallbackEntry(for: event)

        // MARK: WS-F — the boomerang

        case .alumnusJoinedBook(let contactID, let name, let day):
            alumnusEntry(contactID: contactID, name: name, day: day)
        // MARK: Iteration 5 — WS-B (the board and the exit)

        case .roundBoughtBack(let investorID, let amount, let day):
            (
                "arrow.uturn.backward.circle.fill",
                "Bought out \(investorName(investorID)) for \(amount.money) — their seat is empty",
                day,
                Theme.accent
            )
        case .earnOutSigned(let rivalID, let upfront, let price, let day):
            (
                "signature",
                "Signed the earn-out with \(rivalName(rivalID)): \(upfront.money) now, "
                    + "up to \(price.money) if you hit their number",
                day,
                Theme.positiveCash
            )
        case .earnOutReviewed(let met, let paid, let remainingReviews, let day):
            met
                ? (
                    "checkmark.seal.fill",
                    "Earn-out review passed — \(paid.money) paid" + reviewsToGo(remainingReviews),
                    day,
                    Theme.positiveCash
                )
                : (
                    "xmark.seal.fill",
                    "Earn-out review missed — nothing paid this quarter" + reviewsToGo(remainingReviews),
                    day,
                    Theme.warning
                )


        // MARK: WS-D — the answer becomes the policy

        case .staffPolicySet(let flag, let employeeID, let day):
            (
                "text.book.closed.fill",
                policyRule(flag).map {
                    "\($0.name) is the rule now: \(lowercasingFirst($0.answer)) — "
                        + "\(employeeName(employeeID)) asked, and that was the answer"
                } ?? "That is the rule now — \(employeeName(employeeID)) asked, and that was the answer",
                day,
                Theme.accent
            )
        case .staffPolicyApplied(let flag, let employeeID, let day):
            (
                "checkmark.seal.fill",
                policyRule(flag).map {
                    "\(employeeName(employeeID)) — \($0.name.lowercased()), by the rule: "
                        + lowercasingFirst($0.answer)
                } ?? "The rule answered for \(employeeName(employeeID))",
                day,
                policyRule(flag)?.generous == false ? Color.secondary : Theme.positiveCash
            )
        case .staffPolicyReversed(let flag, let day):
            (
                "arrow.uturn.backward.circle.fill",
                policyRule(flag).map { "You reversed the \($0.name.lowercased()) rule — everyone heard" }
                    ?? "You reversed a rule — everyone heard",
                day,
                Theme.warning
            )

        // MARK: Iteration 5

        // WS-E — the date in the diary.
        case .familyDateMissed(let eventID, let day):
            ("heart.slash.fill", missedDateMessage(eventID), day, Theme.warning)
        // WS-G — the independent ladder's ending.
        case .stayedIndependent(let day):
            (
                "flag.checkered",
                "\(state.company.name) is built, and still yours — every share of it",
                day,
                Theme.positiveCash
            )

        // MARK: Iteration 7

        // R5 — the founder kept going past an ending.
        case .continuedAfterEnding(let ending, let day):
            (
                "play.circle.fill",
                ending == .ipo
                    ? "The bell has rung and \(state.company.name) is still running — no board, no buyers, just the work"
                    : "\(state.company.name) is built, still yours, and still open on Monday",
                day,
                Theme.accent
            )
        // R2 — the one thing carried from the last company.
        case .heirloomApplied(let kind, let day):
            ("gift.fill", heirloomMessage(kind), day, Theme.accent)
        // WS-A — the category fight and the incumbent.
        case .categoryChallenged(let rivalID, let topicID, let productName, let quality, let respondByDay, let day):
            (
                "flag.2.crossed.fill",
                "\(rivalName(rivalID)) launched \(productName) into \(topicName(topicID)) — "
                    + "a \(quality). Six weeks to hold it (day \(respondByDay)).",
                day,
                Theme.warning
            )
        case .categoryHeld(let rivalID, let topicID, let day):
            (
                "checkmark.shield.fill",
                "You held \(topicName(topicID)) — \(rivalName(rivalID)) lost ground, your standing there grew",
                day,
                Theme.positiveCash
            )
        case .categoryLost(let rivalID, let topicID, let day):
            (
                "xmark.shield.fill",
                "\(rivalName(rivalID)) took \(topicName(topicID)) — your standing there fell, and they're staying",
                day,
                Theme.negativeCash
            )
        case .incumbentArrived(_, let name, let day):
            ("building.columns.fill", "\(name) arrived in your best markets, with money to lose", day, Theme.warning)
        case .incumbentRetreated(_, let name, let day):
            ("flag.checkered", "\(name) gave up your categories", day, Theme.positiveCash)

        // MARK: Iteration 10 — M2 (pitch room)

        case let .pitchOpened(counterpart, day):
            (
                "bubble.left.and.text.bubble.right.fill",
                pitchOpenedMessage(counterpart),
                day,
                Theme.accent
            )
        case let .pitchClosed(counterpart, band, summary, day):
            (
                PitchBand(rawValue: band)?.isGood == true ? "hand.thumbsup.fill" : "quote.closing",
                "\(pitchWhoMessage(counterpart)) \(summary)",
                day,
                PitchBand(rawValue: band).map { pitchBand in
                    pitchBand.isGood
                        ? Theme.positiveCash
                        : (pitchBand.isBad ? Theme.negativeCash : Color.secondary)
                } ?? Color.secondary
            )

        // MARK: end of Iteration 10 — M2

        // Events added after this file land here instead of breaking the
        // build: `@unknown default` keeps the switch compiling (with a
        // warning naming the new case) when a workstream appends one.
        // `EventPresenter` (WS-B) describes it; anything it doesn't know
        // still gets a line rather than vanishing.
        @unknown default:
            fallbackEntry(for: event)
        }
    }

    // MARK: Iteration 10 — M2 (pitch room)

    /// "You sat down with the investor holding the term sheet".
    private func pitchOpenedMessage(_ counterpart: String) -> String {
        switch PitchCounterpart(rawValue: counterpart) {
        case .investor: "You sat down with the investor holding the term sheet"
        case .client: "You took the client meeting before answering the brief"
        case .journalist: "You gave the press twenty minutes before the launch"
        case .board: "You went into the board room rather than reading the minutes"
        case nil: "You sat down with somebody"
        }
    }

    /// Who the closing line is about, so the summary reads as a sentence.
    private func pitchWhoMessage(_ counterpart: String) -> String {
        switch PitchCounterpart(rawValue: counterpart) {
        case .investor: "The term sheet meeting:"
        case .client: "The client meeting:"
        case .journalist: "The interview:"
        case .board: "The board meeting:"
        case nil: "The meeting:"
        }
    }

    // MARK: end of Iteration 10 — M2

    /// How they left says what the line is. Somebody the founder burned is
    /// in the book only as history; everybody else is a call the founder
    /// can still make — and the line says so, because "you'll see them
    /// again" is the promise the poach sheet just made.
    private func alumnusEntry(
        contactID: UUID, name: String, day: Int
    ) -> (icon: String, message: String, day: Int, tint: Color) {
        let contact = state.networking.contact(contactID)
        if contact?.outcome == .lost {
            return (
                "person.crop.circle.badge.xmark",
                "\(name) left with no reason to take your call",
                day,
                Color.secondary
            )
        }
        return ("book.pages.fill", "\(name) is in your address book — you'll see them again", day, Theme.accent)
    }

    private func fallbackEntry(for event: GameEvent) -> (icon: String, message: String, day: Int, tint: Color) {
        if let line = EventPresenter.describe(
            event, state: state, content: content, balance: balance
        ) {
            return (line.icon, line.message, line.day, line.tint)
        }
        return ("sparkles", "Something happened", state.day, Color.secondary)
    }

    /// The staff moment's own title from the catalog ("Priya is having a
    /// baby"); the two original kinds' sentences when the catalog has no
    /// definition for it.
    private func staffMomentTitle(_ kind: StaffEventKind, employeeID: UUID) -> String {
        let name = employeeName(employeeID)
        if let def = content.staffEvent(kind.rawValue) {
            return def.title
                .replacingOccurrences(of: "{name}", with: name)
                .replacingOccurrences(of: "{company}", with: state.company.name)
        }
        return kind == .familyEmergency
            ? "\(name) has a family emergency"
            : "\(name) is being courted by a rival"
    }

    /// "Full pay, three months" after a colon reads as "full pay, three
    /// months"; a proper noun or an acronym keeps its capital.
    private func lowercasingFirst(_ text: String) -> String {
        guard let first = text.first, first.isUppercase,
              text.dropFirst().first.map({ !$0.isUppercase }) ?? true
        else { return text }
        return first.lowercased() + text.dropFirst()
    }

    /// The rule behind a policy flag: its name and the answer it gives,
    /// from the def whose policy block raised the flag. Nil for a flag the
    /// catalog no longer names.
    private func policyRule(_ flag: String) -> (name: String, answer: String, generous: Bool)? {
        guard let def = content.staffEvents.first(where: {
            $0.policy?.supportiveFlag == flag || $0.policy?.strictFlag == flag
        }), let policy = def.policy else { return nil }
        let generous = policy.supportiveFlag == flag
        let answer = generous ? (def.supportive?.label ?? def.strict.label) : def.strict.label
        return (policy.name, answer, generous)
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

    /// The investor behind a round, from the catalog or — for a persona
    /// the catalog no longer carries — the cap table itself.
    private func investorName(_ id: String) -> String {
        content.investors.first { $0.id == id }?.name
            ?? state.investors.boughtOut.first { $0.investorID == id }?.investorName
            ?? state.investors.rounds.first { $0.investorID == id }?.investorName
            ?? "an investor"
    }

    /// ", 1 review to go" — or nothing on the last one, when the sale
    /// closes in the same breath.
    private func reviewsToGo(_ remaining: Int) -> String {
        remaining == 0 ? "" : ", \(remaining) review\(remaining == 1 ? "" : "s") to go"
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

    /// "You missed Sam's birthday. They noticed." The diary line of the
    /// beat, filled from live state; a date whose def the catalog no
    /// longer knows still reads as what it was.
    private func missedDateMessage(_ eventID: String) -> String {
        guard var label = state.diaryLabel(for: eventID, content: content) else {
            return "You missed a date you had promised. They noticed."
        }
        // "Your anniversary…" mid-sentence; a name keeps its capital.
        for prefix in ["Your ", "The "] where label.hasPrefix(prefix) {
            label = prefix.lowercased() + label.dropFirst(prefix.count)
        }
        return "You missed \(label). They noticed."
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
