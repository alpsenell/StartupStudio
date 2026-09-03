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

## Status

*Filled in at merge.*
