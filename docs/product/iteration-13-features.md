# Iteration 13 — the shop, and the first hour: what was built

*Record of the round. The purchase spec is `iteration-13-iap.md`, the UX
audit is `iteration-13-ux-audit.md`, the direction is
`iteration-13-lanes.md`, and each lane's own report, numbers and
screenshots are under `iteration-13-lanes/`.*

## How it ran

Two analysts first: a product pass wrote the purchase spec (six products,
the ranked-mode rules, the anti-nag rules, the honest paywall line), and a
design pass ran the app on a simulator, photographed every tab on four
fixtures, measured the chrome, the cards and the entry points, and wrote
eleven changes. Then four Opus lanes in pre-created worktrees off
`scaffold-13`: P1 the engine, P2 StoreKit and the session, P3 the surfaces
and copy, U1 the six small UX changes. The scaffold carried the engine
contract as a stub (`Purchase.swift`, the action, the event, the save
slot, all refusing everything), so the two app lanes compiled against
fixed signatures while the engine lane filled the bodies.

They landed P1, P3, U1, P2 and merged P1 → P2 → P3 → U1 without a single
conflict: P2 had dry-run every order against the other heads as they
committed and moved its locked-slot rows into `SlotList` when U1's front
door rewrite touched the slot block. The merge glue was three lines the
lanes had written out in advance: P2's store conforms to P3's surface
protocol, the store is injected at the root, and the veteran card reads
the name-premium ask.

## The rule every lane kept

A run that bought nothing is byte-identical: `PurchaseLog.empty` is
never encoded and nothing but the app sends `.applyPurchase`, so the four
engine fixtures, the three release fixtures and every pacing bot are the
bytes they were. No test was added; U1's 32 re-recorded snapshot images
are listed with reasons in its report, and the one test whose name became
false is reported, not renamed. The shop never nags: not on the rail,
never a pause, never a tip, never self-presenting, no badges or timers.

## The shop

| Product | Type | Grants | Price |
|---|---|---|---|
| The receiver's call | consumable | reverses a bankruptcy once per company: the overdraft written off, four weeks of cash, reputation −5, the loan and the guarantee still yours, unranked from here | $2.99 |
| A month of runway | consumable | 4 × max(weekly burn, $2,000), cap $250k, unranks | $1.99 |
| A quarter of runway | consumable | 13 × the same, cap $1M, unranks | $4.99 |
| A veteran | consumable | one candidate rolled against the tier's ceiling, both traits shown before buying, 1.4× salary, one per fortnight, unranks | $2.99 |
| A fourth slot | non-consumable | a fourth save slot, synced | $0.99 |
| The loft pack | non-consumable | six home decor items, no effect | $1.99 |

**Where.** The money sheet (tap the HUD cash) carries "The App Store"
card with the two cash rows, the grant in dollars, the price and the
unranking line. The bankruptcy post-mortem carries "Take the receiver's
call". The hire sheet carries the veteran as an ordinary candidate card.
The furnish sheet carries the loft pack. The front door carries the
locked fourth slot. Settings gains a Purchases row and an honest restore
alert. The paywall now reads: one purchase for the chapters, a small
shop besides, nothing in it needed to finish the game, nothing bought
reaching a leaderboard.

**Rules.** The shop is closed in the daily, the season and the league
("Not in a shared company"), because those boards score net worth and
leave ghosts other players race. In a standard company an economy
purchase flips it to unranked, asked once ("Leave the boards?"). A stake
of two or more refuses cash and the second chance; scenarios never offer
the second chance.

**The engine** (P1). `PurchaseRule` decides, the reducer arm runs before
the game-over guard, a repeated transaction id grants nothing, ledger
lines go through the helper loans use, the veteran comes from a private
stream keyed to the fortnight through an extracted candidate roll the
pool still calls with its own stream. Checked: a quarter of runway on the
campus fixture buys no IPO (the investor bot spends it on payroll and
goes bankrupt sooner); the veteran is never better per dollar than a
talent-magnet candidate; the receiver only calls once.

**StoreKit** (P2). Six products in the local config; purchase → verify →
apply → finish; a grant that cannot land is parked and applied to the
next company that can take it; unfinished transactions recovered on
launch; the existing updates listener no longer finishes consumables
blindly; non-consumables through current entitlements and the existing
restore; a fourth slot that re-locks without deleting its save; a
bankruptcy fixture for review. Checked by hand: killed between verify
and finish twenty times, exactly one grant on every relaunch; slot 4
cleared and re-locked with its save intact; the pack refunded with the
placed item still standing.

**Surfaces** (P3). The four surfaces plus the paywall, the biography's
"Bought in" line, the feed line, six palette-only decor sprites, README
and TestFlight sentences. With no store injected every surface draws
nothing, which is how P3's branch stayed snapshot-identical.

## The first hour (U1)

Six of the audit's eleven changes, one commit each, measured on a
2,000-pixel screenshot:

| Measure | Before | After |
|---|---|---|
| HUD plus rail, every tab | 412 px | 365 px with a tip, ~270 with no rail |
| Business chrome above the content | 625 px | 365 px |
| Price-war question visible at the medium sheet height | no | title and two body lines |
| Life badge, garage / studio / campus | 0 / 78 / 102 unread messages | 0 / 0 / 0, reads 4 with questions waiting |
| Front-door entry points | 15, about 3½ above the fold | 5, all above the fold |
| Garage Team: where the roster starts | 1,493 px | 898 px |

The decision sheet pins its kicker, title and first two body lines above
the scroll; the rail is one line with a tap to expand and a tip said once
per session under the tab it concerns; badges count threads that are
asking, open doors and waiting questions; departments, the team dinner
and the empty contracts card wait until they can be used; the front door
is Continue, New company and More ways to play, with the nine rows kept
as data behind a grouped sheet; Business leads with the desk and one
scrolling pill row, Investors appearing once there is a term sheet, a
board or a raised round.

Not built this round, by decision: the five medium and large changes
(Life in five folded sections, dormant rooms hidden until their door
opens, one "Waiting on you" inbox, one home per thing, three card
weights). They reshape every tab and wait for the owner's go-ahead.

## Suites after the merge

Engine 943, content 52, save 34, PixelKit 336, app 385, all green on the
four-lane merge with the glue applied, plus a Release build. No test was
added and no pinned number moved; U1's 32 snapshot images re-recorded as
its report lists. The strings catalog is 1,635 keys after one
`make strings`.

## What the owner does by hand

From the spec's §4.5: create the six products in App Store Connect with
the exact ids and types (consumable versus non-consumable cannot be
changed later), set the price tiers, the en-US names and descriptions,
one review screenshot per product, attach all six to the version before
submitting, confirm the Paid Applications agreement, and sandbox-test one
consumable including Ask to Buy. Before TestFlight, run the kill-between-
verify-and-finish check once under Xcode's own Run, because the simulator
launch cannot tap the real StoreKit sheet. App Review cannot reach the
bankruptcy fixture (DEBUG-only), so the review notes keep the ~25-minute
Hard route or a video.

## Not done, honestly

- The §3.4 rail line on return from the receiver ("Back from the
  receiver. Four weeks of cash; the loan is still yours.") is not built.
- The Business badge reads 0 on every fixture: desk rows carry no due
  date, so "due within 7 days" matches nothing until C5 gives them real
  deadlines.
- The Accessibility Inspector pass over the four shop surfaces is
  manual; the labels are written (name, grant, price).
- A veteran can leave with a People & HR pool refresh before his
  fortnight ends while the one-per-fortnight rule still blocks a rebuy.
- A refund while playing in slot 4 does not stop the running game; the
  slot locks the next time the door is up.
- `RestorePurchasesRow` in the paywall is now unused and can go; the old
  office hint and its test are preview-only.
- "Once per session" for tips resets each launch until a tip is
  dismissed with its ✕.
- At the largest text size the money sheet's Company card splits figures
  across lines; it predates this round.

## Debug flags added

`-autoPurchase cash4|cash13|second|veteran` (headless, with `-autoTab`),
`-autoShop <productID|suffix>`, `-autoShopOwned`, `-autoShopGrants`,
`-autoFixture release-bankruptcy`, `-autoSlots`, `-autoRoute
settings -autoPurchases`, `-autoRoute shop|receiver|veteran|loftpack`,
`-autoSheetMedium`, `-autoMoreWays`, `-autoSaves`.
