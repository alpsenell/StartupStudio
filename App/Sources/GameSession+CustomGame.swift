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
    /// The one thing carried from the last company (R2), when the
    /// Heirlooms page was shown and something was picked.
    var heirloom: Heirloom?
    /// Iteration 8: the successor the founder page picked, if any.
    var lineage: Lineage?

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
        // Iteration 8: the dynasty's successors.
        options.successors = Successors.offers(from: ledger)
        options.seasonsFinished = seasonLedger.finishedNumbers
        // R2: the Heirlooms page, when the ledger offers something.
        return heirloomOptions(over: options)
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
            seed: setup.seed, rules: setup.rules, heirloom: setup.heirloom, mode: setup.mode,
            lineage: setup.lineage
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

    // MARK: Iteration 10 — M4 (leagues): the challenge link

    /// The host a *Beat my company* link uses on the same scheme:
    /// `startupstudio://beat/<code>?g=<letters>&s=<score>&n=<name>`.
    ///
    /// One scheme, two hosts: `seed` founds the company, `beat` founds it
    /// *and* carries the challenger's year and score so the result card
    /// can put the two grids side by side. A phone that has not got this
    /// version reads nothing at all from it, which is why the challenger's
    /// share text also spells the plain line out.
    static let challengeURLHost = "beat"

    /// The link a challenge card carries.
    static func challengeURL(for challenge: LeagueChallenge) -> URL? {
        var components = URLComponents()
        components.scheme = seedURLScheme
        components.host = challengeURLHost
        components.path = "/" + challenge.code.encoded
        components.queryItems = [
            URLQueryItem(name: "g", value: challenge.grid),
            URLQueryItem(name: "s", value: "\(challenge.score)"),
            URLQueryItem(name: "n", value: challenge.challenger),
        ]
        return components.url
    }

    /// The challenge inside a `startupstudio://beat/…` URL, if it is one.
    static func challenge(from url: URL) -> LeagueChallenge? {
        guard url.scheme?.lowercased() == seedURLScheme,
              url.host()?.lowercased() == challengeURLHost,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        else { return nil }
        let text = url.path().trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let code = SeedCode.decode(text) else { return nil }
        let items = components.queryItems ?? []
        func value(_ name: String) -> String { items.first { $0.name == name }?.value ?? "" }
        let grid = value("g").uppercased()
        guard grid.allSatisfy({ LeagueChallenge.gridAlphabet.contains($0) }) else { return nil }
        guard let score = Int(value("s")) else { return nil }
        return LeagueChallenge(code: code, grid: grid, score: score, challenger: value("n"))
    }

    // MARK: end of Iteration 10

    /// `onOpenURL`: parks the code for the title screen's *From a code*
    /// row, which opens the custom page prefilled. Under a running game
    /// nothing is interrupted; the code waits at the front door.
    @discardableResult
    func handleOpenURL(_ url: URL) -> Bool {
        // MARK: Iteration 10 — M4 (leagues)
        // A challenge link is a seed code with a year attached, so it is
        // tried first: the front door opens the challenge card on it.
        if let challenge = Self.challenge(from: url) {
            // Only the challenge is parked: setting `pendingSeedCode` as
            // well would open the *From a code* sheet over the challenge
            // card. Taking the challenge on sets it, through
            // `beginCustomGame(code:)`.
            pendingChallenge = challenge
            return true
        }
        // MARK: end of Iteration 10
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
