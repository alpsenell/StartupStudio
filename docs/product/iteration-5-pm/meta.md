# Iteration 5 — progression, replay and the shape of a run

Read: `README.md`, the three `docs/product/*` files, `git log` to `ec829b7`; the
engine (`GameState`, `GameEngine`, `Progression`, `ProgressionSystem`,
`Difficulty`, `Investors`, `InvestorSystem`, the buyout half of `RivalSystem`);
`Goals.json`, `Investors.json`, the `requires`/`effects` vocabulary of
`Events.json`; `TycoonSave`; the onboarding, endings, HQ Now/Goals cards, the
tip strip, the weekly report and `GameSession`; `BalanceTargetsTests`,
`InvestorTargetsTests`, `BalanceDiagnosticsTests`, `PacingBots`,
`InvestorBots`, `ProgressionBots`, `SimRunner`. Played a fresh install on the
iPhone Air through onboarding, then a generated game at ×4 with no product,
relaunching through every pause until the biography. Screenshots are under
`scratchpad/pm/meta/` and cited by name.

**Where I disagree with the brief.** It counts four endings; in play there are
two — a fire sale the game calls a win from day 56, and a bell no measured
strategy gets within a fifth of — and nothing at all survives either. The thin
thing in this lane is not the number of modes; it is that an ending is not a
verdict and a second run is not a second *anything*. Everything below is ranked
by how much it changes what a run *is*, not how much it adds.

---

## 1. Where the shape of a run is thin now

**F1 — Every run starts from the same state; the seed only changes who walks
in later.** `GameState.newGame` (`GameState.swift:594-678`) starts every
company at `startingCash` $12,000, garage, reputation 10 (`:647`),
`market: .neutral` (every topic multiplier 1.0, `Market.swift:203`),
`city: .legacy` (Old Town, renting, `City.swift:47`), `rivals: .empty`. The
new-game flow (`01-onboarding.png`; `NewGameFlow.swift:8`) offers a name, a
look, an archetype — three spreads of the same 100 skill points
(`Balance.json` `progression.archetypes`: 55/25/20) — and a difficulty, which
is nine multipliers (`BalanceConfig.swift:1954-2008`) that "never touch the RNG
draw order" (`Difficulty.swift`). So the first 45–110 days
(`BalanceTargetsTests.swift:80-86`, the pacing gate for the first ship) look
the same on every seed and every setting: one person, one mobile app, no
income. "Try that year again" (`FounderBiographyView.swift`, `onReplay`)
replays a year that only ever had one shape.

**F2 — Two of the four endings are the same ending; one of them is a fire
sale and the other is unreachable.** `EndingKind.isSuccess`
(`GameState.swift:68-73`): `acquired` and `ipo` are both wins, same crown,
same screen, no post-mortem. A buyout opens on `reputation < 20` or
`cash < $5,000` or a day in debt (`RivalSystem.swift:613-615`; every company
starts at reputation 10), from day 56 at 40%/week (`Balance.json`
`rivals.buyoutEarliestDay`, `buyoutChance`). `loop-10.png`: May W20 of year 1,
$3,450 in the bank, **zero products ever started**, and Quill Systems offers
$20,460 — the sheet says "Accepting ends the run as a successful exit", and
"Sell the company" is the first button. `acceptBuyout`
(`RivalSystem.swift:695-716`) makes no distinction between that and the
strategic premium path (`:617-620`, reputation ≥ 60 and 2× the buyer's
valuation). Meanwhile the IPO needs `companyValuation ≥ $5,000,000`
(`investors.ipoValuationFloor`) where valuation = cash − loan + 6 × the last
four weeks' revenue + $1,500 × reputation (`GameState.swift:805-815`): at
reputation 100 the reputation term is $150k, so the rest is ≈ $200k/week of
sales; the best SaaS seed in the suite reaches $40k/week at two years
(`BalanceTargetsTests.swift:277`). No gate in either suite asserts an IPO or
an acquisition ever happens — `BalanceDiagnosticsTests.swift:361` prints the
count as a diagnostic. The "best ending in the game" is five times beyond the
best measured strategy; the "successful exit" is available to a company with
nothing in it.

**F3 — Chapters are a label on a card; nothing in the world reads them, and
two of the five perks do nothing.** `progression.chapter` is read outside
`Progression*.swift` by exactly four lines, all in `GoalsCard.swift`
(54, 70, 81, 92). None of the 83 company events gates on it —
`Events.json` `requires` kinds: `minTier` ×22, `minHeadcount` ×13,
`hasLiveProduct` ×12, `maxTier` ×10, `minReputation` ×7, `minYear` ×6,
`minCash` ×6, never a chapter. `.chapterReached` is `.notable`
(`GameState.swift:388`): the clock stops to show three new rows. Of the five
perks, three are read (`RivalSystem.swift:418` marketDarling,
`InvestorSystem.swift:60` investorRolodex, `EmployeeSystem.swift:752`
talentMagnet); **Press Contacts and Veteran Crew are awarded
(`g2_review_60`, `g4_three_amenities`), have balance numbers
(`pressContactsHypeBonus` 5.0, `veteranCrewMoraleBonus` 4.0) and are read by
no system** (grep over `Packages/TycoonEngine/Sources`). The chapter teasers
promise "a market that notices you" and "rivals who have heard of you"
(`GoalDef.swift`, `ChapterDef.titles`); the market and the rivals do not.

**F4 — Nothing survives a run.** One save slot (`SaveStore.swift:6-8`,
`slot0.json`); every path to a new game calls `store.deleteAll()`
(`GameSession.swift:138-147`). The only state that outlives a company is six
`UserDefaults` keys — sound, haptics, report auto-open, a manual-open count,
the onboarding flag, dismissed tips (`Haptics.swift:67-120`). The biography
(`loop-20.png`: "Bankrupt", day 210, the post-mortem's "Nothing was ever
started. 30 weeks of payroll and rent") names the longest-serving employee,
the best product and the family, and "Start a new company" destroys them. A
player on their third company has nothing that says so, and "with what you
know now" (`FounderBiographyView`) is entirely in their head.

**F5 — The goals know one company, and when it is done there is nothing.**
Chapter 4's six goals are raise a round, twenty on payroll, own a topic, buy a
rival, open the campus, three amenities (`Goals.json`); four of six opens the
next chapter (`progression.goalsToAdvanceChapter`). The suite asserts the
bootstrapper reaches chapter 5 on **0/10** seeds and calls that design
(`InvestorTargetsTests.swift:88-95`: "a bootstrapper reached chapter 5,
which is supposed to need the money"). A solo founder who ships great
products sits in chapter 2 with "Move into the loft" and "Hire somebody" as
the Now card's action for the rest of the run. Chapter 5 complete reads
"Every goal in this chapter is done. Nice." (`GoalsCard.swift:27`) and the run
has no end unless you sell or go public. At ×4 (4 days/s, `SimSpeed.swift`) a
game year is ~90 s of clock plus 30–45 pauses (`BalanceTargetsTests.swift:438-457`),
so chapters 3–5 are the tenth hour — and the tenth hour is where the goals
stop asking anything a 100%-owner can answer.

---

## 2. Five candidates, ranked

### 1. Two ladders — the cap table picks the chapters, and there is a fifth ending

**The player's sentence.** "Take the money and the next three chapters are a
board's chapters; keep every share and the game asks you to build something
that lasts — and there's an ending for that: *Still yours*."

**Problem.** F5 and F2. The late chapters are gated on things only a round
reaches, and the only endings a 100%-owner can reach are bankruptcy and a
buyout. The game's biggest decision — the term sheet — costs equity and a
board and buys the late game; declining it costs the late game and buys
nothing.

**How it plays.** Chapters 1–2 are unchanged. From chapter 3 the catalog
carries two tracks: `funded` (today's eighteen goals, untouched) and
`independent` (eighteen new). The active track is
`investors.equityRemaining == 100` → independent, otherwise funded. There is
nothing to declare: signing a term sheet is the declaration, it is one-way,
and the term-sheet sheet says so on the button ("You stop being independent —
the *Still yours* ending closes"). The independent ladder asks for a company
that lasts rather than one that grows: chapter 3 — six people who have each
been with you a year, four profitable quarters in a row, score 75, own a
topic, buy your office, move in together; chapter 4 — two products on the
market at once for 26 weeks, eight profitable quarters, score 85, $250k in the
bank, a department, marry; chapter 5 — *Still yours* ready, score 90, be worth
a million, frontier research, three children, five years in. The ending:
`canStayIndependent` = equity 100, ≥ 8 consecutive profitable quarters
(`investors.profitableQuarters` already exists), reputation ≥ 70, day ≥ 2
years; the action mirrors `fileIPO`, ends the run, and the biography leads
with the company as it stands — "You still owned 100%." The decision now has
a cost on both sides: the cheque closes a ladder and an ending; independence
closes the campus, the acquisitions and the bell.

**Touches.** Engine: `GoalDef.track: String?` (nil = both; decode default
keeps old content), `ContentCatalog.goals(inChapter:track:)`;
`ProgressionSystem.evaluateGoals` / `advanceChapter` / `refreshActiveGoals`
filter by track; four new `Condition.Kind`s (`profitableQuarters`,
`liveProductsWeeks`, `officeOwned` from `city.ownership`, `tenuredStaff`,
`readyToStayIndependent`), each a two-line `measure`;
`EndingKind.independent` (+ `isSuccess`, headline);
`GameState.canStayIndependent(balance:)` and `independenceBlocker`;
`GameAction.declareIndependence` → `InvestorSystem`, the same shape as
`fileIPO` (`InvestorSystem.swift:401`). Balance: two new gate values
(`investors.independentProfitableQuarters` 8, `independentMinReputation` 70) —
gates, not multipliers. Content: +18 goals in `Goals.json`. Screens:
`GoalsCard` header shows the track ("Chapter 3 · Studio · Independent"), the
term-sheet `DecisionSheet` gets one line, `InvestorsView` gets a "Staying
independent" card beside the IPO card with the same gate rows, `NowAction`
table for the new ids, biography banner for the new kind. Save: no format
bump (a new enum string; old saves decode). **Neutral by default:** the
pacing bots never accept a term sheet, so they sit on the independent track —
solo-slow, grinder and neglectful never leave chapter 2 and are byte-identical;
crunch-hire and saas can reach chapter 3, so the independent goals in each
slot pay *exactly* the reputation/cash/perk of the funded goal they replace,
and the pinned check is the baseline table unchanged. `InvestorTargetsTests`'
"bootstrapper reaches chapter 5 on 0 seeds" flips to "≥ 5 seeds" — that is the
feature. **Determinism:** no RNG; content plus arithmetic.

**Size.** L — three days: engine, content + bot, screens.

**Risk.** The independent ladder is the funded ladder with the numbers filed
off; or "eight profitable quarters" is automatic for a SaaS studio and
impossible for an app shop. Cheapest tell: a `GoalIndependentBot`
(SaaSBuilderBot + weekends + dating + every term sheet declined) must reach
*Still yours* on 3–7 of 10 seeds inside four years. Zero or ten kills it.

**Verify.** Engine tests: track flips on `acceptInvestment` and never back;
each new kind on a fixture; `declareIndependence` refused before the gate,
ends the run after; the bot gate above; `BalanceTargetsTests` untouched and
`InvestorTargetsTests`' funded timings unchanged. Snapshots: goals card with
the track label, the independence card, the new biography.

### 2. Exit terms — a fire sale is not a win, and a real one has an earn-out

**The player's sentence.** "When somebody wants to buy the company you choose
the cheque today or a bigger one in two quarters — if you can hit their number
with them on your board — and selling a company with nothing in it is no longer
called a win."

**Problem.** F2, as seen on the phone (`loop-10.png`): day ~140, no product,
$20,460, "successful exit", first button. The acquisition is the ending most
first-run players are actually offered, and it is one button with no decision
behind it; the strategic premium (`RivalSystem.swift:617-620`) lands on the
identical screen.

**How it plays.** (a) A distress offer (`rivals.lastBuyoutWasStrategic ==
false`) accepted ends as `EndingKind.soldUp` — "Sold up", not a success: the
post-mortem shows, the reason reads "Quill Systems bought the name and the
desks for $20,460." (b) A strategic offer opens a three-way sheet. *Cash*:
today's behaviour, end now at the price. *Earn-out*: 60% now and up to 40%
over the next two quarterly reviews — the acquirer takes a board seat with an
expectation drawn from what the company is currently worst at (the first
`BoardExpectation` it would miss today, else profitability), patience 12 weeks
(the harshest band the review already grades, harshness 2.17), each met
quarter pays 20% of the price, a miss pays nothing, two misses → the existing
`oustedByBoard` ("Replaced") keeping what was paid; after the second review the
run ends `.acquired` with the total. Signing costs `moraleAll −8` (the team has
been sold) and 26 more weeks of the founder's energy, health, partner and
kids. *Decline*: as today. Cash forfeits up to 40%; the earn-out risks 40% and
half a year of your life under the least patient board in the game.

**Touches.** Engine: `EndingKind.soldUp`; `GameAction.acceptBuyout` →
`acceptBuyout(terms:)` (old case decodes as `.cash`); `RivalSystem.acceptBuyout`
(`:695-716`) splits on the flag; `InvestorState.earnOut: EarnOut?`
(`buyerName, price, paid, expectation, remainingReviews, patienceWeeks`,
decode default nil); `InvestorSystem.quarterlyReview` (`:140`) reads it as one
more seated expectation and settles it — no draws; `oustFounder` note. Screens:
the buyout `DecisionSheet` gets the third option with the money on the button
(the after-state line already exists), `FounderBiographyView` money card
("Sold for $X · $Y paid · $Z forfeited"), `InvestorsView` board card
("Earn-out · 1 review left"). Save: optional field, no bump. **Neutral:** the
pacing suite runs with `rivals.rivalCount = 0` (`BalanceTargetsTests.swift:31`)
and no bot in either suite answers a buyout. **Determinism:** the acquirer's
expectation is arithmetic on state; no draws added.

**Size.** M — two days.

**Risk.** The earn-out is free money (two quarters you were going to play
anyway) and is always taken; or the 12-week board makes it a coin flip and it
is never taken. Tell: an `AcquirerBot` (InvestorBot that takes the first
strategic offer on earn-out) — if it collects ≥ 95% of the price on 8+/10
seeds the number is too soft, if ≤ 60% on 8+/10 too hard; target 3–7 seeds at
full price.

**Verify.** Engine: distress → `soldUp`, `isSuccess == false`; strategic cash
→ `acquired` at the price; earn-out met/met = 100%, miss/met = 80%, miss/miss
→ ousted with 60% kept; ending day; save round trip. Snapshots: the
three-button sheet, both biographies.

### 3. Origins — four ways to found the company

**The player's sentence.** "Before you name the studio you choose how it
starts: alone in a garage; with a co-founder who owns a third of it; as a
spin-out with a client, a deadline and a non-compete; or with the bank behind
you and your flat behind the bank."

**Problem.** F1. The choices in onboarding change three numbers and nine
multipliers; the first quarter of every run is the same quarter.

**How it plays.** The Stakes page gains four origins above the difficulty
rows; the biography's first line names it; replay keeps it.
*Garage* — today. *Co-founded* — a second person in the garage on day 0
(skills ~40/40/40 from a fixed table, one trait shown, one hidden), salary $0
until the loft and fair pay after, and they own 30%: `equityRemaining` starts
at 70, so every buyout, IPO and net-worth line is ×0.7 forever and the investor
filter `equityRemaining − equityAsk ≥ 20` (`InvestorSystem.swift:~82`) closes
the biggest cheques sooner. First product roughly twice as fast; last screen
30% smaller. *Spin-out* — you left a big company with a client: a signed
12-week contract on day 0 (~$9,000, fixed points, a named client, deadline day
84, the usual penalty), reputation 15, and a non-compete — one of the twelve
topics is locked for 52 weeks (`startProduct` refuses it; the flow greys it
with the date). Rent paid for a quarter; a deadline that grades your first
crew; a topic you cannot touch. *Mortgaged* — you own a flat: home tier
`apartment` (its rent), and the bank has already lent $25,000 against it
through the existing secured-loan path (`loanBalance` 25,000 with the
guarantee flagged; cash $37,000). A year of runway; interest every week; stay
in the red and the savings go, then the flat — the eviction ladder that
already exists. Every origin costs something on the other side, and none of
them is a multiplier.

**Touches.** Engine: `FoundingOrigin` on `GameState` (Codable, default
`.garage`, decode default), applied inside `newGame` *after* the two RNG draws
and the stream derivations as pure state deltas; `startProduct` checks
`lockedTopics: [String: Int]`; an `isCofounder` flag on `Employee` exempting
them from fair-pay/underpaid until the loft (`EmployeeSystem`). Balance: an
`origins` block with the four deltas (cash, loan, reputation, contract points,
co-founder skills, equity). Screens: `NewGameFlow` difficulty step,
`FounderSetupSheet` (same picker), one biography line, `NewProductFlow` topic
lock; `GameSession.replayCurrentGame` passes the origin. Content: none. Save:
no bump. **Neutral:** `.garage` is the default in every `newGame` call, so the
harness and old saves are bit-identical. **Determinism:** deltas only; the
co-founder's `appearanceSeed` is derived from the seed the way `worldRNG` is,
not drawn.

**Size.** M — two to three days.

**Risk.** One origin dominates — most likely Co-founded (a free skilled pair
of hands on day 0 is worth more than 30% of a company that usually ends
bankrupt). Tell: SoloSlowBot on each origin over the ten seeds; if any origin
wins on both `firstShipDay` and `finalCash` on ≥ 9/10 seeds its cost is too
small (raise the stake to 40%, or start the co-founder's salary at the first
hire).

**Verify.** `SeedRoundTripTests` extended: same seed + origin → same first
month, `.garage` byte-identical to today; day-0 state per origin; the
non-compete refuses and unlocks on day 364; the spin-out contract settles on
day 84 like any other; `BalanceTargetsTests` untouched; snapshots of the
Stakes page and the biography line. This is the one candidate that leans on
the economy lane (a loan, a contract); the reason it is here is that it is a
different first hour, not a different economy.

### 4. Legacy — bring one thing from the last company

**The player's sentence.** "When a company ends, the next one can start with
one thing from it — your best person, your name, or your address book — and
each of them costs you something in the garage."

**Problem.** F4. Nothing lives above a run; the second company starts exactly
like the first; the biography is read once and deleted.

**How it plays.** The moment a run ends the session writes a `RunRecord`
(seed, founder, company, ending kind and day, chapters, best product
name/score/topic, the longest-serving employee as a full `Employee` value, up
to three warm contacts, final reputation, difficulty, origin) into a legacy
ledger that survives `deleteAll`. When the ledger is non-empty the new-game
flow gains a page after Stakes, *Bring one thing*. *The person*: your
longest-serving employee joins on day 0 at their **last** salary — at a studio
that was $600–1,200/wk, so against $12,000 the runway drops from 22 weeks to
~10 — and takes one of the garage's three desks; both traits known; the bond
starts warm. *The name*: reputation starts at 20 instead of 10 (candidates,
contracts and the first term sheet all read it), and the press remembers the
last one: review expectation +5 for the whole run. *The address book*: up to
three contacts at rapport 50 — each a deal in the networking layer — that fade
unless you spend evenings on them (existing decay). *Nothing*: today. The
ledger keeps every record, so the biography gains one line: "Your third
company. The first two: bankrupt on day 210; sold up on day 402."

**Touches.** Save: a second `SaveStore<LegacyLedger>` in `Saves/Legacy/` — the
class already takes a directory, no change to `SaveStore`. App: `GameSession`
writes the record when `gameOver` first appears (the autosave hook sees the
state) and reads the ledger for the flow; `NewGameFlow` and `FounderSetupSheet`
page; a biography line. Engine: `Legacy` value on `GameState` (Codable, default
`.none`, decode default) so replay with the same legacy is the same game;
`newGame` applies the person/reputation/contacts as deltas after the RNG setup
(no draws; the carried employee keeps their own id and appearance seed);
`ReviewModel` reads `state.legacy.reviewExpectationDelta` (0 by default).
Content: none. **Neutral:** `.none` is byte-identical. **Determinism:** the
legacy is an input like the seed.

**Size.** M — two to three days; the ledger and its tests are a day.

**Risk.** The carried person makes the second run trivially easier (a level-2
senior in a garage). Tell: SoloSlowBot with a carried studio-era employee — if
`firstProductScore` clears the 40–66 gate's ceiling and `finalCash` doubles,
the salary is not biting; carry them at their last salary, never garage fair
pay, and count the desk.

**Verify.** Save tests: ledger round-trip, survives `deleteAll`, a corrupt
ledger reads as empty and never blocks a new game. Engine: day-0 state per
choice, `.none` byte-identical, replay with a legacy deterministic. App: the
record is written exactly once per ending. Snapshots of the page.

### 5. Chapters open with a question

**The player's sentence.** "Reaching a chapter stops the clock for a real
choice with a deadline — a lease, a headline, an introduction, an offer — not
for a card that says a number went up."

**Problem.** F3. The chapter is read by four lines of UI, gates no content,
and two of its five rewards are placebo.

**How it plays.** `advanceChapter` schedules a `once` story beat for the next
day through `narrative.scheduled` (`Narrative.swift:79, 108` — the path
follow-ups already use); each is a `narrativeChoice` with `respondByDays` and
an `autoChoiceIndex` that is the no-op. Four beats. Chapter 2, *The lease*: the
loft's landlord — sign 52 weeks (deposit halved on the upgrade; `relocateOffice`
refused until day + 364) or month-to-month. Chapter 3, *The headline*: the
trade press names your category — +20 standing in your best topic (the
iteration-3 standing system) and review expectation +5 there, or "no comment".
Chapter 4, *The introduction*: a warm intro — a seed fund's term sheet with a
board seat lands next week, skipping `earliestOfferDay` and the cooldown, or
keep bootstrapping. Chapter 5, *The call*: the strongest rival's strategic
offer at 1.5× *today's* valuation, seven days, or "we're going for the bell"
(+5 reputation, the buyout cooldown doubles for a year). And wire the two dead
perks: Press Contacts → `MarketingSystem` hype, Veteran Crew → `EmployeeSystem`
morale floor, so a chapter's reward does something. Each beat is a decision
whose cost lands weeks later.

**Touches.** Content: `requires.minChapter` on events (new optional field,
default nil) and four events using the existing effect types (`cash`,
`reputation`, `hype`, `market`, flags). Engine: `ProgressionSystem.advanceChapter`
appends a `ScheduledNarrativeEvent`; one guard line each in
`CitySystem.relocateOffice`, `InvestorSystem.offerCheck` (`:54`) and
`RivalSystem.buyoutCheck` (`:600`) reading a flag; two perk reads. Screens:
none new — `DecisionSheet` already draws story questions. **Neutral:** the
bots auto-resolve every beat at the deadline to the no-op option; four extra
`.narrativeChoice` pauses per run against a 35–50/year budget; the perk reads
are 0/+0 for every pacing bot (none runs a campaign or builds three amenities —
InvestorBot does, so re-run `InvestorTargetsTests` and expect a small morale
lift, not a gate move). **Determinism:** scheduled by day, no draws.

**Size.** S–M — one to two days. The copy is the narrative PM's to write
well; the hook and the four decisions are this lane's.

**Risk.** Four beats become four scripted moments the tenth playthrough skips,
and a beat whose "no" is free is a toll booth. Tell: if playtesters take the
same side every time, cut the beat rather than tune it.

**Verify.** Engine: a chapter opening fires its beat next day, once, with the
deadline; each flag's guard; the auto-choice leaves state unchanged; pauses per
year inside budget; a campaign with Press Contacts posts +5 hype and a veteran
crew's floor is +4. Content test: every `chapter_N_opens` exists with
`minChapter`.

---

## 3. Cut

- **Hall of fame / a gallery of past runs.** Pure reward — a list nobody
  manages. Legacy's ledger stores it; a screen for it is not a mechanic.
- **Weekly seed / shareable seeds.** Social category; the engine already
  replays a seed and sharing one decides nothing.
- **Ironman, permadeath, mutators.** A settings toggle; iteration 3 cut
  mutators for the same reason, and Hard already proves "same game, poorer"
  changes nothing a player does.
- **New Game+ (carry everything).** Pure upside that makes the second run
  easier; "one thing, with a cost" is the version that survives.
- **Step down / retire as an ending.** No push behind *when* — the founder
  does not age — so it is a button; folded into *Still yours*.
- **Chapter select / skip the garage.** Removes the first hour instead of
  fixing it; the pacing contract says the first product takes 45–110 days on
  purpose.
- **A ghost of the last attempt on replay** ("last time Quill offered $20,460
  today" on the rail). Information, not a decision; worth a day inside Legacy
  once the ledger exists, not a feature.

If the lead takes one: **Two ladders**. If two: **Exit terms**, because it is
the ending a first-run player is actually offered.
