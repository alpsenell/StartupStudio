import SwiftUI
import TycoonEngine

/// One-on-one with an employee: morale, seniority, and the management
/// levers — praise, raise/cut, promote/demote, training, firing.
/// The founder never appears here (their levers live on the Life tab).
struct EmployeeManageSheet: View {
    let engine: GameEngine
    let employeeID: UUID

    @Environment(\.dismiss) private var dismiss
    @State private var confirmingFire = false

    /// Live lookup so the sheet tracks state changes while open.
    private var employee: Employee? {
        engine.state.employee(id: employeeID)
    }

    var body: some View {
        NavigationStack {
            if let employee {
                List {
                    headerSection(employee)
                    moraleSection(employee)
                    relationshipSection(employee)
                    salarySection(employee)
                    careerSection(employee)
                    trainingSection(employee)
                    fireSection(employee)
                }
                .navigationTitle(employee.name)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                    }
                }
            } else {
                // Fired, quit, or otherwise gone while the sheet was open.
                ContentUnavailableView(
                    "No longer on the team",
                    systemImage: "person.slash",
                    description: Text("This person has left the company.")
                )
            }
        }
        .presentationDetents([.large])
    }

    // MARK: - Sections

    private func headerSection(_ employee: Employee) -> some View {
        Section {
            HStack(spacing: Theme.Spacing.md) {
                PixelPortrait(seed: employee.appearanceSeed, isFounder: false)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: Theme.Spacing.xs + 2) {
                        Text(employee.name)
                            .font(.system(.headline, design: .rounded))
                        RoleBadge(role: employee.role)
                        LevelBadge(level: employee.level)
                    }
                    Text("\(employee.weeklySalary.money)/wk · hired day \(employee.hiredDay)")
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            SkillBars(skills: employee.skills)
        }
    }

    private func moraleSection(_ employee: Employee) -> some View {
        let staff = engine.balance.staff
        let performance = employee.performanceMultiplier(balance: engine.balance)
        let onCooldown = employee.lastPraisedDay.map {
            engine.state.day - $0 < staff.praiseCooldownDays
        } ?? false

        return Section("Morale & performance") {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                HStack {
                    Text("Morale")
                        .font(.subheadline)
                    Spacer()
                    Text("\(Int(employee.morale.rounded()))/100")
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(lifeMeterTint(employee.morale))
                }
                ProgressView(value: employee.morale, total: 100)
                    .tint(lifeMeterTint(employee.morale))
                Text(String(format: "Output ×%.2f from morale and seniority.", performance))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if employee.morale < staff.quitMoraleThreshold {
                    Text("Miserable — they'll quit if this doesn't improve soon.")
                        .font(.caption)
                        .foregroundStyle(Theme.negativeCash)
                }
            }
            .padding(.vertical, Theme.Spacing.xs)

            Button {
                engine.send(.praise(employeeID: employeeID))
            } label: {
                Label(
                    onCooldown ? "Praised recently" : "Praise their work",
                    systemImage: "hands.clap.fill"
                )
            }
            .disabled(onCooldown)
        }
    }

    @ViewBuilder
    private func relationshipSection(_ employee: Employee) -> some View {
        let social = engine.balance.social
        let onCooldown = employee.lastSocialDay.map {
            engine.state.day - $0 < social.socialCooldownDays
        } ?? false
        let friends = engine.state.friendships
            .filter { $0.involves(employee.id) }
            .sorted { $0.strength > $1.strength }

        Section {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                HStack {
                    Text("Loyalty")
                        .font(.subheadline)
                    Spacer()
                    Text("\(Int(employee.loyalty.rounded()))/100")
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(lifeMeterTint(employee.loyalty))
                }
                ProgressView(value: employee.loyalty, total: 100)
                    .tint(lifeMeterTint(employee.loyalty))
                Text("Loyal people turn down rival offers and hold on through rough patches.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if !friends.isEmpty {
                    // Wrapping isn't needed at 1–3 friends; a plain HStack reads fine.
                    HStack(spacing: Theme.Spacing.xs) {
                        ForEach(Array(friends.enumerated()), id: \.offset) { _, friendship in
                            if let otherID = friendship.other(than: employee.id),
                               let friend = engine.state.employee(id: otherID) {
                                FriendChip(
                                    name: friend.name,
                                    seed: friend.appearanceSeed,
                                    strength: friendship.strength
                                )
                            }
                        }
                    }
                }
            }
            .padding(.vertical, Theme.Spacing.xs)

            Button {
                engine.send(.grabCoffee(employeeID: employeeID))
            } label: {
                Label("Grab coffee (\(social.coffeeCost.money))", systemImage: "cup.and.saucer.fill")
            }
            .disabled(onCooldown || engine.state.company.cash < social.coffeeCost)

            Button {
                engine.send(.oneOnOne(employeeID: employeeID))
            } label: {
                Label("Have a 1-on-1", systemImage: "bubble.left.and.bubble.right.fill")
            }
            .disabled(onCooldown)

            Button {
                engine.send(.giveGift(employeeID: employeeID))
            } label: {
                Label("Give a gift (\(social.giftCost.money))", systemImage: "gift.fill")
            }
            .disabled(onCooldown || engine.state.company.cash < social.giftCost)
        } header: {
            Text("Relationship")
        } footer: {
            if onCooldown {
                Text("You've spent time together recently — give it a few days.")
            }
        }
    }

    private func salarySection(_ employee: Employee) -> some View {
        let fair = EmployeeSalaryGuide.fairPay(for: employee, balance: engine.balance)
        let raised = Int((Double(employee.weeklySalary) * 1.1).rounded())
        let cut = max(1, Int((Double(employee.weeklySalary) * 0.9).rounded()))

        return Section("Salary") {
            LabeledContent("Current") {
                Text("\(employee.weeklySalary.money)/wk").monospacedDigit()
            }
            LabeledContent("Market rate") {
                Text("\(fair.money)/wk").monospacedDigit()
            }
            if Double(employee.weeklySalary) < Double(fair) * engine.balance.staff.underpaidThreshold {
                Text("Underpaid — morale is draining.")
                    .font(.caption)
                    .foregroundStyle(Theme.warning)
            }
            Button {
                engine.send(.adjustSalary(employeeID: employeeID, weeklySalary: raised))
            } label: {
                Label("Raise to \(raised.money)/wk", systemImage: "arrow.up.circle")
            }
            Button(role: .destructive) {
                engine.send(.adjustSalary(employeeID: employeeID, weeklySalary: cut))
            } label: {
                Label("Cut to \(cut.money)/wk", systemImage: "arrow.down.circle")
            }
        }
    }

    private func careerSection(_ employee: Employee) -> some View {
        Section("Career") {
            LabeledContent("Level") {
                Text(employee.level.displayName)
            }
            if let next = employee.level.next {
                Button {
                    engine.send(.promote(employeeID: employeeID))
                } label: {
                    Label(
                        "Promote to \(next.displayName) (+\(Int(engine.balance.staff.promotionSalaryBump * 100))% salary)",
                        systemImage: "arrow.up.forward.circle.fill"
                    )
                }
            }
            if let previous = employee.level.previous {
                Button(role: .destructive) {
                    engine.send(.demote(employeeID: employeeID))
                } label: {
                    Label("Demote to \(previous.displayName)", systemImage: "arrow.down.forward.circle")
                }
            }
        }
    }

    private func trainingSection(_ employee: Employee) -> some View {
        let staff = engine.balance.staff
        let onCooldown = employee.lastTrainedDay.map {
            engine.state.day - $0 < staff.trainingCooldownDays
        } ?? false
        let unaffordable = engine.state.company.cash < staff.trainingCost

        return Section {
            ForEach(TrainableSkill.allCases, id: \.self) { skill in
                Button {
                    engine.send(.train(employeeID: employeeID, skill: skill))
                } label: {
                    Label("Train \(skill.displayName)", systemImage: skill.systemImage)
                }
                .disabled(onCooldown || unaffordable)
            }
        } header: {
            Text("Training")
        } footer: {
            if onCooldown {
                Text("Just finished a course — try again in a couple of weeks.")
            } else {
                Text("Costs \(staff.trainingCost.money), boosts the skill by \(Int(staff.trainingSkillBoost)).")
            }
        }
    }

    private func fireSection(_ employee: Employee) -> some View {
        Section {
            Button(role: .destructive) {
                confirmingFire = true
            } label: {
                Label("Fire \(employee.name)", systemImage: "person.badge.minus")
            }
            .confirmationDialog(
                "Fire \(employee.name)?",
                isPresented: $confirmingFire,
                titleVisibility: .visible
            ) {
                Button("Fire \(employee.name)", role: .destructive) {
                    engine.send(.fire(employeeID: employeeID))
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("No severance in the garage era.")
            }
        }
    }
}

// MARK: - Shared bits

/// Small seniority capsule ("SENIOR") shown next to names.
struct LevelBadge: View {
    let level: SeniorityLevel

    var body: some View {
        Text(level.displayName.uppercased())
            .font(.caption2.weight(.bold))
            .kerning(0.5)
            .foregroundStyle(.secondary)
            .padding(.horizontal, Theme.Spacing.xs + 2)
            .padding(.vertical, 2)
            .background(Theme.chipBackground, in: Capsule())
            .accessibilityLabel("\(level.displayName) level")
    }
}

/// The UI's one place for the fair-pay estimate shown in the salary section
/// (mirrors the engine's morale fairness rule).
enum EmployeeSalaryGuide {
    static func fairPay(for employee: Employee, balance: BalanceConfig) -> Int {
        Int((
            (Double(balance.salaryBase) + balance.salaryPerSkillPoint * employee.skills.total)
                * (1 + balance.staff.levelPayExpectation * Double(employee.level.rank))
        ).rounded())
    }
}

extension TrainableSkill {
    var displayName: String {
        switch self {
        case .coding: "Coding"
        case .design: "Design"
        case .marketing: "Marketing"
        }
    }

    var systemImage: String {
        switch self {
        case .coding: "chevron.left.forwardslash.chevron.right"
        case .design: "paintbrush.fill"
        case .marketing: "megaphone.fill"
        }
    }
}
