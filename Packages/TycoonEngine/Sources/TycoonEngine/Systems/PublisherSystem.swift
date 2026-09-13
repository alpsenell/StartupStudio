import Foundation
import TycoonContent

// MARK: T4 (publisher)

/// Iteration 17 — T4 (G1). The publishing deal's verbs and its three
/// touches on the week: the share after each sales post, the clawback
/// after each slip, the name on launch day (`publisherLaunchHype`, read by
/// `ProductSystem.ship`). Draws nothing. Every entry point returns at once
/// for a product with no publisher, which is every product in every run
/// that never shopped one.
enum PublisherSystem {
    /// Signs the deal `publisherTerms` prints: the advance in cash, the
    /// publisher on the product, the topic in the studio's focus, and the
    /// date through J5's own announcement (a date already standing stays).
    static func shop(
        productID: UUID,
        state: inout GameState,
        balance: BalanceConfig,
        content: ContentCatalog
    ) -> [GameEvent] {
        let terms = state.publisherTerms(productID: productID, balance: balance, content: content)
        guard terms.isOpen,
              let rivalID = terms.rivalID,
              let rivalName = terms.rivalName,
              let date = terms.date,
              let index = state.products.firstIndex(where: { $0.id == productID })
        else { return [] }
        let name = state.products[index].name

        state.company.cash += terms.advance
        state.ledger.post(LedgerEntry(
            day: state.day, amount: terms.advance, category: .other,
            label: "Advance from \(rivalName): \(name)"
        ))
        state.products[index].publisher = Publisher(
            rivalID: rivalID, rivalName: rivalName, advance: terms.advance,
            share: terms.share, signedDay: state.day
        )
        // They read the board: the topic is home now.
        if let rival = state.rivals.rivals.firstIndex(where: { $0.id == rivalID }),
           !state.rivals.rivals[rival].focusTopicIDs.contains(terms.topicID) {
            state.rivals.rivals[rival].focusTopicIDs.append(terms.topicID)
        }
        var events: [GameEvent] = [.publisherSigned(
            productID: productID, rivalID: rivalID, advance: terms.advance,
            share: terms.share, forDay: date, day: state.day
        )]
        if !state.products[index].isAnnounced {
            events += AnnounceSystem.announce(
                productID: productID, day: date, state: &state, balance: balance, content: content
            )
        }
        return events
    }

    /// Buys the publisher out at `publisherBuyoutPrice`: the share stops
    /// today; a date in print stays in print.
    static func buyOut(productID: UUID, state: inout GameState, balance: BalanceConfig) -> [GameEvent] {
        guard state.publisherBuyoutBlocker(productID: productID, balance: balance) == nil,
              let index = state.products.firstIndex(where: { $0.id == productID }),
              let publisher = state.products[index].publisher,
              let price = state.publisherBuyoutPrice(for: state.products[index], balance: balance)
        else { return [] }
        state.company.cash -= price
        state.ledger.post(LedgerEntry(
            day: state.day, amount: -price, category: .other,
            label: "Bought \(state.products[index].name) back from \(publisher.rivalName)"
        ))
        state.products[index].publisher = nil
        return [.publisherBoughtOut(
            productID: productID, rivalID: publisher.rivalID, price: price, day: state.day
        )]
    }

    /// The publisher's share of the sales week just posted for the product
    /// at `index`. Returns at once without a publisher, or once the studio
    /// has left the field.
    static func postShare(at index: Int, revenue: Int, state: inout GameState) {
        guard revenue > 0,
              var publisher = state.products[index].publisher,
              state.publisherIsActive(state.products[index])
        else { return }
        let cut = Int((Double(revenue) * publisher.share).rounded())
        guard cut > 0 else { return }
        publisher.paidBack += cut
        state.products[index].publisher = publisher
        state.company.cash -= cut
        state.ledger.post(LedgerEntry(
            day: state.day, amount: -cut, category: .sales,
            label: "\(publisher.rivalName)'s share: \(state.products[index].name)"
        ))
    }

    /// A published build missed its date: `clawbackPerSlip` of the advance
    /// goes back. `nil` for a build nobody publishes.
    static func clawBack(at index: Int, state: inout GameState, balance: BalanceConfig) -> GameEvent? {
        guard var publisher = state.products[index].publisher,
              state.publisherIsActive(state.products[index])
        else { return nil }
        let amount = Int((Double(publisher.advance) * balance.publisher.clawbackPerSlip).rounded())
        guard amount > 0 else { return nil }
        publisher.clawedBack += amount
        state.products[index].publisher = publisher
        state.company.cash -= amount
        state.ledger.post(LedgerEntry(
            day: state.day, amount: -amount, category: .other,
            label: "Clawed back by \(publisher.rivalName): \(state.products[index].name)"
        ))
        return .publisherClawedBack(
            productID: state.products[index].id, rivalID: publisher.rivalID, amount: amount, day: state.day
        )
    }
}

// MARK: end T4
