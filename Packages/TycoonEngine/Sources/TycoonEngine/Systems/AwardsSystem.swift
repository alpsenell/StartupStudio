import Foundation

// MARK: G8 (awards night, attended)

/// Iteration 18 — G8. What the ceremony pays.
///
/// The judging is the app's (`AwardsJudge`) and always was. This file is
/// the other half: one entry point, `recordCeremony`, reached only by
/// `.recordCeremony`, which only the ceremony sheet sends. It charges the
/// table, spends the founder's evening, pays the envelopes out and files
/// the night — and it refuses a year that is already in the book, so a
/// sheet reopened on a reloaded save cannot pay twice.
///
/// The payouts, and where they came from:
///
/// * A topic envelope, with the team there: `awards.winStanding` into that
///   topic's standing, and `awards.winHype` onto the product that won it.
/// * Studio of the Year, with the team there: `awards.studioReputation`,
///   and `awards.winMoraleAll` for everyone on payroll.
/// * An attended night *without* Studio of the Year: `awards.lossMoraleAll`.
/// * From home: `awards.homeReputation` per envelope and nothing else.
///
/// The two morale numbers key off Studio of the Year alone rather than off
/// any win. That is the spec's own remedy, fired by the spec's own
/// measurement: the judge run on `release-studio-day400` and
/// `release-campus-day900` returns no year in which a rival won a topic
/// the player was live in, so "a win" is not a thing that can fail to
/// happen and `lossMoraleAll` would never have been read. Studio of the
/// Year is the one envelope the floor can lose.
enum AwardsSystem {
    static func recordCeremony(
        year: Int,
        attended: Bool,
        wins: [CeremonyWin],
        state: inout GameState,
        balance: BalanceConfig
    ) -> [GameEvent] {
        guard state.ceremonyRefusal(year: year, attending: attended, balance: balance) == nil else {
            return []
        }
        let config = balance.awards
        let studioOfTheYear = wins.contains { $0.isStudioOfTheYear }
        var cost = 0

        if attended {
            cost = state.ceremonyTablePrice(balance: balance)
            state.company.cash -= cost
            state.ledger.post(LedgerEntry(
                day: state.day, amount: -cost, category: .marketing,
                label: "Awards night: a table for the team"
            ))
            state.spendEvening(balance)

            for win in wins {
                if let topicID = win.topicID {
                    StandingSystem.recordAward(
                        topicID: topicID, amount: config.winStanding, &state, balance
                    )
                }
                if let productID = win.productID,
                   let index = state.products.firstIndex(where: { $0.id == productID }),
                   case .released(var info) = state.products[index].stage {
                    info.liveHype += config.winHype
                    state.products[index].stage = .released(info)
                }
            }
            if studioOfTheYear {
                state.company.reputation = clamp(state.company.reputation + config.studioReputation)
            }
            moraleAll(studioOfTheYear ? config.winMoraleAll : config.lossMoraleAll, &state)
        } else {
            // "You weren't there to collect it": the wire picks the name
            // up, and that is all the night is worth.
            let gain = config.homeReputation * Double(wins.count)
            if gain != 0 {
                state.company.reputation = clamp(state.company.reputation + gain)
            }
        }

        state.company.ceremonies.append(CeremonyRecord(year: year, attended: attended, wins: wins))
        return [.ceremonyRecorded(
            year: year, attended: attended, wins: wins.count,
            studioOfTheYear: studioOfTheYear, cost: cost, day: state.day
        )]
    }

    private static func moraleAll(_ delta: Double, _ state: inout GameState) {
        guard delta != 0 else { return }
        for index in state.employees.indices where !state.employees[index].isFounder {
            state.employees[index].morale = clamp(state.employees[index].morale + delta)
        }
    }

    private static func clamp(_ value: Double) -> Double { min(100, max(0, value)) }
}

// MARK: end G8
