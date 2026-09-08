# Iteration 10 — interactive rooms: what was built

*Record of the round. The brief is `iteration-10-interactive.md`; each
lane's own report, numbers and screenshots are under `iteration-10-lanes/`.*

## How it ran

Six Opus lanes in isolated worktrees, each cut from `scaffold-10` and each
on its own simulator. They landed in the order M5, M4, M1, M2, M3, M6.
Every conflict was a both-added hunk in a shared region (`TitleMenu`,
`TitleScreen`, `EventCopy`, `BalanceConfig`, `Balance.json`, `GameState`'s
severity switch, `ContentCatalog`'s parameter list) and was resolved by
keeping both sides; two test pins that two lanes had each moved by one
were moved by two (title menu rows 7 → 9, pixel-text baseline 47 → 49).

One false alarm at merge time: the app suite twice reported two heavy
snapshot tests "crashed with signal kill" while six lanes were compiling on
the same machine (fifteen-minute load average 36). Both passed in
isolation and the whole suite passed on a quiet machine. Never run the app
suite while every lane is building.

## The rule every feature kept

Identity at default, no new `rng`/`worldRNG` draws, no new tests, old saves
load, lane-prefixed type names, balance keys present in `Balance.json`.
The byte-identical fixture tests pass unchanged: a run that never places a
card, opens a room, plays a league, clears a desk or squashes a bug writes
the same JSON it wrote before.

## The six

### M1 — The feature board

Fifty-nine feature cards across the twelve topics and six product types,
nine behind tech nodes. The type sets four to six slots; the hand is drawn
from the tech tree, the crew's pool strengths and the quarter's market
appetite; fit, synergies and appetite hits multiply quality at ship in a
band of ×0.90 to ×1.12, and an empty board is exactly 1.0 by construction.
The review quotes the best card and complains about the worst; a copycat
rival records the card it lifted; a sequel starts with its parent's board;
the storefront lists what the thing does. `FeatureBoardScreen` opens from
the product detail during design.

### M2 — The pitch room

Term sheets, contract briefs, launch-week interviews and quarterly board
reviews each grew a *Talk first* button that opens a conversation in the
networking floor's grammar. The person across the table has a hidden want,
a tell until the founder listens; what gets said is priced straight back
into the paperwork. At full warmth: the investor's cheque ±25%, their
equity ∓20%, patience ±30%; the client's fee ±20%, deadline ±25%, crew bar
∓25%; one outlet's review ±20 points and the front page's lead; board
pressure ±12. The accept and decline buttons underneath are unchanged.

### M3 — The incident room

Three kinds: a bad patch (a patch inside three days with live bugs over
the alarm threshold), a viral spike (a week selling 1.8× the last with
hosting at 35% of revenue), a data leak (a 2% weekly roll, a quarter of
that with Legal). One at a time, one per product a quarter, and none of it
until the player has opened the Products tab. The clock stops and a
full-screen room opens: a status page from red to green, three lanes
(mitigate, communicate, fix) staffed from the whole payroll, an hour
button that states what it buys, users walking out, and three statements,
one of which leads the front page. Every mutation is a `GameAction`, so an
incident replays from the log.

### M4 — Leagues and challenges

A league week is Monday to Sunday UTC with a seed derived from the week
the way the daily derives from the day: one attempt, one game year,
scored on net worth. Four tiers (bronze, silver, gold, founders) as
recurring Game Center boards; top four up and bottom four down, computed
on the client from the tier's own board (or the ghost field when signed
out) the first time the League screen opens in a later week. *Beat my
company* is a link carrying the seed code, the year grid as letters, the
score and a name; playing it is a custom company, and the front door shows
the two grids side by side when it stops. Apple has no client API to issue
a Game Center challenge on iOS 26, so the link and the share card are the
feature.

### M5 — The morning desk

Three papers derived from the current slot without advancing the clock:
one message (the newest unread phone thread), one decision (the most
urgent desk item), one tap (praise, a coffee, the plant). Clearing all
three marks the day and moves the ledger's streak; a one-day gap
continues, a two-day gap continues once a calendar month, anything else
resets. Rewards at 3, 7, 14, 30, 60 and 100 days: decor, two founder looks,
a masthead flourish. Never a stat. A daily reminder is offered only from
the desk's own button. The HUD's date opens the desk mid-run.

### M6 — The bug hunt

A palette-only beetle crawls the floor strip in front of the desk of
anyone on a build with open bugs; a thumb squashes it, three a game day,
with a chirp, a knock and a splat. The day's tally is derived from the
event log rather than stored, so the feature adds no bytes to any save.
The squash is a quiet event that folds into the journal's routine week.

## Suites after iteration 10

Engine 943, content 52, save 34, PixelKit 336, app 385, all green on the
merged branch on a quiet machine. No test was added; four existing
expectations were re-pinned (Game Center board counts, title menu rows,
the pixel-text baseline, the mapping test's ranking filter).

## Not done, honestly

- The office frame sheets (`OfficeDirector.compose`) do not draw bugs; the
  merge happens in `OfficeSceneView`. Three lines to move.
- A rival's copied feature card is recorded but nothing reads it yet.
- The pitch room's investor and board rooms were not photographed: no
  committed fixture has a pending term sheet or board pressure.
- The incident room does not autosave between hours, and its outcome
  surfaces (journal line, front page) were not photographed headlessly.
- A real league tier field waits on the CloudKit container, as ghosts do.
- The desk's streak decor is drawn by reusing the poster and trophy
  builders; no new sprite was made for it.

## Debug flags added

`-autoRoute featureboard|featurestore|pitch|incident`, `-autoFeatureBoard`,
`-autoPitch <counterpart>`, `-autoIncident <kind>`, `-autoLeague
[demo|challenge|result|<yyyymmdd>]`, `-autoDesk [cleared]`, `-autoBugs
[splat]`.
