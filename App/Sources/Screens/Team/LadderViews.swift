import SwiftUI
import TycoonContent
import TycoonEngine

// Iteration 15 — K3 (the ladder): the surfaces for promoted leads and
// options instead of pay (docs/product/iteration-15-pm/company.md §3, §4).
// Every number printed here is read off the engine (`LadderCrew`,
// `LadderGrantQuote`, `Employee.vestedEquity`) so a screen can never
// promise what the tick will not do.

// MARK: - The crew line

/// *8 people · ×0.59 each · lead: none*: the crowding factor every build
/// always had, finally printed on the build card and the Now card.
struct LadderCrewLine: View {
    let engine: GameEngine
    let productID: UUID

    var body: some View {
        if let crew = engine.state.ladderCrew(productID: productID, balance: engine.balance),
           crew.count > 0 {
            Label {
                // MARK: S1 (seating) — a mentor's cost is its own factor, after the lead's.
                Text(Self.sentence(crew) + (SeatingCopy.crewSuffix(state: engine.state, productID: productID, balance: engine.balance) ?? ""))
                // MARK: end S1
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(crew.leadsColliding ? Theme.warning : .secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: crew.leadName != nil ? "person.3.sequence.fill" : "person.3.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
            .task { LadderDebug.dressIfAsked(engine) }
        }
    }

    static func sentence(_ crew: LadderCrew) -> String {
        let people = crew.count == 1 ? "1 person" : "\(crew.count) people"
        guard crew.count > 1 else { return "\(people) · full speed" }
        let each = "×\(factor(crew.factor)) each"
        if crew.leadsColliding {
            return "\(people) · \(each) · two leads: they cancel out"
        }
        if let lead = crew.leadName {
            let first = lead.split(separator: " ").first.map(String.init) ?? lead
            return "\(people) · \(each) · lead: \(first) (×\(factor(crew.unledFactor)) without)"
        }
        return "\(people) · \(each) · lead: none"
    }

    static func factor(_ value: Double) -> String {
        String(format: "%.2f", value)
    }
}

// MARK: - The promote button's consequence

/// What making this person lead would do, in the words on the button:
/// the build's factor before and after, or why it would do nothing.
@MainActor
enum LadderPromoteCopy {
    /// The second line under *Promote to Lead*; `nil` below senior.
    static func preview(for employee: Employee, engine: GameEngine) -> String? {
        guard employee.level.next == .lead else { return nil }
        let state = engine.state
        let balance = engine.balance
        let idle = balance.ladder.leads.idleMoraleDelta
        guard case .product(let productID) = employee.assignment,
              let product = state.product(id: productID),
              let now = state.ladderCrew(productID: productID, balance: balance),
              let led = state.ladderCrewIfLed(by: employee.id, balance: balance)
        else {
            return "Nobody to lead off a build: morale target \(signed(idle)) until they run one"
        }
        if led.leadsColliding {
            return "\(product.name) already has a lead: two cancel out, nobody speeds up"
        }
        var pieces = ["\(product.name): ×\(LadderCrewLine.factor(now.factor)) → ×\(LadderCrewLine.factor(led.factor)) each"]
        if state.ladderLeadIsIdle(promoted(employee, day: state.day), balance: balance) {
            pieces.append("too few to lead, morale target \(signed(idle))")
        }
        return pieces.joined(separator: " · ")
    }

    /// The status line for somebody who is already a lead.
    static func status(for employee: Employee, engine: GameEngine) -> String? {
        guard employee.level == .lead else { return nil }
        guard let since = employee.leadSinceDay else {
            return "Hired in at lead: the title, not the room. Leads you promote run a build."
        }
        let state = engine.state
        let idle = engine.balance.ladder.leads.idleMoraleDelta
        if state.ladderLeadIsIdle(employee, balance: engine.balance) {
            return "Nothing to lead: fewer than \(engine.balance.ladder.leads.idleMinCrew) others on their build. Morale target \(signed(idle)) while it lasts."
        }
        if case .product(let productID) = employee.assignment,
           let product = state.product(id: productID),
           let crew = state.ladderCrew(productID: productID, balance: engine.balance) {
            if crew.leadsColliding {
                return "Shares \(product.name) with another lead. Neither of you speeds it up."
            }
            return "Runs \(product.name) since \(GameState.dateLabel(forDay: since)): ×\(LadderCrewLine.factor(crew.factor)) each, not ×\(LadderCrewLine.factor(crew.unledFactor))."
        }
        return nil
    }

    private static func promoted(_ employee: Employee, day: Int) -> Employee {
        var copy = employee
        copy.level = .lead
        copy.leadSinceDay = day
        return copy
    }

    static func signed(_ value: Double) -> String {
        value < 0 ? "−\(Int((-value).rounded()))" : "+\(Int(value.rounded()))"
    }
}

// MARK: - Options on the manage sheet

/// The *Options* section of a person's manage sheet: the trade in dollars
/// at today's valuation and the pay cut, with *Still yours* named on the
/// first grant — or, for a holder, what has vested and what would come
/// back if they walked today.
struct LadderOptionsSection: View {
    let engine: GameEngine
    let employee: Employee

    @State private var confirming: LadderGrantQuote?

    var body: some View {
        if !employee.isFounder, !employee.isCofounder {
            Section {
                if employee.holdsOptions {
                    holderRows
                } else {
                    ForEach(BalanceConfig.GrantBalance.sizes, id: \.self) { percent in
                        if let quote = engine.state.ladderGrantQuote(
                            employeeID: employee.id, percent: percent, balance: engine.balance
                        ) {
                            grantButton(quote)
                        }
                    }
                }
            } header: {
                Text("Options")
            } footer: {
                Text(footer)
            }
            .confirmationDialog(
                "Give \(firstName) \(confirming.map { "\($0.percent)%" } ?? "options")?",
                isPresented: Binding(get: { confirming != nil }, set: { if !$0 { confirming = nil } }),
                titleVisibility: .visible,
                presenting: confirming
            ) { quote in
                Button("Grant \(quote.percent)% · pay −\(quote.payCut.money)/wk") {
                    engine.send(.grantEquity(employeeID: employee.id, percent: quote.percent))
                }
                Button("Keep it", role: .cancel) {}
            } message: { quote in
                Text(
                    "\(quote.valueToday.money) of the company at today's valuation, vesting over four years. "
                        + (quote.closesStillYours ? "Still yours closes: that ending needs all of it." : "")
                )
            }
        }
    }

    private var firstName: String {
        employee.name.split(separator: " ").first.map(String.init) ?? employee.name
    }

    private func grantButton(_ quote: LadderGrantQuote) -> some View {
        Button {
            confirming = quote
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Label("Grant \(quote.percent)% · pay −\(quote.payCut.money)/wk", systemImage: "chart.pie.fill")
                Text("\(quote.percent)% of \(engine.state.companyValuation(balance: engine.balance).money) = \(quote.valueToday.money) over four years"
                    + (quote.closesStillYours ? " · Still yours closes" : ""))
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(quote.closesStillYours ? Theme.warning : .secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .disabled(quote.blocker != nil)
        .accessibilityHint(quote.blocker ?? "Asks before it grants")
    }

    @ViewBuilder
    private var holderRows: some View {
        let balance = engine.balance
        let day = engine.state.day
        let vested = employee.vestedEquity(day: day, balance: balance)
        let unvested = employee.unvestedEquity(day: day, balance: balance)
        let valuation = Double(engine.state.companyValuation(balance: balance))
        LabeledContent("Holds") {
            Text("\(employee.grantedEquity.oneDecimal)% · \(vested.formatted(.number.precision(.fractionLength(2)).locale(Theme.gameLocale)))% vested")
                .font(Theme.Typography.number(.body, weight: .regular))
        }
        LabeledContent("Worth today") {
            Text(Int((valuation * employee.grantedEquity / 100).rounded()).money)
                .font(Theme.Typography.number(.body, weight: .regular))
        }
        if let cliff = employee.cliffDay(balance: balance), day < cliff {
            LabeledContent("Cliff") {
                Text(GameState.dateLabel(forDay: cliff))
                    .font(Theme.Typography.number(.body, weight: .regular))
            }
        } else if let grantDay = employee.grantDay, unvested > 0 {
            LabeledContent("Fully vested") {
                Text(GameState.dateLabel(forDay: grantDay + balance.ladder.grants.vestDays))
                    .font(Theme.Typography.number(.body, weight: .regular))
            }
        }
        if let before = employee.salaryBeforeGrant {
            Text("Took \(max(0, before - employee.weeklySalary).money)/wk off \(before.money) for it. Fairness reads the \(before.money).")
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        Text(unvested > 0
            ? "If they leave today, \(GameState.ladderPoints(unvested)) comes back to you and they keep \(GameState.ladderPoints(vested))."
            : "Fully vested: if they leave, all of it goes with them.")
            .font(.caption)
            .monospacedDigit()
            .foregroundStyle(unvested > 0 ? Color.secondary : Theme.warning)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var footer: String {
        if employee.holdsOptions {
            return "A rival has to buy out what hasn't vested, so they call less. What has vested walks out with them — to the rival, if that's where they go."
        }
        let grants = engine.balance.ladder.grants
        let blocker = engine.state.ladderGrantBlocker(
            employeeID: employee.id, percent: BalanceConfig.GrantBalance.sizes[0], balance: engine.balance
        )
        let out = engine.state.ladderOptionsOutstanding
        return (blocker.map { "\($0) " } ?? "")
            + "Loyalty +\(Int(grants.loyalty)), bond +\(Int(grants.bond)). Vests over four years after a one-year cliff; leave before it and every point comes back. "
            + "Pool: \(GameState.ladderPoints(out)) of \(Int(grants.poolMax))% out. Every point is a point of the IPO, the buyout and the earn-out."
    }
}

// MARK: - The cap table's Team row

/// The Investors screen's cap table gains a *Team* row: everyone holding
/// options, vested and not, and alumni who kept what vested.
struct LadderTeamCapCard: View {
    let engine: GameEngine
    @State private var lifted = false

    var body: some View {
        card
            .sheet(isPresented: $lifted) {
                ScrollView { card.padding(Theme.Spacing.lg) }
                    .background(Theme.screenBackground)
            }
            .task {
                guard LadderDebug.liftsCapTable else { return }
                try? await Task.sleep(for: .seconds(4))
                lifted = true
            }
    }

    @ViewBuilder
    private var card: some View {
        let grants = engine.state.networking.grants.filter { $0.reason == .options }
        if grants.isEmpty {
            Color.clear.frame(height: 0)
                .task { LadderDebug.dressIfAsked(engine) }
        } else {
            let balance = engine.balance
            let valuation = Double(engine.state.companyValuation(balance: balance))
            let total = grants.reduce(0) { $0 + $1.percent }
            CardView("Team", systemImage: "person.3.sequence.fill") {
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    ForEach(grants) { grant in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(grant.name)
                                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                                Text(detail(grant))
                                    .font(.caption2)
                                    .monospacedDigit()
                                    .foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 0)
                            Text("\(grant.percent.oneDecimal)%")
                                .font(Theme.Typography.number(.subheadline))
                        }
                        .accessibilityElement(children: .combine)
                    }
                    Divider()
                    HStack {
                        Text("Team, at today's valuation")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(GameState.ladderPoints(total)) · \(Int((valuation * total / 100).rounded()).money)")
                            .font(Theme.Typography.number(.caption))
                    }
                    Text("Pool \(GameState.ladderPoints(total)) of \(Int(balance.ladder.grants.poolMax))%.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func detail(_ grant: EquityGrant) -> String {
        guard let employee = engine.state.employee(id: grant.id) else {
            return "Left, kept what vested"
        }
        let vested = employee.vestedEquity(day: engine.state.day, balance: engine.balance)
        if vested <= 0, let cliff = employee.cliffDay(balance: engine.balance) {
            return "On payroll · cliff \(GameState.dateLabel(forDay: cliff))"
        }
        return "On payroll · \(vested.formatted(.number.precision(.fractionLength(2)).locale(Theme.gameLocale)))% vested"
    }
}

// MARK: - Event copy

enum LadderEventCopy {
    static func entry(for event: GameEvent) -> (icon: String, message: String, day: Int, tint: Color)? {
        switch event {
        case .ladderEquityGranted(_, let name, let percent, let payCut, let day):
            return (
                "chart.pie.fill",
                "\(name) took \(GameState.ladderPoints(percent)) of the company and \(payCut.money)/wk less pay",
                day,
                Theme.accent
            )
        case .ladderOptionsSettled(_, let name, let kept, let returned, let day):
            let message: String = if kept <= 0 {
                "\(name) left before the cliff. Their \(GameState.ladderPoints(returned)) came back to you"
            } else if returned <= 0 {
                "\(name) left fully vested, with \(GameState.ladderPoints(kept)) of the company"
            } else {
                "\(name) left with \(GameState.ladderPoints(kept)) vested. \(GameState.ladderPoints(returned)) came back to you"
            }
            return ("chart.pie", message, day, kept > 0 ? Theme.warning : Theme.positiveCash)
        default:
            return nil
        }
    }
}

// MARK: - Debug

/// `-autoLadder` dresses the loaded company once for the lane's
/// screenshots: one senior (or the best mid, twice) promoted to lead on
/// every build, and options for two people who are not leads.
/// `-autoRoute k3-lead | k3-options | k3-holder` opens the manage sheet on
/// a senior on a build, a non-holder, or a holder. DEBUG only.
@MainActor
enum LadderDebug {
    private static var dressed = false

    static func dressIfAsked(_ engine: GameEngine) {
        #if DEBUG
        guard DebugLaunch.ladderDresses, !dressed else { return }
        dressed = true
        var promoted: Set<UUID> = []
        for product in engine.state.productsInDevelopment {
            let crew = engine.state.employees.filter { !$0.isFounder && $0.assignment == .product(product.id) }
            guard let pick = crew.filter({ $0.level == .senior }).max(by: { $0.skills.total < $1.skills.total })
                ?? crew.filter({ $0.level == .mid }).max(by: { $0.skills.total < $1.skills.total })
            else { continue }
            while let level = engine.state.employee(id: pick.id)?.level, level != .lead {
                guard !engine.send(.promote(employeeID: pick.id)).isEmpty else { break }
            }
            promoted.insert(pick.id)
        }
        let holders = engine.state.employees
            .filter { !$0.isFounder && !$0.isCofounder && !promoted.contains($0.id) }
            .sorted { $0.skills.total > $1.skills.total }
            .prefix(2)
        for (offset, employee) in holders.enumerated() {
            engine.send(.grantEquity(employeeID: employee.id, percent: offset == 0 ? 2 : 1))
        }
        #endif
    }

    /// `-autoRoute k3-lead | k3-options | k3-holder`: the manage sheet
    /// draws the career and options sections first.
    static var liftsManageSections: Bool {
        #if DEBUG
        return DebugLaunch.autoRouteName?.hasPrefix("k3-") == true
        #else
        return false
        #endif
    }

    /// `-autoRoute k3-captable` (with `-autoTab business`): the Team card
    /// is lifted onto a sheet a few seconds in.
    static var liftsCapTable: Bool {
        #if DEBUG
        return DebugLaunch.autoRouteName == "k3-captable"
        #else
        return false
        #endif
    }

    /// The person `-autoRoute k3-…` opens.
    static func person(for route: String?, engine: GameEngine) -> Employee? {
        let hired = engine.state.employees.filter { !$0.isFounder }
        switch route {
        case "k3-holder":
            return hired.first(where: \.holdsOptions)
        case "k3-options":
            return hired.filter { !$0.holdsOptions && !$0.isCofounder }.max { $0.weeklySalary < $1.weeklySalary }
        default:
            return hired.first {
                guard $0.level == .senior, case .product = $0.assignment else { return false }
                return true
            } ?? hired.first
        }
    }
}
