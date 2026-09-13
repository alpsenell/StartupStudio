# Iteration 17 — the wish list: what was built

*Record of the round. The direction and the ranking are
`iteration-17-wishes.md`; the three PM lens reports it was ranked from
are under `iteration-17-pm/`; each lane's own report, measurements,
deviations, merge dry-run and screenshots are under
`iteration-17-lanes/`.*

## How it ran

Three Fable product lenses (the genre's table stakes, the player's first
ten hours, wave two re-ranked plus the joins between the seventeen
iteration-15 verbs) each ranked twenty candidates. The coordinator
grouped the top seventeen into seven Opus lanes in worktrees off
`scaffold-17` (comment-only `T1…T7` marker regions, no engine stubs).
Every lane measured the PM's "how it fails" check first, applied the
spec's remedy where the check failed, built, ran the five suites on its
own simulator, dry-ran the merge against the other branches and wrote its
report to a file.

Merged T4 → T3 → T5 → T1 → T6 → T7 → T2 (finishing order). Every
conflict was a both-added marker pair kept in order, plus three
resolutions that needed reading: the launch hype line became
`(deal-scaled hype + the publisher's name) × the away factor` so T6's
multiplier covers the whole expression; T3's conditional fire section
replaced the bare call T6's side kept on the manage sheet; and T2's
`ShipSheet` replaced both ship dialogs, with T7's exclusive grant glued
into `ShipSheet.ship`. Other glue: the reducer's old `acceptBuyout`
passes the balance, the IPO card reads the exit split, and a paid
holder's dividend is a morale cause on the manage sheet.

Two specs were overruled by the tree and rebuilt mid-lane: the
exclusive's premise (a day-one verdict) was false because all four
reviews already land on launch day, so the exclusive now embargoes the
other three for a week and launch week reads that one outlet's score;
and T3 found the old free-fire row on the people page and priced it too.

## The seventeen features

**T1 — exits and joins.** At an acquisition, sell-up, earn-out or IPO the
director's loan comes back to the wallet first, then every vested option
point is paid its share of the price; the unvested are a row on the
buyout and sell-up sheets, *Accelerate* (they vest and are paid) or *Let
them lapse* (the points come home; each lapsed holder costs 2 on your
name, quits at the earn-out's next weekly pass and counts as a missed
review, capped one short of the ousting — the remedy, because
accelerating measured 5.0% of the founder's share on the studio). Three
new `exit…` actions carry the answer; the old `.acceptBuyout` means
lapse. *Firing the partner is a fight:* −25 affection, −40 with cause,
and next morning a "bag by the door" card: *Pack a bag* or *Stay and take
it*. A dividend that reached a holder's desk is +6 morale, +5 loyalty and
a printed cause; the partner's morale no longer reads the founder's
dividend as pay.

**T2 — the build.** On a build's lifecycle card, *Shelve* (the slot
frees, the crew goes idle, hype to 0, an announced date slips through
the announce system, the crew −3, progress kept and decaying a tenth a
quarter; *Take it off the shelf* resumes it; a shelved build moves to
`GameState.shelf` so every in-flight read excludes it) and *Scrap* (the
product is removed, half its points bank into the type's codebase capped
at what it already holds, morale −4, refused in the last week before its
ETA or under an unslipped date). The move-down refusal now says "Ship or
shelve N builds". The "v2 of…" chip starts the build as a declared v2
(`startProductAsV2`); shipped beside a live parent it makes the parent
the old version (acquisition ×0.5, churn ×1.5, printed as the dialog's
third answer). The ship dialog is a `ShipSheet` that names the price:
the forecast score, the three tiers with their captions, K2's replace
rows, and the run-both line; the launch writes the tier. Measured: no
remedy triggered; the spec numbers ship as written.

**T3 — people.** Plain firing pays notice (one week per quarter served,
up to four; refused when the cash is short; the alumnus stays warm).
Firing for cause is free and the room sees it: everyone −4, the name +6,
the alumnus lost, and a wrongful-dismissal claim at 10% (halved from the
spec: at 20% its expected cost beat the notice) for eight weeks' pay,
settled or fought in the courtroom. A *Let people go* sheet picks
several, totals the severance, and is the target of the move-down's
"Let 6 people go first" refusal. The old free "Let them go" row on the
people page prices its notice too. The seating preview prints the
lesson's price — fair pay +$948 a week at +94 skill points on the studio,
and the recruiters' list — and a taught, seated junior who crosses a rung
asks for the promotion.

**T4 — publisher.** *Shop it to a publisher* on a build: the strongest
rival with strength ≥ 30 advances the crew's cost to the ETA, takes 40%
of the product's revenue forever as a weekly ledger line (the spec's 50%
and full weeks failed the check: the advance was over 100% of the
give-up), the date is the ETA plus two weeks announced through the
existing announce path, a slip claws back 25% of the advance, the
publisher's name adds hype on launch day, the rival now lives in your
topic and saw the board; *Buy them out* at 1.5× the advance less the
share paid. *The sign caps the market:* while a for-sale sign stands no
unsolicited offer pays more than the ask, and the card prints the
windfall you are giving up; `askMax` 1.6 → 2.0 because the wait for a
1.5× offer measured under eight weeks on both late fixtures.

**T5 — expo and pre-orders.** DevWorld on day 182 of every year: from
28 days out the rail and the Now card count down; the sheet lists every
build in development with its quality so far and open bugs, prices a
booth by office ($2,500–$15,000), the hallway ($900) or skipping, and
sends the founder (an evening, energy −8) or a marketer (×0.7). The demo
happens on the day: over 25 open bugs and it crashes (hype ×0.5,
reputation −3, the paper says so); shown, the build is copyable three
weeks after launch (the spec's four never moved a copycat) and faces
reviewers expecting +3. *Pre-orders* on an announced one-time build at
least 21 days out: 30% of the whole ramp to peak at the finished build's
quality, at 65% of list (the slip rate measured 0–7%, under the spec's
line; the spec's 30% of launch week took $57–80, so the lane departed
from the formula — $2,478 on the garage's first build); a third refunded
on the first slip, the rest and −4 reputation on the second; launch day
says "overpromised" when the reviews land under the quality the buyers
were sold.

**T6 — away.** *Send them on a course* beside the workshop: $2,400, ten
working days away, +9 in the chosen skill (the spec's +12 measured +8.4%
weekly points for the slip, over the line); away people give no points,
no RP, no growth, are not crowded or spanned, and the build card and the
ship estimate say so. *Holidays* as a doors-gated staff question: "Ten
days a year, take them" (scheduled from each hire's anniversary, morale
target +4, loyalty +8; it moved the studio's ship estimate twice a year
and mean morale 76 → 80) or "Take them when it's quiet" (morale target
−3, burnouts ×1.5), on the policies card; the staff roll was verified
byte-identical for bots. *The launch reads the founder away:* bots do
ship while away (53 of 2,399 launches, mostly from hospital), so the
×0.85 hype and the skipped party are gated on `doors.armed`; every away
row prints the clash from the ETA. *Home districts read the map:* the
only honest new far pair is Midtown–Old Town (a 22-px corner); the
district panel says "a walk from home" for tonight's room; the school's
weekly bond moved to Midtown because the Suburbs won every column from
every office.

**T7 — press and stakes.** *Exclusive to…* one outlet on the ship page:
only its review appears for seven days, launch-week sales read its score
instead of the average (measured small: 24 units against 24–25, about
1% per review point), it gains 5 standing and the other three lose 1;
standing moves an outlet's later scores by a third of itself (the spec's
fifth vanished in the review noise, σ 6.0) and every review card says it
in words. *Buy a stake* in a rival at 5, 10 or 25% for 1.1× valuation
from company cash: a quarter of the price becomes their strength, a
weekly dividend at a 0.2 payout (the spec's full payout returned 90–280%
a year), their next topic on the profile from 10%, their poaches halved,
their price war refused, *Sell the stake* at 0.9×, gone if they fold; a
25% stake in the strongest rival marked to market at day 730 was up on
3 of 8 and 2 of 7 runs, so premium and sell-back stay.

## Suites after the merge

Engine 943, content 52, save 34, PixelKit 336, app `Executed 385 tests,
with 0 failures` on the merged tree with the glue. No test added; one
re-pin, T6's policy-flag count 12 → 14 for the seventh policy kind. No
engine or release fixture moved. Strings synced with one `make strings`.

## Not done, honestly

- The war room's ship button still sends the plain ship at standard with
  no exclusive, replace or price; it should open `ShipSheet` (T2/T7).
- Replacing still loses to running both because of K2's 40% carry, even
  with the parent decaying (T2); shipping a rough build lowers its
  codebase unseen; a shelved name does not block reuse.
- The publisher's buy-out reaches $0 once the share has paid 1.5× the
  advance; a released product's page does not show its publisher (T4).
- The expo's copycat head start rarely bites because the copycat copies
  the best-reviewed product; the random conference event and J5's
  reseller pre-order event still fire beside the new features (removing
  either moves every bot's roll); annual prepay for subscriptions (T5).
- The build card's crew count still includes people away; the map still
  draws the school in the Suburbs; the launch-day sheet opens at ship
  time, not on the founder's return (T6).
- The embargo misses `averageReviewScore` readers off the named screens
  (rival head-to-head rows, share cards); a paper acquisition does not
  discount a held stake; a price war already running outlives a new
  stake (T7).
- A wrongful-dismissal claim prints as "the matter" on the courtroom
  cards and the Life queue; no fixture has a headcount board (T3).
- The rival page's "Sell for…" button lapses the unvested with no row;
  the partner's "bag by the door" card sits at the bottom of Life rather
  than in the queue (T1).
- Wave three stands as listed in `iteration-17-wishes.md`.

## Debug flags added

T1 `-autoRoute t1-…` (the buyout, the bid, the bag); T2 `-autoRoute t2-…`
(the ship sheet, the shelf, the launch beside); T3 `-autoRoute
t3-fire|t3-dialog|t3-layoff|t3-claim`; T4 `-autoPublisher offer|sign|slip`,
`-autoRoute t4-publisher`; T5 `-autoExpo [booked]`, `-autoPreorders
open|slip`, `-autoRoute t5-expo|t5-preorders`; T6 `-autoAway
course|question|rule|strict|launch|launchday|home|clash`, `-autoRoute
t6-course`; T7 `-autoRoute t7-…` (the exclusive, the stake, the offer).
Each lane's report lists its exact flags and the fixture each one
dresses.
