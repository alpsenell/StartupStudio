import Foundation
import TycoonContent

// MARK: J5 (announce)

/// Iteration 12 — J5. The announced date, kept or missed.
///
/// Daily, after the builds have worked: a build still in development the
/// day after its announced date has slipped. The first slip costs
/// reputation and hype and the press prints a new date (today's ETA plus
/// `announce.redateDays`); the second costs more and voids the
/// announcement. A product that shipped on or before its date gets one
/// line in the paper the day after.
///
/// Draws nothing. The loop skips every product that was never announced,
/// which is every product in every run that never pressed the button.
enum AnnounceSystem {
    @Sendable
    static func run(
        _ state: inout GameState,
        _ balance: BalanceConfig,
        _ content: ContentCatalog
    ) -> [GameEvent] {
        var events: [GameEvent] = []
        var anyStanding = false
        for index in state.products.indices {
            let product = state.products[index]
            guard product.wasAnnounced, let date = product.announcedDay else { continue }
            switch product.stage {
            case .development:
                if state.day > date {
                    events.append(contentsOf: slip(at: index, state: &state, balance: balance, content: content))
                }
                if state.products[index].isAnnounced { anyStanding = true }
            case .released(let info):
                if info.launchDay == state.day - 1, info.launchDay <= date {
                    events.append(.announceKept(
                        productID: product.id, forDay: date, slips: product.slips, day: info.launchDay
                    ))
                }
            }
        }
        // MARK: T5 (expo and pre-orders) — the launch week delivers what a
        // build pre-sold. Walks only products that opened pre-orders.
        events.append(contentsOf: deliverPreorders(&state, balance, content))
        // MARK: end T5
        // `announce_live` stands while a date does, so the events about a
        // coming date stop once there is none. Only a run that announced
        // ever has a product past the guard above, so only it can get here
        // with anything to change.
        let flagged = state.narrative.flags.contains(Announce.liveFlag)
        if anyStanding != flagged {
            if anyStanding {
                state.narrative.flags.insert(Announce.liveFlag)
            } else {
                state.narrative.flags.remove(Announce.liveFlag)
            }
        }
        return events
    }

    // MARK: - Actions

    /// Names `day` as the ship date of a build in development. Refused for
    /// every reason `GameState.announceRefusal` names; a refusal returns no
    /// events, which is how the toast layer knows to say why.
    static func announce(
        productID: UUID,
        day announced: Int,
        state: inout GameState,
        balance: BalanceConfig,
        content: ContentCatalog
    ) -> [GameEvent] {
        guard state.announceRefusal(
            productID: productID, day: announced, balance: balance, content: content
        ) == nil,
            let index = state.products.firstIndex(where: { $0.id == productID })
        else { return [] }
        state.products[index].announcedDay = announced
        state.narrative.flags.insert(Announce.madeFlag)
        state.narrative.flags.insert(Announce.liveFlag)
        return [.announceMade(productID: productID, forDay: announced, day: state.day)]
    }

    /// `-autoAnnounce slip`: miss the standing date today, through the same
    /// slip a real miss takes. Debug builds only; nothing in the game
    /// sends it.
    static func forceSlip(
        productID: UUID,
        state: inout GameState,
        balance: BalanceConfig,
        content: ContentCatalog
    ) -> [GameEvent] {
        guard let index = state.products.firstIndex(where: { $0.id == productID }),
              state.products[index].isAnnounced,
              case .development = state.products[index].stage
        else { return [] }
        return slip(at: index, state: &state, balance: balance, content: content)
    }

    // MARK: - The slip

    // T5: internal, not private — T2's shelve slips an announced build
    // through this same function.
    static func slip(
        at index: Int,
        state: inout GameState,
        balance: BalanceConfig,
        content: ContentCatalog
    ) -> [GameEvent] {
        var product = state.products[index]
        product.slips += 1
        let cost = Announce.slipCost(slipNumber: product.slips, balance: balance)
        state.company.reputation = min(100, max(0, state.company.reputation - cost.reputation))
        if case .development(var dev) = product.stage {
            dev.hype *= cost.hypeFactor
            product.stage = .development(dev)
        }

        let newDay: Int?
        if product.slips >= Announce.voidAfterSlips {
            product.announcedDay = nil
            newDay = nil
            state.narrative.flags.insert(Announce.voidFlag)
        } else {
            // The press prints a new date off the ETA as it stands today.
            // A build nobody is on is dated from today.
            let eta = state.shipETA(for: product, balance: balance, content: content)?.day ?? state.day
            let redated = max(eta, state.day) + max(1, balance.announce.redateDays)
            product.announcedDay = redated
            newDay = redated
        }
        // MARK: T5 (expo and pre-orders) — pre-orders come back the day the
        // date slips: a third on the first slip, the rest (and reputation
        // −4 more) on the void. Nothing for a build that never pre-sold.
        let refund = preorderRefund(
            for: &product, voiding: product.slips >= Announce.voidAfterSlips, state: &state, balance: balance
        )
        // MARK: end T5
        state.narrative.flags.insert(Announce.slippedFlag)
        state.products[index] = product
        // MARK: T4 (publisher) — a published build's slip claws back
        // `publisher.clawbackPerSlip` of the advance. Nothing for a build
        // nobody published, which falls through to the line below.
        if let clawed = PublisherSystem.clawBack(at: index, state: &state, balance: balance) {
            return [
                .announceSlipped(productID: product.id, slips: product.slips, newDay: newDay, day: state.day),
                clawed,
            ]
        }
        // MARK: end T4
        return [.announceSlipped(
            productID: product.id, slips: product.slips, newDay: newDay, day: state.day
        )] + refund // T5: the refund's line, empty without pre-orders
    }
}

// MARK: end J5

// MARK: T5 (expo and pre-orders)

/// Iteration 17 — T5. Pre-orders: opened against the announced date,
/// refunded beside J5's slip, delivered by the launch week. Every function
/// here is reached only from `.openPreorders` or a product that has a
/// `PreorderBook`, so a run that never opened pre-orders passes through
/// untouched and draws nothing.
extension AnnounceSystem {
    /// Sells `preorders.fraction` of the forecast's launch week now, at
    /// `preorders.price` of the standard price. Refused for every reason
    /// `GameState.preorderRefusal` names.
    static func openPreorders(
        productID: UUID,
        state: inout GameState,
        balance: BalanceConfig,
        content: ContentCatalog
    ) -> [GameEvent] {
        guard state.preorderRefusal(productID: productID, balance: balance, content: content) == nil,
              let quote = state.preorderQuote(productID: productID, balance: balance, content: content),
              let index = state.products.firstIndex(where: { $0.id == productID })
        else { return [] }
        state.products[index].preorders = PreorderBook(
            units: quote.units, unitPrice: quote.unitPrice, cash: quote.cash,
            openedDay: state.day, forecastQuality: quote.forecastQuality
        )
        state.company.cash += quote.cash
        state.ledger.post(LedgerEntry(
            day: state.day, amount: quote.cash, category: .sales,
            label: "\(state.products[index].name): \(quote.units) pre-orders"
        ))
        return [.preordersOpened(productID: productID, units: quote.units, cash: quote.cash, day: state.day)]
    }

    /// What a slip gives back, written onto `product` (a copy the caller
    /// stores) and paid out of the company's cash; on the void, the rest
    /// and `preorders.voidReputation` off the company's name. Empty for a
    /// product with nothing owed.
    static func preorderRefund(
        for product: inout Product,
        voiding: Bool,
        state: inout GameState,
        balance: BalanceConfig
    ) -> [GameEvent] {
        guard var book = product.preorders, !book.isDelivered, book.outstanding > 0 else { return [] }
        let units = book.refundUnits(voiding: voiding, balance: balance)
        let cash = book.refundCash(units: units)
        book.refundedUnits += units
        book.refundedCash += cash
        product.preorders = book
        if cash != 0 {
            state.company.cash -= cash
            state.ledger.post(LedgerEntry(
                day: state.day, amount: -cash, category: .sales,
                label: "\(product.name): \(units) pre-orders refunded"
            ))
        }
        if voiding {
            state.company.reputation = min(100, max(0,
                state.company.reputation - balance.expo.preorders.voidReputation
            ))
        }
        return [.preordersRefunded(productID: product.id, units: units, cash: cash, voided: voiding, day: state.day)]
    }

    /// For a build that will never ship (T2's scrap): every pre-order back,
    /// and the void's reputation. Empty for a build that never pre-sold.
    static func refundAllPreorders(
        at index: Int,
        state: inout GameState,
        balance: BalanceConfig
    ) -> [GameEvent] {
        var product = state.products[index]
        let events = preorderRefund(for: &product, voiding: true, state: &state, balance: balance)
        state.products[index] = product
        return events
    }

    /// The launch weeks' first buyers are the pre-orders, already paid for:
    /// each sales week `postWeeklySales` posts (earlier the same day — it
    /// runs before this system) hands its buyers to the pre-orders still
    /// owed first, so its units stand and its revenue counts only the rest,
    /// the difference taken back out as one ledger line. Once every
    /// pre-order is out (or the product leaves the market) the book is
    /// delivered. Walks only products with an undelivered `PreorderBook`.
    static func deliverPreorders(
        _ state: inout GameState,
        _ balance: BalanceConfig,
        _ content: ContentCatalog
    ) -> [GameEvent] {
        var events: [GameEvent] = []
        for index in state.products.indices {
            guard var book = state.products[index].preorders, !book.isDelivered,
                  case .released(var info) = state.products[index].stage
            else { continue }
            let name = state.products[index].name
            let price = content.productType(state.products[index].typeID).map {
                $0.unitPrice * balance.economy.priceTier(info.priceTier).priceFactor
            } ?? 0
            var carved = false
            while book.deliveredWeeks < info.weeklySales.count, book.undelivered > 0 {
                let week = book.deliveredWeeks
                let sale = info.weeklySales[week]
                let taken = min(book.undelivered, sale.units)
                if taken > 0 {
                    let revenue = Int(Double(sale.units - taken) * price)
                    let adjustment = revenue - sale.revenue
                    info.weeklySales[week] = WeeklySale(weekIndex: sale.weekIndex, units: sale.units, revenue: revenue)
                    book.deliveredUnits += taken
                    if adjustment != 0 {
                        state.company.cash += adjustment
                        state.ledger.post(LedgerEntry(
                            day: state.day, amount: adjustment, category: .sales,
                            label: "\(name): \(taken) pre-orders delivered, paid in advance"
                        ))
                    }
                }
                book.deliveredWeeks += 1
                carved = true
            }
            let done = book.undelivered == 0 || info.offMarket
            guard carved || done else { continue }
            if carved { state.products[index].stage = .released(info) }
            if done {
                book.deliveredDay = state.day
                if book.deliveredUnits > 0 {
                    events.append(.preordersDelivered(
                        productID: state.products[index].id, units: book.deliveredUnits, day: state.day
                    ))
                }
            }
            state.products[index].preorders = book
        }
        return events
    }
}

// MARK: end T5
