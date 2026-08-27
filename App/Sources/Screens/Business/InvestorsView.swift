import SwiftUI
import TycoonEngine

/// The Investors segment of the Business tab: cap table, the pending
/// round, board pressure, and founder net worth.
///
/// Scaffold placeholder: an empty-state line, so the segment exists and is
/// reachable without claiming anything that isn't simulated yet. WS-F owns
/// this file and fills it in from `engine.state.investors`.
struct InvestorsView: View {
    let engine: GameEngine

    var body: some View {
        Text("No investors yet — keep building.")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, Theme.Spacing.sm)
    }
}
