import Foundation

// MARK: Iteration 7 — seed codes (R4)

/// A run's seed, origin and difficulty as a string a player can read off
/// a share card and type into another phone: `SS1-XXXXXXXX-XXXXXXXX-X`.
///
/// Version nibble, 64-bit seed, origin (2 bits), difficulty (2 bits) and
/// a check byte, in Crockford base32 — the alphabet is upper-case letters
/// and digits, which the bitmap font can draw. R4 implements `encode` and
/// `decode`; the scaffold fixes the shape so the app can carry one around.
public struct SeedCode: Equatable, Hashable, Sendable {
    public var seed: UInt64
    public var origin: FoundingOrigin
    public var difficulty: Difficulty

    public init(seed: UInt64, origin: FoundingOrigin, difficulty: Difficulty) {
        self.seed = seed
        self.origin = origin
        self.difficulty = difficulty
    }

    public static let version = 1

    /// The printable form. R4.
    public var encoded: String {
        // R4: version nibble + seed + origin + difficulty + check byte,
        // Crockford base32, grouped in eights.
        ""
    }

    /// Parses a code; `nil` on a bad check, an unknown version, or any
    /// character outside the alphabet. R4.
    public static func decode(_ text: String) -> SeedCode? {
        // R4.
        _ = text
        return nil
    }
}
