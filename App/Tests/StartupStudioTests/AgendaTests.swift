import SwiftUI
import TycoonContent
import TycoonEngine
import XCTest

@testable import StartupStudio

/// The agenda is the one screen that claims to know what the next
/// fortnight holds, so the query is tested against a fixture carrying one
/// of everything it can draw: a contract, a board review, an earn-out
/// review on the same tick, a build with an ETA, a diary date, a category
/// challenge, the rent and the loan's interest.
@MainActor
final class AgendaTests: XCTestCase {
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
        return bundled
    }()

    /// Day 180 is chosen so the quarterly review (every 91 days) lands on
    /// day 182, two days out — inside the fortnight, with the two weekly
    /// postings on 182 and 189 either side of it.
    static let today = 180

    /// A studio six months in with one of everything on its calendar.
    static func fixture() -> GameEngine {
        var state = GameState.newGame(
            companyName: "Northgate Softworks", seed: 4242, balance: balance,
            founder: FounderProfile(name: "Mira Okafor", archetype: .hacker, appearanceSeed: 0x5EED),
            content: content
        )
        state.day = today
        state.company.cash = 42_000
        state.company.officeTier = .loft

        // A crew, so the build has hands on it and the chart has branches.
        state.employees.append(contentsOf: [
            employee(name: "Dev Rao", role: .backend, level: .senior, bond: 72, hired: 40, seed: 11),
            employee(name: "Ana Beltrán", role: .designer, level: .mid, bond: 41, hired: 62, seed: 12),
            employee(name: "Kofi Mensah", role: .qa, level: .junior, bond: 18, hired: 120, seed: 13),
            employee(name: "Lena Fischer", role: .ops, level: .lead, bond: 60, hired: 30, seed: 14),
            employee(name: "Tom Alvi", role: .hr, level: .mid, bond: 34, hired: 90, seed: 15),
            employee(name: "Sara Nowak", role: .lawyer, level: .senior, bond: 25, hired: 150, seed: 16),
        ])

        // A build one point short of the ship gate, with the whole studio
        // on it — so the ETA is a day or two out rather than a season.
        let type = content.productType("mobile_app")
        let gate = balance.shipCodeThreshold * (type?.codePts ?? 100)
        let product = Product(
            id: UUID(), name: "Nimbus Notes", typeID: "mobile_app", topicID: "productivity",
            stage: .development(DevProgress(
                designPts: gate, codePts: gate - 1, polishPts: gate / 2,
                openBugs: 3, focus: .balanced, hype: 20
            ))
        )
        state.products.append(product)
        for index in state.employees.indices {
            state.employees[index].assignment = .product(product.id)
        }

        // A contract due in six days.
        state.activeContracts.append(
            ContractJob(
                id: UUID(), clientName: "Harbour Dental",
                requiredCodePts: 60, requiredDesignPts: 30,
                progressCode: 42, progressDesign: 24,
                deadlineDay: today + 6, payout: 9_000, penalty: 2_000,
                acceptedDay: today - 8, requiredSkill: 40,
                skillDaySum: 480, skillDays: 10
            )
        )

        // A board seat, and an acquirer holding the same review tick.
        state.investors.rounds.append(
            RaisedRound(
                investorID: "seed_partner", investorName: "Fenwick Seed",
                amount: 250_000, equity: 12, valuation: 2_000_000, day: 120,
                takesBoardSeat: true, expects: .shipCadence
            )
        )
        state.investors.boardPressure = 44
        state.investors.earnOut = EarnOut(
            buyerName: "Cobalt Interactive", buyerRivalID: UUID(),
            price: 900_000, paid: 540_000, expectation: .profitability,
            remainingReviews: 2, patienceWeeks: 12
        )

        // A rival challenging a category, settling in eight days.
        let challenger = Rival(
            id: UUID(), name: "Quillwork", strength: 62, reputation: 55,
            focusTopicIDs: ["productivity"], foundedDay: 30, appearanceSeed: 0xC0FFEE
        )
        state.rivals.rivals.append(challenger)
        state.rivals.challenges.append(
            CategoryChallenge(
                rivalID: challenger.id, topicID: "productivity",
                productName: "Quill", quality: 74,
                startedDay: today - 13, settlesDay: today + 8
            )
        )

        // The diary: an anniversary five days out.
        state.life.family.stage = .married
        state.life.family.partnerName = "Priya Raman"
        state.life.family.partnerAppearanceSeed = 0xB0B
        state.narrative.scheduled.append(
            ScheduledNarrativeEvent(day: today + 5, eventID: "partner_anniversary", source: .life)
        )

        // The bank.
        state.loanBalance = 15_000

        return GameEngine(state: state, balance: balance, content: content)
    }

    static func employee(
        name: String, role: EmployeeRole, level: SeniorityLevel,
        bond: Double, hired: Int, seed: UInt64
    ) -> Employee {
        Employee(
            id: UUID(), name: name,
            skills: SkillSet(coding: 62, design: 48, marketing: 30),
            weeklySalary: 1_400, assignment: .idle, isFounder: false,
            hiredDay: hired, appearanceSeed: seed, morale: 70, level: level,
            role: role, founderBond: bond
        )
    }

    private func items() -> [AgendaItem] {
        let engine = Self.fixture()
        return Agenda.items(in: engine.state, balance: engine.balance, content: engine.content)
    }

    // MARK: - The query

    func testTheFortnightHoldsOneOfEverything() {
        let engine = Self.fixture()
        let items = Agenda.items(
            in: engine.state, balance: engine.balance, content: engine.content
        )
        let kinds = Set(items.map(\.kind))
        for kind in [
            AgendaItem.Kind.contract, .ship, .board, .earnOut, .challenge, .diary, .money,
        ] {
            XCTAssertTrue(kinds.contains(kind), "the fixture should produce a \(kind) row")
        }
    }

    func testEveryRowLandsInsideTheFortnight() {
        let engine = Self.fixture()
        let today = engine.state.day
        let items = Agenda.items(
            in: engine.state, balance: engine.balance, content: engine.content
        )
        XCTAssertFalse(items.isEmpty)
        for item in items {
            XCTAssertGreaterThanOrEqual(item.day, today, "\(item.id) is in the past")
            XCTAssertLessThan(item.day, today + Agenda.horizonDays, "\(item.id) is past the horizon")
        }
    }

    func testTheRowsAreSortedByDayThenByWhatMattersFirst() {
        let items = items()
        for (lhs, rhs) in zip(items, items.dropFirst()) {
            XCTAssertLessThanOrEqual(lhs.day, rhs.day, "\(lhs.id) sorts after \(rhs.id)")
            if lhs.day == rhs.day {
                XCTAssertLessThanOrEqual(lhs.kind.rank, rhs.kind.rank)
            }
        }
    }

    func testTheBoardAndTheAcquirerShareOneDay() {
        let items = items()
        let board = items.first { $0.kind == .board }
        let earnOut = items.first { $0.kind == .earnOut }
        XCTAssertEqual(board?.day, Self.today + 2, "the quarter closes on day 182")
        XCTAssertEqual(earnOut?.day, board?.day, "the acquirer grades the same tick the board does")
        XCTAssertEqual(board?.route, .investors)
        XCTAssertEqual(earnOut?.route, .investors)
    }

    func testTheBuildIsDatedByItsOwnETA() {
        let engine = Self.fixture()
        let eta = engine.state.shipETAs(balance: engine.balance, content: engine.content).first
        let ship = Agenda.items(
            in: engine.state, balance: engine.balance, content: engine.content
        ).first { $0.kind == .ship }
        XCTAssertNotNil(eta)
        XCTAssertEqual(ship?.day, eta?.day)
        XCTAssertEqual(ship?.route, .product(eta?.productID ?? UUID()))
    }

    func testTheWeeklyChargesPostOnEverySeventhDay() {
        let items = items().filter { $0.kind == .money }
        let days = Set(items.map(\.day))
        XCTAssertEqual(days, [182, 189], "a fortnight holds two weekly postings")
        XCTAssertTrue(items.contains { $0.title == "Office rent" })
        XCTAssertTrue(items.contains { $0.title == "Loan interest" })
        for item in items {
            XCTAssertEqual(item.route, .finances)
        }
    }

    func testTheDiaryLineIsTheOneTheFamilyCardReads() {
        let engine = Self.fixture()
        let next = engine.state.nextFamilyDate(content: engine.content)
        let diary = Agenda.items(
            in: engine.state, balance: engine.balance, content: engine.content
        ).first { $0.kind == .diary }
        XCTAssertEqual(diary?.title, next?.label)
        XCTAssertEqual(diary?.day, next?.day)
        XCTAssertEqual(diary?.title, "Your anniversary with Priya")
    }

    func testAFreshCompanyHasAQuietFortnight() {
        let engine = GameEngine.newGame(companyName: "Quiet Co", seed: 7, difficulty: .normal)
        let items = Agenda.items(
            in: engine.state, balance: engine.balance, content: engine.content
        )
        XCTAssertTrue(
            items.allSatisfy { $0.kind == .money },
            "day one owes rent and nothing else: \(items.map(\.id))"
        )
    }

    func testEveryRowHasAUniqueIdentity() {
        let items = items()
        XCTAssertEqual(Set(items.map(\.id)).count, items.count, "two rows share an id")
    }

    // MARK: - Evenings

    func testTheEveningsLeftThisWeekFillForwardFromToday() {
        let engine = Self.fixture()
        let free = Agenda.freeEveningDays(in: engine.state, balance: engine.balance)
        let left = engine.state.eveningsLeftThisWeek(engine.balance) ?? 0
        let allowance = engine.balance.life.evenings(for: engine.state.life.schedule) ?? 0
        XCTAssertGreaterThan(left, 0, "the fixture's schedule should leave evenings")

        let thisWeek = Agenda.eveningWeek(of: engine.state.day)
        let takenThisWeek = free.filter { Agenda.eveningWeek(of: $0) == thisWeek }
        XCTAssertEqual(takenThisWeek.count, min(left, 7))
        XCTAssertEqual(
            takenThisWeek.sorted().first, engine.state.day,
            "the next free night is tonight"
        )
        for day in Agenda.days(from: engine.state.day)
        where Agenda.eveningWeek(of: day) != thisWeek {
            // Every later week starts full.
            XCTAssertLessThanOrEqual(
                free.filter { Agenda.eveningWeek(of: $0) == Agenda.eveningWeek(of: day) }.count,
                allowance
            )
        }
    }

    func testAWeekWithNoEveningsLeftShowsNoPips() {
        let engine = Self.fixture()
        var state = engine.state
        let allowance = engine.balance.life.evenings(for: state.life.schedule) ?? 0
        state.life.eveningsSpentThisWeek = allowance
        let free = Agenda.freeEveningDays(in: state, balance: engine.balance)
        let thisWeek = Agenda.eveningWeek(of: state.day)
        XCTAssertTrue(
            free.allSatisfy { Agenda.eveningWeek(of: $0) != thisWeek },
            "a spent week has no nights left in it"
        )
        XCTAssertFalse(free.isEmpty, "next week is still the founder's own")
    }
}
