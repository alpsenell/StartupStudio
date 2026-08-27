import SwiftUI
import TycoonEngine

/// Persistent heads-up display: cash (left), in-game date (center),
/// speed control (right).
///
/// Attached by each tab's root screen via `withTopHUD(engine:)` — inside
/// the tab's `NavigationStack`, on the stack's root content view — so the
/// root content is laid out below it and pushed destinations (which show
/// the navigation bar instead) are unaffected.
struct TopHUD: View {
    let engine: GameEngine

    var body: some View {
        ZStack {
            Text(engine.state.dateLabel)
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .contentTransition(.numericText())
                .animation(.spring(duration: 0.3), value: engine.state.day)

            HStack {
                cashCounter
                Spacer()
                SpeedControl(engine: engine)
            }
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.vertical, Theme.Spacing.sm)
        .background(.bar)
        .overlay(alignment: .bottom) { Divider() }
    }

    private var cashCounter: some View {
        let cash = engine.state.company.cash
        return StatPill(
            systemImage: "dollarsign.circle.fill",
            value: cash.money,
            tint: cash < 0 ? Theme.negativeCash : .primary
        )
        .accessibilityLabel("Cash \(cash.money)")
    }
}

extension View {
    /// Attach the persistent HUD as a top safe-area inset.
    ///
    /// Apply this to a tab's ROOT CONTENT VIEW (the `List`/`ScrollView`/
    /// `VStack` that is the `NavigationStack`'s root), never to the
    /// `NavigationStack` itself: an inset applied outside the stack isn't
    /// honored by pinned, non-scrolling content inside it (a header
    /// `VStack` above a `ScrollView` lands underneath the opaque HUD).
    /// Applied on the root content, everything in that view — pinned
    /// pickers included — is laid out below the HUD, and pushed
    /// destinations get the navigation bar instead.
    func withTopHUD(engine: GameEngine) -> some View {
        safeAreaInset(edge: .top, spacing: 0) { TopHUD(engine: engine) }
    }
}
