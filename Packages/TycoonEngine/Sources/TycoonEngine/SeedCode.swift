import Foundation

// MARK: Iteration 7 — seed codes (R4)

/// A run's seed, origin and difficulty as a string a player can read off
/// a share card and type into another phone: `SS1-XXXXXXXX-XXXXXXXX-X`.
///
/// The body is ten bytes — a version nibble and the origin and difficulty
/// in the first byte, the 64-bit seed big-endian in the next eight, and a
/// check byte over those nine — in Crockford base32, which is exactly
/// sixteen characters, grouped in eights. The trailing character is a
/// second, position-weighted check over the sixteen so a transposition is
/// caught too. The alphabet is upper-case letters and digits with `I`,
/// `L`, `O` and `U` left out, all of which the bitmap font can draw.
///
/// `encoded` and `decode` are pure functions of the value: no draws, no
/// state, so the same code founds the same company on any phone.
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

    /// The Crockford base32 alphabet: 32 symbols, no `I`, `L`, `O`, `U`.
    public static let alphabet: [Character] = Array("0123456789ABCDEFGHJKMNPQRSTVWXYZ")

    /// The prefix every code starts with: `SS` and the version digit.
    public static let prefix = "SS\(version)"

    /// The printable form: `SS1-XXXXXXXX-XXXXXXXX-X`.
    public var encoded: String {
        let body = Self.base32(Self.bytes(for: self))
        let head = String(body.prefix(8))
        let tail = String(body.suffix(8))
        return "\(Self.prefix)-\(head)-\(tail)-\(Self.checkCharacter(for: body))"
    }

    /// Parses a code; `nil` on a bad check, an unknown version, or any
    /// character outside the alphabet. Hyphens, spaces and case are
    /// forgiven so a code read aloud still decodes; nothing else is.
    public static func decode(_ text: String) -> SeedCode? {
        let cleaned = text.uppercased().filter { $0 != "-" && $0 != " " && $0 != "\n" }
        guard cleaned.count == prefix.count + 17, cleaned.hasPrefix(prefix) else { return nil }
        let rest = Array(cleaned.dropFirst(prefix.count))
        let body = rest[0..<16]
        let check = rest[16]
        var values: [UInt8] = []
        values.reserveCapacity(16)
        for character in body {
            guard let value = alphabet.firstIndex(of: character) else { return nil }
            values.append(UInt8(value))
        }
        guard checkCharacter(forValues: values) == check else { return nil }
        let bytes = fromBase32(values)
        guard bytes.count == 10 else { return nil }
        let payload = Array(bytes[0..<9])
        guard checkByte(over: payload) == bytes[9] else { return nil }
        let header = payload[0]
        guard Int(header >> 4) == version else { return nil }
        let originIndex = Int((header >> 2) & 0b11)
        let difficultyIndex = Int(header & 0b11)
        guard FoundingOrigin.allCases.indices.contains(originIndex),
              Difficulty.allCases.indices.contains(difficultyIndex)
        else { return nil }
        var seed: UInt64 = 0
        for byte in payload[1..<9] {
            seed = (seed << 8) | UInt64(byte)
        }
        return SeedCode(
            seed: seed,
            origin: FoundingOrigin.allCases[originIndex],
            difficulty: Difficulty.allCases[difficultyIndex]
        )
    }

    /// Whether `text` could be the start of a code: only characters the
    /// alphabet has (plus the separators), in any case. For a field that
    /// validates as the player types.
    public static func isDrawable(_ text: String) -> Bool {
        text.uppercased().allSatisfy { character in
            character == "-" || character == " " || character == "S" || alphabet.contains(character)
        }
    }

    // MARK: - Bytes

    /// Nine payload bytes and the check byte over them.
    private static func bytes(for code: SeedCode) -> [UInt8] {
        let originIndex = FoundingOrigin.allCases.firstIndex(of: code.origin) ?? 0
        let difficultyIndex = Difficulty.allCases.firstIndex(of: code.difficulty) ?? 0
        var payload: [UInt8] = [UInt8(version << 4) | UInt8(originIndex << 2) | UInt8(difficultyIndex)]
        for shift in stride(from: 56, through: 0, by: -8) {
            payload.append(UInt8(truncatingIfNeeded: code.seed >> UInt64(shift)))
        }
        return payload + [checkByte(over: payload)]
    }

    /// FNV-1a over the payload, folded to a byte. Any single-byte
    /// corruption of the payload changes it.
    private static func checkByte(over payload: [UInt8]) -> UInt8 {
        var hash: UInt32 = 0x811C_9DC5
        for byte in payload {
            hash ^= UInt32(byte)
            hash = hash &* 0x0100_0193
        }
        return UInt8(truncatingIfNeeded: hash ^ (hash >> 8) ^ (hash >> 16) ^ (hash >> 24))
    }

    /// The trailing character: a position-weighted sum of the sixteen
    /// body values, mod 32, so swapping two characters is caught.
    private static func checkCharacter(for body: String) -> Character {
        checkCharacter(forValues: body.map { UInt8(alphabet.firstIndex(of: $0) ?? 0) })
    }

    private static func checkCharacter(forValues values: [UInt8]) -> Character {
        var sum = 0
        for (index, value) in values.enumerated() {
            sum += (index + 1) * Int(value)
        }
        return alphabet[sum % 32]
    }

    // MARK: - Base32

    /// Ten bytes → sixteen characters, most significant bit first.
    private static func base32(_ bytes: [UInt8]) -> String {
        var bits = 0
        var buffer = 0
        var output = ""
        for byte in bytes {
            buffer = (buffer << 8) | Int(byte)
            bits += 8
            while bits >= 5 {
                bits -= 5
                output.append(alphabet[(buffer >> bits) & 0x1F])
            }
            buffer &= (1 << bits) - 1
        }
        if bits > 0 {
            output.append(alphabet[(buffer << (5 - bits)) & 0x1F])
        }
        return output
    }

    /// Sixteen 5-bit values → ten bytes.
    private static func fromBase32(_ values: [UInt8]) -> [UInt8] {
        var bits = 0
        var buffer = 0
        var output: [UInt8] = []
        for value in values {
            buffer = (buffer << 5) | Int(value)
            bits += 5
            while bits >= 8 {
                bits -= 8
                output.append(UInt8((buffer >> bits) & 0xFF))
            }
            buffer &= (1 << bits) - 1
        }
        return output
    }
}
