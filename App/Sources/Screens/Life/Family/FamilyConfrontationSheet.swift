import SwiftUI
import TycoonEngine

/// Iteration 11, wave two — W2. The night it comes out.
///
/// Rule 11: an affair is a fact, and this is a conversation about a fact.
/// Nothing is described; four things can be said, each one carries its own
/// consequence on the button, and the room answers in one line.
struct FamilyConfrontationSheet: View {
    let engine: GameEngine
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    PixelPanel(contentPadding: Theme.Spacing.md) {
                        HStack(alignment: .top, spacing: Theme.Spacing.md) {
                            if let seed = engine.state.life.family.partnerAppearanceSeed {
                                PixelPortrait(seed: seed, size: 44)
                                    .padding(3)
                                    .background(Theme.pixelPaper)
                                    .overlay {
                                        PixelPanelBorder(thickness: 2, corner: 2)
                                            .fill(Theme.pixelInk)
                                    }
                                    .accessibilityHidden(true)
                            }
                            VStack(alignment: .leading, spacing: 6) {
                                Text(answered?.line ?? openingLine)
                                    .font(.callout)
                                    .foregroundStyle(Theme.pixelInk)
                                    .fixedSize(horizontal: false, vertical: true)
                                Text(engine.state.life.family.partnerName ?? "Your partner")
                                    .font(.caption2)
                                    .foregroundStyle(Theme.pixelInk.opacity(0.55))
                            }
                            Spacer(minLength: 0)
                        }
                    }

                    if answered == nil {
                        VStack(spacing: Theme.Spacing.sm) {
                            ForEach(FamilyConfession.allCases, id: \.self) { answer in
                                Button { say(answer) } label: {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(answer.label)
                                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                                        Text(answer.detail)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(Theme.Spacing.md)
                                    .background(Theme.cardBackground, in: RoundedRectangle(
                                        cornerRadius: 12, style: .continuous
                                    ))
                                }
                                .buttonStyle(.pressableRow)
                            }
                        }
                    } else {
                        Text("Whatever happens next happens over weeks, not tonight.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(Theme.Spacing.lg)
            }
            .background(Theme.screenBackground)
            .navigationTitle("Tonight")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var answered: FamilyConfession? {
        engine.state.familyDrama.confessionAnswer.flatMap(FamilyConfession.init(rawValue:))
    }

    private var openingLine: String {
        "\"I'm not going to shout. I'd just like you to say it out loud, once.\""
    }

    private func say(_ answer: FamilyConfession) {
        engine.send(.confrontFamily(answer))
        Haptics.commit()
    }
}
