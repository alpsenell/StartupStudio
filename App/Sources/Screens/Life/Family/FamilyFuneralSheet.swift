import SwiftUI
import TycoonEngine

/// Iteration 11, wave two — W2. A stopped day with the family in the room
/// and exactly one argument to settle.
struct FamilyFuneralSheet: View {
    let engine: GameEngine
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    PixelPanel(contentPadding: Theme.Spacing.md) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(who)
                                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                                .foregroundStyle(Theme.pixelInk)
                            Text(answered?.line ?? opening)
                                .font(.callout)
                                .foregroundStyle(Theme.pixelInk)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    if answered == nil {
                        VStack(spacing: Theme.Spacing.sm) {
                            ForEach(FamilyDrama.FuneralArgument.allCases, id: \.self) { answer in
                                Button { settle(answer) } label: {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(answer.label)
                                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                                        Text(answer.detail)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
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
                    }
                }
                .padding(Theme.Spacing.lg)
            }
            .background(Theme.screenBackground)
            .navigationTitle("The funeral")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var who: String {
        let relation = engine.state.familyDrama.funeralRelation
            .flatMap(FamilyRelation.init(rawValue:))
        guard let relation else { return "The service is at eleven." }
        let name = engine.state.familyRelativeName(relation, content: engine.content)
        return "\(name) · \(relation.shortName)"
    }

    private var opening: String {
        let sibling = engine.state.familyRelativeName(.sibling, content: engine.content)
        return "\(sibling) has told the room, twice, about the year you did not come home for "
            + "Christmas. It is the third time today it has come up and the sandwiches are not out yet."
    }

    private var answered: FamilyDrama.FuneralArgument? {
        engine.state.familyDrama.funeralAnswer
            .flatMap(FamilyDrama.FuneralArgument.init(rawValue:))
    }

    private func settle(_ answer: FamilyDrama.FuneralArgument) {
        engine.send(.settleFuneral(answer))
        Haptics.commit()
    }
}
