import SwiftUI
import TycoonEngine

/// Iteration 11 — N2. The one line every person's card gains: a button
/// that opens the whole menu for them.
///
/// It carries its own presentation state so a card in another lane's file
/// needs exactly one inserted line inside its marked region, and no
/// changes to its body, its `@State` or its modifiers.
struct PeopleMenuButton: View {
    let engine: GameEngine
    let target: InteractionTarget
    /// Compact drops the caption, for the tighter cards.
    var compact = false

    @State private var showing = false

    private var count: Int {
        engine.state.peopleMenu(for: target, content: engine.content).count
    }

    var body: some View {
        Button {
            Haptics.tap()
            showing = true
        } label: {
            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: "ellipsis.bubble.fill")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Things you could do")
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(.primary)
                    if !compact {
                        Text("\(count) of them. Not all of them are kind.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Theme.Spacing.md)
            .background(
                Theme.chipBackground,
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
        }
        .buttonStyle(.pressableRow)
        .accessibilityLabel("Things you could do to \(engine.state.interactionName(target, content: engine.content))")
        .sheet(isPresented: $showing) {
            PeopleMenuSheet(engine: engine, target: target)
        }
    }
}
