import SwiftUI
import TycoonContent
import TycoonEngine

/// The one fact about a person that matters this week, in priority order:
/// on notice, out of patience soon, a rival's offer pending, underpaid,
/// idle for weeks, the bond fading, in training. The manage sheet has
/// always computed these one tap deep per person; the roster row, the
/// weekly report and the Team tab's badge read them from here.
struct EmployeeStatus: Equatable {
    enum Kind: Int, Comparable {
        case onNotice, outOfPatience, poachPending, underpaid, idle, bondFading, training

        static func < (lhs: Kind, rhs: Kind) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    let kind: Kind
    let text: String
    let systemImage: String
    let tint: Color

    /// Whether this is the kind of status that should count on the tab.
    var needsAttention: Bool {
        switch kind {
        case .onNotice, .outOfPatience, .poachPending: true
        default: false
        }
    }

    // l10n: the two `On notice`/`Out of patience` lines below pluralise with
    // a trailing `s` inside the interpolation, so they are left as-is rather
    // than wrapped into a key that would read `%lld day%@`. They become a
    // `.stringsdict` plural pair (`status.onNotice`, `status.outOfPatience`)
    // in the sentence lane. The four fixed lines under them are localized.
    /// The status for `employee`, or `nil` when there is nothing to say.
    static func of(_ employee: Employee, in state: GameState, balance: BalanceConfig, content: ContentCatalog) -> EmployeeStatus? {
        guard !employee.isFounder else { return nil }
        let day = state.day

        if let notice = state.economy.pendingResignation, notice.employeeID == employee.id {
            let left = max(0, notice.respondByDay - day)
            return EmployeeStatus(
                kind: .onNotice,
                text: left == 0 ? "On notice · leaves today" : "On notice · \(left) day\(left == 1 ? "" : "s") to answer",
                systemImage: "figure.walk.departure",
                tint: Theme.negativeCash
            )
        }

        if employee.lowMoraleStreakDays > 0 {
            let patience = balance.staff.quitStreakDays
                + Int(employee.loyalty / balance.social.loyaltyQuitDivisor)
                + TraitEffects.quitStreakBonus(employee, content: content)
            let left = max(0, patience - employee.lowMoraleStreakDays)
            if left <= 7 {
                return EmployeeStatus(
                    kind: .outOfPatience,
                    text: left == 0 ? "Out of patience · could resign any day" : "Out of patience in \(left) day\(left == 1 ? "" : "s")",
                    systemImage: "exclamationmark.triangle.fill",
                    tint: left <= 2 ? Theme.negativeCash : Theme.warning
                )
            }
        }

        if let poach = state.rivals.pendingPoach, poach.employeeID == employee.id {
            return EmployeeStatus(
                kind: .poachPending,
                text: String(localized: "Rival offer pending · \(poach.offeredWeeklySalary.money)/wk", comment: "Roster status: a rival has bid for this person. The figure is money per week"),
                systemImage: "person.fill.questionmark",
                tint: Theme.warning
            )
        }

        let fair = EmployeeSalaryGuide.fairPay(for: employee, balance: balance)
        if fair > 0, Double(employee.weeklySalary) < Double(fair) * balance.staff.underpaidThreshold {
            return EmployeeStatus(
                kind: .underpaid,
                text: String(localized: "Underpaid · market rate \(fair.money)/wk", comment: "Roster status: paid below the going rate. The figure is money per week"),
                systemImage: "arrow.down.circle.fill",
                tint: Theme.warning
            )
        }

        if employee.assignment == .idle, day - employee.hiredDay >= 14 {
            return EmployeeStatus(
                kind: .idle,
                text: String(localized: "Idle · nothing assigned", comment: "Roster status: this person has no work"),
                systemImage: "moon.zzz.fill",
                tint: .secondary
            )
        }

        if employee.founderBond < 25, day - employee.hiredDay > 28 {
            return EmployeeStatus(
                kind: .bondFading,
                text: String(localized: "Bond fading · an evening would help", comment: "Roster status: the founder has not spent time with this person"),
                systemImage: "heart.slash.fill",
                tint: .secondary
            )
        }

        if let trained = employee.lastTrainedDay, day - trained < 14 {
            return EmployeeStatus(
                kind: .training,
                text: String(localized: "Just trained · settling in", comment: "Roster status: recently sent on training"),
                systemImage: "book.fill",
                tint: .secondary
            )
        }

        return nil
    }

    /// Everyone with a status, most urgent first.
    static func roster(in state: GameState, balance: BalanceConfig, content: ContentCatalog) -> [(employee: Employee, status: EmployeeStatus)] {
        state.employees
            .compactMap { employee in of(employee, in: state, balance: balance, content: content).map { (employee, $0) } }
            .sorted { $0.status.kind < $1.status.kind }
    }

    /// How many people need attention right now, for the tab badge.
    static func attentionCount(in state: GameState, balance: BalanceConfig, content: ContentCatalog) -> Int {
        roster(in: state, balance: balance, content: content).count { $0.status.needsAttention }
    }
}
