import Foundation
import TycoonContent

/// Iteration 11, wave two — W1. The offer, the cheque, the strings with
/// their clocks, the heat and the three ways out.
///
/// **Nothing in this file runs until the player opens the Business tab's
/// finances.** `run` returns on its first line while
/// `state.dirtyMoney == .empty`, and the only thing that makes it
/// non-empty is `.noticeFinancesOpened`, which the app sends when
/// `FinancesView` appears — the `noticeProductsOpened` pattern. A pacing
/// bot opens no screens, so no bot is ever offered a cheque, and every
/// byte-identical fixture replays exactly as it did.
///
/// **Draws.** `state.socialRNG` only, and only once the player has looked:
/// one uniform a week for the offer roll (and one more to pick the
/// backer), one a week for the reprisal roll while the heat is above the
/// floor, and one to choose which reprisal. `rng` and `worldRNG` are
/// never touched.
enum DirtyMoneySystem {

    /// Set the day a cheque is banked, and read by every `money_` event in
    /// the two catalogs, so a run with clean money draws from exactly the
    /// pool it drew from before this lane existed.
    static let backedFlag = "money_backed"
    /// Set while a string is waiting on an answer.
    static let demandFlag = "money_demand_open"
    /// Set for the rest of the run once the founder gave a statement.
    static let witnessFlag = "money_witness"
    /// Set for the rest of the run once they were paid off, so the world
    /// can remember that it happened at all.
    static let historyFlag = "money_history"

    // MARK: - The tick

    @Sendable
    static func run(
        _ state: inout GameState,
        _ balance: BalanceConfig,
        _ content: ContentCatalog
    ) -> [GameEvent] {
        guard state.dirtyMoney != .empty else { return [] }
        var events: [GameEvent] = []

        events.append(contentsOf: offerClock(&state, balance))
        events.append(contentsOf: demandClock(&state, balance, content))
        events.append(contentsOf: weeklyPass(&state, balance))
        return events
    }

    // MARK: The offer

    /// A cheque appears only for a company that is in trouble, and only
    /// once a week. Two conditions, either of them enough: the cash is
    /// under a month of operating costs, or a term sheet was turned down
    /// this quarter.
    private static func offerClock(
        _ state: inout GameState,
        _ balance: BalanceConfig
    ) -> [GameEvent] {
        let config = balance.dirtyMoney
        // An offer that stood too long goes away, quietly.
        if let by = state.dirtyMoney.offerRespondByDay, state.day > by {
            state.dirtyMoney.offerBacker(nil, cheque: 0, respondBy: nil)
        }
        guard state.dirtyMoney.backer == nil,
              state.dirtyMoney.exit == nil,
              state.dirtyMoney.offeredBacker == nil,
              state.day >= config.offerNotBeforeDay,
              state.day % GameState.daysPerWeek == 0,
              state.dirtyMoney.lastSweepDay != state.day,
              !state.life.isAway(day: state.day),
              isInTrouble(state, balance)
        else { return [] }

        let available = DirtyMoneyBacker.allCases.filter {
            !state.dirtyMoney.offeredAlready.contains($0.rawValue)
        }
        guard !available.isEmpty else { return [] }
        guard state.socialRNG.nextUniform() < config.offerChance else { return [] }

        let backer = available[state.socialRNG.nextInt(in: 0...(available.count - 1))]
        let payroll = state.employees.reduce(0) { $0 + $1.weeklySalary }
        let cheque = DirtyMoney.cheque(backer, payroll: payroll, balance: config)
        state.dirtyMoney.offerBacker(
            backer.rawValue, cheque: cheque, respondBy: state.day + config.offerDays
        )
        state.dirtyMoney.offeredAlready.append(backer.rawValue)

        state.life.phone.post(
            offerText(backer), from: .office, day: state.day
        )
        return [.dirtyMoneyOffered(
            backer: backer.rawValue, cheque: cheque,
            respondByDay: state.day + config.offerDays, day: state.day
        )]
    }

    /// Whether anybody would bother. Public so the card can say why the
    /// offer is not there.
    static func isInTrouble(_ state: GameState, _ balance: BalanceConfig) -> Bool {
        let config = balance.dirtyMoney
        let floor = Int(Double(balance.weeklyOperatingCost) * config.redCashWeeks)
        if state.company.cash < floor { return true }
        let window = state.day - config.declinedWindowDays
        return state.eventLog.contains { event in
            if case let .investmentDeclined(_, day) = event { return day > window }
            return false
        }
    }

    // MARK: J1 (doors)

    /// The shark's door, answered yes: the lane wakes exactly as if the
    /// founder had opened Finances, and the man who called is the offer on
    /// the table — no weekly roll, because he has already rung. Nothing
    /// here draws. A lane that already has a backer, an exit or an offer
    /// only gets the wake-up.
    static func doorOffer(state: inout GameState, balance: BalanceConfig) -> [GameEvent] {
        if !state.dirtyMoney.noticed { state.dirtyMoney.noticed = true }
        let shark = DirtyMoneyBacker.theShark
        guard state.dirtyMoney.backer == nil,
              state.dirtyMoney.exit == nil,
              state.dirtyMoney.offeredBacker == nil,
              !state.dirtyMoney.offeredAlready.contains(shark.rawValue)
        else { return [] }
        let config = balance.dirtyMoney
        let payroll = state.employees.reduce(0) { $0 + $1.weeklySalary }
        let cheque = DirtyMoney.cheque(shark, payroll: payroll, balance: config)
        let by = state.day + config.offerDays
        state.dirtyMoney.offerBacker(shark.rawValue, cheque: cheque, respondBy: by)
        state.dirtyMoney.offeredAlready.append(shark.rawValue)
        state.life.phone.post(offerText(shark), from: .office, day: state.day)
        return [.dirtyMoneyOffered(
            backer: shark.rawValue, cheque: cheque, respondByDay: by, day: state.day
        )]
    }

    // MARK: end J1

    private static func offerText(_ backer: DirtyMoneyBacker) -> String {
        switch backer {
        case .familyOffice:
            "Somebody called for you. Wouldn't leave a company name, left a number and said they'd been watching the round."
        case .theFront:
            "A fund called Meridian want twenty minutes. They already know the cash position, which nobody outside this room does."
        case .theShark:
            "A man called Denny is downstairs. He says you met at demo day and you were very funny."
        }
    }

    // MARK: The strings

    /// Raises the next string when its day arrives, and answers an
    /// unanswered one for the founder when the clock runs out.
    private static func demandClock(
        _ state: inout GameState,
        _ balance: BalanceConfig,
        _ content: ContentCatalog
    ) -> [GameEvent] {
        guard let backer = state.dirtyMoney.backerKind, state.dirtyMoney.exit == nil
        else { return [] }
        var events: [GameEvent] = []
        let config = balance.dirtyMoney

        // A string nobody answered is a refusal with worse manners.
        if let open = state.dirtyMoney.openDemand, state.day > open.dueDay {
            events.append(contentsOf: answer(.refuse, silent: true, state: &state, balance: balance))
        }

        guard state.dirtyMoney.openDemand == nil,
              let taken = state.dirtyMoney.takenDay,
              state.dirtyMoney.lastDemandDay ?? -999 != state.day
        else { return events }

        guard let kind = nextDemand(backer, taken: taken, state: state, balance: balance)
        else { return events }

        let amount = DirtyMoney.demandAmount(kind, cheque: state.dirtyMoney.cheque, balance: config)
        var topicID: String?
        if kind == .theirMarket {
            // The market they name is one the studio is not already in,
            // picked off the catalog in catalog order — no draw, because
            // the interesting thing is that it is not your choice.
            let mine = Set(state.products.map(\.topicID))
            topicID = content.topics.first { !mine.contains($0.id) }?.id
                ?? content.topics.first?.id
            state.dirtyMoney.namedTopicID = topicID
        }
        let demand = DirtyMoneyDemand(
            id: "\(kind.rawValue)-\(state.day)",
            kind: kind,
            raisedDay: state.day,
            dueDay: state.day + config.demandRespondDays,
            amount: amount,
            topicID: topicID
        )
        state.dirtyMoney.demands.append(demand)
        state.dirtyMoney.trimDemands()
        state.dirtyMoney.lastDemandDay = state.day
        state.narrative.flags.insert(demandFlag)
        state.life.phone.post(
            demandText(kind, backer: backer), from: .office, day: state.day
        )
        events.append(.dirtyMoneyDemanded(
            kind: kind.rawValue, amount: amount,
            dueDay: demand.dueDay, day: state.day
        ))
        return events
    }

    /// Which string is next, and whether its day has come. One at a time,
    /// in the backer's own order.
    private static func nextDemand(
        _ backer: DirtyMoneyBacker,
        taken: Int,
        state: GameState,
        balance: BalanceConfig
    ) -> DirtyMoneyDemandKind? {
        let config = balance.dirtyMoney
        let age = state.day - taken
        let asked = Set(state.dirtyMoney.demands.map(\.kind))
        switch backer {
        case .familyOffice:
            if !asked.contains(.consultant), age >= config.consultantAfterDays { return .consultant }
            if !asked.contains(.theirMarket), age >= config.theirMarketAfterDays { return .theirMarket }
            return nil
        case .theFront:
            let invoices = state.dirtyMoney.demands.filter { $0.kind == .invoice }
            let lastInvoice = invoices.last?.raisedDay
            if lastInvoice == nil, age >= config.invoiceAfterDays { return .invoice }
            if let lastInvoice, state.day - lastInvoice >= config.invoiceEveryDays { return .invoice }
            // The nephew arrives after the first invoice was actually paid.
            if !asked.contains(.nephew),
               let paid = invoices.first(where: { $0.answer == .comply })?.answeredDay,
               state.day - paid >= config.nephewAfterDays {
                return .nephew
            }
            return nil
        case .theShark:
            // The shark's string is the vig, which is taken weekly in
            // `FinanceSystem`'s W1 region and needs no sheet. He only asks
            // for something when a payment was missed, and that is raised
            // from there.
            return nil
        }
    }

    private static func demandText(_ kind: DirtyMoneyDemandKind, backer: DirtyMoneyBacker) -> String {
        switch kind {
        case .consultant:
            "\(backer.messageName) have sent through onboarding paperwork for somebody called Anton. Do we know an Anton?"
        case .theirMarket:
            "\(backer.messageName) sent a one-page deck about what we should build next. It isn't a suggestion deck."
        case .invoice:
            "There's an invoice in the inbox from a consultancy nobody here has heard of. It's addressed correctly."
        case .nephew:
            "There's a CV in reception with no CV in it."
        case .lateVisit:
            "Denny is in reception again and he hasn't taken his coat off."
        }
    }

    // MARK: The weekly pass

    /// Heat cools while nothing is outstanding, and pays out while it is
    /// not cool. One `socialRNG` word for the roll and one for the choice,
    /// and only while the heat is above the floor.
    private static func weeklyPass(
        _ state: inout GameState,
        _ balance: BalanceConfig
    ) -> [GameEvent] {
        guard state.day % GameState.daysPerWeek == 0,
              state.dirtyMoney.lastSweepDay != state.day
        else { return [] }
        state.dirtyMoney.lastSweepDay = state.day
        let config = balance.dirtyMoney

        // A founder who turned witness keeps a floor under the heat for
        // the rest of the run: the backer has nothing left to lose.
        let floor = state.narrative.flags.contains(witnessFlag) ? config.witnessHeatFloor : 0
        if state.dirtyMoney.openDemand == nil {
            state.dirtyMoney.heat = max(floor, state.dirtyMoney.heat - config.heatDecayPerWeek)
        }
        guard state.dirtyMoney.heat > config.reprisalHeatFloor else { return [] }
        if let last = state.dirtyMoney.lastReprisalDay,
           state.day - last < config.reprisalCooldownDays { return [] }

        let chance = DirtyMoney.reprisalChance(heat: state.dirtyMoney.heat, balance: config)
        guard state.socialRNG.nextUniform() < chance else { return [] }
        return payOut(&state, balance)
    }

    /// The heat becomes a thing that happened. Which thing depends on what
    /// the founder has to lose: the car only if there is a car, a friend
    /// only if there is a friend.
    private static func payOut(
        _ state: inout GameState,
        _ balance: BalanceConfig
    ) -> [GameEvent] {
        let config = balance.dirtyMoney
        var available: [DirtyMoneyReprisal] = [.window]
        if state.assets.owned.contains(where: { $0.kind == .car }) { available.append(.car) }
        if !state.life.friends.friends.isEmpty { available.append(.friend) }
        if !state.rivals.rivals.isEmpty { available.append(.rival) }

        let pick = available[state.socialRNG.nextInt(in: 0...(available.count - 1))]
        state.dirtyMoney.lastReprisalDay = state.day
        var events: [GameEvent] = []

        switch pick {
        case .window:
            state.company.cash -= config.windowRepairCost
            state.ledger.post(LedgerEntry(
                day: state.day, amount: -config.windowRepairCost,
                category: .other, label: "Glazing, out of hours"
            ))
            for index in state.employees.indices where !state.employees[index].isFounder {
                state.employees[index].morale = max(
                    0, state.employees[index].morale - config.windowMoraleHit
                )
            }
            state.life.phone.post(
                "The window's in. Nobody heard anything, which is a strange thing for a street to say.",
                from: .office, day: state.day
            )

        case .car:
            // N3's own machinery derives every other fact about a car
            // from `owned`, so taking it out of the array is the whole of
            // taking the car — and off the drive with it.
            if let car = state.assets.owned.first(where: { $0.kind == .car }) {
                state.assets.owned.removeAll { $0.catalogID == car.catalogID }
                if let slot = HomeDecor.assetSlotID(for: .car) {
                    HomeDecor.remove(slot: slot, tier: state.life.home, decor: &state.life.decor)
                }
                events.append(.assetStolen(assetID: car.catalogID, day: state.day))
            }
            state.life.meters.apply(mood: -config.reprisalMoodHit)

        case .friend:
            if let index = state.life.friends.friends.indices.max(by: {
                state.life.friends.friends[$0].bond < state.life.friends.friends[$1].bond
            }) {
                let name = state.life.friends.friends[index].name
                state.life.friends.friends[index].bond = max(
                    0, state.life.friends.friends[index].bond - config.friendBondHit
                )
                state.life.phone.post(
                    "Two men came to my work and asked about you for an hour. I told them nothing. Please don't call me for a bit.",
                    from: .friend(state.life.friends.friends[index].id), day: state.day
                )
                _ = name
            }
            state.life.meters.apply(mood: -config.reprisalMoodHit)

        case .rival:
            if let index = state.rivals.rivals.indices.first {
                state.rivals.rivals[index].strength = min(
                    100, state.rivals.rivals[index].strength + config.rivalStrengthGain
                )
            }
        }

        events.append(.dirtyMoneyReprisal(
            kind: pick.rawValue, heat: state.dirtyMoney.heat, day: state.day
        ))
        return events
    }

    // MARK: - Taking the money

    /// The one gate the button and the engine share.
    static func takeRefusal(_ state: GameState, _ balance: BalanceConfig) -> DirtyMoneyRefusal? {
        if state.dirtyMoney.backer != nil { return .alreadyBacked }
        if !state.dirtyMoney.hasOffer(on: state.day) { return .noOffer }
        if state.life.isAway(day: state.day) { return .away }
        return nil
    }

    /// Banks the cheque. The money is the company's, the record entry is
    /// the founder's, and there is no board seat to give away — which is
    /// the entire pitch.
    static func take(
        state: inout GameState,
        balance: BalanceConfig
    ) -> [GameEvent] {
        guard takeRefusal(state, balance) == nil,
              let backer = state.dirtyMoney.offeredKind
        else { return [] }
        let cheque = state.dirtyMoney.offeredCheque

        state.dirtyMoney.backer = backer.rawValue
        state.dirtyMoney.takenDay = state.day
        state.dirtyMoney.cheque = cheque
        state.dirtyMoney.offerBacker(nil, cheque: 0, respondBy: nil)
        state.narrative.flags.insert(backedFlag)
        state.narrative.flags.insert(historyFlag)

        state.company.cash += cheque
        state.ledger.post(LedgerEntry(
            day: state.day, amount: cheque, category: .other,
            label: DirtyMoney.ledgerLabel(backer)
        ))

        // The cheque itself is the first thing a court would ask about.
        var events = launder(cheque, backer: backer, state: &state, balance: balance)
        state.life.phone.post(
            "It's cleared. All of it, in one line, from a bank I had to look up.",
            from: .office, day: state.day
        )
        events.insert(.dirtyMoneyTaken(
            backer: backer.rawValue, cheque: cheque, day: state.day
        ), at: 0)
        return events
    }

    /// Turns the offer down. They are pleasant about it, which is worse.
    static func declineOffer(state: inout GameState) -> [GameEvent] {
        guard let backer = state.dirtyMoney.offeredKind else { return [] }
        state.dirtyMoney.offerBacker(nil, cheque: 0, respondBy: nil)
        state.life.phone.post(
            "They said no problem at all and to keep the number. They said it twice.",
            from: .office, day: state.day
        )
        return [.dirtyMoneyDeclined(backer: backer.rawValue, day: state.day)]
    }

    // MARK: - Answering a string

    /// Why this answer would be refused today, or `nil` when it would land.
    static func answerRefusal(
        _ answer: DirtyMoneyAnswer,
        state: GameState,
        balance: BalanceConfig
    ) -> DirtyMoneyRefusal? {
        guard state.dirtyMoney.isBacked else { return .noBacker }
        guard let demand = state.dirtyMoney.openDemand else { return .nothingToAnswer }
        switch answer {
        case .stall:
            if demand.stalled { return .alreadyStalled }
        case .comply:
            if demand.amount > 0, state.company.cash + state.life.wallet < demand.amount {
                return .cannotAfford
            }
        case .refuse:
            break
        }
        return nil
    }

    /// Comply, stall or refuse. The cost is paid here and only here.
    static func answer(
        _ answer: DirtyMoneyAnswer,
        silent: Bool = false,
        state: inout GameState,
        balance: BalanceConfig
    ) -> [GameEvent] {
        guard silent || answerRefusal(answer, state: state, balance: balance) == nil,
              let backer = state.dirtyMoney.backerKind,
              let index = state.dirtyMoney.demands.firstIndex(where: { $0.isOpen })
        else { return [] }
        let config = balance.dirtyMoney
        let demand = state.dirtyMoney.demands[index]
        var events: [GameEvent] = []

        if answer == .stall, !demand.stalled {
            state.dirtyMoney.demands[index].stalled = true
            state.dirtyMoney.demands[index].dueDay = state.day + config.stallDays
            state.dirtyMoney.heat = min(100, state.dirtyMoney.heat
                + DirtyMoney.heatDelta(.stall, kind: demand.kind, balance: config))
            state.life.phone.post(
                stallText(backer), from: .office, day: state.day
            )
            events.append(.dirtyMoneyAnswered(
                kind: demand.kind.rawValue, answer: answer.rawValue,
                heat: state.dirtyMoney.heat, day: state.day
            ))
            return events
        }

        state.dirtyMoney.demands[index].answer = answer
        state.dirtyMoney.demands[index].answeredDay = state.day
        state.narrative.flags.remove(demandFlag)

        if answer == .comply {
            state.dirtyMoney.complied += 1
            events.append(contentsOf: complyWith(demand, backer: backer, state: &state, balance: balance))
        } else {
            state.dirtyMoney.refused += 1
            state.life.phone.post(refuseText(backer), from: .office, day: state.day)
        }
        state.dirtyMoney.heat = min(100, max(0, state.dirtyMoney.heat
            + DirtyMoney.heatDelta(answer, kind: demand.kind, balance: config)))

        events.append(.dirtyMoneyAnswered(
            kind: demand.kind.rawValue, answer: answer.rawValue,
            heat: state.dirtyMoney.heat, day: state.day
        ))
        return events
    }

    /// What complying actually does.
    private static func complyWith(
        _ demand: DirtyMoneyDemand,
        backer: DirtyMoneyBacker,
        state: inout GameState,
        balance: BalanceConfig
    ) -> [GameEvent] {
        let config = balance.dirtyMoney
        switch demand.kind {
        case .consultant, .nephew:
            let cost = DirtyMoney.passengerCost(
                demand.kind, cheque: state.dirtyMoney.cheque, balance: config
            )
            state.dirtyMoney.passengers.append(DirtyMoneyPassenger(
                id: demand.kind.rawValue,
                name: demand.kind == .consultant ? "Anton" : "Dima",
                title: demand.kind == .consultant ? "Strategic adviser" : "Junior something",
                weeklyCost: cost,
                sinceDay: state.day
            ))
            state.life.phone.post(
                demand.kind == .consultant
                    ? "Anton is on the payroll. Anton has not been in. Payroll has stopped asking."
                    : "The nephew started today. He has asked four people what the company does.",
                from: .office, day: state.day
            )
            return []

        case .theirMarket:
            state.life.phone.post(
                "We're building what they said we'd build. Everyone is being very professional about it.",
                from: .office, day: state.day
            )
            return []

        case .invoice, .lateVisit:
            let amount = demand.amount
            let fromCompany = min(max(0, state.company.cash), amount)
            if fromCompany > 0 {
                state.company.cash -= fromCompany
                state.ledger.post(LedgerEntry(
                    day: state.day, amount: -fromCompany, category: .other,
                    label: demand.kind == .invoice
                        ? "Consultancy services — no PO"
                        : "Facility fee"
                ))
            }
            let fromWallet = amount - fromCompany
            if fromWallet > 0 { state.life.wallet -= fromWallet }
            return launder(amount, backer: backer, state: &state, balance: balance)
        }
    }

    private static func stallText(_ backer: DirtyMoneyBacker) -> String {
        switch backer {
        case .familyOffice: "They said of course, take the time you need, and asked when you'd be back in the office."
        case .theFront: "Meridian said end of the month is fine. They didn't say which month, which is not reassuring."
        case .theShark: "Denny said fine. Denny has never said fine before."
        }
    }

    private static func refuseText(_ backer: DirtyMoneyBacker) -> String {
        switch backer {
        case .familyOffice: "They thanked you for your candour and hung up first."
        case .theFront: "Meridian have stopped replying to the thread. The thread is still open."
        case .theShark: "Denny didn't say anything. He wrote something down, which he has also never done."
        }
    }

    // MARK: - Laundering

    /// Every dollar that goes through them is a line on the record with an
    /// offence attached, so the auditor's weekly sweep can find it and the
    /// courtroom can hear it. This is the only place the seventh offence
    /// is ever written.
    static func launder(
        _ amount: Int,
        backer: DirtyMoneyBacker,
        state: inout GameState,
        balance: BalanceConfig
    ) -> [GameEvent] {
        guard amount > 0 else { return [] }
        state.dirtyMoney.laundered += amount
        let events = CrimeSystem.dirtyMoneyLaunder(
            amount: amount,
            note: DirtyMoney.launderNote(amount, backer: backer),
            notoriety: balance.dirtyMoney.launderNotoriety,
            state: &state
        )
        return events + [.dirtyMoneyLaundered(
            amount: amount, total: state.dirtyMoney.laundered, day: state.day
        )]
    }

    // MARK: - The ways out

    /// What it costs to be rid of them today.
    static func payOffPrice(_ state: GameState, _ balance: BalanceConfig) -> Int {
        DirtyMoney.payoffPrice(
            cheque: state.dirtyMoney.cheque,
            heat: state.dirtyMoney.heat,
            balance: balance.dirtyMoney
        )
    }

    static func payOffRefusal(_ state: GameState, _ balance: BalanceConfig) -> DirtyMoneyRefusal? {
        guard state.dirtyMoney.isBacked else { return .noBacker }
        let price = payOffPrice(state, balance)
        if state.company.cash + state.life.wallet < price { return .cannotAfford }
        return nil
    }

    /// Buys the relationship out at a multiple of the cheque. The money is
    /// still money that went through them, so it is still a line on the
    /// record — but the strings stop and the heat goes.
    static func payOff(state: inout GameState, balance: BalanceConfig) -> [GameEvent] {
        guard payOffRefusal(state, balance) == nil,
              let backer = state.dirtyMoney.backerKind
        else { return [] }
        let price = payOffPrice(state, balance)
        let fromCompany = min(max(0, state.company.cash), price)
        if fromCompany > 0 {
            state.company.cash -= fromCompany
            state.ledger.post(LedgerEntry(
                day: state.day, amount: -fromCompany, category: .other,
                label: "Facility settled in full"
            ))
        }
        let fromWallet = price - fromCompany
        if fromWallet > 0 { state.life.wallet -= fromWallet }

        var events = launder(price, backer: backer, state: &state, balance: balance)
        closeOut(.paidOff, state: &state)
        state.life.phone.post(
            "It's paid. They were warm about it, which after everything is the part I'll remember.",
            from: .office, day: state.day
        )
        events.append(.dirtyMoneyExited(
            how: DirtyMoneyExit.paidOff.rawValue, amount: price, day: state.day
        ))
        return events
    }

    static func witnessRefusal(_ state: GameState) -> DirtyMoneyRefusal? {
        guard state.dirtyMoney.isBacked else { return .noBacker }
        guard state.crime.record.contains(where: { $0.offence == .launderMoney && $0.isOpen })
        else { return .nothingToConfess }
        return nil
    }

    /// Walks into a police station with the statements. N1's `confess`
    /// raises the case today rather than in some week a roll chooses, and
    /// the backer's heat becomes a permanent floor for the rest of the run.
    static func turnWitness(state: inout GameState, balance: BalanceConfig) -> [GameEvent] {
        guard witnessRefusal(state) == nil else { return [] }
        let entry = state.crime.record.last { $0.offence == .launderMoney && $0.isOpen }
        var events = CrimeSystem.confess(entryID: entry?.id, state: &state, balance: balance)
        guard !events.isEmpty else { return [] }

        state.narrative.flags.insert(witnessFlag)
        closeOut(.turnedWitness, state: &state)
        state.dirtyMoney.heat = max(
            balance.dirtyMoney.witnessHeatFloor, state.dirtyMoney.heat
        )
        state.life.phone.post(
            "You gave them everything. There is a car outside your building tonight and it is not one of ours.",
            from: .office, day: state.day
        )
        events.append(.dirtyMoneyExited(
            how: DirtyMoneyExit.turnedWitness.rawValue, amount: 0, day: state.day
        ))
        return events
    }

    static func sellUpPrice(_ state: GameState, _ balance: BalanceConfig) -> Int {
        DirtyMoney.sellUpPrice(
            cheque: state.dirtyMoney.cheque,
            valuation: state.companyValuation(balance: balance),
            balance: balance.dirtyMoney
        )
    }

    static func sellUpRefusal(_ state: GameState) -> DirtyMoneyRefusal? {
        state.dirtyMoney.isBacked ? nil : .noBacker
    }

    /// Sells them the company. The buyout machinery's `.soldUp` ending,
    /// with a line in the biography that says who bought it.
    static func sellUp(state: inout GameState, balance: BalanceConfig) -> [GameEvent] {
        guard sellUpRefusal(state) == nil, let backer = state.dirtyMoney.backerKind
        else { return [] }
        let price = sellUpPrice(state, balance)
        let founderShare = Int((Double(price) * balance.dirtyMoney.sellUpFounderFraction).rounded())

        state.company.cash += price
        state.ledger.post(LedgerEntry(
            day: state.day, amount: price, category: .other,
            label: "Company sale — \(backer.displayName)"
        ))
        state.life.wallet += founderShare
        closeOut(.soldUp, state: &state)

        state.gameOver = GameOverInfo(
            day: state.day,
            reason: "\(backer.displayName) took the company for \(price.dirtyMoneyFigure). Nobody asked what it was worth.",
            kind: .soldUp
        )
        return [
            .dirtyMoneyExited(how: DirtyMoneyExit.soldUp.rawValue, amount: price, day: state.day),
            .gameOver(day: state.day),
        ]
    }

    /// The relationship is over, however it ended: no backer, no strings,
    /// no passengers on the payroll.
    private static func closeOut(_ exit: DirtyMoneyExit, state: inout GameState) {
        state.dirtyMoney.exit = exit
        state.dirtyMoney.exitDay = state.day
        state.dirtyMoney.backer = nil
        state.dirtyMoney.passengers = []
        state.dirtyMoney.namedTopicID = nil
        for index in state.dirtyMoney.demands.indices where state.dirtyMoney.demands[index].isOpen {
            state.dirtyMoney.demands[index].answer = .comply
            state.dirtyMoney.demands[index].answeredDay = state.day
        }
        state.narrative.flags.remove(demandFlag)
        state.narrative.flags.remove(backedFlag)
        if exit != .turnedWitness { state.dirtyMoney.heat = 0 }
    }

    // MARK: - The screenshot pass

    #if DEBUG
    /// `-autoDirtyMoney <backer>`: puts an offer on the table so a
    /// headless pass can photograph it and then take it.
    ///
    /// The *offer* is seeded, not the cheque: everything after this — the
    /// banking, the strings, the heat — is a real `GameAction` through
    /// the ordinary reducer, exactly as a player would send it. Debug
    /// builds only; nothing in the game sends this action.
    static func debugSeedOffer(
        backer: String,
        state: inout GameState,
        balance: BalanceConfig
    ) -> [GameEvent] {
        let kind = DirtyMoneyBacker(rawValue: backer)
            ?? DirtyMoneyBacker.allCases.first { $0.rawValue.lowercased() == backer.lowercased() }
            ?? .theFront
        guard state.dirtyMoney.backer == nil else { return [] }
        let payroll = state.employees.reduce(0) { $0 + $1.weeklySalary }
        let cheque = DirtyMoney.cheque(kind, payroll: payroll, balance: balance.dirtyMoney)
        let by = state.day + balance.dirtyMoney.offerDays
        state.dirtyMoney.noticed = true
        state.dirtyMoney.offerBacker(kind.rawValue, cheque: cheque, respondBy: by)
        if !state.dirtyMoney.offeredAlready.contains(kind.rawValue) {
            state.dirtyMoney.offeredAlready.append(kind.rawValue)
        }
        state.life.phone.post(
            offerText(kind), from: .office, day: state.day
        )
        return [.dirtyMoneyOffered(
            backer: kind.rawValue, cheque: cheque, respondByDay: by, day: state.day
        )]
    }

    /// `-autoDirtyMoneyDemand <kind>`: pulls one of the strings today.
    ///
    /// The demand is the ordinary shape with the ordinary price and the
    /// ordinary clock — only its date is chosen, the way `-autoSecret`
    /// chooses a thread's stage. Answering it is a real action.
    static func debugSeedDemand(
        kind: String,
        state: inout GameState,
        balance: BalanceConfig
    ) -> [GameEvent] {
        guard let backer = state.dirtyMoney.backerKind,
              state.dirtyMoney.openDemand == nil
        else { return [] }
        let wanted = DirtyMoneyDemandKind(rawValue: kind)
            ?? DirtyMoneyDemandKind.allCases.first { $0.rawValue.lowercased() == kind.lowercased() }
            ?? .invoice
        let config = balance.dirtyMoney
        let amount = DirtyMoney.demandAmount(
            wanted, cheque: state.dirtyMoney.cheque, balance: config
        )
        let due = state.day + config.demandRespondDays
        state.dirtyMoney.demands.append(DirtyMoneyDemand(
            id: "\(wanted.rawValue)-\(state.day)",
            kind: wanted,
            raisedDay: state.day,
            dueDay: due,
            amount: amount
        ))
        state.dirtyMoney.trimDemands()
        state.dirtyMoney.lastDemandDay = state.day
        state.narrative.flags.insert(demandFlag)
        state.life.phone.post(
            demandText(wanted, backer: backer), from: .office, day: state.day
        )
        return [.dirtyMoneyDemanded(
            kind: wanted.rawValue, amount: amount, dueDay: due, day: state.day
        )]
    }
    #endif

    // MARK: - The finance system's half

    /// Raised by `FinanceSystem`'s W1 region when the shark's weekly
    /// payment could not be taken. One sheet, three answers, and the third
    /// one is expensive.
    static func raiseLateVisit(
        amount: Int,
        state: inout GameState,
        balance: BalanceConfig
    ) -> [GameEvent] {
        guard state.dirtyMoney.openDemand == nil, state.dirtyMoney.backerKind == .theShark
        else { return [] }
        let due = state.day + max(2, balance.dirtyMoney.demandRespondDays / 2)
        state.dirtyMoney.demands.append(DirtyMoneyDemand(
            id: "lateVisit-\(state.day)",
            kind: .lateVisit,
            raisedDay: state.day,
            dueDay: due,
            amount: amount * 2
        ))
        state.dirtyMoney.trimDemands()
        state.dirtyMoney.lastDemandDay = state.day
        state.narrative.flags.insert(demandFlag)
        state.life.phone.post(
            "Denny is in reception again and he hasn't taken his coat off.",
            from: .office, day: state.day
        )
        return [.dirtyMoneyDemanded(
            kind: DirtyMoneyDemandKind.lateVisit.rawValue,
            amount: amount * 2, dueDay: due, day: state.day
        )]
    }
}

// MARK: - Small mutations the state owns

extension DirtyMoneyState {
    mutating func offerBacker(_ backer: String?, cheque: Int, respondBy: Int?) {
        offeredBacker = backer
        offeredCheque = cheque
        offerRespondByDay = respondBy
    }

    mutating func trimDemands() {
        if demands.count > Self.maxDemands {
            demands.removeFirst(demands.count - Self.maxDemands)
        }
    }
}

// MARK: - Gates the app reads

extension GameState {
    /// Why taking the cheque would be refused today, or `nil` when it
    /// would land. The button and the reducer read the same function.
    public func dirtyMoneyTakeRefusal(balance: BalanceConfig) -> DirtyMoneyRefusal? {
        DirtyMoneySystem.takeRefusal(self, balance)
    }

    /// Why this answer would be refused today.
    public func dirtyMoneyAnswerRefusal(
        _ answer: DirtyMoneyAnswer,
        balance: BalanceConfig
    ) -> DirtyMoneyRefusal? {
        DirtyMoneySystem.answerRefusal(answer, state: self, balance: balance)
    }

    /// What being rid of them costs today.
    public func dirtyMoneyPayOffPrice(balance: BalanceConfig) -> Int {
        DirtyMoneySystem.payOffPrice(self, balance)
    }

    public func dirtyMoneyPayOffRefusal(balance: BalanceConfig) -> DirtyMoneyRefusal? {
        DirtyMoneySystem.payOffRefusal(self, balance)
    }

    public func dirtyMoneyWitnessRefusal() -> DirtyMoneyRefusal? {
        DirtyMoneySystem.witnessRefusal(self)
    }

    public func dirtyMoneySellUpPrice(balance: BalanceConfig) -> Int {
        DirtyMoneySystem.sellUpPrice(self, balance)
    }

    public func dirtyMoneySellUpRefusal() -> DirtyMoneyRefusal? {
        DirtyMoneySystem.sellUpRefusal(self)
    }

    /// The weekly vig, for the card. Zero unless the shark's money is in
    /// the account.
    public func dirtyMoneyWeeklyVig(balance: BalanceConfig) -> Int {
        guard dirtyMoney.backerKind == .theShark else { return 0 }
        return DirtyMoney.vig(cheque: dirtyMoney.cheque, balance: balance.dirtyMoney)
    }
}
