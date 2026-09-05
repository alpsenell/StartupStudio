import Foundation
import TycoonEngine

// MARK: Iteration 7 — the custom company and seed codes (R4)

/// What the new-game flow collected on the custom page, beside the four
/// values it always collected: the seed, the rules and the mode. The
/// defaults are a standard company, so the plain flow passes `.standard`.
struct RunSetup: Equatable {
    var seed: UInt64?
    var rules: GameRules = .standard
    var mode: RunMode = .standard

    static let standard = RunSetup()
}

extension GameSession {
    /// The options the new-game flow opens with: the custom page when a
    /// custom company or a code was asked for, the code that arrived, and
    /// the endings the ledger has for the locks.
    var newGameOptions: NewGameOptions {
        var options = NewGameOptions()
        options.showsCustomStep = customGameRequested || pendingSeedCode != nil
        options.seedCode = pendingSeedCode
        options.endingsReached = ledger.endingsReached
        return options
    }

    /// *Custom company* or *From a code* on the title screen: parks the
    /// request and opens the flow into the first empty slot. Returns
    /// `false` when every slot is taken — the request stays parked, and
    /// the title screen's own "which slot goes" dialog opens the flow
    /// through `beginNewGame(inSlot:)`, which reads it.
    @discardableResult
    func beginCustomGame(code: SeedCode? = nil) -> Bool {
        customGameRequested = true
        if let code { pendingSeedCode = code }
        guard let empty = slots.first(where: \.isEmpty) else { return false }
        beginNewGame(inSlot: empty.slot)
        return true
    }

    /// The plain *New company* path, and a cancelled flow: no custom page
    /// next time.
    func clearCustomGameRequest() {
        customGameRequested = false
        pendingSeedCode = nil
    }

    /// Cancels the flow and forgets the request with it.
    func cancelCustomGame() {
        clearCustomGameRequest()
        cancelOnboarding()
    }

    /// Starts the company the flow built, with whatever the custom page
    /// added, and forgets the request.
    func startNewGame(
        profile: FounderProfile,
        companyName: String,
        difficulty: Difficulty,
        origin: FoundingOrigin,
        setup: RunSetup
    ) {
        startNewGame(
            profile: profile, companyName: companyName, difficulty: difficulty, origin: origin,
            seed: setup.seed, rules: setup.rules, mode: setup.mode
        )
        clearCustomGameRequest()
    }

    // MARK: - URLs

    /// The scheme the share card's link uses: `startupstudio://seed/<code>`.
    static let seedURLScheme = "startupstudio"

    /// The link a card carries for its code.
    static func seedURL(for code: SeedCode) -> URL? {
        URL(string: "\(seedURLScheme)://seed/\(code.encoded)")
    }

    /// The code inside a `startupstudio://seed/<code>` URL, if it is one.
    static func seedCode(from url: URL) -> SeedCode? {
        guard url.scheme?.lowercased() == seedURLScheme,
              url.host()?.lowercased() == "seed"
        else { return nil }
        let text = url.path().trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return SeedCode.decode(text)
    }

    /// `onOpenURL`: parks the code for the title screen's *From a code*
    /// row, which opens the custom page prefilled. Under a running game
    /// nothing is interrupted; the code waits at the front door.
    @discardableResult
    func handleOpenURL(_ url: URL) -> Bool {
        guard let code = Self.seedCode(from: url) else { return false }
        pendingSeedCode = code
        return true
    }

    // MARK: - Headless

    /// `-autoCustom [code]`: opens the custom page on launch so it can be
    /// photographed; a code after the flag prefills it. DEBUG only.
    func openCustomFlowFromLaunchArguments() {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        guard let flag = arguments.firstIndex(of: "-autoCustom"), isAtFrontDoor, !needsOnboarding else { return }
        let code = arguments.indices.contains(flag + 1) ? SeedCode.decode(arguments[flag + 1]) : nil
        if !beginCustomGame(code: code) {
            beginNewGame(inSlot: 0)
        }
        #endif
    }
}
