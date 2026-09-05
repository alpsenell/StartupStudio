import SwiftUI
import TycoonEngine

/// Compact chip menu that reassigns an employee: Idle, anything in
/// development, Research, a live product's support desk, a codebase to
/// refactor, or any active contract.
struct AssignmentMenu: View {
    let engine: GameEngine
    let employee: Employee

    var body: some View {
        Menu {
            assignmentButton(.idle, label: String(localized: "Idle", comment: "An employee with no work. Used in the assignment menu and as the current-assignment readout"), systemImage: "moon.zzz.fill")
            // An office runs one to five builds at a time now (WS-A's
            // concurrent dev slots), so every one of them is offered.
            ForEach(engine.state.productsInDevelopment) { product in
                assignmentButton(
                    .product(product.id), label: product.name, systemImage: "hammer.fill"
                )
            }
            assignmentButton(.research, label: String(localized: "Research", comment: "The tech tree. Used in the assignment menu, as the current-assignment readout, and as a ledger bucket"), systemImage: "flask.fill")
            if !supportable.isEmpty {
                Section("Support") {
                    ForEach(supportable, id: \.product.id) { entry in
                        assignmentButton(
                            entry.assignment,
                            label: entry.bugs > 0
                                ? "\(entry.product.name) — \(entry.bugs) bug\(entry.bugs == 1 ? "" : "s")"
                                : entry.product.name,
                            systemImage: "lifepreserver.fill"
                        )
                    }
                }
            }
            if !engine.state.codebases.isEmpty {
                Section("Refactor") {
                    ForEach(engine.state.codebases) { codebase in
                        assignmentButton(
                            .refactor(codebase.id),
                            // The debt is the whole reason to pick this,
                            // exactly as the bug count is on a support
                            // desk above.
                            label: codebase.debt >= 1
                                ? "\(codebase.name) — \(Int(codebase.debt.rounded())) debt"
                                : codebase.name,
                            systemImage: "wrench.and.screwdriver.fill"
                        )
                    }
                }
            }
            if !engine.state.activeContracts.isEmpty {
                Section("Contracts") {
                    ForEach(engine.state.activeContracts) { job in
                        assignmentButton(
                            .contract(job.id),
                            label: job.clientName,
                            systemImage: "briefcase.fill"
                        )
                    }
                }
            }
        } label: {
            HStack(spacing: Theme.Spacing.xs) {
                Text(currentLabel)
                    .font(.system(.caption, design: .rounded).weight(.semibold))
                    .lineLimit(1)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2.weight(.semibold))
            }
            .foregroundStyle(Theme.accent)
            .padding(.horizontal, Theme.Spacing.sm + 2)
            .padding(.vertical, Theme.Spacing.xs + 1)
            .background(Theme.chipBackground, in: Capsule())
        }
        .accessibilityLabel("Assignment for \(employee.name)")
        .accessibilityValue(currentLabel)
    }

    private func assignmentButton(
        _ assignment: Assignment,
        label: String,
        systemImage: String
    ) -> some View {
        Button {
            engine.send(.assign(employeeID: employee.id, to: assignment))
        } label: {
            // The checkmark marks the current assignment, menu-picker style.
            Label(label, systemImage: employee.assignment == assignment ? "checkmark" : systemImage)
        }
    }

    /// Everything on the market that somebody could be put on, with the
    /// bugs the wild has found so far — the number is the whole reason to
    /// staff a support desk.
    private var supportable: [(product: Product, bugs: Int, assignment: Assignment)] {
        engine.state.products.compactMap { product in
            guard case .released(let info) = product.stage, !info.offMarket,
                  let assignment = LiveOps.supportAssignment(productID: product.id)
            else { return nil }
            return (product, info.liveBugs, assignment)
        }
    }

    private var currentLabel: String {
        switch employee.assignment {
        case .idle:
            String(localized: "Idle", comment: "An employee with no work. Used in the assignment menu and as the current-assignment readout")
        case .research:
            String(localized: "Research", comment: "The tech tree. Used in the assignment menu, as the current-assignment readout, and as a ledger bucket")
        case .contract(let contractID):
            // Defensive: the job should always resolve while assigned.
            engine.state.activeContract(id: contractID)?.clientName ?? String(localized: "Contract", comment: "Current assignment: a client job whose name could not be resolved")
        case .product(let productID):
            // Defensive: the product should always resolve while assigned.
            engine.state.product(id: productID)?.name ?? String(localized: "Product", comment: "Current assignment: a build whose name could not be resolved")
        case .support(let productID):
            // Defensive: the product should always resolve while assigned.
            engine.state.product(id: productID).map { String(localized: "Support: \($0.name)", comment: "Current assignment: staffing a shipped product's support desk") } ?? String(localized: "Support", comment: "Current assignment: a support desk whose product could not be resolved")
        case .refactor(let codebaseID):
            // Defensive: the codebase should always resolve while assigned.
            engine.state.codebase(id: codebaseID).map { String(localized: "Refactor: \($0.name)", comment: "Current assignment: paying down a codebase's technical debt") } ?? String(localized: "Refactor", comment: "Current assignment: a refactor whose codebase could not be resolved")
        @unknown default:
            String(localized: "Assigned", comment: "Current assignment: an assignment kind this build does not know")
        }
    }
}


/// "Put someone on it": a menu of the people who are idle, sending
/// `.assign` straight from the screen that has the work — a contract that
/// nobody is on, a lab that banks no points — instead of a hop to the Team
/// tab and back.
struct IdleAssignMenu: View {
    let engine: GameEngine
    let assignment: Assignment
    var label = String(localized: "Assign", comment: "Menu title: put an idle person on this piece of work")

    @Environment(GameShell.self) private var injectedShell: GameShell?
    /// See `GameShell.shared`: read optionally, because SwiftUI
    /// updates this property for presented content before the
    /// environment is installed and the non-optional form traps there.
    private var shell: GameShell { injectedShell ?? .shared }
    @Environment(AppRouter.self) private var router

    private var idle: [Employee] {
        engine.state.employees.filter { $0.assignment == .idle }
    }

    var body: some View {
        Menu {
            if idle.isEmpty {
                Text("Nobody is idle")
                Button {
                    router.go(.hiring)
                } label: {
                    Label("Open the team", systemImage: "person.2.fill")
                }
            } else {
                ForEach(idle) { employee in
                    Button {
                        shell.toasts.send(
                            .assign(employeeID: employee.id, to: assignment),
                            to: engine,
                            ack: "\(employee.name) is on it"
                        )
                    } label: {
                        Label(employee.name, systemImage: employee.isFounder ? "crown.fill" : "person.fill")
                    }
                }
                if idle.count > 1 {
                    Divider()
                    Button {
                        for employee in idle {
                            engine.send(.assign(employeeID: employee.id, to: assignment))
                        }
                        shell.toasts.show("Everyone idle is on it", icon: "person.3.fill")
                    } label: {
                        Label("Everyone idle", systemImage: "person.3.fill")
                    }
                }
            }
        } label: {
            Label(label, systemImage: "person.badge.plus")
                .font(.system(.footnote, design: .rounded).weight(.semibold))
        }
        .buttonStyle(.bordered)
        .accessibilityLabel("\(label): choose someone who is idle")
    }
}
