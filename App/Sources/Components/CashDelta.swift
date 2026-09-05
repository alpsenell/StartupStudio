import SwiftUI
import TycoonEngine

/// One "+$1,240" / "−$900" label that rises and fades when money moves.
struct CashDeltaLabel: View {
    /// Signed dollars. Positive floats green, negative floats red.
    let amount: Int
    /// What moved the money ("Sales", "Payroll"), from the ledger tail.
    let reason: String?
    /// Pixel scale of the figure. The HUD's slot uses 1 so the label sits
    /// under the cash pill instead of across it.
    var scale: CGFloat = 2
    /// How far the label rises before it fades, in points.
    var rise: CGFloat = 18

    @State private var offset: CGFloat = 4
    @State private var opacity: Double = 0

    private var tint: Color { amount >= 0 ? Theme.positiveCash : Theme.negativeCash }
    private var text: String { amount >= 0 ? "+" + amount.money : amount.money }

    var body: some View {
        HStack(spacing: 4) {
            PixelText(text: text, scale: scale, color: tint, shadow: scale >= 2)
            if let reason {
                Text(reason)
                    .font(.system(.caption2, design: .rounded).weight(.semibold))
                    .foregroundStyle(tint.opacity(0.8))
                    .lineLimit(1)
            }
        }
        .offset(y: offset)
        .opacity(opacity)
        .allowsHitTesting(false)
        .onAppear {
            // Under reduced motion the label still appears and still fades
            // — a cash change the player can't see is worse than one that
            // doesn't rise — it just holds still while it does it.
            let holdStill = Theme.Motion.isReduced
            withAnimation(.easeOut(duration: Theme.Motion.quick + 0.04)) {
                opacity = 1
                offset = holdStill ? 0 : -1
            }
            withAnimation(.easeIn(duration: 0.5).delay(0.7)) {
                opacity = 0
                offset = holdStill ? 0 : -rise
            }
        }
        .accessibilityHidden(true)
    }
}

/// The reserved slot under the HUD's cash pill where the delta shows.
///
/// It used to float over the pill, covering the figure it was explaining
/// for the half second it mattered. The slot has its own height, so the
/// label never lands on the cash; it also reports each delta to the HUD,
/// which flashes the pill's fill in the sign colour.
///
/// Deltas smaller than `threshold` are swallowed so the daily trickle of
/// $3 operating costs doesn't produce a permanent drip of labels.
struct CashDeltaSlot: View {
    let engine: GameEngine
    /// Smallest absolute change worth showing.
    var threshold: Int = 25
    /// Called with every delta the slot shows.
    var onDelta: ((Int) -> Void)?

    /// The pending float: the amount plus a token so two identical deltas
    /// in a row still animate separately.
    private struct Floater: Identifiable, Equatable {
        let id: Int
        let amount: Int
        let reason: String?
    }

    /// The slot's height: one scale-1 pixel line with room to rise.
    static let height: CGFloat = 14

    @State private var lastCash: Int?
    @State private var floater: Floater?
    @State private var nextToken = 0

    var body: some View {
        // The slot claims height, not width: a greedy clear fill here
        // would push the date into its compact form on every phone. The
        // label is sized to its text and may overhang to the right, under
        // the bar's empty middle, which is fine for the second it lives.
        Color.clear
            .frame(width: 1, height: Self.height)
            // An overlay, not a sibling: the label takes no part in the
            // bar's layout, so a long reason cannot widen the cash column.
            .overlay(alignment: .leading) {
                if let floater {
                    CashDeltaLabel(amount: floater.amount, reason: floater.reason, scale: 1, rise: 5)
                        .fixedSize()
                        .id(floater.id)
                }
            }
        .onChange(of: engine.state.company.cash, initial: true) { _, cash in
            defer { lastCash = cash }
            guard let previous = lastCash else { return }
            let delta = cash - previous
            guard abs(delta) >= threshold else { return }
            push(delta)
        }
    }

    private func push(_ delta: Int) {
        let reason = engine.state.ledger.entries.last.map { entry -> String in
            entry.label.count <= 18 ? entry.label : entry.category.displayName
        }
        let next = Floater(id: nextToken, amount: delta, reason: reason)
        nextToken += 1
        floater = next
        onDelta?(delta)
        let id = next.id
        Task {
            try? await Task.sleep(for: .milliseconds(1400))
            if floater?.id == id { floater = nil }
        }
    }
}

extension LedgerEntry.Category {
    /// Player-facing name for a ledger bucket. Every case is spelled out
    /// (rather than defaulted) so a category appended by another
    /// workstream shows up as a compiler warning here, not as "Other".
    var displayName: String {
        switch self {
        case .operating: String(localized: "Operating", comment: "Ledger bucket: day-to-day running costs")
        case .rent: String(localized: "Rent", comment: "Used as a ledger bucket (the office rent) and as the money-sheet row for the founder home rent")
        case .payroll: String(localized: "Payroll", comment: "Ledger bucket: wages")
        case .sales: String(localized: "Sales", comment: "Used as a ledger bucket (money from shipped products) and as the founder selling skill on a chip")
        case .contracts: String(localized: "Contracts", comment: "Client jobs. Used as a ledger bucket and as the button on the coach tip that opens the contracts screen")
        case .marketing: String(localized: "Marketing", comment: "Used as a ledger bucket (campaign spend) and as the marketing skill on a bar")
        case .research: String(localized: "Research", comment: "The tech tree. Used in the assignment menu, as the current-assignment readout, and as a ledger bucket")
        case .hosting: String(localized: "Servers", comment: "Ledger bucket: hosting costs")
        case .other: String(localized: "Other", comment: "Ledger bucket: everything that fits no other category, including one this build does not know")
        @unknown default: String(localized: "Other", comment: "Ledger bucket: everything that fits no other category, including one this build does not know")
        }
    }

    /// SF Symbol for the bucket, used by the finances view and the weekly
    /// report's breakdown rows.
    var systemImage: String {
        switch self {
        case .operating: "wrench.and.screwdriver.fill"
        case .rent: "building.2.fill"
        case .payroll: "person.2.fill"
        case .sales: "cart.fill"
        case .contracts: "briefcase.fill"
        case .marketing: "megaphone.fill"
        case .research: "flask.fill"
        case .hosting: "server.rack"
        case .other: "ellipsis.circle.fill"
        @unknown default: "ellipsis.circle.fill"
        }
    }
}
