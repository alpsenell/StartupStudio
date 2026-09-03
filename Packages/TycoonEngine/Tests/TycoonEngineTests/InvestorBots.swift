import Foundation
import TycoonContent
import TycoonEngine

/// The bot that answers a term sheet.
///
/// Nothing in the harness did before this pass, so WS-F's whole investor and
/// board layer — the offers, the quarterly review, the pressure, the
/// ousting, the IPO — and every chapter-4 goal behind it went entirely
/// unmeasured. The one experiment that had been run (bolting
/// `.acceptInvestment` onto `SaaSBuilderBot`) took it from 3/10 to 7/10
/// "bankrupt", which turned out to be the board replacing the founder and
/// `SimRunner` calling that a bankruptcy.
///
/// This is a funded startup rather than a bootstrapper: it takes the money
/// when the terms are worth the dilution, spends it on people and offices,
/// and — the part that matters — *plays to the number its board watches*,
/// because a founder who takes a growth cheque and then optimises for
/// something else is not measuring the board, they are ignoring it.
struct InvestorBot: BotPolicy {
    var name = "investor"
    /// Whether the bot answers term sheets at all. The control for "does
    /// taking money help?" is this same bot with the cheque declined.
    var takesTheMoney = true
    /// The most of the company it will part with in one round.
    var maxEquityPerRound = 25.0
    /// A cheque is worth taking when it covers at least this many weeks of
    /// payroll — below that the dilution buys nothing.
    var minRunwayWeeksBought = 8
    /// Weeks of payroll kept in the bank before hiring. At 8 the bot hired
    /// on day one out of the starting cash and was dead by day 84 with
    /// nothing shipped.
    var hireRunwayWeeks = 12
    /// Whether the founder actually runs the company against the number
    /// their board watches. False is the other kind of founder: takes the
    /// growth cheque, keeps doing exactly what they were doing.
    var playsToTheBoard = true
    /// Whether it spends on the things chapter 4 asks for: amenities, and
    /// buying a rival outright.
    var buysTheTrophies = true
    /// Whether the company keeps growing once the money is in the bank.
    ///
    /// False is the founder who raises a round and then settles down to
    /// make the thing properly: no more hires, no bigger office, one
    /// product at a time and it ships when it is *right*. That is a real
    /// person, not a straw man — and it is exactly the founder a growth
    /// board exists to fire, because the cheque was priced on the growth
    /// they have stopped delivering. It is the only bot that ever reaches
    /// the vote, so it is the only one that can measure it.
    var growsAfterFunding = true
    /// How finished a build has to look before the perfectionist ships it.
    var coastingPolish = 0.98

    /// True once there is a *board* on the cap table and this founder has
    /// stopped growing into what it paid for.
    ///
    /// Gated on the seat rather than on any round: a company that settles
    /// down after its first angel cheque never grows into a board-seat
    /// investor's valuation floor in the first place, so it is never
    /// offered a board, is never reviewed, and measures nothing. The
    /// founder this bot is about is the one who raises the *big* round —
    /// the one with a partner on the board — and then stops.
    private func coasting(_ state: GameState) -> Bool {
        !growsAfterFunding && state.investors.rounds.contains { $0.takesBoardSeat }
    }

    func actions(
        for state: GameState,
        balance: BalanceConfig,
        content: ContentCatalog
    ) -> [GameAction] {
        var actions: [GameAction] = []
        actions.append(contentsOf: BotHelp.weekendPlan(state))

        // The best ending in the game, whenever it is on the table.
        if state.canFileIPO(balance: balance) {
            return actions + [.fileIPO]
        }
        actions.append(contentsOf: answerTermSheet(state, balance))

        let payroll = state.employees.reduce(0) { $0 + $1.weeklySalary }
        let focus = playsToTheBoard ? state.investors.boardExpectation : nil
        // A board that watches the account is not humoured by a hiring
        // spree in the last week of the quarter.
        let watchingTheAccount = focus == .profitability
        // …and one that counts desks is not humoured by a healthy bank
        // balance. Serving this board means hiring closer to the bone and
        // paying for the room to put them in, which is the whole point:
        // the number the board watches is a number the founder has to
        // spend real money to move.
        let countingDesks = focus == .headcount
        let runway = countingDesks ? max(6, hireRunwayWeeks - 4) : hireRunwayWeeks
        let cap = balance.office(state.company.officeTier).headcountCap
        let stalled = coasting(state)

        if !stalled, state.headcount < cap,
           !watchingTheAccount || state.company.cash > payroll * hireRunwayWeeks * 3,
           let candidate = BotHelp.bestValueCandidate(state),
           state.company.cash > (payroll + candidate.weeklySalary) * runway {
            actions.append(.hire(candidateID: candidate.id))
        }
        for employee in state.employees where !employee.isFounder {
            let fair = Int(balance.fairWeeklyPay(for: employee).rounded())
            if employee.weeklySalary < fair {
                actions.append(.adjustSalary(employeeID: employee.id, weeklySalary: fair))
            }
        }
        if let pending = state.economy.pendingResignation {
            actions.append(.adjustSalary(
                employeeID: pending.employeeID,
                weeklySalary: Int(Double(pending.salaryAtNotice) * 1.2)
            ))
        }

        // A bigger office is a *rent* decision, not a deposit decision.
        // Checking only the sticker price is how this bot moved six people
        // into a fourteen-desk studio on the back of one good launch month
        // and was gone two quarters later.
        if let next = state.company.officeTier.next,
           !watchingTheAccount, !stalled,
           state.headcount >= cap - 1,
           state.company.cash >= balance.office(next).upgradeCost
               + payroll * (countingDesks ? 3 : 6)
               + balance.office(next).weeklyRent * (countingDesks ? 13 : 26) {
            actions.append(.upgradeOffice)
        }
        actions.append(contentsOf: trophies(state, balance))
        actions.append(contentsOf: build(state, balance, content, focus: focus))
        return actions
    }

    /// Takes the cheque when it is worth the dilution: a fifth of the
    /// company for two months of payroll is not, and a founder who signs
    /// anything put in front of them is not measuring the board either.
    private func answerTermSheet(
        _ state: GameState,
        _ balance: BalanceConfig
    ) -> [GameAction] {
        guard let offer = state.investors.pendingOffer else { return [] }
        guard takesTheMoney else { return [.declineInvestment] }
        // This bot used to refuse a second round outright. It had to:
        // accepting a board-seat round wiped the pressure, so a founder
        // could buy their way out of the boardroom for equity alone and
        // the bot would have been measuring the escape hatch instead of
        // the vote.
        //
        // The hatch is closed — a raise now keeps half the pressure and
        // *adds* the new investor's number to what the room watches — so
        // the ban is gone and the bot raises whenever the terms are worth
        // it, which is what a founder would do. Every gate in
        // `InvestorTargetsTests` still holds with it raising freely, which
        // is the evidence the mechanic works rather than the ban hiding a
        // hole.
        let payroll = max(1, state.employees.reduce(0) { $0 + $1.weeklySalary })
        let worthIt = offer.equity <= maxEquityPerRound
            && offer.amount >= payroll * minRunwayWeeksBought
        return [worthIt ? .acceptInvestment : .declineInvestment]
    }

    /// What chapter 4 asks for and no bot ever did: an office people want
    /// to be in, and a competitor bought outright.
    private func trophies(_ state: GameState, _ balance: BalanceConfig) -> [GameAction] {
        guard buysTheTrophies else { return [] }
        var actions: [GameAction] = []
        // Amenities, cheapest first, while a quarter's payroll is still
        // left over afterwards.
        let payroll = state.employees.reduce(0) { $0 + $1.weeklySalary }
        for amenity in Amenity.allCases where !state.amenities.contains(amenity) {
            let def = balance.company.amenity(amenity)
            guard OfficeTier.allCases.firstIndex(of: state.company.officeTier) ?? 0
                    >= OfficeTier.allCases.firstIndex(of: def.minTier) ?? 0,
                  state.company.cash >= def.upgradeCost + payroll * 13
            else { continue }
            actions.append(.buildAmenity(amenity))
            break
        }
        // And a rival, when the company is dominant enough to be allowed
        // and rich enough to pay for it.
        let valuation = Double(state.companyValuation(balance: balance))
        let target = state.rivals.rivals.first { rival in
            let cost = Double(rival.valuation(balance: balance))
            return valuation >= cost * balance.rivals.acquireDominanceFactor
                && Double(state.company.cash) >= cost * balance.rivals.acquirePremium + Double(payroll * 13)
        }
        if let target {
            actions.append(.acquireRival(rivalID: target.id))
        }
        return actions
    }

    /// What to build, and when to call it finished — which is where the
    /// board actually reaches the product.
    private func build(
        _ state: GameState,
        _ balance: BalanceConfig,
        _ content: ContentCatalog,
        focus: BoardExpectation?
    ) -> [GameAction] {
        var actions: [GameAction] = []
        // A board counting ships gets ships: the polish gate drops so the
        // quarter always has something in it. One counting revenue gets
        // the opposite — finish it properly, it earns more. And the
        // founder who has stopped growing polishes until the board runs
        // out of patience.
        let polish: Double = if coasting(state) {
            coastingPolish
        } else if focus == .shipCadence {
            0.7
        } else {
            0.9
        }

        for product in state.productsInDevelopment {
            if BotHelp.looksShippable(product, balance, content, polish: polish) {
                actions.append(.ship(productID: product.id))
            } else {
                actions.append(.setPhaseFocus(
                    productID: product.id,
                    focus: BotHelp.focusForRemainingWork(product, content)
                ))
            }
        }
        // The platform, once the lab has reached it: a board watching MRR
        // is watching subscriptions.
        let unlocked = state.isProductTypeUnlocked("saas_platform", content: content)
        if !unlocked, !coasting(state), state.research.activeNodeID == nil,
           let next = SaaSBuilderBot.path.first(where: { !state.research.unlocked.contains($0) }) {
            actions.append(.startResearch(nodeID: next))
        }
        let hasPlatform = state.products.contains { $0.typeID == "saas_platform" }
        // The perfectionist starts nothing new while the current build is
        // still short of perfect — and their bar is never quite met.
        let mayStartSomething = !coasting(state) || state.productsInDevelopment.isEmpty
        if state.hasFreeDevSlot, mayStartSomething {
            let type: String
            if unlocked, !hasPlatform, state.headcount >= 5 {
                type = "saas_platform"
            } else {
                type = state.headcount >= 2 ? "web_app" : "mobile_app"
            }
            actions.append(.startProduct(
                typeID: type,
                topicID: BotHelp.topic(forProductNumber: state.products.count),
                name: "Round \(state.products.count + 1)",
                focus: .balanced
            ))
            // `startProduct` deals everyone idle onto the new build.
            return actions
        }

        // Crew: the founder in the lab until the platform is unlocked, a
        // support desk once it is live, everyone else across the builds.
        let livePlatform = state.products.first { product in
            guard case .released(let info) = product.stage else { return false }
            return product.typeID == "saas_platform" && !info.offMarket
        }
        let builds = state.productsInDevelopment.map(\.id)
        var dealt = 0
        var supportPlaced = 0
        for employee in state.employees {
            let wanted: Assignment
            if employee.isFounder, !unlocked, state.company.cash > 20_000 {
                wanted = .research
            } else if let livePlatform, supportPlaced < 2, state.headcount > 4 {
                wanted = .support(livePlatform.id)
                supportPlaced += 1
            } else if !builds.isEmpty {
                wanted = .product(builds[dealt % builds.count])
                dealt += 1
            } else {
                wanted = .research
            }
            if employee.assignment != wanted {
                actions.append(.assign(employeeID: employee.id, to: wanted))
            }
        }
        return actions
    }
}

extension InvestorBot {
    /// The control: the identical studio that turns every term sheet down.
    /// The only difference between the two is the answer to one question,
    /// which is what makes "does taking money help?" answerable.
    static var bootstrapper: InvestorBot {
        InvestorBot(name: "bootstrapper", takesTheMoney: false)
    }

    /// The founder who takes the growth cheque and then runs the company
    /// exactly as they were going to anyway — never once looking at what
    /// the board is counting. Measured, this founder is *fine*: a company
    /// that keeps hiring and keeps shipping hits a growth board's numbers
    /// without being asked to, which is the mechanic working as written
    /// rather than a hole in it.
    static var ignoresTheBoard: InvestorBot {
        InvestorBot(name: "ignores-board", playsToTheBoard: false)
    }

    /// The founder who raises a round and then stops. No more hires, no
    /// bigger office, one product at a time and it ships when it is
    /// *right*. Every one of the board's three numbers goes flat at once,
    /// which is what the pressure meter was built to notice, and this is
    /// the only bot that ever reaches the vote.
    static var coasts: InvestorBot {
        InvestorBot(name: "coasts", growsAfterFunding: false)
    }
}

// MARK: - Iteration 5 (WS-B)

/// The founder who takes the first strategic offer as an earn-out and
/// then plays to the acquirer's number — which `InvestorBot` already does
/// once they are seated, because `boardExpectation` is the newest seat's.
/// Distress bids are declined. This is the tell for the earn-out: if it
/// collects the full price on nearly every seed the number is free money;
/// if it is ousted or forfeits on nearly every seed the twelve-week board
/// is a coin flip. Never in either pinned suite.
struct AcquirerBot: BotPolicy {
    var name = "acquirer"
    var base = InvestorBot()

    func actions(
        for state: GameState,
        balance: BalanceConfig,
        content: ContentCatalog
    ) -> [GameAction] {
        var actions: [GameAction] = []
        if state.rivals.pendingBuyout != nil {
            actions.append(state.rivals.lastBuyoutWasStrategic ? .acceptBuyoutEarnOut : .declineBuyout)
        }
        return actions + base.actions(for: state, balance: balance, content: content)
    }
}

/// The founder who buys the board out the moment they can afford it and
/// still keep `runwayWeeks` of payroll in the bank. Seated rounds only:
/// this is about the vote, not the cap table. The tell for the buyback:
/// how often it happens with the room past the warning line, what it
/// costs as a share of the cash on hand, and whether the founder who
/// bought the vote away is better or worse off than the one who did not.
/// Never in either pinned suite.
struct BuybackBot: BotPolicy {
    var name = "buyback"
    var base = InvestorBot()
    var runwayWeeks = 8
    /// Only buy the vote away once the room is at least this hot. Zero
    /// is the founder who ends the meeting the moment they can pay for
    /// it; sixty is the one who waits for the formal warning.
    var minPressure = 0.0

    func actions(
        for state: GameState,
        balance: BalanceConfig,
        content: ContentCatalog
    ) -> [GameAction] {
        var actions: [GameAction] = []
        let payroll = state.employees.reduce(0) { $0 + $1.weeklySalary }
        if state.investors.boardPressure >= minPressure,
           let round = state.investors.rounds.first(where: { round in
            round.takesBoardSeat
                && state.company.cash - state.buybackPrice(for: round, balance: balance)
                    >= payroll * runwayWeeks
        }) {
            actions.append(.buyBackRound(investorID: round.investorID))
        }
        return actions + base.actions(for: state, balance: balance, content: content)
    }
}
