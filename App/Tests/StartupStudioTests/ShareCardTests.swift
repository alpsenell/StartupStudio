import SwiftUI
import TycoonContent
import TycoonEngine
import UIKit
import XCTest

@testable import StartupStudio

/// Iteration 7 (R4): the three share cards render to 1080×1350 PNGs with
/// ink on them, in both appearances, and again at thumbnail size — the
/// biography card has to read at 270×338 or it is a poster nobody opens.
@MainActor
final class ShareCardTests: XCTestCase {
    private var outputDirectory: URL {
        let path = ProcessInfo.processInfo.environment["PIXELKIT_PREVIEW_DIR"]
            ?? NSTemporaryDirectory() + "/startupstudio-previews"
        let url = URL(fileURLWithPath: path, isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// A company a year in, with products shipped and people hired, so
    /// every section of the biography card has something to say.
    private func company(ending: EndingKind = .ipo) -> GameEngine {
        let fresh = GameEngine.newGame(
            companyName: "Northgate Softworks",
            seed: 4242,
            difficulty: .normal,
            founder: FounderProfile(name: "Mira Okafor", archetype: .hacker, appearanceSeed: 0x5EED),
            origin: .cofounded
        )
        var state = fresh.state
        // Two builds, a hire, and a year on the clock.
        let type = fresh.content.productTypes[0]
        _ = Reducer.apply(
            .startProduct(typeID: type.id, topicID: fresh.content.topics[0].id, name: "Overcast", focus: .balanced),
            to: &state, balance: fresh.balance, content: fresh.content
        )
        for day in 0..<120 {
            _ = Reducer.tick(&state, balance: fresh.balance, content: fresh.content)
            if day == 3, let candidate = state.candidatePool.first {
                _ = Reducer.apply(.hire(candidateID: candidate.id), to: &state, balance: fresh.balance, content: fresh.content)
            }
            if state.productsInDevelopment.isEmpty, state.products.count < 2 {
                _ = Reducer.apply(
                    .startProduct(typeID: type.id, topicID: fresh.content.topics[1].id, name: "Ledgerline", focus: .balanced),
                    to: &state, balance: fresh.balance, content: fresh.content
                )
            }
            for product in state.productsInDevelopment
                where state.shipETA(for: product, balance: fresh.balance, content: fresh.content)?.isReady == true {
                _ = Reducer.apply(.ship(productID: product.id), to: &state, balance: fresh.balance, content: fresh.content)
            }
        }
        state.company.cash = 2_400_000
        state.gameOver = try? JSONDecoder().decode(
            GameOverInfo.self,
            from: Data(#"{"day":\#(state.day),"reason":"The bell rang.","kind":"\#(ending.rawValue)"}"#.utf8)
        )
        return GameEngine.resume(state: state)
    }

    private func save(_ image: UIImage, as name: String) throws {
        let data = try XCTUnwrap(image.pngData(), "\(name) has no PNG data")
        XCTAssertGreaterThan(data.count, 20_000, "\(name) is too small to be a card")
        XCTAssertGreaterThan(inkCoverage(image), 0.1, "\(name) rendered blank")
        let url = outputDirectory.appendingPathComponent("\(name).png")
        try data.write(to: url)
    }

    /// The share of sampled pixels that differ from the top-left one.
    private func inkCoverage(_ image: UIImage) -> Double {
        guard let cg = image.cgImage,
              let data = cg.dataProvider?.data,
              let bytes = CFDataGetBytePtr(data)
        else { return 0 }
        let bytesPerPixel = max(1, cg.bitsPerPixel / 8)
        let background = (0..<bytesPerPixel).map { Int(bytes[$0]) }
        var inked = 0
        var sampled = 0
        for y in stride(from: 0, to: cg.height, by: 8) {
            for x in stride(from: 0, to: cg.width, by: 8) {
                let offset = y * cg.bytesPerRow + x * bytesPerPixel
                sampled += 1
                if (0..<bytesPerPixel).contains(where: { abs(Int(bytes[offset + $0]) - background[$0]) > 8 }) {
                    inked += 1
                }
            }
        }
        return sampled == 0 ? 0 : Double(inked) / Double(sampled)
    }

    /// The card at the size a feed shows it before anyone taps.
    private func thumbnail(_ image: UIImage) -> UIImage {
        let size = CGSize(width: 270, height: 338)
        return UIGraphicsImageRenderer(size: size).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }

    private func assertCardSize(_ image: UIImage, _ name: String) {
        XCTAssertEqual(image.size.width * image.scale, 1080, "\(name) is not 1080 wide")
        XCTAssertEqual(image.size.height * image.scale, 1350, "\(name) is not 1350 tall")
    }

    // MARK: - The three cards

    func testTheBiographyCardRendersForEveryEnding() throws {
        for ending in [EndingKind.ipo, .bankruptcy] {
            let engine = company(ending: ending)
            let info = try XCTUnwrap(engine.state.gameOver)
            for scheme in [ColorScheme.light, .dark] {
                let name = "share_biography_\(ending.rawValue)_\(scheme == .light ? "light" : "dark")"
                let image = try XCTUnwrap(
                    ShareRenderer.render(BiographyCardView(engine: engine, info: info), colorScheme: scheme)
                )
                assertCardSize(image, name)
                try save(image, as: name)
            }
            let image = try XCTUnwrap(ShareRenderer.image(for: .biography(engine: engine, info: info)))
            try save(thumbnail(image), as: "share_biography_\(ending.rawValue)_thumb")
        }
    }

    func testTheBiographyCardCarriesThisRunsCode() throws {
        let engine = company()
        let info = try XCTUnwrap(engine.state.gameOver)
        let card = BiographyCardView(engine: engine, info: info)
        XCTAssertEqual(card.seedCode.seed, 4242)
        XCTAssertEqual(card.seedCode.origin, .cofounded)
        XCTAssertEqual(card.seedCode.difficulty, .normal)
        XCTAssertEqual(SeedCode.decode(card.seedCode.encoded), card.seedCode)
    }

    func testTheFrontPageCardRenders() throws {
        let engine = company()
        let composer = NewspaperComposer(state: engine.state, content: engine.content, balance: engine.balance)
        let issue = try XCTUnwrap(composer.issues().last)
        for scheme in [ColorScheme.light, .dark] {
            let name = "share_front_page_\(scheme == .light ? "light" : "dark")"
            let page = try XCTUnwrap(ShareRenderer.render(
                NewspaperPage(issue: issue, aboveTheFold: true), width: FrontPageCardView.pageWidth, colorScheme: scheme
            ))
            let image = try XCTUnwrap(ShareRenderer.render(
                FrontPageCardView(page: page, issue: issue, companyName: engine.state.company.name), colorScheme: scheme
            ))
            assertCardSize(image, name)
            try save(image, as: name)
        }
        let image = try XCTUnwrap(ShareRenderer.image(for: .frontPage(issue: issue, companyName: "Northgate Softworks")))
        assertCardSize(image, "front page via ShareCard")
        try save(thumbnail(image), as: "share_front_page_thumb")
    }

    func testTheOfficePhotoCardRenders() throws {
        let engine = company()
        for scheme in [ColorScheme.light, .dark] {
            let name = "share_office_photo_\(scheme == .light ? "light" : "dark")"
            let image = try XCTUnwrap(ShareRenderer.render(OfficePhotoCardView(engine: engine), colorScheme: scheme))
            assertCardSize(image, name)
            try save(image, as: name)
        }
        let image = try XCTUnwrap(ShareRenderer.image(for: .officePhoto(engine: engine)))
        try save(thumbnail(image), as: "share_office_photo_thumb")
    }

    func testACardRendersTheSameTwice() throws {
        let engine = company()
        let a = try XCTUnwrap(ShareRenderer.image(for: .officePhoto(engine: engine)))
        let b = try XCTUnwrap(ShareRenderer.image(for: .officePhoto(engine: engine)))
        XCTAssertEqual(a.pngData(), b.pngData(), "the office photo is a pure function of the state")
    }

    // MARK: - Codes and URLs

    func testASeedEntryReadsCodesNumbersAndBlanks() {
        let code = SeedCode(seed: 99, origin: .spinOut, difficulty: .hard)
        XCTAssertEqual(SeedEntry.parse(code.encoded), .code(code))
        XCTAssertEqual(SeedEntry.parse("  " + code.encoded.lowercased() + " "), .code(code))
        XCTAssertEqual(SeedEntry.parse("4242"), .number(4242))
        XCTAssertEqual(SeedEntry.parse("1,000,000"), .number(1_000_000))
        XCTAssertEqual(SeedEntry.parse(""), .random)
        XCTAssertEqual(SeedEntry.parse("   "), .random)
        XCTAssertEqual(SeedEntry.parse("hello"), .invalid)
        XCTAssertEqual(SeedEntry.parse("99999999999999999999999"), .invalid)
        XCTAssertTrue(SeedEntry.parse("7").isTyped)
        XCTAssertFalse(SeedEntry.parse("").isTyped)
    }

    func testASeedURLRoundTrips() throws {
        let code = SeedCode(seed: 0xC0DE, origin: .mortgaged, difficulty: .easy)
        let url = try XCTUnwrap(GameSession.seedURL(for: code))
        XCTAssertEqual(url.scheme, "startupstudio")
        XCTAssertEqual(GameSession.seedCode(from: url), code)
        XCTAssertNil(GameSession.seedCode(from: URL(string: "https://example.com/seed/\(code.encoded)")!))
        XCTAssertNil(GameSession.seedCode(from: URL(string: "startupstudio://seed/NOTACODE")!))
        XCTAssertNil(GameSession.seedCode(from: URL(string: "startupstudio://other/\(code.encoded)")!))
    }
}
