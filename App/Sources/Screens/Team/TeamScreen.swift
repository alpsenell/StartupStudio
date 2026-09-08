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
        case attention = "Needs attention"
        case tenure = "Tenure"
        case role = "Role"
        case morale = "Morale"
        case salary = "Salary"

        var id: String { rawValue }
    }

    /// The two ways to look at the same people: a list you can sort and
    /// search, or the shape they make.
    private enum TeamView: String, CaseIterable, Identifiable {
        case roster = "Roster"
        case chart = "Org chart"

        var id: String { rawValue }
    }

    @State private var teamView: TeamView = .roster
    /// Whether the debug `-autoRoute` landing has already been taken.
    @State private var tookLaunchRoute = false
    @State private var showingHiring = false
    @State private var employeeToFire: Employee?
    @State private var employeeToManage: Employee?
    @State private var search = ""
    @State private var sortOrder: SortOrder = .tenure
    /// Picked once on appear: when anybody has something to say, the
    /// roster opens on it.
    @State private var choseDefaultSort = false

    @Environment(AppRouter.self) private var router

    var body: some View {
        NavigationStack {
            // Roster or chart, switched by a picker pinned under the HUD:
            // this tab hides the navigation bar (an opaque HUD sits over
            // it), so a "toolbar" toggle lives in the content, the same way
            // hiring and the team dinner do.
            VStack(spacing: 0) {
                Picker("How to look at the team", selection: $teamView) {
                    ForEach(TeamView.allCases) { view in
                        Text(view.rawValue).tag(view)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.top, Theme.Spacing.md)
                .padding(.bottom, Theme.Spacing.sm)
                .background(Theme.screenBackground)
                .accessibilityLabel("Roster or org chart")

                switch teamView {
                case .roster:
                    rosterList
                case .chart:
                    OrgChartView(engine: engine) { employee in
                        Haptics.tap()
                        employeeToManage = employee
                    }
                }
            }
            // The HUD inset lives on the stack's root content (this VStack),
            // not on the NavigationStack, so the picker lands directly below
            // the HUD and any pushed destination shows the navigation bar.
            .withTopHUD(engine: engine)
            .background(Theme.screenBackground)
            // MARK: N5 (office secrets)
            // The one flag `OfficeSecretsSystem` reads before anything
            // else: the founder has looked at their own team. A pacing bot
            // and a headless pass never switch tabs, so they never set it
            // and never have a secret.
            .task {
                engine.send(.watchTheOffice)
                DebugLaunch.startAutoSecret(engine: engine)
            }
            // MARK: end N5
            .sensoryFeedback(.success, trigger: engine.state.lastTeamDinnerDay)
            .navigationTitle("Team")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .onChange(of: router.pendingPush, initial: true) { _, _ in
                // A headless screenshot pass cannot tap the picker:
                // `-autoRoute orgChart` opens the chart, once.
                if !tookLaunchRoute {
                    tookLaunchRoute = true
                    // MARK: Iteration 11 — a launch route per lane, consumed first
                    // MARK: N2 (people menus)
                    // `-autoRoute peopleTeam` opens the manage sheet on
                    // the first person on the roster, which is where the
                    // employee's people menu hangs.
                    if Route.launchRoute == .peopleTeamMenu {
                        employeeToManage = engine.state.employees.first { !$0.isFounder }
                        return
                    }
                    // MARK: N5 (office secrets)
                    if Route.launchRoute == .secrets {
                        teamView = .roster
                        return
                    }
                    // MARK: end of Iteration 11
                    // MARK: Iteration 11, wave two
                    // MARK: W3 (espionage)
                    // MARK: end of Iteration 11, wave two
                    if Route.launchRoute == .orgChart {
                        teamView = .chart
                        return
                    }
                }
                if router.take(.orgChart) {
                    teamView = .chart
                }
            }
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

    /// The list: hiring and the whole-team moves at the top, then everybody.
    private var rosterList: some View {
        List {
            // MARK: N5 (office secrets)
            // What the room is keeping from you, and the six things you
            // can do about it. It leads the tab while it is running — a
            // thread in the office outranks the hiring pool — and shows
            // nothing at all until one starts. The `.task` on the stack is
            // what lets one start, and only a player ever runs it.
            Section {
                SecretsCard(engine: engine)
            }
            // MARK: end N5

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
                        Text(hiringCaption)
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
                // Departments form by hiring the matching role, so the
                // card lives where the hiring happens (it led HQ before).
                DepartmentsCard(engine: engine)
                // The rules the founder's answers became. Only once
                // there is one: a rule can only be made by somebody
                // asking, never from a card.
                if !engine.state.staffMemory.policies.isEmpty {
                    PoliciesCard(engine: engine)
                }
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
        .onAppear {
            guard !choseDefaultSort else { return }
            choseDefaultSort = true
            if !EmployeeStatus.roster(in: engine.state, balance: engine.balance, content: engine.content).isEmpty {
                sortOrder = .attention
            }
        }
    }

    /// "3 candidates", or when the pool is empty, when the next batch lands.
    private var hiringCaption: String {
        let count = engine.state.candidatePool.count
        guard count == 0 else { return "\(count) candidate\(count == 1 ? "" : "s")" }
        let refresh = max(1, engine.balance.candidateRefreshDays)
        let days = refresh - (engine.state.day % refresh)
        return days == refresh ? "New batch today" : "Next batch in \(days) day\(days == 1 ? "" : "s")"
    }

    // MARK: - Roster

    /// Everyone matching the search, in the chosen order. The founder
    /// always leads, whatever the sort — they are not a row you compare.
    private var roster: [Employee] {
        let matching = engine.state.employees.filter(matchesSearch)
        return matching.sorted { lhs, rhs in
            if lhs.isFounder != rhs.isFounder { return lhs.isFounder }
            switch sortOrder {
            case .attention:
                let l = EmployeeStatus.of(lhs, in: engine.state, balance: engine.balance, content: engine.content)
                let r = EmployeeStatus.of(rhs, in: engine.state, balance: engine.balance, content: engine.content)
                switch (l, r) {
                case let (l?, r?) where l.kind != r.kind: return l.kind < r.kind
                case (.some, .none): return true
                case (.none, .some): return false
                default: break
                }
                if lhs.hiredDay != rhs.hiredDay { return lhs.hiredDay < rhs.hiredDay }
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
                    // The week's one fact, where the fix is.
                    if let status = EmployeeStatus.of(employee, in: engine.state, balance: engine.balance, content: engine.content) {
                        Label(status.text, systemImage: status.systemImage)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(status.tint)
                            .lineLimit(1)
                    } else if employee.isFounder, employee.assignment == .idle {
                        Text("Idle · joins the next product")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .accessibilityElement(children: .combine)

                Spacer(minLength: Theme.Spacing.sm)

                AssignmentMenu(engine: engine, employee: employee)
            }

            if !employee.traits.isEmpty {
                TraitChipRow(
                    traits: employee.traits, content: engine.content,
                    revealedCount: TraitChipRow.revealedCount(for: employee, day: engine.state.day)
                )
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
