# Iteration 18 — X4: throw the launch party

Lane `i18-party`, off `main` at `af5f2e0`. Three code commits —
`6d6f902` (engine), `c66102c` (sheet, room, rows), `20c51b5` (the room at a
full studio) — plus this report.

## What shipped

**One action.** `.throwLaunchParty(productID:venue:guests:)`, valid for
`party.windowDays` (7) after a launch and once per launch. Validity is
enforced in the reducer through `GameState.launchPartyBlocker`, which is
also the function the button reads — the house rule from
`FounderQueries.swift`, so a stale sheet can never spend anything. It
refuses on: not shipped, run over, founder away, already had one, before
the launch, past the window, the diary date kept instead, not enough cash,
no evening left.

**Three venues, priced against the reviews.** $300 office / $1,500 bar /
$6,000 rooftop, each also costing one founder evening — `state.spendEvening`,
the same pool `.seeFriend`, `.moveHome` and a founder-staffed expo booth
draw on.

**Effects, all through existing fields.**

| field | what the party does |
|---|---|
| everybody's `morale` | +2 / +4 / +6, the `SocialSystem.teamDinner` shape |
| `ReleaseInfo.liveHype` | venue's hype × the review slope (below) |
| `Company.pressStanding` | +2 per invited outlet; −3 to *every* outlet when the night reads desperate. Clamped to ±`press.cap`, written `nil` at zero — `PressSystem.grantExclusive`'s exact arithmetic |
| `Contact.rapport` | +6 per invited name, and `lastMetDay` moves |
| the vices' weekly pressure | see the first join |

**The scene.** `PartyFloorView` in `App/Sources/Screens/Products/PartySheet.swift`
is the networking floor's composition (`NetworkingFloorView`'s backdrop,
floor line, seeded scatter and `PixelFigure`) with the studio's own roster
in it: every non-away employee drawn from the appearance seed the office
draws them from, the invited press and contacts standing behind them, the
founder in the corner. Figures shrink in bands as the crowd grows and lose
their labels past six, so a twelve-person studio is a crowd rather than a
pile. Reduce Motion (and VoiceOver) stand everybody still on one frame —
`PixelFigure` gained a `reduceMotion` flag, defaulted off so the networking
floor is untouched, mirroring `OfficeSceneView.resolvedInput`.

**The rows.** `PartyLaunchRow` in the ACTIONS area of `LaunchDaySheet` (one
marked region after T6's, nowhere near the review-reveal end) and on
`WarRoomScreen`'s `LaunchDayPanel` behind the same `revealComplete` gate.
Both draw nothing outside the window, on a launch that already had its
party, or on one where the date was kept.

**Every option prints the cash after-state** via the house helper
`DecisionPrompt.afterState(delta:cash:burn:)` — photographed on the studio
fixture as `−$6,000 → $84,875 · runway 4 wk`.

## The EV check, and the slope shipped

The PM's "how it fails" test: *if the EV is positive, the biggest party is
automatic; compute the rooftop's EV at review 60 on the studio fixture, and
if it is still positive, steepen the slope.*

**The slope shipped.** `liveHype += venue.hype × clamp((review − 60) / 25,
−1.2 … 1.5)`. Pivot 60, so the $6,000 rooftop at a 60 buys exactly nothing;
under it the party *removes* hype.

**First measurement was wrong and is worth recording.** Differencing
`company.cash` 120 days out, with and without the party, produced nonsense
— a $1,500 bar "earning" +$8,236 at review 40, flat across every score.
Spending cash changes what the company can afford, which changes hires and
incidents and the draws behind them, and the run diverges into noise that
swamps the party entirely. The number is chaos, not EV.

**The measurement that holds.** Both arms are the identical state; the only
difference is `liveHype`, added with no cash spent. The readout is the
product's own posted revenue over 120 days — the only channel the hype
touches (`ProductSystem.postWeeklySales`: the weekly peak gains
`liveHype × liveHypeSalesFactor / salesHypeDivisor` = `/150`, decaying
2%/day). The venue's price is then charged against that.

Studio fixture (`release-studio-day400`, day 400, $90,875, twelve on
payroll), all four outlets pinned to the score, its nearest build shipped:

| review | venue | slope | hype | cost | revenue Δ | **EV** | reads |
|---|---|---|---|---|---|---|---|
| 40 | office | −0.80 | −4.8 | 300 | +0 | **−300** | earned |
| 40 | bar | −0.80 | −11.2 | 1,500 | +0 | **−1,500** | desperate |
| 40 | rooftop | −0.80 | −24.0 | 6,000 | +0 | **−6,000** | desperate |
| 55 | rooftop | −0.20 | −6.0 | 6,000 | +0 | **−6,000** | desperate |
| **60** | **office** | **+0.00** | **+0.0** | **300** | **+0** | **−300** | earned |
| **60** | **bar** | **+0.00** | **+0.0** | **1,500** | **+0** | **−1,500** | earned |
| **60** | **rooftop** | **+0.00** | **+0.0** | **6,000** | **+0** | **−6,000** | **desperate** |
| 70 | rooftop | +0.40 | +12.0 | 6,000 | +136 | **−5,864** | desperate |
| 75 | rooftop | +0.60 | +18.0 | 6,000 | +223 | **−5,777** | earned |
| 85 | rooftop | +1.00 | +30.0 | 6,000 | +334 | **−5,666** | earned |
| 95 | rooftop | +1.40 | +42.0 | 6,000 | +600 | **−5,400** | earned |
| 95 | office | +1.40 | +8.4 | 300 | +116 | **−184** | earned |

**The check passes without steepening the slope: the rooftop's EV at review
60 is −$6,000 exactly** — zero hype revenue against the full price. It is
negative at every score and every venue; the best money the hype ever
returns is +$600 on a 95-score rooftop against $6,000 spent.

**What the number actually says, and the one deviation it caused.** The
hype→sales channel is far weaker than the spec assumed: `liveHype` 42 is
worth about $600 over four months on this fixture. So the party is never
bought for money, and the slope's real job is not EV control but *reading* —
it is what makes the hype go negative under 60 and what the desperate rule
hangs off. The party's actual payoff is morale (+6 × 11 heads = +66 points
in one evening), press standing and rapport. That is a better shape than
the spec's — a morale-and-relationships purchase with a cash-and-evening
price — and it is why no tuning followed.

**The one tune made.** At `desperateStanding = −1` (the spec's number), an
invited outlet at a desperate rooftop still came away at **+1** (+2 for
attending, −1 for the venue), which does not read as desperate at all.
Shipped **−3**, so an outlet who stood on the roof of a company that had
just shipped a 55 leaves a point *colder* — the spec's "press standing −1",
exactly — and one who stayed home is three points colder for having read
about it. Measured on the fixture: all four outlets at −1 after a rooftop
for a 60.

Non-money side at review 60, studio fixture (12 on payroll, 2 evenings left
of 3):

```
office   morale +22 over 11 heads · 2 outlets, 0 contacts · press [AppVerdict +2, TechDaily +2]
bar      morale +44 over 11 heads · 4 outlets, 0 contacts · press [all four +2]
rooftop  morale +66 over 11 heads · 4 outlets, 3 contacts · press [all four −1]
```

## The three joins, verified by hand

Verified twice: once in the engine with a throwaway script against the
studio fixture (scratchpad, not committed, no test added), and once in the
running app on the iPhone Air simulator via `-autoRoute x4-…`.

**1. J1's vice door.** The "launch-party vice odds" are not odds — the door
itself is a deterministic 21-of-28-crunch-days threshold that draws nothing
(`Doors.swift:12-17` makes that an identity invariant). The actual
launch-party term is `AssetViceDef.perLaunch`, the weekly dependency growth
in `AssetsSystem.runViceWeek` — *"A launch is a party, and a party is a late
one"* — which K7 already subtracts a kept date from and T6 an away launch
from. A real party thrown on crunch adds it back a second time,
`× party.viceCrunchFactor` (1.0), reading `state.parties`, which is absent
by default. Measured, drink dependency after the week's pass:

```
no party, normal   4.50     party, normal   4.50    (identical)
no party, crunch   7.50     party, crunch  13.50    (+6.0 — one more perLaunch)
```

**2. K7's diary clash.** The party calls `DiaryRoadmap.noteLaunch` — the
same one line `ProductSystem.ship` calls — so it clashes on exactly the
window and predicate a launch does. Dressed with K7's own seed
(`.partnerDebugSeed(stage: "launch")`, which marries the founder and puts
the anniversary on the day): the clash flag went `false → true` on the
party, and *Keep the date* became offerable. Negative direction: with
`.diaryDateKept` in the log the blocker reads *"You kept the date instead"*,
the reducer returns no events and `parties` stays empty — a date kept is
the party not happening, which is what K7 has always priced it as.

**3. T6's founder away.** `launchPartyBlocker` tests
`life.isAway(day: day)` before anything it could spend, and
`GameState.awayPartyReason` names the absence from `life.awayReason`.
Measured with a hospital stay: blocker *"You are in hospital. There is no
party without you"*, no events, cash unmoved ($90,875 → $90,875), evenings
unmoved (0 → 0), no party recorded. The sheet surfaces that line **in place
of the venues**, not as a dead button; photographed via `-autoRoute x4-away`
reading *"You are away on a course. There is no party without you."*

**The cap and the window**, checked with them: a second party is refused
(*"You already had one"*) and costs nothing; at launch day + 8 the blocker
is *"Launch week is over"*.

## Byte identity

- `GameState.parties` is `[]` by default and encoded only when non-empty.
  Verified: the studio fixture re-encodes with no `parties` key (154,355
  bytes); 30 days of simulation from it still writes none (day 430, 157,164
  bytes); a run that throws one writes it and round-trips.
- `balance.party` is an optional JSON key with the shipped numbers inline
  as `.default`, read only behind the action.
- No bot sends `.throwLaunchParty`; no new RNG path anywhere; nothing in
  the lane draws from any stream.
- No baseline or fixture was touched. No snapshot test failed.

## Deviations from the spec

1. **`desperateStanding` is −3, not −1.** −1 left an invited outlet at net
   +2 − 1 = +1 after a party that read desperate. −3 produces the spec's
   stated outcome (invited outlets end at −1). Reasoned above.
2. **The slope was not steepened**, because the check it was conditional on
   passed: the rooftop's EV at review 60 is −$6,000.
3. **`RoomBuilder` was not used.** The brief named it, but it is `internal`
   to PixelKit and unreachable from the app; `NetworkingVenueSheet` does not
   use it either. The party reuses what the networking floor actually
   reuses — `SpriteLibrary.person` + `CharacterAppearance` through
   `PixelFigure`, with a per-venue gradient backdrop. Adding a public party
   room to PixelKit would be a bigger, separate change.
4. **The newspaper snarks through `EventCopy`, not a dedicated
   `NewspaperComposer` line.** `.launchPartyThrown`'s copy puts the score
   next to the venue and notes the standing cooled; the composer picks it up
   like any other dated event. `PartyCopy.newspaperLine` exists for a lane
   that wants a lead line, and is currently unused — say so if it should be
   wired to a masthead.
5. **`GameShell.partyProductID`** was added so `-autoRoute x4-…` can
   photograph the room without a tap. The scene is the feature and the
   screenshot pass could not otherwise reach it.
6. **No tests added**, per CLAUDE.md. Both verification passes were
   throwaway scripts in the scratchpad.

## Files touched

Engine (`Packages/TycoonEngine/Sources/TycoonEngine/`):
- new `LaunchParty.swift` — `PartyVenue`, `PartyGuest`, `LaunchParty`,
  `PartyQuote`, every `GameState` query, `LaunchPartyMath`
- new `Systems/PartySystem.swift` — `throwParty`
- new `Balance/BalanceConfig+Party.swift` — the `party.*` block
- new `PartyDebugSeed.swift`
- `GameAction.swift`, `Reducer.swift`, `GameState.swift`,
  `Balance/BalanceConfig.swift`, `Resources/Balance.json`,
  `Systems/AssetsSystem.swift` — one marked region each

App (`App/Sources/`):
- new `Screens/Products/PartySheet.swift`, `PartyLaunchRow.swift`,
  `PartyCopy.swift`
- `Components/LaunchDaySheet.swift`, `Screens/WarRoom/WarRoomScreen.swift`,
  `Components/EventCopy.swift`, `Screens/Life/NetworkingVenueSheet.swift`
  (`PixelFigure.reduceMotion`), `Screens/Products/ProductsScreen.swift`,
  `DebugLaunch.swift`, `GameShell.swift`, `AppRootView.swift`
- `App/Resources/Localizable.xcstrings` — one `make strings`, 1,977 keys

## Suites run

- `make gen` — clean
- `make test` — TycoonEngine, TycoonContent, TycoonSave, PixelKit all green
- `make apptest SIM="iPhone Air"` — `Executed 385 tests, with 0 failures`,
  the same count as the merged iteration-17 tree
- `make build SIM="iPhone Air"` — succeeds
- `App/Config/Version.xcconfig` reverted before every commit; no `build/`
  or generated noise committed

## Debug flags

`-autoRoute x4-open` (a well-reviewed launch, the window open, the room and
three affordable venues), `x4-desperate` (the same launch at 55, so the
rooftop row reads back what it is), `x4-thrown` (the rooftop already thrown,
the aftermath), `x4-away` (the founder elsewhere, the row that says so).
All four dress `release-studio-day400`; DEBUG only, nothing in the game
sends `.partyDebugSeed`.

## For the merger

- The launch-sheet row is one marked `X4` region in the ACTIONS area, added
  after T6's block and before `if let release {`. The identity lane's share
  card belongs at the review-reveal end, which is untouched.
- The war-room row is inside `LaunchDayPanel`'s `revealComplete` branch,
  between `firstWeek` and the *Back to the office* button.
- `moraleAll` is written through a private helper inside `PartySystem`
  reading only `party.*` constants; nothing of the awards lane's is shared.
- `PixelFigure` gained one defaulted property. Any lane touching
  `NetworkingVenueSheet.swift` should keep it.
- `PartyCopy.newspaperLine` is written and unwired — the one loose end.
