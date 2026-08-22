import SwiftUI
import TycoonEngine

@main
struct StartupStudioApp: App {
    @Environment(\.scenePhase) private var scenePhase

    /// The single session for the app: loads the save (or starts a new
    /// game), owns the engine, and keeps autosave wired.
    @State private var session = GameSession()

    var body: some Scene {
        WindowGroup {
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
}
