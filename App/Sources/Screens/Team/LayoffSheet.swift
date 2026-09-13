import PixelKit
import SwiftUI
import TycoonEngine

// MARK: T3 (people)

/// Iteration 17 — T3. Letting people go, with the price on every answer.
///
/// - `LayoffSheet`: pick several, and the sheet totals the notice, the room's
///   morale, the reputation and the board before the tap. It is the Team
///   tab's *Let people go* row and the target of the move down's "Let N
///   people go first" (`SeveranceDowngradeLink`).
/// - `SeveranceCopy`: the words the manage sheet, the swipe dialog and the
///   People menu print for the two single answers — notice, or cause.
///
/// The engine owns every number (`GameState.severanceNotice`,
/// `severanceLayoffQuote`, the blockers); this prints them and sends
/// `.fire(payNotice: true)`, the with-cause interaction or `.layOff`.

enum SeveranceCopy {
    /// `InteractionTuning.fireWithCauseID`, as the app sends it.
    static let causeInteractionID = "fireWithCause"

    static func first(_ name: String) -> String {
        name.split(separator: " ").first.map(String.init) ?? name
    }

    /// "−4", "+2", "−2.5".
    static func points(_ value: Double) -> String {
        let magnitude = abs(value)
        let text = magnitude == magnitude.rounded() ? "\(Int(magnitude))" : String(format: "%.1f", magnitude)
        return value < 0 ? "−\(text)" : "+\(text)"
    }

    static func weeks(_ count: Int) -> String {
        "\(count) week\(count == 1 ? "" : "s")"
    }

    /// "$3,423 notice (3 weeks)", or "no notice owed".
    static func noticePrice(_ notice: SeveranceNotice) -> String {
        notice.amount > 0 ? "\(notice.amount.money) notice (\(weeks(notice.weeks)))" : "no notice owed"
    }

    static func noticeTitle(_ notice: SeveranceNotice?, name: String) -> String {
        guard let notice, notice.amount > 0 else { return "Let \(first(name)) go: nothing owed" }
        return "Let \(first(name)) go: \(notice.amount.money) notice"
    }

    static func noticeDetail(_ notice: SeveranceNotice?) -> String {
        guard let notice, notice.weeks > 0 else {
            return "Under a quarter here, so no notice · nobody else's morale moves · they stay in the address book"
        }
        return "\(weeks(notice.weeks)) of pay, a week per quarter served · nobody else's morale moves · they stay in the address book"
    }

    static func causeTitle(name: String) -> String {
        "Fire \(first(name)) with cause: free"
    }

    /// Everything the free answer costs instead, including the claim when
    /// they were happy enough here to bring one.
    static func causeDetail(state: GameState, employeeID: UUID, balance: BalanceConfig) -> String {
        let config = balance.severance
        var parts = [
            "everyone who stays \(points(config.causeMoraleAll)) morale",
            "they never come back",
            "your name \(points(balance.founderStanding.nameFiredWithCause)) in every hire's ask",
        ]
        if let claim = state.severanceClaimPrice(employeeID: employeeID, balance: balance) {
            let odds = config.claimChance > 0 ? Int((1 / config.claimChance).rounded()) : 0
            parts.append("a 1-in-\(odds) claim for \(claim.money)")
        } else if let morale = state.employee(id: employeeID)?.morale {
            parts.append("morale \(Int(morale)): too unhappy here to sue")
        }
        return parts.joined(separator: " · ").prefix(1).uppercased() + parts.joined(separator: " · ").dropFirst()
    }

    /// The swipe dialog's message: both answers' prices, or why the notice
    /// is refused.
    static func dialogMessage(state: GameState, employeeID: UUID, balance: BalanceConfig) -> String {
        let notice = state.severanceNotice(employeeID: employeeID, balance: balance)
        let first = state.severanceNoticeBlocker(employeeID: employeeID, balance: balance)
            ?? "With notice: \(noticeDetail(notice).lowercased())."
        return first + "\nWith cause: " + causeDetail(state: state, employeeID: employeeID, balance: balance).lowercased() + "."
    }
}

// MARK: - The sheet

struct LayoffSheet: View {
    let engine: GameEngine
    /// How many have to go, and why: the move down's refusal.
    var need: Int?
    var reason: String?

    @State private var picked: Set<UUID>
    @Environment(\.dismiss) private var dismiss
    @Environment(GameShell.self) private var injectedShell: GameShell?
    /// See `GameShell.shared`: read optionally, because SwiftUI updates
    /// this property for presented content before the environment is
    /// installed and the non-optional form traps there.
    private var shell: GameShell { injectedShell ?? .shared }

    init(engine: GameEngine, need: Int? = nil, reason: String? = nil, preselect: Set<UUID> = []) {
        self.engine = engine
        self.need = need
        self.reason = reason
        _picked = State(initialValue: preselect)
    }

    var body: some View {
        let state = engine.state
        let people = state.employees
            .filter { !$0.isFounder }
            .sorted { $0.hiredDay != $1.hiredDay ? $0.hiredDay > $1.hiredDay : $0.name < $1.name }
        let ids = people.map(\.id).filter(picked.contains)
        let quote = state.severanceLayoffQuote(employeeIDs: ids, balance: engine.balance)
        let blocker = state.severanceLayoffBlocker(employeeIDs: ids, balance: engine.balance)
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    header(quote: quote, total: people.count)
                    VStack(spacing: Theme.Spacing.xs) {
                        ForEach(people) { person in row(person, state: state) }
                    }
                    section("What it costs", lines: costs(quote))
                    section("What it saves", lines: saves(quote))
                    section("Or", lines: [
                        "One at a time with cause, from each person's page: free, everyone who stays \(SeveranceCopy.points(engine.balance.severance.causeMoraleAll)) morale each time, a claim from anybody who was happy here, and they never come back",
                    ])
                    goButton(quote: quote, ids: ids, blocker: blocker)
                }
                .padding(Theme.Spacing.lg)
            }
            .background(Theme.screenBackground)
            .navigationTitle("Let people go")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Keep everyone") { dismiss() }
                }
            }
        }
    }

    // MARK: Header

    private func header(quote: SeveranceLayoffQuote, total: Int) -> some View {
        PixelPanel {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                HStack(alignment: .center, spacing: Theme.Spacing.md) {
                    PixelIconTile(systemImage: "person.2.slash", tint: Theme.warning, size: 44)
                    VStack(alignment: .leading, spacing: 2) {
                        PixelText(text: "\(quote.count) of \(total)", scale: 2, color: Theme.pixelInk)
                        Text(needLine(quote))
                            .font(.caption.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(Theme.pixelInk.opacity(0.7))
                    }
                }
                Text("Everyone you pick is paid their notice today — a week of pay for every quarter they served, up to four — and the people who stay watch them go.")
                    .font(.callout)
                    .foregroundStyle(Theme.pixelInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func needLine(_ quote: SeveranceLayoffQuote) -> String {
        guard let need else {
            return quote.count == 0 ? "Pick who goes" : "\(quote.headcountAfter) left, you included"
        }
        let left = need - quote.count
        let why = reason.map { "\($0) · " } ?? ""
        return left > 0 ? "\(why)\(left) more to go" : "\(why)enough to move down"
    }

    // MARK: A person

    private func row(_ person: Employee, state: GameState) -> some View {
        let isPicked = picked.contains(person.id)
        let notice = state.severanceNotice(employeeID: person.id, balance: engine.balance)
        let weeks = max(0, state.day - person.hiredDay) / GameState.daysPerWeek
        return Button {
            Haptics.tap()
            if isPicked { picked.remove(person.id) } else { picked.insert(person.id) }
        } label: {
            HStack(spacing: Theme.Spacing.md) {
                Rectangle()
                    .stroke(Theme.pixelInk, lineWidth: 2)
                    .frame(width: 18, height: 18)
                    .overlay {
                        if isPicked { Rectangle().fill(Theme.pixelInk).padding(4) }
                    }
                VStack(alignment: .leading, spacing: 2) {
                    Text(person.name)
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    Text("\(person.level.displayName) · \(weeks) wk here · \(person.weeklySalary.money)/wk · morale \(Int(person.morale))")
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(Theme.pixelInk.opacity(0.7))
                }
                Spacer(minLength: Theme.Spacing.sm)
                Text(notice.map { $0.amount > 0 ? $0.amount.money : "no notice" } ?? "—")
                    .font(Theme.Typography.number(.subheadline, weight: .semibold))
                    .foregroundStyle(Theme.pixelInk)
            }
            .padding(Theme.Spacing.sm)
            .background(isPicked ? Theme.pixelAccent.opacity(0.25) : Theme.pixelPaper)
            .overlay(Rectangle().stroke(Theme.pixelInk.opacity(0.6), lineWidth: 2))
            .foregroundStyle(Theme.pixelInk)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(person.name), \(notice.map(SeveranceCopy.noticePrice) ?? "")")
        .accessibilityAddTraits(isPicked ? .isSelected : [])
    }

    // MARK: Lines

    private func costs(_ quote: SeveranceLayoffQuote) -> [String] {
        let config = engine.balance.severance
        guard quote.count > 0 else { return ["Nothing until you pick somebody"] }
        var lines = [
            "\(quote.severance.money) of notice for \(quote.count) \(quote.count == 1 ? "person" : "people"), out of the company today",
            "Everyone who stays: morale \(SeveranceCopy.points(quote.moraleHit)) (\(SeveranceCopy.points(config.layoffMoralePerHead)) a head, never past \(SeveranceCopy.points(config.layoffMoraleCap)))",
        ]
        lines.append(quote.reputationCost > 0
            ? "Reputation \(SeveranceCopy.points(-quote.reputationCost)): \(SeveranceCopy.points(-config.layoffReputationPerThree)) for every three"
            : "Reputation holds: it moves for every three")
        if quote.boardPressure > 0 {
            lines.append("Your board grades headcount: it reads today as a miss, pressure +\(Int(quote.boardPressure.rounded()))")
        }
        return lines
    }

    private func saves(_ quote: SeveranceLayoffQuote) -> [String] {
        guard quote.count > 0 else { return ["Payroll stays where it is"] }
        return [
            "Payroll \(SeveranceCopy.points(-Double(quote.weeklyPayrollSaved)).replacingOccurrences(of: "−", with: "−$")) a week, every week",
            "\(quote.headcountAfter) on the team after, you included",
            "Cash after: \(quote.cashAfter.money)",
        ]
    }

    private func section(_ title: String, lines: [String]) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(title.uppercased())
                .font(.caption2.weight(.semibold))
                .kerning(0.6)
                .foregroundStyle(.secondary)
            ForEach(lines, id: \.self) { line in
                HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.sm) {
                    Text("·")
                    Text(line).fixedSize(horizontal: false, vertical: true)
                }
                .font(.subheadline)
                .monospacedDigit()
                .foregroundStyle(Theme.pixelInk)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    // MARK: The button

    private func goButton(quote: SeveranceLayoffQuote, ids: [UUID], blocker: String?) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Button { letGo(ids: ids, quote: quote, blocker: blocker) } label: {
                Text(quote.count == 0
                    ? "Let people go"
                    : "Let \(quote.count) go for \(quote.severance.money)")
                    .font(.system(.headline, design: .rounded))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PixelButtonStyle(fill: blocker == nil ? Theme.pixelAccent : Theme.pixelPaper))
            .disabled(blocker != nil)
            .opacity(blocker == nil ? 1 : 0.55)
            Text(blocker ?? "Closes: \(quote.count == 1 ? "a desk" : "\(quote.count) desks"), and whatever they were building")
                .font(.caption.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(blocker == nil ? Color.secondary : Theme.warning)
        }
    }

    private func letGo(ids: [UUID], quote: SeveranceLayoffQuote, blocker: String?) {
        let events = engine.send(.layOff(employeeIDs: ids))
        guard !events.isEmpty else {
            Haptics.warning()
            shell.toasts.show(
                blocker ?? "Nobody went.",
                icon: "hand.raised.fill", tint: Theme.warning, severity: .notable
            )
            return
        }
        Haptics.commit()
        shell.toasts.show(
            "Let \(quote.count) go for \(quote.severance.money). The floor is quieter.",
            icon: "person.2.slash", tint: Theme.accent
        )
        dismiss()
    }
}

// MARK: - The move down's refusal

/// Under the move down's "Let N people go first": the sheet that does it,
/// with the number to go and the reason already on it.
struct SeveranceDowngradeLink: View {
    let engine: GameEngine
    let quote: OfficeDowngradeQuote

    @State private var showing = false

    var body: some View {
        let excess = engine.state.headcount - quote.desksAfter
        if excess > 0 {
            Button { showing = true } label: {
                HStack(spacing: Theme.Spacing.sm) {
                    Text("Choose who goes: \(excess) over the \(quote.to.displayName)'s \(quote.desksAfter) desks")
                        .font(.footnote.weight(.semibold))
                        .monospacedDigit()
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .foregroundStyle(Theme.accent)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens the layoff sheet")
            .sheet(isPresented: $showing) {
                LayoffSheet(
                    engine: engine, need: excess,
                    reason: "The \(quote.to.displayName) has \(quote.desksAfter) desks"
                )
            }
        }
    }
}

// MARK: - Debug

/// `-autoRoute t3-layoff | t3-fire | t3-dialog | t3-claim`: who the lane
/// photographs.
enum SeveranceDebug {
    static var route: String? {
        #if DEBUG
        DebugLaunch.launchRoute.flatMap { $0.hasPrefix("t3-") ? $0 : nil }
        #else
        nil
        #endif
    }

    /// `t3-fire`: the manage sheet draws the letting-go section first.
    static var liftsFireSection: Bool { route == "t3-fire" }

    /// The longest-serving happy person who is not a co-founder: notice
    /// owed, and a claim on the with-cause answer.
    static func person(_ state: GameState) -> Employee? {
        state.employees
            .filter { !$0.isFounder && !$0.isCofounder }
            .sorted { lhs, rhs in
                let l = lhs.morale > 50, r = rhs.morale > 50
                if l != r { return l }
                return lhs.hiredDay != rhs.hiredDay ? lhs.hiredDay < rhs.hiredDay : lhs.name < rhs.name
            }
            .first
    }

    /// `t3-layoff`: the newest hires, as many as the move down needs (or
    /// three).
    @MainActor
    static func preselect(_ engine: GameEngine) -> Set<UUID> {
        let state = engine.state
        let excess = state.officeDowngradeQuote(balance: engine.balance).map { state.headcount - $0.desksAfter } ?? 0
        let count = excess > 0 ? excess : 3
        return Set(state.employees
            .filter { !$0.isFounder && !$0.isCofounder }
            .sorted { $0.hiredDay != $1.hiredDay ? $0.hiredDay > $1.hiredDay : $0.name < $1.name }
            .prefix(count)
            .map(\.id))
    }
}

// MARK: end T3
