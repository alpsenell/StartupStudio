# Iteration 4 — workstreams

The build plan for `docs/product/iteration-4-ux-ideas.md`. Seven workstreams
run in parallel from the `scaffold-4` tag on branch `iteration-4`, each in its
own worktree and on its own simulator; an integrator merges them in the order
at the end. A second wave (money, idea 6) runs after the merge because it
touches thirty-six files across every other workstream.

The spec for every item is the direction doc's wording. Where it is
ambiguous, pick the option that reads best on the phone and say so in the
final report.

## What the scaffold already did

- `Route.newProduct(topicID:)` (`AppRouter.swift`), handled in
  `ProductsScreen.consumeRoute` by presenting `NewProductFlow(engine:initialTopicID:)`.
  Any screen can now say `router.go(.newProduct(topicID: nil))`.
- `AssignmentMenu` moved from `TeamScreen` to `Components/AssignmentMenu.swift`
  and made non-private, so a contract card or the lab can reuse it.
- `Components/EveningPips.swift`: the evening budget as pips. Any sheet that
  spends an evening drops `EveningPips(engine:)` above its buttons.
- `GameShell.deferredChoiceID` and `recallDeferredChoice()`: the seam between
  the decision sheet's "Let me think" (WS-D) and the notice rail's countdown
  (WS-A).
- `Theme.gameLocale`: unused until wave 2.

## Ground rules for every workstream

1. Work only in your worktree. Never run a build or a test in
   `/Users/alp/Desktop/Personal-Projects/StartupStudio` itself. Never
   `git checkout` another branch, never merge, rebase or push.
2. Edit only the files you own, plus the seams listed for you, and only in
   the way the seam describes. If you must touch something else, keep it to a
   few lines and list it in your final report.
3. Do not edit `Balance.json` or any balance default. Nothing in this
   iteration changes pacing; `BalanceTargetsTests` must stay green untouched.
4. Definition of done, in this order:
   - Every bullet in your brief, to the doc's wording.
   - `make gen && make build` succeeds with no new warnings.
   - `make apptest` passes (XCTest: `** TEST SUCCEEDED **`).
   - For any package you touched: `cd Packages/<X> && swift test` passes
     (Swift Testing: `✔ Test run with N tests … passed`; ignore the XCTest
     "Executed 0 tests" line above it).
   - New chrome gets a snapshot in the App target's preview tests
     (`PixelChromeTests` pattern; put yours in a new test file named for your
     workstream so two branches never edit one test file) and, for PixelKit,
     a preview PNG in the package tests.
   - A screenshot pass on your simulator: boot it, install your build
     (`build/Build/Products/Debug-iphonesimulator/StartupStudio.app` in your
     worktree), launch with `-autoTab <tab>` (and `-autoSpeed x4` for motion),
     screenshot, look at the PNG with the Read tool, and iterate until it
     reads well in light and dark (`xcrun simctl ui <UDID> appearance dark`).
     Nobody can tap the simulator, so sheets and flows are verified by
     snapshot test and code; say so in the report.
   - Shut your simulator down when you finish (`xcrun simctl shutdown <UDID>`).
5. Commit on your branch in small commits in the repo's style: a `feat:`,
   `fix:` or `polish:` subject in lower case that says what the player gets,
   a body that says why, and the trailers
   `Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>` and
   `Claude-Session: https://claude.ai/code/session_01GDZEw9ngPDpxXQfdTNrGea`.
6. Final report (your last message): what shipped mapped to the doc's items;
   what did not and why; tests run with counts; screenshot paths; every file
   touched outside your ownership; seams the integrator should watch.
7. If the API returns "529 Overloaded", wait 60 seconds and retry the same
   step. Keep tool rounds small so a dropped turn loses little.

## Simulators

| WS | Device | UDID |
|----|--------|------|
| A | iPhone 17 Pro | `257A8CF7-19B6-4DC9-8B04-C5E2CEFA86C0` |
| B | iPhone 17 Pro Max | `4E591C69-5257-4847-871C-6ED76BEE1CBB` |
| C | iPhone Air | `92478751-5886-4EC8-AD52-CE7C9B070CD0` |
| D | iPhone 17e | `BF25D562-F7DD-4373-B564-2C74295A1FBC` |
| E | iPhone 17 (has a day-98 saved game, one employee) | `FC9D8216-E7A3-4933-B41C-2D93B502D9F8` |
| F | iPhone 17 Pro WS-F | `EBF8650B-D1B3-43BB-946F-258069D5C230` |
| G | iPhone 17 Pro WS-G | `E15769F5-31C7-467A-98A1-6D3C3D3C9E26` |

Screenshots go under
`/private/tmp/claude-501/-Users-alp-Desktop-Personal-Projects-StartupStudio/e228e6a0-9663-4ee3-83a3-476480f55c72/scratchpad/ws/<letter>/`.

---

## WS-A — One top band (idea 1, idea 11's HUD width, four quick wins) · M

**Build.** The notice rail: one line under the bar chosen by priority (pause
reason > unread report > loudest transient event line > coach tip), a "+N"
that opens the journal, swipe to cycle, Resume on the rail when a pause
reason leads. Toasts fold into the rail as its transient state, in the HUD's
pixel face, sliding in with `Motion.weighted` and out with `Motion.exit`.
`ToastCenter.announce` uses the same severity table as the pause banner so an
event that pauses or opens a sheet never also toasts; the two rival-launch
lines collapse to one. The cash delta rides in the rail when it comes from a
ledger event and otherwise rises in a reserved slot beside the cash pill,
never over it; the pill flashes the sign colour. The bar gains runway under
the date (small pixel scale, tinted with `BurnRateCard.runwayTint`'s
thresholds) and a dot on the speed control when `engine.lastPauseEvents` is
non-empty or a report is unread. `ViewThatFits` over the full and a compact
date label with layout priority on the speed control. Give the first coach
tip `Route.newProduct(topicID: nil)` and a "Start" button. Render a deferred
narrative choice (`shell.deferredChoiceID != nil` and the clock running) as
the rail's leading notice with its real countdown from
`state.narrative.pendingChoice.respondByDay`; tapping calls
`shell.recallDeferredChoice()`.

**Owns.** `Components/TopHUD.swift`, `Toast.swift`, `PauseBanner.swift`,
`TipStrip.swift`, `CashDelta.swift`, `SpeedControl.swift`, `EventCopy.swift`,
`GameCalendar.swift` (App), new `Components/NoticeRail.swift`;
`AppRootView.swift` **only** the `.overlay(alignment: .top) { ToastStack }`
block (remove it); `App/Tests/.../EventCopyTests.swift`; a new
`NoticeRailSnapshotTests.swift`.

**Seams.** Reads `GameShell.deferredChoiceID` (set by WS-D). Do not touch
`DecisionSheet`. The pause banner's paper may use `PixelPanel` as it stands;
WS-D adds a button variant you do not need.

## WS-B — HQ lands on the next thing; Products day 0 (idea 2 HQ and Products pieces) · S–M

**Build.** `NowCard` above the office: top active goal, progress bar, and its
action as a button via a goal-id → `Route` table (start product →
`.newProduct(topicID: nil)`, hire → `.hiring`, contract → `.contracts`; a goal
with no action shows its detail line). With a build in flight it becomes the
in-development card with the goal beneath. The office card drops to about
60% height on HQ (crop the lower floor band, never the people) and expands on
tap to a full-screen `OfficeSceneScreen` that also hosts the amenities, city
map and upgrade rows. `CompanyCard` moves into `SettingsSheet`;
`DepartmentsCard` leaves HQ (WS-G adds it to Team). HQ becomes Now · Office ·
Burn · Journal. Products day 0: below the CTA, the type catalog inline as
read-only cards (name, blurb, effort dots; leave a slot for WS-F's ceiling
badge) and an R&D teaser line.

**Owns.** `Screens/HQ/HQScreen.swift`, `GoalsCard.swift` (extract `GoalRow`),
`OfficeCard.swift` **layout only** (see seam), `OfficeHelpers.swift`,
`SettingsSheet.swift`, `DepartmentsCard.swift`, `JournalCard.swift`, new
`Screens/HQ/NowCard.swift`, new `Screens/HQ/OfficeSceneScreen.swift`;
`Screens/Products/ProductsListView.swift` **only** `EmptyProductsCard`; a new
`HQSnapshotTests.swift`.

**Seams.** In `OfficeCard.swift`, WS-E owns the `sceneInput`/`ambience`
builders (the code that constructs `OfficeSceneInput`/`OfficeAmbience`); do
not edit those functions. Do not edit `TipStrip` (WS-A routes the tip).

## WS-C — Life in two halves; the Business desk (idea 2 Life and Business pieces, four quick wins) · M

**Build.** `ThisWeekCard` leads Life: `EveningPips`, the schedule control
(embed `WorkScheduleCard` whole or read the same state; do not edit it), the
weekend plan row, the founder output multiplier with its three factors (read
the state `LifeMetersCard` reads; do not edit it). Sections: This week
(Activities, Networking), People (Partner, Family), Money and home (Money, Home
at reduced height with a tap-to-expand, Possessions), You (Skills,
Wellbeing). Drop `EveningPips` into `WeekendCard`, `ActivitiesCard`,
`FounderSkillsCard`'s training, `PartnerCard`, `NetworkingVenueSheet`. City map
reachable from `HomeCard`. Business: `DeskCard` above the pill bar with every
item that has a clock (contract due with the on-track line — copy the logic
from `ContractsView.qualityLine` into a small `ContractOutlook` helper rather
than editing that file; term sheet; price war or boom/crash in a topic you
sell in; campaign ending; loan interest; rival copycat), rows routing into
sections, sorted by urgency, collapsing to "Nothing on the desk".
`SegmentPillBar` gains an optional badge per segment, a trailing fade mask,
and two rows of three on narrow widths; the default section follows the
desk's top row. Runway weeks on the Finances run-rate card.

**Owns.** `Screens/Life/LifeScreen.swift`, new `ThisWeekCard.swift`,
`WeekendCard.swift`, `ActivitiesCard.swift`, `FounderSkillsCard.swift`,
`PartnerCard.swift`, `FamilyCard.swift`, `NetworkingVenueSheet.swift`,
`ShoppingSheet.swift`, `MoneyCard.swift`, `LifeHelpers.swift`,
`HomeCard.swift` **layout only** (see seam); `Screens/Business/BusinessScreen.swift`,
new `DeskCard.swift`, new `ContractOutlook.swift`, `FinancesView.swift`,
`Components/SegmentPillBar.swift`; a new `LifeBusinessSnapshotTests.swift`.

**Seams.** `HomeCard.swift`: WS-E owns the code that builds the home scene's
inputs (`HomeSceneView` init arguments); edit layout only. Do not edit
`WorkScheduleCard` (WS-F), `LifeMetersCard` or `WeekendRecapCard` (WS-E),
`ContactSheet`, `NetworkingCard`, `AddressBookSheet` (WS-G), `ContractsView`
(WS-F).

## WS-D — Decisions with the numbers, in the game's hand, deferrable (idea 3, two quick wins) · M

**Build.** Every `DecisionPrompt.Option` with a cash effect shows its
after-state ("−$2,300 → $9,250 · runway 8 wk") from `state.company.cash`,
`engine.weeklyBurn` and the option's cost (add a `cashDelta: Int?` to
`Option`, filled by each presenter). The deadline pill uses the calendar label
or "in N days". Narrative choices get "Let me think" (and pull-to-dismiss):
set `shell.deferredChoiceID`, resume the clock at the pre-pause speed, and
have `AppRootView.pendingDecision` return nil while the id matches; the
engine's auto-resolve and journal line already handle the deadline. Buyouts,
poaches and term sheets stay modal. Fix the report-then-choice ordering so a
pending choice re-pauses when the report closes. Rebuild the sheet on
`PixelPanel` paper: pixel icon (FX sprites) instead of the SF Symbol,
`PixelText` kicker, amount in pixel numerals, SF body, 9-slice `PixelPanel`
buttons with a 1-px press offset (add the variant to `PixelPanel`), rival
portrait via `PixelPortrait(seed: rival.appearanceSeed)`. Sound and haptic on
present for `.critical` prompts. Buttons into the scroll view's bottom
safe-area inset; `.large` at accessibility sizes.

**Owns.** `Components/DecisionSheet.swift`,
`Narrative/NarrativeChoicePresenter.swift`, `Narrative/ProgressionEventPresenter.swift`
(if a prompt lives there), `Components/PixelPanel.swift`, `Components/PixelPortrait.swift`,
`Audio/Sounds.swift`, `Audio/Haptics.swift`; `AppRootView.swift` **only** the
`pendingDecision` binding, its `.sheet(item:)`, and the weekly-report
ordering; `GameShell.swift` **only** where the deferral is set; a new
`DecisionSheetSnapshotTests.swift`.

**Seams.** Do not touch `PauseBanner` or `TopHUD` (WS-A renders the deferred
countdown from `shell.deferredChoiceID`). Do not touch `WeeklyReportSheet`
(WS-G).

## WS-E — The office and the home read the game; Reduce Motion (idea 4, idea 11's renderer half) · L

**Build.** `OfficeSceneInput.pressure`: work pace pins the lighting to night
and `OfficeTempo` reads `.crunch` from it, not the clock, with a pizza box on
the counter and the clock resuming from morning when crunch ends; runway under
4 flickers the ceiling lamp and lands an envelope pile on the founder's desk,
debt puts the sticky note on the coffee machine; bug load per product drives
the bug bubble over that product's coders; pending departures put a flat box
under the desk three days before; a pending offer stands a courier at the
door. Lighting and props only, never walk plans; one prop per signal,
severity-gated. `HomeSignals`: relationships drive the partner's position and
bubble, health under 40 the slump pose and a takeaway box, work after dusk a
lit desk lamp, wallet below rent the bills on the table. Move `MeterDelta` to
`Components/MeterDelta.swift` and render it inline beside each meter in
`LifeMetersCard`. `PixelSceneView` honours Reduce Motion: 2 fps and still or
toggle animations instead of walk cycles. Every new state gets a preview PNG
from the PixelKit tests; `PaletteTests` must stay green (no new colours).

**Owns.** Everything under `Packages/PixelKit/`; `Screens/HQ/OfficeCard.swift`
**only** the `sceneInput`/`ambience` builders; `Screens/Life/HomeCard.swift`
**only** the code that builds the home scene's inputs; `LifeMetersCard.swift`;
`WeekendRecapCard.swift` **only** the `MeterDelta` extraction;
`ActivityPlaybackSheet.swift`; new `Components/MeterDelta.swift`.

**Seams.** Read `state.economy.workPace`, runway from `engine.weeklyBurn`
and cash, `products[].bugs`, loyalty/notice state, `rivals.pendingBuyout` —
all existing. Do not add engine state.

## WS-F — The product loop shows its maths; crunch and assignment where the work is; market screens that act (ideas 5, 9, 10, two quick wins) · M+

**Build.** `ShipForecast.preStart(typeID:topicID:codebaseID:state:balance:content:)`
with full pools and no bugs; ceiling badge on each `TypeCard`, fit-adjusted
number on the topic cell, a compact forecast with the one-line fix on the
details step, "Start · ~58 best case" on the button. At ship, snapshot the
forecast's components onto `ReleaseInfo` (optional field; decode with
`decodeIfPresent` so old saves need no format bump — if a bump is unavoidable,
add the `MigrationStep` in `TycoonSave`); launch day adds the reason line and
a route to the fix; the released header keeps it. `PhaseFocus.matching(product:content:)`
ported from the bots' `focusForRemainingWork`, a "Match the work" button on
`FocusEditor`, on by default at start, days-to-full per pool "at today's
pace". `WorkPaceControl` (new component) on the in-development card and the
product detail, bound to the same state as the Life card, and swapped into
`WorkScheduleCard`; the Products header says "Crunching — week N".
`AssignmentMenu` inline on the contract card and the lab card. `TopicDetailView`
bottom bar ("Start a product in X" → `router.go(.newProduct(topicID:))`, "Run a
campaign", "Change price" when applicable); the report's "Done" becomes a
toolbar with the same. Engine tests pin the pre-start number to the day-one
forecast and the ship snapshot to the reviews' quality.

**Owns.** `Packages/TycoonEngine/.../ShipForecast.swift`, `Product.swift`,
`Systems/ProductSystem.swift` (ship only), `Packages/TycoonSave/` (only if a
migration is needed), their tests; `Screens/Products/NewProductFlow.swift`,
`ProductDetailScreen.swift`, `ProductsListView.swift` (all but
`EmptyProductsCard`), `Components/FocusEditor.swift`, `PhaseProgress.swift`,
`LiveOps.swift`, `LaunchDaySheet.swift`, `Screens/Life/WorkScheduleCard.swift`,
new `Components/WorkPaceControl.swift`, `Screens/Business/ContractsView.swift`,
`Screens/Research/ResearchView.swift`, `Screens/Market/TopicDetailView.swift`,
`MarketReportScreen.swift`; a new `ProductLoopSnapshotTests.swift`.

**Seams.** `ProductsListView.EmptyProductsCard` is WS-B's (it leaves a slot
for your ceiling badge; fill it only if the merge has landed, otherwise note
it). No balance changes: the pre-start forecast must equal the existing
forecast on day one.

## WS-G — People at a glance; coaching that ends in a sentence (ideas 7, 8, two quick wins) · M

**Build.** `EmployeeStatus` helper (priority: on notice with days > out of
patience in N days > rival offer pending > underpaid > idle N weeks > bond
fading > in training) rendered as one line per roster row; "Needs attention"
sort, default when anyone has a status; a count badge on the Team tab item
when anyone is on notice. Founder row on day 0: "Idle · joins the next
product"; hiring row and empty state count down to the first batch; ghost
marks on candidate skill bars at the roster's best. Address-book rows: trend
glyph and "Fading — call this week" (add a last-contact day to `Networking`
if only rapport is stored, with a decode default); networking card line "3
warm · 2 fading"; `ContactSheet` buttons say what they restore and show
`EveningPips`. Weekly report: `nextAction` derived from the top active goal
leads the outlook card as a route button; the team card uses `EmployeeStatus`;
auto-open stops after the player has opened the report from the chip twice
on their own. Failed endings: "What went wrong" card (three lines max, each
with a number) from a `PostMortem` helper with tests; "Try that year again"
replays the same seed, founder and company (store the seed at `newGame` if
it is not recoverable from state); the win screen gets "Run it back". Add
`DepartmentsCard(engine:)` to the Team tab (WS-B removes it from HQ).

**Owns.** `Screens/Team/TeamScreen.swift`, `EmployeeManageSheet.swift`,
`HiringSheet.swift`, `TraitChip.swift`, `Components/SkillBars.swift`,
`Components/RoleBadge.swift`, `Components/FriendChip.swift`, new
`Components/EmployeeStatus.swift`; `Screens/Life/AddressBookSheet.swift`,
`NetworkingCard.swift`, `ContactSheet.swift`;
`Packages/TycoonEngine/.../Networking.swift`, `Systems/NetworkingSystem.swift`,
`Systems/RelationshipSystem.swift` and tests (last-contact day only);
`Components/WeeklyReport.swift`, `WeeklyReportSheet.swift`; `GameShell.swift`
**only** `dayAdvanced`'s auto-open rule; `Screens/Endings/*`,
`GameOverView.swift`, `GameWonView.swift`, `GameSession.swift`, new
`PostMortem.swift` and tests; `AppRootView.swift` **only** the Team tab
item's badge in `tabs(engine:)`; a new `PeopleCoachingSnapshotTests.swift`.

**Seams.** `GameShell.swift` and `AppRootView.swift` are shared with WS-A and
WS-D in different regions; keep your edits to the named spots.

---

## Integration

Merge order into `iteration-4`: **A → D → B → C → E → F → G**, resolving
`AppRootView.swift` and `GameShell.swift` by hand where hunks touch. After
each merge: `make gen && make build`, `make apptest`, then the four package
suites. After all seven: a screenshot pass on every tab in light and dark on
a fresh game and on the day-98 save, a look at every new snapshot PNG, and a
seams pass — the ceiling badge slot in `EmptyProductsCard`, the deferred
countdown on the rail, the desk's rows against the rail's copy, the Team
badge against `EmployeeStatus`.

**Wave 2 — One money, one face (idea 6).** After the merge, one workstream:
`Theme.gameLocale` through `Int.money` and every `.formatted` site,
`MoneyText`, the `PixelText` glyph roll, `MoneySheet` off the cash counter.
Then a finisher for warnings, dead code, and the README.
