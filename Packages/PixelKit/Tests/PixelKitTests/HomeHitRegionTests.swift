import Foundation
import SwiftUI
import Testing
@testable import PixelKit

/// The home as something a finger — or VoiceOver — can land on. The office
/// suite's counterpart: everyone who lives here gets exactly one region,
/// every region is where the composer actually drew the sprite, and nobody
/// is left standing on the wall.
@Suite("Home hit regions")
struct HomeHitRegionTests {
    // MARK: Fixtures

    func household(partner: Bool = false, children: Int = 0) -> HomeOccupants {
        HomeOccupants(
            founder: CharacterAppearance(seed: 1),
            founderName: "Mira",
            partner: partner ? CharacterAppearance(seed: 2) : nil,
            partnerName: partner ? "Sam" : nil,
            partnerNote: partner ? "affection sliding" : nil,
            children: (0..<children).map {
                HomeOccupants.Child(
                    id: HomeOccupants.derivedChildID(index: $0),
                    appearance: CharacterAppearance(seed: UInt64(10 + $0)),
                    name: ["Ada", "Bo", "Cy"][$0]
                )
            }
        )
    }

    func regions(
        tier: HomeTierStyle,
        activity: HomeActivity,
        partner: Bool = false,
        children: Int = 0,
        mood: MoodLevel = .okay,
        signals: HomeSignals = .none
    ) -> [HomeHitRegion] {
        HomeSceneComposer.hitRegions(
            tier: tier, occupants: household(partner: partner, children: children),
            activity: activity, mood: mood, ambience: .evening, signals: signals
        )
    }

    /// Every tier × activity pairing, the same sweep the composer suite uses.
    var allCombos: [(HomeTierStyle, HomeActivity)] {
        HomeTierStyle.allCases.flatMap { tier in HomeActivity.allCases.map { (tier, $0) } }
    }

    // MARK: People

    @Test func everyOccupantGetsARegion() {
        for (tier, activity) in allCombos {
            // Three children only fit where the tier has three spots, and
            // every tier authors three, so the whole household should read.
            let found = regions(tier: tier, activity: activity, partner: true, children: 3)
            let kinds = Set(found.map(\.kind))
            if activity.isFounderHome {
                #expect(kinds.contains(.founder), "\(tier)/\(activity): no founder region")
            } else {
                #expect(!kinds.contains(.founder), "\(tier)/\(activity): founder is away and still has a region")
            }
            #expect(kinds.contains(.partner), "\(tier)/\(activity): no partner region")
            for index in 0..<3 {
                let id = HomeOccupants.derivedChildID(index: index)
                #expect(kinds.contains(.child(id)), "\(tier)/\(activity): no region for child \(index)")
            }
        }
    }

    @Test func aChildIsCarriedByTheIdTheAppGaveIt() {
        let alpha = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!
        let occupants = HomeOccupants(
            founder: CharacterAppearance(seed: 1),
            founderName: "Mira",
            children: [HomeOccupants.Child(id: alpha, appearance: CharacterAppearance(seed: 9), name: "Ada")]
        )
        let found = HomeSceneComposer.hitRegions(
            tier: .house, occupants: occupants, activity: .relaxing, mood: .okay
        )
        #expect(found.contains { $0.kind == .child(alpha) })
    }

    @Test func eachOccupantGetsExactlyOneRegion() {
        for (tier, activity) in allCombos {
            let found = regions(tier: tier, activity: activity, partner: true, children: 3)
            #expect(found.count == Set(found.map(\.kind)).count, "\(tier)/\(activity): duplicate regions")
        }
    }

    /// The wall is the top band of the room; the floor is everything under
    /// it. Nobody in this house floats on the wall — every figure's feet
    /// are on the floor, which is also what makes the label land where a
    /// sighted player sees the person.
    @Test func nobodyStandsOnTheWall() {
        for (tier, activity) in allCombos {
            let wall = HomeSceneComposer.wallHeight(for: tier)
            for region in regions(tier: tier, activity: activity, partner: true, children: 3)
            where region.kind.isPerson {
                #expect(
                    region.y + region.height > wall,
                    "\(tier)/\(activity): \(region.kind) has its feet on the wall"
                )
            }
        }
    }

    @Test func everyRegionIsInsideTheRoom() {
        for (tier, activity) in allCombos {
            let size = HomeSceneComposer.sceneSize(for: tier)
            for region in regions(
                tier: tier, activity: activity, partner: true, children: 3, mood: .low,
                signals: HomeSignals(relationshipsLow: true, healthLow: true, billsDue: true)
            ) {
                #expect(region.x >= 0, "\(tier)/\(activity): \(region.kind) x")
                #expect(region.y >= 0, "\(tier)/\(activity): \(region.kind) y")
                #expect(region.x + region.width <= size.width, "\(tier)/\(activity): \(region.kind) right edge")
                #expect(region.y + region.height <= size.height, "\(tier)/\(activity): \(region.kind) bottom edge")
                #expect(region.width >= 4 && region.height >= 2, "\(tier)/\(activity): \(region.kind) too small to hit")
            }
        }
    }

    // MARK: Furniture

    @Test func theFurnitureInTheRoomReads() {
        // The house has the fullest set of authored fixtures.
        let found = regions(tier: .house, activity: .dinner, partner: true, children: 1)
        let fixtures = Set(found.compactMap { kind -> HomeFixture? in
            if case .furniture(let fixture) = kind.kind { return fixture }
            return nil
        })
        for expected: HomeFixture in [.bed, .couch, .armchair, .diningTable, .television, .crib, .lamp, .window, .bookshelf, .fireplace] {
            #expect(fixtures.contains(expected), "the house has no \(expected) region")
        }
    }

    @Test func theRoomAndTheOverlayAreNotThingsInTheRoom() {
        // The background sprite and the lighting overlay both cover the
        // whole scene; either as a region would swallow everything else.
        let size = HomeSceneComposer.sceneSize(for: .penthouse)
        let found = regions(tier: .penthouse, activity: .sleeping, partner: true)
        for region in found {
            #expect(
                !(region.width == size.width && region.height == size.height),
                "\(region.kind) is the whole room"
            )
        }
    }

    @Test func aRoomInABadWeekNamesWhatItIsShowing() {
        let low = regions(tier: .apartment, activity: .relaxing, mood: .low)
        let fixtures = Set(low.compactMap { kind -> HomeFixture? in
            if case .furniture(let fixture) = kind.kind { return fixture }
            return nil
        })
        #expect(fixtures.contains(.laundry))
        #expect(fixtures.contains(.takeaway))
        #expect(fixtures.contains(.deadPlant))

        let great = regions(tier: .apartment, activity: .relaxing, mood: .great)
        let goodFixtures = Set(great.compactMap { kind -> HomeFixture? in
            if case .furniture(let fixture) = kind.kind { return fixture }
            return nil
        })
        #expect(goodFixtures.contains(.flowers))
        #expect(!goodFixtures.contains(.laundry))
    }

    // MARK: Order and hit-testing

    @Test func peopleAreReadBeforeFurniture() {
        let found = regions(tier: .house, activity: .relaxing, partner: true, children: 2)
        let firstFurniture = found.firstIndex { !$0.kind.isPerson } ?? found.count
        let lastPerson = found.lastIndex { $0.kind.isPerson } ?? -1
        #expect(lastPerson < firstFurniture, "furniture is read before somebody in the room")
        for region in found where region.kind.isPerson {
            #expect(region.sortPriority > 0, "\(region.kind) does not outrank the furniture")
        }
    }

    @Test func aPointOnSomebodySittingOnTheSofaIsTheSomebody() {
        let occupants = household()
        let found = HomeSceneComposer.hitRegions(
            tier: .apartment, occupants: occupants, activity: .relaxing, mood: .okay
        )
        guard let hit = found.first(where: { $0.kind == .founder }) else {
            Issue.record("the founder has no region")
            return
        }
        let point = (x: hit.x + hit.width / 2, y: hit.y + hit.height - 2)
        let region = HomeSceneComposer.hitTest(
            tier: .apartment, occupants: occupants, activity: .relaxing, mood: .okay,
            x: point.x, y: point.y
        )
        #expect(region?.kind == .founder)
    }

    @Test func aPointOffTheRoomHitsNothing() {
        let occupants = household()
        #expect(HomeSceneComposer.hitTest(
            tier: .studioFlat, occupants: occupants, activity: .relaxing, mood: .okay,
            x: -5, y: -5
        ) == nil)
    }

    // MARK: The spoken room

    @Test func theLabelsSayWhoAndWhat() {
        let view = HomeSceneView(
            tier: .house,
            occupants: household(partner: true, children: 1),
            activity: .dinner,
            mood: .low
        )
        #expect(view.label(for: .founder) == "Mira, at dinner, worn down")
        #expect(view.label(for: .partner) == "Sam, your partner, affection sliding")
        #expect(view.label(for: .child(HomeOccupants.derivedChildID(index: 0))) == "Ada, your child")
        #expect(view.label(for: .furniture(.couch)) == "The sofa")
        #expect(view.sceneSummary.contains("house"))
        #expect(view.sceneSummary.contains("Sam is in"))
    }

    @Test func anUnnamedHouseholdStillReads() {
        let view = HomeSceneView(
            tier: .studioFlat,
            occupants: HomeOccupants(founder: CharacterAppearance(seed: 3)),
            activity: .sleeping,
            mood: .okay
        )
        #expect(view.label(for: .founder) == "You, asleep in bed")
        #expect(view.sceneSummary.contains("studio flat"))
    }
}
