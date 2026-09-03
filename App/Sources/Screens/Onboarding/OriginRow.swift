import SwiftUI
import TycoonEngine

/// One selectable founding origin — the same row the difficulty picker
/// uses, so the Stakes page reads as one list of choices. Shared by
/// `NewGameFlow` (where each row sits in its own card) and
/// `FounderSetupSheet` (where the rows sit inside one card).
struct OriginRow: View {
    let origin: FoundingOrigin
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: origin.systemImageName)
                    .font(.title3)
                    .foregroundStyle(isSelected ? Theme.accent : .secondary)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(origin.displayName)
                        .font(.system(.headline, design: .rounded))
                        .foregroundStyle(.primary)
                    Text(origin.blurb)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(.tertiary))
            }
            .padding(Theme.Spacing.md)
            .background(
                isSelected ? Theme.accent.opacity(0.10) : Color.clear,
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressable)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(origin.displayName). \(origin.blurb)")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

/// The four origins as a list, bound to the choice.
struct OriginPicker: View {
    @Binding var origin: FoundingOrigin
    /// Whether each row gets its own card (the new-game flow) or sits bare
    /// inside a card the caller supplies (the founder setup sheet).
    var rowsAreCards = true

    var body: some View {
        VStack(spacing: Theme.Spacing.sm) {
            ForEach(FoundingOrigin.allCases, id: \.self) { candidate in
                let row = OriginRow(origin: candidate, isSelected: candidate == origin) {
                    Haptics.tap()
                    withAnimation(Theme.Motion.selection) { origin = candidate }
                }
                if rowsAreCards {
                    row.cardStyle()
                } else {
                    row
                }
            }
        }
    }
}
