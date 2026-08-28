/// Amenity zones: where the game room, cafeteria, gym and shuttle go in each
/// tier, and how each zone arranges its props.
///
/// Floor zones line up in the front row to the right of the founder's desk —
/// space the desk grid already leaves empty — so the scene size never
/// changes. The shuttle is a window on the back wall with the van parked
/// outside. Zone slots per tier: garage none, loft one (only the game room
/// fits), studio three, campus four; when more amenities are owned than
/// there are slots, `AmenityStyle.allCases` order decides which are shown.
extension SceneComposer {
    // MARK: Capacity and selection

    /// How many amenity zones a tier can show.
    static func zoneCapacity(for tier: OfficeTierStyle) -> Int {
        switch tier {
        case .garage: 0
        case .loft: 1
        case .studio: 3
        case .campus: 4
        }
    }

    /// Whether a tier physically has room for an amenity at all.
    static func fits(_ amenity: AmenityStyle, in tier: OfficeTierStyle) -> Bool {
        switch tier {
        case .garage: false
        case .loft: amenity == .gameRoom
        case .studio, .campus: true
        }
    }

    /// The amenities actually rendered for a tier, in `AmenityStyle.allCases`
    /// order, capped at the tier's zone capacity.
    static func shownAmenities(for tier: OfficeTierStyle, amenities: Set<AmenityStyle>) -> [AmenityStyle] {
        Array(
            AmenityStyle.allCases
                .filter { amenities.contains($0) && fits($0, in: tier) }
                .prefix(zoneCapacity(for: tier))
        )
    }

    // MARK: Zone geometry

    /// One prop inside a zone, positioned relative to the zone's top-left.
    private struct ZoneItem {
        let name: SpriteLibrary.AmenityPropName
        let x: Int
        let y: Int
        let animation: SpriteAnimation
        let phase: Int
    }

    /// A floor zone: its footprint, its props, and (cafeteria only) the seat
    /// a break-taker occupies and which item is drawn over their lap.
    private struct Zone {
        let width: Int
        let height: Int
        let items: [ZoneItem]
        let seat: (x: Int, y: Int, coveredBy: Int)?
    }

    /// Spacing between floor zones is capped so a lone zone hugs the founder
    /// rather than drifting to the middle of a wide room.
    private static let maxZoneGap = 14
    /// Gap between the founder cell and the first zone.
    private static let zoneLead = 4
    /// Gap between props inside a zone.
    private static let propGap = 2

    private static func floorZone(for amenity: AmenityStyle) -> Zone? {
        let sprite = SpriteLibrary.amenityProp
        switch amenity {
        case .gameRoom:
            let arcade = sprite(.arcadeCabinet), foosball = sprite(.foosballTable)
            let height = max(arcade.height, foosball.height)
            return Zone(
                width: arcade.width + propGap + foosball.width,
                height: height,
                items: [
                    ZoneItem(name: .arcadeCabinet, x: 0, y: height - arcade.height, animation: .glow, phase: 1),
                    ZoneItem(name: .foosballTable, x: arcade.width + propGap, y: height - foosball.height, animation: .still, phase: 0),
                ],
                seat: nil
            )
        case .cafeteria:
            let counter = sprite(.cafeteriaCounter), vending = sprite(.vendingMachine), table = sprite(.cafeteriaTable)
            let backHeight = max(counter.height, vending.height)
            let width = counter.width + propGap + vending.width
            let tablesWidth = table.width * 2 + propGap * 2
            let tableX = (width - tablesWidth) / 2
            let tableY = backHeight + propGap
            return Zone(
                width: width,
                height: tableY + table.height,
                items: [
                    ZoneItem(name: .cafeteriaCounter, x: 0, y: backHeight - counter.height, animation: .still, phase: 0),
                    ZoneItem(name: .vendingMachine, x: counter.width + propGap, y: backHeight - vending.height, animation: .toggle(period: 3), phase: 0),
                    ZoneItem(name: .cafeteriaTable, x: tableX, y: tableY, animation: .still, phase: 0),
                    ZoneItem(name: .cafeteriaTable, x: tableX + table.width + propGap * 2, y: tableY, animation: .still, phase: 0),
                ],
                // Behind the first table: the table top covers the lap rows.
                seat: (x: tableX - 1, y: tableY - 12, coveredBy: 2)
            )
        case .gym:
            let treadmill = sprite(.treadmill), rack = sprite(.weightRack)
            let height = max(treadmill.height, rack.height)
            return Zone(
                width: treadmill.width + propGap + rack.width,
                height: height,
                items: [
                    ZoneItem(name: .treadmill, x: 0, y: height - treadmill.height, animation: .toggle(period: 1), phase: 0),
                    ZoneItem(name: .weightRack, x: treadmill.width + propGap, y: height - rack.height, animation: .still, phase: 0),
                ],
                seat: nil
            )
        case .shuttle:
            return nil // wall-mounted, see `shuttleWindow(for:)`
        }
    }

    /// Where the shuttle window hangs on the back wall, clear of the tier's
    /// own wall props and the back row's bubbles.
    private static func shuttleWindow(for tier: OfficeTierStyle) -> (x: Int, y: Int)? {
        switch tier {
        case .garage, .loft: nil
        case .studio: (x: 8, y: 2)
        case .campus: (x: 44, y: 4)
        }
    }

    /// Floor zones may not run into the tier's own front-row props.
    private static func rightReserve(for tier: OfficeTierStyle) -> Int {
        tier == .campus ? 16 : 2 // campus keeps a coffee machine front-right
    }

    // MARK: Placement

    /// Where each floor zone lands, in scene pixels.
    ///
    /// `amenityZones` lays the props out from these rectangles and
    /// `OfficeWaypoints` hangs its "go and use the game room" anchors off
    /// them, so both agree by construction.
    static func zoneFrames(
        for tier: OfficeTierStyle,
        shown: [AmenityStyle],
        size: SceneSize,
        founderY: Int
    ) -> [(amenity: AmenityStyle, x: Int, y: Int, width: Int, height: Int)] {
        let zones = shown.compactMap { amenity in floorZone(for: amenity).map { (amenity, $0) } }
        guard !zones.isEmpty else { return [] }

        let startX = Layout.sideMargin + Layout.cellWidth + zoneLead
        let endX = size.width - rightReserve(for: tier)
        let totalWidth = zones.reduce(0) { $0 + $1.1.width }
        let gap = min(maxZoneGap, (endX - startX - totalWidth) / (zones.count + 1))
        let baseline = founderY + Layout.cellHeight - 2

        var frames: [(AmenityStyle, Int, Int, Int, Int)] = []
        var x = startX + gap
        for (amenity, zone) in zones {
            frames.append((amenity, x, baseline - zone.height, zone.width, zone.height))
            x += zone.width + gap
        }
        return frames
    }

    static func amenityZones(
        for tier: OfficeTierStyle,
        shown: [AmenityStyle],
        size: SceneSize,
        founderY: Int,
        onBreak: Occupant?
    ) -> [PlacedSprite] {
        guard !shown.isEmpty else { return [] }
        var placements: [PlacedSprite] = []

        func place(_ item: ZoneItem, atX x: Int, y: Int) -> PlacedSprite {
            PlacedSprite(
                sprite: SpriteCache.shared("amenity.\(item.name.rawValue)") { SpriteLibrary.amenityProp(item.name) },
                x: x + item.x, y: y + item.y,
                kind: .amenityProp(item.name),
                animation: item.animation, phase: item.phase
            )
        }

        if shown.contains(.shuttle), let window = shuttleWindow(for: tier) {
            placements.append(place(
                ZoneItem(name: .shuttleVan, x: 0, y: 0, animation: .still, phase: 0),
                atX: window.x, y: window.y
            ))
        }

        let zones = shown.compactMap { amenity in floorZone(for: amenity).map { (amenity, $0) } }
        guard !zones.isEmpty else { return placements }

        let startX = Layout.sideMargin + Layout.cellWidth + zoneLead
        let endX = size.width - rightReserve(for: tier)
        let totalWidth = zones.reduce(0) { $0 + $1.1.width }
        let gap = min(maxZoneGap, (endX - startX - totalWidth) / (zones.count + 1))
        let baseline = founderY + Layout.cellHeight - 2

        var x = startX + gap
        for (amenity, zone) in zones {
            let y = baseline - zone.height
            for (index, item) in zone.items.enumerated() {
                if amenity == .cafeteria, let onBreak, let seat = zone.seat, seat.coveredBy == index {
                    placements.append(PlacedSprite(
                        sprite: SpriteCache.person(appearance: onBreak.appearance, pose: .seated, isFounder: onBreak.isFounder, role: onBreak.role),
                        x: x + seat.x, y: y + seat.y,
                        kind: .person,
                        animation: .typing(slow: true),
                        phase: 4
                    ))
                }
                placements.append(place(item, atX: x, y: y))
            }
            x += zone.width + gap
        }
        return placements
    }
}
