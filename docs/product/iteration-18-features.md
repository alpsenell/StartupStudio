# Iteration 18 — the attention round: what was built

*Record of the round. The direction and the ranking are
`iteration-18-pm.md` (one Fable PM lens, the attention brief); each
lane's own report, measurements and deviations are under
`iteration-18-lanes/`, including the merged-tree UX review.*

## How it ran

One PM lens read the tree at main (iteration 17 merged) and ranked nine
candidates against a single bar: would this grab a user's attention —
store-page-worthy, screenshot-worthy, the thing a player posts. The
coordinator took the lens's recommended picks — five features in four
Opus lanes in worktrees off main, no scaffold — and merged by finishing
order: awards → IPO → party → identity. Every conflict was a both-added
marker pair kept in order, plus one xcstrings key the IPO lane had
re-worded under a key the awards lane sorted beside. Merge glue: the
desperate party's `leadRank` case and `PartyCopy.newspaperLine` as the
lead's body, wired in `NewspaperComposer` — the one loose end the party
lane's report named.

## The five features

**G8 — awards night, attended.** From 28 days out the Now card and the
ship sheet count down to the awards cutoff. In December: *Take the team*
(the table by office tier, one founder evening, the after-state printed)
or *Stay home*; envelopes open one at a time with the team's row drawn
above them. The judge ran on both late fixtures first and both remedy
branches fired: `winStanding` ships at 7.5 (the spec's 15 halved — the
player took 9 of 10 envelopes on the studio fixture) and the night's
morale keys off Studio of the Year alone, the only envelope a rival
contests. One action, `recordCeremony`; `company.ceremonies` encodes
only when non-empty. Flagged for the next balance pass: `homeReputation`
is per envelope as the spec words it — +16 on the campus fixture's year
2 for a night on the sofa.

**A3 — IPO day.** `fileIPO` takes `price: IPOPrice = .fair` behind a
defaulted argument — the old action pays the same dollar (fair's
proceeds multiple is exactly 1.0). The pricing sheet prints proceeds and
pop odds per row; the bell is a full-screen scene — the hall, the board
with the ticker in the 5×7 face, the day-one chart drawing itself, a
seated variant under Reduce Motion. The pop is a pure function of
review, hype, market and aggression; a negative pop is a *broken open*:
reputation −5, the paper leads the week with it, the biography records
it. Priced before any UI: fair wins the studio fixture (aggressive
breaks the open at −11.6%), aggressive wins the campus one (+16.3% and
25% more proceeds). `InvestorState.ipoResult` survives *Keep running
it* — the A7 hook, when a later round wants earnings calls.

**X4 — throw the launch party.** One action,
`throwLaunchParty(productID:venue:guests:)`, valid seven days after a
launch, once per launch, refused for reasons the sheet names — the
window, the cash, the evening, a date kept instead, a founder away
(T6). Three venues ($300/$1,500/$6,000), each costing one founder
evening; morale +2/+4/+6, `liveHype` on a slope pivoted at review 60 so
a rooftop for a 55 *reads desperate* — invited outlets end colder and
the paper files its own line on it. Bond up for invited contacts; on
crunch the party feeds J1's per-launch vice pressure; the diary treats
it exactly as a K7 launch. The EV check came back negative at every
venue and score — the hype→sales channel is weak, so the party is a
morale-and-relationships purchase, not a sales one — and the slope
shipped unsteepened. `desperateStanding` is −3, not the spec's −1: at
−1 an invited outlet still ended warmer than it started.

**P8 — the launch card.** Every launch can mint a share card: the box
art large, the four outlet scores (or the exclusive's one with three
embargoed chips), the kindest or cruelest line, first-week units and
cash, the pennant if staked, the seed code that founds the same company
on another phone. Offered at the end of the review reveal, on the
war-room aftermath, and retroactively from every storefront page. No
engine change, no state. The disaster renders proudly: the studio
fixture's 48 leads with TechDaily's 39 and its sentence; the
OVERPROMISED band reads T5's pre-order burn.

**P9 — the studio mark.** A 16×16 glyph grammar (12 fields × 14 figures
× 4 notches × 16 master-palette ramp pairs), a pure function of a
`UInt64`. Picked from three chips with a shuffle die at the naming step,
seeded from run seed + shuffle count, touching no game RNG. Stamped on
the box-art corner, storefront, newspaper masthead (a badge beside it —
the paper belongs to the industry), front-page and biography cards, the
war room, launch day, the launch card, and the HQ sign on the city map.
Rivals get marks derived from their name hash for free — map, roster,
profile. Distinctness measured before any surface was wired: 24 marks,
all 276 pairs compared at 16 px, zero collisions over 90%; the glyph
set was grown to get there, the palette untouched. `company.markSeed`
encodes only when set, so every old save and fixture is byte-identical.

## The finishing pass

A UX review of the merged tree (its report and per-item resolution:
`iteration-18-lanes/ux-review.md`, screenshots referenced from it) found
one blocker — the awards marquee named the winners while the envelopes
were still sealed — and a set of seams: the party row leaking the review
average mid-reveal, an IPO pricing sheet nobody had rendered (a route
was added; two real defects surfaced and were fixed), a dishonest floor
claim in the pricing copy, two date grammars in the Now card's one slot,
guests standing on name tags, and an exchange floor that read as blocks.
All were fixed on main; the bell hall was rebuilt from PixelKit's own
sprites and now holds beside the war room's rooms, with the remaining
gap (the bell itself, the back desks, crowd depth) named honestly in the
review's resolution as a `RoomBuilder` pass of its own. Deferred, with
reasons, in the same file: the localization-catalog convention for
computed sheet copy, and the smaller copy nits.

## The suites

All four package suites and the app-target suite ran green on every
lane on its own simulator, and again on the merged tree. No test was
added or modified (the owner's standing rule); no snapshot baseline
moved — the dormant-by-default rule holding across all five features.
