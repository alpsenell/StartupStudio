# Startup Studio — Iteration 3 ideas

Written after reading the engine (`Packages/TycoonEngine`), the content
tables (`Packages/TycoonContent/Sources/TycoonContent/Resources/*.json`),
every screen under `App/Sources/Screens`, and the pacing contract in
`Packages/TycoonEngine/Tests/TycoonEngineTests/BalanceTargetsTests.swift`.

## Where the game is actually thin

Three findings drove everything below. None of them is "there isn't enough
content" — there is a great deal of content.

1. **The market is a number the player reads and cannot touch.**
   `MarketSystem.run` walks twelve topic multipliers with a gaussian drift
   plus boom/crash jumps, appends them to `MarketState.history`, and that
   is the whole system — it takes no input from the player, ever.
   `MarketReportScreen.swift` has exactly one button and it says "Done"
   (`MarketReportScreen.swift:38`). `NewProductFlow`, the one screen where
   the market should decide something, never reads `state.market` at all —
   its topic step grades only static `topic.fitByType`
   (`NewProductFlow.swift:390`). And you could not act on it if you wanted
   to: `ProductSystem.postWeeklySales` reads the multiplier *live* each
   week, so a boom during a twelve-week build is weather, not a bet.

2. **Rivals happen to you.** `RivalSystem` is 833 lines and computes
   `playerShare` per topic (`RivalSystem.swift:293`), runs copycats
   (`:363`), price wars (`:412`), poaches (`:466`) and buyouts (`:600`).
   The player's entire vocabulary against all of it is five reactive
   actions in `GameAction.swift`: `matchPoachOffer`, `declinePoachOffer`,
   `acceptBuyout`, `declineBuyout`, `acquireRival`. Four of the five are
   *answers*. There is no move you can make first.

3. **Research is twenty nodes of pure upside.** `TechTree.json` is 20
   nodes; 14 of them are flat `qualityMultiplier` +0.05 or
   `devSpeedMultiplier` +0.10, and the early ones cost $0 cash. `TechNode.Effect`
   has four cases (`TechNode.swift:16-19`) and not one of them is a
   trade-off. There are no exclusive branches, and
   `ResearchSystem.startResearch` refunds 100% of progress when you switch
   nodes (`ResearchSystem.swift:55`), so even *ordering* is close to free.
   The quality bonuses then saturate against `techQualityMultiplierCap`
   (1.5), so the correct play is "research everything, in roughly cost
   order" and the tab never asks a question.

Everything below either turns one of those three into a decision, or puts
a cost on the other side of a screen that currently only gives.

---

## Ranking

| # | Idea | Size | One-line rationale |
|---|------|------|--------------------|
| 1 | **Hold the Category** (MAJOR) | L | Converts the two biggest dead systems — the market walk and the rival field — into the mid-game, using state that already exists (`playerShare`, `priceWar`, `launchMarketScale`, price tiers, patches). **Build this first.** |
| 2 | **The Codebase** (MAJOR) | L | Gives crunch, bugs and the ship-or-wait call a consequence that outlives the product, and makes your second product deliberately unlike your first. |
| 3 | **Ambitions** | M | Turns `Assignment` from throughput bookkeeping into a people decision — the roster's five slots finally mean something to the people in them. |
| 4 | **Named clients** | M | The contract sheet is anonymous and amnesiac; giving clients memory makes a small safe job worth more than a fat stranger's. |
| 5 | **Bet the tree** | S | Exclusive forks and a real switching cost turn a checklist into an identity. Mostly a content + two-field change. |
| 6 | **The launch window** | S | Lets a finished build be *held*, and makes the founder's market-sense attribute buy foresight worth holding for. The cheap probe for idea #1. |

---

# 1. Hold the Category — MAJOR

### The pitch
Pick a topic and make it yours. Every launch, patch, campaign and good
review in *fitness* builds your **standing** there; standing is worth
share, it is worth a heads-up when the category is about to boom, and it
is worth a warmer press. Then a rival walks into your category and you
have to decide how much it is worth defending — cut your price and eat the
margin, pull people off the new build to patch the old one, or spend cash
on a campaign for a product that is two years old. Or let it go, and watch
the back catalogue that was paying your payroll go quiet over six weeks.

### Why now
`TopicMarket.playerShare` already exists and is already multiplied into
weekly sales (`Market.swift:17`, consumed in
`ProductSystem.postWeeklySales`), but nothing the player does moves it —
`RivalSystem.recomputeShare` derives it purely from quality-weighted share
of everything on the market (`RivalSystem.swift:293`). So the game already
has the *stake* of a category fight and none of the *play*. Meanwhile the
copycat (`:363`) and the price war (`:412`) are the two most interesting
things `RivalSystem` does and the player currently receives both as
notifications.

### The player loop
- **A new Category strip** on the Market screen (which today is
  read-only): twelve topics, your standing 0–100 in each, the trend arrow
  that already exists, and *who else is in here*.
- Standing accrues from things you already do: shipping into the topic,
  review score, patch cadence, campaigns, contracts for clients in that
  vertical. It **decays** if you have nothing on the market there — so
  standing is rent you keep paying, not a trophy.
- What standing buys: a share floor (rivals can't take you below it
  quickly), a 3-week forward read on that topic's multiplier before the
  boom lands (the market walk becomes information you own, in one category
  and not the others), and cheaper hype on launches in it.
- **The fight.** When a rival launches into a category you hold above a
  threshold, the game pauses and names it: *"Northwind Software just
  shipped Pulse Fit. You have 6 weeks."* Three answers, each already
  implemented as a mechanic: `setPriceTier(.budget)` (margin), a patch
  cycle via `startUpdate` (dev capacity you wanted on the new build),
  a campaign via `startCampaign` (cash). Or nothing.
- **What goes wrong for the player:** you defend everything, spend two
  quarters defending, and ship nothing new — the board metric
  (`BoardExpectation.shipCadence`) fails and you get replaced. Or you hold
  one category so hard that `launchMarketScale`'s saturation and genre
  fatigue (`ProductSystem.launchMarketScale`) starve your own launches,
  which is the correct punishment for monoculture and is *already written*.

### Systems touched
`MarketState` / `TopicMarket` (new `standing: [String: Double]`),
`RivalSystem.recomputeShare` and `copycatCheck`, `ProductSystem`
(sales read standing-adjusted share; `launchMarketScale` unchanged),
`EconomyState.priceTier` and `startUpdate` (WS-A), `MarketingSystem`,
`GoalDef.Condition.topicsDominated` (already exists — it currently has
almost nothing behind it), `MarketReportScreen`, `NewProductFlow` step 2.
New actions: none strictly required; the three defensive plays reuse
`setPriceTier` / `startUpdate` / `startCampaign`. New state: a standing
dictionary and a `CategoryChallenge` record with a deadline day, which is
the same shape as the existing poach/buyout pending offers.

### Balance risk
Low, and this is the strongest reason to build it first: `BalanceTargetsTests`
runs its 19 gates with **`balance.rivals.rivalCount = 0`**
(`BalanceTargetsTests.swift:31`). Nothing that requires a rival on the
board can move those numbers. The one term that *does* reach the bots is
the standing→share multiplier, so it must read exactly 1.0 at standing 0
and the bots — which never defend anything — must accrue standing at a
rate whose share effect is a no-op in the first two years. Ship the
standing accrual and the read-only strip first, land the pacing table
unchanged, then attach share.

### Scope
**L.** Thinnest shippable version: standing accrues and decays, it is
visible on the market screen and in `NewProductFlow` step 2, and it does
exactly one thing — the 3-week forward read on the multiplier in
categories where you're above 50. No rival challenge, no share effect.
That alone makes the market screen a place you go for a reason. The fight
is phase two.

### Why it might be wrong
Standing may be a third name for something the game already has twice:
company `reputation` and product `quality` both already gate how well a
launch does. If the player experiences standing as "reputation, but
per-topic", it is bookkeeping. The tell is the first playtest question —
if a player can't say *why* they'd defend fitness rather than start a
product in music, the fight isn't real and the idea should collapse back
into idea #6.

---

# 2. The Codebase — MAJOR

### The pitch
Every product you build leaves a codebase behind. Start your next product
on it and you begin weeks ahead with a chunk of the design and code pools
already filled — but you inherit its **debt**, and debt means bugs you
didn't write and a quality ceiling you can't polish past. Crunch adds
debt. Shipping with open bugs adds debt. Patching adds a little. You can
put people on **refactoring**, which produces nothing anyone can see, for
weeks, and is sometimes the only thing that will let the studio ship
anything good again.

### Why now
Three of the game's best mechanics currently end the moment a product
ships and are never heard from again. `DevProgress.openBugs` is discarded
at ship. `WorkPace.crunch` costs morale and bug rate *this week* and
nothing after. The crew quality ceiling that `ShipForecast` so carefully
explains (`ShipForecast.swift`) is recomputed per product from scratch, so
the second product is mechanically identical to the first with better
people. There is currently **no reason a veteran studio plays differently
from a new one** other than bigger numbers, and no state that carries the
studio's history of how it built things.

### The player loop
- New product flow gets a fourth choice: **greenfield** or **build on
  `<codebase name>`**. The sheet shows exactly two numbers: the head start
  (points pre-filled) and the debt (a ceiling penalty and a bug-rate
  multiplier). No hidden term — this game is good about that, see
  `ShipForecast`.
- Debt rises visibly during the build: crunch weeks, ship-with-bugs, and
  each patch add to it. The HQ burn card gets a second line the player
  learns to fear.
- New `Assignment` case `.refactor` (the enum has five cases today,
  `Employee.swift:20-34`). Refactorers produce no design/code/polish and
  no revenue; they cut debt. A studio with two products live, a contract
  running and a refactor going is out of people — which is the point.
- **What goes wrong:** debt spirals. You take the head start three
  products running, your ceiling drops below what your (excellent) crew
  could reach, `ShipForecast.limitingFactor` starts saying *"the codebase
  caps this at 61"*, and the only exit is either weeks of refactoring or
  throwing the codebase away and going greenfield — a decision that costs
  a full slow build in the middle of a run.

### Systems touched
`Product` / `DevProgress` (debt accrual at ship), `ProductSystem.ship` and
`qualityCeiling`, `ShipForecast` (one more term and one more
`limitingFactor` string — the structure is already there for exactly
this), `Employee.Assignment` + `EmployeeSystem.sweepStaleAssignments`
(`EmployeeSystem.swift:347`), `WorkPace`, `LiveOpsSystem` patches,
`NewProductFlow`. New engine state: a `Codebase` struct per lineage
(name, filled pools, debt) on `GameState`, plus a `codebaseID` on
`Product`.

### Balance risk
Medium — this one is in the main loop and the bots will feel it. The
mitigations: greenfield is the default and must be *bit-identical* to
today (no head start, no debt, ceiling term = 1.0), and the debt
accrual rate ships at the value that keeps the existing pacing bots —
which never refactor and which crunch (`crunchHireClimbsTheLadderOnScheduleAndNotFaster`,
`crunchingForeverEndsInHospitalButNotOnATreadmill`) — inside their gates.
Concretely: `debtCeilingPenaltyPerPoint` must be a config value whose
shipped default is chosen *after* running the baseline table, not before.
Expect to spend real time here; it is the reason this is #2 and not #1.

### Scope
**L.** Thinnest shippable version: one codebase per product *type*, a head
start and a debt number, debt from crunch only, and `.refactor` as an
assignment. No naming, no throwing it away, no patch contribution. That is
already the whole decision.

### Why it might be wrong
It is Game Dev Tycoon's engine system, and the honest question is whether
it adds a decision or just a second tax on crunch — crunch already costs
morale, bugs and the founder's health. If playtesters take the head start
every time without thinking, the debt number is too small; if they never
take it, it's too big; and the window where both are live may be narrow.
Cheapest early read: run the pacing bots with the head start on and debt
*off*, and see whether the head start alone is so strong it breaks
`soloFounderShipsALateAndRoughFirstProduct`. If it is, the trade has room.

---

# 3. Ambitions

### The pitch
The people you hire want something besides money. One wants to be on a
product and not a client job. One wants to learn from somebody better than
them. One wants their name on a launch. Park them on the wrong work long
enough and no raise will hold them.

### Why now
`Assignment` has five cases and the game treats them as identical from the
person's point of view: `EmployeeSystem` reads the assignment for output
and for nothing else. Morale is driven by pay, pace, amenities, the
founder's mood and the staff events — never by *what the person is doing
all day*. Meanwhile the game already models a bond with the founder, a
notice period you can reverse, and traits from `Traits.json`. The Team
screen is a sortable list with bulk assign (`TeamScreen.swift`) — it is
the most bookkeeping-heavy screen in the game, and it is one field away
from being a placement puzzle.

### The player loop
Each hire arrives with one ambition, shown on the manage sheet next to the
existing "why they're unhappy" copy. Satisfying it is a slow morale/loyalty
gain; frustrating it is a slow drain that pay only partly covers, and it
shows up in the existing notice-period flow with its own reason string.
The decision: your best backend dev wants product work, and the contract
that pays this month's payroll needs exactly them.

### Systems touched
`Employee` (one field), `EmployeeSystem` morale accumulation,
`EmployeeManageSheet`, `TeamScreen`, `TraitDef` (ambitions can be derived
from traits the way appearances derive from a seed, keeping the RNG stream
append-only), `mentorEmployee` and `oneOnOne` as partial relief.

### Balance risk
Real but bounded. `neglectfulBossLosesPeople` and
`lookingAfterPeopleKeepsThem` are the two gates this can break. The bots
assign almost everyone to product work, which satisfies the most common
ambition, so the expected effect on those gates is small — but the
frustration slope must ship at a value verified against the baseline
table, and the satisfied-ambition bonus must be 0, not a positive number,
so a bot's roster doesn't get quietly happier than the shipped balance
assumes.

### Scope
**M.** Thinnest version: three ambitions (product work / mentorship /
shipped credit), derived from role and trait, one morale term, one line on
the manage sheet.

### Why it might be wrong
It can read as "another reason people leave" in a game that already has
several, and the player's counter-play is thin if they only have four
people — with a small roster there is no slack to satisfy anybody, so
early game the feature is pure punishment. It may need to be gated on
headcount ≥ 6, which is a smell.

---

# 4. Named clients

### The pitch
The client you delivered for last quarter comes back — bigger job, better
money, and they ask for you by name. The one whose deadline you blew
doesn't, and tells the others.

### Why now
`ContractSystem.refreshOffers` picks a client name at random from
`content.names.clientCompanies` (`ContractSystem.swift:53`) and replaces
the entire sheet every refresh (`:85`). Nobody remembers anything. The
delivery grading is genuinely good — payout is docked by crew skill vs.
`requiredSkill`, and a poor delivery costs reputation — and then it
evaporates into a single global number. So the contract tab asks one
question forever: *do I have spare capacity this week?*

### The player loop
Clients persist with a standing. Deliver well and that client returns with
larger jobs, eventually a **retainer** (steady weekly money, but it books
crew capacity you can't reclaim without a penalty). Deliver badly, or miss
a deadline, and they're gone and your offer sheet shrinks. The sharpest
version: one big client offers an exclusive — their job takes your whole
dev capacity for eight weeks, pays very well, and you may not have a
product in development while it runs. That is the choice between being a
studio and being an agency, and it is a different second playthrough.

### Systems touched
`ContractOffer` / `ContractJob` (a `clientID`), `ContractSystem` refresh
and settlement, `ContractsView`, `Company.reputation`, the Legal
department bonuses, `founderDealFactor` (the finance attribute finally has
a repeated place to matter).

### Balance risk
Low-to-medium. `contractGrinderMakesALivingNotAFortune` is the gate. The
grinder bot accepts everything, so it would climb every client to top
standing and earn more than the shipped balance allows — so standing must
raise *offer quality on the sheet* (bigger jobs, longer deadlines) rather
than multiply payout, keeping `contractPayoutPerPoint` untouched and the
grinder's income within its band. If a payout multiplier is used at all,
it must be 1.0 at standing 0.

### Scope
**M.** Thinnest version: clients persist across refreshes, standing moves
on delivery quality, and a good client's next offer is drawn from a
better range. No retainers, no exclusives.

### Why it might be wrong
Contracts are meant to be the boring, safe income floor that lets the
risky product play exist. Making them interesting may pull player
attention toward the least ambitious part of the game — a studio that
grinds happy clients forever is a failure state the game currently avoids
by making contracts dull on purpose.

---

# 5. Bet the tree

### The pitch
The research tree stops being a shopping list. Some nodes are forks: take
*Rapid Prototyping* and you can never take *Formal Verification*. And
walking away from a node in progress costs you what you'd put in.

### Why now
20 nodes, 14 of which are flat +5% quality or +10% dev speed, with the
quality ones saturating against `techQualityMultiplierCap` = 1.5. Four
effect cases, all upside (`TechNode.swift:16-19`). Switching the active
node refunds 100% of progress (`ResearchSystem.swift:55`). There is
literally no wrong research decision available to the player, which means
the Research tab — a whole screen, `ResearchView.swift`, 610 lines — never
asks anything.

### The player loop
Two or three exclusive pairs per tier, each pair being a genuine studio
identity: speed vs. quality, breadth (a product type) vs. depth (a
multiplier), in-house vs. outsourced. The tree screen shows the sibling
greying out permanently before you commit, with the choice spelled out on
the button the way `DecisionSheet` already does for narrative events.
Switching an in-progress node refunds a fraction, not all — so starting
research is a commitment of weeks of somebody's time.

### Systems touched
`TechNode` (one new optional field, `excludes: [String]`, defaulting to
empty so `TechTree.json` and every existing save decode unchanged),
`ResearchSystem.startResearch`, `ResearchView`, `TechTree.json`.

### Balance risk
Lowest of the six. Exclusivity only ever *removes* upside from a bot, and
`ProgressionBots` / `PacingBots` research in cost order — so the concrete
risk is a bot that ends the run with fewer multipliers than the shipped
balance assumes. Pair the exclusive branches so both sides sum to the same
total bonus, and the aggregate the bots accumulate is unchanged. The
partial-refund fraction ships at 1.0 (today's behaviour) and is tuned
separately.

### Scope
**S.** Mostly content plus two engine fields. Thinnest version: three
exclusive pairs, full refund kept as-is.

### Why it might be wrong
If the two sides of a fork are balanced well enough, the choice is a coin
flip and adds nothing but regret. Forks only work when the sides are
*differently* good — one right for a contract shop, one right for a
product studio — which means this idea is worth much more after #4 or #2
exists to give the sides something to be right about. It may be
mis-ranked and belong after them.

---

# 6. The launch window

### The pitch
Your build is finished. You can ship it Monday, or hold it — three weeks
in the drawer, paying wages, watching your hype bleed — because your
market-sense says the category is about to turn, or because a rival is
launching next week and you'd rather not open against them.

### Why now
Today shipping is the only thing you can do with a finished build, and the
market multiplier is read live and weekly during sales
(`ProductSystem.postWeeklySales`), so timing is invisible and unactionable
in both directions. The founder's `marketSense` attribute currently does
one thing — `founderMarketFactor`, a flat multiplier on demand — which is
a stat, not a decision. And `RivalSystem` knows exactly when rivals launch
(`RivalSystem.swift:211`), information the player never sees before it
happens.

### The player loop
On a finished build, the ship sheet — which already tells the truth well
(`ShipForecast.limitingFactor`) — gains a **window** panel: this topic's
multiplier now, and a forecast band for the next three weeks whose width
narrows with the founder's market sense. High market sense and you see a
useful band; low and it's a shrug. Holding costs `hypeDecayRate` per day
against the hype you paid for, plus payroll on people you could have moved
to the next build. Getting it right is a materially better launch peak;
getting it wrong is a worse one, and you knew the odds.

### Systems touched
`MarketState.history` (the forecast is a read over data that already
exists), `FounderQueries.founderMarketFactor`, `ShipForecast`,
`LaunchDaySheet` / `ProductDetailScreen`, `MarketingSystem` hype decay.

### Balance risk
Very low if the forecast is a *read* and the hold is optional: no new
multiplier at all, no default to keep at 1.0. The bots ship immediately
and are unaffected by definition.

### Scope
**S.** Thinnest version: the forecast band on the ship sheet, no hold —
purely turning the market walk into something the ship decision can see.
That alone tests whether players care about market timing before anything
is built on the assumption that they do.

### Why it might be wrong
The market walk's drift sigma may be small enough that three weeks of
forecast is never worth three weeks of held hype, in which case the right
answer is always "ship now" and this is a decorated confirmation dialog.
Check that first, in the numbers, before writing any UI: run the shipped
`market.driftSigma` and ask whether a three-week hold ever beats the hype
decay. If it doesn't, either the market needs more amplitude — which is
idea #1's job — or this idea dies.

---

## Cut list

- **Global expansion / a second city.** The city map already exists with
  five districts and the relocate/rent/buy decision; a second city is more
  surface where the answer is the same one you already made.
- **A stock market / trading the rivals' shares.** New subsystem, no edge
  to any existing one, and the networking floor already sells "buy a stake
  in someone's startup" as a founder-wallet bet.
- **Achievements / Steam-style badges.** Thirty goals across five chapters
  already do this job, and they pay perks rather than vanity.
- **More topics, more product types, more events.** 12 topics, 6 types,
  83 company events and 59 life events. Adding a thirteenth topic changes
  no decision. The tables are not the problem.
- **An office decorator.** Amenities plus four office tiers plus the
  PixelKit room builder already cover this, and none of it would create a
  choice with a cost on the far side.
- **A bug-triage minigame.** Live bugs, support desks and patch cycles
  already turn bugs into a staffing decision; a minigame replaces a
  decision with dexterity.
- **Employee 1:1 dialogue trees.** `DialogueCatalog` and the networking
  conversation grading already carry this weight, and per-employee trees
  are enormous content cost for an effect `oneOnOne` already delivers.
- **A "company culture" set of toggles** (remote work, four-day week,
  equity for staff). Every one of them reads as a permanent global
  multiplier the player sets once in week three and never revisits —
  pure upside with a settings screen in front of it.
- **Difficulty modifiers / mutators.** Four difficulties already exist and
  are enforced by their own pacing gates; mutators are replay variety
  bought without designing any.
- **Sequels to your own products.** Tempting, and close to idea #2 — but
  `launchMarketScale`'s saturation and genre-fatigue terms currently
  *punish* relaunching into the same topic and type, so a sequel system
  fights the balance the game already shipped. It should be folded into
  The Codebase, where the head start is the sequel, rather than built as
  its own feature.

---

## If you build one thing

**Hold the Category.** It is the only idea here that makes two entire
existing systems — 833 lines of `RivalSystem` and the whole market walk —
matter to the player for the first time, it needs almost no new engine
state, and the pacing contract runs with rivals disabled so the balance
risk is mostly quarantined. Ship the standing meter and the forecast
first, confirm the baseline table is unmoved, then attach share and the
fight.
