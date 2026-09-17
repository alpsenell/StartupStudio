# Iteration 18 — PM: the attention round

*17 September 2026. One Fable PM lens read the tree at main (iteration 17
merged: exits, ShipSheet, severance, publisher, expo, pre-orders, away,
exclusive, stakes — `iteration-17-features.md`), the wave-three shelf in
`iteration-17-wishes.md`, the three iteration-17 lens reports, and the
records for iterations 9–16. Premises checked in code where a candidate
stands on one: `fileIPO` (`Packages/TycoonEngine/Sources/TycoonEngine/
Systems/InvestorSystem.swift:678`) has no price decision and no scene;
`App/Sources/Share/` holds five cards (biography, front page, office
photo, year grid, phone thread) and no launch card; no launch-party verb
exists (only J1's vice door and the T6 skip factor); rival products carry
`weeklyUnits` (`Rival.swift:66`); `company.pressStanding` and
`Product.liveHype` exist; `ProductBoxArt` renders on six surfaces.*

**On the brief.** The attention bar is right for this round: seventeen
iterations built decisions faster than anyone outside the phone can see
them, and the shareable surface (five cards, none about a product) lags
the simulation by about eight iterations. One caution, kept throughout:
pure-display features are where this house has cut hardest (G12, P9's
first cut), so the top spectacle picks each carry a real decision inside
them, and the display-only ones are priced honestly as rewards.

One side note for the owner: `README.md`'s feature list stops at
iteration 8. The store listing is drafted from it; nine iterations of
the game's best material (the phone, the darker life, the courtroom, the
queue, seating, the city, the publisher, the expo) are not on the page
the bar cares most about.

---

## The candidates, ranked

### 1. The launch card — S (0.5–1d)

**Pitch.** Every launch mints a 1080×1350 share card: the box art, the
four outlet scores, the stamp, the first week's number, the seed code.
"This is the game I shipped" — the single most forum-post-shaped object
the game can produce, and it does not exist.

**Why it grabs attention.** It is the screenshot, manufactured. The seed
code on it founds the same company on another phone (the existing
`SS1-…` mechanism), so every shared launch is also an invitation.

**What to build.** No engine change, no state — fully derived. A
`LaunchCardView` in `App/Sources/Share/` beside the five existing cards,
rendered through `ShareRenderer.swift`: `ProductBoxArt` large, product
and studio name, the four scores (or the exclusive's single score with
three "embargoed" chips — T7's state), the best or cruelest review
quote, first-week units and cash, the launch day, the pennant if staked,
`SeedCodeField`. Offered at the end of the review reveal on
`App/Sources/Components/LaunchDaySheet.swift` and the war-room aftermath
(`App/Sources/Screens/WarRoom/WarRoomScreen.swift`), and retroactively
from every product's storefront page
(`App/Sources/Screens/Storefront/StorefrontScreen.swift`).

**How it fails.** It becomes a brag button that hides after bad
launches, and a brag button is used once. Remedy in the spec: the card
renders disasters proudly — the 31-score variant leads with the review's
worst line and the "overpromised" stamp when pre-orders were burned,
because tycoon players share catastrophes at least as often as wins.
Cheap check: render it on the best and worst launch of each of the three
release fixtures; both must be legible and both must be *funny or
proud*, never blank.

**Collisions.** #2 (mark on the card), #6 (peak-rank stamp),
#4 (LaunchDaySheet real estate).

### 2. The studio mark — S (1d)

**Pitch.** Your studio gets a generated pixel glyph and colour — picked
from three comps at the naming step — stamped on every box art, the
storefront, the newspaper masthead, your building on the city map, and
every share card. Rivals get theirs derived from their names for free.

**Why it grabs attention.** Identity is what makes a screenshot *yours*.
The player lens cut this in 17 as "pure expression, no decision — keep
for a round whose brief is identity." This is that round; the cut reason
inverts.

**What to build.** `company.markSeed: UInt64?` on the company state
(encode when set; nil draws nothing new, so old saves and all fixtures
are byte-identical). A three-chip picker with a shuffle die at the
company-name step (`App/Sources/Screens/Onboarding/NewGameFlow.swift`),
S3's exact pattern: seeded from run seed + shuffle count, touching no
game RNG. PixelKit gains a `StudioMarkBuilder` (a small glyph grammar —
two to three shapes, two master-palette ramps; `PaletteTests` already
gates invented colours). Stamp sites: `ProductBoxArt.swift` corner,
`StorefrontScreen`, the masthead in
`App/Sources/Screens/Story/NewspaperComposer.swift` and
`Share/FrontPageCardView.swift`, the HQ building plate in
`CityDistrictArt`, `BiographyCardView`, and #1's card. Rival marks
derive from the name hash — the map, the head-to-heads and #6's chart
rows all read better for it.

**How it fails.** Twenty-four random marks are the same smudge at 16 px.
Remedy: constrain the grammar to high-contrast ramp pairs, and render a
24-mark sheet through the PixelKit preview suite
(`PIXELKIT_PREVIEW_DIR=… make test`) before wiring any surface; if
neighbours collide, grow the glyph set, never the palette.

**Collisions.** #1, #6 (same stamp surfaces), S4 city files.

### 3. IPO day: price the offering, ring the bell — M (2–3d)

**Pitch.** Going public stops being a button. Price the offering —
conservative, fair, or aggressive — then stand on the exchange floor in
a full-screen pixel scene, ring the bell, and watch your ticker's first
day draw itself tick by tick.

**Why it grabs attention.** The best ending in the game currently
resolves in one paragraph (`fileIPO` computes one multiple and sets
`gameOver` — verified at `InvestorSystem.swift:678`). A bell scene with
a derived 3–4 letter ticker in the 5×7 face and a day-one chart is the
game's missing money shot; "my ticker popped 38%" is a forum post.

**The decision.** Aggressive: +25% proceeds now, and the pop can go
negative — a *broken open* costs reputation 5, the paper leads with it,
and the biography records it forever. Conservative: −15% proceeds, a
near-certain pop headline, press standing up. Fair sits between. The pop
is a pure function of hype, average review, the market multiplier and
the aggression — no new draws anywhere.

**What to build.** Engine: `fileIPO` gains `price: IPOPrice = .fair`
behind a defaulted argument (the old action byte-identical — the T1/T2
precedent); the pop formula and a `dayOneClose` on the game-over info;
balance keys in `Balance/BalanceConfig+Exits.swift`. UI: the file row in
`App/Sources/Screens/Business/InvestorsView.swift` becomes a three-row
pricing sheet with proceeds and pop odds printed per row (house rule:
two answers, both priced); a new `Screens/Endings/IPOBellScreen.swift`
in the war room's full-screen grammar (the floor, the bell, the ticker,
the chart reveal); the ending card and `BiographyCardView` carry the
ticker and day-one close. T1's exit-split row keeps its place on the
sheet.

**How it fails.** One row dominates and the sheet is theatre. Cheap
check, before any UI: compute all three outcomes on
`release-campus-day900` and the studio fixture; tune the pop coefficient
until fair wins one and aggressive the other, through the broken-open
costs. If a continued run is picked up later by A7 (the street, #8), the
broken open must also start the premium low — say so in the report even
if A7 is not in the round.

**Collisions.** #8 (same files: `InvestorSystem`, `Investors.swift`,
`RunMode.swift`), T1's marked pairs in `fileIPO`.

### 4. Throw the launch party — M (2d)

**Pitch.** After a ship, throw the party: pizza in the office, the bar,
or the rooftop — your actual team drawn in the room, press and investors
on the guest list, and the founder's one evening spent holding a drink.

**Why it grabs attention.** The party scene is the screenshot: the
networking floor's visual grammar (rooms with drawn guests already
exists — `NetworkingVenueSheet.swift`, `RoomBuilder`,
`CharacterAppearance`) filled with *your roster* on the night of *your
launch*. The game already talks about launch parties twice (J1's vice
door, T6's skipped party) without ever letting you throw one.

**The decision.** Venue tiers ($300 office / $1,500 bar / $6,000
rooftop) plus one founder evening — the scarcest currency in the game —
against moraleAll (+2/+4/+6), `liveHype` scaled by (review − 60) so a
rooftop for a 55 *reads desperate* (press standing −1, the paper
snarks), `pressStanding` up for invited outlets, bond up for invited
contacts. On crunch, the party raises J1's existing launch-party vice
odds; on a diary date it clashes exactly as K7 launches do; with the
founder away (T6) there is no party, which the sheet already knows.

**What to build.** Engine: one action
`throwLaunchParty(productID:venue:guests:)`, valid for N days after a
launch, once per launch; effects through existing fields
(`moraleTarget`, `liveHype`, `pressStanding`, bonds, vice-door odds read
from an optional field absent by default). Balance block `party.*`. No
bot sends it; a run that never parties is byte-identical. UI: a party
row on `LaunchDaySheet.swift` and the war-room aftermath; a `PartySheet`
composing the venue scene with the team, in
`App/Sources/Screens/Products/` or beside the war room.

**How it fails.** If the EV is positive the biggest party is automatic.
Remedy is the review-score slope and the once-per-launch cap; cheap
check: EV of the rooftop at review 60 on the studio fixture — if still
positive, steepen the slope before tuning anything else.

**Collisions.** #1 (LaunchDaySheet), #5 (both write moraleAll — keep
constants apart), T6/T7's marked pairs near the launch sheet.

### 5. Awards night, attended (G8) — S (0.75–1d)

**Pitch.** From day 322 the Now card counts down to the awards cutoff;
in December you buy the table, take the team, and either collect Best in
Finance in front of them or lose it in front of them.

**Why it grabs attention.** The ceremony sheet with envelopes and your
team's row is a scene players will photograph, and "shipped at 76 to
make the cutoff, lost to Ironwood anyway" is a story that tells itself.
The judge already exists (`App/Sources/Awards/AwardsJudge.swift`,
`AwardsNightSheet.swift`); today it is invisible until it has happened.

**What to build.** Exactly the pre-vetted spec in
`iteration-17-pm/genre.md` §8: the cutoff line on
`Screens/HQ/NowCard.swift` and the ship sheet from day 322; *Take the
team* ($2,400 by tier, one evening) or *Stay home*; wins with the team
there pay standing +15 in the topic, `liveHype` +20, moraleAll +8,
Studio of the Year reputation +5, a winless night moraleAll −3, a win
from home reputation +2 only. One `recordCeremony(year:attended:wins:)`
sent from the sheet after the app-side judge runs — the engine never
learns to judge; `company.ceremonies` encodes when non-empty.

**How it fails.** Named in the spec with the measure: if the player wins
three-plus categories a year on the campus, halve the standing; if a
rival never wins a topic the player is live in, make Studio of the Year
the only envelope the team cares about. Run the judge (a pure function)
on both late fixtures first.

**Collisions.** NowCard (T5's expo countdown lives there — one more
marked pair), #4 (moraleAll), K7 diary (free clash, already generic).

### 6. Top of the charts — S–M (1.5d)

**Pitch.** A weekly Top 10 — your products and every rival's, box art
and marks, the incumbent squatting at #1 — and "Peak #1 · 3 wk" stamped
on the storefront and the launch card forever.

**Why it grabs attention.** "#1" is the most shareable number in the
genre and the game already computes everything under it (rival products
carry `weeklyUnits`; yours carry weekly sales). G12's industry table was
cut as "a rank with no verb"; this survives only because the rank
*travels* — onto the storefront, the launch card, the biography — and
the paper prints chart moves.

**What to build.** A Charts page under Business/Market
(`App/Sources/Screens/Market/`): all released products ranked by weekly
units across all topics (so the incumbent contests the top), box-art
rows, a per-type filter. Engine: a `chartsOpened` gate (the J3/N5
dormant-until-opened precedent — nothing is recorded and no byte moves
until the player opens the page once); after that, the weekly pass
records `ReleaseInfo.peakRank`/`weeksAtOne` (encode when set). Stamp
readers: `StorefrontScreen`, #1's card, `NewspaperComposer` (one chart
line). Marks from #2 on every row if both land.

**How it fails.** G12's fate — wallpaper. The claims are the remedy, and
the honest check comes first: compute ranks on the three release
fixtures from the existing share math; if the player's products are
always top of their own topics, the all-topics ranking is the feature
and the per-topic filter is secondary. If even all-topics #1 is
uncontested on the campus, the chart needs the incumbent weighting
looked at before the page ships.

**Collisions.** #1, #2 (stamp surfaces), `Rival.swift` readers.

### 7. The all-nighter (A5) — S (1d)

**Pitch.** Long-press the whiteboard: the office pins to night, the
founder alone in the glow, tonight's contribution ×3 — and tomorrow's
energy, the partner's evening, and the bug count pay for it.

**Why it grabs attention.** The 3 a.m. office with one lit desk is the
game's aesthetic in a single frame — a vignette players will screenshot
the first time they see it. And it is the smallest true decision on the
shelf: ship sooner at the body's expense, in a game where hospital
stays compound into a chronic condition.

**What to build.** Exactly `iteration-15-pm/meta.md` §5:
`pullAllNighter(productID:)`, founder points ×3 tonight, energy −15,
health −3, affection −2, extra points roll bugs ×1.5, refused under
energy 30; `life.allNighter` consumed by the next daily tick. Files as
specced (`Life.swift`, `Systems/ProductSystem.swift`,
`Systems/LifeSystem.swift`, `OfficeCard`'s long-press,
`ProductDetailScreen`). The night scene comes free from `Ambience` +
the crunch-night precedent.

**How it fails.** Spec's own check: on the campus the founder's points
are a rounding error. Measure the founder's share of daily points on the
three release fixtures; under 10% on the studio, it becomes the crew's
night (their −3 morale, their ×1.5 points) instead.

**Collisions.** `ProductSystem.applyDailyProgress` (nobody else in this
list touches it), OfficeCard taps.

### 8. The street (A7) — M (2–3d)

**Pitch.** After the bell, *Keep running it* means quarterly earnings
calls: beat the number and the premium and dividends grow; miss three
in a row and the shareholders show you the door.

**Why it grabs attention.** Quieter screenshots than #3, but it is the
natural second half of the same story and shares its files; a "went
public, got ousted by my own street" run is a strong forum post. Fully
pre-specced in `iteration-15-pm/meta.md` §7 with state, files, identity
gate (`epilogue != nil`, which no bot sets) and the failure check
(0.9× trailing average unreachable → 0.8×).

**Collisions.** #3 (`InvestorSystem`, `Investors.swift`,
`RunMode.swift`) — if both are picked they are one lane.

### 9. Announce a number (A18) — S–M (1.5d)

**Pitch.** Promise a review score or a valuation in print by a date; the
paper leads with the promise, then grades you against it.

**Why it grabs attention.** The newspaper is already the game's best
share surface; a front page holding *your own promise* is drama the
composer can print for free. The decision: hype and press standing now
against double reputation damage on a public miss.

**What to build.** One action on the announce path
(`Systems/AnnounceSystem.swift`, `Announce.swift`), a promise field on
the announcement, graded in `ship`'s review pass; `NewspaperComposer`
lead lines both ways; balance `promise.*`.

**How it fails.** Players promise only what the forecast already
guarantees, and the promise is free hype. Remedy: the payout scales with
the gap between promise and forecast — promising the forecast pays
nothing; check the forecast band's width on the studio fixture first
(J5 measured 94–99% on-time, so scores are predictable; the promise must
demand *more* than the forecast to pay).

**Collisions.** T5's announce/pre-order pairs in `AnnounceSystem`, #1
(the card could carry a "promised 90 / shipped 87" stamp — optional).

---

## Cut, and why

- **Contractors (G5)** — the best pure mechanic on the shelf, fully
  specced, and invisible in a screenshot; wrong round, first pick for 19.
- **The custom build (P6), cross-promotion (P7)** — ledger features;
  real decisions, nothing to show a friend.
- **Pick the cover (box-art comps)** — expression with no anchor; #2 is
  the identity feature. A finishing lane may add it to #2 if idle.
- **Then-and-now card (garage day 1 beside today)** — a second new share
  card in a round that already has #1; fold into the biography card later.
- **Photo mode** — `OfficePhotoCardView` exists; a time-of-day picker on
  it is a toggle, not a feature.
- **The industry table (G12) as-is** — the cut stands; #6 is the version
  that survives, and only through the stamps.
- **License the tech (G7), research forks (C7/G19)** — research depth,
  no surface; pair them in a systems round.
- **Own the home (F8), draft the chapter (A6)** — no screenshot, no new
  scene, and A6's degenerate default (drop the two hardest) is unsolved.
- **The beta (P18), the counter-launch (P20), custom scenarios (G14),
  eras (G10)** — the 17 lens cut reasons stand unchanged.
- **A trailer/replay of the year (animated)** — the one genuinely new
  spectacle idea rejected: the share grid and the newspaper carry the
  story at a tenth of the cost; an animation pipeline is a new subsystem
  for one payoff.

## Ranked table

| # | Name | Size | One line |
|---|---|---|---|
| 1 | The launch card | S | The forum post, manufactured; zero state, ships in a day |
| 2 | The studio mark | S | Makes every screenshot *yours*; rivals get faces for free |
| 3 | IPO day: price it, ring the bell | M | The game's missing money shot, with a real pricing decision inside |
| 4 | Throw the launch party | M | Your roster drawn at the rooftop; evenings, hype, press and vices in one sheet |
| 5 | Awards night, attended | S | Pre-vetted G8; envelopes, the December window, a loss in front of the team |
| 6 | Top of the charts | S–M | "#1" travels to the storefront and the card; gated dormant like every room |
| 7 | The all-nighter | S | The 3 a.m. office vignette with the game's cheapest true trade |
| 8 | The street | M | The second half of #3; one lane if both are picked |
| 9 | Announce a number | S–M | Your promise on the front page; pays only past the forecast |

## Recommended picks

**1 + 2 (one lane), 3, 4, 5.** Four lanes, every one landing a new
screenshot surface:

- **Launch card + studio mark** — one identity lane (they share
  `ProductBoxArt`, the storefront and `Share/`); together they turn every
  launch into a branded, shareable object.
- **IPO day** — the store-page hero: the bell scene is the new
  screenshot for the listing, and the pricing sheet keeps the house bar.
- **The launch party** — the mid-game spectacle between launches and
  exits, and the round's strongest new *decision*; it makes five
  existing systems (evenings, hype, press standing, bonds, vices) meet
  in one room.
- **Awards night** — the cheapest pick, pre-vetted to the balance key,
  and it gives every December a date the whole year bends around.

If a fifth lane exists, **top of the charts** over the all-nighter: it
feeds the identity lane (marks and stamps on the same surfaces, so lane
them adjacently) and "#1" is the one number a screenshot needs no
caption for.
