import SwiftUI
import TycoonEngine

// MARK: Iteration 12 — J1 (doors)

/// One door, on a sheet of pixel paper: who it is from, what they want,
/// how long they will wait, and the answers with what each one costs
/// printed under it. Pushed from the Life tab (`LifeDestination.door`),
/// which every way in — the card, a tip, `-autoRoute door` — lands on.
///
/// Nothing here writes state except the answer the thumb gives, sent as
/// `.answerDoor`; the room behind a yes is woken by the engine, and this
/// page only takes the founder there.
struct DoorSheet: View {
    let engine: GameEngine
    let kind: DoorKind

    @Environment(AppRouter.self) private var router
    /// The fame door's yes: the compose sheet, with the launch post drafted.
    @State private var composing = false

    private var state: GameState { engine.state }
    private var record: DoorRecord? { state.doors.record(kind) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                letter
                if let record {
                    if record.isOpen(on: state.day) {
                        answers
                    } else {
                        outcome(record)
                    }
                } else {
                    Text("Nobody has knocked yet.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(Theme.Spacing.lg)
        }
        .background(Theme.screenBackground)
        .navigationTitle(DoorCopy.title(kind))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $composing, onDismiss: { router.go(.feed) }) {
            FeedComposeSheet(engine: engine, draft: .launch)
        }
        .task {
            if let choice = DoorDebug.takeAnswer(for: kind) { answer(choice) }
        }
    }

    // MARK: - The letter

    private var letter: some View {
        PixelPanel {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                HStack(alignment: .center, spacing: Theme.Spacing.md) {
                    PixelIconTile(systemImage: DoorCopy.icon(kind), tint: DoorCopy.tint(kind), size: 56)
                    VStack(alignment: .leading, spacing: 4) {
                        PixelText(text: DoorCopy.title(kind), scale: 2, color: Theme.pixelInk)
                        Text(DoorCopy.sender(kind, record: record, state: state, content: engine.content))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.pixelInk.opacity(0.7))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Text(DoorCopy.letter(kind, record: record, engine: engine))
                    .font(.callout)
                    .foregroundStyle(Theme.pixelInk)
                    .fixedSize(horizontal: false, vertical: true)
                if let record, record.isOpen(on: state.day) {
                    Text(deadline(record))
                        .font(.caption.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(record.daysLeft(on: state.day) <= 2 ? Theme.warning : Theme.pixelInk.opacity(0.7))
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func deadline(_ record: DoorRecord) -> String {
        switch record.daysLeft(on: state.day) {
        case 0: "Today is the last day. After that, it's a no."
        case 1: "One day to answer. After that, it's a no."
        case let days: "\(days) days to answer. After that, it's a no."
        }
    }

    // MARK: - The answers

    private var answers: some View {
        VStack(spacing: Theme.Spacing.sm) {
            ForEach(DoorChoice.choices(for: kind), id: \.self) { choice in
                let refusal = DoorRules.refusal(kind, choice, state: state, balance: engine.balance)
                Button { answer(choice) } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(DoorCopy.label(choice, kind: kind, state: state, content: engine.content))
                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        Text(refusal?.reason ?? DoorCopy.consequence(choice, kind: kind, engine: engine))
                            .font(.caption)
                            .opacity(0.85)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(PixelButtonStyle(fill: choice.opens ? Theme.pixelAccent : Theme.pixelPaper))
                .disabled(refusal != nil)
                .opacity(refusal == nil ? 1 : 0.55)
            }
        }
    }

    private func answer(_ choice: DoorChoice) {
        engine.send(.answerDoor(kind: kind, choice: choice))
        guard engine.state.doors.record(kind)?.answer == choice else { return }
        guard choice.opens else {
            Haptics.tap()
            return
        }
        Haptics.commit()
        if kind == .fame {
            composing = true
        } else {
            router.go(DoorCopy.destination(kind))
        }
    }

    // MARK: - After

    private func outcome(_ record: DoorRecord) -> some View {
        CardView("What happened", systemImage: record.answer?.opens == true
            ? "door.left.hand.open" : "door.left.hand.closed") {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                Text(DoorCopy.outcome(record, engine: engine))
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
                if record.answer?.opens == true {
                    Button {
                        Haptics.tap()
                        router.go(DoorCopy.destination(kind))
                    } label: {
                        Label("Go there", systemImage: "arrow.forward")
                            .font(.subheadline.weight(.semibold))
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }
}
