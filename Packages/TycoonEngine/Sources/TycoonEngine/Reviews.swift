/// Short review one-liners, picked by score band (variety comes from the
/// seeded RNG so runs stay reproducible).
///
/// Moved out of `ProductSystem.swift` unchanged in the scaffold: WS-B owns
/// this file and replaces these hard-coded bands with the content-backed
/// `Reviews.json` voices, keeping `pick(for:rng:)`'s single RNG draw.
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

    /// Picks a blurb from the band matching `score` using the state RNG.
    static func pick(for score: Int, rng: inout SeededRNG) -> String {
        let band: [String] = switch score {
        case ..<20: dire
        case ..<40: poor
        case ..<60: mixed
        case ..<80: good
        default: stellar
        }
        return band[Int(rng.next() % UInt64(band.count))]
    }
}
