# Iteration 7 — the release

*5 September 2026. Everything around a run: a first hour, saves that follow the player, a reason to come back tomorrow, a way to show a life off, one thing to carry into the next company, the unlock that pays for it, and the plumbing the store asks for. Nine lanes, one engineer-day each, off a `scaffold-7` tag on `iteration-7`.*

## Why

Six iterations built a run that is deep enough. What does not exist is anything *around* it: a new player is dropped on a Now card with five tabs and 61 actions; a save lives on one phone; the only reason to open the app tomorrow is the company you left running; a finished life can be read once and never shown to anyone; the address book is deleted with the slot; and there is no App Store, no price, no privacy manifest, no iPad. The brief is right that this is the thin place now. Every lane below is a surface between the run and the world, and none of them touch the balance.

## Where the brief is wrong, before the work

**The first hour is not a fortnight.** `BalanceTargetsTests` pins a solo founder's first ship to day 45–110, and a day is one second at ×1 (`SimSpeed.ticksPerSecond`). "Hire, start a build, ship it, read a report" cannot fit in fourteen days; the tour has to be paced by *beats* (start, hire, week one's report, then a dormant stretch until `shipETA.isReady`), not by the calendar. R1 is specified that way.

**Nothing here wants a Balance.json key.** Every knob the brief lists — rivals off, incumbent off, starting cash — already exists as a balance value (`rivals.rivalCount`, `rivals.depth.incumbentEnabled`, `startingCash`), and `Difficulty` already shows how to apply per-run overrides without touching the engine's numbers (`BalanceConfig.adjusted(for:)`, applied once in `GameEngine.newGame`/`resume`). Custom games and endless are per-run rules on `GameState`, not balance. The scaffold adds no balance keys, and the pinned suites stay byte-identical by construction.

## Three hard things, stated plainly

1. **The gate against a replayable engine.** The engine must stay free of StoreKit (deterministic, testable, 888 tests). The gate therefore lives where the clock lives: `GameEngine.performTick` and `setSpeed` consult an app-installed `advanceGate` closure; unentitled past chapter 1, the clock will not run, but every action, screen and save still works. The same seam stops the daily at its horizon. Nothing is ever deleted or hidden — a revoked purchase re-locks the clock, not the file.
2. **iCloud conflicts.** Key-value store sync is last-writer-wins by wall clock; the owner's policy is newest in-game day. So the policy is layered on top, as a pure function over two envelopes (`SaveSummary.day`, `seed`, `savedAt`), and incoming saves are only ever applied at the front door — never under a running game. A save that loses becomes the slot's `.backup.json`, so "local as backup" is literally the existing rotation.
3. **Canvas accessibility.** `OfficeSceneView` already does it right (an invisible overlay of one element per `OfficeHitRegion`, from the director's own placement). The home, city map and rival studio are one label each; the market map, networking floor and org chart are already `Button`s. So the work is to give the home and the city map a region model and copy the office's overlay — not to invent accessibility for `Canvas`.

## The items, and the nine lanes that build them

| # | Item (owner's priority) | Lane | Entry point | Lives in |
|---|---|---|---|---|
| 1 | Scripted first hour | R1 | Automatic, first company on a fresh install | A rail line + a card above the tab bar; tabs appear as they are introduced |
| 2 | iCloud sync of the three slots | R2 | Automatic; status row in Settings | `App/Sources/Cloud/`, `TycoonSave` merge policy |
| 6 | Legacy ledger, heirlooms, unlocks | R2 (ledger, heirloom page) + R4 (look/origin locks) | *Heirlooms* page in the new-game flow | `App/Sources/Legacy/`, `TycoonEngine/Legacy.swift` |
| 3 | Game Center achievements + leaderboards | R3 | Automatic; *Game Center* row in Settings | `App/Sources/GameCenter/` |
| 4 | Daily seed | R3 | *Today's company* on the title screen | `App/Sources/Daily/`, `TycoonEngine/Daily.swift` |
| 5 | Share biography / newspaper / office photo; start from a seed | R4 | Share buttons on those three screens; *From a code* on the title screen | `App/Sources/Share/` |
| 7a | Custom company | R4 | *Custom company* on the title screen | `Screens/Onboarding/CustomStep.swift`, `TycoonEngine/GameRules.swift` |
| 7b | Endless after IPO / Still yours | R5 | *Keep running it* on the biography | `Reducer`, `GameEngine`, `FounderBiographyView` |
| — | Iteration 6 wave-2 fixes | R5 | — | the five named sites |
| 8 | StoreKit 2 unlock, restore, review prompt | R6 | Paywall when chapter 2 opens; *Restore* on it and in Settings | `App/Sources/Store/`, `App/StoreKit/StartupStudio.storekit` |
| 9 | Accessibility of the scenes, Dynamic Type on pixel screens | R7 | — | PixelKit scene views, the pixel screens |
| — | Privacy manifest, App Privacy answers, iPad, TestFlight checklist, screenshots | R8 | — | `App/Resources/`, `project.yml`, `Makefile`, `docs/release/` |
| 10 | String Catalog groundwork | R9 | — | `App/Resources/Localizable.xcstrings`, the non-`Text` string sites |

Grouping, and why: **Game Center and the daily** are one lane because the daily's only output is a leaderboard post and both need the same authenticated client. **iCloud and the ledger** share the save layer and the ledger is the second thing the sync moves. **Share, seed codes and the custom company** are one lane because they are one flow — a code is decoded into the custom page, and the custom page is where a code lands. **Endless** goes with the polish lane because both are engine-adjacent fixes small enough to share a day, and the polish must land first anyway. **The unlock is its own lane**, split from the release plumbing: StoreKit with a testable gate and a pixel paywall is a full day; the plumbing (manifest, iPad, screenshots, checklist) is another. **Strings** are alone and merge last because they touch every file lightly.

---

## R1 — The first hour

**What's thin.** A new player lands on `HQScreen`'s Now card with all five tabs open, six coach tips (`CoachTip.all`, `TipStrip.swift:25–68`) that fire by goal, a weekly report that opens itself for eight weeks (`GameShell.autoOpenWeeks`), and a notice rail. Nothing says what to do first. The Now card comes closest and it is a summary, not a hand.

**The tour.** A `TutorialScript` of nine beats, each with a rail line, a card, the tab it opens, an optional route, and a *done* predicate on `GameState` (or on a shell event). Beats, not days:

| Beat | Opens | Line | Done when |
|---|---|---|---|
| 1 Welcome | HQ | "This is your garage. The desk is you; the whiteboard is what you are building." | 4 s or a tap on the office |
| 2 Name a product | Products | "Start something. Pick a topic the shelf is thin in." | `products.count ≥ 1` (the `g1_name_a_product` condition) |
| 3 Hire | Team | "You cannot ship alone by winter. Hire one person — interview them first if you want to see the second trait." | `employees.count ≥ 2` |
| 4 Run the clock | — | "Press play. A day is a second." | `day ≥ 7` |
| 5 Read the week | — | the report opens itself, tour or no tour | the week-1 report dismissed |
| 6 Your evenings | Life | "You have three evenings on normal. Spend one." | any evening spent, or `day ≥ 14` |
| 7 The desk | Business | "A client is worth cash before you have sales." | `activeContracts.count ≥ 1`, or `day ≥ 28` |
| 8 Ship it | — | dormant until `shipETA(for:).isReady`; then "It is ready. Ship it from the war room." | `.shipped` |
| 9 Launch day | — | "Read every review. The score has reasons." | `.reviewsIn` → tour complete |

Tabs not yet opened are not rendered (`AppRootView.tabs(engine:)` filters on `session.tutorial?.openTabs`); all five by beat 7. The card sits above the tab bar, drawn as a `PixelPanel` with the line and one button that routes (`router.go`). *Skip the tour* on every card ends it and opens everything.

**Coexistence.** `RailNotice.Kind` gains `.tour(TutorialStep)` at priority 1 — after `pause` (a story question stops the clock and must lead), before `deferred`. Coach tips are suppressed while the tour runs; on completion or skip, the six ids in `CoachTip.all` are written to `GameSettings.dismissedTips`, since beats 2/3/7/8/9 say the same things. Beat 5 opens the weekly report regardless of the `manualOpens < 2` rule; the counters in `GameShell.dayAdvanced` are untouched otherwise.

**Never for a returning player.** The tour starts only if `GameSettings.tutorialCompleted == false` **and** every other slot is empty **and** `session.ledger.runs.isEmpty` (the R2 type; the scaffold gives it an empty default). Anyone updating with a save never sees it; a fresh install sees it once; skipping counts as completing. Daily and custom runs never start it. Progress persists per slot in `UserDefaults` (`tutorial.slot<N>.step`) so backgrounding mid-tour resumes.

**Build.** `App/Sources/Tutorial/TutorialScript.swift` (steps, predicates), `TutorialProgress.swift` (state, persistence), `TutorialCard.swift`; hooks in `GameShell.dayAdvanced`/`eventsChanged` (already the two places state change is observed) and `GameEngine.eventSink` (scaffold). `GameSession.tutorial: TutorialProgress?` (scaffold stored property; R1 owns `GameSession+Tutorial.swift`).

**Tests.** `TutorialScriptTests`: every predicate against fixture states; "does not start when another slot holds a save"; "skip writes the six tip ids"; rail ordering with a pause and a tour line present; `TutorialCard` snapshot light/dark. `-autoTour` debug flag to reach each beat headlessly.

**Accepts when** a fresh simulator install reaches launch day with the tabs appearing in order and no coach tip shown; a second company on the same install shows nothing; the existing `NoticeRailSnapshotTests` and `WeeklyReportTests` are unchanged.

**Fails if** the card nags across the dormant stretch between beats 7 and 8 (three to twelve weeks). Cheapest early check: beat 8 must be *silent* until `isReady`; the rail shows nothing from the tour during that stretch.

**Outside the repo.** Nothing.

---

## R2 — Cloud saves and the ledger

### iCloud

**Recommendation: `NSUbiquitousKeyValueStore`, not CloudKit and not a ubiquity container.** The numbers: a day-210 save is 35 KB on disk (`eventLog` 13 KB and capped at `maxEventLogEntries = 500`, `market` 9 KB, `ledger` 5 KB); a four-year save should land under 100 KB. Three slots plus the ledger is under 400 KB raw, and `NSData.compressed(using: .lzfse)` takes sorted-key JSON down about 5×. KVS allows 1 MB total, 1 MB per key, 1024 keys. It needs one entitlement, no container to create, no schema to deploy, works in the simulator when signed in, and returns nothing when iCloud is off, which is the degrade the brief asks for. CloudKit would be the right answer at ten slots or with any shared data; here it is a day of `CKRecord`/`CKAsset`/change-tag handling to move four small blobs. A ubiquity container matches `SaveStore`'s files but brings `NSFileCoordinator`, `NSMetadataQuery` and `NSFileVersion` conflicts, and is the least reliable of the three in the simulator.

**Layout.** Keys `slot0`, `slot1`, `slot2`, `legacy`; each value is the compressed bytes of the envelope file exactly as `SaveStore` writes it (`formatVersion`, `savedAt`, `appVersion`, `summary`, `state`), so a cloud blob is a save file and migrations run on the way in, unchanged. Two scaffolded methods carry bytes: `SaveStore.rawSave(slot:) -> Data?` and `SaveStore.importRaw(_:slot:)` (staged and rotated like `save`).

**Policy, as a pure function in `TycoonSave`:** `CloudMergePolicy.resolve(local: SaveEnvelope?, remote: SaveEnvelope?) -> Verdict` (`.keepLocal`, `.takeRemote`, `.pushLocal`). Same `seed` in both summaries → the higher `summary.day` wins, ties keep local. **Different seeds** — the player founded a different company in that slot on one device — the newer `savedAt` wins, because in-game day says nothing about which company they meant. The loser becomes `slot<N>.backup.json` through the normal rotation. (`SaveSummary` gains `seed: UInt64?` in the scaffold so the policy never decodes a state.)

**When.** Pull and resolve on launch and on `NSUbiquitousKeyValueStore.didChangeExternallyNotification`, but *apply* only while `session.isAtFrontDoor`; under a running game the verdict is held in `session.cloud.pending` and applied on `returnToFrontDoor()`. Push after a local save, coalesced to at most one write per 30 s per key and always on `pauseForBackground()` — KVS rate-limits writers. `deleteSlot` pushes a tombstone (`nil`) so a deletion propagates. A slot whose compressed blob exceeds 900 KB stays local-only and says so; the others still sync.

**Degrade.** `FileManager.default.ubiquityIdentityToken == nil` → `CloudSyncStatus.off`; Settings' new *iCloud* row reads "Off — saves stay on this device"; the title screen shows a one-line notice when a slot was updated from iCloud ("Slot 2 · updated from iCloud, day 340").

### The ledger

`LegacyLedger` in `TycoonEngine/Legacy.swift` (it names engine types, so it cannot live in `TycoonSave`): `runs: [LegacyRun]` (company, founder, `seed`, `origin`, `difficulty`, `ending: EndingKind`, `day`, net worth, the address book's top eight contacts by rapport with skills and revealed traits, the perks earned, the deed if `city` says the office was owned — tier and district), `endingsReached: Set<EndingKind>`, `spentHeirlooms`. Persisted as `SaveStore<LegacyLedger>(directory: …/Legacy, currentFormatVersion: 1, slotCount: 1)` — a second store in a second directory, so `deleteAll()` on the saves store cannot reach it; that is the whole "survives deleteAll" argument, and one app test proves it. Written by `GameSession` the moment `gameOver` becomes non-nil (`LegacyLedger.record(_ state:)` is pure and engine-tested). **First-launch migration:** seed `endingsReached` from every slot whose `SaveSummary.ending` is set, so nobody who already finished a company is told they have not.

**Heirlooms.** A new *Heirlooms* page in `NewGameFlow` after Stakes (case pre-added in `OnboardingStep`), shown only when the ledger offers something. Pick **one** of: a person (arrives as a `Contact` with their skills, revealed traits, rapport 60 and `leftReason: .formerCompany` (a new `DepartureReason` case) — you still recruit them at their ask), a perk (`progression.perks` from day 0), or the deed (the office owned outright at the tier you owned, capped at studio, in its district — no rent, from day 0). Applied in `GameState.newGame(…, heirloom:)` after `applyOrigin`, as pure deltas, drawing nothing. **The cost:** an heirloom is spent — Marco carries once, the deed carries once — and an heirloom run is `RunMode.isRanked == false`, so it never posts to the fastest-IPO or richest boards. That is the decision: spend the deed on this easy run, or save it for the hard one.

**Build.** `App/Sources/Cloud/CloudSync.swift`, `CloudSyncStatus.swift`; `TycoonSave/CloudMergePolicy.swift`; `TycoonEngine/Legacy.swift`; `App/Sources/Legacy/LegacyStore.swift`; `Screens/Onboarding/HeirloomsStep.swift`; `GameSession+Cloud.swift`, `GameSession+Legacy.swift`; the iCloud row in `SettingsSheet`.

**Tests.** `CloudMergePolicyTests` (TycoonSave): same seed higher day wins; different seed newer `savedAt` wins; nil remote pushes; nil local takes; tombstone. `SaveStore` raw round-trip. `LegacyTests` (engine): `record` captures the eight contacts and the deed; each heirloom applies as the named delta and nothing else; garage-no-heirloom `newGame` byte-identical to today (extend the origins guard). App: "deleteAll leaves the ledger"; "a pending cloud verdict is not applied under a running game"; Heirlooms page snapshot.

**Accepts when** two simulators signed into one iCloud account converge on the higher day inside a minute; turning iCloud off leaves the game identical; the pacing and investor suites are byte-identical; `slot0.json`'s envelope keys are unchanged except the added `summary.seed`.

**Fails if** the policy ping-pongs — device A pushes day 300, B pulls, B's stale autosave pushes day 250 back. The rule that prevents it: a device never pushes a slot whose verdict was `.takeRemote` until it has been played past the remote day. Cheapest early check: log every push with `(slot, day, verdict)` and watch two simulators for five minutes.

**Outside the repo.** Enable iCloud on the App ID with *Key-value storage* ticked (no CloudKit container). The entitlement `com.apple.developer.ubiquity-kvstore-identifier = $(TeamIdentifierPrefix)$(CFBundleIdentifier)` is in the scaffold. Sign a second simulator into the same account for the convergence check.

---

## R3 — Game Center and the daily

### Game Center

`GameCenterClient` protocol (`authenticate`, `report(achievement:)`, `submit(score:to:)`, `isAuthenticated`) with `LiveGameCenter` (GameKit) and `NoopGameCenter`. `GKLocalPlayer.local.authenticateHandler` at launch; the presented sign-in view controller is shown once, never nagged. Not authenticated → reports go into a small `UserDefaults` queue (`gc.queue`, capped at 100) and flush on the next authentication, so an offline IPO still lands. `GKAccessPoint` stays off (it fights the pixel chrome); a *Game Center* row in Settings presents `GKGameCenterViewController`.

**Hook.** `GameEngine.eventSink` (scaffold) delivers every tick's and every `send`'s events; `GameSession+GameCenter.swift` maps `.goalCompleted(goalID:)` → the goal achievement, `.gameOver` → the ending achievement plus the boards below. Ranked boards are posted only when `state.mode.isRanked` (standard mode, no heirloom, no custom rules — R4/R2 set the flag; R3 only reads it).

**Identifiers** (bundle-prefixed so the owner can create them by pasting):

- Achievements, 48: `com.alpsenel.startupstudio.goal.<goalID>` for the 42 ids in `Goals.json` (e.g. `…goal.g1_ship_it`, `…goal.g4i_marry`), 10 points each = 420; `com.alpsenel.startupstudio.ending.<EndingKind.rawValue>` for `bankruptcy`, `acquired`, `ipo`, `oustedByBoard`, `soldUp`, `independent`, 50 each = 300. Total 720 of the 1,000 allowed. Titles are the goal titles and `EndingKind.headline`; the ledger's ending set is the same list, so R2 and R3 agree by construction.
- Leaderboards, 8: `…lb.ipo_days.<easy|normal|hard>` (integer, ascending, submitted `state.day` on `.ipo`), `…lb.still_yours_net_worth.<easy|normal|hard>` (money, descending, `founderNetWorth(balance:)` on `.independent`), `…lb.tenure_days` (integer, descending, `day − min(employees.hiredDay)` excluding the founder, submitted at any ending, any mode), `…lb.daily` (**recurring**, daily, UTC, money, descending).

### The daily

`DailyChallenge.forDay(_ n: Int) -> DailyChallenge` in `TycoonEngine/Daily.swift`: `n` is days since 2026-01-01 UTC; `seed = SplitMix64(n ^ 0xDA11_5EED)` two draws in, `origin = allCases[seed % 4]`, `difficulty = allCases[(seed >> 8) % 3]`. Pure, so it is engine-tested for stability (a table of ten dates → seeds is pinned). Everyone on the same calendar day gets the same company; the game runs the deterministic engine on it.

**A run.** *Today's company* on the title screen shows the date, origin and difficulty and *Play*. It starts `newGame` with `mode: .daily(day: n)` into its own store (`SaveStore<GameState>(directory: …/Daily, slotCount: 1)`), never a slot, so it survives backgrounding and cannot be copied into a slot. Horizon 364 days (`GameState.daysPerYear`): the `DailyHorizonGate` stops the clock at `day == 364` through the scaffolded `advanceGate`, exactly the mechanism the paywall uses; an ending before then ends it early. Score is `founderNetWorth(balance:)` at the stop, posted to `lb.daily`. One attempt: `DailyLedger` (`SaveStore<DailyLedger>` in the same directory) records `n → (score, submitted)`; once recorded, the title entry shows the **result card** — score, ending or "the year is up", the day, and the biography's three lines — instead of *Play*. An attempt started before midnight UTC can be finished after; the post is skipped if the board's period has closed and the card says so. Reinstalling resets it; accepted.

**The gate and the daily.** The daily crosses chapter 1 inside its year. Recommendation: the daily is *free* and the unlock gate does not apply inside `mode == .daily`, because a daily cannot be saved into a slot, continued, or replayed — it is a taste of the later chapters, one per day, and the best funnel this game has. The switch is one line (`UnlockGate.appliesTo(mode)`); if the owner disagrees, the daily is gated at chapter 2 like everything else. Decide before R6 lands.

**Build.** `App/Sources/GameCenter/` (client, queue, id table), `App/Sources/Daily/` (store, ledger, `DailyCard`, `DailyResultCard`, `DailyHorizonGate`), `TycoonEngine/Daily.swift`, `GameSession+GameCenter.swift`, `GameSession+Daily.swift`; the *Today's company* row in `TitleScreenContent` (scaffolded slot), the Settings row.

**Tests.** Engine: the date table; `RunMode.daily` encodes only when set. App: `NoopGameCenter` receives the right ids for a fixture ending (a table test over all six kinds and three difficulties); queue flushes on auth; the horizon gate refuses `x1` at day 364; the result card snapshot; `-autoDaily 20260905` reaches the card headlessly.

**Accepts when** a sandbox Game Center account sees an achievement banner on `g1_ship_it` and a row on `lb.daily`; with Game Center off nothing logs, nothing crashes; the pacing suites are unchanged (no engine numbers move).

**Fails if** a balance change in an update changes the daily's world mid-day so two app versions post different companies to one board. Accept it (the board resets daily) but salt the id table with `MARKETING_VERSION` only if this becomes visible; do not build for it now.

**Outside the repo.** Enable Game Center on the App ID; create the 48 achievements and 8 leaderboards with the ids above (the daily one as *recurring*, 1-day period, UTC start); attach them to the version; a sandbox tester signed into Game Center on the simulator.

---

## R4 — Share, seed codes, and the custom company

### The code

`SeedCode` in `TycoonEngine/SeedCode.swift`: version nibble, `seed` (64 bits), origin (2 bits), difficulty (2 bits), a check byte, Crockford base32, grouped: `SS1-7Q3K9F2A-XB4M8R2C-7`. `encode(seed:origin:difficulty:) -> String`, `decode(_:) -> SeedCode?`; rejects a bad check and any character the bitmap font cannot draw (the alphabet is uppercase + digits, so the card can print it). A URL type `startupstudio://seed/<code>` is registered in the scaffold's `Info.plist`; `StartupStudioApp` handles `onOpenURL` by parking it in `session.pendingSeedCode`, and the title screen's *From a code* row opens the custom page prefilled.

### The three cards

Each is a fixed-size, non-scrolling view rendered by `ImageRenderer` at 1080×1350 (`scale = 1`, the view is laid out at 540×675 points) and offered through `ShareLink(item: Image, preview:)`:

- **Biography card** — `BiographyCardView`: the banner and its ending icon, the founder's `PixelPortrait`, the company name in `PixelCompanyName` (made internal; it is private to `TitleScreen` today), chapters with days, best product with its review line, longest-serving employee, net worth, and the seed code as a `PixelText` footer ("Replay this life · SS1-…"). It is a new composition, not `biographyContent` in a frame; the biography's card is 480 lines of `ScrollView` content.
- **Front page** — the existing `NewspaperScreen` content for one issue, framed; the composer is deterministic per state so the same week shares the same page.
- **Office photo** — `OfficePhotoView` is already a `Canvas`; framed at the same size with the masthead and the game date.

Share buttons: the biography (the toolbar), the newspaper (toolbar), the office card on HQ (a small camera icon on the frame). Every button plays `Sounds.tap`.

### The custom company

`GameRules` in `TycoonEngine/GameRules.swift`: `rivalsEnabled = true`, `incumbentEnabled = true`, `startingCash: Int? = nil`; `static let standard`. `BalanceConfig.applying(_ rules: GameRules) -> BalanceConfig` sets `rivals.rivalCount = 0`, `rivals.depth.incumbentEnabled = false`, `startingCash` when overridden — applied in `GameEngine.newGame`/`resume` immediately after `adjusted(for:)`, the way difficulty already is. `GameState.rules` and `GameState.mode` (scaffold; `.custom` when any rule is non-standard or the seed was typed) are encoded only when non-standard.

A *Custom* page before *You* in `NewGameFlow` (case pre-added): seed field (a code or a number, with *Random*), difficulty (the existing rows move here for this path), rivals, incumbent, starting cash (a stepper from $10k to $500k, default the difficulty's own). The page ends with one honest line: "A custom company earns achievements but does not post to leaderboards." **That is the cost.** `NewGameFlow(options: NewGameOptions)` carries the prefill (from a code) and the mode; `GameSession.startNewGame(profile:companyName:difficulty:origin:seed:rules:)` gains the last two parameters with defaults so `FounderSetupSheet` and replay are untouched.

### Locks (read-only on the ledger)

`OriginRow` shows `.mortgaged` padlocked with "Reach an ending" until `session.ledger.endingsReached` is non-empty (existing players are covered by R2's migration; the engine never checks — `SimRunner` and every bot keep calling `newGame` with any origin). Six extra looks — one curated appearance seed per `EndingKind` appended to `NewGameFlow.appearanceSeeds` as they are earned, with a ribbon. No PixelKit work: the 24 looks are seeds, and so are these.

**Build.** `App/Sources/Share/` (the three card views, `ShareRenderer`, `SeedCodeField`), `Screens/Onboarding/CustomStep.swift`, `TycoonEngine/SeedCode.swift`, `GameRules.swift`, `GameSession+CustomGame.swift`, `OriginRow`, the look picker rows in `NewGameFlow.founderStep`, the *From a code* and *Custom company* rows on the title screen (scaffolded slot).

**Tests.** Engine: `SeedCode` round-trips 1,000 random seeds, rejects one flipped character; `balance.applying(.standard) == balance` (the neutrality proof); rivals-off produces `rivals.studios.isEmpty` at day 365. App: the three cards' `pngData` is above size and `inkCoverage > 0.1` (the `EndingSnapshotTests` sampler); a typed code and the ending's *Run it back* produce the same first month (extend `SeedRoundTripTests`' idea into the app); the custom page snapshot; the padlock snapshot.

**Accepts when** a card shared to Messages on the simulator opens in Photos at 1080×1350 with the code legible; pasting that code into another install founds the same first month; `BalanceTargetsTests` and `InvestorTargetsTests` are byte-identical.

**Fails if** the biography card tries to be the biography — a 5-section poster nobody can read at thumbnail size. Cheapest early check: render it at 270×338 and read the company name and the ending without zooming.

**Outside the repo.** Nothing.

---

## R5 — Endless, and the wave-2 fixes

### Endless

`GameAction.continueAfterEnding` (scaffold), handled in `Reducer.apply` **before** the `gameOver == nil` guard: allowed only when `gameOver?.kind` is `.ipo` or `.independent`; sets `state.epilogue = Epilogue(ending:, day:)`, clears `gameOver`, emits `.continuedAfterEnding`. With an epilogue set: `InvestorSystem` runs no quarterly review and seats no round, `canFileIPO`/`canStayIndependent` are false, `RivalSystem` makes no buyout offer; everything else — rivals, the market, the diary, the team — carries on, and bankruptcy remains possible. `GameEngine` restarts its loop when `gameOver` goes nil (today `performTick` cancels it for good). The biography keeps the original banner and adds "Public since day 812 · still running"; `SaveSummary.epilogue` (scaffold) lets the front door say the same. *Keep running it* sits beside *Run it back* on the biography for those two endings only.

**Neutral by construction:** no bot calls it, no number moves. Tests: `EndlessTests` — continue after an IPO fixture, tick 364 days, same seed twice gives identical JSON; refused after bankruptcy and ousting; no `.quarterlyReview`/`.termSheet`/`.buyoutOffered` events after the epilogue; `FullLoopDeterminismTests` byte-identical.

### The five fixes

1. **One ETA.** `GameState.shipETA(for:)` becomes a projection of `buildETA(productID:)` (`ShipETA.day = state.day + buildETA.daysToShippable`); `ShipETA` stays as the `Identifiable` shape the agenda and Now card read. `BuildETATests` and `ShipETATests` both pass; a new test asserts the two agree on every fixture product.
2. **Optional router reads in sheet content.** `LaunchDaySheet.swift:19` (and the other sheet-presented `@Environment(AppRouter.self)` reads that survive an audit — `MoneySheet.swift:40` is the second) become `AppRouter?`, following `OfficeCard.swift:39`; the documented trap in `StorefrontAutoRoute.swift:35` gets a test that presents and tears the sheet down while clearing `launchDayProductID`.
3. **Box art keys.** `ProductBoxArt.silhouette(typeID:)` matches `mobile_app`, `web_app`, `desktop_tool`, `game`, `saas_platform`, `enterprise_tool` — the ids in `ProductTypes.json` — with a `ContentVarietyTests`-style guard that every type id in the catalog hits a non-default silhouette.
4. **`-autoAnswer` from any root.** `DebugLaunch.startAutoAnswering` moves from `HQScreen`'s task to `AppRootView.game(engine:)`'s, so `-autoTab business -autoAnswer` works, which R8's screenshot pipeline needs.
5. **The lead story's sub-line.** `NewspaperComposer.leadStory` sets `body` to the second sentence of the event's copy (`EventCopy` already has the long form) or, when there is none, to the numbers line — cash delta, reputation delta — never the sentence the headline was compressed from. `NewspaperComposerTests` asserts `headline != body` for every fixture week.

**Outside the repo.** Nothing.

---

## R6 — The unlock

**The product.** One non-consumable, `com.alpsenel.startupstudio.fullgame`, price tier of the owner's choosing. The garage chapter is free; the moment `.chapterReached(chapter: 2)` fires, the progression card's celebration plays as it does today, and then the paywall.

**The gate.** `UnlockGate` implements the scaffolded `AdvanceGate`: `allows(state) = entitled || state.progression.chapter < 2 || !appliesTo(state.mode)`. `GameSession` composes its gates into `engine.advanceGate`; `GameEngine.performTick` and `setSpeed` refuse to run the clock when any gate says no (the engine's own tests never install one). Everything else is live: hire, browse, read the journal, save, sync, share. The Speed control shows a lock glyph and opens the paywall. Because the gate reads `chapter` from state — not a flag in the save — editing the file cannot open it, and because it only ever refuses ticks, nothing can be lost: the run autosaves at the gate day and *Continue* from the front door brings the paywall back.

**Entitlement.** `Entitlements` actor over StoreKit 2: `Transaction.currentEntitlements` on launch (works offline from the local receipt), `Transaction.updates` listened for the app's life (a purchase on another device, a refund — `revocationDate` re-locks), `AppStore.sync()` behind *Restore purchases*, every result checked through `VerificationResult`. A cached `UserDefaults` bool exists only so the first frame does not flicker; the gate never trusts it alone past launch. No server, no receipt validation service — the unlock is Apple-ID-scoped, which is what a $-once game wants.

**The paywall.** `PaywallSheet` on pixel paper: the office scene at night, the four chapter names as flags with the garage lit, `Product.displayPrice` in `PixelText` at scale 3, one button ("Unlock the company · $4.99"), *Restore purchases*, *Not now* (returns to the paused game). No countdown, no "limited", nothing that would fail review or the game's tone. Reduce Motion drops the flag bob.

**The review prompt.** `ReviewPromptPolicy`: ask once per install, on the title screen's `.task` after the player returns from the *first* biography of any ending, never from a daily, never if the paywall was shown in the same session (`@Environment(\.requestReview)`). Stored as `review.askedForVersion`.

**Testing on the simulator.** `App/StoreKit/StartupStudio.storekit` (the one product, the scaffold wires it into the scheme's run action through `project.yml`), and `StoreKitTest`'s `SKTestSession` in the app suite: purchase → the gate opens; refund → it closes; `clearTransactions` → chapter 1 still runs; *Restore* after clear with a purchase present → opens. A `-unlocked` debug flag (DEBUG only, like `-autoSpeed`) for the screenshot pipeline.

**Build.** `App/Sources/Store/Entitlements.swift`, `UnlockGate.swift`, `PaywallSheet.swift`, `ReviewPromptPolicy.swift`, `GameSession+Unlock.swift`, the Restore row in Settings, the lock on `SpeedControl`.

**Tests.** The `SKTestSession` four above; `UnlockGate` table over chapter × entitled × mode; paywall snapshot light/dark; "a gated save loads and shows the paywall on Continue".

**Accepts when** the simulator with the `.storekit` file plays chapter 1 free, stops at chapter 2, buys, runs, refunds, stops again — with the save intact after every step; a release build without the configuration reaches the App Store sandbox.

**Fails if** the gate fires *under* the chapter card and the player sees a paywall before the reward. Cheapest early check: the sheet order test — chapter card dismissed, then paywall.

**Outside the repo.** Create the non-consumable in App Store Connect with the id above, a price, a localized display name and a screenshot for review; the Paid Applications agreement signed; a sandbox tester. Decide the daily question in R3.

---

## R7 — Reaching the rooms

**What exists.** `OfficeSceneView` hides its canvas, overlays one `Color.clear` per `OfficeHitRegion` with label, hint, `.isButton` and an action (`OfficeSceneView.swift:304–328`), labels from `Occupant.accessibilityLabel`. That is the pattern. `MarketMapView` districts are `Button`s with a spoken summary; `NetworkingFloorView` guests and `OrgChartNodeView` nodes are `Button`s. The home, the city map and the rival studio are one label each; the city map has taps (`CityMapComposer.hitTest`) and no elements.

**Build.**

- **Home:** `HomeHitRegion` (`.founder`, `.partner`, `.child(UUID)`, `.furniture(HomeFixture)`) from `HomeSceneComposer`'s placement; `HomeSceneView` gains the office's overlay with static-text elements ("Sam, your partner — affection sliding", "the sofa, tier apartment"). Informational, not buttons, unless the app passes an action.
- **City map:** five district elements from `CityMapComposer`'s district rects, `.isButton`, activating the same `DistrictDetailPanel` the tap opens; the office marker as a sixth.
- **Market map:** keep the buttons; add `.accessibilityValue` with share and standing, and `.accessibilitySortPriority` by market size so the biggest districts come first.
- **Networking floor:** the founder figure gets a label ("You, three exchanges left"); guests already read.
- **Rival studio:** the value line (strength, reputation) on the one label.
- **Dynamic Type on pixel screens.** `PixelText` ignores it by design and every site carries a label. The sweep: every pixel screen at `.accessibility3` and `.accessibility5` in the snapshot suite (the title, the war room, the newspaper, the storefront, the biography, the paywall from R6, the cards from R4); fix by `ViewThatFits` and wrapping, never by scaling glyphs. The `MarketMapScreen` clamp at `...large` becomes a `ViewThatFits`.

**Tests.** PixelKit: `HomeHitRegionTests` (every occupant gets a region; regions never overlap a wall); city district rects cover every district exactly once. App: an `AccessibilityAuditTests` pass with `XCUIApplication.performAccessibilityAudit` on `-autoTab hq|life|business -autoRoute city|marketmap` (iOS 17 API, runs on the simulator); accessibility-size snapshots for the pixel screens.

**Accepts when** VoiceOver on the simulator reaches every person and fixture in the office and home, every district on both maps, and every guest on the floor, in a sensible order; the audit reports no missing labels on the five tab roots.

**Fails if** the overlay is rebuilt every animation frame and VoiceOver focus jumps. The office throttles to `TimelineView(.periodic(by: 1))`; the home and city are static and should use no timeline at all.

**Outside the repo.** Nothing.

---

## R8 — Release plumbing

- **Privacy manifest** `App/Resources/PrivacyInfo.xcprivacy`: `NSPrivacyTracking = false`, no tracking domains, **no** collected data types, accessed-API reasons: `NSPrivacyAccessedAPICategoryUserDefaults` → `CA92.1`. Nothing reads file timestamps (`savedAt` is JSON), disk space, or system boot time. A test asserts the file is in the bundle and `NSPrivacyTracking` is false.
- **App Privacy answers**: *Data Not Collected*. Game Center identifiers and iCloud contents are handled by Apple under the player's account and the app collects nothing of its own; there is no analytics SDK and never will be (rule 7). Verify the Game Center wording in App Store Connect's questionnaire at submission — it has changed before.
- **iPad.** `TARGETED_DEVICE_FAMILY: "1,2"`, `UIRequiresFullScreen: YES` (so portrait-only holds on iPad and the multitasking sizes need not be supported), `UISupportedInterfaceOrientations~ipad` portrait. `AppRootView.game` gets `frame(maxWidth: 640)` centred on `Theme.screenBackground`; sheets become form sheets on their own. `PixelSceneView.Scale.fitWidth` already floors an integer scale, so scenes grow one step and letterbox; `CityMapScreen`'s `.fixed(3)` and 280-pt inset become width-relative. Snapshot helpers gain a second width (820) for the tab roots and the pixel screens. `make build-ipad` and an `iPad Pro 13-inch` destination in the Makefile.
- **Store listing plumbing.** `MARKETING_VERSION` 1.0.0, `CURRENT_PROJECT_VERSION` from `git rev-list --count HEAD` in `project.yml`, `ITSAppUsesNonExemptEncryption = false`, `NSHumanReadableCopyright`, `LSApplicationCategoryType = public.app-category.simulation-games`, the URL type from R4's scaffold. Age rating answers: no gambling (the market is not a casino), infrequent alcohol references (the rooftop party), no violence.
- **Screenshots.** `make screenshots` runs the app on `iPhone 17 Pro Max` and `iPad Pro 13-inch` over a list of `(-autoFixture, -autoTab/-autoRoute, -unlocked, -autoAnswer)` launches and `simctl io screenshot`s into `docs/release/screenshots/<device>/`. `-autoFixture <name>` (new, DEBUG) installs a bundled fixture save into slot 0 before the shell appears — three fixtures generated the way the engine's `FixtureGenerator` makes `scaffold5-garage-day30-4242.json`: a day-40 garage, a day-400 studio with a build in launch week, a day-900 campus with a board. The app's own PNG previews stay what they are (chrome, 393 wide); the store needs real screens at device size. The preview video is out of scope (wave 2).
- **TestFlight checklist** in `docs/release/testflight.md`: the App ID capabilities (iCloud KVS, Game Center, In-App Purchase), the product created and *Ready to Submit*, the 48 + 8 Game Center items attached to the version, the `.storekit` file **not** in the release scheme, export compliance answered by the plist key, the privacy answers, the age rating, a sandbox tester for purchases and one for Game Center, the review notes ("chapter 1 is free; the unlock is at chapter 2 — a sandbox purchase reaches it in ~30 minutes, or use the `Continue` slot on the attached fixture"), and the last-mile check: a release build on a device with iCloud on, Game Center on, no purchase.

**Tests.** The manifest test; the iPad snapshot widths; `make screenshots` producing the expected file count.

**Accepts when** an archive validates in Xcode Organizer with no missing-manifest or missing-entitlement warnings; every tab root and pixel screen holds at 820 points wide with nothing edge-to-edge.

**Fails if** iPad becomes a redesign. It is not: a centred column and integer-scaled scenes. Cheapest early check: run `-autoTab hq` on the iPad destination on day one of the lane and look.

**Outside the repo.** App Store Connect record, the capabilities on the App ID, the screenshots uploaded, the privacy answers entered, the review notes pasted.

---

## R9 — Strings

**What is true today.** Zero `String(localized:)`, zero catalogs, zero `.lproj`. 311 literal `Text("…")` sites are already `LocalizedStringKey`s; roughly 1,500–2,500 user-visible strings pass through `String` — `PixelText(text:)`, `EventCopy`, `NewspaperComposer`, `PostMortem`, the biography's sentences, every `"\(n) days"`.

**Build.** `App/Resources/Localizable.xcstrings` with `SWIFT_EMIT_LOC_STRINGS: YES` and `LOCALIZATION_PREFERS_STRING_CATALOGS: YES` in `project.yml`, `developmentLanguage: en`. Building then extracts every `Text` literal into the catalog for free. The lane's hand work is the `String` sites: `String(localized: "…", comment: …)` on the chrome (`Components/`, `Theme`, `TopHUD`, `NoticeRail`, `SettingsSheet`, the title screen, the onboarding flow, the paywall) and a **`StringsAuditTests`** that greps the app sources for `PixelText(text: "` with a bare literal and fails on new ones — the bar is "no new unlocalized pixel chrome", not "everything converted". Sentence-building code (`EventCopy`, the composer, the biography) gets a `// l10n:` comment naming the string-format it would become, and is left.

**The bitmap font, honestly.** `PixelFont` has 62 glyphs: `A–Z`, `0–9`, space, `$ . , : - + / ! ? ' % ( )`, and `× · ▶ ♥ ★`. No lowercase (all input is uppercased), no accented letters, no `€ £ ¥`, no `&`, `#`, `@`, quotes or brackets; an unknown character draws a hollow box (`PixelChromeTests` asserts it). So **pixel text is English-and-dollars only** until the face grows a Latin-1 extension (~60 glyphs, wave 2), and number formatting stays pinned to `en_US_POSIX` through `Theme.gameLocale` (the `MoneySnapshotTests` guard) because a locale's grouping separator can be a character the face cannot draw. Say this in the catalog's header comment and in the README.

**Content JSON.** Leave `Events.json`, `LifeEvents.json`, `StaffEvents.json`, `News.json`, `Reviews.json`, `Dialogue.json`, `Goals.json` as they are; the path is `ContentCatalog.load(locale:)` reading `Resources/<lang>.lproj/<file>.json` overlays keyed by id with English fallback per string — a wave-2 lane, and an engine-neutral one because ids never change.

**Tests.** The audit test; the catalog exists and the build extracts at least 300 keys (a floor, asserted in the app suite by decoding the `.xcstrings` JSON); every existing snapshot unchanged.

**Accepts when** `xcodebuild` reports no `Localizable.xcstrings` warnings and the app runs identically in English.

**Fails if** the lane tries to convert every string and lands a 2,000-line diff last in the merge order. The audit test is the scope: chrome now, sentences later.

**Outside the repo.** Nothing.

---

## Scaffold pre-adds (one commit, tagged `scaffold-7` on `iteration-7`)

Every shared seam, so no lane edits another lane's file for a declaration. Every addition defaults to today's behaviour; the pacing suites are byte-identical after the scaffold, and `ScaffoldContractTests` grows a test per item.

**TycoonEngine**
- `GameAction`: `// MARK: Iteration 7` region with `continueAfterEnding` (R5). Nothing else — heirlooms, rules and modes are `newGame` parameters or state.
- `GameEvent`: `continuedAfterEnding(ending: EndingKind, day: Int)`, `heirloomApplied(kind: String, day: Int)`.
- `GameState`: `mode: RunMode = .standard` (`standard`, `custom`, `daily(day: Int)`; `isRanked`), `rules: GameRules = .standard`, `heirloom: Heirloom? = nil`, `epilogue: Epilogue? = nil` — all encoded only when non-default, decoded with defaults; `newGame(…, seed:, …, heirloom: Heirloom? = nil, rules: GameRules = .standard, mode: RunMode = .standard)`.
- `GameRules` + `BalanceConfig.applying(_:)` (identity at `.standard`, asserted), applied in `GameEngine.newGame`/`resume` after `adjusted(for:)`.
- `GameEngine`: `public var advanceGate: (@MainActor (GameState) -> Bool)?` consulted by `performTick` and `setSpeed`; `public var eventSink: (@MainActor ([GameEvent]) -> Void)?` called after every tick and `send`; the loop restarts when `gameOver` goes nil.
- `Legacy.swift`: `LegacyLedger`, `LegacyRun`, `Heirloom`, `LegacyDeed`, `LegacyPerson` as empty-defaulting Codable types; `record`/`applyHeirloom` as stubs that R2 fills (guarded by tests R2 writes).
- `Daily.swift` (`DailyChallenge`) and `SeedCode.swift` as files with the type names and one failing-until-implemented test each, so R3 and R4 own them outright.
- `shipETA` re-expressed over `buildETA` (fix 1 of R5, done here because R1 and R3 read it).
- `DepartureReason.formerCompany`.

**TycoonSave**
- `SaveSummary.seed: UInt64?` and `.epilogue: String?` (defaulted, `slot0.json` keys asserted unchanged by `SaveSlotTests`).
- `SaveStore.rawSave(slot:) -> Data?` and `importRaw(_:slot:)`.
- `CloudMergePolicy.swift` with the `Verdict` enum and a stub `resolve`.

**App**
- Directories: `App/Sources/Tutorial/`, `Cloud/`, `Legacy/`, `GameCenter/`, `Daily/`, `Share/`, `Store/`; `App/StoreKit/StartupStudio.storekit` (one product, `com.alpsenel.startupstudio.fullgame`); `App/Resources/PrivacyInfo.xcprivacy` (empty-but-valid), `App/Resources/Localizable.xcstrings` (empty), `App/Resources/StartupStudio.entitlements`; `docs/release/`.
- `GameSession` stored properties, each with an empty default, one per lane's extension file: `tutorial: TutorialProgress?` (R1), `cloud: CloudSyncStatus` and `ledger: LegacyLedger` (R2), `daily: DailyState?` (R3), `pendingSeedCode: SeedCode?` (R4), `unlock: UnlockState` (R6), `gates: [any AdvanceGate]` with the composition into `engine.advanceGate`; `startNewGame(profile:companyName:difficulty:origin:seed:rules:heirloom:mode:)` with defaults so today's three callers compile unchanged.
- `AdvanceGate` protocol (`App/Sources/AdvanceGate.swift`).
- `OnboardingStep` gains `.custom` (before `.founder`) and `.heirlooms` (after `.difficulty`), each rendering an empty stub view behind `NewGameOptions` flags that default off; `NewGameFlow(content:options:onStart:onCancel:)`.
- `TitleScreenContent` gains a `TitleMenu` section with three rows (*Today's company*, *Custom company*, *From a code*) behind `TitleMenu.Row.isEnabled` flags defaulting to false, so R3 and R4 flip flags rather than edit the screen.
- `FounderBiographyView` gains `BiographyActions` (`onShare`, `onContinueRunning`, both optional, both rendered only when set).
- `RailNotice.Kind.tour(TutorialStep)` at priority 1 with the other priorities shifted by one; `NoticeRailSnapshotTests` re-pinned.
- `SettingsSheet` gains a *Services* section with three empty rows (iCloud, Game Center, Restore purchases) each behind a flag.
- `DebugLaunch`: flag names reserved — `-unlocked`, `-autoTour <beat>`, `-autoDaily <yyyymmdd>`, `-autoFixture <name>` — parsed, unused.
- `Info.plist`: `CFBundleURLTypes` (`startupstudio`), `ITSAppUsesNonExemptEncryption = false`.
- `project.yml`: `CODE_SIGN_ENTITLEMENTS`, the entitlements file with `com.apple.developer.ubiquity-kvstore-identifier`, `com.apple.developer.game-center`, and `com.apple.developer.icloud-services: [ ]` (KVS needs no container); the scheme's run action `storeKitConfiguration: App/StoreKit/StartupStudio.storekit`; `SWIFT_EMIT_LOC_STRINGS: YES`. **Not** the device family — R8 flips it with the layout that holds.
- **Balance.json: no keys.** Deliberate; see the top.

### What the scaffold actually cut (5 September, afternoon)

The list above is the plan; `scaffold-7` is the commit. Where they differ:

- **No string catalog and no `SWIFT_EMIT_LOC_STRINGS` in the scaffold.** Xcode rewrites `Localizable.xcstrings` on every build once extraction is on, which would have eight lanes each committing a different 300-key catalog. R9 adds both, last in the merge order, and owns the diff.
- **`DailyChallenge.forDay` is implemented, not stubbed**, with the ten-date table pinned in `Iteration7ScaffoldTests` (`n ^ 0xDA11_5EED`, two SplitMix64 draws in; origin `seed % 4`, difficulty `(seed >> 8) % 3`). R3 builds on it. `SeedCode` is the type with an empty `encoded`/`decode` and a `.disabled` round-trip test that R4 turns on.
- **`CloudMergePolicy.resolve` settles the two one-sided cases** (nil local → `.takeRemote`, nil remote → `.pushLocal`); the seed/day comparison is R2's.
- **`GameSession` fans events out.** `observeEvents(key, observer)` / `stopObservingEvents(key)` and `installGate(_:)` / `removeGate(id:)`; the session re-wires `engine.advanceGate` and `engine.eventSink` on every engine swap, so R1 and R3 both observe without clobbering and no lane touches the engine's hooks directly.
- **`GameEngine.mayAdvance`** is public: the speed control (R6) reads it to draw the lock.
- **Entitlements** are generated by xcodegen at `App/StartupStudio.entitlements` from `project.yml` (`entitlements.properties`), outside `App/Resources` so they are not copied into the bundle. `Info.plist` is likewise generated from `project.yml`'s `info.properties` — edit the yml, never the plist.
- **`TitleMenu`** lives in its own file (`Screens/FrontDoor/TitleMenu.swift`) with `TitleMenu.Flags`; **`ServiceFlags`** (`App/Sources/ServiceFlags.swift`) holds the three Settings constants. Both ship `false`.
- **`ShipETA` over `BuildETA`** landed in the scaffold: `daysAway == buildETA.daysToShippable` (rounded up, where the old query used floor + 1). `ShipETATests` passed unchanged.
- **`EventCopy`** already carries lines for `continuedAfterEnding` and `heirloomApplied`; the lanes may reword them.
- **`GameCenterID`** (`App/Sources/GameCenter/GameCenterClient.swift`) is the id table's prefix functions; `NoopGameCenter` records what it was asked.
- Suites after the scaffold: engine 901 (was 888), save 26 (was 21); the app suite's count is in the commit message.

## File ownership and merge order

| Lane | Owns outright | Touches lightly (the diff is a flag flip, a row, or one call) |
|---|---|---|
| R1 First hour | `App/Sources/Tutorial/`, `GameSession+Tutorial.swift`, `NoticeRail` tour row | `AppRootView.tabs` filter, `GameShell.dayAdvanced`/`eventsChanged` hooks |
| R2 Cloud + ledger | `App/Sources/Cloud/`, `App/Sources/Legacy/`, `TycoonSave/CloudMergePolicy.swift`, `SaveStore` raw methods' bodies, `TycoonEngine/Legacy.swift`, `Screens/Onboarding/HeirloomsStep.swift`, `GameSession+Cloud.swift`, `+Legacy.swift` | Settings iCloud row, title notice line, `NewGameFlow.advance` heirloom pass-through |
| R3 Game Center + daily | `App/Sources/GameCenter/`, `App/Sources/Daily/`, `TycoonEngine/Daily.swift`, `GameSession+GameCenter.swift`, `+Daily.swift` | `TitleMenu` daily flag, Settings Game Center row, `DebugLaunch -autoDaily` |
| R4 Share + codes + custom | `App/Sources/Share/`, `TycoonEngine/SeedCode.swift`, `GameRules.swift` bodies, `Screens/Onboarding/CustomStep.swift`, `OriginRow`, `GameSession+CustomGame.swift` | `TitleMenu` two flags, `BiographyActions.onShare`, newspaper and office toolbar buttons, `NewGameFlow.founderStep` look rows, `StartupStudioApp.onOpenURL` |
| R5 Endless + fixes | `Reducer` Iteration 7 region, `InvestorSystem`/`RivalSystem` epilogue guards, `Epilogue`, `ProductBoxArt`, `NewspaperComposer.leadStory`, `LaunchDaySheet`/`MoneySheet` router reads, `DebugLaunch.startAutoAnswering` site | `BiographyActions.onContinueRunning`, `GameEngine` loop restart |
| R6 Unlock | `App/Sources/Store/`, `App/StoreKit/`, `GameSession+Unlock.swift`, `SpeedControl` lock | Settings Restore row, `TitleScreen.task` review prompt, `AppRootView` paywall sheet |
| R7 Reaching the rooms | PixelKit `HomeHitRegion`, `HomeSceneView` overlay, `CityMapScreen` elements, `MarketMapView` values, `NetworkingFloorView` founder label, `RivalStudioScene` label, accessibility-size snapshots | one-line label edits on the pixel screens |
| R8 Release plumbing | `PrivacyInfo.xcprivacy`, `project.yml` device family/version, `Info.plist` iPad keys, `Makefile` screenshots/ipad, `docs/release/`, `DebugLaunch -autoFixture`, the fixture saves, `AppRootView.game` width cap, `CityMapScreen` scale | snapshot helper widths |
| R9 Strings | `Localizable.xcstrings`, `StringsAuditTests`, `String(localized:)` in `Components/`, `Theme`, the title, onboarding, Settings | `// l10n:` comments elsewhere; README glyph note |

**Merge order: R5 → R6 → R2 → R4 → R3 → R1 → R7 → R8 → R9.**

R5 first because it fixes seams the others build on (the optional router reads, `-autoAnswer` from any root, the box art the share cards draw) and it is the smallest. R6 next because the gate sits in `GameEngine`/`GameSession` and every later lane should rebase onto a tree where the clock can refuse to run. R2 before R4 because R4 reads the ledger's `endingsReached` and both add a step to `NewGameFlow`. R3 after R4 because it reads `mode.isRanked`, which R4 sets. R1 after the front-door lanes because it filters the tab list and must see the final `TitleMenu`. R7 and R8 touch many screens lightly and go late; R9 touches every file and goes last. After each merge: `make gen`, the app suite, and the package suites the merge touched.

## Rules for every lane

1. **Read the line, not the exit code.** `Executed N tests, with 0 failures` for the app suite; `✔ Test run with N tests` per package. A grep-filtered pipeline exits 0 on a compile failure. Report the N.
2. **Worktrees.** One per lane off `scaffold-7`; one simulator clone per lane (`xcrun simctl clone`); never test in a shared tree.
3. **Swift 6, strict concurrency complete, iOS 17.** StoreKit 2, GameKit, `NSUbiquitousKeyValueStore` and `ShareLink` are all iOS 16+; nothing here needs 18. `@MainActor` on the session extensions; the engine stays `Sendable` and free of every framework.
4. **No third-party dependencies. No tracking, no analytics SDKs.** The privacy manifest says *no data collected* and every lane keeps it true.
5. **The pixel visual language.** Paywall, cards, tutorial card, daily card and result card in `PixelPanel`/`PixelText`/`Theme.pixel*`; system controls for controls; `.money` and `Theme.gameLocale` for numbers (the `MoneySnapshotTests` guard); light and dark snapshots; Reduce Motion honoured; Dynamic Type through the accessibility sizes.
6. **Deterministic engine.** No new draws; the daily's seed derivation and the seed code are pure functions with pinned tables; `FullLoopDeterminismTests` byte-identical.
7. **Balance neutral at defaults.** `GameRules.standard` is the identity; no bot calls `continueAfterEnding`; no balance key is added; `BalanceTargetsTests` and `InvestorTargetsTests` byte-identical after every merge.
8. **Saves decode.** New fields optional or defaulted, encoded only when non-default; no `saveFormatVersion` bump; `slot0.json`'s envelope keys asserted; `LegacySaveCompatibilityTests` green.
9. **`project.yml` is the truth.** `make gen` after adding any file; never touch the `.xcodeproj`.
10. **Verify before you claim.** `make build`, the app suite on your clone with the line read, `swift test` in every package you touched, a real screenshot of your surface through the debug flags. Numbers, not adjectives.

## Left for wave 2

- **CloudKit.** When a save or the ledger outgrows the key-value store's megabyte, or when anything is shared between players. Not before.
- **Syncing the daily ledger and the tutorial flag through iCloud.** Small, but it couples R2 and R3; do it when both are merged.
- **Latin-1 glyphs for `PixelFont`** (~60 glyphs) and the content overlay loader (`ContentCatalog.load(locale:)`). The prerequisite for a second language; nothing ships in another language this iteration.
- **A preview video** from the screenshot pipeline (`simctl io recordVideo` over an `-autoSpeed x4` run). Cheap once R8's fixtures exist; not needed for the first submission.
- **A Game Center leaderboard set** and a "friends' daily" card on the title screen. Once the daily has players.
- **Sentence-level localization** of `EventCopy`, the composer, the biography and the post-mortem. R9 marks them; converting them is its own lane.
- **iPad landscape.** Requires-full-screen and portrait get the game on the iPad; a landscape layout is a redesign of the HUD and the rail.
- **What they want / They call you / Bet the Tree / Chapters open with a question** — still on iteration 5's list; none of them is release plumbing.
