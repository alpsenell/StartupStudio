# Iteration 6 — new surfaces

*3 September 2026, evening. Ten new screens and interaction layers, chosen for what they change about how the game looks to a new player. Not polish: every item here is a place the game did not have.*

## Why these

Iteration 4 made the existing screens read well; iteration 5 gave the world a memory. What the game still lacks is *pull*: the moments people remember happen inside sheets, the systems with the most state (standing, rivals, the diary, bonds) have no picture, and the front door is an onboarding form. Each surface below draws something the engine already knows and gives one of those moments a room of its own.

## The ten, and the seven lanes that build them

| # | Surface | Lane | Route | Lives in |
|---|---|---|---|---|
| 1 | Launch week war room | U1 | `.warRoom` | Products (from the build card and the Now card, last 7 days before a ship and launch day) |
| 2 | The weekly newspaper | U2 | `.newspaper` | HQ (Monday's rail line and the journal card open it) |
| 3 | Company timeline | U2 | `.timeline` | HQ (the chapter card opens it) |
| 4 | Market map | U3 | `.marketMap` | Business → Market (a segment beside the report) |
| 5 | Rival profiles | U3 | `.rivalProfile(rivalID:)` | Business → Rivals (tap a rival) |
| 6 | The office as the interface | U4 | — | HQ's office scene |
| 7 | The agenda | U5 | `.agenda` | Life (above "Your week") |
| 8 | Org chart | U5 | `.orgChart` | Team (a toolbar toggle beside the roster) |
| 9 | The storefront | U6 | `.storefront(productID:)` | Products (from the product detail screen) |
| 10 | Title screen with save slots | U7 | — | The app root, before onboarding |

### U1 — Launch week war room

A full-screen mode for the last seven days before a build ships and for launch day. The office scene with the crew at their desks and the pressure the build is under; a countdown in the game's numeric face; the hype meter and the campaigns feeding it; the forecast the ship sheet already computes (`ShipForecast`, `LaunchForecast`) as a live band; press mentions rolling in (drawn from `News.json` and the reviews' outlets); the whiteboard with the phase progress; and on launch day the review reveal, one outlet at a time, which `LaunchDaySheet` already does and this screen absorbs. Entered from the build card on Products and from the Now card, automatically offered (not forced) when a build is inside seven days of its ETA. Sound and haptics on the reveal through the existing `Sounds`/`Haptics`. The clock keeps running in the room; the speed control is on screen.

### U2 — The weekly newspaper, and the company timeline

*Newspaper.* Every Monday a front page: masthead with the game date, the lead story about the company (the week's biggest event, chosen from the journal by severity), a rival column from the rival events, the market column from booms/crashes and the forecast, a "photo" that is one frame of the office scene, and a small-print strip of the quiet events. Composed app-side by a `NewspaperComposer` from `eventLog`, `News.json`, `market`, `rivals`; deterministic for a given state. Drawn in the pixel language: `Theme.pixelPaper`/`pixelInk`, `PixelText` for headlines, hairline rules. The rail's report line and the journal card open it; the last four issues are browsable.

*Timeline.* A horizontal, scrollable pixel timeline of the run: products as their box art at launch day, hires as portraits at hire day, chapters as flags, the crash, the round, the incumbent. Built from `chapterLog`, `eventLog` and the products. Pinch or segment to zoom between quarters and the whole run. Opened from the chapter card on HQ.

### U3 — Market map, and rival profiles

*Map.* The twelve topics as districts on a pixel map, each sized by market size and coloured by the player's standing, with the player's live products as buildings, rival flags where rivals sell, the incumbent as a fortress, an active challenge as a siege marker, and the forecast as weather over the district. Tap a district for the topic detail that exists. A `MarketMapView` in PixelKit (Canvas), data from `market`, `rivals`, standing, `ShipForecast`.

*Profiles.* Tap a rival: a `RivalStudioScene` in PixelKit (a building sized by strength, lit by reputation, with the incumbent's fortress variant), their shelf, a strength sparkline from a small history the engine keeps (append-only, decodes empty), and the history between you compiled from `eventLog`: poaches, wars, challenges held or lost, buyouts offered, sponsored jobs. The buyout and acquisition actions that exist live at the bottom.

### U4 — The office as the interface

`PixelSceneView` already has a tap gesture. Give `OfficeSceneView` hit regions: each person (by employee id), the coffee machine, the whiteboard, the door, the founder's desk. The app wires them: a person opens their manage sheet, the coffee machine offers the team coffee (`.grabCoffee` / `.teamDinner` menu), the whiteboard opens the product in development, the door opens hiring, the founder's desk opens the work schedule. A press highlight in the scene (an outline or a bob) so the scene reads as tappable; Reduce Motion leaves the outline and drops the bob. VoiceOver labels on the regions.

### U5 — The agenda, and the org chart

*Agenda.* A fourteen-day calendar on Life: contract deadlines, the next board review, the earn-out review, the build's ETA from the forecast, the diary's dated beats (`narrative.scheduled` with `source: .life`), a challenge's settlement day, the rent, the loan's interest, and the week's evenings left as pips per day. Rows route to their screens. A pure app-side query over state; add engine query helpers only where none exist.

*Org chart.* A tree of the company on Team: founder at the top, departments as branches, seniority as rank, portraits as nodes, bonds with the founder as line weight, friendships as dotted lines between peers. Tap a node for the manage sheet. Grows with headcount; scrolls both ways; the roster's toolbar toggles between list and chart.

### U6 — The storefront

A product's app-store style page: box art (`ProductBoxArt`), a screenshot strip drawn from the product's type and topic in pixel, star rating from the average review score, the reviews as cards with outlet and quote, the price tier as the buy button (which routes to the price change that exists), subscribers or units this week, the update history. Opened from the product detail screen; deep-linkable by route.

### U7 — Title screen with save slots

A front door before onboarding: the office scene at night (`OfficeSceneView(timeOfDay: .night)`), the company name and the founder's portrait when a save exists, *Continue*, *New company*, and three slots. `TycoonSave` grows from one slot to three: `slotN.json` with the same envelope, rotation and migration as today, `slot0.json` staying exactly where it is so every existing save loads; a slot list API with company name, day, ending for the picker. `GameSession` gains the current slot; every new-game path clears only its slot. This also unblocks iteration 5's wave-2 Legacy feature.

## Visual language for the new screens

- **Pixel chrome for the game layer, system chrome for controls.** Panels, headlines and numbers in the game's own hand (`PixelPanel`, `PixelText`, `Theme.pixelInk/pixelPaper/pixelAccent`); toolbars, pickers and buttons in SwiftUI's. Money through `.money` and every number through `Theme.gameLocale` (the source guard in `MoneySnapshotTests` fails the build otherwise).
- **Faces, not names.** Any row naming a person, rival, investor or contact carries their `PixelPortrait`.
- **Cards and spacing.** `CardView`, `Theme.Spacing`, `Theme.cornerRadius`; both themes; Dynamic Type through the accessibility sizes; `Theme.Motion` for every animation, and Reduce Motion honoured.
- **Scenes.** PixelKit draws; the app composes. New scene types go in PixelKit with their own PNG preview test (`PIXELKIT_PREVIEW_DIR`) and a palette test.
- **Snapshots.** Every new screen ships an `ImageRenderer` snapshot, light and dark, in `App/Tests/StartupStudioTests` following `HQSnapshotTests` — render the content view, not a `ScrollView`, or the PNG is blank.

## Rules

1. **The engine's balance does not move.** No change to any number a bot can feel; `BalanceTargetsTests` and `InvestorTargetsTests` byte-identical. Engine additions are pure queries or append-only history that decodes empty; no new RNG draws.
2. **Saves decode.** New fields optional or defaulted; the slots lane keeps `slot0.json` loading unchanged.
3. **Own your files.** New screens in their own folder under `App/Sources/Screens/`; the tab root that consumes your route is the one place you touch a shared screen, and the diff there is the `router.take` and the presentation.
4. **Verify before you claim.** `make build`; the app suite on your own simulator, reading the `Executed N tests, with 0 failures` line (a grep-filtered pipeline exits 0 on a compile failure); `swift test` in any package you touch, reading the `✔ Test run with N tests` line; a real screenshot of the screen on your simulator via `-autoTab` where it can be reached without a tap.

## Merge order

**U7 → U4 → U1 → U6 → U3 → U5 → U2.** The front door first (it touches the app root), then the scene lanes, then the screens that only add files.

## Status (4 September)

Seven lanes in worktrees: U1, U2, U3, U4, U7 on Fable; U5, U6 on Opus. Merged onto `iteration-6` as they landed (U7 → U1 → U2 → U4 → U5 → U6 → U3), the app suite and the touched package suites re-run after each. Deviations as each lane reported them:

- **U7 — front door and slots.** The slot rows are the picker (tap an empty row to found there; *New company* takes the first empty slot or asks which to replace); the biography reaches the door through a session environment value; Settings' "Start a new game" returns to the door. Fixed a latent bug: backgrounding during onboarding wrote a generated company to slot 0 and skipped onboarding next launch. TycoonSave 9 → 21 tests; `slot0.json`'s envelope keys are asserted unchanged.
- **U1 — war room.** The engine had no "days to done", so a pure query `GameState.buildETA` was added (two privates in `EmployeeSystem` opened). The Ship button lives in the room, since shipping is a player action; the room suppresses the root launch-day sheet for its own product; `ReviewCardView` stops typing under Reduce Motion; the room composes its own scene rather than refactoring `OfficeCard`. `-autoRoute warRoom|launchDay|shipInRoom`.
- **U2 — newspaper and timeline.** Added `-autoAnswer` so a headless pass survives its story prompts (every lane's screenshot pass hits the first modal within seconds). Crash markers filtered to topics the studio sells into; refresh notices never lead; newsprint dark tokens are local (the pixel-paper token goes dark, the brief asked for dimmed paper). Noted, not changed: `ProductBoxArt` keys on `"mobile"`/`"web"` while type ids are `mobile_app`/`web_app`.
- **U4 — office as the interface.** Hit regions come from the director's own placement (figures over furniture over floor); only the garage draws a door, so other tiers get a doormat region; the founder's desk opens the work schedule (the manage sheet excludes the founder); the coffee menu and the whiteboard open sheets rather than routing away. Fixed a latent bug: the old tap hit-tested walking plans under Reduce Motion. PixelKit 274 → 297.
- **U5 — agenda and org chart.** Also needed a "when" query and added `GameState.shipETA` — a second ETA beside U1's `buildETA`; consolidating them is a wave-2 cleanup. `officeWeeklyRent` made public (three call sites re-derived it). The Team toggle is a segmented picker under the HUD (that tab hides its navigation bar); the agenda carries every dated desk row; the card omits evening pips because "Your week" beneath it owns them; the chart tolerates a founderless company and draws inside a two-way scroll view with offsets, since `.position` rendered nothing on device.

Cross-lane fixes at merge: U1 and U2 both declared a `launchRoute` accessor (HQ's typed one is now `launchStoryRoute`); the Xcode project must be regenerated after every merge that adds files.
