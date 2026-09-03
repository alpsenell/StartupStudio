import TycoonContent
import TycoonEngine
import XCTest

@testable import StartupStudio

/// The three policy events (WS-D) as sentences: a rule made, a rule
/// answering, a rule taken back — in the Team journal, named from the
/// catalog, and still a line when the catalog has moved on.
final class StaffPolicyCopyTests: XCTestCase {
    private static let content: ContentCatalog = {
        guard let bundled = try? ContentCatalog.loadBundled() else {
            fatalError("TycoonContent is missing its bundled resources")
        }
        return bundled
    }()

    private static let balance: BalanceConfig = {
        guard let bundled = try? BalanceConfig.loadBundled() else {
            fatalError("TycoonEngine is missing its bundled Balance.json resource")
        }
        return bundled.adjusted(for: .normal)
    }()

    private func makeCopy() -> (EventCopy, Employee) {
        var state = GameState.newGame(
            companyName: "Fixture Softworks", seed: 7, balance: Self.balance, difficulty: .normal
        )
        let priya = Employee(
            id: UUID(), name: "Priya Nair",
            skills: SkillSet(coding: 50, design: 30, marketing: 20),
            weeklySalary: 900, assignment: .idle, isFounder: false, hiredDay: 0,
            appearanceSeed: 0xA11CE, role: .backend
        )
        state.employees.append(priya)
        return (EventCopy(state: state, content: Self.content, balance: Self.balance), priya)
    }

    func testARuleMadeAppliedAndReversedEachReadAsASentenceInTheTeamJournal() {
        let (copy, priya) = makeCopy()
        let set = copy.line(for: .staffPolicySet(flag: "good_leave_policy", employeeID: priya.id, day: 120))
        XCTAssertEqual(
            set.message,
            "Parental leave is the rule now: full pay, three months, written down — Priya Nair asked, and that was the answer"
        )
        XCTAssertEqual(set.day, 120)

        let applied = copy.line(for: .staffPolicyApplied(flag: "good_leave_policy", employeeID: priya.id, day: 300))
        XCTAssertEqual(applied.message, "Priya Nair — parental leave, by the rule: full pay, three months, written down")

        let strict = copy.line(for: .staffPolicyApplied(flag: "ip_strict", employeeID: priya.id, day: 301))
        XCTAssertEqual(strict.message, "Priya Nair — side projects, by the rule: remind them of the IP clause")

        let reversed = copy.line(for: .staffPolicyReversed(flag: "good_leave_policy", day: 400))
        XCTAssertEqual(reversed.message, "You reversed the parental leave rule — everyone heard")

        for event in [
            GameEvent.staffPolicySet(flag: "good_leave_policy", employeeID: priya.id, day: 1),
            .staffPolicyApplied(flag: "good_leave_policy", employeeID: priya.id, day: 2),
            .staffPolicyReversed(flag: "good_leave_policy", day: 3),
        ] {
            XCTAssertEqual(copy.category(of: event), .team, "\(event)")
        }
    }

    func testAFlagTheCatalogNoLongerNamesStillGetsALine() {
        let (copy, priya) = makeCopy()
        XCTAssertFalse(copy.line(for: .staffPolicySet(flag: "gone", employeeID: priya.id, day: 1)).message.isEmpty)
        XCTAssertFalse(copy.line(for: .staffPolicyApplied(flag: "gone", employeeID: priya.id, day: 1)).message.isEmpty)
        XCTAssertFalse(copy.line(for: .staffPolicyReversed(flag: "gone", day: 1)).message.isEmpty)
    }

    func testAStaffMomentReadsItsOwnTitleFromTheCatalog() {
        let (copy, priya) = makeCopy()
        let line = copy.line(for: .staffEventOccurred(employeeID: priya.id, kind: .parentalLeave, respondByDay: 5, day: 1))
        XCTAssertEqual(line.message, "Priya Nair is having a baby")
        let courted = copy.line(for: .staffEventOccurred(employeeID: priya.id, kind: .rivalOfferRumor, respondByDay: 5, day: 1))
        XCTAssertEqual(courted.message, "Priya Nair is being courted")
    }
}
