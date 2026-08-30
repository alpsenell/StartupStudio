import Foundation

/// The scene's sense of time.
///
/// Every animated scene is a *pure function of `(input, t)`* where `t` is
/// seconds since the view appeared. `AnimationClock` is the one place that
/// says how fast that time is sampled and how it maps onto the legacy
/// 4-ticks-per-second modulo clock the first-iteration composers used.
///
/// Nothing here reads the wall clock or the simulation: the view supplies
/// `t`, tests supply `t`, and the same `t` always produces the same frame.
public enum AnimationClock {
    /// Frames drawn per second. 12 fps is the classic hand-animation rate:
    /// fast enough that a walk cycle reads, slow enough that a campus of
    /// forty people costs almost nothing.
    public static let fps: Double = 12

    /// The interval `TimelineView` is asked to fire at.
    public static let frameInterval: TimeInterval = 1 / fps

    /// Ticks per second of the original modulo clock, kept so `.typing`,
    /// `.glow` and `.toggle` animate at exactly the rate they always did.
    public static let legacyTicksPerSecond: Double = 4

    /// The legacy tick index for a scene time.
    ///
    /// `frameIndex(atTick:)` remains the definition for the four original
    /// animation modes; `frameIndex(at:)` funnels through here so a scene
    /// driven by seconds and a scene driven by ticks stay in lockstep.
    public static func tick(at t: TimeInterval) -> Int {
        Int((max(0, t) * legacyTicksPerSecond).rounded(.down)) & 0x3FFF_FFFF
    }

    /// The 12 fps frame index for a scene time.
    public static func frame(at t: TimeInterval) -> Int {
        Int((max(0, t) * fps).rounded(.down))
    }

    /// The scene time a frame index lands on — the inverse of `frame(at:)`,
    /// handy when a test wants to step frame by frame.
    public static func time(ofFrame frame: Int) -> TimeInterval {
        TimeInterval(max(0, frame)) / fps
    }

    /// The whole-second bucket a scene time falls in.
    ///
    /// The office director quantizes every plan boundary to a whole second,
    /// so the placement *list* only changes when this changes — which is
    /// what makes memoizing the director's output per second exact rather
    /// than approximate. Motion and frame indices keep moving inside the
    /// second because they are evaluated from `t`, not from the bucket.
    public static func secondBucket(at t: TimeInterval) -> Int {
        Int(max(0, t).rounded(.down))
    }
}
