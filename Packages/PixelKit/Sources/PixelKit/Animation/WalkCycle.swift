import Foundation

/// How fast a walk cycle has to play so the feet stay on the ground.
///
/// A pixel walk reads as *walking* only when the ground moves under the
/// character at the rate the legs claim it does. The art says how far one
/// full cycle carries a body — `sideCycleLength` for the profile walk,
/// `towardCycleLength` for the one facing the camera — and this works out
/// the frame rate that makes that true for a leg travelling at any speed.
///
/// It matters here more than in most games because `Motion.walk` rounds
/// every leg's duration **up to a whole second** (that rounding is what
/// keeps the director's per-second memoization exact). A 13 px sidestep and
/// a 24 px stride therefore both take one second, at 13 px/s and 24 px/s —
/// nearly a factor of two apart. One fixed step rate cannot serve both, and
/// the difference is exactly the "sprites sliding around" look: feet
/// planting on a floor that is moving at the wrong speed.
public enum WalkCycle {
    /// The profile walk, in the order `HomePersonArt.walkRightFrames`
    /// authors them: contact (leading hand forward), passing (body lifted),
    /// contact (hand trailing), passing again with a head bob.
    ///
    /// All four, in order. The director used to play `[0, 1]` — half the
    /// authored cycle, which put the same hand forward on every stride and
    /// is what made the walk read as a shuffle rather than a gait.
    public static let sideFrames = [0, 1, 2, 3]

    /// Ground covered by one full four-frame profile cycle, in scene pixels.
    ///
    /// The contact pose plants its feet nine pixels apart (columns 2 and 11
    /// of `HomePersonArt.strideLegs`), so one step is nine pixels and a
    /// cycle — contact, pass, contact, pass — is two of them.
    public static let sideCycleLength: Double = 18

    /// Walking toward the camera: two frames, one step each.
    public static let towardFrames = [0, 1]

    /// A step toward the camera foreshortens, so the same leg art reads as
    /// a shorter pace than it does in profile.
    public static let towardCycleLength: Double = 12

    /// Slowest the legs may tick over. Below this a shuffle stops reading
    /// as motion at all and starts reading as a stuck sprite.
    static let minimumFPS: Double = 2
    /// Fastest, so a short leg forced into a whole second — or a crunch
    /// multiplier on top of it — never turns into a blur.
    static let maximumFPS: Double = 14

    /// The frame rate that lands `frames` frames on `cycleLength` pixels of
    /// ground at `speed` pixels per second.
    public static func fps(speed: Double, frames: Int, cycleLength: Double) -> Double {
        guard speed > 0, cycleLength > 0, frames > 0 else { return minimumFPS }
        let exact = Double(frames) * speed / cycleLength
        return min(maximumFPS, max(minimumFPS, exact))
    }

    /// The speed a motion actually travels at, which is not the speed it
    /// was asked for: `Motion.walk` rounds the duration up to a whole
    /// second, so the true speed is always this, and never `walkSpeed`.
    public static func groundSpeed(of motion: Motion) -> Double {
        guard motion.duration > 0 else { return 0 }
        return motion.from.distance(to: motion.to) / motion.duration
    }

    /// The cadence for one leg of a journey.
    ///
    /// - Parameters:
    ///   - motion: the leg being walked.
    ///   - facing: profile legs get the four-frame cycle, legs toward or
    ///     away from the camera the two-frame one.
    ///   - strideScale: the walker's own stride, a hair longer or shorter
    ///     than the norm (see `ActorRhythm`). A longer stride means fewer
    ///     steps for the same ground, so the cadence drops.
    ///   - tempoScale: what the room is doing to everybody's pace.
    public static func cadence(
        for motion: Motion,
        facing: Facing,
        strideScale: Double = 1,
        tempoScale: Double = 1
    ) -> (frames: [Int], fps: Double) {
        let profile = facing != .forward
        let frames = profile ? sideFrames : towardFrames
        let length = (profile ? sideCycleLength : towardCycleLength) * max(0.5, strideScale)
        let rate = fps(speed: groundSpeed(of: motion), frames: frames.count, cycleLength: length)
        return (frames, min(maximumFPS, max(minimumFPS, rate * max(0.25, tempoScale))))
    }
}
