import PixelKit
import SwiftUI
import TycoonContent
import TycoonEngine

/// Which face of the Market section is showing: the pulse and the report,
/// or the map. Owned by `BusinessScreen` so the `.marketMap` deep link can
/// pick it; `MarketView` draws the segment.
enum MarketLens: String, CaseIterable, Identifiable {
    case report = "Report"
    case map = "Map"

    var id: String { rawValue }
}

/// The market as a map (iteration 6, U3): the twelve topics as districts,
/// each sized by demand and coloured by the studio's standing, with the
/// studio's live products as buildings, a flag per rival selling there,
/// the incumbent's fortress, the siege over a category fight, and the
/// forecast as weather — only over the categories the studio holds, since
/// the read is what standing buys.
///
/// PixelKit draws the map; this screen builds its input from state, lays
/// the district names and the accessibility summaries over it, and hands
/// a tapped district to the caller, which opens the topic detail that
/// already exists.
struct MarketMapScreen: View {
    let engine: GameEngine
    /// Where a tapped district goes.
    var onSelectTopic: (String) -> Void

    private var snapshot: MarketMapSnapshot {
        MarketMapSnapshot(state: engine.state, content: engine.content, balance: engine.balance)
    }

    var body: some View {
        let snapshot = self.snapshot
        VStack(spacing: Theme.Spacing.lg) {
            PixelPanel(contentPadding: Theme.Spacing.sm) {
                MarketMapView(input: snapshot.input, onTapDistrict: { district in
                    Haptics.tap()
                    onSelectTopic(district.id)
                }) { district in
                    MarketDistrictLabel(
                        name: district.name,
                        summary: snapshot.summaries[district.id] ?? district.name
                    )
                }
            }

            MarketMapLegendCard(heldCount: snapshot.heldCount, threshold: snapshot.threshold)

            Text("Tap a district for its report. Bigger districts are hotter markets; greener ones are more yours.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Theme.Spacing.xs)
        }
    }
}

// MARK: - The district label

/// The topic's name on its strip. A display label on a pixel plate, so it
/// is clamped rather than scaled with Dynamic Type — the spoken summary
/// carries everything the label cannot.
private struct MarketDistrictLabel: View {
    let name: String
    let summary: String

    var body: some View {
        Text(name)
            .font(.system(.caption2, design: .rounded).weight(.bold))
            .foregroundStyle(Theme.onTint)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .padding(.horizontal, 2)
            .dynamicTypeSize(...DynamicTypeSize.large)
            .accessibilityLabel(summary)
            .accessibilityHint("Opens the market report for \(name)")
    }
}

// MARK: - The legend

/// What the marks mean, drawn with the map's own sprites so the legend and
/// the map cannot disagree.
private struct MarketMapLegendCard: View {
    let heldCount: Int
    let threshold: Double

    private let columns = [
        GridItem(.flexible(), alignment: .leading),
        GridItem(.flexible(), alignment: .leading),
    ]

    var body: some View {
        CardView("Legend", systemImage: "map.fill") {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                HStack(spacing: Theme.Spacing.sm) {
                    ForEach(StandingBand.allCases, id: \.self) { band in
                        VStack(spacing: 3) {
                            SpriteSwatch(sprite: MarketSpriteLibrary.districtBlock(side: 9, band: band), scale: 2)
                            Text(MarketMapSnapshot.tierName(band))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(
                    "District colour is your standing: grey no presence, sand newcomer, light green known, green established, teal household name"
                )

                LazyVGrid(columns: columns, alignment: .leading, spacing: Theme.Spacing.sm) {
                    legendRow(MarketSpriteLibrary.playerBuilding(), "One of your products")
                    legendRow(MarketSpriteLibrary.rivalFlag(), "A rival sells here")
                    legendRow(MarketSpriteLibrary.fortress(), "The incumbent")
                    legendRow(MarketSpriteLibrary.siegeMarker(), "Under challenge")
                    legendRow(MarketSpriteLibrary.weather(.sunny), "Forecast: warming")
                    legendRow(MarketSpriteLibrary.weather(.overcast), "Forecast: steady")
                    legendRow(MarketSpriteLibrary.weather(.rain), "Forecast: cooling")
                    legendRow(MarketSpriteLibrary.weather(.storm), "A boom or crash is likely")
                }

                Text(heldCount == 0
                    ? "Weather appears over a category once your standing there reaches \(Int(threshold.rounded())) — the forecast is what standing buys."
                    : "Weather shows over the \(heldCount) \(heldCount == 1 ? "category" : "categories") you hold; nowhere else can you see where demand is heading.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func legendRow(_ sprite: PixelSprite, _ text: String) -> some View {
        HStack(spacing: Theme.Spacing.sm) {
            SpriteSwatch(sprite: sprite, scale: 3)
                .frame(width: 30, height: 27, alignment: .center)
            Text(text)
                .font(.caption)
                .foregroundStyle(.primary)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text)
    }
}

/// A sprite's first frame at an integer scale, crisp.
private struct SpriteSwatch: View {
    let sprite: PixelSprite
    let scale: CGFloat

    var body: some View {
        Image(decorative: sprite.cgImage(frame: 0), scale: 1)
            .interpolation(.none)
            .resizable()
            .frame(width: CGFloat(sprite.width) * scale, height: CGFloat(sprite.height) * scale)
            .accessibilityHidden(true)
    }
}

// MARK: - The model

/// The map's input, built from state once per render, with the spoken
/// summary for every district beside it. Pure: nothing here draws from
/// the RNG or mutates state.
struct MarketMapSnapshot {
    let input: MarketMapInput
    /// VoiceOver's line for each district, keyed by topic id.
    let summaries: [String: String]
    /// How many categories the studio holds — the districts with weather.
    let heldCount: Int
    /// The standing that buys the forecast.
    let threshold: Double

    /// A boom or crash more likely than not inside the forecast window
    /// reads as a storm. At the shipped balance the window's jump chance
    /// is a constant well under this, so the storm is a sprite for a
    /// tuned-volatile market rather than a weekly sight.
    static let stormJumpChance = 0.5

    init(state: GameState, content: ContentCatalog, balance: BalanceConfig) {
        let market = balance.market
        var districts: [MarketDistrictInfo] = []
        var summaries: [String: String] = [:]
        var held = 0
        for topic in content.topics.prefix(MarketMapLayout.slots) {
            let category = CategorySnapshot(topic: topic, state: state, balance: balance)
            let competitors = state.rivals.competitors(in: topic.id, on: state.day)
            let incumbent = state.rivals.incumbent
            let fortress = incumbent.map { giant in
                giant.focusTopicIDs.contains(topic.id) || competitors.contains { $0.rival.id == giant.id }
            } ?? false
            let rivals = competitors.filter { $0.rival.id != incumbent?.id }.count
            let weather = Self.weather(forecast: category.forecast, driftSigma: market.driftSigma)
            if weather != nil { held += 1 }
            let district = MarketDistrictInfo(
                id: topic.id,
                name: topic.name,
                size: Self.size(multiplier: category.market.multiplier, market: market),
                standing: Self.band(standing: category.standing, balance: balance),
                playerProducts: category.liveProducts.count,
                rivalCount: rivals,
                hasFortress: fortress,
                underSiege: state.rivals.challenge(in: topic.id) != nil,
                weather: weather
            )
            districts.append(district)
            summaries[topic.id] = Self.summary(district, category: category, incumbentName: incumbent?.name)
        }
        input = MarketMapInput(districts: districts)
        self.summaries = summaries
        heldCount = held
        threshold = market.standing.forecastThreshold
    }

    /// Demand as a 0…1 footprint across the market's clamp.
    static func size(multiplier: Double, market: BalanceConfig.MarketBalance) -> Double {
        let span = market.multiplierMax - market.multiplierMin
        guard span > 0 else { return 0.5 }
        return min(1, max(0, (multiplier - market.multiplierMin) / span))
    }

    /// The same rungs `CategorySnapshot.tier` names, as a band.
    static func band(standing: Double, balance: BalanceConfig) -> StandingBand {
        let threshold = balance.market.standing.forecastThreshold
        let max = balance.market.standing.maxStanding
        if standing <= 0 { return .none }
        if standing < threshold / 2 { return .newcomer }
        if standing < threshold { return .known }
        if standing < (threshold + max) / 2 { return .established }
        return .household
    }

    /// The tier name the category rows use for a band.
    static func tierName(_ band: StandingBand) -> String {
        switch band {
        case .none: "No presence"
        case .newcomer: "Newcomer"
        case .known: "Known"
        case .established: "Established"
        case .household: "Household"
        }
    }

    /// The forecast's lean as weather; nil where there is no forecast.
    static func weather(forecast: MarketForecast?, driftSigma: Double) -> MarketWeather? {
        guard let forecast else { return nil }
        if forecast.jumpChance >= stormJumpChance { return .storm }
        return switch forecast.lean(threshold: driftSigma / 2) {
        case .warming: .sunny
        case .cooling: .rain
        case .steady: .overcast
        }
    }

    private static func summary(
        _ district: MarketDistrictInfo, category: CategorySnapshot, incumbentName: String?
    ) -> String {
        var parts = [
            "\(district.name), \(tierName(district.standing).lowercased()), demand \(category.market.multiplierLabel)",
        ]
        switch district.playerProducts {
        case 0: break
        case 1: parts.append("one of your products")
        default: parts.append("\(district.playerProducts) of your products")
        }
        switch district.rivalCount {
        case 0: break
        case 1: parts.append("one rival selling here")
        default: parts.append("\(district.rivalCount) rivals selling here")
        }
        if district.hasFortress {
            parts.append("\(incumbentName ?? "the incumbent") is here")
        }
        if district.underSiege {
            parts.append("under challenge")
        }
        if let weather = district.weather {
            parts.append("forecast \(weatherName(weather))")
        }
        return parts.joined(separator: ", ")
    }

    private static func weatherName(_ weather: MarketWeather) -> String {
        switch weather {
        case .sunny: "warming"
        case .overcast: "steady"
        case .rain: "cooling"
        case .storm: "a boom or crash likely"
        }
    }
}
