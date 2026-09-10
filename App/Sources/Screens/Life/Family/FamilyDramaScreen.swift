import SwiftUI
import TycoonEngine

/// Iteration 11, wave two — W2. The room the family drama lives in: the
/// people, the paperwork, and the four doors (the confrontation, the
/// settlement, the hearing, the will).
struct FamilyDramaScreen: View {
    let engine: GameEngine
    /// Opens the settlement over this screen; `LifeScreen` owns it so a
    /// launch route can arm it.
    @Binding var showingDivorce: Bool

    @Environment(GameShell.self) private var injectedShell: GameShell?
    /// See `GameShell.shared`: read optionally, because SwiftUI updates
    /// this property for presented content before the environment is
    /// installed and the non-optional form traps there.
    private var shell: GameShell { injectedShell ?? .shared }

    @State private var showingWill = false

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                if engine.state.familyDrama.isConfrontationOpen {
                    confrontationCard
                }
                if let ask = engine.state.familyDrama.pendingAsk,
                   let kind = FamilyAsk(rawValue: ask.askStage) {
                    askCard(kind)
                }
                peopleCard
                if engine.state.life.family.stage != .single
                    || engine.state.familyDrama.settlement != nil
                    || engine.state.familyDrama.leaving != nil { // K7: after a packed bag
                    marriageCard
                }
                if !engine.state.life.family.children.isEmpty {
                    custodyCard
                }
                willCard
            }
            .padding(Theme.Spacing.lg)
        }
        .background(Theme.screenBackground)
        .navigationTitle("The rest of the family")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingDivorce) { FamilyDivorceSheet(engine: engine) }
        .sheet(isPresented: $showingWill) { FamilyWillSheet(engine: engine) }
        .sheet(isPresented: confrontationBinding) { FamilyConfrontationSheet(engine: engine) }
        .sheet(isPresented: funeralBinding) { FamilyFuneralSheet(engine: engine) }
        .onAppear {
            engine.send(.openFamilyRoom)
            armDebugSheetIfAsked()
        }
    }

    private var confrontationBinding: Binding<Bool> {
        .init(
            get: { engine.state.familyDrama.isConfrontationOpen && armedConfrontation },
            set: { armedConfrontation = $0 }
        )
    }

    private var funeralBinding: Binding<Bool> {
        .init(
            get: { engine.state.familyDrama.isFuneralOpen && armedFuneral },
            set: { armedFuneral = $0 }
        )
    }

    @State private var armedConfrontation = false
    @State private var armedFuneral = false
    @State private var tookDebugSheet = false

    /// `-autoFamily <stage>` can land with a sheet open, the same way
    /// `-autoRoute courtroom` lands in the hearing. Once per push.
    private func armDebugSheetIfAsked() {
        guard !tookDebugSheet, let sheet = FamilyDramaDebug.armedSheet else { return }
        tookDebugSheet = true
        switch sheet {
        case "confrontation": armedConfrontation = true
        case "funeral": armedFuneral = true
        case "will": showingWill = true
        default: break
        }
    }

    // MARK: - They know

    private var confrontationCard: some View {
        CardView("Tonight", systemImage: "exclamationmark.bubble.fill") {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                Text("They know about it. The house is very quiet and neither of you has cooked.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Have the conversation", systemImage: "bubble.left.and.bubble.right.fill") {
                    armedConfrontation = true
                    Haptics.tap()
                }
                .buttonStyle(.pressable)
                .font(.footnote.weight(.semibold))
            }
        }
    }

    // MARK: - The ask

    private func askCard(_ ask: FamilyAsk) -> some View {
        CardView(ask.title, systemImage: "hand.raised.fill") {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                Text(ask.body)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: Theme.Spacing.sm) {
                    Button(ask.yesLabel) { answer(true) }
                        .buttonStyle(.pressable)
                        .font(.footnote.weight(.semibold))
                    Button("Not this time") { answer(false) }
                        .buttonStyle(.pressable)
                        .font(.footnote.weight(.semibold))
                }
                Text(costLine(ask))
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func costLine(_ ask: FamilyAsk) -> String {
        let config = engine.balance.familyDrama
        switch ask {
        case .job: return "\(config.siblingSalary.money) a week on the payroll · bond +\(Int(config.askYesBond))"
        case .stake: return "\(Int(config.siblingStakePoints))% of the company · bond +\(Int(config.askYesBond))"
        case .loan: return "\(config.siblingLoan.money) out of your wallet · bond +\(Int(config.askYesBond))"
        }
    }

    private func answer(_ accept: Bool) {
        Haptics.commit()
        shell.toasts.send(
            .answerFamilyAsk(accept: accept), to: engine,
            ack: accept ? "Done." : "Not this time.",
            rejected: "Nothing to answer.", icon: "hand.raised.fill"
        )
    }

    // MARK: - The people

    private var peopleCard: some View {
        let relatives = engine.state.familyRelatives(names: engine.content.names)
        return CardView("The people you did not choose", systemImage: "person.3.fill") {
            VStack(spacing: Theme.Spacing.sm) {
                ForEach(relatives) { relative in
                    FamilyRelativeRow(
                        relative: relative,
                        record: engine.state.familyDrama.record(relative.relation),
                        day: engine.state.day,
                        cooldownDays: engine.balance.familyDrama.visitCooldownDays,
                        // MARK: J1 (doors)
                        visit: { visit(relative.relation) },
                        careNote: DoorCopy.careNote(relative.relation, state: engine.state, content: engine.content)
                        // MARK: end J1
                    )
                }
                if engine.state.life.family.stage != .single {
                    Divider()
                    spareRoomRow
                }
            }
        }
    }

    private var spareRoomRow: some View {
        let occupied = engine.state.familyDrama.record(.motherInLaw)?.movedInDay != nil
        let config = engine.balance.familyDrama
        return HStack(alignment: .top, spacing: Theme.Spacing.sm) {
            Image(systemName: "bed.double.fill")
                .font(.footnote)
                .foregroundStyle(occupied ? Theme.warning : .secondary)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(occupied ? "The in-laws are in the spare room" : "The spare room is empty")
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                Text(occupied
                    ? "\(config.inLawsWeeklySaving.money) a week saved · mood \(Int(config.inLawsMoodDrift)) · affection +\(Int(config.inLawsAffectionDrift))"
                    : "\(config.inLawsWeeklySaving.money) a week saved · mood \(Int(config.inLawsMoodDrift)) a week")
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Button(occupied ? "Ask them to go" : "Offer it") {
                Haptics.commit()
                shell.toasts.send(
                    .familySpareRoom(accept: !occupied), to: engine,
                    rejected: "There is nobody to ask.", icon: "bed.double.fill"
                )
            }
            .buttonStyle(.pressable)
            .font(.caption.weight(.semibold))
        }
    }

    private func visit(_ relation: FamilyRelation) {
        Haptics.commit()
        shell.toasts.send(
            .seeRelative(relation), to: engine,
            ack: "An evening.", rejected: "Not this week.", icon: "figure.2"
        )
    }

    // MARK: - The marriage

    private var marriageCard: some View {
        CardView("The marriage", systemImage: "heart.slash.fill") {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                if let settlement = engine.state.familyDrama.settlement {
                    Text("It was settled on day \(settlement.day). \(settlement.lawyer == CrimeLawyer.silk.rawValue ? "Expensively." : "Cheaply.")")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    // MARK: K7 (partner and diary)
                    // The ex on the cap table, and in the address book.
                    FamilyExSliceView(engine: engine)
                    // MARK: end K7
                } else if let reason = engine.state.familyDivorceRefusal {
                    Text(reason)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Everything either of you owns is on one table and somebody has to divide it.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Button("Divide the estate", systemImage: "rectangle.split.2x1.fill") {
                        showingDivorce = true
                        Haptics.tap()
                    }
                    .buttonStyle(.pressable)
                    .font(.footnote.weight(.semibold))
                }
            }
        }
    }

    // MARK: - Custody

    private var custodyCard: some View {
        let refusal = engine.state.familyCustodyRefusal(balance: engine.balance)
        let standing = engine.state.familyCustodyStanding(balance: engine.balance)
        let likely = FamilyDrama.custodyVerdict(standing, balance: engine.balance.familyDrama)
        return CardView("The children", systemImage: "building.columns.fill") {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                if let verdict = engine.state.familyDrama.custody {
                    Text(verdict.displayName)
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(verdict.keepsTheHouse ? Theme.positiveCash : Theme.warning)
                    Text(verdict.closing)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    FamilyEvidenceLedger(engine: engine)
                    Text("On today's diary, a court would probably say: \(likely.displayName.lowercased()).")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                    Button(
                        refusal ?? "File for custody · \(engine.balance.familyDrama.custodyFilingFee.money)",
                        systemImage: "doc.text.fill"
                    ) {
                        Haptics.commit()
                        shell.toasts.send(
                            .fileCustody, to: engine,
                            ack: "It is listed.", rejected: refusal ?? "Not today.",
                            icon: "building.columns.fill"
                        )
                    }
                    .buttonStyle(.pressable)
                    .font(.footnote.weight(.semibold))
                    .disabled(refusal != nil)
                }
            }
        }
    }

    // MARK: - The will

    private var willCard: some View {
        CardView("The will", systemImage: "signature") {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                if let name = engine.state.familyDrama.heirName {
                    Text("Everything goes to \(name).")
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                } else {
                    Text("There is no will. If this ends badly, the company is an argument.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Button(
                    engine.state.familyDrama.heirName == nil ? "Name an heir" : "Change it",
                    systemImage: "pencil.and.list.clipboard"
                ) {
                    showingWill = true
                    Haptics.tap()
                }
                .buttonStyle(.pressable)
                .font(.footnote.weight(.semibold))
            }
        }
    }
}

// MARK: - One relative

private struct FamilyRelativeRow: View {
    let relative: FamilyRelative
    let record: FamilyKinRecord?
    let day: Int
    let cooldownDays: Int
    let visit: () -> Void
    // MARK: J1 (doors)
    /// Where the care door put them, when it was not the home.
    var careNote: String? = nil
    // MARK: end J1

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.md) {
            PixelPortrait(seed: relative.appearanceSeed, size: 40)
                .opacity(record?.isAlive == false ? 0.4 : 1)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(relative.name)
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                Text(subtitle)
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                if record?.isAlive != false {
                    PeopleBar(value: record?.bond ?? FamilyKinRecord.defaultBond, tint: Theme.romance)
                }
            }
            Spacer(minLength: 0)
            if record?.isAlive != false {
                Button(waitDays > 0 ? "\(waitDays)d" : "See them") { visit() }
                    .buttonStyle(.pressable)
                    .font(.caption.weight(.semibold))
                    .disabled(waitDays > 0)
            }
        }
    }

    private var waitDays: Int {
        guard let last = record?.lastSeenDay else { return 0 }
        return max(0, cooldownDays - (day - last))
    }

    private var subtitle: String {
        if let died = record?.diedDay { return "\(relative.relation.shortName) · died day \(died)" }
        // MARK: J1 (doors)
        if record?.isInCare == true, let careNote { return "\(relative.caption) · \(careNote)" }
        // MARK: end J1
        if record?.isInCare == true { return "\(relative.caption) · in a home" }
        if record?.employeeID != nil { return "\(relative.caption) · on the payroll" }
        if let stake = record?.stakePoints, stake > 0 {
            return "\(relative.caption) · holds \(Int(stake.rounded()))%"
        }
        if let lent = record?.lentAmount, lent > 0 {
            return "\(relative.caption) · owes you \(lent.money)"
        }
        return relative.caption
    }
}

// MARK: - The evidence

/// What the children's ledgers add up to, in a family court's arithmetic —
/// the same table `FamilyDrama.evidenceWeight` grades with, printed.
struct FamilyEvidenceLedger: View {
    let engine: GameEngine

    var body: some View {
        let tallies = tally()
        VStack(alignment: .leading, spacing: 6) {
            Text("WHAT THEY REMEMBER")
                .font(.caption2.weight(.bold))
                .kerning(0.8)
                .foregroundStyle(.secondary)
            if tallies.isEmpty {
                Text("Nothing on either side yet.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            ForEach(tallies, id: \.label) { row in
                HStack {
                    Text(row.label)
                        .font(.caption)
                    Spacer(minLength: Theme.Spacing.sm)
                    Text("\(row.count)×")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.tertiary)
                    Text(row.points > 0 ? "for you" : "against you")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(row.points > 0 ? Theme.positiveCash : Theme.negativeCash)
                }
            }
        }
    }

    private func tally() -> [(label: String, count: Int, points: Double)] {
        var counts: [ChildMemoryKind: Int] = [:]
        for child in engine.state.life.family.children {
            for memory in child.memories {
                guard let kind = ChildMemoryKind(rawValue: memory.kind) else { continue }
                let weight = FamilyDrama.evidenceWeight(kind)
                guard weight != 0 else { continue }
                counts[kind, default: 0] += 1
            }
        }
        return counts
            .map { (label($0.key), $0.value, FamilyDrama.evidenceWeight($0.key)) }
            .sorted { abs($0.2) > abs($1.2) || (abs($0.2) == abs($1.2) && $0.0 < $1.0) }
    }

    private func label(_ kind: ChildMemoryKind) -> String {
        switch kind {
        case .birthdayKept: "Birthdays kept"
        case .missedBirthday: "Birthdays missed"
        case .evening: "Evenings that were theirs"
        case .internSummer: "Summers at the studio"
        case .internQuit: "Summers that ended early"
        case .burnout: "The burnouts"
        case .hospital: "The hospital"
        case .eviction: "The eviction"
        case .wedding: "The wedding"
        case .launch: "Launch nights"
        case .sabbatical: "The time off"
        case .chapter, .exit, .grewUp: "Growing up"
        }
    }
}
