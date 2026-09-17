import PixelKit
import SwiftUI
import TycoonEngine

/// The scrollable pixel city: five districts, the player's office flag,
/// rival HQ pins. Tap a district to select it; the bottom panel shows its
/// terms (rent, buy, perks) and the move/buy/sell actions. Presented full
/// screen from the HQ office card.
///
/// S4 (city): the city is a place now. Every thing on it — the office, the
/// home pin, each rival's building and pin, the five networking rooms, the
/// hospital, the courthouse and the school when the founder's life has put
/// them there, the office the company moved out of — is a hit region with
/// a label. A first tap selects the thing's district and puts its pixel
/// name plate over it; a second tap (or the panel's button) opens it: a
/// rival's profile and a room that is open tonight open over the map, the
/// office, the home and the founder's own places take the player to the
/// card or screen that owns them. The traffic runs at the game's speed.
struct CityMapScreen: View {
    let engine: GameEngine

    @Environment(\.dismiss) private var dismiss
    @State private var selectedDistrict: DistrictID
    // MARK: S4 (city)
    @Environment(AppRouter.self) private var router: AppRouter?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// The thing the last tap landed on; a second tap on it opens it.
    @State private var focused: CityHitTarget?
    @State private var path: [CityMapDestination] = []
    @State private var showingVenue = false
    @State private var sceneCache = CityMapSceneCache()
    /// Where the map opens scrolled to: the selected district's middle.
    private let initialAnchor: UnitPoint
    // MARK: end S4

    /// The phone's pixel scale, and the floor everywhere: 320 × 3 = 960
    /// points (S4's city), panned inside the ScrollView on every iPhone.
    private static let phoneMapScale = 3

    /// The map's integer pixel scale for a view this wide (R8).
    ///
    /// It has to be a whole number and the same number the tap handler
    /// divides by, which is why this is `.fixed(_)` rather than
    /// `.fitWidth` — a pannable scene takes its exact drawn size so a
    /// finger lands on the pixel it looks like it landed on.
    ///
    /// The map is presented as a full-screen cover, so on an iPad it gets
    /// the whole 1,024-point screen rather than the game's centred column,
    /// and a scale pinned at 3 left the city floating small in the middle
    /// of it. Above 5 the districts stop reading as one city, so that is
    /// the ceiling.
    ///
    /// S4 (city): the ladder is keyed to the 224-pixel width the city had
    /// when it was pinned, not to today's 320, so every device keeps the
    /// scale it had (3 on every phone, 4 on a 13" iPad) and the bigger city
    /// pans under the finger at that scale rather than shrinking.
    static func mapScale(forWidth width: CGFloat) -> Int {
        let sceneWidth = scaleReferenceWidth
        guard width.isFinite, width > 0, sceneWidth > 0 else { return phoneMapScale }
        return min(5, max(phoneMapScale, Int(width) / sceneWidth))
    }

    /// Room under the map for the district panel, so every district can be
    /// scrolled clear of it. Expressed in *scene rows* rather than points
    /// (280 points at the phone's scale 3, and the same rows of clearance
    /// at every larger scale), so a bigger map keeps the same margin
    /// around its own bottom edge.
    static func panelClearance(scale: Int) -> CGFloat {
        (280.0 / CGFloat(phoneMapScale) * CGFloat(scale)).rounded()
    }

    // MARK: S4 (city)
    /// The scene width the scale ladder was pinned against (the old city).
    static let scaleReferenceWidth = 224

    /// The panel's "who's here" block, on top of `panelClearance`: 100
    /// points at the phone's scale, in scene rows like the rest.
    static func whoIsHereClearance(scale: Int) -> CGFloat {
        (100.0 / CGFloat(phoneMapScale) * CGFloat(scale)).rounded()
    }
    // MARK: end S4

    init(engine: GameEngine, initialDistrict: DistrictID? = nil) {
        self.engine = engine
        // MARK: S4 (city) — `-autoCityDistrict` picks the panel a pass lands on
        let district = DebugLaunch.launchCityDistrict ?? initialDistrict ?? engine.state.city.district
        _selectedDistrict = State(initialValue: district)
        let frame = CityMapComposer.districtFrame(DistrictStyle(rawValue: district.rawValue) ?? .oldTown)
        let scene = CityMapComposer.sceneSize()
        initialAnchor = UnitPoint(
            x: Double(frame.x + frame.width / 2) / Double(scene.width),
            y: Double(frame.y + frame.height / 2) / Double(scene.height)
        )
        // MARK: end S4
    }

    var body: some View {
        NavigationStack(path: $path) {
            GeometryReader { proxy in
                let scale = Self.mapScale(forWidth: proxy.size.width)
                // MARK: S4 (city)
                let reading = self.reading
                let tag = focusTag(in: reading)
                let cache = sceneCache
                let pace = reduceMotion ? 0 : (engine.state.speed.ticksPerSecond ?? 0)
                // MARK: end S4
                ZStack(alignment: .bottom) {
                    ScrollView([.horizontal, .vertical]) {
                        PixelSceneView(
                            sceneSize: CityMapComposer.sceneSize(),
                            scale: .fixed(scale),
                            accessibilityLabel: mapAccessibilityLabel
                        ) { t in
                            cache.placements(at: t, reading: reading, tag: tag, pace: pace)
                        }
                        .onTapGesture { location in
                            let x = Int(location.x) / scale
                            let y = Int(location.y) / scale
                            // MARK: S4 (city) — the thing under the finger, else its district
                            if let target = CityMapComposer.target(
                                atX: x, y: y, in: cache.regions(for: reading)
                            ) {
                                activate(target)
                            }
                            // MARK: end S4
                        }
                        // Keep every district reachable above the panel.
                        .padding(.bottom, Self.panelClearance(scale: scale) + Self.whoIsHereClearance(scale: scale))
                    }
                    // The canvas is one picture; the districts laid over it
                    // are the things in it.
                    .accessibilityHidden(true)
                    .overlay { districtElements(scale: scale) }
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel(mapAccessibilityLabel)
                    .defaultScrollAnchor(initialAnchor)
                    .background(Theme.screenBackground)

                    DistrictDetailPanel(
                        engine: engine, district: selectedDistrict,
                        // MARK: S4 (city)
                        focused: focused,
                        onOpen: { open($0) },
                        onPlanWeekend: {
                            router?.go(.life)
                            dismiss()
                        }
                        // MARK: end S4
                    )
                        .frame(maxWidth: AppRootView.maxColumnWidth)
                        .padding(.horizontal, Theme.Spacing.lg)
                        .padding(.bottom, Theme.Spacing.md)
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
            }
            .navigationTitle("City map")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            // MARK: S4 (city)
            .navigationDestination(for: CityMapDestination.self) { destination in
                switch destination {
                case .rival(let id):
                    RivalProfileScreen(engine: engine, rivalID: id)
                }
            }
            // MARK: end S4
        }
        // MARK: S4 (city)
        .sheet(isPresented: $showingVenue) {
            NetworkingVenueSheet(engine: engine)
        }
        .onAppear { applyLaunchFocus() }
        // MARK: end S4
    }

    /// One thing on the map VoiceOver can land on: a district block, or
    /// the player's own office marker sitting in one.
    private struct MapElement: Identifiable {
        var id: String
        var district: DistrictID
        var rect: CityMapComposer.Rect
        var label: String
        var hint: String
        var sortPriority: Double
        // MARK: S4 (city) — a thing that opens rather than only selecting
        var target: CityHitTarget? = nil
        // MARK: end S4
    }

    /// The five district rects plus the office marker as a sixth, built
    /// from exactly the frames the composer draws and hit-tests with.
    private var mapElements: [MapElement] {
        let state = engine.state
        var elements: [MapElement] = []
        for district in DistrictID.allCases {
            guard let style = DistrictStyle(rawValue: district.rawValue) else { continue }
            elements.append(MapElement(
                id: district.rawValue,
                district: district,
                rect: CityMapComposer.districtFrame(style),
                label: districtLabel(district),
                hint: "Shows this district's rent, price and perks",
                sortPriority: district == selectedDistrict ? 1 : 0
            ))
            if district == state.city.district {
                elements.append(MapElement(
                    id: district.rawValue + ".office",
                    district: district,
                    rect: CityMapComposer.officeMarkerFrame(for: style),
                    label: "Your office, " + district.displayName,
                    hint: "Shows this district's terms",
                    sortPriority: 2
                ))
            }
            // MARK: K6 (home and rooms)
            if district == state.life.homeDistrict {
                elements.append(MapElement(
                    id: district.rawValue + ".home",
                    district: district,
                    rect: CityMapComposer.homeMarkerFrame(
                        for: style, besideOffice: district == state.city.district
                    ),
                    label: "Your home, " + district.displayName,
                    hint: "Shows this district's terms",
                    sortPriority: 1.5
                ))
            }
            // MARK: end K6
        }
        // MARK: S4 (city) — every building with a region of its own: the
        // rivals' HQs, the rooms, the founder's places. The flags and pins
        // above are already elements; their buildings join them here.
        var seen: Set<CityHitTarget> = []
        for region in sceneCache.regions(for: reading) {
            guard !seen.contains(region.target) else { continue }
            seen.insert(region.target)
            switch region.target {
            case .office, .home, .district: continue
            default: break
            }
            guard let district = DistrictID(rawValue: region.target.district.rawValue) else { continue }
            elements.append(MapElement(
                id: "s4.\(region.target)",
                district: district,
                rect: region.rect,
                label: thingLabel(region.target),
                hint: thingHint(region.target),
                sortPriority: 0.5,
                target: region.target
            ))
        }
        // MARK: end S4
        return elements
    }

    /// One invisible button per element, laid over the map exactly where
    /// the composer put it. The office's overlay is the pattern; unlike
    /// the office this one uses no `TimelineView` — the city does not
    /// move, and an overlay that rebuilt itself would take VoiceOver's
    /// focus with it.
    ///
    /// Activating one selects the district, which is exactly what a tap
    /// does: the `DistrictDetailPanel` below is already showing the
    /// selection, so the terms, the rivals and the move/buy/sell buttons
    /// are the next elements after the map.
    private func districtElements(scale mapScale: Int) -> some View {
        let scene = CityMapComposer.sceneSize()
        let scale = CGFloat(mapScale)
        return ZStack(alignment: .topLeading) {
            ForEach(mapElements) { element in
                Color.clear
                    .frame(
                        width: CGFloat(element.rect.width) * scale,
                        height: CGFloat(element.rect.height) * scale
                    )
                    .offset(
                        x: CGFloat(element.rect.x) * scale,
                        y: CGFloat(element.rect.y) * scale
                    )
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(element.label)
                    .accessibilityHint(element.hint)
                    .accessibilityAddTraits(.isButton)
                    .accessibilitySortPriority(element.sortPriority)
                    .accessibilityAction {
                        selectedDistrict = element.district
                        // MARK: S4 (city) — a thing opens straight away
                        if let target = element.target {
                            focused = target
                            open(target)
                        }
                        // MARK: end S4
                    }
            }
        }
        .frame(
            width: CGFloat(scene.width) * scale,
            height: CGFloat(scene.height) * scale,
            alignment: .topLeading
        )
        // The scene's own tap gesture stays the finger's route in; these
        // are the assistive-technology route.
        .allowsHitTesting(false)
    }

    /// What a district says when VoiceOver lands on it: the name, whether
    /// it is yours, who else is here, and whether it is the one selected.
    func districtLabel(_ district: DistrictID) -> String {
        let state = engine.state
        var parts = [district.displayName]
        if district == state.city.district {
            parts.append(state.city.ownership.isOwned ? "your office, owned" : "your office, renting")
        }
        // MARK: K6 (home and rooms)
        if district == state.life.homeDistrict { parts.append("your home") }
        // MARK: end K6
        let rivals = state.rivals.rivals.filter { $0.homeDistrict == district }
        switch rivals.count {
        case 0: break
        case 1: parts.append(rivals[0].name + " is based here")
        default: parts.append("\(rivals.count) rival studios based here")
        }
        if district == selectedDistrict { parts.append("selected") }
        return parts.joined(separator: ", ")
    }

    /// The map in one line, for the container the districts sit in.
    private var mapAccessibilityLabel: String {
        "City map: five districts, your office in " + engine.state.city.district.displayName
    }

    /// The composer's per-district state: selection, the player flag, and
    /// rival pins. `DistrictID` and `DistrictStyle` share raw values by
    /// design; the fallback is defensive.
    private var districtInfos: [CityDistrictInfo] {
        let state = engine.state
        return DistrictID.allCases.compactMap { district in
            guard let style = DistrictStyle(rawValue: district.rawValue) else { return nil }
            return CityDistrictInfo(
                style: style,
                selected: district == selectedDistrict,
                hasPlayerOffice: district == state.city.district,
                rivalSeeds: state.rivals.rivals
                    .filter { $0.homeDistrict == district }
                    .map(\.appearanceSeed),
                // MARK: K6 (home and rooms)
                hasPlayerHome: district == state.life.homeDistrict,
                // MARK: end K6
                // MARK: Iteration 18 — the studio mark: a rival's comes
                // free from their name, so every rival on the map has one.
                rivalMarkSeeds: state.rivals.rivals
                    .filter { $0.homeDistrict == district }
                    .map { StudioMark.seed(forRival: $0.name) }
                // MARK: end of Iteration 18
            )
        }
    }

    // MARK: S4 (city)

    /// Everything the map draws this frame, read from the game.
    private var reading: CityMapReading {
        let state = engine.state
        return CityMapReading(
            districts: districtInfos,
            landmarks: state.cityLandmarks(balance: engine.balance),
            tier: OfficeTierStyle(rawValue: state.company.officeTier.rawValue) ?? .garage,
            season: PixelKit.Season(rawValue: state.calendar.season.rawValue) ?? .summer,
            // MARK: Iteration 18 — the studio mark
            markSeed: state.company.markSeed
            // MARK: end of Iteration 18
        )
    }

    /// A tap on the map: select the thing's district; a first tap on a
    /// thing names it, a second opens it.
    private func activate(_ target: CityHitTarget) {
        if let district = DistrictID(rawValue: target.district.rawValue) {
            selectedDistrict = district
        }
        if case .district = target {
            focused = nil
        } else if focused == target {
            open(target)
        } else {
            focused = target
            Haptics.tap()
        }
    }

    /// Opens a thing: over the map when it belongs to the map (a rival's
    /// profile, tonight's room), else at the card or screen that owns it.
    private func open(_ target: CityHitTarget) {
        let state = engine.state
        switch target {
        case .district:
            break
        case .office:
            router?.tab = .hq
            dismiss()
        case .home:
            router?.tab = .life
            dismiss()
        case .rival(let style, let index):
            guard let district = DistrictID(rawValue: style.rawValue) else { return }
            let rivals = state.cityRivals(in: district)
            guard rivals.indices.contains(index) else { return }
            path.append(.rival(rivals[index].id))
        case .venue(let style):
            if state.networking.pendingEvent.map({ $0.venue.rawValue == style.venue.rawValue }) == true {
                showingVenue = true
            }
        case .hospital:
            router?.go(.assets)
            dismiss()
        case .courthouse:
            router?.go(.crimeLedger)
            dismiss()
        case .school:
            router?.go(.children)
            dismiss()
        case .formerOffice:
            break
        }
    }

    /// The name plate over the focused thing, if any.
    private func focusTag(in reading: CityMapReading) -> CityMapTag? {
        guard let focused else { return nil }
        let rects = sceneCache.regions(for: reading).filter { $0.target == focused }.map(\.rect)
        guard let rect = rects.max(by: { $0.width * $0.height < $1.width * $1.height }) else { return nil }
        let words = plateWords(focused)
        return CityMapTag(label: words.name, line: words.line, rect: rect)
    }

    /// The plate's two lines, in the pixel font's capitals (12 and 16
    /// characters at most).
    private func plateWords(_ target: CityHitTarget) -> (name: String, line: String?) {
        let state = engine.state
        switch target {
        case .district(let style): return (style.displayName, nil)
        case .office: return ("Your office", "2nd tap: HQ")
        case .home: return ("Your home", "2nd tap: home")
        case .rival(let style, let index):
            let rivals = DistrictID(rawValue: style.rawValue).map { state.cityRivals(in: $0) } ?? []
            let name = rivals.indices.contains(index) ? rivals[index].name : "Rival"
            return (name, "2nd tap: profile")
        case .venue(let style):
            let open = state.networking.pendingEvent.map { $0.venue.rawValue == style.venue.rawValue } == true
            return (Self.shortVenueName(style.venue), open ? "open - tap again" : "closed tonight")
        case .hospital: return ("Hospital", "2nd tap: doctor")
        case .courthouse: return ("Courthouse", "2nd tap: cases")
        case .school: return ("School", "2nd tap: kids")
        case .formerOffice: return ("Old office", "to let")
        }
    }

    /// A room's name short enough for a plate.
    static func shortVenueName(_ venue: CityVenueStyle) -> String {
        switch venue {
        case .coworkingMixer: "Cowork mixer"
        case .rooftopParty: "Rooftop"
        case .demoDay: "Demo day"
        case .hackerHouse: "Hacker house"
        case .conferenceBar: "Hotel bar"
        }
    }

    /// What VoiceOver says for a thing with a region of its own.
    private func thingLabel(_ target: CityHitTarget) -> String {
        let state = engine.state
        switch target {
        case .district(let style): return style.displayName
        case .office(let style): return "Your office building, " + style.displayName
        case .home(let style): return "Your home, " + style.displayName
        case .rival(let style, let index):
            let rivals = DistrictID(rawValue: style.rawValue).map { state.cityRivals(in: $0) } ?? []
            let name = rivals.indices.contains(index) ? rivals[index].name : "A rival studio"
            return "\(name), rival studio, \(style.displayName)"
        case .venue(let style):
            let venue = NetworkingVenue(rawValue: style.venue.rawValue)
            let open = state.networking.pendingEvent?.venue == venue
            return "\(venue?.displayName ?? "A networking room"), \(style.displayName)\(open ? ", open tonight" : "")"
        case .hospital: return "The hospital, Midtown"
        case .courthouse: return "The courthouse, Old Town"
        case .school: return "The school, Suburbs"
        case .formerOffice(let style): return "Your old office, \(style.displayName), to let"
        }
    }

    private func thingHint(_ target: CityHitTarget) -> String {
        switch target {
        case .rival: "Opens the studio's profile"
        case .venue: "Goes in when the room is open tonight"
        case .hospital: "Opens the doctor, on the Life tab"
        case .courthouse: "Opens your record and your cases, on the Life tab"
        case .school: "Opens the children, on the Life tab"
        case .formerOffice: "Shows this district's terms"
        case .office: "Opens the office, on HQ"
        case .home: "Opens your home, on the Life tab"
        case .district: "Shows this district's rent, price and perks"
        }
    }

    /// `-autoCityFocus <office|home|rival|venue|hospital|courthouse|school|former>`
    /// puts the plate over the first such thing on the map (debug only).
    private func applyLaunchFocus() {
        guard let wanted = DebugLaunch.launchCityFocus else { return }
        let reading = self.reading
        // Tonight's room first, when the pass asks for a room.
        let regions = sceneCache.regions(for: reading).sorted { lhs, _ in
            lhs.target == .venue(reading.landmarks.openVenue ?? .downtown)
        }
        let match = regions.first { region in
            switch (wanted, region.target) {
            case ("office", .office), ("home", .home), ("rival", .rival), ("venue", .venue),
                 ("hospital", .hospital), ("courthouse", .courthouse), ("school", .school),
                 ("former", .formerOffice):
                true
            default:
                false
            }
        }
        if let target = match?.target {
            selectedDistrict = DistrictID(rawValue: target.district.rawValue) ?? selectedDistrict
            focused = target
        }
    }
    // MARK: end S4
}
