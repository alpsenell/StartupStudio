# Iteration 18 — UX review: the attention round, seen whole

*One reviewer, main at 8f22702 plus the working tree, iPhone 17 Pro Max
simulator, Debug build in `/tmp/ux-build`. Read: the PM brief, all four
lane reports and their deviations, the full merged diff over `App/`, and
the engine files the new surfaces read. Screenshots under
`/tmp/i18-ux-shots/` (listed at the end). No code was changed.*

The short version: the five features are individually well made — the
card is funny at both ends, the party room is the screenshot the round
was bought for, the bell chart reads in half a second. The problems are
almost all seams: two of the round's three reveal scenes spoil
themselves from an adjacent element another concern owns, the round's
central decision sheet has never been rendered on a device by anyone,
and the three lanes each invented their own rule for which copy goes
through the string catalog.

---

## Punch list, ranked

### 1. BLOCKER — the awards marquee names every winner while the envelopes are still sealed

`App/Sources/Awards/AwardsNightSheet.swift:128-138`

The marquee's `headline` switches off the sealed-envelopes line the
moment `phase != .question`. Tap *Take the team* and the top of the
sheet immediately reads "Meridian Labs took 4 home: Best in Finance, …"
— with `revealed == 0` and every envelope below still closed. The
envelope-at-a-time scene G8 was built around defeats itself on every
attended night. (Iteration 8's headline was written for a sheet that
opened fully revealed; the new phase reused it unchanged — exactly the
seam a lane alone cannot see.)

**Fix:** gate the winners headline on
`revealed == night.categories.count`, and keep the sealed-envelopes line
(or "The envelopes are on the podium.") until then.

### 2. SHOULD-FIX (top) — the party row prints the average above the reveal that is still building to it

`App/Sources/Components/LaunchDaySheet.swift:87-91` (placement),
`App/Sources/Screens/Products/PartyLaunchRow.swift:81-91` (`pitch`)

Photographed live (`launchday-t7.png`): the sheet opens, the outlets
below are still typing out one at a time toward the stamped average, and
THE PARTY panel above them already says **"It is out, at 37."** The lane
put its row in the ACTIONS area precisely to stay "nowhere near the
review-reveal end" — but the copy carries the number, so the collision
travelled with it. The order (decision above, launch-card memento at the
end) is right; the leak is the score in the pitch.

**Fix:** on the launch-day sheet, hold the score sentence until the
reveal completes (drop to "It is out. There are 7 days left to call it
one." while `revealed < reviews.count`), or move the row below
`ReviewRevealList`. The war-room copy is already safe — that row sits
behind `revealComplete`.

### 3. SHOULD-FIX — the IPO pricing sheet has never been seen rendered, and it cannot be

`App/Sources/Screens/Business/IPOPricingSheet.swift:16`,
`App/Sources/DebugLaunch.swift` (no route)

The round's flagship decision — three books side by side — is reachable
only through *Price the offering* on the Investors card, which is
disabled on every bundled fixture (`canFileIPO` is false on all of
them), and there is no `-autoRoute` for the sheet itself. The IPO lane's
own report photographs the bell twice and the sheet never. I could not
photograph it either. A three-row sheet with per-row money lines, an
exit-split panel and a paragraph under it is exactly the kind of surface
that clips on first contact.

**Fix:** add an `a3-pricing` debug route (present `IPOPricingSheet` over
a fixture, the `a3-bell` pattern) and screenshot it once on a small
phone before ship.

### 4. SHOULD-FIX — the exchange floor reads as abstract blocks, not a floor

`App/Sources/Screens/Endings/IPOBellScreen.swift:231-298`

Photographed (`bell-good.png`, `bell-floor-zoom.png`): on the light
theme the hall is ink-opacity blocks over `paper.opacity(0.5)` — the
windows all but vanish, the back-wall desks read as UI chips (they
rhyme with the outlet chips two screens earlier), and the crowd reads
as a bar chart with caps, not people; the middle desk merges with the
podium into one grey mass. The board, bell, chart and closing lines are
all strong — the room between them is the weakest pixel scene in the
game, on the surface the PM called the store-page hero. The lane flagged
the Canvas-not-PixelKit deviation; this is the visual bill for it.

**Fix (cheap):** darken the hall toward the war-room ambience and give
the crowd two skin/shirt tones from the master palette; the full fix is
the lane's own suggestion — replace `IPOBellContent.floor` with a
PixelKit room in a later pass.

### 5. SHOULD-FIX — five or more party guests stand on the first row's name tags

`App/Sources/Screens/Products/PartySheet.swift:515-525` (guest band)

Photographed (`party-thrown.png`): with 7 on the list, the second guest
row's figures are drawn straight over the first row's tags —
"TechDaily" and "Stack" are half-covered by Elif and Yara. The guests
are "always named, because who came is the half of the list the player
chose", and the names are the thing being covered.

**Fix:** deepen the guest band / row pitch when `guests.count > 4`, or
drop the second row's figures below the first row's tag line.

### 6. SHOULD-FIX — "Price the offering — from $X to you" names the wrong floor

`App/Sources/Screens/Business/InvestorsView.swift:479`

`proceeds` there is `exitIPOProceeds` — the **fair** price. The sheet it
opens prices conservative at 0.85×, so the row promises "from $480,516"
and the first row inside pays $408,439. In a game whose voice is
numbers-kept-in-line, the one number on the door contradicts the sheet.

**Fix:** either "Price the offering — $480,516 at the fair price" or
compute the conservative proceeds for the "from".

### 7. SHOULD-FIX — the two Now-card countdowns disagree on what a date looks like

`App/Sources/Awards/AwardsCutoff.swift:64` vs
`App/Sources/Screens/Business/ExpoViews.swift:31`

Same card, same slot, five months apart: the expo row's trailing date
reads "July 1" (`AnnounceEventPresenter.dateLabel`), the awards row's
reads "W50 · Y2" (`GameState.dateLabel`). The rows are otherwise
structural twins — which makes the drift louder.

**Fix:** one line — use `AnnounceEventPresenter.dateLabel` in
`AwardsCutoffRow`. (Neither countdown can be photographed today: no
fixture sits inside either notice window. Worth one seeded fixture in a
later round.)

### 8. SHOULD-FIX — the party's newspaper lead is wired, but only in the uncommitted working tree

`App/Sources/Screens/Story/NewspaperComposer.swift:260-275, 390-397`
(uncommitted diff)

The party lane shipped `PartyCopy.newspaperLine` unwired and said so.
Someone has since wired it — desperate parties lead the paper, with the
lane's own copy — but the change sits dirty in the working tree, in
nobody's report, covered by no lane's test run. The wiring itself reads
correct and in voice.

**Fix:** decide it: run `make test`/`make apptest` over it and commit it
as the merge-glue it is, or revert it. Don't ship a dirty tree.

### 9. SHOULD-FIX (low) — three lanes, three localization rules

Party: `PartyLaunchRow.swift:81-91`, `PartySheet.swift:113-125, 207-217,
271-275`; IPO: `IPOPricingSheet.swift:43-50, 81-87, 138-149, 186-193`,
`IPOBellScreen.swift:354, 363-367`; awards: `AwardsNightSheet.swift:128-138`.

Iteration 17's pattern for app-side dynamic copy was
`String(localized:)` (PressByline, PressEmbargoRow). Iteration 18's
computed strings — the party pitch and headline, the venue list note,
the pricing captions, the bankers' paragraph, the pop explainer, the
bell headline, the awards marquee — are plain `String`s and
concatenated `Text(...)`, none of which reach the catalog (verified:
zero hits for all of them in `Localizable.xcstrings`; the literals
around them all landed). The catalog is en-only today, so nothing is
broken on screen — but the round quietly forked the convention three
ways, and the next locale pays for it.

**Fix:** one pass moving the computed user-facing strings through
`String(localized:)`, or an explicit note in CLAUDE.md that dynamic
sheet copy is exempt.

### 10. NICE — the bell's closing line slips into the third person

`App/Sources/Screens/Endings/IPOBellScreen.swift:354`

The headline above it says "under the price **you** sold it at"; the
line below says "$602,295 of it was **Alex Chen's**." Same breath, two
persons — and "of it" claims the proceeds came out of the close, which
they didn't (they came out of the offer). "· $602,295 of the offer was
yours." fixes both.

### 11. NICE — "First week 20 · Took $79" undersells the launch it is bragging about

`App/Sources/Share/LaunchCardView.swift:246-289`

Engine truth (weeklySales is append-only; verified), but the adoption
ramp makes week one structurally the *smallest* week — so the campus's
best launch, an 81, carries "Took $79" (`card-best.png`). Fine on the
launch sheet, bathetic on a share card. Consider the peak week ("Best
week 1,842 · $7,120") or total-to-date for cards minted after week one.

### 12. NICE — the selected venue's note prints twice on one screen

`App/Sources/Screens/Products/PartySheet.swift:506` (room caption) and
`:388` (venue row)

"A tab down the road. Somebody will make a speech." appears in the
room's corner and again in the selected row directly below it
(`party-open.png`). Drop the row's note for the selected venue, or give
the room a different line (who is in the room would earn the spot).

### 13. NICE — between 55 and 59 a bar is "earned" yet drains hype, and nothing says why

`Packages/TycoonEngine/Sources/TycoonEngine/Balance/BalanceConfig+Party.swift:86`
(bar `earnedAt: 55`) vs the slope pivot 60

`party-desperate.png` at a 55: the bar row reads "Everyone +4 morale ·
hype −3 · 4 on the list" with no flag — negative hype on a venue the
sheet treats as earned, because `earnedAt` and the hype pivot disagree
by five points. Either align the bar's `earnedAt` with the pivot or let
`effectLine` say "hype −3 at 55" so the number has a reason.

### 14. NICE — dead state and a stack of "away"s

- `PartySheet.swift:27, 251` — `@State thrown` is written and never
  read; the body keys off `state.party(for:)`. Delete it.
- `LaunchDaySheet.swift:57, 76-91` — on an away launch the sheet can say
  "away" three times in adjacent rows: the Tell-people subtitle ("You
  are away."), T6's label, and THE PARTY panel (`party-away.png` shows
  two of the three). Suppress the party panel's sentence when T6's
  label is rendering; the panel can read "No party without you." alone.

### 15. NICE — "Stay home" caption is white on light grey

`App/Sources/Awards/AwardsNightSheet.swift:216`

`borderedProminent` tinted `Color.secondary.opacity(0.35)` leaves the
caption borderline at a glance (`awards-question.png`) and likely under
WCAG in light mode. `.bordered` with default label color reads the same
"lesser answer" without the contrast cost.

### 16. NICE — the war room's aftermath is now four stacked full-width actions

`App/Sources/Screens/WarRoom/WarRoomScreen.swift:799-812`

firstWeek → THE PARTY panel (own big button) → *Make the launch card*
(prominent) → *Back to the office*. Order is right (decision before
memento before exit) and nothing overlaps, but it is a wall of buttons;
the card button could take its quieter bordered form here since the
party panel already owns the visual weight. (Not photographable
headlessly — the aftermath state needs a reveal played in the room.)

### 17. NICE — the new debug routes silently require a tab flag

`x4-…` fires only from the Products tab (`ProductsScreen`), `t7-…` only
from Business — launched bare, both leave you on HQ (I lost two passes
to it; neither lane report says so). One sentence in each report, or
have the route imply its tab the way `-autoRoute investors` does.

---

## What already reads well

- **The launch card is the feature the brief hoped for.** Both ends
  photographed: the 81 leads with its kindest line, the 48 leads with
  "Everyone shipped a music app this month" and the red ink — funny at
  the studio's expense, exactly per spec. Legible at phone width, the
  quote floats with air rather than a hole, the seed code footer reads
  as an invitation.
- **The party room.** Roster drawn from the office's own seeds, press
  badged in accent, "You" in the corner, the venue rows each carrying
  the house money line (`−$6,000 → $84,875 · runway 4 wk`) and a
  one-line reading. "Reads desperate at 55 · every outlet colder" on
  the rooftop row is the game's voice at its best.
- **The desperate mechanism reads on the sheet, not in a manual.** The
  same room, the same rows, one flipped line and one orange tint.
- **The bell's chart and headline.** The step chart against the offer
  line reads instantly in both directions; "MERL broke open. It closed
  its first day at −12% — under the price you sold it at." is the
  round's best sentence.
- **EventCopy additions are all in voice.** "Year 2's awards went by on
  the wire. Nothing of ours in it." / "The table cost $4,800" / the
  party line that "puts the score next to the venue and lets the reader
  do it."
- **The awards question.** Both answers priced, the after-state under
  the paid one, refusals in the player's words on a greyed answer, no
  dismiss until answered — the house grammar, held.
- **Dormant-by-default held everywhere I could check.** No mark → the
  storefront, box art and masthead render byte-identical
  (`storefront.png`); no party → no row; eleven months → no cutoff
  line.
- **The pixel-title grammar unified the round by accident:** THE PARTY /
  THE NIGHT / THE INDUSTRY AWARDS / IPO DAY all speak the same face —
  five features from four lanes read as one game.

## Not visually verified (and why)

- **IPO pricing sheet** — no route, gated button (item 3).
- **NowCard awards cutoff + ShipSheet cutoff line** — no fixture inside
  the 28-day window (item 7 note).
- **Awards envelopes phase / room row** — needs a tap; simulator tap
  integration unavailable on this machine (`xcode-select` not pointed at
  Xcode; needs sudo). The spoiler in item 1 is code-certain.
- **War-room aftermath stack** — needs a reveal played in the room
  (item 16).

## Screenshots taken (`/tmp/i18-ux-shots/`)

| file | surface |
|---|---|
| `card-best.png` | Launch card, campus best (81, marked studio, mark on box art + name) |
| `card-worst.png` | Launch card, studio worst (48, cruelest quote leading) |
| `bell-good.png` | IPO bell, HALS +36%, full day drawn |
| `bell-broken.png` | IPO bell, MERL −12% broken open |
| `bell-floor-zoom.png` | 2× crop of the floor scene (item 4) |
| `party-open.png` | Party sheet, well-reviewed launch, three venues + roster room |
| `party-desperate.png` | Party sheet at a 55, rooftop row flipped desperate |
| `party-thrown.png` | Aftermath: THE NIGHT, stats row, guest-tag overlap (item 5) |
| `party-away.png` | Launch-day sheet, away state of the party row |
| `launchday-t7.png` | Launch-day sheet: Tell people + THE PARTY + reveal (item 2) |
| `awards-question.png` | Awards night, question phase, both answers priced |
| `investors-ipo-card.png` | Investors screen (IPO card below the fold) |
| `storefront.png` | Storefront released page, unmarked save (dormant check) |
