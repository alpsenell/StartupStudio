# Iteration 5 — the world answers back

*3 September 2026. Three PM lenses (company systems, people and life, the shape of a run), fifteen candidates, ten chosen. The full PM reports are in `iteration-5-pm/`.*

## The thesis

Iteration 3 gave the game systems; iteration 4 gave it a face. What all three PMs found, independently, is the same gap: **nothing in the game responds to the player, and nothing remembers.** Rivals are weather with names; investors write a cheque and watch a number; eleven staff scenes and fifty-nine life beats evaporate the day they fire; leaving the company is deletion; a bootstrapper can never reach chapter 5 and the "successful exit" is a fire sale offered to a company with nothing in it. Every feature below is an edge between things that already exist, chosen so that a player's move has an answer in the world, and an answer has a memory.

Three findings are bugs rather than gaps, and ship with their lane:

- **The phantom price war.** `RivalSystem.priceWarCheck` treats a topic the player has never entered as 100% player share, so a rival's first launch into an untouched topic reads as the player beating them and two weeks later they declare war — on a company with no products, day 15, and the clock stops for it. (WS-A)
- **The fire sale is a win.** A distress buyout (reputation < 20 or cash < $5k, from day 56) ends the run as `.acquired`, crown and all, on the same screen as the strategic premium. (WS-B)
- **Two dead perks.** Press Contacts and Veteran Crew are awarded, have balance numbers, and are read by no system. (WS-G wires them.)

## The ten

Ranked by how much they change what a run *is*. Sizes are the PMs' engineer-days; a lane is one teammate.

| # | Feature | Lane | Size | The player's sentence |
|---|---|---|---|---|
| 1 | The Category Fight | A | L | "A rival launched into my category and I had six weeks to decide whether it was worth defending — and now I can bleed a rival out by out-selling them." |
| 2 | The Incumbent | A | M | "Once I got big, a giant showed up in my best market — and stayed." |
| 3 | Two ladders | G | L | "Take the money and the next three chapters are a board's chapters; keep every share and there's an ending for that: *Still yours*." |
| 4 | Exit terms | B | M | "Cheque today or a bigger one in two quarters if I hit their number with them on my board — and selling a company with nothing in it is no longer called a win." |
| 5 | The answer becomes the policy | D | M | "I gave Priya three months' paid leave in year one, so when Marco asked in year two nobody asked me — it just came out of the account." |
| 6 | The date in the diary | E | M | "Sam's birthday is launch week. I'm on crunch, I have one evening, and I've already promised it to the coach." |
| 7 | Build It For Them | C | M | "A rival paid us to build their next app. I took the money — and shipped a competitor into my own category." |
| 8 | Buy Back the Board | B | S–M | "I bought my investors out and took the company back." |
| 9 | The boomerang | F | S–M | "Marco left for Meridian Works in March. I ran into him at demo day in September, senior now, and hired him back." |
| 10 | Origins | H | M | "Before you name the studio you choose how it starts: a garage, a co-founder who owns a third, a spin-out with a client and a non-compete, or the bank behind you and your flat behind the bank." |

### 1. The Category Fight (WS-A)

Standing (0–100 per topic, iteration 3) buys a share floor: in a contested topic the player's share cannot fall below `0.55 × standing/100`, which only exceeds today's hard floor of 0.30 above standing ~55, so early play reads exactly as now. When a rival launches into a topic where the player's standing ≥ 50 and its quality is within 15 of the player's best there, the clock stops on `.categoryChallenged` with the rival's portrait, the share now, their score against yours, and six weeks. The answers are actions the game already has — budget tier, a patch, a campaign — and the sheet routes to them; `concedeCategory` lets it go. After six weeks: held (share ≥ 0.5) → rival −8 strength, +10 standing; lost → standing −20, rival +5 and the topic joins its focus. One challenge per topic per 26 weeks. The first move: weekly, in every topic where both sides sell, the side with lower share loses 1.0 strength — out-sell a rival for six months and it folds. Fix the phantom war in the same pass (count only topics with `playerShare[topicID] != nil`).

*Neutral:* the 19 pacing gates run at `rivalCount = 0`; the investor suite runs at `rivalCount = 4`, so the bleed and challenge penalties must be measured against its 9 gates (gate the bleed on the player having a live product in the topic). *Verify:* a `DefenderBot` vs SoloSlow on 10 seeds keeps ≥ 10 more share points at week 6 and has less cash 12 weeks on; a rival out-shared 26 weeks folds on ≥ 3/10 seeds; a fresh game emits no `.priceWarStarted` in 90 days; the baseline table unchanged.

### 2. The Incumbent (WS-A, after 1)

When valuation first crosses $750k or `dominatedTopicCount ≥ 2` and no incumbent exists, the next founding is an incumbent: `.deepPockets`, strength `0.6 × valuation/4000` clamped 70–95, reputation 60–80, focus = the two topics where the player has the highest standing *and* something live, and it opens with a category challenge in the higher. It is the buyer the strategic buyout was written for. Hold ≥ 0.5 share in both its topics for 26 weeks and it retreats (`.incumbentRetreated`: +5 reputation, +15 standing in both). Acquiring *any* rival now absorbs its competing products as released player products with synthesised reviews — acquisition buys a category instead of a reputation bump. Ship behind `rivals.incumbentEnabled` (default true) and measure the investor suite with it on and off.

### 3. Two ladders (WS-G)

From chapter 3 the goal catalog carries two tracks: `funded` (today's eighteen goals, untouched) and `independent` (eighteen new: tenured staff, consecutive profitable quarters, two products live at once, own the office, be worth a million still owning all of it…). The track is `equityRemaining == 100` → independent; signing a term sheet is the one-way declaration and the term-sheet sheet says so on the button. A fifth ending, `.independent` ("Still yours"): equity 100, ≥ 8 consecutive profitable quarters, reputation ≥ 70, day ≥ 2 years; `declareIndependence` mirrors `fileIPO`. Wire the two dead perks. *Neutral:* pacing bots never take a term sheet, so they sit on the independent track — the independent goal in each chapter-3+ slot pays exactly the reputation/cash/perk of the funded goal it replaces, and the baseline table must be unchanged. `InvestorTargetsTests`' "bootstrapper reaches chapter 5 on 0 seeds" flips to "≥ 5 seeds" — that is the feature. A `GoalIndependentBot` must reach *Still yours* on 3–7 of 10 seeds inside four years.

### 4. Exit terms (WS-B)

A distress offer (`lastBuyoutWasStrategic == false`) accepted ends as `.soldUp`, not a success: post-mortem, "Quill Systems bought the name and the desks for $20,460." A strategic offer opens a three-way sheet: cash now (today), an earn-out (`acceptBuyoutEarnOut`: 60% now, up to 40% over two quarterly reviews with the acquirer seated as a 12-week-patience board on the expectation the company is currently worst at; each met review pays 20%, two misses → ousted keeping what was paid; then `.acquired` with the total; signing costs `moraleAll −8`), or decline. The acquirer's expectation is arithmetic on state, no draws.

### 5. The answer becomes the policy (WS-D)

A supportive answer to a policy-shaped staff moment (`parentalLeave`, `remoteRequest`, `sideProject`, `harassmentComplaint`, `raiseRequest`, `roleSwitch`) sets the flag the content already writes; from then on the same kind does not pause for the next person — the policy answers, the same numbers land (`.staffPolicyApplied`, a ledger line). Policies show on a *How we do things here* card on Team with the day and the person, and can be reversed (`reverseStaffPolicy`), publicly: everyone who benefited takes `moraleAll −N`, the flag flips to its inverse. The strict answer sets no policy; the sheet offers "…and make that the rule" as a third button. Second acts ride the flags: `StaffEventDef.Outcome` gains `followUpEventID`/`followUpDelayDays`, `Gate` gains `flagsAll`/`flagsNone`, scheduled through `narrative.scheduled` with `source: .staff` and `employeeID` (scaffolded); 8–10 follow-up defs in `StaffEvents.json`. *Neutral:* bots auto-resolve strict at the deadline, so no policy is ever set in a pacing run.

### 6. The date in the diary (WS-E)

Three new `EventEffect` cases — `affection(amount)`, `evening` (books one of the week's evenings; with `requires.minEveningsLeft` the option greys out with its reason when the week is spent — on crunch that is one evening), `bond(amount)` — and a family calendar: an anniversary on `stageSinceDay + 365`, each child's birthday on `bornDay + 365k`, and the follow-up a promise creates (`partner_asks_future` → 90 days later). Dated beats are scheduled, not rolled, and take the life roll's slot on the next interval day inside a 10-day window rather than adding a pause; missing one costs affection −20 and sets a flag the next beat reads (`.familyDateMissed`). ~12 `followUpOnly` life defs. `FamilyCard` gets a "next: Sam's birthday · 9 days" line; the decision sheet gets its first greyed option. *Neutral:* bots are single and childless.

### 7. Build It For Them (WS-C)

On refresh days, when a rival exists, one offer may be sponsored: "Northwind Software · Fitness · white-label", 1.8× the sheet's rate, high skill, long deadline, and it says what it is: on delivery the rival ships a Fitness product at the quality you built, and you hold Fitness at 62. Delivery appends a `RivalProduct` at `projectedQuality × 0.9`, rival +6 strength, topic joins its focus, player standing in the topic −5; a poor delivery pays 50% and −2 reputation and their product is weak — sandbagging is a real option with a real cost. `ContractOffer`/`ContractJob` gain `sponsorRivalID`, `topicID` (decode nil); the sponsored roll draws from `worldRNG` so the per-offer draw groups stay byte-identical. Knobs in the scaffolded `sponsoredContracts` balance block (`sponsorChance` 0.25, never in the first 8 weeks, one per sheet). *Neutral:* `rivalCount = 0` in the pacing suite means no sponsored offer ever rolls; the investor bots never accept contracts.

### 8. Buy Back the Board (WS-B)

Every seated round gets "Buy them out — $X": `equity% × valuation × 2.5 × (1 + boardPressure/100)`. Cash out, the round moves to `boughtOut`, `equityRemaining` rises, and its ask leaves the room because `boardExpectations` is derived from seated rounds. Cheapest when small and broke, dearest the moment you can afford it. Raises IPO proceeds by exactly `equity × valuation × 1.4`. *Neutral by construction:* no bot calls it. A `BuybackBot` shows the cost is real.

### 9. The boomerang (WS-F)

Anyone who leaves — quit, poached, fired — becomes (or re-opens as) a `Contact`: archetype from role, skills carried, `rapport = founderBond`, revealed traits, `askingSalary` = the poach offer if poached else fair pay × 1.1, plus `leftDay`/`leftReason`. They keep moving off-screen (+3 skill points a quarter); a prodigy or showman who leaves founds something after 180 days and `backThem` opens. They appear as the returning faces `startEvent` already seats; the address book reads "Left in March · was your backend dev"; recruiting is the existing `.recruit` at the new ask and `founderBond` comes back. Fired with bond under 30 → rapport 0, `.lost`. The poach sheet's copy gets a third future. *Neutral:* creating the contact draws nothing; bots never network.

### 10. Origins (WS-H)

Four founding starts on the Stakes page, applied inside `newGame` after the RNG setup as pure deltas (`FoundingOrigin`, `GameState.origin`, `origins` balance block — all scaffolded). *Garage*: today. *Co-founded*: a second person on day 0 (~40/40/40, `isCofounder`, salary $0 until the loft) who owns 30%: `equityRemaining` starts at 70. *Spin-out*: a signed 12-week contract on day 0 (~$9,000, named client, the usual penalty), reputation 15, one topic locked 52 weeks (`startProduct` refuses; the flow greys it with the date). *Mortgaged*: home tier apartment, `loanBalance` 25,000 secured against it, cash $37,000. The biography names the origin; replay keeps it. *Neutral:* `.garage` is byte-identical and every harness call is a garage. SoloSlowBot on each origin over ten seeds: no origin may win on both `firstShipDay` and `finalCash` on ≥ 9/10.

## Left for wave 2

- **Legacy — bring one thing from the last company** (meta #4). A second `SaveStore` ledger that survives `deleteAll`, and a new-game page. Strong, but it needs Origins' flow page first and a save-layer change; first in line next.
- **What they want** (people #4). One want per hire; the grievance that gives `promotionDemand` its cause. Iteration 3 cut it for early punishment; the −8/28-day version is a nudge, but it is the third change to the morale target this year and wants its own measurement.
- **They call you** (people #5). The missing `callContact` verb and contacts who come to you. Competes with the diary for the life roll's slot; sequence it after WS-E lands.
- **Bet the Tree** (systems #5). Three exclusive research forks. Smallest, and a coin flip until the sides are proven different.
- **Chapters open with a question** (meta #5). Four scripted beats; copy-heavy, and the perk wiring it carried moved into WS-G.

## Workstreams

Eight lanes, one teammate each, in git worktrees branched from the `scaffold-5` tag on `iteration-5`. Merge order, chosen so the lanes that touch `RivalSystem` land first and the ones that touch `FounderBiographyView` and `InvestorsView` land in one sequence:

**A → C → F → B → G → H → D → E**

| Lane | Features | Owns (engine) | Owns (app) | Shared seams (touch lightly) |
|---|---|---|---|---|
| A | Category Fight, Incumbent, phantom-war fix | `RivalSystem`, `Rival`, `RivalsState`, `StandingSystem`, `Market.recomputeShare`, `rivals.*` balance | `RivalsView`, `CategoryStripCard`, the challenge `DecisionPrompt` | `AppRootView.currentPrompt`, `DeskCard`, `EventCopy` |
| B | Exit terms, Buy Back the Board | `Investors`, `InvestorSystem`, `RivalSystem.acceptBuyout` (that function only), `investors.*` balance | `InvestorsView` (round row + earn-out card), buyout `DecisionPrompt` third option, biography money card | `FounderBiographyView`, `EventCopy` |
| C | Build It For Them | `Contract`, `ContractSystem`, `sponsoredContracts` balance, `RivalSystem.appendProduct` (make internal, nothing else), `StandingSystem` negative source | `ContractsView`, `ContractOutlook` | `DeskCard`, `EventCopy` |
| D | The answer becomes the policy | `Social` (`StaffEventDef`, `StaffEventChoice` if needed), `SocialSystem`, `NarrativeSystem` `.staff` arms, `StaffEvents.json`, `staff.*` balance | `EmployeeManageSheet.moraleCauses`, new `PoliciesCard` on Team, staff `DecisionPrompt` third button | `Narrative.swift` (`NarrativeState.flags` reads), `EventCopy` |
| E | The date in the diary | `Narrative` (`EventEffect`, `EventRequirements`), `NarrativeSystem.apply`/`rollLifeEvent`, `LifeSystem`, `RelationshipSystem`, `NetworkingSystem.askOut`, `LifeEvents.json`, `relationships.*`/`life.*` balance | `FamilyCard`, `PartnerCard`, `DecisionSheet` greyed option | `NarrativeChoicePresenter`, `EventCopy` |
| F | The boomerang | `Networking` (`Contact` fields), `NetworkingSystem` (`departed`, drift), the quit/fire call sites in `EmployeeSystem`, one line in `RivalSystem.poachSucceeds` | `AddressBookSheet`, `ContactSheet`, poach `DecisionPrompt` copy | `EventCopy` |
| G | Two ladders, dead perks | `Progression`, `ProgressionSystem`, `GoalDef` (`track`), `Goals.json`, `InvestorSystem.declareIndependence`, `MarketingSystem`/`EmployeeSystem` perk reads, `progression.*`/`investors.independent*` balance | `GoalsCard`, `NowCard` table, `InvestorsView` independence card, term-sheet `DecisionPrompt` line, biography banner | `FounderBiographyView`, `InvestorsView`, `EventCopy` |
| H | Origins | `GameState.newGame` origin deltas, `Employee.isCofounder`, `startProduct` topic lock, `origins` balance | `NewGameFlow` Stakes page, `FounderSetupSheet`, `NewProductFlow` lock, `GameSession.replayCurrentGame` | `FounderBiographyView` (one line) |

### Rules for every lane

1. **Balance is pinned.** `BalanceTargetsTests` (19 gates) and `InvestorTargetsTests` (9 gates) must pass unchanged. Every new multiplier reads 1.0 and every new delta 0 at the shipped default, or the feature is gated on something no pacing bot does (rivals on, a term sheet taken, a partner, a networking weekend). Say in the commit which it is.
2. **Saves decode.** New fields are optional or defaulted (`decodeIfPresent`); no `saveFormatVersion` bump. `SeedRoundTripTests` and `TycoonSave`'s suite stay green.
3. **Determinism.** New draws come from the lane's stream (`worldRNG`, `socialRNG`, `investorRNG`) and only when the feature is active; `FullLoopDeterminismTests` unchanged.
4. **Stay in your region.** `GameAction`, `Reducer.apply`, `GameEvent`, `EventCopy` and `BalanceConfig` have an *Iteration 5* region with your lane's cases already in it; replace your stubs, do not reorder anything.
5. **Prove it moves play.** Each lane ships at least one engine test that shows the decision has a cost on both sides (the PM's *How to verify*), plus a snapshot of its sheet or card in both themes.
6. **Verify before you claim.** `swift test` in `Packages/TycoonEngine` (look for the `✔ Test run with N tests` line), `make build`, and the app suite on your own simulator. Report numbers, not adjectives.

## Status (3 September, evening)

Eight Fable lanes in worktrees; three PM reports; one scaffold. Every lane shipped its feature with engine tests, a bot measurement where the PM asked for one, and both-theme snapshots; every lane's balance suites were byte-identical or gate-for-gate unchanged. Merged onto `iteration-5` in the order C → F → H → B → D → E → G → A, with the suites re-run after each merge. Deviations from the design, as each lane reported them:

- **A — Category Fight, Incumbent.** `strengthPerWeekBeaten` ships at 0.5, not 1.0: at 1.0 the investor suite lost three of nine gates (out-sold rivals launch worse products, revenue rises, the coasting founder is never removed). Acquisition absorbs, per category the player is in, only the rival's best product there and only if it beats the player's best — the whole shelf let a coaster buy a minnow a quarter and count it as a ship. `incumbentEnabled` lives at `rivals.depth.incumbentEnabled`. `defendCategory(topicID:defense:)` added beside `concedeCategory` so a routed answer marks the challenge answered only when it lands. The challenge sheet is modal, not deferrable. Bots: the defender holds more on 8/8 measured seeds (median +7.4 share points, short of the PM's 10) and is poorer 12 weeks on in 7/8; an out-sold rival folds inside a year on 6/10; the dominator meets an incumbent on 9/10 by day 730. Not done: the incumbent's News.json headlines and the "ignored challenge drops share ≥ 15" measurement. *Retune on the merged tree:* the incumbent's "two dominated topics" trigger fired in year one for coasting and independent bots alike (two minnows launching weak products into your categories counts as dominance), and that one mechanic moved all three investor gates. The trigger is now valuation alone, at $1M instead of $750k (`incumbentDominatedTopics` 0 = off, `acquisitionAbsorbsShelf` knob added, default on). After: underWarning 4, recoveries 3, independent chapter 5 on 6/10, *Still yours* on 4/10; the dominator still meets an incumbent on 8/10 by day 730; the defender gate is re-pinned at the measured 7 of 10 poorer.
- **B — Exit terms, Buy Back.** Added `.earnOutSigned` so signing has its own journal line; `EarnOut.missedReviews` kept explicitly; term sheets and the IPO close while an earn-out runs; the earn-out's expectation is read *before* the cheque lands so the cheque cannot be the profitable quarter. AcquirerBot on 10 seeds: 10 signed, 2 full price, 2 partial, 4 ousted, 2 open at three years; BuybackBot never buys the vote away cheaply (23 buybacks at 64–97% of cash). Biography snapshots now sample pixels because `ImageRenderer` renders nothing inside a `ScrollView`.
- **C — Build It For Them.** Product name is brand + topic (no name draw); standing is lost only where held; the sponsored roll draws `worldRNG`, so with rivals on the world stream shifts from day 56 (the investor suite re-rolls its rivals and its 9 gates still pass). Bot pair, 10 seeds: the taker ends 57% richer and faces 5 more rival products in its own topics at 0.61 share vs 0.81. The founder-alone sandbag beats both, and is the lever the PM named for wave 2.
- **D — Policies.** Content opts in through `StaffEventDef.policy`; the third button is a new `StaffEventChoice.strictAsPolicy`; the deadline's strict answer schedules no follow-up (that is the whole neutrality argument beyond "bots never set a policy"); reversing a strict rule is free. Ten follow-up defs. Note for the boomerang: `SocialSystem.handInNotice`'s walk-out path should also call `NetworkingSystem.departed`.
- **E — Diary.** Past the 10-day window a dated beat fires as an ordinary follow-up (a pause; only a partnered player can reach it); `.familyDateMissed` fires on the polite miss by hand or by deadline; `childID` added to the pending choice and the scheduled event so a birthday's second act names the same child; life follow-ups re-check their gate on the day; `anniversary_dinner` retired in favour of the calendar. 59 → 70 life beats.
- **F — Boomerang.** `leftRole` kept beside `leftDay`/`leftReason` (deriving the role back through the archetype collapses frontend/QA to backend); tuning in `AlumniTuning` in code, like `RivalDepthTuning`; interest on departure = morale on the way out. No pacing bot ever plans a networking weekend.
- **G — Two ladders.** The track is chosen by tapping *Stay independent* at 100%, not by equity alone: a diagnostic showed crunch-hire and saas finishing 3–5 funded chapter-3 goals inside two years, so an equity-keyed track would have moved the pinned table. Twelve new goals plus six shared, not eighteen new. The bootstrapper flip is measured with a `GoalIndependentBot` (5/10 reach *Still yours* at three years, 8/10 reach chapter 5 at four); the no-life bootstrapper still reaches chapter 5 on 0. Dead perks wired; `Route.city` added for "buy the office".
- **H — Origins.** `GameState.newGame` takes an optional `ContentCatalog` so a spin-out and a co-founder can be named from content; mortgaged builds the secured-loan state directly (the day-0 ceiling is far below $25k); `-autoOrigin` debug flag. SoloSlowBot per origin, 10 seeds: co-founded wins on first ship and cash on 8/10 but its founder's net worth lands under the garage's — the 30% is roughly what the second pair of hands is worth; nothing reached the ≥ 9/10 line.

Cross-lane fixes made at merge: two always-encoded fields (`boughtOut`, `liveProductsWeeks`) now encode only when they carry something, which is what keeps lane H's garage byte-identity guard meaningful; lane B's earn-out bot counts settled runs instead of asserting none are open, since lane C's sponsored roll moves when strategic offers land.
