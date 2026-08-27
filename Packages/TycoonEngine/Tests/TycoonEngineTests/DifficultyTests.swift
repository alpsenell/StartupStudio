import Foundation
import Testing
import TycoonContent
import TycoonEngine

@Suite("Difficulty")
struct DifficultyTests {
    @Test func casesAndLabels() {
        #expect(Difficulty.allCases == [.easy, .normal, .hard])
        #expect(Difficulty.easy.displayName == "Easy")
        #expect(Difficulty.normal.displayName == "Normal")
        #expect(Difficulty.hard.displayName == "Hard")
        for difficulty in Difficulty.allCases {
            #expect(!difficulty.blurb.isEmpty)
            #expect(!difficulty.blurb.contains("\n"))
        }
        #expect(Difficulty(rawValue: "normal") == .normal)
    }

    @Test func bundledBalanceCarriesAllThreeDifficultyBlocks() throws {
        let balance = try BalanceConfig.loadBundled()
        for difficulty in Difficulty.allCases {
            #expect(balance.difficulty[difficulty.rawValue] != nil, Comment(rawValue: difficulty.rawValue))
        }
        #expect(balance.difficulty[Difficulty.normal.rawValue] == .identity)
    }

    @Test func normalIsTheIdentity() throws {
        let bundled = try BalanceConfig.loadBundled()
        #expect(bundled.adjusted(for: .normal) == bundled)
        let custom = TestBalance.standard
        #expect(custom.adjusted(for: .normal) == custom)
    }

    @Test func aBalanceWithoutTheBlockTreatsEveryDifficultyAsNormal() {
        var balance = TestBalance.standard
        balance.difficulty = [:]
        #expect(balance.adjusted(for: .easy) == balance)
        #expect(balance.adjusted(for: .hard) == balance)
    }

    @Test func everyKnobMovesInTheRightDirection() throws {
        let normal = try BalanceConfig.loadBundled()
        let easy = normal.adjusted(for: .easy)
        let hard = normal.adjusted(for: .hard)

        // Starting cash: easy richer, hard poorer.
        #expect(easy.startingCash > normal.startingCash)
        #expect(hard.startingCash < normal.startingCash)
        #expect(easy.startingCash == Int((Double(normal.startingCash) * 1.5).rounded()))
        #expect(hard.startingCash == Int((Double(normal.startingCash) * 0.7).rounded()))

        // Weekly operating cost.
        #expect(easy.weeklyOperatingCost < normal.weeklyOperatingCost)
        #expect(hard.weeklyOperatingCost > normal.weeklyOperatingCost)

        // Office rents and upgrade costs (garage stays free).
        #expect(easy.office(.garage).weeklyRent == 0)
        #expect(easy.office(.garage).upgradeCost == 0)
        for tier in [OfficeTier.loft, .studio, .campus] {
            #expect(easy.office(tier).weeklyRent < normal.office(tier).weeklyRent, Comment(rawValue: tier.rawValue))
            #expect(hard.office(tier).weeklyRent > normal.office(tier).weeklyRent, Comment(rawValue: tier.rawValue))
            #expect(easy.office(tier).upgradeCost < normal.office(tier).upgradeCost, Comment(rawValue: tier.rawValue))
            #expect(hard.office(tier).upgradeCost > normal.office(tier).upgradeCost, Comment(rawValue: tier.rawValue))
            #expect(easy.office(tier).headcountCap == normal.office(tier).headcountCap)
        }

        // Salary formula: both the base and the per-skill slope.
        #expect(easy.salaryBase < normal.salaryBase)
        #expect(hard.salaryBase > normal.salaryBase)
        #expect(easy.salaryPerSkillPoint < normal.salaryPerSkillPoint)
        #expect(hard.salaryPerSkillPoint > normal.salaryPerSkillPoint)

        // Sales market sizes and contract payouts.
        #expect(easy.marketSizeScale > normal.marketSizeScale)
        #expect(hard.marketSizeScale < normal.marketSizeScale)
        #expect(easy.contractPayoutPerPoint > normal.contractPayoutPerPoint)
        #expect(hard.contractPayoutPerPoint < normal.contractPayoutPerPoint)

        // Review expectation base is additive: easy −5, hard +6.
        #expect(easy.reviewExpectationBase == normal.reviewExpectationBase - 5)
        #expect(hard.reviewExpectationBase == normal.reviewExpectationBase + 6)

        // Bankruptcy grace: easy 21 days, hard 10 (normal ships at 14).
        #expect(easy.bankruptcyGraceDays == 21)
        #expect(hard.bankruptcyGraceDays == 10)

        // Candidate skill base is additive: easy +10, hard −5.
        #expect(easy.candidateSkillBase == normal.candidateSkillBase + 10)
        #expect(hard.candidateSkillBase == normal.candidateSkillBase - 5)

        // Life: hospital bill and home rents (upgrade costs untouched).
        #expect(easy.life.hospitalBill < normal.life.hospitalBill)
        #expect(hard.life.hospitalBill > normal.life.hospitalBill)
        for tier in HomeTier.allCases {
            #expect(easy.home(tier).weeklyRent < normal.home(tier).weeklyRent, Comment(rawValue: tier.rawValue))
            #expect(hard.home(tier).weeklyRent > normal.home(tier).weeklyRent, Comment(rawValue: tier.rawValue))
            #expect(easy.home(tier).upgradeCost == normal.home(tier).upgradeCost, Comment(rawValue: tier.rawValue))
        }

        // Everything the difficulty does not touch stays put.
        #expect(easy.market == normal.market)
        #expect(easy.staff == normal.staff)
        #expect(easy.company == normal.company)
        #expect(easy.difficulty == normal.difficulty)
        #expect(easy.salesBaseFactor == normal.salesBaseFactor)
        #expect(easy.contractPtsMax == normal.contractPtsMax)
    }

    @Test func adjustingIsPureAndIdempotentPerCall() throws {
        let normal = try BalanceConfig.loadBundled()
        let once = normal.adjusted(for: .hard)
        let again = normal.adjusted(for: .hard)
        #expect(once == again)
        // Adjusting never mutates the receiver.
        #expect(normal == (try BalanceConfig.loadBundled()))
    }

    // MARK: - State & engine wiring

    @Test func newGameDefaultsToNormalAndRecordsTheChoice() {
        let balance = TestBalance.standard
        let defaulted = GameState.newGame(companyName: "Acme", seed: 1, balance: balance)
        #expect(defaulted.difficulty == .normal)
        let hard = GameState.newGame(companyName: "Acme", seed: 1, balance: balance, difficulty: .hard)
        #expect(hard.difficulty == .hard)
    }

    @Test func difficultyRoundTripsAndOldSavesDecodeAsNormal() throws {
        let state = GameState.newGame(
            companyName: "Acme", seed: 3, balance: TestBalance.standard, difficulty: .easy
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(state)
        let decoded = try JSONDecoder().decode(GameState.self, from: data)
        #expect(decoded.difficulty == .easy)
        #expect(decoded == state)
        #expect(try encoder.encode(decoded) == data)

        var object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(object["difficulty"] as? String == "easy")
        object["difficulty"] = nil
        let legacy = try JSONSerialization.data(withJSONObject: object)
        let fromLegacy = try JSONDecoder().decode(GameState.self, from: legacy)
        #expect(fromLegacy.difficulty == .normal)
    }

    @Test @MainActor func engineAppliesTheAdjustedBalanceOnNewGameAndResume() throws {
        let bundled = try BalanceConfig.loadBundled()

        let normal = GameEngine.newGame(companyName: "Acme", seed: 9)
        #expect(normal.state.difficulty == .normal)
        #expect(normal.balance == bundled)
        #expect(normal.state.company.cash == bundled.startingCash)

        let hard = GameEngine.newGame(companyName: "Acme", seed: 9, difficulty: .hard)
        #expect(hard.state.difficulty == .hard)
        #expect(hard.balance == bundled.adjusted(for: .hard))
        #expect(hard.state.company.cash == bundled.adjusted(for: .hard).startingCash)
        #expect(hard.weeklyBurn == bundled.adjusted(for: .hard).weeklyOperatingCost)

        let resumed = GameEngine.resume(state: hard.state)
        #expect(resumed.balance == bundled.adjusted(for: .hard))
        #expect(resumed.state.difficulty == .hard)

        let easy = GameEngine.newGame(companyName: "Acme", seed: 9, difficulty: .easy)
        #expect(easy.state.company.cash > normal.state.company.cash)
    }

    /// Difficulty only rescales constants; it must never change how many
    /// words the simulation draws, so the same seed walks the same RNG
    /// path on every difficulty.
    @Test func difficultyLeavesTheRNGDrawOrderUntouched() throws {
        let bundled = try BalanceConfig.loadBundled()
        let content = TestContent.bundled
        var streams: [SeededRNG] = []
        for difficulty in Difficulty.allCases {
            let balance = bundled.adjusted(for: difficulty)
            var state = GameState.newGame(
                companyName: "Acme", seed: 77, balance: balance, difficulty: difficulty
            )
            for _ in 0..<100 {
                Reducer.tick(&state, balance: balance, content: content)
            }
            #expect(state.gameOver == nil, Comment(rawValue: difficulty.rawValue))
            streams.append(state.rng)
        }
        #expect(streams[0] == streams[1])
        #expect(streams[1] == streams[2])
    }
}
