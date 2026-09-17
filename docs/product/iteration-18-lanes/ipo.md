# Iteration 18 — A3: IPO day, priced and rung

Branch `i18-ipo`, two commits. PM spec: `iteration-18-pm.md` §3.

## What shipped

**The decision.** `fileIPO` gains `price: IPOPrice = .fair` behind a
defaulted argument (the T1/T2 precedent). `.fair`'s proceeds multiple is
exactly `1.0`, so the old action pays the same dollar, posts the same
ledger line and settles T1's exit at the same price it always did.
Conservative prices at `0.85×`, aggressive at `1.25×`, and the whole
company is sold at whatever number the founder picked — so the exit split
reads the same price the founder is paid at.

**The pop is derived, never drawn.** `GameState.ipoPop(price:balance:)` is
a pure function of the book as the bell rings:

```
pop% = ipoPopBase
     + ipoPopPerReviewPoint  × (average review of what is on sale − ipoPopReviewNeutral)
     + ipoPopPerHypePoint    × (average liveHype behind it)
     + ipoPopPerMarketPoint  × (average market multiplier − 1) × 100
     + price offset          (+ipoPopConservative / 0 / −ipoPopAggressive)
clamped to [ipoPopFloor, ipoPopCeiling]
```

No RNG stream is touched anywhere in the feature. A negative pop is a
**broken open**: reputation `−5` on the way out, the paper leads the week
with it (`NewspaperComposer.leadRank` +40 against +30 for a good open),
the feed line turns red, and the biography records it forever. A
conservative book warms every review outlet's standing by `+2`.

**What is written down.** `IPOResult` (price, ticker, offer valuation,
proceeds, pop, day-one close, day) lands in two places, both
encode-when-set: `GameOverInfo.ipo` — the ending's own record, which the
bell scene, the ending card and the share card read — and
`InvestorState.ipoResult`, which survives "Keep running it" (the ending
info is cleared there). `.wentPublic` gained two optional associated
values (`ticker`, `pop`), the `fire(payNotice:)` precedent, so an event
written before the bell encodes and decodes unchanged.

**The ticker.** `IPOTicker.derive(from:)` — no state, no draw. Several
words take the initials (`Blue Harbour Games` → `BHG`), two words take
three of the first and one of the second (`Pixel Forge` → `PIXF`), one
word takes its first letter and the consonants after it (`Northwind` →
`NRTH`, `Halcyon Systems` → `HALS`, `Meridian Labs` → `MERL`); a name with
nothing usable in it borrows letters from an FNV-1a fold of itself, not
`hashValue` (which is seeded per process). A–Z only, so the 5×7 face can
draw it.

**The sheet.** `IPOPricingSheet` replaces the confirmation dialog: three
rows, each with the money it pays, the street's read of the day
(`IPOQuote.oddsLine`) and — the house rule for anything with a cash
effect — the wallet afterwards and the offer valuation. T1's exit split
keeps its place under the rows; there is no accelerate/lapse toggle
because a listing offers no acceleration (`fileIPO` passes
`accelerate: false`), so the row prints the loan, the vested payout and
says the unvested lapse home.

**The scene.** `IPOBellScreen` in the war room's full-screen grammar: top
bar with the pixel title, the hall with its windows, the board with the
ticker in the 5×7 face, the bell (it drops and clangs, the desk screens
light, arms go up in the crowd), then the first day drawing itself print
by print off `IPOResult.dayOnePath()` — 24 prints derived from the ticker
and the day, so the same listing draws the same chart every time. It is
presented from `AppRootView.endingCover` **before** the biography, once
per run (keyed on seed + ending day), and `IPOBellContent` takes its beat
as a plain value so any moment can be drawn without the timer.

**Reduce Motion** (`Theme.Motion.isReduced` and
`\.accessibilityReduceMotion`, the two idioms already in the app): the
scene is seated — every beat revealed at once, on the frame the animation
would have ended on, no ringing, no drawing chart, the same words under
it.

## The pricing check (before any UI)

Run with a throwaway SwiftPM executable in the scratchpad (no test added —
CLAUDE.md's rule), decoding the fixture `GameState` and calling
`GameEngine.resume` so the numbers are the ones the app would show.
`canFileIPO` is `false` on both fixtures (neither has the profitable
quarters), which does not affect the quote maths.

### `release-studio-day400` — Meridian Labs, `MERL`, valuation $572,043
book: review **65.5**, hype **0.0**, market **0.901**

| Price | Proceeds | Offer | Pop | Day-one close | |
|---|---|---|---|---|---|
| Conservative | $408,439 | $680,731 | **+18.4%** | $806,315 | |
| Fair | $480,516 | $800,860 | **+8.4%** | $868,520 | |
| Aggressive | $600,645 | $1,001,075 | **−11.6%** | $885,435 | **broken open** |

### `release-campus-day900` — Halcyon Systems, `HALS`, valuation $2,151,053
book: review **73.1**, hype **0.0**, market **1.264**

| Price | Proceeds | Offer | Pop | Day-one close |
|---|---|---|---|---|
| Conservative | $511,951 | $2,559,753 | **+46.3%** | $3,745,495 |
| Fair | $602,295 | $3,011,474 | **+36.3%** | $4,105,318 |
| Aggressive | $752,869 | $3,764,343 | **+16.3%** | $4,378,779 |

**The read.** On the campus the book carries the greed: aggressive pays
25% more and still opens up 16%, so **aggressive wins there**. On the
studio the same greed breaks the open — reputation 5, the front page, and
the line in the biography — so **fair wins there**, exactly the split the
spec asked for. Conservative is the deliberately dominated row: it pays
least on both and buys a certain headline plus press standing; it only
becomes the right answer on a book weak enough that even fair is near
zero (the studio's fair is +8.4%, so a slightly worse shelf flips it).

**Tuned coefficients** (defaults in `BalanceConfig.ExitsBalance`, every
key optional-decoded so `Balance.json` is untouched): `ipoPopBase 18`,
`ipoPopPerReviewPoint 0.8`, `ipoPopReviewNeutral 70`,
`ipoPopPerHypePoint 0.25`, `ipoPopPerMarketPoint 0.6`,
`ipoPopConservative 10`, `ipoPopAggressive 20`, `ipoPopFloor −40`,
`ipoPopCeiling 120`, `ipoConservativeProceeds 0.85`,
`ipoAggressiveProceeds 1.25`, `ipoBrokenOpenReputation 5`,
`ipoConservativeStanding 2`. The first pass (`base 6`, conservative +14,
aggressive −26) broke fair open on the studio and aggressive on both —
aggressive could never win — so the base rose and the aggression discount
fell until the split above held.

**One caveat for the balance owner:** `liveHype` is **0.0 on both
fixtures** (it decays after a launch), so `ipoPopPerHypePoint` is inert in
this check. It only bites when the founder files in the weeks after a
launch — worth a look the first time someone lists straight off a ship.

## The A7 hook (the street, not in this round)

A7 wants a broken open to start the post-IPO premium low. The hook is
already in place and needs no engine change: `InvestorState.ipoResult`
(`Investors.swift`, encode-when-set) survives `.continueAfterEnding`,
which clears `gameOver` and with it `GameOverInfo.ipo`. A7 should seed its
premium from `state.investors.ipoResult` — `pop` for the opening premium
and `brokeOpen` for the "the street never forgave the open" start — read
where the epilogue's first quarter is set up. `dayOneClose` is the natural
base for the first quarter's mark.

## Deviations from the spec

- **The old action is `.fileIPO()`, not `.fileIPO`.** A Swift enum case
  with an associated value cannot be spelled bare, so the eleven call
  sites (the bot, four test files) gained empty parentheses. The
  *behaviour* and the encoded action are unchanged, and the defaulted
  argument means nothing else moved.
- **The fair ending sentence gained a clause** ("HALS closed its first
  day +36%."). Filing is now always a priced offering, so every IPO has a
  ticker and a close; no dormant state and no other ending is touched.
- **T1's exit-split row is informational on this sheet**, with no
  accelerate/lapse choice, because a listing has no acceleration to offer.
- **The bell scene is drawn with `Canvas` blocks in the app**, not with a
  new PixelKit sprite scene: the 5×7 ticker goes through `PixelText` and
  every colour is a `Theme.pixel*` / `Theme` token, so nothing invents a
  colour, but the exchange floor is not a PixelKit room. A future lane
  that wants the floor in the sprite grammar can replace
  `IPOBellContent.floor` alone.

## Files touched

Engine:
- `Packages/TycoonEngine/Sources/TycoonEngine/IPO.swift` (new)
- `.../Systems/InvestorSystem.swift`, `.../Reducer.swift`,
  `.../GameAction.swift`, `.../GameState.swift`, `.../Investors.swift`,
  `.../Systems/ChildhoodSystem.swift`,
  `.../Balance/BalanceConfig+Exits.swift`
- `.../Sources/TycoonBots/InvestorBots.swift` (call site only)

App:
- `App/Sources/Screens/Business/IPOPricingSheet.swift` (new)
- `App/Sources/Screens/Endings/IPOBellScreen.swift` (new)
- `App/Sources/Screens/Business/InvestorsView.swift`,
  `App/Sources/AppRootView.swift`,
  `App/Sources/Screens/Endings/FounderBiographyView.swift`,
  `App/Sources/Share/BiographyCardView.swift`,
  `App/Sources/Narrative/ProgressionEventPresenter.swift`,
  `App/Sources/Screens/Story/NewspaperComposer.swift`,
  `App/Resources/Localizable.xcstrings` (`make strings`)

Tests: **no new tests** (CLAUDE.md). Five existing files took the
mechanical `.fileIPO()` / pattern-arity fix only.

## Suites run

- `make test` — 943 + 52 + 34 + 336 tests, all green.
- `make apptest SIM="iPhone 17e"` — 385 tests, green. (One real catch:
  `StringsAuditTests.testNoNewUnlocalizedPixelChrome` flagged three bare
  `PixelText` literals; they went through `String(localized:comment:)`
  rather than the baseline being raised.)
- `make build SIM="iPhone 17e"` — succeeded.
- The scene was photographed on the simulator in both variants
  (`-autoRoute a3-bell`, `-autoRoute a3-broken`).
