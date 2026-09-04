import Foundation

/// How a `Motion` distributes its distance over its duration.
///
/// Every curve maps a normalized progress `0...1` onto `0...1` — except
/// `.easeOutBack`, which deliberately overshoots past 1 before settling.
/// That little rebound is what makes a walker plant a foot instead of
/// gliding to a stop.
public enum Easing: String, Sendable, Equatable, Hashable, Codable, CaseIterable {
    /// Constant speed. The default for walking: pixel people have no inertia.
    case linear
    /// Slow start, full speed at the end — standing up, leaning in.
    case easeIn
    /// Full speed at the start, gentle stop — arriving at a waypoint.
    case easeOut
    /// Slow at both ends. The all-purpose "this was deliberate" curve.
    case easeInOut
    /// Overshoots ~10% then settles. Used for pops (bubbles, confetti burst).
    case easeOutBack
    /// Holds at `from` for the whole duration, then snaps to `to` — a hard
    /// cut that still occupies time (the office-upgrade wipe uses it).
    case step
    /// Overshoots to *twice* the distance, then settles. A hop: over a
    /// one-pixel lift `easeOutBack`'s ten percent rounds away to nothing,
    /// and a press that lifts by a whole pixel then settles by one reads as
    /// the scene answering the finger. The office's press bob uses it.
    case bob

    /// Maps normalized progress onto normalized distance.
    ///
    /// Progress outside `0...1` is clamped first, so callers never have to.
    public func apply(_ progress: Double) -> Double {
        let p = min(1, max(0, progress))
        // Pin the endpoints: floating-point curves can land a hair off 0 or
        // 1, and a sprite that stops half a pixel short of its waypoint
        // reads as a bug.
        if p <= 0 { return 0 }
        if p >= 1 { return 1 }
        switch self {
        case .linear:
            return p
        case .easeIn:
            return p * p
        case .easeOut:
            return 1 - (1 - p) * (1 - p)
        case .easeInOut:
            return p < 0.5 ? 2 * p * p : 1 - 2 * (1 - p) * (1 - p)
        case .easeOutBack:
            let c1 = 1.10158
            let c3 = c1 + 1
            let q = p - 1
            return 1 + c3 * q * q * q + c1 * q * q
        case .step:
            return p >= 1 ? 1 : 0
        case .bob:
            // Straight up to the peak in the first two fifths, then back
            // down to the settle point.
            let peak = 0.4
            return p < peak ? 2 * p / peak : 2 - (p - peak) / (1 - peak)
        }
    }
}
