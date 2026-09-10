# Iteration 15 — PM report: the founder's life

*10 September 2026. Lens: everything the founder does as a person, against
BitLife-class life sims and against the company half. Tree `iteration-15`
@ 6660ccc. Read-only; nothing here is built.*

**Where I disagree with the brief.** The brief's example gaps (ageing,
death, a degree, politics, the partner's career) are BitLife's shape, and
BitLife runs a life from 0 to 90; this game runs a company for two to
five years, and its life half already has about 45 verb families and,
on the family fixture, over a thousand buttons. The thin place is not
missing verbs. It is that the life half has exactly one scarce resource
(three evenings a week) and almost no pipe to the two things the company
half is made of: money and the calendar. Everything below is ranked on
that, and the BitLife-shaped items are in the cut list with reasons.

## Diagnosis

**What exists, counted.** `GameAction.swift` carries about 45 life verb
families (the weekend, the schedule, the salary, the home, the ladder,
children, friends, relatives, five skills × three methods, the side
project, the sabbatical, decor, 23 people interactions, four assets
kinds, the doctor, therapy, vices, three tables, the lottery, crypto,
four post kinds, crime, prison, dirty money, family drama, doors). The
scarce resource is `LifeState.eveningsSpentThisWeek` against
`life.eveningsPerWeek` = 5 / 3 / 1 for chill / normal / crunch, and
sixteen call sites spend one (`spendEvening(` in the reducer,
interactions, children, training, side project, three in assets, doors,
two in office secrets, one narrative effect, partner / hang-out / mentor,
instant activities, friends, relatives). On `l3-family-day900` (day 905,
married, two children, three friends, five relatives, 35 staff, wallet
$18,400, normal schedule) the week offers roughly: 4 instant activities,
3 partner evenings, 2 child evenings, 3 friend evenings, 5 relative
evenings, 15 training rows, 35 hang-outs, 105 mentor rows, 23
interactions across ~45 targets, therapy — about 1,200 buttons competing
for 3 evenings, which is a real economy and the best thing on the tab.
The verbs with no trade-off at all are few and known: `callFriend`
(free, weekly), `postToFeed` (free, daily; the only cost is a 10% weekly
cancel roll past 12 posts), `placeDecor` (cosmetic), `buyItem` (mood
drift, nothing else) and the weekend, which is a free meter top-up
priced only in wallet dollars. Life *happens* rarely: the random life
beat rolls every 14 days at 35% (`NarrativeSystem.rollLifeEvent`), about
nine a year, and the 303 events in `LifeEvents.json` (237 flag-gated)
all compete for those nine slots; only five sites raise a life event
directly (`ChildhoodSystem`, `FamilyCalendar`, two in `OfficeSecrets`,
`SocialSystem`).

**What is thin, with evidence.** (1) *The wallet is a rounding error.*
Wallets on the four fixtures are $2,400 / $5,040 / $2,555 / $18,400
against company cash of $11,750 / $90,875 / $644,446 / $616,014. The only
pipes between them are the weekly salary (default $200, `founderPayExcess`
bites above 1.5× the team median) and `takeSecuredLoan`; `buyBackRound`
spends company cash, and the founder can neither lend to the company nor
draw from it. Worse, `LifeSystem.checkEviction` bails the founder out
automatically with a `rescueSalary` up to $5,000 a week, and
`FounderQueries.founderPayExcess:101` exempts it — so a founder who moves
into the penthouse ($2,500 a week on a $200 salary) is paid by the
company with no morale or board cost, and never chose it. (2) *Health is
unmanaged until a cliff nobody warns about.* `release-studio-day400` has
health 16.6 and `release-campus-day900` 26.3; the hospital fires at 10
(`hospitalHealthThreshold`), drift is −0.2 a day on normal. The one
warning event, `doctor_says`, is gated `maxEnergy: 55` while those
founders sit at energy 95–99; the coach tip `tip.state.hospital` fires
after the stay. Health's only company edge is the 0.3 wellbeing weight
in `founderOutputMultiplier`. (3) *The partner is a meter with a name.*
`FamilyState` holds affection, a name and a seed; `advanceRelationship`
draws the name from `partnerNames` with `state.rng`, so the player never
chooses whom; `partner_job_offer` prices "take it" at relationships +22
and "stay" at −16 and nobody moves. An ex is a string
(`FamilySettlement.exName`) even though `equityToEx` hands them 3–12
points of the company that `buyBackRound` cannot reach (it reads
`RaisedRound`s only). A 7-day `vacation` sets `awayUntilDay`, and
`RelationshipSystem.driftAffection` doubles the affection drift while
away (−0.6 a day, about −4 a holiday) while the meter reads +10 — the
game's own holiday costs the marriage and the sheet does not say so.
(4) *Home is a rent tier.* Four tiers, rent charged weekly
(`LifeSystem.swift:403`), no ownership (`CityState.ownership` exists for
the office only — the mortgaged origin "owns a flat" and pays $120 a week
on it), no location, while `city.districts` has rent multipliers 0.7–2.2
that only the office reads. (5) *The two calendars never meet.* The
diary (`FamilyCalendar`: anniversary, birthdays, parents' birthdays) is
never read by the announce sheet (J5, `Product.announcedDay`) or the
launch day; `wedding_on_launch_week` is a one-off event that shows the
join is wanted. (6) *Children's memories do nothing during the run*: read
by `Legacy` (the successor), custody grading and three interaction
lines, nothing before a divorce.

## Twenty candidates

| id | name | one line | size | reads | writes |
|---|---|---|---|---|---|
| F1 | Skin in the game | Lend the company your own money; draw a dividend when it can afford one | M | wallet, cash, runway, board, equityRemaining | economy (director loan), wallet, ledger, boardPressure, founderPayExcess |
| F2 | Hire your partner | Put your partner on payroll; the marriage now reads the office | M | affection, partner seed, employees, work pace | employees, family, alumni, divorce settlement, founderPayExcess |
| F3 | Where you live | The home gets a district; the commute is paid in evenings | S–M | city districts, office district, homes | life.homeDistrict, eveningsPerWeek, livingCosts, child memories |
| F4 | The ex on the cap table | Buy the ex's slice back, or let it ride; the ex stays in the address book | S–M | settlement.equityGiven, valuation, cash, wallet | equityRemaining, settlement, networking.contacts |
| F5 | The diary reads the roadmap | Announcing a date within two days of a birthday or anniversary is a choice you make on purpose | S | narrative.scheduled, announcedDay, ship day | memories, affection, hype, family_date_missed |
| F6 | Take them with you | A family holiday beside the solo one: less recovery, more marriage | S | family, children, wallet | affection, child bond, memories, meters |
| F7 | The doctor's letter | A dated letter when health crosses 40, with the number and the days to the hospital | S | health, drift, doors.armed | narrative.scheduled, wallet, health |
| F8 | Own the home | Buy the flat: no rent, headroom for the secured loan, half of it in a divorce | M | wallet, homes, city.buyPriceFactor, guarantee | life.homeOwnership, homeValue, net worth, settlement |
| F9 | The rescue is a choice | The company's bailout of a broke founder becomes a sheet the board and the team can see | S | wallet, evictionWarning, cash, board | founderSalary, rescueSalary, founderPayExcess, boardPressure |
| F10 | Key person | A hospital stay or a chronic condition prices the next term sheet and the board review | S | hospitalizationDays, chronicCondition, doors.armed | term-sheet cash, boardPressure |
| F11 | Memories come due | A teen reads their own ledger: sour memories act out, proud ones ask to intern | M | child.memories, stage, bond | narrative beats, bond decay, intern gate |
| F12 | The grown child | Back them (a stake), hire them, or let them go — a child becomes a rival, a holding or a hire | M | child, internSummers, bond, wallet | rivals, networking holdings, employees |
| F13 | Two matches | Choose whom to date from two seed-derived people with one modifier each | M | rng at ladder start, contacts | family (archetype), affection drift rules |
| F14 | A mentor from the address book | A founder contact at rapport 60 trains a skill monthly for advisory equity | S–M | contacts, skills | skills, equityRemaining, rapport |
| F15 | Personal health insurance | A weekly premium from the wallet that covers the hospital and halves treatment | S | wallet, ailments | wallet, hospitalBill |
| F16 | The weekend costs an evening | Any weekend but rest spends one of the week's evenings | S | eveningsPerWeek | eveningsSpentThisWeek |
| F17 | An MBA mid-game | 26 weeks, one evening a week locked, $30k, finance and leadership up | S | skills, wallet, evenings | skills |
| F18 | Pets that need you | A pet's condition decays while you are away or on crunch; it can die | S | assets.owned, away, pace | condition, child memories |
| F19 | Founder ageing and mortality | An age, a decline, a death that ends the run in the dynasty | L | day, health | new subsystem |
| F20 | A savings account | Wallet interest on a positive balance | S | wallet | wallet |

Sizes: S = a half to one day, M = two to three days, L = a week, for one
Opus engineer in a worktree.

## The top eight, worked out

### 1. F1 — Skin in the game: the director's loan and the dividend
*Put your own money in when the runway is short; take some out when the
company can afford it, and everybody on the cap table gets their share.*

- **What the player does.** Two rows on the money sheet (tap the HUD
  cash). *Lend the company* `amount` from the wallet: company cash up,
  wallet down, a ledger line "Director's loan", and the loan sits on the
  books ahead of the bank: repaid on demand while cash covers it, and
  repaid automatically out of the next accepted term sheet before the
  cheque lands (cash in = cheque − loan; wallet += loan). *Declare a
  dividend* `amount`: allowed when cash − amount ≥ 8 weeks of burn, no
  open case, none in the last 13 weeks; the wallet receives
  `amount × equityRemaining / 100`, the company loses all of `amount`
  (the other holders' share leaves for nothing), a ledger line
  "Dividend", and for the next 13 weeks `founderPayExcess` counts
  `amount / 13` as founder pay, so the team's morale and the board's
  pay-pressure line read it the way they read a fat salary.
- **The two answers.** At four weeks of runway: your savings (the wallet
  to zero, the eviction clock, every evening that costs money refused
  — and the shark's door, J1, is the alternative on the same screen) or
  somebody else's money. In a fat quarter: the dividend that buys the
  house and the life score, at the price of the investors' cut and a
  team that knows, or reinvest.
- **GameState.** `EconomyState.directorLoan: Int` (0, not encoded when
  0), `EconomyState.lastDividendDay: Int?`. Nothing else.
- **Files.** `GameAction.swift` (+`lendToCompany(amount:)`,
  `repayDirectorLoan(amount:)`, `declareDividend(amount:)`),
  `Reducer.swift`, `Systems/FinanceSystem.swift` (beside
  `takeLoan`/`repayLoan`), `Systems/InvestorSystem.swift`
  (`acceptInvestment` repays the loan first), `FounderQueries.swift`
  (`founderPayExcess` gains the dividend term; blockers with reasons),
  `Economy.swift`, `Stakes.swift` (the loan follows the `.takeLoan`
  refusal rule), `Balance.json` new `founderMoney` block,
  `App/Sources/Screens/Business` money sheet and
  `Screens/Life/MoneyCard.swift`.
- **Identity.** No bot sends either action; default fields are not
  encoded. No draw. The fixtures stand.
- **Old saves.** Decode-if-present, defaults 0 / nil.
- **How it fails.** The dividend becomes the way to fund the assets
  room and the loan a free runway pump on a rich wallet. The cheap
  tell: on the campus fixture, cap the dividend at half of last
  quarter's profit and check that a year-three founder cannot pull more
  than about $100k; the league scores net worth and a dividend must
  *lower* it by the investors' share (it does, if net worth counts
  company cash at equityRemaining).
- **Estimate.** 2–3 days.

### 2. F2 — Hire your partner
*They are good at this, they are already at dinner, and the marriage now
reads the office.*

- **What the player does.** A row on the partner card from the
  `partner` stage: *Hire them*. Built exactly the way `FriendSystem.hire`
  builds a friend: skills derived from `partnerAppearanceSeed` (the
  `Friend.derivedSkills` shape), fair pay, a `Candidate` pushed through
  `EmployeeSystem.hire`, `founderBond` seeded from affection. Two
  couplings while they are on payroll: the partner's morale target
  moves with affection (`(affection − 50) × 0.3`) and affection drifts
  with the company's pace (crunch pace −0.6 a day on top of the
  schedule's; a shipped product +6, a burnout −8 — they were there).
  Their salary lands in the wallet: the household draw (founder salary +
  partner salary) is what `founderPayExcess` compares to the team
  median, so the second legal pipe from company to wallet costs morale
  and board pressure like the first. `breakUp` or the confrontation's
  "pack a bag" resigns them the same day (an alumni entry, lost), and
  the divorce settlement's company slice ignores `equityMarriedDays`
  — they were a co-founder in everything but name.
- **The two answers.** A loyal senior hire on day one and a second
  salary, against a marriage that now takes every crunch week and a
  breakup that is also a resignation and a bigger settlement. Or keep
  them out and keep the two halves insulated, which is today.
- **GameState.** `FamilyState.partnerEmployeeID: UUID?` (nil, not
  encoded). The employee is an ordinary `Employee`.
- **Files.** `Systems/RelationshipSystem.swift` (hire, the two
  couplings, the resignation), `Life.swift`, `GameAction.swift`
  (+`hirePartner`), `Reducer.swift`, `Systems/EmployeeSystem.swift`
  (morale target hook, beside the founder-bond term),
  `Systems/FamilyDramaSystem.swift` (the settlement clause),
  `Systems/InteractionSystem.swift` (`breakUp` path),
  `FounderQueries.swift` (`founderPayExcess`),
  `App/Sources/Screens/Life/PartnerCard.swift`, a chip on the Team
  roster row.
- **Identity.** Nothing until `.hirePartner`; no bot has a partner. No
  draw: skills are derived from the seed already stored.
- **Old saves.** Optional field; an old married save simply gains the
  row.
- **How it fails.** The partner is just a discount hire. The
  affection↔pace coupling has to bite: the partner card should print
  "−0.6 a day: the office" during crunch, and a playtester who hires
  the partner and crunches a launch should see the warning text land
  inside the month. If nobody ever loses a partner this way, double the
  pace term.
- **Estimate.** 2–3 days.

### 3. F3 — Where you live
*Rent in the suburbs and pay for it in evenings; rent downtown and pay
for it in dollars.*

- **What the player does.** The home card gains *Move* with the five
  districts the city already has. Rent is `weeklyRent ×
  districts[home].rentMultiplier` (studio: $84 in the suburbs, $264
  downtown; house: $490 to $1,540). A commute table (far pairs:
  suburbs↔downtown, suburbs↔techPark, oldTown↔techPark; everything else
  near) takes one evening off the week when home and office are far,
  never below the schedule's minimum of 1. Moving costs two weeks' rent
  and an evening, and a school-age or teen child writes a memory ("new
  school"). The office relocation sheet prints the commute it would
  create ("Your commute: far · −1 evening"), so a company decision
  reads the founder's home.
- **The two answers.** Cheap and far (a third of a normal week's
  evenings gone, the kids and the partner feel it) or near and dear
  (rent that a $200 salary cannot carry, so the salary knob — and F1 —
  come into it). And the office move becomes a household decision.
- **GameState.** `LifeState.homeDistrict: DistrictID?` (nil = today:
  no multiplier, no commute).
- **Files.** `Life.swift` (field, `eveningsPerWeek` minus commute),
  `Systems/LifeSystem.swift` (`livingCosts`, the weekly debit),
  `Systems/CitySystem.swift` (relocation preview), `GameAction.swift`
  (+`moveHome(district:)`), `Reducer.swift`, `Balance/BalanceConfig+…`
  (the far pairs, `Balance.json` `city.commute`),
  `Systems/ChildhoodSystem.swift` (the memory),
  `App/Sources/Screens/Life/HomeCard.swift`, `Screens/City/*` (a home
  pin on the map).
- **Identity.** nil district means multiplier 1.0 and no commute, so a
  bot that relocates its office loses nothing. No draw.
- **Old saves.** nil.
- **How it fails.** Nobody lives far because −1 of 3 is brutal, or
  nobody lives near because $1,540 a week is absurd on any salary. The
  tell is the sheet: print "this costs N% of your salary" and "−1
  evening of 3" side by side; if playtesters always pick one column,
  make far cost the evening only on normal and crunch (chill absorbs
  it), and let the salary knob be linked from the same sheet.
- **Estimate.** 2 days.

### 4. F4 — The ex on the cap table
*They own eight points of it. Buy them out now, or watch the number grow.*

- **What the player does.** After a divorce that gave equity, the
  family-drama screen shows the slice and its value today (`points/100 ×
  valuation`) and a *Buy them out* row at ×1.15, wallet first then
  company cash (the `settleCase` split), refused with an open case or
  when it would leave under four weeks of runway. The ex also becomes a
  contact in the address book with rapport = affection at the divorce
  and an archetype from the partner seed: they can be talked to,
  recruited at rapport 50, and asked out again at 75 — "hide, never
  remove". The row on the confrontation sheet that reads "pack a bag"
  gets the projected slice on its button.
- **The two answers.** Cash and runway now for a clean cap table, or
  leave the slice to ride: their share of every exit and, if the
  company grows, a price that grows with it.
- **GameState.** `FamilySettlement.boughtOutDay: Int?`,
  `FamilySettlement.exContactID: UUID?`; the contact is an ordinary
  `Contact` (a new `ContactOutcome` case `.formerPartner`).
- **Files.** `FamilyDrama.swift`, `Systems/FamilyDramaSystem.swift`
  (buy-out, contact creation at settlement), `Networking.swift`,
  `Investors.swift` (valuation), `GameAction.swift` (+`buyOutEx`),
  `Reducer.swift`, `App/Sources/Screens/Life/Family/FamilyDramaScreen.swift`
  and `FamilyDivorceSheet.swift`, `AddressBookSheet.swift`.
- **Identity.** No bot divorces. The contact is created only at a
  settlement; an id from the seeded stream is a draw, so use the
  partner's stored `partnerAppearanceSeed` to derive it.
- **Old saves.** Optional fields; an old post-divorce save shows the
  slice with no contact (the button says "They changed their number").
- **How it fails.** The valuation is small early, so the buy-out is
  always cheap and always taken; or the ×1.15 on a campus valuation is
  never affordable. The tell: on the studio fixture, 8 points × the
  valuation there should land near the company's cash, a real call; if
  it is under a quarter of cash, raise the multiple to 1.5.
- **Estimate.** 1.5 days.

### 5. F9 — The rescue is a choice
*The company will cover you. Say so out loud, and let the board and the
team hear it.*

- **What the player does.** When the wallet passes −$3,000 the
  eviction warning already lands; today, a fortnight later,
  `checkEviction` silently raises the founder's salary to clear the
  hole (up to $5,000 a week) and `founderPayExcess` exempts it. Make it
  a queue entry with three answers: *Take the rescue* (the same salary
  rise, but no exemption — the team's morale and the board's pay line
  read it, and `FounderStanding` gains +4 for the year), *Move down*
  (today's downgrade, mood −12, kept as the deadline default), *Sell
  something* (routes to the assets room; the answer counts only when
  the wallet is back above the line by the deadline).
- **The two answers.** The company's money at a public price, or a
  smaller home. Nobody chooses the third unless they have something to
  sell, which is what the assets room is for.
- **GameState.** No new fields: `rescueSalary` already exists; the
  exemption at `FounderQueries.swift:101` is removed and the queue
  entry is a `QueueKind`.
- **Files.** `Systems/LifeSystem.swift` (`checkEviction` raises the
  question instead of acting), `Queue.swift` (+kind), `GameAction.swift`
  (+`answerRescue(RescueAnswer)`), `Reducer.swift`,
  `FounderQueries.swift`, `FounderStanding.swift`,
  `App/Sources/…/QueueBoard` prompt builder, `MoneyCard.swift`.
- **Identity.** Bots never go below −$3,000 (rent on a studio is $120
  against a $200 salary); check with the ten pacing seeds that
  `evictionWarning` never fires before changing the branch, and keep the
  old automatic path when `doors` are not armed.
- **Old saves.** A save already on a rescue salary keeps it, exempt,
  until the wallet is square; the new rule applies to the next warning.
- **How it fails.** It never fires. The tell is the count above; if
  the warning is unreachable in ordinary play, this is a half-day
  exemption fix and not a feature, and it still closes the penthouse
  hole.
- **Estimate.** 1 day.

### 6. F5 — The diary reads the roadmap
*Announce for the 14th and it is Nora's birthday. Announce for the 21st
and lose a week of hype. Your call, on purpose.*

- **What the player does.** J5's announce sheet already shows the ETA,
  +7 and +14 with slack and risk; each row gains a diary line when a
  dated entry in `narrative.scheduled` (anniversary, a child's
  birthday, a parent's birthday) falls within two days of it. On a ship
  day that lands within a day of a diary date, the launch-day sheet
  gains *Keep the date*: no launch party (hype ×0.85, no
  launch-party vice gain) and the date counts as kept (a good memory,
  affection as a date night); the default is the launch, which marks
  the date missed the way the diary already does.
- **The two answers.** A week of hype decay (1% a day announced, 2%
  not) against a birthday that a child's memory ledger will carry into
  the dynasty; on the day, the party or the cake.
- **GameState.** None. `Product.announcedDay` and the diary already
  exist.
- **Files.** `Announce.swift` (`AnnounceOption.diaryClash: String?`),
  `Systems/AnnounceSystem.swift`, `Systems/FamilyCalendar.swift` (a
  query for entries near a day), `Systems/ProductSystem.swift` (ship
  day: the clash flag), the launch-day sheet in
  `App/Sources/Screens/Products`, `LifeEvents.json` (one
  `kid_birthday_launch` variant, gated on a flag only this path
  raises).
- **Identity.** Bots do not announce and have no diary. The launch-day
  clash needs a partner or a child, which no fixture bot has.
- **Old saves.** None.
- **How it fails.** Clashes are rare (one anniversary, one birthday
  per child, two parents' birthdays a year, inside a ±2-day window).
  Count them over ten seeds with a family; under one per run, widen to
  ±3 days and let the sheet also warn when the ETA itself clashes,
  which it can today.
- **Estimate.** 0.5–1 day.

### 7. F6 — Take them with you
*A week away alone brings you back. A week away with them brings them
back.*

- **What the player does.** The weekend grid gains *Family holiday*
  beside *Vacation*: $1,500 plus $600 a head (partner and each child),
  seven days away, energy +25 rather than +40, health +10, affection
  +20 with `lastPartnerDay` set, child bond +8 each and a memory ("the
  holiday"), and the solo row's caption finally says what it costs:
  "Affection −4 while you are away". The solo row itself is unchanged.
- **The two answers.** Recover fully and pay for it at home, or
  recover less, pay more, and come back to a family that was there.
- **GameState.** `WeekendActivity` gains a case (encoded only when
  planned).
- **Files.** `Life.swift`, `Systems/LifeSystem.swift` (`resolveWeekend`,
  `resolvedActivity` falls back to `.vacation` when single),
  `Systems/ChildhoodSystem.swift` (the memory), `Balance.json`
  `life.activities.familyVacation`,
  `App/Sources/Screens/Life/WeekendCard.swift`.
- **Identity.** No bot plans a vacation; `WeekendActivity.allCases` is
  not used for any roll (checked). No draw.
- **Old saves.** An old save decodes its planned activity as before.
- **How it fails.** The family row is strictly better once the wallet
  can pay, and the solo row dies. The energy gap (25 vs 40) is the
  lever; if playtesters with a family never pick solo, make solo the
  only holiday that counts as a chronic-recovery week
  (`applyWeekendRecovery`), which is what a rest cure is.
- **Estimate.** 1 day.

### 8. F7 — The doctor's letter
*"Health 38. At this rate, the hospital in 140 days." Then the two
choices the game already writes.*

- **What the player does.** When health crosses 40 downward and the
  doors are armed (J1's "a person is playing" gate), a dated diary
  entry `doctor_letter` is scheduled seven days out, once per 180 days:
  the body carries the number and the days to the hospital at the
  current drift, and the choices are `doctor_says`'s — *Do the three
  things* ($400, an evening, health +18) or *After this quarter*
  (health −8). Leave `doctor_says` itself alone: re-keying its
  `maxEnergy` gate would change the eligible set on the random roll
  and move the fixtures.
- **The two answers.** An evening and $400 in the week you are
  crunching a launch, or the hospital as a scheduled risk you have now
  seen the date of.
- **GameState.** None new (a `narrative.scheduled` entry and a
  `lastDoctorLetterDay: Int?` on `EconomyState`, nil not encoded).
- **Files.** `Systems/LifeSystem.swift` (the crossing check, after
  `checkThresholds`), `Systems/FamilyCalendar.swift` (schedule),
  `LifeEvents.json` (+`doctor_letter`, dated, no random weight),
  `Balance.json` `life.letterHealth`, `Economy.swift`,
  `App/Sources/Components/EventCopy.swift`.
- **Identity.** Gated on `doors.armed`, which bots, replays and tests
  never set. The dated fire path draws nothing.
- **Old saves.** Nothing.
- **How it fails.** It nags, or it fires once at day 200 and never
  matters. Once per 180 days on a downward crossing, and the number in
  the body is the test: if playtesters cannot say how many days they
  have, the letter is wallpaper.
- **Estimate.** 0.5 day.

## Cut, and why

- **F8 Own the home** — a real decision (capital vs rent, 70% of the
  value as secured-loan headroom, half of it in a divorce), but the
  maths only starts once wallets are six figures, which is F1's job.
  Revisit the round after F1 ships; and decode the mortgaged origin as
  owned when it lands.
- **F10 Key person** — a consequence, not a decision: term sheets
  arrive on the investors' clock, so the founder cannot time health
  against them. J2's shape, less of a reason.
- **F11 Memories come due** — the choice it grades (being home in the
  toddler years) is one the bond already grades; a second reader of the
  same ledger is a second bill for the same thing.
- **F12 The grown child** — the right join (child → rival, holding or
  hire), but a grown child lands 900 days after a birth that cannot
  come before about day 200; almost no run gets there. Do it when the
  balance window passes year three.
- **F13 Two matches** — picking a partner is picking a passive bonus;
  no decision after the tap. F2 gives the partner an inner life the
  player keeps having to answer.
- **F14 A mentor** — a private coach with a face; skills never decay,
  so nothing trades against training already.
- **F15 Personal health insurance** — a weekly toggle whose right
  answer is yes once affordable; People & HR already carries 60%.
- **F16 The weekend costs an evening** — a retune of the one economy
  that works, and it would move every bot that plans a weekend.
- **F17 An MBA** — `coach` at $2,400 buys 14 points now; a longer,
  dearer version of the same row.
- **F18 Pets that need you** — pure punishment; the dog already has a
  loss chance and a place in the settlement.
- **F19 Founder ageing and mortality** — cut in iteration 12 for the
  same reason: runs are two to five years, a new subsystem for a cruel
  payoff.
- **F20 A savings account** — bookkeeping with a positive sign.
- **Politics, books, podcasts as systems** — they exist as fame events
  with priced choices (`fame_book_deal`, `fame_keynote_offer`,
  `fame_open_letter`); a system would be the same choices with a card.
- **Fame with a cost for the clean founder** — J2's spotlight is the
  cost, and it belongs to the crime lens; a free daily post is a fine
  chore.
- **Conferences, travel** — the networking weekend, `conferenceBar`,
  the weekend away and the sabbatical cover it; F6 is the one gap.

## Not verified

- I did not run the simulator; every count above is from the fixture
  JSON and the engine source, not the screen.
- Whether any of the ten pacing seeds ever trips `evictionWarning` or
  the hospital (the campus fixture at day 900 shows no stay at health
  26; the studio fixture at day 400 is at 16.6) — F9 and F7 gate on
  `doors.armed` regardless, so identity holds either way, but F9's
  reach depends on it.
- The valuation on the studio fixture, for F4's price sanity check.
