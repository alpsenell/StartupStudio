# Iteration 10 — interactive rooms: things the player does, not waits for

*Direction doc for six lanes. Scaffold: tag `scaffold-10` on branch
`iteration-10`. Read this whole file, then `iteration-9-features.md` for
what the last round learned at merge time.*

## Why

Almost every action in the game is a button that moves a number and then a
wait. The player is *doing* something in the moment in exactly three
places: the networking floor, the launch-week war room, and the story
sheets. Building a product is a focus slider and a wait. A term sheet, a
contract bid, an interview and a board review are accept or decline.
Nothing breaks in a way you have to handle live. And there is no reason to
open the app for sixty seconds on a day you are not playing a run. This
round fills those gaps with six rooms.

## The rule every feature keeps

Same as iterations 5 through 9, plus three lessons from the last merge:

1. **Identity at the default.** New balance values read as "off" or 1.0 at
   their default; a feature the player never engages must not change a
   number in a run that never engages it. The pacing bots and the
   byte-identical fixtures (`OriginTests`, `ReleaseFixtureGenerator`)
   will tell you.
2. **No new draws from `rng` or `worldRNG`.** Use `state.socialRNG` or a
   private stream derived from `state.seed`, and only when engaged.
3. **No new tests.** Run every suite as verification; extend none. Re-pin
   an existing expectation only when your feature genuinely changes what
   it counts, and say so with old and new numbers.
4. **Read the Executed line.** The evidence is
   `Executed N tests, with 0 failures` for the app and
   `✔ Test run with N tests … passed` for a package.
5. **Old saves load.** Everything new decodes as its default when absent
   and encodes only when non-default (the `ghosts` precedent).
6. **Pixel, not SF.** Study `WarRoomScreen`, `NetworkingVenueSheet`, the
   phone's `ThreadView`, `FurnishSheet` and the `Theme` before inventing.
   Palette-only sprites.
7. **Every action shows its consequence on the button**, and a refused
   action says why.
8. **Prefix every new type with your lane's subject.** Three lanes each
   declared a `BondBar` last round. `FeatureCardView`, `PitchLine`,
   `IncidentBoard`, `LeagueRow`, `DeskCard`, `BugSprite`: never a generic
   name.
9. **A new `BalanceConfig+X.swift` block must also exist as a key in
   `Packages/TycoonEngine/Sources/TycoonEngine/Resources/Balance.json`**
   (append after `"sabbatical"`), or the engine suite fails on
   `keyNotFound`.
10. **Insert only between your own two markers** in shared files. If you
    need a change in a file you do not own, write it in your report as a
    follow-up, do not make it.

## The scaffold

Committed at `scaffold-10`:

- Engine files, one per lane, that lanes own and may reshape:
  `FeatureBoard.swift` (M1), `PitchRoom.swift` (M2), `Incident.swift`
  (M3), `League.swift` (M4), `MorningDesk.swift` (M5), `BugHunt.swift`
  (M6).
- `GameState` slots `pitch: PitchState?`, `incident: IncidentState?`,
  `desk: DeskState`, each with a coding key, decode-if-present and
  encode-when-non-default. **Do not add fields to `GameState`.** M1's
  state goes on `Product` (M1 owns `Product.swift`, whose Codable is
  hand-written). M4 and M5 have marked regions in `LegacyLedger` (fields,
  keys, decoder).
- Marker regions `// MARK: M<n> (…)` in: `GameAction.swift`,
  `Reducer.swift` (systems and handlers), `GameState.swift` (`GameEvent`,
  which iteration 9 lacked), `RunMode.swift` (M4), `Legacy.swift` (M4, M5),
  `AppRouter.swift` (`Route` and its tab switch), `DebugLaunch.swift`
  (flags and route names), `GameCenterCatalog.swift` (M4), and
  `consumeRoute()` in `ProductsScreen`, `BusinessScreen`, `HQScreen`, plus
  the row list in `TitleMenu.swift` (M4, M5).

## File ownership

| Lane | Owns |
|---|---|
| M1 | `FeatureBoard.swift`, `Product.swift`, `Systems/ProductSystem.swift` (the build and the review paths), `ShipForecast.swift`, `Codebase` sequel inheritance, a `Features.json` in TycoonContent with its `ContentCatalog` wiring (decode-if-present), `ReviewCatalog` blurb hooks, `App/Sources/Screens/Products/NewProductFlow.swift`, `ProductDetailScreen.swift`, `App/Sources/Screens/Products/FeatureBoard/**`, `App/Sources/Screens/Storefront/**` (the features list), `Systems/RivalSystem.swift` copycat region (marked) |
| M2 | `PitchRoom.swift`, `Systems/PitchSystem.swift` (new), `Networking.swift` marked region (new counterpart kinds if needed), `App/Sources/Screens/Business/PitchRoom/**`, marked regions in `InvestorsView.swift`, `ContractsView.swift`, `DeskCard.swift`, the newspaper's interview hook (`App/Sources/Screens/Story`, marked), `Systems/InvestorSystem.swift` marked region (term sheet terms and board review outcome from a pitch), `Systems/ContractSystem.swift` marked region (bid terms), a `Pitches.json` in TycoonContent (lines, wants, tells) |
| M3 | `Incident.swift`, `Systems/IncidentSystem.swift` (new), `Systems/LiveOpsSystem.swift` marked region (what raises an incident), `App/Sources/Screens/WarRoom/Incident/**`, marked regions in `NowCard.swift` and `AppRootView.swift` (the full-screen presentation, the way the war room is presented), `EventCopy` for your events, a `BalanceConfig+Incidents.swift` |
| M4 | `League.swift`, `RunMode.swift` (the `.league` case and every switch), `App/Sources/Leagues/**`, `GameCenterCatalog.swift`/`GameCenterClient.swift` marked regions, `docs/release/game-center-ids.md` (append), `App/Sources/Share/YearGrid.swift` marked region (the challenge payload), `GameSession+CustomGame.swift` marked region (the challenge URL), `TitleMenu.swift` and `TitleScreen.swift` marked regions, `Legacy.swift` M4 regions, `App/Sources/Ghosts/GhostStore.swift` marked region (a league week's field) |
| M5 | `MorningDesk.swift`, `App/Sources/Desk/**`, `TitleMenu.swift`/`TitleScreen.swift` marked regions, `Legacy.swift` M5 regions (the streak and its rewards), `LegacyStore.swift` marked region, `HomeDecor.swift` marked region (streak decor ids, decode-safe), `Unlocks.swift` marked region (a streak look), local notifications (a new `App/Sources/Desk/DeskReminder.swift`; ask permission only from the desk itself, never at launch) |
| M6 | `BugHunt.swift`, `Systems/ProductSystem.swift` marked region (one function: squash), PixelKit `Office/OfficeFX.swift`, `OfficeFXSprites.swift`, `Office/OfficeHitRegions.swift` (a bug hit region), `OfficeSceneView.swift` marked region, `App/Sources/Screens/HQ/OfficeCard.swift` and `OfficeTaps.swift` marked regions, `Audio/**` marked region (a squash chirp), a `BalanceConfig+BugHunt.swift` |

Shared, marker-only: `GameAction.swift`, `Reducer.swift`, `GameState.swift`,
`AppRouter.swift`, `DebugLaunch.swift`, the three `consumeRoute()`s, the
title menu rows. M1 and M6 both touch `ProductSystem.swift`: M1 owns it,
M6 adds one marked function at the end.

## The six lanes

### M1 — The feature board

**What.** A product is assembled from feature cards on a board rather than
a focus slider. The hand comes from the tech tree, the team's skills and
the market's appetite this quarter; the player places four to six cards
(the product type sets the slots), chases synergies between cards and with
the topic, and the review quotes the cards by name. Rivals copy the best
card eight weeks later; sequels inherit the board; the storefront lists
the features.

**Build.**

- `Features.json`: forty to sixty cards across the twelve topics and the
  product types, each with `fits` (types, topics), `unlockedBy` (a tech
  node id or none), `leansOn` (design/code/polish), `synergies` (card
  ids), `appetiteTag` (a market boom tag it rides). Decode-if-present in
  `ContentCatalog` so the content suite's variety checks still pass.
- `Product.features: [String]` in the hand-written Codable; `FeatureBoard`
  computes the hand (`hand(for:state:content:)`), the board's score
  (`boardScore` in 0…1 from fit, synergy, appetite and slot fill) and the
  copy for the review. The score feeds `ProductSystem.ship`'s quality as
  a multiplier that is exactly 1.0 for an empty board, so a bot that never
  places a card gets the game that shipped; a full, well-fitted board
  earns up to the balance's cap and a badly fitted one costs. The
  `ShipForecast` shows the board's contribution before shipping.
- Actions: `.placeFeature(productID, cardID, slot)`, `.removeFeature(
  productID, slot)`; refused after design phase ends (say so).
- Reviews: `ReviewCatalog.blurbs` gains a `{feature}` token M1 fills from
  the board's best and worst card. Storefront lists the features. Rival
  copycat (`RivalSystem`, marked region) records the copied card in the
  rival column copy. Sequels (`startProductOnCodebase`) start with the
  parent board pre-placed.
- App: `FeatureBoardScreen` from the product detail during design (the
  board as pixel slots, the hand as a fanned row of cards with fit shown
  in words, synergy lines drawn between placed cards); the new-product
  flow's last step opens it. `-autoRoute featureboard`.

### M2 — The pitch room

**What.** Term sheets, contract bids, press interviews and the quarterly
board review become short conversations in the networking floor's format.
The person across the table has a hidden want you discover by listening;
the lines you pick move the valuation, the terms, the review's tone, or
the board's patience.

**Build.**

- Four counterparts: *investor* (opens from a term sheet: three exchanges
  to move `amount`, `equity` and `patienceWeeks` within a band), *client*
  (opens from a contract offer: payout, deadline, quality bar), *journalist*
  (opens the week of a launch: the outlet's review band shifts one notch
  either way, and the front page's lead), *the board* (opens on a
  quarterly review with pressure > 0: talk pressure down or up).
- The exchange grammar reuses `ConversationTopic`: small talk is safe,
  shop talk is graded on the relevant founder attribute, listen reveals
  the want, pitch is the swing. Three to five exchanges. `Pitches.json`
  holds lines, wants and tells per counterpart and per situation.
- `PitchState` on `GameState`; `PitchSystem.run` times a pitch out at
  day end (the default outcome is exactly today's accept/decline path, so
  a player who never opens the room has the game that shipped).
- App: `PitchRoomSheet` drawn like the venue sheet with one person at a
  table, the exchange buttons carrying their read ("They lean in", "That
  landed badly"), and the terms updating live. Entry points: a *Talk
  first* button on the term sheet, the contract offer, the board review
  card and the launch-week press strip. `-autoRoute pitch`.

### M3 — The incident room

**What.** When a live product breaks, from a bad patch, a viral spike or a
data leak, the clock stops and an incident room opens: a triage board
where you assign people to *mitigate*, *communicate* and *fix*, a status
page that changes as they work, a countdown of users leaving, and a
public statement to choose. The outcome lands on reviews, reputation, the
journal and the phone.

**Build.**

- `IncidentSystem.run` raises an incident from `LiveOpsSystem`'s facts
  (live bugs over the alarm threshold after an update, a sales spike over
  the hosting cost, a `dataLeak` roll gated on the Legal department and
  drawn from `socialRNG`), at most one per product per quarter, never in
  a run with `rules` that forbid it, and never for a bot: incidents only
  fire once the player has opened the Products tab this run (a flag M3
  sets from the app) so the pacing bots stay where they are.
- The room is a stopped-clock mode like the war room: `IncidentState`
  holds the three threads, who is on each, the status (red/amber/green),
  users lost so far, and the statement chosen. Actions:
  `.assignToIncident(employeeID, thread)`, `.chooseIncidentStatement(id)`,
  `.resolveIncident`. Each "tick" of the room is an action too
  (`.advanceIncident`), so the room is deterministic and replayable.
- Outcomes: users lost become churn on `ReleaseInfo`; the statement moves
  reputation; a bad fix leaves live bugs; the front page leads with it;
  the phone's office thread and the partner both post.
- App: `IncidentRoomScreen`, full-screen like the war room (marked region
  in `AppRootView`), pixel status page, the team as draggable portraits
  on three lanes, the countdown, the statement as three story-sheet
  buttons. `-autoIncident <kind>` on a fixture with a live product.

### M4 — Leagues and challenges

**What.** Weekly leagues of about twenty players on one seed, with
promotion and relegation across tiers, and *Beat my company* challenges:
your seed plus your year grid as a link, their attempt, and both of you
see the comparison.

**Build.**

- `RunMode.league(week:)`: the week's seed derived from the ISO week the
  way the daily derives from the day, one attempt, scored at one game
  year on net worth (the daily's rule). Tiers are Game Center leaderboard
  *sets* per tier (bronze, silver, gold, founders); the ledger remembers
  the player's tier and last week's rank; promotion is the top four,
  relegation the bottom four, computed on the client from the recurring
  board's scores when the week rolls (no server).
- Challenges: a `SS1-…` seed code with the challenger's grid and score
  appended (`YearGrid` marked region), opened by the existing URL scheme
  (`GameSession+CustomGame` marked region). Playing it is a custom run on
  that seed; the result card shows both grids side by side and, with Game
  Center, posts the pair as a challenge activity if the API is available
  on the device, otherwise as a share card.
- Ghosts: a league week's field is the other players in your tier (the
  ghost store's marked region), so the rivals in a league run are the
  people you are racing.
- App: `LeagueScreen` from the title menu (your tier, the table, days
  left, the seed), the result card, and the challenge flow. `-autoLeague`.
- Game Center ids in `docs/release/game-center-ids.md`; the existing
  pinned counts in `GameCenterDailyTests` move, say by how much.

### M5 — The morning desk

**What.** A one-minute daily ritual at the front door, even mid-run: one
message to answer, one decision, one tap. A streak counter, and streak
rewards paid in decor, founder looks and season cosmetics rather than
stats.

**Build.**

- The desk derives three cards from the current slot's state without
  advancing the clock: the newest unanswered phone thread, the most urgent
  desk item from the Business tab's list, and one tap (praise somebody, a
  coffee, water the plant). Clearing all three marks today (yyyymmdd) in
  `DeskState.clearedDays` and advances the ledger's streak (M5's `Legacy`
  regions: `deskStreak`, `deskBestStreak`, `deskLastDay`, all
  decode-if-present). A missed day resets, with one free "sick day" a
  month.
- Rewards at 3, 7, 14, 30, 60 and 100 days: a decor id
  (`HomeDecor` marked region), a founder look (`Unlocks` marked region),
  a masthead flourish. Never a stat.
- A local notification the player opts into *from the desk* ("Remind me
  tomorrow"), one a day, at the hour they cleared it. Never ask at launch.
- App: `DeskCard` on the title screen (streak, today's three), the desk
  itself as a pixel desk with three papers, cleared papers fly off. The
  same desk is reachable from the HUD's date. `-autoDesk`.

### M6 — The bug hunt

**What.** During a build, bugs crawl across the coders' desks in the pixel
office and a tap squashes one, taking one off `openBugs`. Capped per day
so it is a treat, not a strategy. A chirp and a splat.

**Build.**

- PixelKit: a `bug` sprite (palette-only) that walks a short path near a
  coder's desk while their product is in code or polish phase and has
  open bugs; a `bug` hit region; a splat frame. `OfficeSceneInput` gains
  a defaulted `bugs` input so every existing caller draws what it drew.
- Engine: `.squashBug(productID:)` decrements `openBugs` by one, at most
  `balance.bugHunt.perDay` (default 3) per day, refused past the cap and
  outside the phases; a `GameEvent.bugSquashed` (M6's region) for the
  journal, collapsed by the journal's routine-week rule.
- App: `OfficeCard` spawns bugs from the products in flight, the tap
  dispatches the action, a haptic and a synthesized chirp from `Audio`.
- Neutral: nothing spawns unless a build has open bugs, and the cap keeps
  it from touching the pacing bots (no bot taps).

## Working method

- **Worktree per lane**, branch `m<n>-<slug>` from `scaffold-10`
  (`git checkout -B m1-featureboard scaffold-10`). Never build or test in
  the main checkout.
- **Simulator per lane:** `ws-l1` … `ws-l6` (M1 → ws-l1 … M6 → ws-l6).
  Build with `xcodebuild -project StartupStudio.xcodeproj -scheme
  StartupStudio -destination 'platform=iOS Simulator,name=ws-l<n>'
  -derivedDataPath build build` after `make gen`; install and launch with
  `-unlocked -autoSpeed x4` plus your own flags; screenshot with
  `xcrun simctl io ws-l<n> screenshot`.
- **Verify before you report:** engine, content, save and PixelKit suites
  (`swift test` in each you touched, TycoonEngine always) and
  `make apptest`. Paste the summary lines.
- **Report** as `docs/product/iteration-10-lanes/m<n>.md` with
  screenshots under `m<n>/`.
- **Commit on your branch**; do not merge, do not push. The PM merges
  M6 → M1 → M3 → M2 → M5 → M4 and runs `make strings` once at the end.

## What "done" looks like

A build is a board the player argues with. A term sheet is a conversation
they can win. A bad day is a room they run. A week has a table they are
climbing. A morning has a desk that takes a minute. And a bug is a thing
they can squash with a thumb.
