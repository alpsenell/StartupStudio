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
            assignmentButton(.idle, label: "Idle", systemImage: "moon.zzz.fill")
            // An office runs one to five builds at a time now (WS-A's
            // concurrent dev slots), so every one of them is offered.
            ForEach(engine.state.productsInDevelopment) { product in
                assignmentButton(
                    .product(product.id), label: product.name, systemImage: "hammer.fill"
                )
            }
            assignmentButton(.research, label: "Research", systemImage: "flask.fill")
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
            "Idle"
        case .research:
            "Research"
        case .contract(let contractID):
            // Defensive: the job should always resolve while assigned.
            engine.state.activeContract(id: contractID)?.clientName ?? "Contract"
        case .product(let productID):
            // Defensive: the product should always resolve while assigned.
            engine.state.product(id: productID)?.name ?? "Product"
        case .support(let productID):
            // Defensive: the product should always resolve while assigned.
            engine.state.product(id: productID).map { "Support: \($0.name)" } ?? "Support"
        case .refactor(let codebaseID):
            // Defensive: the codebase should always resolve while assigned.
            engine.state.codebase(id: codebaseID).map { "Refactor: \($0.name)" } ?? "Refactor"
        @unknown default:
            "Assigned"
        }
    }
}

