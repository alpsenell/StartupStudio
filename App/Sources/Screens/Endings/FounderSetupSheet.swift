import PixelKit
import SwiftUI
import TycoonEngine

/// Who you are this time: a name, a face, an archetype, and a difficulty.
///
/// Reached from the founder biography's "Start a new company". WS-E's
/// `NewGameFlow` will front the same `FounderProfile` API on first launch;
/// until then this is where a player picks an identity, and it is the only
/// way archetype skill spreads reach the game.
struct FounderSetupSheet: View {
    let defaultCompanyName: String
    let onStart: (Difficulty, FounderProfile, FoundingOrigin) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var archetype: FounderArchetype = .hacker
    @State private var difficulty: Difficulty = .normal
    @State private var origin: FoundingOrigin = .garage
    /// Re-rolled by the shuffle button; `nil` lets the engine draw one.
    @State private var appearanceSeed: UInt64 = UInt64.random(in: .min ... .max)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.lg) {
                    facePicker
                    nameField
                    archetypePicker
                    originPicker
                    difficultyPicker
                    startButton
                }
                .padding(Theme.Spacing.lg)
            }
            .background(Theme.screenBackground)
            .navigationTitle("New founder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    // MARK: - Face

    private var facePicker: some View {
        VStack(spacing: Theme.Spacing.sm) {
            PixelPortrait(seed: appearanceSeed, isFounder: true, size: 88)
            Button {
                appearanceSeed = UInt64.random(in: .min ... .max)
            } label: {
                Label("Shuffle", systemImage: "shuffle")
                    .font(.system(.caption, design: .rounded).weight(.semibold))
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("Shuffle the founder's appearance")
        }
    }

    // MARK: - Name

    private var nameField: some View {
        CardView("Your name", systemImage: "person.fill") {
            TextField("Founder", text: $name)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .font(.system(.body, design: .rounded))
                .accessibilityLabel("Founder name")
        }
    }

    // MARK: - Archetype

    private var archetypePicker: some View {
        CardView("What you're good at", systemImage: "star.fill") {
            VStack(spacing: Theme.Spacing.sm) {
                ForEach(FounderArchetype.allCases, id: \.self) { option in
                    Button {
                        archetype = option
                    } label: {
                        HStack(alignment: .top, spacing: Theme.Spacing.md) {
                            Image(systemName: option.systemImageName)
                                .font(.title3)
                                .frame(width: 28)
                                .foregroundStyle(option == archetype ? Theme.accent : .secondary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(option.displayName)
                                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                                    .foregroundStyle(.primary)
                                Text(option.blurb)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)
                                Text("Strongest in \(option.headlineSkill.lowercased())")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: option == archetype ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(option == archetype ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(.tertiary))
                        }
                        .padding(.vertical, Theme.Spacing.xs)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.pressableRow)
                    .accessibilityLabel("\(option.displayName). \(option.blurb)")
                    .accessibilityAddTraits(option == archetype ? [.isSelected] : [])
                }
            }
        }
    }

    // MARK: - Origin

    /// The same four starts the new-game flow's Stakes page offers.
    private var originPicker: some View {
        CardView("How it starts", systemImage: "flag.fill") {
            OriginPicker(origin: $origin, rowsAreCards: false)
        }
    }

    // MARK: - Difficulty

    private var difficultyPicker: some View {
        CardView("How hard", systemImage: "dial.medium.fill") {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Picker("Difficulty", selection: $difficulty) {
                    ForEach(Difficulty.allCases, id: \.self) { level in
                        Text(level.displayName).tag(level)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityLabel("Difficulty")

                Text(difficulty.blurb)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Start

    private var startButton: some View {
        Button {
            onStart(
                difficulty,
                FounderProfile(name: name, archetype: archetype, appearanceSeed: appearanceSeed),
                origin
            )
        } label: {
            Label("Start building", systemImage: "play.fill")
                .font(.system(.headline, design: .rounded))
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Spacing.sm)
        }
        .buttonStyle(.borderedProminent)
        .tint(Theme.accent)
        .accessibilityLabel(
            "Start a new company as \(name.isEmpty ? "Founder" : name), "
                + "\(archetype.displayName), \(origin.displayName), on \(difficulty.displayName)"
        )
    }
}
