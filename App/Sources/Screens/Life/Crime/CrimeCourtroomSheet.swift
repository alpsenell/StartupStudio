import SwiftUI
import TycoonEngine

/// Iteration 11 — N1. The courtroom: a bench, a prosecutor, and three
/// things the founder can say.
///
/// Drawn in the pitch room's grammar — a room with somebody in it, their
/// last line over the table, and the thing the conversation is moving
/// underneath — and stopped like the incident room: `openHearing` pauses
/// the clock, because a hearing is the interruption, not a screen over
/// one. The standing bar and the verdict word under it call exactly the
/// engine functions the verdict calls (`Crime.verdict`), so what the
/// player is reading is what the judge is about to say.
struct CrimeCourtroomSheet: View {
    let engine: GameEngine

    @Environment(\.dismiss) private var dismiss

    private var hearing: CrimeHearing? { engine.state.crime.hearing }
    private var legalCase: LegalCase? {
        if let hearing {
            return engine.state.crime.cases.first { $0.id == hearing.caseID }
        }
        return engine.state.crime.pendingCase
            ?? engine.state.crime.cases.last { $0.verdict != nil }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                CrimeBenchView(
                    seed: benchSeed,
                    line: hearing?.lastLine ?? closingLine,
                    landed: hearing?.lastLanded,
                    standing: hearing?.standing ?? finishedStanding,
                    verdictWord: verdictWord,
                    charge: legalCase?.offence?.chargeName ?? "the matter"
                )
                .frame(height: 300)

                ScrollView {
                    VStack(spacing: Theme.Spacing.md) {
                        if hearing != nil {
                            exchangesCard
                        } else {
                            afterCard
                        }
                    }
                    .padding(Theme.Spacing.lg)
                }
                .background(Theme.screenBackground)
            }
            .background(Theme.screenBackground)
            .navigationTitle("The hearing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(hearing == nil ? "Done" : "Rest your case") {
                        if hearing != nil { engine.send(.restCase) }
                        dismiss()
                    }
                }
            }
        }
        .onAppear(perform: openIfNeeded)
    }

    private func openIfNeeded() {
        guard engine.state.crime.hearing == nil,
              let pending = engine.state.crime.pendingCase,
              engine.state.day >= pending.hearingDay
        else { return }
        engine.send(.openHearing)
        Sounds.play(.tap)
        Haptics.commit()
        playScriptIfAsked()
    }

    /// `-autoCourtSay deny,explain`: a screenshot pass cannot tap, so the
    /// exchanges it wants photographed are played through the ordinary
    /// reducer, exactly as the buttons would. DEBUG only, and a script is
    /// stopped by the same guards the buttons are.
    private func playScriptIfAsked() {
        #if DEBUG
        for name in CrimeDebug.courtScript {
            guard let exchange = CrimeExchange(rawValue: name),
                  engine.state.crime.hearing != nil
            else { continue }
            engine.send(.sayInCourt(exchange))
        }
        #endif
    }

    // MARK: - The look of the room

    /// Deterministic in the charge and the company, so the same case has
    /// the same bench every time the sheet is opened.
    private var benchSeed: UInt64 {
        PitchLook.hash("bench-\(legalCase?.id ?? "none")-\(engine.state.company.name)")
    }

    private var finishedStanding: Double {
        guard let legalCase, let verdict = legalCase.verdict else { return 0 }
        return switch verdict {
        case .acquitted: 70
        case .fine: 20
        case .settlement: -14
        case .sentence: -60
        }
    }

    private var verdictWord: String {
        guard let hearing else { return legalCase?.verdict?.displayName ?? "" }
        return Crime.standingLabel(hearing.standing, balance: engine.balance.crime)
    }

    private var closingLine: String {
        guard let legalCase, let verdict = legalCase.verdict else {
            return "\"The court is not yet sitting.\""
        }
        return Crime.closing(verdict, weeks: legalCase.sentenceWeeks, money: legalCase.penalty)
    }

    // MARK: - What to say

    private var exchangesCard: some View {
        let hearing = hearing
        let legalCase = legalCase
        return CardView("Say something", systemImage: "bubble.left.and.text.bubble.right.fill") {
            VStack(spacing: Theme.Spacing.sm) {
                ForEach(CrimeExchange.allCases, id: \.self) { exchange in
                    let objectionsLeft = hearing?.objectionsLeft ?? 0
                    let enabled = (hearing?.exchangesLeft ?? 0) > 0
                        && (exchange != .objection || objectionsLeft > 0)
                    CrimeExchangeRow(
                        exchange: exchange,
                        read: read(exchange, hearing: hearing, legalCase: legalCase),
                        enabled: enabled
                    ) {
                        say(exchange)
                    }
                }
                if let hearing {
                    Text(hearing.exchangesLeft > 0
                        ? "\(hearing.exchangesLeft) exchange\(hearing.exchangesLeft == 1 ? "" : "s") before the bench makes its mind up."
                        : "That's the hearing.")
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    /// The odds on the button. The same function the engine grades with,
    /// so the number is not a promise the room can break.
    private func read(
        _ exchange: CrimeExchange,
        hearing: CrimeHearing?,
        legalCase: LegalCase?
    ) -> String {
        guard let legalCase else { return "" }
        if exchange == .objection, (hearing?.objectionsLeft ?? 0) <= 0 {
            return legalCase.lawyer == .dutySolicitor
                ? "Your lawyer has not objected to anything today and is not going to."
                : "They have used all of theirs."
        }
        let defence = legalCase.defence ?? .everybodyDoesThis
        let chance = Crime.landChance(
            exchange,
            defence: defence,
            lawyer: legalCase.lawyer,
            skill: engine.state.life.skills.crimeValue(for: exchange.gradedOn),
            evidence: legalCase.evidence,
            balance: engine.balance.crime
        )
        let percent = Int((chance * 100).rounded())
        let onLine = exchange == defence.favours ? " · your line" : ""
        return "\(percent)% it lands · graded on \(exchange.gradedOn.displayName.lowercased())\(onLine)"
    }

    private func say(_ exchange: CrimeExchange) {
        let before = engine.state.crime.hearing?.standing ?? 0
        engine.send(.sayInCourt(exchange))
        let after = engine.state.crime.hearing?.standing
        if let after, after > before { Haptics.commit() } else { Haptics.tap() }
    }

    // MARK: - After

    private var afterCard: some View {
        CardView("The verdict", systemImage: "gavel.fill") {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                if let legalCase, let verdict = legalCase.verdict {
                    Text(Crime.closing(
                        verdict, weeks: legalCase.sentenceWeeks, money: legalCase.penalty
                    ))
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
                    Text(afterLine(legalCase, verdict: verdict))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(verdict.isGood ? Theme.positiveCash : Theme.negativeCash)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("Nothing is listed. Nobody is waiting for you.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Text("It goes on the record either way. The record is the part that lasts.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func afterLine(_ legalCase: LegalCase, verdict: CrimeVerdict) -> String {
        switch verdict {
        case .acquitted: "Nothing owed, and the company's name is a little cleaner than it was."
        case .fine: "\(legalCase.penalty.money), and the reputation that went with it."
        case .settlement: "\(legalCase.penalty.money), and a gag order nobody in the office believes."
        case .sentence: "\(legalCase.sentenceWeeks) weeks. Somebody else has the keys."
        }
    }
}

// MARK: - Rows

private struct CrimeExchangeRow: View {
    let exchange: CrimeExchange
    let read: String
    let enabled: Bool
    let say: () -> Void

    var body: some View {
        Button(action: say) {
            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: exchange.symbol)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(enabled ? Theme.accent : .secondary)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(exchange.displayName)
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(read)
                        .font(.caption2)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Theme.Spacing.md)
            .background(Theme.chipBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.pressableRow)
        .disabled(!enabled)
        .accessibilityLabel("\(exchange.displayName). \(read)")
    }
}
