import SwiftUI
import TycoonEngine

/// Sheet listing every `Difficulty` (name + blurb). Tapping one calls
/// `onChoose` — the caller starts the new game and dismisses. Used by the
/// game-over screen and the Settings sheet's "Start a new game…".
struct DifficultyPickerSheet: View {
    /// Highlighted with a checkmark when set (the running game's setting).
    var current: Difficulty?
    let onChoose: (Difficulty) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(Difficulty.allCases, id: \.self) { difficulty in
                        Button {
                            onChoose(difficulty)
                        } label: {
                            DifficultyRow(
                                difficulty: difficulty,
                                isCurrent: difficulty == current
                            )
                        }
                        .buttonStyle(.pressableRow)
                        .accessibilityLabel("\(difficulty.displayName). \(difficulty.blurb)")
                        .accessibilityHint("Starts a new game")
                    }
                } header: {
                    Text("Choose a difficulty")
                } footer: {
                    Text("You can't change this once the game has started.")
                }
            }
            .navigationTitle("New game")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

private struct DifficultyRow: View {
    let difficulty: Difficulty
    let isCurrent: Bool

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.md) {
            Image(systemName: difficulty.systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(Theme.accent)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: Theme.Spacing.sm) {
                    Text(difficulty.displayName)
                        .font(.system(.headline, design: .rounded))
                    if isCurrent {
                        Text("Current")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, Theme.Spacing.xs + 2)
                            .padding(.vertical, 2)
                            .background(Theme.chipBackground, in: Capsule())
                    }
                }
                Text(difficulty.blurb)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, Theme.Spacing.xs)
        .contentShape(Rectangle())
    }
}

// MARK: - Presentation

extension Difficulty {
    /// SF Symbol for the difficulty, shared by the picker and the HQ chip.
    var systemImage: String {
        switch self {
        case .easy: "leaf.fill"
        case .normal: "dial.medium.fill"
        case .hard: "flame.fill"
        }
    }
}
