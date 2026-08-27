import Observation
import SwiftUI

/// The five tabs of the game.
enum GameTab: Hashable {
    case hq
    case life
    case team
    case products
    case business
}

/// A destination inside a tab, for cross-tab deep links ("go hire someone",
/// "open the market report for fitness"). WS-E adds cases as it replaces the
/// dead-end "go to the Team tab" texts with real buttons.
enum Route: Hashable {
    case hiring
    case research
    case product(UUID)
    case contracts
    case marketReport(topicID: String)
}

/// Cross-tab navigation, injected into the environment at the app root.
///
/// Scaffold shape: the state exists and is observable, but nothing reads it
/// yet — `AppRootView` still owns its own tab selection, so navigation
/// behaves exactly as before. WS-E takes ownership: it binds the `TabView`
/// selection to `tab`, adds `go(_:)`, and has each screen consume and clear
/// `pendingPush`.
@Observable
final class AppRouter {
    /// The tab currently on screen.
    var tab: GameTab = .hq
    /// A destination the frontmost tab should push as soon as it appears.
    var pendingPush: Route?

    init() {}
}
