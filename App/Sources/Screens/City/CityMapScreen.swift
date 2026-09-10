import PixelKit
import SwiftUI
import TycoonEngine

/// The scrollable pixel city: five districts, the player's office flag,
/// rival HQ pins. Tap a district to select it; the bottom panel shows its
/// terms (rent, buy, perks) and the move/buy/sell actions. Presented full
/// screen from the HQ office card.
struct CityMapScreen: View {
    let engine: GameEngine

    @Environment(\.dismiss) private var dismiss
    @State private var selectedDistrict: DistrictID

    /// The phone's pixel scale, and the floor everywhere: 224 × 3 = 672
    /// points, panned inside the ScrollView on every iPhone.
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
    static func mapScale(forWidth width: CGFloat) -> Int {
        let sceneWidth = CityMapComposer.sceneSize().width
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

    init(engine: GameEngine, initialDistrict: DistrictID? = nil) {
        self.engine = engine
        _selectedDistrict = State(initialValue: initialDistrict ?? engine.state.city.district)
    }

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                let scale = Self.mapScale(forWidth: proxy.size.width)
                ZStack(alignment: .bottom) {
                    ScrollView([.horizontal, .vertical]) {
                        PixelSceneView(
                            placements: CityMapComposer.compose(districts: districtInfos),
                            sceneSize: CityMapComposer.sceneSize(),
                            scale: .fixed(scale),
                            accessibilityLabel: mapAccessibilityLabel
                        )
                        .onTapGesture { location in
                            let x = Int(location.x) / scale
                            let y = Int(location.y) / scale
                            if let style = CityMapComposer.hitTest(x: x, y: y),
                               let district = DistrictID(rawValue: style.rawValue) {
                                selectedDistrict = district
                            }
                        }
                        // Keep every district reachable above the panel.
                        .padding(.bottom, Self.panelClearance(scale: scale))
                    }
                    // The canvas is one picture; the districts laid over it
                    // are the things in it.
                    .accessibilityHidden(true)
                    .overlay { districtElements(scale: scale) }
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel(mapAccessibilityLabel)
                    .defaultScrollAnchor(.center)
                    .background(Theme.screenBackground)

                    DistrictDetailPanel(engine: engine, district: selectedDistrict)
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
        }
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
                    .accessibilityAction { selectedDistrict = element.district }
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
                hasPlayerHome: district == state.life.homeDistrict
                // MARK: end K6
            )
        }
    }
}
