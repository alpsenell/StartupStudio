import Foundation
import PixelKit
import TycoonContent
import TycoonEngine

/// One thing on the company's timeline: the day it happened, what to draw
/// there, and the two lines the detail card reads.
struct TimelineMarker: Identifiable, Equatable {
    enum Kind: Equatable {
        /// Day 0: the founder's portrait.
        case founding(seed: UInt64)
        /// A product's box art at its launch day.
        case product(typeID: String, topicID: String, seed: UInt64)
        /// A hire's portrait at their hire day.
        case hire(seed: UInt64, role: RoleLook)
        /// A chapter flag.
        case chapter(Int)
        /// A market crash in a topic.
        case crash(topicID: String)
        /// A round closed.
        case round
        /// The incumbent arrived.
        case incumbent
        /// A category challenge, held or lost.
        case challengeHeld(topicID: String)
        case challengeLost(topicID: String)
        /// The company changed hands.
        case buyout
        /// How the run ended, when it has.
        case ending(EndingKind)

        /// Products, chapters and the ending hang above the line; people
        /// and the world's blows hang below it.
        var isAboveBaseline: Bool {
            switch self {
            case .product, .chapter, .ending, .buyout: true
            case .founding, .hire, .crash, .round, .incumbent, .challengeHeld, .challengeLost: false
            }
        }
    }

    let id: String
    let day: Int
    let kind: Kind
    /// Short: a name, a chapter title, a topic.
    let title: String
    /// One sentence for the detail card.
    let detail: String
}

/// How much of the run fits across the screen at once.
enum TimelineZoom: String, CaseIterable, Identifiable {
    case quarter, year, run

    var id: String { rawValue }

    var label: String {
        switch self {
        case .quarter: "Quarter"
        case .year: "Year"
        case .run: "Whole run"
        }
    }

    /// The days that span the viewport, for a run `spanDays` long.
    func daysAcross(spanDays: Int) -> Int {
        switch self {
        case .quarter: 91
        case .year: 364
        case .run: max(spanDays, 28)
        }
    }
}

/// Builds the run's markers from `chapterLog`, `eventLog`, the products,
/// the team, the cap table and the rivals. Pure: state in, markers out,
/// sorted by day.
enum TimelineBuilder {
    static func markers(state: GameState, content: ContentCatalog, balance: BalanceConfig) -> [TimelineMarker] {
        let copy = EventCopy(state: state, content: content, balance: balance)
        var markers: [TimelineMarker] = []

        // The founder, on the day the doors opened.
        let founder = state.employees.first { $0.isFounder }
        markers.append(TimelineMarker(
            id: "founding",
            day: 0,
            kind: .founding(seed: founder?.appearanceSeed ?? state.progression.founder.appearanceSeed ?? 0),
            title: state.company.name,
            detail: "\(state.progression.founder.displayName) founded \(state.company.name)."
        ))

        // Chapters after the first: the first is the founding.
        for entry in state.progression.chapterLog where entry.chapter > 1 {
            markers.append(TimelineMarker(
                id: "chapter-\(entry.chapter)",
                day: entry.day,
                kind: .chapter(entry.chapter),
                title: ChapterDef.title(for: entry.chapter),
                detail: "Chapter \(entry.chapter): \(ChapterDef.title(for: entry.chapter))."
            ))
        }

        // Products, at launch.
        for product in state.products {
            guard case .released(let release) = product.stage else { continue }
            let seed = product.id.uuidString.utf8.reduce(UInt64(0)) { $0 &* 31 &+ UInt64($1) }
            let type = content.productType(product.typeID)?.name ?? product.typeID
            let topic = content.topic(product.topicID)?.name ?? product.topicID
            let score = release.reviews.isEmpty
                ? ""
                : " Reviewed at \(release.reviews.reduce(0) { $0 + $1.score } / release.reviews.count)."
            markers.append(TimelineMarker(
                id: "product-\(product.id.uuidString)",
                day: release.launchDay,
                kind: .product(typeID: product.typeID, topicID: product.topicID, seed: seed),
                title: product.name,
                detail: "\(product.name) shipped: a \(type.lowercased()) in \(topic).\(score)"
            ))
        }

        // Hires.
        for employee in state.employees where !employee.isFounder {
            markers.append(TimelineMarker(
                id: "hire-\(employee.id.uuidString)",
                day: employee.hiredDay,
                kind: .hire(
                    seed: employee.appearanceSeed,
                    role: RoleLook(rawValue: employee.role.rawValue) ?? .none
                ),
                title: employee.name,
                detail: "\(employee.name) joined as a \(employee.role.displayName.lowercased())."
            ))
        }

        // Rounds, seated or bought back.
        for round in state.investors.rounds + state.investors.boughtOut {
            markers.append(TimelineMarker(
                id: "round-\(round.investorID)-\(round.day)",
                day: round.day,
                kind: .round,
                title: round.investorName,
                detail: "\(round.investorName) put \(round.amount.money) in for "
                    + "\(round.equity.formatted(.number.precision(.fractionLength(1)).locale(Theme.gameLocale)))%."
            ))
        }

        // The world's blows, from the log: the crash, the incumbent, the
        // category fights, and the sale.
        //
        // A run logs a dozen crashes a year across twelve topics; the one
        // that belongs on this company's line is the one in a market it
        // sells into — the same relevance the pause policy applies.
        let soldTopics = Set(state.products.compactMap { product -> String? in
            guard case .released = product.stage else { return nil }
            return product.topicID
        })
        var seenCrashes: Set<String> = []
        var sawIncumbent = false
        for (index, event) in state.eventLog.enumerated() {
            switch event {
            case .marketCrash(let topicID, let day):
                guard soldTopics.contains(topicID) else { continue }
                let key = "\(topicID)-\(day)"
                guard seenCrashes.insert(key).inserted else { continue }
                markers.append(TimelineMarker(
                    id: "crash-\(key)",
                    day: day,
                    kind: .crash(topicID: topicID),
                    title: content.topic(topicID)?.name ?? topicID,
                    detail: copy.line(for: event).message
                ))
            case .incumbentArrived(_, let name, let day):
                sawIncumbent = true
                markers.append(TimelineMarker(
                    id: "incumbent-\(day)",
                    day: day,
                    kind: .incumbent,
                    title: name,
                    detail: copy.line(for: event).message
                ))
            case .categoryHeld(_, let topicID, let day):
                markers.append(TimelineMarker(
                    id: "held-\(topicID)-\(day)",
                    day: day,
                    kind: .challengeHeld(topicID: topicID),
                    title: content.topic(topicID)?.name ?? topicID,
                    detail: copy.line(for: event).message
                ))
            case .categoryLost(_, let topicID, let day):
                markers.append(TimelineMarker(
                    id: "lost-\(topicID)-\(day)",
                    day: day,
                    kind: .challengeLost(topicID: topicID),
                    title: content.topic(topicID)?.name ?? topicID,
                    detail: copy.line(for: event).message
                ))
            case .companySold(let rivalID, _, let day), .earnOutSigned(let rivalID, _, _, let day):
                markers.append(TimelineMarker(
                    id: "buyout-\(index)",
                    day: day,
                    kind: .buyout,
                    title: state.rivals.rival(id: rivalID)?.name ?? "Sold",
                    detail: copy.line(for: event).message
                ))
            default:
                continue
            }
        }

        // The log is capped, so an incumbent founded a year ago may have
        // scrolled out of it; the rivals' own record still has the day.
        if !sawIncumbent, let day = state.rivals.incumbentFoundedDay {
            let name = state.rivals.incumbent?.name
                ?? state.rivals.rivals.first { $0.foundedDay == day }?.name
                ?? "The incumbent"
            markers.append(TimelineMarker(
                id: "incumbent-\(day)",
                day: day,
                kind: .incumbent,
                title: name,
                detail: "\(name) arrived in your best markets, with money to lose."
            ))
        }

        // How it ended.
        if let over = state.gameOver {
            markers.append(TimelineMarker(
                id: "ending",
                day: over.day,
                kind: .ending(over.kind),
                title: Self.endingTitle(over.kind),
                detail: over.reason
            ))
        }

        return markers.sorted { lhs, rhs in
            if lhs.day != rhs.day { return lhs.day < rhs.day }
            return lhs.id < rhs.id
        }
    }

    static func endingTitle(_ kind: EndingKind) -> String {
        switch kind {
        case .bankruptcy: "Bankrupt"
        case .acquired: "Acquired"
        case .ipo: "Went public"
        case .oustedByBoard: "Ousted"
        case .soldUp: "Sold up"
        case .independent: "Still yours"
        case .walkedAway: "Walked away"
        }
    }
}
