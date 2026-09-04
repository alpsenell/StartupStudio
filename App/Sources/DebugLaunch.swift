import Foundation
import TycoonEngine

/// Debug-only launch hooks for headless QA, alongside `GameSession`'s
/// existing `-autoSpeed`.
///
/// The simulator can be launched, screenshotted and killed from the command
/// line but not *tapped* without accessibility permissions, so every
/// workstream's screenshot pass needs a way to land on the screen it is
/// about. `-autoTab team` (hq | life | team | products | business) opens
/// the app on that tab; `-autoOrigin cofounded` (garage | cofounded |
/// spinOut | mortgaged) founds the generated game that way, since the
/// Stakes page cannot be tapped either; `-autoRoute marketMap` (marketMap
/// | rivalProfile) pushes a screen a tab root owns, since nothing inside a
/// tab can be tapped either.
///
/// Release builds ignore the argument entirely.
enum DebugLaunch {
    /// The origin a headless pass founds its generated game with:
    /// `-autoOrigin <name>` in debug builds, `nil` (a garage) otherwise.
    static var launchOrigin: FoundingOrigin? {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        guard let flag = arguments.firstIndex(of: "-autoOrigin"),
              arguments.indices.contains(flag + 1)
        else { return nil }
        return FoundingOrigin.allCases.first {
            $0.rawValue.lowercased() == arguments[flag + 1].lowercased()
        }
        #else
        return nil
        #endif
    }

    /// The screen a headless pass wants pushed once the tab is up:
    /// `-autoRoute marketMap|rivalProfile` in debug builds (iteration 6,
    /// U3), `nil` otherwise and after it has been handed out once.
    ///
    /// The rival profile needs a rival, and a fresh game has none until
    /// the first tick founds the field, so the route is resolved against
    /// state and left pending until it can be — the strongest rival on
    /// the board, or the incumbent when there is one.
    @MainActor
    static func takeLaunchRoute(in state: GameState) -> Route? {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        guard !launchRouteConsumed,
              let flag = arguments.firstIndex(of: "-autoRoute"),
              arguments.indices.contains(flag + 1)
        else { return nil }
        switch arguments[flag + 1].lowercased() {
        case "marketmap":
            launchRouteConsumed = true
            return .marketMap
        case "rivalprofile":
            let strongest = state.rivals.rivals.max { lhs, rhs in
                if lhs.strength != rhs.strength { return lhs.strength < rhs.strength }
                return lhs.id.uuidString < rhs.id.uuidString
            }
            guard let rival = state.rivals.incumbent ?? strongest else { return nil }
            launchRouteConsumed = true
            return .rivalProfile(rivalID: rival.id)
        default:
            return nil
        }
        #else
        return nil
        #endif
    }

    #if DEBUG
    @MainActor private static var launchRouteConsumed = false
    #endif

    /// Whether this launch is a headless QA pass — `-autoSpeed` or
    /// `-autoTab` on the command line.
    ///
    /// Those two flags exist so a screenshot pass can land on a running
    /// game without tapping anything, and the front door and the
    /// onboarding flow (neither of which can be tapped either) would
    /// otherwise sit in front of every one of them on a fresh install. A
    /// headless launch therefore skips both, straight into slot 0: its
    /// save if there is one, a generated new game otherwise. Release
    /// builds never see it.
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
