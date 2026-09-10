# Iteration 15 — PM lens: meta, endings and moment-to-moment

*Read-only pass over `iteration-15` @ 6660ccc, 10 September 2026. Two halves: how a run ends and what crosses it; what a hand can do in the pixel rooms.*

**Where I disagree with the brief.** Half (a) asks how many endings there are and whether the player can choose one; the count is fine (seven, four chosen). The gap is that every chosen ending is an *exit* — nothing lets the founder stay in the company they built, and the two endings that can be played past have no game in them. Half (b) asks what a tap does; the office answer is "opens a sheet", and the home answer is "nothing".

## Diagnosis

**Meta.** `EndingKind` (`GameState.swift:54`) has seven cases. Four are chosen by the player — `acceptBuyout` (only when a rival's `buyoutCheck` has rolled an offer, `RivalSystem.swift:1352`), `fileIPO`, `declareIndependence`, `walkAway` — and three are forced (bankruptcy, ousted, and `soldUp`, which is `acceptBuyout` on a distress bid). Nothing lets the player *solicit* a sale, hand the company to a named successor and keep playing, or fold on their own terms before the receiver. Only `.ipo` and `.independent` can be continued (`Reducer.continueAfterEnding`, :1028), and the epilogue is the same simulation with three doors shut: `epilogue` is read at five guard sites (`InvestorSystem.swift:38,524,589`, `Investors.swift:605,647`, `RivalSystem.swift:1364`) and nothing scores, threatens or rewards a company past its ending. What crosses a run: one heirloom (a person, a perk or the deed; carrying one unranks), and a successor's face, archetype and household traits. `GameState.lineage` is stored and encoded (six hits in `GameState.swift`) and read by no system. The six reward ledgers — Hall of Fame (`HallOfFameSheet` has one button, Done), awards (honorific, `AwardsJudge` sends nothing), scenario stars, season looks, desk-streak decor, the stake rung — are all pure upside; the heirloom is the one meta choice in the game. Goals: 42 authored in `Goals.json` over 29 condition kinds, rewards are reputation (30), perk+reputation (8), cash (4); a chapter opens on *any* four (`goalsToAdvanceChapter = 4`), so the chapter card is a checklist, not a choice. Daily, season and league all score `founderNetWorth` (`GameSession+Daily.swift:144`, `+Season.swift:113`, `+League.swift:344`). Two stale facts still in the tree: `HeirloomsStep.swift` prints "of 6 endings" and `Unlocks.earnedLooks` has six faces, so *Walked away* earns no look.

**Moment-to-moment.** `OfficeHitRegion.Kind` has six cases (`PixelKit/Office/OfficeHitRegions.swift:14`): person, coffee machine, whiteboard, door, founder's desk, bug. `OfficeTapDestination` maps the first five to sheets (a person's page, the coffee menu, the build or the new-product flow, hiring, the work schedule); the bug is the only tap the room finishes itself (`squashBug`, three a day, `Balance.json bugHunt.perDay`). Drawn but inert: the plant, the window, the game room, the cafeteria and the gym (`OfficeWaypoints.swift:6–20`), and the office-secrets clue props, which `OfficeCard.swift:87` draws *above* the scene. The home is worse: `HomeHitRegion.Kind` names the founder, the partner, each child, twenty fixtures and every decor slot with VoiceOver labels, and `HomeCard.swift:63` constructs `HomeSceneView` without `onTapRegion`, so on the Life tab the house is a picture; only `FurnishSheet` (:121) taps it, and only for slots. Every verb on a person is a list: 23 interaction rules × 6 kinds (`Interactions.json`), 4 instant activities, 10 weekend activities, 4 partner activities, 163 `GameAction` cases. The real-time layer is `SimSpeed` at 1/2/4 days a second plus the queue and rail; `DragGesture` appears in six app files (the decision sheet, the rail, the paywall, the newspaper, the divorce sheet, the incident room) and in no room. The five rooms with a grammar — pitch, courtroom, incident, feature board, inside — are all turn-based choice; during a build the player's only lever is the pace switch.

## Twenty candidates

| id | name | one line | size | reads | writes |
|---|---|---|---|---|---|
| A1 | Hand over the keys | Name a successor, keep a silent stake, and play on as them in the same company | L | walkAway gates, caretaker gate, Successors | founder swap, silent round, lineage, ledger |
| A2 | The for-sale sign | Name your price; rivals bid on a clock while the office reads the papers | M | rivals' valuation, standing, morale, poach | pendingBuyout (existing path), listing |
| A3 | Seating | Put people at desks; who sits next to whom moves skills, morale and the secret threads | M | traits, bond, secrets start conditions | company.seating, PixelKit seating |
| A4 | Sell up before the receiver | From the bankruptcy warning, take a distress price now instead of gambling the grace period | S–M | distress offer formula, daysInDebt | soldUp ending, ledger people |
| A5 | The all-nighter | Hold the whiteboard: the founder's points ×3 tonight, the body pays, bugs come with it | S | founder skills, energy, health | DevProgress, life meters |
| A6 | Draft the chapter | Keep four of the six goals dealt; the chapter opens on those four and the other two are gone | S–M | Goals.json, ProgressionState | draftedGoalIDs |
| A7 | The street | After the bell, an earnings call every quarter prices the company; dividends up, ousting down | M | epilogue, profit, valuation | Epilogue.premium/misses, wallet |
| A8 | The rooms answer | Every fixture at home opens the verb it stands for; the amenities take a paid break | S | HomeHitRegion, OfficeWaypoints, instant/partner activities | callBreak (new), tap routes |
| A9 | Keep this company | A finished daily, league week or season moves into a slot, unranked (it-12 A2) | S–M | detached stores | a slot, mode .custom |
| A10 | The name carries | A child successor inherits followers, notoriety and the nemesis; the employee starts clean (it-12 A3) | M | fame, crime, rival grudge at record | newGame deltas |
| A11 | Go back to the flag | Each chapter flag keeps a snapshot; branch from it into another slot, unranked | M | TimelineMarkers, SaveStore | chapter snapshots, a slot |
| A12 | Twists on the ladder | Rungs 11–15 are the five season twists as ranked handicaps | S | SeasonTwist, StakeLadder | rules.stake |
| A13 | Awards night is a room | Attend (an evening) and give the speech in the pitch grammar; winners' hype and a rival's standing move | S–M | AwardsJudge, PitchSystem | hype, reputation, rival strength |
| A14 | Clue props you can touch | The secrets' props become hit regions with the clue's line and the six responses | S | secrets.open.props | OfficeHitRegions, respondToSecret route |
| A15 | Sequel with fans | A hall product's sequel starts with carried hype and a raised bar (it-8 deferred) | S–M | HallEntry, codebase | starting hype, review expectation |
| A16 | The phone rings | Someone walks to your desk while the clock runs; answer in eight seconds for a bond bonus, or the queue takes it | M | QueueBoard, deskside waypoint | bond, queue defaults |
| A17 | Three questions for three modes | League scores valuation, season scores net worth × life/100, daily stays (it-12 B2) | S | valuation, LifeScore | posted score |
| A18 | Announce a number | Promise a valuation or a review score in print by a date; hype now, a slip in print later (J5's machinery) | S–M | Announce, valuation, reviews | hype, reputation, board pressure |
| A19 | Drag to assign | Drag a sprite onto the whiteboard or a desk instead of the picker | M | assign | nothing new |
| A20 | Darker scenarios | The hearing, the shark, out on parole, on the existing scenario machinery (it-12 B4) | S–M | Scenario, debug setups | scenario ledger |

Ranked by play added per engineer-day; the top eight follow.

## The top eight

### 1. Hand over the keys (A1, L, 4 days)

*"I gave Priya the company and 60% of it. I kept the rest and moved into the dynasty room. She has my rivals, my open case, and no board."*

**What the player does.** On the same gates as `walkAway` minus the two life gates (day ≥ 546, no debt, no board, somebody to hand it to), a second button beside *Walk away*: *Hand it to…*, listing every employee who passes the caretaker gate (`caretakerBlocker`: 26 weeks' tenure, bond 50). A stepper sets what the founder keeps: 10%, 25% or 50% of their holding. Confirm, and the same `GameState` carries on with the successor as founder.

**The two answers.** *Walk away*: the ending is ranked, the life-score board posts, the ledger records the founder's number, the next run is a clean seed. *Hand over*: the company survives with its standing, its products, its rivals' grudges, its open case and its debts; the run becomes `.custom` (unranked); the successor starts with a small wallet, a fresh life (single, studio flat, meters at their defaults) and a cap table that has the old founder on it — so *Still yours* is closed to them until they buy the emeritus stake back through the existing `buyBackRound`. Keep more and the outgoing founder's ledger net worth is higher; give more and the successor's IPO proceeds are.

**GameState.** `progression.founder` ← name, archetype (`Successors.archetype(for:)`), appearance seed of the successor; the founder's employee row leaves payroll and becomes a `Contact` with `leftReason: .formerCompany` and rapport = bond; the successor's row gets `isFounder = true`; `life` ← a new `LifeState` (wallet = 8 × their salary, derived); `investors.rounds` += a `RaisedRound` for the emeritus with `takesBoardSeat = false`, `patienceWeeks = 0`, a `.none`-shaped expectation, so `boardExpectations` (derived from seated rounds) ignores it; `equityRemaining` −= kept; `lineage` = `Lineage(kind: .employee, …)`; `mode = .custom`. Before the rewrite the app records a `LegacyRun` for the outgoing founder with ending `.walkedAway` and a new optional `successorEmployeeID`, so no eighth `EndingKind`, no new Game Center id, and the Dynasty tree already hangs the continuation under the old run by predecessor.

**Files.** `GameAction` (`handOverKeys(successorID:keptPercent:)`), `Reducer`, a new `HandOver.swift` beside `LifeScore.swift`'s walk-away, `Investors.swift` (the silent round), `Legacy.swift` (`successorEmployeeID`), `GameSession+Legacy.swift` (record without `gameOver`), `FounderBiographyView` / the walk-away sheet in `Life/LifeScore/`, `Successors.swift`, `DynastySheet.swift`, `SaveSummary+GameState.swift`.

**Identity.** A pure state rewrite on one action; no stream is read. No bot calls it.

**Old saves.** `successorEmployeeID` and the emeritus round decode as absent; the round's existing optional fields cover it.

**How it fails.** A handed-over company on day 600 with no board and a rich shelf is a company with nothing to do; the successor's first month is an empty inbox. Cheap check: hand over on `l3-family-day900` by debug flag and count queue items in the next four weeks. Under three, rivals read `lineage` as weakness — J3's studios treat new management as a boom crossing for one quarter.

### 2. The for-sale sign (A2, M, 2–3 days)

*"I hung the sign at 1.4× and it took nine weeks. Two people left and the launch went out cold. Meridian paid it."*

**What the player does.** On the Rivals or Investors view, *Put it up for sale* with an asking price from 0.8× to 1.6× today's valuation; *Take the sign down* any time. While it stands: every four weeks the strongest rival whose valuation is ≥ 1.5× yours (the strategic bar that `buyoutCheck` already uses) bids `valuation × (0.9 + 0.1 × weeks listed / 4)`, capped at the ask; no such rival, and only a liquidator's 0.5× arrives. A bid lands on the existing `pendingBuyout` path, so accept, decline and the earn-out all work unchanged; a bid at or above 1.0× is strategic (`.acquired`), below it is `.soldUp`.

**The two answers.** *Hang the sign*: a sale on your timetable, but people read the papers — morale −1 a week for everyone, poach chance ×1.5, launch hype ×0.9, +5 board pressure if there is a board, and the paper leads with it. *Wait*: keep the office calm and hope `buyoutCheck` rolls a strategic offer (40% a week, only when you already dominate a buyer by 1.5×), which arrives at the rival's number, not yours. The ask itself is the second decision: high means weeks of bleed, low means a fast exit for less.

**GameState.** `rivals.listing: SaleListing? { askingPrice, sinceDay, bids }`, encoded when set.

**Files.** `Rival.swift` (`RivalsState.listing`), `Systems/RivalSystem.swift` (a `listingCheck` beside `buyoutCheck`; `buyoutCheck` itself is untouched), `Systems/EmployeeSystem.swift` (the morale line reads the listing), `RivalSystem.poach` (the multiplier), `Marketing`/hype at launch, `GameAction` (`listForSale(ask:)`, `takeDownSign`), `Reducer`, `RivalsView.swift`, `InvestorsView.swift`, `NewspaperComposer.swift`.

**Identity.** `buyoutCheck` keeps drawing exactly as it does; the listing's bids are arithmetic on valuations already in state, so no stream moves. A run that never lists is byte-identical.

**Old saves.** `listing` decodes nil.

**How it fails.** The bid formula is visible on the rival profile, so the player sets the ask to the week-12 number and waits: the only decision is the bleed. That is enough only if the bleed bites. Cheap check: on `release-campus-day900`, list at 1.0×, 1.3×, 1.6× and count morale lost and people poached by the bid; if nobody leaves at 1.6×, raise the poach multiplier to ×2.

### 3. Seating (A3, M, 3 days)

*"The mentor sits by the junior or by the flight risk. I have one mentor."*

**What the player does.** Tap a person in the office, then a desk: *Move Priya to desk 4* (the manage sheet gets a Desk row as the accessible twin). Once any seat has been set, neighbours matter: a mentor beside somebody weaker trains them (`mentorSkillGain`-sized, weekly) and gives up 10% of their own output; a grumbler drags both neighbours −0.1 morale a day; two people with bond ≥ 60 beside each other gain bond and, in N5's machinery, are where the romance and clique threads start; the founder's neighbour gains bond weekly; the desk by the door is the one a poacher's recruiter sees first (+poach odds for whoever sits there).

**The two answers.** Seat for growth (mentor by the junior, output down, skills up) or for retention (mentor by the flight risk, bond up, nobody learns); spread the grumbler's damage or concentrate it on the person who can take it; cluster friends and invite the clique.

**GameState.** `company.seating: [UUID: Int]`, empty by default, encoded as a sorted array when non-empty.

**Files.** `Organization.swift`, `Systems/TraitSystem.swift` (adjacency effects), `Systems/OfficeSecretsSystem.swift` (start conditions read seats), `RivalSystem.poach` (door desk), `PixelKit/Office/OfficeBehaviors.swift` (`seating(for:)` honours the map, falls back to its rule), `OfficeCard.swift` / `OfficeTaps.swift` (move mode), `EmployeeManageSheet.swift`.

**Identity.** With `seating` empty PixelKit seats as today and every effect is zero. The pinned fixtures never set a seat.

**Old saves.** Decodes empty.

**How it fails.** The effects are too small to see, or the best arrangement is obvious and the feature is bookkeeping. Cheap check: on `release-studio-day400`, compute one mentor adjacency over 26 weeks; under 3 skill points, double it and make the mentor's output cost 20%, so the trade is visible on the Now card's ship date.

### 4. Sell up before the receiver (A4, S–M, 1.5–2 days)

*"Twenty-one days of grace. A contract paid on day 14, once. I sold on day 3 the next time and kept my name."*

**What the player does.** `.soldUp` exists but only a rival's distress roll reaches it. From the day cash goes negative (`bankruptcyWarning`, 21-day grace, `bankruptcyGraceDays`), the warning sheet and the money sheet carry *Sell up now*: the strongest rival buys at the distress fraction `buyoutCheck` already uses (`offerFractionMin…Max`, taken at the midpoint, no draw), or with no rivals a liquidator at 0.4×; the price falls 10% for each week of debt.

**The two answers.** *Sell up*: the run ends `.soldUp` today; the wallet, reputation and the address book are intact, and the ledger's people carry with their rapport. *Ride it*: the grace period might be saved by a launch, a contract, a term sheet or the receiver's call from the shop — and if it is not, bankruptcy's ledger people carry at rapport −20 (a new rule in `LegacyLedger.record`) and the post-mortem leads the biography. Every day of waiting also lowers the sell-up price.

**GameState.** None new; `.soldUp` and `lastBuyoutWasStrategic = false` already exist. The rapport haircut lives in the ledger's `record`.

**Files.** `Systems/RivalSystem.swift` (`distressPrice(state:)` extracted from `buyoutCheck`), `GameAction` (`sellUp`), `Reducer`, `Legacy.swift` (`record`: bankruptcy haircut), the warning entry in `QueueBoard`/`DecisionSheet`, `FinancesView.swift`, `PostMortem.swift` (a line: "sold on day N of 21").

**Identity.** Only on the action. `LegacyLedger.record` is called by the app, not by any pacing suite — verify with a grep of the test targets before touching it.

**Old saves.** Nothing new to decode.

**How it fails.** Selling always dominates because nothing ever saves a company in its grace period. Cheap check: over the ten pacing seeds, count bankrupt bots that took a cash event inside their last 21 days; under 2 in 10, the gamble is fake and the sell-up price should start lower (0.5×) so waiting is the only way to a better number.

### 5. The all-nighter (A5, S, 1 day)

*"Held the whiteboard. Ship date moved two days. Slept through Sam's birthday."*

**What the player does.** Long-press the whiteboard while a build is coding (the product sheet carries the same button). Tonight the founder's contribution to that build is ×3, energy −15, health −3, one of the day's two instant-activity slots is spent, affection −2 if partnered, and the extra points roll bugs at ×1.5. Refused under energy 30, on sabbatical, or twice in a day.

**The two answers.** Ship sooner at the body's expense — burnouts and hospital stays are what the life score's penalty counts and what a chronic condition grows from — or keep the evening and the health and let the ETA stand.

**GameState.** `life.allNighter: (productID, day)?`, encoded when set, consumed by the next tick's `applyDailyProgress`. Balance keys `allNighter.pointsFactor 3, energy 15, health 3, bugFactor 1.5, minEnergy 30`.

**Files.** `Life.swift`, `Systems/ProductSystem.swift` (`applyDailyProgress` reads and clears it), `Systems/LifeSystem.swift` (the meters), `GameAction` (`pullAllNighter(productID:)`), `Reducer`, `OfficeCard.swift` (the hold), `ProductDetailScreen.swift`, `Balance.json`.

**Identity.** Only on the action; the extra points draw extra bug rolls from `state.rng` only in a run where the founder pulled one.

**Old saves.** Decodes nil.

**How it fails.** On a campus the founder's points are a rounding error and the verb is garage-only. Cheap check: the founder's share of daily points on the three release fixtures; under 10% on the studio, make it the assigned crew's night instead (their morale −3 each, their points ×1.5).

### 6. Draft the chapter (A6, S–M, 1.5 days)

*"Six on the table. I dropped 'Weather three crashes' and 'Form a department'. Then the crash came anyway."*

**What the player does.** When a chapter opens, its goals are dealt face-up and the player keeps four (chapters with four or fewer on the track keep all). The chapter opens only when the kept four are done; the dropped goals and their rewards are gone for the run.

**The two answers.** Keep the perk goal (eight goals carry a perk) and risk a chapter that stalls on it, or keep the four you can already see the way to and forgo the perk. Today all six are live and any four open the chapter, so there is nothing to weigh.

**GameState.** `progression.draftedGoalIDs: [String]`, encoded when non-empty; `ProgressionSystem.advanceChapter` requires all drafted goals when the list is non-empty, else today's rule.

**Files.** `Progression.swift`, `Systems/ProgressionSystem.swift`, `GoalsCard.swift` (the deal), `NowCard.swift`, `GameAction` (`draftGoals(ids:)`), `Reducer`.

**Identity.** Bots never draft; an undrafted chapter is today's chapter.

**Old saves.** Decodes empty; a run mid-chapter simply is not drafted.

**How it fails.** Players always drop the two hardest and the draft is a formality. Cheap check: per chapter, mark which goals the three release fixtures have already met; if four of six are met on arrival in every chapter, deal the draft at the chapter's *start* only and pay a reputation bonus for finishing a drafted perk goal.

### 7. The street (A7, M, 2–3 days)

*"Rang the bell, stayed as CEO. Beat the number twice, missed it three times, and the shareholders showed me the door. The ledger says Replaced."*

**What the player does.** After `.ipo`, *Keep running it* now means something: every 13 weeks an earnings call sets the number — profit ≥ 0.9 × the trailing four-quarter average (arithmetic, no draw). Beat it and the public premium on valuation rises 5% and a dividend of 2% × valuation × your equity lands in the wallet; miss it and the premium falls 10% and the paper leads with it; three misses in a row and the ending is rewritten to `.oustedByBoard` — "the shareholders replaced you" — which is what the ledger then records. *Still yours* keeps its quiet epilogue.

**The two answers.** Ring the bell and go — the IPO board posts, the ledger records Public, the run is over — or stay: the founder's net worth can keep growing (dividends and premium both read into `founderNetWorth`), and the same street can take the headline off you.

**GameState.** `Epilogue.premium: Double = 1`, `Epilogue.consecutiveMisses: Int = 0`, `Epilogue.lastCallDay: Int?`, all encoded when non-default.

**Files.** `RunMode.swift` (the struct), `Systems/InvestorSystem.swift` (the early return at :38 gains the epilogue branch), `Investors.swift` (`companyValuation` reads the premium inside an epilogue), `InvestorsView.swift` (the street card replaces the empty board), `NewspaperComposer.swift`, `FounderBiographyView.swift` (the button's copy says the price).

**Identity.** Runs only when `epilogue != nil`, which no bot ever sets.

**Old saves.** The three fields decode to their defaults; an epilogue already running gets its first call 13 weeks after load.

**How it fails.** The number is unreachable by quarter four and the street is a timer. Cheap check: run the investor bot on `release-campus-day900` past a forced IPO and log eight quarters of profit; if a 0.9× trailing average is missed three times running by quarter six, widen it to 0.8×.

### 8. The rooms answer (A8, S, 1–1.5 days)

*"Tapped the fridge. Tapped the kid. Tapped the game room and lost an afternoon."*

**What the player does.** `HomeCard` passes `onTapRegion`: founder → the Today grid as a sheet; partner → the people menu (`.partner`); a child → their menu; bed → the work schedule; couch and television → cinema; fridge, stove and dining table → restaurant; dumbbells and yoga mat → gym session; suitcase → the sabbatical sheet; crib → the family card; laundry, takeaway and the dead plant → the meters card with the signal's line; a decor slot → furnish. In the office the plant becomes the desk's "one tap", the window opens the city map, and the game room, cafeteria and gym take one new verb, *Call a break*: everyone's morale +3 (the gym also +5 founder energy), today's build progress ×0.5, once a week, only with that amenity built.

**The two answers.** For the break: a morale point today against half a day on every build in flight — cheap on a quiet week, dear inside a ship window. For the home: the same decisions as the grid, in the room the game already draws; the grid then becomes the sheet the room opens, which is V1's own next step for the Life fold.

**GameState.** `company.lastBreakDay: Int?`, encoded when set.

**Files.** `HomeCard.swift`, `PixelKit/Office/OfficeHitRegions.swift` (+plant, window, amenity regions at the waypoints' positions), `OfficeTaps.swift`, `GameAction` (`callBreak(amenity:)`), `Reducer`, `Systems/EmployeeSystem.swift`, `Systems/ProductSystem.swift` (the day's factor), `Balance.json` (`amenities.break*`).

**Identity.** Taps route to existing actions; the break is only on the action.

**Old saves.** Decodes nil.

**How it fails.** Two homes for one thing (the grid and the room) breaks the repo's rule, and +3 morale is free against half a day. Cheap check: none for the first — fold the grid into the sheet; for the second, tune on `release-studio-day400`: if a weekly break never moves the ETA sentence on the Now card, make it a full day at ×0.

## Cut, and why

- **Decor with effects** (trophies, posters, the loft pack). The loft pack says "No effect on anything" (`HomeDecor.swift:363`) and the paywall promises nothing bought reaches a board; earned decor with effects is a reward, not a mechanic.
- **Bugs that escape** (unsquashed bugs become live bugs at ship). Punishes the ×4 clock the game sells; the hunt is "a treat, not a strategy" by design.
- **The office plant that grows with a streak.** Cosmetic, no decision.
- **Remaster** (a Hall product as a fourth heirloom, it-12 A5). Unranked is not a felt cost; the Hall stays a list until something else uses it.
- **Wagers on *Beat my company*.** Needs a server the container does not have.
- **Choose your daily** (three seeds a day). More surface, the same question.
- **An eighth `EndingKind`** for hand-over or wind-down. A new raw value is a forward-compat break for an older app reading a newer save; both ideas reuse `.walkedAway` and `.soldUp`.
- **Drag to assign** kept in the table but not the eight: the same decision as the picker with a new gesture, and PixelKit gesture work is a lane on its own.
- **The phone rings** (real-time deskside interrupt) kept in the table but not the eight: a bonus for attention is pure upside for the attentive and the queue already carries the deadline.
- **A twist picker on the custom page.** Unranked preference, no cost; the ladder rung (A12) is the version with a board behind it.
- **Pick your morning tap.** The desk's "one tap" is prescribed; letting the player choose praise or coffee costs nothing either way.
- **Move the coffee machine.** Arranging furniture with no effect is a screen with no decision; seating (A3) is the version that reads other systems.
- **A "retire rich" ending inside the epilogue.** *Walked away* already is that, and the street (A7) gives the epilogue its own exit.
- **Coach tips, "of 6 endings", the seventh look, "What comes next".** Real, small, and not playable; the two stale facts are a one-line fix each to bundle into whichever lane touches `HeirloomsStep` and `Unlocks`.

## Could not verify

No simulator run was made: every claim above is a count from code (`OfficeHitRegions.Kind`, `HomeCard`'s `HomeSceneView` call, `Interactions.json`, `Goals.json`, the three score lines). The founder's share of daily build points on the release fixtures (A5's check) and whether any pacing bot's last 21 days contain a cash event (A4's check) were not measured; both are the first thing their lanes should run.
