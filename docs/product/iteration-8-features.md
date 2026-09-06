# Iteration 8 — pull and rivalry: what was built

*6 September 2026. The seven ideas in `iteration-8-ideas.md`, built in one session on `iteration-8` under the owner's rule of **no new tests** (`CLAUDE.md`): every existing suite stays green and the pacing suites are byte-identical; each feature was verified by running the app on the simulator through a debug flag and reading the screenshot, plus the existing suites.*

## The rule every feature kept

- No new balance key. Stakes and season twists are `GameRules` presets applied after `Difficulty`, exactly the way R4's custom rules are — identity at `.standard`, so `BalanceTargetsTests`, `InvestorTargetsTests` and `FullLoopDeterminismTests` cannot move. Verified: engine 943 passed after every engine change.
- No bot exercises a new mechanic. Stakes, seasons, scenarios and ghosts are entered from the title screen or the custom page only.
- Saves decode. Every new field is optional or defaulted and encoded only when set (`GameRules.stake/twist`, `GameState.lineage/ghosts`, `Rival.ghostIndex`, the ledger's `highestStakeWon/hall`, `LegacyRun`'s dynasty facts).
- Detached runs stay out of the slots. Scenarios and seasons follow the daily's pattern: their own `SaveStore` directories under `Saves/`, `startDetachedGame`, a gate that stops the clock, a ledger one level down, a result card on the front door.

## The seven

| # | Feature | Entry point | Debug flag | Status |
|---|---|---|---|---|
| 7 | Share grid | Daily result card, season result card, biography share sheet | `-autoDaily <yyyymmdd>` | Done |
| 2 | Stakes | Custom page → Stakes card; biography and share-card pennant; `lb.stakes` | `-autoCustom` | Done |
| 3 | Scenarios | Title → Scenarios; weekly featured with `lb.scenario` | `-autoScenario room` / `-autoScenario <id>` (+`-autoSpeed`) | Done |
| 4 | Awards night + Hall of Fame | Mid-December ceremony; Title → Hall of Fame; biography line | `-autoAwards <year>` (with `-autoFixture … -unlocked`), `-autoRoom hall` | Done, sequels deferred |
| 5 | Seasons | Title → This season; `lb.season` | `-autoRoom season` (+`-autoSpeed` plays it) | Done |
| 6 | Dynasty | New company → founder page "Who takes over?"; Title → Dynasty | `-sampleLedger -autoNewGame`, `-sampleLedger -autoRoom dynasty` | Done |
| 1 | Rival ghosts | Automatic in the daily | two consecutive `-autoDaily` days | Done locally; CloudKit written, disabled |

### 7. The share grid

`YearGrid` (App/Sources/Share) reads the financial ledger and the event log into one square per week — green up, red down, gold a launch, black a crash, purple a round, grey unknown — for the last 52 weeks. The daily's ledger entry stores the strip at the stop, the result card shows it and shares `title / strip / score line / Play it: <code>` as text; the biography's share sheet gained "Share the year as text"; the season result card does the same. Both capped stores (500 entries each) cover a daily's year comfortably; a long run shows its last year.

### 2. Stakes

`StakeLadder` (engine, `Stakes.swift`): ten rungs, each keeping the ones below. 1 thin press (+5 review expectation), 2 no credit (the reducer refuses `takeLoan`/`takeSecuredLoan`), 3 hungry rivals (+20 founding strength, ship chance ×1.5), 4 short patience (board patience ×0.5), 5 no crunch (the reducer refuses the crunch pace), 6 jumpy market (boom/crash chance ×2), 7 poachers (poach chance ×2, interval halved), 8 the giant (incumbent floor 0), 9 cold rooms (rapport decay ×2), 10 mortal (chronic condition harder and twice as long). `GameRules.stake` (0 by default, encoded only when set); `isStakeOnly` keeps a stake-only run **ranked** (`CustomChoices.mode` no longer flips to `.custom` for it). The ledger's `highestStakeWon` opens the next rung on a successful ending; the custom page's ladder folds to the rungs within reach with "Show all 10". `lb.stakes` posts the stake on a successful ranked ending. The biography carries "Stake n · title"; the share card's footer says "STAKE N". **Deviation from the ideas doc:** stakes 3, 4, 7, 8, 10 were reworded to what existing knobs can do (no copycat-delay, seated-board-on-day-1 or every-hire-Flight-Risk mechanics exist as balance values).

### 3. Scenarios

`ScenarioCatalog` (App/Sources/Scenarios): ten authored starts, each a bundled fixture (`release-garage-day40`, `release-studio-day400`, `release-campus-day900`) plus a day-one `prepare` closure (cash, bugs on the build, morale, a topic's multiplier, the difficulty, a stake, a rival's strength) and a `check` closure over the live state and the start state. Two objective shapes: *reach by* (stars for speed: ≤½ the days = 3, ≤¾ = 2, by the deadline = 1) and *hold until* (stars for cash: held = 1, ≥ start cash = 2, ≥ start + $100k = 3). `RunMode.scenario(id:startDay:)`; `ScenarioGate` stops the clock when decided; runs and the star ledger live under `Saves/Scenarios/`; the weekly featured one is `ScenarioCatalog.featured(now:)` (catalog index from the ISO week number) and posts `lb.scenario` (weekly recurring). The fixtures now ship in Release (`EXCLUDED_SOURCE_FILE_NAMES` emptied). Scenarios are free of the unlock gate. Verified: *Empty chairs* played headlessly on the campus fixture to a one-star result card.

### 4. Awards night and the Hall of Fame

`AwardsJudge` (App/Sources/Awards) is app-side and pure: for a year it collects every launch — the player's released products (average review score) and every rival's `RivalProduct` (quality) — and names Product of the Year, Studio of the Year (quality summed over launches), Best Newcomer (a studio founded that year), and Best in each topic. `GameShell.dayAdvanced` flags the year when the clock crosses day 350 of it; `AppRootView` pauses the clock and presents `AwardsNightSheet`, resuming on close. Wins are honorific — no number moves — and the biography's story line lists them. `LegacyLedger.hall` (engine) gets every product reviewed ≥ 85 when a company ends (`AwardsJudge.hallEntries`, inducted in `recordEnding`); the Hall of Fame room on the title screen lists them best first with box art. **Deferred:** sequels with hype carry-over need an engine rule; `startProductOnCodebase` already exists, so a sequel is a build on the hall product's codebase today, without the hype.

### 5. Seasons

`GameSeason` (App/Sources/Seasons; the name avoids PixelKit's `Season`): 28-day periods from the daily's epoch, seed/origin/difficulty derived like the daily, one `SeasonTwist` per season cycling through five: platform launch (booms ×2, jump ×1.5), funding winter (no round premium, salaries ×0.8), crash season (crashes ×2, jump ×1.5), poaching season (poach ×2), press year (reviews −5 expectation, market ×1.2). `GameRules.twist` (nil by default) applies them after the stake. `RunMode.season(number:)`, ranked; `SeasonGate` at one game year; own stores under `Saves/Seasons/`; `lb.season` recurring; the result card carries the share grid. The cosmetic is a founder look per season finished (`GameSeason.lookSeed`, appended to the new-game picker via `NewGameOptions.seasonsFinished`). **Deviation:** no PixelKit decor sprites — the look is the reward, which respects the palette rule for free.

### 6. The dynasty

`Successors` (App/Sources/Dynasty) builds offers from the ledger: every finished company's children (name + the founder's surname, a face from the child's seed, an archetype from it), the last company's longest-serving employee (archetype from role), and the last founder again. The founder page shows "Who takes over?" when the ledger offers anybody; picking one sets the name, archetype and look (the successor's seed leads the picker) and a `Lineage` rides `RunSetup` into `GameState.lineage` (engine, encoded when set). `LegacyRun` records `founderAppearanceSeed`, `founderArchetype`, `children`, `longestServing`, `lineage`, `stake` (all optional). The Dynasty room draws the ledger as an indented tree by predecessor; the biography shows the lineage line. **Deferred:** traits grown from the household (the founder has no trait system).

### 1. Rival ghosts

Engine: `GhostScript` (name, face, strength, focus topics, launches, final net worth), `GameState.ghosts` (encoded when non-empty), `Rival.ghostIndex`. `RivalSystem.run` founds one rival per script before rolling the rest — stable id from the script's facts, no `worldRNG` draw — and `evolve` replays a ghost's launches for the days since the last pass instead of drifting or rolling; ghosts never fold. App: `GhostLog` and `GhostStore` (App/Sources/Ghosts) — `LocalGhostStore` keeps this phone's own dailies under `Saves/Ghosts/<day>/`, so the field is *your past selves* until the cloud exists; `CloudGhostStore` is written against CloudKit's public database (`iCloud.com.alpsenel.startupstudio`, record `GhostLog` with `day`, `finalNetWorth`, `payload`) with the local store as fallback and `isEnabled = false` until the container exists. `playDaily` founds today's company against yesterday's best four; the daily's stop records its own ghost (Game Center display name when signed in, else the company name) and the result card says "Finished 2nd of 5 against …". The engine's own tests never see a ghost, so every pacing suite is untouched.

## Suites after iteration 8

App 385, engine 943, save 34, PixelKit 336, content 52 — all green, no test added; the pacing suites are byte-identical. Existing expectations re-pinned: the board id table (11 boards, three recurring), the title-menu rows (7), and the pixel-literal audit's baseline (46, from 37).

## Not done, honestly

- Ghosts across players need the CloudKit container on a paid App ID; flip `CloudGhostStore.isEnabled` once it exists. Until then a daily's field is the player's own earlier dailies.
- Sequels' hype carry-over (engine rule) and household-grown traits (no trait system on founders).
- Office decor as season rewards (PixelKit sprites); a look per season stands in.
- Scenario objectives are closures in code, not content JSON; adding one is a Swift edit.
- The Awards judge treats a rival's `quality` and the player's average review as the same scale, which is what the market already does.

## Debug flags added

`-autoScenario room|<id>`, `-autoRoom hall|dynasty|season`, `-autoAwards <year>`, `-sampleLedger`, `-autoNewGame`. `-unlocked` now sticks on a device until `-locked` (debug builds only; inert under the test host).
