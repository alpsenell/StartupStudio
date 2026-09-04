import TycoonContent
import TycoonEngine
import XCTest

@testable import StartupStudio

/// The front page is composed from the journal, the market, the rivals
/// and the office, and nothing else — so what it says can be read back
/// against the state it was built from.
final class NewspaperComposerTests: XCTestCase {
    private func composer(_ state: GameState) -> NewspaperComposer {
        NewspaperComposer(state: state, content: StoryFixtures.content, balance: StoryFixtures.balance)
    }

    // MARK: - The newsstand

    func testTheNewsstandHoldsTheLastFourCompletedWeeks() {
        let issues = composer(StoryFixtures.fourWeeks()).issues()
        XCTAssertEqual(issues.map(\.week), [1, 2, 3, 4])
        XCTAssertEqual(issues.map(\.dayRange), [0...6, 7...13, 14...20, 21...27])
        XCTAssertEqual(issues.map(\.publishedDay), [7, 14, 21, 28])
        XCTAssertFalse(issues.contains(where: \.isInProgress))
    }

    func testOnlyCompletedWeeksGoToPrintUntilTheFirstOneIsOver() {
        // Day 10: week 1 is done, week 2 is half lived and not yet printed.
        let tenDays = composer(StoryFixtures.newState(day: 10)).issues()
        XCTAssertEqual(tenDays.map(\.week), [1])
        XCTAssertFalse(tenDays[0].isInProgress)

        // Day 3: nothing has completed, so week 1 is on the stand as it
        // stands, dated today.
        let threeDays = composer(StoryFixtures.newState(day: 3)).issues()
        XCTAssertEqual(threeDays.map(\.week), [1])
        XCTAssertTrue(threeDays[0].isInProgress)
        XCTAssertEqual(threeDays[0].dayRange, 0...3)
        XCTAssertEqual(threeDays[0].publishedDay, 3)

        // Day 63: nine weeks in, the stand holds the last four.
        let nineWeeks = composer(StoryFixtures.newState(day: 63)).issues()
        XCTAssertEqual(nineWeeks.map(\.week), [6, 7, 8, 9])
    }

    func testTheDatelineIsTheMondayAfterTheWeek() {
        let issues = composer(StoryFixtures.fourWeeks()).issues()
        for issue in issues {
            XCTAssertTrue(issue.dateline.hasPrefix("Monday, "), issue.dateline)
        }
        XCTAssertEqual(issues[3].dateline, "Monday, January 29, Year 1")
        // Numbered by the week covered, not the week it prints in.
        XCTAssertEqual(issues[3].edition, "Vol. 1 · No. 4")
        XCTAssertEqual(issues[0].edition, "Vol. 1 · No. 1")

        let midweek = composer(StoryFixtures.newState(day: 3)).issues()[0]
        XCTAssertTrue(midweek.dateline.hasPrefix("Thursday, "), midweek.dateline)
    }

    // MARK: - The lead

    func testTheLeadIsTheWeeksLoudestCompanyEvent() {
        let issues = composer(StoryFixtures.fourWeeks()).issues()

        // Week 4: the reviews (notable, company) beat the crash and the
        // incumbent (notable, but the world's news) and the birthday.
        XCTAssertEqual(issues[3].lead.headline, "Reviews are in for Overcast")
        XCTAssertEqual(issues[3].lead.body, "Reviews are in for Overcast: 72")
        XCTAssertEqual(issues[3].lead.kicker, "Company")
        XCTAssertEqual(issues[3].lead.severity, .notable)
        XCTAssertEqual(issues[3].lead.day, 23)

        // Week 3: a chapter opening outranks the launch and the round.
        XCTAssertEqual(issues[2].lead.severity, .notable)
        XCTAssertTrue(issues[2].lead.body.hasPrefix("Chapter 2:"), issues[2].lead.body)

        // Week 2: at equal severity the company's own strand leads the
        // team's, and the boom stays in the market column.
        XCTAssertEqual(issues[1].lead.headline, "Delivered for a client")
        XCTAssertFalse(issues[1].lead.body.contains("booming"))
    }

    func testTheWorldLeadsOnlyWhenTheCompanyHasNothingOfItsOwn() {
        var state = StoryFixtures.newState(day: 7)
        state.eventLog = [
            .marketBoom(topicID: "fitness", day: 2),
            .weekendSpent(activity: .rest, day: 5),
        ]
        let issue = composer(state).issues()[0]
        XCTAssertEqual(issue.lead.kicker, "Market")
        XCTAssertEqual(issue.lead.headline, "Fitness market is booming!")
    }

    func testAQuietWeekStillHasAFrontPage() {
        let issue = composer(StoryFixtures.newState(day: 0)).issues()[0]
        XCTAssertEqual(issue.lead.severity, .quiet)
        XCTAssertEqual(issue.lead.headline, "A quiet week at Northgate Softworks")
        XCTAssertTrue(issue.lead.body.contains("opened its doors"), issue.lead.body)
        XCTAssertEqual(issue.smallPrint, [])
        XCTAssertEqual(issue.rivalColumn.lines, ["No rival studios on the board yet."])
        XCTAssertEqual(issue.marketColumn.lines, ["Markets held steady. Nothing boomed, nothing crashed."])
    }

    func testTheWeeklyRefreshNoticesNeverLead() {
        var state = StoryFixtures.newState(day: 7)
        state.eventLog = [.candidatesRefreshed(day: 1), .contractOffersRefreshed(day: 3)]
        let issue = composer(state).issues()[0]
        XCTAssertEqual(issue.lead.severity, .quiet)
        XCTAssertEqual(issue.lead.headline, "A quiet week at Northgate Softworks")
        XCTAssertEqual(issue.smallPrint, ["New candidates are looking for work", "New clients are asking around"])
    }

    func testTheFoundersLifeIsNotNews() {
        var state = StoryFixtures.newState(day: 7)
        state.eventLog = [.breakup(day: 3), .hired(employeeID: UUID(), day: 4)]
        let issue = composer(state).issues()[0]
        XCTAssertEqual(issue.lead.kicker, "Team")
        XCTAssertFalse(issue.smallPrint.contains { $0.contains("single") })
    }

    // MARK: - The columns

    func testTheColumnsCarryTheirOwnStrands() {
        let issues = composer(StoryFixtures.fourWeeks()).issues()

        XCTAssertEqual(issues[0].rivalColumn.title, "Rivals")
        XCTAssertTrue(issues[0].rivalColumn.lines.contains("Lumen Labs entered the scene"))
        XCTAssertTrue(issues[2].rivalColumn.lines.contains("Lumen Labs shipped a Fitness product"))
        XCTAssertTrue(
            issues[3].rivalColumn.lines.contains { $0.hasPrefix("Meridian Works arrived") },
            issues[3].rivalColumn.lines.description
        )

        XCTAssertEqual(issues[1].marketColumn.title, "Market")
        XCTAssertTrue(issues[1].marketColumn.lines.contains("Fitness market is booming!"))
        XCTAssertTrue(issues[3].marketColumn.lines.contains("Finance market crashed"))
    }

    func testTheRivalColumnFallsBackToTheStandingOfTheField() {
        let issues = composer(StoryFixtures.fourWeeks()).issues()
        // Week 2 had no rival news: the column names the incumbent as it
        // stands today.
        XCTAssertEqual(issues[1].rivalColumn.lines, ["Meridian Works is still camped in your best markets."])

        var state = StoryFixtures.fourWeeks()
        state.rivals.rivals.removeAll { $0.isIncumbent }
        state.rivals.incumbentFoundedDay = nil
        let alone = composer(state).issues()[1]
        XCTAssertEqual(alone.rivalColumn.lines, ["Lumen Labs is the only other studio in town."])
    }

    func testOnlyTheLatestIssueReadsTheForwardBook() {
        let issues = composer(StoryFixtures.fourWeeks()).issues()
        let forecast = issues[3].marketColumn.lines.first { $0.hasPrefix("Fitness looks") }
        XCTAssertNotNil(forecast, issues[3].marketColumn.lines.description)
        XCTAssertTrue(forecast?.contains("×") == true, forecast ?? "")
        XCTAssertFalse(issues[1].marketColumn.lines.contains { $0.hasPrefix("Fitness looks") })

        // No standing, no read.
        var state = StoryFixtures.fourWeeks()
        state.market.standing = [:]
        XCTAssertFalse(composer(state).issues()[3].marketColumn.lines.contains { $0.hasPrefix("Fitness looks") })
    }

    // MARK: - Small print

    func testTheSmallPrintHoldsTheQuietEventsAndNotTheLead() {
        let issues = composer(StoryFixtures.fourWeeks()).issues()
        let week1 = issues[0].smallPrint
        XCTAssertTrue(week1.contains("A new framework is announced. It is fine."), week1.description)
        XCTAssertTrue(week1.contains("New candidates are looking for work"), week1.description)
        XCTAssertTrue(week1.contains("Weekend spent on rest"), week1.description)
        XCTAssertFalse(week1.contains(issues[0].lead.body))

        // Nothing notable or critical is small print.
        let week4 = issues[3].smallPrint
        XCTAssertFalse(week4.contains { $0.contains("Reviews are in") })
        XCTAssertFalse(week4.contains { $0.contains("crashed") })
        XCTAssertTrue(week4.contains { $0.contains("birthday") }, week4.description)
    }

    // MARK: - The photo

    func testThePhotoShowsWhoWasThereByThen() {
        let issues = composer(StoryFixtures.fourWeeks()).issues()
        XCTAssertEqual(issues[0].photo.scene.occupants.count, 2, "the founder and Priya, hired on day 5")
        XCTAssertEqual(issues[1].photo.scene.occupants.count, 3)
        XCTAssertEqual(issues[3].photo.scene.occupants.count, 4)
        XCTAssertTrue(issues[0].photo.scene.occupants[0].isFounder)
        XCTAssertTrue(issues[3].photo.scene.reduceMotion, "a photograph is a still")
        XCTAssertEqual(issues[3].photo.scene.ambience.timeOfDay, .day)
        XCTAssertTrue(issues[3].photo.caption.contains("4 at their desks"), issues[3].photo.caption)
    }

    func testACriticalWeekIsPhotographedAtDusk() {
        var state = StoryFixtures.fourWeeks()
        state.eventLog.append(.employeeQuit(employeeID: StoryFixtures.devID, name: "Dev", day: 25))
        let issue = composer(state).issues()[3]
        XCTAssertEqual(issue.lead.severity, .critical)
        XCTAssertEqual(issue.lead.headline, "Dev quit")
        XCTAssertEqual(issue.photo.scene.ambience.timeOfDay, .dusk)
    }

    // MARK: - Determinism

    func testAnIssueIsAPureFunctionOfTheState() {
        let state = StoryFixtures.fourWeeks()
        let first = composer(state).issues()
        let second = composer(state).issues()
        XCTAssertEqual(first, second)
        XCTAssertEqual(composer(state).issue(forWeek: 3), first[2])
    }

    // MARK: - Headlines

    func testHeadlinesAreTheFirstClauseInTheGlyphsTheFaceHas() {
        XCTAssertEqual(Headline.compress("Priya quit — morale hit rock bottom"), "Priya quit")
        XCTAssertEqual(Headline.compress("Reviews are in for Overcast: 72"), "Reviews are in for Overcast")
        XCTAssertEqual(Headline.compress("Shipped Overcast!"), "Shipped Overcast!")
        XCTAssertEqual(Headline.compress("Moved into the loft!"), "Moved into the loft!")
        XCTAssertEqual(Headline.compress("Delivered for Acme: +$1,500 — client delighted"), "Delivered for Acme")
        XCTAssertEqual(Headline.compress("It’s over. You’re single again"), "It's over")
        XCTAssertEqual(Headline.compress("Café opened"), "Caf opened", "a glyph the face lacks is dropped, not boxed")
        let long = Headline.compress("Halcyon Ventures put a great deal of money into the company for a stake")
        XCTAssertLessThanOrEqual(long.count, Headline.maxLength)
        XCTAssertFalse(long.hasSuffix(" "))
        XCTAssertEqual(Headline.compress(""), "News")
        for character in Headline.compress("Second hospital stay this year — the doctor calls it chronic.") {
            XCTAssertTrue(PixelFont.hasGlyph(for: character), "no glyph for '\(character)'")
        }
    }
}
