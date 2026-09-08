# Iteration 11 — the founder's darker life: what was built

*Record of the round. The brief is `iteration-11-darker-life.md`; each
lane's own report, numbers and screenshots are under `iteration-11-lanes/`.
Wave one is recorded here; wave two is appended when it lands.*

## How wave one ran

Five Opus lanes in isolated worktrees, each cut from `scaffold-11` and on
its own simulator. They landed in the order N5, N2, N4, N1, N3. Every
conflict was a both-added hunk (`EventCopy`, `BalanceConfig`,
`Balance.json`, `ContentCatalog`'s parameter list) or an event file, which
was merged by a three-way union by id: company events 83 → 147, life
events 78 → 208, without a single entry edited by two lanes.

One real defect surfaced at the four-lane merge and is worth remembering.
The engine test process died with a bus error inside the balance
config's synthesized decoder, and each lane had passed alone. The cause
was a debug-build stack cliff, not the lanes' code: `BalanceConfig` has
close to four hundred stored properties and grows a kilobyte per lane,
and the determinism script passed it by value at thirty-three call
sites, each costing that test's frame a copy. Five lanes' growth crossed
a cooperative thread's 512 KB together. Two fixes went in: the script
goes through two nested helpers and keeps one copy, and
`BalanceConfig.decode` runs the synthesized decoder on a 64 MB thread so
no caller's stack can be too small for it. A test function that passes
the balance by value at many sites will hit the same cliff again; hoist
it.

## The rule every feature kept

Identity at default, no new `rng`/`worldRNG` draws, no new tests, old
saves load, lane-prefixed type names, balance keys in `Balance.json`,
dark not cruel, thirty or more events per lane. Every lane held it: a
run that never commits a crime, opens a menu, buys a car, posts a take
or looks at the team writes the same JSON it wrote before, and the
byte-identical fixture tests pass unchanged.

## Wave one

### N1 — Crime, scandal and the courtroom

Six offences, each priced and gated with a refusal sentence: cook the
books, dodge the tax, the NDA poach, bribe a journalist, fake the demo,
plant a story. A notoriety needle that decays a point a week; a weekly
discovery sweep per open record entry that the Legal department halves;
a case with a hearing four to eight weeks out that the newspaper leads
with and the phone carries; settle, three lawyer tiers and four defences
before it; a courtroom in the pitch room's grammar with the bench, the
prosecutor and the charge on the plaque; verdicts of acquitted, a fine,
a settlement with a gag order, or a three-to-sixteen-week sentence that
hands the company to the sabbatical caretaker with the founder "inside".
Turn yourself in, or sue a rival from their profile. Thirty-seven events.

### N2 — People you can mess with

Twenty-three interactions on four shelves (nice, mean, money, serious)
for every person in the game, each row carrying its cost, cooldown, the
bar it moves on both outcomes and the roll it faces. Five hundred and
forty-four outcome lines keyed by kind of person, played on pixel paper,
posted to the phone and written into a child's memory. The existing
actions sit in the same menu. Propose, break up, an affair flag with a
day on it, disown a grown child, fire with cause (which closes the
boomerang), and a rival's grudge that names your nemesis.

### N3 — Assets, vices and the doctor

Four cars, two properties, three pets with drawn names, three casino
tables with the house edge printed, a weekly lottery ticket, a crypto
wallet on a log-normal walk, five named ailments with causes and courses
of treatment, an hour of therapy, and four vices that creep in from
launch parties, crunch weeks and the tables, with a one-per-run
intervention from the partner or the oldest friend. Net worth counts the
lot; the car stands on the drive and the animal takes a corner of the
home. Everything is dormant until the Assets screen is opened.
Forty-three events.

### N4 — Fame and the feed

A public feed on the Life tab: four post kinds, one a day, each rolling
a reach that brings followers and replies from the world. Fame is the
followers plus the last fortnight's reach, and it leaks. Fame buys daily
hype, unasked-for applicants, a warm journalist, and at five thresholds
the podcast, the book deal, the keynote and the TV slot. A subtweet at a
rival opens a beef they answer in public; above *notable* an old post
surfaces with three priced ways out. The audience saturates, so the
first hundred followers stay hard. The newspaper prints the beef.

### N5 — The office has secrets

Six slow-burn threads: a mole, a romance across a reporting line,
embezzlement, a clique, a union drive, a coup. Each has a start
condition, three stages twelve days apart, a clue per stage in one of
four places (a journal beat, a text from a third party, a prop in the
room, a real ledger line), and an ending nobody chose. Six answers on the
Team tab: ask around, hire a PI, say it to their face (a real staff
moment), take it to HR, make a deal, leave it alone. Nothing runs until
the Team tab has been opened. Forty-two events.

## Suites after wave one

Engine 943, content 52, save 34, PixelKit 336, app 385. No test was
added; one existing content test learned two new follow-up id sets, the
way it already knew the calendar's.

## Not done, honestly (wave one)

- N1's offence buttons live on one crime screen rather than beside the
  ledger, the hiring sheet, the press strip and the launch flow.
- The game never had a tax bill; the dodge computes a notional one.
- N2 raises no `GameEvent` of its own (no copy owner for it); outcomes
  ride the phone and the child's ledger.
- Subtweets raise a rival's grudge only where N2's field exists on the
  merged branch, which it now does; the one-line hook is marked in place.
- The pixel home has no driveway; the car stands at the room's edge.
- N5's office clues are drawn over the scene rather than by the scene's
  own director.

## Debug flags added (wave one)

`-autoRoute courtroom|people|assets|feed`, `-autoCase <kind>`,
`-autoAssets`, `-autoFame`, `-autoCompose`, `-autoSecret <kind>`.
