import Testing
@testable import PixelKit

@Suite("OfficeTierStyle")
struct OfficeTierStyleTests {
    @Test func deskCapacities() {
        #expect(OfficeTierStyle.garage.deskCapacity == 3)
        #expect(OfficeTierStyle.loft.deskCapacity == 6)
        #expect(OfficeTierStyle.studio.deskCapacity == 14)
        #expect(OfficeTierStyle.campus.deskCapacity == 40)
    }

    @Test func allTiersPresent() {
        #expect(OfficeTierStyle.allCases == [.garage, .loft, .studio, .campus])
    }

    @Test func workStatusCases() {
        #expect(WorkStatus.allCases == [
            .idle, .coding, .designing, .marketing, .researching,
            .testing, .legal, .peopleOps, .operations,
        ])
    }

    @Test func amenityStylesMirrorTheEngineRawValues() {
        #expect(AmenityStyle.allCases == [.gameRoom, .cafeteria, .shuttle, .gym])
        #expect(AmenityStyle.allCases.map(\.rawValue) == ["gameRoom", "cafeteria", "shuttle", "gym"])
    }
}
