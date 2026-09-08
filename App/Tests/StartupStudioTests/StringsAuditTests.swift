import XCTest
@testable import StartupStudio

/// The localization bar, asserted rather than described (R9, iteration 7).
///
/// Three things are pinned here, and none of them is "everything is
/// translated" — the lane's scope is *the chrome now, the sentences later*:
///
/// 1. **No new unlocalized pixel chrome.** A `PixelText(text: "…")` with a
///    bare literal is a user-visible string that never reaches the catalog.
///    The count at the end of iteration 7's string lane is pinned as a
///    ceiling, so a new one fails this test and an old one being converted
///    does not.
/// 2. **The catalog exists and the build filled it.** `Localizable.xcstrings`
///    is checked into `App/Resources`, and the extracted key count is above
///    a floor, so a build that silently stopped extracting (a dropped
///    `SWIFT_EMIT_LOC_STRINGS`, a catalog reverted to `{}`) is caught.
/// 3. **The bitmap face's coverage.** `PixelFont` has 55 glyphs and no
///    accents, so a translated string routed through `PixelText` renders as
///    hollow boxes. The count and the exact glyph set are pinned, and the
///    money format is checked against them, because the day somebody adds
///    `é` to the font is the day the pixel screens can be translated.
///
/// The source-tree checks read the repository through `#filePath`. Simulator
/// tests share the host filesystem, so that works locally and in CI on a
/// Mac; if the tree is not there (a test bundle shipped somewhere else) the
/// test skips rather than fails, and the bundle-level checks still run.
final class StringsAuditTests: XCTestCase {

    // MARK: - The bar: no new unlocalized pixel chrome

    /// Every `PixelText(text: "` immediately followed by a string literal,
    /// across the app's sources. Interpolated literals (`"\(score)"`) count
    /// too: they are still a bare literal in an argument that never becomes
    /// a `LocalizedStringKey`.
    ///
    /// 24 at the end of R9. Of those, three are `#Preview` samples in
    /// `PixelText.swift`, two are the brand name "Startup Studio" (not
    /// translated), one is the `▶` glyph on the speed control, and nine are
    /// pure interpolations of a number. The rest — "In brief", "War room",
    /// "Launch day", "Coming soon", "Today", "Done", "Every pool is full",
    /// "T-minus" — belong to lanes that own those screens; converting them
    /// is the sentence lane's job, not this one's.
    ///
    /// **When you merge a lane that adds pixel chrome**, this number moves.
    /// Localize the new site if the string is prose, then re-pin the count
    /// here in the same commit — deliberately, with the reason.
    // Re-pinned at the iteration 7 merge: R9 counted 24 on its own branch;
    // the tutorial card (R1), the daily cards (R3), the share cards and the
    // custom page (R4) and the paywall (R6) add thirteen more. The bar is
    // still "no new ones from here".
    // Re-pinned again after iteration 8: the scenario and season cards,
    // awards night, the hall, the dynasty and the stake ladder add nine.
    // Re-pinned by iteration 9's L2: the life score adds one site, the
    // "/100" beside the figure, which is a glyph rather than prose. Its
    // two words — "LIFE" and "LIFE SCORE" — went through
    // `String(localized:comment:)` instead and are not counted here.
    // Re-pinned by iteration 10's M3: the incident room adds one site, the
    // count of users who have walked out, which is a pure number. Its two
    // prose strings — "INCIDENT ROOM" and "<product> STATUS" — went
    // through `String(localized:comment:)` instead and are not counted.
    static let pixelTextLiteralBaseline = 48

    func testNoNewUnlocalizedPixelChrome() throws {
        let sources = try Self.appSourceFiles()
        var sites: [String] = []
        for url in sources {
            let text = try String(contentsOf: url, encoding: .utf8)
            for (index, line) in text.split(separator: "\n", omittingEmptySubsequences: false).enumerated()
            where line.contains(#"PixelText(text: ""#) {
                sites.append("\(url.lastPathComponent):\(index + 1): \(line.trimmingCharacters(in: .whitespaces))")
            }
        }
        XCTAssertLessThanOrEqual(
            sites.count,
            Self.pixelTextLiteralBaseline,
            """
            New unlocalized pixel chrome: \(sites.count) bare `PixelText(text: "…")` \
            literals, up from the pinned \(Self.pixelTextLiteralBaseline).

            Either wrap the new one in `String(localized:comment:)` — remembering \
            that PixelFont has no lowercase and no accents, so the comment must \
            say so — or, if it is a brand name, a glyph or a pure number, raise \
            `pixelTextLiteralBaseline` in the same commit and say why.

            All sites:
            \(sites.joined(separator: "\n"))
            """
        )
    }

    // MARK: - The catalog

    func testCatalogExistsAndIsAnEnglishSourceCatalog() throws {
        let catalog = try Self.catalogJSON()
        XCTAssertEqual(catalog["sourceLanguage"] as? String, "en")
        XCTAssertEqual(catalog["version"] as? String, "1.0")
    }

    /// The floor from the plan: the build extracts at least 300 keys.
    ///
    /// It extracts far more than that — every `Text("…")`, every
    /// `accessibilityLabel("…")`, every `Button("…")` in the app is a
    /// `LocalizedStringKey` and comes across for free — plus the
    /// `String(localized:)` sites this lane converted by hand. The floor is
    /// deliberately well under the real number so that re-syncing the
    /// catalog after a merge never trips it; what it catches is extraction
    /// having stopped altogether.
    func testCatalogHoldsTheExtractedKeys() throws {
        let catalog = try Self.catalogJSON()
        let strings = try XCTUnwrap(catalog["strings"] as? [String: Any])
        XCTAssertGreaterThanOrEqual(
            strings.count, 300,
            """
            The string catalog has \(strings.count) keys, under the 300 floor. \
            `xcodebuild` compiles the catalog but does not write extracted keys \
            back into it — only Xcode's IDE does. Re-run `make strings` (build, \
            then `xcstringstool sync` over the emitted .stringsdata) and commit \
            the result.
            """
        )
    }

    /// The hand-converted sites are in there, with their comments — the
    /// proof that `String(localized:comment:)` reached the catalog and not
    /// just the source.
    func testHandConvertedChromeKeysCarryTranslatorComments() throws {
        let catalog = try Self.catalogJSON()
        let strings = try XCTUnwrap(catalog["strings"] as? [String: Any])
        for key in ["IN THE RED", "NO BURN", "Be supportive", "Founder", "A hit"] {
            let entry = strings[key] as? [String: Any]
            XCTAssertNotNil(entry, "`\(key)` is not in the catalog — re-run `make strings`.")
            let comment = entry?["comment"] as? String
            XCTAssertFalse(
                (comment ?? "").isEmpty,
                "`\(key)` reached the catalog without its translator comment."
            )
        }
    }

    /// The compiled side: the catalog becomes `en.lproj/Localizable.strings`
    /// in the bundle, and the app resolves through it at runtime. This one
    /// needs no source tree.
    func testCompiledCatalogIsInTheBundle() throws {
        let bundle = Bundle(for: Self.self)
        let app = bundle.bundleURL
            .deletingLastPathComponent()  // …/StartupStudio.app/PlugIns/…xctest → .app
        let candidates = [app, app.deletingLastPathComponent()]
        let found = candidates.contains { root in
            FileManager.default.fileExists(
                atPath: root.appendingPathComponent("en.lproj/Localizable.strings").path
            )
        }
        XCTAssertTrue(found, "The host app has no en.lproj/Localizable.strings — the catalog did not compile in.")
    }

    // MARK: - The bitmap face

    /// 55 glyphs, and exactly these. Counted from `PixelFont`'s own table,
    /// not from the design doc, which said 62 and was wrong.
    func testPixelFontGlyphCoverageIsPinned() {
        let expected = Set("ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 $.,:-+/!?'%()×·▶♥★")
        XCTAssertEqual(expected.count, 55)
        XCTAssertEqual(Set(PixelFont.glyphs.keys), expected)
        XCTAssertEqual(PixelFont.glyphs.count, 55)
    }

    /// The consequence, stated as a test: no accented Latin letter draws.
    /// When somebody adds the Latin-1 extension in wave 2, this fails, and
    /// the failure is the signal that the pixel screens can be translated.
    func testPixelFontStillCannotDrawASecondLanguage() {
        for character in "éàüßñçøåÉÀÜÑ€£¥&#@" {
            XCTAssertFalse(
                PixelFont.hasGlyph(for: character),
                "PixelFont has grown a glyph for `\(character)`. If the Latin-1 "
                    + "extension has landed, re-pin the coverage test above and "
                    + "revisit Theme.gameLocale — pixel text may no longer be "
                    + "English-and-dollars only."
            )
        }
    }

    /// Why `Theme.gameLocale` stays `en_US_POSIX`: every character the money
    /// formatter can emit has to exist in the face. A locale with a
    /// non-breaking-space group separator would fail this.
    func testEveryCharacterOfAFormattedFigureIsDrawable() {
        XCTAssertEqual(Theme.gameLocale.identifier, "en_US_POSIX")
        for amount in [0, 7, 950, 12_400, 1_250_000, -2_300] {
            for character in amount.money where !PixelFont.hasGlyph(for: character) {
                XCTFail("`\(amount.money)` contains `\(character)`, which PixelFont cannot draw.")
            }
        }
    }

    // MARK: - Locating the repository

    private static func repositoryRoot() throws -> URL {
        // …/App/Tests/StartupStudioTests/StringsAuditTests.swift → repo root
        var url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // StartupStudioTests
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // App
            .deletingLastPathComponent()  // repo root
        url.standardize()
        guard FileManager.default.fileExists(atPath: url.appendingPathComponent("project.yml").path) else {
            throw XCTSkip("The source tree is not reachable from \(url.path); source-level audit skipped.")
        }
        return url
    }

    private static func appSourceFiles() throws -> [URL] {
        let root = try repositoryRoot().appendingPathComponent("App/Sources")
        guard let walker = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil) else {
            throw XCTSkip("App/Sources is not enumerable.")
        }
        let files = walker.compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" }
        XCTAssertGreaterThan(files.count, 100, "Only \(files.count) app sources found — the walk is wrong.")
        return files.sorted { $0.path < $1.path }
    }

    private static func catalogJSON() throws -> [String: Any] {
        let url = try repositoryRoot().appendingPathComponent("App/Resources/Localizable.xcstrings")
        let data = try Data(contentsOf: url)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }
}
