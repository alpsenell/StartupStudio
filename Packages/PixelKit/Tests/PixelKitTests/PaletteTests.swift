import Foundation
import Testing
@testable import PixelKit

/// The art-direction gate. Two rules hold the look together:
///
/// 1. Every color in every shipped sprite is a `Palettes.master` color
///    (alpha ignored — glows are master hues at reduced opacity).
/// 2. Every office and home room separates its wall from its floor by at
///    least 18% perceived luminance, so people and furniture read against
///    the background at any tier and any hour.
@Suite("Master palette")
struct PaletteTests {
    // MARK: Sprite inventory

    /// A spread of appearances that touches every ramp index.
    static var appearances: [CharacterAppearance] {
        (0..<24).map { CharacterAppearance(seed: UInt64($0) &* 0x9E37_79B9 &+ 7) }
    }

    /// Every sprite the packages can produce, tagged for failure messages.
    static func allSprites() -> [(name: String, sprite: PixelSprite)] {
        var out: [(String, PixelSprite)] = []

        // People: every pose × role × founder flag, over a spread of looks.
        for appearance in appearances.prefix(8) {
            for pose in SpriteLibrary.PersonPose.allCases {
                for role in RoleLook.allCases {
                    for isFounder in [false, true] {
                        out.append((
                            "person(\(pose), \(role), founder: \(isFounder))",
                            SpriteLibrary.person(appearance: appearance, pose: pose, isFounder: isFounder, role: role)
                        ))
                    }
                }
            }
            out.append(("child", SpriteLibrary.child(appearance: appearance)))
        }
        out.append(("baby", SpriteLibrary.baby()))
        out.append(("controller", SpriteLibrary.controller()))
        out.append(("book", SpriteLibrary.book()))
        out.append(("zzzBubble", SpriteLibrary.zzzBubble()))
        out.append(("desk", SpriteLibrary.desk()))
        out.append(("monitor", SpriteLibrary.monitor()))
        out.append(("cat", SpriteLibrary.cat()))

        for status in WorkStatus.allCases { out.append(("statusBubble(\(status))", SpriteLibrary.statusBubble(status))) }
        for mood in MoodLevel.allCases { out.append(("moodBubble(\(mood))", SpriteLibrary.moodBubble(mood))) }
        for name in SpriteLibrary.PropName.allCases { out.append(("prop(\(name))", SpriteLibrary.prop(name))) }
        for name in SpriteLibrary.HomePropName.allCases { out.append(("homeProp(\(name))", SpriteLibrary.homeProp(name))) }
        for name in SpriteLibrary.AmenityPropName.allCases { out.append(("amenityProp(\(name))", SpriteLibrary.amenityProp(name))) }

        // Ambience seams.
        for style in WindowStyle.allCases {
            for time in TimeOfDay.allCases {
                for weather in Weather.allCases {
                    out.append((
                        "window(\(style), \(time), \(weather))",
                        SpriteLibrary.window(style: style, time: time, weather: weather)
                    ))
                }
            }
        }
        for time in TimeOfDay.allCases {
            out.append(("lightingOverlay(\(time))", SpriteLibrary.lightingOverlay(width: 40, height: 24, time: time)))
        }

        // Rooms.
        for tier in OfficeTierStyle.allCases {
            for time in TimeOfDay.allCases {
                out.append((
                    "officeRoom(\(tier), \(time))",
                    RoomBuilder.officeRoom(tier: tier, width: 120, height: 90, wallHeight: 34, time: time)
                ))
            }
        }
        for tier in HomeTierStyle.allCases {
            for time in TimeOfDay.allCases {
                out.append((
                    "homeRoom(\(tier), \(time))",
                    RoomBuilder.homeRoom(tier: tier, width: 120, height: 80, wallHeight: 36, time: time)
                ))
            }
        }

        // Composed scenes pick up anything the factories above missed.
        let crowd = appearances.prefix(6).enumerated().map { index, appearance in
            Occupant(
                id: UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", index))!,
                appearance: appearance,
                status: WorkStatus.allCases[index % WorkStatus.allCases.count],
                isFounder: index == 0,
                role: RoleLook.allCases[index % RoleLook.allCases.count]
            )
        }
        for tier in OfficeTierStyle.allCases {
            for placement in SceneComposer.compose(
                tier: tier, occupants: Array(crowd), amenities: Set(AmenityStyle.allCases)
            ) {
                out.append(("office \(tier) placement", placement.sprite))
            }
        }
        let household = HomeOccupants(
            founder: appearances[0], partner: appearances[1],
            children: [appearances[2], appearances[3]]
        )
        for tier in HomeTierStyle.allCases {
            for activity in HomeActivity.allCases {
                for time in TimeOfDay.allCases {
                    for placement in HomeSceneComposer.compose(
                        tier: tier, occupants: household, activity: activity, mood: .low,
                        ambience: HomeAmbience(timeOfDay: time, weather: .rain, isWeekend: true)
                    ) {
                        out.append(("home \(tier)/\(activity)/\(time)", placement.sprite))
                    }
                }
            }
        }
        for style in ActivitySceneStyle.allCases {
            for placement in ActivitySceneComposer.compose(style: style, appearance: appearances[0]) {
                out.append(("activity \(style)", placement.sprite))
            }
        }
        let districts = DistrictStyle.allCases.map {
            CityDistrictInfo(style: $0, selected: $0 == .downtown, hasPlayerOffice: $0 == .oldTown, rivalSeeds: [1, 2])
        }
        for time in TimeOfDay.allCases {
            for placement in CityMapComposer.compose(
                districts: districts,
                ambience: CityAmbience(timeOfDay: time, season: .autumn, playerTier: .campus)
            ) {
                out.append(("city \(time)", placement.sprite))
            }
        }
        return out
    }

    // MARK: Rule 1 — everything is a master color

    @Test func everySpriteColorIsInTheMasterPalette() {
        var offenders: [String] = []
        for (name, sprite) in Self.allSprites() {
            for (character, color) in sprite.palette where !Palettes.isMaster(color) {
                offenders.append("\(name): '\(character)' = rgb(\(color.r), \(color.g), \(color.b))")
            }
        }
        let report = Set(offenders).sorted().joined(separator: "; ")
        #expect(offenders.isEmpty, "off-palette colors: \(report)")
    }

    @Test func masterPaletteIsElevenRampsOfFiveStepsPlusCharacterRamps() {
        #expect(Palettes.ramps.count == 11)
        for ramp in Palettes.ramps {
            #expect(ramp.all.count == 5, "\(ramp.name) has five steps")
            // Ramps run light → deep with no plateau, so `shaded` and the
            // depth bands always land somewhere visibly different.
            let luminances = ramp.all.map(Palettes.luminance)
            #expect(luminances == luminances.sorted(by: >), "\(ramp.name) runs light → deep")
            for step in 1..<luminances.count {
                #expect(luminances[step - 1] - luminances[step] > 0.02, "\(ramp.name) step \(step) is a real step")
            }
        }
        #expect(Palettes.outline == Palettes.ink[4])
        // Shirts are literally master ramp pairs.
        for (base, shade) in Palettes.shirtColors {
            #expect(Palettes.isMaster(base) && Palettes.isMaster(shade))
            #expect(Palettes.luminance(base) > Palettes.luminance(shade), "shade is darker than base")
        }
    }

    @Test func nearestMasterIsIdempotentAndKeepsAlpha() {
        for color in Palettes.master {
            #expect(Palettes.nearestMaster(color) == color)
        }
        let ghost = Palettes.translucent(Palettes.gold[1], 90)
        #expect(Palettes.nearestMaster(ghost).a == 90)
        #expect(Palettes.isMaster(ghost))
    }

    // MARK: Rule 2 — rooms have depth contrast

    @Test func officeWallsAndFloorsSeparateByLuminance() {
        for tier in OfficeTierStyle.allCases {
            for time in TimeOfDay.allCases {
                let surfaces = RoomBuilder.officeSurfaces(tier: tier, time: time)
                #expect(
                    surfaces.contrast >= 0.18,
                    """
                    \(tier)/\(time): wall \(surfaces.wallLuminance) vs floor \(surfaces.floorLuminance) \
                    — the art direction needs an 18% luminance gap
                    """
                )
            }
        }
    }

    @Test func homeWallsAndFloorsSeparateByLuminance() {
        for tier in HomeTierStyle.allCases {
            for time in TimeOfDay.allCases {
                let surfaces = RoomBuilder.homeSurfaces(tier: tier, time: time)
                #expect(
                    surfaces.contrast >= 0.18,
                    """
                    \(tier)/\(time): wall \(surfaces.wallLuminance) vs floor \(surfaces.floorLuminance) \
                    — the art direction needs an 18% luminance gap
                    """
                )
            }
        }
    }

    @Test func floorsRecedeTowardTheBackWall() {
        for tier in OfficeTierStyle.allCases {
            let surfaces = RoomBuilder.officeSurfaces(tier: tier, time: .day)
            #expect(
                surfaces.farFloorLight.luminance < surfaces.floorLight.luminance,
                "\(tier): the back of the floor is darker than the front"
            )
        }
    }

    @Test func theHoursGetDarkerInOrder() {
        for tier in OfficeTierStyle.allCases {
            let walls = [TimeOfDay.day, .dusk, .night].map {
                RoomBuilder.officeSurfaces(tier: tier, time: $0).wallLuminance
            }
            #expect(walls == walls.sorted(by: >), "\(tier) office: day → dusk → night gets darker")
        }
        for tier in HomeTierStyle.allCases {
            let walls = [TimeOfDay.day, .dusk, .night].map {
                RoomBuilder.homeSurfaces(tier: tier, time: $0).wallLuminance
            }
            #expect(walls == walls.sorted(by: >), "\(tier) home: day → dusk → night gets darker")
        }
    }
}
