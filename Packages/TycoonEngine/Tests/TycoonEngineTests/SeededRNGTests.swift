import Foundation
import Testing
import TycoonEngine

@Suite("SeededRNG")
struct SeededRNGTests {
    @Test func sameSeedProducesIdenticalTenValueSequence() {
        var a = SeededRNG(seed: 42)
        var b = SeededRNG(seed: 42)
        let seqA = (0..<10).map { _ in a.next() }
        let seqB = (0..<10).map { _ in b.next() }
        #expect(seqA == seqB)
    }

    @Test func differentSeedsProduceDifferentSequences() {
        var a = SeededRNG(seed: 1)
        var b = SeededRNG(seed: 2)
        let seqA = (0..<10).map { _ in a.next() }
        let seqB = (0..<10).map { _ in b.next() }
        #expect(seqA != seqB)
    }

    @Test func implementsCanonicalSplitMix64() {
        // Reference vector for SplitMix64 with seed 1234567.
        var rng = SeededRNG(seed: 1_234_567)
        let expected: [UInt64] = [
            6_457_827_717_110_365_317,
            3_203_168_211_198_807_973,
            9_817_491_932_198_370_423,
            4_593_380_528_125_082_431,
            16_408_922_859_458_223_821,
        ]
        let produced = (0..<5).map { _ in rng.next() }
        #expect(produced == expected)
    }

    @Test func codableRoundTripResumesExactSequenceMidStream() throws {
        var original = SeededRNG(seed: 987_654_321)
        for _ in 0..<5 { _ = original.next() }

        let data = try JSONEncoder().encode(original)
        var decoded = try JSONDecoder().decode(SeededRNG.self, from: data)
        #expect(decoded == original)

        let fromOriginal = (0..<10).map { _ in original.next() }
        let fromDecoded = (0..<10).map { _ in decoded.next() }
        #expect(fromOriginal == fromDecoded)
    }
}
