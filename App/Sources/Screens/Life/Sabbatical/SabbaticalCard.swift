import PixelKit
import SwiftUI
import TycoonEngine

/// Iteration 9 — L6. The Life tab's entry to the sabbatical, in the You
/// section under the meters.
///
/// Three states, because the feature has three: nobody has ever left (the
/// pitch, and the person you would have to trust to do it), the founder is
/// away (a countdown and the last thing the office said), and the founder
/// is back with a report they have not read.
struct SabbaticalCard: View {
    let engine: GameEngine
    /// Pushes the full surface (the plan, or the log).
    var onOpen: () -> Void

    @State private var showingReport = false

    @Environment(GameShell.self) private var injectedShell: GameShell?
    /// See `GameShell.shared`: read optionally, because SwiftUI updates
    /// this property for presented content before the environment is
    /// installed and the non-optional form traps there.
    private var shell: GameShell { injectedShell ?? .shared }

    var body: some View {
        let state = engine.state
        CardView("Stepping away", systemImage: "airplane.departure") {
            if let sabbatical = state.life.sabbatical, sabbatical.isActive {
                away(sabbatical, state: state)
            } else if let report = state.life.sabbatical?.report {
                back(report)
            } else {
                pitch(state)
            }
        }
        .sheet(isPresented: $showingReport) {
            if let report = engine.state.life.sabbatical?.report {
                SabbaticalReportSheet(engine: engine, report: report)
            }
        }
        .task { DebugLaunch.startAutoSabbatical(engine: engine) }
    }

    // MARK: - Never been away

    @ViewBuilder
    private func pitch(_ state: GameState) -> some View {
        let best = state.sabbaticalCandidates(balance: engine.balance).first
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text("Hand the company to somebody you trust and disappear for a month. You come back rested; you come back to whatever they did.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let best {
                CaretakerRow(
                    employee: best,
                    tenureWeeks: state.tenureWeeks(best),
                    blocker: state.caretakerBlocker(best, balance: engine.balance),
                    minBond: engine.balance.sabbatical.minBond
                )
            } else {
                Text("There is nobody to leave it with. Hire somebody, then get to know them.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Button("Plan a sabbatical", systemImage: "airplane") { onOpen() }
                .buttonStyle(.pressable)
                .font(.footnote.weight(.semibold))

            Text(costLine(weeks: engine.balance.sabbatical.minWeeks))
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Away

    @ViewBuilder
    private func away(_ sabbatical: SabbaticalState, state: GameState) -> some View {
        let left = sabbatical.daysLeft(from: state.day)
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack(spacing: Theme.Spacing.md) {
                if let caretaker = state.employee(id: sabbatical.caretakerID) {
                    PixelPortrait(
                        seed: caretaker.appearanceSeed,
                        role: RoleLook(rawValue: caretaker.role.rawValue) ?? .none,
                        size: 40
                    )
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(left) day\(left == 1 ? "" : "s") left")
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                    Text("\(sabbatical.caretakerName) has the keys")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            ProgressView(
                value: Double(state.day - sabbatical.sinceDay),
                total: Double(max(1, sabbatical.untilDay - sabbatical.sinceDay))
            )
            .tint(Theme.accent)

            ForEach(sabbatical.log.suffix(2)) { entry in
                LogLine(entry: entry)
            }

            HStack(spacing: Theme.Spacing.sm) {
                Button("The log", systemImage: "list.bullet.rectangle") { onOpen() }
                    .buttonStyle(.pressable)
                Button("Come home", systemImage: "airplane.arrival") {
                    shell.toasts.send(
                        .endSabbaticalEarly,
                        to: engine,
                        ack: "You're home. Nobody said anything.",
                        rejected: "You're not away.",
                        icon: "airplane.arrival"
                    )
                }
                .buttonStyle(.pressable)
                .foregroundStyle(Theme.warning)
            }
            .font(.footnote.weight(.semibold))

            Text("Coming home early costs \(Int(engine.balance.sabbatical.earlyEndBondPenalty)) bond with \(sabbatical.caretakerName), and the weeks are already paid for.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Back

    @ViewBuilder
    private func back(_ report: SabbaticalReport) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text(report.headline)
                .font(.subheadline.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
            Text("\(report.weeks) week\(report.weeks == 1 ? "" : "s") with \(report.caretakerName)\(report.endedEarly ? ", cut short" : "")")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: Theme.Spacing.sm) {
                Button("Read the report", systemImage: "doc.text") { showingReport = true }
                    .buttonStyle(.pressable)
                Button("Go again", systemImage: "airplane") { onOpen() }
                    .buttonStyle(.pressable)
            }
            .font(.footnote.weight(.semibold))
        }
    }

    private func costLine(weeks: Int) -> String {
        let config = engine.balance.sabbatical
        let cost = weeks * config.weeklyCost
        let wallet = engine.state.life.wallet
        return "\(config.minWeeks)–\(config.maxWeeks) weeks · \(config.weeklyCost.money) a week · \(weeks) weeks = −\(cost.money) → \((wallet - cost).money)"
    }
}

// MARK: - Pieces

/// One person who could mind the shop: the face, what they are, how long
/// they have been here, and either the bond bar or the reason they cannot.
struct CaretakerRow: View {
    let employee: Employee
    let tenureWeeks: Int
    let blocker: String?
    let minBond: Double
    var isSelected = false

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            PixelPortrait(
                seed: employee.appearanceSeed,
                role: RoleLook(rawValue: employee.role.rawValue) ?? .none,
                size: 36
            )
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: Theme.Spacing.xs) {
                    Text(employee.name)
                        .font(.subheadline.weight(.semibold))
                    Text(employee.level.displayName)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                if let blocker {
                    Text(blocker)
                        .font(.caption)
                        .foregroundStyle(Theme.warning)
                } else {
                    Text("\(tenureWeeks) weeks here · bond \(Int(employee.founderBond))")
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                CaretakerBondBar(bond: employee.founderBond, minBond: minBond)
            }
            Spacer(minLength: 0)
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Theme.accent)
            }
        }
        .opacity(blocker == nil ? 1 : 0.65)
        .accessibilityElement(children: .combine)
    }
}

/// Bond, with a notch where the gate is.
struct CaretakerBondBar: View {
    let bond: Double
    let minBond: Double

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.chipBackground)
                Capsule()
                    .fill(bond >= minBond ? Theme.accent : Theme.warning)
                    .frame(width: proxy.size.width * min(1, bond / 100))
                Rectangle()
                    .fill(Theme.pixelInk.opacity(0.45))
                    .frame(width: 2)
                    .offset(x: proxy.size.width * min(1, minBond / 100))
            }
        }
        .frame(height: 5)
        .accessibilityHidden(true)
    }
}

/// One line of the caretaker's log.
struct LogLine: View {
    let entry: SabbaticalLogEntry

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.sm) {
            Image(systemName: entry.isDecision ? "arrow.turn.down.right" : "text.bubble")
                .font(.caption2)
                .foregroundStyle(entry.isDecision ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(.tertiary))
                .frame(width: 14)
            VStack(alignment: .leading, spacing: 1) {
                Text(entry.text)
                    .font(.caption)
                    .foregroundStyle(entry.isDecision ? .primary : .secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Day \(entry.day)")
                    .font(.caption2)
                    .monospacedDigit()
                    .foregroundStyle(.tertiary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
