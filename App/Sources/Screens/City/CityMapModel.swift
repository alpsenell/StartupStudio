import Foundation
import PixelKit
import TycoonEngine

// MARK: S4 (city)

/// A push inside the city map's own navigation stack: a rival's profile
/// opens over the map, so Back returns to it.
enum CityMapDestination: Hashable {
    case rival(UUID)
}

/// Everything the map draws, read from the game. Nothing here is stored:
/// the rivals' districts come from `Rival.homeDistrict` (derived from the
/// appearance seed when a rival has none), the landmarks from the founder's
/// own record, the old office from the event log.
struct CityMapReading: Hashable, Sendable {
    var districts: [CityDistrictInfo]
    var landmarks: CityLandmarks
    var tier: OfficeTierStyle
    var season: PixelKit.Season
    // MARK: Iteration 18 — the studio mark on the HQ sign; nil draws the
    // map exactly as it always was.
    var markSeed: UInt64?
    // MARK: end of Iteration 18
}

extension GameState {
    /// The district the office moved out of, read from the event log: the
    /// district before the latest relocation (the founding Old Town when
    /// there has been only one). `nil` for a company that never moved.
    var cityFormerOfficeDistrict: DistrictID? {
        let moves = eventLog.compactMap { event -> DistrictID? in
            if case .officeRelocated(let district, _) = event { return district }
            return nil
        }
        guard !moves.isEmpty else { return nil }
        let previous = moves.count >= 2 ? moves[moves.count - 2] : CityState.legacy.district
        return previous == city.district ? nil : previous
    }

    /// The day the company last moved, for the old office's line.
    var cityLastMoveDay: Int? {
        eventLog.last { event in
            if case .officeRelocated = event { return true }
            return false
        }.flatMap { event in
            if case .officeRelocated(_, let day) = event { return day }
            return nil
        }
    }

    /// The rivals headquartered in a district, in roster order — the same
    /// order the map's pins and buildings are drawn in.
    func cityRivals(in district: DistrictID) -> [Rival] {
        rivals.rivals.filter { $0.homeDistrict == district }
    }

    /// A child at school today (the Suburbs school is drawn while one is).
    func cityChildAtSchool(balance: BalanceConfig) -> Bool {
        life.family.children.contains { $0.stage(on: day, balance: balance.childhood) == .school }
    }

    /// The places the founder's life has put on the map.
    func cityLandmarks(balance: BalanceConfig) -> CityLandmarks {
        CityLandmarks(
            hospital: !economy.hospitalizationDays.isEmpty,
            courthouse: !crime.cases.isEmpty,
            school: cityChildAtSchool(balance: balance),
            formerOffice: cityFormerOfficeDistrict.flatMap { DistrictStyle(rawValue: $0.rawValue) },
            openVenue: networking.pendingEvent.flatMap { CityVenueStyle(rawValue: $0.venue.rawValue)?.district }
        )
    }
}

/// The name plate over a focused thing, in scene pixels.
struct CityMapTag: Hashable, Sendable {
    var label: String
    var line: String?
    var rect: CityMapComposer.Rect
}

/// The live map's memo. The scene view asks for placements every frame;
/// this composes the layers once per (reading, hour) and only the traffic
/// per frame, so a frame costs the traffic and an array append. The hour
/// rolls on the office's own four-minute clock (`OfficeAmbience.timeOfDay`),
/// never on the simulation's day. Called from the renderer on the main
/// thread; the lock is belt and braces.
final class CityMapSceneCache: @unchecked Sendable {
    private let lock = NSLock()
    private var reading: CityMapReading?
    private var byHour: [TimeOfDay: CityMapComposer.CityMapLayers] = [:]
    private var tagKey: CityMapTag?
    private var tagSprite: PlacedSprite?

    /// One frame: the hour's layers, the traffic at `t`, the name plate.
    func placements(at t: TimeInterval, reading: CityMapReading, tag: CityMapTag?, pace: Double) -> [PlacedSprite] {
        let hour = OfficeAmbience.timeOfDay(at: t, startingAt: .day)
        let layers = layers(for: reading, hour: hour)
        var list = layers.base
        list += CityMapComposer.traffic(at: t, pace: pace, time: hour)
        list += layers.overlay
        if let plate = plate(for: tag) { list.append(plate) }
        return list
    }

    /// The composed layers for a reading at an hour, built on first ask.
    func layers(for reading: CityMapReading, hour: TimeOfDay) -> CityMapComposer.CityMapLayers {
        lock.lock()
        defer { lock.unlock() }
        if self.reading != reading {
            self.reading = reading
            byHour = [:]
        }
        if let hit = byHour[hour] { return hit }
        let layers = CityMapComposer.layers(
            districts: reading.districts,
            ambience: CityAmbience(
                timeOfDay: hour, season: reading.season, playerTier: reading.tier,
                // MARK: Iteration 18 — the studio mark
                markSeed: reading.markSeed
                // MARK: end of Iteration 18
            ),
            landmarks: reading.landmarks
        )
        byHour[hour] = layers
        return layers
    }

    /// The tappable regions for a reading (they do not depend on the hour).
    func regions(for reading: CityMapReading) -> [CityHitRegion] {
        layers(for: reading, hour: .day).regions
    }

    private func plate(for tag: CityMapTag?) -> PlacedSprite? {
        lock.lock()
        defer { lock.unlock() }
        if tag != tagKey {
            tagKey = tag
            tagSprite = tag.map { CityMapComposer.nameTag(label: $0.label, line: $0.line, over: $0.rect) }
        }
        return tagSprite
    }
}
// MARK: end S4
