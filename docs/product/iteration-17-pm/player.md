# Iteration 17 — PM lens: the player's first ten hours

*13 September 2026. Tree `iteration-17` @ 8051373, Debug build on `ws-l2`.
Played: a fresh install through the front door and a headless new game
(`-autoSpeed x1`, then `-autoAnswer`), the three release fixtures on every
tab and eleven routes (`-unlocked -autoFixture … -autoTab … -autoRoute …`),
a 12-week auto-answered run of the studio (day 401–483) and 16 days of the
garage at 1×. `simctl` cannot tap and this Mac's System Events cannot see
the Simulator process, so nothing was tapped: the first build was judged
from the garage fixture at day 40 and from code, and every count below says
where it came from. Screenshots are in the session scratchpad, not the
repo.*

## Diagnosis

**The first hour is a ninety-second wait with nine reports in it.** The
garage fixture at day 40 says "Ships in about 67 days · 1 person · full
speed", 0 bugs (`NowCard`); the war room's whiteboard prints the founder's
day as "+1.2 design, +0.7 code, +0.5 polish", 2.4 points against a mobile
app's 219 (`ProductTypes.json`). In the sixteen game days I ran it the
build went 96 → 137 points and nothing asked for a tap. During a build the
levers are the focus split, the company-wide pace, three bug taps a day
(`Balance.json bugHunt.perDay`; the garage build has no bugs to tap) and
K6's weekly break. The launch is better: the war room counts down, the
review reveal with its score stamp is the best screenshot in the game
(`21-studio-launchday.png`) — but it is a reading. `ship(productID:)` takes
no price (every one of the 63 fixture products launched at `standard`, and
K2 made the first change cost 12% of the book), no outlet, no date; the
four outlets in `Reviews.json` have personas and no memory (each is
`baseScore + gaussian` in `ProductSystem.ship`); "Review copies are out.
The verdicts land next week" is the whole of launch day. There is no way
out of a bad build: no shelve verb exists (`GameAction` has `sunset` and
`shipReplacing` for live products, nothing for one in development), so a
garage founder who picked a poor-fit topic at week 1 learns it from the
"Best case with this crew: 58" card and must ship it anyway to free the
slot — S2's downgrade refusal literally says "Ship N builds first".

**After a hit, the hit is a number.** On the campus one SaaS (Round 9,
2,091 subscribers, $52k a week) carries 48 web apps earning $23–$518 a
week; on the studio Round 6 makes $5.9k against products making $67. What
a hit can do: be re-priced (28-day cooldown), get a support desk, an
update, a retirement, a v2, a feature board and a storefront page. What it
cannot do: touch any other product (the company's own products never
interact — company lens, iteration 15), earn a contract (the contracts desk
pays $2–7k regardless of what you have shipped), or be shared (share cards:
biography, front page, office photo, phone thread, year grid — no product
card, no launch card). The week's shape on the studio, measured over the
12-week auto-run with no player initiative: **about 1.0 question a week
arrives** (story 0.34, poach 0.25, door 0.25, staff 0.08, price war 0.08,
buyout 0.08) against **about 2.5 dismissals** (the weekly report; booms
0.76 + crashes 0.34 stopping the clock under the 10-day pause budget;
rival launches 0.67, contract and candidate refreshes 1.0 each as notices).
Every company verb — ship, hire, price, assign, announce, campaign — is
initiative; nothing in the week asks for one, which is why the auto-run
shipped nothing in 12 weeks with three builds reading "Could ship now".
The phone on the studio is 43 unread, 18 of them the company's own thread
and seven alumni at "Seen. No reply."; the feed has 0 followers on every
fixture; no fixture ever ran a campaign or announced a date. The return
hooks are sound where they exist (desk streak, daily, league week, season)
but all live on the front door; the main save has nothing that says
"tomorrow", and the daily is a full game year (`DailyChallenge.horizonDays
= 364`), which at the studio's rate is ~50 questions and ~35 notices before
a score — a session, not a coffee break. Expression is the founder's look
(24 + earned), the names, seating and decor that "has no effect on
anything"; box art, the studio's mark and the storefront are derived, not
chosen. The "Tap anyone — or the whiteboard, the coffee…" tip is still the
rail's default on the studio at day 400.

## Twenty candidates

| # | Name | One line | Size | Reads | Writes |
|---|---|---|---|---|---|
| P1 | Name the price | The ship dialog asks budget / standard / premium with the forecast's caption; free at launch, the 28-day clock starts | S 0.5–1d | `ShipForecast.quality`, `revenueFactor(for:reviewScore:)`, `priceTiers` | `ReleaseInfo.priceTier` at ship, `lastPriceChangeDay` |
| P2 | Shelve the build | Cancel a product in development: half its points bank into the type's codebase, morale −4, the slot frees, no review | S 1d | `DevProgress`, `Codebase`, morale, slots | products (removed), `Codebase.*Pts`, `.productShelved` |
| P3 | The exclusive | Give one outlet the review copy: its verdict lands on launch day, it warms to you, the other three cool; outlets remember | S–M 1.5d | `balance.reviewOutlets`, `ProductSystem.ship`, reputation | `company.pressStanding`, `ReleaseInfo.exclusiveOutlet` |
| P4 | Pre-orders | On an announced date, sell the build before the reviews: hype becomes cash now; a slip refunds and doubles the reputation cost; a bad score is "overpromised" | M 2d | J5 announce, hype, `unitPrice`, slips | `Product.preorderUnits`, cash, reputation, week-0 sales |
| P5 | The contractor | Rent a pair of hands for one pool for two to four weeks: points now for cash, bugs ×1.5, debt for the next build, the ceiling reads a 50 | M 2d | `buildProduct`, cash, `debtAccrued`, `crewSkillDaySum` | `Product.contractor`, cash, `Codebase.debt` |
| P6 | The custom build | A live product earning enough draws a client who wants their own version: four weeks' revenue up front, two people, no update or re-price until delivery | S–M 1.5d | `weeklySales`, `ContractSystem`, assignments | `ContractOffer.productID`, refusals on update/price |
| P7 | Cross-promotion | Show one live product inside another for four weeks: the guest gains buyers from the host's base, the host's book churns | S–M 1.5d | two `ReleaseInfo`s, topics, subscribers | `ReleaseInfo.promoting`, weekly sales |
| P8 | The launch card | A 1080×1350 share card of a launch: box art, the four scores, the stamp, the first week, the run's code | S 0.5d | `ReleaseInfo`, `ProductBoxArt`, `SeedCode` | nothing |
| P9 | The studio mark | A generated studio glyph and colour on box art, the storefront, the front page, the city building | S 1d | seed, company name | `company.markSeed` |
| P10 | The all-nighter (meta A5, wave two) | Hold the whiteboard tonight: founder points ×3, energy −15, health −3, bugs ×1.5 | S 1d | founder skills, meters | `life.allNighter` |
| P11 | Draft the chapter (meta A6, wave two) | Keep four of the six goals dealt; the other two are gone | S–M 1.5d | `Goals.json`, progression | `draftedGoalIDs` |
| P12 | Announce a number (meta A18) | Promise a score or a valuation in print by a date | S–M 1.5d | announce, reviews, valuation | hype, reputation |
| P13 | Ask them back from the phone | Reply to an alumnus's thread with an offer | S 1d | alumni contacts | employees |
| P14 | The week's focus | Each report asks build / sell / people for the coming week, ×1.1 there, ×0.95 elsewhere | S 1d | pace, output | a weekly flag |
| P15 | Park the build | Freeze a build in development, keep its points, free the slot, resume later | S 1d | slots, hype | `Product.parkedDay` |
| P16 | The expansion pack | A 30% build sold to an existing one-time product's buyers at an attach rate | M 2.5d | units, codebase | a child product |
| P17 | The port | Ship the same product as a second type with half the pools pre-filled | M 2.5d | codebases per type, saturation | a sibling product |
| P18 | The beta | Release a build early to users for a fortnight: live bugs found before launch, hype leaks to copycats | M 2d | bugs, copycat clock | `Product.betaDay` |
| P19 | The lunch-break daily | A 13-week daily beside the year-long one | S 1d | daily store | a second board |
| P20 | The counter-launch | When a rival launches into your live topic, a one-week campaign at ×1.5 hype | S 0.75d | rival launches, campaigns | a campaign |

## The top eight

### 1. Name the price — S, 0.5–1 day

*"Premium at a forecast of 72: fewer buyers, more each, and the press
reads the tag."*

**What the player does.** The ship confirmation (`ProductsListView` "Ship
it", `ProductDetailScreen`, the war room's button) becomes a short sheet:
the forecast score, then three tiers with `LiveOps.priceCaption` at that
score — "Premium · ×1.6 price, ×0.6 demand, reads the score", "Budget ·
×0.6 price, ×1.5 demand, ×1.35 share" — and a Ship button that names the
tier. Choosing here is free; the tier is written as the launch tier, and
K2's 28-day clock starts on launch day exactly as it does today.

**The two answers.** Premium: more per buyer and, above the
`premiumReviewCurve` pivot, more demand too, but fewer units for standing
(`shareWeight` 0.85) and I1's harsher live-bug penalty. Budget: the
category, at a third of the revenue, and the sale week already spent.
Standard is what every product does today, and stays the default.

**GameState.** None. `ReleaseInfo.priceTier` and `lastPriceChangeDay`
already exist; the launch writes them instead of `standard` and `nil`.

**Files.** `GameAction` (+`shipAt(productID:tier:)`; `.ship` untouched so
every bot sends what it sent), `Reducer`, `Systems/ProductSystem.swift`
`ship` (a tier parameter defaulting to `.standard`), a new
`Screens/Products/ShipSheet.swift` reusing `LifecyclePriceSheet`'s rows,
`ProductsListView`, `ProductDetailScreen`, `WarRoomScreen`, `EventCopy`.

**Identity.** `.ship` is unchanged and defaults to `standard`; the new
action is app-only. Fixtures do not move.

**Old saves.** Nothing new is encoded.

**Estimate.** 0.5–1 day.

**How it fails.** Premium is a lookup, not a choice: if
`revenueFactor(.premium, score) ≥ revenueFactor(.standard, score)` for
every score above 60, the sheet just says "premium above 60" and the
decision is dead. Measure first over the 63 fixture launches' scores; if
premium wins from 60 up, the printed cost has to be the standing share
(`shareWeight` 0.85 vs 1.0 → "Own a topic" goals) and the sheet must say
so, or the pivot moves.

### 2. Shelve the build — S, 1 day

*"Quiet 1 was a poor fit from day one. Shelve it, bank what you learned,
start the right one."*

**What the player does.** On a product in development, K2's lifecycle
card gains *Shelve it*, with the consequence on the button: "Bank 50% of
its points into the mobile app codebase · morale −4 · the slot frees · no
review, no sales". Refused in the last seven days before its ETA ("It is
a week from done — ship it or don't") and while it carries an announced
date that has not slipped (a shelve after an announcement is a slip:
J5's first-slip reputation applies).

**The two answers.** Shelve: the weeks are gone, the next build of that
type starts a third full, the topic's saturation is untouched, nobody
reviews you. Ship rough: cash and standing in the topic, a score in the
forties that feeds the reputation expectation and the journal, and a
codebase entry with the full points and whatever debt it accrued.

**GameState.** No new field: the product is removed from `products`, the
codebase for its type gains `min(pool, pts × 0.5)` per pool and
`debtAccrued`, `GameEvent.productShelved(productID:name:day:)` is logged
(the event log is the K-lanes' precedent for new cases).

**Files.** `GameAction` (+`shelveProduct(productID:)`), `Reducer`,
`Systems/ProductSystem+Lifecycle.swift` (beside `sunset`), `CodebaseSystem`
(the bank), `Systems/EmployeeSystem.swift` (crew → idle, the existing
sweep), `Lifecycle.swift` (`LifecycleRefusal` cases), `LiveOps.swift`,
`ProductDetailScreen`, `OfficeDowngradeRow` (the refusal can now name the
verb), `EventCopy`, `Balance.json` `lifecycle.shelveBankFraction 0.5,
shelveMorale 4, shelveLastDays 7`.

**Identity.** Action-only; no draw. Bots never shelve.

**Old saves.** Nothing new to decode.

**Estimate.** 1 day.

**How it fails.** Shelving at 90% is a free head start: on the studio,
Round 15 at 199 of 325 points would bank 100 into the web-app codebase,
30% of the next build. Measure the bank against the next build's days
saved on the studio and the campus first; if a shelve-at-the-gate loop
beats shipping, the fraction drops to 0.25 and the bank is capped at the
codebase's existing points (a lineage you already have gets nothing).

### 3. The exclusive — S–M, 1.5 days

*"TechDaily gets it first. Their verdict lands today; the others read that
they were second."*

**What the player does.** The ship sheet (P1's, or the confirm if P1 is
not built) offers *Exclusive to…* with the four outlets and "none".
The chosen outlet's review is revealed on the launch-day sheet itself
instead of a week later, its blurb leads the paper, its standing with the
studio rises +5 and the other three fall −2. Every outlet's standing adds
`standing / 5` to its score on future launches (±4 at the cap of ±20) and
drifts 1 toward 0 per launch. The launch-day sheet prints each outlet's
standing as a byline ("TechDaily · warm to you").

**The two answers.** Know the verdict today and warm one outlet, at the
price of three cooler ones next launch — a rotation the player has to
manage across launches; or ship even-handed and wait the week as now.

**GameState.** `CompanyState.pressStanding: [String: Double]` (empty,
encoded when non-empty), `ReleaseInfo.exclusiveOutlet: String?`.

**Files.** `Company` in `GameState.swift`, `Product.swift`,
`Systems/ProductSystem.swift` `ship` (the loop over `reviewOutlets` adds
the standing offset — 0 for every outlet in every save that never chose
one — then applies the ±), the reveal gate in `LaunchDaySheet` /
`ReviewRevealList` (one review visible on day one), `NewspaperComposer` (a
marked block), `WarRoomScreen`, `Balance.json` `press.exclusiveGain 5,
snub 2, scorePerStanding 0.2, driftPerLaunch 1, cap 20`.

**Identity.** The offset is exactly 0 with an empty map, and the loop's
draws are unchanged in count and order; the reveal timing is app-side.

**Old saves.** Empty map, nil outlet.

**Estimate.** 1.5 days.

**How it fails.** Standing is invisible under noise: if
`reviewNoiseSigma` is 6 or more, ±4 never reads as anything but luck.
Measure the sigma and the per-outlet spread on the fixtures' reviews
first; if the spread swamps it, the standing shows on the byline in words
and the score offset rises to `standing / 3`, or the exclusive's value is
moved entirely to the day-one verdict and the paper.

### 4. Pre-orders — M, 2 days

*"Announce March 29, open pre-orders: $3,100 today against a launch week
that will be smaller, and a refund if you slip."*

**What the player does.** J5's announce sheet gains *Open pre-orders*
(one-time products only). Each day until launch, `hype × preorders.
unitsPerHype` units sell at the standard price × 0.85 into cash, printed on
the product page as "412 pre-ordered · $820". At launch those units are
subtracted from week 0's sales (they were the same buyers). A slip refunds
half and doubles J5's reputation cost; a second slip refunds all. If the
average score lands under `scoreFloor` 60, reputation −3 and the
"overpromised" callout fires (it already exists in `Reviews.json`).

**The two answers.** Cash before the verdict — the garage's $11,750
becomes runway — against a smaller launch week for standing and a bet on
your own date and score. Or announce without pre-orders as now.

**GameState.** `Product.preorderUnits: Int` (0, encoded when non-zero),
`Product.preorderCash: Int`.

**Files.** `Announce.swift`, `Systems/AnnounceSystem.swift` (the daily
sale, the slip refund), `Systems/ProductSystem.swift` `postWeeklySales`
(week 0 minus the pre-orders) and `ship` (the callout and the reputation
line), `Screens/Products/Announce/**`, `ProductDetailScreen`,
`FinanceSystem` (a ledger category), `Balance.json` `preorders.unitsPerHype
0.4, discount 0.85, refundFraction 0.5, scoreFloor 60, floorReputation 3`.

**Identity.** Only after `.openPreorders(productID:)`; bots never
announce.

**Old saves.** Defaults 0.

**Estimate.** 2 days.

**How it fails.** Pre-orders sell nothing: fixture hype at launch is 0–7
on the studio and 0–35 on the campus, and nobody ran a campaign. Measure
first: a garage build announced at day 60 with one $500 press release —
what is hype at launch and what would pre-orders have netted against the
wallet? Under $500 the verb is decorative, and the unit rate must read
followers (`fame.followers`) as well as hype, or pre-orders open only
from the loft.

### 5. The contractor — M, 2 days

*"A contractor takes the code for three weeks: $900 a week, ships 26 days
sooner, and the next build inherits the mess."*

**What the player does.** On a build's Focus card: *Bring in a
contractor* → pick a pool and a term (2–4 weeks). Each day the pool gains
`typePool / 60` points at the pace's output factor, the crew's
`crewSkillDaySum` counts a 50 for the day (so a beginner crew's ceiling
rises and a strong one's falls — the sheet prints the new ceiling before
the tap), bugs roll at ×1.5 for the contractor's points, `debtAccrued`
grows 0.3 a week, and the fee posts weekly. Refused with fewer than four
weeks of runway after the term, or twice on one build.

**The two answers.** Ship sooner and learn nothing — no skill growth, a
worse codebase for the next product, bugs — for cash the garage can
barely spare; or hire, which is slower to start, permanent, and grows.
On the garage the contractor is the answer to "67 days" that the hiring
sheet is not, and the tutorial's "you cannot ship alone by winter" gets
its second reading.

**GameState.** `Product.contractor: ContractorJob?` (pool, untilDay,
weeklyFee; nil, encoded when set).

**Files.** `Product.swift`, `Systems/EmployeeSystem.swift` `buildProduct`
(one marked block after `gatherCrewOutput`), `Systems/FinanceSystem.swift`
(the fee), `CodebaseSystem` (debt already flows from `debtAccrued`),
`ShipForecast` (the 50 in the ceiling), `ProductDetailScreen` (the row and
its sheet), `NowCard` / `LadderCrewLine` ("+ a contractor on code"),
`Balance.json` `contractor.poolFractionPerDay 1/60, weeklyFee 900,
feePerOfficeTier 1.0/1.5/2.5/4, bugFactor 1.5, debtPerWeek 0.3, skill 50,
maxWeeks 4`.

**Identity.** nil contractor → the block adds nothing and draws nothing
(the extra bug rolls only exist when points were added).

**Old saves.** nil.

**Estimate.** 2 days.

**How it fails.** Always-on: if a $900 contractor turns 67 days into 40
for $3,600 of an $11,750 wallet, nobody builds without one. Measure the
solo garage ETA with a code contractor at the proposed fraction and fee
first; the price is right when the term costs a quarter of the runway and
the debt shows on the next build's ceiling by at least 3 points.

### 6. The custom build — S–M, 1.5 days

*"Halden Group wants Round 9 for their own floor: four weeks of its
revenue up front, two people for six weeks, and no update until it
ships."*

**What the player does.** Once a quarter, a live product earning at least
$1,000 a week raises a contract offer on the Business desk sourced from it
(`ContractOffer.productID`): payout = 4 × its weekly revenue (capped at
$75,000), penalty 1.5 × payout, required skill from the product's crew
index, deadline 6 weeks. While the job runs, the product's *Ship an
update* and *Change the price* are refused with the reason ("Halden Group
is on the current version"), and its live-bug discovery runs ×1.5 (the
client's people are using it hard). The product page shows the row; the
contract is otherwise the existing contract (assignment, delivery,
quality).

**The two answers.** Cash sized to the hit, at last, against six weeks of
a frozen roadmap on the one product that matters and two people off the
next build; or turn it down and keep the hit moving.

**GameState.** `ContractOffer.productID: UUID?`, `ContractJob.productID:
UUID?` (nil, encoded when set), `economy.lastCustomBuildDay: [UUID: Int]`.

**Files.** `Contract.swift`, `Systems/ContractSystem.swift` (the offer,
generated on the existing refresh from the product's numbers — no new
draw: the client name comes from the existing offer's name roll, the
numbers are arithmetic), `Systems/ProductSystem+Lifecycle.swift` and
`LiveOpsSystem` (the two refusals and the ×1.5), `ContractsView`,
`DeskCard`, `ProductDetailScreen`, `Balance.json` `customBuild.
minWeeklyRevenue 1000, payoutWeeks 4, payoutCap 75000, penaltyFactor 1.5,
deadlineWeeks 6, cooldownDays 91, liveBugFactor 1.5`.

**Identity.** The offer only exists when a product clears the revenue
floor *and* the refresh already rolled an offer that day (the custom
build replaces that offer's numbers rather than adding one), so the
stream is untouched; the pacing bots never accept contracts on the
fixtures' path. If replacing an offer moves any fixture, gate the offer on
`noticeProductsOpened` like the incident room.

**Old saves.** nil fields, empty map.

**Estimate.** 1.5 days.

**How it fails.** It erases the late-game money cliff iteration 12 built:
the campus's Round 9 would offer $75k a quarter against a $17k weekly
loss. Measure the campus's cash line with and without four custom builds
a year first; if it closes the gap alone, the cap falls to two weeks'
revenue and the freeze lengthens to the whole quarter.

### 7. Cross-promotion — S–M, 1.5 days

*"Put Round 45 in front of Round 9's users for a month. Round 9's book
churns for it."*

**What the player does.** A live product's Live ops card gains *Promote
another product here* → a picker of the other live products. For four
weeks the guest's weekly units gain `transfer × host units` (×1.5 for the
same topic), and the host loses: a one-time host sells ×0.92, a
subscription host churns 2% of its subscribers over the term. Once a
quarter per host. The storefront shows the strip ("Also from Meridian
Labs") under the host's screenshots.

**The two answers.** Spend the hit's goodwill on the launch that needs
it; or protect the book that pays the payroll. Two live products finally
touch, which is the thin place the company lens named and C1 only half
answered.

**GameState.** `ReleaseInfo.promoting: (productID: UUID, untilDay: Int)?`,
`ReleaseInfo.lastPromoDay: Int?`.

**Files.** `Product.swift`, `Systems/ProductSystem.swift` `postWeeklySales`
(one marked block: exactly ×1 and +0 with nil), `LiveOps.swift`,
`ProductDetailScreen`, `StorefrontScreen` (the strip), `Balance.json`
`crossPromo.transfer 0.15, sameTopicFactor 1.5, hostSalesFactor 0.92,
hostChurn 0.02, weeks 4, cooldownDays 91`.

**Identity.** nil → nothing; action-only.

**Old saves.** nil.

**Estimate.** 1.5 days.

**How it fails.** The arithmetic never favours it: on the campus, Round 9
(2,091 subscribers) promoting Round 45 hands the guest ~313 units (~$1,250
once) and costs the host ~42 subscribers (~$1,050 a week, forever). Measure
that pair and the studio's Round 6 → Round 14 first; the transfer has to
be worth at least the host's quarter of churn on the studio, or the host's
cost becomes a one-time hit to `liveHype` instead of subscribers.

### 8. The launch card — S, 0.5 day (not a mechanic; ranked for what it is)

*The one screenshot the game invites and does not offer.*

**What the player does.** Once the reviews are in, the launch-day sheet
(and the product page's Reviews card) gains a share button beside Done:
box art, the name, type · topic, the four outlets' scores in the pixel
font, the stamped average, "first week: 434 sold · $1,731", the studio's
name and the run's seed code ("Play it: …", as the year grid does).

**The two answers.** None; it is a reward. It is here because the brief
asked what a player would screenshot, the reveal is that moment, and it
costs half a day inside whichever lane touches `LaunchDaySheet` (P3).

**GameState.** None. **Files.** `Share/ShareRenderer.swift` (+`.launch`),
a new `Share/LaunchCardView.swift`, `LaunchDaySheet`, `ProductDetailScreen`.
**Identity / old saves.** Nothing. **Estimate.** 0.5 day.

**How it fails.** It lies: offered before the reviews land it shows an
empty stamp. Gate on `reviews.isEmpty == false`; render under the
existing `ShareRenderer.cardSize` and check it in both colour schemes the
way R4's cards were.

## Cut, and why

- **P9 The studio mark** — pure expression, no decision; the rule about
  decor ("no effect on anything") applies. Keep for a round whose brief is
  identity, and put it on the box art and the city building together.
- **P10 The all-nighter, P11 Draft the chapter, P12 Announce a number** —
  already specced by the meta lens (A5, A6, A18) and still open; nothing
  new to add, and A5 is the right answer to the build's dead ninety
  seconds if the lead wants a wave-two item pulled forward.
- **P13 Ask them back from the phone** — alumni already re-hire from the
  networking rooms at `askOverFairPay` with skills grown by time away
  (`NetworkingSystem+Alumni`); a phone route to the same offer is a
  shortcut, not a verb.
- **P14 The week's focus** — the pace switch with a weekly tax on top;
  bookkeeping every seven days, and V2 deliberately made pace one control.
- **P15 Park the build** — shelve (P2) with none of the cost; a parked
  build is a free option on the topic's next boom.
- **P16 The expansion pack** — an update that also sells; K2's v2 carries
  the book and `startUpdate` re-reviews. Too much scaffolding for a third
  version of the same verb.
- **P17 The port** — codebases are per type, so a port is a new product
  with a head start into a topic you already saturate; it is the
  self-cannibalisation problem the company lens recorded as un-gateable.
- **P18 The beta** — the forecast already tells the player the score, so
  the beta's information is worth nothing; only its bug clearance is
  real, and the support desk does that after launch.
- **P19 The lunch-break daily** — more surface, the same question ("choose
  your daily" was cut for this reason); the finding that stands is that
  the daily is long, which is a horizon number, not a feature.
- **P20 The counter-launch** — a campaign with a trigger; the campaign
  exists and the price-war answer covers the reactive case.
- **A launch-week bet with the board, review-copy embargo dates, a fan
  base as a stock, merch, a free tier, platform stores** — a new node
  each, or cut with a reason in iteration 15 (C15, C19, C20).
- **Two UX facts worth a line in some lane, not a feature:** the "Tap
  anyone" tip is the rail's default at day 400 on the studio; the phone's
  company thread holds 18 unread on the studio fixture after V2's filter.

## Could not verify

- No tapping: the fresh game was never given a product, so the first
  build was read off the garage fixture (day 40 → 56 at 1×) and the
  war room's whiteboard line rather than played from day 0.
- The 12-week tap count is from `-autoAnswer`, which takes the first
  option: it sold the company at day 483 on the bankruptcy warning, so
  weeks 1–12 are the count and nothing after.
- The daily's length in wall time is inferred from the studio's weekly
  rate, not timed.
- `reviewNoiseSigma` and the per-score `revenueFactor` table (the first
  measurements for P1 and P3) were not computed here; both are one
  script over `Balance.json`.
