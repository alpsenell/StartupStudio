import PixelKit
import SwiftUI
import TycoonEngine

/// Iteration 9 — L6. The whole sabbatical on one pushed screen: who you
/// would leave it with, how long, what it costs, what it risks — and, once
/// the founder is gone, the countdown and the caretaker's log.
///
/// Deep link: `Route.sabbatical`, `-autoRoute sabbatical`.
struct SabbaticalScreen: View {
    let engine: GameEngine

    @State private var weeks: Int?
    @State private var caretakerID: UUID?
    @State private var showingReport = false

    @Environment(GameShell.self) private var injectedShell: GameShell?
    private var shell: GameShell { injectedShell ?? .shared }

    var body: some View {
        let state = engine.state
        ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                if let sabbatical = state.life.sabbatical, sabbatical.isActive {
                    awayHeader(sabbatical, state: state)
                    logCard(sabbatical)
                    comeHomeCard(sabbatical)
                } else {
                    planHeader(state)
                    caretakersCard(state)
                    lengthCard(state)
                    riskCard()
                    if let report = state.life.sabbatical?.report {
                        lastTimeCard(report)
                    }
                }
            }
            .padding(Theme.Spacing.lg)
        }
        .background(Theme.screenBackground)
        .navigationTitle("Stepping away")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingReport) {
            if let report = engine.state.life.sabbatical?.report {
                SabbaticalReportSheet(engine: engine, report: report)
            }
        }
        .task { DebugLaunch.startAutoSabbatical(engine: engine) }
        .task {
            // `-autoRoute sabbaticalreport` photographs the return sheet,
            // which is otherwise behind a tap no simulator can make.
            #if DEBUG
            guard DebugLaunch.autoRouteName == "sabbaticalreport" else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(400))
                if engine.state.life.sabbatical?.report != nil {
                    showingReport = true
                    return
                }
            }
            #endif
        }
    }

    // MARK: - Away

    private func awayHeader(_ sabbatical: SabbaticalState, state: GameState) -> some View {
        let left = sabbatical.daysLeft(from: state.day)
        let now = SabbaticalSnapshot(state)
        return PixelPanel {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                PixelText(text: String(localized: "AWAY", comment: "Pixel-font headline on the sabbatical screen while the founder is away. Uppercase A-Z, digits and $ . , : - + / ! ? ' % ( ) only — the bitmap font has no accents."), scale: 3, color: Theme.pixelAccent, shadow: true)
                Text("\(left) day\(left == 1 ? "" : "s") left · \(sabbatical.caretakerName) is running it")
                    .font(.footnote)
                    .monospacedDigit()
                    .foregroundStyle(Theme.pixelInk.opacity(0.75))
                HStack(spacing: Theme.Spacing.lg) {
                    SabbaticalStat(
                        label: "Cash", was: sabbatical.opening.cash.money, now: now.cash.money,
                        better: now.cash >= sabbatical.opening.cash
                    )
                    SabbaticalStat(
                        label: "Morale",
                        was: "\(Int(sabbatical.opening.morale.rounded()))",
                        now: "\(Int(now.morale.rounded()))",
                        better: now.morale >= sabbatical.opening.morale
                    )
                    SabbaticalStat(
                        label: "Team", was: "\(sabbatical.opening.headcount)",
                        now: "\(now.headcount)",
                        better: now.headcount >= sabbatical.opening.headcount
                    )
                }
            }
        }
    }

    private func logCard(_ sabbatical: SabbaticalState) -> some View {
        CardView("What they did", systemImage: "list.bullet.rectangle") {
            if sabbatical.log.isEmpty {
                Text("Nothing yet. That is the best possible news.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    ForEach(sabbatical.log.reversed()) { entry in
                        LogLine(entry: entry)
                    }
                }
            }
        }
    }

    private func comeHomeCard(_ sabbatical: SabbaticalState) -> some View {
        CardView("Cut it short", systemImage: "airplane.arrival") {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                Text("Flying home means telling \(sabbatical.caretakerName) you did not think they could do it.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button {
                    shell.toasts.send(
                        .endSabbaticalEarly,
                        to: engine,
                        ack: "You're home. Nobody said anything.",
                        rejected: "You're not away.",
                        icon: "airplane.arrival"
                    )
                } label: {
                    Text("Come home now · −\(Int(engine.balance.sabbatical.earlyEndBondPenalty)) bond with \(sabbatical.caretakerName)")
                        .font(.footnote.weight(.semibold))
                }
                .buttonStyle(PixelButtonStyle(fill: Theme.warning))
            }
        }
    }

    // MARK: - Planning

    private func planHeader(_ state: GameState) -> some View {
        PixelPanel {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                PixelText(text: String(localized: "STEP AWAY", comment: "Pixel-font headline on the sabbatical screen: plan a sabbatical. Uppercase A-Z only — the bitmap font has no accents."), scale: 3, color: Theme.pixelAccent, shadow: true)
                Text("Four to twelve weeks. The company keeps running without you — which is either the proof it works, or the way you find out it doesn't.")
                    .font(.footnote)
                    .foregroundStyle(Theme.pixelInk.opacity(0.75))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func caretakersCard(_ state: GameState) -> some View {
        let people = state.sabbaticalCandidates(balance: engine.balance)
        return CardView("Who gets the keys", systemImage: "key.fill") {
            if people.isEmpty {
                Text("You are the whole company. There is nobody to hand it to.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: Theme.Spacing.md) {
                    ForEach(people.prefix(6)) { person in
                        let blocker = state.caretakerBlocker(person, balance: engine.balance)
                        Button {
                            caretakerID = person.id
                        } label: {
                            CaretakerRow(
                                employee: person,
                                tenureWeeks: state.tenureWeeks(person),
                                blocker: blocker,
                                minBond: engine.balance.sabbatical.minBond,
                                isSelected: selectedCaretaker(state)?.id == person.id
                            )
                        }
                        .buttonStyle(.pressableRow)
                        .disabled(blocker != nil)
                    }
                    Text("A caretaker needs \(engine.balance.sabbatical.minTenureWeeks) weeks on the payroll and a bond of \(Int(engine.balance.sabbatical.minBond)). Coffees, one-on-ones and evenings out are how you get there.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func lengthCard(_ state: GameState) -> some View {
        let config = engine.balance.sabbatical
        let chosen = chosenWeeks
        let cost = chosen * config.weeklyCost
        let blocker = plannedBlocker(state)
        return CardView("How long", systemImage: "calendar") {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                Stepper(value: weeksBinding, in: config.minWeeks...config.maxWeeks) {
                    Text("\(chosen) weeks")
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                }
                Text("−\(cost.money) → \((state.life.wallet - cost).money) in your wallet")
                    .font(.footnote)
                    .monospacedDigit()
                    .foregroundStyle(state.life.wallet >= cost ? .secondary : Theme.warning)
                // MARK: T6 (away) — J3: a launch inside the sabbatical, printed before the tap.
                if let clash = state.launchClash(
                    awayFrom: state.day,
                    days: chosen * GameState.daysPerWeek,
                    absence: "the sabbatical",
                    balance: engine.balance,
                    content: engine.content
                ) {
                    Label(clash, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(Theme.warning)
                        .fixedSize(horizontal: false, vertical: true)
                }
                // MARK: end T6

                Button {
                    guard let caretaker = selectedCaretaker(state) else { return }
                    shell.toasts.send(
                        .startSabbatical(caretakerID: caretaker.id, weeks: chosen),
                        to: engine,
                        ack: "You handed \(caretaker.name) the keys.",
                        rejected: blocker ?? "Not now.",
                        icon: "airplane.departure"
                    )
                } label: {
                    Text(buttonTitle(state, cost: cost))
                        .font(.footnote.weight(.semibold))
                }
                .buttonStyle(PixelButtonStyle())
                .disabled(blocker != nil)

                if let blocker {
                    Label(blocker, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(Theme.warning)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func riskCard() -> some View {
        let config = engine.balance.sabbatical
        return CardView("What you are risking", systemImage: "exclamationmark.triangle")  {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                RiskLine(
                    icon: "person.crop.circle.badge.xmark",
                    text: "You produce nothing for the whole trip."
                )
                RiskLine(
                    icon: "chair.lounge.fill",
                    text: "The board's patience reads as \(Int(config.boardPatienceFactor * 100))% of itself while you are gone."
                )
                RiskLine(
                    icon: "person.badge.minus",
                    text: "Rivals are ×\(config.poachChanceFactor.formatted(.number.precision(.fractionLength(1)).locale(Theme.gameLocale))) more likely to call your people."
                )
                RiskLine(
                    icon: "heart.fill",
                    text: "You come back healthier, rested, and on better terms with whoever is waiting."
                )
            }
        }
    }

    private func lastTimeCard(_ report: SabbaticalReport) -> some View {
        CardView("Last time", systemImage: "clock.arrow.circlepath") {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text(report.headline)
                    .font(.footnote.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
                Button("Read the report", systemImage: "doc.text") { showingReport = true }
                    .buttonStyle(.pressable)
                    .font(.footnote.weight(.semibold))
            }
        }
    }

    // MARK: - Plumbing

    private var chosenWeeks: Int {
        weeks ?? engine.balance.sabbatical.minWeeks
    }

    private var weeksBinding: Binding<Int> {
        Binding(get: { chosenWeeks }, set: { weeks = $0 })
    }

    /// The row the player picked, or the best eligible person — so the
    /// button is never dead on a screen where somebody obviously qualifies.
    private func selectedCaretaker(_ state: GameState) -> Employee? {
        let people = state.sabbaticalCandidates(balance: engine.balance)
        if let caretakerID, let picked = people.first(where: { $0.id == caretakerID }) {
            return picked
        }
        return people.first { state.caretakerBlocker($0, balance: engine.balance) == nil }
    }

    /// Why the button is grey, in the player's words: the engine's own
    /// gates, never a second copy of them.
    private func plannedBlocker(_ state: GameState) -> String? {
        guard let caretaker = selectedCaretaker(state) else {
            return "Nobody has been here long enough yet"
        }
        if let reason = state.caretakerBlocker(caretaker, balance: engine.balance) {
            return "\(caretaker.name): \(reason)"
        }
        return state.sabbaticalBlocker(
            weeks: chosenWeeks, balance: engine.balance, content: engine.content
        )
    }

    private func buttonTitle(_ state: GameState, cost: Int) -> String {
        guard let caretaker = selectedCaretaker(state) else { return "Hand over the keys" }
        return "Hand \(caretaker.name) the keys · \(chosenWeeks) weeks · −\(cost.money)"
    }
}

// MARK: - Pieces

/// A number then and a number now, side by side, in the report's hand.
struct SabbaticalStat: View {
    let label: String
    let was: String
    let now: String
    let better: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(.caption2.weight(.semibold))
                .kerning(0.5)
                .foregroundStyle(Theme.pixelInk.opacity(0.55))
            Text(now)
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(better ? Theme.positiveCash : Theme.negativeCash)
            Text("was \(was)")
                .font(.caption2)
                .monospacedDigit()
                .foregroundStyle(Theme.pixelInk.opacity(0.55))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(now), was \(was)")
    }
}

private struct RiskLine: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.sm) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(Theme.accent)
                .frame(width: 18)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}
