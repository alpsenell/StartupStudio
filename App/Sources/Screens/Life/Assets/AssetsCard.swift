import SwiftUI
import TycoonEngine

/// Iteration 11 — N3. The Life tab's door into the founder's own balance
/// sheet: what they own, what it costs a week, and whatever is currently
/// off the road or waiting at the doctor's.
///
/// Sits under *Money and home*, beside the wallet, because it is the same
/// money.
struct AssetsCard: View {
    let engine: GameEngine
    let onOpen: () -> Void

    var body: some View {
        let state = engine.state
        let assets = state.assets
        let owned = assets.owned
        let weekly = state.assetWeeklyCosts(balance: engine.balance)
        let worth = state.assetResaleValue(balance: engine.balance)

        Group {
            // MARK: V1 (ux: Life folded, rooms dormant) — C2
            // Nothing on Life until the room has something in it (a
            // door, an event, a case, a first post): until then it is a
            // quiet row under "Other rooms". The modifiers below stay on
            // the stand-in, so the card's debug hooks still run.
            if LifeRoom.assets.isOpen(in: engine.state, balance: engine.balance) {
                CardView("What you own", systemImage: "key.fill") {
                    VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                        if owned.isEmpty, assets.crypto == nil {
                            Text("A wallet, a salary and a rented home. There is a whole other column and nothing is in it yet.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                            HStack(alignment: .top, spacing: Theme.Spacing.xl) {
                                AssetFigure(label: "Resale value", value: worth.money, tint: .primary)
                                AssetFigure(
                                    label: weekly >= 0 ? "Upkeep" : "Income",
                                    value: "\(abs(weekly).money)/wk",
                                    tint: weekly > 0 ? Theme.negativeCash : Theme.positiveCash
                                )
                            }
                            Text(inventoryLine(owned))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        if let warning = warningLine(state) {
                            HStack(alignment: .top, spacing: Theme.Spacing.sm) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.caption.weight(.semibold))
                                Text(warning)
                                    .font(.footnote)
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer(minLength: 0)
                            }
                            .foregroundStyle(Theme.warning)
                            .padding(Theme.Spacing.sm)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                Theme.warning.opacity(0.12),
                                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                            )
                        }

                        Button {
                            Haptics.tap()
                            onOpen()
                        } label: {
                            HStack {
                                Label(owned.isEmpty ? "The garage, the deeds and the doctor" : "Open your things",
                                      systemImage: "chevron.right.circle.fill")
                                    .font(.footnote.weight(.semibold))
                                Spacer(minLength: 0)
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                }
            } else {
                LifeRoomDormant()
            }
            // MARK: end V1
        }
    }

    /// "A coupé, a flat and a dog" — what the founder would say if asked.
    private func inventoryLine(_ owned: [AssetOwned]) -> String {
        let names = owned
            .sorted { $0.catalogID < $1.catalogID }
            .compactMap { engine.balance.assets.asset($0.catalogID)?.name.assetLowercasedFirst }
        guard !names.isEmpty else { return "A wallet that moves on its own, and nothing else." }
        return names.joined(separator: " · ")
    }

    /// The one thing on this card that wants doing today.
    private func warningLine(_ state: GameState) -> String? {
        if let broken = state.assets.owned.first(where: \.needsRepair),
           let def = engine.balance.assets.asset(broken.catalogID) {
            return "\(def.name) is off the road. The bill is \(def.repairCost.money)."
        }
        if let ailment = state.assets.ailments.first(where: { !$0.isBeingTreated }),
           let def = engine.balance.assets.ailment(ailment.id) {
            return "The doctor has written down \(def.name.assetLowercasedFirst). It is still untreated."
        }
        if let worst = state.assets.worstVice,
           let def = engine.balance.assets.vice(worst.id),
           worst.dependency >= def.interventionAt {
            return "\(def.name) is past the point where people have started saying something."
        }
        return nil
    }
}

private struct AssetFigure: View {
    let label: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(Theme.Typography.number(.title3))
                .foregroundStyle(tint)
                .contentTransition(.numericText())
                .animation(Theme.Motion.valueChange, value: value)
        }
        .accessibilityElement(children: .combine)
    }
}

extension String {
    /// "The German coupé" → "the German coupé", for use mid-sentence.
    /// Leaves an all-caps word alone.
    var assetLowercasedFirst: String {
        guard let first, first.isUppercase,
              !(count > 1 && dropFirst().allSatisfy { $0.isUppercase || !$0.isLetter })
        else { return self }
        return first.lowercased() + dropFirst()
    }
}
