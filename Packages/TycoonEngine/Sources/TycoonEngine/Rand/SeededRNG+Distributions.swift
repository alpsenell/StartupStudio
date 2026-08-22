import Foundation

extension SeededRNG {
    /// Uniform double in [0, 1), built from the top 53 bits of one RNG word.
    mutating func nextUniform() -> Double {
        Double(next() >> 11) * 0x1.0p-53
    }

    /// Uniform integer in the closed range, consuming exactly one RNG word.
    mutating func nextInt(in range: ClosedRange<Int>) -> Int {
        let span = UInt64(range.upperBound - range.lowerBound + 1)
        return range.lowerBound + Int(next() % span)
    }

    /// Zero-mean gaussian sample via Box-Muller. Always consumes exactly two
    /// RNG words (even when `sigma` is 0) so the stream stays predictable.
    mutating func nextGaussian(sigma: Double) -> Double {
        // u1 in (0, 1] so log(u1) is finite; u2 in [0, 1).
        let u1 = (Double(next() >> 11) + 1) * 0x1.0p-53
        let u2 = Double(next() >> 11) * 0x1.0p-53
        return sigma * sqrt(-2 * log(u1)) * cos(2 * .pi * u2)
    }
}
