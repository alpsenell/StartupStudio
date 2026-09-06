# Iteration 9 — the Life tab: the founder is a person

*Direction doc for seven lanes. Scaffold: tag `scaffold-9` on branch
`iteration-9`. Read this whole file before touching code.*

## Why

The game's pitch is "the founder is a person", and Life is mechanically the
deepest tab in it: four meters, five attributes, evenings as a currency, a
partner with affection, kids, four homes, a shop, five districts, the
networking floor, seventy life events. But nearly all of it is numbers and
menus, not people and moments:

- **Kids are a name and a birthday.** They never grow, never speak, and only
  cost money and drift. The dynasty promises "a child grown from the
  household" and iteration 8's doc admits the household traits were not built.
- **The partner has four buttons.** The seventy life events are the only
  place they feel like a person.
- **Friends are a weekend activity with nobody in it.** Several events name
  a friend who does not exist in state.
- **Possessions are a mood number in a text list.** The pixel home never
  changes when you buy something.
- **Every ending and every board is a company ending.** The biography leads
  with money. Nothing in Life is scored, shared, or chased. The tab is a cost
  centre the player manages so the company can win.

That last point is the real gap. The game never asks whether the *person*
won. This iteration makes Life the thing people screenshot and talk about.

## The rule every feature keeps

Same as iterations 5–8, and it is not negotiable:

1. **Identity at the default.** Any new balance value must read as "off" or
   1.0 at its default so the pacing bots and the pinned balance tests do
   not move. A feature the player never engages must not change a single
   number in a run that never engages it.
2. **No new draws from `rng` or `worldRNG`.** Use `state.socialRNG`, and
   only when the feature is engaged. Ids that must be deterministic are
   ordinals or derived from existing seeds, never `UUID()` in the engine.
3. **No new tests.** The owner's rule (repo `CLAUDE.md`) stands: run every
   suite as verification, extend none. Re-pin an existing expectation only
   when your feature genuinely changes what it counts (say so in your
   report, with the old and new numbers).
4. **Read the Executed line.** A filtered `xcodebuild` pipeline exits 0 on
   a compile failure. The evidence for the app suite is
   `Executed N tests, with 0 failures`; for a package it is
   `✔ Test run with N tests … passed`. Missing line = failure.
5. **Old saves load.** Every new field on state decodes as its default when
   absent. The scaffold already did this for the five `LifeState` slots and
   `Child.memories`; do the same for anything you add elsewhere.
6. **Pixel, not SF.** New surfaces are drawn in the game's hand: pixel
   paper, bitmap kickers, portraits from `PixelKit`, the existing `Theme`
   tokens. Look at `NetworkingVenueSheet`, `AgendaScreen`, the awards night
   and the Dynasty room before inventing a look. Palette rule for any new
   sprite: only colours from `Palettes.swift`; the PixelKit pixel-literal
   baseline test will tell you if you drifted.
7. **Every action shows its consequence on the button** the way the rest of
   the game does ("−1 evening", "−$400 → $2,150"), and a refused action
   says why.

## The scaffold

Committed at `scaffold-9`:

- Engine files, one per lane, that lanes own and may reshape:
  `Phone.swift` (L1), `LifeScore.swift` (L2), `Friends.swift` (L4),
  `SideProject.swift` (L5), `Sabbatical.swift` (L6), `HomeDecor.swift` (L7).
  `Child.memories` and `ChildMemory` in `Life.swift` (L3).
- `LifeState` slots: `phone`, `friends`, `sideProject`, `sabbatical`,
  `decor`, each with a default and a coding key. **Do not add fields to
  `LifeState` or `GameState`**; put everything in your own slot's type.
- Marker regions, `// MARK: L<n> (…)`, in every shared file. **Insert only
  between your own two markers**, never outside them:
  `GameAction.swift`, `Reducer.swift` (the `systems` array and the `apply`
  switch), `GameState.swift` (`EndingKind`, L2 only), `AppRouter.swift`
  (`Route` and its tab switch), `LifeScreen.swift` (cards, destinations,
  destination switch), `DebugLaunch.swift` (flags and route names),
  `GameCenterCatalog.swift` (L2 only).
- `PhoneState.post(_:from:day:fromFounder:eventID:)` is the one cross-lane
  API. L3, L4, L5 and L6 post messages through it from day one; L1 owns the
  type and keeps that signature.

## File ownership

A file is owned by exactly one lane; touch an unowned file only inside your
marker region. If you need a change in somebody else's file, write it in
your report as a follow-up, do not make it.

| Lane | Owns |
|---|---|
| L1 | `Phone.swift`, `Systems/PhoneSystem.swift`, `App/Sources/Screens/Life/Phone/**`, the HUD unread badge (`GameShell.swift` inside a marked region you add), `NarrativeSystem.swift` hooks in a marked region |
| L2 | `LifeScore.swift`, `EndingKind` + every switch over it, `App/Sources/Screens/Life/LifeScore/**`, `FounderBiographyView.swift`, `BiographyCardView.swift`, `EpilogueCopy.swift`, `PostMortem.swift`, `GameCenterCatalog.swift`, `GameCenterID`, `docs/release/game-center-ids.md`, `LegacyRun` (one field), `Legacy.swift` marked region |
| L3 | `Child`/`ChildMemory` in `Life.swift`, `Systems/LifeSystem.swift` child paths, `Systems/FamilyCalendar.swift`, `Systems/ChildhoodSystem.swift` (new), `FamilyCard.swift`, `App/Sources/Screens/Life/Children/**`, `App/Sources/Dynasty/Successors.swift`, PixelKit `HomePersonArt.swift` + `HomeTypes.swift` (`HomeOccupants.Child`), `LifeEvents.json` (append only, at the end, ids prefixed `kid_`) |
| L4 | `Friends.swift`, `Systems/FriendSystem.swift`, `App/Sources/Screens/Life/Friends/**`, `WeekendCard.swift` (the friends weekend), `Names.json` (a `friendNames` pool, append), `LifeEvents.json` (append only, at the end, ids prefixed `friend_`) — coordinate with L3: L3 appends first in merge order, so append yours after the last `kid_` entry and expect a trivial both-added merge |
| L5 | `SideProject.swift`, `Systems/SideProjectSystem.swift`, `App/Sources/Screens/Life/SideProject/**`, a `BalanceConfig+SideProject.swift` file |
| L6 | `Sabbatical.swift`, `Systems/SabbaticalSystem.swift`, `App/Sources/Screens/Life/Sabbatical/**`, `WorkScheduleCard.swift` (the "step away" entry), a `BalanceConfig+Sabbatical.swift` file |
| L7 | `HomeDecor.swift`, `HomeCard.swift`, `ShoppingSheet.swift`, `App/Sources/Screens/Life/Decor/**`, PixelKit `HomeSceneComposer.swift`, `HomeSpriteLibrary.swift`, `HomeRoomBuilder.swift`, `HomeHitRegion.swift`, `BalanceConfig` `instantLife.items` (the shop catalog), `LegacyLedger` (one field: `unlockedDecor`), `Seasons/**` reward hook in a marked region |

Shared, marker-only: `GameAction.swift`, `Reducer.swift`, `AppRouter.swift`,
`LifeScreen.swift`, `DebugLaunch.swift`, `GameState.swift`.

## The seven lanes

### L1 — The phone

**What.** A messaging surface where the founder's partner, children,
friends, contacts, ex-employees and the office text them. Everything that
today arrives as a life-event sheet also lands as a message in the right
thread, and the founder's answer lands as a reply. Threads have history the
player scrolls back through. An event whose deadline passed with no answer
is marked in the thread and stays there: *Seen. No reply.* forever.

**Build.**

- `PhoneSystem.run` (daily, in the L1 region of `systems`): mirrors what the
  narrative already does. When `NarrativeSystem` raises a `PendingChoice`
  whose source is a life event with a counterpart (partner, a child by
  `childID`, later a friend), post its headline/body as an incoming message
  in that thread with `eventID`; when the player resolves it, post the
  chosen option's label as the founder's reply; when the deadline answers
  for them, post the *Seen. No reply.* marker. Non-question life events
  (`impact` only) post one line. Add the hooks in `NarrativeSystem.swift`
  inside a region you mark `// MARK: Iteration 9 — L1`. Staff moments post
  to `.employee(id)`. The boomerang (`NetworkingSystem+Alumni`) posts to
  `.contact(id)` when somebody who left checks in. Partner affection's
  single warning posts to `.partner`. The weekly report's one-line summary
  posts to `.office` every Sunday. Use existing copy where it exists; write
  new copy in the game's voice (short, dry, specific).
- Reading a thread sets `lastReadDay`; the HUD gets an unread count badge on
  the Life tab (same style as the Team tab's badge).
- App: `PhoneCard` on the Life tab (the three newest threads, one line each,
  unread bold) → `PhoneScreen` (thread list, pixel phone frame, portraits
  from `PixelKit`) → `ThreadView` (bubbles on pixel paper; the founder's
  bubbles right-aligned; the pending question shows its options *as reply
  buttons* in the thread and dispatches the same `resolveChoice`). Deep link
  `Route.phone` and `Route.phoneThread(PhoneCounterpart)`; `-autoRoute phone`.
- Share: a thread can be exported as a 1080×1350 card (`ShareRenderer`
  pattern), because the screenshot of the partner's texts during launch
  week is the point of this lane.

**Neutral by default.** Posting is pure bookkeeping; no meter moves because
of the phone.

### L2 — A life score, a second board, and a seventh ending

**What.** `LifeScore.score` grades the founder's life 0…100 as a pure
function with a visible breakdown: partner (stage × affection), children
(count × a bond proxy until L3 lands: days since the last missed birthday),
health and energy, friends (bond sum — reads `state.life.friends`, zero
until L4 ships), evenings spent on people over the last year (from the
journal), home, and a penalty for burnouts and the chronic condition. Sits
next to net worth everywhere net worth is shown: biography, share card,
result cards, front door. Three Game Center boards (best life per
difficulty). A seventh ending, **Walked away**: the founder steps down on
purpose while both numbers are good.

**Build.**

- `LifeScore.score` + `LifeScore.breakdown(state:balance:) -> [Component]`
  (label, points, max). Weights in a `BalanceConfig+LifeScore.swift` with
  defaults; the score is display-only so nothing balances on it.
- `EndingKind.walkedAway` in the L2 marker; `isSuccess` true; update every
  exhaustive switch (`EpilogueCopy`, `PostMortem`, `GameCenterCatalog`
  details, endings achievements, the biography headline, the front door,
  `LegacyLedger.endingsReached` copy, `Successors`). Action `.walkAway` in
  the L2 region with gates you choose and document: at least a year in,
  company not in debt, no seated board (or bought out), life score at or
  above a threshold; the ending reason quotes both numbers. Refused with
  the reason on the button.
- `LegacyRun.lifeScore: Int?` (decode-if-present), so the ledger and the
  Dynasty room can show it.
- App: `LifeScoreCard` in the You section (the number, the breakdown as
  bars, the one thing that would raise it most), `Route.lifeScore` →
  `LifeScoreScreen` with the full breakdown and the *Walk away* button
  when available. Biography and `BiographyCardView` carry
  "$4.2M · Life 71". `YearGrid` text export appends `Life NN`.
- Game Center: `GameCenterID.lifeScore(difficulty)` ×3 plus the
  `walkedAway` achievement; extend `docs/release/game-center-ids.md`;
  `GameCenterDailyTests` pins the id strings, so re-pin its counts (say so).

### L3 — Children who grow up, and remember

**What.** Kids age on real days through **baby → toddler → school → teen →
grown**, each with its own sprite size in the pixel home and its own way of
claiming evenings. Each child keeps a memory ledger of what they saw. A
teen with a strong bond can intern at the studio for a summer. Memories
become traits when the child founds the next company in the dynasty.

**Build.**

- `Child.stage` computed from `bornDay` and `state.day` with thresholds in
  `BalanceConfig` (`childStageDays`): kids in this game grow fast, a child
  born in the garage is a teenager by the campus. Suggested defaults: baby
  to day 180, toddler to 540, school to 1100, teen to 1800, then grown.
  Say the convention in copy ("kids grow up faster than companies").
- `Child.bond: Double` (add it to the `Child` Codable you own, decode as a
  default), grown by `familyTime`, birthdays kept, an evening with the kid
  (`.spendTimeWithChild(childID)` in the L3 action region; one evening,
  stage-appropriate vignette copy), decayed by silence. Existing events
  `kid_*` and `recital_vs_dinner`, `school_run`, `kid_sick_night` now name
  the child and move bond.
- **The memory ledger.** `ChildhoodSystem.run` (L3 region of `systems`)
  watches the day's events and appends a `ChildMemory` to every child old
  enough to notice (toddler and up): a launch reviewed at 75+, an award
  won, a burnout / hospital stay, an eviction, a missed birthday (the
  `kid_after_missed_birthday` flag), an IPO or acquisition, a sabbatical
  (reads `state.life.sabbatical`), a friend's wedding attended. Cap at
  twelve, oldest dropped. Every memory also posts one line to the child's
  phone thread via `PhoneState.post`.
- **The intern.** Teen with bond ≥ 60, summer only (the calendar knows
  months): `.hireChildIntern(childID)` puts a temporary `Employee` on the
  roster for eight weeks with a small skill sheet, no salary, and a bond
  bump; a memory either way. Leaving before the eight weeks costs bond.
- **Dynasty.** `LegacyChild` gains `memories` and `bond`; `Successors.swift`
  maps memory kinds to the successor's traits (two burnouts → Grumbler,
  launch parties → Speedster, an intern summer → Mentor) and skill spread.
  This is the "household-grown traits" that iteration 8 left undone.
- PixelKit: `HomeOccupants.Child.stage` and `HomePersonArt` draws four
  sizes; a teen has a desk in the house / penthouse. Respect the palette.
- App: `FamilyCard` shows each child with stage, bond and their last two
  memories; `ChildSheet` shows the full ledger with the day each happened,
  and the evening / intern actions.

### L4 — Friends with names

**What.** Three named friends from before the company, generated at the
first day the feature touches (`socialRNG`, once), each with an archetype,
a face, a bond that decays like an employee's, and a life of their own:
they marry, start companies, burn out, move away. A friend can become your
first angel, your first hire, or the one who talks you out of the buyout.

**Build.**

- Archetypes: *the uni friend* (an engineer, will eventually be hireable),
  *the ex-colleague* (an operator, will start a company you can invest in
  from your wallet using the existing `Holding` machinery), *the neighbour*
  (a civilian, keeps you sane: the biggest relationships-meter lever).
  Generate lazily on day 1 in `FriendSystem.run` from a `friendNames` pool
  in `Names.json`; decode-if-present makes an old save meet them the day
  it loads.
- Actions (L4 region): `.callFriend(id)` (free, small bond, one per week),
  `.seeFriend(id)` (one evening, bond + relationships, a vignette), and
  offers gated on bond: `.hireFriend(id)` (creates a `Candidate` with the
  bond pre-set, then the normal hire), `.investInFriend(id, amount)`
  (wallet → `Holding`), `.borrowFromFriend(id, amount)` (a personal loan,
  no interest, bond bleeds if unpaid past 26 weeks; `.repayFriend`).
- The `.friends` weekend now picks the friend you have seen least and
  moves their bond.
- Friend life beats as life events appended to `LifeEvents.json` with ids
  `friend_*`: the wedding (an evening claimed, a memory for L3's kids if
  attended), the company they started (opens the invest offer), the
  burnout (a call that costs an evening or a bond), moving away (bond
  frozen; the phone thread stays). The lonely-holiday event now names who
  is not there.
- **The buyout.** When a buyout is pending and a friend's bond is ≥ 70,
  they post to their phone thread with an opinion drawn from their
  archetype. Text only, no numbers move.
- Neutral: friends' bond decay has no company effect. A friend with a low
  bond simply stops texting.
- App: `FriendsCard` under Family (three portraits, bond as a small bar, the
  last thing they said) → `FriendSheet` (the vignette scene from
  `ActivityScenes` reused, the actions, the offers). Every message goes
  through `PhoneState.post(… from: .friend(id))`.

### L5 — A side project that is yours

**What.** The founder builds something that is not the company: a
**novel**, a **band**, a **marathon**, a **weekend app**, a **restaurant**.
Five tracks, four chapters each, each chapter a milestone that takes
evenings and pays out as press, cash into the wallet, or a perk, and each
finished track a line in the biography. The founder who finished the novel
has a reason to walk away.

**Build.**

- `SideProjectState` grows: `track`, `chapter`, `progress`, `completedTracks:
  [String]`, `lastSessionDay`. Catalog in `BalanceConfig+SideProject.swift`:
  per track the attribute that drives progress (novel: conversation; band:
  conversation + leadership; marathon: health; weekend app: technical;
  restaurant: market sense + finance), sessions per chapter, wallet cost per
  session, the payout per chapter (reputation / wallet / a `Perk` id / a
  meter). One project at a time; abandoning keeps nothing.
- Actions (L5 region): `.startSideProject(track)`, `.workOnSideProject`
  (one evening, progress = base × attribute curve, a mood pop), `.abandonSideProject`.
- `SideProjectSystem.run`: the marathon's progress also moves with the gym
  streak; the restaurant's last chapter can lose money; the weekend app's
  last chapter ships a tiny product-shaped payout (a lump into the wallet,
  a press line) without touching `products`. Chapter completions post to
  `.office` on the phone (the trade press noticed) and to `.partner` (they
  noticed too).
- Biography line per completed track, appended in a region you mark in
  `FounderBiographyView` (coordinate: L2 owns that file, so your edit is a
  single call to a function you define, inside `// MARK: L5` markers).
- App: `SideProjectCard` in the You section (track art from `PixelKit`
  drawn as a small vignette, the chapter, the next session's cost) →
  `SideProjectSheet` (pick a track, the four chapters as a strip, what
  each pays). `-autoRoute sideproject`.

### L6 — The sabbatical

**What.** Hand the company to your best employee as caretaker, go away for
four to twelve weeks, and watch it from the phone. Health, energy and
affection recover fast; the company runs on the caretaker's traits; you come
back to a sheet that says what they did.

**Build.**

- Gates for `.startSabbatical(caretakerID, weeks)`: an employee with ≥ 26
  weeks' tenure and bond ≥ 50, no build shipping in the next fortnight, a
  wallet that can cover the weeks (a per-week cost, default in balance).
  `.endSabbaticalEarly` costs bond with the caretaker.
- Reuse `awayUntilDay` / `awayReason` so the office and home scenes already
  show the founder gone; founder output is zero while away.
- `SabbaticalSystem.run`: the caretaker's autopilot, driven by their
  revealed traits and role: a Speedster starts the next build and ships
  early; a Mentor trains; a Grumbler lets morale slide; a Flight Risk might
  be poached mid-sabbatical (the run-ending version of "what happened while
  you were gone"). Every autopilot decision is a normal `GameAction` applied
  through `Reducer.apply`, so the ledger and the journal record it as if
  the founder did it, tagged with the caretaker's name. One decision a week
  at most; deterministic from `socialRNG`. A daily one-liner posts to
  `.office` on the phone. Board patience halves while the founder is away;
  rivals' poach odds rise.
- On return: a `SabbaticalReport` (what they started, shipped, hired, lost;
  cash then and now; morale then and now) shown as a pixel-paper sheet the
  way the weekly report is, and stored on the state so the biography can
  quote it.
- Neutral: with no sabbatical, nothing runs.
- App: `SabbaticalCard` in the You section (eligible caretakers, weeks
  slider, the cost, what is at risk) and the "step away" entry on
  `WorkScheduleCard`; while away, the card is the countdown and the log.
  `-autoRoute sabbatical`.

### L7 — Furnish the home

**What.** Possessions become objects placed in the pixel home rather than a
text list, plus a small collection of decor to earn from seasons and
endings. The home finally changes when you buy something.

**Build.**

- Slots per home tier in `HomeDecor.swift` (a studio has three, a penthouse
  twelve) with a pixel anchor each in `HomeRoomBuilder`. Every existing shop
  item gets a sprite and a set of slots it fits; new decor ids (a poster
  from each season, a trophy from each ending, the plant, the record
  player) are unlocked in `LegacyLedger.unlockedDecor` and are free to
  place. Moving home keeps the items and empties the slots.
- `HomeSceneComposer` reads `HomeDecorState` and draws the sprites; a tap on
  a slot (extend `HomeHitRegion`) opens the furnish sheet at that slot. New
  sprites in `HomeSpriteLibrary`, palette-only.
- Actions (L7 region): `.placeDecor(slot, itemID)`, `.removeDecor(slot)`.
  Buying an item that fits an empty slot places it automatically. Prestige
  and mood keep their existing values; decor is cosmetic beyond them
  (identity at default).
- Season and ending rewards: `Seasons/**` and the ending flow add an id to
  `unlockedDecor` in regions you mark; the awards night's pennant becomes a
  wall item.
- App: `FurnishSheet` (the home scene with tappable slots, a shelf of owned
  items, "earned from" captions), `HomeCard` gets a *Furnish* button,
  `ShoppingSheet` shows where an item would go. `-autoRoute furnish`.

## Working method

- **Worktree per lane**, branch `l<n>-<name>` checked out from `scaffold-9`
  (`git checkout -B l1-phone scaffold-9`). Never build or test in the main
  checkout.
- **Simulator per lane:** `ws-l1` … `ws-l7`, already cloned. Build with
  `xcodebuild -project StartupStudio.xcodeproj -scheme StartupStudio
  -destination 'platform=iOS Simulator,name=ws-l<n>' build` after
  `make gen` in your worktree (the project is generated and gitignored).
  Install and launch with `-autoSpeed x4 -autoTab life` plus your own
  `-autoRoute`; screenshot with `xcrun simctl io <udid> screenshot`.
- **Verify before you report:** engine, content, save and PixelKit suites
  (`swift test` in each package you touched, plus TycoonEngine always) and
  `make apptest`. Paste the summary lines into your report.
- **Report** as `docs/product/iteration-9-lanes/l<n>.md`: what you built,
  deviations from this doc and why, the numbers you chose, the suites'
  summary lines, screenshots' paths, follow-ups for other lanes' files.
- **Commit on your branch** with a conventional message; do not merge, do
  not push. The PM merges in the order L1 → L2 → L3 → L4 → L7 → L5 → L6.

## What "done" looks like

A player opens Life and sees their partner's last text under the week, a
child who is now at school and remembers the launch, three friends with
faces, a number for their life next to the number for their company, a
side project two chapters in, a way to step away for a summer, and a home
with their things in it. And every one of those makes a screenshot somebody
would post.
