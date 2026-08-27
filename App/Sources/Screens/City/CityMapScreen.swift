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
                        accessibilityLabel: "City map"
                    )
                    .onTapGesture { location in
                        let x = Int(location.x) / Self.mapScale
                        let y = Int(location.y) / Self.mapScale
                        if let style = CityMapComposer.hitTest(x: x, y: y),
                           let district = DistrictID(rawValue: style.rawValue) {
                            selectedDistrict = district
                        }
                    }
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
