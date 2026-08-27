import SwiftUI
import TycoonEngine

/// The Team tab: the roster (portraits, skills, salaries, assignments)
/// with swipe-to-fire, plus the hiring sheet.
struct TeamScreen: View {
    let engine: GameEngine

    @State private var showingHiring = false
    @State private var employeeToFire: Employee?
    @State private var employeeToManage: Employee?

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

                    teamDinnerRow
                }

                Section {
                    ForEach(roster) { employee in
                        EmployeeRow(engine: engine, employee: employee)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                // The founder's levers live on the Life tab.
                                if !employee.isFounder {
                                    employeeToManage = employee
                                }
                            }
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
            // The HUD inset lives on the stack's root content (not on the
            // NavigationStack) so the list scrolls below it and any pushed
            // destination shows the navigation bar instead.
            .withTopHUD(engine: engine)
            .sensoryFeedback(.success, trigger: engine.state.lastTeamDinnerDay)
            .navigationTitle("Team")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showingHiring) {
                HiringSheet(engine: engine)
            }
            .sheet(item: $employeeToManage) { employee in
                EmployeeManageSheet(engine: engine, employeeID: employee.id)
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
    /// Team dinner: morale + loyalty for everyone, per-head cost, global
    /// cooldown. Mirrors the engine's gates to disable with a reason.
    @ViewBuilder
    private var teamDinnerRow: some View {
        let state = engine.state
        let social = engine.balance.social
        let hiredCount = state.employees.filter { !$0.isFounder }.count
        let cost = social.dinnerCostPerHead * state.headcount
        let onCooldown = state.lastTeamDinnerDay.map {
            state.day - $0 < social.teamDinnerCooldownDays
        } ?? false
        let blocker: String? = if hiredCount == 0 {
            "Hire someone first"
        } else if onCooldown {
            "The team ate out recently"
        } else if state.company.cash < cost {
            "Need \((cost - state.company.cash).money) more"
        } else {
            nil
        }

        Button {
            engine.send(.teamDinner)
        } label: {
            HStack {
                Label("Team dinner", systemImage: "fork.knife.circle.fill")
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(blocker == nil ? Theme.accent : .secondary)
                Spacer()
                Text(blocker ?? "\(cost.money) · morale & loyalty up")
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
        .disabled(blocker != nil)
        .accessibilityLabel("Team dinner. \(blocker ?? "\(cost.money), lifts morale and loyalty")")
    }

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
                        // The founder's role badge doubles as the founder
                        // marker (crown, accent tint); staff get level too.
                        RoleBadge(role: employee.role, prominent: employee.isFounder)
                        if !employee.isFounder {
                            LevelBadge(level: employee.level)
                        }
                    }
                    HStack(spacing: Theme.Spacing.xs + 2) {
                        Text("\(employee.weeklySalary.money)/wk")
                            .font(.caption)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                        if !employee.isFounder {
                            MoraleDot(morale: employee.morale)
                        }
                    }
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

/// Tiny colored dot plus label summarizing morale in the roster row.
private struct MoraleDot: View {
    let morale: Double

    var body: some View {
        HStack(spacing: 3) {
            Circle()
                .fill(lifeMeterTint(morale))
                .frame(width: 6, height: 6)
            Text("Morale \(Int(morale.rounded()))")
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .accessibilityLabel("Morale \(Int(morale.rounded())) out of 100")
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

extension SocialActivityKind {
    var systemImage: String {
        switch self {
        case .coffee: "cup.and.saucer.fill"
        case .oneOnOne: "bubble.left.and.bubble.right.fill"
        case .gift: "gift.fill"
        case .teamDinner: "fork.knife.circle.fill"
        }
    }
}
