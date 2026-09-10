import SwiftUI
import TycoonEngine

// MARK: Iteration 12 — J1 (doors)

/// The doors waiting on an answer, on the Life tab. Draws nothing at all
/// while no door is open, so a run that never meets one sees the tab it
/// always saw.
struct DoorsCard: View {
    let engine: GameEngine
    let onOpen: (DoorKind) -> Void

    var body: some View {
        let day = engine.state.day
        let open = engine.state.doors.open(on: day)
        if !open.isEmpty {
            CardView("At the door", systemImage: "door.left.hand.open") {
                VStack(spacing: Theme.Spacing.sm) {
                    ForEach(open) { record in
                        Button {
                            Haptics.tap()
                            onOpen(record.kind)
                        } label: {
                            HStack(spacing: Theme.Spacing.md) {
                                Image(systemName: DoorCopy.icon(record.kind))
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(DoorCopy.tint(record.kind))
                                    .frame(width: 22)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(DoorCopy.railTitle(record.kind))
                                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                                        .foregroundStyle(.primary)
                                    Text(left(record, day: day))
                                        .font(.caption)
                                        .monospacedDigit()
                                        .foregroundStyle(record.daysLeft(on: day) <= 2 ? Theme.warning : .secondary)
                                }
                                Spacer(minLength: 0)
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.secondary)
                            }
                            .frame(minHeight: 44)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.pressableRow)
                        .accessibilityHint("Opens the question")
                    }
                }
            }
        }
    }

    private func left(_ record: DoorRecord, day: Int) -> String {
        switch record.daysLeft(on: day) {
        case 0: "Answers itself today — as a no"
        case 1: "1 day left, then it's a no"
        case let days: "\(days) days left, then it's a no"
        }
    }
}

/// Life B5: the launch-day sheet's way into the feed. Opens the compose
/// sheet with the launch post drafted; nothing is posted — and the feed
/// is not engaged — until the founder taps a row there.
struct DoorTellPeopleRow: View {
    let engine: GameEngine
    let action: () -> Void

    var body: some View {
        let blocker = Fame.postBlocker(kind: .launch, state: engine.state, content: engine.content)
        Button {
            Haptics.tap()
            action()
        } label: {
            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: "megaphone.fill")
                    .font(.subheadline.weight(.bold))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Tell people")
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    Text(blocker ?? "Opens the feed with the launch post drafted · one post a day · nothing goes out until you tap")
                        .font(.caption)
                        .opacity(0.85)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
        }
        .buttonStyle(PixelButtonStyle(fill: Theme.pixelAccent))
        .disabled(blocker != nil)
        .opacity(blocker == nil ? 1 : 0.55)
    }
}

/// The compose sheet's header when a post arrives already written — from
/// the fame door's yes, or from launch day's *Tell people*.
struct DoorDraftNote: View {
    let engine: GameEngine
    let kind: FamePostKind

    var body: some View {
        PixelPanel {
            VStack(alignment: .leading, spacing: 6) {
                PixelText(text: "Drafted", scale: 2, color: Theme.pixelAccent)
                Text(line)
                    .font(.callout)
                    .italic()
                    .foregroundStyle(Theme.pixelInk)
                    .fixedSize(horizontal: false, vertical: true)
                Text("It is the \(kind.displayName) row below, outlined. Nothing goes out until you tap it.")
                    .font(.caption)
                    .foregroundStyle(Theme.pixelInk.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var line: String {
        let shipped = engine.state.products.last { product in
            if case .released = product.stage { return true }
            return false
        }
        guard let name = shipped?.name else {
            return "\u{201C}We made a thing. It is out. Go and look.\u{201D}"
        }
        return "\u{201C}\(name) is out. We made it in a room with no windows. Go and look.\u{201D}"
    }
}
