import SwiftUI

/// The market as a map: twelve districts on the shared pixel renderer,
/// with a caller-supplied label laid over each district's name strip and a
/// tap target the size of the whole cell.
///
/// PixelKit draws; the app composes. The label is a view the app builds
/// (it knows the fonts, the theme and the accessibility summary), and the
/// map only positions it on the same pixels the scene drew the strip on —
/// `MarketMapLayout.fit(in:)` is the one place that arithmetic lives.
public struct MarketMapView<DistrictLabel: View>: View {
    private let input: MarketMapInput
    private let placements: [PlacedSprite]
    private let onTapDistrict: ((MarketDistrictInfo) -> Void)?
    private let label: (MarketDistrictInfo) -> DistrictLabel

    /// - Parameters:
    ///   - input: the districts, in catalog order.
    ///   - onTapDistrict: called with the district under a tap; nil makes
    ///     the map a picture.
    ///   - label: the view laid over the district's name strip.
    public init(
        input: MarketMapInput,
        onTapDistrict: ((MarketDistrictInfo) -> Void)? = nil,
        @ViewBuilder label: @escaping (MarketDistrictInfo) -> DistrictLabel
    ) {
        self.input = input
        self.placements = MarketMapComposer.compose(input)
        self.onTapDistrict = onTapDistrict
        self.label = label
    }

    public var body: some View {
        PixelSceneView(
            placements: placements,
            sceneSize: MarketMapLayout.sceneSize,
            accessibilityLabel: "Market map"
        )
        .overlay {
            GeometryReader { geometry in
                let fit = MarketMapLayout.fit(in: geometry.size)
                ForEach(Array(input.districts.prefix(MarketMapLayout.slots).enumerated()), id: \.element.id) { index, district in
                    if let cell = MarketMapLayout.cellFrame(index: index),
                       let strip = MarketMapLayout.stripFrame(index: index) {
                        let cellRect = MarketMapLayout.viewRect(cell, scale: fit.scale, origin: fit.origin)
                        let stripRect = MarketMapLayout.viewRect(strip, scale: fit.scale, origin: fit.origin)
                        districtOverlay(district, cell: cellRect, strip: stripRect)
                            .position(x: cellRect.midX, y: cellRect.midY)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func districtOverlay(_ district: MarketDistrictInfo, cell: CGRect, strip: CGRect) -> some View {
        let content = VStack(spacing: 0) {
            label(district)
                .frame(width: strip.width, height: strip.height)
            Spacer(minLength: 0)
        }
        .frame(width: cell.width, height: cell.height)
        .contentShape(Rectangle())

        if let onTapDistrict {
            Button {
                onTapDistrict(district)
            } label: {
                content
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityValue(district.accessibilityValue)
            .accessibilitySortPriority(Self.sortPriority(district))
        } else {
            content
                .accessibilityElement(children: .combine)
                .accessibilityValue(district.accessibilityValue)
                .accessibilitySortPriority(Self.sortPriority(district))
        }
    }

    /// Districts are read biggest market first. The grid's own reading
    /// order is left-to-right, top-to-bottom, which is the catalog's order
    /// and says nothing; size is the thing a sighted player sees first,
    /// because the footprint *is* the demand.
    static func sortPriority(_ district: MarketDistrictInfo) -> Double {
        district.size
    }
}
