# Meta, retention and session shape: iteration 12 PM report

*Read-only pass over `iteration-11` @ a12f3be.*

**Where I disagree with the brief.** This lens is not short of modes. The front door already has Continue, three slots, Today's company, This season, Scenarios, Hall of Fame, Dynasty, League, The desk, a seed code and custom (`TitleMenu.swift:71-82`). What's thin is that three of those rows are the same game with the same score, two of them have no opponents, and nothing earned in a short mode reaches the long run. So most of what follows adds connections between things that exist, not new rows.

## What the ideas rest on

- **Ghosts are only you.** `CloudGhostStore.isEnabled = false` (`Ghosts/GhostStore.swift:126`), because the personal team can't sign the container. The daily's "real players" are therefore this phone's own finished daily from yesterday: `ghostScripts(forDailyDay:)` reads `day - 1` from the local cache.
- **A signed-out league week is a field of one.** `settleLeague` sets `fieldSize = max(standings.count, rank)`, which is 1 with nobody else in the table. `LeagueRules.outcome` returns `.held` when `fieldSize <= 1`, so that player stays Bronze forever.
- **The three shared modes ask one question.** Daily (`GameSession+Daily.swift:144`), season (`GameSession+Season.swift:113`) and league all score `founderNetWorth` at day 365. Since N3, that number is wallet + asset resale (car, property, the crypto wallet) + the equity slice (`Investors.swift:504-512`).
- **Everything but the long run is free.** `UnlockRule.allows` (`Store/UnlockGate.swift`) lets daily, scenario, season and league run in every chapter. The purchase only buys continuing your own company past the garage, and custom games.
- **The tour switches coach tips off.** The six coach tips are all chapter-1 (`TipStrip.swift:25-68`). Finishing or skipping the tour writes all six into `dismissedTips` (`GameSession+Tutorial.swift:134`), so the tip rail never fires again for any fresh install.
- **Little of a run crosses an ending.** Iteration 11 added 121 company events and 221 life events. The only one of those to cross an ending is the will (`LegacyRun.willHeir`, `Legacy.swift:371`).
- **Session shapes today.**
  - 5 minutes works: the morning desk, then a few game weeks.
  - 30 minutes is a shared-seed year: about 90 s of ×4 clock plus 30–45 stops. That figure is the iteration-5 pacing estimate, not measured on this branch. The year then ends at a wall: "Come back tomorrow for a new one."
  - Day 2 and day 30 are the desk streak, which pays only cosmetics (`DeskRewards`).
  - Day 7 is the league, and the league is empty.

---

## A) Five new features, ranked

### 1. The house field
**Pitch.** Nineteen house founders also play every league week and every daily. Each has a name and a face and plays a known strategy. The table is full on the first day anyone installs, and the people you climb past are ways of playing, not blanks.

**Mechanic.**
- The first time the front door opens in a new league week or daily day, a background task plays the house roster through that seed to day 365.
  - Bronze: SoloSlow, Grinder and Neglectful variants.
  - Silver: CrunchHire and SaaS.
  - Gold: InvestorBot variants.
  - Founders: the best of each.
- Each house run writes an ordinary `GhostLog` (launches and final net worth) under the existing `LeagueGhostKey` (`1_000_000 + week*8 + tier`) or the daily's day key. The table, the daily's four ghost rivals (`ghostFieldSize = 4`) and the result card all read it through paths that already exist.
- The field is real players first (the Game Center board, or cloud ghosts once they're on), with house founders filling up to `LeagueRules.fieldSize` 20. Promotion stays 4 up and 4 down.
- The result card names whoever finished directly above you, and how they play: "Grinder — contracts only, never hired — finished $38,000 ahead."
- The bots are pure functions of seed and balance, so every phone computes the same house scores. There are no draws on the player's engine and no network.

**Hooks.**
- The bots in `Packages/TycoonEngine/Tests/TycoonEngineTests/PacingBots.swift` and `InvestorBots.swift` move into a small shipping library that the test target depends on. No tests are added; the existing suites keep calling the bots.
- `Leagues/GameSession+League.swift` (`leagueStandings`, around lines 155-172).
- `GameSession+Ghosts.swift`.
- `Leagues/LeagueDemoField.swift`, which is this idea's DEBUG version with random numbers.

**Why this is the thin spot.** The league is the product's only day-7 hook, and without CloudKit or a crowd on Game Center it settles against nobody.

**Decision.** To go up, beat the strategy on the rung above. The named strategies tell you what that is.

**Size.** M–L, about 4 days: one for the target move, one for the runner and cache, one for the table and result copy, one for tuning the roster per tier.

**How it fails.** The roster could be too soft (everyone reaches Founders in three weeks), or an InvestorBot could find an IPO on some seed. Two cheap early checks:
- Run the roster over the last eight weeks' seeds on a Mac and look at each tier's spread before building any UI.
- Time one bot-year in a release build on the phone. If 19 runs take more than about 10 s, cut the field to 9.

### 2. Keep this company
**Pitch.** When a daily, league week or season stops at its year, you can take the company home. It moves into a save slot and carries on as your own, unranked, past the horizon.

**Mechanic.**
- The result cards (`DailyCards.swift` `DailyResultCard`, the league and season cards) gain "Keep this company" once the score has been submitted, never before.
- It uses the existing slot picker ("Replace … in slot N", `TitleScreen.swift:300`). The state is copied into the slot with `mode = .custom` (`GameState.mode` is a `var`, `GameState.swift:1006`).
  - `.custom` is unranked, and `DailyHorizonGate` and `LeagueGate` only act on their own modes, so the horizon lifts.
  - `UnlockGate` starts applying. Most year-one companies are past chapter 2, so an unentitled player meets the paywall on a company they've already played for half an hour. That path gets its own first line: "The year is scored. Keep going with <Company>."
- A company can be kept once per daily day, league week or season. The shared store stays as the record, and the kept copy is a fork.
- A kept company that later ends records into the legacy ledger. That makes the Hall of Fame and Dynasty see a company from the short modes for the first time.

**Hooks.** `Daily/DailyCards.swift`, `DailyStores.swift`, `GameSession+Daily.swift`, `Leagues/LeagueCards.swift`, `Seasons/SeasonCards.swift`, the slot save APIs, and the copy in `Store/PaywallSheet.swift`. No engine change.

**Why this is the thin spot.** The paywall sells chapter names (`PaywallSheet.swift:119`) and is only ever met in the first standard run. A player who lives in the dailies never meets it, and the company they loved hits a wall at day 365.

**Decision.** Take it home, at the cost of one of three slots (maybe the company you're running) and ranking forever, or let it stand as a score.

**Size.** S–M, 2 days.

**How it fails.** If most year-one dailies end broke, nobody keeps one. Cheap check: count how many of the owner's own daily ledger entries ended in the black. Under one in three and the button is decoration.

### 3. The name carries
**Pitch.** The next founder inherits more than a face.
- A child carries the family name: its audience, its reputation with the police, and the studio that hated their parent.
- You again carry all of it.
- The longest-serving employee starts clean and unknown.

**Mechanic.**
- `LegacyRun` gains optional `followers`, `notoriety`, `openRecord` (untried record entries) and `nemesis` (name, appearance seed, focus topics, strength). They decode nil, following the `willHeir` pattern.
- Child: followers ×0.25 and notoriety ×0.5. The nemesis founds into the new world with its grudge at the nemesis threshold, which puts W3's operations against you in play early.
- Founder again: followers ×0.5, notoriety ×1.0, and the open record carries, so the discovery sweep keeps running. With `notorietyDecayPerWeek` at 1.0, a 40-point name is about 40 weeks of heat, and `notorietyDiscoveryFactor` is 1.2.
- Employee: nothing carries.
- The Dynasty room and the founder page show what each successor carries: "3,100 followers · notoriety 20 · Quill Systems".
- These are applied as deltas where lineage lands in `newGame` (`GameState.swift:1263`), after every draw. The nemesis is founded through the ghost path (`GhostScript` → rival, no rolls). With no lineage the output is byte-identical.

**Hooks.** `Legacy.swift` (`LegacyRun`, `record`), `Crime.swift:653,657`, `Fame.swift:305`, `Interactions.swift:513`, `Rival.swift:228`, `Dynasty/Successors.swift`, `DynastySheet.swift`.

**Why this is the thin spot.** Today the successor choice is a stat spread plus the household traits a child grows. A second run in a dynasty is the first run with a different face.

**Decision.** Audience, heat and an enemy (the child); everything (you again); or a clean nobody (the employee).

**Size.** M, 3 days.

**How it fails.** The child dominates, if a quarter of a famous parent's audience outweighs half their heat. Cheap check: on `-sampleLedger`, work out each successor's first-year hype and discovery odds from the balance by hand. If the child wins both, raise notoriety's share.

### 4. The vow
**Pitch.** A failed company's post-mortem names what killed it. Make one line a vow, and the next company carries it as a public promise. Keep it and the press says so; break it and they say that too.

**Mechanic.**
- Each `PostMortem.Line` (ids `never-shipped`, `burn`, `hired-early`, `salary`, `rent`, which are stable and test-pinned) gets a "Make it a vow" button. Each becomes a threshold:
  - ship by day 80, which sits inside the 45–110-day first-ship band, so roughly half of normal play misses it;
  - no second hire before the first sale;
  - salary at most 1.5× the team median for the first year;
  - rent at most 35% of burn for the first year;
  - no quarter spending more than twice income after day 90.
- It is stored as `GameState.vow: FounderVow?`, decoding nil, and shown as an extra row with a deadline on the chapter card.
- It is not enforced. The hire button still works.
- Keeping it: +10 reputation and a Newspaper lead. Breaking it: −5 reputation, the paper prints it, and if that company fails, the same line leads its post-mortem. The run stays ranked.

**Hooks.** `Screens/Endings/PostMortem.swift`, `FounderBiographyView.swift` (`postMortemCard`), `NewGameFlow`'s `NewGameOptions`, a weekly check in the progression tick, `GoalsCard`, `Story/NewspaperComposer.swift`.

**Why this is the thin spot.** The post-mortem is information the player can't act on: it appears after the run, and "Start a new company" drops it.

**Decision.** At every tempting moment, the thing you need now against the promise you made.

**Size.** M, 2–3 days.

**How it fails.** The reward is too small to bend a choice. Cheap check: compare +10 reputation with what one chapter-1 goal pays in `Goals.json`. If a vow is worth less than one goal, nobody bends for it.

### 5. Remaster (a fourth heirloom)
**Pitch.** Carry a Hall of Fame product into the new company and rebuild it. It's half-built on day 0, and the press will judge it against the original.

**Mechanic.**
- A new `Heirloom.ip(HallEntry)`. The entry already carries its seed, type, topic and score (`Legacy.swift:569`).
- The new company starts with "<Name> Remastered" in development at 40% of the design and code phases.
- That product's review expectation rises by (original − 70) / 2, so a 91 original adds 10.
- It spends the company's one heirloom and makes the run unranked, as heirlooms already do.
- `HallOfFameSheet` gains a "Remaster" button that opens the new-game flow with it preselected.

**Hooks.** `Heirloom` and `applyHeirloom` (`Legacy.swift:457,516`), the review expectation in `Reviews.swift`, `HeirloomsStep.swift`, `Awards/HallOfFameSheet.swift`. One caveat: an older app reading a save that carries the new case will report it as a future format.

**Why this is the thin spot.** The Hall is a list nobody acts on. The iteration-5 PM cut it for exactly that reason, and it shipped in iteration 8 anyway.

**Decision.** A head start (roughly half of a first build's 45–110 days) against a raised bar and the loss of the other heirloom choices.

**Size.** M, 2 days.

**How it fails.** Being unranked isn't a cost most players feel, so this is pure upside unless the bar bites. Cheap check: on a garage fixture, compare the remaster's `ShipForecast` at the raised bar with a fresh first product's. If the remaster forecasts at least as well, raise the bar. This is the weakest of the five.

---

## B) Five improvements to existing features, ranked

### 1. Coach tips point at the systems nobody finds
- **Today.** `TipStrip.swift:25-68` holds six chapter-1 tips, and `GameSession+Tutorial.swift:134` dismisses all six when the tour ends. The weekly report's "Do this next" reads only the top active goal (`WeeklyReport.swift:103-105`).
- **What's weak.** The iteration 9–11 systems sleep until their screen is opened (`Assets.swift:8`; N5 waits for the Team tab; W1 waits for the finances). Their cards sit at the bottom of a Life tab of about 25 cards (`LifeScreen.swift:134-152`). A player can finish a 10-hour run without learning there's a feed, a casino or a doctor.
- **Change.** Key about ten tips to state triggers instead of goals:
  - first rival launch into a topic you hold → rival profile;
  - runway under 4 weeks → finances, which is also the dirty-money gate;
  - first term sheet → pitch room;
  - first hospital stay → the doctor;
  - affection warning → phone;
  - first colleague complaint → the secrets card.

  Leave the tour's dismissal on the chapter-1 six only. Tips are routes and write no state, so fixtures are untouched. Opening the screen from a tip is still the player's own action.
- **Size.** S, 1.5 days.

### 2. The three shared-seed modes stop asking one question
- **Today.** Daily, season and league all score founder net worth at day 365. That number includes the crypto wallet and casino winnings (`Investors.swift:504-512`).
- **What's weak.** They're three front-door rows of the same game. The ranked score also rewards a bet on day 360.
- **Change.**
  - Daily keeps founder net worth.
  - League scores `companyValuation`, which the wallet can't touch, so the weekly table rewards building the company.
  - Season scores net worth × LifeScore / 100, so the twist changes the world and the score asks what it cost you.

  Board ids and the money format stay. Switch at a week or season boundary so no open board changes meaning mid-period. All of this is app-side reads of numbers that already exist.
- **Size.** S–M, 2 days.

### 3. The ending points at the next run
- **Today.**
  - `FounderBiographyView.swift` (`playAgainButton`) ends with Keep running it / Try that year again / Start a new company, and the last goes to the front door.
  - Successors, the heirloom this company just left, and a newly opened stake are all two pages deep in the new-game flow.
  - `HeirloomsStep.swift`'s banner still says "of 6 endings", but there are seven (`walkedAway`, `GameState.swift:81`).
  - `Unlocks.earnedLooks` has six faces, so Walked away earns none.
- **Change.** Add a "What comes next" card built from the ledger after the ending is recorded. It holds up to three rows, each opening `NewGameFlow` pre-filled:
  - "Found the next one as Ada (Reads as: Speedster)";
  - "Priya is in the ledger — carry her";
  - "Stake 3 is open: Short patience".

  Also derive the ending count from the enum and add the seventh look.
- **Size.** S–M, 2 days.

### 4. Scenarios teach what takes ten hours to reach
- **Today.** The ten scenarios in `Scenarios/Scenario.swift:43-143` were authored in iteration 8, and none starts in a darker-life state. Reaching a hearing takes a crime, a discovery sweep and 4–8 weeks.
- **Change.** Add three scenarios on the existing day-one-change machinery, using the lanes' debug setups (`-autoCase`, `-autoDirtyMoney`, `-autoInside`):
  - **The hearing:** a case five weeks out and $40,000 in the bank. Settle or fight.
  - **The shark:** $30,000 at a weekly vig with six weeks of runway.
  - **Out on parole:** the founder has 12 weeks to undo a quarter the caretaker ran down.

  The featured rotation goes from 10 weeks to 13. Scenarios are unranked, so no board is affected.
- **Size.** S–M, 2 days.

### 5. VoiceOver can receive a clue
- **Today.** Iteration 7 promised VoiceOver reaches every fixture. The new drawn rooms carry almost no labels:

  | File or folder | Accessibility modifiers | Lines |
  |---|---|---|
  | `InsideCellView.swift` | 2 | — |
  | `CrimeBenchView.swift` | 2 | — |
  | Crime | 7 | 1,533 |
  | Inside | 9 | 1,514 |

  N5's "prop in the room" clues are drawn over the office scene, not by it (iteration-11 "Not done"), so a VoiceOver player misses one of the four clue channels.
- **Change.** Put each clue prop into the office scene's existing hit regions with a label and a journal line. Label the cell, the bench, the casino tables and the car. Do one manual Accessibility Inspector pass per room at AX5; no new tests.
- **Size.** S–M, 2 days.

---

## Cut list
- **More notifications (league closing, season ending).** The desk's button promises "One notification a day … Nothing else, ever." (`DeskReminder.swift`). Breaking a printed promise for a day-7 nudge is a bad trade.
- **Desk streaks that pay in-run.** Pure upside, and it puts wall-clock days into a deterministic run.
- **A career or stats screen.** The Dynasty room and the Hall already draw the ledger; another list is one nobody manages.
- **A cosmetic store or season pass.** The paywall says "nothing else in the game is for sale" (`PaywallSheet.swift:123`).
- **iPad landscape or two columns.** Large, creates no decision, and the column was a deliberate iteration-7 choice.
- **"Stop here" bookmarks.** The weekly report already is the stopping point; no decision.
- **Carrying the crime record into every company.** Pure downside that nobody would pick. It's only worth building as the price of the child's audience (feature 3).
- **A house field made of random scores** (what `LeagueDemoField` does in DEBUG). Nobody earned those numbers, and tuning the band is guessing.
- **Universal links for seed codes.** Needs a hosted domain for a small payoff; typed codes and the custom scheme already work.
- **Latin-1 pixel font and localization.** Real work, but already scoped as a wave-2 production lane, not a product decision.

If you take one feature, take **the house field**. If you take two, add **Keep this company**: it's the only item here that makes the purchase meet players where they already are.
