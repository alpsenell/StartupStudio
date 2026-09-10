# Iteration 13 — the shop, and the first-hour UX fixes: the direction

*10 September 2026. Four Opus lanes in pre-created worktrees, cut from
`scaffold-13` on `iteration-13`. The purchase spec is
`iteration-13-iap.md` (P1–P3 build it, section by section); the UX audit
is `iteration-13-ux-audit.md` (U1 builds its six small changes). This
file is the rules, the ownership and the working method.*

## The rule every lane keeps

The twelve rules of `iteration-12-joins.md`, unchanged, plus three for
this round:

13. **A run that bought nothing is byte-identical.** `PurchaseLog.empty`
    is never encoded; no bot, fixture or determinism script ever sends
    `.applyPurchase`; the four engine fixtures and the three release
    fixtures must not move. U1 changes no engine bytes at all.
14. **The shop never nags.** The anti-nag rules in the spec's §5 are law:
    never on the rail, never a pause, never a coach tip, never
    self-presenting, no badges, timers, "limited" or sale marks, one price
    per item next to the thing it buys, the grant said in dollars before
    the tap.
15. **Re-recording an existing snapshot is a re-pin.** The owner forbids
    new tests; changing a pinned PNG or a pinned number is allowed only
    when the feature legitimately changes what it shows, and every one is
    listed in the report with its reason. A test whose *name* becomes false
    (the audit names one) is reported, not renamed.

## The scaffold

Committed at `scaffold-13`:

- `Packages/TycoonEngine/Sources/TycoonEngine/Purchase.swift`: the
  contract from the spec's §3.1 (`PurchaseKind`, `PurchaseGrant`,
  `PurchaseLog`, `PurchaseRule`). `PurchaseRule`'s bodies are stubs that
  refuse everything; P1 replaces the bodies and must not change the
  signatures, because P2 and P3 compile against them.
- `GameAction.applyPurchase(kind:transactionID:)`, handled before the
  game-over guard in `Reducer.apply` (a stub returning `[]`),
  `GameEvent.purchaseApplied` graded `.info`, `GameState.purchases`
  decode-if-present / encode-when-non-empty, and a fallback journal line
  in `EventCopy`.
- Marker regions `// MARK: P1|P2|P3|U1` / `// MARK: end …` before every
  `// MARK: end of Iteration 12` line in the shared files.

## The lanes

| Lane | Branch | Sim | Builds | Size |
|---|---|---|---|---|
| P1 | `p1-engine` | `ws-l1` | spec §3 (engine), §2's `isRanked`, the stake refusals, the veteran roll | M |
| P2 | `p2-store` | `ws-l2` | spec §4 (StoreKit 2, the session, parked grants, the fourth slot, the pack entitlement, the settings rows, a bankruptcy fixture) | M–L |
| P3 | `p3-surfaces` | `ws-l3` | spec §5 and §6 (the money-sheet card, the receiver's-call button, the veteran row, the pack section and six sprites, the paywall rewrite, the biography line, the event copy) | M |
| U1 | `u1-firsthour` | `ws-l4` | audit C4, C3, C6, C8, C9, C7, in that order | M |

## File ownership

| Lane | Owns |
|---|---|
| P1 | `Purchase.swift` (the bodies), `Reducer.swift` P1 region (the real arm), `Legacy.swift` `isRanked`, `Stakes.swift` (refusals), `Systems/EmployeeSystem.swift` (extract `rollCandidate(…rng:)`, identity-checked against the day-30 fixtures), `GameState.weeklyBurn(balance:)` + `GameEngine.weeklyBurn` delegate, ledger labels. |
| P2 | `App/Sources/Store/Shop*.swift` (new), `App/Sources/GameSession+Shop.swift` (new), `Store/Entitlements.swift` (the `updates()` routing: the one risky edit), `App/StoreKit/StartupStudio.storekit`, `SaveStore`/`CloudSync` for slot 4, the slot rows of `TitleScreen` inside P2 markers (U1 reshapes the same screen's menu: both use markers), `DecorPresentation.available(owned:)` + `DecorSource.purchased`, `HQ/SettingsSheet.swift` restore copy and the Purchases row, a `release-bankruptcy` fixture, `DebugLaunch` P2 region. |
| P3 | `Components/MoneySheet.swift` (the App Store card), `Screens/Endings/FounderBiographyView.swift` (the button; the money line), the hire sheet's veteran row, `Screens/Life/Decor/FurnishSheet.swift` pack section, `Store/PaywallSheet.swift` (the pitch), `EventCopy` P3 region (the feed line), six sprites in PixelKit `HomeDecorSprites.swift` + six `DecorItem`s in `HomeDecor.swift`, README and `docs/release/testflight.md` sentences. |
| U1 | `Components/DecisionSheet.swift` (C4 layout; not J6's queue logic), `Screens/Business/RivalFight/PriceWarPrompt.swift` (player words), `Components/NoticeRail.swift` and `Components/TipStrip.swift` (C3; keep J6's seams and J1's hooks), `OfficeTaps.swift` (the office hint), `AppRootView.swift` badge region (C6), `Screens/Business/BusinessScreen.swift` + `Components/SegmentPillBar.swift` + `MarketView` toolbar (C7), `Screens/HQ/DepartmentsCard.swift`, `Screens/Team/TeamScreen.swift` (C8), `ContractsView` empty state, `FrontDoor/TitleScreen.swift` + `TitleMenu.swift` view only (C9: the nine `Row`s stay as data, pinned by two tests). |

Known shared spots: `TitleScreen.swift` (P2 slot rows, U1 the menu),
`AppRootView.swift` (P2 shop wiring, U1 badges), `DebugLaunch.swift`
(all four, own regions). Everything else is disjoint by design.

## Working method

Worktree per lane at `/Users/alp/Desktop/Personal-Projects/StartupStudio-lanes/<lane>`,
simulator `ws-l<n>`, `make gen` first, `make build SIM=ws-l<n>`,
`make apptest SIM=ws-l<n>` last, `git checkout -- App/Config/Version.xcconfig`
before every commit. Baselines at scaffold: engine 943, content 52, save
34, PixelKit 336, app 385. Report as `iteration-13-lanes/<lane>.md` with
screenshots under `iteration-13-lanes/<lane>/`, in the shape of
`iteration-12-lanes/j5.md`, including a "how it fails" check from the spec's
§8 or the audit's per-change notes. Commit on your branch; no merge, no
push. The PM merges P1 → P2 → P3 → U1, runs `make strings` once, records
the round in `iteration-13-features.md`, and fast-forwards main.
