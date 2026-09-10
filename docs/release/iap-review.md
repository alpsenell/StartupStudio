# The shop in App Store Connect — the owner's checklist

*Iteration 14, asc-prep. Everything here is done by hand in App Store
Connect (ASC) by the account holder. The source of truth for every string
below is `App/StoreKit/StartupStudio.storekit` (copied verbatim) and
`docs/product/iteration-13-iap.md` (§1 catalog, §4.4 entries, §4.5
hand-steps, §6 store rules, §8 the hand check). Screenshots are in
`docs/release/iap-review/`.*

Bundle ID `com.alpsenel.startupstudio` · Team `6S7Q8F967Q`. The existing
non-consumable `com.alpsenel.startupstudio.fullgame` is covered by
[`testflight.md`](testflight.md) §2 and is not repeated here.

---

## Part A — create the six products, in this order

For each product: **Monetization → In-App Purchases → +**, pick the type,
enter the Reference Name and Product ID, save; then fill in Price,
Localization (English (U.S.)), Review Information (screenshot + notes).

> **The type cannot be changed after saving, and a Product ID can never
> be reused, even after deletion.** Read both twice before pressing Create.

Prices: ASC now uses price points, not numbered tiers. Pick the US
price point shown (the old tier number is in brackets for reference) and
let ASC derive the other storefronts. The app never shows a hardcoded
price — it reads `Product.displayPrice` — so any storefront's own
figure is what the player sees.

Family Sharing: leave **off** on all six (`familyShareable: false` in
the local config). ASC only offers the switch on the two non-consumables.

### A1. The receiver's call

- [ ] **Type:** Consumable
- [ ] **Reference Name:** `Second chance`
- [ ] **Product ID:** `com.alpsenel.startupstudio.secondchance`
- [ ] **Price:** USD 2.99 (old tier 3)
- [ ] **Display Name (en-US):** `The receiver's call`
- [ ] **Description (en-US):** `Reverses one bankruptcy: the overdraft is written off and a month of cash goes in. Unranks the company.`
- [ ] **Review screenshot:** `docs/release/iap-review/secondchance.png`
- [ ] **Review Note:** `On the "Bankrupt" screen a standard company reaches when its account stays overdrawn past the grace period (21 days on Normal, 11 on Hard), the button "Take the receiver's call · $2.99" sits under "What went wrong"; the quickest route is a Hard company that hires three people before shipping anything, about 25 minutes at ×4 speed.`

### A2. A fourth slot

- [ ] **Type:** Non-Consumable
- [ ] **Reference Name:** `Fourth slot`
- [ ] **Product ID:** `com.alpsenel.startupstudio.slot4`
- [ ] **Price:** USD 0.99 (old tier 1)
- [ ] **Display Name (en-US):** `A fourth slot`
- [ ] **Description (en-US):** `A fourth save slot on the front door, synced through iCloud like the other three.`
- [ ] **Review screenshot:** `docs/release/iap-review/slot4.png`
- [ ] **Review Note:** `On the title screen, tap "Saves" beside Continue (the slots are open already before the first company exists); the fourth row, locked, reads "A fourth slot · $0.99" — tap it to buy.`

### A3. The loft pack

- [ ] **Type:** Non-Consumable
- [ ] **Reference Name:** `Loft pack`
- [ ] **Product ID:** `com.alpsenel.startupstudio.decor.loft`
- [ ] **Price:** USD 1.99 (old tier 2)
- [ ] **Display Name (en-US):** `The loft pack`
- [ ] **Description (en-US):** `Six things for the founder's flat: two for the wall, two for a shelf, two for the floor. No effect on the game.`
- [ ] **Review screenshot:** `docs/release/iap-review/decor.loft.png`
- [ ] **Review Note:** `In any company, open the Life tab, tap "Furnish" on the Home card, and scroll below "Your things" to "The loft pack · $1.99" and its "Buy the pack" button.`

### A4. A month of runway

- [ ] **Type:** Consumable
- [ ] **Reference Name:** `Cash — month`
- [ ] **Product ID:** `com.alpsenel.startupstudio.cash.month`
- [ ] **Price:** USD 1.99 (old tier 2)
- [ ] **Display Name (en-US):** `A month of runway`
- [ ] **Description (en-US):** `Four weeks of the company's burn in cash, at least $8,000 and at most $250,000. Unranks the company.`
- [ ] **Review screenshot:** `docs/release/iap-review/cash.month.png`
- [ ] **Review Note:** `In any standard company (Chapter 1 is free), tap the cash figure in the top bar to open Money; the "The App Store" card under Bank lists "A month of runway" with the dollar amount it adds and its price (closed in the daily, season and league companies, which are shared).`

### A5. A quarter of runway

- [ ] **Type:** Consumable
- [ ] **Reference Name:** `Cash — quarter`
- [ ] **Product ID:** `com.alpsenel.startupstudio.cash.quarter`
- [ ] **Price:** USD 4.99 (old tier 5)
- [ ] **Display Name (en-US):** `A quarter of runway`
- [ ] **Description (en-US):** `Thirteen weeks of the company's burn in cash, at least $26,000 and at most $1,000,000. Unranks the company.`
- [ ] **Review screenshot:** `docs/release/iap-review/cash.quarter.png` (the same card as the month — both rows are on it)
- [ ] **Review Note:** `In any standard company, tap the cash figure in the top bar to open Money; "A quarter of runway" is the second row of the "The App Store" card under Bank.`

### A6. A veteran

- [ ] **Type:** Consumable
- [ ] **Reference Name:** `Veteran`
- [ ] **Product ID:** `com.alpsenel.startupstudio.veteran`
- [ ] **Price:** USD 2.99 (old tier 3)
- [ ] **Display Name (en-US):** `A veteran`
- [ ] **Description (en-US):** `The lead-level candidate shown on the hire sheet joins your pool, both traits known. Unranks the company.`
- [ ] **Review screenshot:** `docs/release/iap-review/veteran.png`
- [ ] **Review Note:** `On the Team tab tap "Hiring"; below the candidate pool, under "A veteran", is one named candidate shown in full — skills, both traits, salary — with "Bring them in · $2.99", so the exact person is visible before purchase (no random draw).`

Each product should now read **Ready to Submit**. If one still reads
*Missing Metadata*, it is almost always the screenshot or the price.

---

## Part B — the version

1. [ ] **Attach all six to the version.** App Store → the iOS version
   being submitted → *In-App Purchases and Subscriptions* → **+** → tick
   all six (and `fullgame` if it is not attached yet). First-time IAPs are
   reviewed together with the binary; one left unattached is not reviewed
   and cannot be bought after release.
2. [ ] **Paid Applications agreement.** Business → Agreements: the Paid
   Apps agreement is *Active*, and banking and tax forms are complete. An
   expired agreement makes every product silently return nothing in
   production.
3. [ ] **A sandbox tester.** Users and Access → Sandbox → Test Accounts →
   **+** (a fresh email address never used as an Apple Account). On the
   test iPhone: Settings → Developer → Sandbox Apple Account → sign in.
   Install the TestFlight or a development build and buy A month of
   runway once: the ledger shows `App Store · a month of runway`, Money's
   cash rises by the amount the row promised, and Settings → Purchases
   lists the grant. Buy the fourth slot, delete the app, reinstall,
   Settings → Restore purchases: the slot comes back without a second
   charge, and the alert says cash, second chances and veterans do not
   restore.
4. [ ] **Ask to Buy on one consumable** (spec §4.5 step 5). Use a child
   sandbox account in a sandbox family if one is available; if not, the
   local config does the same job: in Xcode open
   `App/StoreKit/StartupStudio.storekit`, **Editor → Enable Ask To Buy**,
   run the scheme, and buy A month of runway. Expected: the sheet closes,
   the app says *"Waiting for approval. It arrives by itself when it comes
   through."*, and nothing is granted. Then **Debug → StoreKit → Manage
   Transactions**, select the pending transaction, **Approve**: the grant
   lands once, with no second tap. Decline instead on a second try:
   nothing lands and nothing stays parked. Turn Ask To Buy back off.
5. [ ] **Keep the `.storekit` file out of the archive.** It is a scheme
   run setting (`project.yml` → `scheme.storeKitConfiguration`), never a
   resource; `testflight.md` §2 has the one-line check.
6. [ ] **The version-level review notes.** `testflight.md` §8 still says
   *"The one in-app purchase"*. Replace its first paragraph's IAP
   sentences with:

   > Chapter 1 is free and complete. The in-app purchase
   > `com.alpsenel.startupstudio.fullgame` (non-consumable) unlocks every
   > chapter after it; the paywall appears when chapter 2 opens. Besides it
   > there is a small shop of six items, each shown with its price next to
   > what it buys and nothing chosen at random: two cash packs on the
   > Money sheet (tap the cash in the top bar), a fourth save slot on the
   > title screen (Saves), a decor pack on Life → Furnish, a named
   > veteran candidate on Team → Hiring, and "The receiver's call" on the
   > Bankrupt screen. None of them is needed to finish the game; the cash,
   > the veteran and the receiver's call make that company unranked, and
   > the shop is closed in the shared daily, season and league companies.
   >
   > The receiver's call only appears after a bankruptcy. The quickest
   > route by playing is a Hard company that hires three people before
   > shipping anything, about 25 minutes at ×4 speed; the attached
   > screenshot shows the screen it appears on.

   **Why not "use the Continue slot on the attached fixture"** (the
   spec's §4.5 wording): the `release-bankruptcy` fixture is installed by
   `-autoFixture`, a DEBUG-only launch flag. A reviewer runs the release
   build and cannot install a save, so the ~25-minute Hard route above is
   the only in-app route. If that is too long to ask, attach a short
   screen recording of the fixture reaching the button instead (DEBUG
   build: `-unlocked -autoFixture release-bankruptcy`, Continue, let one
   day run) and mention it in the notes.

---

## Part C — before TestFlight: the kill-between-verified-and-finish check

Spec §8: *"Kill the app between `.verified` and `finish()` … every
relaunch must show exactly one grant. This is the one test to run by hand
before TestFlight."* P2 ran it twenty times against a fake store
(20/20); this run goes through the real StoreKit sheet, which only
Xcode's own Run can drive. Two breakpoints make the kill land exactly
where it matters, instead of relying on timing:

- `App/Sources/GameSession+Shop.swift:176` — `switch grant(kind, …)`:
  the transaction is verified, the grant is **not yet applied**.
- `App/Sources/GameSession+Shop.swift:181` — `await source.finish(…)`:
  the grant is **applied and autosaved, not yet finished**.

1. Open `StartupStudio.xcodeproj` (after `make gen`), pick the
   `StartupStudio` scheme and an iPhone simulator. The scheme's Run action
   carries `App/StoreKit/StartupStudio.storekit`.
2. **Product → Scheme → Edit Scheme → Run → Arguments Passed On Launch**:
   add `-unlocked` and `-autoFixture release-garage-day40` (Northgate,
   day 40, cash **$11,750**, burn well under the floor, so a month is
   exactly **$8,000**).
3. Set a breakpoint on line **176**. Press **⌘R**.
4. Tap **Continue**, tap the cash in the top bar, and on *The App Store*
   card tap **$1.99** beside *A month of runway* (it reads *+$8,000 into
   company cash*). Answer **"Buy and leave the boards"**, then confirm
   the StoreKit sheet.
5. When Xcode stops on line 176, press **Stop (⌘.)**. The app is dead
   after verification, before the grant.
6. **Untick `-autoFixture release-garage-day40`** in the scheme's
   arguments — left on, it rewrites slot 0 on every launch and would wipe
   the very grant you are checking. **Disable breakpoints (⌘Y)**. Press
   **⌘R**.
7. Continue, open Money → **Finances**: exactly **one**
   `App Store · a month of runway` line of **+$8,000**, and cash
   **$19,750** (plus or minus whatever the day that ran has booked).
   Settings → **Purchases** lists one grant for Northgate, and nothing
   under *Waiting*.
8. Stop. Re-tick `-autoFixture release-garage-day40`, re-enable
   breakpoints, move the breakpoint to line **181**, and repeat steps
   3–7: this time the kill lands after the grant was saved and before
   `finish`. On relaunch it must again be **one** line and **$19,750**,
   not two lines and $27,750.
9. Once more at each breakpoint with **A quarter of runway** (+$26,000)
   if you have the patience — the path is the same, only the amount
   differs.
10. **Fail condition:** any relaunch that shows two ledger lines, no
    ledger line and no *Waiting* entry, or a *Waiting* entry that never
    clears when Northgate is open. Any of those is a bug in
    `applyGrant` — stop the release there.
11. Remove every launch argument you added, so the scheme is back to
    none, and do not commit the scheme change.

---

## Where the product ids live (spec §8, "the shop nags anyway")

Checked on `asc-prep` (= `iteration-14`, `66da9e4`) with

```sh
git grep -nE "startupstudio\.(secondchance|slot4|decor\.loft|cash\.month|cash\.quarter|veteran)" -- ':!docs'
```

| File | What | Allowed by the spec? |
|---|---|---|
| `App/Sources/Store/ShopCatalog.swift` | all six, the catalog (`ShopProduct`) | yes — the catalog |
| `App/Sources/Store/ShopSurfaceModel.swift` | the five the surfaces draw (`ShopSurfaceItem`) | yes — the one seam every surface reads |
| `App/StoreKit/StartupStudio.storekit` | all six, the local config | yes — the config (never in the bundle) |
| `Packages/TycoonEngine/Sources/TycoonEngine/HomeDecor.swift:362` | `decor.loft`, inside a `///` doc comment on `loftPackItems` | a comment, not code; harmless |

No view names a product id: the money sheet, the post-mortem, the hire
sheet, the furnish sheet and the front door all go through
`ShopSurfaceItem` or `ShopCatalog`. Nothing in the rail, tips, the weekly
report, toasts or notifications does, and no test file names one. So the
§8 grep holds, strictly, only in *code*: the only literal outside the
catalog, the seam and the config is one doc comment in the engine.

---

## How the screenshots were made

All six on `ws-l5` (iPhone 17 class, **1206 × 2622**, the 6.3" display
size, accepted for IAP review screenshots), Debug build from this
branch, the real `ShopClient` reading the local `.storekit`. Every price
on them is the storefront's `displayPrice`, not the preview store.

| File | Product | Launch arguments | What it shows |
|---|---|---|---|
| `cash.month.png` | `cash.month` | `-unlocked -autoFixture release-studio-day400 -autoRoute shop` | Money sheet, *The App Store* card: the unranking line, *A month of runway +$81,144 · $1.99*, *A quarter of runway +$263,718 · $4.99* |
| `cash.quarter.png` | `cash.quarter` | same (a copy of the file above) | same card |
| `secondchance.png` | `secondchance` | `-unlocked -autoFixture release-bankruptcy -autoRoute receiver` | *Bankrupt*, Theo Marsh / Lantern Works; the §5 copy, *Overdraft written off: $8,711*, *A month of cash: +$33,368*, **Take the receiver's call · $2.99** |
| `veteran.png` | `veteran` | `-unlocked -autoFixture release-studio-day400 -autoTab team -autoRoute veteran` | Hiring, *A VETERAN*: Wei Mendoza, Designer, $2,789/wk, both traits (Social Butterfly, Perfectionist), **Bring them in · $2.99** |
| `decor.loft.png` | `decor.loft` | `-unlocked -autoFixture release-studio-day400 -autoTab life -autoRoute loftpack` | Furnish, **THE LOFT PACK · $1.99**, the six greyed items, **Buy the pack** |
| `slot4.png` | `slot4` | `-unlocked -autoFixture release-studio-day400 -autoSaves -autoSlots` | Title screen, slots open, row 4 locked: **A fourth slot · $0.99** |

Notes for a reshoot:

- **Prices on a `simctl` launch.** A fresh install launched with
  `xcrun simctl launch` gets no products (the fourth row reads *"The App
  Store isn't answering"*). Neither `make build` nor running an unrelated
  test fixes that. What does: run one existing StoreKit test through the
  scheme on that simulator, which opens an `SKTestSession` on the same
  config; storekitd keeps serving it to later plain launches:

  ```sh
  xcodebuild -project StartupStudio.xcodeproj -scheme StartupStudio \
    -destination "platform=iOS Simulator,name=<sim>" -derivedDataPath build test \
    -only-testing:StartupStudioTests/StoreKitEntitlementTests/testTheProductLoadsFromTheConfigurationWithItsPrice
  ```

  Then launch with the arguments above without reinstalling. (Its
  tearDown clears transactions, so nothing is owned — right for the
  locked slot and the unowned pack.)
- **`-autoSlots` alone is not enough** since U1's front door folds the
  slots behind *Saves*; add U1's `-autoSaves`.
- **The receiver's call is drawn on a scratch copy.** `-autoRoute
  receiver` writes a bankruptcy ending into a copy of the open company
  (never saved). On `release-bankruptcy` the cash is already −$8,711, so
  the overdraft figure is the fixture's own; the ending's day reads 881,
  where a played-out ending would read 882.
- 15 seconds of settle per launch; the routes wait ~2.5 s and scroll
  their surface into view.

---

## Where the shipped copy and the spec disagree

1. **`testflight.md` still describes one IAP.** §1's capability table
   ("R6's one unlock"), §8's review notes ("The one in-app purchase") and
   §9's last box ("The IAP attached") predate the shop. Part B step 6
   above gives the replacement notes; the file itself was not edited
   (docs-only lane, but that file is the release record — the owner's
   call).
2. **Spec §4.5 step 3's review note** ("use the `Continue` slot on the
   attached fixture") cannot work for App Review: the fixture is
   DEBUG-only. Same finding as P2's report; Part B step 6 drops it.
3. **The store descriptions are thinner than the in-game copy.** The
   receiver's call's description does not say that the loan and whatever
   the bank took stay, or reputation −5 (the in-game panel does say the
   loan stays); the veteran's does not say the salary is 1.4× what their
   skills would fetch (the card shows the salary before the tap). Neither
   contradicts the game, and both say "Unranks the company" as §6
   requires — flagged in case the owner wants the listing to carry the
   costs too, under guideline 2.3.
4. **"The three economy items"** (§6): the `.storekit` puts "Unranks the
   company" on four products — both cash packs, the veteran and the
   receiver's call. That is the spec's three *kinds*; consistent, noted
   only so nobody "fixes" it down to three.
5. **§5's example figures** (*+$78,400 / +$254,800* on the studio) differ
   from the shipped *+$81,144 / +$263,718*: the card is computed live
   from the day's burn ($20,286 on the fixture's day 400, not the spec's
   ≈$19,600). Not a defect.
6. **§3.4's rail line on return from the receiver** ("Back from the
   receiver. Four weeks of cash; the loan is still yours.") is still not
   built; the feed line ("Back from the receiver: +$N. The loan is still
   yours.") is. Already in the iteration-13 record.

Names, reference names, types and prices in the `.storekit` match §1 and
§4.4 exactly; `familyShareable` is `false` on all six.
