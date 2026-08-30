#if os(macOS)
import CoreGraphics
import Foundation
import ImageIO
import Testing
@testable import PixelKit

/// Writes PNG frame sheets of the *live* office — the exact
/// `OfficeDirector.compose` output the SwiftUI view draws — at a spread of
/// scene times, so office life can be reviewed by eye rather than by
/// assertion.
///
/// Files land in `PIXELKIT_PREVIEW_DIR`.
@Suite("Office frame sheets", .serialized)
struct OfficeFrameSheetPNGTests {
    let png = PreviewPNGTests()

    // MARK: Helpers

    func occupants(
        _ count: Int,
        seed: UInt64,
        moods: [MoodLevel] = [.okay],
        friends: Bool = true,
        names: Bool = true
    ) -> [Occupant] {
        let pool = ["Mara", "Dev", "Nils", "Ines", "Otto", "Suki", "Rafa", "Wren", "Yuki", "Bo"]
        var people: [Occupant] = []
        for index in 0..<count {
            let id = UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", index))!
            let friendID = UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", (index + 1) % count))!
            people.append(Occupant(
                id: id,
                appearance: CharacterAppearance(seed: UInt64(index) &+ seed),
                status: WorkStatus.allCases[index % WorkStatus.allCases.count],
                isFounder: index == 0,
                mood: moods[index % moods.count],
                friendIDs: friends && index % 3 == 0 && count > 2 ? [friendID] : [],
                speech: index == 1 ? "Shipping Friday." : nil,
                role: RoleLook.allCases[index % RoleLook.allCases.count],
                name: names ? pool[index % pool.count] : nil
            ))
        }
        return people
    }

    /// Renders one director frame at scene time `t`.
    func renderFrame(input: OfficeSceneInput, timing: OfficeSceneTiming = .none, t: TimeInterval) -> CGImage {
        let size = SceneComposer.sceneSize(for: input.tier)
        let scale = PreviewPNGTests.scale
        let context = png.makeCanvas(width: size.width * scale, height: size.height * scale, background: nil)
        for placement in OfficeDirector.compose(input: input, timing: timing, at: t) {
            let point = placement.position(at: t)
            png.blit(
                placement.sprite,
                frame: placement.frameIndex(at: t),
                x: point.x, y: point.y,
                into: context, canvasHeight: size.height * scale
            )
        }
        return context.makeImage()!
    }

    /// Stacks several timestamps into one tall sheet with a gap between
    /// them, so a whole behaviour reads at a glance.
    func renderSheet(
        input: OfficeSceneInput,
        timing: OfficeSceneTiming = .none,
        times: [TimeInterval]
    ) -> CGImage {
        let size = SceneComposer.sceneSize(for: input.tier)
        let scale = PreviewPNGTests.scale
        let gap = 6 * scale
        let width = size.width * scale
        let height = times.count * size.height * scale + (times.count - 1) * gap
        let sheet = png.makeCanvas(
            width: width, height: height, background: .init(r: 24, g: 24, b: 30)
        )
        for (index, t) in times.enumerated() {
            let frame = renderFrame(input: input, timing: timing, t: t)
            let y = height - (index + 1) * size.height * scale - index * gap
            sheet.draw(frame, in: CGRect(x: 0, y: y, width: width, height: size.height * scale))
        }
        return sheet.makeImage()!
    }

    // MARK: Tiers over time

    @Test(arguments: OfficeTierStyle.allCases)
    func tierOverTheDay(tier: OfficeTierStyle) throws {
        let headcount: Int
        switch tier {
        case .garage: headcount = 4
        case .loft: headcount = 7
        case .studio: headcount = 15
        case .campus: headcount = 30
        }
        let input = OfficeSceneInput(
            tier: tier,
            occupants: occupants(headcount, seed: 300, moods: [.okay, .great, .okay, .low]),
            amenities: [.gameRoom, .cafeteria, .gym, .shuttle]
        )
        for t: TimeInterval in [0, 2, 4, 6, 8] {
            try png.writePNG(
                renderFrame(input: input, t: t),
                named: "office_\(tier.rawValue)_t\(Int(t)).png"
            )
        }
        // One tall sheet per tier covering a full minute of office life.
        try png.writePNG(
            renderSheet(input: input, times: [0, 12, 30, 55, 90, 130]),
            named: "office_\(tier.rawValue)_sheet.png"
        )
    }

    // MARK: Celebrations

    @Test func shippedCelebration() throws {
        let people = occupants(12, seed: 500)
        let input = OfficeSceneInput(
            tier: .studio, occupants: people,
            celebration: .init(kind: .shipped(score: 84), token: 1)
        )
        try png.writePNG(
            renderSheet(input: input, times: [0.5, 1.5, 3, 5, 8]),
            named: "celebration_shipped.png"
        )
    }

    @Test func hiredCelebration() throws {
        let people = occupants(7, seed: 620)
        let input = OfficeSceneInput(
            tier: .loft, occupants: people,
            celebration: .init(kind: .hired(people[6].id), token: 1)
        )
        try png.writePNG(
            renderSheet(input: input, times: [0, 1, 2, 3, 5]),
            named: "celebration_hired.png"
        )
    }

    @Test func quitCelebration() throws {
        let people = occupants(7, seed: 640)
        let input = OfficeSceneInput(
            tier: .loft, occupants: people,
            celebration: .init(kind: .quit(people[4].id), token: 1)
        )
        try png.writePNG(
            renderSheet(input: input, times: [0, 2, 4, 6, 8]),
            named: "celebration_quit.png"
        )
    }

    @Test func upgradeWipe() throws {
        let input = OfficeSceneInput(
            tier: .campus, occupants: occupants(22, seed: 700),
            celebration: .init(kind: .officeUpgraded, token: 1)
        )
        try png.writePNG(
            renderSheet(input: input, times: [0.05, 0.2, 0.35, 0.5, 0.65]),
            named: "celebration_upgrade.png"
        )
    }

    @Test func researchAndContract() throws {
        let people = occupants(10, seed: 760)
        try png.writePNG(
            renderFrame(
                input: OfficeSceneInput(
                    tier: .studio, occupants: people,
                    celebration: .init(kind: .researchComplete, token: 1)
                ),
                t: 1
            ),
            named: "celebration_research.png"
        )
        try png.writePNG(
            renderSheet(
                input: OfficeSceneInput(
                    tier: .studio, occupants: people,
                    celebration: .init(kind: .contractDelivered, token: 1)
                ),
                times: [0.2, 0.8, 1.6]
            ),
            named: "celebration_contract.png"
        )
    }

    // MARK: Ambience

    @Test func hoursAndWeather() throws {
        let people = occupants(16, seed: 820, moods: [.okay, .great, .low])
        for time in TimeOfDay.allCases {
            let input = OfficeSceneInput(
                tier: .studio, occupants: people,
                amenities: [.cafeteria, .gameRoom],
                ambience: OfficeAmbience(timeOfDay: time)
            )
            try png.writePNG(renderFrame(input: input, t: 3), named: "office_hour_\(time.rawValue).png")
        }
        for weather in [Weather.rain, .snow] {
            let input = OfficeSceneInput(
                tier: .campus, occupants: occupants(24, seed: 860),
                ambience: OfficeAmbience(timeOfDay: .dusk, weather: weather)
            )
            try png.writePNG(renderFrame(input: input, t: 3), named: "office_weather_\(weather.rawValue).png")
        }
    }

    @Test func weekendIsNearlyEmpty() throws {
        let input = OfficeSceneInput(
            tier: .studio, occupants: occupants(15, seed: 880),
            ambience: OfficeAmbience(timeOfDay: .morning, isWeekend: true)
        )
        try png.writePNG(renderFrame(input: input, t: 4), named: "office_weekend.png")
    }

    @Test func awayDesksAndNameTag() throws {
        var people = occupants(12, seed: 910)
        people[3].isAway = true
        people[7].isAway = true
        let input = OfficeSceneInput(tier: .studio, occupants: people)
        let timing = OfficeSceneTiming(
            celebrationStart: 0,
            statusChanges: [people[2].id: 2],
            tap: .init(id: people[1].id, at: 2)
        )
        try png.writePNG(
            renderFrame(input: input, timing: timing, t: 3),
            named: "office_away_and_nametag.png"
        )
    }

    // MARK: The runtime's own art

    @Test func fxSheet() throws {
        let scale = PreviewPNGTests.scale
        let sprites: [(String, PixelSprite, Int)] = [
            ("easel", OfficeFXSprites.easel(), 0),
            ("kitchenette", OfficeFXSprites.kitchenette(), 1),
            ("box", OfficeFXSprites.cardboardBox(), 0),
            ("note", OfficeFXSprites.stickyNote(), 0),
            ("chatter", OfficeFXSprites.chatterBubble(), 2),
            ("mug", OfficeFXSprites.mugBubble(), 0),
            ("idea", OfficeFXSprites.ideaBubble(), 1),
            ("gloom", OfficeFXSprites.gloomCloud(), 0),
            ("coin", OfficeFXSprites.coinSparkle(), 1),
            ("confetti", OfficeFXSprites.confetti(variant: 0), 0),
            ("tag", OfficeFXSprites.nameTag(name: "Mara", line: "Shipping Friday."), 0),
        ]
        let gap = 4
        let width = sprites.reduce(0) { $0 + $1.1.width + gap } + gap
        let height = (sprites.map(\.1.height).max() ?? 8) + 8
        let context = png.makeCanvas(
            width: width * scale, height: height * scale,
            background: .init(r: 148, g: 152, b: 168)
        )
        var x = gap
        for (_, sprite, frame) in sprites {
            png.blit(
                sprite, frame: min(frame, sprite.frameCount - 1),
                x: x, y: height - 4 - sprite.height,
                into: context, canvasHeight: height * scale
            )
            x += sprite.width + gap
        }
        try png.writePNG(context.makeImage()!, named: "office_fx_sheet.png")
    }
}
#endif
