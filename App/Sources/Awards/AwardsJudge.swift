import Foundation
import TycoonContent
import TycoonEngine

// MARK: Iteration 8 — awards night and the Hall of Fame

/// Who won what at the year's ceremony. Judged over everything the
/// player and every rival launched that year, so a win means something.
struct AwardWinner: Equatable, Identifiable {
    let name: String
    let detail: String
    let isPlayer: Bool

    var id: String { name + detail }
}

struct AwardCategory: Identifiable {
    let title: String
    let winner: AwardWinner?

    var id: String { title }
}

struct AwardsNight: Equatable {
    let year: Int
    let categories: [AwardCategory]

    var playerWins: [AwardCategory] {
        categories.filter { $0.winner?.isPlayer == true }
    }

    static func == (lhs: AwardsNight, rhs: AwardsNight) -> Bool {
        lhs.year == rhs.year && lhs.categories.map(\.title) == rhs.categories.map(\.title)
            && lhs.categories.map(\.winner) == rhs.categories.map(\.winner)
    }
}

/// A launch in the year: the player's or a rival's.
private struct Launch {
    let studio: String
    let isPlayer: Bool
    let product: String
    let topicID: String
    let quality: Double
    let day: Int
}

enum AwardsJudge {
    /// The day of the year the ceremony is held: mid-December.
    static let ceremonyDayOfYear = 350
    /// A review this good gets a product into the Hall of Fame.
    static let hallThreshold = 85

    /// The ceremony's day for `year` (1-based).
    static func ceremonyDay(year: Int) -> Int {
        (year - 1) * DailyChallenge.horizonDays + ceremonyDayOfYear
    }

    /// The year (1-based) a day falls in.
    static func year(of day: Int) -> Int {
        day / DailyChallenge.horizonDays + 1
    }

    /// The ceremony for `year`, judged on `state`.
    static func judge(year: Int, state: GameState, content: ContentCatalog) -> AwardsNight {
        let first = (year - 1) * DailyChallenge.horizonDays
        let last = year * DailyChallenge.horizonDays
        let launches = self.launches(in: state, from: first, to: last)

        var categories: [AwardCategory] = []

        let best = launches.max { $0.quality < $1.quality }
        categories.append(AwardCategory(
            title: "Product of the Year",
            winner: best.map { AwardWinner(name: $0.product, detail: "\($0.studio) · \(Int($0.quality.rounded()))", isPlayer: $0.isPlayer) }
        ))

        // Studio of the Year: the studio whose year added up to the most,
        // quality summed over launches — shipping well, and shipping.
        let byStudio = Dictionary(grouping: launches, by: \.studio)
        let studio = byStudio.max { lhs, rhs in
            let l = lhs.value.reduce(0) { $0 + $1.quality }
            let r = rhs.value.reduce(0) { $0 + $1.quality }
            if l != r { return l < r }
            return lhs.key > rhs.key
        }
        categories.append(AwardCategory(
            title: "Studio of the Year",
            winner: studio.map { entry in
                AwardWinner(
                    name: entry.key,
                    detail: "\(entry.value.count) launch\(entry.value.count == 1 ? "" : "es")",
                    isPlayer: entry.value.first?.isPlayer == true
                )
            }
        ))

        // Best Newcomer: the best launch by a studio founded this year.
        let newcomers = launches.filter { launch in
            if launch.isPlayer { return year == 1 }
            return state.rivals.rivals.first { $0.name == launch.studio }.map { $0.foundedDay >= first && $0.foundedDay < last } ?? false
        }
        let newcomer = newcomers.max { $0.quality < $1.quality }
        categories.append(AwardCategory(
            title: "Best Newcomer",
            winner: newcomer.map { AwardWinner(name: $0.studio, detail: "for \($0.product)", isPlayer: $0.isPlayer) }
        ))

        for topic in content.topics {
            let inTopic = launches.filter { $0.topicID == topic.id }
            guard let winner = inTopic.max(by: { $0.quality < $1.quality }) else { continue }
            categories.append(AwardCategory(
                title: "Best in \(topic.name)",
                winner: AwardWinner(name: winner.product, detail: "\(winner.studio) · \(Int(winner.quality.rounded()))", isPlayer: winner.isPlayer)
            ))
        }
        return AwardsNight(year: year, categories: categories)
    }

    /// Every ceremony the run has reached, oldest first.
    static func allNights(state: GameState, content: ContentCatalog) -> [AwardsNight] {
        let years = (1...max(1, year(of: state.day))).filter { state.day >= ceremonyDay(year: $0) }
        return years.map { judge(year: $0, state: state, content: content) }
    }

    /// The player's wins across every ceremony reached, as biography lines.
    static func playerWinLines(state: GameState, content: ContentCatalog) -> [String] {
        allNights(state: state, content: content).flatMap { night in
            night.playerWins.map { "\($0.title), year \(night.year)" + ($0.winner.map { " — \($0.name)" } ?? "") }
        }
    }

    /// The player's products good enough for the hall, as ledger entries.
    static func hallEntries(state: GameState, content: ContentCatalog) -> [HallEntry] {
        state.products.compactMap { product in
            guard case .released(let release) = product.stage else { return nil }
            let score = reviewScore(release)
            guard score >= hallThreshold else { return nil }
            return HallEntry(
                id: product.id,
                productName: product.name,
                companyName: state.company.name,
                founderName: state.progression.founder.name,
                topicID: product.topicID,
                typeID: product.typeID,
                score: score,
                year: year(of: release.launchDay),
                seed: state.seed
            )
        }
    }

    static func reviewScore(_ release: ReleaseInfo) -> Int {
        guard !release.reviews.isEmpty else { return Int(release.quality.rounded()) }
        return release.reviews.reduce(0) { $0 + $1.score } / release.reviews.count
    }

    private static func launches(in state: GameState, from first: Int, to last: Int) -> [Launch] {
        var launches: [Launch] = []
        for product in state.products {
            guard case .released(let release) = product.stage,
                  release.launchDay >= first, release.launchDay < last
            else { continue }
            launches.append(Launch(
                studio: state.company.name, isPlayer: true, product: product.name,
                topicID: product.topicID, quality: Double(reviewScore(release)), day: release.launchDay
            ))
        }
        for rival in state.rivals.rivals {
            for product in rival.products where product.launchDay >= first && product.launchDay < last {
                launches.append(Launch(
                    studio: rival.name, isPlayer: false, product: product.name,
                    topicID: product.topicID, quality: product.quality, day: product.launchDay
                ))
            }
        }
        return launches
    }
}
