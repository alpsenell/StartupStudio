import PixelKit
import SwiftUI

/// The little pixel vignette that plays after an instant activity. Pure
/// celebration — the action was already sent; nothing here touches game
/// logic. Auto-dismisses after a few seconds, with Done as the escape
/// hatch.
struct ActivityPlaybackSheet: View {
    let playing: PlayingActivity
    let appearanceSeed: UInt64

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: Theme.Spacing.lg) {
                Spacer(minLength: 0)

                PixelSceneView(
                    placements: ActivitySceneComposer.compose(
                        style: playing.style,
                        appearance: CharacterAppearance(seed: appearanceSeed),
                        isFounder: true
                    ),
                    sceneSize: ActivitySceneComposer.sceneSize(),
                    accessibilityLabel: "\(playing.title) scene"
                )
                .frame(maxWidth: 340)
                .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))

                VStack(spacing: Theme.Spacing.xs) {
                    Text(playing.title)
                        .font(.system(.title3, design: .rounded).weight(.bold))
                    Text(playing.summary)
                        .font(.subheadline)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)
            }
            .padding(Theme.Spacing.lg)
            .background(Theme.screenBackground)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
        .task {
            try? await Task.sleep(for: .seconds(3.5))
            dismiss()
        }
    }
}
