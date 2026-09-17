import Foundation
import TycoonContent

/// Daily contract system, running after `EmployeeSystem` has poured the
/// day's points into the active jobs: replaces the weekly offer sheet on
/// its cadence, pays out jobs whose point pools both cleared, and penalizes
/// jobs that blew past their deadline. Also hosts the acceptContract action
/// handler used by `Reducer.apply`.
enum ContractSystem {
    @Sendable
    static func run(
        _ state: inout GameState,
        _ balance: BalanceConfig,
        _ content: ContentCatalog
    ) -> [GameEvent] {
        var events: [GameEvent] = []

        if state.day % balance.contractOfferRefreshDays == 0 {
            refreshOffers(&state, balance, content)
            events.append(.contractOffersRefreshed(day: state.day))
        }

        events.append(contentsOf: settleContracts(&state, balance, content))
        return events
    }

    // MARK: - Weekly offer sheet

    /// Replaces the sheet with `contractOfferCount` fresh rolls (plus
    /// `legalExtraOffers` with a Legal department). Per offer, the RNG
    /// draws in a fixed order: id, client name, total points, code split,
    /// urgency premium, deadline slack, required skill. The point-roll
    /// range scales with the studio's age:
    /// `1 + contractYearScale * (year - 1)`; the required-skill roll rises
    /// `skillYearBump` per year, capped at `skillCap`. Once the sheet is
    /// rolled, `sponsorOneOffer` may hand one offer to a rival — from
    /// `worldRNG`, after every `rng` draw above.
    private static func refreshOffers(
        _ state: inout GameState,
        _ balance: BalanceConfig,
        _ content: ContentCatalog
    ) {
        let scale = 1 + balance.contractYearScale * Double(state.year - 1)
        // Like `legalExtraOffers`, the district bonus changes how many
        // per-offer draw groups run — a player-caused divergence of the
        // main stream (relocating), same class as hiring a lawyer.
        let offerCount = balance.contractOfferCount
            + (state.hasDepartment(.legal) ? balance.company.legalExtraOffers : 0)
            + balance.city.district(state.city.district).extraContractOffers

        var offers: [ContractOffer] = []
        offers.reserveCapacity(offerCount)
        for _ in 0..<offerCount {
            let id = UUID(from: &state.rng)
            let clientName = pick(content.names.clientCompanies, &state.rng)
            let totalPts = scale * (balance.contractPtsMin
                + state.rng.nextUniform() * (balance.contractPtsMax - balance.contractPtsMin))
            let codeSplit = balance.contractCodeSplitMin
                + state.rng.nextUniform() * (balance.contractCodeSplitMax - balance.contractCodeSplitMin)
            let premium = balance.contractUrgencyPremiumMin
                + state.rng.nextUniform() * (balance.contractUrgencyPremiumMax - balance.contractUrgencyPremiumMin)
            let slack = balance.contractDeadlineSlackMin
                + state.rng.nextUniform() * (balance.contractDeadlineSlackMax - balance.contractDeadlineSlackMin)
            // An empty roll range draws nothing, so a quality-neutral
            // balance (skillMin == skillMax == 0) leaves the RNG sequence
            // exactly as it was before contract quality existed.
            let quality = balance.contractQuality
            let skillRoll = quality.skillMax > quality.skillMin
                ? quality.skillMin + state.rng.nextUniform() * (quality.skillMax - quality.skillMin)
                : quality.skillMin
            let requiredSkill = min(quality.skillCap,
                skillRoll + quality.skillYearBump * Double(state.year - 1))

            let payout = Int((totalPts * balance.contractPayoutPerPoint * premium).rounded())
            offers.append(ContractOffer(
                id: id,
                clientName: clientName,
                requiredCodePts: totalPts * codeSplit,
                requiredDesignPts: totalPts * (1 - codeSplit),
                payout: payout,
                penalty: Int((balance.contractPenaltyFraction * Double(payout)).rounded()),
                deadlineDays: Int((totalPts / balance.contractDeadlinePtsPerDay * slack).rounded(.up)),
                expiresDay: state.day + balance.contractOfferRefreshDays,
                requiredSkill: requiredSkill
            ))
        }
        sponsorOneOffer(&offers, &state, balance)
        warmKnownClientOffers(&offers, state, balance)
        state.contractOffers = offers
    }

    private static func pick(_ pool: [String], _ rng: inout SeededRNG) -> String {
        guard !pool.isEmpty else { return "" }
        return pool[rng.nextInt(in: 0...(pool.count - 1))]
    }

    // MARK: - The sponsored offer

    /// "Build It For Them": once the sheet is rolled, a rival may sponsor
    /// one offer on it. The offer keeps its id and its point pools and
    /// becomes a white-label job for that rival — its name as the client,
    /// a topic it ships into on delivery, `payoutFactor` times the pay,
    /// the skill a studio of its strength expects, and a longer deadline.
    ///
    /// Every draw here comes from `worldRNG`, never `rng`, so the
    /// per-offer draw groups above stay byte-identical whether or not a
    /// rival calls — the trick `RivalSystem` uses. And nothing draws
    /// unless a rival exists and the day is past `earliestDay`, so a
    /// world with no rivals (the pacing suite) never touches the stream.
    /// World draw order on a roll: the sponsor chance; then, on a hit,
    /// the rival pick, the slot pick, the topic-choice uniform and — when
    /// the sponsor's own focus is chosen — the focus-topic pick.
    ///
    /// The topic is the sharp part: with `playerTopicChance`, when the
    /// player holds standing anywhere, the sponsor asks for the player's
    /// best category — the offer names a topic you hold. Otherwise it is
    /// one of the rival's own focus topics.
    private static func sponsorOneOffer(
        _ offers: inout [ContractOffer],
        _ state: inout GameState,
        _ balance: BalanceConfig
    ) {
        let config = balance.sponsoredContracts
        guard !state.rivals.rivals.isEmpty,
              !offers.isEmpty,
              state.day >= config.earliestDay,
              config.sponsorChance > 0
        else { return }
        guard state.worldRNG.nextUniform() < config.sponsorChance else { return }

        let rival = state.rivals.rivals[
            state.worldRNG.nextInt(in: 0...(state.rivals.rivals.count - 1))
        ]
        let slot = state.worldRNG.nextInt(in: 0...(offers.count - 1))
        let topicRoll = state.worldRNG.nextUniform()

        let topicID: String?
        if let held = bestStandingTopicID(state), topicRoll < config.playerTopicChance {
            topicID = held
        } else if !rival.focusTopicIDs.isEmpty {
            topicID = rival.focusTopicIDs[
                state.worldRNG.nextInt(in: 0...(rival.focusTopicIDs.count - 1))
            ]
        } else {
            topicID = bestStandingTopicID(state)
        }
        // A rival with no focus and a player with no standing: nothing to
        // build. The draws above still happened; the sheet stays plain.
        guard let topicID else { return }

        var offer = offers[slot]
        offer.clientName = rival.name
        offer.topicID = topicID
        offer.sponsorRivalID = rival.id
        offer.payout = Int((Double(offer.payout) * config.payoutFactor).rounded())
        offer.penalty = Int((balance.contractPenaltyFraction * Double(offer.payout)).rounded())
        offer.requiredSkill = min(
            balance.contractQuality.skillCap,
            config.requiredSkill(forStrength: rival.strength)
        )
        offer.deadlineDays = Int((Double(offer.deadlineDays) * config.deadlineFactor).rounded(.up))
        offers[slot] = offer
    }

    // MARK: - The client book

    /// After the sheet's documented draws and the sponsor's rewrite, a
    /// trusted client may claim a plain offer: their name on it, a payout
    /// bonus scaled by their trust, and a longer deadline — the same
    /// rewrite-after-the-roll trick as `sponsorOneOffer`, except nothing
    /// here draws from any stream at all, so the sheet's RNG walk is
    /// byte-identical whether or not anybody is trusted. Inert until the
    /// player has opened the client book, which no bot ever does.
    private static func warmKnownClientOffers(
        _ offers: inout [ContractOffer],
        _ state: GameState,
        _ balance: BalanceConfig
    ) {
        let config = balance.clientBook
        guard state.clientBook.noticed, !offers.isEmpty else { return }
        let warm = state.clientBook.warmClients(
            day: state.day, trustedThreshold: config.trustedThreshold
        )
        guard !warm.isEmpty else { return }

        var slots = offers.indices.filter { !offers[$0].isSponsored }
        for client in warm.prefix(max(0, config.warmedOffersPerSheet)) {
            guard let slot = slots.first else { return }
            slots.removeFirst()
            var offer = offers[slot]
            offer.clientName = client.name
            let bonus = config.warmPayoutBonus(forTrust: client.trust)
            offer.payout = Int((Double(offer.payout) * (1 + bonus)).rounded())
            offer.penalty = Int((balance.contractPenaltyFraction * Double(offer.payout)).rounded())
            offer.deadlineDays = Int((Double(offer.deadlineDays) * config.warmDeadlineFactor).rounded(.up))
            offers[slot] = offer
        }
    }

    /// Writes a settled job onto its client's page: delivered at the
    /// grade the settle just computed, or failed on the deadline. A
    /// sponsored job's "client" is a rival with a payroll, not a client —
    /// the book keeps out of it. Only ever called once the book has been
    /// opened, so a run that never looks writes nothing.
    private static func recordSettlement(
        clientName: String,
        delivered: Bool,
        quality: Int,
        state: inout GameState,
        balance: BalanceConfig
    ) {
        let config = balance.clientBook
        let grades = balance.contractQuality
        state.clientBook.record(clientName: clientName, baseTrust: config.trustBase) { client in
            client.lastSettledDay = state.day
            guard delivered else {
                client.jobsFailed += 1
                client.trust -= config.trustFailLoss
                client.coldUntilDay = state.day + max(0, config.coldDays)
                return
            }
            client.jobsDelivered += 1
            if quality >= grades.greatThreshold {
                client.trust += config.trustGreatGain
            } else if quality >= grades.okayThreshold {
                client.trust += config.trustOkayGain
            } else {
                client.trust -= config.trustPoorLoss
                client.coldUntilDay = state.day + max(0, config.coldDays)
            }
        }
    }

    /// The topic the player holds highest, `nil` when they hold nothing.
    /// Ties break on topic id so the choice replays.
    private static func bestStandingTopicID(_ state: GameState) -> String? {
        state.market.standing
            .filter { $0.value > 0 }
            .max { lhs, rhs in
                if lhs.value != rhs.value { return lhs.value < rhs.value }
                return lhs.key > rhs.key
            }?
            .key
    }

    // MARK: - Daily settlement

    /// Completion is checked before the deadline, so a job can still be
    /// delivered on its deadline day. A Legal department lifts every payout
    /// by `legalPayoutBonus` and scales every missed-deadline penalty by
    /// `legalPenaltyFactor`. Settled jobs leave `activeContracts`; the
    /// daily employee sweep then returns their workers to idle.
    ///
    /// A delivered *sponsored* job is also handed to its rival — see
    /// `shipSponsoredDelivery` — after the pay and the grade have landed
    /// exactly as they would for any client.
    private static func settleContracts(
        _ state: inout GameState,
        _ balance: BalanceConfig,
        _ content: ContentCatalog
    ) -> [GameEvent] {
        var events: [GameEvent] = []
        var remaining: [ContractJob] = []
        remaining.reserveCapacity(state.activeContracts.count)
        let hasLegal = state.hasDepartment(.legal)
        // Legal reads the contract; the founder negotiated it. Both land
        // on what the client actually pays.
        let payoutBonus = (hasLegal ? balance.company.legalPayoutBonus : 1)
            * state.founderDealFactor(balance)
        let penaltyFactor = hasLegal ? balance.company.legalPenaltyFactor : 1

        for job in state.activeContracts {
            if job.progressCode >= job.requiredCodePts, job.progressDesign >= job.requiredDesignPts {
                // Grade the delivery: the crew's average skill vs. what the
                // client expected. A weak crew gets docked pay; a very weak
                // one also costs reputation ("this is not good").
                let quality = job.projectedQuality
                let config = balance.contractQuality
                let paidFraction: Double
                var reputationDelta = balance.contractReputationReward
                if quality >= config.greatThreshold {
                    paidFraction = 1
                } else if quality >= config.okayThreshold {
                    paidFraction = config.okayPayoutFraction
                    reputationDelta = 0
                } else {
                    paidFraction = config.poorPayoutFraction
                    reputationDelta = -config.poorReputationPenalty
                }
                let paid = Int((Double(job.payout) * paidFraction * payoutBonus).rounded())

                state.company.cash += paid
                state.ledger.post(LedgerEntry(
                    day: state.day, amount: paid, category: .contracts, label: job.clientName
                ))
                state.company.reputation = min(100, max(0,
                    state.company.reputation + reputationDelta
                ))
                events.append(.contractDelivered(
                    contractID: job.id, quality: quality, payout: paid, day: state.day
                ))
                if state.clientBook.noticed, !job.isSponsored {
                    recordSettlement(
                        clientName: job.clientName, delivered: true, quality: quality,
                        state: &state, balance: balance
                    )
                }
                if job.isSponsored {
                    events.append(contentsOf: shipSponsoredDelivery(
                        job, quality: quality, &state, balance, content
                    ))
                }
            } else if state.day > job.deadlineDay {
                let penalty = Int((Double(job.penalty) * penaltyFactor).rounded())
                state.company.cash -= penalty
                state.ledger.post(LedgerEntry(
                    day: state.day, amount: -penalty, category: .contracts, label: job.clientName
                ))
                state.company.reputation = min(100, max(0,
                    state.company.reputation - balance.contractReputationPenalty
                ))
                events.append(.contractFailed(contractID: job.id, penalty: penalty, day: state.day))
                if state.clientBook.noticed, !job.isSponsored {
                    recordSettlement(
                        clientName: job.clientName, delivered: false, quality: 0,
                        state: &state, balance: balance
                    )
                }
            } else {
                remaining.append(job)
            }
        }

        state.activeContracts = remaining
        return events
    }

    /// What a sponsored delivery does beyond the pay: the rival ships
    /// what you built. Its product lands on the sponsor's shelf at
    /// `productQuality(forProjected:)` — a little under the grade you
    /// delivered, clamped like any rival launch — the topic joins the
    /// sponsor's focus, it gains `rivalStrengthGain`, and the player's
    /// standing in the topic takes `standingLoss`. A poor delivery has
    /// already cost half the pay and a little reputation; what it hands
    /// the rival is correspondingly weak. Sandbagging is a choice, with
    /// a price on both sides.
    ///
    /// Draws one product id from `worldRNG` — only ever on a delivery to
    /// a rival, so a world without rivals never reaches this. A sponsor
    /// that folded or was bought before delivery has nobody to ship it:
    /// the job pays like any other and nothing else happens.
    private static func shipSponsoredDelivery(
        _ job: ContractJob,
        quality projectedQuality: Int,
        _ state: inout GameState,
        _ balance: BalanceConfig,
        _ content: ContentCatalog
    ) -> [GameEvent] {
        guard let rivalID = job.sponsorRivalID,
              let topicID = job.topicID,
              let index = state.rivals.rivals.firstIndex(where: { $0.id == rivalID })
        else { return [] }
        let config = balance.sponsoredContracts
        let rival = state.rivals.rivals[index]
        let quality = config.productQuality(forProjected: projectedQuality)

        // The same shape `RivalSystem.launchProduct` gives its own
        // launches: the readable units stand-in, the catalog's first
        // type. The name is the sponsor's brand on your category — no
        // draw, so the only word the world stream spends is the id.
        let product = RivalProduct(
            id: UUID(from: &state.worldRNG),
            name: sponsoredProductName(rival: rival, topicID: topicID, content),
            topicID: topicID,
            typeID: content.productTypes.first?.id ?? "mobile_app",
            quality: quality,
            launchDay: state.day,
            weeklyUnits: Int((rival.strength * 40 * (0.5 + quality / 200)).rounded())
        )
        RivalSystem.appendProduct(product, to: index, in: &state)
        state.rivals.rivals[index].lastShippedDay = state.day
        state.rivals.rivals[index].strength = min(100, max(1, rival.strength + config.rivalStrengthGain))
        if !rival.focusTopicIDs.contains(topicID) {
            state.rivals.rivals[index].focusTopicIDs.append(topicID)
        }
        StandingSystem.recordSponsoredDelivery(topicID: topicID, &state, balance)

        return [.sponsoredContractDelivered(
            rivalID: rivalID,
            topicID: topicID,
            quality: Int(quality.rounded()),
            day: state.day
        )]
    }

    /// "Northwind Fitness": the first word of the sponsor's name on the
    /// topic it now sells into.
    private static func sponsoredProductName(
        rival: Rival,
        topicID: String,
        _ content: ContentCatalog
    ) -> String {
        let brand = rival.name.split(separator: " ").first.map(String.init) ?? rival.name
        let topic = content.topic(topicID)?.name ?? topicID.capitalized
        return "\(brand) \(topic)"
    }

    // MARK: - Actions

    /// Accepts an offer off the sheet: it becomes an active job (keeping the
    /// offer's id) with its deadline anchored to today. Ignored for unknown
    /// or expired offers; no partial state changes on rejection.
    static func acceptContract(offerID: UUID, state: inout GameState) -> [GameEvent] {
        guard let index = state.contractOffers.firstIndex(where: { $0.id == offerID }),
              state.day <= state.contractOffers[index].expiresDay
        else { return [] }

        let offer = state.contractOffers.remove(at: index)
        state.activeContracts.append(ContractJob(
            id: offer.id,
            clientName: offer.clientName,
            requiredCodePts: offer.requiredCodePts,
            requiredDesignPts: offer.requiredDesignPts,
            progressCode: 0,
            progressDesign: 0,
            deadlineDay: state.day + offer.deadlineDays,
            payout: offer.payout,
            penalty: offer.penalty,
            acceptedDay: state.day,
            requiredSkill: offer.requiredSkill,
            topicID: offer.topicID,
            sponsorRivalID: offer.sponsorRivalID
        ))
        return [.contractAccepted(contractID: offer.id, day: state.day)]
    }
}
