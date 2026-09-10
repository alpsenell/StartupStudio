# Iteration 12 — joins: what was built

*Record of the round. The brief is `iteration-12-joins.md`, the ideas are
`iteration-12-ideas.md` with the four lens reports under
`iteration-12-pm/`, and each lane's own report, numbers and screenshots
are under `iteration-12-lanes/`.*

## How it ran

Six Opus lanes in pre-created worktrees, each cut from `scaffold-12` and
on its own simulator. The scaffold was comment-only: `// MARK: J<n>`
regions in the shared files and the direction doc, no engine stubs. The
lanes landed in the order J2, J1, J5, J3, J6, J4 and were merged J6 →
J5 → J3 → J2 → J1 → J4, the order the brief set so the queue and the
pacing re-pin were on the floor before anything else stood on them.

Every conflict was the expected kind: the balance JSON (four lanes each
appended a block; joined with `},`), the company events (union by id,
204 → 217), one both-added debug hook in the root view, and two
structural ones that the brief predicted. J3 had put its price-war sheet
into the old decision chain that J6 replaced with the queue, so the
merge seats it as a `QueueKind` with an entry in `QueueBoard.entries`
and a builder in `queuePrompt(for:)`; J2's term-sheet prompt now takes
the balance, so J6's queue caller passes it. J1's three notice-rail
hooks were re-seated into the three seams J6 left for them
(`laneNotices`, `fallbackTip`, `laneRoute(forNoticeID:)`), and J5's rail
countdown was wired into the same seam at merge, since the type did not
exist on J6's branch. J4 merged without a conflict.

## The rule every feature kept

Identity at default, no new `rng`/`worldRNG` draws, old saves load, no
new tests, lane-prefixed type names, balance keys in `Balance.json`,
insert only inside your markers. Two lanes found the spec's gate was not
enough and built a better one rather than re-pin: J1's doors arm only
when the HUD says a person is playing (`.armDoors`), because
crunch-hire meets the vices condition on day 90 on every seed; J3's
rivals read the market only after the market board has been opened
(`.noticeMarketOpened`). J6 alone was allowed to move measured numbers,
and in the end moved none of the two targets suites' pins: it chose a
gentler default for the event-stakes reference burn ($6,000, not the
brief's $4,000) so the board gate held at its original wording.

## The lanes

### J1 — Nobody asks permission

Four one-time doors from the company game into the dormant rooms: the
shark at four weeks of runway, the launch-party vice after 21 crunch
days in 28, the journalist after an 80 review or reputation 60, and a
parent's care bill at a seed-derived 69–72 (the balance's 78 never
arrives inside a run). Each opens once from day 90, lands as a phone
message and a deferred rail line with 14 days on it, never pauses, draws
nothing, and treats silence as a no; a yes goes through the room's own
function. *Tell people* on the launch-day sheet drafts the launch post
into the feed's compose sheet. Eleven state-keyed coach tips plus one
per open door; the chapter-1 six are unchanged and the tour still
dismisses only those. Four `door_` life events. Measured over the ten
pacing seeds: the shark opens for nearly every growth bot, care for
about half of all bots, vices only for crunchers.

### J2 — Your record crosses over

The board reads the papers: each review with a seated board prints
`THE FOUNDER'S QUARTER: +N` (+8 per open case, +12 per guilty verdict,
+4 per beef round, +6 for an unanswered cancellation, cap +25), the cap
table shows the next review's line before it lands, and with no board a
term sheet that arrives during an open case is 15% smaller, applied
after the roll. Your name gets around: a pure `FounderStanding` score of
0–100 marks up candidates' asks by name/200, and at 50 the best
candidate refuses the interview and the hiring sheet names them. Fame is
a spotlight: 1 + 0.25 × fame level multiplies crime discovery, laundering
and espionage trace, printed on the operation buttons; a conviction or a
trace drops fame a rung. The laundering constant became the key
`founderStanding.launderDiscovery` at the same value. Measured: a board
was seated during an open case in 5–9 of 10 darker runs, and those
founders made 16–20 hires afterwards at +7% to +30% on asks.

### J3 — Rivals follow the money

Once the market board has been opened, rival launches lean toward booms
(the same single draw, weighted by multiplier²), the strongest studio
above 40 moves into a topic crossing ×1.35 and ships there next, a topic
under ×0.70 for a month is dropped, and rival products get the type the
topic suits (no more "everything is a mobile app"). The market report's
category card says who is circling and why; the map shows a siege; the
rival profile says where they are going; the paper prints the moves. The
price war is a sheet with Match (budget for the war, the −10% lifts, the
rival bleeds 1.5 strength a week and gains 25 grudge), Out-ship (a patch
inside the war ends it, +8 standing) and Outlast (the default after a
week). The copied card counts for half on your board while the clone
competes, the clone gets +4, false plans make it copy your worst card,
and the hand shows a "copied by" chip. Three `rivalmarket_` events.
Measured over ten seeds and four variants: a boom launch still
out-earns a quiet one by about 38%, not the 15–30% the spec asked for,
because on most seeds no studio is strong enough at the crossing to
answer it. That is a design follow-up, recorded with all four tables.

### J4 — The house field

The engine's bots ship: a new `TycoonBots` library holds `SimRunner`,
`BotPolicy`, the pacing bots and the investor bots, moved out of the
test target (the tests gained only import lines). Nineteen named house
founders per league tier, and nineteen for the daily, each playing the
player's own company on the seed to the year's end, off the main actor,
filed as ordinary ghost logs under the league and daily keys. Real
players first, house founders fill the table to 20; promotion is four up
and four down instead of "held" in a field of one. Both result cards
name who finished directly above you and how they play. The demo field
no longer uses random numbers. Measured: nineteen runs take 0.03–0.05 s
in Release on the simulator; the share of variants beating each tier's
fourth place falls 0.31, 0.27, 0.18, 0.14 from Bronze to Founders; on
the three hardest weeks the top tiers go bankrupt and surviving wins.

### J5 — Announce the date, and premium means something

A build with an ETA gets an "Announce for <day>" sheet (the ETA, +7, +14,
or stay quiet), each row with its slack and risk. While a date stands,
hype decays 1% a day instead of 2% and campaigns land ×1.25; a first
slip costs reputation −4 and hype ×0.6 with a correction and a new date,
a second −8 and ×0.4 and the announcement is void; the copycat is ripe
at four weeks instead of eight; the paper leads with a slip; the war
room counts down; the rail carries the deadline. The check found that
builds ship on time so reliably (94–99% with 14 days of slack) that
announcing is tied to being early: a date can only be given while the
ETA is at least 14 days away and at most 14 days past it. Premium demand
is `min(0.8, max(0.3, 0.6 + 0.02 × (review − 75)))`, so a review of 85
earns ×1.28 standard's revenue; live bugs cost premium double; the
live-ops caption shows the real percentage for this product. Ten
`announce_` events.

### J6 — One queue, the children's clock, money with teeth

Every open question is read into one ordered `QueueBoard` (derived,
never stored) with a severity, a deadline and a default: the seven old
sheets and wave two's seven. "Let me think" works on every sheet but the
category challenge, which a snapshot test pins modal. The dirty-money
string and the confrontation now reach the root; the case, the hearing,
the offer, the funeral and the old post sit on the rail with deadlines
and route into their rooms. Past two critical stops in a week the next
question that can wait goes to the rail, on the live clock only. The five
direct pause writes are gone. Child stages move from [180, 540, 1100,
1800] to [90, 270, 540, 900] days. Event cash and the button's money
line scale by `max(1, burn / 6000)^0.5` (a studio story costs about
$3,385 against the old $2,500, a campus ×2.58); campus rent is $4,000
plus $200 a head above 14. The two studio and campus release fixtures
were regenerated on their seeds (the garage one is byte-identical, the
proof the gating holds) and one app pin moved, 905 → 900.

## Suites after the merge

Engine 943, content 52, save 34, PixelKit 336, app 385, all green on the
six-lane merge, plus a Release build of the app (J4's Release-only trap
stays fixed). No test was added; the two release fixtures and one app
pin moved as J6's report records. Company events 204 → 217, life events
299 → 303, and the strings catalog 1,544 keys after one `make strings`.

## Not done, honestly

- J3's boom premium sits at about +38% against a 15–30% target; four
  variants (as built, an entrant quality floor at leader −8 and −4, a 25%
  ship chance for a studio holding a boom entry) all measured the same,
  because the limiter is whether a strong enough studio exists at the
  crossing. A better-funded or a second entrant is a design call.
- J1's shark opens for almost every growing company at the spec's four
  weeks; three weeks or a falling-runway condition if playtests find it
  naggy. Tip dismissal is per install, so a dismissed door tip stays
  dismissed in the next run.
- J2's fame drop does not stick (followers are untouched), guilty
  verdicts never leave the name, and the beef count reads the running
  beef only.
- J3's Match is free for a founder who never opened the Team tab, because
  the rival's espionage machine waits on that gate.
- J4's top tiers all go bankrupt on the three hardest weeks; a survivor
  or two per roster would fix it. Not measured on a real phone.
- J6's brief asked for ×1.66 studio stakes; the shipped $6,000 reference
  gives ×1.35, one JSON number away at the cost of re-pinning the board
  gate. The board gate itself runs on a margin of a few reviews.
- The category challenge stays modal. Two room sheets (the string, the
  confrontation) now duplicate the root's.

## Debug flags added

`-autoRoute door -autoDoor shark|vices|fame|care`, `-autoDoorAnswer …`,
`-autoStanding <name>`, `-autoBoardReview case|offer`, `-autoSpotlight
<level>`, `-autoRoute hiring|investors`, `-autoRivalMarket boom|crash`,
`-autoPriceWar`, `-autoCopied`, `-autoMarketReport`,
`-autoRivalMarketCard`, `-autoHouseField week|day`, `-autoLeague demo`
(now the house field), `-autoRoute announce|premium|announceroom`,
`-autoAnnounce [slip|void]`, `-autoPremium`, `-autoQueue [eventID]`,
`-autoChild teen|grown`, `-autoCampus`, `-autoStakes`.
