# Iteration 12 — joins: the direction for six lanes

*10 September 2026. The brief for the round that builds
`iteration-12-ideas.md`. Six Opus lanes in isolated worktrees, cut from
`scaffold-12` on `iteration-12`. Each lane's detailed spec is the ideas
doc plus the lens report it came from under `iteration-12-pm/`; this file
is the rules, the ownership and the working method.*

## Why

Iterations 9 to 11 built the founder's life and its dark half, and the
identity rule made all of it opt-in. Nothing the founder does wrong
reaches the company; rivals never read the market; the league is a table
of one; two core choices have one right answer. This round adds joins,
not rooms. Every lane connects two things that already exist.

## The rule every lane keeps

1. **Identity at the default.** A run that never opens a door, never
   announces, never answers a price war, has no case and no fame writes
   the same JSON it wrote before. The byte-identical fixture tests and
   the pacing bots enforce it. New multipliers read 1.0 (or +0) at their
   default; new state decodes if present and encodes when non-default.
   **One exception this round:** J6's two pacing keys deliberately move
   the measured gates; J6 alone re-pins, and reports old and new.
2. **No new draws from `rng` or `worldRNG` on the default path.** Reweight
   an existing draw (J3's topic pick) or use a private stream derived
   from `state.seed`, and only once engaged.
3. **No new tests.** The owner's rule in `CLAUDE.md`. Run every suite;
   extend none. Re-pin an existing number only when your feature
   legitimately changes it, and say so with old and new in your report.
   Moving files between targets (J4) is allowed; adding test functions is
   not.
4. **Read the Executed line.** `Executed N tests, with 0 failures` for the
   app, `✔ Test run with N tests … passed` for a package. Run the app
   suite last, on your own simulator, when your own build is done. If a
   heavy snapshot test reports "crashed with signal kill" while the other
   lanes are compiling, re-run that test alone before you believe it.
5. **Old saves load.** Decode-if-present, encode-when-non-default. The
   four committed fixtures under `Tests/Fixtures` must load unchanged.
6. **Pixel, not SF.** New sheets use the pitch room, pixel paper, the
   phone and the `Theme`. Study one before drawing.
7. **Every action shows its consequence on the button**, and a refused
   action says why. A number the player cannot see is not a mechanic.
8. **Prefix every new type with your lane's subject:** `Door…`,
   `Standing…`, `RivalMarket…`, `HouseField…`, `Announce…`, `Queue…`.
9. **A new balance block is one defaulted property** in
   `BalanceConfig.swift` under your `// MARK: J<n>` marker, with its
   struct in `Balance/BalanceConfig+<Subject>.swift` and its key
   appended to `Resources/Balance.json` at the end. Few keys: the config
   is near four hundred stored properties and a debug-build stack cliff
   (see `iteration-11-features.md`).
10. **Insert only between your own two markers in shared files.** The
    scaffold opens `// MARK: J<n> (…)` / `// MARK: end J<n>` regions in
    `GameAction`, `Reducer` (systems and handlers), `GameState`
    (`GameEvent` and the slot block), `BalanceConfig`, `AppRouter`,
    `DebugLaunch`, `EventCopy`, `LifeScreen`, `TeamScreen`,
    `BusinessScreen`. In any other shared file you must touch, open your
    own pair at the point of use. A change you need outside your markers
    in a file another lane owns is a follow-up in your report, not an
    edit.
11. **Dark, not cruel.** Short, specific, deadpan.
12. **Events are content.** New events go in JSON with your lane's prefix
    (`door_`, `standing_`, `rivalmarket_`, `announce_`), appended at the
    END of the right file. Expect a both-added merge and nothing else.
    Wave-two lanes learned that an ungated life event moves the
    byte-identical fixtures: gate every new event on a flag only your
    feature raises.

## The scaffold

Committed at `scaffold-12`: the marker regions above, this document and
the ideas. No engine stubs this round; each lane's types are its own.

## The lanes

| Lane | Branch | Sim | Builds | Size |
|---|---|---|---|---|
| J1 | `j1-doors` | `ws-l1` | F1 doors + Life B5 surfacing + Meta B1 coach tips | M |
| J2 | `j2-record` | `ws-l2` | F2 the record crosses over (board, name, spotlight) | M |
| J3 | `j3-rivals` | `ws-l3` | F3 rivals follow the money + I4 price war + copycat card | M |
| J4 | `j4-field` | `ws-l4` | F4 the house field | M–L |
| J5 | `j5-announce` | `ws-l5` | F5 announce the date + I1 premium | M |
| J6 | `j6-queue` | `ws-l6` | I5 one queue + I2 children's clock + I3 pacing keys and re-pin | M |

Specs: `iteration-12-ideas.md` (F1–F5, I1–I5) and, for the full
mechanic, numbers and "how it fails" checks, the lens report named there
(`iteration-12-pm/systems.md` A1/B1/B3/B4, `life.md` A1/A2/B1/B5,
`company.md` A1/A2/B1/B3/B4, `meta.md` A1/B1). Where the ideas doc and a
lens report disagree on a number, the ideas doc wins; where the ideas doc
is silent, the report is the spec.

## File ownership

| Lane | Owns |
|---|---|
| J1 | `Doors.swift`, `Systems/DoorSystem.swift`, `Balance/BalanceConfig+Doors.swift`, `App/Sources/Screens/Life/Doors/**`, `App/Sources/Components/TipStrip.swift` (state-keyed tips), marked regions in `Systems/DirtyMoneySystem.swift` (run the offer as if finances were opened), `Systems/AssetsSystem.swift` (engage + seed the vice), `Systems/FameSystem.swift` (open the feed with a drafted post), `Systems/FamilyDramaSystem.swift` (open the room at the care beat), the launch-day sheet ("Tell people"), `EventPresenter` (room links on the wedding and burnout beats), `Events.json` / `LifeEvents.json` append (`door_`). Uses the notice rail's existing `deferred` entry point; does not edit `NoticeRail.swift` (J6 owns it). |
| J2 | `FounderStanding.swift` (pure), `Balance/BalanceConfig+Standing.swift`, marked regions in `Systems/InvestorSystem.swift` (the key-person line beside the pay-pressure line), `Investors.swift` (term-sheet haircut; the printed review line), `Systems/HiringSystem.swift` (asks, the refusal), `Interactions.swift` + `Systems/InteractionSystem.swift` (the mean-act day list), `Crime.swift` (spotlight on discovery; the laundering constant becomes a key), `Espionage.swift` (spotlight on trace), `Fame.swift` (rung drop on conviction or trace), `App/Sources/Screens/Team/HiringSheet.swift` (the standing line), the board-review sheet, the operation buttons' odds breakdown. |
| J3 | marked regions in `Systems/RivalSystem.swift` (weighted topic pick, boom recruit, crash drop, product type, price-war answers, copycat card read), `Market.swift` (the forecast's topic line), `Rival.swift` (new fields, decode-if-present), `FeatureBoard.swift` (copied-card fit), `App/Sources/Screens/Business/RivalFight/**` (the price-war sheet), marked regions in `MarketMapScreen`, `TopicDetailView`, `CategoryStripCard`, `RivalProfileScreen`, the feature-board card view (the "copied by" chip), `NewspaperComposer` (market column), `Events.json` append (`rivalmarket_`). Adds `noticeMarketOpened` under its J3 markers and stores the flag decode-if-present. |
| J4 | A new `TycoonBots` library target in `Packages/TycoonEngine/Package.swift` holding `SimRunner`, `BotPolicy`, `PacingBots`, `InvestorBots` moved out of the test target (the test target depends on it; imports only, no test edits beyond that), `App/Sources/Leagues/HouseField*.swift`, `LeagueDemoField.swift`, marked regions in `GameSession+League.swift`, `GameSession+Ghosts.swift`, `Ghosts/GhostStore.swift`, the league, daily and season cards, `project.yml` (link the library). No engine balance change. |
| J5 | marked regions in `Product.swift` (`announcedDay`, `slips`, encode-when-set), `Systems/MarketingSystem.swift` (decay and campaign multipliers), `ShipETA.swift`, one marked line in `RivalSystem.copycatCheck` reading `Announce.copycatDelayWeeks` from its own `Systems/RivalSystem+Announce.swift` (J3 owns the rest of that file), the premium demand formula where the tier is applied (marked) and `Balance.json` `economy.priceTiers` / `premium*` keys, `App/Sources/Components/LiveOps.swift` (the caption), `App/Sources/Screens/Products/Announce/**`, marked regions in `WarRoomScreen`, the launch-week pitch-room interview, `NewspaperComposer` (the slip headline; J3 is in that file too, both append under own markers), `Events.json` append (`announce_`). |
| J6 | `App/Sources/Components/NoticeRail.swift`, the `PausePolicy` and `pendingChoice` region of `GameState.swift` (keep the existing `pendingChoice` API working for the other lanes), the five direct `state.speed = .paused` writes (three in `FamilyDramaSystem`, one each in `CrimeSystem`, `PrisonSystem`; tiny marked edits), the wave-two demand sheets onto the rail (`DirtyMoney` demands, family confrontation, the case), `Balance/BalanceConfig+Childhood.swift` `stageDays`, the two pacing keys (event cash scale in the narrative block; campus rent formula where office rent is read) and the re-pin of `BalanceTargetsTests` / `InvestorTargetsTests` numbers with old and new in the report. |

Known shared spots, both-added by design: `RivalSystem.swift` (J3 owns;
J5 one marked line), `NewspaperComposer.swift` (J3, J5), `Fame.swift` /
`FameSystem.swift` (J1 opens the feed, J2 drops a rung), `FamilyDramaSystem.swift`
(J1 the care door, J6 the pause writes), `Balance.json` and
`BalanceConfig.swift` (J1, J2, J5, J6 each append one block).

## Working method

- **Worktree per lane**, pre-created by the PM at
  `/Users/alp/Desktop/Personal-Projects/StartupStudio-lanes/j<n>` on
  branch `j<n>-<slug>` from `scaffold-12`. Work only there.
- **Simulator per lane:** `ws-l<n>`. `make gen` first (the project file
  is generated and gitignored), then `make build SIM=ws-l<n>` and
  `make apptest SIM=ws-l<n>`. Never the shared "iPhone 17".
- **Launch with your flags:** `-unlocked -autoSpeed x4` plus your own
  `-autoRoute …` / `-auto<Subject> …` registered under your `DebugLaunch`
  markers, so a screenshot needs no play-through.
- **Baselines at scaffold:** engine 943, content 52, save 34, PixelKit
  336, app 385. Your numbers must match, or your report says which pin
  moved and why.
- **Verify before you report:** every package suite, then
  `make apptest SIM=ws-l<n>`. Paste the summary lines.
- **Report** as `docs/product/iteration-12-lanes/j<n>.md` with screenshots
  under `iteration-12-lanes/j<n>/`, in the shape of `iteration-11-lanes/w3.md`:
  what was built (engine, app, content), the numbers, the "how it fails"
  check you ran and what it showed, suites, follow-ups, debug flags.
- **Commit on your branch;** no merge, no push. The PM merges J6 → J5 →
  J3 → J2 → J1 → J4, runs `make strings` once, records the round in
  `iteration-12-features.md`, and fast-forwards main.

## What "done" looks like

A founder three weeks from the wall gets the call without going looking
for it; a founder with a hearing next month watches the board price it;
a boom fills with company and a crash empties; the league has nineteen
names in it on the first day; a ship date is a promise the paper
remembers; premium is sometimes right; children grow up before the
campus; and every question the game asks arrives through one door with a
deadline on it.
