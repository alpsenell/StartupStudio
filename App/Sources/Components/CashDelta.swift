import SwiftUI
import TycoonEngine

/// One floating "+$1,240" / "−$900" label that rises and fades out of the
/// HUD when money moves.
struct CashDeltaLabel: View {
    /// Signed dollars. Positive floats green, negative floats red.
    let amount: Int
    /// What moved the money ("Sales", "Payroll"), from the ledger tail.
    let reason: String?

    @State private var offset: CGFloat = 6
    @State private var opacity: Double = 0

    private var tint: Color { amount >= 0 ? Theme.positiveCash : Theme.negativeCash }
    private var text: String { amount >= 0 ? "+" + amount.money : amount.money }

    var body: some View {
        HStack(spacing: 4) {
            PixelText(text: text, scale: 2, color: tint, shadow: true)
            if let reason {
                Text(reason)
                    .font(.system(.caption2, design: .rounded).weight(.semibold))
                    .foregroundStyle(tint.opacity(0.8))
            }
        }
        .offset(y: offset)
        .opacity(opacity)
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(.easeOut(duration: 0.22)) {
                opacity = 1
                offset = -2
            }
            withAnimation(.easeIn(duration: 0.5).delay(0.7)) {
                opacity = 0
                offset = -18
            }
        }
        .accessibilityHidden(true)
    }
}

/// Watches the company's cash and floats a `CashDeltaLabel` under the HUD
/// every time it moves, labelled from the newest ledger entry.
///
/// Deltas smaller than `threshold` are swallowed so the daily trickle of
/// $3 operating costs doesn't produce a permanent drip of labels.
struct CashDeltaOverlay: View {
    let engine: GameEngine
    /// Smallest absolute change worth showing.
    var threshold: Int = 25

    /// A pending float: the amount plus a token so two identical deltas in
    /// a row still animate separately.
    private struct Floater: Identifiable, Equatable {
        let id: Int
        let amount: Int
        let reason: String?
    }

    @State private var lastCash: Int?
    @State private var floaters: [Floater] = []
    @State private var nextToken = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(floaters) { floater in
                CashDeltaLabel(amount: floater.amount, reason: floater.reason)
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
        let floater = Floater(id: nextToken, amount: delta, reason: reason)
        nextToken += 1
        floaters.append(floater)
        // Keep at most three on screen; each removes itself after its own
        // rise-and-fade finishes.
        if floaters.count > 3 { floaters.removeFirst() }
        let id = floater.id
        Task {
            try? await Task.sleep(for: .milliseconds(1400))
            floaters.removeAll { $0.id == id }
        }
    }
}

extension LedgerEntry.Category {
    /// Player-facing name for a ledger bucket. Every case is spelled out
    /// (rather than defaulted) so a category appended by another
    /// workstream shows up as a compiler warning here, not as "Other".
    var displayName: String {
        switch self {
        case .operating: "Operating"
        case .rent: "Rent"
        case .payroll: "Payroll"
        case .sales: "Sales"
        case .contracts: "Contracts"
        case .marketing: "Marketing"
        case .research: "Research"
        case .hosting: "Servers"
        case .other: "Other"
        @unknown default: "Other"
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
