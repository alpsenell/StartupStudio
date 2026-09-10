# Iteration 13 — the shop (in-app purchases)

*PM spec, read-only pass over `iteration-12` @ 22c599a. The owner's brief: "add in-game purchase options — users can buy extra money and some more features like that."*

**Where I disagree with the brief.** "Extra money" is the one product this game can least afford to sell carelessly: the whole company loop is runway, and the ranked boards score `founderNetWorth`, which is wallet + assets + a slice of `companyValuation`, which starts from `company.cash − loanBalance` (`GameState.swift:1496`). So cash is sold here, but sized in *weeks of burn*, capped, and it makes the company unranked the way an heirloom does. The money that will not hurt the game — and I think will sell better — is the second chance after a bankruptcy, the fourth slot and the decor pack. The spec builds all of it; the ranking is by fit.

---

## 0. What the shop rests on (read, not inherited)

- One product exists: `com.alpsenel.startupstudio.fullgame`, non-consumable, $4.99, StoreKit 2 in `App/Sources/Store/Entitlements.swift`. Chapter 1 is free; daily, scenario, season and league are free in every chapter (`UnlockRule.allows`). Restore is `AppStore.sync()` behind a paywall link and a Settings row.
- `Entitlements.updates()` **finishes every verified transaction it sees** ("Finish everything verified, whether or not it is ours"). That line must change: a consumable finished before it is applied is money taken for nothing.
- `PaywallSheet.swift:123` prints "One purchase. No subscription, and nothing else in the game is for sale." The iteration-12 cut list refused a cosmetic store on that line. The owner has changed the decision; the line is rewritten in §6.
- There is no "add cash" action. Money enters through `FinanceSystem.post(amount:category:label:)` — one ledger line, `company.cash += amount`. Loans (`takeLoan`, `takeSecuredLoan`) are the only outside money today and they post `"Loan drawdown"` under `.other`.
- Weekly burn (`GameEngine.weeklyBurn`) = `weeklyOperatingCost` 250 + office rent + payroll + founder salary + amenity upkeep. From the bundled fixtures:

  | Fixture | Day | Tier | Cash | Burn/wk | Starting cash (Normal) |
  |---|---|---|---|---|---|
  | `release-garage-day40` | 40 | garage | $11,750 | **≈$450** | $12,000 (Hard $6,600, Easy $18,000) |
  | `release-studio-day400` | 400 | studio | $90,875 | **≈$19,600** | |
  | `release-campus-day900` | 900 | campus | $644,446 | **≈$79,000** | |

  A flat $50,000 is two years in the garage and four days at the campus. Every cash figure below is therefore `weeks × max(burn, $2,000)`, with a cap.
- Bankruptcy: cash negative for more than `bankruptcyGraceDays` (21; Easy 28, Hard 11) → `state.gameOver = GameOverInfo(kind: .bankruptcy)`. Before that the bank has already called the founder's guarantee (savings, then the house) — that stays called.
- On `.gameOver` the app records the run into the `LegacyLedger` once (`GameSession+Legacy.swift:51`, keyed seed+day+company), inducts hall entries, posts the ending achievement and — if `state.isRanked` — the ranked boards (`GameSession+GameCenter.swift:52`). Bankruptcy posts only the life-score board.
- "Try that year again" is a replay from the seed, not a snapshot. There is no autosave before an ending to roll back to; a second chance has to *repair* the ended state.
- Ranking: `GameState.isRanked = mode.isRanked && heirloom == nil` (`Legacy.swift:550`). Standard, daily, season and league are ranked modes; custom and scenario are not. **Daily, season and league submit their score without reading `isRanked`** (`dailyRunChanged`, `seasonRunChanged`, `leagueRunChanged` all post `founderNetWorth` unconditionally while the period is open) and record a ghost that other players' runs replay.
- Stake 2, "No credit", refuses `.takeLoan`/`.takeSecuredLoan` in `StakeLadder.refuses` (`Stakes.swift:86`). A stake-only run is still ranked.
- Saves: three slots (`SaveStore.defaultSlotCount = 3`), one iCloud KVS key per slot, LZFSE-compressed, 900 KB cap per key. The 334 KB campus fixture compresses to ~70 KB, so a fourth key fits.
- Home decor: `HomeDecor.catalog = shopItems + earnedItems + assetItems` with a `DecorSource` (`shop`, `free`, `season`, `ending`, `award`, `hall`, `streak`, `asset`). Availability is `life.possessions` for shop items and `ledger.availableDecor` for the rest (`DecorPresentation.available`). Decor has no stat effect. 56 sprites in `PixelKit/HomeDecorSprites.swift`.
- Candidates are rolled from `state.rng` (`EmployeeSystem.swift:~808`) — names, role, skills, salary jitter, appearance. Anything the shop adds to the pool must not touch that stream.
- Repo rules: no new tests (CLAUDE.md); the byte-identical suites (`FullLoopDeterminismTests`, `LegacySaveCompatibilityTests`, the release fixtures) must hold, so every new field encodes only when non-default.

---

## 1. The catalog

Ranked by fit with the game's tone and by how little each can make the game worse. All ids under `com.alpsenel.startupstudio.`; prices are the US price points the owner picks in App Store Connect — the app never hardcodes them (`Product.displayPrice` only).

| # | Product id (suffix) | Type | Working name | Grants | US price |
|---|---|---|---|---|---|
| 1 | `secondchance` | Consumable | **The receiver's call** | Reverses a bankruptcy ending once per company: the overdraft is written off, four weeks of burn go in, the loan and the guarantee stay, reputation −5, the run is unranked from here | $2.99 |
| 2 | `slot4` | Non-consumable | **A fourth slot** | A fourth save slot on the front door, synced like the other three | $0.99 |
| 3 | `decor.loft` | Non-consumable | **The loft pack** | Six home decor items for the flat (two wall, two shelf, two floor). No effect on anything | $1.99 |
| 4 | `cash.month` | Consumable | **A month of runway** | `4 × max(weeklyBurn, $2,000)`, capped at $250,000, into company cash. Unranks the company | $1.99 |
| 5 | `cash.quarter` | Consumable | **A quarter of runway** | `13 × max(weeklyBurn, $2,000)`, capped at $1,000,000. Unranks the company | $4.99 |
| 6 | `veteran` | Consumable | **A veteran** | One lead-level candidate joins the hiring pool, both traits shown, at 1.4× the salary their skills would fetch. Shown *before* you buy. Unranks the company | $2.99 |

What each pack is worth where (Normal):

| | Garage (burn $450) | Studio ($19.6k) | Campus ($79k) |
|---|---|---|---|
| A month | $8,000 (floor) | $78,400 | $250,000 (cap) |
| A quarter | $26,000 (floor) | $254,800 | $1,000,000 (cap) |
| Receiver's call | overdraft → 0, +$8,000 | overdraft → 0, +$78,400 | overdraft → 0, +$250,000 |

Why the floor: a garage founder's honest month is $1,800, which is not a product. $8,000 is two thirds of a Normal start — enough to matter, not enough to skip the garage. Why the cap: a campus quarter uncapped is $1.03M against an IPO valuation floor of $5M; capped at $1M it is still large, but the run is unranked and the IPO also needs three profitable quarters and a subscription product. The quarter is the item to watch (see §1.1).

Why the veteran is shown before purchase: a candidate rolled after the money changes hands is a randomised item, which is loot-box territory under guideline 3.1.1. So the hire sheet shows *the* veteran available this fortnight — name, face, role, skills, both traits, salary — derived deterministically from `(seed, day / 14)`, and the purchase adds exactly that person to the pool. The offer rotates with the pool.

### 1.1 Rejected products (the cut list)

- **One-time debt write-off.** It is a cash pack whose size the player chose by borrowing, and the bank/house rule is the best decision the money system has. Duplicates `cash.*`; cut.
- **Quiet quarter (story pauses go to the rail).** The pause budget already rations non-critical stops to one per 10 days (`pauseBudgetDays`); what is left are questions with deadlines that answer for you. Selling their silence sells the story's second acts for a speed-up, and the README brags about the rail. Cut.
- **Skipping a build phase.** Design/code/polish with focus *is* the Products loop. Pure upside inside the core decision; cut.
- **Office look / palette pack.** The office palette lives in `RoomBuilder.wallColor(tier:…)` per tier with no selection model. New subsystem for a cosmetic; the home already has a furnish system with slots, sprites and sources, so the cosmetic pack goes there. Cut in favour of `decor.loft`.
- **Founder looks.** The 24 looks are free and the seven extra faces are *earned* by endings (`Unlocks.earnedLooks`). Selling what others earn is the wrong pattern; cut.
- **Cash for the wallet (founder's personal money).** The wallet buys the house, which secures the loan, which is the guarantee rule. It would route around the salary-band decision. Cut; company cash only, and the salary stepper stays the one pipe to the wallet.
- **Anything timed, bundled, "limited", or a currency.** Dollars are dollars; every item shows one price and does one thing.

---

## 2. Ranked-mode rules

**Recommendation: both, split by mode.**

1. **Daily, season, league: the shop is closed, and the button says why.** Three reasons, any one sufficient: those paths submit `founderNetWorth` without consulting `isRanked`; each run leaves a `GhostLog` that tomorrow's players race against, so bought money would poison somebody else's field; and the modes are free in every chapter, so there is nothing fair to sell. Flipping them to unranked would need three new submission guards plus ghost suppression for a product that undermines the mode.
2. **Standard: an economy purchase flips the company to unranked, permanently.** `GameState.isRanked` becomes `mode.isRanked && heirloom == nil && !purchases.affectsRanking`. This is the heirloom rule the player already knows ("a company that carries one never posts to the leaderboards", `HeirloomsStep.swift:37`). Achievements are unaffected, as they are for custom companies. Cosmetics and the slot never touch a run.
3. **Custom and scenario: already unranked**, cash and the veteran are allowed. **The receiver's call is not offered in a scenario** — a scenario's failure is its recorded outcome (`GameSession+Scenario.swift:146`), and reversing it means un-recording a ledger line the front door already shows.
4. **Stake 2 or higher ("No credit"): cash packs and the receiver's call are refused**, through the existing `StakeLadder.refuses` arm, so a stake keeps meaning what it says.

**Copy.**

- Shared company (daily/season/league), the button, disabled: **"Not in a shared company"**. Footnote: *"Today's company is the same for everyone, and your year leaves a ghost for the next player. Money from outside it would be a different game. The shop opens in a company of your own."*
- Stake, disabled: **"Not at this stake"**. Footnote: *"Stake 2, No credit: the bank won't lend, and neither will we."*
- Standard, above the two cash buttons, always visible: *"Bought money makes this company unranked — no leaderboards from here on, like an heirloom. Achievements, the ledger and the Hall of Fame carry on."*
- The first economy purchase in a ranked run, one `confirmationDialog` before StoreKit's sheet: title **"Leave the boards?"**, message *"\(company) stops posting to leaderboards from today. Achievements still count."*, buttons **"Buy and leave the boards"** / **"Cancel"**. Once per company; never again after the run is unranked.
- Slot summary on the front door, once unranked: the same `Unranked` glyph the heirloom runs carry today, if `SaveSummary` has one; if it does not, one word after the day: "Day 412 · Unranked".

---

## 3. Engine design

Everything in `Packages/TycoonEngine/Sources/TycoonEngine/Purchase.swift`, one new action arm in `Reducer.apply`, one new event, one new field on `GameState`.

### 3.1 Types

```swift
/// What a purchase grants, in game terms. No prices, no product ids: the
/// engine does not know the store exists.
public enum PurchaseKind: Codable, Equatable, Hashable, Sendable {
    /// `weeks` is 4 or 13 today; the amount is computed from state, not carried.
    case cash(weeks: Int)
    case secondChance
    case veteran
}

/// One applied transaction. `transactionID` is StoreKit's `Transaction.id`.
public struct PurchaseGrant: Codable, Equatable, Hashable, Sendable {
    public var transactionID: UInt64
    public var kind: PurchaseKind
    public var day: Int
    /// Dollars posted, for the biography's money card. 0 for the veteran.
    public var amount: Int
}

/// The run's record of bought things. `.empty` on every run that never
/// bought anything, encoded only when it is not.
public struct PurchaseLog: Codable, Equatable, Sendable {
    /// Sorted by `transactionID`, so identical states encode identically.
    public var grants: [PurchaseGrant] = []
    /// The day the receiver's call was taken; one per company.
    public var secondChanceDay: Int? = nil
    public static let empty = PurchaseLog()
    public var isEmpty: Bool { grants.isEmpty && secondChanceDay == nil }
    /// Cash, the veteran and the second chance all unrank; nothing else exists here.
    public var affectsRanking: Bool { !isEmpty }
    public func contains(_ id: UInt64) -> Bool
}

/// The one rule the UI and the reducer share, so a button is never shown
/// for a purchase the reducer would refuse.
public enum PurchaseRule {
    public static func allows(_ kind: PurchaseKind, state: GameState) -> Bool
    /// Why not, in one line, or nil.
    public static func refusal(_ kind: PurchaseKind, state: GameState) -> String?
    /// What `.cash(weeks:)` would post right now.
    public static func cashAmount(weeks: Int, state: GameState, balance: BalanceConfig) -> Int
    /// The veteran on offer this fortnight, or nil while the pool is empty.
    public static func veteranOnOffer(state: GameState, balance: BalanceConfig, content: ContentCatalog) -> Candidate?
}
```

`GameAction`: `case applyPurchase(kind: PurchaseKind, transactionID: UInt64)`, in its own `// MARK: Iteration 13 — P1 (purchases)` region. `GameEvent`: `case purchaseApplied(kind: PurchaseKind, amount: Int, day: Int)`, severity `.info` (feed and journal; never a pause).

`GameState.purchases: PurchaseLog = .empty`, decoded with `decodeIfPresent … ?? .empty`, encoded only `if !purchases.isEmpty` — exactly the `ghosts`/`incidents` pattern, so a pacing bot's save and every fixture are the bytes they were.

`weeklyBurn` moves to `GameState.weeklyBurn(balance:)`; `GameEngine.weeklyBurn` becomes a one-line delegate. Same formula, so it is an identity refactor.

### 3.2 `PurchaseRule.allows`

| Kind | Requires |
|---|---|
| any | `mode` is not daily/season/league; `!purchases.contains(transactionID)` (checked in the reducer, not the rule) |
| `.cash` | `gameOver == nil`; `rules.stake < 2` |
| `.veteran` | `gameOver == nil`; `candidatePool` is non-empty (the pool exists); the veteran is not already in the pool or on the roster |
| `.secondChance` | `gameOver?.kind == .bankruptcy`; `purchases.secondChanceDay == nil`; `!mode.isScenario`; `rules.stake < 2` |

### 3.3 The reducer arm

`.applyPurchase` is handled **before** the `gameOver == nil` guard, next to `.continueAfterEnding`, because the second chance is only legal on an ended game. Then:

1. `guard !state.purchases.contains(transactionID)` → `[]`. A replayed transaction grants nothing, returns no events, and the session finishes it anyway (§4).
2. `guard PurchaseRule.allows(kind, state)` → `[]`.
3. Apply:
   - **`.cash(weeks)`**: `amount = PurchaseRule.cashAmount(…)`; `post(amount:, category: .other, label: "App Store · a month of runway")` (or "a quarter of runway"). Same `post` helper `takeSecuredLoan` uses, so the ledger, the weekly report's money-in and `FinancesView` all show it without new code.
   - **`.secondChance`**: `company.cash = max(company.cash, 0)`; the write-off is its own ledger line: `"App Store · overdraft written off"` for `−cash` if cash was negative; then `post(amount: cashAmount(weeks: 4), label: "App Store · the receiver's call")`; `company.daysInDebt = 0`; `company.reputation = max(0, reputation − 5)`; `gameOver = nil`; `economy.pauseEvents = []`; `speed = .paused`; `purchases.secondChanceDay = day`. Nothing else is touched: the loan, the guaranteed amount, the resignations, the board, the taken house all stand. `epilogue` stays nil — the company has not "played past an ending", it has been pulled back before one.
   - **`.veteran`**: `let c = PurchaseRule.veteranOnOffer(…)`; `candidatePool.append(c)` with the reveal flag set so both traits show and the interview day is not needed. Salary 1.4× the pool's formula for those skills. The candidate is derived from a private `SeededRNG(seed: state.seed ^ (UInt64(state.day / 14) &* 0x9E3779B97F4A7C15))` through a refactored `EmployeeSystem.rollCandidate(role:ceilings:rng: inout SeededRNG)` that the pool builder itself calls with `&state.rng` — so `state.rng`, `worldRNG`, `investorRNG` and `socialRNG` advance by nothing. Skills roll at the tier's ceiling + 15, clamped to 95.
4. Append `PurchaseGrant`, keep `grants` sorted, emit `.purchaseApplied`. The session's `engine.send` autosaves on a non-empty return, so the grant is on disk before `transaction.finish()`.

Bots and fixtures never send `.applyPurchase`: `ProgressionBots`, `RivalFightBots`, `BoardBot`, `OriginBot`, `FixtureGenerator`, `ReleaseFixtureGenerator` and the determinism script are untouched. `PurchaseLog.empty` encodes nothing. Both facts together are what keeps the suites green with no new tests.

### 3.4 How the second chance rewinds an ending, app side

The post-mortem screen (`GameOverView` → `FounderBiographyView`, bankruptcy only) is the entry point. On a verified transaction the session:

1. `engine.send(.applyPurchase(kind: .secondChance, transactionID:))`. `gameOver` clearing dismisses the ending cover by itself (the cover's binding reads `engine.state.gameOver`, `AppRootView.swift:487`), and `engine.send` restarts nothing because the action left `speed = .paused`.
2. Removes the ledger entry the bankruptcy wrote: `ledger.runs.removeAll { $0.seed == seed && $0.day == day && $0.companyName == name }`, then `saveLedger()`. **`endingsReached` keeps `.bankruptcy`** — you did go bankrupt; the receiver's letter stays framed on the shelf (the ending trophy decor and the earned look stay earned). Hall inductions stay: the products were real.
3. Game Center: the bankruptcy achievement and the life-score post already went out and cannot be recalled. The run is unranked from here, so its eventual ending posts no board. Stated in the button's copy so nobody feels tricked.
4. Rail line on return (a `.pause` kind carrying the `purchaseApplied` event as the headline, one time): *"Back from the receiver. Four weeks of cash; the loan is still yours."*

---

## 4. StoreKit 2 flow

New files under `App/Sources/Store/`: `ShopCatalog.swift` (ids, kinds, which are consumable), `ShopClient.swift` (the StoreKit actor, behind a `ShopSource` protocol so the session tests' fake pattern holds), `ShopState.swift` (prices, owned non-consumables, last message), and `GameSession+Shop.swift`.

### 4.1 Consumables (cash, second chance, veteran)

```
tap → PurchaseRule.allows (UI already checked) → [first time in a ranked run: confirmationDialog]
    → Product.purchase()
    → .success(.verified(tx))   → session.applyGrant(tx)  → tx.finish()
    → .success(.unverified)     → message; nothing granted; not finished
    → .pending (Ask to Buy)     → message "Waiting for approval…"; the grant arrives via updates
    → .userCancelled            → nothing
```

`applyGrant(tx)`:
1. Map `tx.productID` → `PurchaseKind` via `ShopCatalog`. Unknown id → finish and ignore (an old build's product).
2. If a game is open and `PurchaseRule.allows(kind, state)` → `engine.send(.applyPurchase(kind:, transactionID: tx.id))`. Applied (events non-empty) **or already in `purchases`** → `await tx.finish()`.
3. Otherwise the transaction stays **unfinished** and its id goes into `ShopState.parked: [UInt64]` (UserDefaults). The rule: a cash pack belongs to the company that was open when it was bought; if that company cannot take it right now (it ended between tap and verify, or the app was killed) it waits, and is applied to the next company that can. The front door's shop row shows *"1 purchase waiting for a company"*.
4. `Transaction.unfinished` on launch and `Transaction.updates` both route through `applyGrant`. **The existing `updates()` listener stops finishing everything it sees**: it finishes `fullgame` and the non-consumables (idempotent by nature) and hands consumables to `applyGrant`.

Idempotence is two-layered: the engine refuses a repeated `transactionID`; the session finishes on "already granted" so an unfinished duplicate stops being redelivered.

No restore for consumables. "Restore purchases" copy says so (§5).

### 4.2 Non-consumables (the slot, the loft pack)

`Transaction.currentEntitlements` → `ShopState.owned: Set<String>`, kept current by `updates` and by the existing `restore()` (`AppStore.sync()`). Revocation (`revocationDate != nil`) removes ownership: the fourth slot becomes read-only-until-restored (the save is never deleted — the same "re-lock the clock, not the file" rule as the unlock), the pack's items stay placed in any save that has them but can no longer be placed anew. `DecorPresentation.available(life:ledger:)` gains an `owned: Set<String>` parameter and a `DecorSource.purchased` case ("Bought from the App Store").

### 4.3 The slot

`SaveStore` is built with `slotCount: 4` always (the `let` is fixed at init; `-autoChapter` uses `slotCount − 1`, so the DEBUG fixture moves to slot 4 — note it in the screenshot list). `TitleScreen` shows row 4 locked with the price while unowned; `CloudSync` iterates the store's count, so `slot3` is a fourth KVS key. The slot-replace dialog lists it only when owned.

### 4.4 `StartupStudio.storekit`

Add six entries alongside `fullgame`:

| referenceName | productID | type | displayPrice |
|---|---|---|---|
| Second chance | `com.alpsenel.startupstudio.secondchance` | Consumable | 2.99 |
| Fourth slot | `com.alpsenel.startupstudio.slot4` | NonConsumable | 0.99 |
| Loft pack | `com.alpsenel.startupstudio.decor.loft` | NonConsumable | 1.99 |
| Cash — month | `com.alpsenel.startupstudio.cash.month` | Consumable | 1.99 |
| Cash — quarter | `com.alpsenel.startupstudio.cash.quarter` | Consumable | 4.99 |
| Veteran | `com.alpsenel.startupstudio.veteran` | Consumable | 2.99 |

`familyShareable: false` on all. Localizations (en_US) carry the display names in §1 and one-sentence descriptions; the same strings go into App Store Connect so the local config and the store agree.

### 4.5 App Store Connect, by hand (the owner)

1. Monetization → In-App Purchases → create six products with the ids, types and reference names above. Consumables cannot be changed to non-consumables later; check the type before saving.
2. Price schedule per product (the tiers in §1), then the display name and description per locale (en-US first).
3. One review screenshot per product (the money sheet card for the two cash packs, the post-mortem for the second chance, the hire sheet for the veteran, the furnish sheet for the pack, the front door for the slot). Review notes: "Chapter 1 is free; the shop is on the money sheet (tap the cash in the HUD). A bankruptcy for the second chance takes ~25 minutes on Hard — or use the `Continue` slot on the attached fixture, which is one day from it." → the lane needs a `release-bankruptcy-day…` fixture for that.
4. Attach all six to the version's In-App Purchases section before submitting the build (they are reviewed with the binary the first time).
5. Confirm the Paid Applications agreement and banking are still active; a sandbox tester; Ask to Buy tested on a child sandbox account for one consumable.
6. Keep `App/StoreKit/StartupStudio.storekit` out of the release scheme (`project.yml` run action only), as the iteration-7 checklist already says.

---

## 5. Where it surfaces

- **The money sheet** (`Components/MoneySheet.swift`, opened from the HUD cash pill and the three "See all money" links). A fourth card after *Bank*: **"The App Store"**, with two rows — *A month of runway · +$78,400 · $1.99* and *A quarter of runway · +$254,800 · $4.99* — the granted amount computed live from `PurchaseRule.cashAmount`, the price from `displayPrice`, the unranking line above them, and the refusal footnote from §2 when disabled. Nothing on the card animates or badges.
- **The post-mortem** (`Screens/Endings/FounderBiographyView.swift`, bankruptcy only, under the three "what went wrong" facts and above *Try that year again*): one button **"Take the receiver's call · $2.99"** with the copy: *"The overdraft is written off and a month of cash goes in. The loan is still yours, so is whatever the bank already took, and the trade press will remember. From here the company is unranked."* Hidden when `PurchaseRule.refusal(.secondChance)` is non-nil (already taken, a scenario, a shared company, a stake).
- **The hire sheet** (Team → Hire): a last row under the pool, **"A veteran"**, drawn as a normal candidate card with both traits and the salary, with the price where *Interview* would be. Tapping buys; the card moves into the pool. Disabled with the §2 reasons in shared companies.
- **The furnish sheet** (`Screens/Life/Decor`): the six pack items greyed with one price on the section header, **"The loft pack · $1.99"**, when unowned; the source caption "Bought from the App Store" when owned.
- **The front door** (`TitleScreen`): the fourth slot row, locked, *"A fourth slot · $0.99"*. That row and the parked-purchase line are the only shop presence on the title screen.
- **The paywall** (`Store/PaywallSheet.swift`): rewritten pitch (§6). No shop items on the paywall — it sells the chapters.
- **Settings** (`HQ/SettingsSheet.swift`): *Restore purchases* stays; its alert now names what was restored ("The full company, a fourth slot and the loft pack are yours on this Apple ID." / "…Cash and second chances don't restore — each is used once."). A **"Purchases"** row beneath it listing what is owned and, per open company, what it bought (from `purchases.grants`), so the honesty is inspectable.
- **The biography's money card**: one line when `purchases.grants` is non-empty — *"Bought in: $332,400 over 2 purchases."* The record says what happened.

**Anti-nag rules** (pinned in `ShopPresentation`, a pure function like `PaywallPresentation`, so a table can hold it):

1. Never on the notice rail: `NoticeRail.Kind` gets no shop case, and the `.pause` line for `bankruptcyWarning` never mentions money for sale.
2. Never a pause: `purchaseApplied` is `.info`; no shop event is `.notable` or `.critical`.
3. Never a coach tip: `TipStrip`/`CoachTip` gets no shop entry.
4. Never self-presenting: unlike the paywall, no shop sheet ever opens on its own — not at a bankruptcy warning, not at runway < 4 weeks, not on the ending screen, not on launch.
5. Never in the weekly report, the tour, the morning desk, the journal, a toast or a push notification.
6. No badges, dots, counters, countdowns, "limited", "offer", "best value", sale strikethroughs, or a price anywhere the HUD is drawn.
7. One price per item, in the storefront's own currency string, next to the thing it buys, and the thing said in dollars before the tap.

---

## 6. Honesty and store rules

**The paywall line** (`PaywallSheet.swift:123`), rewritten:

> One purchase for the chapters. There is a small shop besides — a month of cash, a second chance after a bankruptcy, a fourth save, a few things for the flat — and nothing in it is needed to finish the game, and nothing bought reaches a leaderboard. Your save is exactly where you left it either way.

The README's "Investors, boards and endings" paragraph and `docs/release/testflight.md` gain one sentence each saying the same.

**Guidelines that apply.**

- **3.1.1 In-App Purchase**: every item goes through StoreKit; no links out, no codes, no alternative prices. The app displays `Product.displayPrice` and never a hardcoded figure. Restore is offered for non-consumables (existing row); consumables are explicitly described as one-use.
- **3.1.1 randomised items**: does not apply, and the veteran is designed so it cannot — the exact candidate is shown before the purchase. The cash figure is computed and shown before the purchase. Nothing in the shop is a draw.
- **3.1.2 subscriptions**: none. Keep it that way in copy ("No subscription" stays true).
- **2.3 accurate metadata**: the store descriptions say "unranks the company" on the three economy items, because the App Store listing must not promise what the game then withholds.
- **5.1.1 / 1.3 kids**: the game is rated for simulation with infrequent alcohol references; it is not a Kids Category app, so Ask to Buy is the OS's job (`.pending` is handled and worded). Our side is no dark patterns: no countdowns, no repeat prompts, no currency abstraction that hides the dollar price, one tap buys one thing, and the confirmation dialog in §2 is *added* on the first ranked purchase, not removed. A consumable cannot be bought from the ending screen twice: the second chance disappears after one.
- **Refunds**: a refunded consumable is not clawed back from the save (Apple's model; the money was spent in a game world). A refunded non-consumable revokes through `revocationDate`, same as `fullgame`.
- **Privacy manifest**: unchanged. StoreKit adds no tracking; App Privacy stays *Data Not Collected*.

---

## 7. Lane plan

Three Opus lanes in worktrees off `scaffold-13` on `iteration-13`; merge P1 → P2 → P3. Every lane: identity at default (a save that bought nothing is byte-identical), no draws from any state RNG, **no new tests** (run the suites, read the `Executed N tests, with 0 failures` line), old saves and the three release fixtures load, lane-prefixed types (`Purchase…` in the engine, `Shop…` in the app), `make strings` before the wrap.

### P1 — the engine (`Purchase…`)

Owns: `Packages/TycoonEngine/Sources/TycoonEngine/Purchase.swift` (new: `PurchaseKind`, `PurchaseGrant`, `PurchaseLog`, `PurchaseRule`), `GameAction.swift` (one case, own region), `Reducer.swift` (the arm before the game-over guard), `GameState.swift` (`purchases` field, codable, `weeklyBurn(balance:)`, `isRanked` now in `Legacy.swift:550`), `GameEngine.swift` (`weeklyBurn` delegate), `Stakes.swift` (`refuses` arm for `.applyPurchase(.cash)` / `.secondChance` at level ≥ 2), `Systems/EmployeeSystem.swift` (extract `rollCandidate(…rng:)`; the pool builder calls it with `&state.rng` and must produce the bytes it produced before — check against `scaffold5-garage-day30-4242.json`), `GameEvent` (`purchaseApplied`, `.info`), ledger labels.
Accepts when: the four fixtures and the determinism script are byte-identical; a bankrupt fixture takes `.secondChance` once and refuses the second; a repeated transaction id returns `[]`; the veteran on offer is the same `Candidate` for the same seed and fortnight; `isRanked` reads false after any grant.

### P2 — StoreKit and the session (`Shop…`)

Owns: `App/Sources/Store/ShopCatalog.swift`, `ShopClient.swift`, `ShopState.swift`, `ShopPresentation.swift` (the anti-nag table), `App/Sources/GameSession+Shop.swift` (purchase, `applyGrant`, parked ids, unfinished-on-launch, ledger-run removal on the second chance), `Entitlements.swift` (the `updates()` routing change — the one risky edit in the lane), `App/StoreKit/StartupStudio.storekit`, `SaveStore` construction and `TitleScreen` slot rows for slot 4, `CloudSync` for the fourth key, `DecorPresentation.available(owned:)` + `DecorSource.purchased`, the `Settings` restore-alert copy and the Purchases row, a `release-bankruptcy` fixture for review.
Accepts when: on the simulator with the `.storekit` file — buy a month, the ledger shows the line, the slot row says Unranked; kill the app between purchase and apply, relaunch, the grant lands once; refund the pack, the placed items stay; `clearTransactions`, slot 4 locks with its save intact.

### P3 — surfaces and copy

Owns: `Components/MoneySheet.swift` (the App Store card), `Screens/Endings/FounderBiographyView.swift` (the receiver's-call button; the biography money line), the hire sheet's veteran row, the furnish sheet's pack section, `Store/PaywallSheet.swift` (the pitch rewrite), `Components/EventCopy.swift` (`purchaseApplied` feed line: "A month of runway came in from outside the story: +$78,400."), six sprites in `PixelKit/HomeDecorSprites.swift` + six `DecorItem`s in `HomeDecor.swift` (`neonSign`, `filmPoster` — wall; `bonsai`, `vintageRadio` — shelf; `arcadeCabinet`, `standingLamp` — floor), README and testflight sentences, `make strings`.
Accepts when: light/dark snapshots of the money sheet, the post-mortem and the furnish sheet at the default and AX3 sizes; VoiceOver reads each price with its item; the paywall's old line is gone from the catalog.

**Wave 2, not this round:** a "parked purchase" resolution UI beyond the one front-door line; localisation of the ledger labels (they follow the post-mortem's `l10n: NOT LOCALIZED` note for now).

---

## 8. How it fails, and the cheap check

- **The quarter buys an IPO.** On `release-campus-day900`, apply `.cash(weeks: 13)` and run the `InvestorBot` a year: if it files an IPO more than a quarter earlier than the unbought run, drop the cap to $500,000. Ten minutes on a Mac before any UI exists.
- **The receiver's call is the meta.** If the owner's own ledger shows companies dying at the grace period and buying back more than once in five runs, the −5 reputation is not a cost; make it −10 and post the write-off as a headline in `News.json`.
- **The veteran beats the pool.** Compare the veteran's skills at 1.4× salary with the best `talentMagnet` candidate on the studio fixture: if the veteran is strictly better per dollar, lower the ceiling bonus from +15 to +8.
- **The `updates()` change eats a transaction.** Kill the app between `.verified` and `finish()` twenty times on the simulator; every relaunch must show exactly one grant. This is the one test to run by hand before TestFlight.
- **The shop nags anyway.** Grep the app for the six product ids: they should appear in `ShopCatalog` and the four surfaces in §5, and nowhere else.
