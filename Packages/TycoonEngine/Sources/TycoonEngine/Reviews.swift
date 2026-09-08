import TycoonContent

/// Everything a review needs to know about the launch it is reviewing.
///
/// Built at ship time from the product and its development record, so the
/// blurb can name the app, the type and the topic, and the callout can
/// mention the thing that actually stood out — crashes, polish, an
/// over-promise, an unnoticed launch, a crowded shelf, or (iteration 10)
/// the feature on the board the launch was really about.
struct ReviewContext: Equatable, Sendable {
    var productName: String
    var typeName: String
    var topicName: String
    /// Open bugs at ship as a fraction of the code pool (0 = spotless).
    var bugRatio: Double
    /// Polish points delivered as a fraction of the polish pool.
    var polishRatio: Double
    /// Hype carried into launch, 0...100+.
    var hype: Double
    /// The launch's market scale — below 1 means a saturated shelf.
    var marketScale: Double
    /// M1: the best card on the feature board, by name. Empty when the
    /// board is empty, which is when no feature callout can fire.
    var bestFeature: String = ""
    /// M1: the card on the board that should not have been there. Empty
    /// unless something on it actually costs the product.
    var worstFeature: String = ""

    static let unknown = ReviewContext(
        productName: "the app", typeName: "app", topicName: "software",
        bugRatio: 0, polishRatio: 1, hype: 0, marketScale: 1
    )
}

/// Review one-liners, written per outlet and picked by score band.
///
/// The catalog (`Reviews.json`) gives every outlet its own voice and eight
/// blurbs per band; the fallback bands below are what a build without the
/// content file gets, and are also what the unit-test catalogs use.
///
/// The RNG budget is exactly one word per review, unchanged from the
/// pre-content version: the same word picks the blurb and, when the ship
/// context earns one, the callout variant. Which callout applies is a pure
/// function of the context, so it costs nothing.
enum ReviewBlurbs {
    private static let dire = [
        "We want our afternoon back.",
        "Crashes faster than it launches.",
        "A bold experiment in user punishment.",
        "The loading spinner is the best feature.",
        "Uninstalled before the tutorial ended.",
    ]
    private static let poor = [
        "Rough edges as far as the eye can see.",
        "Needed six more months in the oven.",
        "Promising idea, painful execution.",
        "Works, in the way a squeaky door works.",
        "We kept waiting for it to get good.",
    ]
    private static let mixed = [
        "Fine. Perfectly, stubbornly fine.",
        "Half brilliant, half baffling.",
        "Does the job, rarely with grace.",
        "You could do worse. You could do better.",
        "A solid maybe from our review desk.",
    ]
    private static let good = [
        "Polished where it counts.",
        "Quietly excellent in daily use.",
        "A confident, capable release.",
        "Easy to recommend, hard to put down.",
        "Small studio, big craftsmanship.",
    ]
    private static let stellar = [
        "An instant classic of the genre.",
        "Set the bar; everyone else, take notes.",
        "We forgot we were reviewing it.",
        "Flawless victory for a tiny team.",
        "The rare app that feels inevitable.",
    ]

    /// The band raw value a score falls into. Matches the keys of an
    /// outlet's `bands` object in `Reviews.json`.
    static func band(for score: Int) -> String {
        switch score {
        case ..<20: "dire"
        case ..<40: "poor"
        case ..<60: "mixed"
        case ..<80: "good"
        default: "stellar"
        }
    }

    private static func fallbackBand(for score: Int) -> [String] {
        switch score {
        case ..<20: dire
        case ..<40: poor
        case ..<60: mixed
        case ..<80: good
        default: stellar
        }
    }

    /// Picks a blurb for one outlet's review. One RNG word, always.
    ///
    /// `outlet`, `context` and `catalog` are defaulted so the pre-content
    /// call site keeps compiling and keeps behaving identically.
    static func pick(
        for score: Int,
        rng: inout SeededRNG,
        outlet: String = "",
        context: ReviewContext = .unknown,
        catalog: ReviewCatalog? = nil
    ) -> String {
        let word = rng.next()
        let bandID = band(for: score)
        let lines = catalog?.blurbs(outlet: outlet, band: bandID) ?? fallbackBand(for: score)
        var blurb = fill(lines[Int(word % UInt64(lines.count))], context: context)

        if let catalog,
           let calloutID = callout(for: score, context: context),
           let variants = catalog.callout(calloutID) {
            let line = fill(variants[Int((word >> 32) % UInt64(variants.count))], context: context)
            blurb += " " + line
        }
        return blurb
    }

    /// Which callout the launch earned, if any. Pure — no draws. At most
    /// one applies, in priority order: the loudest true thing wins.
    static func callout(for score: Int, context: ReviewContext) -> String? {
        if context.bugRatio >= 0.20 { return "buggy" }
        if context.hype >= 45, score < 55 { return "overpromised" }
        if context.marketScale <= 0.65 { return "crowded" }
        // M1's two, placed *after* every callout that existed before them
        // so a launch with no board still earns exactly the callout it
        // earned before boards existed. Both are `nil` on an empty board.
        if !context.worstFeature.isEmpty, score < 60 { return "featureMisfit" }
        if !context.bestFeature.isEmpty, score >= 55 { return "featureLed" }
        if context.polishRatio >= 0.95, score >= 55 { return "polished" }
        if context.hype <= 8, score >= 60 { return "unnoticed" }
        return nil
    }

    private static func fill(_ text: String, context: ReviewContext) -> String {
        guard text.contains("{") else { return text }
        return text
            .replacingOccurrences(of: "{name}", with: context.productName)
            .replacingOccurrences(of: "{type}", with: context.typeName.lowercased())
            .replacingOccurrences(of: "{topic}", with: context.topicName.lowercased())
            // M1: `{feature}` is the board's best card, `{misfit}` the one
            // that should not have been on it. Both are empty strings on
            // an empty board, and no line that uses them is reachable
            // then — see `callout(for:context:)`.
            .replacingOccurrences(of: "{feature}", with: context.bestFeature)
            .replacingOccurrences(of: "{misfit}", with: context.worstFeature)
    }
}
