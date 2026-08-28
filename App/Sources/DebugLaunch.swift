import Foundation

/// Debug-only launch hooks for headless QA, alongside `GameSession`'s
/// existing `-autoSpeed`.
///
/// The simulator can be launched, screenshotted and killed from the command
/// line but not *tapped* without accessibility permissions, so every
/// workstream's screenshot pass needs a way to land on the screen it is
/// about. `-autoTab team` (hq | life | team | products | business) opens
/// the app on that tab.
///
/// Release builds ignore the argument entirely.
extension GameTab {
    /// The tab the app opens on: `-autoTab <name>` in debug builds, HQ
    /// otherwise.
    static var launchTab: GameTab {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        guard let flag = arguments.firstIndex(of: "-autoTab"),
              arguments.indices.contains(flag + 1)
        else { return .hq }
        return switch arguments[flag + 1].lowercased() {
        case "life": .life
        case "team": .team
        case "products": .products
        case "business": .business
        default: .hq
        }
        #else
        return .hq
        #endif
    }
}
