import TycoonContent
import TycoonEngine
import XCTest

@testable import StartupStudio

/// The timeline is read out of the state: every launch, hire, chapter,
/// round and blow lands on the day it happened, in order.
final class TimelineBuilderTests: XCTestCase {
    private func markers(_ state: GameState) -> [TimelineMarker] {
        TimelineBuilder.markers(state: state, content: StoryFixtures.content, balance: StoryFixtures.balance)
    }

    func testTheRunIsReadInOrderWithEveryKindOnItsDay() {
        let markers = markers(StoryFixtures.longRun())
        XCTAssertEqual(markers.map(\.day), markers.map(\.day).sorted())
        XCTAssertEqual(markers.first?.id, "founding")
        XCTAssertEqual(markers.first?.day, 0)
        XCTAssertEqual(markers.first?.title, "Northgate Softworks")

        func days(where match: (TimelineMarker.Kind) -> Bool) -> [Int] {
            markers.filter { match($0.kind) }.map(\.day)
        }
        XCTAssertEqual(days { if case .chapter = $0 { true } else { false } }, [90, 250, 420])
        XCTAssertEqual(days { if case .product = $0 { true } else { false } }, [60, 200, 380])
        XCTAssertEqual(days { if case .hire = $0 { true } else { false } }, [30, 75, 130, 200, 260, 330, 400, 470])
        XCTAssertEqual(days { if case .crash = $0 { true } else { false } }, [130])
        XCTAssertEqual(days { if case .round = $0 { true } else { false } }, [170])
        XCTAssertEqual(days { if case .incumbent = $0 { true } else { false } }, [300])
        XCTAssertEqual(days { if case .challengeHeld = $0 { true } else { false } }, [342])
        XCTAssertFalse(markers.contains { if case .ending = $0.kind { true } else { false } })
    }

    func testMarkersCarryTheirOwnCopy() {
        let markers = markers(StoryFixtures.longRun())
        let chord = markers.first { $0.title == "Chord" }
        XCTAssertEqual(chord?.detail, "Chord shipped: a web app in Music. Reviewed at 81.")
        let round = markers.first { if case .round = $0.kind { true } else { false } }
        XCTAssertEqual(round?.title, "Halcyon Ventures")
        XCTAssertEqual(round?.detail, "Halcyon Ventures put $400,000 in for 15.0%.")
        let held = markers.first { if case .challengeHeld = $0.kind { true } else { false } }
        XCTAssertEqual(held?.title, "Fitness")
        XCTAssertTrue(held?.detail.hasPrefix("You held Fitness") == true, held?.detail ?? "")
    }

    func testOnlyCrashesInMarketsTheStudioSellsIntoMakeTheLine() {
        var state = StoryFixtures.longRun()
        state.eventLog.append(.marketCrash(topicID: "dating", day: 200))
        state.eventLog.append(.marketCrash(topicID: "music", day: 210))
        let crashes = markers(state).filter { if case .crash = $0.kind { true } else { false } }
        XCTAssertEqual(crashes.map(\.day), [130, 210], "finance and music are sold into; dating is not")
    }

    func testTheIncumbentSurvivesTheLogBeingTrimmed() {
        var state = StoryFixtures.longRun()
        state.eventLog.removeAll {
            if case .incumbentArrived = $0 { true } else { false }
        }
        let markers = markers(state)
        let incumbent = markers.filter { if case .incumbent = $0.kind { true } else { false } }
        XCTAssertEqual(incumbent.map(\.day), [300])
        XCTAssertEqual(incumbent.first?.title, "Meridian Works")
    }

    func testTheEndingClosesTheLine() throws {
        var state = StoryFixtures.longRun()
        // The engine writes endings; from outside it the way in is the
        // save format.
        state.gameOver = try JSONDecoder().decode(
            GameOverInfo.self,
            from: Data(#"{"day":540,"reason":"Rang the bell.","kind":"ipo"}"#.utf8)
        )
        let markers = markers(state)
        XCTAssertEqual(markers.last?.id, "ending")
        XCTAssertEqual(markers.last?.title, "Went public")
        XCTAssertEqual(markers.last?.day, 540)
    }

    func testAFreshCompanyIsJustTheFounding() {
        let markers = markers(StoryFixtures.newState(day: 0))
        XCTAssertEqual(markers.map(\.id), ["founding"])
    }

    func testTheZoomsSpanAQuarterAYearOrTheRun() {
        XCTAssertEqual(TimelineZoom.quarter.daysAcross(spanDays: 547), 91)
        XCTAssertEqual(TimelineZoom.year.daysAcross(spanDays: 547), 364)
        XCTAssertEqual(TimelineZoom.run.daysAcross(spanDays: 547), 547)
        XCTAssertEqual(TimelineZoom.run.daysAcross(spanDays: 8), 28, "a day-old run is not a screen wide")
    }

    func testTheSidesOfTheLine() {
        XCTAssertTrue(TimelineMarker.Kind.product(typeID: "game", topicID: "gaming", seed: 1).isAboveBaseline)
        XCTAssertTrue(TimelineMarker.Kind.chapter(2).isAboveBaseline)
        XCTAssertFalse(TimelineMarker.Kind.hire(seed: 1, role: .qa).isAboveBaseline)
        XCTAssertFalse(TimelineMarker.Kind.crash(topicID: "finance").isAboveBaseline)
    }
}
