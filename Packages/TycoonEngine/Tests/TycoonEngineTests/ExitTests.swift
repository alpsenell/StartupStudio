import Foundation
import Testing
import TycoonContent
@testable import TycoonEngine

/// The exits: a rival's strategic approach to a company worth having (as
/// opposed to the distress bid that was the only path before), and the
/// endings all four kinds resolve to.
@Suite("Exits")
struct ExitTests {
    private static let content = TestContent.bundled

    private static func balance() throws -> BalanceConfig {
        try BalanceConfig.loadBundled()
    }

    /// Puts one small rival on the board and waits for their approach.
    private static func approach(
        in state: inout GameState,
        balance: BalanceConfig,
        days: Int = 400
    ) -> BuyoutOffer? {
        for _ in 0..<days {
            Reducer.tick(&state, balance: balance, content: Self.content)
            if let offer = state.rivals.pendingBuyout { return offer }
            if state.gameOver != nil { return nil }
        }
        return nil
    }

    /// A thriving company gets a *premium* offer — the reward for building
    /// something worth buying, rather than the fire-sale that used to be
    /// the only exit.
    @Test func aStrongCompanyIsCourtedAtAPremium() throws {
        let balance = try Self.balance()
        var state = GameState.newGame(companyName: "Acme", seed: 31, balance: balance)
        state.company.cash = 3_000_000
        state.company.reputation = 85

        let offer = try #require(
            Self.approach(in: &state, balance: balance),
            "no rival approached a strong company in 400 days"
        )
        #expect(state.rivals.lastBuyoutWasStrategic, "the approach should have been strategic")
        let valuation = state.companyValuation(balance: balance)
        #expect(Double(offer.amount) >= Double(valuation) * balance.investors.strategicPremiumMin * 0.99)
        #expect(Double(offer.amount) <= Double(valuation) * balance.investors.strategicPremiumMax * 1.01)
    }

    /// A struggling company still gets the old lowball, unchanged.
    @Test func aWeakCompanyStillGetsALowball() throws {
        let balance = try Self.balance()
        var state = GameState.newGame(companyName: "Acme", seed: 32, balance: balance)
        // Solvent enough to survive the wait, but nobody has heard of it —
        // weak on reputation, which is the distress path.
        state.company.cash = 60_000
        state.company.reputation = 8

        let offer = try #require(
            Self.approach(in: &state, balance: balance),
            "no rival approached a weak company in 400 days"
        )
        #expect(!state.rivals.lastBuyoutWasStrategic)
        let valuation = state.companyValuation(balance: balance)
        #expect(Double(offer.amount) <= Double(valuation) * balance.rivals.offerFractionMax * 1.01)
    }

    /// Selling ends the run as a success, whichever kind of offer it was.
    @Test func acceptingAnOfferEndsTheRunAsAnExit() throws {
        let balance = try Self.balance()
        var state = GameState.newGame(companyName: "Acme", seed: 33, balance: balance)
        state.company.cash = 3_000_000
        state.company.reputation = 85
        _ = Self.approach(in: &state, balance: balance)
        try #require(state.rivals.pendingBuyout != nil)

        Reducer.apply(.acceptBuyout, to: &state, balance: balance, content: Self.content)
        #expect(state.gameOver?.kind == .acquired)
        #expect(state.gameOver?.kind.isSuccess == true)
    }

    /// Every ending kind grades and names itself, so the biography screen
    /// always has a headline and a tone.
    @Test func everyEndingKindGradesAndNamesItself() {
        #expect(EndingKind.bankruptcy.isSuccess == false)
        #expect(EndingKind.oustedByBoard.isSuccess == false)
        #expect(EndingKind.acquired.isSuccess == true)
        #expect(EndingKind.ipo.isSuccess == true)
        for kind in [EndingKind.bankruptcy, .acquired, .ipo, .oustedByBoard] {
            #expect(!kind.headline.isEmpty)
        }
    }

    /// The new ending kinds survive a save round trip, and a save written
    /// before they existed still reads as a bankruptcy.
    @Test func endingKindsRoundTripAndOldSavesStillDecode() throws {
        for kind in [EndingKind.bankruptcy, .acquired, .ipo, .oustedByBoard] {
            let info = GameOverInfo(day: 5, reason: "r", kind: kind)
            let data = try JSONEncoder().encode(info)
            #expect(try JSONDecoder().decode(GameOverInfo.self, from: data).kind == kind)
        }
        let legacy = Data(#"{"day":1,"reason":"broke"}"#.utf8)
        #expect(try JSONDecoder().decode(GameOverInfo.self, from: legacy).kind == .bankruptcy)
    }
}
