import Foundation

/// Decides what everyone in the office is doing at time `t`: desk work,
/// coffee runs, whiteboard huddles, amenity visits, celebrations.
///
/// Scaffold stub: only the hit-testing entry point exists, and it always
/// returns `nil`, so the app can wire "tap an occupant" today and get real
/// answers when WS-C lands the director. WS-C owns this file and the rest
/// of the `Office/` folder.
public enum OfficeDirector {
    /// The occupant whose sprite covers scene-space point (`x`, `y`) at
    /// time `t`, or `nil` when the tap missed everybody (always, for now).
    public static func hitTest(
        input: OfficeSceneInput,
        t: TimeInterval,
        x: Int,
        y: Int
    ) -> UUID? {
        nil
    }
}
