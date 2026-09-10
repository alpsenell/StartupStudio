import SwiftUI
import TycoonEngine

// MARK: Iteration 11 — N4 (fame and the feed)

/// What to say. Four kinds, each with what it does on the row and, when
/// it is refused, why — which is rule 7, and the whole reason the sheet
/// exists rather than a single *Post* button.
///
/// A subtweet also picks its target: the strongest studio on the board is
/// the default, because that is the one worth being seen to name.
struct FeedComposeSheet: View {
    let engine: GameEngine
    // MARK: J1 (doors)
    /// The kind whose post arrives already written (the fame door's yes,
    /// launch day's *Tell people*): a drafted note above the rows, and
    /// that row outlined. `nil` is the sheet as it always was.
    var draft: FamePostKind? = nil
    // MARK: end J1

    @Environment(\.dismiss) private var dismiss
    @State private var subject: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    Text("One post a day. Reach is a roll — the same sentence twice "
                        + "is not the same sentence twice.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    // MARK: J1 (doors)
                    if let draft {
                        DoorDraftNote(engine: engine, kind: draft)
                    }
                    // MARK: end J1

                    ForEach(FamePostKind.allCases.filter { $0 != .reply }, id: \.self) { kind in
                        kindRow(kind)
                    }

                    if !rivals.isEmpty {
                        CardView("Who the subtweet is about", systemImage: "at") {
                            VStack(spacing: Theme.Spacing.xs) {
                                ForEach(rivals, id: \.self) { name in
                                    Button {
                                        Haptics.tap()
                                        subject = name
                                    } label: {
                                        HStack {
                                            Text(name)
                                                .font(.system(.subheadline, design: .rounded)
                                                    .weight(.semibold))
                                            Spacer(minLength: 0)
                                            if name == selectedSubject {
                                                Image(systemName: "checkmark")
                                                    .font(.caption.weight(.bold))
                                                    .foregroundStyle(Theme.accent)
                                            }
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    .buttonStyle(.pressableRow)
                                }
                            }
                        }
                    }
                }
                .padding(Theme.Spacing.lg)
            }
            .background(Theme.screenBackground)
            .navigationTitle("Say something")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Not today") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
    }

    // MARK: - One kind

    @ViewBuilder
    private func kindRow(_ kind: FamePostKind) -> some View {
        let blocker = Fame.postBlocker(
            kind: kind, state: engine.state, content: engine.content
        )
        Button {
            Haptics.tap()
            engine.send(.postToFeed(
                kind: kind, subject: kind == .subtweet ? selectedSubject : nil
            ))
            dismiss()
        } label: {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: kind.systemImage)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Theme.accent)
                    Text(kind.displayName)
                        .font(.system(.headline, design: .rounded))
                        .foregroundStyle(.primary)
                    Spacer(minLength: 0)
                    Text("×\(multiplier(kind))")
                        .font(Theme.Typography.number(.caption))
                        .foregroundStyle(.secondary)
                }
                Text(kind.promise)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if let blocker {
                    Text(blocker)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.warning)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("About \(FeedFormat.count(expectedReach(kind))) people, give or take a lot.")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Theme.Spacing.md)
            .background(
                Theme.chipBackground,
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            // MARK: J1 (doors)
            .overlay {
                if kind == draft {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Theme.accent, lineWidth: 2)
                }
            }
            // MARK: end J1
        }
        .buttonStyle(.pressableRow)
        .disabled(blocker != nil)
        .opacity(blocker == nil ? 1 : 0.55)
    }

    // MARK: - Numbers on the row

    private func multiplier(_ kind: FamePostKind) -> String {
        let value = engine.balance.fame.reachMultiplier(kind)
        return value == value.rounded() ? "\(Int(value))" : String(format: "%.2g", value)
    }

    /// The midpoint of the roll, so the row can promise a ballpark without
    /// pretending it knows the number.
    private func expectedReach(_ kind: FamePostKind) -> Int {
        let config = engine.balance.fame
        let midRoll = (config.rollFloor + config.rollCeiling) / 2
        return Fame.reach(
            followers: engine.state.fame.followers,
            fame: engine.state.fame.fame,
            kindMultiplier: config.reachMultiplier(kind),
            newsMultiplier: 1,
            roll: midRoll,
            balance: config
        ).reach
    }

    private var rivals: [String] {
        engine.state.rivals.rivals
            .sorted { $0.strength > $1.strength }
            .prefix(5)
            .map(\.name)
    }

    private var selectedSubject: String? {
        subject ?? rivals.first
    }
}
