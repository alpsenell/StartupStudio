#if os(macOS)
import CoreGraphics
import Foundation
import Testing
@testable import PixelKit

/// The room reading the company: one PNG per pressure signal, in two
/// tiers, plus the home reading the meters, plus a Reduce Motion frame.
/// These are the pictures the integrator looks at; the assertions pin the
/// rules the pictures rely on.
@Suite("Pressure PNGs", .serialized)
struct OfficePressurePNGTests {
    let png = PreviewPNGTests()
    let sheet = OfficeFrameSheetPNGTests()

    private func input(
        tier: OfficeTierStyle,
        headcount: Int,
        pressure: OfficePressure
    ) -> OfficeSceneInput {
        var input = OfficeSceneInput(
            tier: tier,
            occupants: sheet.occupants(headcount, seed: 700, moods: [.okay, .great, .okay, .low]),
            amenities: [.gameRoom, .cafeteria]
        )
        input.pressure = pressure
        return input
    }

    private static let signals: [(name: String, pressure: OfficePressure)] = [
        ("crunch", OfficePressure(crunch: true)),
        ("runway", OfficePressure(runwayWeeks: 3)),
        ("debt", OfficePressure(inDebt: true)),
        ("bugs1", OfficePressure(bugLoad: 1)),
        ("bugs3", OfficePressure(bugLoad: 3)),
        ("offer", OfficePressure(pendingOffer: true)),
        ("everything", OfficePressure(crunch: true, runwayWeeks: 2, inDebt: false, bugLoad: 2, pendingOffer: true)),
    ]

    @Test(arguments: [OfficeTierStyle.garage, .studio])
    func eachSignalHasAPicture(tier: OfficeTierStyle) throws {
        let headcount = tier == .garage ? 4 : 12
        for signal in Self.signals {
            let input = input(tier: tier, headcount: headcount, pressure: signal.pressure)
            try png.writePNG(
                sheet.renderFrame(input: input, t: 3),
                named: "pressure_\(tier.rawValue)_\(signal.name).png"
            )
        }
    }

    @Test func aLeaverGetsAFlatBoxUnderTheDesk() throws {
        let occupants = sheet.occupants(6, seed: 701)
        let leaver = occupants[2].id
        var input = OfficeSceneInput(tier: .loft, occupants: occupants, amenities: [])
        input.pressure = OfficePressure(departing: [leaver])
        let placements = OfficeDirector.compose(input: input, timing: .none, at: 3)
        let boxes = placements.filter { $0.sprite.height == 3 && $0.sprite.width == 12 }
        #expect(boxes.count == 1, "one flat box for one leaver")
        try png.writePNG(sheet.renderFrame(input: input, t: 3), named: "pressure_loft_departing.png")
    }

    @Test func crunchIsReadFromThePressureNotTheClock() {
        var quiet = input(tier: .garage, headcount: 4, pressure: .none)
        quiet.ambience.timeOfDay = .night
        #expect(OfficeTempo.reading(for: quiet) != .crunch, "a late hour alone is not crunch any more")
        let crunching = input(tier: .garage, headcount: 4, pressure: OfficePressure(crunch: true))
        #expect(OfficeTempo.reading(for: crunching) == .crunch)
    }

    @Test func crunchPinsTheRoomToNight() {
        let crunching = input(tier: .garage, headcount: 4, pressure: OfficePressure(crunch: true))
        let quiet = input(tier: .garage, headcount: 4, pressure: .none)
        // The room's own clock rolls through the hours every four minutes;
        // under crunch every hour reads night, and without it they differ.
        let times: [TimeInterval] = [0, 70, 140, 210]
        #expect(times.allSatisfy { crunching.withHourOfDay(at: $0).ambience.timeOfDay == .night })
        #expect(Set(times.map { quiet.withHourOfDay(at: $0).ambience.timeOfDay }).count > 1)
    }

    @Test func reduceMotionSeatsEverybody() throws {
        var input = input(tier: .studio, headcount: 12, pressure: .none)
        input.reduceMotion = true
        // Across the day nobody's plan leaves the desk.
        for plan in OfficeDirector.plans(for: input, at: 30) {
            #expect(plan.segments.count == 1)
            #expect(plan.segments.first?.waypointID == "desk")
        }
        try png.writePNG(sheet.renderFrame(input: input, t: 30), named: "pressure_studio_reduce_motion.png")
    }

    @Test func theHomeReadsTheMeters() throws {
        let occupants = HomeOccupants(
            founder: CharacterAppearance(seed: 7),
            partner: CharacterAppearance(seed: 21)
        )
        let cases: [(String, HomeSignals)] = [
            ("warm", .none),
            ("cold", HomeSignals(relationshipsLow: true)),
            ("unwell", HomeSignals(healthLow: true)),
            ("bills", HomeSignals(billsDue: true)),
        ]
        for (name, signals) in cases {
            let placements = HomeSceneComposer.compose(
                tier: .apartment, occupants: occupants, activity: .relaxing, mood: .okay,
                ambience: .evening, signals: signals
            )
            let size = HomeSceneComposer.sceneSize(for: .apartment)
            let scale = PreviewPNGTests.scale
            let context = png.makeCanvas(width: size.width * scale, height: size.height * scale, background: nil)
            for placement in placements {
                png.blit(
                    placement.sprite, frame: placement.frameIndex(atTick: 0),
                    x: placement.x, y: placement.y,
                    into: context, canvasHeight: size.height * scale
                )
            }
            try png.writePNG(context.makeImage()!, named: "home_signal_\(name).png")
        }
        let cold = HomeSceneComposer.compose(
            tier: .apartment, occupants: occupants, activity: .dinner, mood: .okay,
            ambience: .evening, signals: HomeSignals(relationshipsLow: true)
        )
        let warm = HomeSceneComposer.compose(
            tier: .apartment, occupants: occupants, activity: .dinner, mood: .okay,
            ambience: .evening, signals: .none
        )
        #expect(cold.count == warm.count, "a low bubble replaces the heart, it does not add to it")
    }
}
#endif
