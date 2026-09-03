import TycoonContent
import TycoonEngine
import XCTest

@testable import StartupStudio

/// Every event the world produces has to come out the other side as a
/// sentence — in the journal, in a toast, on the pause banner. An event
/// with no line is an event the player never learns about.
final class EventCopyTests: XCTestCase {
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

    private func makeCopy() -> EventCopy {
        let state = GameState.newGame(
            companyName: "Fixture Softworks", seed: 7, balance: Self.balance, difficulty: .normal
        )
        return EventCopy(state: state, content: Self.content, balance: Self.balance)
    }

    /// One of every `GameEvent` case the scaffold ships. Cases added by
    /// another workstream fall through to `EventPresenter`, which is
    /// covered by the fallback test below.
    private var everyEvent: [GameEvent] {
        let id = UUID()
        return [
            .bankruptcyWarning(day: 1),
            .gameOver(day: 2),
            .productStarted(productID: id, day: 3),
            .shipped(productID: id, day: 4),
            .reviewsIn(productID: id, averageScore: 62, day: 5),
            .productOffMarket(productID: id, day: 6),
            .hired(employeeID: id, day: 7),
            .fired(employeeID: id, day: 8),
            .candidatesRefreshed(day: 9),
            .researchStarted(nodeID: "version_control", day: 10),
            .researchCompleted(nodeID: "version_control", day: 11),
            .contractOffersRefreshed(day: 12),
            .contractAccepted(contractID: id, day: 13),
            .contractCompleted(contractID: id, payout: 900, day: 14),
            .contractFailed(contractID: id, penalty: 400, day: 15),
            .campaignStarted(campaignID: id, day: 16),
            .officeUpgraded(tier: .loft, day: 17),
            .randomEvent(eventID: "unknown_event", day: 18),
            .lifeEvent(eventID: "unknown_life_event", day: 19),
            .founderAway(reason: "flu", untilDay: 25, day: 20),
            .founderBack(day: 26),
            .relationshipChanged(stage: .dating, day: 27),
            .breakup(day: 28),
            .childBorn(name: "Noor", day: 29),
            .homeUpgraded(tier: .apartment, day: 30),
            .weekendSpent(activity: .rest, day: 31),
            .marketBoom(topicID: "fitness", day: 32),
            .marketCrash(topicID: "fitness", day: 33),
            .employeeQuit(employeeID: id, name: "Sam", day: 34),
            .employeePromoted(employeeID: id, level: .senior, day: 35),
            .employeeDemoted(employeeID: id, level: .junior, day: 36),
            .salaryChanged(employeeID: id, weeklySalary: 1_200, day: 37),
            .employeeTrained(employeeID: id, day: 38),
            .contractDelivered(contractID: id, quality: 84, payout: 1_500, day: 39),
            .loanTaken(amount: 10_000, day: 40),
            .loanRepaid(amount: 2_000, day: 41),
            .amenityBuilt(amenity: .gameRoom, day: 42),
            .departmentFormed(department: .legal, day: 43),
            .departmentDissolved(department: .legal, day: 44),
            .rivalFounded(rivalID: id, name: "Lumen Labs", day: 45),
            .rivalShipped(rivalID: id, topicID: "fitness", day: 46),
            .rivalFolded(rivalID: id, name: "Lumen Labs", day: 47),
            .poachAttempt(
                rivalID: id, employeeID: id, offeredWeeklySalary: 1_800, respondByDay: 54, day: 48
            ),
            .poachDefeated(employeeID: id, day: 49),
            .employeePoached(employeeID: id, name: "Sam", rivalID: id, day: 50),
            .buyoutOffered(rivalID: id, amount: 250_000, respondByDay: 57, day: 51),
            .buyoutWithdrawn(rivalID: id, day: 52),
            .companySold(rivalID: id, amount: 250_000, day: 53),
            .rivalAcquired(rivalID: id, name: "Lumen Labs", hiresAbsorbed: 3, day: 54),
            .officeRelocated(district: .downtown, day: 55),
            .officeBought(district: .downtown, price: 90_000, day: 56),
            .officeSold(district: .downtown, price: 95_000, day: 57),
            .instantActivityDone(activity: .walk, day: 58),
            .itemPurchased(itemID: "unknown_item", day: 59),
            .socialActivity(kind: .coffee, employeeID: id, day: 60),
            .friendshipFormed(a: id, b: id, day: 61),
            .friendLostMorale(employeeID: id, day: 62),
            .staffBirthday(employeeID: id, day: 63),
            .staffEventOccurred(employeeID: id, kind: .rivalOfferRumor, respondByDay: 70, day: 64),
            .staffEventResolved(employeeID: id, choice: .supportive, day: 65),
            .familyDateMissed(eventID: "kid_birthday", day: 66),
        ]
    }

    func testEveryEventYieldsANonEmptyLine() {
        let copy = makeCopy()
        for event in everyEvent {
            let line = copy.line(for: event)
            XCTAssertFalse(line.message.isEmpty, "no message for \(event)")
            XCTAssertFalse(line.icon.isEmpty, "no icon for \(event)")
        }
    }

    func testEveryEventsLineCarriesItsOwnDay() {
        let copy = makeCopy()
        for event in everyEvent {
            XCTAssertEqual(
                copy.line(for: event).day,
                EventDay.of(event),
                "the line's day disagrees with the event's for \(event)"
            )
        }
    }

    func testUnknownIdsFallBackInsteadOfCrashing() {
        // Saves outlive content: an event can name a topic, tech, item or
        // life event the catalog no longer has.
        let copy = makeCopy()
        XCTAssertFalse(copy.line(for: .marketBoom(topicID: "gone", day: 1)).message.isEmpty)
        XCTAssertFalse(copy.line(for: .researchCompleted(nodeID: "gone", day: 1)).message.isEmpty)
        XCTAssertFalse(copy.line(for: .itemPurchased(itemID: "gone", day: 1)).message.isEmpty)
        XCTAssertFalse(copy.line(for: .lifeEvent(eventID: "gone", day: 1)).message.isEmpty)
    }

    /// A missed date reads as the date it was, from the diary's own line
    /// and the people in the founder's life (WS-E).
    func testAMissedDateNamesTheDateFromTheDiary() {
        var state = GameState.newGame(
            companyName: "Fixture Softworks", seed: 7, balance: Self.balance, difficulty: .normal
        )
        state.day = 400
        state.life.family.stage = .married
        state.life.family.partnerName = "Sam Ortega"
        state.life.family.children = [Child(id: UUID(), name: "Noor", bornDay: 30, appearanceSeed: 1)]
        let copy = EventCopy(state: state, content: Self.content, balance: Self.balance)

        XCTAssertEqual(
            copy.line(for: .familyDateMissed(eventID: "kid_birthday", day: 400)).message,
            "You missed Noor's birthday. They noticed."
        )
        XCTAssertEqual(
            copy.line(for: .familyDateMissed(eventID: "partner_anniversary", day: 400)).message,
            "You missed your anniversary with Sam. They noticed."
        )
        XCTAssertEqual(copy.category(of: .familyDateMissed(eventID: "kid_birthday", day: 400)), .life)
        // A date whose definition the catalog no longer knows still reads.
        XCTAssertEqual(
            copy.line(for: .familyDateMissed(eventID: "gone", day: 1)).message,
            "You missed a date you had promised. They noticed."
        )
    }

    func testCategoriesRouteEventsToTheRightJournalFilter() {
        let copy = makeCopy()
        XCTAssertEqual(copy.category(of: .breakup(day: 1)), .life)
        XCTAssertEqual(copy.category(of: .hired(employeeID: UUID(), day: 1)), .team)
        XCTAssertEqual(copy.category(of: .marketCrash(topicID: "fitness", day: 1)), .market)
        XCTAssertEqual(copy.category(of: .rivalFolded(rivalID: UUID(), name: "X", day: 1)), .rivals)
        XCTAssertEqual(copy.category(of: .officeUpgraded(tier: .loft, day: 1)), .company)
    }

    func testJournalCollapsesAWeeksRoutineIntoOneLine() {
        let copy = makeCopy()
        let entries = [
            JournalEntry(
                id: 3,
                event: .weekendSpent(activity: .gym, day: 13),
                line: copy.line(for: .weekendSpent(activity: .gym, day: 13)),
                category: .life,
                severity: .quiet
            ),
            JournalEntry(
                id: 2,
                event: .instantActivityDone(activity: .walk, day: 12),
                line: copy.line(for: .instantActivityDone(activity: .walk, day: 12)),
                category: .life,
                severity: .quiet
            ),
            JournalEntry(
                id: 1,
                event: .officeUpgraded(tier: .loft, day: 11),
                line: copy.line(for: .officeUpgraded(tier: .loft, day: 11)),
                category: .company,
                severity: .notable
            ),
        ]
        let rows = JournalBuilder.collapsingRoutine(entries)
        XCTAssertEqual(rows.count, 2, "the two routine lines collapse into one")
        guard case .routine(let week, let bundled) = rows[0] else {
            return XCTFail("expected the routine row first")
        }
        XCTAssertEqual(week, 2)
        XCTAssertEqual(bundled.count, 2)
        guard case .entry = rows[1] else {
            return XCTFail("the office upgrade must survive as its own line")
        }
    }

    // MARK: - Decision sheets

    /// The sheet prints the title big and the message underneath in grey.
    /// A definition with no `body` is snapshotted with the headline in
    /// both fields, and the sheet then says the same sentence twice — the
    /// bug this guards. The auto-answer line still gets through.
    func testANarrativeChoiceNeverRepeatsItsHeadlineAsItsBody() {
        var state = GameState.newGame(
            companyName: "Fixture Softworks", seed: 7, balance: Self.balance, difficulty: .normal
        )
        let headline = "Your family does Sunday lunch and has stopped expecting you."
        state.narrative.pendingChoice = PendingChoice(
            id: "sunday_lunch",
            source: .life,
            title: headline,
            body: headline,
            options: [
                ChoiceOption(id: "go", label: "Turn up unannounced", index: 0),
                ChoiceOption(id: "call", label: "Call instead", index: 1),
            ],
            respondByDay: state.day + 4,
            autoOptionIndex: 1,
            category: "life",
            raisedDay: state.day
        )

        guard let prompt = NarrativeChoicePresenter.prompt(
            for: state, content: Self.content, balance: Self.balance
        ) else {
            return XCTFail("a pending choice must reach the sheet")
        }
        XCTAssertEqual(prompt.title, headline)
        XCTAssertFalse(
            prompt.message.contains(headline),
            "the sheet printed its own title again as the body"
        )
        XCTAssertTrue(
            prompt.message.contains("Call instead"),
            "the deadline's answer still has to be spelled out"
        )
    }

    /// And a real body survives untouched.
    func testARealBodyIsShown() {
        var state = GameState.newGame(
            companyName: "Fixture Softworks", seed: 7, balance: Self.balance, difficulty: .normal
        )
        let body = "Nobody has said anything about it, which is worse."
        state.narrative.pendingChoice = PendingChoice(
            id: "sunday_lunch",
            source: .life,
            title: "Your family does Sunday lunch and has stopped expecting you.",
            body: body,
            options: [ChoiceOption(id: "go", label: "Turn up", index: 0)],
            respondByDay: state.day + 4,
            autoOptionIndex: 0,
            category: "life",
            raisedDay: state.day
        )
        let prompt = NarrativeChoicePresenter.prompt(
            for: state, content: Self.content, balance: Self.balance
        )
        XCTAssertEqual(prompt?.message.hasPrefix(body), true)
    }
}
