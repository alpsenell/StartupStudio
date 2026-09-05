import SwiftUI
import TycoonEngine

/// One selectable founding origin — the same row the difficulty picker
/// uses, so the Stakes page reads as one list of choices. Shared by
/// `NewGameFlow` (where each row sits in its own card) and
/// `FounderSetupSheet` (where the rows sit inside one card).
///
/// Iteration 7 (R4): a row can be padlocked. The lock is the picker's
/// alone — the engine founds any origin for anyone — and it reads the
/// ledger, never the run.
struct OriginRow: View {
    let origin: FoundingOrigin
    let isSelected: Bool
    /// Padlocked: not selectable, with `lockReason` under the name.
    var isLocked = false
    var lockReason: String = Unlocks.originLockReason
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: isLocked ? "lock.fill" : origin.systemImageName)
                    .font(.title3)
                    .foregroundStyle(isLocked ? AnyShapeStyle(.tertiary) : isSelected ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(.secondary))
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(origin.displayName)
                        .font(.system(.headline, design: .rounded))
                        .foregroundStyle(isLocked ? .secondary : .primary)
                    if isLocked {
                        Label(lockReason, systemImage: "lock")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Theme.accent)
                    }
                    Text(origin.blurb)
                        .font(.footnote)
                        .foregroundStyle(isLocked ? .tertiary : .secondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: isLocked ? "lock.circle.fill" : isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected && !isLocked ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(.tertiary))
            }
            .padding(Theme.Spacing.md)
            .background(
                isSelected && !isLocked ? Theme.accent.opacity(0.10) : Color.clear,
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressable)
        .disabled(isLocked)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            isLocked
                ? "\(origin.displayName), locked. \(lockReason). \(origin.blurb)"
                : "\(origin.displayName). \(origin.blurb)"
        )
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

/// The four origins as a list, bound to the choice.
struct OriginPicker: View {
    @Binding var origin: FoundingOrigin
    /// Whether each row gets its own card (the new-game flow) or sits bare
    /// inside a card the caller supplies (the founder setup sheet).
    var rowsAreCards = true
    /// Iteration 7 (R4): the origins padlocked. `nil` reads the session's
    /// ledger when there is one, and locks nothing when there is not (a
    /// preview, a snapshot); the new-game flow passes the ledger's answer
    /// itself, since a full-screen cover does not see the environment.
    var lockedOrigins: Set<FoundingOrigin>?

    @Environment(\.gameSession) private var session

    private var locked: Set<FoundingOrigin> {
        if let lockedOrigins { return lockedOrigins }
        guard let session else { return [] }
        return Unlocks.lockedOrigins(endingsReached: session.ledger.endingsReached)
    }

    var body: some View {
        VStack(spacing: Theme.Spacing.sm) {
            ForEach(FoundingOrigin.allCases, id: \.self) { candidate in
                // A locked origin that is already chosen (a code carried
                // it) keeps its tick: the code is the friend's life, and
                // the lock is about picking it cold.
                let isLocked = locked.contains(candidate) && candidate != origin
                let row = OriginRow(origin: candidate, isSelected: candidate == origin, isLocked: isLocked) {
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
