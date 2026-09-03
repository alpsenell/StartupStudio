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
  penthouse), energy/health/mood/relationship meters, your own five
  attributes and the training that raises them, work schedule and work
  pace, founder salary and wallet, weekend plans and thirteen illustrated
  activity vignettes, shopping, the networking floor and address book, the
  city map (five districts to relocate to, and an office you can rent, buy
  or sell), and family — dating, moving in, marriage and kids
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

- **Chapters and goals.** Forty-two goals across five chapters, six live
  at a time; finish enough of a chapter and the next one opens. From
  chapter 3 there are two ladders — *funded* and *independent* — and the
  cap table picks yours. Each goal pays
  reputation, cash, or a permanent perk — press contacts, a talent magnet,
  an investor rolodex, veteran crew, market darling.
- **A world with opinions.** 83 company events and 70 life events, most of
  them a real question with consequences spelled out on the buttons and a
  deadline that answers for you if you don't; choices schedule follow-ups
  weeks later, so a decision has a second act. 44 industry headlines, 11
  staff moments (a raise request, a rumour a rival is circling, a
  complaint that has to be handled properly), and per-outlet review voices.
- **Work pace and resignations.** Relaxed, normal or crunch, each trading
  output against morale and bugs. An unhappy employee does not vanish: they
  hand in notice and keep working, and a real raise or a promotion inside
  the notice period still turns it around.
- **One founder, one week.** Your work schedule buys output and spends
  *evenings*: five a week on chill, three on normal, one on crunch. Every
  personal thing you do — a course, a date, a night out with someone on the
  team, an afternoon teaching them something, an hour at the gym — spends
  one. Company gestures (a coffee, a gift, the team dinner) stay free,
  because those are the company's time and money. So crunch finally costs
  something that isn't another meter: the one evening you have goes to the
  coach, or the partner whose affection is sliding, or the new hire a rival
  has been taking to lunch.
- **The two crunches can see each other.** The company has a work pace and
  you have a work schedule, and they now sit on the same card. While the
  team is crunching, being on chill costs the room morale and normal costs
  half of it — you can put everyone on crunch from a deckchair, and the car
  park will tell them. Your own mood reaches them too, but only downward: a
  founder falling apart drags the room, and a cheerful one buys nothing.
- **A salary the room can read.** Pay yourself more than 1.5× your team's
  median and morale slides on a slope, and a seated board adds it to the
  quarterly pressure. The band moves with the roster, so a garage founder
  on a grand a week is fine and a fourteen-person studio founder on the
  same is invisible. A salary the *company* raised to stop you being
  evicted is exempt — the team resents a founder who helped themselves,
  not one who had to be bailed out.
- **The house is collateral.** The bank lends about half its ceiling on the
  company's name; the rest needs your signature and your home behind it. A
  studio flat secures nothing, a penthouse secures a great deal. Stay in
  the red with guaranteed debt outstanding and they take your savings, and
  then the house — one tier down, the same way an eviction does. The home
  ladder is no longer a mood bonus you buy once.
- **You are a character sheet.** Five attributes — conversation,
  technical, market sense, leadership, finance — each with exactly one job:
  your own build output and bug rate, the sales a release finds, the morale
  your team settles at, what a delivered contract actually pays, and how
  far a conversation gets. Train them with an evening's reading, an online
  course or a private coach; the closer to 100, the less each session adds.
  They also grow quietly from doing the thing.
- **The networking floor.** Plan a networking weekend and you walk into a
  room — a co-working mixer, a rooftop party, a demo day — with three to
  five people standing in it, drawn rather than listed. You get a handful
  of exchanges: small talk is safe, talking shop is graded on what you
  actually know, listening is how you learn what somebody wants, and
  pitching a stranger costs you. Warm somebody up and the deals open, in
  both directions: hire them for salary; give away a slice of your own
  company to get somebody who would never take the salary; buy a stake in
  *their* startup out of your own wallet and hold it until it exits or
  folds; take their cheque into yours; or, if you are single and the
  evening went unusually well, stop talking about work. Contacts persist —
  rapport fades if you never call.
- **People, not payroll.** Every hire has a bond with *you*, separate from
  how they feel about the job — grown by your own time and money (an
  evening out, an afternoon teaching them something) rather than the
  company's, decayed by being ignored, and worth output, morale and staying
  put when a rival calls. A partner has affection, which only your own
  time moves: it slides every day, faster once a fortnight has passed with
  no contact, and you get exactly one warning before it ends things.
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
  quarter; miss it enough and they replace you. Six endings — bankruptcy,
  sold up, acquisition, IPO, ousted, and *Still yours* — and all six land
  on the same founder biography: the chapters and the day each opened, the best thing you
  shipped with its best review quoted, your longest-serving employee, your
  family, and the money.
- **The weekly report.** An end-of-week debrief — cash in and out by
  category, per-product sales with sparklines, morale and its direction,
  your own meters, what happened, and what is due next week. It opens
  itself for the first eight weeks and can be told not to, from the report
  itself.
- **One top band.** Under the HUD sits a single notice rail: the reason
  the clock stopped, a story question you put off and its real countdown,
  the unread weekly report, the newest thing that happened, or a coach
  tip — one line at a time, by priority, with a "+N" that opens the
  journal and a swipe to cycle. The HUD carries runway under the date, a
  dot on the speed control when something needs you, and a cash figure
  that rolls; tapping it opens the money sheet (company, bank, you).
- **Every tab lands on the next thing.** HQ opens on a Now card — the
  build in flight and the goal you are closest to, with its action as a
  button — then the office. Life opens on your week: evenings as pips,
  your schedule and the team's pace side by side, the weekend plan, and
  what a day of you is worth. Business opens on the desk: every contract,
  term sheet, campaign, boom, crash, price war, loan and board with a
  clock on it, most urgent first, and a grid of six sections with badges.
  Products on day 0 shows the catalog and what today's crew could review
  as; Team says what each person needs this week and badges the tab.
- **Decisions with the numbers, in the game's hand.** Every option with a
  cash effect shows the company afterwards ("−$2,300 → $9,250 · runway 8
  wk"); story questions can be put off with "Let me think" and go to the
  rail with their deadline; the sheet is drawn on pixel paper with the
  asker's portrait and a bitmap kicker.
- **The office reads the game.** Crunch pins the room to night with a
  pizza box on the founder's desk; a short runway lands an envelope pile;
  debt puts the note on the coffee machine; a buggy build spawns bug
  bubbles over the coders; somebody about to leave has a flattened box
  under their desk; a buyout on the table stands a courier at the door.
  The home reads the meters the same way. Reduce Motion seats everyone.
- **The maths, before and after.** The new-product flow says what today's
  crew could review as before you commit, launch day says why the score
  was what it was with the fix one tap away, and the focus editor offers
  "Match the work". A failed ending gets a post-mortem — three facts with
  numbers — and every ending offers the same year again on the same seed.
- **Coaching without nagging.** Six dismissable coach tips keyed to the
  goals you actually have, a weekly report that leads with "Do this next"
  and stops opening itself once you have opened it twice yourself, a
  searchable journal that collapses routine weeks, and chiptune sound and
  haptics (both synthesized in-app, both switchable).

### The world answers back

Iteration 5 gave the game a memory and a temper: a player's move has an
answer in the world, and an answer has a memory.

- **The category fight.** Standing in a topic holds your share there. A
  rival launching into a category you hold stops the clock: six weeks to
  cut the price, patch, campaign, or let it go — and a real consequence
  either way. Out-sell a rival for long enough and it bleeds, then folds.
- **The incumbent.** Once the company is worth having, a deep-pocketed
  giant founds into your two best markets and opens with a challenge. Hold
  both for half a year and it retreats; buy it and its shelf is yours.
  Buying any rival now absorbs the product that was beating you.
- **Exit terms.** A distress bid is *Sold up*, not a win. A strategic
  offer is cash today, or an earn-out: 60% now and the rest over two
  quarterly reviews with the acquirer seated as the least patient board in
  the game.
- **Buy back the board.** Pay a seated round out — cheapest when you are
  small and broke, dearest the moment you can afford it — and its ask
  leaves the room.
- **Rival-sponsored contracts.** A rival pays 1.8× for a white-label job
  and, on delivery, ships what you built into the category it names —
  possibly the one you hold. Sandbagging is allowed and costs pay,
  reputation and standing.
- **The answer becomes the policy.** A supportive answer to a staff moment
  becomes the rule for the next person, who no longer asks; reverse it and
  everyone hears. Ten second acts ride the flags the first answers set.
- **The date in the diary.** Anniversaries and birthdays land on real
  days and claim the week's evenings; on crunch that is one. Miss one and
  they notice — and bring it up next year.
- **The boomerang.** People who leave — quit, fired, poached — go into the
  address book with the bond they had, keep getting better elsewhere, and
  can be hired back senior. Fire a friend and you burn the contact.
- **Two ladders and a fifth ending.** Stay at 100% and the late chapters
  ask for a company that lasts; eight profitable quarters in a row and the
  founder can declare it built — *Still yours*.
- **Origins.** Four ways to found the company on the Stakes page: alone in
  a garage; co-founded, with a partner who owns 30% forever; a spin-out
  with a client, a deadline and a year's non-compete; or mortgaged, a year
  of runway borrowed against the flat you live in.

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

  The App target renders its own chrome the same way — the HUD, the notice
  rail, the decision sheet, the weekly report's bottom bar, launch day, the box-art
  sheet and the bitmap font, each in light and dark. Those run inside the
  simulator, where `PIXELKIT_PREVIEW_DIR` from the host does not reach
  them, so they land in the app's own temporary directory:

  ```sh
  make apptest
  open "$(xcrun simctl get_app_container booted com.alpsenel.startupstudio data)/tmp/startupstudio-previews"
  ```
