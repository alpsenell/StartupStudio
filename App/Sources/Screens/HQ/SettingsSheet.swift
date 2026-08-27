import SwiftUI
import TycoonEngine

/// Settings for the running game, opened from the gear button at the
/// bottom of HQ: the current difficulty, "Start a new game…" (confirmation,
/// then the difficulty choice), and the app version.
struct SettingsSheet: View {
    let engine: GameEngine
    let onNewGame: (Difficulty) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var confirmingNewGame = false
    @State private var choosingDifficulty = false

    var body: some View {
        NavigationStack {
            List {
                Section("Game") {
                    LabeledContent("Difficulty") {
                        Text(engine.state.difficulty.displayName)
                    }
                    LabeledContent("Company") {
                        Text(engine.state.company.name)
                    }
                }

                Section {
                    Button(role: .destructive) {
                        confirmingNewGame = true
                    } label: {
                        Label("Start a new game…", systemImage: "arrow.counterclockwise")
                    }
                } footer: {
                    Text("Deletes the current company and its save. You'll pick a difficulty next.")
                }

                Section("About") {
                    LabeledContent("Version") {
                        Text(Self.versionLabel)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .confirmationDialog(
                "Start over?",
                isPresented: $confirmingNewGame,
                titleVisibility: .visible
            ) {
                Button("Delete game and choose difficulty", role: .destructive) {
                    choosingDifficulty = true
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Your current company will be deleted for good.")
            }
            .sheet(isPresented: $choosingDifficulty) {
                DifficultyPickerSheet(current: engine.state.difficulty) { difficulty in
                    choosingDifficulty = false
                    onNewGame(difficulty)
                    dismiss()
                }
            }
        }
    }

    /// "0.1.0 (1)" from the bundle; falls back to the project defaults.
    private static var versionLabel: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "0.1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(short) (\(build))"
    }
}
