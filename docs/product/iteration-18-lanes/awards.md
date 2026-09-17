# Iteration 18 — AWARDS lane: awards night, attended (G8)

Branch `i18-awards`. Implements the pre-vetted spec in
`docs/product/iteration-17-pm/genre.md` §8, as directed by
`docs/product/iteration-18-pm.md` §5.

## What shipped

**The cutoff has a date.** From `awards.cutoffNoticeDays` (28) before the
ceremony — day 350 of every year, where `AwardsJudge` has always held it —
the Now card prints *Awards cutoff in N days* beside T5's expo countdown,
and the ship sheet (`ShipSheet`, the ship-or-polish decision) prints the
same line in its header. Both render nothing outside the window and
nothing once the year's night has been answered, so eleven months of every
year read exactly as they read before this lane.

**The night has a room.** `AwardsNightSheet` was a list that appeared
already decided. It is now two phases:

1. *Take the team* — `awards.tableByTier`, one founder evening, with the
   house after-state line (`DecisionPrompt.afterState`) under it:
   `−$2,400 → $x · runway y wk`. Refusals (no evening, no cash, already
   answered) are drawn in the player's words on a greyed answer rather
   than hidden. Or *Stay home*.
2. The envelopes, opened one at a time on a tap, with your team's row
   (`PixelPortrait`, up to eight, the rest as `+N`) drawn above them. An
   *Open them all* escape sits under the button. Reduce Motion is honoured
   through `Theme.Motion.entrance`, which is `nil` when it is on — the
   tapping stays, because the tapping is the scene, not the movement.

The question phase has no Done button and no interactive dismiss: a night
dismissed rather than answered would leave the clock paused with nothing
to resume it.

**One action.** `.recordCeremony(year:attended:wins:)`, sent from the sheet
after the app-side judge has run. The engine never learns to judge.
`AwardsSystem.recordCeremony` charges the table, posts the ledger entry,
spends the evening, pays out, and files one `CeremonyRecord` per year — so
a sheet reopened on a reloaded save cannot pay twice.

**Dormant by default.** `Company.ceremonies` encodes only when non-empty.
Verified directly: all five bundled fixtures decode to an empty
`ceremonies` and re-encode without the key (output below). No fixture sits
inside the 28-day notice window either — the four late fixtures land on
days of the year 40, 36, 172 and 172 — so the countdown line does not
appear in any fixture screenshot, and the HQ snapshot tests (which run a
day-1 engine) were untouched. No test baseline was modified.

## The judge run — "how it fails", run first

The judge is a pure function, so it was run on both late release fixtures
before a line of this lane was written, via a throwaway SwiftPM executable
that compiled the real `AwardsJudge.swift` against `TycoonEngine` and
`TycoonContent` (no test was added anywhere; the harness lives outside the
repo and is not committed).

```
FIXTURE release-studio-day400  (day 400, Meridian Labs, 14 player releases, 4 rivals / 14 rival launches)
  ceremonies reached: 1
  YEAR 1 — player wins 9 of 10 envelopes (6 of them topic categories)
      Product of the Year : Round 11  — Meridian Labs · 76   <<< PLAYER
      Studio of the Year  : Meridian Labs — 11 launches      <<< PLAYER
      Best Newcomer       : Meridian Labs — for Round 11     <<< PLAYER
      Best in Fitness     : Round 1  · 64                    <<< PLAYER
      Best in Finance     : Round 2  · 56                    <<< PLAYER
      Best in Social      : Marrow — Summit Crate · 46
      Best in Travel      : Round 10 · 69                    <<< PLAYER
      Best in Music       : Round 11 · 76                    <<< PLAYER
      Best in Productivity: Round 3  · 67                    <<< PLAYER
      Best in Health      : Round 6  · 59                    <<< PLAYER
  wins per year = [9];  a rival won a topic the player is live in: NO

FIXTURE release-campus-day900  (day 900, Halcyon Systems, 49 player releases, 4 rivals / 8 rival launches)
  ceremonies reached: 2
  YEAR 1 — player wins 7 (4 topic categories): PotY, SotY, Newcomer,
           Fitness 56, Finance 44, Travel 51, Productivity 48
  YEAR 2 — player wins 8 (6 topic categories): PotY, SotY,
           Fitness 60, Finance 67, Travel 70, Music 63, Productivity 72, Health 64
  wins per year = [7, 8];  a rival won a topic the player is live in: NO
```

Topics the player is live in on both fixtures: finance, fitness, health,
music, productivity, travel. The single rival win anywhere in either
fixture is Best in Social on `release-studio-day400` — a topic the player
has never shipped into.

### Both remedy branches fired

**Remedy A — "if the player wins three-plus categories a year on the
campus, halve the standing."** The campus fixture returns 7 and 8 wins in
its two years, more than double the trigger. `awards.winStanding` ships at
**7.5, not 15.**

Flagged for the next balance pass: halving is the spec's remedy and it is
what shipped, but at 6 topic envelopes a year that is still +45 standing in
a single evening. The bots out-ship the rivals so heavily (11 launches
against 14 across four rivals) that the judge is close to a formality on
these fixtures; whether a *player's* year looks like a bot's is the thing
nobody has measured yet.

**Remedy B — "if a rival never wins a topic the player is live in, the
night has no loss and `lossMoraleAll` is dead weight — make Studio of the
Year the only one the team cares about."** No rival wins a topic the player
is live in, in any year of either fixture. So both morale numbers now key
off **Studio of the Year alone** rather than off any win:

* Studio of the Year, team present → `studioReputation` +5 and
  `winMoraleAll` +8 for everyone on payroll.
* Attended, no Studio of the Year → `lossMoraleAll` −3.

Topic standing and hype still pay per topic envelope, as specified. This is
the only way the night can be lost in front of the floor, which is the
whole point of buying the table.

## Balance (`awards.*` in `Balance.json`, every key optional)

| key | value | note |
|---|---|---|
| `tableByTier` | garage/loft 2400, studio 4800, campus 9600 | spec's $2,400 ×1/×2/×4 |
| `winStanding` | 7.5 | **spec says 15**; remedy A fired |
| `winHype` | 20 | spec |
| `winMoraleAll` | 8 | spec's number, **on Studio of the Year only** (remedy B) |
| `studioReputation` | 5 | spec |
| `lossMoraleAll` | −3 | spec's number, **fires when Studio of the Year is lost** (remedy B) |
| `homeReputation` | 2 | spec, per envelope |
| `cutoffNoticeDays` | 28 | spec |

## Deviations from the spec, and why

1. **`winStanding` 7.5, not 15** — remedy A, fired by the spec's own
   measurement. See above.
2. **The two morale numbers key off Studio of the Year, not off any win**
   — remedy B, fired by the spec's own measurement. See above.
3. **The ceremony's date stays app-side.** The spec put `cutoffNoticeDays`
   in balance, which it is; it did not say where the day itself lives. It
   stays `AwardsJudge.ceremonyDayOfYear` (350), where it has been since
   iteration 8, rather than being copied into the engine as
   `expo.dayOfYear` was. Duplicating it would have created two sources of
   truth for one date; the engine does not need it, because
   `.recordCeremony` is guarded on the year not already being in the book
   rather than on the calendar.
4. **The ship-sheet line is on `ShipSheet`, not `LaunchDaySheet`.** §8's
   file list predates iteration 17's `ShipSheet`. `LaunchDaySheet` is the
   post-launch result; `ShipSheet` is the ship-or-polish decision the
   cutoff is actually about, and is what the iteration-18 brief calls "the
   ship sheet".
5. **Hype is paid on any envelope naming one of the player's products** —
   in practice the topic envelopes plus Product of the Year, so a product
   that takes both collects +40. The spec names the topic case; Product of
   the Year is literally "the winning product" and paying it the same +20
   read as the smaller surprise. Flagging it rather than hiding it.
6. **`homeReputation` is per envelope**, as the spec words it ("a win is
   reputation +2"). On the campus fixture's year 2 that is +16 reputation
   for a night spent on the sofa. It is the spec's number and shipped as
   written, but it is the one payout the fixtures argue with hardest and
   the next balance pass should look at it.

## Known limitations

* `GameShell.pendingAwardsYear` is transient, as it was before this lane.
  A player who quits on the ceremony day and reloads is not re-asked and
  that year goes unanswered — nothing is recorded, nothing is paid, and
  the cutoff line is gone. That behaviour is iteration 8's; this lane did
  not widen it, but it now costs a payout rather than a screen.
* The judge was run on bot-made fixtures. What a player's year of wins
  looks like is still unmeasured.

## Files touched

Engine (`Packages/TycoonEngine/Sources/TycoonEngine/`):

* `Awards.swift` — **new**: `CeremonyWin`, `CeremonyRecord`,
  `CeremonyRefusal`, the table price and the refusal query.
* `Systems/AwardsSystem.swift` — **new**: `recordCeremony`, the payouts.
* `Balance/BalanceConfig+Awards.swift` — **new**: the `awards` block.
* `Balance/BalanceConfig.swift` — `public var awards`.
* `GameState.swift` — `Company.ceremonies` + guarded coding;
  `GameEvent.ceremonyRecorded`.
* `GameAction.swift` — `.recordCeremony(year:attended:wins:)`.
* `Reducer.swift` — the one case.
* `Systems/StandingSystem.swift` — `recordAward`.
* `Resources/Balance.json` — the `awards` block, appended.

App (`App/Sources/`):

* `Awards/AwardsCutoff.swift` — **new**: the countdown arithmetic, the
  copy, and `AwardsCutoffRow`.
* `Awards/AwardsNightSheet.swift` — the attended scene.
* `Awards/AwardsJudge.swift` — topic and product on an envelope;
  `AwardsNight.ceremonyWins`.
* `AppRootView.swift` — the engine passed to the sheet.
* `Screens/HQ/NowCard.swift` — one row, beside T5's (additive, 6 lines).
* `Screens/Products/ShipSheet.swift` — the cutoff line in the header.
* `Components/EventCopy.swift` — the night's journal line.
* `Resources/Localizable.xcstrings` — `make strings`, 13 new keys.

## Suites run

| check | result |
|---|---|
| `make gen` | clean |
| `make test` (TycoonEngine 943, TycoonContent 52, TycoonSave 34, PixelKit 336) | all green |
| `make apptest SIM="iPhone 17"` | 385 tests, 0 failures, **TEST SUCCEEDED** |
| `make build SIM="iPhone 17"` | succeeds, no new warnings |

No tests were created, anywhere (CLAUDE.md hard rule). The one
`make test` hiccup seen was `PixelKit`'s
`fortyPeopleAtTwelveFpsStayWithinBudget` timing out at 0.688s against a
0.6s budget under load from a parallel build; it passes on its own and on
a re-run of the full suite, and PixelKit was not touched by this lane.

`App/Config/Version.xcconfig` was reverted after each `make gen` and is not
in any commit.
