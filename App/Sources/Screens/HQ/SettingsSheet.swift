import SwiftUI
import TycoonEngine

/// Settings for the running game, opened from the gear button at the
/// bottom of HQ: feedback toggles (sound, haptics, the weekly report),
/// "Start a new game…" (confirmation, then the full new-game flow), and
/// the app version.
struct SettingsSheet: View {
    let engine: GameEngine
    /// Opens the new-game flow. The running game keeps ticking until the
    /// flow finishes, so a cancelled flow costs the player nothing.
    let onNewGame: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var confirmingNewGame = false
    @State private var soundEnabled = GameSettings.soundEnabled
    @State private var hapticsEnabled = GameSettings.hapticsEnabled
    @State private var weeklyReportAuto = GameSettings.weeklyReportAuto

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
                    LabeledContent("Founder") {
                        Text(engine.state.employees.first(where: \.isFounder)?.name ?? "—")
                    }
                }

                Section {
                    Toggle(isOn: $soundEnabled) {
                        Label("Sound effects", systemImage: "speaker.wave.2.fill")
                    }
                    .onChange(of: soundEnabled) { _, enabled in
                        Sounds.isEnabled = enabled
                        if enabled { Sounds.play(.tap) }
                    }

                    Toggle(isOn: $hapticsEnabled) {
                        Label("Haptics", systemImage: "iphone.radiowaves.left.and.right")
                    }
                    .onChange(of: hapticsEnabled) { _, enabled in
                        Haptics.isEnabled = enabled
                        if enabled { Haptics.commit() }
                    }

                    Toggle(isOn: $weeklyReportAuto) {
                        Label("Weekly report: auto", systemImage: "calendar.badge.clock")
                    }
                    .onChange(of: weeklyReportAuto) { _, enabled in
                        GameSettings.weeklyReportAuto = enabled
                    }
                } header: {
                    Text("Feedback")
                } footer: {
                    Text("Sound is synthesized in-app and follows the silent switch. The weekly report can always be opened from the chip in the HUD.")
                }

                Section {
                    Button {
                        GameSettings.resetTips()
                    } label: {
                        Label("Show coach tips again", systemImage: "lightbulb")
                    }
                }

                Section {
                    Button(role: .destructive) {
                        confirmingNewGame = true
                    } label: {
                        Label("Start a new game…", systemImage: "arrow.counterclockwise")
                    }
                } footer: {
                    Text("Deletes the current company and its save. You'll name a new founder and studio next.")
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
                Button("Delete game and start over", role: .destructive) {
                    dismiss()
                    onNewGame()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("\(engine.state.company.name) will be deleted for good.")
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
