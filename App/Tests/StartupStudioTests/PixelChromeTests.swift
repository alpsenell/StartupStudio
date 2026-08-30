import TycoonEngine
import XCTest

@testable import StartupStudio

/// The bitmap font draws the HUD's cash and dates. A missing glyph shows
/// up as a hollow box on screen, so the coverage is worth asserting.
final class PixelFontTests: XCTestCase {
    /// Every character the chrome actually asks the font to draw.
    private static let requiredCharacters = Array(
        "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 $.,:-+/!?'%()×·▶♥★"
    )

    func testEveryRequiredCharacterHasAGlyph() {
        for character in Self.requiredCharacters {
            XCTAssertTrue(PixelFont.hasGlyph(for: character), "no glyph for '\(character)'")
        }
    }

    func testLowercaseFoldsToUppercase() {
        XCTAssertEqual(PixelFont.glyph(for: "a"), PixelFont.glyph(for: "A"))
        XCTAssertTrue(PixelFont.hasGlyph(for: "z"))
    }

    func testEveryGlyphIsExactlyFiveBySeven() {
        for (character, glyph) in PixelFont.glyphs {
            XCTAssertEqual(glyph.count, PixelFont.glyphHeight, "'\(character)' is not 7 rows")
            for row in glyph {
                XCTAssertEqual(row.count, PixelFont.glyphWidth, "'\(character)' has a bad row width")
            }
        }
    }

    func testGlyphsUseOnlyInkAndBlank() {
        for (character, glyph) in PixelFont.glyphs {
            for row in glyph {
                for pixel in row {
                    XCTAssertTrue(
                        pixel == "#" || pixel == " ",
                        "'\(character)' contains an unexpected pixel '\(pixel)'"
                    )
                }
            }
        }
    }

    func testWidthAccountsForTracking() {
        XCTAssertEqual(PixelFont.width(of: ""), 0)
        XCTAssertEqual(PixelFont.width(of: "A"), 5)
        XCTAssertEqual(PixelFont.width(of: "AB"), 11)
        XCTAssertEqual(PixelFont.width(of: "$12,400"), 7 * 5 + 6)
    }

    func testUnknownCharactersRenderTheMissingBox() {
        XCTAssertEqual(PixelFont.glyph(for: "\u{1F600}"), PixelFont.missing)
        XCTAssertFalse(PixelFont.hasGlyph(for: "\u{1F600}"))
    }

    func testPixelRunsCoverEveryInkPixelExactlyOnce() {
        let text = "W12 · $9,300"
        let runs = PixelFont.pixelRuns(of: text)
        var painted = Set<[Int]>()
        for run in runs {
            for offset in 0..<run.width {
                XCTAssertTrue(
                    painted.insert([run.x + offset, run.y]).inserted,
                    "pixel painted twice at \(run.x + offset),\(run.y)"
                )
            }
        }
        let expected = text.reduce(0) { total, character in
            total + PixelFont.glyph(for: character).reduce(0) { rowTotal, row in
                rowTotal + row.filter { $0 == "#" }.count
            }
        }
        XCTAssertEqual(painted.count, expected)
    }

    func testRunsStayInsideTheStringsBounds() {
        let text = "MAR W2 · Y1"
        let width = PixelFont.width(of: text)
        for run in PixelFont.pixelRuns(of: text) {
            XCTAssertGreaterThanOrEqual(run.x, 0)
            XCTAssertLessThanOrEqual(run.x + run.width, width)
            XCTAssertTrue((0..<PixelFont.glyphHeight).contains(run.y))
        }
    }
}

/// The calendar turns the engine's day counter into the months and
/// weekends the HUD and the weekly report speak in.
final class GameCalendarTests: XCTestCase {
    func testDayZeroIsTheFirstOfJanuaryYearOne() {
        let calendar = GameCalendar(day: 0)
        // The engine's calendar spells months out and keeps the short form
        // separately; the App's labels use the short one.
        XCTAssertEqual(calendar.monthName, "January")
        XCTAssertEqual(calendar.shortMonthName, "Jan")
        XCTAssertEqual(calendar.dayOfMonth, 1)
        XCTAssertEqual(calendar.year, 1)
        XCTAssertEqual(calendar.quarter, 1)
        XCTAssertEqual(calendar.weekOfYear, 1)
    }

    func testMonthLengthsCoverExactlyAYear() {
        XCTAssertEqual(GameCalendar.monthLengths.reduce(0, +), 364)
        XCTAssertEqual(GameCalendar.monthLengths.count, GameCalendar.monthNames.count)
    }

    func testEveryDayOfAYearLandsInAValidMonth() {
        for day in 0..<364 {
            let calendar = GameCalendar(day: day)
            XCTAssertTrue((0..<12).contains(calendar.monthIndex), "day \(day)")
            XCTAssertTrue(
                (1...GameCalendar.monthLengths[calendar.monthIndex]).contains(calendar.dayOfMonth),
                "day \(day) fell outside its month"
            )
            XCTAssertTrue((1...4).contains(calendar.quarter))
        }
    }

    func testQuartersAreExactlyNinetyOneDays() {
        XCTAssertEqual(GameCalendar(day: 90).quarter, 1)
        XCTAssertEqual(GameCalendar(day: 91).quarter, 2)
        XCTAssertEqual(GameCalendar(day: 181).quarter, 2)
        XCTAssertEqual(GameCalendar(day: 182).quarter, 3)
        XCTAssertEqual(GameCalendar(day: 273).quarter, 4)
    }

    func testYearsAndWeeksMatchTheEnginesOwnCounters() {
        for day in stride(from: 0, to: 1_100, by: 13) {
            var state = GameState.newGame(
                companyName: "Fixture", seed: 1, balance: fixtureBalance, difficulty: .normal
            )
            state.day = day
            let calendar = state.gameCalendar
            XCTAssertEqual(calendar.year, state.year, "year drift on day \(day)")
            XCTAssertEqual(calendar.weekOfYear, state.weekOfYear, "week drift on day \(day)")
            XCTAssertEqual(calendar.dayOfWeek, state.dayOfWeek, "weekday drift on day \(day)")
        }
    }

    func testWeekendIsTheLastTwoDaysOfTheWeek() {
        XCTAssertFalse(GameCalendar(day: 0).isWeekend)
        XCTAssertFalse(GameCalendar(day: 4).isWeekend)
        XCTAssertTrue(GameCalendar(day: 5).isWeekend)
        XCTAssertTrue(GameCalendar(day: 6).isWeekend)
        XCTAssertFalse(GameCalendar(day: 7).isWeekend)
    }

    func testHudLabelIsStableAndShort() {
        XCTAssertEqual(GameCalendar(day: 0).hudLabel, "Jan W1 · Y1")
        XCTAssertEqual(GameCalendar(day: 364).hudLabel, "Jan W1 · Y2")
        // Everything in the label has a glyph in the bitmap font.
        for character in GameCalendar(day: 200).hudLabel {
            XCTAssertTrue(PixelFont.hasGlyph(for: character), "no glyph for '\(character)'")
        }
    }

    func testNegativeDaysClampToTheStart() {
        XCTAssertEqual(GameCalendar(day: -5).dayOfMonth, 1)
        XCTAssertEqual(GameCalendar(day: -5).year, 1)
    }

    private var fixtureBalance: BalanceConfig {
        guard let bundled = try? BalanceConfig.loadBundled() else {
            fatalError("TycoonEngine is missing its bundled Balance.json resource")
        }
        return bundled.adjusted(for: .normal)
    }
}

/// The generated product cover art has to be a valid sprite for every
/// product type, and the same product must always draw the same box.
final class ProductBoxArtTests: XCTestCase {
    func testEveryProductTypeProducesAValidSprite() {
        for typeID in ["mobile", "web", "desktop", "game", "saas", "enterprise", "unknown_type"] {
            let sprite = ProductBoxArt.sprite(typeID: typeID, topicID: "fitness", seed: 12)
            XCTAssertEqual(sprite.width, 24, "\(typeID) is not 24 wide")
            XCTAssertEqual(sprite.height, 24, "\(typeID) is not 24 tall")
        }
    }

    func testTheSameProductAlwaysDrawsTheSameBox() {
        let first = ProductBoxArt.sprite(typeID: "mobile", topicID: "fitness", seed: 99)
        let second = ProductBoxArt.sprite(typeID: "mobile", topicID: "fitness", seed: 99)
        XCTAssertEqual(first, second)
    }

    func testDifferentTopicsGetDifferentBoxes() {
        let fitness = ProductBoxArt.sprite(typeID: "mobile", topicID: "fitness", seed: 99)
        let finance = ProductBoxArt.sprite(typeID: "mobile", topicID: "finance", seed: 99)
        XCTAssertNotEqual(fitness, finance)
    }
}
