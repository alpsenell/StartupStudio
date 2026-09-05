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

    /// Pixel scale of the map content (fixed, so taps map exactly).
    private static let mapScale = 3

    init(engine: GameEngine, initialDistrict: DistrictID? = nil) {
        self.engine = engine
        _selectedDistrict = State(initialValue: initialDistrict ?? engine.state.city.district)
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ScrollView([.horizontal, .vertical]) {
                    PixelSceneView(
                        placements: CityMapComposer.compose(districts: districtInfos),
                        sceneSize: CityMapComposer.sceneSize(),
                        scale: .fixed(Self.mapScale),
                        accessibilityLabel: mapAccessibilityLabel
                    )
                    .onTapGesture { location in
                        let x = Int(location.x) / Self.mapScale
                        let y = Int(location.y) / Self.mapScale
                        if let style = CityMapComposer.hitTest(x: x, y: y),
                           let district = DistrictID(rawValue: style.rawValue) {
                            selectedDistrict = district
                        }
                    }
                    // The canvas is one picture; the districts laid over it
                    // are the things in it.
                    .accessibilityHidden(true)
                    .overlay { districtElements }
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel(mapAccessibilityLabel)
                    .padding(.bottom, 280) // keep every district reachable above the panel
                }
                .defaultScrollAnchor(.center)
                .background(Theme.screenBackground)

                DistrictDetailPanel(engine: engine, district: selectedDistrict)
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.bottom, Theme.Spacing.md)
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
    private var districtElements: some View {
        let scene = CityMapComposer.sceneSize()
        let scale = CGFloat(Self.mapScale)
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
                    .map(\.appearanceSeed)
            )
        }
    }
}
