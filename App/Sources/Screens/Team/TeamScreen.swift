import SwiftUI
import TycoonEngine

/// The Team tab: the roster (portraits, skills, salaries, assignments)
/// with swipe-to-fire, plus the hiring sheet.
struct TeamScreen: View {
    let engine: GameEngine

    @State private var showingHiring = false
    @State private var employeeToFire: Employee?

    var body: some View {
        NavigationStack {
            List {
                // In-content hiring entry point: nav-bar toolbars sit
                // underneath the opaque top HUD in this design, so actions
                // live in the list instead.
                Section {
                    Button {
                        showingHiring = true
                    } label: {
                        HStack {
                            Label("Hiring", systemImage: "person.badge.plus")
                                .font(.system(.headline, design: .rounded))
                                .foregroundStyle(Theme.accent)
                            Spacer()
                            Text("\(engine.state.candidatePool.count) candidate\(engine.state.candidatePool.count == 1 ? "" : "s")")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .accessibilityLabel("Open hiring")
                }

                Section {
                    ForEach(roster) { employee in
                        EmployeeRow(engine: engine, employee: employee)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                // The founder can't be fired — the engine
                                // would ignore it, so don't offer it.
                                if !employee.isFounder {
                                    Button(role: .destructive) {
                                        employeeToFire = employee
                                    } label: {
                                        Label("Fire", systemImage: "person.badge.minus")
                                    }
                                    .accessibilityLabel("Fire \(employee.name)")
                                }
                            }
                    }
                } header: {
                    Text("Roster")
                } footer: {
                    payrollFooter
                }
            }
            .navigationTitle("Team")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showingHiring) {
                HiringSheet(engine: engine)
            }
            .confirmationDialog(
                employeeToFire.map { "Fire \($0.name)?" } ?? "",
                isPresented: fireDialogPresented,
                titleVisibility: .visible,
                presenting: employeeToFire
            ) { employee in
                Button("Fire \(employee.name)", role: .destructive) {
                    engine.send(.fire(employeeID: employee.id))
                }
                Button("Cancel", role: .cancel) {}
            } message: { _ in
                Text("No severance in the garage era.")
            }
        }
    }

    /// Founder first, then by hire day — matching desk order in the
    /// office scene.
    private var roster: [Employee] {
        engine.state.employees.sorted { lhs, rhs in
            if lhs.isFounder != rhs.isFounder { return lhs.isFounder }
            return lhs.hiredDay < rhs.hiredDay
        }
    }

    private var fireDialogPresented: Binding<Bool> {
        Binding(
            get: { employeeToFire != nil },
            set: { presented in
                if !presented { employeeToFire = nil }
            }
        )
    }

    private var totalPayroll: Int {
        engine.state.employees.reduce(0) { $0 + $1.weeklySalary }
    }

    private var payrollFooter: some View {
        HStack {
            Text("Total payroll")
            Spacer()
            Text("\(totalPayroll.money)/wk")
                .monospacedDigit()
                .contentTransition(.numericText())
                .animation(.spring(duration: 0.35), value: totalPayroll)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Total payroll \(totalPayroll.money) per week")
    }
}

// MARK: - Roster row

private struct EmployeeRow: View {
    let engine: GameEngine
    let employee: Employee

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(spacing: Theme.Spacing.md) {
                PixelPortrait(seed: employee.appearanceSeed, isFounder: employee.isFounder)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: Theme.Spacing.xs + 2) {
                        Text(employee.name)
                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                            .lineLimit(1)
                        if employee.isFounder {
                            FounderBadge()
                        }
                    }
                    Text("\(employee.weeklySalary.money)/wk")
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)

                Spacer(minLength: Theme.Spacing.sm)

                AssignmentMenu(engine: engine, employee: employee)
            }

            SkillBars(skills: employee.skills)
        }
        .padding(.vertical, Theme.Spacing.xs)
    }
}

/// Small "FOUNDER" capsule next to the founder's name.
private struct FounderBadge: View {
    var body: some View {
        Text("FOUNDER")
            .font(.caption2.weight(.bold))
            .kerning(0.5)
            .foregroundStyle(Theme.accent)
            .padding(.horizontal, Theme.Spacing.xs + 2)
            .padding(.vertical, 2)
            .background(Theme.accent.opacity(0.15), in: Capsule())
            .accessibilityLabel("Founder")
    }
}

// MARK: - Assignment menu

/// Compact chip menu that reassigns an employee: Idle, the product in
/// development (if any), Research, or any active contract.
private struct AssignmentMenu: View {
    let engine: GameEngine
    let employee: Employee

    var body: some View {
        Menu {
            assignmentButton(.idle, label: "Idle", systemImage: "moon.zzz.fill")
            if let product = engine.state.productInDevelopment {
                assignmentButton(.product(product.id), label: product.name, systemImage: "hammer.fill")
            }
            assignmentButton(.research, label: "Research", systemImage: "flask.fill")
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
        }
    }
}
