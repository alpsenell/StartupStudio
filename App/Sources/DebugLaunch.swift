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
/// Stakes page cannot be tapped either; `-autoRoute warRoom` opens a
/// surface the tab's root would otherwise only open on a tap (the tab
/// root that owns the surface reads `launchRoute` and presents it).
///
/// Release builds ignore the argument entirely.
enum DebugLaunch {
    /// The surface a headless pass asked to land on: the lower-cased word
    /// after `-autoRoute` in debug builds, `nil` otherwise. Each tab root
    /// recognises its own names (`warroom`, `launchday` on Products).
    static var launchRoute: String? {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        guard let flag = arguments.firstIndex(of: "-autoRoute"),
              arguments.indices.contains(flag + 1)
        else { return nil }
        return arguments[flag + 1].lowercased()
        #else
        return nil
        #endif
    }

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

    /// The screen a headless pass opens on top of HQ: `-autoRoute
    /// newspaper|timeline` in debug builds, `nil` otherwise. U2's two
    /// screens are pushed from cards nobody can tap from the command line.
    /// (`launchRoute` above is the raw flag every tab root reads; this is
    /// HQ's typed reading of it.)
    static var launchStoryRoute: Route? {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        guard let flag = arguments.firstIndex(of: "-autoRoute"),
              arguments.indices.contains(flag + 1)
        else { return nil }
        return switch arguments[flag + 1].lowercased() {
        case "newspaper": .newspaper
        case "timeline": .timeline
        default: nil
        }
        #else
        return nil
        #endif
    }

    /// `-autoAnswer`: a headless pass answers every question the game asks
    /// with its first open option, closes the launch-day sheet, and keeps
    /// the clock at the `-autoSpeed` pace — so a screen can be photographed
    /// weeks into a run that would otherwise stop, modal up, at the first
    /// story beat. Started once, from HQ's root task; the loop outlives
    /// the view. Release builds never run it.
    @MainActor
    static func startAutoAnswering(engine: GameEngine) {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        guard arguments.contains("-autoAnswer"), autoAnswerTask == nil else { return }
        let pace: SimSpeed = if let flag = arguments.firstIndex(of: "-autoSpeed"),
                                arguments.indices.contains(flag + 1),
                                let speed = SimSpeed(rawValue: arguments[flag + 1]), speed != .paused {
            speed
        } else {
            .x4
        }
        autoAnswerTask = Task { @MainActor in
            while !Task.isCancelled, engine.state.gameOver == nil {
                try? await Task.sleep(for: .milliseconds(200))
                // The first open option, except the one that ends the run:
                // a pass that sells the company on day 68 photographs
                // nothing.
                if let prompt = DecisionPrompt.pending(in: engine.state, content: engine.content, balance: engine.balance),
                   let option = prompt.options.first(where: { option in
                       guard option.disabledReason == nil else { return false }
                       switch option.action {
                       case .acceptBuyout, .acceptBuyoutEarnOut: return false
                       default: return true
                       }
                   }) {
                    _ = engine.send(option.action)
                }
                GameShell.shared.launchDayProductID = nil
                if engine.state.speed == .paused {
                    engine.setSpeed(pace)
                }
            }
        }
        #endif
    }

    #if DEBUG
    @MainActor private static var autoAnswerTask: Task<Void, Never>?
    #endif

    /// Whether this launch is a headless QA pass — `-autoSpeed`,
    /// `-autoTab` or `-autoRoute` on the command line.
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
            || arguments.contains("-autoRoute")
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
