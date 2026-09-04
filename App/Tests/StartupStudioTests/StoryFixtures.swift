import Foundation
import TycoonContent
import TycoonEngine

@testable import StartupStudio

/// Hand-built runs for the story screens: four weeks of a company with
/// a few weeks' worth of events on the log, and a year and a half of one
/// for the timeline. Built once, by hand, so a test can name the day a
/// thing happened and read it back off the page.
enum StoryFixtures {
    static let content: ContentCatalog = {
        guard let bundled = try? ContentCatalog.loadBundled() else {
            fatalError("TycoonContent is missing its bundled resources")
        }
        return bundled
    }()

    static let balance: BalanceConfig = {
        guard let bundled = try? BalanceConfig.loadBundled() else {
            fatalError("TycoonEngine is missing its bundled Balance.json resource")
        }
        return bundled.adjusted(for: .normal)
    }()

    // Stable ids, so the log and the state agree without a lookup.
    static let priyaID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    static let devID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
    static let inesID = UUID(uuidString: "00000000-0000-0000-0000-000000000003")!
    static let overcastID = UUID(uuidString: "00000000-0000-0000-0000-000000000010")!
    static let chordID = UUID(uuidString: "00000000-0000-0000-0000-000000000011")!
    static let lumenID = UUID(uuidString: "00000000-0000-0000-0000-000000000020")!
    static let meridianID = UUID(uuidString: "00000000-0000-0000-0000-000000000021")!

    static func newState(day: Int) -> GameState {
        var state = GameState.newGame(
            companyName: "Northgate Softworks",
            seed: 4242,
            balance: balance,
            founder: FounderProfile(name: "Mira Okafor", archetype: .hacker, appearanceSeed: 0x5EED)
        )
        state.day = day
        return state
    }

    static func staffer(_ id: UUID, _ name: String, role: EmployeeRole, hiredDay: Int, seed: UInt64, morale: Double = 72) -> Employee {
        Employee(
            id: id,
            name: name,
            skills: SkillSet(coding: 50, design: 40, marketing: 20),
            weeklySalary: 900,
            assignment: .idle,
            isFounder: false,
            hiredDay: hiredDay,
            appearanceSeed: seed,
            morale: morale,
            role: role
        )
    }

    static func released(_ id: UUID, _ name: String, typeID: String, topicID: String, launchDay: Int, score: Int) -> Product {
        Product(
            id: id, name: name, typeID: typeID, topicID: topicID,
            stage: .released(ReleaseInfo(
                launchDay: launchDay, quality: Double(score),
                reviews: ["TechDaily", "AppVerdict", "The Stack Review", "ByteSized"].map {
                    Review(outlet: $0, score: score, blurb: "Polished where it counts.")
                },
                weeklySales: [], offMarket: false
            ))
        )
    }

    /// Four weeks in (day 28): three hires, one launch with its reviews,
    /// a round, a chapter, a boom, a crash, a rival on the board and the
    /// incumbent arriving in the last week.
    static func fourWeeks() -> GameState {
        var state = newState(day: 28)
        state.employees += [
            staffer(priyaID, "Priya", role: .backend, hiredDay: 5, seed: 21),
            staffer(devID, "Dev", role: .designer, hiredDay: 12, seed: 34),
            staffer(inesID, "Ines", role: .qa, hiredDay: 20, seed: 55),
        ]
        state.products = [
            released(overcastID, "Overcast", typeID: "mobile_app", topicID: "fitness", launchDay: 16, score: 72),
        ]
        state.rivals.rivals = [
            Rival(
                id: lumenID, name: "Lumen Labs", strength: 40, reputation: 30,
                focusTopicIDs: ["fitness"], lastShippedDay: 17, foundedDay: 3, appearanceSeed: 0xA11
            ),
            Rival(
                id: meridianID, name: "Meridian Works", strength: 95, reputation: 72,
                focusTopicIDs: ["fitness", "music"], foundedDay: 24, appearanceSeed: 0xBEEF,
                personality: .deepPockets, isIncumbent: true
            ),
        ]
        state.rivals.incumbentFoundedDay = 24
        state.market.standing["fitness"] = 78
        state.market.recentEvents = [
            MarketEvent(day: 9, topicID: "fitness", kind: .boom),
            MarketEvent(day: 23, topicID: "finance", kind: .crash),
        ]
        state.investors.rounds = [
            RaisedRound(
                investorID: "halcyon", investorName: "Halcyon Ventures", amount: 150_000, equity: 12.5,
                valuation: 1_200_000, day: 18, takesBoardSeat: true, expects: .shipCadence
            ),
        ]
        state.progression.chapterLog = [ChapterEntry(chapter: 1, day: 0), ChapterEntry(chapter: 2, day: 14)]
        state.progression.chapter = 2
        let contract = UUID()
        state.eventLog = [
            // Week 1: days 0…6.
            .candidatesRefreshed(day: 1),
            .industryNews(headline: "A new framework is announced. It is fine.", day: 2),
            .rivalFounded(rivalID: lumenID, name: "Lumen Labs", day: 3),
            .productStarted(productID: overcastID, day: 4),
            .hired(employeeID: priyaID, day: 5),
            .weekendSpent(activity: .rest, day: 5),
            // Week 2: days 7…13.
            .socialActivity(kind: .coffee, employeeID: priyaID, day: 8),
            .marketBoom(topicID: "fitness", day: 9),
            .industryNews(headline: "Conference season starts. Half the industry is in a hotel lobby.", day: 10),
            .contractDelivered(contractID: contract, quality: 84, payout: 1_500, day: 11),
            .hired(employeeID: devID, day: 12),
            .weekendSpent(activity: .gym, day: 12),
            // Week 3: days 14…20.
            .chapterReached(chapter: 2, day: 14),
            .goalCompleted(goalID: "ship_first_product", day: 14),
            .industryNews(headline: "A salary report leaks. Engineers are reading it at their desks.", day: 15),
            .shipped(productID: overcastID, day: 16),
            .rivalShipped(rivalID: lumenID, topicID: "fitness", day: 17),
            .investmentAccepted(investorID: "halcyon", amount: 150_000, equity: 12.5, day: 18),
            .hired(employeeID: inesID, day: 20),
            // Week 4: days 21…27.
            .reviewsIn(productID: overcastID, averageScore: 72, day: 23),
            .marketCrash(topicID: "finance", day: 23),
            .incumbentArrived(rivalID: meridianID, name: "Meridian Works", day: 24),
            .staffBirthday(employeeID: devID, day: 25),
            .weekendSpent(activity: .rest, day: 26),
            .industryNews(headline: "Cloud prices go up 8 percent and everyone's margins go with them.", day: 27),
        ]
        return state
    }

    /// A year and a half in (day 540): eight hires spread over the run,
    /// three launches, four chapters, a crash, a round, the incumbent
    /// and a challenge held.
    static func longRun() -> GameState {
        var state = newState(day: 540)
        let hires: [(UUID, String, EmployeeRole, Int, UInt64)] = [
            (priyaID, "Priya", .backend, 30, 21),
            (devID, "Dev", .designer, 75, 34),
            (inesID, "Ines", .qa, 130, 55),
            (UUID(uuidString: "00000000-0000-0000-0000-000000000004")!, "Otto", .frontend, 200, 61),
            (UUID(uuidString: "00000000-0000-0000-0000-000000000005")!, "Suki", .marketer, 260, 77),
            (UUID(uuidString: "00000000-0000-0000-0000-000000000006")!, "Rafa", .backend, 330, 83),
            (UUID(uuidString: "00000000-0000-0000-0000-000000000007")!, "Wren", .lawyer, 400, 91),
            (UUID(uuidString: "00000000-0000-0000-0000-000000000008")!, "Yuki", .designer, 470, 99),
        ]
        state.employees += hires.map { staffer($0.0, $0.1, role: $0.2, hiredDay: $0.3, seed: $0.4) }
        state.products = [
            released(overcastID, "Overcast", typeID: "mobile_app", topicID: "fitness", launchDay: 60, score: 72),
            released(chordID, "Chord", typeID: "web_app", topicID: "music", launchDay: 200, score: 81),
            released(
                UUID(uuidString: "00000000-0000-0000-0000-000000000012")!, "Ledger",
                typeID: "saas_platform", topicID: "finance", launchDay: 380, score: 66
            ),
        ]
        state.rivals.rivals = [
            Rival(
                id: meridianID, name: "Meridian Works", strength: 95, reputation: 72,
                focusTopicIDs: ["fitness", "music"], foundedDay: 300, appearanceSeed: 0xBEEF,
                personality: .deepPockets, isIncumbent: true
            ),
        ]
        state.rivals.incumbentFoundedDay = 300
        state.investors.rounds = [
            RaisedRound(
                investorID: "halcyon", investorName: "Halcyon Ventures", amount: 400_000, equity: 15,
                valuation: 2_600_000, day: 170, takesBoardSeat: true, expects: .mrrGrowth
            ),
        ]
        state.progression.chapterLog = [
            ChapterEntry(chapter: 1, day: 0), ChapterEntry(chapter: 2, day: 90),
            ChapterEntry(chapter: 3, day: 250), ChapterEntry(chapter: 4, day: 420),
        ]
        state.progression.chapter = 4
        state.eventLog = [
            .marketCrash(topicID: "finance", day: 130),
            .investmentAccepted(investorID: "halcyon", amount: 400_000, equity: 15, day: 170),
            .incumbentArrived(rivalID: meridianID, name: "Meridian Works", day: 300),
            .categoryHeld(rivalID: meridianID, topicID: "fitness", day: 342),
        ]
        return state
    }
}
