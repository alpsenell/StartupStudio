import Foundation

/// The read-only questions the Life, Team and networking screens ask about
/// the founder's own life before they draw a button.
///
/// Every one of these answers "why is this greyed out?" with the *engine's*
/// reason, delegating to the same system that would refuse the action. The
/// alternative — SwiftUI re-deriving each gate — is the bug where a button
/// looks available and does nothing, and it is the bug this file exists to
/// make impossible.
extension GameState {
    /// Why a training session would be refused, or `nil` when it would go
    /// ahead.
    public func trainingBlocker(_ method: TrainingMethod, balance: BalanceConfig) -> String? {
        FounderSystem.trainingBlocker(method, state: self, balance: balance)
    }

    /// Why an instant activity would be refused, or `nil` when it would go
    /// ahead. Mirrors `LifeSystem.doInstantActivity`'s gates, in the order
    /// the player would hit them.
    public func instantActivityBlocker(
        _ activity: InstantActivity,
        balance: BalanceConfig
    ) -> String? {
        guard let def = balance.instantLife.activity(activity) else { return "Not available" }
        if life.isAway(day: day) { return "The founder is away" }
        if life.instantActionsToday >= balance.instantLife.maxPerDay { return "Done for today" }
        if let reason = eveningBlocker(balance) { return reason }
        if let last = life.instantCooldowns[activity.rawValue] {
            let left = def.cooldownDays - (day - last)
            if left > 0 { return "Again in \(left) day\(left == 1 ? "" : "s")" }
        }
        if def.cost > 0, life.wallet < def.cost {
            return "Need \(def.cost - life.wallet) more"
        }
        return nil
    }

    /// Why this networking deal cannot be made, or `nil` when it can.
    public func networkingOfferBlocker(
        _ offer: NetworkingOffer,
        contactID: UUID,
        balance: BalanceConfig
    ) -> String? {
        NetworkingSystem.offerBlocker(offer, contactID: contactID, state: self, balance: balance)
    }

    /// Why an evening with the founder's partner would be refused, or
    /// `nil`.
    public func partnerActivityBlocker(
        _ activity: PartnerActivity,
        balance: BalanceConfig
    ) -> String? {
        RelationshipSystem.partnerBlocker(activity, state: self, balance: balance)
    }

    /// Why a hang-out with somebody on the team would be refused, or `nil`.
    public func hangOutBlocker(employeeID: UUID, balance: BalanceConfig) -> String? {
        RelationshipSystem.hangOutBlocker(employeeID: employeeID, state: self, balance: balance)
    }

    /// Why mentoring somebody would be refused, or `nil`.
    public func mentorBlocker(employeeID: UUID, balance: BalanceConfig) -> String? {
        RelationshipSystem.mentorBlocker(employeeID: employeeID, state: self, balance: balance)
    }

    /// Morale-target points the founder personally is costing the team
    /// right now — their mood, and whose crunch this is. Zero or negative,
    /// never positive: see `EmployeeSystem.founderMoraleDelta`.
    ///
    /// The Life tab's schedule card and the HQ pace picker both show this,
    /// so the two crunch switches can name each other instead of the
    /// player discovering the interaction from a morale number that moved
    /// for no visible reason.
    public func founderMoraleImpact(balance: BalanceConfig) -> Double {
        EmployeeSystem.founderMoraleDelta(self, balance)
    }

    /// The team's median weekly salary, or `nil` with nobody on payroll.
    /// The median rather than the mean, so one lead's package does not
    /// move the band the whole room is judged against.
    public var teamMedianSalary: Int? {
        let salaries = employees.filter { !$0.isFounder }.map(\.weeklySalary).sorted()
        guard !salaries.isEmpty else { return nil }
        return salaries[salaries.count / 2]
    }

    /// How many whole multiples of the team's median pay the founder is
    /// taking *above* the fair band — zero when they are inside it, when
    /// there is nobody to compare against, or when the salary is the one
    /// the company set to keep them housed.
    ///
    /// That last exemption matters: `LifeSystem.checkEviction` raises the
    /// founder's pay itself when they are about to be evicted, and
    /// punishing the room's morale for a bail-out the player did not ask
    /// for would undo the floor the debt spiral was deliberately given.
    /// A team resents a founder who helped themselves, not one the company
    /// had to rescue.
    public func founderPayExcess(balance: BalanceConfig) -> Double {
        guard let median = teamMedianSalary, median > 0 else { return 0 }
        guard economy.rescueSalary != life.founderSalary else { return 0 }
        let ratio = Double(life.founderSalary) / Double(median)
            // MARK: K7 (partner and diary) — the household draw: the partner's pay comes home.
            + Double(partnerHouseholdDraw) / Double(median)
            // MARK: end K7
        return max(0, ratio - balance.economy.founderPayFairRatio)
    }

    /// What the founder's pay is costing team morale right now.
    public func founderPayMoralePenalty(balance: BalanceConfig) -> Double {
        let config = balance.economy
        return min(
            config.founderPayMoraleCap,
            founderPayExcess(balance: balance) * config.founderPayMoralePerRatioPoint
        )
    }

    /// The most the founder could pay themselves before the room minds.
    /// `nil` with nobody on payroll — a solo founder answers to no one.
    public func fairFounderSalaryCeiling(balance: BalanceConfig) -> Int? {
        teamMedianSalary.map {
            Int((Double($0) * balance.economy.founderPayFairRatio).rounded())
        }
    }

    /// Whether the founder is standing in a networking room right now.
    public var isAtNetworkingEvent: Bool { networking.pendingEvent != nil }

    /// The founder's remaining slice of their own company, after every
    /// funding round and every slice signed over to somebody they met.
    public var founderEquity: Double { investors.equityRemaining }
}

// MARK: - Credit

/// What the bank will lend the company, asked of the system that decides
/// it.
///
/// The Business tab used to compute this itself out of `balance.loans`
/// (`baseLimit + reputation × perReputation`) while `FinanceSystem` lent
/// against `balance.economy` (`creditLimitBase + trailing revenue × 0.5 +
/// reputation × 300`). The two had drifted apart: a studio with revenue
/// could borrow more than the screen said it could, and the reputation
/// term on screen was double the one the engine honoured. Both numbers now
/// come from here, and the two dead keys are gone from `LoanBalance`.
extension GameState {
    /// The bank's ceiling on total company borrowing today.
    public func creditLimit(balance: BalanceConfig) -> Int {
        FinanceSystem.creditLimit(self, balance)
    }

    /// What is still available to draw: the ceiling less what is already
    /// outstanding, floored at zero.
    public func creditHeadroom(balance: BalanceConfig) -> Int {
        max(0, creditLimit(balance: balance) - loanBalance)
    }

    /// What the bank will lend on the company's name alone.
    public func unsecuredCreditLimit(balance: BalanceConfig) -> Int {
        FinanceSystem.unsecuredCreditLimit(self, balance)
    }

    /// Unsecured borrowing still available.
    public func unsecuredHeadroom(balance: BalanceConfig) -> Int {
        max(0, unsecuredCreditLimit(balance: balance) - loanBalance)
    }

    /// What the founder's home is worth as collateral.
    public func guaranteeCapacity(balance: BalanceConfig) -> Int {
        FinanceSystem.guaranteeCapacity(self, balance)
    }

    /// Borrowing available only against the founder's home — the slice of
    /// the bank's ceiling their signature unlocks.
    public func securedHeadroom(balance: BalanceConfig) -> Int {
        max(0, min(
            creditHeadroom(balance: balance) - unsecuredHeadroom(balance: balance),
            guaranteeCapacity(balance: balance) - economy.guaranteedLoanAmount
        ))
    }

    /// How much of the company's debt the founder is personally on the
    /// hook for.
    public var guaranteedDebt: Int { economy.guaranteedLoanAmount }
}
