import Foundation
import TycoonContent

/// Weekly investor system and quarterly board room.
///
/// Once the company is worth something, term sheets start arriving: cash
/// for equity, and — for the bigger cheques — a seat at the table. A board
/// watches one number. Miss it for a few quarters and the pressure climbs;
/// at 100 they thank the founder for their service and bring in a grown-up.
/// Hit it and the pressure falls away.
///
/// All randomness draws from `state.investorRNG` — not `state.rng`, and not
/// the shared `worldRNG` either. Whether a term sheet is on the table on a
/// given day is a function of `Investors.json`'s valuation floors, so
/// retuning those floors changes how many draws this system has taken by
/// day N; on a shared stream that silently reshuffles rivals, the city, the
/// social round and every life event for every seed, and a pass that priced
/// the board would come back with the founder's health gates broken for no
/// reason it could name. Investor draw order per tick: expired-offer sweep
/// (no draws) → offer check (one uniform, and on a hit one more for the
/// persona pick and one for the cheque jitter) → quarterly review (no draws).
enum InvestorSystem {
    @Sendable
    static func run(
        _ state: inout GameState,
        _ balance: BalanceConfig,
        _ content: ContentCatalog
    ) -> [GameEvent] {
        var events: [GameEvent] = []
        // A term sheet left on the desk when the run ended still lapses;
        // it costs no draw and clears the board room on the way out.
        events.append(contentsOf: expireOffer(&state))
        // Iteration 7 (R5): a company running past its own ending has no
        // board room. Nobody writes it a term sheet and nobody grades its
        // quarter — the offer check's draw is skipped with it, which only
        // ever moves `investorRNG` inside an epilogue run (no other run
        // has one), so every pinned suite is byte-identical.
        guard state.epilogue == nil else { return events }
        events.append(contentsOf: offerCheck(&state, balance, content))
        events.append(contentsOf: quarterlyReview(&state, balance))
        return events
    }

    // MARK: - Offers

    /// An unanswered term sheet is withdrawn the day after its deadline.
    private static func expireOffer(_ state: inout GameState) -> [GameEvent] {
        guard let offer = state.investors.pendingOffer, state.day > offer.respondByDay else {
            return []
        }
        state.investors.pendingOffer = nil
        return [.investmentWithdrawn(investorID: offer.investorID, day: state.day)]
    }

    /// On check days, an investor whose valuation floor the company has
    /// cleared — and who has not approached before — may put a term sheet
    /// on the table.
    ///
    /// Draws one uniform for the approach, and on a hit one more to pick
    /// among the eligible personas and one to jitter the cheque, so the
    /// stream advances by a fixed, documented amount.
    private static func offerCheck(
        _ state: inout GameState,
        _ balance: BalanceConfig,
        _ content: ContentCatalog
    ) -> [GameEvent] {
        let config = balance.investors
        let rolodex = state.progression.hasPerk(.investorRolodex)
        let earliest = max(
            0,
            config.earliestOfferDay
                - (rolodex ? balance.progression.investorRolodexWeeksEarlier * GameState.daysPerWeek : 0)
        )

        guard !content.investors.isEmpty,
              state.day >= earliest,
              state.day.isMultiple(of: max(1, config.offerIntervalDays)),
              state.investors.pendingOffer == nil,
              state.investors.ipoDay == nil,
              // Nobody writes a term sheet for a company that is being
              // bought. (The guard sits before the draw, so it only ever
              // changes the stream when an earn-out is actually running.)
              state.investors.earnOut == nil,
              state.company.reputation >= config.minReputation,
              state.investors.lastOfferDay.map({ state.day - $0 >= config.offerCooldownDays }) ?? true
        else { return [] }

        let valuation = state.companyValuation(balance: balance)
        // Deterministic eligibility: cheap to compute, no draws.
        let eligible = content.investors.filter { persona in
            !state.investors.approachedInvestorIDs.contains(persona.id)
                && valuation >= persona.valuationFloor
                && state.company.reputation >= persona.minReputation
                && state.investors.equityRemaining - persona.equityAsk >= 20
        }
        guard !eligible.isEmpty else { return [] }

        guard state.investorRNG.nextUniform() < config.offerChance else { return [] }

        let index = state.investorRNG.nextInt(in: 0...(eligible.count - 1))
        let persona = eligible[index]
        // The cheque scales with what the company is worth, jittered a
        // little so two runs at the same valuation don't read identically.
        let jitter = 0.9 + state.investorRNG.nextUniform() * 0.3
        // An investor buys `equityAsk`% of what the company is worth *to
        // an investor* — `companyValuation` is what an acquirer would pay
        // today, and a round is bought forward, hence the premium. The
        // persona's `checkSize` is the ceiling on what they will write,
        // not a floor under it.
        //
        // It used to be the floor, which meant a seed fund put $250,000
        // into a company worth $250,000 for twelve per cent — an implied
        // valuation of $2.08M against a real one of a quarter of that.
        // The company then hired to the cap on money that had nothing to
        // do with its own size, and the board arrived expecting growth
        // from a burn rate the round had just quintupled. Taking money
        // was not a trade-off, it was a trap.
        let priced = Double(valuation) * config.roundValuationPremium
        let impliedByEquity = priced * persona.equityAsk / 100
        let amount = max(1, Int((min(impliedByEquity, Double(persona.checkSize)) * jitter).rounded()))
        let offerValuation = Int((Double(amount) * 100 / max(1, persona.equityAsk)).rounded())

        let offer = InvestmentOffer(
            investorID: persona.id,
            investorName: persona.name,
            amount: amount,
            equity: persona.equityAsk,
            valuation: offerValuation,
            takesBoardSeat: persona.boardSeat,
            expects: persona.expectation,
            patienceWeeks: persona.patienceWeeks,
            respondByDay: state.day + config.responseDays
        )
        state.investors.pendingOffer = offer
        state.investors.lastOfferDay = state.day
        state.investors.approachedInvestorIDs.insert(persona.id)
        return [.investmentOffered(
            investorID: persona.id,
            amount: amount,
            equity: persona.equityAsk,
            respondByDay: offer.respondByDay,
            day: state.day
        )]
    }

    // MARK: - Board

    /// Every `reviewIntervalDays` the board takes the company's temperature
    /// against the one thing it cares about, and the founder's grip on the
    /// company tightens or slips. No draws — the verdict is arithmetic on
    /// the last quarter.
    private static func quarterlyReview(
        _ state: inout GameState,
        _ balance: BalanceConfig
    ) -> [GameEvent] {
        let config = balance.investors
        let interval = max(1, config.reviewIntervalDays)
        guard state.day > 0, state.day.isMultiple(of: interval) else { return [] }

        let revenue = quarterRevenue(state, interval: interval)
        let shipped = shippedThisQuarter(state, interval: interval)
        // A quarter is profitable when the account grew across it.
        let profitable = state.company.cash > state.investors.lastQuarterCash
        if profitable {
            state.investors.profitableQuarters += 1
        } else {
            state.investors.profitableQuarters = 0
        }

        var events: [GameEvent] = []
        let watching = state.investors.boardExpectations
        if let expectation = watching.last {
            // Every seated investor grades their own number. The step is
            // the *share* missed rather than the sum, so a second board is
            // harder to satisfy without being an unwinnable pincer: two
            // boards asking for profitability and headcount at once would
            // otherwise step twice a quarter and oust a founder who was
            // doing one of them well.
            let results = watching.map {
                meets(
                    $0, revenue: revenue, shipped: shipped,
                    profitable: profitable, state: state, balance: balance
                )
            }
            let metShare = Double(results.count(where: { $0 })) / Double(max(1, results.count))
            let met = metShare >= 1
            // The review line names a number that was actually missed,
            // which is the one the founder can act on.
            let reported = zip(watching, results).first { !$0.1 }?.0 ?? expectation
            // `patienceWeeks` finally does something. A twelve-week fund
            // reacts twice as hard as a twenty-four-week one, in both
            // directions — the impatient board is quicker to lose faith
            // *and* quicker to be won back, which is what makes the
            // pressure meter a thing the player can play against rather
            // than a countdown.
            // The newest seat sets the temperature of the room, and an
            // acquirer on an earn-out is the newest seat there is.
            let patience = state.investors.earnOut?.patienceWeeks
                ?? state.investors.rounds.last { $0.takesBoardSeat }?.patienceWeeks
            let harshness = min(2.5, max(0.5, config.patienceReferenceWeeks / Double(max(1, patience ?? 26))))
            let step = -config.pressurePerHit * metShare
                + config.pressurePerMiss * (1 - metShare)
            // The board reads the founder's own pay line too. A founder
            // drawing several times what they pay their engineers is a
            // governance question, and it is the one number on the Life
            // tab the Business tab can see directly.
            let payPressure = state.founderPayExcess(balance: balance)
                * balance.economy.founderPayBoardPressure
            var pressure = min(config.boardOustPressure, max(
                0,
                state.investors.boardPressure + step * harshness + payPressure
            ))
            let crossedWarning = pressure >= config.boardWarningPressure
                && state.investors.boardPressure < config.boardWarningPressure
            // Nobody is fired at the meeting where the problem is first
            // raised. `boardDemandedPlan` asks the founder for a plan, and
            // a plan the board never gave them a quarter to execute is not
            // a warning, it is a formality — so a review that crosses the
            // warning line cannot also carry the vote, however hard the
            // step was. An impatient strategic board steps 65 at a time,
            // which without this would take a founder from 35 straight to
            // the door with the warning and the vote in the same minute.
            if crossedWarning {
                pressure = min(pressure, config.boardOustPressure - 1)
            }
            state.investors.boardPressure = pressure
            state.investors.record(BoardReview(
                day: state.day,
                expectation: reported,
                met: met,
                pressure: pressure,
                note: met ? metNote(reported) : missNote(reported)
            ))
            events.append(.boardReviewed(met: met, pressure: pressure, day: state.day))

            if crossedWarning, pressure < config.boardOustPressure {
                events.append(.boardDemandedPlan(pressure: pressure, day: state.day))
            }
            // The acquirer's review settles before the room's vote, so a
            // review that closes the sale closes it.
            if let earnOut = state.investors.earnOut {
                let earnOutMet = zip(watching, results).first { $0.0 == earnOut.expectation }?.1 ?? false
                events.append(contentsOf: settleEarnOut(met: earnOutMet, state: &state, balance: balance))
            }
            if pressure >= config.boardOustPressure {
                events.append(contentsOf: oustFounder(&state))
            }
        }

        state.investors.lastQuarterCash = state.company.cash
        state.investors.lastQuarterRevenue = revenue
        state.investors.peakQuarterRevenue = max(state.investors.peakQuarterRevenue, revenue)
        state.investors.lastQuarterShipped = shipped
        state.investors.lastQuarterHeadcount = state.headcount
        return events
    }

    /// Sales booked in the last quarter, from the ledger.
    private static func quarterRevenue(_ state: GameState, interval: Int) -> Int {
        state.ledger.entries
            .filter { $0.day > state.day - interval && $0.amount > 0 }
            .filter { $0.category == .sales || $0.category == .contracts }
            .reduce(0) { $0 + $1.amount }
    }

    /// Products that reached the market inside the last quarter.
    private static func shippedThisQuarter(_ state: GameState, interval: Int) -> Int {
        state.products.count { product in
            guard case .released(let info) = product.stage else { return false }
            return state.day - info.launchDay < interval
        }
    }

    /// The first expectation, in the board's own order, the company would
    /// miss if it were reviewed today — what an acquirer holds it to on an
    /// earn-out. `nil` when it would pass all four. Read before the
    /// acquirer's money lands, so the cheque cannot be the profitable
    /// quarter.
    static func currentlyMissedExpectation(
        _ state: GameState,
        balance: BalanceConfig
    ) -> BoardExpectation? {
        let interval = max(1, balance.investors.reviewIntervalDays)
        let revenue = quarterRevenue(state, interval: interval)
        let shipped = shippedThisQuarter(state, interval: interval)
        let profitable = state.company.cash > state.investors.lastQuarterCash
        return BoardExpectation.allCases.first { expectation in
            !meets(
                expectation, revenue: revenue, shipped: shipped,
                profitable: profitable, state: state, balance: balance
            )
        }
    }

    /// Whether the quarter met the one number the board is watching.
    ///
    /// Two of the four asks used to compound without a ceiling — "ten per
    /// cent more revenue than last quarter" and "one more head than last
    /// quarter", *every quarter, forever*. Measured over five game years
    /// that is not a demanding board, it is a countdown: every company
    /// eventually stops growing at ten per cent a quarter, and every
    /// office eventually fills up, so a founder who took money was fired
    /// sooner or later on **every** seed (6/10 by year five, and every
    /// surviving funded run under warning), while the bootstrapper next
    /// door sailed on. That is a trap with extra steps, not a trade-off.
    /// Both asks now have a ceiling that a company which has *arrived* can
    /// stand on, and neither is satisfied by a company sliding backwards.
    private static func meets(
        _ expectation: BoardExpectation,
        revenue: Int,
        shipped: Int,
        profitable: Bool,
        state: GameState,
        balance: BalanceConfig
    ) -> Bool {
        let config = balance.investors
        switch expectation {
        case .mrrGrowth:
            let previous = Double(state.investors.lastQuarterRevenue)
            // A first quarter with any revenue at all counts as growth.
            guard previous > 0 else { return revenue > 0 }
            if Double(revenue) >= previous * (1 + config.expectedQuarterlyRevenueGrowth) {
                return true
            }
            // Or a record quarter. A company at the top of its own range
            // is not failing its investors — it is where the last round
            // was betting it would get to. Falling off that peak is what
            // this board is actually watching for, and a studio only holds
            // its peak by launching into it, because a shipped product's
            // sales decay from the week it lands.
            return revenue >= state.investors.peakQuarterRevenue && revenue > 0
        case .shipCadence:
            return shipped >= config.expectedQuarterlyShips
        case .headcount:
            if state.headcount
                >= state.investors.lastQuarterHeadcount + config.expectedQuarterlyHeadcountGrowth {
                return true
            }
            // Or a full house: nobody can hire into a room with no desk in
            // it, and a board that fires a founder for that is asking for
            // an office upgrade rather than for a hire. The founder can
            // still buy the bigger room — that is the decision this ask is
            // meant to force — but standing at the cap is not a miss.
            return state.headcount >= balance.office(state.company.officeTier).headcountCap
        case .profitability:
            return profitable
        }
    }

    private static func metNote(_ expectation: BoardExpectation) -> String {
        switch expectation {
        case .mrrGrowth: "Revenue is up. The board is briefly pleasant."
        case .shipCadence: "You shipped. Nobody mentions the roadmap."
        case .headcount: "The team grew. Somebody says \"velocity\" twice."
        case .profitability: "The account grew. The meeting ends early."
        }
    }

    private static func missNote(_ expectation: BoardExpectation) -> String {
        switch expectation {
        case .mrrGrowth: "Revenue slipped. They want to know what changed."
        case .shipCadence: "Another quarter with nothing shipped. They noticed."
        case .headcount: "The team didn't grow. \"Are we still ambitious?\""
        case .profitability: "You burned more than you made. Again."
        }
    }

    /// The board replaces the founder. The run ends — not a bankruptcy, but
    /// not a win either.
    private static func oustFounder(_ state: inout GameState, reason: String? = nil) -> [GameEvent] {
        guard state.gameOver == nil else { return [] }
        let name = state.progression.founder.displayName
        state.gameOver = GameOverInfo(
            day: state.day,
            reason: reason ?? "The board voted to replace \(name) with an outside CEO.",
            kind: .oustedByBoard
        )
        return [.founderOusted(day: state.day), .gameOver(day: state.day)]
    }

    // MARK: - Buy back the board

    /// Pays a round back out of the cap table at
    /// `GameState.buybackPrice(for:balance:)`. Cash out with a ledger
    /// line, the round moves to `boughtOut`, the equity comes home, and
    /// because `boardExpectations` is derived from seated rounds their
    /// ask leaves the room by construction; when the last seat goes, so
    /// does the pressure, and the quarterly review has nobody to grade
    /// for. Refused without the cash, after the run has ended, or for a
    /// round that is not on the table. No draws.
    static func buyBackRound(
        investorID: String,
        state: inout GameState,
        balance: BalanceConfig
    ) -> [GameEvent] {
        guard state.gameOver == nil,
              let index = state.investors.rounds.firstIndex(where: { $0.investorID == investorID })
        else { return [] }
        let round = state.investors.rounds[index]
        let price = state.buybackPrice(for: round, balance: balance)
        guard state.company.cash >= price else { return [] }

        state.company.cash -= price
        state.ledger.post(LedgerEntry(
            day: state.day, amount: -price, category: .other,
            label: "Bought out \(round.investorName)"
        ))
        var bought = state.investors.rounds.remove(at: index)
        bought.boughtOutDay = state.day
        bought.buybackPrice = price
        state.investors.boughtOut.append(bought)
        state.investors.equityRemaining = min(100, state.investors.equityRemaining + round.equity)
        if state.investors.boardExpectations.isEmpty {
            state.investors.boardPressure = 0
        }
        return [.roundBoughtBack(investorID: investorID, amount: price, day: state.day)]
    }

    // MARK: - Earn-out

    /// One earn-out review, graded by the review that just ran. A met
    /// review pays its tranche (the last one pays whatever is left, so two
    /// met reviews come to the price exactly); a miss pays nothing; the
    /// balance's number of misses is the acquirer bringing in their own
    /// CEO, keeping what was paid; and the last review closes the sale as
    /// `.acquired` for the total. No draws.
    private static func settleEarnOut(
        met: Bool,
        state: inout GameState,
        balance: BalanceConfig
    ) -> [GameEvent] {
        guard var earnOut = state.investors.earnOut, earnOut.remainingReviews > 0,
              state.gameOver == nil
        else { return [] }
        let config = balance.investors
        earnOut.remainingReviews -= 1
        var paid = 0
        if met {
            let tranche = Int((Double(earnOut.price) * config.earnOutReviewShare).rounded())
            let last = earnOut.remainingReviews == 0 && earnOut.missedReviews == 0
            paid = min(earnOut.outstanding, last ? earnOut.outstanding : tranche)
            state.company.cash += paid
            state.ledger.post(LedgerEntry(
                day: state.day, amount: paid, category: .other,
                label: "\(earnOut.buyerName) earn-out"
            ))
            earnOut.paid += paid
        } else {
            earnOut.missedReviews += 1
        }
        state.investors.earnOut = earnOut
        var events: [GameEvent] = [.earnOutReviewed(
            met: met, paid: paid, remainingReviews: earnOut.remainingReviews, day: state.day
        )]

        let founder = state.progression.founder.displayName
        if earnOut.missedReviews >= config.earnOutMissesToOust {
            events.append(contentsOf: oustFounder(
                &state,
                reason: "\(earnOut.buyerName) lost patience and replaced \(founder) with their own CEO. "
                    + "The earn-out paid \(earnOut.paid.dollars) of \(earnOut.price.dollars)."
            ))
        } else if earnOut.remainingReviews == 0 {
            let reason = earnOut.paid >= earnOut.price
                ? "Acquired by \(earnOut.buyerName) for \(earnOut.price.dollars), every dollar of the earn-out paid."
                : "Acquired by \(earnOut.buyerName) for \(earnOut.paid.dollars) — "
                    + "\(earnOut.outstanding.dollars) of the \(earnOut.price.dollars) earn-out forfeited."
            state.gameOver = GameOverInfo(day: state.day, reason: reason, kind: .acquired)
            events.append(.companySold(rivalID: earnOut.buyerRivalID, amount: earnOut.paid, day: state.day))
            events.append(.gameOver(day: state.day))
        }
        return events
    }

    // MARK: - Actions

    /// Takes the money: cash into the company, equity off the founder's
    /// slice, and the investor onto the cap table (and the board, if the
    /// term sheet asked for a seat). Ignored with nothing pending.
    static func acceptOffer(state: inout GameState, balance: BalanceConfig) -> [GameEvent] {
        // R5: no round is seated past the ending, including one whose
        // term sheet was already on the desk when the bell rang.
        guard let offer = state.investors.pendingOffer, state.epilogue == nil else { return [] }
        state.investors.pendingOffer = nil

        state.company.cash += offer.amount
        state.ledger.post(LedgerEntry(
            day: state.day,
            amount: offer.amount,
            category: .other,
            label: "\(offer.investorName) round"
        ))
        state.investors.equityRemaining = max(0, state.investors.equityRemaining - offer.equity)
        state.investors.rounds.append(RaisedRound(
            investorID: offer.investorID,
            investorName: offer.investorName,
            amount: offer.amount,
            equity: offer.equity,
            valuation: offer.valuation,
            day: state.day,
            takesBoardSeat: offer.takesBoardSeat,
            expects: offer.expects,
            patienceWeeks: offer.patienceWeeks
        ))
        // A fresh board starts its clock from today's numbers rather than
        // grading the founder on a quarter it wasn't in the room for —
        // and the pressure goes with the old board.
        //
        // This is the founder's way out of a hostile board, and it costs
        // exactly what it should: somebody has just looked at the company,
        // priced it *above* what the last round paid, and wired the money,
        // which is a harder vote of confidence than any quarter's numbers.
        // The price of it is another slice of the company, so a founder
        // who keeps buying their way out of the boardroom arrives at the
        // exit owning very little of it. That is the trade-off the whole
        // layer is for.
        if offer.takesBoardSeat {
            state.investors.lastQuarterCash = state.company.cash
            state.investors.lastQuarterHeadcount = state.headcount
            // A fresh cheque buys goodwill, not amnesia. Wiping the
            // pressure outright made raising again a full pardon priced in
            // equity — the harness's own investor bot had to be forbidden
            // from re-raising to measure an ousting at all. What is left
            // carries, and the new investor's expectation is *added* to
            // what the room is watching rather than replacing it.
            state.investors.boardPressure *= balance.investors.raisePressureRelief
        }
        return [.investmentAccepted(
            investorID: offer.investorID, amount: offer.amount, equity: offer.equity, day: state.day
        )]
    }

    /// Takes a strategic buyout as an earn-out: `earnOutUpfrontShare` of
    /// the price today, the rest over the next `earnOutReviews` quarterly
    /// reviews with the acquirer seated as the board. Their number is the
    /// first one the company would miss this morning (else profitability),
    /// read before the cheque lands; their patience is the shortest the
    /// review grades; and the team, who have just been sold, take it
    /// badly. Ignored with nothing pending, on a distress bid, or with an
    /// earn-out already running. No draws.
    static func acceptBuyoutEarnOut(state: inout GameState, balance: BalanceConfig) -> [GameEvent] {
        guard let offer = state.rivals.pendingBuyout,
              state.rivals.lastBuyoutWasStrategic,
              state.investors.earnOut == nil,
              state.gameOver == nil,
              // R5: an earn-out seats the acquirer as the board, and an
              // epilogue run has no board.
              state.epilogue == nil
        else { return [] }
        let config = balance.investors
        state.rivals.pendingBuyout = nil
        let buyerName = state.rivals.rival(id: offer.rivalID)?.name ?? "a rival"

        // Decided on the company as it stands, before their money lands.
        let expectation = state.earnOutExpectation(balance: balance)
        let upfront = Int((Double(offer.amount) * config.earnOutUpfrontShare).rounded())
        state.company.cash += upfront
        state.ledger.post(LedgerEntry(
            day: state.day, amount: upfront, category: .other,
            label: "\(buyerName) earn-out, up front"
        ))
        for index in state.employees.indices where !state.employees[index].isFounder {
            state.employees[index].morale = min(
                100, max(0, state.employees[index].morale - config.earnOutMoraleCost)
            )
        }
        state.investors.earnOut = EarnOut(
            buyerName: buyerName,
            buyerRivalID: offer.rivalID,
            price: offer.amount,
            paid: upfront,
            expectation: expectation,
            remainingReviews: config.earnOutReviews,
            patienceWeeks: config.earnOutPatienceWeeks
        )
        // A fresh seat starts its clock from today's numbers, the same way
        // a new board-seat round does — and the cheque that just landed is
        // not a profitable quarter.
        state.investors.lastQuarterCash = state.company.cash
        state.investors.lastQuarterHeadcount = state.headcount
        return [.earnOutSigned(
            rivalID: offer.rivalID, upfront: upfront, price: offer.amount, day: state.day
        )]
    }

    /// Turns the term sheet down. Ignored with nothing pending.
    static func declineOffer(state: inout GameState) -> [GameEvent] {
        guard let offer = state.investors.pendingOffer else { return [] }
        state.investors.pendingOffer = nil
        return [.investmentDeclined(investorID: offer.investorID, day: state.day)]
    }

    /// Files to go public. Gated exactly as `GameState.canFileIPO` reports,
    /// so the UI can explain a refusal before the player taps. The founder
    /// cashes out their slice at the IPO multiple and the run ends on the
    /// best note in the game.
    static func fileIPO(state: inout GameState, balance: BalanceConfig) -> [GameEvent] {
        guard state.canFileIPO(balance: balance) else { return [] }
        let config = balance.investors
        let valuation = Double(state.companyValuation(balance: balance)) * config.ipoValuationMultiple
        let proceeds = Int((valuation * state.investors.equityRemaining / 100).rounded())

        state.investors.ipoDay = state.day
        state.life.wallet += proceeds
        state.ledger.post(LedgerEntry(
            day: state.day, amount: 0, category: .other, label: "Initial public offering"
        ))
        state.gameOver = GameOverInfo(
            day: state.day,
            reason: "\(state.company.name) went public. \(state.progression.founder.displayName) "
                + "walked away with \(proceeds.dollars) for a "
                + "\(Int(state.investors.equityRemaining))% stake.",
            kind: .ipo
        )
        return [.wentPublic(proceeds: proceeds, day: state.day), .gameOver(day: state.day)]
    }

    // MARK: Iteration 5 — Still yours (WS-G)

    /// Declares the company built, still owning all of it. Gated exactly
    /// as `GameState.canStayIndependent` reports, so the UI can explain a
    /// refusal before the player taps. Nobody is bought out and nothing is
    /// cashed in — the founder keeps the company, which is the point — and
    /// the run ends on the independent ladder's note.
    static func declareIndependence(state: inout GameState, balance: BalanceConfig) -> [GameEvent] {
        guard state.canStayIndependent(balance: balance) else { return [] }
        let staff = state.headcount - 1
        let onSale = state.products.count { product in
            guard case .released(let info) = product.stage else { return false }
            return !info.offMarket
        }
        let quarters = state.investors.profitableQuarters
        let years = state.day / GameState.daysPerYear

        state.ledger.post(LedgerEntry(
            day: state.day, amount: 0, category: .other, label: "Still yours"
        ))
        state.gameOver = GameOverInfo(
            day: state.day,
            reason: "You still owned 100%. \(state.company.name) at \(years) years: "
                + "\(staff) \(staff == 1 ? "person" : "people") on payroll, "
                + "\(onSale) \(onSale == 1 ? "product" : "products") on sale, "
                + "\(quarters) profitable quarters in a row, and nobody in the room but you.",
            kind: .independent
        )
        return [.stayedIndependent(day: state.day), .gameOver(day: state.day)]
    }
}
