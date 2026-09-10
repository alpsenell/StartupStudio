# Iteration 14 — the UX audit, finished: what was built

*Record of the round. The direction is `iteration-14-ux.md`, the audit it
completes is `iteration-13-ux-audit.md`, and each lane's own report,
measurements and before/after screenshots are under
`iteration-14-lanes/`. The App Store Connect material for the shop is
under `docs/release/iap-review.md` and `docs/release/iap-review/`.*

## How it ran

Three Opus lanes in pre-created worktrees off `scaffold-14`, one per
group of the audit's five remaining changes, and a fourth agent that
produced the shop's submission material. The scaffold carried one shared
contract, `CardView`'s `weight: CardWeight` (`.primary`, `.row`,
`.quiet`), so V1 and V2 could ask for row and quiet cards from day one
while V3 gave them their look; its first cut clashed with the theme's
existing `CardStyle` name and was re-tagged. Every lane changed
presentation only: `git diff scaffold-14 -- Packages` is empty on all
three, no test was added, and the suites are at their baselines.

They landed V3, V2, V1 and merged V3 → V1 → V2 → the prep branch without
a conflict. The merge glue was one hook the lanes had agreed in advance:
V3 left the journal's week heading with a marked one-line opener, V2
wrote out the two-member replacement that calls its shell reopen, and it
went in at merge.

## The changes

**Life in five folded sections** (V1, C1). This week, People, Money and
home, You, More of your life. The week, the people and the rooms open by
default; a closed section is one summary line with a badge ("Priya Raman
52 ♥ · 2 kids · 1 asking"); open or closed is remembered per install. The
Fortnight nests inside Your week, both types kept. The doors and Inside
sit in This week. People are rows with one number each. Open rooms are
rows that unfold in place, a room that waits on you lit and first;
dormant rooms are quiet rows under "Other rooms".

**Rooms dormant until opened** (V1, C2). Crime, Assets, Fame, Family
drama, Side project, Sabbatical and Life score draw nothing until their
room is open; the guard wraps only the card, so their tasks and sheets
still run. Four coach tips stop giving directions.

**One inbox** (V2, C5). The rail's +N opens "Waiting on you": the rail's
own queue rows (J6's rule now lives in one place the rail also calls),
J1's doors, phone threads that are asking, and desk rows due within
seven days, each with its deadline and the rail's own button. The desk
card, the morning papers and the inbox read the same list. The reporter
row and an unanswered price war now carry real deadlines, which is what
had kept the Business badge at zero. The shop never appears in it.

**One home per thing** (V2 and V1, C10). Work pace is one company-wide
setting, so Products gets one pace card and build cards show only a pill
when the pace is not normal; Your week reads the pace and links to
Products. A closed week's report can be reopened from the rail and from
the journal's week heading, as it was built, without resetting the
deltas. The phone hides the company's weekly closes (app side; the save
keeps every message). "Morning desk" is "Morning papers".

**Three card weights and a Now card that answers when** (V3, C11).
`.row` is a 56-pt line with an icon, a title, one number and a chevron;
`.quiet` is one secondary line. The Now card's three bars are one
segmented phase bar with a sentence from the build estimate ("Ships in
about 67 days"). The office takes the largest whole-pixel scale its card
allows with no paper margin: the studio draws at 2× instead of 1×. Below
the office HQ is one Company card with three rows (Burn and runway,
Chapter, Journal), each opening the old card on its own page.

## The numbers

| Measure (audit method) | Before | After |
|---|---|---|
| Life scroll length, garage / studio / campus / family (650-pt tiles) | 9 / 10 / 10 / 11 | 3 / 3 / 3 / 4 |
| Life blocks rendered | 19 / 20 / 20 / 20 | 9 / 10 / 11 / 13 |
| Numbers on the family save's whole Life scroll | ~130 | ~41 |
| Places to check what is waiting | 5 | 1 |
| Business badge, garage / studio / campus / family | 0 / 0 / 0 / 0 | 0 / 1 / 1 / 2 |
| Pace controls on Products, studio / campus | 3 / 5 | 1 / 1 |
| Now card share of the HQ fold, garage / studio / campus | 42% / 45% / 44% | 28% / 37% / 37% |
| Studio office paper margin per side (desk cells) | 2.7 / 2.3 | 0 / 0 |
| HQ below the office, garage / studio / campus (pt) | 855 / 1,011 / 952 | 274 / 273 / 273 |

Section E's exact target (about 8 blocks and 25 numbers above Life's
second fold) is close but not met: the Today activity grid alone is 16
numbers and sits in both folds; V1 names a compact activity card as the
next step.

## The shop's submission material (asc-prep)

Six review screenshots at native size with real prices from the local
StoreKit config, one per product, under `docs/release/iap-review/`, and
`docs/release/iap-review.md`: each product's id, reference name, type,
price point, en-US name and description, screenshot and review note; the
version steps (attach all six, the Paid Applications agreement, a
sandbox tester, Ask to Buy); replacement App Review notes that drop the
DEBUG-only fixture; and the pre-TestFlight kill-between-verified-and-
finish check as eleven numbered steps with two breakpoints. The product
ids appear only in the catalog, the surface seam and the StoreKit
config. `docs/release/testflight.md`'s three stale "one in-app purchase"
mentions were corrected at merge.

## Suites after the merge

Engine 943, content 52, save 34, PixelKit 336, app 385, all green on the
merged tree with the journal glue applied, plus a Release build. No test
added, no pinned number moved. The strings catalog is 1,664 keys after
one `make strings`.

## Re-pins

V1: the iPad column life root. V2: the iPad column business, products
and life roots, and `agenda_card` / `agenda_fortnight` (the dated
reporter row now appears in the Fortnight). V3: `now_card_build`, the
iPad column HQ root, and the four office-card tap snapshots (the garage
draws at 3×). Every assertion passes unchanged; only images moved, and
V2 separated real changes from render noise with a control run.

## Not done, honestly

- The Today activity grid is the last big block on Life (16 numbers in
  both folds); a compact activity card is the next step.
- The Fortnight now lists the reporter's date twice (once as a desk row);
  a one-line fix in `Agenda.swift`.
- J5's announce countdown row on the rail still falls through to the
  deferred story recall; it wants `.announce` from the lane-route seam.
- The +N count still counts rail notices, not inbox items.
- Reopenable reports are per launch: after a relaunch only the latest
  closed week reopens.
- The weekly-close filter matches on text.
- The product detail page keeps its own pace control.
- The Now card is still about 37% of the fold on the studio and campus;
  a one-line goal description would bring it to about 30%.
- The campus office is small at 1×; bigger needs a second scene size or
  a pannable scene.
- The married and complaint tips still say "on the Life tab" / "on the
  Team tab".
- Store descriptions omit costs the game shows (the loan stays, the
  reputation −5, the 1.4× salary); nothing in them is false. The owner's
  call under guideline 2.3.

## Debug flags added

`-autoLifeOffset <pt>`, `-autoRoute hq-money|hq-chapter|hq-journal`,
`-autoHQBottom`, `-autoHQMeasure`, and the inbox opens from `-autoQueue`.
