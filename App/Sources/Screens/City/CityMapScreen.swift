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
                            accessibilityLabel: "City map"
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
