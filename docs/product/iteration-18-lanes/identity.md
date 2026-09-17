# Identity — the launch card and the studio mark

*Iteration 18, lane `i18-identity`, branch off `main` (af5f2e0),
simulator `iPhone 17 Pro`. Spec: `iteration-18-pm.md` §1 (the launch
card) and §2 (the studio mark). Two features in one lane because they
share `ProductBoxArt`, the storefront and `App/Sources/Share/`.*

Two commits, in build order: the mark first (so the card could carry it),
then the card.

---

## 1. The studio mark

### The grammar

`Packages/PixelKit/Sources/PixelKit/StudioMarkBuilder.swift` — a 16×16
glyph that is a pure function of a `UInt64`:

- **field** (12): block, disc, shield, diamond, hexagon, arch, banner,
  chevron plate, ring, tower, wedge, cross. The field carries the
  silhouette, which is what survives being shrunk.
- **figure** (14): bolt, bar, bars, dot, ring, slash, cross, arrow,
  stair, split, crescent, spark, brick, notch. Punched *inside* the
  field only, so it can never break the outline.
- **notch** (4): none, top-left, bottom-right, both top corners — cut out
  of the field rather than painted over it, so it changes the outline.
- **ramp pair** (16), plus an inversion bit: every pair is two
  `Palettes` steps, a deep under a light, chosen for contrast. Nothing
  invents a colour; `PaletteTests` stayed green.

Two more entry points earn their keep:

- `sprite(seed:side:)` — the same recipe nearest-neighbour-sampled down,
  for plates too small for the whole glyph (the HQ sign band takes 5 px,
  a rival's banner 4).
- `seed(forName:)` — FNV-1a then SplitMix, which is where **rival marks**
  come from. No state, no migration, and the same studio wears the same
  glyph in every run that meets it.

The picker's three comps are `comps(runSeed:shuffle:)`: pure arithmetic
on the run seed and the shuffle count, touching no generator the
simulation owns — the same shape as `NewGameFlow`'s fixed
`appearanceSeeds` table and `nameShuffle`. A code typed on the custom
page (R4) makes the comps that seed's own three, so the same code founds
the same company down to the mark on the door.

### Check: 24 marks are not the same smudge at 16 px

Run **before any surface was wired**, through a throwaway SwiftPM
executable outside the repo that depends on PixelKit by path (no test was
added; the existing preview PNG suites are `@Test`s and adding one would
break the house rule). It rendered 24 marks from arbitrary seeds as a
6×4 sheet at 1× and 6×, and compared all **276 pairs** pixel for pixel at
the failure size of 16 px, counting a pixel "the same" when alpha agreed
within 24 and RGB within 60 summed.

> **24 marks, 276 pairs. Most alike: #5 vs #16 at 64% identical pixels at
> 16 px. Collisions over 90%: 0.**

The sheet reads as 24 different studios by eye as well: different
silhouettes, different hues, and the notch pulls apart the pairs that
share a field. The glyph set was sized *up* to get there (five fields and
six figures collided); the palette was never touched.

### State

`company.markSeed: UInt64?` in `GameState.swift`, written only by
`GameAction.chooseStudioMark(seed:)` and only by the naming step of the
new-game flow — no bot sends it. Hand-written `encode` skips the key
while nil, exactly as `seating` (S1) and `pressStanding` (T7) do, so
every old save, every release fixture and every recorded run writes the
bytes it always wrote. Nil draws nothing anywhere; the feature's absence
*is* nil.

One wrinkle the merger should know: the reducer case returns no events,
which is the engine's own signal for "refused", so `GameEngine.send` does
not autosave on it. `GameSession` persists explicitly on both paths that
send it (`startNewGame`, `replayCurrentGame`). An event case was not
added because it would have meant a new `GameEvent` and an exhaustive
`EventCopy` switch for a picture that moves no number.

### The picker

`StudioMarkPicker` at the company-name step (`NewGameFlow.swift`): three
chips, a shuffle die beside them, and a *No mark* row — because "no mark"
is a real answer, not an absence, and a studio without one leaves the
game looking exactly as it looked before. The chosen glyph appears on the
sign preview beside the name. It rides to the session in
`RunSetup.markSeed`.

### Stamp sites

Player: `ProductBoxArt` corner (a `markSeed:` parameter defaulting to
nil, so an unstamped box is byte-identical art) on the launch sheet, the
war room, the storefront hero, the biography card's best product and the
launch card; the storefront's developer line; the newspaper masthead
(`NewspaperIssue.markSeed`, which the front-page share card inherits,
plus its own badge on the mat); the biography card's banner; and the HQ's
sign band on the city map (`CitySpriteLibrary.playerHQ(markSeed:)` — the
band grows from 5 px to 7 only when there is a mark to put on it).

Rivals, free from the name hash: their buildings on the city map
(`CityDistrictInfo.rivalMarkSeeds`), the Rivals roster rows and the rival
profile header.

---

## 2. The launch card

`App/Sources/Share/LaunchCardView.swift`, beside the five existing cards
and rendered through `ShareRenderer` as `ShareCard.launch(engine:product:)`.
**No engine change and no new state** — everything is read off the
product and the run, which is why a four-hundred-day-old launch mints as
readily as this morning's.

On it: the box art at 132 with the mark on it, the product name, the
studio's name with its mark, the type and topic, the launch day, the
verdict (average in the 5×7 face with a one-word reading), the four
outlets as chips — or, under T7's exclusive, the one verdict that is out
and the rest as `embargoed` chips — a pulled quote from the press, the
first week's units and cash, the stake pennant when the run is staked
(`rules.stake`, the biography card's own line), and the `SS1-…`
`SeedCode` in the footer.

### Offered

- **`LaunchDaySheet`** — at the *end* of the review-reveal flow, after
  the market section. One line, purely additive; the ACTIONS area another
  lane is adding a launch-party row to was not touched.
- **`WarRoomScreen`** — one line inside `LaunchDayPanel`'s
  `revealComplete` block, under the first week.
- **`StorefrontScreen`** — one line at the foot of the released page, so
  every product that ever shipped can still be minted.

All three are the same `LaunchCardButton`, which owns its own sheet
state, so no host gained a `@State`.

### Check: the best and the worst launch, both legible, neither blank

`-autoRoute i18-card-best` / `i18-card-worst` (DEBUG only, in
`LaunchCardDebug`, one line on `HQScreen`) opens the card over HQ for the
best or worst launch of whatever fixture `-autoFixture` installed.
Screenshotted on `iPhone 17 Pro`:

| Fixture | End | Result |
|---|---|---|
| `release-campus-day900` | best | **Round 32, 81, "Well received"**, green verdict, The Stack Review's *"We are going to reference this architecture in future reviews…"* at 86. Proud. |
| `release-studio-day400` | worst | **Round 5, 48, "Mixed"**, red verdict, and it leads with TechDaily's **39**: *"A promising team having a difficult launch. Everyone shipped a music app this month."* Funny, and the joke is at the studio's expense. |
| `release-garage-day40` | either | Nothing shipped yet, so no card is offered at all — correct, not blank. |

The first pass left a hole in the middle of the card where the quote sat
high and the figures sat low; the quote now floats between two spacers
with a coloured rule down its left edge, which is what the shipped shots
show.

`-autoMarkSeed <n>` dresses a loaded save with a mark through the
ordinary reducer, so a *marked* card was photographed too (the plum ring
beside "Halcyon Systems", and the same glyph in the box-art corner).

### Deviations

1. **The overpromised band could not be photographed against a fixture.**
   No release fixture carries a pre-order book (`grep preorders` over all
   four is zero), and seeding one would have meant a new debug seed in
   T5's `Expo.swift` — another lane's file, in a round where T5 is
   adjacent. The band ships, reads `product.preordersOverpromised` (T5's
   own derived property, untouched), and **was** verified visually by
   forcing the branch on in a throwaway build: the OVERPROMISED stamp in
   the 5×7 face, white on `ShareInk.failure`, full card width, with the
   units-and-forecast line beside it. Screenshot taken, branch reverted
   before the commit.
2. **The newspaper's mark is a badge, not a masthead replacement.** The
   paper is the industry's ("THE DAILY BUILD"), not the studio's, so the
   mark sits beside the masthead the way a trade paper runs the logo of
   whoever the issue is about. Without a mark the masthead is centred
   exactly as it was.
3. **Rival marks are on the map, the roster and the profile**, not on
   every head-to-head surface — price-war prompts and espionage cards
   already carry a portrait and a name in tight rows, and a third badge
   made them worse. Cheap to add later wherever #6's chart rows land.
4. **The peak-rank stamp (#6) is not on the card.** That lane owns
   `ReleaseInfo.peakRank`; the card has an obvious place for it under the
   verdict.

---

## Files touched

Engine (`Packages/TycoonEngine/Sources/TycoonEngine/`):
`GameState.swift` (`Company.markSeed` + encode/decode), `GameAction.swift`
(`chooseStudioMark`), `Reducer.swift`.

PixelKit (`Packages/PixelKit/Sources/PixelKit/`): `StudioMarkBuilder.swift`
(new), `CitySpriteLibrary.swift` (`playerHQ`/`rivalHQ` gain `markSeed:`),
`CityMapComposer.swift` (`CityDistrictInfo.rivalMarkSeeds`, cache keys),
`Ambience.swift` (`CityAmbience.markSeed`).

App (`App/Sources/`): `Components/StudioMarkView.swift` (new),
`Share/LaunchCardView.swift` (new), `Components/ProductBoxArt.swift`,
`Components/LaunchDaySheet.swift`, `Share/ShareRenderer.swift`,
`Share/BiographyCardView.swift`, `Share/FrontPageCardView.swift`,
`Screens/Onboarding/NewGameFlow.swift`, `Screens/Storefront/StorefrontScreen.swift`,
`Screens/WarRoom/WarRoomScreen.swift`, `Screens/Story/NewspaperComposer.swift`,
`Screens/Story/NewspaperScreen.swift`, `Screens/City/CityMapScreen.swift`,
`Screens/City/CityMapModel.swift`, `Screens/Business/RivalsView.swift`,
`Screens/Business/RivalProfileScreen.swift`, `Screens/HQ/HQScreen.swift`,
`GameSession.swift`, `GameSession+CustomGame.swift`,
`Resources/Localizable.xcstrings` (`make strings`, 1,977 keys).

**No test file was created or edited**, in the app target or any package.

## Suites run

- `make test` — TycoonEngine 943 in 135 suites, TycoonContent 52 in 7,
  TycoonSave 34 in 4, PixelKit 336 in 32. All green, twice (once after
  the mark, once after the card).
- `make apptest SIM="iPhone 17 Pro"` — 385 tests, 0 failures. The
  snapshot suites did not move, which is the dormant-by-default rule
  holding: nothing renders without a `markSeed`.
- `make build SIM="iPhone 17 Pro"` — succeeds.
- `App/Config/Version.xcconfig` is not in either commit.

One thing that cost a rebuild and is worth knowing:
`StringsAuditTests.testNoNewUnlocalizedPixelChrome` greps the *source
tree* for `PixelText(text: "`, so a **code comment** quoting that
fragment counts as a site. The pinned baseline of 49 is untouched by this
lane.
