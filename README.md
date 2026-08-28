# Startup Studio

A Game Dev Tycoon-style software-company tycoon game for iPhone. You run a
tiny startup from a garage: watch your cash, ship products before the money
runs out, hire people who have opinions about how you treat them, and try
to still have a life. Built with SwiftUI on a deterministic simulation
engine, with a living pixel-art office as the game's face.

## Features

A run starts with **onboarding**: name your founder, shuffle through
twenty-four pixel looks, and pick an archetype — hacker, designer or
hustler, each with its own starting skill spread. Name the company (or take
a generated one), choose a difficulty, and read a four-panel look, drawn
with the game's own pixel scenes, at what you are about to run.

Five tabs over the persistent cash/date/speed HUD:

- **HQ** — the animated pixel office (garage → loft → studio → campus) with
  the team walking to the coffee machine, huddling at the flip-chart and
  cheering a launch; the chapter card with three live goals and the perks
  earned so far; departments (Legal, People & HR, Operations, formed by
  hiring the matching role); amenities (game room, cafeteria, shuttle,
  gym); the journal; burn rate and runway; office upgrades; and the
  activity feed
- **Life** — the founder's own life: the pixel home (studio flat →
  penthouse), energy/health/mood/relationship meters, work schedule and
  work pace, founder salary and wallet, weekend plans and thirteen
  illustrated activity vignettes, shopping, the city map (five districts to
  relocate to, and an office you can rent, buy or sell), and family —
  dating, moving in, marriage and kids
- **Team** — a searchable, sortable roster with mood faces, trait chips,
  roles and seniority, and bulk assignment; hiring from a rotating pool
  where each candidate shows one trait and hides the second behind an
  interview that costs you a day; a manage sheet that says *why* somebody
  is unhappy and how many days of patience they have left; praise, raises,
  promotions, training and cuts
- **Products** — *Products* builds phase by phase (design / code / polish)
  with a tunable focus, bug hunting, and one to five concurrent builds
  depending on the office; live ops after launch — price tiers, patch
  cycles, live bugs the wild finds and support desks to staff; a launch-day
  sheet that reveals the reviews one at a time. *R&D* is a twenty-node,
  five-tier tech tree
- **Business** — six sections behind a scrolling pill bar: client contracts
  with deadlines *and* quality expectations, a market board of twelve
  topics with booms and crashes, marketing campaigns, the finance ledger
  and bank loans, rivals, and investors

### Under the tabs

- **Chapters and goals.** Thirty goals across five chapters, six each;
  finish enough of a chapter and the next one opens. Each goal pays
  reputation, cash, or a permanent perk — press contacts, a talent magnet,
  an investor rolodex, veteran crew, market darling.
- **A world with opinions.** 83 company events and 59 life events, most of
  them a real question with consequences spelled out on the buttons and a
  deadline that answers for you if you don't; choices schedule follow-ups
  weeks later, so a decision has a second act. 44 industry headlines, 11
  staff moments (a raise request, a rumour a rival is circling, a
  complaint that has to be handled properly), and per-outlet review voices.
- **Work pace and resignations.** Relaxed, normal or crunch, each trading
  output against morale and bugs. An unhappy employee does not vanish: they
  hand in notice and keep working, and a real raise or a promotion inside
  the notice period still turns it around.
- **The founder is a person.** Miss rent long enough and the landlord
  evicts you into somewhere cheaper. Two hospital stays in a year and you
  live with a chronic condition; three restorative weekends clear it. Burn
  out twice and the trade press notices.
- **Rivals.** Named studios shipping named products, splitting each topic's
  demand by quality-weighted share. A copycat clones your best topic eight
  weeks after you launch; beat somebody two weeks running in a topic you
  both sell into and they start a price war.
- **Traits.** Every hire arrives with two personalities derived from their
  face — a Speedster ships more and learns slower, a Flight Risk is nearly
  twice as easy to poach, a Mentor makes everyone else better while doing less
  themselves, a Grumbler drags the room down.
- **Investors, boards and endings.** Term sheets arrive once the company is
  worth a meeting. Take one and a board grades you on one number every
  quarter; miss it enough and they replace you. Four endings — bankruptcy,
  acquisition, IPO, ousted — and all four land on the same founder
  biography: the chapters and the day each opened, the best thing you
  shipped with its best review quoted, your longest-serving employee, your
  family, and the money.
- **The weekly report.** An end-of-week debrief — cash in and out by
  category, per-product sales with sparklines, morale and its direction,
  your own meters, what happened, and what is due next week. It opens
  itself for the first eight weeks and can be told not to, from the report
  itself.
- **Coaching without nagging.** A pause banner leads with the loudest
  reason the clock stopped, six dismissable coach tips keyed to the goals
  you actually have, a searchable journal that collapses routine weeks, and
  chiptune sound and haptics (both synthesized in-app, both switchable).

Plus autosave with versioned migrations, and a deterministic engine — same
seed, same game — under all of it.

## Layout

- `App/` — the SwiftUI app shell (HUD, tabs, screens, theme)
- `Packages/TycoonEngine` — the simulation engine (Swift package)
- `Packages/TycoonContent` — game content/data (Swift package)
- `Packages/TycoonSave` — save/load with versioned migrations (Swift package)
- `Packages/PixelKit` — the pixel-art renderer: office, home, city and
  activity scenes, sprites, palettes and the animation runtime (Swift
  package)
- `Packages/IconGen` — macOS dev tool that renders the app icon from
  PixelKit sprites (not part of the app)

## Requirements

- Xcode 26+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)

## Commands

```sh
make gen      # generate StartupStudio.xcodeproj from project.yml
make test     # run the TycoonEngine, TycoonContent, TycoonSave and PixelKit package tests
make apptest  # run the App target's own unit tests (StartupStudioTests)
make build    # build the app for the iPhone 17 simulator
make icon     # regenerate the app icon (AppIcon.png) from PixelKit sprites
make clean    # remove build artifacts and the generated project
```

The four package suites use Swift Testing — look for
`✔ Test run with N tests … passed`, and ignore the XCTest
"Executed 0 tests" line above it. `make apptest` is XCTest and reports
`** TEST SUCCEEDED **`.

## Playing the dev build

Build and install on a simulator from the command line:

```sh
make build
xcrun simctl boot "iPhone 17" || true   # no-op if already booted
open -a Simulator
xcrun simctl install booted build/Build/Products/Debug-iphonesimulator/StartupStudio.app
xcrun simctl launch booted com.alpsenel.startupstudio
```

For hands-off checks the debug build takes two launch arguments:
`-autoSpeed` starts the simulation running immediately (`x1`, `x2`, `x4`),
and `-autoTab` opens straight onto a tab (`hq`, `life`, `team`,
`products`, `business`):

```sh
xcrun simctl launch booted com.alpsenel.startupstudio -autoSpeed x4 -autoTab business
xcrun simctl io booted screenshot /tmp/shot.png
```

Either flag marks the launch as a headless pass: onboarding is skipped so
the app reaches the game, and the weekly report does not auto-open (it
holds the clock until somebody presses "Next week", which is right for a
player and a wall for a screenshot run). Both are `#if DEBUG` only —
release builds see neither.

## Notes

- `StartupStudio.xcodeproj` is **generated** and gitignored — never edit it
  by hand. `project.yml` is the source of truth.
- Re-run `xcodegen generate` (or `make gen`) after adding, removing, or
  moving files.
- The app icon is generated art: `make icon` re-renders
  `App/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png` from the
  game's own sprites via `Packages/IconGen`.

## Art notes

All of the game's pixel art is generated by `Packages/PixelKit` — there are
no image assets in the repo except the app icon, which is itself rendered
from the same sprites.

- **One palette.** `Palettes` is the master palette: eleven hue ramps of
  five steps (`ink`, `stone`, `clay`, `sand`, `gold`, `moss`, `teal`,
  `sky`, `indigo`, `ember`, `plum`) plus the skin, hair and shirt ramps.
  Shirt colours *are* neighbouring steps of a master ramp, which is why a
  crowded office reads as one wardrobe. `PaletteTests` fails the build if a
  sprite invents a colour, and gates every room at ≥ 18% wall-vs-floor
  luminance separation so people always read against the background.
- **Rooms are one sprite.** `RoomBuilder` bakes walls, trim, the accent
  stripe, the skirting shadow, three floor depth bands and all the fixed
  dressing into a single background sprite via `PixelCanvas`, so the
  dressing costs nothing to draw and can never drift out of the room.
  `officeSurfaces(tier:time:)` and `homeSurfaces(tier:time:)` are the
  hand-tuned colour schemes, one per tier per hour.
- **People are overlays.** Every adult pose keeps its head in rows 1–6 of a
  14-wide canvas; hair, glasses, beard, outfit and the role accessory are
  overlays that drop onto any pose and ride its head bob.
  `CharacterAppearance` derives everything from one seed, appending new
  fields to the SplitMix64 stream so old seeds never change.
- **Time of day** runs through `Ambience.swift` (`TimeOfDay`, `Weather`,
  `Season`, `HomeAmbience`, `CityAmbience`). Windows, skylines, room
  schemes, the lighting overlay and the city all take it.
- **Looking at the art.** The PixelKit test suite writes PNG previews of
  everything it draws — office and home scenes, the pose and role sheets,
  the master palette, the thirteen activity vignettes and the city map:

  ```sh
  PIXELKIT_PREVIEW_DIR=/tmp/pixelkit make test
  open /tmp/pixelkit
  ```

  The App target renders its own chrome the same way — the HUD, the pause
  banner, toasts, the weekly report's bottom bar, launch day, the box-art
  sheet and the bitmap font, each in light and dark. Those run inside the
  simulator, where `PIXELKIT_PREVIEW_DIR` from the host does not reach
  them, so they land in the app's own temporary directory:

  ```sh
  make apptest
  open "$(xcrun simctl get_app_container booted com.alpsenel.startupstudio data)/tmp/startupstudio-previews"
  ```
