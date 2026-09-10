# Cross-cutting systems and pacing: iteration 12 candidates (pm-systems)

*Opus PM pass, 10 September 2026, read-only over `iteration-11` @ a12f3be.*

I read the code and edited nothing, ran nothing, and added no tests.

## Where I disagree with the brief

Two numbers in the brief are out of date. The catalogs hold **204 company events and 299 life events** (the brief says 147 and 208). Wave two added the rest.

The company event pool does **not** go quiet after year 1. The events that need no flag number 43 in the garage and 57 at the campus in year 3. The problem is that their stakes stay small, not that they stop firing (see B1).

The real thin spot is structural. The identity rule has made every system since iteration 9 opt-in:

- 221 of the 279 life events that can roll are gated on 35 flags. Only rooms the player has to enter raise those flags. Just 58 can reach a founder who plays the company game.
- 57 of the 124 company events that can roll are gated on `crime_` / `money_` / `spy_` flags.
- Every dark-life system does nothing until a button is pressed:
  - `AssetsSystem.swift:56` (`isEngaged`)
  - `FameSystem.swift:27`
  - `OfficeSecretsSystem.swift:36` (`watching`)
  - the dirty-money offer waits for `.noticeFinancesOpened`
  - family drama waits for the family room

BitLife works because life happens to you. Here it only happens to players who go looking for it.

## A. Five new features, ranked

### A1. Nobody asks permission: four one-time doors from the company into the dark half (M, about 3 days)

**Pitch.** At three weeks of runway the shark calls, even if you never opened Finances. After a month of crunch, somebody at the launch party offers you something. After a launch reviewed 80 or better, a journalist wants your take. Your mother's care bill arrives by text. Each door is one question you can decline. Saying yes wakes up a room that already exists.

**The four doors:**

| Door | Condition | What "yes" does |
|---|---|---|
| The shark | `runwayIsShort` (4 weeks or less, `OfficeSceneView.swift:109`), `day >= 90`, Finances never opened | Runs the existing `DirtyMoneySystem` offer as if `noticeFinancesOpened` had been sent |
| Vices | Founder schedule on crunch for 21 of the last 28 days | Sets `assets.isEngaged` and seeds a vice at the dependency a launch party already adds. Crunch-hire bots meet this on most seeds. |
| Fame | A launch reviewed 80 or better, or reputation 60 or more | Opens the feed with a first post already drafted, which moves `state.fame` off `.empty` |
| Family care | `day >= 365` and a seed-derived parent reaches care age | Opens the family room at the care-bill beat: pay from the wallet, give the spare room (one evening a week), or leave it to the sibling (bond cost) |

**Rules for all four doors:**

- Each fires at most once per run.
- Each lands on the notice rail as a `.deferred` notice (priority 2) plus a phone post. It is not a `pendingChoice` or a pause, and it does not touch `narrative.lastFiredDay`. So the company and life rolls and the pause budget are unchanged.
- If the deadline passes, the answer is decline and the room stays dormant.
- There are no random draws; every condition is a plain read of the state.
- Bots never answer, so they always get the neutral outcome.
- The day-30 fixtures cannot reach `day >= 90`.

**Why it is the thin spot.** See above. The dirty-money lane was written for a founder three weeks from bankruptcy, and today that founder only meets it if they happened to open Finances in time.

**Touches.** The `DirtyMoneySystem` offer gate, `AssetsSystem`, `FameSystem`, `FamilyDramaSystem`, `NoticeRail` `.deferred`, `PhoneSystem`. Four follow-up-only defs, so the roll never picks them.

**Balance keys.** 0–2; the thresholds can stay file constants.

**How it fails.** The doors can read as the game punishing players for not opting in, and the pacing suite never measures the "yes" branch. Cheapest early tell: over the 10 BalanceTargets seeds, count how many runs meet each door's condition. Fewer than 2 in 10 means the door is dead; more than 8 in 10 means it is a nag.

### A2. The founder's cheque book: distributions and a founder loan (M, about 2 days)

**Pitch.** Take money out of the company, or put your savings in when it runs dry. Both cost you something.

**Mechanic:**

- `takeDistribution(amount)`: company cash goes down by `amount`, and the wallet goes up by `amount × equityRemaining%`. The investors' share leaves the company too. So a founder at 100% equity gets a dollar for a dollar, and a funded founder at 55% gets 55 cents.
- `lendToCompany(amount)`: wallet money goes into the company as `economy.founderLoan`. `companyValuation` subtracts it the way it subtracts `loanBalance` (`GameState.swift:1403`). It is repaid first and lost in a bankruptcy.

**What it costs:**

- A profitable quarter is simply "cash grew across the quarter" (`InvestorSystem.swift:162–163`). A distribution bigger than the quarter's profit resets `profitableQuarters`. That is the 8-quarter independent ladder: `g4i_eight_profitable_quarters`, `g5i_ready_to_stay_independent` and *Still yours*.
- A seated board adds pressure, reusing `founderPayBoardPressure` (4.0) for every 10% of cash distributed.
- Distributions from the last 13 weeks count toward the founder pay band (`FounderQueries.swift:107`, 1.5× the team median), so the team reacts to them like salary.
- A wallet behind a signed guarantee is still collateral, so moving money there is not fully safe.

**Why it is the thin spot.** Of 152 `GameAction` cases, only `setFounderSalary` moves money between the company and the wallet. Salary is capped at $5,000 a week and carries a morale penalty. Yet the wallet pays for the whole life half: homes up to $250k, the $60k car, children, the assets room, `investInFriend`, and the house that secures a guarantee. The reverse is missing too: a founder with savings cannot rescue the company except through the mortgaged origin on day 0.

**The decision.** Money in the company is runway, valuation and the streak. Money in the wallet survives bankruptcy, buys the life, and counts toward net worth (`Investors.swift:502`).

**Touches.** `GameAction` (+2), `FinanceSystem`, `InvestorSystem`, the pay band, the money sheet. Save: one optional Int.

**Balance keys and draws.** No new keys, no bot calls it, and there are no draws.

**How it fails.** At 100% equity, moving money doesn't change net worth, so only the streak and the runway price it. If the streak cost doesn't bite, this is a free "move money to safety" button. Tell: an independent bot that distributes everything above 8 weeks of burn each quarter. If it still reaches *Still yours* on 8 or more of 10 seeds, the cost is fake.

### A3. Fame is a spotlight (S, 1 day)

**Pitch.** Being famous makes everything you hide easier to find.

**What exists today.** Notoriety already raises crime discovery and espionage trace odds (`Espionage.swift:414`: `1 + notoriety/100 × notorietyDiscoveryFactor`). Fame raises only the odds of an affair being found (`FamilyDramaSystem.swift:73`). Otherwise fame (hype, applicants, the podcast, book, keynote and TV) is pure upside next to every illicit system.

**Mechanic:**

- Add `spotlight = 1 + 0.25 × fameRung`, using the five existing rungs: 1.25× at *public* up to 2.25× at *star*.
- It multiplies `Crime.discoveryChance`, `Espionage.traceChance` and the odds that laundered money is found.
- While there, turn the `Crime.launderDiscovery` constant into a balance key, which closes a wave-two "Not done" item.
- A conviction or a trace drops fame one rung.
- Print the spotlight as its own line in the odds already shown on the operation buttons.

**The decision.** A TV slot or the dirty money, not both.

**Neutrality.** A run that never posted has fame at rung 0, so the multiplier is exactly 1.0. It only multiplies existing roll thresholds and adds no draws. 2 new balance keys.

**How it fails.** It is invisible unless printed, and few players engage both halves. It is cheap enough that this does not matter.

### A4. Economic weather: a deterministic business cycle (L, about 4 days)

**Pitch.** The whole economy has seasons. Talent is cheaper and money is scarce in the trough; everything is expensive at the peak. The seed decides when your winter comes.

**Mechanic:**

- A pure function `cycle(day, seed)` produces a sine wave with a period of 2–3 years. The phase and period come from a SplitMix64 hash of the seed, the way seed codes are derived, so it draws from no stream. It reads exactly 1.0 for the first 180 days.
- The levers are read live where they are used. `SeasonTwist.apply` can't do this because it changes the balance once, at creation (`RunMode.swift:144`).
  - investor `offerChance` drops from 0.45 to 0.2, and `roundValuationPremium` from 2.5 to 1.5
  - contract pay per point moves ±20%
  - `salaryBase` (180) moves ±15%
  - `marketSizeScale` moves ±15%
  - crypto and property prices move where the assets room is in use
- The Monday newspaper's market column prints the forecast, and the Business desk shows the phase.

**The decision.** Hire and buy through the trough at the risk of your runway, or hoard. Raise money at the peak, or wait. It also gives a second playthrough a different shape.

**Balance.** It can't be neutral and still matter. Ship at amplitude 0, measure the BalanceTargets and InvestorTargets suites at 0.15, then re-pin the gates: the iteration-5 retune path. 3 new balance keys.

**How it fails.** It's just noise on revenue if the player can't see it coming. Tell: a bot that hires only in troughs should beat one that hires evenly on 6 or more of 10 seeds. If not, there is no decision.

### A5. The chair: a standing COO built from the caretaker (M, 2–3 days)

**Pitch.** Seat someone to run one half of the company while you are still in the building. They make calls you would not make.

**Mechanic.** The sabbatical caretaker already makes one real `GameAction` a week, chosen by their traits (`SabbaticalSystem.swift:14–21`). Let a senior hire with a bond of 50 or more hold that seat permanently, over one domain:

- **People:** praise, training and raises, paced by the stagnation clock.
- **Live ops:** patches and support desks.

**What it costs:**

- Their salary goes up 1.3× and they stop producing.
- Their traits decide their calls: a Speedster patches early, a Perfectionist over-trains.
- Gestures made by the COO earn no founder bond.
- Rivals are twice as likely to poach them.

**Why it is the thin spot.** An employee not recognised for 364 days loses 10 morale target, and only a hire, raise, promotion or training resets that clock (`EmployeeSystem.swift:313`). Training costs $800 with a 14-day cooldown. A 40-person campus therefore needs 40 manual recognitions a year: bookkeeping, not choices.

**Neutrality.** No bot seats one. It draws from `socialRNG` only while someone is seated. Save: one optional UUID.

**How it fails.** It plays the game for you. If nobody ever removes a COO after a call they disliked, the costs are too low.

## B. Five improvements

### B1. Event stakes that scale with the company (pacing; S, 1 day plus measurement)

**Today.** The 52 cash effects in the company events that need no flag have a median of $2,500, a p90 of $8,000 and a maximum of $20,000. Campus rent alone is $12,000 a week. Only 8 of the 67 events that need no flag require the studio or the campus. A campus story question costs less than a week's rent, so late-game decisions are free.

**Change.** Multiply event cash effects, and the money line on each button, by `max(1, weeklyBurn / 4000)^0.5`.

| Stage | Weekly burn | Multiplier | Median cash effect |
|---|---|---|---|
| Garage, early loft | under $4k | exactly 1.0 (fixtures stay byte-identical) | $2,500 |
| Studio | about $11k | about 1.66× | about $4,150 |
| Campus | about $40k | about 3.16× | about $7,900 |

**Cost.** 1 new balance key (the reference burn; 0 means off). BalanceTargets bots that reach the studio will move, so measure and re-pin.

### B2. Rivals grow up with the market (pacing; S)

**Today.** A new rival's founding strength is a flat 15–55 with no year term (`RivalSystem.swift:129`). At $4,000 per strength, the strongest new rival is worth about $330k, so by mid-game every rival is buyable. Every acquisition brings in another small one, and the incumbent comes only once.

**Change.** Raise the minimum by 6 and the maximum by 8 each year after the first, capped at 45 and 85. That makes year 3 a 27–71 field. It is the same single `worldRNG` draw, rescaled, so no new draws.

**Cost.** 2 new balance keys. The pacing suite runs with `rivalCount = 0` and is untouched. The investor suite (`rivalCount = 4`) moves and needs re-pinning.

### B3. The campus cliff (pacing; S)

**Today.** The studio costs $1,800 a week for 14 desks ($129 a desk). The campus costs $300k up front plus $12,000 a week for 40 desks ($300 a desk). Moving with 14 people adds $10,200 a week of rent on day one, which roughly doubles the burn, and the only answer is to hire into it. That is a spiral risk right after the biggest purchase in the game.

**Change.** Campus rent becomes $4,000 plus $200 for each person above 14, which is $9,200 at 40 people. The $300k up front stays as the commitment.

**Cost.** 1 new balance key. First read the campus column of `baselineTable`: if no seed reaches the campus in 730 days, the gate (campus no earlier than day 500) is unaffected. Also check whether the office buy and sell price is derived from rent.

### B4. One queue for every question (M)

**Today:**

- The rail's order is pause 0, tour 1, deferred 2, report 3, toast 4, tip 5 (`NoticeRail.swift:37–61`).
- `PausePolicy` budgets only `.notable` events, with a 10-day budget; `.critical` always pauses (`GameState.swift:924`).
- Wave two's demand sheets are not on the shared rail (iteration-11 "Not done").
- Five places pause the game by writing `state.speed = .paused` directly: three in `FamilyDramaSystem`, one in `CrimeSystem`, one in `PrisonSystem`. The pause budget and `lastPauseEvents` never see them.
- Two headless screenshot passes lost to "a root sheet always won the race" (the parole board, the sabbatical return).
- The `autoPausesStayWithinBudget` gate (mean of 45 a year for crunch, 30 for solo) is measured only on bots that never open a dark room.

**Change.** Every demand sheet becomes a `PendingChoice`-shaped entry in one ordered queue with a severity, a deadline and a default. "Let me think" works everywhere. Past two critical pauses in a week, the rest become deferred with their real deadlines. The five direct writes become events that go through `PausePolicy`.

**Cost.** No new balance keys.

### B5. The office shows the dark half (S–M)

**Today.** `OfficePressure` reads crunch, runway, debt, bug load, people leaving and a pending offer (`OfficeSceneView.swift:73–109`). It reads nothing from iterations 10 or 11. N5's clues are drawn over the scene by the app, not by `OfficeDirector` (iteration-11 "Not done").

**Change.** Add three fields:

- `hearingSoon`: a suit waiting by the door in the week before a court date.
- `heat`: a black car outside in a week the shark is owed money.
- `fameRung`: a photographer at the window at *notable* fame or higher.

Also move N5's clues into the director. Each is information the player can act on, shown on the game's face.

**Cost.** No new balance keys.

## Cut list

- **Founder aging and mortality:** runs last 2–5 game years, too short for aging to bite without faking the clock. It is a realism argument.
- **Public-company quarters after an IPO:** a new system for the few players who IPO and keep going.
- **Founder attributes growing from the work:** a real gap. `finance` has no `FounderSystem.practice` call site at all, and `technical` gets only 0.5× from shop talk. But at a practice gain of 0.35 × (1 − v/100) it moves about a point a year, and it is pure upside.
- **More late-game events:** that is "more content"; B1 gives the existing ones teeth.
- **LifeScore feeding a system:** its source comment says it is display-only by design, and a consumer would turn it into something to optimise.
- **An HR review budget:** the same bottleneck as A5, and funding it is always the right answer.
- **Wiring `office_confrontation`:** nothing raises it on purpose, so confrontations only happen when the founder speaks up.
- **Rival economies, Bet the Tree, sequel hype carry-over:** these were already on the iteration-5 and iteration-8 lists, and the reasons they stayed there still hold: a new subsystem, research-only, and pure upside.

## Constraints

- All ten items together add about 12 balance keys, which is tiny next to the balance config's roughly 6.5 KB. Tests that pass the balance by value at many call sites still need hoisting to avoid the stack cliff.
- None of the ten adds a random draw on the default path.
- Save additions are one optional Int (A2) and one optional UUID (A5).
- A4, B1, B2 and B3 deliberately move measured pacing gates and need a re-measure and re-pin. A1, A2, A3, A5, B4 and B5 are neutral by construction.
