import Foundation
import Testing
import TycoonEngine

/// The game's calendar: twelve months over the engine's 364-day year, in a
/// 30 / 30 / 31 pattern so every quarter is exactly 91 days.
@Suite("Game calendar")
struct GameCalendarTests {
    @Test func dayZeroIsTheFirstOfJanuaryYearOne() {
        let calendar = GameCalendar(day: 0)
        #expect(calendar.year == 1)
        #expect(calendar.monthIndex == 0)
        #expect(calendar.monthName == "January")
        #expect(calendar.dayOfMonth == 1)
        #expect(calendar.quarter == 1)
        #expect(calendar.weekOfYear == 1)
        #expect(calendar.season == .winter)
        #expect(calendar.shortLabel == "1 Jan · Y1")
    }

    @Test func theMonthsRunThirtyThirtyThirtyOne() {
        #expect(GameCalendar.monthLengths.reduce(0, +) == 364)
        // The last day of January, then the first of February.
        #expect(GameCalendar(day: 29).dayOfMonth == 30)
        #expect(GameCalendar(day: 29).monthIndex == 0)
        #expect(GameCalendar(day: 30).dayOfMonth == 1)
        #expect(GameCalendar(day: 30).monthName == "February")
        // March is the long one.
        #expect(GameCalendar(day: 60).monthName == "March")
        #expect(GameCalendar(day: 90).monthName == "March")
        #expect(GameCalendar(day: 90).dayOfMonth == 31)
        #expect(GameCalendar(day: 91).monthName == "April")
    }

    @Test func everyQuarterIsExactlyNinetyOneDays() {
        for quarter in 1...4 {
            let first = GameCalendar(day: (quarter - 1) * 91)
            let last = GameCalendar(day: quarter * 91 - 1)
            #expect(first.quarter == quarter)
            #expect(last.quarter == quarter)
        }
        #expect(GameCalendar(day: 364).year == 2)
        #expect(GameCalendar(day: 364).monthIndex == 0)
        #expect(GameCalendar(day: 364).quarterLabel == "Q1 Y2")
    }

    @Test func theWeekendIsTheLastTwoDaysOfTheWeek() {
        let weekend = (0..<14).filter { GameCalendar(day: $0).isWeekend }
        #expect(weekend == [5, 6, 12, 13])
        for day in 0..<14 {
            #expect(GameCalendar(day: day).dayOfWeek == day % 7 + 1)
        }
    }

    @Test func theSeasonsFollowTheMonths() {
        #expect(GameCalendar(day: 0).season == .winter)      // January
        #expect(GameCalendar(day: 60).season == .spring)     // March
        #expect(GameCalendar(day: 152).season == .summer)    // June
        #expect(GameCalendar(day: 243).season == .autumn)    // September
        #expect(GameCalendar(day: 334).season == .winter)    // December
    }

    @Test func theCalendarAgreesWithTheEnginesOwnYearAndWeek() throws {
        let balance = TestBalance.make()
        var state = GameState.newGame(companyName: "Acme", seed: 1, balance: balance)
        for day in [0, 1, 45, 200, 363, 364, 500, 900] {
            state.day = day
            #expect(state.calendar.year == state.year, "day \(day)")
            #expect(state.calendar.weekOfYear == state.weekOfYear, "day \(day)")
            #expect(state.calendar.dayOfWeek == state.dayOfWeek, "day \(day)")
        }
    }

    @Test func negativeDaysClampToTheFirstDay() {
        #expect(GameCalendar(day: -5) == GameCalendar(day: 0))
    }
}
