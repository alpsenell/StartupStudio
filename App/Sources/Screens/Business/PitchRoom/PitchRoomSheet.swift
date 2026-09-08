import SwiftUI
import TycoonContent
import TycoonEngine

/// The pitch room: one person, one table, and three exchanges to change
/// what the paperwork says.
///
/// Drawn the way the networking floor is drawn rather than the way a form
/// is — a room with somebody in it, their last line over the table, and
/// the terms underneath moving as the conversation does. The terms panel
/// calls exactly the engine functions the settle step calls
/// (`PitchRoom.revised`), so the numbers on screen are the numbers that
/// get written when the founder gets up.
struct PitchRoomSheet: View {
    let engine: GameEngine
    /// The chair the sheet was opened for. Once a session is running the
    /// session's own counterpart wins, so a room that settles under the
    /// sheet still reads as itself.
    let counterpart: PitchCounterpart
    var subjectID: UUID?

    @Environment(\.dismiss) private var dismiss

    private var session: PitchSession? { engine.state.pitch?.session }

    private var seated: PitchCounterpart { session?.counterpart ?? counterpart }

    /// The last conversation, so the sheet has something to say after the
    /// room closes rather than emptying out mid-tap.
    private var lastRecord: PitchRecord? {
        engine.state.pitch?.log.last
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                PitchTableView(
                    counterpart: seated,
                    seed: PitchLook.seed(for: seated, state: engine.state, subjectID: subjectID),
                    line: session?.lastLine ?? lastRecord.map(\.summary) ?? "",
                    landed: session?.lastLanded,
                    warmth: session?.warmth ?? lastRecord.map { record in
                        record.band.isGood ? 60 : (record.band.isBad ? -60 : 0)
                    } ?? 0,
                    tell: tellLine
                )
                // A room, not a wallpaper: fixed so the terms and the
                // exchanges are on screen with it rather than below the
                // fold.
                .frame(height: 300)

                ScrollView {
                    VStack(spacing: Theme.Spacing.md) {
                        if session != nil {
                            PitchTermsCard(engine: engine, session: session!)
                            exchangesCard
                        } else {
                            closedCard
                        }
                    }
                    .padding(Theme.Spacing.lg)
                }
                .background(Theme.screenBackground)
            }
            .background(Theme.screenBackground)
            .navigationTitle(roomTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(session == nil ? "Done" : "Leave it there") {
                        if session != nil { engine.send(.leavePitch) }
                        dismiss()
                    }
                }
            }
        }
        .onAppear(perform: openIfNeeded)
    }

    private var roomTitle: String {
        engine.content.pitchCounterpart(seated.rawValue)?.title ?? seated.displayName
    }

    /// The body language, until the founder has listened; after that the
    /// want has a name and the terms card says it.
    private var tellLine: String? {
        guard let session, !session.wantRevealed else { return nil }
        return engine.content.pitchCounterpart(session.counterpart.rawValue)?
            .wants.first { $0.id == session.wantID }?.tell
    }

    private func openIfNeeded() {
        guard engine.state.pitch?.session == nil else { return }
        // Opening a room that has already been talked to, or that has
        // nothing behind it, is refused by the engine — the sheet then
        // shows the closed state rather than an empty table.
        engine.send(.openPitch(counterpart: counterpart, subjectID: subjectID))
        playScriptIfAsked()
    }

    /// `-autoPitchSay listen,shopTalk`: a screenshot pass cannot tap, so
    /// the exchanges it wants photographed are played here — through the
    /// ordinary reducer, exactly as the buttons would. DEBUG only, and a
    /// script is stopped by the same guards the buttons are.
    private func playScriptIfAsked() {
        #if DEBUG
        for name in DebugLaunch.launchPitchScript {
            guard let topic = ConversationTopic(rawValue: name),
                  engine.state.pitch?.session != nil
            else { continue }
            engine.send(.sayInPitch(topic: topic))
        }
        #endif
    }

    // MARK: - What to say

    private var exchangesCard: some View {
        let session = session
        return CardView("Say something", systemImage: "bubble.left.and.text.bubble.right.fill") {
            VStack(spacing: Theme.Spacing.sm) {
                ForEach(ConversationTopic.allCases, id: \.self) { topic in
                    PitchTopicRow(
                        topic: topic,
                        read: session.map { current in
                            PitchRoom.read(
                                topic,
                                session: current,
                                want: want(for: current),
                                state: engine.state
                            )
                        } ?? "",
                        enabled: (session?.exchangesLeft ?? 0) > 0
                    ) {
                        say(topic)
                    }
                }
                if let session {
                    Text(session.exchangesLeft > 0
                        ? "\(session.exchangesLeft) exchange\(session.exchangesLeft == 1 ? "" : "s") left before they make their mind up."
                        : "That's the meeting.")
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private func want(for session: PitchSession) -> PitchWantDef? {
        engine.content.pitchCounterpart(session.counterpart.rawValue)?
            .wants.first { $0.id == session.wantID }
    }

    private func say(_ topic: ConversationTopic) {
        let before = engine.state.pitch?.session?.warmth ?? 0
        engine.send(.sayInPitch(topic: topic))
        let after = engine.state.pitch?.session?.warmth
        if let after, after > before { Haptics.commit() }
    }

    // MARK: - After

    private var closedCard: some View {
        CardView("How it went", systemImage: "door.left.hand.closed") {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                if let record = lastRecord {
                    Text(PitchRoom.closing(
                        counterpart: record.counterpart, band: record.band, content: engine.content
                    ))
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
                    Text(record.summary)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(record.band.isGood
                            ? Theme.positiveCash
                            : (record.band.isBad ? Theme.negativeCash : .secondary))
                        .fixedSize(horizontal: false, vertical: true)
                } else if let blocker = engine.state.pitchBlocker(
                    for: counterpart, subjectID: subjectID,
                    balance: engine.balance, content: engine.content
                ) {
                    // Rule 7: a refused action says why.
                    Label(blocker, systemImage: "hand.raised.fill")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("Nobody's at the table.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Text("The answer itself is still yours — this only changed what you're answering.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - Rows

private struct PitchTopicRow: View {
    let topic: ConversationTopic
    let read: String
    let enabled: Bool
    let say: () -> Void

    var body: some View {
        Button(action: say) {
            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: topic.pitchSymbol)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(enabled ? Theme.accent : .secondary)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(topic.displayName)
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(read)
                        .font(.caption2)
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
        .accessibilityLabel("\(topic.displayName). \(read)")
    }
}

extension ConversationTopic {
    /// The pitch room's own icons — the networking floor's four topics
    /// read differently across a boardroom table.
    var pitchSymbol: String {
        switch self {
        case .smallTalk: "cup.and.saucer.fill"
        case .shopTalk: "chart.bar.doc.horizontal.fill"
        case .listen: "ear.fill"
        case .pitch: "megaphone.fill"
        }
    }
}

// MARK: - Who is sitting there

/// The look of the person across the table. Deterministic in the thing
/// the conversation is about, so the same investor has the same face
/// every time the sheet is opened.
enum PitchLook {
    static func seed(
        for counterpart: PitchCounterpart, state: GameState, subjectID: UUID?
    ) -> UInt64 {
        switch counterpart {
        case .investor:
            return hash(state.investors.pendingOffer?.investorID ?? "investor")
        case .client:
            let name = subjectID
                .flatMap { id in state.contractOffers.first { $0.id == id }?.clientName }
                ?? state.contractOffers.first?.clientName
            return hash(name ?? "client")
        case .journalist:
            return hash("press-\(subjectID?.uuidString ?? "")-\(state.company.name)")
        case .board:
            return hash("board-\(state.investors.rounds.first?.investorID ?? state.company.name)")
        }
    }

    /// FNV-1a, so a name maps to the same face on every device and every
    /// run without touching an RNG stream.
    static func hash(_ text: String) -> UInt64 {
        var value: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in text.utf8 {
            value ^= UInt64(byte)
            value &*= 0x1000_0000_01b3
        }
        return value
    }

    static func gradient(_ counterpart: PitchCounterpart) -> [Color] {
        switch counterpart {
        case .investor: [Color(red: 0.12, green: 0.18, blue: 0.28), Color(red: 0.24, green: 0.34, blue: 0.46)]
        case .client: [Color(red: 0.14, green: 0.20, blue: 0.18), Color(red: 0.28, green: 0.40, blue: 0.34)]
        case .journalist: [Color(red: 0.22, green: 0.17, blue: 0.13), Color(red: 0.42, green: 0.32, blue: 0.22)]
        case .board: [Color(red: 0.18, green: 0.13, blue: 0.22), Color(red: 0.34, green: 0.24, blue: 0.38)]
        }
    }
}
