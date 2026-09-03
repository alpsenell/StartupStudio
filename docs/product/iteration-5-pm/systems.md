# Iteration 5 — the company game (products, market, rivals, contracts, research, investors, economy)

Written after reading `README.md`, `docs/product/iteration-3-ideas.md`,
`iteration-4-ux-ideas.md` and `iteration-4-workstreams.md` (Status, 3 Sep),
`git show --stat 4c5600a a3dc235`, every engine file in the lane
(`GameAction`, `GameState`, `Product`, `Market`, `Rival`, `Investors`,
`Contract`, `Research`, `Economy`, `Codebase`, and `Systems/Rival`, `Product`,
`LiveOps`, `Investor`, `Contract`, `Market`, `Marketing`, `Research`,
`Standing`, `Codebase`, `Finance`), `Balance.json`, the fourteen content
tables, the Business / Products / Market / Research screens, and the pacing
contract (`BalanceTargetsTests`, `PacingBots`, `InvestorTargetsTests`,
`InvestorBots`, `ProgressionBots`). The simulator was run twice at ×4; the
clock stops at the first pausing event (day 15–30), so mid- and late-game
screens are judged from code. One screenshot matters and is cited below.

Counts, verified: 12 topics, 6 product types (3 unlocked from the start),
20 tech nodes, 8 investor personas, 83 company events, 44 headlines, 32
client names, 40 rival studio names, 30 goals, 695 engine tests.

What iteration 3 actually shipped, against its own doc: **Hold the
Category** landed as *phase one only* — standing accrues and decays and
buys a 3-week forecast, and the commit says so ("Deferred to phase two, as
scoped: the standing→share multiplier and the rival category challenge").
**The Codebase** landed in full. Ambitions, Named clients, Bet the tree and
the Launch window did not land.

One correction to the brief's framing. The mid and late game are not thin
because there is too little in them; they are thin because **nothing in the
company game responds to the player**. Rivals wander on a random walk you
cannot touch, investors write a cheque and watch a number, contracts forget
you weekly, research has no wrong answer. Every candidate below is a new
*edge* between systems that already exist, chosen so a player's move has an
answer in the world.

---

## Where the company game is thin now

### 1. Rivals are weather with names

The player's entire vocabulary against 833 lines of `RivalSystem` is five
reactive cases — `matchPoachOffer`, `declinePoachOffer`, `acceptBuyout`,
`declineBuyout`, `acquireRival` (`GameAction.swift:37–46`). Four are
answers; the fifth is a purchase.

- Rival strength is a gaussian walk (`strengthDriftSigma` 2/week) that no
  player action moves except a successful poach (+5,
  `RivalSystem.poachedStrengthGain`). Out-selling a rival for a year does
  nothing to it.
- Rival products have a `weeklyUnits` figure the code itself calls
  decorative — "nothing simulates against it" (`RivalSystem.swift:228`) —
  and every rival product is typed as the first product type in the catalog
  (`:230`).
- Standing "buys exactly one thing" — the forecast
  (`StandingSystem.swift:14`, `Market.swift:243`). Share is quality-weighted
  and the only player lever on it is the price tier's `shareWeight`
  (1.35 / 1.0 / 0.85).
- **The price war fires at phantoms.** `priceWarCheck` counts a topic as
  "player ahead" when `share(for:) > 0.5` (`RivalSystem.swift:433`), and
  `share(for:)` returns 1.0 for any topic the player has never entered
  (`Rival.swift:344–345`). So a rival's first launch into a topic you are
  not in reads as you beating them, and two weeks later they declare war.
  Screenshot `pm/systems/business-01.png`: **Jan W3 Y1, zero products,
  "Anvil Digital started a price war in Finance — until day 42."**
  `.priceWarStarted` is `.notable` (`GameState.swift:388`) so it stops the
  clock; the penalty is applied only in topics you sell in
  (`recomputeShare`), so it is a pause with no consequence. The existing
  test `beatingARivalTwiceStartsAPriceWar` sets up a player product first
  and never sees this.

### 2. The field never scales with you

Rivals are founded at strength 15–55 and reputation 10–50
(`Balance.json` → `rivals.foundingStrength*`), with no year or player-size
term. Valuation is `strength × 4000 × (1 + rep/100)` (`Rival.swift`), so the
strongest fresh rival is worth about $330k. The player's valuation is cash
plus four weeks of revenue × 6 plus reputation × 1500
(`GameState.swift:805–815`): a studio-tier company with a $20k/week platform
is worth $480k before cash. `acquireDominanceFactor` is 1.5, so by mid-game
every rival on the board is buyable — and `acquireRival` removes it
(`RivalSystem.swift:767`), drops its products on the floor, and the next
tick re-founds a fresh 15–55 minnow (`:45`). The strategic buyout — the best
exit — needs a buyer worth at least half of you (`strategicDominanceFactor`
2.0); by the time you qualify, no such rival exists. There is no late-game
antagonist.

### 3. Investors: cash in, one number watched, no move afterwards

Three actions: `acceptInvestment`, `declineInvestment`, `fileIPO`
(`GameAction.swift:99–104`). Equity sold is gone for the run; each seated
round's ask is *added* to `boardExpectations` (`Investors.swift`) and the
only relief is another round (`raisePressureRelief` 0.5) — the way out of a
board is more board. Equity has one use: IPO proceeds are
`valuation × 1.4 × equityRemaining`, the largest single lever on the ending,
and nothing lets you pull it. Late-game cash has few sinks with a decision
attached: the campus ($300k, `offices.campus.upgradeCost`), amenities, and
acquisitions that respawn.

### 4. Contracts are anonymous, amnesiac, and touch nothing

`ContractSystem.refreshOffers` picks a client name at random from 32
(`ContractSystem.swift:53`) and replaces the sheet weekly. `ContractOffer`
has no topic, no client id, no counterpart — commit `4c5600a` notes
"Contracts carry no topic, so the 'contracts in that vertical' accrual
source has nothing to hang off yet." `ContractSystem` and `RivalSystem`
share no state. The offer card (screenshot: "Herring & Hound Legal · Code
49 · Design 13 pts · Skill ~53 · $3,305 · Penalty $992 · Due in 25 days")
asks the one question it always asks: do I have spare hands this week.

### 5. Research is a checklist with a free undo

20 nodes: 7 quality (+0.05 each = +0.35, which is exactly the
`techQualityMultiplierCap` of 1.35), 7 speed (+0.80 total), 4 type unlocks,
2 campaign unlocks. `TechNode.Effect` has four cases, all upside. Switching
or cancelling refunds 100% of progress (`ResearchSystem.swift:55`, `:86`).
The prerequisites already draw two spines — a quality line
(`code_reviews → automated_testing → … → craftsmanship_culture`) and a
speed line (`version_control → agile_sprints → … → hyperscale_pipeline`) —
and nothing stops you taking both in cost order. `ResearchView` is 603 lines
that never ask a question.

---

## Five candidates, ranked

### 1. The Category Fight (Hold the Category, phase two) · L

**The player's sentence.** "A rival launched into my category and I had six
weeks to decide whether it was worth defending — and now I can bleed a
rival out by out-selling them."

**Problem.** Findings 1 and 2. Standing exists (0–100 per topic, decays
1.5/week with nothing on the market) and is worth a forecast and nothing
else. Share is a number the rival system computes and the player watches
(`RivalsView.TopicBattleCard` shows "62% of the market · YOU LEAD" and
offers nothing). Rivals never feel a thing you do.

**How it plays.**

- *Standing holds share.* In a contested topic your share cannot fall below
  `shareFloorAtFullStanding × standing/100` (0.55 at standing 100). This
  only exceeds today's hard floor of 0.30 above standing ~55, so early play
  reads exactly as it does now. A held category is worth defending because
  it is sticky; a category you walked out of is not.
- *The challenge.* When a rival launches (weekly roll or copycat) into a
  topic where your standing ≥ 50 and its product's quality is within 15 of
  your best score there, the clock stops on
  `.categoryChallenged(rivalID, topicID, productName, quality, respondByDay)`,
  drawn on the WS-D decision sheet with the rival's portrait. It names the
  stakes in numbers: your share now, their score against yours, the six
  weeks until it settles. The answers are actions the game already has —
  `setPriceTier(.budget)` (margin), `startUpdate` (a build slot for weeks),
  `startCampaign` (cash), or "Let it go" — the sheet routes to them; nothing
  new is built for the answers. One challenge per topic per 26 weeks.
- *The consequence.* After `challengeWeeks` (6): share ≥ 0.5 in the topic
  and you held it — the rival loses 8 strength and +10 standing for you;
  otherwise you lost — standing −20 (so the retainer stops covering the
  decay and the category goes quiet), the rival gains +5 and adds the topic
  to `focusTopicIDs`, so it keeps coming.
- *The first move.* Weekly, in every topic where you and a rival both have
  something on the market, the side with the lower share loses
  `strengthPerWeekBeaten` (1.0). A rival you out-sell for six months is at
  the fold threshold (8). Shipping a strong product *into a rival's topic*
  is now a way to push it off the board — the move you can make first.
- *Fix the phantom war* while in there: `priceWarCheck` counts only topics
  where `playerShare[topicID] != nil`.

*When it lands:* first challenge typically months 4–10 (standing ≥ 50 needs
one launch reviewed 60+ plus a few weeks of retainer; the copycat fires 8
weeks after your first good launch, straight into your best topic).

**Touches.** `RivalsState` (+ `pendingChallenge: CategoryChallenge?`, the
shape of `pendingPoach`); `GameEvent` (+ `.categoryChallenged`,
`.categoryHeld`, `.categoryLost`); `RivalSystem` (launch/copycat hook,
weekly strength bleed, challenge settlement, the price-war fix,
`recomputeShare` floor); `StandingSystem` (two new awards); move
`RivalDepthTuning` into a `rivals.depth` block of `Balance.json`;
`DecisionSheet` route for a non-narrative critical decision (poach and
buyout already have sheets — reuse the presenter); `RivalsView.TopicBattleCard`
(challenge banner + countdown), `DeskCard` (a clock), `CategoryStripCard`.
Save: one optional field, decodes nil. No content JSON beyond balance.

*Balance stays neutral by default:* the 19 pacing gates run with
`rivalCount = 0` (`BalanceTargetsTests.swift:31`), so nothing here can reach
them; `standingNeverReachesTheEconomy` also runs at `rivalCount = 0`
(`CategoryStandingTests.swift:287`) and keeps passing — add its twin: with
rivals on and standing 0, share equals the shipped share to the dollar. The
floor term must be a no-op below standing 55. **The investor suite runs
with `rivalCount = 4`** (`InvestorTargetsTests.swift:42`), so the strength
bleed and challenge outcomes *can* reach the 9 investor gates through
revenue; ship `strengthPerWeekBeaten` and the challenge penalties at values
verified against that suite, and gate the bleed on the player having a live
product in the topic (the same guard as the war fix), which the funded bots
mostly do not.

**Size.** L — 3 engineer-days. Thinnest shippable: the standing floor and
the challenge with three routed answers; the strength bleed is day three.

**Risk.** It reads as a nag if it fires for every rival mobile app in a
topic you hold; the quality-within-15 gate and the 26-week cooldown are the
guard. The real failure: defending is always right (floor too generous) or
never right (six weeks too short to finish a patch on a 600-point
platform). The tell is the first playtest question — if the player cannot
say why they'd defend fitness rather than start something in music, the
numbers are wrong, not the idea.

**How to verify.** A `DefenderBot` (SoloSlow plus: on a challenge, go
budget tier and start a patch) against SoloSlow on the same 10 seeds with
`rivalCount = 4`: the defender keeps ≥ 10 more share points at week 6 *and*
has less cash over the following 12 weeks (the margin cost is real). A
rival out-shared for 26 straight weeks folds on ≥ 3/10 seeds. A fresh game
with no product emits no `.priceWarStarted` in 90 days (regression for the
phantom war). Baseline table at `rivalCount = 0` unchanged line for line.

---

### 2. Buy Back the Board · S–M

**The player's sentence.** "I bought my investors out and took the company
back."

**Problem.** Finding 3. Once you take a cheque the equity is gone for the
run, the board's ask is added forever, and the only relief is a second
cheque. The founder's exit is `valuation × 1.4 × equityRemaining`; nothing
lets you move `equityRemaining` upward. Late-game cash has nowhere to go
with a decision attached.

**How it plays.** Every closed round on the Investors screen gets "Buy them
out — $X". Price = `round.equity% × current valuation × buybackPremium`
(2.5, the same `roundValuationPremium` they paid forward at) `× (1 +
boardPressure/100)` — an investor who can smell a vote charges for the
privilege. Paying it: cash out (ledger `.other`, "Bought out Northgate
Seed"), the round moves to `boughtOut` history, `equityRemaining` rises by
its equity, and because `boardExpectations` is derived from seated rounds,
its ask leaves the room by construction. With no seated round left, reviews
stop (`watching.last == nil`).

The decision: cash that is runway, hires, the campus — against a bigger
slice at exit and one fewer master. The curve does the work: buyback is
cheapest when you are small and broke and most expensive the moment you can
afford it, and a founder at 80 pressure pays 1.8× to end the meeting. The
sharp version lands in year 2–3 with two boards watching two numbers: pay
$400k to lose the profitability ask, or keep the cash and hit the number.

**Touches.** `GameAction.buyBackRound(investorID:)`; `InvestorSystem.buyBack`;
`InvestorState` (+ `boughtOut: [RaisedRound]`, decodes empty); `GameEvent`
(+ `.roundBoughtBack`); `InvestorsView` round row (the button and a confirm
carrying the WS-D money line: "−$240,000 → $310,000 · runway 9 wk");
`FounderBiographyView` ("bought out Lantern Partners in year 3");
`founderNetWorth` and `canFileIPO` unchanged. No content JSON.

*Balance stays neutral by default:* no pacing bot and no `InvestorBot`
calls it — neutral by construction for all 19 + 9 gates. No multiplier
touches an existing path.

**Size.** S–M — 1.5 engineer-days.

**Risk.** It becomes the answer to every board: if the pressure multiplier
is too weak, a founder at 90 pressure buys the vote away for pocket change
and `theBoardRemovesTheFounderWhoStopsGrowingIntoTheMoney` is a paper tiger
for a human even while the bots still fail it. Cheapest early read: a
`BuybackBot` (InvestorBot that buys back the moment it can afford it and
keep 8 weeks of payroll) — count how often the buyback happens at pressure
≥ 60 against how often that founder would have been ousted. If it saves
more than 70% of oustings for less than 20% of cash on hand, raise the
premium. Second risk: `InvestorsView` is already 457 lines; the button
belongs on the round row, not in a new section.

**How to verify.** Unit: buying back the only seated round empties
`boardExpectations`, stops the next quarterly review, and raises IPO
proceeds by exactly `equity × valuation × 1.4`. Bot: `BuybackBot` against
`InvestorBot` on the ten seeds — the buyer IPOs with higher proceeds on
some seeds and goes bankrupt on more (the cost is real), and the 9 investor
gates still pass with the buyer *not* in the suite.

---

### 3. Build It For Them · M

**The player's sentence.** "A rival paid us to build their next app. I took
the money — and shipped a competitor into my own category."

**Problem.** Findings 4 and 1. `ContractSystem` and `RivalSystem` share no
state. Contracts have no topic and no counterpart; the sheet asks about
spare capacity every week and nothing else. Rival products appear from a
weekly roll (`shipChance` 0.10) with quality off strength — nothing the
player did.

**How it plays.** On refresh days, when a rival exists, one offer on the
sheet may be *sponsored*: "Northwind Software · Fitness · white-label". It
pays `sponsorPayoutFactor` (1.8×) the sheet's rate, asks a high skill
(`rival.strength × 0.8 + 20`), has a long deadline, and says plainly what
it is: *"On delivery Northwind ships a Fitness product at the quality you
build. You hold Fitness at 62."*

On delivery a `RivalProduct` is appended to the rival with quality
`projectedQuality × 0.9` (clamped 20–95), the rival gains +6 strength and
adds the topic to `focusTopicIDs`; you are paid; your standing in that topic
drops 5 (the trade press knows whose app that was). Deliver poorly
(`projectedQuality` < 60): you are paid 50% and lose 2 reputation — the
existing rules — *and* their product is weak. Sandbagging is a real option
with a real cost.

The decision: cash now — the biggest contract you will see this year —
against arming a rival, possibly in the category you hold, and telling the
world you are an agency. It also tells you something: which topic that
rival is about to enter. Lands from the first rival launch (~month 2) and
is sharpest mid-game when the sponsored offer names a topic you hold.

**Touches.** `ContractOffer` / `ContractJob` (+ `sponsorRivalID: UUID?`,
`topicID: String?`, decode nil); `ContractSystem.refreshOffers` (one extra
sponsored roll drawn from `worldRNG`, so `rng`'s documented per-offer draw
groups stay byte-identical — the trick `RivalSystem` already uses);
`settleContracts` (hand the product to `RivalSystem.appendProduct`, made
internal); `StandingSystem` (a negative accrual source — the one the
`4c5600a` commit said had nothing to hang off); `ContractsView` (sponsor
badge, the warning line, the rival's portrait); `DeskCard` (a clock).
`Names.json` `rivalStudios` (40) already exists. Save: two optional fields.

*Balance stays neutral by default:* the pacing gates run at
`rivalCount = 0`, so no sponsored offer ever rolls and
`contractGrinderMakesALivingNotAFortune` is unchanged by construction. The
investor suite (`rivalCount = 4`) uses bots that never accept contracts, so
the 9 gates are untouched. `sponsorChance` ships at 0.25 per refresh, never
in the first 8 weeks, one per sheet.

**Size.** M — 2 engineer-days.

**Risk.** It is a trap if the sponsored payout is the only contract worth
taking; the one-per-sheet cap and the 8-week quiet start are the guard. The
sharper failure: the sandbag is dominant (take the money, deliver at 50%).
The tell is playtesters always sandbagging; the fix is a rival-specific
term — the rival tells the other clients and the sheet shrinks by one for 8
weeks. Verify the shape before building UI: a grinder that takes every
sponsored job against one that declines, `rivalCount = 4`, ten seeds — the
taker should end ≥ 15% richer *and* face ≥ 2 more rival products in its own
topics with a measurably lower share.

**How to verify.** Unit: delivering a sponsored job appends a rival product
of the promised quality and drops standing by 5; a poor delivery appends a
< 55 product and pays half. Bot: the pair above. Determinism:
`FullLoopDeterminismTests` unchanged at `rivalCount = 0`.

---

### 4. The Incumbent · M (after #1)

**The player's sentence.** "Once I got big, a giant showed up in my best
market — and stayed."

**Problem.** Finding 2. There is no late-game antagonist: every rival is
founded at 15–55 regardless of the year, the player out-values the board
1.5× by studio tier and can buy it clean, and every purchase re-founds a
minnow. The best exit (a strategic buyout at 1.5–2.5×) needs a buyer worth
half of you, which by then does not exist. `g4_own_a_topic` and
`g4_acquire_a_rival` (Goals.json) are goals about a fight that never
escalates.

**How it plays.** The first time the player's valuation crosses
`incumbentValuationFloor` ($750k) *or* `dominatedTopicCount ≥ 2`, and no
incumbent is on the board, the next founding is an Incumbent: personality
`.deepPockets` (never folds), strength `0.6 × valuation / 4000` clamped
70–95, reputation 60–80, two focus topics = the two topics where you have
the highest standing *and* something live, and it opens with a category
challenge (#1) in the higher. At strength 90 / rep 70 it is worth ~$612k,
so it is the buyer the strategic path was written for (`buyoutCheck`
already picks `strongestRival`) — the late game finally has someone who can
afford you.

It can be beaten: hold ≥ 0.5 share in both its topics for 26 weeks and it
retreats (`.incumbentRetreated`: drops your topics, +5 reputation, +15
standing in both). It can be bought (`acquireRival`, ~$800k) — and as part
of this, **acquiring any rival absorbs its competing products as yours**:
released, on market, in their topics, reviews synthesised from their
quality (`ReviewBlurbs.pick`). Acquisition becomes a way to buy a category
instead of a $300k reputation bump.

The decision is the late-game cash question: fight (two quarters of
patches, campaigns and price cuts across two topics), buy (most of your
cash for their shelf and share), or sell to them at the premium. Lands year
2–3.

**Touches.** `RivalSystem.found` (an incumbent branch — same draw order,
`worldRNG`); `Rival` (+ `isIncumbent: Bool`, decodes false); `RivalsState`
(+ `incumbentFoundedDay: Int?`); `acquireRival` (absorb
`competingProducts` into `state.products` as `.released`); `RivalsView`
(incumbent card, retreat countdown); `News.json` (two incumbent headlines,
optional). Save: one Bool, one optional Int.

*Balance stays neutral by default:* quarantined from the 19 pacing gates
(`rivalCount = 0`). **Not** quarantined from the investor suite — a funded
bot that crosses $750k could meet an incumbent's challenge inside the
gates' horizon. Ship behind `rivals.incumbentEnabled` (default true) with
the investor suite's first run measured against it off; if any of the 9
gates move, either raise the floor past what the bots reach in two years
or turn the flag off in that suite and measure the incumbent in its own
test.

**Size.** M — 2 engineer-days on top of #1; the acquisition-absorbs-shelf
piece alone is 1 day and stands without #1.

**Risk.** Punishment for success with no payoff — the retreat and the
absorbed shelf *are* the payoff and must ship together. Second: "your two
highest-standing topics" can both be categories whose products are long
off market; the `liveTopicIDs ∩ standing` filter matters. The cheap early
tell: run a `DominatorBot` (CrunchHire that patches and prices budget in
its best topic) and check the incumbent's challenge actually moves share
— if a strength-90 product barely dents a 70-scored player product,
`shareExponent` 2.0 is doing too much and the incumbent is theatre.

**How to verify.** `DominatorBot`, `rivalCount = 4`, 10 seeds: an incumbent
is founded on ≥ 8/10 by day 730; share in the challenged topic drops ≥ 15
points within 8 weeks where the bot ignores it; a bot that acquires the
incumbent ends with ≥ 2 more live products and higher share in those
topics. Unit: an acquired rival's products appear on `state.products` with
`averageReviewScore` within 3 of their quality.

---

### 5. Bet the Tree · S

**The player's sentence.** "The research tree made me pick a side — craft
house or factory."

**Problem.** Finding 5. All upside, cost order is the strategy, the undo is
free. Honest about rank: this is the smallest "major" here, and the one a
player would describe last; it is on the list because research is the one
lane system with a whole screen and no decision, and because the codebase
now gives the two sides something to be right about.

**How it plays.** `TechNode.excludes: [String]`, defaulting to empty so
`TechTree.json` and every save decode unchanged. Three pairs, differently
good, none on `SaaSBuilderBot.path` (`code_reviews, version_control,
automated_testing, agile_sprints, cloud_infrastructure`):

- tier 3: `design_system` (quality) ↔ `telemetry` (speed)
- tier 4: `user_research_lab` (quality) ↔ `internal_tooling` (speed)
- tier 5 falls out by prerequisite: `craftsmanship_culture` needs
  `user_research_lab`, `hyperscale_pipeline` needs `internal_tooling`. The
  factory also forecloses `launch_event` (needs `user_research_lab`) — a
  real cost, and the sheet says so.

The craft house reaches the quality cap (+0.35 = 1.35) and gives up ~0.35
of the +0.80 speed; the factory gives up the cap and the launch event. A
foreclosed sibling greys with "Chose Design System instead"; the Research
button says what it forecloses, the WS-D way. `research.switchRefundFraction`
ships at 1.0 (today) as the knob for making a node a commitment later.

Which studio you are: a category-holder wants the cap for share; a
contract shop or a platform builder wants the 600-point build to go faster.

**Touches.** `TechNode` (one field); `ResearchSystem.startResearch` (one
guard); `GameState.isTechForeclosed(_:)`; `TechTree.json` (three
`excludes` entries, symmetric); `ResearchView.TechNodeRow` (a foreclosed
state), `TechNodeInfoSheet`. Save: none.

*Balance stays neutral by default:* exclusivity only removes options and no
bot path crosses a fork. `GoalCrunchBot` researches the first affordable
node in catalog order (`ProgressionBots.swift:73–80`) and still reaches a
tier-5 node either way (`g5_frontier_research`); `ContentCatalogTests`
asserts `techTree.count == 20`, which this does not change. Add a content
test: every `excludes` is symmetric, same tier, and never names a node on a
bot path.

**Size.** S — 1 engineer-day.

**Risk.** A coin flip if both sides are equally good for everyone. The
tell: if playtesters always pick the same side, the wrong node is on the
other side — swap, don't tune. Verify with a `CraftBot` / `FactoryBot`
pair on 10 seeds: different final `qualityTechMultiplier` and
`devSpeedTechMultiplier`, and neither strictly dominates on final cash.

---

## Rejected

- **The launch window** (hold a finished build for the forecast). The walk
  has no mean reversion and sales read the multiplier live every week for
  ~20 weeks, so a 3-week hold (σ ≈ 0.24 over three shifts) changes almost
  nothing the product's life will not see anyway — a decorated confirm
  dialog with a payroll bill.
- **Named clients / retainers.** Gives contracts memory, but pulls play
  toward the part of the game built to be the dull income floor, and the
  grinder's $10k–$120k band is exactly the gate it would break. #3 gives
  contracts a strategic edge without making them a career.
- **Tech nodes that unlock live-ops mechanics** (telemetry → early sight of
  live bugs, continuous delivery → half-size patches). The right long-term
  shape for the tree, but every unlock is its own mechanic — five small
  features wearing one name, not one feature in one to three days.
- **Sunset / retire a product.** `launchMarketScale` counts off-market
  releases too, so retiring buys only the hosting line ($25–250/week); no
  decision.
- **Competing term sheets.** A richer accept/decline, not a new loop, and
  `equityRemaining − equityAsk ≥ 20` already thins the field late.
- **Rival economies** (simulating rival units and revenue). New subsystem
  under a number the code already calls decorative; #1 and #4 make rivals
  respond without simulating their books.

## Not verified on device

The clock stops at the first pausing event, so the Rivals, Investors and
Market sections and every late-game state were read from code and the
PixelKit/app snapshot previews, not watched. The one thing the simulator
did show unprompted — a price war against a company with no products on day
15 — is finding 1's evidence and #1's first fix.
