# Iteration 12 — ideas: the halves of the game meet

*10 September 2026. Five new features and five improvements, chosen from
four Opus product passes over `iteration-11` @ a12f3be (company loop,
founder's life, meta and retention, cross-cutting systems). The four
full reports, with twenty candidates each and their cut lists, are in
`iteration-12-pm/`. Nothing here is built.*

## What the four passes agreed on

Iterations 9 to 11 gave the game a second half: the founder's life, the
family, crime, prison, fame, dirty money, espionage, office secrets. The
identity rule that kept every fixture byte-identical also made every one
of those systems opt-in. The systems pass counted it: of the 279 life
events that can roll, 221 are gated on flags that only a room the player
has to enter can raise, and every dark-life system returns on its first
line until a button is pressed. The life pass found the reverse edge is
missing too: nothing the founder does wrong ever reaches a term sheet, a
board review or a candidate. The company pass found the core loop still
has two choices with one right answer (the price tier and the tech tree)
and two big systems (rivals and the market) that never read each other.
The meta pass found the only day-7 hook, the league, is a table of one.

So the round's theme is joins, not rooms: doors from the company into the
dark half, consequences from the dark half back into the company, rivals
into the market, and a field for the league.

## Ranking

| # | Idea | Lens | Size |
|---|---|---|---|
| F1 | Nobody asks permission: four doors into the dark half | systems + life + meta | M, 3–4 days |
| F2 | Your record crosses over: the board, the hiring sheet and the spotlight | life + systems | M, 5 days |
| F3 | Rivals follow the money | company | M, 3–4 days |
| F4 | The house field | meta | M–L, 4 days |
| F5 | Announce the date | company | M, 3 days |
| I1 | Premium means something | company | S, 1 day |
| I2 | Put the children on the company's clock | life | S, 1 day |
| I3 | Late-game money has teeth: event stakes and the campus cliff | systems | S, 2 days + re-pin |
| I4 | Answer the price war | company | S, 1–2 days |
| I5 | One queue for every question | systems | M, 3 days |

Every item keeps the repo's rules: identity at the default, no new
`rng`/`worldRNG` draws on the default path, old saves load, no new tests.
I3 is the one item that deliberately moves measured gates and needs the
measure-and-re-pin pass from iteration 5.

---

## New features

### F1. Nobody asks permission
*Four one-time doors from the company game into rooms that already exist.*

Today the shark only calls a founder who happened to open Finances, the
vices only creep in on a founder who opened Assets, the feed only exists
once you post, and the family room only opens when you walk in. BitLife
works because life happens to you; here it only happens to players who go
looking.

- **The shark.** Runway four weeks or less, day 90 or later, Finances
  never opened: the dirty-money offer runs as if the screen had been
  opened. (Systems A1.)
- **Vices.** Founder on crunch 21 of the last 28 days: somebody at the
  launch party offers something. Yes engages Assets and seeds the vice a
  launch party already adds.
- **Fame.** A launch reviewed 80 or better, or reputation 60: a journalist
  wants a take. Yes opens the feed with the first post drafted.
- **Family care.** Day 365 or later and a seed-derived parent reaches care
  age: the bill arrives by text. Yes opens the family room at that beat.
- Each door fires once per run, lands on the rail as a deferred notice
  and a phone post, never pauses, never touches `narrative.lastFiredDay`.
  A missed deadline is a decline. A bot never answers.
- **The cheap half, ship it with the doors:** surface each room from the
  moment that wants it (the wedding links the family room, launch day
  gets "Tell people" into compose, a burnout links the doctor) and key
  about ten new coach tips to game state instead of chapter-1 goals,
  since finishing the tour dismisses all six existing tips for good
  (`GameSession+Tutorial.swift:134`). (Life B5, Meta B1.)
- **Touches.** `DirtyMoneySystem` offer gate, `AssetsSystem`, `FameSystem`,
  `FamilyDramaSystem`, `NoticeRail`, `PhoneSystem`, `TipStrip`.
- **How it fails.** Over the ten BalanceTargets seeds, count runs meeting
  each condition. Under 2 in 10 the door is dead; over 8 in 10 it is a
  nag.

### F2. Your record crosses over
*The board reads the papers, recruiters ring your ex-employees, and fame
makes everything you hide easier to find.*

Notoriety is read only by the crime and espionage discovery rolls. An
open case, a guilty verdict, a public beef or firing with cause never
reaches a term sheet, a board review or a candidate. The content already
promises it does ("Difficult but effective is now a thing recruiters say
about you" costs mood −2 and nothing else).

- **The board reads the papers** (Life A1). At each review with a seated
  board, a key-person line: +8 per open case with the founder as
  defendant, +12 for a guilty verdict that quarter, +4 per beef round,
  +6 for an unanswered cancellation, capped at +25. Printed on the review
  as `THE FOUNDER'S QUARTER: +20`. With no board, a term sheet that
  arrives during an open case is priced 15% lower, applied after the roll.
  Settle-or-fight becomes a company decision, not a wallet one.
- **Your name gets around** (Life A2). A pure `FounderStanding` score,
  clamped 0…100: notoriety × 0.5, +6 per firing with cause, +3 per mean
  act on staff in 180 days (cap 24), +10 per guilty verdict, −4 per fame
  level, −3 per alumnus with rapport ≥ 60. Candidates' asks × (1 +
  name/200); at 50 the best candidate refuses the interview and the
  button says why. The hiring sheet prints `YOUR NAME: +14% ON ASKS · 2
  ALUMNI VOUCH`. Fame launders a name; treating leavers well does too.
- **Fame is a spotlight** (Systems A3). `spotlight = 1 + 0.25 × fameRung`
  multiplies crime discovery, espionage trace and laundering discovery,
  printed as its own line on the odds breakdown. A conviction or a trace
  drops fame one rung. Move the laundering discovery constant into a
  balance key while there (a wave-two leftover). A TV slot and the
  dirty-money cheque, but not both.
- **Identity.** No cases, no beef, no mean acts, fame empty: +0, ×1.0.
- **Touches.** `Systems/InvestorSystem.swift` beside the pay-pressure
  line, `Crime.swift`, `Fame.swift`, `Investors.swift`,
  `Systems/HiringSystem.swift`, `Screens/Team/HiringSheet.swift`,
  `Interactions.swift`, `Espionage.swift`.
- **How it fails.** Independent-ladder founders never seat a board, so
  the haircut carries half the weight; if late-game founders rarely hire,
  move the name's effect onto rivals' poach odds.

### F3. Rivals follow the money
*Booms draw rivals in, crashes empty a topic, and the forecast finally
says something different per topic.*

`RivalSystem.evolve` picks a launch topic uniformly from the rival's
focus list and every rival product is the first product type in the
catalog, so the topic screen calls them all mobile apps. Nothing a rival
does reads the market walk.

- The launch topic stays one `worldRNG` word, now mapped through weights
  of multiplier²: a ×1.4 topic is 1.96× as likely, a ×0.6 one 0.36×.
- The week a topic crosses ×1.35 (the feature board's existing
  `boomAppetiteThreshold`), the strongest non-incumbent rival above
  strength 40 adds it to its focus. At a 10% weekly ship chance it
  arrives in about a quarter.
- A focus topic under ×0.7 for four shifts is dropped (each rival keeps
  one). Once their product ages out, your share returns to 1.0 on a
  market you still hold standing in.
- Rival product type becomes the argmax of the topic's `fitByType`.
- The forecast card gains its first topic-specific line: who is circling
  and why. Siege markers on the market map.
- Gated on a new `noticeMarketOpened`, so headless runs see today's
  rivals; the pacing suite runs at `rivalCount = 0` anyway.
- **The decision.** Take the boom's demand and expect company within a
  quarter, or build where the standing floor protects you. Sit through a
  crash to inherit the category.
- **How it fails.** With the fight bots over ten seeds, a boom launch
  should out-earn a quiet-topic launch by 15–30% over 26 weeks. Losing is
  wrong; winning by 80% is too.

### F4. The house field
*Nineteen named house founders play every league week and every daily,
so the table is full on day one and the people you climb past are ways
of playing.*

CloudKit ghosts are off (`GhostStore.swift:126`), so the daily's "real
players" are this phone's own daily from yesterday, and a signed-out
league week has a field of one: `LeagueRules.outcome` returns `.held`
when the field is one, so that player stays Bronze forever.

- On the first front-door open of a new league week or daily day, a
  background task plays the house roster through that seed to day 365:
  SoloSlow, Grinder and Neglectful in Bronze; CrunchHire and SaaS in
  Silver; InvestorBot variants in Gold; the best of each in Founders.
- Each house run writes an ordinary `GhostLog` under the existing league
  and daily ghost keys, so the table, the daily's four ghost rivals and
  the result card read it through paths that exist.
- Real players first (Game Center, cloud ghosts once signed), house
  founders fill to `LeagueRules.fieldSize` 20. Promotion stays 4 up, 4
  down.
- The result card names whoever finished directly above you and how they
  play: "Grinder — contracts only, never hired — finished $38,000 ahead."
- The bots move from the engine test target into a small shipping
  library the tests keep calling. No tests added.
- **How it fails.** Roster too soft, or an InvestorBot finds an IPO on
  some seed. Run the roster over the last eight weeks' seeds on a Mac
  before building UI; time one bot-year in release on the phone and cut
  the field to 9 if nineteen take over ten seconds.
- **Companion, if there is room:** *Keep this company* (Meta A2), which
  lets a finished daily or league company move into a save slot
  unranked, and is the only idea in the round that puts the paywall in
  front of daily players on a company they already care about.

### F5. Announce the date
*Tell the press a ship day. Hype holds, the copycat sharpens, and missing
it costs you in print.*

`ShipETA` projects a day nobody commits to, hype decays 2% a day, so
marketing reduces to "buy it late".

- An *Announce for <day>* sheet on any build with an ETA; the date
  defaults to ETA plus a slack you pick, at least three weeks out.
- While announced, hype decays 1% a day instead of 2% and campaigns land
  ×1.25; over 30 days that keeps 74% of hype instead of 55%. The
  newspaper prints the date, the war room counts down, the rail carries
  the deadline.
- First slip: reputation −4, hype ×0.6, a "slipped" headline. Second:
  −8, ×0.4, the announcement is void.
- An announced product is ripe for the copycat at 4 weeks instead of 8.
- State is `Product.announcedDay` and `slips`, encoded only when set.
- **The decision.** Commit and maybe crunch to hit it, or stay dark for a
  smaller launch with no deadline and no early clone.
- **How it fails.** Skills grow, so builds finish early and announcing at
  ETA + 2 weeks may never miss. Check actual ship day against the ETA at
  50% progress on a debug run; if 90% ship on time, tie the bonus to
  announcing early.

---

## Improvements to existing features

### I1. Premium means something
Premium earns 1.6 × 0.6 = 0.96 of standard's revenue with share weight
0.85 and a penalty under a 70 review (`Balance.json` `priceTiers`);
`LiveOps.swift:38` admits standard won every time. Change premium demand
to 0.6 + 0.02 × (review − 75), capped at 0.8, so a review of 85 reaches
×1.28; live bugs cost premium twice the sales penalty; the caption shows
the real percentage for this product's score. Premium then has a window
that the copycat closes, and budget is for the fight. No bot ever sets
premium. One day.

### I2. Put the children on the company's clock
Child stages are `[180, 540, 1100, 1800]` days since birth
(`BalanceConfig+Childhood.swift:70`) and the earliest births land around
day 200, so a teen arrives around day 1300 and a grown child around day
2000. The intern summer, disowning, moving out and the grown-stage
vignettes from iterations 9 and 11 almost never play. Change to
`[90, 270, 540, 900]` so a day-200 child is a teen by about day 740; keep
ages derived from the stage. No bot has a child and no fixture holds
one, so the pinned suites should not move; childhood unit tests that pin
stage days may need a re-pin, reported old and new. One day plus an audit
of the `kid_` events' stage gates.

### I3. Late-game money has teeth
Two pacing keys, both identity in the garage.
- **Event stakes scale with the company** (Systems B1). The 52 cash
  effects in unflagged company events have a median of $2,500 and a
  maximum of $20,000; campus rent alone is $12,000 a week, so a campus
  story question costs less than a week's rent. Multiply event cash
  effects and the money line on the button by
  `max(1, weeklyBurn / 4000)^0.5`: the garage reads 1.0, a studio about
  1.66×, a campus about 3.16×. One key; 0 means off.
- **The campus cliff** (Systems B3). The studio is $1,800 a week for 14
  desks, the campus $300k plus $12,000 a week for 40. Moving with 14
  people doubles the burn on day one and the only answer is to hire into
  it. Campus rent becomes $4,000 plus $200 per person above 14 ($9,200
  at 40); the $300k stays as the commitment. Check first whether any
  seed reaches the campus inside 730 days and whether the buy and sell
  price derives from rent.
Both move measured gates for bots that reach the studio: measure and
re-pin.

### I4. Answer the price war
`priceWarStarted` is `.notable` (`GameState.swift:773`): the clock stops,
share drops 0.10 for four weeks, and nothing is asked. Make it a sheet
with three answers. **Match:** budget for the four weeks and the penalty
lifts; the rival bleeds 1.5 strength a week and its grudge rises 25, so
two matches against the same rival pass `rivalGrudgeToAct` and its
espionage machine starts on you. **Out-ship:** a patch inside the war
ends it and pays +8 standing. **Outlast:** today's behaviour and the
deadline default. This is the join between rivals in the market and
rivals in espionage. If a rival at 45+ rarely runs an operation, Match is
free; check that first. One to two days. The companion one-day fix is
**the copycat takes the card** (Company B4): `copiedFeature` is written
and never read, so drop that card's fit to 0.5 in that topic for 26
weeks, give the clone +4, and show a "copied by Northwind" chip on the
card before you place it.

### I5. One queue for every question
The rail orders pause, tour, deferred, report, toast, tip
(`NoticeRail.swift:37–61`) and `PausePolicy` budgets only `.notable`
events. Wave two's demand sheets are not on the rail (iteration-11
leftover), and five pause writes bypass the policy by setting
`state.speed = .paused` directly: three in `FamilyDramaSystem`, one in
`CrimeSystem`, one in `PrisonSystem`. They are invisible to the budget and
to `lastPauseEvents`, and two headless photo passes lost to "a root sheet
always won the race". Every demand sheet becomes a `PendingChoice`-shaped
entry in one ordered queue with a severity, a deadline and a default;
"Let me think" works everywhere; past two critical pauses in a week,
further ones defer with their real deadlines; the five direct writes go
through `PausePolicy`. No keys. Three days, and it should land before F1
adds four more doors to the rail.

---

## Runners-up worth keeping

From the four reports, in the order they should be revisited:
*Keep this company* (Meta A2, S–M, the paywall meets daily players);
*The founder's cheque book* (Systems A2, only salary moves money between
company and wallet today); *Sunset and successor* (Company A3, no retire
action exists); *Character witnesses* (Life A4, bonds you built with
evenings spent in the courtroom); *The name carries* (Meta A3, the
dynasty heir inherits fame, notoriety and a nemesis); *Research forks*
(Company B2, the 20-node tree is done in 14 months and RP then banks
into nothing); *The ending points at the next run* (Meta B3, and the
heirloom page still says six endings when there are seven); *League
scores valuation, not net worth* (Meta B2); *The will names the
caretaker* (Life B3); *Custody that changes the week* (Life B2);
*Favours come due* (Life A5, a dead button and a dead field);
*VoiceOver can receive a clue* (Meta B5).

## Cut, and why

Founder mortality (runs are two to five years; realism only); economic
weather (cannot be both identity and matter without the re-pin of nine
suites); a prophetic market forecast (changes the walk every pacing bot
sells into); a cosmetic store, more notifications, or a season pass (the
paywall and the desk both print promises that forbid them); the life
score feeding anything (display-only by design); more late-game events
(I3 gives the existing ones teeth instead).

## Suggested lanes

Six lanes on a `scaffold-12` cut, each in its own worktree as before:

| Lane | Contents |
|---|---|
| A | F1 doors + Life B5 surfacing + Meta B1 coach tips |
| B | F2 record crosses over (board, name, spotlight) |
| C | F3 rivals follow the money + I4 price war + copycat card |
| D | F4 house field |
| E | F5 announce the date + I1 premium |
| F | I5 one queue + I2 children's clock + I3 pacing keys and re-pin |

Merge F first (the queue and the re-pin are what every other lane's
sheets and numbers land on), then E, C, B, A, D.
