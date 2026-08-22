# Startup Studio

A Game Dev Tycoon-style software-company tycoon game for iPhone. You run a
tiny startup: watch your cash, manage your burn rate, and ship products
before the money runs out. Built with SwiftUI on a deterministic simulation
engine, with a pixel-art office scene as the game's face.

## Features

Five tabs over the persistent cash/date/speed HUD:

- **HQ** — the animated pixel office scene (upgradeable from garage to
  campus), company overview, burn rate and runway, the product in
  development, office upgrades, and the activity feed
- **Life** — the founder's personal life: the pixel home scene (studio
  flat to penthouse), energy/health/mood/relationship meters, work
  schedule (chill/normal/crunch), founder salary and wallet, weekend plans,
  and family — dating, moving in, marriage, and kids
- **Team** — roster with skills, salaries, and assignments; hiring from a
  rotating candidate pool; swipe-to-fire
- **Products** — two segments: *Products* builds products phase by phase
  (design/code/polish), tunes the phase focus, squashes bugs, ships, and
  watches reviews and sales roll in; *R&D* is the tech tree — bank research
  points and unlock technologies
- **Business** — client contracts with deadlines, marketing campaigns, and
  the company finance ledger

Plus autosave with versioned migrations, game over on bankruptcy, and a
deterministic engine (same seed, same game) under it all.

## Layout

- `App/` — the SwiftUI app shell (HUD, tabs, screens, theme)
- `Packages/TycoonEngine` — the simulation engine (Swift package)
- `Packages/TycoonContent` — game content/data (Swift package)
- `Packages/TycoonSave` — save/load with versioned migrations (Swift package)
- `Packages/PixelKit` — the pixel-art office scene renderer (Swift package)
- `Packages/IconGen` — macOS dev tool that renders the app icon from
  PixelKit sprites (not part of the app)

## Requirements

- Xcode 26+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)

## Commands

```sh
make gen    # generate StartupStudio.xcodeproj from project.yml
make test   # run the TycoonEngine, TycoonContent, TycoonSave, and PixelKit package tests
make build  # build the app for the iPhone 17 simulator
make icon   # regenerate the app icon (AppIcon.png) from PixelKit sprites
make clean  # remove build artifacts and the generated project
```

## Playing the dev build

Build and install on a simulator from the command line:

```sh
make build
xcrun simctl boot "iPhone 17" || true   # no-op if already booted
open -a Simulator
xcrun simctl install booted build/Build/Products/Debug-iphonesimulator/StartupStudio.app
xcrun simctl launch booted com.alpsenel.startupstudio
```

For hands-off checks, the debug build accepts an `-autoSpeed` launch
argument that starts the simulation running immediately (values: `x1`,
`x2`, `x4`):

```sh
xcrun simctl launch booted com.alpsenel.startupstudio -autoSpeed x4
```

## Notes

- `StartupStudio.xcodeproj` is **generated** and gitignored — never edit it
  by hand. `project.yml` is the source of truth.
- Re-run `xcodegen generate` (or `make gen`) after adding, removing, or
  moving files.
- The app icon is generated art: `make icon` re-renders
  `App/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png` from the
  game's own sprites via `Packages/IconGen`.
