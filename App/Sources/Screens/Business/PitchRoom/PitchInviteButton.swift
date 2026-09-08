import SwiftUI
import TycoonEngine

/// *Talk first* — the button that turns a card with two answers on it
/// into a conversation.
///
/// It carries its own sheet, so a card anywhere in the app can offer the
/// room with one line and without learning anything about presentation.
/// It draws nothing at all when there is nothing to talk about, and when
/// the conversation has already happened it says so in place of offering
/// it again (rule 7).
struct PitchInviteButton: View {
    let engine: GameEngine
    let counterpart: PitchCounterpart
    var subjectID: UUID?
    /// Prominent on the term sheet and the board card, bordered where it
    /// sits next to an Accept.
    var prominent = false

    @State private var showingRoom = false
    /// So a redraw does not reopen a sheet the player just closed.
    @State private var hasAutoOpened = false

    var body: some View {
        // The sheet hangs off the root, not off the button: opening a
        // room makes the blocker non-nil ("You're already in a meeting"),
        // and a `.sheet` attached to a view that has just been swapped
        // out never presents.
        content
            .sheet(isPresented: $showingRoom) {
                PitchRoomSheet(engine: engine, counterpart: counterpart, subjectID: subjectID)
            }
            // `-autoPitch <counterpart>`: a screenshot pass cannot tap, so
            // the button matching the flag opens itself once. DEBUG only,
            // and it does exactly what the tap does.
            .onAppear {
                guard !hasAutoOpened,
                      DebugLaunch.launchPitchCounterpart == counterpart.rawValue
                else { return }
                hasAutoOpened = true
                showingRoom = true
            }
    }

    @ViewBuilder
    private var content: some View {
        let blocker = engine.state.pitchBlocker(
            for: counterpart, subjectID: subjectID,
            balance: engine.balance, content: engine.content
        )
        // "Nothing to talk about" is not a refusal worth a disabled
        // button: the invitation simply isn't there. Everything else — a
        // conversation already had, the founder out of the building — is
        // shown, because the player looked for it.
        if blocker == nil {
            invitation
        } else if hasSubject, let blocker {
            Label(blocker, systemImage: "bubble.left.slash")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            // Nobody there: nothing at all, but the sheet's host stays.
            Color.clear.frame(width: 0, height: 0)
        }
    }

    /// Whether the counterpart exists at all right now — the difference
    /// between "already talked to them" and "there is nobody there".
    private var hasSubject: Bool {
        engine.state.pitchSubject(
            for: counterpart, balance: engine.balance, content: engine.content
        ) != nil
    }

    private var invitation: some View {
        VStack(alignment: .leading, spacing: 2) {
            Button {
                showingRoom = true
            } label: {
                Label(counterpart.invitation, systemImage: "bubble.left.and.text.bubble.right.fill")
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .frame(maxWidth: prominent ? .infinity : nil)
            }
            .buttonStyle(.bordered)
            .tint(Theme.accent)
            Text(counterpart.stakesLine)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(counterpart.invitation). \(counterpart.stakesLine)")
    }
}
