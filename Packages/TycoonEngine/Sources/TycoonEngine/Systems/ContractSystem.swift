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

        events.append(contentsOf: settleContracts(&state, balance))
        return events
    }

    // MARK: - Weekly offer sheet

    /// Replaces the sheet with `contractOfferCount` fresh rolls (plus
    /// `legalExtraOffers` with a Legal department). Per offer, the RNG
    /// draws in a fixed order: id, client name, total points, code split,
    /// urgency premium, deadline slack, required skill. The point-roll
    /// range scales with the studio's age:
    /// `1 + contractYearScale * (year - 1)`; the required-skill roll rises
    /// `skillYearBump` per year, capped at `skillCap`.
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
        state.contractOffers = offers
    }

    private static func pick(_ pool: [String], _ rng: inout SeededRNG) -> String {
        guard !pool.isEmpty else { return "" }
        return pool[rng.nextInt(in: 0...(pool.count - 1))]
    }

    // MARK: - Daily settlement

    /// Completion is checked before the deadline, so a job can still be
    /// delivered on its deadline day. A Legal department lifts every payout
    /// by `legalPayoutBonus` and scales every missed-deadline penalty by
    /// `legalPenaltyFactor`. Settled jobs leave `activeContracts`; the
    /// daily employee sweep then returns their workers to idle.
    private static func settleContracts(
        _ state: inout GameState,
        _ balance: BalanceConfig
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
            } else {
                remaining.append(job)
            }
        }

        state.activeContracts = remaining
        return events
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
