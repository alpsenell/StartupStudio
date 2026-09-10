import SwiftUI
import TycoonEngine

/// Iteration 11 — N1. The ledger the founder keeps for themselves: what
/// they have done, what it is doing to the needle, what is coming, and
/// the six buttons.
///
/// One screen rather than six buttons scattered across the game. The
/// brief wanted the offences where they belong — the books and the tax in
/// the finance ledger, the poach on the hiring sheet, the envelope on the
/// press strip — and every one of those files belongs to another lane
/// this round, so they are gathered here and the report lists moving them
/// as wave two's first job. The rival's two (the story and the suit) do
/// live where they belong, on the rival's own profile.
struct CrimeScreen: View {
    let engine: GameEngine
    /// Opens the courtroom over this screen.
    @Binding var showingCourtroom: Bool

    @State private var confirming: CrimeOffence?

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                if let pending = engine.state.crime.pendingCase {
                    CrimeCaseCard(engine: engine, legalCase: pending) { showingCourtroom = true }
                }
                offencesCard
                recordCard
                if !engine.state.crime.cases.filter({ !$0.isPending }).isEmpty {
                    historyCard
                }
            }
            .padding(Theme.Spacing.lg)
        }
        .background(Theme.screenBackground)
        .navigationTitle("The other ledger")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingCourtroom) {
            CrimeCourtroomSheet(engine: engine)
        }
        // The screenshot pass: commit, confess, wait for the listing, and
        // walk in — every step a real action through the reducer.
        .task {
            CrimeDebug.startIfAsked(engine: engine)
            await CrimeDebug.openWhenListed(engine: engine) { showingCourtroom = true }
        }
    }

    // MARK: - The six

    private var offencesCard: some View {
        CardView("Things you should not do", systemImage: "hand.raised.slash.fill") {
            VStack(spacing: Theme.Spacing.sm) {
                ForEach(CrimeOffence.allCases, id: \.self) { offence in
                    CrimeOffenceRow(
                        offence: offence,
                        gain: engine.state.crimeGainLine(for: offence, balance: engine.balance),
                        notoriety: Crime.notorietyCost(offence, balance: engine.balance.crime),
                        refusal: engine.state.crimeRefusal(for: offence, balance: engine.balance),
                        armed: confirming == offence,
                        tap: { tap(offence) }
                    )
                }
                Text("Every one of these is on the record for good. The record is what a court reads.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// Two taps, always. The first arms the row and turns the gain line
    /// into the sentence the founder is about to be able to say; the
    /// second sends it. Nothing here is undoable and the row says so.
    private func tap(_ offence: CrimeOffence) {
        guard engine.state.crimeRefusal(for: offence, balance: engine.balance) == nil else { return }
        if confirming == offence {
            confirming = nil
            engine.send(.commitOffence(offence: offence))
            Haptics.commit()
        } else {
            confirming = offence
            Haptics.tap()
        }
    }

    // MARK: - The record

    private var recordCard: some View {
        CardView("The record", systemImage: "list.bullet.rectangle.portrait.fill") {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                CrimeNotorietyNeedle(notoriety: engine.state.crime.notoriety)
                if engine.state.crime.record.isEmpty {
                    Text("Empty. Enjoy it.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(engine.state.crime.record.reversed()) { entry in
                        CrimeRecordRow(
                            entry: entry,
                            // MARK: J2 (record) — the odds the sweep rolls.
                            chance: engine.state.standingDiscoveryChance(
                                entry, balance: engine.balance
                            ),
                            // MARK: end J2
                            day: engine.state.day
                        )
                    }
                    if engine.state.crime.pendingCase == nil,
                       !engine.state.crime.openRecord.isEmpty {
                        Button("Turn yourself in", systemImage: "figure.walk.motion") {
                            engine.send(.confessOffence())
                            Haptics.commit()
                        }
                        .buttonStyle(.pressable)
                        .font(.footnote.weight(.semibold))
                        Text("Raises the case today, with a third of the paper against you. It is the only way to choose when.")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    // MARK: - What the courts did

    private var historyCard: some View {
        CardView("Heard", systemImage: "building.columns") {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                ForEach(engine.state.crime.cases.filter { !$0.isPending }.reversed()) { legalCase in
                    HStack(alignment: .top, spacing: Theme.Spacing.sm) {
                        Image(systemName: legalCase.verdict?.isGood == true
                            ? "checkmark.seal.fill" : "seal.fill")
                            .font(.footnote)
                            .foregroundStyle(legalCase.verdict?.isGood == true
                                ? Theme.positiveCash : Theme.negativeCash)
                            .frame(width: 18)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(historyTitle(legalCase))
                                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                            Text(GameState.dateLabel(forDay: legalCase.hearingDay))
                                .font(.caption)
                                .monospacedDigit()
                                .foregroundStyle(.tertiary)
                        }
                        Spacer(minLength: 0)
                    }
                }
            }
        }
    }

    private func historyTitle(_ legalCase: LegalCase) -> String {
        let verdict = legalCase.verdict?.displayName ?? "Withdrawn"
        if legalCase.isFounderSuing {
            return legalCase.verdict?.isGood == true
                ? "Your suit succeeded — \(legalCase.penalty.money)"
                : "Your suit failed"
        }
        let charge = legalCase.offence?.chargeName.capitalizedFirstLetter ?? "The matter"
        if legalCase.sentenceWeeks > 0 {
            return "\(charge): \(verdict), \(legalCase.sentenceWeeks) weeks"
        }
        if legalCase.penalty > 0 {
            return "\(charge): \(verdict), \(legalCase.penalty.money)"
        }
        return "\(charge): \(verdict)"
    }
}

// MARK: - Rows

/// One of the six. Carries what it buys, what it costs the needle, and —
/// once armed — the fact that there is no way back from the second tap.
private struct CrimeOffenceRow: View {
    let offence: CrimeOffence
    let gain: String
    let notoriety: Double
    let refusal: CrimeRefusal?
    let armed: Bool
    let tap: () -> Void

    var body: some View {
        Button(action: tap) {
            HStack(alignment: .top, spacing: Theme.Spacing.md) {
                Image(systemName: offence.symbol)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(refusal == nil
                        ? (armed ? Theme.negativeCash : Theme.accent)
                        : .secondary)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 3) {
                    Text(armed ? "Do it — tap again" : offence.displayName)
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(armed ? Theme.negativeCash : .primary)
                    if let refusal {
                        // Rule 7: a refused action says why.
                        Text(refusal.sentence)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        Text(armed ? offence.pitch : gain)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("Notoriety +\(Int(notoriety.rounded())) · on the record for good")
                            .font(.caption2)
                            .monospacedDigit()
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
                                armed ? Theme.negativeCash.opacity(0.7) : .clear,
                                lineWidth: 1
                            )
                    )
            )
        }
        .buttonStyle(.pressableRow)
        .disabled(refusal != nil)
        .accessibilityLabel("\(offence.displayName). \(refusal?.sentence ?? gain)")
    }
}

/// One thing on the record: what it was, what it bought, and how warm the
/// paper still is.
private struct CrimeRecordRow: View {
    let entry: CrimeRecordEntry
    let chance: Double
    let day: Int

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.sm) {
            Image(systemName: entry.offence.symbol)
                .font(.footnote)
                .foregroundStyle(entry.isOpen ? Theme.warning : .secondary)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.offence.displayName)
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                Text(entry.note)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(status)
                    .font(.caption2)
                    .monospacedDigit()
                    .foregroundStyle(.tertiary)
            }
            Spacer(minLength: 0)
        }
    }

    private var status: String {
        let when = GameState.dateLabel(forDay: entry.day)
        if entry.settledDay != nil { return "\(when) · answered for" }
        if entry.discoveredDay != nil { return "\(when) · this is the one they found" }
        let percent = Int((chance * 100).rounded())
        return "\(when) · \(percent)% a week"
    }
}
