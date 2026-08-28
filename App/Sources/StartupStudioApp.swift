import SwiftUI
import TycoonEngine

@main
struct StartupStudioApp: App {
    @Environment(\.scenePhase) private var scenePhase

    /// The single session for the app: loads the save (or starts a new
    /// game), owns the engine, and keeps autosave wired.
    @State private var session = GameSession()

    /// True while the app is hosting the unit-test bundle.
    ///
    /// The tests exercise types directly, so standing the whole game up
    /// behind them buys nothing and costs a lot: the pixel scenes animate
    /// on a timeline and the onboarding cover renders four of them, and a
    /// busy host is a host the simulator is willing to kill mid-run. Under
    /// tests the window stays empty.
    private static let isRunningTests = NSClassFromString("XCTestCase") != nil

    var body: some Scene {
        WindowGroup {
            if Self.isRunningTests {
                Color.clear
            } else {
                gameRoot
            }
        }
    }

    private var gameRoot: some View {
        AppRootView(session: session)
            .onChange(of: scenePhase) { _, newPhase in
                switch newPhase {
                case .active:
                    session.engine.resumeAfterForeground()
                case .background, .inactive:
                    session.engine.pauseForBackground()
                @unknown default:
                    break
                }
            }
    }
}
