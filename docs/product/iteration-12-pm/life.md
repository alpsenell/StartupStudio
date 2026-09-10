# Founder's life and people: where it's thin, and ten things to build

**Where I disagree with the brief.** Two of its example gaps already exist:
- **Fame already reaches hiring.** `Fame.inboundApplicants` feeds `HiringSystem.swift:127–134`.
- **The partner already finds out about an affair.** W2 rolls it weekly at 7%, rising to a 42% ceiling (`Balance.json` `familyDrama.discovery*`).

The real gap is narrower and worse. **Everything the founder does wrong stays on the Life tab.** Notoriety is read only by the crime and espionage discovery rolls. The board takes pressure from a crime only while the founder is in prison (`CrimeSystem.swift:307/328`). An open case, a guilty fine, a public beef, being cruel to staff or firing with cause never reaches a candidate, a term sheet or a board review. The content even promises it does: `people_hard_reputation` reads *"Difficult but effective" is now a thing recruiters say about you* and costs `mood −2`, nothing else.

Second, **the children's clock runs outside the length of a run**, so much of what iterations 9 and 11 built for teens and grown children almost never plays. That is Improvement B1.

Everything below keeps the repo rules: identity at the default, no new `rng`/`worldRNG` draws, old saves load, no new tests.

---

## A) Five new features, best first

### A1. The board reads the papers
*Your scandals now show up at the quarterly review, not just your numbers.*

- **What's thin.** The quarterly review already reads one Life-tab number, the founder's pay (`founderPayExcess` in `InvestorSystem.swift` around line 225), so there is a precedent. Nothing else from the founder's life reaches it.
  - The only writers of `boardPressure` are the review itself, the pitch room, the office-secrets coup and the prison.
  - A `LegalCase` that is open for eight weeks costs the company nothing until the verdict lands.
- **Mechanic.**
  - At each review with a seated board, add a key-person line:
    - +8 for each open case where the founder is the defendant.
    - +12 for a guilty verdict this quarter.
    - +4 for each beef round last quarter (`FameState.beef.rounds`).
    - +6 for an unanswered cancellation.
  - Cap the line at +25 a quarter. The existing `crossedWarning` rule still stops a warning and an ousting from landing in the same review.
  - With no board: a term sheet that arrives while a case is open is priced 15% lower (a key-person clause). The haircut is applied after the offer is rolled, so it adds no draw.
  - The review prints the line: `THE FOUNDER'S QUARTER: +20`.
  - Identity: no cases, no beef and no cancellation means +0 and ×1.0.
- **The decision.** Settling stops the bleed now but costs the wallet and the gag order. Fighting risks the verdict and costs board patience every quarter the case stays open. That makes settle-or-fight a company decision, not only a wallet one. Posting a beef gets the same treatment: reach and followers against board patience.
- **Hooks.**
  - `Systems/InvestorSystem.swift`, next to the pay-pressure line.
  - `Crime.swift` (`CrimeState.cases`, the verdict).
  - `Fame.swift` (the beef, the cancellation).
  - `Investors.swift` (term-sheet valuation).
  - The `BoardReview` record, for the printed line.
- **How it fails.** Founders on the independent ladder never seat a board, so half of all runs only ever see the haircut. The cheap test: in five playtest runs with a case, count how many had a board seated. If it is under two, move the weight onto the haircut.
- **Size.** S, about 2 engineer-days.

### A2. Your name gets around
*People you treated badly give references too, so cruelty and crime make hiring more expensive.*

- **What's thin.** `HiringSystem` reads fame and nothing else about the founder. `firedWithCauseIDs` only closes the boomerang. The mean interactions (insult, argue, silent treatment, throw under the bus, threaten) leave no trace outside the one person's bar.
- **Mechanic.**
  - A pure function, `FounderStanding.name(state)`, clamped to 0…100:
    - notoriety × 0.5
    - +6 for each firing with cause
    - +3 for each mean act on an employee in the last 180 days, capped at 24
    - +10 for each guilty verdict
    - −4 for each fame level
    - −3 for each alumnus with rapport ≥ 60 (they vouch for you)
  - The clamp at 0 matters. Pacing bots do build up alumni, and without it a clean run would score below zero and move the numbers.
  - Effect 1: candidates' asking salary × (1 + name/200), so a name of 40 means asks 20% higher. This applies at display and at hire, not at roll time, so it adds no draw.
  - Effect 2: at 50 or above, the best candidate in the pool refuses the interview. The button says why: "They rang someone who used to work for you."
  - The hiring sheet carries one line: `YOUR NAME: +14% ON ASKS · 2 ALUMNI VOUCH`.
  - New state: `InteractionState` needs a small list of the days a mean act was used on staff, decode-if-present.
- **The decision.** Managing by fear, or cutting corners, becomes a payroll cost. It can be bought back two ways: fame, which launders a name, or treating leavers well. That opens a second playthrough — the notorious but famous founder who outruns their reputation.
- **Hooks.**
  - `Systems/HiringSystem.swift`, `Screens/Team/HiringSheet.swift`.
  - `Crime.swift`, `Interactions.swift`.
  - `Systems/NetworkingSystem+Alumni.swift` (rapport), `Fame.swift` (level).
- **How it fails.** Late-game founders rarely hire, so the price goes unnoticed. The cheap test: count hires made after the first mean act or crime in a playtest. If it is under two a run, move the effect onto rivals' poach odds.
- **Size.** M, about 3 days.

### A3. The room hears it
*Insult someone on the team and their friends there hear about it.*

- **What's thin.** `InteractionSystem.apply(.employee)` moves one person's `founderBond` and half that as `morale` (`InteractionSystem.swift` around lines 198–206), and nobody else's. Meanwhile `SocialSystem` keeps friendships between employees that already lift output (`EmployeeSystem.swift:551–565`). Two systems about the same people never touch.
- **Mechanic.**
  - A mean act on an employee: each coworker with a friendship bond ≥ 40 to the target loses morale equal to |delta| × bond/100 × 0.5.
  - A nice act spreads 25% of its gain the same way.
  - Throw under the bus: the target takes −20, and people who are *not* the target's friends gain +2. Scapegoating works on the room, for now.
  - Fire with cause: friends of the fired person take −8 morale and −10 founder bond.
  - The outcome paper names who saw it: `DEV AND MARA SAW IT · MORALE −4, −3`.
  - No draws. Nothing happens in a run that never opens the people menu.
- **The decision.** Who you can afford to be hard on depends on the friendship graph. The isolated underperformer is cheap to lean on. Anyone in N5's clique, or the target's closest colleague, is expensive. Management style becomes a choice about targets, not a toggle.
- **Hooks.**
  - `Systems/InteractionSystem.swift`.
  - `SocialSystem.strongestBond` and the friendships behind it.
  - `Screens/People/PeopleOutcomePaper.swift`.
  - `OrgChartView` already draws bonds as line weight, so the player can read the graph.
- **How it fails.** If the player cannot see who is friends with whom, it feels random. The outcome paper naming the witnesses is the fix and the test: if playtesters cannot say why morale fell, the line is missing or unclear.
- **Size.** S, about 1.5 days.

### A4. Character witnesses
*Before a hearing, ask someone who likes you to speak for you. If you lose, it costs them too.*

- **What's thin.** The courtroom's opening standing is `defence.openingStanding − evidence × weight` (`Crime.swift:979`). Custody grades the children's memory ledgers and their bond. Every other bond in the game is passive:
  - an employee's `founderBond` feeds the morale target, loyalty and the sabbatical caretaker gate;
  - a friend's bond gates loans and hires;
  - a relative's bond (`FamilyKinRecord.bond`) does almost nothing.
- **Mechanic.**
  - A row on the courtroom sheet and the custody opener lets you pick up to two witnesses:
    - employees with bond ≥ 70
    - friends with bond ≥ 70
    - relatives with bond ≥ 60
    - the ex-cellmate, who counts −5
  - Each witness adds +6 standing, or +9 if their bond is ≥ 90.
  - In custody, the neighbour counts +9.
  - The costs:
    - An employee witness is out for 2 days with zero output.
    - If you are convicted, that employee takes −10 morale ("they said it under oath").
    - A friend or relative loses 15 bond if you lose.
    - A win gives both sides +10 bond.
  - For book-cooking charges, an employee with loyalty < 50 refuses, and the refusal opens a staff moment.
  - Deterministic: it only moves the opening standing.
- **The decision.** You spend relationships you built with evenings to win a case, and risk them. Replay value: a founder who invested in people is harder to convict and keeps the children.
- **Hooks.**
  - `Crime.swift` `openingStanding`; the custody standing in `FamilyDrama.swift` (around line 732).
  - `Employee.founderBond`, `Friend.bond`, `FamilyKinRecord.bond`.
  - The inmate `Contact`.
  - `Screens/Life/Crime/**` (the courtroom sheet).
  - `PhoneState.post`, for the witness's own line.
- **How it fails.** Six points either never moves a verdict band or makes every case winnable. The custody bands are about 30–40 points wide (full ≥ 34, shared ≥ −6, weekends ≥ −34). The cheap test: the sheet shows the projected band before and after picking witnesses. If picks rarely cross a band, retune.
- **Size.** M, about 3 days.

### A5. Favours come due
*Asking a favour gets you something now. The person asks for one back later, at a time you don't choose.*

- **What's thin.** This is a dead button and a dead field.
  - `askForAFavour` (in `Interactions.json`, on the money shelf) costs bond on both rolls (−1 if it lands, −8 if not) and gives nothing. `InteractionSystem` has no case for it, so a good roll still loses bond.
  - `PrisonState.favourOwed` is written at `PrisonSystem.swift:329` and read nowhere. This is W4's follow-up 1.
- **Mechanic.**
  - The favour pays by who you ask:
    - An employee stays late: one day of their output at double, with no morale cost.
    - A contact makes an intro: +10 pitch-room warmth for the next meeting, or their archetype is guaranteed in the next networking room.
    - A friend covers a family date: the next claimed diary evening counts as kept.
  - Each favour goes into a small debt list.
  - 3–8 weeks later, each debt comes back as a sheet using W1's `Demand` machinery (comply, stall, refuse). The ask is priced in the game's own currencies: an evening, a $5k loan, or "hire my kid" (a real candidate).
  - Refusing costs 20 bond.
  - The wing's `favourOwed` becomes the first debt, a job for the cellmate.
  - Timing uses `socialRNG`, and only for a player who has asked a favour.
- **The decision.** Borrow against a relationship now and repay at an inconvenient moment, or spend the evening yourself.
- **Hooks.**
  - `Interactions.json`, `Systems/InteractionSystem.swift`.
  - `Prison.swift`, `DirtyMoney.swift` (the `Demand` sheets).
  - `Systems/FamilyCalendar.swift`, `Systems/PitchSystem.swift`, the networking roster.
- **How it fails.** It turns into bookkeeping if debts pile up. Cap open debts at 2 and refuse the ask while the list is full, with the reason on the button. The cheap test: if playtesters never press the button once it pays, the cost is wrong; if they press it every week, the call-back is too soft.
- **Size.** M, about 3–4 days.

---

## B) Five improvements to existing features, best first

### B1. Put the children on the company's clock
- **Today.** Stages are set in days since birth: `stageDays: [180, 540, 1100, 1800]` (`BalanceConfig+Childhood.swift:70`).
  - A child needs marriage first (at least 84 days at the stage, relationships ≥ 75), so the earliest births land around day 200.
  - The balance targets run 730 days (`BalanceTargetsTests.days`).
- **Weak.** A child becomes a teen around day 1300 and grown around day 2000, in *Keep running it* territory. So these rarely or never play in a normal run:
  - the intern summer (teen only);
  - `disown` (grown only);
  - `kid_moves_out`;
  - the grown-stage vignettes;
  - the "Could intern for a summer" promise.

  The file's own header claims "a teenager by the campus", and the median campus is past day 500.
- **Change.** Use `[90, 270, 540, 900]`, so a child born on day 200 is a teen by about day 740. Keep ages derived from the stage, as the warning at `Childhood.swift:117` says to.
- **Identity.** No bot calls `.haveChild`; it appears only in `FamilyDiaryTests` and `LifeSystemTests`. None of the four `Fixtures/*.json` holds a child. The pacing and byte-identical suites should not move. Childhood unit tests that pin stage days may need a re-pin; report the old and new numbers.
- **Size.** S, about 1 day including an audit of the `kid_` events' stage gates.

### B2. Custody that changes the week
- **Today.** `custodyVerdict` is written once (`FamilyDramaSystem.swift:515`) and read by nothing else. It moves bond once (full +6, shared 0, weekends −9, none −22). Children keep claiming diary evenings and birthdays as if nothing happened.
- **Weak.** The verdict is a headline, not a new life.
- **Change.**
  - Shared: birthdays alternate years, and a missed one counts only on your years.
  - Weekends only: weekday evenings with the child are refused ("It's not your week"), the family weekend is the only lever, and the bond grace period drops from 14 days to 7.
  - None: one supervised visit a month, costing an evening and $200.
  - A sentence during your custody weeks becomes a child memory.
  - Fix the bench label: `CrimeBenchView` should ask for the custody label, not the crime's word. This is W2's follow-up.
- **Size.** S–M, about 2 days.

### B3. Make the will do something before the dynasty
- **Today.** The will reorders the dynasty list for a child or an employee only. For partner and sibling: "Neither is a successor the ledger carries" (`Successors.swift`, around line 232). The founder cannot die; no founder-death path exists in the engine.
- **Weak.** Half the options on the will sheet are inert, and the sheet is never read during a run.
- **Change.** The named heir becomes the default caretaker whenever the founder is away: prison, the hospital sign-off, or the sabbatical.
  - An employee heir with at least 1 year of tenure skips the bond ≥ 50 gate.
  - A sibling heir runs the company through their payroll seat, with Grumbler-style autopilot.
  - A partner heir means zero caretaker output, but affection does not slide while you are inside.
  - With a board seated and no will signed: +3 key-person pressure a quarter. This joins A1.
- **Decision.** Name the competent employee (the company holds) or the partner (the marriage holds).
- **Size.** M, about 2–3 days.

### B4. Friends who help the company, one way each
- **Today.** L4 made friends deliberately company-neutral ("friends' bond decay has no company effect"). The buyout opinion is text only (`Friends.swift` buyout lines). The neighbour moves only the relationships meter.
- **Weak.** A friend is only worth an evening in meter points, so the partner and the kids always win the evening.
- **Change.** Each archetype gets one bond-gated evening that pays into the company:
  - The uni friend, bond ≥ 60, the week before a ship: −15% on that build's bug count.
  - The ex-colleague, bond ≥ 60, before a pitch: +8 warmth.
  - The neighbour, bond ≥ 70, while a buyout is pending: "Sleep on it" pushes the offer's deadline back 14 days.

  Each has a 60-day cooldown. None of it applies to anyone who never touches the friends.
- **Decision.** Evenings now compete across partner, kids and a friend who can actually help the launch.
- **Size.** M, about 2–3 days.

### B5. Rooms nobody finds
- **Today.** Five systems stay dormant until the player opens them:
  - Assets (`noticeAssetsOpened`);
  - the family room (`openedDay`);
  - the feed (the first post);
  - dirty money (`noticeFinancesOpened`);
  - office secrets (the Team tab gate).

  Their cards are the last five in the Life tab's *You* section (`LifeScreen.swift:134–152`), below about twenty other cards.
- **Weak.** In most runs, iteration 11's roughly 300 new events never become eligible, because the gate never opens.
- **Change.** Surface each room once, from the moment that naturally wants it, as a rail line with a button:
  - The first launch-party life event links to Assets.
  - The wedding links to the family room.
  - The launch-day sheet gets "Tell people" into the feed's compose sheet.
  - A burnout links to the doctor.

  App-only. Engagement still happens only on the tap, so identity holds.
- **Size.** S, about 1 day.

---

## Cut list

- **Founder death / mortality:** a new subsystem plus a mid-run succession flow, for a mostly cruel payoff. B3 gets most of the will's value without it.
- **Texting first from the phone:** a daily chore that resets a neglect clock. Bookkeeping, not a choice.
- **The life score feeding anything:** it is display-only by design. Making it an input turns the whole Life tab into one number to optimise.
- **Vices hitting output directly:** already covered. Vices drift the meters, and the meters drive output through wellbeing (`Life.swift:666`) and room morale (`EmployeeSystem.swift:298`).
- **A partner with a job:** a new node, and the only argument for it is realism.
- **Grown children as candidates:** the right idea, but unreachable until B1 lands. Revisit after.
- **A nepotism penalty for relatives on payroll:** small, and W1's nephew already tells that joke.
- **Notoriety boosting feed reach ("infamy"):** pure upside for crime unless A1 exists. Do A1 first.
- **Wiring the espionage truce flag:** a real leftover, but it belongs to the rival lens.
- **Making the cellmate a better "fixer" hire:** folded into A5's first debt.

**Suggested order:** A1, A3 and B1 first. All three are small and each connects two systems that already exist. Then A2 and A4, which reuse the name score and the courtroom sheet. A5, B2 and B3 are the ones that finish iteration 11's honest leftovers.
