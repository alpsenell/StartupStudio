import SwiftUI
import TycoonContent
import TycoonEngine

/// One-on-one with an employee: morale, seniority, and the management
/// levers — praise, raise/cut, promote/demote, training, firing.
/// The founder never appears here (their levers live on the Life tab).
struct EmployeeManageSheet: View {
    let engine: GameEngine
    let employeeID: UUID

    @Environment(\.dismiss) private var dismiss
    @State private var confirmingFire = false
    @State private var confirmingCut = false
    /// The custom weekly salary the stepper holds, seeded from the
    /// employee's current pay the first time the sheet opens.
    @State private var customSalary: Int?

    /// Live lookup so the sheet tracks state changes while open.
    private var employee: Employee? {
        engine.state.employee(id: employeeID)
    }

    var body: some View {
        NavigationStack {
            if let employee {
                List {
                    headerSection(employee)
                    traitSection(employee)
                    moraleSection(employee)
                    relationshipSection(employee)
                    bondSection(employee)
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

    /// Who they are, and exactly what it costs you: the trait chips plus a
    /// line per trait spelling out the numbers it moves.
    @ViewBuilder
    private func traitSection(_ employee: Employee) -> some View {
        let explanations = TraitEffects.explanations(for: employee, content: engine.content)
        if !explanations.isEmpty {
            Section {
                TraitChipRow(traits: employee.traits, content: engine.content)
                    .padding(.vertical, Theme.Spacing.xs)
                ForEach(Array(explanations.enumerated()), id: \.offset) { _, entry in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.name)
                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        Text(entry.detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .accessibilityElement(children: .combine)
                }
            } header: {
                Text("Personality")
            } footer: {
                Text("Traits come with the person and never change. They shape output, learning, mood, patience and how hard a rival finds it to hire them away.")
            }
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
                ForEach(Array(moraleCauses(employee).enumerated()), id: \.offset) { _, cause in
                    Label(cause.text, systemImage: cause.isGood ? "arrow.up" : "arrow.down")
                        .font(.caption)
                        .foregroundStyle(cause.isGood ? Theme.positiveCash : Theme.warning)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if employee.morale < staff.quitMoraleThreshold {
                    Text(quitWarning(employee))
                        .font(.caption)
                        .foregroundStyle(Theme.negativeCash)
                        .fixedSize(horizontal: false, vertical: true)
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

    /// Why this person's mood is where it is, read off the same balance the
    /// engine settles morale from — pay fairness, the office, amenities,
    /// HR, and their own personality.
    private func moraleCauses(_ employee: Employee) -> [(text: String, isGood: Bool)] {
        let balance = engine.balance
        let staff = balance.staff
        let state = engine.state
        var causes: [(String, Bool)] = []

        let fair = Double(EmployeeSalaryGuide.fairPay(for: employee, balance: balance))
        let ratio = fair > 0 ? Double(employee.weeklySalary) / fair : 1
        if ratio < staff.underpaidThreshold {
            causes.append(("Paid below the market rate", false))
        } else if ratio > staff.wellPaidThreshold {
            causes.append(("Paid well above the market rate", true))
        }

        let officeBonus = staff.officeMoraleBonus[state.company.officeTier.rawValue] ?? 0
        if officeBonus > 0 {
            causes.append(("The \(state.company.officeTier.displayName.lowercased()) is a nice place to work", true))
        } else if officeBonus < 0 {
            causes.append(("The \(state.company.officeTier.displayName.lowercased()) is grim", false))
        }

        let amenityBonus = Amenity.allCases
            .filter { state.hasAmenity($0) }
            .reduce(0.0) { $0 + balance.company.amenity($1).moraleBonus }
        if amenityBonus > 0 {
            causes.append(("Office perks", true))
        }
        if state.hasDepartment(.hr) {
            causes.append(("People & HR looks after them", true))
        }

        let traitDelta = TraitEffects.moraleTargetDelta(employee, content: engine.content)
        if traitDelta <= -2 {
            causes.append(("It's who they are — see Personality", false))
        } else if traitDelta >= 2 {
            causes.append(("It's who they are — see Personality", true))
        }
        return causes.map { (text: $0.0, isGood: $0.1) }
    }

    /// How long they will hold on, in their own terms — loyalty and their
    /// traits both buy patience.
    private func quitWarning(_ employee: Employee) -> String {
        let balance = engine.balance
        let patience = balance.staff.quitStreakDays
            + Int(employee.loyalty / balance.social.loyaltyQuitDivisor)
            + TraitEffects.quitStreakBonus(employee, content: engine.content)
        let left = max(0, patience - employee.lowMoraleStreakDays)
        return left <= 0
            ? "Miserable, and out of patience. They could resign any day."
            : "Miserable for \(employee.lowMoraleStreakDays) day"
                + "\(employee.lowMoraleStreakDays == 1 ? "" : "s"). "
                + "About \(left) more before they resign."
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

    /// The founder's *own* relationship with this person, as distinct from
    /// how they feel about the job.
    ///
    /// Everything above this section is the company's money: coffee, a
    /// gift, a raise. Everything in it is the founder's — their wallet,
    /// their evening, their energy — which is exactly why it is worth
    /// more, and why it is the only lever that keeps working when the
    /// company has no cash left.
    @ViewBuilder
    private func bondSection(_ employee: Employee) -> some View {
        let relationships = engine.balance.relationships
        let hangOutBlocker = engine.state.hangOutBlocker(
            employeeID: employeeID, balance: engine.balance
        )
        let mentorBlocker = engine.state.mentorBlocker(
            employeeID: employeeID, balance: engine.balance
        )

        Section {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                HStack {
                    Text("Bond with you")
                        .font(.subheadline)
                    Spacer()
                    Text("\(Int(employee.founderBond.rounded()))/100")
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(lifeMeterTint(employee.founderBond))
                }
                ProgressView(value: employee.founderBond, total: 100)
                    .tint(lifeMeterTint(employee.founderBond))
                Text(bondBlurb(employee))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, Theme.Spacing.xs)

            Button {
                engine.send(.hangOutWith(employeeID: employeeID))
            } label: {
                Label(
                    "Hang out (\(relationships.hangOut.cost.money) of your own)",
                    systemImage: "figure.2"
                )
            }
            .disabled(hangOutBlocker != nil)

            Menu {
                ForEach(TrainableSkill.allCases, id: \.self) { skill in
                    Button(skill.displayName) {
                        engine.send(.mentorEmployee(employeeID: employeeID, skill: skill))
                    }
                }
            } label: {
                Label("Mentor them", systemImage: "graduationcap.fill")
            }
            .disabled(mentorBlocker != nil)
        } header: {
            Text("You and them")
        } footer: {
            Text(bondFooter(hangOut: hangOutBlocker, mentor: mentorBlocker))
        }
    }

    private func bondBlurb(_ employee: Employee) -> String {
        switch employee.founderBond {
        case ..<20: "You barely know each other outside of standups."
        case ..<50: "You get on. They'd hear you out."
        case ..<80: "They're in your corner — and it shows in their work."
        default: "They'd follow you to the next company. Don't waste that."
        }
    }

    private func bondFooter(hangOut: String?, mentor: String?) -> String {
        if let hangOut, let mentor, hangOut == mentor { return hangOut }
        var lines: [String] = []
        if let hangOut { lines.append("Hang out: \(hangOut).") }
        if let mentor { lines.append("Mentor: \(mentor).") }
        guard lines.isEmpty else { return lines.joined(separator: " ") }
        return "Your time, not the company's. A close team works better, "
            + "stays longer, and turns down rivals."
    }

    private func salarySection(_ employee: Employee) -> some View {
        let fair = EmployeeSalaryGuide.fairPay(for: employee, balance: engine.balance)
        let raised = Int((Double(employee.weeklySalary) * 1.1).rounded())
        let cut = max(1, Int((Double(employee.weeklySalary) * 0.9).rounded()))
        let proposed = customSalary ?? employee.weeklySalary
        let step = max(10, employee.weeklySalary / 20)

        return Section {
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
                customSalary = cut
                confirmingCut = true
            } label: {
                Label("Cut to \(cut.money)/wk", systemImage: "arrow.down.circle")
            }

            // A named number, for matching an offer or landing exactly on
            // the market rate.
            Stepper(value: salaryBinding(default: employee.weeklySalary), in: 1...200_000, step: step) {
                HStack {
                    Text("Set to")
                    Spacer()
                    Text("\(proposed.money)/wk")
                        .monospacedDigit()
                        .foregroundStyle(proposed < employee.weeklySalary ? Theme.negativeCash : .primary)
                }
            }
            .accessibilityLabel("Custom weekly salary")
            .accessibilityValue("\(proposed.money) per week")

            Button {
                if proposed < employee.weeklySalary {
                    confirmingCut = true
                } else {
                    engine.send(.adjustSalary(employeeID: employeeID, weeklySalary: proposed))
                    customSalary = nil
                }
            } label: {
                Label("Apply \(proposed.money)/wk", systemImage: "checkmark.circle")
            }
            .disabled(proposed == employee.weeklySalary)
        } header: {
            Text("Salary")
        } footer: {
            Text("Pay below the market rate drains morale; pay above it lifts the ceiling. Matching a rival's offer is what keeps people.")
        }
        .confirmationDialog(
            "Cut \(employee.name) to \((customSalary ?? cut).money)/wk?",
            isPresented: $confirmingCut,
            titleVisibility: .visible
        ) {
            Button("Cut their pay", role: .destructive) {
                engine.send(.adjustSalary(
                    employeeID: employeeID, weeklySalary: customSalary ?? cut
                ))
                customSalary = nil
            }
            Button("Cancel", role: .cancel) { customSalary = nil }
        } message: {
            Text("A pay cut hits morale hard, and underpaid people start listening to rivals.")
        }
    }

    /// Backs the custom-salary stepper, seeding itself from the employee's
    /// current pay the first time it is read.
    private func salaryBinding(default current: Int) -> Binding<Int> {
        Binding(
            get: { customSalary ?? current },
            set: { customSalary = $0 }
        )
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
