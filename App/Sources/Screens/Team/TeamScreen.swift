import SwiftUI
import TycoonContent
import TycoonEngine

/// The Team tab: the roster with portraits, mood faces, trait chips,
/// skills, salaries and assignments — searchable, sortable, and with a
/// bulk "everyone onto this" move for the days when the whole studio has
/// to swing onto one thing. Swipe to fire; tap anyone to manage them.
struct TeamScreen: View {
    let engine: GameEngine

    /// How the roster is ordered. Founder-first is the default, matching
    /// desk order in the office scene.
    private enum SortOrder: String, CaseIterable, Identifiable {
        case tenure = "Tenure"
        case role = "Role"
        case morale = "Morale"
        case salary = "Salary"

        var id: String { rawValue }
    }

    @State private var showingHiring = false
    @State private var employeeToFire: Employee?
    @State private var employeeToManage: Employee?
    @State private var search = ""
    @State private var sortOrder: SortOrder = .tenure

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
                                .font(Theme.Typography.number(.subheadline, weight: .regular))
                                .foregroundStyle(.secondary)
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .accessibilityLabel("Open hiring")

                    teamDinnerRow
                    bulkAssignRow
                }

                Section {
                    if roster.isEmpty {
                        Text(
                            search.isEmpty
                                ? "Nobody on payroll yet."
                                : "Nobody matches \u{201C}\(search)\u{201D}."
                        )
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }
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
                    rosterHeader
                } footer: {
                    payrollFooter
                }
            }
            .searchable(text: $search, prompt: "Search the team")
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

    // MARK: - Roster

    /// Everyone matching the search, in the chosen order. The founder
    /// always leads, whatever the sort — they are not a row you compare.
    private var roster: [Employee] {
        let matching = engine.state.employees.filter(matchesSearch)
        return matching.sorted { lhs, rhs in
            if lhs.isFounder != rhs.isFounder { return lhs.isFounder }
            switch sortOrder {
            case .tenure:
                if lhs.hiredDay != rhs.hiredDay { return lhs.hiredDay < rhs.hiredDay }
            case .role:
                if lhs.role != rhs.role { return lhs.role.displayName < rhs.role.displayName }
            case .morale:
                if lhs.morale != rhs.morale { return lhs.morale < rhs.morale }
            case .salary:
                if lhs.weeklySalary != rhs.weeklySalary { return lhs.weeklySalary > rhs.weeklySalary }
            }
            return lhs.name < rhs.name
        }
    }

    /// Matches on name, role and trait name, so "flight" finds the people
    /// about to leave.
    private func matchesSearch(_ employee: Employee) -> Bool {
        let query = search.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return true }
        if employee.name.lowercased().contains(query) { return true }
        if employee.role.displayName.lowercased().contains(query) { return true }
        return employee.traits.contains { id in
            guard let trait = engine.content.traits.first(where: { $0.id == id }) else { return false }
            return trait.name.lowercased().contains(query)
        }
    }

    private var rosterHeader: some View {
        HStack {
            Text("Roster")
            Spacer()
            Picker("Sort by", selection: $sortOrder) {
                ForEach(SortOrder.allCases) { order in
                    Text(order.rawValue).tag(order)
                }
            }
            .pickerStyle(.menu)
            .font(.caption)
            .textCase(nil)
            .accessibilityLabel("Sort the roster")
            .accessibilityValue(sortOrder.rawValue)
        }
    }

    // MARK: - Bulk assign

    /// "Everyone onto Nimbus Notes" — the move you want on the day before a
    /// deadline, without twelve taps.
    @ViewBuilder
    private var bulkAssignRow: some View {
        let hired = engine.state.employees.filter { !$0.isFounder }
        if !hired.isEmpty {
            Menu {
                if let product = engine.state.productInDevelopment {
                    bulkButton(
                        .product(product.id),
                        label: "Everyone → \(product.name)",
                        systemImage: "hammer.fill"
                    )
                }
                ForEach(engine.state.activeContracts) { job in
                    bulkButton(
                        .contract(job.id),
                        label: "Everyone → \(job.clientName)",
                        systemImage: "briefcase.fill"
                    )
                }
                bulkButton(.research, label: "Everyone → Research", systemImage: "flask.fill")
                bulkButton(.idle, label: "Everyone → Idle", systemImage: "moon.zzz.fill")
            } label: {
                HStack {
                    Label("Assign everyone", systemImage: "person.3.sequence.fill")
                        .font(.system(.headline, design: .rounded))
                        .foregroundStyle(Theme.accent)
                    Spacer()
                    Text("\(hired.count) staff")
                        .font(Theme.Typography.number(.caption, weight: .regular))
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityLabel("Assign the whole team to one thing")
        }
    }

    private func bulkButton(
        _ assignment: Assignment,
        label: String,
        systemImage: String
    ) -> some View {
        Button {
            // The founder keeps their own assignment: their time is
            // managed on the Life tab, not here.
            for employee in engine.state.employees
            where !employee.isFounder && employee.assignment != assignment {
                engine.send(.assign(employeeID: employee.id, to: assignment))
            }
        } label: {
            Label(label, systemImage: systemImage)
        }
    }

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
                .animation(Theme.Motion.valueChange, value: totalPayroll)
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
                            .font(Theme.Typography.number(.caption, weight: .regular))
                            .foregroundStyle(.secondary)
                        if !employee.isFounder {
                            MoodFace(morale: employee.morale)
                        }
                    }
                }
                .accessibilityElement(children: .combine)

                Spacer(minLength: Theme.Spacing.sm)

                AssignmentMenu(engine: engine, employee: employee)
            }

            if !employee.traits.isEmpty {
                TraitChipRow(traits: employee.traits, content: engine.content)
            }

            SkillBars(skills: employee.skills)
        }
        .padding(.vertical, Theme.Spacing.xs)
    }
}

/// Morale as a face, not a dot: you can read the room at a glance.
struct MoodFace: View {
    let morale: Double

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: symbol)
                .font(.caption)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(lifeMeterTint(morale))
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label), morale \(Int(morale.rounded())) out of 100")
    }

    private var symbol: String {
        switch morale {
        case ..<20: "face.dashed.fill"
        case ..<40: "cloud.rain.fill"
        case ..<60: "face.smiling"
        case ..<80: "face.smiling.inverse"
        default: "star.circle.fill"
        }
    }

    private var label: String {
        switch morale {
        case ..<20: "Miserable"
        case ..<40: "Unhappy"
        case ..<60: "Fine"
        case ..<80: "Happy"
        default: "Thriving"
        }
    }
}

// MARK: - Social activity icons

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
