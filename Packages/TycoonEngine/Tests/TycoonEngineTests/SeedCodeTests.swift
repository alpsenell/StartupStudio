import Foundation
import Testing
import TycoonContent
@testable import TycoonEngine

/// The seed code (R4): a pure, printable form of a run's seed, origin and
/// difficulty that survives the trip through a share card and a thumb.
@Suite("Seed codes")
struct SeedCodeTests {
    private static let balance: BalanceConfig = {
        guard let bundled = try? BalanceConfig.loadBundled() else {
            fatalError("TycoonEngine is missing its bundled Balance.json resource")
        }
        return bundled
    }()

    @Test("The printed shape is SS1-XXXXXXXX-XXXXXXXX-X in the font's alphabet")
    func shape() {
        let code = SeedCode(seed: 0xDEAD_BEEF_0000_0001, origin: .spinOut, difficulty: .hard)
        let text = code.encoded
        #expect(text.count == 23)
        #expect(text.hasPrefix("SS1-"))
        let groups = text.split(separator: "-").map(String.init)
        #expect(groups.map(\.count) == [3, 8, 8, 1])
        for character in groups.dropFirst().joined() {
            #expect(SeedCode.alphabet.contains(character), "\(character) is outside the alphabet")
        }
        // Never the four letters a thumb confuses.
        #expect(!text.contains("I") && !text.contains("L") && !text.contains("O") && !text.contains("U"))
    }

    @Test("A thousand random seeds, every origin and difficulty, round-trip")
    func roundTripsAThousandSeeds() {
        var rng = SeededRNG(seed: 0x5EED_C0DE)
        for index in 0..<1000 {
            let origin = FoundingOrigin.allCases[index % FoundingOrigin.allCases.count]
            let difficulty = Difficulty.allCases[(index / 4) % Difficulty.allCases.count]
            let code = SeedCode(seed: rng.next(), origin: origin, difficulty: difficulty)
            #expect(SeedCode.decode(code.encoded) == code, "seed \(code.seed) did not round-trip")
        }
        for extreme: UInt64 in [0, 1, .max, .max - 1, 0x8000_0000_0000_0000] {
            let code = SeedCode(seed: extreme, origin: .garage, difficulty: .easy)
            #expect(SeedCode.decode(code.encoded) == code)
        }
    }

    @Test("Encoding is a pure function of the value")
    func encodingIsStable() {
        let code = SeedCode(seed: 4242, origin: .garage, difficulty: .normal)
        #expect(code.encoded == code.encoded)
        #expect(code.encoded == SeedCode(seed: 4242, origin: .garage, difficulty: .normal).encoded)
        #expect(code.encoded != SeedCode(seed: 4243, origin: .garage, difficulty: .normal).encoded)
        #expect(code.encoded != SeedCode(seed: 4242, origin: .mortgaged, difficulty: .normal).encoded)
        #expect(code.encoded != SeedCode(seed: 4242, origin: .garage, difficulty: .hard).encoded)
    }

    @Test("One flipped character is rejected, at every position")
    func rejectsAFlippedCharacter() {
        var rng = SeededRNG(seed: 99)
        for _ in 0..<50 {
            let code = SeedCode(seed: rng.next(), origin: .cofounded, difficulty: .normal)
            var characters = Array(code.encoded)
            for position in characters.indices where characters[position] != "-" && position >= 3 {
                let original = characters[position]
                let replacement = SeedCode.alphabet[(SeedCode.alphabet.firstIndex(of: original)! + 7) % 32]
                characters[position] = replacement
                #expect(
                    SeedCode.decode(String(characters)) == nil,
                    "flipping position \(position) of \(code.encoded) was accepted"
                )
                characters[position] = original
            }
        }
    }

    @Test("Two swapped characters are rejected")
    func rejectsATransposition() {
        var rng = SeededRNG(seed: 7)
        var caught = 0
        var attempted = 0
        for _ in 0..<200 {
            let code = SeedCode(seed: rng.next(), origin: .garage, difficulty: .easy)
            var characters = Array(code.encoded)
            // Two adjacent body characters that differ.
            let a = 4, b = 5
            guard characters[a] != characters[b] else { continue }
            attempted += 1
            characters.swapAt(a, b)
            if SeedCode.decode(String(characters)) == nil { caught += 1 }
        }
        #expect(caught == attempted)
    }

    @Test("Characters outside the alphabet, a wrong version and a wrong length are rejected")
    func rejectsWhatItCannotRead() {
        let code = SeedCode(seed: 1, origin: .garage, difficulty: .normal).encoded
        #expect(SeedCode.decode(code.replacingOccurrences(of: "SS1", with: "SS2")) == nil)
        #expect(SeedCode.decode(code.replacingOccurrences(of: "SS1", with: "XX1")) == nil)
        #expect(SeedCode.decode(String(code.dropLast())) == nil)
        #expect(SeedCode.decode(code + "0") == nil)
        #expect(SeedCode.decode("") == nil)
        #expect(SeedCode.decode("hello") == nil)
        var withU = Array(code)
        withU[5] = "U"
        #expect(SeedCode.decode(String(withU)) == nil)
        var withSymbol = Array(code)
        withSymbol[6] = "!"
        #expect(SeedCode.decode(String(withSymbol)) == nil)
    }

    @Test("Case and separators are forgiven")
    func forgivesCaseAndSeparators() {
        let code = SeedCode(seed: 0xABCD, origin: .mortgaged, difficulty: .hard)
        #expect(SeedCode.decode(code.encoded.lowercased()) == code)
        #expect(SeedCode.decode(code.encoded.replacingOccurrences(of: "-", with: "")) == code)
        #expect(SeedCode.decode(code.encoded.replacingOccurrences(of: "-", with: " ")) == code)
        #expect(SeedCode.decode(" " + code.encoded + "\n") == code)
    }

    @Test("A decoded code founds the same first month as the run it came from")
    func decodedCodeFoundsTheSameCompany() {
        let content = TestContent.bundled
        let code = SeedCode(seed: 0x1234_5678_9ABC, origin: .cofounded, difficulty: .hard)
        let decoded = SeedCode.decode(code.encoded)!
        let balance = Self.balance.adjusted(for: code.difficulty)
        var a = GameState.newGame(
            companyName: "Twice", seed: code.seed, balance: balance,
            difficulty: code.difficulty, origin: code.origin, content: content
        )
        var b = GameState.newGame(
            companyName: "Twice", seed: decoded.seed, balance: balance,
            difficulty: decoded.difficulty, origin: decoded.origin, content: content
        )
        #expect(a == b)
        for _ in 0..<28 {
            _ = Reducer.tick(&a, balance: balance, content: content)
            _ = Reducer.tick(&b, balance: balance, content: content)
        }
        #expect(a == b)
    }
}

/// The custom company's rules (R4) on the engine: rivals off means an
/// empty field for a whole year, and standard rules change nothing.
@Suite("Custom company rules")
struct CustomRulesTests {
    private static let balance: BalanceConfig = {
        guard let bundled = try? BalanceConfig.loadBundled() else {
            fatalError("TycoonEngine is missing its bundled Balance.json resource")
        }
        return bundled
    }()

    @Test("Standard rules are the identity on the balance")
    func standardIsIdentity() {
        #expect(Self.balance.applying(.standard) == Self.balance)
        #expect(Self.balance.adjusted(for: .hard).applying(.standard) == Self.balance.adjusted(for: .hard))
    }

    @Test("Rivals off: the field is empty at day 365")
    func rivalsOffIsAnEmptyField() {
        let content = TestContent.bundled
        let rules = GameRules(rivalsEnabled: false)
        let balance = Self.balance.adjusted(for: .normal).applying(rules)
        var state = GameState.newGame(
            companyName: "Alone", seed: 31, balance: balance,
            difficulty: .normal, content: content, rules: rules, mode: .custom
        )
        for _ in 0..<365 where state.gameOver == nil {
            _ = Reducer.tick(&state, balance: balance, content: content)
        }
        #expect(state.rivals.rivals.isEmpty)
        #expect(state.rivals.incumbent == nil)
        #expect(state.mode == .custom)
        #expect(state.isRanked == false)
    }

    @Test("Incumbent off leaves the rivals but never founds the giant")
    func incumbentOffKeepsTheRivals() {
        let content = TestContent.bundled
        let rules = GameRules(incumbentEnabled: false)
        let balance = Self.balance.adjusted(for: .normal).applying(rules)
        var state = GameState.newGame(
            companyName: "Small", seed: 32, balance: balance,
            difficulty: .normal, content: content, rules: rules, mode: .custom
        )
        for _ in 0..<60 where state.gameOver == nil {
            _ = Reducer.tick(&state, balance: balance, content: content)
        }
        #expect(!state.rivals.rivals.isEmpty)
        #expect(balance.rivals.depth.incumbentEnabled == false)
    }

    @Test("Starting cash lands on day 0")
    func startingCashLands() {
        let rules = GameRules(startingCash: 250_000)
        let balance = Self.balance.adjusted(for: .hard).applying(rules)
        let state = GameState.newGame(
            companyName: "Rich", seed: 33, balance: balance, difficulty: .hard, rules: rules, mode: .custom
        )
        #expect(state.company.cash == 250_000)
    }
}
