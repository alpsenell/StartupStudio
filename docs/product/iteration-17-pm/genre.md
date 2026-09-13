# Iteration 17 — PM lens: the genre wish list

*13 September 2026. Read-only over `iteration-17` @ 8051373 (= main, build
426). Evidence is counted from `GameAction.swift`, `TechTree.json`,
`Balance.json`, `Events.json`, `StaffEvents.json`, the engine systems
named inline, and the four release fixtures (`release-garage-day40`,
`release-studio-day400`, `release-campus-day900`, `l3-family-day900`).
No simulator run; see "Not verified".*

**Where I disagree with the brief.** The genre list is mostly nodes
(a platform, a publisher, an expo, an HR view), and most of them already
exist here in some form — as a random event, a reward, or a number. The
thin place is not that the nodes are missing; it is that the game's
calendar things (the ceremony on day 350, the conference, the platform
change, a course, the year) happen *to* the player instead of being
something the player plans against. The eight below turn those into
dated decisions, and reuse the counterparties (rivals, investors, the
address book) the game already names.

## Diagnosis

**Against the genre, system by system.** *Research*: exists, thin — 20
nodes in `TechTree.json`, five tiers, four effect kinds
(`TechNode.Effect`: unlock a type, unlock a campaign, +quality,
+speed), every node pure upside, 3,260 RP and $104,000 for the whole
tree; one researcher makes about 4 RP a day (`1 + coding/25 +
design/50`), so the tree is roughly three people-years, and both later
fixtures sit at 5 of 20 with `activeNodeID` nil and nobody assigned to
`.research` (the pacing bot researches until `saas_platform` unlocks
and stops). Forks (C7) are on the wave-two list; nothing else in this
lens re-proposes them. *Platform*: missing as a dimension — six
`ProductTypes.json` types with a fixed `marketSize`, unlocked by
research not by time; the only platform in the game is the
`platform_change` event (−$1,500, morale −5, hype −8) and the
`platformLaunch` season twist. The campus fixture is 51 web apps of 54
products. *Publisher/contract counterparty*: half there — contracts are
four anonymous rolls a week from 32 `clientCompanies` names with no
memory (C11 was cut for pay scale); the rival-sponsored white-label job
(`sponsorOneOffer`) is the one named counterparty and it is the rival
paying *you*; nobody ever funds one of *your* builds — money into the
company comes only as equity (8 personas in `Investors.json`), the
bank, the shark, the director's loan (K1) or a friend. *Marketing as a
calendar*: thin — three kinds (`social_push` $50/day × 14,
`press_release` $500, `launch_event` $5,000 from the studio), 14-day
cooldown, ×0.7 per repeat, hype −2% a day (−1% announced), and the only
calendar is J5's announced date; 0 campaigns on every fixture. *Expo*:
exists as a dice roll — `conference_booth` (weight 3, cooldown 240
days, loft+: $7,500 for +9 reputation +15 hype, $900 hallway, or −2),
`conference_invite`, and the `demoDay`/`conferenceBar` networking
evenings; no date to plan for, no build to show. *Office designed*:
tiered — four tiers ($0/$15k/$55k/$300k; 3/6/14/40 desks; 1/2/3/5
slots), four amenities all four owned on both later fixtures, seating
(S1), districts, buy/sell/downgrade; decor is home-only. *Staff
careers*: broad but shallow — nine roles, four levels, `train` ($800,
+6 skill, 14-day cooldown; never used on any fixture, though the bots
never train so that is not player evidence), `mentorEmployee`, daily
growth `0.08 × (1 − skill/100)`, 33 staff events including
`burnoutWarning`, `parentalLeave`, `remoteRequest`, `roleSwitch`,
`raiseRequest` with the policies card, leads and options (K3); and no
employee is ever *absent* — `Employee` has no away field, only the
founder has meters, a burnout, a vacation. *Eras*: missing — `Market.swift`
is a per-topic zero-mean weekly walk (σ 0.06, 5% boom/crash ±0.4,
clamped 0.4–1.8); the year is read by three constants
(`reviewExpectationPerYear` 4, `contractYearScale` 0.25, `skillYearBump`
5) and `calendar.season` by one system (summer internships). The +4 a
year on review expectation is a punishment the game never warns about.
*Awards and rankings*: awards exist (`AwardsJudge`, ceremony on day
350, Product/Studio/Newcomer plus Best-in-topic for twelve topics,
judged over player and rival launches) and pay nothing inside the run —
a decor unlock and a biography line; the `award_shortlist` event is the
only ceremony with a price. Rankings: the Rivals segment sorts by
strength and prints valuation and share; there is no table the player
climbs, and the Hall, leagues, seasons and daily are outside the run.
*End-game beyond exits*: seven endings, the empty epilogue, K5's
hand-over, the Dynasty, and two small holdings — the networking floor's
`.backed` contact (`Holding`, settles weekly) and `investInFriend`
(writes `invested`, pays out nowhere I can find). No second company, no
publisher role, no stake in a rival short of buying it. *Sandbox*: the
custom page (three rules and a seed), ten stake rungs, ten authored
scenarios (closures over three fixtures — not data, not authorable),
five twists that only seasons apply.

**What this game does that the genre does not, and how the eight join
it.** None of the comparators has the founder's other half: 305 life
events, a partner who can be hired, children who remember, a home in a
district with a commute paid in evenings, burnout, the hospital, the
courtroom, prison, fame, dirty money, the doors. That half is where this
game's decisions already have two answers, and its currency is the
evening. So the expo costs the founder an evening or a marketer's
weaker pitch; the holidays policy is the team's version of the vacation
the founder already plans; the publisher's advance is the third door
beside the term sheet and K1's director's loan; the ceremony is a diary
date K7's roadmap can clash with. Everything below is a new
`GameAction` no bot sends, reads no stream on the default path, and
decodes absent in an old save.

## Twenty candidates

| id | name | one line | size | reads | writes |
|---|---|---|---|---|---|
| G1 | The publishing deal | A rival publishes your build: an advance now, half the product forever, and a date | M | rivals, crew cost, ShipETA, announce, sales | `Product.publisher`, cash, announcedDay, rival focus |
| G2 | The expo | A dated show every year: pick one build to demo; hype and a name, or the copycat's head start | M | calendar, hype, bugs, traits, copycat window, evenings | `Product.expoDay`, cash, reputation, life.evenings |
| G3 | Away from the desk | A two-week course instead of the instant workshop, and holidays as a policy | M | assignment output, RP, ETA, staff events, policies | `Employee.awayUntilDay`, policy flag, skills |
| G4 | A stake in them | Buy 5–25% of a rival: dividends from their launches, their roadmap, a cheaper acquisition later | S–M | rival valuation, products, strength, acquire, poach | `rivals.stakes`, cash, rival strength |
| G5 | Contractors | Buy a week of points for a build; the codebase carries the debt | S | crew, crowding, codebase debt, bugs | cash, pools, debt |
| G6 | Pre-orders | Sell launch-week units early on an announced date; a slip refunds them | S | announce, ShipForecast, price tier, slips | `DevProgress.preorders`, cash |
| G7 | License the tech | Any node for cash and a royalty instead of researcher-days | S–M | research, revenue, ledger | `research.licensed`, cash, royalties |
| G8 | The ceremony pays | The cutoff shows from Q4; a win with the team there moves morale, standing, hype | S | AwardsJudge, standing, hype, morale | reputation, standing, moraleAll |
| G9 | The giant's platform | Build on the incumbent's store: ×1.4 market, 30% fee, they see your board | M–L | incumbent, types, sales, feature board | `Product.platformRivalID`, rival strength |
| G10 | Generations | Product-type markets on a four-year cycle you can read on the map | M | types, calendar, seed | a twist/rule only |
| G11 | Rooms cost desks | Convert desks into a quiet room or a war room | M–L | seating, headcount cap, crowding, RP | `company.rooms`, PixelKit scene |
| G12 | The industry table | Studios ranked by valuation, reputation, launches; your row and the gap | S | rivals, company | nothing |
| G13 | Port it | Ship a live product into a second type on half the pools, judged against the original's score | S–M | codebase, types, reviews | a product |
| G14 | Custom scenarios | Save any slot as a challenge: a goal kind, a target, a deadline | M | Goals kinds, Scenario machinery | scenario ledger |
| G15 | Your old company as a rival | The next run's slate carries your last company's shelf as a ghost | S–M | Ghosts, Legacy | rivals at new game |
| G16 | The hackathon | A team weekend that seeds a codebase for a type you have never shipped | S | side project, codebase | codebases, morale |
| G17 | Specialisation at lead | A lead picks architect (quality) or manager (span) | S | K3 leads | `Employee.track` |
| G18 | The annual review | One sheet a year: raise, hold, or notice for everyone | S | payroll, morale | salaries |
| G19 | Research forks | Exclusive pairs after tier 3 (company C7, wave two) | M | research | `unlockedForks` |
| G20 | Repeat clients | A client remembers a great delivery and comes back bigger | M | contracts, reputation | `clientBook` |

Sizes: S = a half to one day, M = two to three days, L = a week, for one
Opus engineer in a worktree.

## The top eight

Ranked by play added per engineer-day. Each is a new action sent only
from the app; every new field is `decodeIfPresent` with a default and
encoded only when set; no `rng`/`worldRNG` draw on the default path.

### 1. The publishing deal — G1, M, 3 days

*"Ironwood put up $31,000 for Round 4 and a date in March. They own
half of it now, and they know what's on the board."*

**What's thin.** Money reaches a *build* only through the company: a
term sheet (equity, on the investors' clock, `earliestOfferDay` 120),
the bank, the shark, the director's loan. The genre's publisher — a
bigger company that pays for your project and takes a cut and a date —
is the one counterparty this game lacks, and the pieces are all here:
rivals with a valuation and a focus, `announceShipDate` with its slip
costs, `ShipETA`, the crew's weekly cost, `postWeeklySales`.

**What the player does.** On a build in development, a *Financing* row
beside J5's announce: *Shop it to a publisher*. The counterparty is
deterministic — the strongest rival with `strength ≥ publisherMinStrength`
(30), else "Nobody would publish this." Terms are arithmetic, printed
before the tap: the advance is `(crew weekly pay + weeklyOperatingCost +
rent) × weeks to the ETA` in cash now; the publisher takes
`publisherShare` (50%) of the product's revenue for as long as it sells
(a weekly ledger line, *Ironwood's share: −$1,140*); the date is the ETA
plus two weeks, announced through `announceShipDate` unchanged, so a
slip costs J5's reputation and hype *and* claws back 25% of the advance
per slip; the publisher's name on the launch adds `launchEventHype × 0.5`
on ship day. The publisher reads your board: the copycat window for
this build is J5's four weeks, and the rival adds the topic to
`focusTopicIDs` on the day of the deal — they call it home now. *Buy
them out* any time at 1.5× the advance less the share already paid.
Refused on a product with a publisher, on a build past `tooLate`, and
inside an earn-out.

**The two answers.** At the loft (three people, $1,500 a week each, an
ETA of eight weeks) the advance is about $31,000 against $90,875 of
studio cash or $11,750 of garage cash: eight weeks of runway without a
term sheet, and the independent ladder stays open because no equity
moved. Against it: half of every week the product ever earns, a date
you did not pick, a rival who now lives in your topic and saw the
board. Or raise instead: equity gone, no date, no share. Or neither and
build slower. The advance is worth most exactly when the company is
weakest, which is when the share costs least in dollars and most in
what the product becomes.

**GameState.** `Product.publisher: Publisher? { rivalID, advance, share,
signedDay, paidBack }`, encodeIfPresent. Balance `publisher {
minStrength 30, share 0.5, clawbackPerSlip 0.25, buyoutMultiple 1.5,
launchHypeFactor 0.5 }`.

**Files.** `Product.swift`, `GameAction.swift`, `Reducer.swift`,
`Systems/ProductSystem.swift` (`postWeeklySales` posts the share;
`ship` adds the hype), `Systems/AnnounceSystem.swift` (the slip
clawback beside the slip's own costs), `Systems/RivalSystem.swift`
(focus topic), `Rival.swift`, `Screens/Products/ProductDetailScreen.swift`
(the row and its sheet), `Screens/Business/RivalProfileScreen.swift`
(published titles), `NewspaperComposer.swift` (the deal is news),
`EventCopy`, `Balance.json`.

**Identity.** The counterparty is picked by sort, the terms by
arithmetic; `announceShipDate` is the existing action. No draws. Bots
never shop a build.

**Old saves.** `publisher` decodes nil; a save mid-announce is untouched.

**How it fails.** The advance is a rounding error at the garage (the
founder's pay is 0, so the crew line is `weeklyOperatingCost` $250 ×
weeks ≈ $2,000) and the deal is loft-only; or it is so large at the
studio that every build is published and the share is never felt.
Measure first on the three fixtures: the advance against the product's
expected 50% give-up (`ShipForecast` quality → the type's launch-week
units × `unitPrice` × the 42-week ramp). Target: the advance between
30% and 60% of the expected give-up on a review-60 build. Under 30%,
floor the crew line at `salaryBase × 3`; over 100%, cut the share to
40% and the advance's weeks to the ETA's half.

### 2. The expo — G2, M, 2.5 days

*"DevWorld is on the 12th. I showed Kite with 31 open bugs. The demo
crashed, and Ironwood shipped theirs four weeks later."*

**What's thin.** The conference is a random event with three priced
answers and no product in it; the networking evenings are contacts,
not launches. Nothing in the year is a date the player builds toward
except the one they announce themselves.

**What the player does.** An expo on day 182 of every year (the
ceremony's opposite), a pure calendar fact like `AwardsJudge.ceremonyDay`.
From day 154 the Now card and the queue say *Expo in N days*. On the
day, a sheet: pick one build in development (or none). *Take a booth*
at a tier price (`expoBooth` loft $2,500 / studio $7,500 / campus
$15,000) or *work the hallway* for $900 at half effect. The shown build
gets `expoHype` (30) × the marketing team's trait factor
(`TraitEffects.campaignHypeFactor`); reputation +3 if its quality so far
(`ShipForecast.quality`) is ≥ 60; if its `openBugs` is over
`expoCrashBugs` (25) the demo crashes — hype ×0.5, reputation −3, the
paper says so. Either way the build is now public: its copycat window
is J5's four weeks (`Product.expoDay` reads where `announcedDay` does),
and its review expectation rises +3 ("we saw the demo"). Who goes: the
founder (−1 evening this week, energy −8) or a marketer on payroll
(hype ×0.7, no evening); nobody, and the booth is the hallway.

**The two answers.** Show the best build: the biggest hype in the game
short of a launch event, a reputation point, and a rival that ships its
copy a month earlier, against reviewers who now expect more. Show the
*second* build to protect the first. Or skip the room and keep the
board dark. The bug count makes it a build decision three weeks out:
squash to 25 or show something else.

**GameState.** `Product.expoDay: Int?` (encodeIfPresent);
`company.lastExpoYear: Int` (encode when non-zero). Balance `expo {
dayOfYear 182, boothByTier, hallway 900, hype 30, hallwayFactor 0.5,
crashBugs 25, reputationGood 3, reputationCrash −3, expectationBump 3,
marketerFactor 0.7, founderEnergy 8 }`.

**Files.** `Product.swift`, `GameAction.swift` (`showAtExpo(productID:,
booth:, attendee:)`, `skipExpo`), `Reducer.swift`,
`Systems/MarketingSystem.swift` (the hype), `Systems/RivalSystem.swift`
(the copycat window reads `expoDay` beside `announcedDay`),
`Systems/ProductSystem.swift` (expectation), `Systems/LifeSystem.swift`
(the evening), `Queue.swift` (+`QueueKind.expo`), `Screens/HQ/NowCard.swift`,
a new `Screens/Business/ExpoSheet.swift`, `NewspaperComposer.swift`,
`EventCopy`, `Balance.json`.

**Identity.** The date is arithmetic; nothing runs unless the player
answers the sheet (a skipped or unanswered expo writes `lastExpoYear`
only from the app). The `conference_booth` event stays in `Events.json`
untouched — changing its weight moves the event roll for every bot —
and the lane records "two conferences" as a follow-up for the owner.

**Old saves.** Both fields decode absent; a save past day 182 gets next
year's expo.

**How it fails.** It is a $7,500 launch event with steps: if the hype
per dollar beats `launch_event` ($5,000, 40 hype, studio+) the expo is
the one answer and the copycat cost is invisible. Measure on
`release-studio-day400`: the shown build's launch-week units with 30
hype at day 182 versus a launch event on the same build a week before
ship (hype decays 2% a day, so the expo's 30 is worth about 12 by a
six-week ship). If the expo still wins per dollar, hype 30 → 20 and
keep the reputation; if the copycat's four weeks never costs share on
the fixture, make it three.

### 3. Away from the desk — G3, M, 2 days

*"Sofia is on a course until the 14th. The ETA moved three days. Then
she asked for August off, and now everybody gets August off."*

**What's thin.** `train` is a tap: $800, +6 skill, morale +4, every 14
days, no cost in time — cheaper than any hire and never a decision.
Nobody on payroll is ever away; the founder has burnouts, vacations and
a sabbatical, the team has none. The genre's holidays and sick days are
random punishments; this game already turns staff questions into rules
(`StaffPolicy`, the policies card), which is the better shape.

**What the player does.** Two verbs on one field. *Send them on a
course* on the manage sheet beside the existing workshop: `courseCost`
($2,400, × `hrTrainingCostFactor` with People & HR), ten working days
away, `courseSkillBoost` +12 in the chosen skill on return, and the
person's fair pay rises with the skill, so `raiseRequest` follows.
While away: no points, no RP, no growth, not counted for crowding or a
lead's span, morale target +2. The build card prints *Sofia away until
14 Mar* and `ShipETA` excludes her. *Holidays* arrive as a staff
question, `holidayRequest` in `StaffEvents.json` ("{name} wants two
weeks in August"), gated on `doors.armed` like K1's and K7's questions
so no bot ever rolls it: *Four weeks a year, take them* — every
non-founder is away ten working days a year, scheduled from their
`hiredDay` anniversary (deterministic), morale target +4 and loyalty +8
for everyone; or *Take them when it's quiet* — no scheduled absence,
morale target −3, `burnoutWarning` weighted ×1.5 for this company only.
The rule lands on the policies card and reverses at the card's usual
price.

**The two answers.** The course: +12 for ten days of a senior's output
on a build with an ETA and possibly a date — a week's pay and a slip
against a skill that never decays. The workshop stays: +6 now, nothing
lost. Holidays: 4% of the year's output (ten of 250 days) against a
floor that stays and asks for fewer raises; the strict answer is free
and costs you the next burnout.

**GameState.** `Employee.awayUntilDay: Int?`, `awayReason:
EmployeeAway? (.course(skill), .holiday)`, encodeIfPresent; the policy
flag on the existing `staffMemory.policies`. Balance `staffAway {
courseCost 2400, courseDays 10, courseSkillBoost 12, holidayDays 10,
holidayMoraleTarget 4, holidayLoyalty 8, strictMoraleTarget −3,
strictBurnoutWeight 1.5 }`.

**Files.** `Employee.swift`, `Systems/EmployeeSystem.swift`
(`produceDailyOutput`, `buildProduct`, the research loop, crowding,
morale target), `ShipETA.swift`, `Systems/SocialSystem.swift` (the
question and the schedule), `StaffEvents.json` (+`holidayRequest`, and
`_back` follow-up), `StaffEventDef.swift` if the policy needs a field,
`Screens/Team/EmployeeManageSheet.swift`, `Screens/Team/TeamScreen.swift`
(the away chip), `Screens/Team/PoliciesCard.swift`, `Screens/HQ/NowCard.swift`,
`Balance.json`.

**Identity.** The course is an action; the holiday question is gated on
`doors.armed`; the schedule runs only with the flag set. The instant
workshop keeps its bytes.

**Old saves.** Absent fields decode as "at their desk".

**How it fails.** +12 for ten days is always right — skills never decay
and a $2,400 course on a $2,200-a-week senior is one week's pay.
Measure first on `release-studio-day400`: send every builder on a course
in week one, compare the ETA slip against weekly points afterwards. If
points are up more than 8% for a two-week slip, the course is a
no-brainer: make it fifteen days or +9. And if the scheduled holidays
never move the Now card's ETA sentence, they are decoration — ten days
must land inside a ship window on the fixture at least once a year.

### 4. A stake in them — G4, S–M, 2 days

*"I bought a quarter of Vantage Point for $128,000. Every launch of
theirs in fitness costs me share and pays me a dividend. When they
stumbled I lost forty grand on paper."*

**What's thin.** The campus has $644,446 and nothing to buy; the rival
worth owning costs more than the cash and the affordable ones are not
worth it (company lens, unchanged). The only relationships with a rival
are fight (price war, challenge, lawsuit, espionage) or own (cash or
paper). The game already has a holding shape (`Holding` on the
networking floor, settled weekly) and a rival valuation that moves
(`strength × 4000 × (1 + rep/100)`, drift σ 2 a week, 6% stumbles of −6,
folds at 8).

**What the player does.** On a rival's profile beside *Acquire*: *Buy a
stake* at 5, 10 or 25% for `valuation × stakePremium (1.1) × percent`,
company cash. A quarter of the price becomes the rival's strength
(`paid / (valuationPerStrength × 4)` — $128,000 is +8): your money made
them stronger. While you hold it: a weekly dividend of `percent × Σ
(product.weeklyUnits × type.unitPrice)` over their competing products,
a ledger line; from 10% their next topic is on the profile (the line
the mole's report gives, `EspionageSystem`, without the crime); their
poaches of your people ×0.5; their price war against you refused. *Sell
the stake* any time at `valuation × 0.9 × percent`. If they fold, it is
gone. `acquireRival` on a rival you hold costs `(1 − percent)` of the
price. Refused inside an earn-out or with the for-sale sign up.

**The two answers.** Back the studio that dents your share: every
Vantage Point launch in your topic is a dent (`competitionDent`) and a
dividend, and their strength is your loss on the head-to-head and your
gain on paper. Or keep the cash as runway and fight them for the
category. And *which* rival: the strong one that will not fold and
already beats you, or the minnow whose +8 strength makes it a
competitor.

**GameState.** `RivalsState.stakes: [RivalStake { rivalID, percent,
paid, sinceDay }]`, encoded when non-empty. Balance `stakes {
premium 1.1, sellBack 0.9, strengthShare 0.25, roadmapFrom 10,
poachFactor 0.5 }`.

**Files.** `Rival.swift`, `Systems/RivalSystem.swift` (`buyRivalStake`,
`sellRivalStake`, the dividend on the weekly evolution, `poach` weight,
`acquireRival` price, the fold), `Systems/RivalSystem+RivalMarket.swift`
(the price war refusal), `Screens/Business/RivalProfileScreen.swift`,
`Screens/Business/RivalsView.swift` (a holdings row),
`Screens/Business/FinancesView.swift` (the asset line), `EventCopy`,
`Balance.json`.

**Identity.** The rival's own weekly rolls are untouched; the dividend
is arithmetic on `weeklyUnits`. No bot buys. The strength bump moves
only a rival somebody paid.

**Old saves.** `stakes` decodes empty.

**How it fails.** A bond with a positive drift: strength drifts with
mean zero but the strong rival never folds, so a quarter of Vantage
Point bought at day 400 is worth more at day 730 on most seeds and the
stake is free money. Measure across the ten pacing seeds with the debug
rival slates: buy 25% of the strongest rival at day 400 and mark to
market at 730. If it is up on more than 8 of 10, premium 1.1 → 1.3 and
sell-back 0.9 → 0.7; if the dividend is under 2% a year of the price on
the campus, count off-market products too.

### 5. Contractors — G5, S, 1 day

*"Two contractors for three weeks got Round 15 out before the date.
The codebase is nine points deeper in debt and nobody on the floor
learned anything."*

**What's thin.** Speed on a build is bought only by hiring (capped by
desks — 36 of 40 on the campus), crunch (morale −18 target, debt 0.15 a
day) or a promoted lead (K3). The campus has money and no way to turn
it into a ship date. The codebase already prices carelessness (debt →
ceiling −0.004 a point, bugs +1% a point, the `.refactor` assignment
pays it down), which is the cost this verb needs.

**What the player does.** On a build's card: *Bring in contractors*
for one to four weeks, `contractorWeeklyCost` ($3,000 — twice a mid's
fair pay) each, paid up front. Each contractor-week adds the points of
a mid-level backend (`employeeBasePoints`, skill 120, the backend role
yield) to the build's pools, counts as one more head for Brooks
crowding (so the ETA on the Now card shows both the gain and the
crowding), grows nobody's skills and no bond, and writes
`contractorDebtPerWeek` (3.0 — three patches' worth) to the type's
codebase; on a greenfield build with no codebase yet, bugs ×1.5 on
their points instead. Refused inside a price war? No — refused only
without the cash and on a build at `tooLate`.

**The two answers.** $9,000 for three contractor-weeks moves a
six-week ETA about a week and leaves nine points of debt for the next
product on that codebase — or the same $9,000 hires a junior for six
weeks who is still there, learning, and on the cap table's morale
sheet. Or promote a lead. On a build with a publisher's date (G1) or
pre-orders (G6) the contractor is the slip's price.

**GameState.** `DevProgress.contractorWeeks: Int` (encode when
non-zero). Balance `contractors { weeklyCost 3000, skill 120,
debtPerWeek 3.0, greenfieldBugFactor 1.5, maxWeeks 4 }`.

**Files.** `Product.swift`, `Systems/EmployeeSystem.swift` (a
contractor's points in `buildProduct`, the crowding head count),
`Systems/CodebaseSystem.swift` (the debt on ship or per week),
`ShipETA.swift`, `Screens/Products/ProductDetailScreen.swift`,
`Screens/HQ/NowCard.swift`, `Balance.json`.

**Identity.** Only on the action; the debt goes through the existing
codebase write. No draws (their bug rolls use the build's existing
per-day roll with a factor, drawn only in a run that hired them).

**Old saves.** `contractorWeeks` decodes 0.

**How it fails.** At $3,000 a week the campus buys four weeks on every
build every time and the debt is paid down by a `.refactor` intern.
Measure on `release-campus-day900`: four contractor-weeks on each of the
five builds, then the codebase's debt at day 960 and the ceiling it
costs the next launch. If the ceiling loss is under 3 review points,
debt 3.0 → 5.0; if nobody would ever pay it, weekly cost 3,000 → 2,000.

### 6. Pre-orders — G6, S, 1 day

*"Announced Kite for the 3rd, opened pre-orders, took $6,200. Slipped
a week and refunded a third of them. The second slip would have been
all of it."*

**What's thin.** J5's announced date has one upside (hype holds,
campaigns land ×1.25) and slips cost reputation; nothing lets the date
raise money, so announcing is a marketing choice and never a cash one.
The garage's whole problem is cash before launch.

**What the player does.** On an announced one-time build at least 21
days from its date: *Open pre-orders*. Units = `ShipForecast`'s
launch-week estimate (`marketScale × type marketSize × quality curve`)
× `preorderFraction` (0.3), sold at `standard price × 0.8`, cash now, a
ledger line. On ship they are delivered: the launch week's units start
with them (already paid, so the week's revenue counts only the rest)
and they count for standing and the awards judge. A slip refunds
`refundPerSlip` (a third) of them in cash on the day J5 already takes
its −4; the void (second slip) refunds the rest and adds −4. Once per
product. Subscription products are a follow-up (annual prepay).

**The two answers.** Cash now at 80 cents, and a date that now has a
dollar figure hanging on it, against full price in the launch week and
a slip that only costs face. The refund lands on the day cash is
tightest, which is what makes the second slip a real cliff rather than
a second headline.

**GameState.** `DevProgress.preorders: Preorders? { units, cash,
openedDay, refunded }`, encodeIfPresent. Balance `preorders { fraction
0.3, price 0.8, minDaysBefore 21, refundPerSlip 0.34, voidReputation −4 }`.

**Files.** `Product.swift`, `Systems/AnnounceSystem.swift` (the refunds
beside the slip), `Systems/ProductSystem.swift` (`ship` delivers them;
`launchMarketScale` unchanged), `ShipForecast.swift` (a units read),
`Screens/Products/Announce/**` (the row under the date),
`Components/LaunchDaySheet.swift` (the delivered line), `Balance.json`.

**Identity.** Gated on `announcedDay`, which only the player sets.

**Old saves.** Decodes nil.

**How it fails.** Slips are rare and the refund is cheap, so pre-orders
are free cash and every announced build takes them. Measure first: on
the J5 lane's announce runs, the slip rate of announced builds. If under
10% of announced builds slip, the discount is the only cost and 0.8 must
become 0.65; if over 40%, the refund on the first slip should be a half.

### 7. License the tech — G7, S–M, 1.5 days

*"Telemetry would have taken Priya four months. I licensed it for
$7,800 and three per cent of everything, forever. Then I licensed
three more."*

**What's thin.** The tree is the one place the campus's money cannot
go: RP comes only from people on `.research` (~4 a day each), the
whole tree is three people-years, and both later fixtures stopped at
five nodes with nobody researching. The genre's tree is a choice
between nodes; this one is a queue, and the only decision is whether to
take a builder off a build for it.

**What the player does.** Every node whose prerequisites are met gains
a second button on `ResearchView`: *License* for `researchCost ×
licenseDollarsPerRP` ($60 — tier 1 $1,200, `telemetry` $7,800,
`hyperscale_pipeline` $19,200 plus its own $15,000 cash cost) and a
royalty of `licenseRoyalty` (3%) of all product revenue for the rest of
the run, per licensed node, a weekly ledger line (*Royalties: −$2,310*).
The node's effect is full. *Buy out the licence* later for 26 weeks of
its royalty at today's revenue. Licensed nodes are drawn with a tag on
the tree.

**The two answers.** People-days now, or cash now and a slice forever:
five licences is 15% off the top of a campus that already loses $17k a
week, against three people freed from research for a year. Early it is
the difference between shipping the SaaS platform in month six or month
ten; late it is a tax you chose. And which nodes: the unlocks
(`cloud_infrastructure`, `enterprise_suite`) are worth a royalty; a 5%
quality node is not, at 3% of revenue.

**GameState.** `ResearchState.licensed: Set<String>` (sorted on
encode, like `unlocked`), encoded when non-empty. Balance `licence {
dollarsPerRP 60, royalty 0.03, buyoutWeeks 26 }`.

**Files.** `Research.swift` (`unlocked` reads union `licensed` for
effects), `Systems/ResearchSystem.swift`, `Systems/ProductSystem.swift`
(the royalty in `postWeeklySales`) or `Systems/FinanceSystem.swift`,
`Screens/Research/ResearchView.swift`, `Screens/Business/FinancesView.swift`,
`Balance.json`.

**Identity.** Only on the action; `isProductTypeUnlocked` and the
multipliers read the union, which is `unlocked` alone in every run that
never licensed. Bots research by id and never license.

**Old saves.** `licensed` decodes empty.

**How it fails.** The campus licenses the tree on day one of the
campus and research is dead. Measure on `release-campus-day900`:
licence the ten remaining nodes, sum the royalty over a year against
the cost of two researchers for the same year. If ten licences cost
less than two researchers, royalty 3% → 5%; if a single licence is never
worth it at the studio, dollars per RP 60 → 40.

### 8. The ceremony pays — G8, S, 0.75 days

*"Awards cutoff in nine days. Round 11 was at 76. I shipped it at 76,
took the team, and lost Best in Finance to Ironwood in front of them."*

**What's thin.** The ceremony is judged on quality over the year
(`AwardsJudge`), rivals included, and a win writes a decor unlock and a
biography line. The cutoff (day 350) is invisible until it has passed.
Warned about nothing, rewarded with nothing.

**What the player does.** From day 322 the Now card and the ship sheet
print *Awards cutoff in N days* beside the ETA. On the night, the sheet
asks before the envelopes: *Take the team* (`ceremonyTable` $2,400 at
the loft, ×2 studio, ×4 campus; one founder evening) or *Stay home*.
With the team there: a win in a topic writes standing +15 in it,
`liveHype` +20 on the product, moraleAll +8; Studio of the Year
reputation +5; a night with no win moraleAll −3. From home: a win is
reputation +2 and nothing else — "you weren't there to collect it."
Sent as one `recordCeremony(year:, attended:, wins:)` from the app
after the judge runs, so the engine never learns to judge.

**The two answers.** Ship at 76 for the window or polish to 80 and
miss it: a real ship-or-polish with a date, once a year. Then $2,400
and an evening on a night you might lose in front of the floor, or
stay home and take the two points. K7's diary makes the night a family
date the roadmap can clash with, for free.

**GameState.** `company.ceremonies: [CeremonyRecord { year, attended,
wins }]`, encoded when non-empty. Balance `ceremony { tableByTier,
winStanding 15, winHype 20, winMoraleAll 8, studioReputation 5,
lossMoraleAll −3, homeReputation 2, cutoffNoticeDays 28 }`.

**Files.** `App/Sources/Awards/AwardsNightSheet.swift` (the question),
`AppRootView.swift` (send after judging), `GameAction.swift`,
`Reducer.swift`, `Systems/StandingSystem.swift` (a `recordAward`),
`Organization.swift` or `GameState.swift` (the record),
`Screens/HQ/NowCard.swift`, `Components/LaunchDaySheet.swift`,
`Balance.json`.

**Identity.** Judged in the app as today; the action is sent only from
the sheet, which no bot opens.

**Old saves.** `ceremonies` decodes empty; a run past a ceremony
records nothing for it.

**How it fails.** Standing +15 and hype +20 make attendance the one
answer once affordable, and the cutoff line makes everyone ship in
December. Measure on `release-studio-day400` and `-campus-day900`: how
many of the player's launches would have won a topic on each fixture's
last ceremony (the judge is a pure function — run it). If the player
wins three or more categories a year on the campus, halve the standing;
if a rival never wins a topic the player is live in, the night has no
loss and `lossMoraleAll` is dead weight — make Studio of the Year the
only one the team cares about.

## Cut, and why

- **G9 The giant's platform** — the platform dimension with a named
  owner (the incumbent's store: ×1.4 market, a 30% fee, they read your
  board). A real relationship, but it is C20 with a face, and G1 gives
  the same counterparty a sharper price on one build instead of a fee
  on a whole type. Revisit if G1 lands and players ask for the store.
- **G10 Generations** — the market changing over years is the genre's
  biggest missing piece here, and it cannot ship on the default path
  (it moves every pacing bot). The only doors are a season twist (the
  meta lens cut a twist picker as an unranked preference) or stake rung
  11, which sits behind ten wins. Recorded for the day a re-pin is on
  the table; the cycle should be a pure function of seed and year, as
  the feature board's appetite is.
- **G11 Rooms cost desks** — the one office-design decision that
  reads seating, headcount and crowding; but it is a PixelKit scene
  lane on its own, and the cheap version (amenities cost a desk) moves
  the investor bots, which build amenities.
- **G12 The industry table** — every number in it is on the rival card
  already; a rank with no verb is a stat card.
- **G13 Port it** — K2's v2 across types; its only cost is the slot,
  and judging the port against the original's score is a punishment
  with one answer (don't).
- **G14 Custom scenarios** — sandbox surface with no in-run decision;
  needs a server to be worth sharing, and the ten scenarios, the rules
  page and the ladder cover the ask for a phone game.
- **G15 Your old company as a rival** — the ghost machinery makes it
  cheap, and it is flavour: no decision after the tap.
- **G16 The hackathon** — a cheaper `startProductOnCodebase`; one
  answer once affordable.
- **G17 Specialisation at lead** — K3 gave leads a job and `roleSwitch`
  already moves people between roles; a second fork on the same rung.
- **G18 The annual review** — `raiseRequest`, `promote`, `adjustSalary`
  and the resignation counter are the review, reactively; a yearly
  sheet is bookkeeping.
- **G19 Research forks** — on the wave-two list from iteration 15;
  nothing to add. G7 is the other half of the research question (cash
  versus people) and sits beside it.
- **G20 Repeat clients** — company C11, cut for the same reason it was:
  contract pay does not scale with headcount, so a returning client at
  the studio is still $2–7k against a $20k burn.
- **Employee sick days as random absence** — the genre's version;
  here it is a draw on the default path and a punishment with no
  answer. G3's policy is the version with a decision in it.
- **A marketing budget slider** — weekly spend per product with
  diminishing returns is bookkeeping; the three kinds plus J5's date and
  G6 are the calendar.
- **Piracy, DRM, hardware R&D, consoles** — the game-dev-tycoon nodes
  that do not belong to a web-and-SaaS startup.
- **Unions, remote, interns, bonuses, a mentor, conferences as evenings,
  the HR view, the org chart** — exist (`officeUnion`, `remoteRequest`,
  `hireChildIntern`, `praise`/`giveGift`, `mentorEmployee`,
  `demoDay`/`conferenceBar`, `PoliciesCard`, `OrgChartView`). Not
  proposed.

## Not verified

- No simulator run: every count is from the fixture JSON, the content
  files and the engine source, not the screen. The four fixtures are
  bot-made, so "0 uses of `train`, 0 campaigns" says what the bots do,
  not what players do.
- G1's advance-to-give-up ratio, G2's hype-per-dollar against the
  launch event, G4's ten-seed mark-to-market, G6's slip rate and G8's
  wins-per-year are each the lane's first measurement; none was run.
- Whether `StaffEvents.json` additions gated on `doors.armed` leave the
  staff-event roll byte-identical for bots (K7's `LifeEvents.json`
  precedent suggests yes; the lane for G3 should verify against the
  engine fixtures before writing the event).
- `investInFriend`'s payout: I found `invested` written in
  `FriendSystem.invest` and read nowhere; if it settles somewhere I
  missed, the diagnosis line about holdings is one sentence too strong.
