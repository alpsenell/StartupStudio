# Iteration 15 — verbs: what was built

*Record of the round. The direction and the ranking are
`iteration-15-verbs.md`; the three PM lens reports it was ranked from are
under `iteration-15-pm/`; each lane's own report, measurements, deviations,
merge dry-run and screenshots are under `iteration-15-lanes/`.*

## How it ran

Three Fable product lenses (company, life, meta) each read the tree,
counted, and ranked twenty candidates. The coordinator grouped the top
seventeen by the files they touch into seven Opus lanes in pre-created
worktrees off `scaffold-15` (comment-only `K1…K7` marker regions in the
ten shared files, no engine stubs). Every lane measured the PM's "how it
fails" check first, built, ran the five suites on its own simulator,
dry-ran the merge against the other branches, wrote its report to a file
and was shut down once verified.

Merged K3 → K1 → K5 → K6 → K4 → K2 → K7 (the order the lanes finished;
every conflict was a predicted both-added marker pair, plus one hunk in
`InvestorsView` whose two halves had to be reseated as two sequential
chips). Glue at merge: K7's partner-salary line inside K1's household
draw in `founderPayExcess`; the money views and the rescue read the
district's rent (K6 → K1); the Life badge counts the landlord's question
(K1); a family holiday no longer doubles the away drift (K6 → K7); and no
dividend before the company has shipped a product (K1's own day-one
garage note: a sole owner could have taken $8,150 of $11,750 home on
day one).

## The seventeen features

**K1 — founder money.** *Lend the company* from the wallet, repaid on
demand or out of the next term sheet before the cheque lands, lost in a
bankruptcy. *Declare a dividend*: paid pro-rata and printed line by line
(you, each round, the option holders, the ex), once a quarter, never
below eight weeks of runway, refused with a case, in the red, on an
earn-out or with a bank loan; a seated board adds pressure unless the
last quarter was profitable; it posts as an expense so the profitable
streak has to grow past it; the founder's take reads as pay for thirteen
weeks. *The landlord's question*: the automatic rescue salary becomes a
sheet for real players (doors armed) — take the company's money (now
counted as pay, and it marks your name for a year), move down, or sell
something. Measured: the eviction warning fires in 53 of 100 bot runs, so
bots keep the old exempt path; a bot paying the maximum dividend every
quarter reaches *Still yours* on 0 of 10 seeds against 10 of 10.

**K2 — product lifecycle.** *Retire* a live product; *Replace* it on the
ship dialog with a v2 that carries 40% of its subscribers (one-time
products carry hype), skips the same-topic saturation, and says so on
launch day and the storefront ("Discontinued"); a "v2 of…" entry in the
new-product flow. The price picker is a priced sheet: a rise costs 12%
of the book, a cut is a sale once a quarter (+50% for a week), changes
28 days apart, the paper prints both. Measured on the studio fixture's
Round 6: a review-70 successor with the carry only out-earns the kept
parent week-by-week at week 21 and never cumulatively inside a year, so
the carry stays 0.4; the spec's "decaying parent" premise was wrong (kept,
it grows 235 → 657 subscribers in a year).

**K3 — the ladder.** A lead the founder *promoted* halves the crowding
penalty on one build for up to six others; an idle lead's morale target
drifts −4; two leads on one build cancel; every build card prints its
crew and factor ("8 people · ×0.59 each · lead: none") and the Now card's
estimate reads it; the promotion demand only asks when it is true.
*Options instead of pay*: 1–2% for a 20/35% pay cut, loyalty +25, bond
+10, a one-year cliff over four years' vesting, unvested returns when
they leave, poachers keep what vested, a 10% pool, the trade printed in
dollars, a Team row on the cap table, and the button says *Still yours*
closes on the first grant. Measured on the campus: five promoted leads
+23.6% weekly points for $1,767 a week; a grant-every-hire bot ends day
730 at median equity 98 / 94.

**K4 — deals and exits.** *The for-sale sign* on Rivals: an ask from
0.8× to 1.6×, a bid every four weeks on the existing buyout path, morale
target dragged, poaching ×1.5, launch hype ×0.9, board pressure, the
paper leads with it. *Sell up* from the first day in the red, at 0.5× of
valuation falling 10% a week (only 1 in 10 bankrupt bots ever saw a cash
event in its last 21 days, so the gamble is real); a company that rides
it into bankruptcy carries its people into the next run 20 rapport
cooler. *Buy with paper* on a rival's profile: equity instead of cash,
capped at 25% and at keeping 20%, their founder seated and in the
address book. Known limit: on every late fixture the existing
unsolicited offers (1.5–2.5×) beat any sign bid, so the sign pays for
mid-sized companies nobody courts — an owner call whether to cap
unsolicited offers at the ask while listed.

**K5 — hand over the keys.** Beside *Walk away*: *Hand it to…* any
employee who passes the caretaker gate, keeping 10, 25 or 50% as a
silent emeritus round; the successor becomes the founder with a fresh
life and eight weeks of their pay, the run becomes unranked, the old
founder's ledger entry is *Walked away* with the successor named, the
Dynasty tree hangs the continuation, and *Still yours* stays closed to
them until they buy the stake back. No eighth ending, no draw. The two
stale facts fixed: seven endings on the heirlooms page, *Walked away*
earns a look (one pinned count 6 → 7). Measured: the queue after a
hand-over on the family fixture holds the same five items as without.

**K6 — home and rooms.** *Move* to one of the city's five districts:
rent × the district's multiplier, a far commute costs one evening on
normal and crunch, moving costs two weeks' rent and an evening, a child
at school remembers it, the office relocation sheet prints the commute
it would create, a home pin on the map. *The rooms answer*: every home
fixture opens the verb it stands for (the founder opens the Today
sheet, which the Life row now points at); the office plant opens the
papers, the window the map, a built amenity its sheet with *Call a break*
(+3 morale, half a day of build progress, once a week; the studio's ETA
moves 17 → 18 days). *Family holiday* beside the vacation, with the solo
row finally printing "Affection −4 while you are away". Finding: from
Old Town, where every fixture's office is, the suburbs are both cheapest
and near, so the home trade-off only appears once the office moves.

**K7 — partner and diary.** *Hire your partner* (fair pay, skills from
the stored seed): affection moves their morale target, crunch costs the
marriage 0.6 a day and the card says so, a launch +6, a burnout −8, their
pay comes home and counts as founder pay, any breakup is a resignation,
a divorce gives them a slice regardless of the marriage's length. *The
ex on the cap table*: the slice and its value today, *Buy them out* at
×1.15 wallet-then-cash with its refusals, the ex in the address book,
old settlements read "They changed their number", *Pack a bag* prints
the slice (and now actually leads to the settlement it promised). *The
diary reads the roadmap*: announce rows warn of a birthday within two
days; a launch on one offers *Keep the date* (hype ×0.85, no party).
*The doctor's letter* for real players under health 40, once per 180
days, with the number and the days to the hospital. Measured: a crunch
month from affection 70 ends at 35 with the partner hired, 52 without.

## Suites after the merge

Engine 943, content 52, save 34, PixelKit 336, app `Executed 385 tests,
with 0 failures`, on the merged tree with the glue. No test added; the
engine and release fixtures did not move; the one re-pin is K5's earned
looks 6 → 7 (its test name is now false and was not renamed, per rule
15). Strings catalog 1,664 → 1,814 keys after one `make strings`.

## Not done, honestly

- The sign loses to unsolicited buyout offers late in the game (K4).
- A paper-only acquirer bot was not run for C5's oust check (K4).
- The hand-over sheet itself has no screenshot; the successor inherits
  the team's bond with the old founder; family drama, fame and the crime
  record stay with the company; three systems count the kept stake as a
  funding round (K5).
- The doctor's letter fires under 40 rather than on a strict crossing
  (yesterday's health is not stored) and is not a diary entry (K7).
- Journal entries for a move or a break: none, a toast instead (K6).
- An intern's summer exit skips the code that returns unvested options;
  two colliding leads do not open the clique thread (K3).
- The War Room's ship button has no *Replace*; C6's cuts-versus-rises
  count needs playtest saves; running the v2 beside its parent beats
  replacing because the founder's own products never split demand (K2).
- `FriendSystem.hire` pays under the fair band (K7 found it, not fixed).
- Wave two stands as listed in `iteration-15-verbs.md`.

## Debug flags added

K1 `-autoFounderMoney loan|dividend|paid|rescue`; K2 `-autoRoute k2-…`
(the price sheet, the lifecycle card, the replace dialog, `k2-paper`);
K3 `-autoLadder`, `-autoRoute k3-lead|k3-options|k3-holder|k3-captable`;
K4 `-autoDeal list|<ask>|show|paper|sellup`, `-autoRoute forsale|paperdeal`;
K5 `-autoRoute k5keys`; K6 `-autoRoute k6-move|k6-break|k6-today`,
`-autoLifeFolds open`; K7 `-autoPartner <stage>`. Each lane's report lists
its exact flags and the fixture each one dresses.
