# Startup Studio — Iteration 4: UI and UX

A review of the game as it plays, not as it simulates. Iteration 3 was about
systems (the market, rivals, the tree); this one is about what the player sees,
where they have to scroll, what interrupts them, and whether the pixel office
is a face or a poster.

Written after building `main` at `a3dc235`, installing it on four simulators
(iPhone 17, 17 Pro, 17 Pro Max, Air), screenshotting every tab in a fresh game
and in a day-98 saved game, running x4 time-lapses to catch the chrome under
load, rendering the app's own snapshot previews in light and dark, and reading
every screen under `App/Sources/Screens`, the chrome under `App/Sources/Components`,
and the renderer's inputs in `Packages/PixelKit`. The simulator cannot be tapped
without accessibility permissions, so onboarding steps 2–4, every sheet, and the
sub-screens (market report, city map, networking floor, address book) are judged
from code and previews. Each finding below says which it is.

Four lenses were used: the first session; the core loop (Products, R&D, Team);
the dense tabs (Business, Life, City, Market); and feel (theme, motion,
feedback, accessibility). The ideas are merged across lenses and ranked once.

## Where the UI is actually thin

Six findings drove the ranking. None is "it needs polish" — each is a place
where the screen hides a number the player needs, says something untrue, or
lands them somewhere other than the decision.

1. **The top band is a pile-up.** `TopHUD` stacks the bar, the weekly-report
   chip, the pause banner and the tip strip as four independently conditional
   rows (`TopHUD.swift:229-234`), and toasts are overlaid at a fixed 72 pt from
   the root (`AppRootView.swift:45-48`) that does not know how many rows are
   open. Captured three separate times: day 9 of a new game with all four rows
   up and a decision sheet on top (a third of the screen is chrome before the
   game starts); week 3 on Life with two toasts drawn across the chip and the
   tip; and the cash-delta floater "−$450 Operating costs" drawn over the
   `$3,750` pill it is explaining (`TopHUD.swift:254-258`). One rival launch
   produces two toasts with different copy (`EventCopy.swift:197` and the
   product-level line); one buyout produces a toast, a banner and a sheet. The
   weekend sun badge pushes the speed control's frame off the right edge on
   the widest phone (`TopHUD.swift:243-249`, `PixelText` at scale 2 cannot
   shrink).

2. **Every tab lands on a picture, and the next action is below the fold.**
   HQ's first viewport is the office; the "Start your first product" card is
   the sixth card (`HQScreen.swift:23-42`), and the tip that says "Start a
   product from HQ" (`TipStrip.swift:378`) is the only chapter-1 tip with no
   route button, because `Route` has no case for the new-product flow
   (`AppRouter.swift:17-25`). Life's first viewport is the home; its twelve
   cards (`LifeScreen.swift:16-33`) put the weekly decisions (schedule,
   activities, weekend, networking) at positions 4, 6, 7 and 9 and the yearly
   ones (home, possessions, family) at 1, 10 and 12. Business lands on two
   empty states under a pill bar that shows three and a half of its six
   sections with no fade or badge (`SegmentPillBar.swift:27-28`,
   `BusinessScreen.swift:36-100`). Products and Team on day 0 are a lone card
   and a blank screen: candidates start empty (`GameState.swift:649`) and the
   founder is marked "Idle" with no explanation that idle people join the next
   product automatically (`ProductSystem.swift:271, 308`).

3. **Decisions are asked without the numbers, and promise a deadline that
   cannot happen.** `DecisionSheet` covers the HUD, so "Pay the squatter
   −$2,300" is asked with the cash hidden; the stats pill says "Answer by Day
   12", a unit the HUD never shows (`NarrativeChoicePresenter.swift:27-30`).
   The sheet appends "If you don't answer within 5 days, it goes down as …"
   (`:66-76`), but `.narrativeChoice` is `.critical` (`GameState.swift:377`),
   always pauses, and the sheet disables interactive dismissal
   (`DecisionSheet.swift:33-37`): the clock cannot move while the question is
   up. The one path where days *do* tick behind the modal is the weekly report
   yielding to it (`AppRootView.swift:183`) and "Next week" resuming the
   clock with the choice still pending. (A time-lapse under `-autoSpeed` also
   shows the clock running behind a buyout sheet, but that flag calls
   `setSpeed` at launch and clears the pause; it is a debug artefact, not
   play.) Visually, the biggest decisions in the game — the buyout, a hire,
   a story beat — are stock iOS sheets with an SF Symbol, while the weekly
   report and launch day are in the game's pixel hand
   (`previews/app/weekly_report_headline_light.png`). At the AX1 text size
   the title clips to "Waypoint Nine / wants to buy you…" behind the fixed
   button stack (`DecisionSheet.swift:51-131`).

4. **The office is a face for five things and a poster for the five that
   matter.** `OfficeCard` feeds tier, amenities, per-person assignment and
   mood, friendships, weather, weekend and seven celebrations
   (`OfficeCard.swift:144-300`). It does not feed cash or runway, a product's
   bug count, a pending departure, or a buyout on the table. Crunch is faked:
   the only channel is `timeOfDay: workPace == .crunch ? .dusk : .morning`
   (`OfficeCard.swift:166`), which sets the start phase of the room's own
   four-minute cosmetic clock, and `OfficeTempo.reading` then reports
   `.crunch` whenever the clock says it is late and somebody is building
   (`OfficeTempo.swift:33-40`) — roughly half of every four real minutes,
   crunch or not. The home reads energy and mood and ignores health,
   relationships and the wallet: a founder with Relationships at 16 sits on
   the couch under a heart bubble (`HomeCard.swift:96-146`). `grep ReduceMotion
   Packages/PixelKit/Sources` returns nothing; the scenes walk for a player
   who asked them not to (`PixelSceneView.swift:98`).

5. **The numbers have three faces and two locales.** `Int.money` hard-codes
   the thousands comma; 36 other sites use `.formatted(...)` and obey the
   device, so on a comma-decimal region the Life tab shows "Founder output
   ×0,93" under "$5,100" (`LifeMetersCard.swift:84`). Money on one Business
   screen appears in pixel, SF rounded and SF regular. Runway — the number the
   fifth coach tip says to watch — is on HQ's burn card, the weekly report and
   the tip, and not on the Finances section's run-rate card
   (`FinancesView.swift:463`) nor in the HUD. Morale changes silently: the
   roster row has a mood face and no number, no status, no haptic
   (`TeamScreen.swift:304-351`).

6. **The forecast, the reason and the post-mortem all arrive one step late.**
   The crew ceiling — the number that decides whether a product is worth
   starting — appears only after the player has committed, on the detail's
   forecast card (`ProductDetailScreen.swift:680-745`); the type and topic
   steps show market size and effort and nothing about *this* crew
   (`NewProductFlow.swift:305-372, 785-814`). Launch day reveals the score and
   not what held it down; `ShipForecast.limitingFactor` is a projection that
   is never captured at ship (`LaunchDaySheet.swift:114-196`). The ending is
   one engine sentence ("cash stayed negative beyond the 14-day grace period",
   `FinanceSystem.swift:75`) over a biography; nothing derived from the run
   says why, and the deterministic seed the README advertises is not offered
   as a second attempt.

---

## Ranking

| # | Idea | Size | Why here |
|---|------|------|----------|
| 1 | **One top band** | M | Every screen, every minute; verified broken in three captures. Cheapest large win. |
| 2 | **Every tab lands on the next thing** | L (4 × S–M) | Turns four "picture first" tabs into "decision first". Splittable per tab. |
| 3 | **Decisions with the numbers, in the game's hand, deferrable** | M | The most consequential screens are the least legible and the least *this* game. |
| 4 | **The office and the home read the game** | L | The art is the identity; make it a state display for crunch, runway, bugs, departures, meters. |
| 5 | **The product loop shows its maths before, not after** | M | Pre-start forecast, launch-day reason, focus that follows the work. |
| 6 | **One money, one face** | M | Locale-honest numbers, a money sheet off the cash counter, a delta that sits beside the pill. |
| 7 | **People at a glance** | S–M | Roster rows and address-book rows carry the week's one fact. |
| 8 | **Coaching that ends in a sentence** | M | Week-1 "do this next", earlier auto-open cutoff, a post-mortem, same-seed replay. |
| 9 | **Crunch and assignment where the work is** | S | Work pace on the product; assign from the contract and the lab. |
| 10 | **Market screens that act** | S | The report and topic detail get "Start a product here" and "Run a campaign". |
| 11 | **Reduce Motion reaches the renderer; the HUD fits every width** | S | Two real accessibility failures, both small. |

---

## 1. One top band · M

**Problem.** Finding 1. Four rows plus a floating toast stack plus a floating
delta compete for 250 pt; order is by file, not urgency; the same event can
arrive three ways.

**Idea.** Replace the chip, the pause banner, the tip strip and the toast stack
with one *notice rail* under the bar: exactly one line at a time, chosen by
priority — pause reason ("Time stopped: the domain you wanted is for sale ·
Resume") > unread report ("Week 1 report") > transient event line (the loudest
toast of the batch, in the HUD's own pixel face) > coach tip. A trailing "+2"
opens the journal; swiping the rail cycles. `ToastCenter.announce` consults the
same severity table the pause banner uses, so an event that will pause or open
a sheet never also toasts, and the two rival-launch lines collapse to one. The
cash delta rides in the same line when it comes from a ledger event ("−$450 ·
Operating costs") and otherwise rises inside a reserved slot beside the cash
pill, never over it; the pill's fill flashes the sign colour so the direction
reads even when the text does not. The bar itself gains the two things the
player looks for every minute: runway under the date in the small pixel scale,
tinted with the burn card's thresholds, and a dot on the speed control when the
clock is stopped by something or a report is unread. `ViewThatFits` over the
full and a compact date label ("W15 · Y1", sun badge folded in) with layout
priority on the speed control fixes the weekend clip.

**Touches.** `TopHUD.swift` (fold `WeeklyReportChip`, `PauseBanner`, `TipStrip`
and `ToastStack` into a `NoticeRail` with a small `Notice` model), `Toast.swift`
(`announce`, severity table shared with `PauseBanner`), `AppRootView.swift:45-48`,
`CashDelta.swift`, `EventCopy.swift:197`, `GameCalendar` (compact label),
`PixelChromeTests` snapshots for the rail's states.

**Risk.** A single line hides information in a busy tick; the "+N" and the
journal are the escape hatch. Do not let the rail grow past one line plus
counter, or it becomes the thing it replaces.

## 2. Every tab lands on the next thing · L, in four pieces

**Problem.** Finding 2.

**HQ (S–M).** A `NowCard` above the office: the top active goal, its progress
bar, and *its action as a button* — "Start your first product" opens
`NewProductFlow`, "Hire someone" routes to hiring, "Accept a contract" to
contracts (a small goal-id → route table, keyed like `CoachTip.goalID`). With a
build in flight it becomes today's in-development card with the goal beneath.
The office card drops to about 60% height on HQ (crop the lower floor band, keep
the people) and expands on tap to a full-screen scene that also hosts the
amenities, city and upgrade rows. `CompanyCard` moves to the settings sheet;
`DepartmentsCard` to Team, where the hiring that forms a department happens. HQ
becomes Now · Office · Burn · Journal. Add `Route.newProduct` and put it on the
first tip.

**Life (M).** A `ThisWeekCard` leads: five evening pips (spent ones say what
spent them on tap), the schedule control, the weekend plan row, and the founder
output multiplier with its three factors. Then sections: This week (Activities,
Networking), People (Partner, Family), Money and home (Money, Home at the
reduced height, Possessions), You (Skills, Wellbeing). The pips are passed into
every sheet that spends an evening — `ContactSheet` and `WeekendCard` never
mention evenings today; the remaining count is rendered only in
`ActivitiesCard`'s footer (`ActivitiesCard.swift:30, 104-112`).

**Business (M).** A `DeskCard` above the pill bar, always on landing: every
business item with a clock or a state change — a contract due in N days with
the on-track line the contract card already computes
(`ContractsView.swift:133-150`), a term sheet, a price war or a boom/crash in a
topic you sell in, a campaign ending, loan interest, a rival's copycat — each
row routing into its section, sorted by urgency, collapsing to "Nothing on the
desk". The pill bar gains a count badge per section and renders as two rows of
three on narrow widths.

**Products and Team, day 0 (S).** Products renders the type catalog inline as
read-only cards with the idea-5 ceiling badge, plus an R&D teaser. Team's
hiring row counts down to the first batch, the founder row reads "Idle · joins
the next product", and one line names the crew's weakest pool against the
unlocked types' biggest.

**Touches.** `HQScreen`, `GoalsCard`, `OfficeCard`, `AppRouter`, `LifeScreen`
and a new `ThisWeekCard` built from `WorkScheduleCard`/`WeekendCard`/
`LifeMetersCard`, an `EveningPips` view, `BusinessScreen`, `SegmentPillBar`
(badge), a `DeskItem` helper, `ProductsListView.EmptyProductsCard`,
`TeamScreen`, `HiringSheet`.

**Risk.** The office and the home are the identities of their tabs; cropping
must never cut the people, and each stays one tap from full height. The desk
duplicates what the rail and the weekly report say — make it the persistent
form of those and route the rail's "Details" for business events to it.

## 3. Decisions with the numbers, in the game's hand, deferrable · M

**Problem.** Finding 3.

**Idea.** Three parts on `DecisionSheet`. (a) *Numbers:* every option with a
cash effect shows its after-state computed in the app — "Pay the squatter ·
−$2,300 → $9,250 · runway 8 wk" — and the deadline pill uses the calendar label
("by Jan W3") or "in 5 days". (b) *Deferral for narrative choices:* a "Let me
think" option (and pull-to-dismiss) resumes the clock and turns the question
into the rail's leading notice with a *real* countdown; the engine already
auto-resolves at the deadline and journals "you never answered, so: …"
(`EventPresenter.swift:41-47`). Buyouts, poaches and term sheets stay modal.
Fix the report-then-choice ordering at `AppRootView.swift:183` so a pending
choice re-pauses when the report closes. (c) *The game's hand:* rebuild the
sheet on `PixelPanel` paper — a pixel icon (envelope, handshake, box exist as
FX sprites) instead of the SF Symbol, a `PixelText` kicker ("BUYOUT OFFER"),
the amount in pixel numerals, body copy in SF for Dynamic Type, choices as
9-slice `PixelPanel` buttons with the speed control's 1-px press offset. Rivals
carry `appearanceSeed`; draw the rival founder with `PixelPortrait` so
"Waypoint Nine" is a person. Give the sheet a sound and a haptic on present for
`.critical` prompts — it has none today. Move the buttons into the scroll
view's bottom safe-area inset and open at `.large` at accessibility sizes,
which fixes the AX1 clip. Apply the same paper to the pause banner.

**Touches.** `DecisionSheet.swift`, `NarrativeChoicePresenter.swift`,
`AppRootView.swift:179-192`, `TopHUD`/rail (countdown notice), `PixelPanel`
(button variant), `PixelPortrait`, `Sounds`/`Haptics`, an app preview test for
the sheet in light and dark.

**Risk.** Deferral lets a player be surprised by an auto-answer; the rail
countdown and the journal line are the mitigation. Pixel body copy is
unreadable — keep prose SF. Pixel buttons must keep 44 pt targets and use
`Theme.ink(on:)` for contrast.

## 4. The office and the home read the game · L

**Problem.** Finding 4.

**Idea.** A small `OfficeSceneInput.pressure` struct, each field owning exactly
one prop or one lighting change. `workPace` pins the lighting overlay to night
while crunch is on (desk lamps lit, windows dark) and `OfficeTempo` reads
`.crunch` from *this* rather than the clock; a pizza box appears on the
kitchenette counter; when crunch ends the clock resumes from morning and the
room visibly exhales. `runwayWeeks` under 4 flickers the ceiling lamp and lands
a red-ringed envelope pile on the founder's desk; in debt, the coffee machine
gets the existing sticky-note sprite reading "OUT OF ORDER". `bugLoad` per
product drives the existing bug bubble over that product's coders at a rate
proportional to load. `pendingDepartures` (loyalty under threshold, or a poach
in flight) puts a flattened box *under* that person's desk three days before
they go — the box-carry exit already exists; this is its foreshadowing and the
player's chance to act. `pendingOffer` stands a courier at the door with an
envelope until the decision is made, so the buyout exists somewhere other than
the sheet. Lighting and props only, never the walk plans, which is the rule
`OfficeTempo` already follows. The home gets the same treatment from a
`HomeSignals` struct: Relationships drives the partner's position and bubble
(near and a heart when warm; the far end of the couch under a phone glow when
cold; the founder's own "…" bubble when single and low), Health under 40 uses
the slump pose and a takeaway box on the counter, a lit desk lamp after dusk
when the planned activity is work, unpaid bills on the table when the wallet is
below next rent. Put the weekend recap's `MeterDelta` inline beside each meter
so a meter never slides silently.

**Touches.** `OfficeSceneInput` (new struct), `OfficeCard.sceneInput/ambience`
(read `economy.workPace`, runway, `products[].bugs`, loyalty,
`rivals.pendingBuyout`), `OfficeDirector.build` (props step,
`OfficeDirector.swift:228-262`), `OfficeTempo.reading(for:)`, `RoomBuilder`/
`officeSurfaces(tier:time:)` for the night pin, `OfficeFXSprites` (pizza box,
envelope pile, flat box, courier), `HomeCard.swift:96-146`, `HomeSceneView`,
`HomeSpriteLibrary`, `LifeMetersCard`, PixelKit preview tests so every state has
a PNG.

**Risk.** Noise. One prop per signal, severity-gated, never two on one desk;
the night pin must not fight the celebration lighting. A partner "acting cold"
from a number can read as punitive — use position and bubble, never expression.
Nothing here changes balance; it reads state.

## 5. The product loop shows its maths before, not after · M

**Problem.** Finding 6, first two parts; and the focus editor is three sliders
with one right answer — the engine's own bots compute it as "a focus split
matching what a product still needs … the thing any player learns in their
first hour" (`PacingBots.swift:56-70`).

**Idea.** (a) A `preStartForecast(typeID:topicID:codebaseID:)` on the engine
reusing `ShipForecast`'s arithmetic with full pools and no bugs. Each
`TypeCard` gets a ceiling badge ("~58 with this crew", `Theme.scoreTint`), the
topic cell adds the fit-adjusted number, and the details step shows a compact
forecast above the name field with the one-line fix ("Your crew caps code-heavy
types — a coder would lift this to ~70"); the Start button reads "Start · ~58
best case". (b) At ship, snapshot the forecast's components onto the release;
after the average stamps down, launch day adds one line in the founder's voice
— "Your crew capped this at 61. Better people, not more time." / "Open bugs cost
12 points." / "Two launches this quarter split the market." — with a button to
the fix (Hiring, live ops, R&D), and the released product's header keeps the
line. (c) A "Match the work" button on `FocusEditor` (port
`focusForRemainingWork` into the engine as `PhaseFocus.matching`), on by
default at start, with days-to-full per pool at today's pace next to the
sliders so dragging is a decision.

**Touches.** `ShipForecast.swift` (static projection), `NewProductFlow.swift`
(`TypeCard`, `TopicCell`, `DetailsStep`), `Product.swift` (`ReleaseInfo` field,
save migration in `TycoonSave`), `ProductSystem.ship`, `LaunchDaySheet.swift`,
`ProductDetailScreen.ReleasedHeaderCard`, `FocusEditor.swift`, engine tests
pinning the pre-start number to the day-one forecast.

**Risk.** A low ceiling on every type in the garage can read as "nothing is
worth building" — always pair the number with the fix. The days-to-full
estimate must say "at today's pace". Save format bump; the field is optional.

## 6. One money, one face · M

**Problem.** Finding 5.

**Idea.** `Theme.gameLocale` (`en_US_POSIX`) that both `Int.money` and every
`.formatted(...)` site route through; money is the game's currency and is
documented as deliberately not localised. A `MoneyText(value, style:)` component
replaces the three faces — pixel at HUD and report scale, `Theme.Typography.number`
elsewhere, sign colour from one place. `PixelText` gains a glyph roll for a
changing figure (each changed column slides 7 px over `Motion.value`), the pixel
equivalent of `.numericText()`, so the HUD cash moves the way every SF figure
already does. Tapping the cash counter opens a `MoneySheet` with three groups —
Company (cash, burn, runway, income last week, tech debt), Bank (outstanding,
limit, interest, what the house secures), You (wallet, salary against the team
band, rent, next home tier) — and the burn card, Finances and Life's money card
each link to it. Runway weeks join the Finances run-rate card regardless.

**Touches.** `Theme.swift` (`money`, `gameLocale`), the 36 `.formatted` sites
starting at `LifeMetersCard.swift:84`, `PixelText.swift`, `TopHUD.cashCounter`, a
`MoneySheet` composed from `BurnRateCard`, the Finances bank card and
`MoneyCard`, `FinancesView.swift:463`.

**Risk.** A 5×7 glyph roll at scale 2 is subtle — test at 1x. Pinning the
locale is wrong for a player who wants "5.100 $"; accept it.

## 7. People at a glance · S–M

**Problem.** Finding 5, last part; the manage sheet computes patience days,
notice, loyalty and bond (`EmployeeManageSheet.swift:203-362`) one tap deep per
person; the address book prints rapport with no warning before a contact goes
cold (`AddressBookSheet.swift:18, 104`).

**Idea.** One status line per roster row from a shared `EmployeeStatus`
helper, by priority: "On notice · 9 days" > "Out of patience in 4 days" >
"Rival offer pending" > "Underpaid" > "Idle for 3 weeks" > "Bond fading" > "In
training until day N". A "Needs attention" sort, default when anyone has a
status, and a count badge on the Team tab when anyone is on notice. The weekly
report's team card uses the same helper. In the address book, each row shows a
trend glyph and "Fading — call this week" when rapport has fallen for N days;
the networking card's line becomes "3 warm · 2 fading". In hiring, a ghost mark
on each candidate's skill bars at the roster's current best, so "better than
anyone we have" reads at a glance.

**Touches.** `TeamScreen.swift` (`EmployeeRow`, `SortOrder`), an `EmployeeStatus`
helper shared with `EmployeeManageSheet` and `WeeklyReport`, `AppRootView.tabs`
(badge), `AddressBookSheet`, `NetworkingCard`, `ContactSheet` (needs a
last-contact day per contact — add it if only rapport is stored), `HiringSheet`,
`SkillBars`.

**Risk.** Rows grow by a line; move the trait chips to the status line's
trailing edge to hold height.

## 8. Coaching that ends in a sentence · M

**Problem.** Finding 6, last part; the weekly report auto-opens eight times
(`GameShell.swift:66`) and its "Next week" card lists deadlines or says "Nothing
is due. Build something." (`WeeklyReportSheet.swift:258-290`).

**Idea.** The report's outlook card leads with one line derived from the top
active goal and its state — "Do this next: start a product — you have $12,000
and no income" / "…ship it: code is at the gate, polish is 40%" / "…hire: 2
empty desks, candidates in 3 days" — as a button that routes there (the sheet
already takes a route callback). Stop auto-opening once the player has opened
the report from the chip twice on their own, not at a fixed week. On a failed
ending, a "What went wrong" card built from state and the ledger, three lines
at most, each with its number: never shipped; burn against income for N weeks;
hired before first revenue; salary above the team band; rent tier above cash.
Beside "Play again", "Try that year again": a new game with the same seed,
founder and company, so the same events and candidates appear and the player
can play them differently — the engine already supports it
(`GameEngine.newGame(companyName:seed:difficulty:founder:)`); the win screen
gets "Run it back".

**Touches.** `WeeklyReport.swift` (a `nextAction` field), `WeeklyReportSheet`
(outlook card), `GameShell.dayAdvanced`, a `GameSettings` counter,
`FounderBiographyView.swift`, `GameSession` (a replay path that recovers the
seed from state, storing it at `newGame` if it is not recoverable), a
`PostMortem` helper with tests.

**Risk.** The derived line must match what the goal system will credit; drive
it from goal ids like `CoachTip` does. Post-mortem lines must be facts with
numbers, not a scold.

## 9. Crunch and assignment where the work is · S

**Problem.** `setWorkPace` is exposed only on Life's `WorkScheduleCard`; the
product screen, where "we need to ship sooner" is decided, has no pace control
and no line saying the team is on crunch. "Nobody is working on this — it makes
no progress" (`ContractsView.swift:107`) and the lab's "Nobody is researching"
both send the player to the Team tab.

**Idea.** A `WorkPaceControl` (Relaxed / Normal / Crunch with its live cost:
"+30% output · +bugs · morale −2/wk · your evenings: 1") on the in-development
card and the product detail, bound to the same state as the Life card; while
crunching, the Products header and the office say so. An inline assign menu of
idle employees on the contract card and the lab card, reusing the roster's
`AssignmentMenu`.

**Touches.** `ProductsListView.InDevelopmentCard`, `ProductDetailScreen`,
`WorkScheduleCard` (shared control), `ContractsView`, `ResearchView.LabSummaryCard`,
`TeamScreen.AssignmentMenu` (make reusable).

**Risk.** Two controls for one state must animate together.

## 10. Market screens that act · S

**Problem.** `MarketReportScreen` has one button, "Done"
(`MarketReportScreen.swift:39`); `TopicDetailView` has no route to start a
product or a campaign in the topic it describes.

**Idea.** A bottom bar on the topic detail — "Start a product in Dating"
(opens `NewProductFlow` with the topic pre-selected) and, with a released
product in the topic, "Run a campaign" and "Change price"; the report's toolbar
gets the same for the selected topic. Boom and crash lines in the rail route to
the topic detail, closing the toast → report → action chain.

**Touches.** `TopicDetailView`, `MarketReportScreen`, `NewProductFlow` (initial
topic), `Route.newProduct(topicID:)`.

## 11. Reduce Motion reaches the renderer; the HUD fits every width · S

**Problem.** Finding 4, last part; Finding 1, last part.

**Idea.** `PixelSceneView` reads the reduce-motion trait `Theme.Motion` already
derives from: under it the `TimelineView` runs at 2 fps and `OfficeDirector`
substitutes still and toggle animations for walk cycles — people sit, monitors
glow, bubbles appear, nothing walks. The room stays a state display and stops
being a motion display. The HUD width fix is part of idea 1 and can ship alone.

**Touches.** `PixelSceneView.swift:98`, `OfficeDirector.animation(for:)`,
`TopHUD.dateLabel`, `GameCalendar`.

---

## Quick wins (under a day each)

- Move `CashDeltaOverlay` out of the cash pill's frame to a trailing slot
  (`TopHUD.swift:254-258`).
- Anchor toasts to the bottom of the HUD stack rather than 72 pt from the root
  (`AppRootView.swift:45-48`).
- `Theme.gameLocale`, applied to `Int.money` and the 36 `.formatted` sites,
  starting at `LifeMetersCard.swift:84`.
- `ViewThatFits` over full and compact date labels, layout priority on the
  speed control (`TopHUD.swift:243-249`).
- Add `Route.newProduct` and give the first tip a route (`TipStrip.swift:375-380`).
- "Answer by Day 12" → the calendar label (`NarrativeChoicePresenter.swift:27-30`).
- Decision sheet buttons into the scroll view's bottom inset; `.large` at
  accessibility sizes (`DecisionSheet.swift:51-131`).
- Announce each event once: keep one of the two rival-ship lines
  (`EventCopy.swift:197`); skip toasts for events the banner or a sheet will
  carry.
- Founder row on day 0: "Idle · joins the next product"; hiring empty state
  counts down to the first batch (`HiringSheet.swift:83`).
- Runway weeks on the Finances run-rate card (`FinancesView.swift:463`).
- A fade mask on the trailing edge of `SegmentPillBar`.
- Evening pips on `ContactSheet` and `WeekendCard`.

## What this review could not verify

- Any office with two or more people: the saved game had one employee, so
  huddles, friend-chats and the crowd's motion were judged from
  `OfficeBehaviors.swift`, `OfficeTempo.swift` and the `anim_*`/`office_*_sheet`
  previews, not watched.
- Late-game screens (loft to campus, live ops with several products, a seated
  board, the endings) — from code and previews only.
- Onboarding steps 2–4, every sheet, and every sub-screen — from code.
- Haptics and sound — call-site inventory only; the simulator has neither.
- Dark mode was checked on every tab and had no failures.

## Not in this doc

Iteration 3's systems ideas (the category fight, the codebase, ambitions,
named clients, the tree's forks, the launch window) are assumed; several ideas
above say how a screen would carry them. Nothing here changes balance: every
idea reads state the engine already has, and the six pacing tests pinned in
`BalanceTargetsTests` are untouched.
