import Testing
@testable import PixelKit

/// The city map's five district rects are what the accessibility overlay
/// is built from, so they have to be a partition of the map: every pixel
/// belongs to exactly one district, and every district gets exactly one
/// rect. A gap is a district VoiceOver cannot reach; an overlap is two
/// elements over the same place.
@Suite("City district rects")
struct CityDistrictRegionTests {
    @Test func everyDistrictHasOneRect() {
        for style in DistrictStyle.allCases {
            let frame = CityMapComposer.districtFrame(style)
            #expect(frame.width > 0 && frame.height > 0, "\(style) has no rect")
        }
        #expect(CityMapComposer.frames.count == DistrictStyle.allCases.count)
    }

    @Test func theRectsCoverEveryPixelExactlyOnce() {
        let size = CityMapComposer.sceneSize()
        var counted = 0
        for y in 0..<size.height {
            for x in 0..<size.width {
                let hits = DistrictStyle.allCases.filter {
                    CityMapComposer.districtFrame($0).contains(x: x, y: y)
                }
                #expect(hits.count == 1, "(\(x), \(y)) is in \(hits.count) districts")
                counted += hits.count
            }
        }
        #expect(counted == size.width * size.height)
    }

    @Test func theRectsAddUpToTheMap() {
        let size = CityMapComposer.sceneSize()
        let area = DistrictStyle.allCases
            .map { CityMapComposer.districtFrame($0) }
            .reduce(0) { $0 + $1.width * $1.height }
        #expect(area == size.width * size.height)
    }

    @Test func theRectsStayInsideTheMap() {
        let size = CityMapComposer.sceneSize()
        for style in DistrictStyle.allCases {
            let frame = CityMapComposer.districtFrame(style)
            #expect(frame.x >= 0 && frame.y >= 0, "\(style) starts off the map")
            #expect(frame.x + frame.width <= size.width, "\(style) runs off the right")
            #expect(frame.y + frame.height <= size.height, "\(style) runs off the bottom")
        }
    }

    @Test func theOfficeMarkerSitsInsideItsOwnDistrict() {
        for style in DistrictStyle.allCases {
            let marker = CityMapComposer.officeMarkerFrame(for: style)
            let district = CityMapComposer.districtFrame(style)
            #expect(marker.width > 0 && marker.height > 0, "\(style) has no marker")
            #expect(
                CityMapComposer.hitTest(x: marker.x + marker.width / 2, y: marker.y + marker.height / 2) == style,
                "\(style)'s office marker is not in \(style)"
            )
            #expect(
                marker.x >= district.x && marker.x + marker.width <= district.x + district.width,
                "\(style)'s office marker runs out of the district"
            )
        }
    }
}
