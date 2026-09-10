import Foundation
import Testing
import TycoonContent
import TycoonEngine
import TycoonBots

/// The two WS-B bots, measured. Neither is in a pinned suite — no pacing
/// or investor gate ever calls `acceptBuyoutEarnOut` or `buyBackRound` —
/// so these are the tells the PMs asked for, with the numbers printed and
/// the shape gated loosely enough to move without lying.
///
/// Rivals are live (`rivalCount = 4`), as in `InvestorTargetsTests`: a
/// buyout needs a buyer.
@Suite("Board bots (WS-B)")
struct BoardBotTests {
    static let seeds = BalanceTargetsTests.seeds
    static let threeYears = InvestorTargetsTests.threeYears

    static func balance() throws -> BalanceConfig {
        var balance = try BalanceConfig.loadBundled()
        balance.rivals.rivalCount = 4
        return balance
    }

    static func runAll(_ bot: any BotPolicy, days: Int = threeYears) throws -> [SimRunner.Result] {
        let balance = try balance()
        return seeds.map {
            SimRunner.run(days: days, seed: $0, bot: bot, balance: balance, content: TestContent.bundled)
        }
    }

    // MARK: - The earn-out

    /// `AcquirerBot` on ten seeds over three years: how many were made a
    /// strategic offer and signed, and of those how many collected the
    /// whole price, forfeited a tranche, or were replaced. The PM's
    /// bands: full price on 8+ of the signers is too soft, 60% on 8+ is
    /// too hard; anything between is a decision.
    @Test func theEarnOutIsNeitherFreeMoneyNorACoinFlip() throws {
        let runs = try Self.runAll(AcquirerBot())
        var lines: [String] = []
        var signed = 0, full = 0, partial = 0, ousted = 0, open = 0
        for (seed, result) in zip(Self.seeds, runs) {
            guard let earnOut = result.state.investors.earnOut else {
                lines.append("seed \(seed): no strategic offer taken · ending \(result.endingKind.map { "\($0)" } ?? "running") day \(result.state.day)")
                continue
            }
            signed += 1
            let share = Double(earnOut.paid) / Double(max(1, earnOut.price))
            let outcome: String
            switch result.endingKind {
            case .acquired where earnOut.paid >= earnOut.price:
                full += 1; outcome = "full price"
            case .acquired:
                partial += 1; outcome = "forfeited \(earnOut.outstanding)"
            case .oustedByBoard:
                ousted += 1; outcome = "ousted"
            default:
                open += 1; outcome = "still open (\(earnOut.remainingReviews) reviews left)"
            }
            lines.append(
                "seed \(seed): signed with \(earnOut.buyerName) for \(earnOut.price) watching "
                    + "\(earnOut.expectation.rawValue) · paid \(earnOut.paid) (\(Int((share * 100).rounded()))%) · "
                    + "\(outcome) day \(result.state.day)"
            )
        }
        print("AcquirerBot, 10 seeds × 3 years")
        for line in lines { print("  " + line) }
        print("  signed \(signed)/10 · full \(full) · partial \(partial) · ousted \(ousted) · open \(open)")

        #expect(signed >= 3, "only \(signed)/10 seeds were ever made a strategic offer — the bot measures nothing")
        #expect(full < 8, "the earn-out paid in full on \(full) seeds: free money")
        #expect(ousted < 8, "the acquirer replaced the founder on \(ousted) seeds: a coin flip")
        // An offer signed in the last two quarters is still open at the
        // horizon (with rivals on, the sponsored roll moves when offers
        // land); the measurement needs enough *settled* earn-outs to mean
        // anything.
        #expect(full + partial + ousted >= 3, "only \(full + partial + ousted) earn-outs settled inside three years (\(open) still open)")
    }

    // MARK: - The buyback

    /// One seed of a bot, driven like `SimRunner` but watching each
    /// buyback as it is applied: the pressure the room was at, what it
    /// cost, and the cash it came out of.
    struct Buyback {
        var day: Int
        var pressure: Double
        var price: Int
        var cashBefore: Int
    }

    static func runWatchingBuybacks(
        _ bot: any BotPolicy,
        seed: UInt64,
        days: Int = threeYears
    ) throws -> (state: GameState, buybacks: [Buyback]) {
        let balance = try balance()
        let content = TestContent.bundled
        var state = GameState.newGame(companyName: bot.name, seed: seed, balance: balance)
        var buybacks: [Buyback] = []
        for _ in 0..<days {
            Reducer.tick(&state, balance: balance, content: content)
            if state.gameOver != nil { break }
            for action in bot.actions(for: state, balance: balance, content: content) {
                if case let .buyBackRound(investorID) = action,
                   let round = state.investors.rounds.first(where: { $0.investorID == investorID }) {
                    let price = state.buybackPrice(for: round, balance: balance)
                    let before = state
                    let events = Reducer.apply(action, to: &state, balance: balance, content: content)
                    if !events.isEmpty {
                        buybacks.append(Buyback(
                            day: before.day, pressure: before.investors.boardPressure,
                            price: price, cashBefore: before.company.cash
                        ))
                    }
                } else {
                    Reducer.apply(action, to: &state, balance: balance, content: content)
                }
            }
        }
        return (state, buybacks)
    }

    /// `BuybackBot` against the same founder who never buys back, on the
    /// two founders that matter: the one who plays to the board (does
    /// the buyback cost them the bell?) and the one who coasts into the
    /// vote (does it buy the vote away for pocket change?). The PM's
    /// tell: if it saves more than 70% of the oustings for less than 20%
    /// of the cash on hand, the premium is too low.
    @Test func theBuybackHasARealPrice() throws {
        func report(_ label: String, base: InvestorBot, minPressure: Double = 0) throws -> (buybacks: [Buyback], saved: Int, oustedControl: Int, cheap: Int) {
            let control = try Self.runAll(base)
            var buybacks: [Buyback] = []
            var buyers: [GameState] = []
            for seed in Self.seeds {
                let run = try Self.runWatchingBuybacks(
                    BuybackBot(base: base, minPressure: minPressure), seed: seed
                )
                buybacks.append(contentsOf: run.buybacks)
                buyers.append(run.state)
            }
            let oustedControl = control.count { $0.endingKind == .oustedByBoard }
            let oustedBuyers = buyers.count { $0.gameOver?.kind == .oustedByBoard }
            let bankruptControl = control.count { $0.endingKind == .bankruptcy }
            let bankruptBuyers = buyers.count { $0.gameOver?.kind == .bankruptcy }
            let ipoControl = control.count { $0.endingKind == .ipo }
            let ipoBuyers = buyers.count { $0.gameOver?.kind == .ipo }
            let underPressure = buybacks.count { $0.pressure >= 60 }
            let cheap = buybacks.count { Double($0.price) < Double($0.cashBefore) * 0.2 }
            let seedsWithBuyback = buyers.count { !$0.investors.boughtOut.isEmpty }
            print("BuybackBot(\(label)) vs \(label), 10 seeds × 3 years")
            print("  buybacks \(buybacks.count) on \(seedsWithBuyback) seeds · at pressure ≥ 60: \(underPressure) · under 20% of cash: \(cheap)")
            for buyback in buybacks {
                print("    day \(buyback.day) · pressure \(Int(buyback.pressure.rounded())) · paid \(buyback.price) of \(buyback.cashBefore) cash (\(Int((Double(buyback.price) / Double(max(1, buyback.cashBefore)) * 100).rounded()))%)")
            }
            print("  ousted: control \(oustedControl) / buyers \(oustedBuyers) · bankrupt: control \(bankruptControl) / buyers \(bankruptBuyers) · IPO: control \(ipoControl) / buyers \(ipoBuyers)")
            let controlCash = control.map(\.finalCash).reduce(0, +) / 10
            let buyerCash = buyers.map(\.company.cash).reduce(0, +) / 10
            let controlEquity = control.map(\.state.investors.equityRemaining).reduce(0, +) / 10
            let buyerEquity = buyers.map(\.investors.equityRemaining).reduce(0, +) / 10
            print("  mean final cash: control \(controlCash) / buyers \(buyerCash) · mean equity: control \(Int(controlEquity)) / buyers \(Int(buyerEquity))")
            return (buybacks, max(0, oustedControl - oustedBuyers), oustedControl, cheap)
        }

        let plays = try report("plays", base: InvestorBot())
        let coasts = try report("coasts", base: .coasts)
        // The PM's question: the founder who waits for the warning and
        // then buys the vote away — how often, and for what.
        let warned = try report("coasts, past the warning line", base: .coasts, minPressure: 60)

        let all = plays.buybacks + coasts.buybacks + warned.buybacks
        #expect(!all.isEmpty, "no founder ever bought a board out — the bot measures nothing")
        // Every buyback left the runway the bot promised itself.
        #expect(all.allSatisfy { $0.price <= $0.cashBefore })
        // The PM's tell, on the founder who actually reaches the vote:
        // buying the vote away must not be both common and cheap.
        for measured in [coasts, warned] where measured.oustedControl > 0 {
            let savedShare = Double(measured.saved) / Double(measured.oustedControl)
            let cheapShare = Double(measured.cheap) / Double(max(1, measured.buybacks.count))
            #expect(
                !(savedShare > 0.7 && cheapShare > 0.5),
                "the buyback saved \(measured.saved)/\(measured.oustedControl) oustings with \(measured.cheap)/\(measured.buybacks.count) of them under a fifth of the cash — raise the premium"
            )
        }
    }
}
