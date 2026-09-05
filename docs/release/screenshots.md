# The store screenshots

```sh
make screenshots
```

Builds the app once (Debug, iOS Simulator), installs it on a 6.9" iPhone
and a 13" iPad, launches it once per shot with a bundled fixture save
already in slot 0, and photographs it with `simctl io screenshot` into
`docs/release/screenshots/<device type>/`. Eleven shots per device, 22
files; the script fails if the count is wrong or any PNG is suspiciously
small, because a launch that dies quietly still produces a valid picture
of a black screen.

The devices are the Makefile's `SHOT_SIM_PHONE` and `SHOT_SIM_IPAD`. Use
clones if you would rather not have the pipeline reinstall over your own
simulators — the output folder is named for the simulator's *device
type*, not its name, so a clone called `r8-max` still writes into
`iphone-17-pro-max/`:

```sh
xcrun simctl clone "iPhone 17 Pro Max" shots-max
xcrun simctl clone "iPad Pro 13-inch (M5)" shots-ipad
make screenshots SHOT_SIM_PHONE=shots-max SHOT_SIM_IPAD=shots-ipad
```

## What App Store Connect wants

Two sizes carry the whole listing; everything narrower is derived from
the 6.9" set, and every iPad size from the 13" set.

| Size | Device | Pixels (portrait) | Folder |
|---|---|---|---|
| 6.9" iPhone | iPhone 17 Pro Max | 1320 × 2868 | `iphone-17-pro-max/` |
| 13" iPad | iPad Pro 13-inch (M5) | 2064 × 2752 | `ipad-pro-13-inch-m5-12gb/` |

**Ten per size is the maximum.** The pipeline shoots eleven: the first
ten in numeric order are the listing, in order, and `11-campus` is an
alternate for `03-hq` if the campus office sells the game better than the
studio does.

## The shots

| # | What | Fixture | Launch |
|---|---|---|---|
| 01 | The front door — the office at night, Continue with the founder's face, three slots | studio, day 400 | *(none)* |
| 02 | Where you start: one founder, a garage, three desks, day 40 | garage, day 40 | `-autoTab hq` |
| 03 | What it becomes: the Now card, a goal with its action, twelve at their desks | studio, day 400 | `-autoTab hq` |
| 04 | Life — the fortnight, your week, the evenings, tonight's options | studio, day 400 | `-autoTab life` |
| 05 | Team — 34 staff, three departments, the roster with traits and bonds | campus, day 905 | `-autoTab team` |
| 06 | Products — three builds in flight, phase bars, work pace | studio, day 400 | `-autoTab products` |
| 07 | Launch week's war room — T-minus, the room, the whiteboard | studio, day 400 | `-autoTab products -autoRoute warroom` |
| 08 | Business — the desk, the market pulse, hot and cold | campus, day 905 | `-autoTab business` |
| 09 | The market as a map — twelve districts, rival flags, the incumbent | campus, day 905 | `-autoTab business -autoRoute marketmap` |
| 10 | The weekly newspaper — the headline, the office photo, rivals and market | studio, day 400 | `-autoTab hq -autoRoute newspaper` |
| 11 | *(alternate)* The campus: 35 desks, "be ready to go public" | campus, day 905 | `-autoTab hq` |

Every launch also carries `-unlocked` (R6's flag), because the listing
shows the whole game.

## The fixtures

`-autoFixture <name>` is a DEBUG launch flag that installs a bundled save
into slot 0 **before the shell appears**, through `SaveStore`, so the app
resumes it down the ordinary path (`App/Sources/ReleaseFixtures.swift`).
Three of them, in `App/Resources/Fixtures/`:

| Name | Day | Company |
|---|---|---|
| `release-garage-day40` | 40 | Northgate — one founder, a garage, the first build in progress |
| `release-studio-day400` | 400 | Meridian Labs — a studio, 12 people, three builds, one in launch week |
| `release-campus-day900` | 905 | Halcyon Systems — a campus, 35 people, a seated board, $616k |

They are real bot runs against the shipped `Balance.json` with rivals on,
written by the engine test target's `ReleaseFixtureGenerator` from pinned
seeds. Each stops on a **quiet** day — nothing pending — because the app
puts a `DecisionSheet` over every tab whenever a question is waiting, and
the first campus draft photographed as a modal about a feature nobody
could see the market behind.

Regenerate deliberately, and reshoot afterwards:

```sh
cd Packages/TycoonEngine
REGENERATE_RELEASE_FIXTURES=1 swift test --filter regenerateReleaseFixtures
# and, if a brief no longer has a seed that satisfies it:
SEARCH_RELEASE_FIXTURE_SEEDS=1 swift test --filter searchForSeeds
```

`theCommittedFixturesStillDecodeAndStillMatchTheirBriefs` runs in the
ordinary engine suite and fails if an engine change breaks them, so you
find out from a test rather than from three black screenshots.

The JSON never ships: `EXCLUDED_SOURCE_FILE_NAMES = release-*.json` in
the Release configuration keeps it out of the archive (checked — a
Release build's bundle contains `PrivacyInfo.xcprivacy` and no fixtures).

## Two things the pipeline deliberately does not shoot

- **The company timeline** (`-autoRoute timeline`). Its year view stacks
  every moment's label at the same height, so a company with 35 of them
  photographs as overlapping text. The pipeline can still take the shot —
  add the line back to `SHOTS` — but it is not listing material until the
  timeline lays its labels out. That is the timeline's work, not this
  lane's.
- **The org chart** (`-autoTab team -autoRoute orgchart`). At 35 people
  the chart opens scrolled to the middle of a tree far wider than the
  screen, so the shot is a handful of cards and a lot of paper.

## One iPad rough edge, recorded

On the iPad the tab bar is a floating pill at the top of the window
(iPadOS's own `TabView` presentation), and a pushed screen's Back chevron
lands beside it rather than under it — visible on `10-newspaper`. It is
the system's chrome placement, not the column, and it does not affect the
phone. Worth a look from whoever owns navigation next.
