# Iteration 17 — PM lens: wave two and the systems that read each other

*Read-only pass over `iteration-17` @ 8051373 (= main, build 426), 13
September 2026. Two halves: (a) the wave-two list from `iteration-15-verbs.md`
re-ranked against what iterations 15 and 16 actually built; (b) the joins
missing between the seventeen new verbs, and the one-answer defaults the
lanes' own measurements exposed. No simulator run was made; every claim is a
count from the tree, the fixture JSON or a lane report, and the last section
says which ones a lane should measure first.*

**Where I disagree with the brief.** The brief frames this round as the
player's wish list. From this lens the wish a forum would actually post is not
a new verb — it is "why did nothing happen when I…": I granted options and
sold the company; I lent the company money and sold it; I went on holiday over
launch day; I fired my wife. Those are joins, they are half-day fixes, and they
add more play per day than any wave-two item except severance. The wave-two
list is re-ranked below as asked, but four of the top eight are joins.

## Diagnosis

**Wave two, against the tree as it is.** `GameAction.swift` has 189 `case`
lines now (163 cases when the list was written). Of the seven open items,
three premises moved. *Own the home* (F8) was waiting for six-figure wallets;
the four fixtures' wallets are $2,400, $5,040, $2,555 and $18,400, and K1's
dividend gives a campus founder about $8k a quarter — but the office's own
`city.buyPriceFactor` is 150 weeks of rent, and at that price a studio flat is
$12,600 in the Suburbs and $18,000 in Old Town, one dividend away, while a
house is $73,500–$231,000; the premise inverted rather than arrived. *The
all-nighter* (A5) assumed the founder's points matter; `gatherCrewOutput`
gives the founder `founderOutputMultiplier` (0 while away, vitality-scaled)
as one producer among the crew, so on the campus's seven-person builds a ×3
night is at most two extra shares of seven, +29% of one build's day, and on
the studio's four-person builds +50% — still a verb, but a studio verb.
*Remote company* (C9) now competes with four systems that assume a room:
seating, the break, the desks row and the move down; and `remote_friendly`
already exists as a staff policy (`remoteBondGrowthFactor` 0.5,
`remoteConflictWeightFactor` 2). Two premises are unchanged and still thin:
*severance or cause* (C8) — `EmployeeSystem.fire` is nineteen lines and costs
nothing, `fireWithCause` closes the alumnus, zeroes their rapport and adds to
`FounderStanding.name`, so the plain fire strictly dominates, and S2's refusal
"Let 6 people go first" now points at six free taps with no sheet; and
*research forks* (C7) — `activeNodeID` is nil on all four fixtures, three of
them sit at 5 of 20 nodes, and every node is still upside. *Draft the chapter*
(A6) holds: `Goals.json` deals exactly six goals per chapter on either track
(chapter 3: 2 shared + 4 per track; 4: 6 per track; 5: 4 + 2), and
`goalsToAdvanceChapter` is 4, so the card is still a checklist. *The street*
(A7) holds: `epilogue` is read at 31 sites and every one is a guard. Of the
owner calls: the sign is dominated wherever a strategic buyer exists (K4's own
numbers: unsolicited offers at 2.12×, 1.62× and 1.98× in weeks 3, 7 and 20 on
the campus, 2.48× in week 1 on the studio, against an ask that tops out at
1.6×) and a one-line cap after `buyoutCheck`'s draws fixes it; there is no
shelve verb (`cancelResearch` and `abandonSideProject` are the only cancels);
rivals' product names are bytes in four fixtures, so moving them is a re-pin
round and adds no play; the city's 15 ms first compose per hour is not a play
problem.

**The joins.** Audited and fine: a sunset product reaches the judge (by launch
year), the hall (`hallEntries` keeps history) and the league (net worth reads
a valuation that excludes off-market books); the sign, the door desk and the
unvested options all land in `RivalSystem.poachTarget`/`poachCheck` and
compose; the map prints the home commute (K6, S4); a downgrade reaches rent,
the cap, slots, hiring gates and the scene. Missing, each with a consequence
the player can see: (1) `networking.grants` is read by three files — `Ladder`,
`FounderMoney`, `Networking` — and by no ending: `fileIPO` pays
`valuation × equityRemaining / 100` and `acceptBuyout` puts the price into
company cash, so the holder page's "1% of $2,151,053 = $21,511 over four
years" is paid by nothing. (2) `directorLoan` is read by two lines, the
valuation (as a liability) and the term sheet (repaid), so a founder who lent
$25,000 and then sold, sold up or listed gets a price lowered by the loan and
never gets the loan. (3) `ProductSystem.ship` reads `founderAway` nowhere; a
launch inside a vacation, a family holiday or a sabbatical is byte-identical
to one at the desk, while K7's *Keep the date* already built "no party, hype
×0.85". (4) K2's "Or a v2 of…" flow pre-fills a name and writes no
`parentID` — it is written only by `shipReplacing` — so a v2 shipped beside
its parent is two independent books, which is exactly why K2 measured that
running both beats replacing (Σ$122k against $74k at week 10). (5)
`EmployeeSystem.fire` on `partnerEmployeeID` removes the roster row and leaves
the marriage untouched; `RelationshipSystem.run`'s safety net only fires when
the founder is already single. (6) The seating preview prints the skill gain
(+3.6 a week) and not what the gain does to `fairWeeklyPay` (reads
`skills.total`) or to the poach score (`poachSkillWeight × skills.total`) —
the cost that would make "mentor by the flight risk" a real alternative is
already computed by the engine and printed nowhere. (7) The partner's morale
target reads the founder's dividend take as pay (`founderPayExcess`) although
it landed in their own household — small, listed for completeness.

## Twenty candidates

| id | name | one line | size | reads | writes |
|---|---|---|---|---|---|
| J1 | The exit reads the options | Vested holders are paid from the price; the unvested are the founder's call — accelerate or let them lapse | S–M | grants, vesting, buyout/IPO/sell-up, earn-out | wallet, holders' pay, `optionsLapsedDay` |
| J2 | The exit repays the director | A buyout, sell-up or IPO repays the director's loan before the split, as the term sheet already does | S | `directorLoan`, the three exit paths | wallet, ledger |
| W1 | Severance or cause | Plain firing pays notice; for cause is free and the floor watches; a *Let people go* sheet answers S2's refusal | S | fire, tenure, alumni, standing, S2 refusal, K3 unvested | cash, moraleAll, name, a claim |
| J4 | The v2 cannibalises its parent | A declared v2 shipped beside its parent halves the parent's acquisition and raises its churn; the ship dialog says so | S | `parentID`, postWeeklySales, the ship dialog's third answer | `parentID` at start, subscribers |
| J3 | The launch reads the founder away | A ship day inside a week away: no launch party, hype ×0.85, and the weekend card says which launch it is | S | ship day, isAway, K7's keep-the-date machinery, K6 holidays | hypeAtLaunch, the vice week |
| O1 | The sign caps the market | While a sign stands nobody pays more than the ask; the card prints the windfall you are giving up | S | `buyoutCheck` (after the draws), listing | pendingBuyout amount |
| J5 | The lesson's price | The seating preview prints what a taught skill does to fair pay and the recruiters' list; a taught junior who crosses a rung asks for the promotion | S | seating preview, fairWeeklyPay, poach score, promotionDemand gate | nothing new (a demand event) |
| O3 | Shelve a build | Put an in-flight build in the drawer: the slot frees, hype is gone, an announced date slips, progress decays a tenth a quarter | M | slots, S2 refusal, announce slips, crew morale, K2 replace | `DevProgress.shelvedDay` |
| J6 | Home districts read the map | Far pairs re-cut to the drawn map; tonight's room in your district costs no evening; a schoolchild in the Suburbs gains bond | S | home.farPairs, S4 rooms, child stage | `home.farPairs`, evenings |
| W2 | The street | An earnings call every quarter after the bell: beat it and a dividend lands, miss three and the shareholders replace you | M | epilogue, profit, valuation | `Epilogue.premium/misses` |
| W5 | Own the home | Buy the flat at 150 weeks of the district's rent: no rent, 70% as secured headroom, half of it in a divorce; the mortgaged origin decodes as owned | M | wallet, homeDistrict, guaranteedLoanAmount, settlement | `life.homeOwned`, net worth |
| W3 | The all-nighter | Hold the whiteboard on one build you are on: your points ×3 tonight, the body pays, bugs come with it | S | founder skills, energy, health, partner | `life.allNighter`, meters |
| J7 | Firing the partner is a fight | Fire your spouse and the marriage reads it: −25 affection, −40 with cause and *Pack a bag* the next morning | S | fire, partnerEmployeeID, family drama | affection, a confrontation |
| J8 | The dividend reaches the holders' desks | A holder who gets a dividend line gains morale and loyalty that week; non-holders keep resenting the take | S | dividend split, grants | morale, loyalty |
| W4 | Draft the chapter | Keep four of the six goals dealt; the chapter opens on those four and the other two are gone | S–M | Goals.json, track, ProgressionState | `draftedGoalIDs` |
| W6 | Research forks | Four exclusive pairs after tier 3, each reaching a system the tree never touches | M | research, codebase, live ops, contracts | `unlockedForks` |
| J9 | The downgrade reaches the recruiters | A move down leads the paper and raises poach odds for the drag's thirteen weeks | S | officeDowngraded, poachCheck | nothing new |
| O2 | Rivals use the name generator | Rival studios name products from `ProductNames.json` | S | ProductNameGenerator, worldRNG | rival product names (re-pin) |
| W7 | Remote company | Give up the office: no headcount cap, bonds at half speed | M–L | office tier gates, seating, amenities | `company.isRemote` |
| O4 | Pre-warm the city compose | Compose the next hour's ground plate before the clock reaches it | S | CityMapSceneCache | nothing |

Ranked by play added per engineer-day. The top eight follow; 9–20 are ranked
in the table's order, and the last four are the cut list's.

## The top eight

### 1. J1 + J2 — The exit reads the options, and repays the director (S–M, 1.5 days)

*"Meridian paid 1.5×. Priya's 2% had vested; it came out of the price. Tariq's
1% had eight months to the cliff. I could pay him $32,000 of mine, or let it
lapse — and the earn-out needs him."*

**What's thin.** `networking.grants` is read by `Ladder.swift`,
`FounderMoney.swift` and `Networking.swift` and by no exit path. `fileIPO`
pays the founder `valuation × equityRemaining / 100` (the granted points are
already outside `equityRemaining`, so the money simply does not exist), and
`RivalSystem.acceptBuyout` does `company.cash += offer.amount` and ends the
run. The holder sheet, the cap table's Team row and the grant button all
print a dollar figure at today's valuation that nothing ever pays. In the same
paths `directorLoan` is a liability in `companyValuation` (`GameState.swift:1721`)
and is repaid only by a term sheet (`Investors.swift:624`), so lend-then-sell
pays the founder a lower price *and* eats the loan.

**What the player does.** Nothing new to tap for the vested and the loan: at
an acquisition, a sell-up or an IPO the director's loan is repaid to the
wallet first, then every vested option point is paid its share of the price
(the founder's share is unchanged — those points were never theirs). The
unvested points are a row on the buyout and sell-up sheets, before the tap:
**Accelerate** (the unvested vest today and are paid; the founder's proceeds
fall by `unvested × price / 100`) or **Let them lapse** (the points return to
the founder and are paid to them). At an IPO the unvested lapse and the sheet
says so — with no company to keep, there is nothing to buy with them.

**The two answers.** Accelerate: on the campus with `-autoLadder`'s 3 points
out and a 1.5× bid on $2.15M, about $97,000 off the founder's $645,000 — 15%
of the cheque — and a team that arrives at the acquirer whole. Lapse: the
money stays yours; during an earn-out (`acceptBuyoutEarnOut`) every lapsed
holder is a quit at the next weekly pass (loyalty 0, `NetworkingSystem.departed`
with `.quit`), and the acquirer's `shipCadence`/`headcount` expectation reads
the hole. With no earn-out, lapsing is free — and the sheet says "They will
not be coming with you", which is the founder's name at the next hire's ask
(`FounderStanding.name` +2 per lapsed holder, the same read as with-cause).

**GameState.** `Employee.optionsLapsedDay: Int?` (decode-if-present, encoded
when set; read by the earn-out's weekly pass and the standing). Balance
`ladder.exit { lapsedNamePenalty 2 }`. No new draw.

**Files.** `Systems/RivalSystem.swift` (`acceptBuyout`'s tail: loan, vested,
the answer), `Systems/InvestorSystem.swift` (`fileIPO`, `acceptBuyoutEarnOut`),
`Deals.swift` (the sell-up price pays the loan first), `Ladder.swift` (a
`ladderExitSplit` query the sheets print), `FounderStanding.swift`,
`GameAction` (`acceptBuyout(accelerate:)` — a new branch on the old case gated
on a new argument with a default, so the bots' `acceptBuyout` is unchanged),
`Components/DecisionSheet.swift` (the buyout sheet's row), `DealViews.swift`
(the sell-up sheet, the sign card's holder line), `PostMortem.swift`.

**Identity.** `grants` is empty on every bot and fixture (K3: none grants), so
every new payout is exactly $0 and the loan is 0. `acceptBuyout` with the
default argument is the old path.

**Old saves.** One optional field.

**How it fails.** The unvested points are pennies and accelerating is the one
answer. K3's bots kept 2–6 points out; on a 20%-equity campus founder 3 points
are 15% of the cheque, on a 100% garage founder 3%. Cheap check first: price
the acceleration on the studio (60% equity, valuation $572k) at a 1.0× bid; if
it is under 5% of the founder's proceeds, make the lapse bite harder — the
earn-out's patience reads each lapsed holder as a missed review.

### 2. W1 — Severance or cause, and the layoff sheet (S, 1.5 days)

*"The Loft has six desks and I have twelve people. Six weeks of notice was
$21,000, or none, and the six who stayed watching."*

**What's thin.** As C8 wrote it and still true: `EmployeeSystem.fire`
(`:1199`) removes the row, keeps the alumnus warm and costs nothing;
`fireWithCause` (`InteractionSystem.swift:341`) does the same and then zeroes
the contact, sets the estranged flag and adds to the founder's name. So the
plain fire is strictly better and the with-cause verb is the office-secrets'
harshest answer only. New since: S2's move down is refused with "Let 6 people
go first" on the studio fixture, and there is no sheet to go to — six manage
sheets, six free taps. K3's `ladderSettleOptions` already runs on every fire.

**What the player does.** Plain fire pays notice — `min(4, tenureWeeks / 13)`
weeks of salary, refused when the cash is short — with `moraleAll` untouched
and the alumnus warm. For cause stays free and the room sees it: `moraleAll`
−4, the name +6 (exists), the alumnus lost (exists), and when their morale was
over 50 a wrongful-dismissal claim at 20% (drawn from `socialRNG` only on the
player's tap): eight weeks' pay, settled or fought in the courtroom. A *Let
people go* sheet on the Team tab (and as the target of S2's refusal) picks
several: severance totalled, `moraleAll` −2 a head capped at −10, reputation
−1 per three, and a seated board with a `headcount` expectation reads the
week as a miss.

**The two answers.** Pay the notice out of the cash that is the problem and
keep the door open; or cut for free and wear it — a floor that watched, a name
recruiters repeat, a one-in-five claim. On the studio at four weeks of runway,
three mid-levels are $18,000 or $0 and −12 morale on the nine who stay; the
move down's $2,450 a week saved now has a price before it.

**GameState.** Nothing new beyond the crime system's existing case. Balance
`severance { maxWeeks 4, weeksPerQuarterTenure 1, causeMoraleAll -4,
claimChance 0.2, claimWeeksPay 8, layoffMoralePerHead -2, layoffMoraleCap -10 }`.

**Files.** `Systems/EmployeeSystem.swift` (`fire` gains the notice; the old
free path stays for the bots behind a defaulted argument), `Systems/InteractionSystem.swift`,
`Systems/CrimeSystem.swift` (a civil case with a settlement), `FounderStanding.swift`,
`Screens/Team/EmployeeManageSheet.swift` (two priced buttons), `Screens/Team/TeamScreen.swift`
(the layoff sheet), `Screens/HQ/OfficeDowngradeRow.swift` (the refusal opens
the sheet), `EventCopy`, `Balance.json`.

**Identity.** No bot fires (`grep .fire TycoonBots`: none — re-check before
building); the claim draws only on the player's with-cause tap. The notice is
a new branch gated on the action's new argument.

**Old saves.** Nothing new to decode.

**How it fails.** At the garage, four weeks of a $1,200 junior against
$11,750 starting cash makes a bad first hire unrecoverable — the tenure taper
(one week per quarter served) is for that; a three-month hire costs one week.
If the claim lands too often, with-cause becomes never-do; 20% is a guess.
Cheap check first: fire every employee on the studio fixture plain and with
cause and total both columns; if the with-cause column's expected claim cost
exceeds the notice column, halve the chance.

### 3. J4 — The v2 cannibalises its parent (S, 1 day)

*"Round 6 v2 shipped beside Round 6. The old one lost 26 subscribers a week to
it. I retired it in the spring; the book had mostly walked over anyway."*

**What's thin.** K2's measurement: replacing never beats keeping inside a
year on the studio's Round 6, and the third answer — ship the v2 beside the
parent, no carry, both bills — wins outright (Σ$122k against $74k at week 10)
"because the player's own products do not split demand". The PM's cut list
called self-cannibalisation the deepest fix and unbuildable, since it moves
every bot that ships twice into one topic. The gap the lane left: the "Or a v2
of…" chips pre-fill type, topic, codebase and "Round 6 v2" and write nothing;
`Product.parentID` is written only by `shipReplacing`.

**What the player does.** The "v2 of…" chip writes `parentID` on the build at
`startProduct` (a new optional argument, nil from every other caller). When a
build with a `parentID` ships by plain *Ship it* and the parent is still live,
the parent becomes "the old version": weekly acquisition ×0.5 and churn ×1.5
in `postWeeklySales`, from launch day until it is retired. The ship dialog's
third answer prints it before the tap — "Running both: Round 6 keeps its 235
subscribers and its bill, and loses about 26 a week to its v2" — and the
parent's lifecycle card says why the line is falling.

**The two answers.** Replace: 40% of the book carries, the parent is off the
shelf, one hosting bill. Run both: two bills, the parent's book walks over on
its own timetable, the parent still holds the topic's standing while it sells.
Neither dominates: K2's table shows a review-80 successor overtakes a kept
parent at week 19; with the parent decaying under it, the crossing moves to
about week 8 and the cumulative crossing inside the year. The check below
pins it.

**GameState.** `Product.parentID` written at start (already optional, already
encoded only when set).

**Files.** `Systems/ProductSystem.swift` (`startProduct` takes `parentID`;
`postWeeklySales` reads `lifecycleParentDecay`, exactly ×1 with no parent),
`Lifecycle.swift` (the query and the sentence), `GameAction` (`startProduct`
gains a defaulted `parentID`), `NewProductFlow` (the chip passes it),
`Screens/Products/Lifecycle/LifecycleViews.swift` (the ship dialog's third
answer, the card's line), `Balance.json` `lifecycle { parentAcquisition 0.5,
parentChurn 1.5 }`.

**Identity.** No bot starts a product with a parent; `startProduct`'s old
shape is the default. Every read of the decay is gated on `parentID`, which no
fixture carries.

**Old saves.** Nothing new.

**How it fails.** The decay is so steep that replacing becomes the one
answer. Cheap check with K2's scratch harness: Round 6 at ×0.5/×1.5 under a
review-60 v2 beside it, Σ at weeks 10, 20 and 52 against replacing at carry
0.4; if replace wins at every review score, soften to ×0.7/×1.25.

### 4. J3 — The launch reads the founder away (S, 0.75 day)

*"Booked the family holiday. The card said Round 9 ships on the Thursday: no
party, hype ×0.85. Went anyway."*

**What's thin.** `ProductSystem.ship` reads nothing about the founder's
whereabouts; `founderOutputMultiplier` is 0 while away, so the build slows,
but the launch day itself — the review roll, the hype, the launch-day sheet,
the launch party's vice gain in `AssetsSystem.runViceWeek` — is byte-identical
whether the founder is at the desk or in a hospital bed. K7 built the exact
consequence for the diary (*Keep the date*: no party, `keepDateHypeFactor`
0.85, the vice gain taken back) and K6 built the week away with the family;
neither reads the other.

**What the player does.** On a ship day with `life.isAway`, the launch goes
out without its founder: `hypeAtLaunch × 0.85`, no launch-party vice gain, and
the launch-day sheet opens when they are back with "You were away for this
one." Before the tap, every away row — vacation, family holiday, sabbatical,
the networking weekend — prints the clash from the Now card's ETA: "Round 9
ships on day 4 of the week away · hype ×0.85, no party", or nothing when
nothing is due. (Burnouts and hospital stays are not chosen and pay the same
price silently — that is what the doctor's letter is for.)

**The two answers.** Go: the holiday's +25/+40 energy, +20 affection, the
children's +8, and a launch at 85%. Stay: the launch whole and the week's
family cost as printed; or switch to chill for a week to push the ETA past the
holiday, which is the pace switch finally having a reason on the weekend card.

**GameState.** Nothing new: `isAway(day:)` and `awayReason` exist; the vice
subtraction reuses K7's marked pair keyed on a new `.launchWhileAway` event.

**Files.** `Systems/ProductSystem.swift` (one marked factor beside K4's on the
hype line, exactly ×1 at the desk; the event), `Systems/AssetsSystem.swift`
(K7's pair counts the new event too), `Screens/Life/WeekendCard.swift` and the
sabbatical sheet (the clash line, from `BuildETA`), `Components/LaunchDaySheet.swift`
(the sentence), `EventCopy`, `Balance.json` `partner.awayLaunchHypeFactor 0.85`.

**Identity.** Bots plan weekends (`WeekendActivity` rolls) and ship, so a bot
*can* ship while away — this is the one item that touches the default path.
Two options: gate the factor on `doors.armed` the way K1's rescue is (clean,
the K1 precedent); or measure first — if no pacing seed ever ships inside a
vacation week, the factor is inert on the suites and the gate is unnecessary.
The lane measures, then gates if it must.

**Old saves.** Nothing new.

**How it fails.** Launches never fall inside a planned week away, and the
line never prints. K7 counted 1.0–1.8 launches within ±1 day of a diary date
per run; a week away is seven days on a campus with five builds. Cheap check:
over the ten pacing seeds, count ship days inside a vacation; under one per
run, keep the print and drop the hype factor to a party-only cost.

### 5. O1 — The sign caps the market (S, 0.5 day)

*"I hung the sign at 1.2×. Vantage Point would have paid 2.1× a month later.
The card told me so."*

**What's thin.** K4's finding, in K4's words: "wherever the sign has a
strategic bidder, waiting beats every sign bid." `buyoutCheck` keeps rolling
1.5–2.5× unsolicited offers every four to six weeks on every late fixture
whether or not a sign stands, and the ask tops out at 1.6×. So the sign pays
only for a company nobody courts, and for everyone else the right answer is
never to hang it.

**What the player does.** While `rivals.listing` is set, an unsolicited
strategic offer is capped at the ask: `amount = min(amount, listing.askingPrice)`,
one line after both draws in `buyoutCheck`, so the world stream is untouched.
The sign card prints the other side before the tap: "While the sign stands
nobody pays more than your ask. Without it, Vantage Point has paid 1.5–2.5×
when it came." The take-down button prints the reverse.

**The two answers.** Hang the sign: a sale on your clock at a number you
named, and the windfall closed. Wait: the office calm, a possible 2× that
comes when the market says, and possibly never (K4: the sign pays only under
reputation 60 or with no rival worth 2× of you).

**GameState.** None.

**Files.** `Systems/RivalSystem.swift` (`buyoutCheck`, one marked line after
the multiplier), `Deals.swift` (a query for the card), `Screens/Business/Deals/DealViews.swift`.

**Identity.** `listing` is nil on every bot and fixture; the line is
`min(x, ∞)`.

**Old saves.** Nothing.

**How it fails.** The cap makes the sign never worth hanging (a windfall
foregone for nothing), and the one answer flips. Cheap check on K4's harness:
the expected wait for an unsolicited ≥1.5× offer on the campus and the studio;
if it is under eight weeks on both, raise `askMax` to 2.0 so a patient sign
can reach the market's own number.

### 6. J5 — The lesson's price (S, 0.75 day)

*"Sofia teaches Emeka +3.6 a week. In a quarter that is $60 more a week he is
owed, and he is the one the recruiters call."*

**What's thin.** S1's own measurement: "the choice is *who* learns and
*whether to pay*, not *where*; the arithmetic favours teaching." The merge
halved `mentorGainScale` to 0.5, which slows the lesson and does not change
its sign. The cost that would make "mentor by the flight risk" a real
alternative already exists in the engine — `fairWeeklyPay` reads
`skills.total`, so a taught junior's fair pay rises and the underpaid morale
cause opens; `poachTarget` scores `poachSkillWeight × skills.total`, so the
student climbs the recruiters' list — and the seating preview prints neither.
An informational join, plus one mechanical one.

**What the player does.** The preview and the Desk section print the lesson
in full: "Sofia teaches Emeka coding +3.6/wk · his fair pay +$14/wk and rising
· he moves up the recruiters' list". The mechanical half: a taught employee
whose skills cross the next rung's bar asks for the promotion through the
existing `promotionDemand`, eligible only for people with a seat in the map
(so nothing changes on the default path, K3's own gating precedent).

**The two answers.** Teach the junior: a stronger team that costs more and is
more poachable, and a promotion ask you now have to answer. Seat the mentor by
the flight risk instead: bond, no lesson, the mentor at full output. Seat the
mentor alone: nothing learned, nothing owed.

**GameState.** Nothing new.

**Files.** `Seating.swift` (`seatingPreview` gains the pay and poach lines),
`Systems/SeatingSystem.swift` (the weekly lesson raises a `promotionDemand`
eligibility flag for seated students, read by `SocialSystem`'s gate the way
K3's is), `Screens/HQ/SeatingViews.swift`, `EmployeeManageSheet` (the Desk
section).

**Identity.** Print-only for the first half; the second is gated on
`seatingIsSet`, empty everywhere.

**Old saves.** Nothing.

**How it fails.** The pay line is pennies (+3.6 a week on a skill is a few
dollars of fair pay) and the print changes nothing. Cheap check: on the studio,
`fairWeeklyPay` for Emeka now and at +94 skill points (26 weeks of the shipped
0.5 lesson); under $50 a week, drop the pay line and keep the recruiters' line
and the promotion ask.

### 7. O3 — Shelve a build (M, 1.5 days)

*"Round 17 was six weeks from done and Brightwater had just taken the topic.
I put it in the drawer. The date I had announced slipped in print."*

**What's thin.** S2's refusal says "Ship N builds first" because there is no
way to stop a build; the studio fixture is refused on two counts and one of
them is a build. The only cancels in `GameAction` are `cancelResearch` and
`abandonSideProject`. The ship dialog's answers are ship now or polish; a
build in a topic a rival just took, or a build the crew is needed off, has no
third answer but finishing it.

**What the player does.** *Shelve* on the build card and the product page: the
slot frees today, the crew goes idle, the build's hype goes to 0, an announced
date slips through `AnnounceSystem.slip` (the first slip's reputation cost and
its hype share; a second voids it), the crew on it lose 3 morale, and the
progress is kept — decaying a tenth a quarter while shelved (`DevProgress.shelvedDay`
read by a weekly pass). *Take it off the shelf* into a free slot resumes it.
The button prints all of it: "Frees a slot today · hype 42 → 0 · the announced
date slips (−3 reputation) · 4 people idle · progress 71% keeps, −7%/quarter".

**The two answers.** Shelve: the slot for the patch, the v2 or the move down,
at the price of the announcement, the hype and the crew's week. Finish it: the
slot stays busy and a saturated launch goes out. Ship early: the existing gate
(`daysToShippable`), at the quality it has.

**GameState.** `DevProgress.shelvedDay: Int?` (decode-if-present, encoded
when set). Balance `shelve { crewMorale -3, decayPerQuarter 0.1 }`.

**Files.** `Product.swift`, `Systems/ProductSystem.swift` (`shelveBuild`,
`unshelveBuild`, the weekly decay; `buildsInFlight` and the six in-flight
reads exclude shelved builds), `Systems/AnnounceSystem.swift` (the slip on
the action), `OfficeDowngrade.swift` (the refusal counts unshelved builds and
says "Ship or shelve N builds"), `GameAction`, `Reducer`, `Screens/Products/**`
(the button, a *Shelved* section), `NowCard` (a shelved build is not the Now
build), `EventCopy`.

**Identity.** Only on the action; `shelvedDay` nil everywhere. The
`buildsInFlight` filters read `shelvedDay == nil`, true for every existing
build.

**Old saves.** One optional field.

**How it fails.** Shelving is always better than shipping a bad build — free
the slot, keep the progress forever, never launch into saturation. The decay
and the slip are the brakes. Cheap check: on the three fixtures count in-flight
builds whose forecast review (the frozen `ShipForecast`) is under the topic's
rival average; if it is most of them, the drawer is the new one answer and the
decay doubles.

### 8. J6 — Home districts read the map (S, 1 day)

*"The Suburbs were cheap and near. Now they are cheap and far, the hacker
house is a walk from home, and the school is on the corner."*

**What's thin.** K6's finding: from Old Town — where every fixture's office
is and every game starts — the Suburbs are both the cheapest and near, so the
home has no trade-off until the office moves to Downtown or Tech Park. The
district table has five office-side numbers (rent, price, candidate skill,
contract offers, reputation drift, morale) and no home-side one but rent; S4
put one networking room in each district and the school in the Suburbs, and
neither is read by the home.

**What the player does.** Three small reads. `home.farPairs` are re-cut to the
drawn map's adjacency (K6: "Old Town and Midtown are as far apart as Suburbs
and Downtown on the drawn map"), so from Old Town the cheap district costs an
evening. Tonight's networking room, when it is in the home district, costs no
evening (the `Visit` row prints "a walk from home"). A child at the `.school`
stage with a Suburbs home gains +1 bond a week and the "school on the corner"
memory; from anywhere else the school run costs nothing but is printed as the
Suburbs' reason. The move sheet's two columns gain a third: "Nearby: the
hacker house · the school".

**The two answers.** From Old Town: Suburbs — $84 a week and a far commute
(−1 of 3 evenings on normal), the school, the hacker house; Old Town — $120
and near; Midtown — $156, near, the hotel bar. Every office district must have
at least one home where the cheap column and the evening column disagree —
the check below.

**GameState.** Nothing new (`homeDistrict`, `eveningsPerWeek`, the child's
memory kinds exist).

**Files.** `Balance.json` `home.farPairs` (data), `HomeRooms.swift` (the
nearby line, the room's free evening), `Systems/NetworkingSystem.swift` (the
weekend's evening cost reads the home), `Systems/ChildhoodSystem.swift` (the
weekly bond), `Screens/Life/HomeMoveSheet.swift`, `Screens/City/DistrictDetailPanel.swift`.

**Identity.** `homeDistrict` nil on every bot: the room's cost, the bond and
the commute are the old numbers. Re-cutting `farPairs` changes nothing for a
nil home.

**Old saves.** A player already in a district may find a formerly near home
far after the re-cut; the Home card prints the commute, and the move sheet
prints the way out. Hide never remove: no pair is removed, two are added.

**How it fails.** The perks become the new one answer (the Suburbs: cheap,
the school, the hacker house). Cheap check: `homeMoveQuotes` from each of the
five office districts; if any office district has no home where cost and
evenings disagree, or the Suburbs win all three columns from every office,
move the school's bond to Midtown (the park) and leave the Suburbs with rent
alone.

## Ranked 9–16, not worked out

9. **W2 The street** (M, 2.5d) — premise unchanged, spec stands as meta A7.
   Fewer players reach it than reach a fire or a launch; after the joins.
10. **W5 Own the home** (M, 2d) — priced at `city.buyPriceFactor` × the
    district's rent it is one dividend away at flat tier; 70% as secured
    headroom makes it K1's second pipe; decode the mortgaged origin as owned.
    Worth a lane once J1/J2 make the founder's money honest at the exit.
11. **W3 The all-nighter** (S, 1d) — as meta A5, refused when the founder is
    not on the build; +50% of a studio build's day, +29% on the campus. Joins
    the doctor's letter and the partner.
12. **J7 Firing the partner is a fight** (S, 0.5d) — obvious once seen; a
    one-pair guard in `fire`/`fireWithCause` on `partnerEmployeeID`.
13. **J8 The dividend reaches the holders' desks** (S, 0.5d) — makes K3's
    grant read K1's dividend; a morale cause line.
14. **W4 Draft the chapter** (S–M, 1.5d) — the premise holds exactly (six per
    chapter per track); a modest decision, not a join, not a forum wish.
15. **W6 Research forks** (M, 4d) — research is dead on every fixture and this
    is still the fix, but it is a content lane; run it when a content day is
    on the table, priced per quarter first as C7 says.
16. **J9 The downgrade reaches the recruiters** — see the cut list.

## Cut, and why

- **W7 Remote company (C9)** — `remote_friendly` already answers the staff
  question; a room-less company voids seating, the break, the desks row and
  the move down, four systems built since it was proposed. Four days to make
  four features not apply.
- **O2 Rivals use the name generator** — no play added; names are bytes in
  four pinned fixtures. Do it inside the next re-pin round (self-cannibalisation
  or a balance retune), not on its own.
- **O4 Pre-warm the city compose** — 15 ms once an hour; an engineering note,
  not a feature. Leave it in S4's follow-ups.
- **J9 The downgrade reaches the recruiters and the paper** — S2 measured the
  move down as two-sided already (−23 morale for a quarter against $2,450 a
  week); a poach multiplier on top makes it one-sided the other way. The
  paper's lead rank is a one-line nicety, not a lane.
- **The partner's morale reads the dividend as founder pay** — real, one
  guard in `partnerMoraleTargetDelta`'s caller; fold into whichever lane
  touches `founderPayExcess`, not a candidate.
- **The successor inherits the room's bond / keeps a grant line under their
  own name (K5)** — no decision in either; owner's calls, both harsher if
  changed.
- **The emeritus's dividends on the Dynasty row; a bidder's plate on the
  map** — cosmetic reads with no answer.
- **The lead's span is the desks around them** — seating as bookkeeping; the
  lead relief and the lesson are already two separate printed factors.
- **The sabbatical reads the sign** — pure punishment stacked on a bleed that
  already bites on the studio.
- **A dividend to the partner's own line** — the partner on payroll gets a
  grant line only if granted; that is K3's verb, not a new one.
- **Self-cannibalisation for every product** — still the deepest fix and
  still moves every pacing bot; J4 is the player-declared half.

## Not verified

- No simulator run. Every number is from the tree, `Balance.json`, the four
  fixtures' JSON or the lane reports.
- J1's central claim — that no exit path pays `networking.grants` — rests on
  a grep of the engine (`grants` appears in `Ladder`, `FounderMoney`,
  `Networking` only). The lane should read `acceptBuyout`'s tail and
  `GameSession.recordEnding`'s net worth before building; if the ledger's
  number somehow counts the holders, the fix is in the ledger instead.
- Whether any bot ever ships inside a vacation week (J3's identity question)
  is unmeasured; the lane measures before deciding on the `doors.armed` gate.
- J5's dollar delta (`fairWeeklyPay` at +94 skill points) was not computed.
- J6's re-cut of `farPairs` assumes K6's reading of the drawn map; the
  district rectangles in `CityMapComposer` were not read.
- The founder's actual share of a build's daily points on the campus fixture
  (W3) is an upper bound from crew counts, not a measurement.
