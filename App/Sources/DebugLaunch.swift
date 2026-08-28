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
enum DebugLaunch {
    /// Whether this launch is a headless QA pass — `-autoSpeed` or
    /// `-autoTab` on the command line.
    ///
    /// Those two flags exist so a screenshot pass can land on a running
    /// game without tapping anything, and the onboarding flow (which
    /// cannot be tapped either) would otherwise sit in front of every one
    /// of them on a fresh install. A headless launch therefore skips
    /// straight into a generated new game. Release builds never see it.
    static var isHeadlessPass: Bool {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        return arguments.contains("-autoSpeed") || arguments.contains("-autoTab")
        #else
        return false
        #endif
    }
}

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
