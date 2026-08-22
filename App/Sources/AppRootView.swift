import SwiftUI
import TycoonEngine

/// Root of the app: tab bar plus the persistent top HUD.
/// The HUD is attached here (not inside a screen) so it stays visible
/// across every future tab.
struct AppRootView: View {
    let session: GameSession

    /// Tabs of the game.
    private enum GameTab: Hashable {
        case hq
        case life
        case team
        case products
        case business
    }

    @State private var selectedTab: GameTab = .hq

    var body: some View {
        let engine = session.engine
        TabView(selection: $selectedTab) {
            HQScreen(engine: engine)
                .withTopHUD(engine: engine)
                .tabItem { Label("HQ", systemImage: "building.2") }
                .tag(GameTab.hq)

            LifeScreen(engine: engine)
                .withTopHUD(engine: engine)
                .tabItem { Label("Life", systemImage: "heart.fill") }
                .tag(GameTab.life)

            TeamScreen(engine: engine)
                .withTopHUD(engine: engine)
                .tabItem { Label("Team", systemImage: "person.2.fill") }
                .tag(GameTab.team)

            // Products and R&D share one tab (segmented inside) to keep the
            // bar at five tabs.
            ProductsScreen(engine: engine)
                .withTopHUD(engine: engine)
                .tabItem { Label("Products", systemImage: "shippingbox.fill") }
                .tag(GameTab.products)

            BusinessScreen(engine: engine)
                .withTopHUD(engine: engine)
                .tabItem { Label("Business", systemImage: "briefcase.fill") }
                .tag(GameTab.business)
        }
        .tint(Theme.accent)
        .fullScreenCover(isPresented: gameOverPresented) {
            if let info = engine.state.gameOver {
                GameOverView(info: info, dateLabel: engine.state.dateLabel) {
                    session.startNewGame()
                }
            }
        }
        .alert("Couldn't load your save", isPresented: loadFailurePresented) {
            Button("OK") { session.clearLoadFailure() }
        } message: {
            Text(session.loadFailureMessage ?? "")
        }
    }

    /// Presented whenever the engine reports game over. The setter is a
    /// no-op: dismissal happens when "New game" swaps in a fresh engine
    /// whose state has no `gameOver`.
    private var gameOverPresented: Binding<Bool> {
        Binding(
            get: { session.engine.state.gameOver != nil },
            set: { _ in }
        )
    }

    /// One-time dismissible notice when the save failed to load.
    private var loadFailurePresented: Binding<Bool> {
        Binding(
            get: { session.loadFailureMessage != nil },
            set: { presented in
                if !presented { session.clearLoadFailure() }
            }
        )
    }
}

private extension View {
    /// Attach the persistent HUD to a tab's root screen. Applied per-screen
    /// (not on the TabView) because a safe-area inset applied outside the
    /// UIKit-backed TabView doesn't reliably propagate into tab content.
    func withTopHUD(engine: GameEngine) -> some View {
        safeAreaInset(edge: .top, spacing: 0) { TopHUD(engine: engine) }
    }
}

// MARK: - Top HUD

/// Persistent heads-up display: cash (left), in-game date (center),
/// speed control (right).
private struct TopHUD: View {
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
