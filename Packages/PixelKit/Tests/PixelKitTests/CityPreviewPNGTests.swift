#if os(macOS)
import CoreGraphics
import Foundation
import ImageIO
import Testing
@testable import PixelKit

/// PNG previews of the city map at each hour and each office tier, and the
/// invariants that keep the map honest: everything inside the frame, the
/// player's HQ growing with the tier, and hit-testing untouched by any of
/// the new dressing.
@Suite("City preview PNGs", .serialized)
struct CityPreviewPNGTests {
    static let outputDirectory = PreviewPNGTests.outputDirectory.appendingPathComponent("city", isDirectory: true)
    static let scale = 3
    let painter = PreviewPNGTests()

    func districts(selected: DistrictStyle = .downtown) -> [CityDistrictInfo] {
        DistrictStyle.allCases.map { style in
            CityDistrictInfo(
                style: style,
                selected: style == selected,
                hasPlayerOffice: style == .midtown,
                rivalSeeds: style == .downtown ? [11, 42] : (style == .techPark ? [7] : [])
            )
        }
    }

    func renderMap(ambience: CityAmbience, tick: Int) -> CGImage {
        let size = CityMapComposer.sceneSize()
        let context = CGContext(
            data: nil, width: size.width * Self.scale, height: size.height * Self.scale,
            bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        context.interpolationQuality = .none
        context.setAllowsAntialiasing(false)
        let canvasHeight = size.height * Self.scale
        for placement in CityMapComposer.compose(districts: districts(), ambience: ambience) {
            let sprite = placement.sprite
            context.draw(
                sprite.cgImage(frame: placement.frameIndex(atTick: tick)),
                in: CGRect(
                    x: placement.x * Self.scale,
                    y: canvasHeight - (placement.y + sprite.height) * Self.scale,
                    width: sprite.width * Self.scale,
                    height: sprite.height * Self.scale
                )
            )
        }
        return context.makeImage()!
    }

    func writePNG(_ image: CGImage, named name: String) throws {
        try FileManager.default.createDirectory(at: Self.outputDirectory, withIntermediateDirectories: true)
        let url = Self.outputDirectory.appendingPathComponent(name)
        let destination = try #require(CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        #expect(CGImageDestinationFinalize(destination), "failed writing \(name)")
    }

    @Test func theCityAtEveryHour() throws {
        for time in TimeOfDay.allCases {
            let image = renderMap(
                ambience: CityAmbience(timeOfDay: time, season: .summer, playerTier: .studio), tick: 2
            )
            try writePNG(image, named: "city_\(time.rawValue).png")
        }
    }

    @Test func theHeadquartersGrowsWithTheTier() throws {
        for tier in OfficeTierStyle.allCases {
            let image = renderMap(
                ambience: CityAmbience(timeOfDay: .day, season: .spring, playerTier: tier), tick: 0
            )
            try writePNG(image, named: "city_hq_\(tier.rawValue).png")
        }
        // Side by side, so the growth is obvious.
        let sprites = OfficeTierStyle.allCases.map { CitySpriteLibrary.playerHQ(tier: $0, time: .night) }
        let gap = 4
        let width = gap + sprites.reduce(0) { $0 + $1.width + gap }
        let height = gap * 2 + sprites.map(\.height).max()!
        let canvasHeight = height * PreviewPNGTests.scale
        let context = painter.makeCanvas(
            width: width * PreviewPNGTests.scale, height: canvasHeight, background: .init(r: 46, g: 42, b: 60)
        )
        var x = gap
        for sprite in sprites {
            painter.blit(
                sprite, frame: 0, x: x, y: height - gap - sprite.height,
                into: context, canvasHeight: canvasHeight
            )
            x += sprite.width + gap
        }
        try writePNG(context.makeImage()!, named: "hq_growth.png")
    }

    @Test func theSeasonsChangeTheGreenery() throws {
        for season in Season.allCases {
            let image = renderMap(
                ambience: CityAmbience(timeOfDay: .day, season: season, playerTier: .loft), tick: 1
            )
            try writePNG(image, named: "city_\(season.rawValue).png")
        }
    }

    // MARK: Invariants

    @Test func everyPlacementStaysInsideTheMap() {
        let size = CityMapComposer.sceneSize()
        for time in TimeOfDay.allCases {
            for tier in OfficeTierStyle.allCases {
                let scene = CityMapComposer.compose(
                    districts: districts(), ambience: CityAmbience(timeOfDay: time, playerTier: tier)
                )
                for placement in scene {
                    #expect(placement.x >= 0 && placement.y >= 0, "\(time)/\(tier) \(placement.kind) origin")
                    #expect(placement.x + placement.sprite.width <= size.width, "\(time)/\(tier) \(placement.kind) right edge")
                    #expect(placement.y + placement.sprite.height <= size.height, "\(time)/\(tier) \(placement.kind) bottom edge")
                }
            }
        }
    }

    @Test func theHeadquartersIsDrawnOnceAndGrowsMonotonically() {
        var heights: [Int] = []
        for tier in OfficeTierStyle.allCases {
            let scene = CityMapComposer.compose(
                districts: districts(), ambience: CityAmbience(playerTier: tier)
            )
            let hqs = scene.filter { $0.kind == .cityProp("playerHQ") }
            #expect(hqs.count == 1, "\(tier): exactly one headquarters")
            heights.append(hqs[0].sprite.height)
        }
        #expect(heights == heights.sorted(), "the HQ never shrinks")
        #expect(heights.first! < heights.last!, "a campus towers over a garage")
    }

    @Test func rivalsGetTheirOwnBuildings() {
        let scene = CityMapComposer.compose(districts: districts(), ambience: .noon)
        let rivals = scene.filter { $0.kind == .cityProp("rivalHQ") }
        #expect(rivals.count == 3, "two downtown, one in the tech park")
        // Each carries a different founder's portrait.
        #expect(Set(rivals.map { $0.sprite.frames[0].joined() }).count == 3)
    }

    @Test func trafficAndStreetlightsAppear() {
        let day = CityMapComposer.compose(districts: districts(), ambience: CityAmbience(timeOfDay: .day))
        let night = CityMapComposer.compose(districts: districts(), ambience: CityAmbience(timeOfDay: .night))
        #expect(day.filter { $0.kind == .cityProp("traffic") }.count == 2, "one lane each way")
        #expect(day.contains { $0.kind == .cityProp("streetlight") })
        for lane in day.filter({ $0.kind == .cityProp("traffic") }) {
            #expect(lane.sprite.frameCount == 2)
            #expect(lane.sprite.frames[0] != lane.sprite.frames[1], "the cars move between frames")
        }
        // Headlights come on after dark.
        let dayLamp = day.first { $0.kind == .cityProp("streetlight") }!.sprite
        let nightLamp = night.first { $0.kind == .cityProp("streetlight") }!.sprite
        #expect(dayLamp != nightLamp)
    }

    @Test func hitTestingIsUnchangedByTheDressing() {
        // Every pixel of the map belongs to exactly one district (or a road).
        let size = CityMapComposer.sceneSize()
        for style in DistrictStyle.allCases {
            let frame = CityMapComposer.districtFrame(style)
            #expect(CityMapComposer.hitTest(x: frame.x + 1, y: frame.y + 1) == style)
            #expect(CityMapComposer.hitTest(x: frame.x + frame.width - 1, y: frame.y + frame.height - 1) == style)
        }
        #expect(CityMapComposer.hitTest(x: size.width + 4, y: 0) == nil)
    }

    @Test func compositionIsDeterministic() {
        for time in TimeOfDay.allCases {
            let ambience = CityAmbience(timeOfDay: time, season: .autumn, playerTier: .studio)
            #expect(
                CityMapComposer.compose(districts: districts(), ambience: ambience)
                    == CityMapComposer.compose(districts: districts(), ambience: ambience)
            )
        }
    }

    @Test func theLegacyComposeIsTheNoonMap() {
        #expect(
            CityMapComposer.compose(districts: districts())
                == CityMapComposer.compose(districts: districts(), ambience: .noon)
        )
    }
}
#endif
