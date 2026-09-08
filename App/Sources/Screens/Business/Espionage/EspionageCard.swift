import SwiftUI
import TycoonEngine

/// Iteration 11, wave two — W3. *The other kind of research*: the five
/// things the founder can have done to this studio, each with its price,
/// its odds and its odds of coming back; the dossier once there is one;
/// and the mole's report, counting down to a launch nobody else knows
/// about yet.
///
/// Every number on a row is the number the engine rolls
/// (`Espionage.successChance` / `Espionage.traceChance` through
/// `GameState.espionageOdds`), and every refusal is
/// `EspionageSystem.refusal`'s, in the founder's words — the card never
/// greys a row silently.
struct EspionageCard: View {
    let engine: GameEngine
    let rivalID: UUID
    /// Debug only: the card lives near the bottom of a long profile, and a
    /// headless pass cannot scroll. `-autoSpyCard` lifts the same card
    /// onto a sheet so a screenshot can see it; the sheet's own copy is
    /// drawn with this `false`, so it never presents a second one.
    var presentsDebugSheet = true

    @State private var arming: EspionageOperation?
    @State private var showingDebugSheet = false

    private var rival: Rival? { engine.state.rivals.rival(id: rivalID) }
    private var dossier: EspionageDossier? { engine.state.espionage.dossier(on: rivalID) }
    private var intel: EspionageIntel? { engine.state.espionage.liveIntel(on: rivalID) }

    var body: some View {
        if let rival {
            CardView("The other kind of research", systemImage: "binoculars.fill") {
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    if let intel { EspionageIntelStrip(engine: engine, intel: intel) }
                    if let dossier { EspionageDossierStrip(dossier: dossier) }
                    VStack(spacing: Theme.Spacing.sm) {
                        ForEach(EspionageOperation.allCases, id: \.self) { operation in
                            EspionageOperationRow(
                                operation: operation,
                                detail: detail(operation, rival: rival),
                                odds: engine.state.espionageOdds(
                                    for: operation, against: rivalID, balance: engine.balance
                                ),
                                refusal: engine.state.espionageRefusal(
                                    for: operation, against: rivalID, balance: engine.balance
                                ),
                                armed: arming == operation,
                                tap: { tap(operation) }
                            )
                        }
                    }
                    if !history.isEmpty {
                        Divider().opacity(0.4)
                        EspionageHistoryStrip(records: history)
                    }
                    Text("Every one of these goes on the record as industrial espionage, "
                         + "whether it works or not. The record is what a court reads.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            // The screenshot pass: `-autoSpy <operation>` runs one, once,
            // through the ordinary reducer, and `-autoSpyCard` lifts the
            // card where a camera can see it.
            .task {
                DebugLaunch.takeAutoEspionage(engine: engine, rivalID: rivalID)
                if presentsDebugSheet, DebugLaunch.liftsEspionageCard {
                    showingDebugSheet = true
                }
            }
            .sheet(isPresented: $showingDebugSheet) {
                EspionageCardSheet(engine: engine, rivalID: rivalID)
            }
        }
    }

    private var history: [EspionageOpRecord] {
        engine.state.espionage.ops(against: rivalID).reversed()
    }

    /// Two taps, always: the first arms the row and turns the price line
    /// into what the founder is about to be able to say, the second sends
    /// it. Nothing here is undoable and the row says so.
    private func tap(_ operation: EspionageOperation) {
        guard engine.state.espionageRefusal(
            for: operation, against: rivalID, balance: engine.balance
        ) == nil else { return }
        if arming == operation {
            arming = nil
            engine.send(.runEspionageOperation(operation: operation, rivalID: rivalID))
            Haptics.commit()
        } else {
            arming = operation
            Haptics.tap()
        }
    }

    /// What it costs and what it buys, in one line.
    private func detail(_ operation: EspionageOperation, rival: Rival) -> String {
        let config = engine.balance.espionage
        let price = Espionage.cost(operation, balance: config)
        let money = price.wallet > 0
            ? "\(price.wallet.money) of your own"
            : "\(price.company.money) of the company's"
        switch operation {
        case .tailFounder:
            return "\(money) · three things about \(rival.name)'s founder, in a folder"
        case .placeMole:
            return "\(money) · what they are shipping, \(config.intelLeadDays) days early"
        case .poachWithDirt:
            return "\(money) · their best engineer, who now has a reason to listen"
        case .buyRoadmap:
            return "\(money) · +\(Int(config.roadmapHype)) hype on your build, "
                + "−\(Int(config.roadmapStrengthHit)) on their strength"
        case .hackStorefront:
            return "\(money) · \(Int(config.hackUnitsFraction * 100))% off their launch week"
        }
    }
}

// MARK: - The rows

/// One operation, with what it costs, what it is likely to do, and what it
/// is likely to cost you if somebody works out who did it.
private struct EspionageOperationRow: View {
    let operation: EspionageOperation
    let detail: String
    let odds: (success: Double, trace: Double)
    let refusal: EspionageRefusal?
    let armed: Bool
    let tap: () -> Void

    var body: some View {
        Button(action: tap) {
            HStack(alignment: .top, spacing: Theme.Spacing.md) {
                Image(systemName: operation.systemImageName)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(refusal == nil
                        ? (armed ? Theme.negativeCash : Theme.accent)
                        : .secondary)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 3) {
                    Text(armed ? "Have it done — tap again" : operation.displayName)
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(armed ? Theme.negativeCash : .primary)
                    if let refusal {
                        // Rule 7: a refused action says why.
                        Text(refusal.sentence)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        Text(armed ? operation.pitch : detail)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("\(Int((odds.success * 100).rounded()))% it works · "
                             + "\(Int((odds.trace * 100).rounded()))% they trace it")
                            .font(Theme.Typography.number(.caption2, weight: .regular))
                            .foregroundStyle(.tertiary)
                    }
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Theme.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Theme.chipBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(
                                armed ? Theme.negativeCash.opacity(0.7) : .clear, lineWidth: 1
                            )
                    )
            )
        }
        .buttonStyle(.pressableRow)
        .disabled(refusal != nil)
        .accessibilityLabel("\(operation.displayName). \(refusal?.sentence ?? detail)")
    }
}

/// The folder: three things that are true, and how much they are worth.
private struct EspionageDossierStrip: View {
    let dossier: EspionageDossier

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "folder.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.warning)
                Text("The folder")
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                Spacer(minLength: 0)
                Text(MarketFormat.dateLabel(forDay: dossier.day))
                    .font(Theme.Typography.number(.caption2, weight: .regular))
                    .foregroundStyle(.tertiary)
            }
            ForEach(Array(dossier.facts.enumerated()), id: \.offset) { _, fact in
                HStack(alignment: .top, spacing: Theme.Spacing.sm) {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 4))
                        .foregroundStyle(.tertiary)
                        .padding(.top, 6)
                    Text(fact)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(Theme.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Theme.warning.opacity(0.10))
        )
        .accessibilityElement(children: .combine)
    }
}

/// What the mole sent back, counting down.
private struct EspionageIntelStrip: View {
    let engine: GameEngine
    let intel: EspionageIntel

    private var topicName: String {
        engine.content.topics.first { $0.id == intel.topicID }?.name ?? intel.topicID
    }

    var body: some View {
        let days = intel.daysToLaunch(from: engine.state.day)
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "shippingbox.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.accent)
                Text("They are shipping \(intel.codename)")
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                Spacer(minLength: 0)
                Text("\(days)d")
                    .font(Theme.Typography.number(.caption))
                    .foregroundStyle(Theme.accent)
                    .contentTransition(.numericText())
            }
            Text("Into \(topicName). Your mole says nobody there thinks it is a secret. "
                 + "Be on that shelf before they are and the launch lands smaller.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Theme.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Theme.accent.opacity(0.10))
        )
        .accessibilityElement(children: .combine)
    }
}

/// What has already been done to this studio, newest first.
private struct EspionageHistoryStrip: View {
    let records: [EspionageOpRecord]

    private static let shown = 4

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text("What you have already done")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            ForEach(records.prefix(Self.shown)) { record in
                HStack(alignment: .top, spacing: Theme.Spacing.sm) {
                    Image(systemName: record.tracedDay == nil
                        ? (record.landed ? "checkmark.circle.fill" : "xmark.circle")
                        : "exclamationmark.triangle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(record.tracedDay == nil
                            ? (record.landed ? Theme.positiveCash : Color.secondary)
                            : Theme.negativeCash)
                        .frame(width: 18)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(record.note.isEmpty
                             ? (record.op?.displayName ?? "Something")
                             : record.note)
                            .font(.caption)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(record.tracedDay == nil
                             ? MarketFormat.dateLabel(forDay: record.day)
                             : "\(MarketFormat.dateLabel(forDay: record.day)) · traced back to you")
                            .font(Theme.Typography.number(.caption2, weight: .regular))
                            .foregroundStyle(.tertiary)
                    }
                    Spacer(minLength: 0)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }
}

/// The same card, on a sheet, for the screenshot pass only
/// (`-autoSpyCard`). Nothing in the game presents it.
private struct EspionageCardSheet: View {
    let engine: GameEngine
    let rivalID: UUID

    private var rival: Rival? { engine.state.rivals.rival(id: rivalID) }

    var body: some View {
        NavigationStack {
            ScrollView {
                EspionageCard(engine: engine, rivalID: rivalID, presentsDebugSheet: false)
                    .padding(Theme.Spacing.lg)
            }
            .background(Theme.screenBackground)
            .navigationTitle(rival?.name ?? "Rival")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
