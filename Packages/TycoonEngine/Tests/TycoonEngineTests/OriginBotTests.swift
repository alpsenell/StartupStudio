import Foundation
import Testing
import TycoonContent
import TycoonEngine
import TycoonBots

/// The PM's neutrality tell for origins (meta #3): `SoloSlowBot` on each
/// origin over the ten pacing seeds. An origin that wins on *both*
/// `firstShipDay` and `finalCash` on nine seeds or more is a free lunch,
/// and its cost is too small.
///
/// The bot plays every origin the same way — one product at a time, never
/// hires, never works a contract — so this measures what the day-0 state
/// is worth on its own, not what a player who leans into it could do.
@Suite("Origin bot table")
struct OriginBotTests {
    static let seeds = BalanceTargetsTests.seeds

    struct Row {
        let origin: FoundingOrigin
        let results: [SimRunner.Result]
    }

    static func table() throws -> [Row] {
        try FoundingOrigin.allCases.map { origin in
            Row(origin: origin, results: try seeds.map { seed in
                SimRunner.run(
                    days: BalanceTargetsTests.days,
                    seed: seed,
                    bot: SoloSlowBot(),
                    balance: try BalanceTargetsTests.balance(),
                    content: TestContent.bundled,
                    origin: origin
                )
            })
        }
    }

    /// Wins on a seed: earliest first ship *and* most cash at the horizon,
    /// alone at the top of both.
    static func wins(_ rows: [Row]) -> [FoundingOrigin: Int] {
        var wins: [FoundingOrigin: Int] = [:]
        for (index, _) in seeds.enumerated() {
            let ships = rows.map { $0.results[index].firstShipDay ?? Int.max }
            let cash = rows.map { $0.results[index].finalCash }
            let bestShip = ships.min() ?? Int.max
            let bestCash = cash.max() ?? Int.min
            for (row, origin) in rows.enumerated() {
                let aloneOnShip = ships[row] == bestShip && ships.filter { $0 == bestShip }.count == 1
                let aloneOnCash = cash[row] == bestCash && cash.filter { $0 == bestCash }.count == 1
                if aloneOnShip && aloneOnCash {
                    wins[origin.origin, default: 0] += 1
                }
            }
        }
        return wins
    }

    @Test func noOriginWinsOnBothFirstShipAndFinalCash() throws {
        let rows = try Self.table()
        let wins = Self.wins(rows)

        let balance = try BalanceTargetsTests.balance()
        print("origin table — SoloSlowBot, \(Self.seeds.count) seeds, \(BalanceTargetsTests.days) days")
        for row in rows {
            let ships = row.results.map { $0.firstShipDay.map(String.init) ?? "never" }
            let cash = row.results.map { String($0.finalCash) }
            let meanShip = BalanceTargetsTests.mean(row.results) { Double($0.firstShipDay ?? BalanceTargetsTests.days) }
            let meanCash = BalanceTargetsTests.mean(row.results) { Double($0.finalCash) }
            // What the last screen says: the founder's slice of the
            // company plus their wallet. The one number the co-founder's
            // 30% shows up in.
            let meanNetWorth = BalanceTargetsTests.mean(row.results) {
                Double($0.state.founderNetWorth(balance: balance))
            }
            let bust = row.results.count(where: \.wentBankrupt)
            print("  \(row.origin.rawValue.padding(toLength: 10, withPad: " ", startingAt: 0))"
                + " firstShip \(ships.joined(separator: " "))"
                + " | mean \(Int(meanShip.rounded()))")
            print("  \(String(repeating: " ", count: 10))"
                + " finalCash \(cash.joined(separator: " "))"
                + " | mean \(Int(meanCash.rounded())) | bankrupt \(bust)"
                + " | wins both \(wins[row.origin] ?? 0)"
                + " | mean net worth \(Int(meanNetWorth.rounded()))")
        }

        for origin in FoundingOrigin.allCases {
            let count = wins[origin] ?? 0
            #expect(
                count < 9,
                "\(origin.displayName) wins on both first ship and final cash on \(count)/\(Self.seeds.count) seeds — its cost is too small"
            )
        }

        // The garage row is the pacing suite's own solo row: every seed
        // ships inside the first-product gate, exactly as the 19 gates say.
        let garage = try #require(rows.first { $0.origin == .garage })
        for result in garage.results {
            let day = try #require(result.firstShipDay)
            #expect((45...110).contains(day))
            #expect(!result.wentBankrupt)
        }
    }

    /// Every origin costs something the bot can see. Not a balance gate —
    /// the sentence each origin was written to be able to say.
    @Test func eachOriginHasItsCost() throws {
        let rows = try Self.table()
        func row(_ origin: FoundingOrigin) throws -> Row { try #require(rows.first { $0.origin == origin }) }
        let garage = try row(.garage)

        // Co-founded: the second pair of hands ships sooner…
        let cofounded = try row(.cofounded)
        let soonerShips = zip(cofounded.results, garage.results).count { ($0.firstShipDay ?? .max) < ($1.firstShipDay ?? .max) }
        #expect(soonerShips >= 7, "a co-founder should ship the first product sooner on most seeds (\(soonerShips)/10)")
        // …and the founder owns 70% of whatever it becomes.
        for result in cofounded.results {
            #expect(result.state.investors.equityRemaining == 70)
        }

        // Spin-out: the bot never works the contract, so the deadline
        // lands as a penalty on every seed — the client was real.
        let spinOut = try row(.spinOut)
        for result in spinOut.results {
            #expect(result.contractsFailed >= 1)
            #expect(result.state.activeContracts.isEmpty)
        }

        // Mortgaged: the loan is still on the books after two years of a
        // bot that never repays, and it cost interest every week.
        let mortgaged = try row(.mortgaged)
        for result in mortgaged.results {
            #expect(result.state.loanBalance >= 25_000)
            let interest = result.state.ledger.entries.filter {
                $0.label.localizedCaseInsensitiveContains("interest")
            }
            #expect(!interest.isEmpty)
        }
    }
}
