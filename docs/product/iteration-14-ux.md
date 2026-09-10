# Iteration 14 — the UX audit, finished: the direction

*10 September 2026. Three Opus lanes in pre-created worktrees, cut from
`scaffold-14` on `iteration-14`, build the five audit changes iteration 13
left: C1, C2, C5, C10, C11 in `iteration-13-ux-audit.md`. Section E of the
audit ("the target, one screen per tab") is the picture every lane builds
toward. This file is the rules, the ownership and the working method.*

## The rule every lane keeps

The twelve rules of `iteration-12-joins.md` and rule 15 of
`iteration-13-lanes.md` (a re-recorded snapshot is a re-pin, listed with
its reason), plus:

16. **No engine bytes.** Every change this round is presentation. Where
    the audit's wording implies an engine change (the phone's company
    thread "stops restating weekly closes"), do it as an app-side filter
    over what is already in the save. The fixtures and every package
    suite must not move at all.
17. **Hide, group and sequence; never remove.** Every card, room, route
    and debug landing that exists today still exists and still lands.
    `consumeRoute` stays as it is on every tab.
18. **Remember, don't reset.** A section's open or closed state is
    per-install (`GameSettings`), like tip dismissal. Nothing the player
    folded pops back open on the next launch.
19. **Two pinned facts stay true:** `HQSnapshotTests` asserts a `NowAction`
    for every chapter-1 goal (keep the action table); `TitleMenu`'s nine
    rows stay as data.

## The scaffold

Committed at `scaffold-14`: marker regions `// MARK: V1|V2|V3` /
`// MARK: end …` before every `// MARK: end of Iteration 13` line in the
shared files, and one shared component contract: `CardView` gains a
`weight: CardWeight` parameter (the theme already owns a `CardStyle` modifier) (`.primary`, the default, unchanged; `.row`;
`.quiet`) whose two new cases render as `.primary` until V3 gives them
their look. V1 and V2 may use the new styles from day one; the visuals
land with V3.

## The lanes

| Lane | Branch | Sim | Builds | Size |
|---|---|---|---|---|
| V1 | `v1-life` | `ws-l1` | C1 Life in five folded sections; C2 rooms dormant until their door opens; C10's read-only work-pace line on Your week | L |
| V2 | `v2-inbox` | `ws-l2` | C5 one inbox ("Waiting on you" from the rail's +N, the desk card and the morning papers reading the same list); C10's one work-pace control on Products, the reopenable weekly report from the rail, the "Morning papers" naming, the phone's weekly-close filter | M |
| V3 | `v3-weights` | `ws-l3` | C11 three card weights, the Now card's single phase bar and "Ships in about N days", the office scaled to its card, HQ's one Company card (Burn and runway · Chapter · Journal, with the journal's week row reopening the report) | M |

## File ownership

| Lane | Owns |
|---|---|
| V1 | `Screens/Life/LifeScreen.swift` (the V1 region and the card order), a new `Screens/Life/LifeSection.swift`, the seven room cards' `body` guards (`Crime/CrimeCard`, `Assets/AssetsCard`, `Feed/FameCard`, `Family/FamilyDramaCard`, `SideProject/SideProjectCard`, `Sabbatical/SabbaticalCard`, `LifeScore/LifeScoreCard`), `Screens/Life/ThisWeekCard.swift` (the read-only pace line; the merged Fortnight/Your week card keeps both types nested), `CoachTip.stateTip` copy in `TipStrip.swift` (four directions become route buttons; tip ids unchanged), `GameSettings` keys for section state. |
| V2 | `Components/NoticeRail.swift` (the +N target only; J6's seams, J1's hooks, U1's one-line rail stay), a new `Components/WaitingSheet.swift`, `Screens/Business/DeskCard.swift` and the morning-papers card (`Desk/**`) as the shared source, `Screens/Products/ProductsListView.swift` (the one work-pace control in the tab header; verify first whether the product-card control is per-build, and if so label it instead), `AppRootView.swift` presenter region (report reopen), the phone thread list filter (app side), `MorningDeskCard` copy. |
| V3 | `Components/CardView.swift` (the `.row` and `.quiet` looks), `HQ/NowCard.swift`, `Components/PhaseProgress.swift`, `HQ/OfficeCard.swift`, `HQ/HQScreen.swift` (the Company card), `HQ/JournalCard.swift` (the week row reopens the report; coordinate: V2 owns the presenter, V3 calls it through the existing route or a marked hook). |

Known shared spots: `NoticeRail.swift` (V2 the +N target; V1 does not
touch it), `TipStrip.swift` (V1 copy only), `AppRootView.swift` (V2
presenter region only), `CardView.swift` (V3 owns; V1 and V2 only call
it). Everything else is disjoint.

## Working method

Worktree per lane at `/Users/alp/Desktop/Personal-Projects/StartupStudio-lanes/<lane>`,
simulator `ws-l<n>`, `make gen` first, `make build SIM=ws-l<n>`,
`make apptest SIM=ws-l<n>` last, `git checkout -- App/Config/Version.xcconfig`
before every commit. Baselines: engine 943, content 52, save 34, PixelKit
336, app 385; counts must match, only PNGs may change. Measure the way the
audit did (pixels of a 2,000-px screenshot; cards and numbers above the
fold; entry points) before and after on the garage, studio, campus and
family fixtures, and put the numbers in the report. Report as
`iteration-14-lanes/<lane>.md` with before/after screenshots under
`iteration-14-lanes/<lane>/`. Commit on your branch; no merge, no push.
The PM merges V3 → V1 → V2, runs `make strings` once, records the round in
`iteration-14-features.md`, and fast-forwards main.
