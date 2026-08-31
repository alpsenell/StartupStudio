import Foundation

/// The small, permanent differences between one person's movement and the
/// next's: stride length, where they are in a breath, when they blink.
///
/// A room where everybody breathes on the same beat is a metronome, not an
/// office — and the office's only desynchronizer used to be `seatIndex % 2`,
/// which gives a campus of forty people exactly two gaits. This gives each
/// of them their own, seeded from their id, so it is stable for the life of
/// the character, identical on every machine, and free of any dependence on
/// wall-clock time or `Hasher`'s per-process seed.
///
/// Deliberately *not* seeded by the office day: a stride is a property of a
/// person, not of a Tuesday.
public struct ActorRhythm: Sendable, Equatable, Hashable {
    /// How long this person's stride is against the authored norm. A longer
    /// stride is a slower cadence over the same ground.
    public var strideScale: Double
    /// Offset into every two-frame idle cycle, in ticks.
    public var idlePhase: Int
    /// Nudge to the idle period, so two people stood together do not
    /// breathe in and out as one.
    public var breathBias: Int
    /// Which step of the typing chart is a blink.
    var blinkSlot: Int
    /// Which step of the typing chart is a beat of thought — hands held
    /// still over the keys.
    var thoughtSlot: Int

    /// How many steps a typing chart runs for before repeating. Sixteen at
    /// eight steps a second is a two-second loop: long enough that the
    /// blink is a punctuation mark rather than a tic.
    static let typingChartLength = 16

    public init(id: UUID) {
        var rng = OfficeRandom(id: id, day: 0, salt: 0x9A17)
        // ±12%: enough that two walkers drift apart within a couple of
        // strides, small enough that nobody looks like they are in a
        // different gravity.
        strideScale = 0.88 + rng.unit() * 0.24
        idlePhase = rng.int(0...5)
        breathBias = rng.int(-1...1)
        // The held beat starts on an even step, so it covers one even and
        // one odd slot. The blink takes an odd slot from outside it — put
        // on top of the beat it would swallow the pause whole, and roughly
        // one person in seven would never take their hands off the keys.
        let thought = rng.int(0...(Self.typingChartLength - 3)) & ~1
        let blinkable = Array(stride(from: 1, to: Self.typingChartLength, by: 2))
            .filter { $0 != thought + 1 }
        thoughtSlot = thought
        blinkSlot = blinkable[rng.int(0...(blinkable.count - 1))]
    }

    /// A person's typing loop: hands alternating over the keys, with one
    /// blink and one held beat placed where this particular person puts
    /// them.
    ///
    /// Frame 0 is hands up, 1 is hands down on the keys, 2 is the blink —
    /// the three frames `SpriteLibrary.PersonPose.seated` authors.
    public var typingChart: [Int] {
        var chart = (0..<Self.typingChartLength).map { $0 % 2 }
        // Two steps of stillness first: a hand off the keys, then back to
        // it. The blink goes on afterwards so it always survives, even when
        // this person's held beat lands on top of it.
        chart[thoughtSlot] = 0
        chart[thoughtSlot + 1] = 0
        chart[blinkSlot] = 2
        return chart
    }

    /// A toggle period for an idle two-frame cycle, in legacy ticks, biased
    /// by this person and clamped so it stays a breath rather than a twitch.
    public func idlePeriod(base: Int) -> Int {
        max(2, base + breathBias)
    }
}
