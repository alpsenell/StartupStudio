import SwiftUI
import TycoonEngine

// MARK: K7 (partner and diary)

/// Iteration 15 — K7. The launch-day sheet's diary row: the launch landed
/// on a date in the family diary, and the founder can keep it — no launch
/// party (hype at launch ×0.85, no late night for the vices), and the date
/// counts as kept. The default is the launch; the diary asks on the day,
/// as it always does. Draws nothing when there is no clash.
struct DiaryKeepDateRow: View {
    let engine: GameEngine
    let product: Product

    @Environment(GameShell.self) private var injectedShell: GameShell?
    private var shell: GameShell { injectedShell ?? .shared }

    var body: some View {
        let state = engine.state
        if let clash = state.launchDiaryClash(productID: product.id, balance: engine.balance, content: engine.content) {
            let blocker = state.keepTheDateBlocker(productID: product.id, balance: engine.balance, content: engine.content)
            PixelPanel(contentPadding: Theme.Spacing.md) {
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    PixelSectionTitle(title: "In the diary")
                    Text("\(clash.label) is \(when(clash.day, launch: launchDay ?? state.day)). The launch party is tonight.")
                        .font(.callout)
                        .foregroundStyle(Theme.pixelInk)
                        .fixedSize(horizontal: false, vertical: true)
                    Button { keep(clash) } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Keep the date")
                                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                                .foregroundStyle(blocker == nil ? Theme.romance : .secondary)
                            Text("No launch party: launch hype ×\(factor(engine.balance.partner.keepDateHypeFactor)), no late night. The date counts as kept.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                            if let blocker {
                                Text(blocker)
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(Theme.warning)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(Theme.Spacing.md)
                        .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.pressableRow)
                    .disabled(blocker != nil)
                    Text("Or go to the party. The diary asks on the day, and sending your apologies is what happens if you say nothing.")
                        .font(.caption)
                        .foregroundStyle(Theme.pixelInk.opacity(0.7))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var launchDay: Int? {
        if case .released(let info) = engine.state.product(id: product.id)?.stage { return info.launchDay }
        return nil
    }

    private func when(_ day: Int, launch: Int) -> String {
        switch day - launch {
        case 0: "today"
        case 1: "tomorrow"
        case -1: "yesterday"
        case let offset where offset > 0: "in \(offset) days"
        case let offset: "\(-offset) days ago"
        }
    }

    private func factor(_ value: Double) -> String {
        value == value.rounded() ? "\(Int(value))" : String(format: "%g", value)
    }

    private func keep(_ clash: FamilyDate) {
        Haptics.commit()
        shell.toasts.send(
            .keepTheDate(productID: product.id), to: engine,
            ack: "\(clash.label). You were there.",
            rejected: "The date has passed.",
            icon: "calendar.badge.checkmark"
        )
    }
}

// MARK: end K7
