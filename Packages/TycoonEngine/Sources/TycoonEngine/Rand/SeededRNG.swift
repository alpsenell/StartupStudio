/// Deterministic random number generator using the SplitMix64 algorithm.
///
/// All simulation randomness flows through an instance of this generator stored
/// inside `GameState`, which makes every run fully reproducible from a seed and
/// lets saves resume the exact random sequence mid-stream.
public struct SeededRNG: RandomNumberGenerator, Codable, Equatable, Sendable {
    private var state: UInt64

    public init(seed: UInt64) {
        self.state = seed
    }

    /// SplitMix64: advance the state by the golden-gamma constant, then mix.
    public mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
