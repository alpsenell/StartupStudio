# Company loop — where the founder runs out of verbs

*Fable PM pass, 10 September 2026, read-only over `iteration-15` @ 6660ccc.
Evidence: the engine's `GameAction.swift` (163 cases), the three release
fixtures (`release-garage-day40`, `-studio-day400`, `-campus-day900`),
`Balance.json`, the four bot playbooks in `TycoonBots`, and the studio
fixture photographed on `ws-l1` (Business, Products, Team, HQ tabs).*

**Where I disagree with the brief.** The brief lists verbs a tycoon game
has and this one lacks (platforms, regions, bundles, unions, partnerships).
Most of those are new nodes, and the thin place is not a missing node: it is
that the company loop stops offering decisions once the office is a
studio. The eight ideas below add edges between systems that exist —
products, the cap table, seniority, the wallet, the rivals — and the
new-node verbs are in the cut list with the reason for each.

## Diagnosis

**The week collapses as the company grows.** On the garage fixture (day
40, one founder, one build) a week offers three two-sided choices: ship
now or polish, take a $2–4k contract or keep building, and which of five
candidates to make the first hire. On the studio fixture (day 400, 12
staff, 3 builds in 3 slots, 12 products live, $90,875 cash against a
$20,726 burn) the Business tab shows a price war, a reporter and a crash
(all real), and the week offers about seven: ship-or-polish ×3, the price
war's three answers, patch-versus-new-build for the last slot, hire against
runway, and the pitch room. Everything else on the studio's screens has
one answer: the four contract offers ($2,057–$7,203 against a $20,726
weekly burn — nobody pulls two builders for that), all four amenities are
owned, all three departments are staffed, nothing is being researched
(5 of 20 nodes, `activeNodeID` nil, 2 RP banked), all 12 live products sit
on `standard`, 0 of 12 have ever been patched, and 11 staff each carry
14 relationship verbs on cooldowns that the morning papers already
automate. On the campus fixture (day 900, 36 of 40 desks, 5 builds, 36
products live, $644,446 cash) the week is "ship ×5 and hire to the cap":
all six investor personas have been approached (`approachedInvestorIDs`
= 6, so no term sheet will ever arrive again), contracts are $2,250–$6,854
against a $76,652 burn, the strongest rival (Vantage Point, strength 97)
costs more than the cash on hand to acquire while the minnows are not
worth $130k, and nothing in the company can spend $644k on a decision. The
campus runs at a $17k weekly loss with no sink but payroll. The late game
has money and nothing to buy.

**The product has no lifecycle, the team has no ladder, and the cap table
has one door.** Of 63 released products across the two later fixtures, 0
changed price tier, 0 were patched, 0 were retired by the player; a product
leaves the market only when sales fall under 2% of demand
(`delistFraction`), so on the campus 4 live products earn less than their
own hosting and hold standing 100 in six topics for it. There is no verb to
retire a product, no successor that carries its audience (the codebase is
per *type*, so "v2" of a 235-subscriber SaaS starts at 0 subscribers and
×0.75 saturation), and `setPriceTier` is free and instant so premium at
launch and budget when the copy lands is the whole strategy. On the team,
`SeniorityLevel` is read by exactly three things: output +6% per rank, pay
expectation +12% per rank, and the office-secrets clique picker
(`grep .level`), so `promote` is a raise with a hat and `lead` is a top rung
with no job; the Brooks crowding factor `1/(1+0.1(n−1))` reaches ×0.34 with
twenty people on one build and is printed nowhere in the app (`grep
crowdingFactor App/Sources`: no hits). `fire` is free and keeps the alumnus
warm, `fireWithCause` costs the founder's name, so the plain fire is the
one answer. Money moves from company to founder through exactly one
channel (salary, capped at $5,000/wk, board-read above 1.5× fair) and the
cap table has one way to give equity to a person on payroll — the
networking floor's `.equityHire`, for a contact, never for an employee.
Acquisitions are cash-only at 1.3× the rival's valuation, which is exactly
the deal the one rival worth buying is never affordable for.

## Twenty candidates

| id | name | one line | size | reads | writes |
|---|---|---|---|---|---|
| C1 | Sunset and v2 | Retire a product; ship a successor that replaces it and carries 40% of its book | M | products, standing, hosting, codebase, saturation | `ReleaseInfo.sunsetDay`, `Product.parentID`, subscribers |
| C2 | The dividend | Pay the company's cash out pro-rata; the founder gets `equityRemaining`% of it, the board reads it | S | cash, cap table, board, profitable quarters | wallet, ledger, boardPressure |
| C3 | Leads run the room | A lead you promoted halves the crowding penalty on one build; two leads collide; the crowding factor is printed | M | seniority, assignments, Brooks factor, staff events | output, morale target, `Employee.leadSinceDay` |
| C4 | Options instead of pay | Grant an employee 1–2% for a pay cut; vests over four years; poachers have to buy it | S–M | payroll, loyalty, poach, `EquityGrant`, exits | `Employee.grantedEquity`, `equityRemaining`, salary |
| C5 | Buy them with paper | Acquire a rival with equity instead of cash; their founder takes a board seat | S | rival valuation, own valuation, cap table | `RaisedRound`, contacts, rivals |
| C6 | A price change is news | A rise churns the book, a cut buys one bumper week a quarter; both make the paper | S | price tier, subscribers, copycat, standing | `ReleaseInfo.lastPriceChangeDay`, units |
| C7 | Research forks | Four exclusive pairs after tier 3, each reaching a system the tree never touches | M | research, codebase, live ops, feature board, contracts | `unlockedForks` |
| C8 | Severance or cause | Plain firing pays notice; firing for cause is free and everyone watches | S | fire, alumni, standing, morale, courtroom | cash, moraleAll, name, a claim |
| C9 | Remote company | Give up the office ladder: no rent cap on headcount, bonds grow at half speed | M | office tier, headcount cap, bonds, amenities, city | `company.isRemote` |
| C10 | Sell a product to a rival | Divest one live product for six weeks' revenue; they own the category now | S–M | products, rivals, standing, share | cash, rival shelf, standing |
| C11 | Named clients and the retainer | Clients remember; three great deliveries earn a 26-week retainer for two people | M | contracts, pitch room | `clientBook`, assignments |
| C12 | Hire from a rival by name | Their best person as a candidate at 1.3× with grudge +15 | S | rivals, candidate pool, grudge | candidates, grudge |
| C13 | The office as collateral | An owned office adds to secured credit the way the home does | S | city ownership, credit limit | `guaranteedLoanAmount` |
| C14 | Answer the worst review | Promise the worst outlet a patch inside four weeks; land it and they re-score | S–M | reviews, patches, reputation | review score, reputation |
| C15 | Free tier | A subscription product goes free: no revenue, ×3 acquisition, fame and standing | M | subscribers, fame, standing | price tier, revenue |
| C16 | Follow-on cheque | A seated investor offers a bridge at worse terms when runway is short | S–M | rounds, runway, board | cash, equity |
| C17 | Start a price war | Match without being attacked: budget for four weeks to bleed a rival | S | rivals, share, grudge | strength, grudge |
| C18 | Bundle two products | Two live products in one topic sold as one at ×1.5 | S | products | revenue |
| C19 | Regional launch | Ship a product into a second region with its own market walk | L | market | a second `MarketState` |
| C20 | Platform stores | Choose a storefront per product with fees and reach | L | products, marketing | a new node |

## The top eight

Ranked by play added per engineer-day. Every one is a new action no bot
sends, stores new fields only when set, and draws no `rng`/`worldRNG` word
on the default path unless the note says otherwise.

### 1. Sunset and v2 — M, 3 days

*"Round 6 had 235 subscribers and was tired. I shipped Round 6 v2, retired
the old one the same day, and opened with 94 paying customers instead of
zero."*

**What's thin.** No action retires a product (`GameAction` has none);
`ReleaseInfo.offMarket` flips only when sales fall under
`delistFraction`. A successor of the same type builds on the type's
`Codebase` (35% of the pools, the parent's feature board) but launches
into `launchMarketScale` ×0.75 per recent same-topic release and with
`subscribers: 0`. Iteration 8 deferred "sequels with hype carry-over"; the
iteration-12 company pass ranked sunset-and-successor third and it was not
built.

**What the player does.** Two verbs. `sunsetProduct(productID)` on a live
product: hosting stops, subscribers go to 0, `sunsetDay` is written, the
storefront says *Discontinued*, and the topic loses its live presence, so
standing decays 1.5 a week unless something else is live there.
`shipReplacing(productID, parentID)` on a build of the same type and topic
as a live product: ships as `ship` does, then sunsets the parent the same
day, excludes the parent from the saturation and genre-fatigue counts, and
opens the successor's book with `successorBookCarry` (0.4) of the parent's
subscribers (one-time products instead inherit the parent's `liveHype`).
The ship sheet offers *Replace Round 6* beside *Ship it* whenever a parent
qualifies; the product detail offers *Retire* on any live product.

**The two answers.** Keep the tired product: it holds the topic's standing
(the share floor at 0.55 × standing, forecast access, challenge
eligibility), keeps counting for the awards judge, and costs $40–$250 a
week in hosting. Replace it: the successor skips ×0.75 and opens with 94
subscribers (≈ $2,300 a week from week one against a 42-week acquisition
ramp), but the parent is gone, and if the successor ships poorly the
category is now held by a worse product. Running both is still allowed
and is the third answer: full saturation, no carry, two hosting bills.

**GameState.** `ReleaseInfo.sunsetDay: Int?`, `Product.parentID: UUID?`,
both `encodeIfPresent`. A balance block `successor { bookCarry 0.4,
hypeCarry 0.5 }`.

**Files.** `Product.swift`, `GameAction.swift` (a new region),
`Reducer.swift`, `Systems/ProductSystem.swift` (`sunset`,
`launchMarketScale` skip, `ship` opening book), `StandingSystem.liveTopicIDs`
(already reads `offMarket`), `ProductDetailScreen`, `LaunchDaySheet`
/ the ship confirmation, `StorefrontScreen`, `NewProductFlow` (a "v2 of…"
entry that pre-fills type and topic), the newspaper, `EventCopy`,
`Balance.json`.

**Identity.** New actions only; `ship` keeps its case and bytes. No draws.
Old saves decode both fields nil. The awards judge counts a sunset
product's year as it always did.

**How it fails.** If replace-and-carry always beats keep, every studio
churns a version every six months and the feature is a treadmill. Check
by hand on the studio fixture's Round 6 (SaaS, 235 subs, review 60): the
successor at review 70 with 94 carried subscribers versus the parent's
book decaying at 6% − 3% × 0.6 a week. If the successor wins inside 10
weeks whatever its review, drop the carry to 0.25. Cheapest early tell: a
debug run that replaces on every ship and counts subscribers at day 730
against the never-replace run.

### 2. The dividend — S, 1 day

*"Six investors own 80% of Meridian Labs. I paid out $200,000 and took
$40,000 of it home. Nobody on the board was happy."*

**What's thin.** Company cash reaches the founder through `founderSalary`
alone (cap $5,000/wk, `founderPayBoardPressure` above 1.5× fair). The
campus fixture holds $644,446 with no decision to spend it on; the
founder lives in a studio flat on $200 a week. The iteration-12 systems
pass listed "the founder's cheque book" as a runner-up; nothing was built.
Nothing moves money the other way either (no "put your own money in"), so
a dividend is one-way, which is what makes it a decision.

**What the player does.** `payDividend(amount)` from the money sheet.
The company pays `amount`; the founder's wallet receives `amount ×
equityRemaining / 100`; the rest is distributed to the cap table (the
`EquityGrant` holders and rounds, printed line by line) and leaves the
game. Once per 91 days. Refused while cash after payment would be under
`dividendRunwayWeeks` (8) of burn, in debt, during an earn-out, or inside
a case. With a seated board, `boardPressure += dividendBoardPressure`
(10) unless the last quarter was profitable. The ledger posts it as an
expense, so a quarter carrying a dividend is unprofitable unless it earned
it — which is the cost on the independent ladder, whose ending needs
eight profitable quarters in a row.

**The two answers.** Take it home: the house ($40,000) raises
`guaranteeCapacity` × 0.7 for the company's own secured credit, the
penthouse is $250,000, the life score's home slice is 10 points, the
millionaire goal reads `founderNetWorth`. Leave it: eight more weeks of
runway on a campus losing $17k a week, no board pressure, the
profitable-quarter streak intact. At 20% equity a $200k dividend costs the
company $200k to put $40k in the founder's pocket; at 100% it is the same
money for the same runway, and the streak is the only thing at risk. The
two ladders finally price themselves in dollars every quarter.

**GameState.** `InvestorState.lastDividendDay: Int?` (encode if set).
Balance: `dividend { runwayWeeks 8, boardPressure 10, intervalDays 91 }`.

**Files.** `GameAction.swift`, `Reducer.swift`, `Systems/FinanceSystem.swift`
(post), `Systems/InvestorSystem.swift` (pressure), `Investors.swift`,
`Components/MoneySheet.swift` or `FinancesView` (a row with the split
printed: *You $40,000 · Corvus $36,000 · Helion $44,000 …*), the phone's
office thread, `EventCopy`, `Balance.json`.

**Identity.** New action; the money-sheet row is the only caller. No
draws. Old saves decode nil.

**How it fails.** An independent founder drains the company into the
wallet, where nothing bad happens to it. The runway floor and the
profitable-quarter cost are the brakes; if a debug bootstrapper that pays
the maximum dividend every quarter still reaches *Still yours* on as many
seeds as one that never does, raise the runway floor to 13 weeks.

### 3. Leads run the room — M, 3 days

*"Eight people on Round 15 were each doing 59% of a day's work. I made
Liam lead and the build came in three weeks early."*

**What's thin.** `SeniorityLevel` is read by output (+6%/rank), pay
expectation (+12%/rank) and the clique picker; `promote` is +15% salary
and +15 morale; `lead` has no job. `EmployeeSystem.crowdingFactor` is
`1/(1+0.1(n−1))` — ×0.59 at eight on a build, ×0.34 at twenty — and the
app never prints it; a hire lands on `productInDevelopment` (the first
in-flight build), so the pile-up is the default. `promotionDemand` asks
for a title with no reason in the world for it.

**What the player does.** `promote` to `lead` writes `leadSinceDay`. A
promoted lead assigned to a build halves the Brooks penalty on that build
(0.1 → 0.05) for up to `leadSpan` (6) other people; extras beyond the span
pay the full penalty. A promoted lead on a build with fewer than three
others has nothing to lead: morale target −4 while it lasts. Two promoted
leads on one build cancel each other's relief and make the clique thread
eligible (`OfficeSecretsSystem` already picks senior/junior pairs by
rank). Every build card prints its crew and factor: *8 people · ×0.59
each · lead: none*. `promotionDemand` gains a gate: a senior on a build
with four or more people and no lead, so the ask arrives when it is true.

**The two answers.** Promote Liam (senior, $2,225/wk) to lead for +$334 a
week: the six-person build goes from ×0.67 to ×0.80 each, a 20% throughput
gain, and Liam's pay expectation rises 12% for good. Or hire a seventh pair
of hands at $1,500 that lands at ×0.62 and drags everyone to ×0.62. Or
split the build across slots and promote nobody. And who: the best coder as
lead is the best coder still — but now a lead with no build worth leading
next quarter.

**GameState.** `Employee.leadSinceDay: Int?` (encode if set). Balance:
`leads { penaltyFactor 0.5, span 6, idleMoraleDelta −4 }`.

**Files.** `Employee.swift`, `Systems/EmployeeSystem.swift` (`promote`,
`gatherCrewOutput` / `dailyCodeOutput` per build, morale target),
`Systems/SocialSystem.swift` (event gate), `OfficeSecretsSystem` clique
eligibility (optional), `ProductDetailScreen` crew row, `NowCard`'s
estimate (`ShipETA` already calls `dailyCodeOutput`),
`EmployeeManageSheet` promote copy, `OrgChart`, `Balance.json`.

**Identity.** The relief applies to *promoted* leads only. This matters:
`SeniorityLevel.forSkillTotal` makes a candidate with skills ≥ 210 a lead
at hire, and the campus fixture has three such leads on builds — relief for
hired-in leads would move the investor bots. No bot promotes, so
`leadSinceDay` is never set on the default path. No draws. Old saves: nil.

**How it fails.** If the relief is worth more than the raise, "one lead
per build" is the new one answer. Measure on the campus fixture: promote a
senior on each of the five builds and compare weekly points; over +25%
cut `penaltyFactor` to 0.7. The idle-lead penalty must be a target delta,
not a jump, or it nags.

### 4. Options instead of pay — S–M, 2 days

*"Sofia had two offers. I gave her 1% and cut her pay by a fifth, and
Sable & Co stopped calling."*

**What's thin.** Equity reaches people through three doors — a co-founder
at founding, the networking floor's `.equityHire` (a contact joins for
`equityAsk` and a fraction of salary, recorded as an `EquityGrant`), and an
angel's `.angel` — and never through the Team tab. Poach resistance is
loyalty, bond and salary; the campus fixture's 36 people sit at loyalty
62–65 with bond 0, and a strong rival's poach lands at 35% × resistance
every week.

**What the player does.** `grantEquity(employeeID, percent)` from the
manage sheet, percent ∈ {1, 2}: salary drops by `grantPayCut` (20% / 35%)
of fair pay, loyalty +25, bond +10, and `equityRemaining` falls by the
grant, recorded as an `EquityGrant` with reason `.options`. Vesting: a
four-year schedule with a one-year cliff; leaving before the cliff — quit,
fired, poached — returns the equity; after it, they keep what vested, so a
poached holder takes part of the company with them. The underpaid morale
check reads pay before the cut for a holder. Pool cap `grantPoolMax` (10%)
per run. The button prints the trade at today's valuation: *1% of $2.1M =
$21,000 over four years · pay −$440/wk*. The cap table on the Investors
screen gains a *Team* row.

**The two answers.** Cash now and a locked door: a 20% cut on five
$2,200 seniors is $2,200 a week, a fortnight of runway a year on the
studio fixture, and five people a poacher has to buy out. Or keep the
equity: every point is a point of IPO proceeds (`proceeds = valuation ×
1.4 × equityRemaining`), of the strategic buyout, of the earn-out — and
`Still yours` requires `equityRemaining ≥ 100`, so the first grant closes
the independent ending, exactly as the networking floor's partner hire
already does. The button says so.

**GameState.** `Employee.grantedEquity: Double`, `grantDay: Int?`,
`salaryBeforeGrant: Int?` (encode when non-zero); the existing
`networking.grants` list with a new `reason`. Balance `grants { payCut
[0.2, 0.35], loyalty 25, bond 10, cliffDays 364, vestDays 1456, poolMax 10 }`.

**Files.** `Employee.swift`, `Systems/EmployeeSystem.swift` (fairness,
`adjustSalary` guard), `Systems/RivalSystem.swift` (`poachTarget` weight,
`poachSucceeds` keeps vested), `Systems/NetworkingSystem+Alumni.swift`
(`departed` returns unvested), `Networking.swift` (`EquityGrant.Reason`),
`EmployeeManageSheet` (an *Options* section), `InvestorsView` cap table,
`Balance.json`.

**Identity.** New action; the fairness and poach reads take their old
path when `grantedEquity == 0`. No draws. Old saves decode 0.

**How it fails.** Early, 1% of a $100k company is $1,000 against a real
pay cut, so everybody gets granted and the founder ends at 60% without
noticing. The pool cap and the printed dollar figure are the guard; the
early tell is a CrunchHire bot that grants on every hire and reads
`equityRemaining` at day 730 — under 80 and the pay cut is too generous.

### 5. Buy them with paper — S, 1.5 days

*"Vantage Point cost $840,000 and I had $644,000. I gave their founder
19% and a board seat instead."*

**What's thin.** `acquireRival` is cash only, `1.3 × rival.valuation`,
with own valuation ≥ 1.5× theirs. On the campus fixture the one rival
worth owning (Vantage Point, strength 97, two of the player's topics at
the 0.55 floor) is over the cash on hand while three minnows are
affordable and not worth $130k plus a headcount slot. The buyback verb
(WS-B) already lets a founder remove a seated round at 2.5×.

**What the player does.** `acquireRivalForStock(rivalID)` beside the cash
button on the rival's profile: equity out = `1.3 × theirValuation /
ourValuation × 100`, capped at `stockDealMaxEquity` (25) and at
`equityRemaining − 20`; the dominance gate is unchanged. Their founder
takes a seat: a `RaisedRound` with `amount 0`, the equity, `takesBoardSeat
true`, `expects .shipCadence`, patience 26 — so the board machinery, the
quarterly review and the buyback all apply to them unchanged — and joins
the address book as a `.founder` contact at rapport 60. The shelf and the
hires are absorbed as today.

**The two answers.** Cash: runway gone, no new voice at the table. Paper:
runway kept, 19% of every exit gone, a board member who expects a ship
every quarter and can be bought out later at 2.5× — and the independent
ending closed. A minnow at 3% is cheap paper; a giant at 25% is a merger.

**GameState.** Nothing new: a `RaisedRound` and a `Contact`. Balance
`stockDeal { premium 1.3, maxEquity 25 }`.

**Files.** `Systems/RivalSystem.swift` (`acquireRival` takes a payment),
`GameAction.swift`, `Reducer.swift`, `Systems/NetworkingSystem.swift` (a
contact from a rival's name and `appearanceSeed`), `RivalProfileScreen`
(second button with the % printed), `InvestorsView`, `EventCopy`.

**Identity.** New action; `InvestorBot` sends the cash acquisition only.
No draws (the contact is minted from the rival's existing seed). Old
saves: nothing.

**How it fails.** Paper is always cheaper in cash, so every deal is paper
and the founder bleeds to 20%. The seat is the brake: each stock deal adds
an expectation the review grades. If a debug acquirer bot that always pays
paper is never ousted by day 1095, raise the acquired founder's
`pressurePerMiss` or lower the cap to 15.

### 6. A price change is news — S, 1.5 days

*"I dropped Round 11 to budget the week Ironwood's copy landed and had
my best week since launch. Six months on, raising it back cost me an
eighth of the book."*

**What's thin.** `setPriceTier` is free, instant, and fires only
`.priceChanged`. I1 gave premium a curve at review ≥ 75; J3 noted the open
question "watch whether players switch back when the copy arrives" — they
will, because nothing stops them. Sixty-three fixture products, zero tier
changes.

**What the player does.** The picker becomes a confirmation with the cost
printed. A rise (budget → standard, standard → premium) on a subscription
product churns `priceRiseChurn` (12%) of the book that week; on a
one-time product the next four weeks sell ×0.8 ("people wait for the
sale"). A cut buys one bumper week at `updateSalesBump` (×1.5) and +2
standing, once per 91 days per product — a sale. Changes are 28 days
apart per product. The storefront and the paper print both. A cut during
a category challenge counts as the `.budgetPrice` defense, as it does
today.

**The two answers.** Cut now for the bumper week and the 1.35 share
weight against the copy, knowing the way back costs 12% of the book. Or
hold standard and let the copy take its 26 weeks. Premium at launch is now
a bet that cannot be quietly unwound.

**GameState.** `ReleaseInfo.lastPriceChangeDay: Int?`,
`priceRiseUntilDay: Int?`, `lastSaleDay: Int?` (encode if set). Balance
`pricing { riseChurn 0.12, riseUnitsFactor 0.8, riseWeeks 4, saleBump 1.5,
saleIntervalDays 91, changeCooldownDays 28 }`.

**Files.** `Systems/ProductSystem.swift` (`setPriceTier`,
`postWeeklySales`), `Product.swift`, `Components/LiveOps.swift` (caption),
`ProductDetailScreen` (picker → sheet), `StorefrontScreen`, the newspaper,
`Balance.json`.

**Identity.** Only the player's `setPriceTier` writes the new fields;
every read is gated on them. No draws. Old saves: nil.

**How it fails.** Rises become never-do and cuts a quarterly ritual. Count
changes in playtest saves: if cuts are over 80% of them, drop the bumper
to ×1.25 and the churn to 8%.

### 7. Research forks — M, 4 days

*"After Telemetry I had to choose: Static Analysis for the crunch we run
every launch, or Hot Reload for the refactoring we never do."*

**What's thin.** Unchanged since the iteration-12 pass and still true:
`TechTree.json` is 20 nodes, all upside, order only, 100% refund on
switching; the seven quality nodes sum to exactly the 1.35 cap. Both
later fixtures stopped at 5 nodes with nothing active. `TechNode.Effect`
has four cases and none reaches the codebase, live ops, the feature board
or contracts.

**What the player does.** After any tier-3 node, four exclusive pairs
open in their own `TechForks.json`: Static Analysis (crunch debt ×0.5) vs
Hot Reload (refactoring ×1.6); Crash Reporting (bugs found in the wild
×0.67) vs Canary Releases (patch pool 0.3 → 0.2); Feature Flags (+1 board
slot) vs Design Tokens (synergy ×1.5); Client Portal (contract skill bar
−10) vs Growth Lab (campaign hype ×1.25). Each costs 300–400 RP plus
cash, refunds 50% if abandoned, and locks its partner for the run.

**The two answers.** Each pair is a question about how this company
works: does it crunch or refactor, patch or prevent, ship boards or
synergies, sell to clients or to the public. Priced per quarter before
content is written, for a contract-heavy run and a product-heavy run;
any pair with the same winner in both is redesigned.

**GameState.** `ResearchState.unlockedForks: Set<String>`, encoded when
non-empty. Balance `forks { refundFraction 0.5 }`.

**Files.** `Research.swift`, `Systems/ResearchSystem.swift`,
`Systems/CodebaseSystem.swift`, `Systems/LiveOpsSystem.swift`,
`FeatureBoard.slots`, `Systems/ContractSystem.swift` grading,
`Systems/MarketingSystem.swift`, `ResearchView`, `TechForks.json`,
`ContentCatalog`.

**Identity.** The forks live outside `content.techTree`, which
`ProgressionBots` and `PacingBots` walk by id; every new effect is 1.0
until a fork is unlocked. No draws. Old saves decode an empty set.

**How it fails.** A coin flip. The pricing pass above is the tell; if two
pairs come out even after it, ship the two that did not.

### 8. Severance or cause — S, 1.5 days

*"I let Tariq go with four weeks' pay and he came back a year later,
senior. I fired Ravi for cause to save $6,000 and the whole floor watched."*

**What's thin.** `fire` costs nothing and keeps the alumnus warm at his
bond (the boomerang); `fireWithCause` is free, closes the boomerang and
adds +6 to the founder's name. So plain firing is strictly better and the
with-cause verb exists for the office-secrets' harshest answer. No bot
fires (`grep .fire TycoonBots`: none). A layoff of six people is six free
taps.

**What the player does.** Plain `fire` pays notice: `min(4, tenureWeeks /
13)` weeks' salary — one week for a three-month hire, four for a
year-old one — refused when unaffordable; `moraleAll` 0; the alumnus
stays warm. `fireWithCause` stays free but the room sees it: `moraleAll
−4`, the name +6 (exists), the alumnus lost (exists), and when the person's
morale was above 50 a wrongful-dismissal claim with `socialRNG` at 20%
(drawn only on the player's act): a demand for eight weeks' pay, settled
or fought in N1's courtroom with the founder as defendant. A *Let people
go* sheet on the Team tab picks several at once: severance totalled,
`moraleAll −2` per person capped at −10, reputation −1 per three, the
headcount board expectation reads it as a miss.

**The two answers.** Pay the notice out of the cash that is the problem,
keep the door open and the name clean. Or cut for free and wear it: a
floor that watched, a name recruiters repeat, a one-in-five claim. On the
studio fixture with four weeks of runway, letting three mid-level people
go costs $18,000 in notice or $0 and −12 morale across the nine who stay.

**GameState.** Nothing new stored beyond the crime system's existing
case. Balance `severance { maxWeeks 4, weeksPerQuarterTenure 1,
causeMoraleAll −4, claimChance 0.2, claimWeeksPay 8 }`.

**Files.** `Systems/EmployeeSystem.swift` (`fire`),
`Systems/InteractionSystem.swift` (`fireWithCause` path),
`Systems/CrimeSystem.swift` (a civil case with a settlement),
`FounderStanding.swift`, `EmployeeManageSheet` (two priced buttons),
`TeamScreen` (the layoff sheet), `EventCopy`, `Balance.json`.

**Identity.** No bot fires; the claim draws only when the player fires
with cause. Old saves: nothing.

**How it fails.** At the garage, four weeks of a $1,200 junior against
$12,000 starting cash makes a bad first hire unrecoverable — the tenure
taper is for that. If the claim lands too often, with-cause becomes
never-do and the choice is gone; 20% is a guess to be watched.

## Cut, and why

- **C9 Remote company** — a real replay lever using numbers that exist
  (`remoteBondGrowthFactor`, `officeMoraleBonus`, the headcount cap), but
  rent is $1,800 against $17,000 of payroll at the studio so the money side
  is weak, and it touches the office scene, the city, amenities and every
  office-tier gate. Four days for a second office path; revisit after
  C3 gives the office a reason to be a room.
- **C10 Sell a product to a rival** — clean and cheap, but on the
  fixtures the products worth selling are the ones holding standing, and
  C1 already prices "give up the category" without handing a rival a
  quality-70 product for six weeks' revenue.
- **C11 Named clients and the retainer** — contracts pay $2–7k against a
  $20–77k burn from chapter 3 on; a retainer worth taking needs contract
  pay to scale with headcount, which re-pins the bots' contract tables.
  The garage's safety net can stay a safety net.
- **C12 Hire from a rival by name** — rivals have no named staff;
  espionage's poach-with-dirt and the NDA poach already cover the verb.
- **C13 The office as collateral** — buying the office is already the
  better deal once affordable (tax $540/wk against rent $1,800 on the
  studio); adding credit makes it more one-answer, not less.
- **C14 Answer the worst review** — a promise the patch system mostly
  keeps already; the re-score is pure upside unless the promise can be
  broken, and J5's slip mechanics do that better for a whole launch.
- **C15 Free tier** — needs a fourth revenue model, a conversion state and
  fame plumbing for one product type's late game.
- **C16 Follow-on cheque** — the shark door (J1) already answers "four
  weeks of runway"; a second lender at worse terms is the same sheet.
- **C17 Start a price war** — J3's Match answer is this verb, reactive;
  proactive it is "bleed a rival for margin" with no new cost.
- **C18 Bundle** — the player's own products never compete for demand, so
  a bundle is ×1.5 revenue for a tap. Pure upside.
- **C19 Regional launch, C20 Platform stores** — new nodes, a second
  market walk or a fee table, and the pacing bots sell into the market
  that exists. Nothing they add is a decision the topic map and the six
  product types do not already ask.
- **Self-cannibalisation** (your own products splitting a topic's demand,
  which is why 49 web apps into six topics is the campus fixture's winning
  play) — true and the deepest fix, but it moves every pacing bot that
  ships twice into one topic and cannot be gated on a player action.
  Recorded here for the day a re-pin is on the table; C1 is the playable
  half.
- **Unions, remote per person, lawsuits, buybacks, being acquired,
  earn-outs, co-founders** — all exist (`officeUnion`, `remoteRequest`,
  `sueRival`, `buyBackRound`, `acceptBuyoutEarnOut`, the co-founded
  origin). Not proposed.
- **Customers as an entity, a CRM, support tickets** — support is an
  assignment with a churn number; a customer object is scaffolding for a
  screen with one answer (staff it).

## If you build one thing

C1, because it gives the product a lifecycle and the campus's 36 live
products a reason to be looked at. If you build one cheap thing, C2: one
day, and the two ladders finally show their difference in dollars every
quarter.
