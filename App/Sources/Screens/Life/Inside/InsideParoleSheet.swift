import SwiftUI
import TycoonEngine

/// Iteration 11, wave two — W4. The parole board: three people at a table
/// with your file open in front of them.
///
/// The courtroom's grammar, because it is the same kind of room — the
/// bench above, the standing bar reading what the room would decide right
/// now, and a short list of things to say with their real odds on them.
/// `CrimeBenchView` is N1's and is used as it stands (a view, called, not
/// edited); everything the board grades on is `Prison`'s.
struct InsideParoleSheet: View {
    let engine: GameEngine

    @Environment(\.dismiss) private var dismiss

    private var prison: PrisonState? { engine.state.prison }
    private var hearing: PrisonParoleHearing? { prison?.parole }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                CrimeBenchView(
                    seed: benchSeed,
                    line: hearing?.lastLine ?? closingLine,
                    landed: hearing?.lastLanded,
                    standing: hearing?.standing ?? finishedStanding,
                    verdictWord: verdictWord,
                    charge: "parole hearing"
                )
                .frame(height: 260)

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
            .navigationTitle("The board")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(hearing == nil ? "Done" : "Let them decide") {
                        if hearing != nil { engine.send(.decideParole) }
                        dismiss()
                    }
                }
            }
        }
        .onAppear(perform: openIfNeeded)
    }

    private func openIfNeeded() {
        guard engine.state.prison?.parole == nil,
              engine.state.prison?.isParoleEligible(
                  on: engine.state.day, balance: engine.balance.prison
              ) == true
        else { return }
        engine.send(.openParole)
        Sounds.play(.tap)
        Haptics.commit()
        #if DEBUG
        InsideDebug.playParoleScript(engine: engine)
        #endif
    }

    // MARK: - The look of the room

    /// Deterministic in the sentence and the company, so the same hearing
    /// has the same three faces every time it is opened.
    private var benchSeed: UInt64 {
        PitchLook.hash("parole-\(prison?.sinceDay ?? 0)-\(engine.state.company.name)")
    }

    private var finishedStanding: Double {
        guard let prison, prison.paroleHeardDay != nil else { return 0 }
        return prison.paroleGranted ? 60 : -40
    }

    private var verdictWord: String {
        guard let hearing else {
            guard let prison, prison.paroleHeardDay != nil else { return "" }
            return prison.paroleGranted ? "Released" : "Refused"
        }
        return Prison.paroleLabel(hearing.standing, balance: engine.balance.prison)
    }

    private var closingLine: String {
        guard let prison, prison.paroleHeardDay != nil else {
            return "\"The board is not sitting today.\""
        }
        return prison.paroleGranted
            ? "\"You will keep an address and a job. Do not make me wrong.\""
            : "\"Not this time. The date on your file has not moved.\""
    }

    // MARK: - What to say

    private var exchangesCard: some View {
        let hearing = hearing
        return CardView("Say something", systemImage: "bubble.left.and.text.bubble.right.fill") {
            VStack(spacing: Theme.Spacing.sm) {
                ForEach(PrisonParoleExchange.allCases, id: \.self) { exchange in
                    InsideParoleRow(
                        exchange: exchange,
                        read: read(exchange),
                        enabled: (hearing?.exchangesLeft ?? 0) > 0
                            && !(hearing?.said.contains(exchange.rawValue) ?? false)
                    ) {
                        say(exchange)
                    }
                }
                if let hearing {
                    Text(hearing.exchangesLeft > 0
                        ? "\(hearing.exchangesLeft) thing\(hearing.exchangesLeft == 1 ? "" : "s") they will hear before they decide."
                        : "That is everything they are going to hear.")
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    /// The odds on the button, from the same function the board grades
    /// with, so the number is not a promise the room can break.
    private func read(_ exchange: PrisonParoleExchange) -> String {
        guard let prison else { return "" }
        let chance = Prison.paroleLandChance(
            exchange,
            skill: engine.state.life.skills.crimeValue(for: exchange.gradedOn),
            state: prison,
            balance: engine.balance.prison
        )
        let percent = Int((chance * 100).rounded())
        return "\(percent)% it lands · +\(Int(exchange.landed)) / \(Int(exchange.missed)) · graded on \(exchange.gradedOn.displayName.lowercased())"
    }

    private func say(_ exchange: PrisonParoleExchange) {
        let before = engine.state.prison?.parole?.standing ?? 0
        engine.send(.sayAtParole(exchange: exchange))
        let after = engine.state.prison?.parole?.standing
        if let after, after > before { Haptics.commit() } else { Haptics.tap() }
    }

    // MARK: - After

    private var afterCard: some View {
        CardView("The decision", systemImage: "doc.text.fill") {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                if let prison, prison.paroleHeardDay != nil {
                    Text(closingLine)
                        .font(.callout)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(prison.paroleGranted
                        ? "Out today, on paper, with an address to keep."
                        : "The rest of it, day by day, the way it was written down.")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(prison.paroleGranted ? Theme.positiveCash : Theme.negativeCash)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("Nothing is listed. Nobody is waiting to hear from you.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Text("Whatever they decide, the conviction stays where it is. That part does not get reviewed.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - Rows

private struct InsideParoleRow: View {
    let exchange: PrisonParoleExchange
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
