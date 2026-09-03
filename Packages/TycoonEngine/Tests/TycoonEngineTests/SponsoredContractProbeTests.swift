import Foundation
import Testing
import TycoonContent
@testable import TycoonEngine

// "Build It For Them", measured: three founders who play the same game and
// differ only in what they do when a rival's cheque lands on the sheet.

/// A studio that builds and sells its own apps, hires up to three, grinds
/// a plain contract when broke — and has one opinion about a rival's
/// white-label offer.
struct SponsorBot: BotPolicy {
    enum Policy: String {
        /// Never touches a sponsored offer.
        case decline
        /// Takes every sponsored offer and puts the whole team on it until
        /// it is delivered; the product in development idles meanwhile.
        case take
        /// Takes every sponsored offer and puts the founder alone on it —
        /// the team stays on the product. Whatever the founder delivers is
        /// what the rival gets; often that is a poor grade, half pay, and
        /// a weak product on their shelf.
        case sandbag
    }

    let policy: Policy
    var name: String { "sponsor-\(policy.rawValue)" }

    let productCashFloor = 15_000
    let hireCashFloor = 25_000
    let maxHeadcount = 3

    func actions(
        for state: GameState,
        balance: BalanceConfig,
        content: ContentCatalog
    ) -> [GameAction] {
        var actions = BotHelp.weekendPlan(state)

        if state.headcount < maxHeadcount,
           state.company.cash > hireCashFloor,
           let candidate = BotHelp.bestValueCandidate(state) {
            actions.append(.hire(candidateID: candidate.id))
        }

        // The rival's cheque. Only when nothing else is on the books, the
        // way a founder would.
        var sponsoredID = state.activeContracts.first { $0.isSponsored }?.id
        if policy != .decline,
           sponsoredID == nil,
           state.activeContracts.isEmpty,
           let offer = state.contractOffers.first(where: { $0.isSponsored }),
           offer.penalty <= state.company.cash {
            actions.append(.acceptContract(offerID: offer.id))
            sponsoredID = offer.id
        }

        var crew = state.employees
        if let sponsoredID {
            switch policy {
            case .take:
                return actions + BotHelp.assignAll(state, to: .contract(sponsoredID))
            case .sandbag:
                if let founder = crew.first(where: \.isFounder) {
                    if founder.assignment != .contract(sponsoredID) {
                        actions.append(.assign(employeeID: founder.id, to: .contract(sponsoredID)))
                    }
                    crew.removeAll { $0.id == founder.id }
                }
            case .decline:
                break
            }
        }

        // The product loop, for whoever is left.
        if let product = state.productInDevelopment {
            if BotHelp.isComplete(product, content) {
                actions.append(.ship(productID: product.id))
            } else {
                for employee in crew where employee.assignment != .product(product.id) {
                    actions.append(.assign(employeeID: employee.id, to: .product(product.id)))
                }
            }
        } else if state.company.cash > productCashFloor {
            actions.append(.startProduct(
                typeID: "mobile_app",
                topicID: BotHelp.topic(forProductNumber: state.products.count),
                name: "Own \(state.products.count + 1)",
                focus: .balanced
            ))
        } else {
            // Broke: a plain contract keeps the lights on.
            var plainID = state.activeContracts.first { !$0.isSponsored }?.id
            if plainID == nil,
               let offer = state.contractOffers
                   .filter({ !$0.isSponsored && $0.penalty <= state.company.cash })
                   .max(by: { $0.payout < $1.payout }) {
                actions.append(.acceptContract(offerID: offer.id))
                plainID = offer.id
            }
            if let plainID {
                for employee in crew where employee.assignment != .contract(plainID) {
                    actions.append(.assign(employeeID: employee.id, to: .contract(plainID)))
                }
            }
        }
        return actions
    }
}

/// The pair the PM asked for, plus the sandbagger: ten seeds, two years,
/// rivals live. What the money buys, and what it arms.
@Suite("Sponsored contracts, measured")
struct SponsoredContractProbeTests {
    static let days = 730
    static let seeds = BalanceTargetsTests.seeds

    struct Probe {
        var seed: UInt64
        var finalCash: Int
        var bankrupt: Bool
        var productsShipped: Int
        var sponsoredOffered: Int
        var sponsoredDelivered: Int
        var sponsoredPoor: Int
        var sponsoredPay: Int
        /// Rival products on the shelves at the end whose topic the player
        /// has shipped into.
        var rivalProductsInOwnTopics: Int
        /// Mean of the player's share across its live topics, sampled weekly.
        var meanShareInOwnTopics: Double
        /// Mean standing across the player's shipped topics at the end.
        var meanStandingInOwnTopics: Double
    }

    static func run(_ policy: SponsorBot.Policy, seed: UInt64) throws -> Probe {
        var balance = try BalanceConfig.loadBundled()
        balance.rivals.rivalCount = 4
        let content = TestContent.bundled
        let bot = SponsorBot(policy: policy)
        var state = GameState.newGame(companyName: bot.name, seed: seed, balance: balance)
        var probe = Probe(
            seed: seed, finalCash: 0, bankrupt: false, productsShipped: 0,
            sponsoredOffered: 0, sponsoredDelivered: 0, sponsoredPoor: 0, sponsoredPay: 0,
            rivalProductsInOwnTopics: 0, meanShareInOwnTopics: 0, meanStandingInOwnTopics: 0
        )
        var shareSamples: [Double] = []
        var sponsoredIDs: Set<UUID> = []

        func tally(_ events: [GameEvent], _ state: GameState) {
            for event in events {
                switch event {
                case .contractOffersRefreshed:
                    probe.sponsoredOffered += state.contractOffers.filter(\.isSponsored).count
                case let .contractDelivered(id, _, payout, _) where sponsoredIDs.contains(id):
                    probe.sponsoredPay += payout
                case let .sponsoredContractDelivered(_, _, quality, _):
                    probe.sponsoredDelivered += 1
                    // 60 projected × 0.9 is the poor line on their shelf.
                    if Double(quality) < 60 * balance.sponsoredContracts.productQualityFactor {
                        probe.sponsoredPoor += 1
                    }
                case .shipped:
                    probe.productsShipped += 1
                default:
                    break
                }
            }
        }

        for _ in 0..<Self.days {
            tally(Reducer.tick(&state, balance: balance, content: content), state)
            if state.day % GameState.daysPerWeek == 0 {
                let live = StandingSystem.liveTopicIDs(state)
                if !live.isEmpty {
                    shareSamples.append(
                        live.reduce(0) { $0 + state.rivals.share(for: $1) } / Double(live.count)
                    )
                }
            }
            if state.gameOver != nil { break }
            for action in bot.actions(for: state, balance: balance, content: content) {
                tally(Reducer.apply(action, to: &state, balance: balance, content: content), state)
                if case .acceptContract(let id) = action,
                   state.activeContract(id: id)?.isSponsored == true {
                    sponsoredIDs.insert(id)
                }
            }
        }

        let ownTopics = Set(state.products.map(\.topicID))
        probe.finalCash = state.company.cash
        probe.bankrupt = state.gameOver?.kind == .bankruptcy
        probe.rivalProductsInOwnTopics = state.rivals.rivals.reduce(0) { total, rival in
            total + rival.products.filter { ownTopics.contains($0.topicID) }.count
        }
        probe.meanShareInOwnTopics = shareSamples.isEmpty
            ? 1 : shareSamples.reduce(0, +) / Double(shareSamples.count)
        probe.meanStandingInOwnTopics = ownTopics.isEmpty
            ? 0 : ownTopics.reduce(0) { $0 + state.market.standing(for: $1) } / Double(ownTopics.count)
        return probe
    }

    static func runAll(_ policy: SponsorBot.Policy) throws -> [Probe] {
        try seeds.map { try run(policy, seed: $0) }
    }

    static func median(_ values: [Int]) -> Int {
        let sorted = values.sorted()
        return sorted.isEmpty ? 0 : sorted[sorted.count / 2]
    }

    static func mean(_ values: [Double]) -> Double {
        values.isEmpty ? 0 : values.reduce(0, +) / Double(values.count)
    }

    static func summarize(_ label: String, _ probes: [Probe]) {
        print("""
        \(label.padding(toLength: 16, withPad: " ", startingAt: 0)) \
        cash med \(median(probes.map(\.finalCash))) mean \(Int(mean(probes.map { Double($0.finalCash) }))) \
        bankrupt \(probes.filter(\.bankrupt).count)/\(probes.count) \
        shipped \(median(probes.map(\.productsShipped))) \
        offered \(probes.reduce(0) { $0 + $1.sponsoredOffered }) \
        delivered \(probes.reduce(0) { $0 + $1.sponsoredDelivered }) \
        poor \(probes.reduce(0) { $0 + $1.sponsoredPoor }) \
        pay \(probes.reduce(0) { $0 + $1.sponsoredPay }) \
        rivalsInOwn \(probes.reduce(0) { $0 + $1.rivalProductsInOwnTopics }) \
        share \(String(format: "%.3f", mean(probes.map(\.meanShareInOwnTopics)))) \
        standing \(String(format: "%.1f", mean(probes.map(\.meanStandingInOwnTopics))))
        """)
        for probe in probes {
            print("""
              seed \(String(probe.seed).padding(toLength: 7, withPad: " ", startingAt: 0)) \
            cash \(String(probe.finalCash).padding(toLength: 8, withPad: " ", startingAt: 0)) \
            shipped \(probe.productsShipped) \
            offered \(probe.sponsoredOffered) delivered \(probe.sponsoredDelivered) poor \(probe.sponsoredPoor) \
            pay \(probe.sponsoredPay) rivalsInOwn \(probe.rivalProductsInOwnTopics) \
            share \(String(format: "%.3f", probe.meanShareInOwnTopics)) \
            standing \(String(format: "%.1f", probe.meanStandingInOwnTopics))\(probe.bankrupt ? " BANKRUPT" : "")
            """)
        }
    }

    /// The table behind every claim in the lane's commit. Printed, then
    /// asserted below.
    @Test func sponsorTable() throws {
        print("=== Build It For Them (10 seeds × 730 days, Normal, rivals live) ===")
        Self.summarize("decline", try Self.runAll(.decline))
        Self.summarize("take", try Self.runAll(.take))
        Self.summarize("sandbag", try Self.runAll(.sandbag))
        #expect(Self.seeds.count == 10)
    }

    /// The offer is on the sheet whether or not you take it — about once
    /// a month from week eight — and declining it costs nothing.
    @Test func theSheetCarriesTheOfferAndDecliningIsFree() throws {
        let decline = try Self.runAll(.decline)
        for probe in decline {
            #expect(probe.sponsoredOffered >= 10, "seed \(probe.seed) saw only \(probe.sponsoredOffered) sponsored offers")
            #expect(probe.sponsoredDelivered == 0)
            #expect(probe.sponsoredPay == 0)
            #expect(!probe.bankrupt)
        }
    }

    /// The PM's pair: the taker ends at least 15% richer *and* faces at
    /// least two more rival products in its own categories, with a
    /// measurably lower share. Measured: +57% cash (median $46.0k against
    /// $28.6k), +5.1 rival products per run in its own topics (206
    /// against 155 over ten seeds), share 0.605 against 0.814, standing
    /// 7.7 against 19.3. The money is real and so is what it arms.
    @Test func takingTheMoneyPaysAndArmsARival() throws {
        let decline = try Self.runAll(.decline)
        let take = try Self.runAll(.take)

        let declineCash = Self.mean(decline.map { Double($0.finalCash) })
        let takeCash = Self.mean(take.map { Double($0.finalCash) })
        #expect(
            takeCash >= declineCash * 1.15,
            Comment(rawValue: "taker mean cash \(Int(takeCash)) against decliner \(Int(declineCash))")
        )
        for probe in take {
            #expect(probe.sponsoredDelivered >= 10, "seed \(probe.seed) delivered only \(probe.sponsoredDelivered)")
            #expect(!probe.bankrupt)
        }

        let declineArmed = decline.reduce(0) { $0 + $1.rivalProductsInOwnTopics }
        let takeArmed = take.reduce(0) { $0 + $1.rivalProductsInOwnTopics }
        #expect(
            takeArmed >= declineArmed + 2 * Self.seeds.count,
            Comment(rawValue: "rival products in own topics: taker \(takeArmed), decliner \(declineArmed)")
        )

        let declineShare = Self.mean(decline.map(\.meanShareInOwnTopics))
        let takeShare = Self.mean(take.map(\.meanShareInOwnTopics))
        #expect(
            takeShare <= declineShare - 0.05,
            Comment(rawValue: "share in own topics: taker \(takeShare), decliner \(declineShare)")
        )
        let declineStanding = Self.mean(decline.map(\.meanStandingInOwnTopics))
        let takeStanding = Self.mean(take.map(\.meanStandingInOwnTopics))
        #expect(takeStanding < declineStanding)
    }

    /// The sandbag, measured so the finding is on record rather than
    /// argued: the founder alone on every rival job, the team never
    /// leaving the product, ends *richer than the all-hands taker*
    /// (median $70.9k against $46.0k) while arming the field less (+3.0
    /// rival products per run against +5.1) — and it is not the 50%-pay
    /// sandbag the PM feared: only 18% of its deliveries grade poor, the
    /// founder's skill grows into the job. It still pays the cost — share
    /// 0.677 and standing 12.4 against the decliner's 0.814 and 19.3 —
    /// so the decision stands; what this says is that stalling the
    /// product for the cheque is the wrong way to take it, which a
    /// player will work out in a month. If playtesters always play it
    /// this way, the PM's rival-specific term (a poor delivery shrinks
    /// the sheet for eight weeks) is the lever; it is not in this lane.
    @Test func theFounderAloneOnTheJobIsTheDominantWayToTakeIt() throws {
        let decline = try Self.runAll(.decline)
        let take = try Self.runAll(.take)
        let sandbag = try Self.runAll(.sandbag)

        let takeCash = Self.mean(take.map { Double($0.finalCash) })
        let sandbagCash = Self.mean(sandbag.map { Double($0.finalCash) })
        #expect(
            sandbagCash > takeCash,
            Comment(rawValue: "sandbag mean cash \(Int(sandbagCash)) against taker \(Int(takeCash))")
        )
        for probe in sandbag {
            #expect(probe.sponsoredDelivered >= 5, "seed \(probe.seed) delivered only \(probe.sponsoredDelivered)")
            #expect(!probe.bankrupt)
        }
        // Not the half-pay sandbag: most of its deliveries grade okay or
        // better, so the rival gets a real product and the founder real pay.
        let delivered = sandbag.reduce(0) { $0 + $1.sponsoredDelivered }
        let poor = sandbag.reduce(0) { $0 + $1.sponsoredPoor }
        #expect(poor * 2 < delivered, "\(poor) of \(delivered) sandbag deliveries graded poor")
        // And it still pays the category price.
        let declineShare = Self.mean(decline.map(\.meanShareInOwnTopics))
        let sandbagShare = Self.mean(sandbag.map(\.meanShareInOwnTopics))
        #expect(sandbagShare <= declineShare - 0.05)
        let declineArmed = decline.reduce(0) { $0 + $1.rivalProductsInOwnTopics }
        let sandbagArmed = sandbag.reduce(0) { $0 + $1.rivalProductsInOwnTopics }
        #expect(sandbagArmed > declineArmed)
    }
}
