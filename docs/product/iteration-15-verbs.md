# Iteration 15 — verbs: the missing playable features, and the direction for seven lanes

*10 September 2026. Three Fable PM lenses read `iteration-15` @ 6660ccc
(= main, iteration 14, build 366 on the phone) and answered one question:
which playable features are missing, major or minor. Their full reports,
twenty candidates each with cut lists, are in `iteration-15-pm/`
(`company.md`, `life.md`, `meta.md`; the brief is `brief.md`). This file
is the ranking, the seven lanes, the ownership and the working method.
Nothing here is built yet.*

## What the three lenses agreed on

The game is not short of verbs — 163 `GameAction` cases, about 45 life
verb families, roughly 1,200 buttons on the family fixture competing for
three evenings a week. It is short of **decisions with two defensible
answers**, and short of **pipes between halves that already exist**:

- **The company week collapses as the office grows.** Garage: three
  two-sided choices a week. Studio: about seven. Campus: "ship ×5, hire to
  the cap" — all six investor personas approached, contracts at $2–7k
  against a $77k burn, $644k of cash with nothing to buy, a $17k weekly
  loss with no sink but payroll. Of 63 released fixture products, none was
  ever re-priced, patched or retired. `promote` is a raise with a hat;
  the Brooks crowding factor reaches ×0.34 and is printed nowhere.
- **The wallet is a rounding error.** Wallets of $2–18k against company
  cash of $90–644k, with the salary and the secured loan as the only
  pipes; the automatic rescue salary is exempt from founder-pay pressure,
  so a penthouse is quietly paid for by the company. The partner is a
  meter with a name; the ex is a string holding up to 12 points of the
  company that `buyBackRound` cannot reach; the home has no location
  while the city's rent multipliers sit unused by anything but the
  office; the diary never meets the announce sheet.
- **Every chosen ending is an exit**, the epilogue is the sim with three
  doors shut, `lineage` is stored and read by nothing. A tap on the office
  opens a sheet; a tap on the home does nothing (`HomeCard` passes no
  `onTapRegion` although 23 hit regions are named).

## Ranking

Ranked by play added per engineer-day, then grouped into lanes by the
files they touch. Sizes are the PM estimates for one Opus engineer.

| # | Feature | Lens id | Size | Lane |
|---|---|---|---|---|
| 1 | Sunset and v2: retire a product; ship a successor that carries 40% of its book | company C1 | M 3d | K2 |
| 2 | Skin in the game: the director's loan and the dividend (pro-rata, board-read, streak-read) | life F1 + company C2 | M 3d | K1 |
| 3 | Leads run the room: a promoted lead halves crowding on one build; the factor is printed | company C3 | M 3d | K3 |
| 4 | Hand over the keys: name a successor, keep a silent stake, play on as them | meta A1 | L 4d | K5 |
| 5 | The for-sale sign: name your price; rivals bid on a clock while the office bleeds | meta A2 | M 2.5d | K4 |
| 6 | Hire your partner: affection reads the office; a breakup is a resignation | life F2 | M 2.5d | K7 |
| 7 | Options instead of pay: 1–2% for a pay cut, vesting, poachers must buy it | company C4 | S–M 2d | K3 |
| 8 | Where you live: a home district; the commute is paid in evenings; relocation reads it | life F3 | S–M 2d | K6 |
| 9 | Sell up before the receiver: `.soldUp` as a chosen ending against the 21-day gamble | meta A4 | S–M 1.75d | K4 |
| 10 | Buy them with paper: acquire a rival for equity; their founder takes a seat | company C5 | S 1.5d | K4 |
| 11 | A price change is news: a rise churns, a cut is a sale, both make the paper | company C6 | S 1.5d | K2 |
| 12 | The ex on the cap table: buy the slice back or let it ride; the ex is a contact | life F4 | S–M 1.5d | K7 |
| 13 | The rooms answer: home fixtures open their verbs; amenities take a paid break | meta A8 | S 1.25d | K6 |
| 14 | The rescue is a choice: the bailout salary becomes a queue question the board reads | life F9 | S 1d | K1 |
| 15 | Take them with you: a family holiday beside the solo one, with the solo cost printed | life F6 | S 1d | K6 |
| 16 | The diary reads the roadmap: announce and ship days warn of birthdays; keep the date | life F5 | S 0.75d | K7 |
| 17 | The doctor's letter: a dated warning at health 40 with the days to the hospital | life F7 | S 0.5d | K7 |

**Wave two (not this round, in order):** A6 draft the chapter (keep four
of six goals), A5 the all-nighter, A3 seating (desk placement that reads
traits and the secret threads), A7 the street (an earnings call in the IPO
epilogue), C7 research forks, C8 severance or cause, C9 remote company,
F8 own the home (after K1 makes wallets six figures). Two stale facts to
fix in passing: `HeirloomsStep` says "of 6 endings" (seven exist) and
`Unlocks.earnedLooks` has no look for *Walked away*.

## The rule every lane keeps

Rules 1–12 of `iteration-12-joins.md` and 13–15 of `iteration-13-lanes.md`
apply unchanged (identity at the default, no new `rng`/`worldRNG` draws on
the default path, **no new tests**, read the Executed line, old saves
load, pixel not SF, the consequence on the button, lane-prefixed types,
one defaulted balance block per lane, insert only between your markers,
dark not cruel, events are content, a bought-nothing run is
byte-identical, the shop never nags, a re-recorded snapshot is a re-pin).
Rules 17–19 of `iteration-14-ux.md` too (hide never remove; remember
don't reset; the two pinned facts). Plus, this round:

20. **No bot sends a new action.** Every feature is a new `GameAction`
    case (or a new branch of an old one gated on a new field), sent only
    from the app. New `GameState` fields are `decodeIfPresent` with a
    default and are encoded only when non-default. The four engine
    fixtures and the three release fixtures do not move; the pacing and
    identity suites pass unchanged. If your feature *must* change a
    default-path number, stop and write it up as a follow-up instead.
21. **Two answers, both printed.** A new verb ships with its price and its
    alternative on the sheet: what it costs now, what it closes later
    (*Still yours* closes on the first equity grant; a listed company
    bleeds morale; a far commute is −1 evening of 3). The PM's "how it
    fails" check is your first measurement, not your last.
22. **One home per thing.** A verb lives on the screen that owns its
    subject (money on the money sheet, a product's price on its page, a
    person's options on their manage sheet). No new tab, no new root card
    on Life or HQ; a new room is a row that unfolds, as V1 built them.
23. **Write the report to a file.** `iteration-15-lanes/k<n>.md` with
    measurements, re-pins with reasons, deviations and follow-ups, and
    before/after screenshots under `iteration-15-lanes/k<n>/`. Your final
    message to the coordinator is five lines. Long messages truncate.
24. **Dry-run the merge.** Before you report done, fetch the other lane
    branches (`git fetch` is not needed — they are local; `git branch
    --list 'k*'`) and run `git merge-tree --write-tree <yours> <theirs>`
    against each one that exists; list every `CONFLICT` line in your
    report with the one-line resolution you propose.

## The scaffold

Committed at `scaffold-15` on `iteration-15`: marker regions
`// MARK: K1 (…)` / `// MARK: end K1` … `K7` before every
`// MARK: end of Iteration 14` line in `GameAction`, `Reducer` (systems
and handlers), `GameState` (`GameEvent` and the slot blocks),
`BalanceConfig`, `AppRouter`, `DebugLaunch`, `EventCopy`, `LifeScreen`,
`TeamScreen`, `BusinessScreen`; this document; the three PM reports. No
engine stubs: each lane's types are its own.

## The lanes

| Lane | Branch | Sim | Builds | Spec | Size |
|---|---|---|---|---|---|
| K1 | `k1-money` | `ws-l1` | The director's loan; the dividend (pro-rata to the cap table, printed line by line, founder gets `equityRemaining`%, once per 91 days, runway floor, board pressure unless last quarter profitable, counts against the profitable-quarter streak, counts as founder pay for 13 weeks); the rescue as a queue question with the exemption removed | life F1 §1, company C2 §2, life F9 §5 | M |
| K2 | `k2-lifecycle` | `ws-l2` | Sunset a product; ship a successor that replaces it and carries the book; a price change is news (rise churns, cut is a quarterly sale, 28-day cooldown, storefront and paper print both) | company C1 §1, C6 §6 | M–L |
| K3 | `k3-ladder` | `ws-l3` | Leads run the room (promoted leads only, span 6, idle-lead morale target, two leads collide, crew and factor printed on every build card and the Now estimate); options instead of pay (1–2%, pay cut, cliff and vest, poach keeps vested, pool cap, the trade printed in dollars, a Team row on the cap table) | company C3 §3, C4 §4 | M–L |
| K4 | `k4-deals` | `ws-l4` | The for-sale sign (ask 0.8–1.6×, bids on the existing `pendingBuyout` path, morale/poach/hype/board bleed, the paper leads with it); sell up before the receiver (from the warning and the money sheet, distress price falls weekly, bankruptcy's ledger people carry at rapport −20); buy them with paper (equity out capped at 25 and `equityRemaining − 20`, their founder as a seated `RaisedRound` and a contact) | meta A2 §2, A4 §4, company C5 §5 | M–L |
| K5 | `k5-keys` | `ws-l5` | Hand over the keys: beside *Walk away*, hand the company to an employee who passes the caretaker gate, keep 10/25/50% as a silent emeritus round, the successor becomes the founder with a fresh life and the run becomes `.custom`; the outgoing founder's `LegacyRun` records `.walkedAway` with `successorEmployeeID`; the Dynasty tree hangs the continuation; fix the two stale facts ("of 6 endings", the seventh look) | meta A1 §1 + the cut list's last bullet | L |
| K6 | `k6-home` | `ws-l6` | Where you live (five districts, rent × multiplier, far pairs cost one evening never below 1, moving costs two weeks' rent and an evening, a child memory, the office relocation sheet prints the commute, a home pin on the city map); the rooms answer (every home fixture opens its verb, the office plant/window/amenities get theirs, *Call a break* once a week with the day's build factor); the family holiday (with the solo row's affection cost finally printed) | life F3 §3, meta A8 §8, life F6 §7 | M |
| K7 | `k7-partner` | `ws-l7` | Hire your partner (skills from the partner seed, affection↔morale and affection↔pace couplings, a breakup resigns them, the settlement clause, household draw read by founder pay); the ex on the cap table (the slice and its value, buy-out at ×1.15 wallet-then-cash, the ex as a `.formerPartner` contact derived from the stored seed); the diary reads the roadmap (announce rows and the launch-day sheet warn, *Keep the date*); the doctor's letter (dated, once per 180 days, gated on `doors.armed`) | life F2 §2, F4 §4, F5 §6, F7 §8 | M–L |

The spec for each item is the PM section named; where this table and a
PM section disagree on a number, the PM section wins; where a PM section
and the repo disagree on a fact, the repo wins and your report says so.

## File ownership

| Lane | Owns |
|---|---|
| K1 | `Systems/FinanceSystem.swift`, `Economy.swift`, `FounderQueries.swift` (`founderPayExcess` — K7 adds one marked line, see below), `Systems/InvestorSystem.swift` `acceptInvestment` (repay the loan first) and the pressure line, `Systems/LifeSystem.swift` `checkEviction`, `Queue.swift` (+`QueueKind` for the rescue), `Components/MoneySheet.swift`, `Screens/Business/FinancesView.swift`, `Screens/Life/MoneyCard.swift`, `Balance/BalanceConfig+FounderMoney.swift` |
| K2 | `Product.swift`, `Systems/ProductSystem.swift` (`sunset`, `ship`, `launchMarketScale`, `setPriceTier`, `postWeeklySales`), `Systems/StandingSystem.swift` (if `liveTopicIDs` needs it), `Components/LiveOps.swift`, `Components/LaunchDaySheet.swift` (K7 adds one marked *Keep the date* row), `Screens/Products/**` (except `Announce/`), `Screens/Storefront/**`, `Screens/Story/NewspaperComposer.swift` (a marked block; K4 adds its own), `Balance/BalanceConfig+Lifecycle.swift` |
| K3 | `Employee.swift`, `Systems/EmployeeSystem.swift` (`promote`, crowding, output, morale target — K7's affection hook and K6's break are one marked line each), `Systems/SocialSystem.swift` (the promotion-demand gate), `Systems/NetworkingSystem+Alumni.swift` (unvested returns), `Networking.swift` (`EquityGrant.Reason`), `Screens/Team/**` (K7 adds a partner chip on the roster row inside a marked pair), `Screens/HQ/NowCard.swift` (the crew line), `ShipETA.swift` if needed, the cap table's Team row in `Screens/Business/InvestorsView.swift` (a marked pair; K4 and K5 add their own), `Balance/BalanceConfig+Ladder.swift` |
| K4 | `Rival.swift`, `Systems/RivalSystem.swift` (`buyoutCheck` untouched; `listingCheck`, `distressPrice`, `acquireRival` payment; K3 adds one marked line to the poach weight), `Screens/Business/RivalsView.swift`, `Screens/Business/RivalProfileScreen.swift`, the bankruptcy warning entry in `QueueBoard`/`DecisionSheet`, `Legacy.swift` `record` (the rapport haircut — K5 adds `successorEmployeeID` in its own pair), `Screens/Endings/PostMortem.swift`, `Balance/BalanceConfig+Deals.swift` |
| K5 | a new `HandOver.swift` beside `LifeScore.swift`, `Investors.swift` (the silent round; K4 mints its `RaisedRound` in `RivalSystem`, not here), `Legacy.swift` (`successorEmployeeID`), `GameSession+Legacy.swift`, `Screens/Life/LifeScore/**` (the walk-away sheet), `Screens/Endings/FounderBiographyView.swift`, `Dynasty/**`, `Screens/FrontDoor/SaveSummary+GameState.swift`, `Screens/Onboarding/HeirloomsStep.swift` and `Unlocks.swift` (the two stale facts), `RunMode.swift` if `.custom` needs a reason field |
| K6 | `Life.swift` (`homeDistrict`, `eveningsPerWeek`; K7 adds `partnerEmployeeID` in its own pair), `Systems/LifeSystem.swift` (`livingCosts`, `resolveWeekend`, the weekly rent — not `checkEviction`), `Systems/CitySystem.swift`, `City.swift`, `Systems/ChildhoodSystem.swift` (memories; K7 does not touch), `Screens/Life/HomeCard.swift`, `Screens/Life/WeekendCard.swift`, `Screens/City/**`, `PixelKit` `OfficeHitRegions.swift` and `OfficeWaypoints.swift`, `Screens/HQ/OfficeCard.swift` and `OfficeTaps.swift`, `Screens/HQ/AmenitiesSheet.swift`, `Balance/BalanceConfig+Home.swift` |
| K7 | `Systems/RelationshipSystem.swift`, `Systems/FamilyDramaSystem.swift`, `FamilyDrama.swift`, `Systems/InteractionSystem.swift` (`breakUp`), `Systems/AnnounceSystem.swift` and `Announce.swift` (`diaryClash`), `Systems/FamilyCalendar.swift`, `Screens/Life/PartnerCard.swift`, `Screens/Life/Family/**`, `Screens/Life/AddressBookSheet.swift`, `Screens/Products/Announce/**`, `LifeEvents.json` (appended, prefixed `partner_`/`diary_`/`doctor_`), `Balance/BalanceConfig+Partner.swift` |

Every lane: its own `// MARK: K<n>` regions in the scaffolded files, its
own `Balance.json` keys appended at the end, its own `EventCopy` block,
its own `DebugLaunch` flags (`-autoRoute k<n>-…`).

**Known shared spots** (open your own marker pair at the point of use;
expect a both-added merge and nothing else):

- `FounderQueries.founderPayExcess`: K1 owns the function; K7 adds one
  marked line (the partner's salary joins the household draw).
- `Systems/EmployeeSystem.swift`: K3 owns; K7 one marked line (morale
  target reads affection when `partnerEmployeeID` is set); K6 one marked
  call (`callBreak`'s morale delta).
- `Systems/ProductSystem.swift`: K2 owns; K6 one marked factor in
  `applyDailyProgress` (the break's day); K7 one marked flag on the ship
  day (the diary clash).
- `Systems/RivalSystem.swift`: K4 owns; K3 one marked line in the poach
  target weight (vested holders).
- `Systems/InvestorSystem.swift` / `Investors.swift`: K1 owns the accept
  path and `companyValuation`'s callers; K5 the silent-round shape; K4
  mints its round elsewhere. If two of you must touch `companyValuation`,
  the second one writes a follow-up, not an edit.
- `Systems/LifeSystem.swift`: K1 `checkEviction`; K6 costs and the
  weekend; K7 the health-crossing check after `checkThresholds`. Three
  functions, three pairs.
- `Screens/Business/InvestorsView.swift`, `NewspaperComposer.swift`,
  `Components/LaunchDaySheet.swift`, `Legacy.swift`, `Life.swift`: named
  above with their owner and the guests' one marked block each.
- `Balance.json` and `LifeEvents.json`: append at the end only.

## Working method

Worktree per lane at
`/Users/alp/Desktop/Personal-Projects/StartupStudio-lanes/k<n>` (created
by the coordinator on branch `k<n>-…` from `scaffold-15`), simulator
`ws-l<n>` (boot it if it is shut down: `xcrun simctl boot ws-l<n>`).
`make gen` first; `make build SIM=ws-l<n>`; package suites with
`swift test` in each package; `make apptest SIM=ws-l<n>` last, on your own
simulator, when your own build is done; `git checkout --
App/Config/Version.xcconfig` before every commit. Baselines: engine 943,
content 52, save 34, PixelKit 336, app 385 — counts must match, only PNGs
may change, and every re-pin is listed with its reason. Verify the three
release fixtures and the four engine fixtures load and that the identity
suites pass before and after. Measure the PM's "how it fails" check first
and put the number in the report. Screenshots via the debug flags you add.
Commit on your branch in small commits; no merge, no push, no test added.

Merge order (the owner of the hottest shared file lands first):
K3 → K2 → K4 → K1 → K6 → K7 → K5. Then one `make strings`, the round
record in `iteration-15-features.md`, fast-forward main; push and the
phone build on the owner's word.
