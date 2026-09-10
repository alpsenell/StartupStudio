import Foundation

// MARK: S4 (city)

/// The five networking rooms, as the map draws them. Raw values mirror the
/// engine's `NetworkingVenue` (PixelKit never imports TycoonEngine; the app
/// maps between them with `init(rawValue:)`). Each stands in the district
/// whose character it fits, one per district.
public enum CityVenueStyle: String, Sendable, CaseIterable {
    case coworkingMixer, rooftopParty, demoDay, hackerHouse, conferenceBar

    /// The district the room stands in.
    public var district: DistrictStyle {
        switch self {
        case .coworkingMixer: .oldTown      // a converted brick warehouse
        case .rooftopParty: .downtown       // a tower with a terrace on top
        case .demoDay: .techPark            // the accelerator's hall
        case .hackerHouse: .suburbs         // six laptops, one sofa
        case .conferenceBar: .midtown       // the conference hotel's bar
        }
    }
}

extension DistrictStyle {
    /// The networking room that stands in this district.
    public var venue: CityVenueStyle {
        CityVenueStyle.allCases.first { $0.district == self } ?? .coworkingMixer
    }
}

/// The places the founder's own life has put on the map. Everything here
/// is read from the game (a hospital stay, a case in court, a child at
/// school, the office the company moved out of) — the map never invents
/// one. The default is none of them, which is the map every existing
/// caller draws.
public struct CityLandmarks: Sendable, Equatable, Hashable {
    /// The founder has been in hospital: the Midtown hospital is drawn.
    public var hospital: Bool
    /// The founder has been to court: the Old Town courthouse is drawn.
    public var courthouse: Bool
    /// A child is at school: the Suburbs school is drawn.
    public var school: Bool
    /// The district of the office the company moved out of, drawn boarded
    /// up with a "TO LET" board. `nil` for a company that never moved.
    public var formerOffice: DistrictStyle?
    /// The district whose networking room is open tonight: its sign is
    /// lit and a crowd is out front.
    public var openVenue: DistrictStyle?

    public init(
        hospital: Bool = false, courthouse: Bool = false, school: Bool = false,
        formerOffice: DistrictStyle? = nil, openVenue: DistrictStyle? = nil
    ) {
        self.hospital = hospital
        self.courthouse = courthouse
        self.school = school
        self.formerOffice = formerOffice
        self.openVenue = openVenue
    }

    public static let none = CityLandmarks()
}

/// One thing on the map a finger can land on. Every target belongs to a
/// district (`district`), which is what a tap selects before anything else.
public enum CityHitTarget: Sendable, Equatable, Hashable {
    /// The district's ground, roads and anything without a region of its own.
    case district(DistrictStyle)
    /// The player's headquarters (the building or its flag).
    case office(DistrictStyle)
    /// The founder's home pin.
    case home(DistrictStyle)
    /// A rival studio's building or pin; `index` is its position in that
    /// district's `CityDistrictInfo.rivalSeeds`.
    case rival(DistrictStyle, index: Int)
    /// The district's networking room.
    case venue(DistrictStyle)
    case hospital
    case courthouse
    case school
    /// The office the company moved out of.
    case formerOffice(DistrictStyle)

    /// The district the target stands in.
    public var district: DistrictStyle {
        switch self {
        case .district(let style), .office(let style), .home(let style),
             .rival(let style, _), .venue(let style), .formerOffice(let style):
            style
        case .hospital: CityMapComposer.hospitalDistrict
        case .courthouse: CityMapComposer.courthouseDistrict
        case .school: CityMapComposer.schoolDistrict
        }
    }
}

/// A tappable rectangle on the map, in scene pixels.
public struct CityHitRegion: Sendable, Equatable {
    public let target: CityHitTarget
    public let rect: CityMapComposer.Rect

    public init(target: CityHitTarget, rect: CityMapComposer.Rect) {
        self.target = target
        self.rect = rect
    }
}

/// What a lot holds when nothing claims it.
enum CityLotUse: Equatable {
    /// The district's own building, in one of its variants.
    case building(variant: Int)
    /// A small café with its awning out (Midtown).
    case cafe
    /// The district's networking room.
    case venue
    /// The hospital when the founder has been there, else a building.
    case hospital
    /// The courthouse when the founder has been there, else a building.
    case courthouse
    /// The school when a child is at one, else a playground.
    case school
    /// The old office when the company moved out of this district, else a
    /// building.
    case formerOffice
}

/// One authored building plot: a footprint standing on `baseline` (the
/// first scene row *below* the building), `width` wide and `height` tall.
/// `claimable` lots are the ones a headquarters may take over.
struct CityLot: Equatable {
    let x: Int
    let baseline: Int
    let width: Int
    let height: Int
    let use: CityLotUse
    let claimable: Bool

    init(_ x: Int, _ baseline: Int, _ width: Int, _ height: Int, _ use: CityLotUse, claimable: Bool = false) {
        self.x = x
        self.baseline = baseline
        self.width = width
        self.height = height
        self.use = use
        self.claimable = claimable
    }

    var top: Int { baseline - height }
    var centerX: Int { x + width / 2 }
}

/// A piece of set dressing: a tree, a bench, a lamp.
enum CityScenery: Equatable {
    case tree, gardenTree, bush, bench, lamp, clockTower, antenna, fountain
}

extension CityMapComposer {
    // MARK: Where the special buildings stand

    static let hospitalDistrict: DistrictStyle = .midtown
    static let courthouseDistrict: DistrictStyle = .oldTown
    static let schoolDistrict: DistrictStyle = .suburbs

    // MARK: The lots

    /// Hand-placed plots per district, in the order a rival claims them
    /// from the far end. Heights are authored against the roads: nothing
    /// grows into a street, and each district's tallest claimable lot
    /// leaves room for a campus tower (46 rows) above it.
    static func lots(for district: DistrictStyle) -> [CityLot] {
        switch district {
        case .suburbs: [
            // North row, facing the lane.
            CityLot(4, 49, 16, 13, .building(variant: 0), claimable: true),
            CityLot(24, 49, 26, 16, .school),
            CityLot(54, 49, 20, 19, .venue),
            CityLot(78, 49, 22, 16, .formerOffice),
            // South row, facing the spine.
            CityLot(4, 102, 18, 14, .building(variant: 2), claimable: true),
            CityLot(26, 102, 22, 16, .building(variant: 3), claimable: true),
            CityLot(52, 102, 24, 18, .building(variant: 1), claimable: true),
            CityLot(80, 102, 20, 14, .building(variant: 0), claimable: true),
        ]
        case .midtown: [
            CityLot(114, 48, 28, 22, .hospital),
            CityLot(111, 77, 17, 17, .formerOffice),
            CityLot(152, 77, 16, 22, .building(variant: 3), claimable: true),
            CityLot(192, 77, 16, 18, .building(variant: 2), claimable: true),
            CityLot(112, 102, 18, 26, .building(variant: 0), claimable: true),
            CityLot(132, 102, 18, 34, .building(variant: 1), claimable: true),
            CityLot(152, 102, 14, 10, .cafe),
            CityLot(168, 102, 22, 24, .venue),
            CityLot(192, 102, 18, 22, .building(variant: 2), claimable: true),
        ]
        case .techPark: [
            CityLot(220, 56, 30, 16, .venue),
            CityLot(254, 56, 18, 24, .building(variant: 1), claimable: true),
            CityLot(276, 56, 20, 20, .building(variant: 2), claimable: true),
            CityLot(299, 56, 17, 18, .formerOffice),
            CityLot(252, 102, 20, 26, .building(variant: 0), claimable: true),
            CityLot(274, 102, 22, 34, .building(variant: 3), claimable: true),
            CityLot(298, 102, 18, 22, .building(variant: 1), claimable: true),
        ]
        case .oldTown: [
            // North row, backing onto the spine's pavement.
            CityLot(16, 151, 16, 22, .building(variant: 0), claimable: true),
            CityLot(34, 151, 24, 20, .venue),
            CityLot(60, 151, 16, 26, .building(variant: 1), claimable: true),
            CityLot(78, 151, 14, 20, .building(variant: 2), claimable: true),
            CityLot(94, 151, 18, 24, .formerOffice),
            CityLot(114, 151, 10, 18, .building(variant: 3)),
            // South row, on the quay.
            CityLot(4, 199, 20, 30, .building(variant: 2), claimable: true),
            CityLot(26, 199, 30, 22, .courthouse),
            CityLot(58, 199, 20, 36, .building(variant: 3), claimable: true),
            CityLot(80, 199, 16, 24, .building(variant: 0), claimable: true),
            CityLot(98, 199, 26, 20, .building(variant: 1), claimable: true),
        ]
        case .downtown: [
            // North row.
            CityLot(136, 151, 16, 30, .building(variant: 0), claimable: true),
            CityLot(154, 151, 22, 34, .venue),
            CityLot(178, 151, 16, 36, .building(variant: 1), claimable: true),
            CityLot(196, 151, 14, 28, .building(variant: 2), claimable: true),
            CityLot(212, 151, 18, 32, .building(variant: 3), claimable: true),
            CityLot(232, 151, 17, 26, .formerOffice),
            CityLot(250, 151, 18, 36, .building(variant: 1), claimable: true),
            CityLot(270, 151, 14, 30, .building(variant: 0), claimable: true),
            CityLot(286, 151, 16, 34, .building(variant: 2), claimable: true),
            CityLot(304, 151, 14, 26, .building(variant: 3), claimable: true),
            // South row, either side of the plaza.
            CityLot(136, 199, 18, 40, .building(variant: 2), claimable: true),
            CityLot(156, 199, 16, 34, .building(variant: 3), claimable: true),
            CityLot(212, 199, 18, 44, .building(variant: 0), claimable: true),
            CityLot(232, 199, 16, 38, .building(variant: 1), claimable: true),
            CityLot(250, 199, 20, 42, .building(variant: 3), claimable: true),
            CityLot(272, 199, 16, 36, .building(variant: 2), claimable: true),
            CityLot(290, 199, 26, 30, .building(variant: 0), claimable: true),
        ]
        }
    }

    /// Trees, benches, lamps and landmarks per district: (what, x, y) with
    /// (x, y) the sprite's top-left.
    static func scenery(for district: DistrictStyle) -> [(CityScenery, Int, Int)] {
        switch district {
        case .suburbs: [
            (.tree, 6, 14), (.gardenTree, 22, 20), (.tree, 66, 16), (.gardenTree, 86, 12),
            (.bush, 42, 28), (.bush, 80, 30),
            (.tree, 4, 58), (.gardenTree, 30, 62), (.tree, 56, 60), (.gardenTree, 86, 60),
            (.bush, 22, 98), (.bush, 48, 98), (.bush, 76, 98),
            (.bush, 20, 45), (.bush, 50, 45), (.bush, 74, 45),
        ]
        case .midtown: [
            (.tree, 152, 30), (.tree, 170, 33), (.tree, 188, 7), (.tree, 196, 24), (.tree, 178, 12),
            (.lamp, 186, 36), (.bench, 158, 44), (.bench, 194, 44),
            (.gardenTree, 176, 62),
        ]
        case .techPark: [
            (.tree, 262, 18), (.gardenTree, 282, 10), (.antenna, 304, 4), (.gardenTree, 283, 60),
        ]
        case .oldTown: [
            (.clockTower, 4, 118), (.gardenTree, 100, 154), (.gardenTree, 6, 156),
        ]
        case .downtown: [
            (.fountain, 188, 178), (.tree, 199, 164), (.tree, 175, 186),
            (.bench, 182, 168), (.bench, 200, 192), (.lamp, 176, 172), (.lamp, 208, 178),
        ]
        }
    }

    /// Streetlights along the spine's north pavement.
    static let spineLampXs = [8, 48, 88, 128, 168, 196, 236, 276, 306]
}
// MARK: end S4
