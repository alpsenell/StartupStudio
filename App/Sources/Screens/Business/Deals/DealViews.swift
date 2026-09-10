import SwiftUI
import TycoonContent
import TycoonEngine

// Iteration 15 — K4 (deals and exits): the app's half of the three verbs
// (`Deals.swift` is the engine's). One home each: the sign on Rivals, the
// paper deal on the rival's profile, the sell-up on the queue's sheet and
// the money sheet. Every button carries its consequence; the engine is
// the enforcer and these views only read the same queries it does.

// MARK: - The for-sale sign

/// The for-sale sign, on the Rivals segment: name a price, see who would
/// bid and when on today's numbers, and what the office pays while the
/// sign stands — or, once it is up, where the bids have got to.
struct DealSignCard: View {
    let engine: GameEngine

    @State private var ask: Double = 1.2
    @State private var confirming = false

    var body: some View {
        let state = engine.state
        let balance = engine.balance
        CardView("The for-sale sign", systemImage: "signpost.right.fill") {
            if let listing = state.rivals.listing {
                listed(listing, state: state, balance: balance)
            } else {
                unlisted(state: state, balance: balance)
            }
        }
        .task { await DealDebug.startIfAsked(engine: engine) }
    }

    // MARK: Before

    @ViewBuilder
    private func unlisted(state: GameState, balance: BalanceConfig) -> some View {
        let deals = balance.deals
        let valuation = state.companyValuation(balance: balance)
        let clamped = GameState.dealClampedAsk(ask, balance: balance)
        let price = Int((Double(valuation) * clamped).rounded())
        let bids = DealProjection.schedule(state: state, balance: balance, ask: clamped)
        let blocker = state.dealListingBlocker(balance: balance)

        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text("Name your price. Every \(deals.bidIntervalDays / 7) weeks a rival bids, a little higher each time, up to your ask — and the office reads the papers while the sign is up.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: Theme.Spacing.sm) {
                step(systemImage: "minus", by: -0.1, disabled: clamped <= deals.askMin)
                VStack(spacing: 2) {
                    Text("\(DealCopy.multiple(clamped)) · \(price.money)")
                        .font(Theme.Typography.number(.headline))
                        .contentTransition(.numericText())
                    Text("of today's \(valuation.money)")
                        .font(.caption2)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .combine)
                step(systemImage: "plus", by: 0.1, disabled: clamped >= deals.askMax)
            }

            DealBidSchedule(bids: bids, ask: price, day: state.day)

            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Button {
                    Haptics.tap()
                    confirming = true
                } label: {
                    Label("Put it up for sale at \(price.money)", systemImage: "signpost.right.fill")
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .monospacedDigit()
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.warning)
                .disabled(blocker != nil)

                Text(blocker ?? DealCopy.bleed(state: state, balance: balance))
                    .font(.caption)
                    .foregroundStyle(blocker == nil ? Theme.warning : .secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(DealCopy.wait(state: state, balance: balance))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .confirmationDialog(
            "Put \(state.company.name) up for sale at \(price.money)?",
            isPresented: $confirming,
            titleVisibility: .visible
        ) {
            Button("Hang the sign at \(price.money)", role: .destructive) {
                engine.send(.listForSale(askMultiple: clamped))
                Haptics.commit()
            }
            Button("Not yet", role: .cancel) {}
        } message: {
            Text(DealCopy.bleed(state: state, balance: balance))
        }
    }

    private func step(systemImage: String, by delta: Double, disabled: Bool) -> some View {
        Button {
            Haptics.tap()
            ask = GameState.dealClampedAsk(ask + delta, balance: engine.balance)
        } label: {
            Image(systemName: systemImage)
                .font(.headline.weight(.bold))
                .frame(width: 44, height: 36)
                .background(Theme.chipBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.pressable)
        .disabled(disabled)
        .accessibilityLabel(delta < 0 ? "Lower the ask" : "Raise the ask")
    }

    // MARK: While it stands

    @ViewBuilder
    private func listed(_ listing: DealListing, state: GameState, balance: BalanceConfig) -> some View {
        let deals = balance.deals
        let weeks = state.dealWeeksListed ?? 0
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack(alignment: .firstTextBaseline) {
                Text("Asking \(listing.askingPrice.money)")
                    .font(Theme.Typography.number(.headline))
                Spacer()
                Text("\(DealCopy.multiple(listing.askMultiple)) · week \(weeks + 1)")
                    .font(Theme.Typography.number(.caption))
                    .foregroundStyle(.secondary)
            }
            if let next = state.dealNextBid(balance: balance) {
                let days = max(0, next.day - state.day)
                Text(next.isLiquidator
                    ? "Next in \(days) day\(days == 1 ? "" : "s"): only the liquidator, \(next.amount.money) (\(DealCopy.multiple(next.multiple))). Nobody else is buying."
                    : "Next bid in \(days) day\(days == 1 ? "" : "s"): \(next.rivalName), \(next.amount.money) (\(DealCopy.multiple(next.multiple)))\(next.amount >= listing.askingPrice ? " — your price." : ".")")
                    .font(.subheadline)
                    .monospacedDigit()
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text(listing.bids == 0
                ? "No bids yet."
                : "\(listing.bids) bid\(listing.bids == 1 ? "" : "s") so far\(listing.lastBid.map { ", the last \($0.money)" } ?? "").")
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(.secondary)
            Text("Paying for it: morale target −\(Int(state.dealMoraleTargetDrag(balance: balance).rounded())) (to −\(Int(deals.moraleDragCap))) · poach odds ×\(DealCopy.factor(deals.poachFactor)) · launch hype ×\(DealCopy.factor(deals.launchHypeFactor))\(state.investors.hasBoard ? " · board +\(Int(deals.boardPressure)) a bid" : "")")
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(Theme.warning)
                .fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Button {
                    Haptics.tap()
                    engine.send(.takeDownSign)
                } label: {
                    Label("Take the sign down", systemImage: "signpost.right")
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(Theme.accent)
                Text("The bleed stops today; a bid already on the desk stands until it lapses.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .contain)
    }
}

/// The bids a sign hung today would bring, on today's numbers: the
/// formula, printed, so the ask is a decision about weeks of bleed.
struct DealBidSchedule: View {
    let bids: [DealBid]
    let ask: Int
    let day: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let first = bids.first, first.isLiquidator {
                Text("Nobody is buying at a real price: only the liquidator, \(first.amount.money) (\(DealCopy.multiple(first.multiple))) every few weeks.")
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(Theme.negativeCash)
                    .fixedSize(horizontal: false, vertical: true)
            } else if let last = bids.last {
                ForEach(Array(bids.prefix(5).enumerated()), id: \.offset) { _, bid in
                    HStack {
                        Text("Week \((bid.day - day) / 7)")
                            .foregroundStyle(.secondary)
                        Text(bid.rivalName)
                            .lineLimit(1)
                        Spacer()
                        Text("\(bid.amount.money) · \(DealCopy.multiple(bid.multiple))")
                            .foregroundStyle(bid.amount >= ask ? Theme.positiveCash : .primary)
                    }
                    .font(.caption)
                    .monospacedDigit()
                }
                Text(last.amount >= ask
                    ? "Your price in week \((last.day - day) / 7), if the numbers hold."
                    : "Not at your price inside a year on today's numbers.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

/// The projection behind `DealBidSchedule`: a sign hung today at `ask`,
/// read bid by bid until one reaches it (at most twelve).
enum DealProjection {
    static func schedule(state: GameState, balance: BalanceConfig, ask: Double) -> [DealBid] {
        var probe = state
        let price = Int((Double(state.companyValuation(balance: balance)) * ask).rounded())
        probe.rivals.listing = DealListing(askingPrice: price, askMultiple: ask, sinceDay: state.day)
        var bids: [DealBid] = []
        for number in 1...12 {
            guard let bid = probe.dealListingBid(number: number, balance: balance) else { break }
            bids.append(bid)
            if bid.amount >= price || bid.isLiquidator { break }
        }
        return bids
    }
}

// MARK: - The rival's profile

/// Beside the cash acquisition on a rival's profile: the paper deal with
/// its percentage on the button, and — while the sign stands — what this
/// studio would bid next.
struct DealProfileRows: View {
    let engine: GameEngine
    let rival: Rival

    @State private var confirming = false

    var body: some View {
        let state = engine.state
        let terms = state.dealStockTerms(for: rival, balance: engine.balance, content: engine.content)
        let percent = terms.equity.isFinite ? GameState.dealPercent(terms.equity) : "—"
        let kept = state.investors.equityRemaining - (terms.equity.isFinite ? terms.equity : 0)
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            if let listing = state.rivals.listing,
               let next = state.dealNextBid(balance: engine.balance), next.rivalID == rival.id {
                let days = max(0, next.day - state.day)
                Text(next.isLiquidator
                    ? "They are the liquidator for your sign: \(next.amount.money) in \(days) day\(days == 1 ? "" : "s")."
                    : "Your sign: they bid \(next.amount.money) (\(DealCopy.multiple(next.multiple))) in \(days) day\(days == 1 ? "" : "s"); you asked \(listing.askingPrice.money).")
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(Theme.warning)
                    .fixedSize(horizontal: false, vertical: true)
            }
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Button {
                    Haptics.tap()
                    confirming = true
                } label: {
                    Label("Buy with paper — \(percent) of the company", systemImage: "doc.text.fill")
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .monospacedDigit()
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(Theme.accent)
                .disabled(!terms.isOpen)

                Text(terms.blocker
                    ?? "No cash. \(terms.founderName) takes \(percent) and a board seat that expects a ship every quarter; the team and the shelf come over as with cash.\(state.investors.equityRemaining >= 100 ? " Still yours closes." : "")")
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .confirmationDialog(
            "Give \(terms.founderName) \(percent) of the company?",
            isPresented: $confirming,
            titleVisibility: .visible
        ) {
            Button("Buy \(rival.name) for \(percent)", role: .destructive) {
                engine.send(.acquireRivalForStock(rivalID: rival.id))
                Haptics.commit()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Priced at \(terms.price.money), as the cash deal is. You keep \(GameState.dealPercent(kept)); the seat can be bought back later at \(DealCopy.factor(engine.balance.investors.buybackPremium))× their slice.")
        }
    }
}

// MARK: - Selling up

/// The money sheet's *Sell up now*: present only in the red.
struct DealSellUpRow: View {
    let engine: GameEngine

    @State private var confirming = false

    var body: some View {
        if let offer = engine.state.dealSellUpOffer(balance: engine.balance) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Button {
                    Haptics.tap()
                    confirming = true
                } label: {
                    Label("Sell up now — \(offer.amount.money)", systemImage: "tag.fill")
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .monospacedDigit()
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(Theme.warning)
                Text(DealCopy.sellUpLine(offer, balance: engine.balance))
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, Theme.Spacing.xs)
            .confirmationDialog(
                "Sell up for \(offer.amount.money)?",
                isPresented: $confirming,
                titleVisibility: .visible
            ) {
                Button("Sell up for \(offer.amount.money)", role: .destructive) {
                    engine.send(.sellUp)
                }
                Button("Ride it", role: .cancel) {}
            } message: {
                Text("The run ends today as Sold up.")
            }
        }
    }
}

extension DecisionPrompt {
    /// The queue's sell-up sheet, from the first day in the red: *Sell up*
    /// against *Ride it*, the price today and what waiting costs, and what
    /// the receiver takes if the grace runs out.
    static func dealSellUpPrompt(state: GameState, balance: BalanceConfig) -> DecisionPrompt? {
        guard let offer = state.dealSellUpOffer(balance: balance) else { return nil }
        let rival = offer.rivalID.flatMap { state.rivals.rival(id: $0) }
        let start = state.day - state.company.daysInDebt + 1
        let left = offer.daysLeft
        var prompt = DecisionPrompt(
            id: "sellup-\(start)",
            systemImage: "tag.fill",
            tint: Theme.warning,
            title: "\(left) day\(left == 1 ? "" : "s") before the receiver",
            message: "\(offer.buyerName) will take \(state.company.name) today for \(offer.amount.money): "
                + "the name, the desks, a Sold up ending, and your wallet, your reputation and everyone "
                + "you know intact. Ride it and a launch, a contract or a term sheet might still save it; "
                + "if the grace runs out, the people you carry arrive "
                + "\(Int(balance.deals.bankruptcyRapportHaircut)) rapport cooler.",
            stats: [
                (String(localized: "Cash", comment: "Decision sheet stat: cash on hand"), state.company.cash.money),
                (String(localized: "Grace left", comment: "Decision sheet stat: days before the bankruptcy ending"), "\(left)d"),
                (String(localized: "Sell-up", comment: "Decision sheet stat: what selling up fetches today"), offer.amount.money),
            ],
            options: [
                Option(
                    label: "Sell up for \(offer.amount.money)",
                    detail: "Ends the run today as Sold up · \(offer.nextWeekAmount.money) in \(offer.dropsInDays)d",
                    role: .destructive,
                    action: .sellUp
                ),
            ],
            kicker: String(localized: "IN THE RED", comment: "Bitmap kicker: the company is out of cash and on the clock. Uppercase A-Z only"),
            portraitSeed: rival?.appearanceSeed
        )
        prompt.dealPostponeLabel = String(localized: "Ride it", comment: "The wait answer on the sell-up sheet: keep going and hope")
        prompt.dealPostponeDetail = "The clock runs on. The price falls to \(offer.nextWeekAmount.money) in \(offer.dropsInDays)d; the receiver calls in \(left + 1)."
        return prompt
    }

    /// A listing's bid on the buyout sheet: what was asked and what the
    /// next bid would be, so declining is a number too. Empty for an
    /// approach the sign did not bring.
    static func dealListingNote(_ offer: BuyoutOffer, state: GameState, balance: BalanceConfig) -> String {
        guard let listing = state.rivals.listing, listing.lastBid == offer.amount else { return "" }
        var note = " You asked \(listing.askingPrice.money)."
        if offer.amount < listing.askingPrice, let next = state.dealNextBid(balance: balance) {
            note += " Decline and the next bid, in \(max(0, next.day - state.day)) days, is about \(next.amount.money)."
        }
        return note
    }
}

// MARK: - The post-mortem

/// How the grace period ended, for `PostMortem`: a sell-up leads with
/// its day; the receiver follows the first finding with its cost.
enum DealPostMortem {
    static func line(for state: GameState, balance: BalanceConfig) -> PostMortem.Line? {
        guard let over = state.gameOver else { return nil }
        let grace = balance.bankruptcyGraceDays
        switch over.kind {
        case .soldUp where state.company.daysInDebt > 0:
            return PostMortem.Line(
                id: "sold-up-in-the-red",
                systemImage: "tag.fill",
                text: "Sold on day \(state.company.daysInDebt) of \(grace) in the red, before the receiver. Everyone you knew carries at the rapport they had."
            )
        case .bankruptcy:
            return PostMortem.Line(
                id: "rode-it-out",
                systemImage: "hourglass.bottomhalf.filled",
                text: "Rode all \(grace) days of grace to the receiver. The people you carry into the next company arrive \(Int(balance.deals.bankruptcyRapportHaircut)) rapport cooler."
            )
        default:
            return nil
        }
    }
}

// MARK: - Copy

enum DealCopy {
    /// "1.3×".
    static func multiple(_ value: Double) -> String {
        String(format: "%.1f×", value)
    }

    /// "1.5", "0.9", "2".
    static func factor(_ value: Double) -> String {
        value == value.rounded() ? "\(Int(value))" : String(format: "%.1f", value)
    }

    /// What the sign costs while it stands.
    static func bleed(state: GameState, balance: BalanceConfig) -> String {
        let deals = balance.deals
        var line = "While it stands: morale target −\(factor(deals.moralePerWeek)) a week (to −\(Int(deals.moraleDragCap))) · "
            + "poach odds ×\(factor(deals.poachFactor)) · launch hype ×\(factor(deals.launchHypeFactor))"
        if state.investors.hasBoard {
            line += " · board pressure +\(Int(deals.boardPressure)) now and with every bid"
        }
        return line + " · the paper leads with it."
    }

    /// The other answer: wait for somebody to come on their own.
    static func wait(state: GameState, balance: BalanceConfig) -> String {
        let exits = balance.investors
        let config = balance.rivals
        let valuation = Double(state.companyValuation(balance: balance))
        let weak = state.company.daysInDebt > 0
            || state.company.cash < config.weakCashThreshold
            || state.company.reputation < config.weakRepThreshold
        let courting = weak || state.company.reputation < exits.strategicMinReputation
            ? []
            : state.rivals.rivals.filter {
                valuation >= Double($0.valuation(balance: balance)) * exits.strategicDominanceFactor
            }
        let premium = "\(factor(exits.strategicPremiumMin))–\(factor(exits.strategicPremiumMax))×"
        if courting.isEmpty {
            return "Or wait: a rival you are worth \(factor(exits.strategicDominanceFactor))× comes on its own at \(premium), "
                + "once your reputation is \(Int(exits.strategicMinReputation)). None qualifies today."
        }
        let names = courting.prefix(2).map(\.name).joined(separator: " and ")
        return "Or wait: \(names) can come on \(courting.count == 1 ? "its" : "their") own at \(premium) — at their number, on their clock."
    }

    /// The sell-up's price and what waiting does to it.
    static func sellUpLine(_ offer: DealSellUpOffer, balance: BalanceConfig) -> String {
        "\(offer.buyerName) takes the name and the desks; the run ends as Sold up. \(offer.daysLeft) day\(offer.daysLeft == 1 ? "" : "s") of grace left; "
            + "the price falls to \(offer.nextWeekAmount.money) in \(offer.dropsInDays)d."
    }
}

// MARK: - Debug

/// `-autoDeal <word>` once the Rivals segment is up, debug builds only:
/// `list` hangs the sign at 1.3× (with `-autoSpeed x4` the first bid
/// lands 28 game days later), a number hangs it at that ask, `show` only
/// lifts the unlisted card to the top of the segment for a camera,
/// `paper` buys the strongest studio the company can buy with paper, and
/// `sellup` sells up (in the red: `-autoFixture release-bankruptcy`).
enum DealDebug {
    @MainActor private static var started = false

    /// Whether the unlisted card leads the Rivals segment (`show`).
    static var cardLeads: Bool {
        DebugLaunch.dealAutoAsk == "show"
    }

    @MainActor
    static func startIfAsked(engine: GameEngine) async {
        #if DEBUG
        guard !started, let word = DebugLaunch.dealAutoAsk, word != "show" else { return }
        started = true
        try? await Task.sleep(for: .seconds(1))
        let events: [GameEvent]
        switch word {
        case "paper":
            let state = engine.state
            let open = state.rivals.rivals
                .filter { state.dealStockTerms(for: $0, balance: engine.balance, content: engine.content).isOpen }
                .max { $0.strength < $1.strength }
            events = open.map { engine.send(.acquireRivalForStock(rivalID: $0.id)) } ?? []
        case "sellup":
            events = engine.send(.sellUp)
        default:
            guard engine.state.rivals.listing == nil else { return }
            events = engine.send(.listForSale(askMultiple: Double(word) ?? 1.3))
        }
        print("[K4] -autoDeal \(word): \(events.isEmpty ? "refused" : "sent (\(events.count) events)")")
        #endif
    }
}
