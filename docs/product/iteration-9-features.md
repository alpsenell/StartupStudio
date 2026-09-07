# Iteration 9 — the Life tab: what was built

*Record of the round. The brief is `iteration-9-life.md`; each lane's own
report, numbers and screenshots are under `iteration-9-lanes/`.*

## How it ran

Seven Opus lanes in isolated worktrees, each cut from the `scaffold-9` tag
and each on its own simulator (`ws-l1` … `ws-l7`). The scaffold reserved
one engine state file per lane, five `LifeState` slots that decode as their
defaults and encode only when used, and marker regions in every shared
file. Lanes landed in the order L5, L3, L7, L2, L4, L1, L6; every merge
conflict was a both-added hunk in a shared region (`LifeScreen.consumeRoute`,
`BalanceConfig`, `Balance.json`, `LifeEvents.json`), and every one was
resolved by keeping both sides. Two lanes stalled once and were resumed from
a work-in-progress snapshot without losing anything.

Two cross-lane fixes were made at merge time: the seventh ending's trophy in
L7's decor catalog (L7 had left the two lines for it), and L4's bond bar
renamed `FriendBondBar` so it no longer collides with L3's.

## The rule every feature kept

Identity at default, no new `rng`/`worldRNG` draws, no new tests, old saves
load. All seven lanes held it: a run that engages nothing writes no new key
to its save, and the byte-identical fixture tests in `OriginTests` and
`ReleaseFixtureGenerator` pass unchanged. The only re-pinned expectations
are L2's Game Center counts (achievements 48 → 49, points 720 → 770, three
new boards) and one pixel-text glyph in the strings audit (46 → 47).

## The seven

### L1 — The phone

Every question the game asks also lands as a message in a thread with the
person it is about; the founder's answer lands as a reply; a deadline that
answered for them leaves *Seen. No reply.* in the thread forever. Staff
moments, the partner's one warning, the boomerang and the weekly numbers
all post. The phone is a mirror: nothing in it moves a meter or spends an
evening. `PhoneCard` under the week, `PhoneScreen`, `ThreadView` with the
pending question's options as reply buttons, a Life-tab unread badge, and
a thread as a 1080×1350 share card. The office thread opens only once
somebody other than the founder is on payroll, which is what keeps a solo
garage byte-identical.

### L2 — A life score, a second board, and a seventh ending

`LifeScore.score` grades the founder 0…100 with a seven-part breakdown:
partner 22, children 15, health and energy 22, friends 12, evenings on
people 19, home 10, less a capped penalty for burnouts, hospital stays and
a chronic condition. Display-only. It sits next to net worth on the Life
tab, its own screen, the biography, the share card, the year grid's text
and the Dynasty room. **Walked away** is the seventh ending: at least a
year and a half in, no debt, no seated board, somebody to hand it to,
$250k net worth and Life 60; it cannot be played past. Three life-score
boards and the ending's achievement are in `docs/release/game-center-ids.md`.

### L3 — Children who grow up, and remember

Five ages derived from the birthday: baby, toddler, school, teen, grown, at
180 / 540 / 1100 / 1800 days ("kids grow up faster than companies"). Each
child has a bond, an evening you can spend with them, and a memory ledger
capped at twelve, fed from the day's events: a launch, a chapter, a
burnout, an eviction, a missed birthday, a sabbatical. A teen with bond 60
can intern for eight unpaid summer weeks. `LegacyChild` carries bond,
memories and summers, and `Successors` maps them to the successor's traits
and archetype, which closes iteration 8's "household-grown traits" gap.
PixelKit draws four sizes; the home scene still places one size (a
two-line follow-up for the composer, now L7's).

### L4 — Friends with names

Three friends from before the company, the uni friend, the ex-colleague
and the neighbour, derived from the seed rather than stored, so an old
save meets them the day it loads with no bytes written until the founder
acts. A call is free and weekly; an evening costs one evening and $60; the
friends weekend goes to whoever you have seen least. A long friendship
becomes a hire that arrives with the whole bond, a stake in their company
from your wallet, or an interest-free loan that bleeds bond after 26
weeks. Six existing events now name somebody; four new `friend_*` beats;
a friend at bond 70 texts an opinion when a buyout is pending.

### L5 — A side project that is yours

Five tracks, the novel, the band, the marathon, the weekend app, the
restaurant, four chapters each, paid in evenings. Every chapter states its
evenings and its payout before you commit; completions pay reputation,
wallet money, one of two real perks and meters, post to the office and the
partner, and land a press line. A finished track is a line in the
biography in the year it happened.

### L6 — The sabbatical

Hand the company to an employee with 26 weeks' tenure and bond 50, go away
for four to twelve weeks at $500 a week, and recover: health, energy, mood
and affection climb daily. The caretaker makes one trait-driven call a
week through the normal reducer, so the ledger and the journal record it:
a Speedster ships, a Mentor trains, a Grumbler lets morale slide, a Flight
Risk may leave. Board patience halves and poach odds rise by half while
you are gone. A daily line lands in the office thread, and the return
report says what they did and what the numbers were then and now.

### L7 — Furnish the home

Twelve named slots unlocked by tier (three in the studio, twelve in the
penthouse) and a catalog of nineteen things: the five shop items as
objects, the plant, the record player, the awards pennant, five season
posters and six ending trophies (seven, with *Walked away*). Buying a thing
that fits an empty slot places it; moving house keeps the boxes and empties
the walls. `HomeSceneComposer` draws the sprites from a defaulted
parameter, so every existing caller draws what it drew. `FurnishSheet`,
a Furnish row on the home card, and shop rows that say where a thing goes.

## Suites after iteration 9

Engine 943, content 52, save 34, PixelKit 336, app 385, all green on the
merged branch. No test was added.

## Not done, honestly

- The home scene draws one child size; the four-size art exists in
  `HomeChildArt` and the composer switch is a two-line follow-up.
- A bond move from an answered family beat reaches every child in the
  house, because `.narrativeResolved` carries no child id.
- The life score is not on the front door (it would need a field in the
  save summary).
- The sabbatical's return sheet is not photographed: the app's root sheets
  win the race against a headless pass.
- `make strings` was run once after the last merge; it swept in the
  unsynced keys from iterations 7 and 8 as well as this round's.
- CloudKit ghosts, sequel hype carry-over and season decor as PixelKit
  rewards remain where iteration 8 left them.

## Debug flags added

`-autoRoute phone|lifescore|children|friends|sideproject|sabbatical|furnish`,
`-autoFixture l3-family-day900`, `-autoChild`, `-autoSideProject <track>`,
`-autoDecor`, `-autoHome <tier>`, and the phone's newest-thread landing.
