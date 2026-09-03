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
                text: "Rival offer pending · \(poach.offeredWeeklySalary.money)/wk",
                systemImage: "person.fill.questionmark",
                tint: Theme.warning
            )
        }

        let fair = EmployeeSalaryGuide.fairPay(for: employee, balance: balance)
        if fair > 0, Double(employee.weeklySalary) < Double(fair) * balance.staff.underpaidThreshold {
            return EmployeeStatus(
                kind: .underpaid,
                text: "Underpaid · market rate \(fair.money)/wk",
                systemImage: "arrow.down.circle.fill",
                tint: Theme.warning
            )
        }

        if employee.assignment == .idle, day - employee.hiredDay >= 14 {
            return EmployeeStatus(
                kind: .idle,
                text: "Idle · nothing assigned",
                systemImage: "moon.zzz.fill",
                tint: .secondary
            )
        }

        if employee.founderBond < 25, day - employee.hiredDay > 28 {
            return EmployeeStatus(
                kind: .bondFading,
                text: "Bond fading · an evening would help",
                systemImage: "heart.slash.fill",
                tint: .secondary
            )
        }

        if let trained = employee.lastTrainedDay, day - trained < 14 {
            return EmployeeStatus(
                kind: .training,
                text: "Just trained · settling in",
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
