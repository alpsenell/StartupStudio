import Foundation
import TycoonContent
import TycoonEngine

/// The history between the studio and one rival, compiled from
/// `eventLog`: the people they went after, the wars they started, the
/// challenges held or lost, the offers on the table, the jobs the studio
/// built for them. A pure read over state — the log is capped at 500
/// entries, so this is the last year or so of a long run, which is the
/// part a founder remembers anyway.
struct RivalHistory: Equatable {
    struct Entry: Identifiable, Equatable {
        enum Kind: Equatable {
            case arrived, launch, copycat, priceWar, poachAttempt, poached
            case challenge, held, lost
            case buyoutOffered, buyoutWithdrawn, sold, sponsored, retreated, acquired
        }

        /// The event's index in the log: stable while the log keeps it.
        let id: Int
        let day: Int
        let kind: Kind
        let text: String
    }

    /// What was tallied, for the one-line summary.
    struct Tally: Equatable {
        var poachAttempts = 0
        var poached = 0
        var priceWars = 0
        var challenges = 0
        var held = 0
        var lost = 0
        var buyoutOffers = 0
        var sponsoredJobs = 0
    }

    /// Newest first.
    let entries: [Entry]
    let tally: Tally

    var isEmpty: Bool { entries.isEmpty }

    /// "2 poaches · 1 price war · held 1 of 2 challenges", or nil with
    /// nothing to say.
    var summary: String? {
        var parts: [String] = []
        if tally.poachAttempts > 0 {
            parts.append(tally.poachAttempts == 1 ? "1 poach" : "\(tally.poachAttempts) poaches")
            if tally.poached > 0 {
                parts[parts.count - 1] += " (\(tally.poached) landed)"
            }
        }
        if tally.priceWars > 0 {
            parts.append(tally.priceWars == 1 ? "1 price war" : "\(tally.priceWars) price wars")
        }
        if tally.challenges > 0 {
            let settled = tally.held + tally.lost
            parts.append(
                settled == 0
                    ? (tally.challenges == 1 ? "1 challenge open" : "\(tally.challenges) challenges open")
                    : "held \(tally.held) of \(settled) \(settled == 1 ? "challenge" : "challenges")"
            )
        }
        if tally.buyoutOffers > 0 {
            parts.append(tally.buyoutOffers == 1 ? "1 buyout offer" : "\(tally.buyoutOffers) buyout offers")
        }
        if tally.sponsoredJobs > 0 {
            parts.append(tally.sponsoredJobs == 1 ? "1 job built for them" : "\(tally.sponsoredJobs) jobs built for them")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    static let empty = RivalHistory(entries: [], tally: Tally())

    /// Everything in the log that names `rivalID`, newest first.
    static func compile(for rivalID: UUID, state: GameState, content: ContentCatalog) -> RivalHistory {
        var entries: [Entry] = []
        var tally = Tally()

        func topic(_ id: String) -> String { content.topic(id)?.name ?? id }
        func employee(_ id: UUID) -> String { state.employee(id: id)?.name ?? "one of your people" }

        for (index, event) in state.eventLog.enumerated() {
            let entry: Entry?
            switch event {
            case .rivalFounded(let id, let name, let day) where id == rivalID:
                entry = Entry(id: index, day: day, kind: .arrived, text: "\(name) entered the scene")
            case .incumbentArrived(let id, let name, let day) where id == rivalID:
                entry = Entry(id: index, day: day, kind: .arrived, text: "\(name) arrived in your best markets, with money to lose")
            case .rivalProductLaunched(let id, let productName, let topicID, let quality, let day) where id == rivalID:
                entry = Entry(id: index, day: day, kind: .launch, text: "Launched \(productName) into \(topic(topicID)) — a \(quality)")
            case .rivalCopycat(let id, let topicID, let day) where id == rivalID:
                entry = Entry(id: index, day: day, kind: .copycat, text: "Cloned your \(topic(topicID)) play")
            case .priceWarStarted(let id, let topicID, _, let day) where id == rivalID:
                tally.priceWars += 1
                entry = Entry(id: index, day: day, kind: .priceWar, text: "Started a price war in \(topic(topicID))")
            case .poachAttempt(let id, let employeeID, let offered, _, let day) where id == rivalID:
                tally.poachAttempts += 1
                entry = Entry(id: index, day: day, kind: .poachAttempt, text: "Made \(employee(employeeID)) an offer — \(offered.money)/wk")
            case .employeePoached(_, let name, let id, let day) where id == rivalID:
                tally.poached += 1
                entry = Entry(id: index, day: day, kind: .poached, text: "Hired \(name) away from you")
            case .categoryChallenged(let id, let topicID, let productName, let quality, _, let day) where id == rivalID:
                tally.challenges += 1
                entry = Entry(id: index, day: day, kind: .challenge, text: "Challenged you in \(topic(topicID)) with \(productName), a \(quality)")
            case .categoryHeld(let id, let topicID, let day) where id == rivalID:
                tally.held += 1
                entry = Entry(id: index, day: day, kind: .held, text: "You held \(topic(topicID)) against them")
            case .categoryLost(let id, let topicID, let day) where id == rivalID:
                tally.lost += 1
                entry = Entry(id: index, day: day, kind: .lost, text: "They took \(topic(topicID)) from you")
            case .buyoutOffered(let id, let amount, _, let day) where id == rivalID:
                tally.buyoutOffers += 1
                entry = Entry(id: index, day: day, kind: .buyoutOffered, text: "Offered \(amount.money) for the company")
            case .buyoutWithdrawn(let id, let day) where id == rivalID:
                entry = Entry(id: index, day: day, kind: .buyoutWithdrawn, text: "Withdrew the buyout offer")
            case .companySold(let id, let amount, let day) where id == rivalID:
                entry = Entry(id: index, day: day, kind: .sold, text: "Bought the company for \(amount.money)")
            case .sponsoredContractDelivered(let id, let topicID, let quality, let day) where id == rivalID:
                tally.sponsoredJobs += 1
                entry = Entry(id: index, day: day, kind: .sponsored, text: "Shipped the \(topic(topicID)) app you built for them, at \(quality)")
            case .incumbentRetreated(let id, _, let day) where id == rivalID:
                entry = Entry(id: index, day: day, kind: .retreated, text: "Gave up your categories")
            case .rivalAcquired(let id, let name, let hires, let day) where id == rivalID:
                entry = Entry(
                    id: index, day: day, kind: .acquired,
                    text: hires > 0 ? "You acquired \(name); \(hires) of theirs joined you" : "You acquired \(name)"
                )
            default:
                entry = nil
            }
            if let entry { entries.append(entry) }
        }
        return RivalHistory(entries: entries.reversed(), tally: tally)
    }
}
