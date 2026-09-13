# Iteration 17 — PM brief: what players would like to see

*13 September 2026. Tree: `iteration-17` @ 8051373 (= main; iterations 15
and 16 shipped and on the phone as build 426).*

## The question

The owner asked: "generate more playable features that users would like
to see in this simulation game." Two rounds ago the lenses found the game
short of two-answer decisions and of pipes between its halves, and
iteration 15 built seventeen of those (`iteration-15-features.md`);
iteration 16 added seating, the office move down, a product-name
generator and an interactive city (`iteration-16-features.md`). The
wave-two list in `iteration-15-verbs.md` (draft the chapter, the
all-nighter, the street, research forks, severance or cause, remote
company, own the home) is still open.

This round the frame is **the player's wish list**: what someone who
plays Game Dev Tycoon, Software Inc., Startup Company, BitLife, Mad
Games Tycoon or Two Point-style sims would open this game and look for,
and not find, or find thin. Think in terms of what a review or a forum
post would ask for: "I wish I could…", "why can't I…", "it needs…".
**Playable** still means a verb with a consequence and two defensible
answers, not a stat card; both major systems and half-day verbs count,
ranked by play added per engineer-day.

## How to work

1. Read `iteration-15-features.md`, `iteration-16-features.md`,
   `iteration-15-verbs.md` (the ranking, the wave-two list, rules 20–24)
   and skim `iteration-15-pm/*.md` so you do not re-propose what exists
   or what was cut with a reason. Then read the actual code for anything
   you propose touching (engine `Packages/TycoonEngine/Sources/TycoonEngine`,
   content `Packages/TycoonContent`, app `App/Sources`).
2. Run the game if a claim depends on feel: `make build SIM="<your clone>"`
   with the clone named in your prompt; `-autoFixture release-studio-day400`
   / `release-campus-day900`, `-autoTab`, `-autoRoute` (see `DebugLaunch.swift`).
   Read-only: **do not edit source, do not add tests, do not commit.**
3. Write your report to the file named in your prompt:
   - a two-paragraph diagnosis from your lens, with counts or file
     evidence;
   - twenty candidates in a table (id, name, one line, size S/M/L, reads,
     writes);
   - the top eight worked out: what the player does, the two answers,
     `GameState` changes, files, engine-identity risk, old-save
     compatibility, an estimate in days for one Opus engineer, and a
     "how it fails" check the lane can measure first;
   - a cut list with one line each.
4. Standing rules: engine identity at the default path (no new
   `rng`/`worldRNG` draws unless the player acts; no bot sends a new
   action), old saves load, **no new tests** (CLAUDE.md), hide never
   remove, one home per thing, pixel not SF.

Final message to the coordinator: five lines — file path, top three by
name, anything unverified. The file is the deliverable.
