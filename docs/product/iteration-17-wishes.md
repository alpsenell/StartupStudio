# Iteration 17 — the wish list: the direction for seven lanes

*13 September 2026. Three Fable PM lenses read `iteration-17` @ 8051373
(= main, build 426 on the phone): the genre's table stakes
(`iteration-17-pm/genre.md`), the player's first ten hours (`player.md`),
and wave two re-ranked plus the joins between the seventeen new verbs
(`systems.md`); the brief is `brief.md`. This file is the ranking, the
seven lanes, the ownership and the working method. Nothing here is
built yet.*

## What the three lenses agreed on

- **The wish a forum would post is "why did nothing happen when I…"**
  Options granted then the company sold: nothing pays them. Money lent
  then the company sold: the loan lowers the price and is never repaid.
  A holiday over launch day: byte-identical to being at the desk. Firing
  your spouse: the marriage does not notice. Each is a half-day join.
- **The build has one answer: finish it.** No shelve, no scrap, no
  price picked at ship (63 of 63 fixture launches shipped at standard),
  no publisher, no pre-orders, no expo; the studio fixture auto-run for
  twelve weeks offered about one question a week against two and a half
  dismissals and shipped nothing.
- **People are never away and firing is free.** `train` is an instant
  tap, nobody on payroll takes a holiday, plain `fire` costs nothing and
  strictly dominates with-cause, and S2's "Let 6 people go first" points
  at six free taps with no sheet.
- **One-answer defaults the lanes measured** now have named fixes: the
  sign loses to unsolicited offers (cap them at the ask), running a v2
  beside its parent beats replacing (the declared v2 cannibalises), the
  mentor always wins (print the lesson's price and let the student ask
  for the promotion), the suburbs are cheapest and near (re-cut the far
  pairs to the drawn map).

## Ranking

Ranked by play added per engineer-day, grouped into lanes by the files
they touch. Sizes are the PM estimates for one Opus engineer.

| # | Feature | Lens id | Size | Lane |
|---|---|---|---|---|
| 1 | The exit reads the options and repays the director: vested paid from the price, unvested accelerate-or-lapse on the buyout sheet, the loan repaid first at every exit | systems J1+J2 | S–M 1.5d | T1 |
| 2 | Severance or cause, and the layoff sheet (the target of the move-down refusal) | systems W1 / company C8 | S 1.5d | T3 |
| 3 | Shelve a build (the drawer: slot frees, hype gone, announced date slips, progress decays) and scrap it (bank half into the codebase) | systems O3 + player P2 | M 2d | T2 |
| 4 | The declared v2 cannibalises its parent, which prices "run both" | systems J4 | S 1d | T2 |
| 5 | Name the price at ship: the ship dialog picks the tier with the forecast's caption | player P1 | S 0.75d | T2 |
| 6 | The publishing deal: a rival advances a build for half of it forever and a date | genre G1 | M 3d | T4 |
| 7 | The sign caps the market: no unsolicited offer beats the ask while listed, the windfall printed | systems O1 | S 0.5d | T4 |
| 8 | The expo: a dated annual show of one build — hype and a name against the copycat's head start and a crash on open bugs | genre G2 | M 2.5d | T5 |
| 9 | Pre-orders on an announced date: hype becomes cash now, a slip refunds | genre G6 / player P4 | S–M 1.5d | T5 |
| 10 | Away from the desk: a two-week course beside the instant workshop, holidays as a doors-gated staff policy | genre G3 | M 2d | T6 |
| 11 | The launch reads the founder away: no party, hype ×0.85, the weekend card prints the clash | systems J3 | S 0.75d | T6 |
| 12 | The exclusive: one outlet's verdict on launch day; outlets keep a standing with the studio | player P3 | S–M 1.5d | T7 |
| 13 | A stake in a rival: 5–25% for dividends, their roadmap, a cheaper acquisition later | genre G4 | S–M 2d | T7 |
| 14 | The lesson's price: the seating preview prints fair pay and the recruiters' list; a taught junior who crosses a rung asks for the promotion | systems J5 | S 0.75d | T3 |
| 15 | Home districts read the map: far pairs re-cut, tonight's room in your district is free, the school on the corner | systems J6 | S 1d | T6 |
| 16 | Firing the partner is a fight: −25 affection, −40 with cause and *Pack a bag* next morning | systems J7 | S 0.5d | T1 |
| 17 | The dividend reaches the holders' desks: a holder's line is morale and loyalty that week | systems J8 | S 0.5d | T1 |

**Wave three (not this round):** contractors (genre G5 / player P5), the
custom build (P6), cross-promotion (P7), the launch share card (P8), the
studio mark (P9), license the tech (G7), the ceremony pays (G8), the
street (A7), own the home (F8, priced at 150 weeks of the district's
rent), the all-nighter (A5, a studio verb), draft the chapter (A6),
research forks (C7, a content lane), announce a number (A18), the beta
(P18), the counter-launch (P20). Cut again with reasons in the lens
reports: eras, remote company, rival names through the generator
(re-pin round), the city pre-warm, the industry table, custom scenarios.

## The rule every lane keeps

Rules 1–12 of `iteration-12-joins.md`, 13–15 of `iteration-13-lanes.md`,
17–19 of `iteration-14-ux.md` and 20–24 of `iteration-15-verbs.md` apply
unchanged. The ones that bite this round:

- **Identity at the default.** No bot sends a new action; a new branch
  on an old action is gated on a new argument with a default (`ship`,
  `fire`, `startProduct`, `acceptBuyout` keep their old shape and
  bytes). A staff question that only a person should get is gated on
  `doors.armed` (K1's rescue and K7's letter are the precedent). New
  fields decode-if-present and encode when non-default. The four engine
  fixtures and three release fixtures do not move; pacing and identity
  suites pass unchanged. The one item that can touch the default path
  is the launch-while-away factor (T6): measure first whether any pacing
  seed ships inside a vacation week; if one does, gate on `doors.armed`.
- **Measure the PM's "how it fails" check first** and put the number in
  the report before tuning; the spec's remedy applies when the check
  fails.
- **Two answers, both printed** on the button, with the price now and
  what it closes later. **One home per thing.** **No new tests.**
  **Pixel, not SF.** **Hide, never remove.**
- **Dry-run the merge** against every other `t*` branch with commits and
  against `iteration-17`; list every CONFLICT with a resolution in the
  report. Report to `iteration-17-lanes/t<n>.md` with screenshots under
  `t<n>/`; five-line final message.

## The scaffold

Committed at `scaffold-17` on `iteration-17`: marker regions
`// MARK: T1 (…)` / `// MARK: end T1` … `T7` before every
`// MARK: end of Iteration 15` line in the ten shared files (`GameAction`,
`Reducer` ×2, `GameState` ×5, `BalanceConfig`, `AppRouter` ×2,
`DebugLaunch` ×2, `BusinessScreen`, `LifeScreen` ×4, `TeamScreen`,
`EventCopy`), this document and the three PM reports. No engine stubs.

## The lanes

| Lane | Branch | Sim | Builds | Spec | Size |
|---|---|---|---|---|---|
| T1 | `t1-exits` | `ws-l1` | The exit reads the options and repays the director; firing the partner is a fight; the dividend reaches the holders' desks | `systems.md` §1, J7 (rank 12), J8 (rank 13) | M |
| T2 | `t2-build` | `ws-l2` | Shelve (the drawer, with un-shelve, decay and the announce slip) and scrap (bank half into the codebase) as two answers on the same card; the declared v2 cannibalises its parent; name the price at ship | `systems.md` §7 + `player.md` §2, `systems.md` §3, `player.md` §1 | M–L |
| T3 | `t3-people` | `ws-l3` | Severance or cause with the layoff sheet as the target of S2's refusal; the lesson's price | `systems.md` §2, §6 | M |
| T4 | `t4-publisher` | `ws-l4` | The publishing deal; the sign caps the market | `genre.md` §1, `systems.md` §5 | M–L |
| T5 | `t5-expo` | `ws-l5` | The expo; pre-orders on an announced date (one-time products; subscriptions a follow-up) | `genre.md` §2, §6 (and `player.md` §4 for the "overpromised" review line) | M–L |
| T6 | `t6-away` | `ws-l6` | Away from the desk (courses, the holidays policy); the launch reads the founder away; home districts read the map | `genre.md` §3, `systems.md` §4, §8 | M–L |
| T7 | `t7-press` | `ws-l7` | The exclusive (press standing); a stake in a rival | `player.md` §3, `genre.md` §4 | M |

Where this table and a PM section disagree on a number, the PM section
wins; where a PM section and the repo disagree on a fact, the repo wins
and the report says so. Where two lens specs describe one feature (the
shelve, the pre-orders) the lane builds one feature that keeps both
lenses' two answers and says which numbers it chose.

## File ownership

| Lane | Owns |
|---|---|
| T1 | `Systems/RivalSystem.swift` `acceptBuyout`'s tail (a marked pair inside T4's file), `Systems/InvestorSystem.swift` (`fileIPO`, `acceptBuyoutEarnOut`), `Ladder.swift` (the exit split), `FounderMoney.swift` (the holders' morale line), `FounderStanding.swift`, `Systems/RelationshipSystem.swift` + `Systems/EmployeeSystem.swift` `fire` guard on `partnerEmployeeID` (one marked pair in T3's function), `Components/DecisionSheet.swift` (the buyout sheet's row), `Screens/Endings/PostMortem.swift`, `Balance/BalanceConfig+Exits.swift` |
| T2 | `Product.swift`, `Systems/ProductSystem.swift` and `+Lifecycle.swift` (`ship` gains a defaulted tier, `startProduct` a defaulted `parentID`, `postWeeklySales` the parent decay, shelve/scrap/unshelve, the weekly decay; **keep `ship`'s review loop and `postWeeklySales`'s shape — T4, T5, T6 and T7 each add one marked pair there**), `Lifecycle.swift`, `Systems/CodebaseSystem.swift` (the bank), `Screens/Products/**` except `Announce/`, a new `Screens/Products/ShipSheet.swift`, `Components/LiveOps.swift`, `Screens/HQ/NowCard.swift` (a shelved build is not the Now build), `Screens/HQ/OfficeDowngradeRow.swift` (the refusal names the verb — T3 adds its layoff-sheet link in its own pair), `Balance/BalanceConfig+Build.swift` |
| T3 | `Systems/EmployeeSystem.swift` (`fire` gains the notice behind a defaulted argument; **keep the output/crowding/morale-target functions' shapes — T6 adds its away reads there**), `Systems/InteractionSystem.swift` (`fireWithCause`), `Systems/CrimeSystem.swift` (the claim), `Seating.swift` (the preview lines), `Systems/SeatingSystem.swift` (the student's promotion flag), `Systems/SocialSystem.swift` (the gate), `Screens/Team/**` (**T6 adds an away chip and the course row in its own pairs**), `Screens/HQ/SeatingViews.swift`, `Balance/BalanceConfig+Severance.swift` |
| T4 | `Rival.swift`, `Systems/RivalSystem.swift` (the publisher's focus topic, `buyoutCheck`'s cap line; **T1's `acceptBuyout` tail and T7's stake are their own pairs**), `Deals.swift`, `Screens/Business/Deals/DealViews.swift`, `Screens/Business/RivalProfileScreen.swift` (**T7 adds its stake row in its own pair**), `Screens/Products/Announce/**` only for the financing row's placement (**T5 owns the announce sheet's rows; coordinate: the publisher row is one marked pair there**), `Systems/AnnounceSystem.swift` clawback (one marked pair in T5's file), `Screens/Story/NewspaperComposer.swift` (a marked block; T5 and T7 add their own), `Balance/BalanceConfig+Publisher.swift` |
| T5 | `Systems/AnnounceSystem.swift` (the refunds beside the slip), `Announce.swift`, `Systems/MarketingSystem.swift` (the expo hype), `Queue.swift` (+`.expo`), `ShipForecast.swift` (a units read), a new `Screens/Business/ExpoSheet.swift`, `Screens/Products/Announce/**`, `Balance/BalanceConfig+Expo.swift`; the copycat-window read of `expoDay` beside `announcedDay` in `RivalSystem` is one marked pair in T4's file; the delivered pre-orders on ship day one marked pair in T2's `ship`; `Product.swift` fields `expoDay` / `preorders` in T5's own pair |
| T6 | `Employee.swift` (`awayUntilDay`, `awayReason`), `ShipETA.swift`, `StaffEvents.json` (appended, `holiday_` prefix, doors-gated), `Screens/Team/PoliciesCard.swift`, `Systems/LifeSystem.swift` (the evening), `Screens/Life/WeekendCard.swift` and the sabbatical sheet (the clash line), `HomeRooms.swift`, `Systems/NetworkingSystem.swift` (the room's free evening), `Systems/ChildhoodSystem.swift` (the school bond), `Screens/Life/HomeMoveSheet.swift`, `Screens/City/DistrictDetailPanel.swift` (the nearby line), `Balance.json` `home.farPairs` (data), `Balance/BalanceConfig+Away.swift`; one marked pair each in T3's `EmployeeSystem` (away excluded from output, crowding, span; morale target), T2's `ship` (the away hype factor), `Systems/AssetsSystem.swift` (K7's vice pair counts the new event) |
| T7 | `Components/LaunchDaySheet.swift` and the review reveal (**T5 adds the delivered line, T6 the "you were away" sentence, in their own pairs**), `Company` in `GameState.swift` (`pressStanding`), `Product.swift` `exclusiveOutlet` (own pair), the standing offset in T2's `ship` review loop (one marked pair; the loop's draws unchanged in count and order), `Screens/WarRoom/**`, `Screens/Business/RivalsView.swift` (the holdings row), `Screens/Business/FinancesView.swift` (the asset line), the stake in `RivalSystem` (own pairs in T4's file: `buyRivalStake`, `sellRivalStake`, the weekly dividend, the poach weight, `acquireRival`'s price, the fold), `Systems/RivalSystem+RivalMarket.swift` (the price-war refusal), `Balance/BalanceConfig+Press.swift` |

Every lane: its own `// MARK: T<n>` regions in the scaffolded files, its
own `Balance.json` keys appended at the end, its own `EventCopy` block,
its own `DebugLaunch` flags (`-autoRoute t<n>-…`). A change you need
outside your markers in a file another lane owns is one marked pair at
the point of use if this table names it, otherwise a follow-up in your
report.

## Working method

Worktree per lane at
`/Users/alp/Desktop/Personal-Projects/StartupStudio-lanes/t<n>` (created
by the coordinator on branch `t<n>-…` from `scaffold-17`), simulator
`ws-l<n>` (boot it if it is shut down). `make gen` first; `make build
SIM=ws-l<n>`; `swift test` in each package (read the `✔ Test run with N
tests` line: engine 943, content 52, save 34, PixelKit 336); `make
apptest SIM=ws-l<n>` last, on your own simulator, and read `Executed 385
tests, with 0 failures` — a missing Executed line is a failure. `git
checkout -- App/Config/Version.xcconfig` before every commit. Small
commits on your branch; no merge, no push, no test added.

Merge order (the owner of the hottest shared file lands first):
T2 → T4 → T3 → T5 → T7 → T6 → T1. Then one `make strings`, the round
record in `iteration-17-features.md`, fast-forward main; push and the
phone build on the owner's word.
