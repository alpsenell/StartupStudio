# Iteration 15 — PM brief: missing playable features

*10 September 2026. Tree: `iteration-15` @ 6660ccc (= main, iteration 14 shipped
and on the phone as build 366).*

## The question

The owner asked: "analyse the game and identify missing playable features that
you would recommend — either major or minor things." Fourteen rounds have
built a startup-tycoon-meets-BitLife game: company loop (products, features,
research, hiring, marketing, contracts, investors, rivals, market map, price
war, announce dates, espionage, dirty money, incidents), the founder's life
(meters, partner, children, family drama, friends, networking, assets, decor,
crime, prison, fame, feed, side project, sabbatical, doors into the dark half,
life score), and the meta (daily runs, seasons, league with house field,
scenarios, ghosts, dynasty/successors, legacy, awards, Game Center, share
cards, timeline/newspaper, custom games, the in-app shop).

**Playable** means something the player *does* with their hands and gets a
consequence for — a verb, a choice with two defensible answers, a system that
reads another system. Not a card that shows a number, not a UX tidy. Both
sizes count: a major system (multi-day lane) and a minor verb (a half-day
addition to an existing screen) are equally welcome, ranked by how much
play they add per day of work.

## How to work

1. Read the round records `docs/product/iteration-{5,8,9,10,11,12,13,14}-features.md`
   and `iteration-12-ideas.md` (the last idea round; its "open follow-ups"
   section is a starting list) so you do not propose what exists.
2. Read the actual code for anything you propose touching: the engine is
   `Packages/TycoonEngine/Sources/TycoonEngine` (Reducer.swift, GameAction.swift,
   GameState.swift, one file per system), content is `Packages/TycoonContent`
   (Events.json, LifeEvents.json, Balance.json), the app is `App/Sources`
   (Screens/<Tab>/, Components/, GameSession+*.swift).
3. Run the game if a claim depends on feel: `make build` needs a simulator;
   use `SIM="<your clone>"` with the clone named in your prompt. `-autoRoute`
   and `-fixture` debug flags exist (see `App/Sources/DebugLaunch.swift`).
   Read-only: **do not edit source, do not add tests, do not commit.**
4. Write your report to the file named in your prompt. Format:
   - a two-paragraph diagnosis of what is thin *from your lens*, with counts
     or file evidence, not adjectives;
   - twenty candidates in a table (id, name, one line, size S/M/L, the
     system it reads and the system it writes);
   - the top eight worked out: what the player does, the two defensible
     answers, what changes in `GameState`, which files, the engine-identity
     risk (does the default path draw new `rng`?), old-save compatibility,
     a build estimate in days for one Opus engineer;
   - a cut list with one line each on why.
5. Keep the repo's standing rules: engine identity at the default path (no
   new `rng`/`worldRNG` draws unless the player acts), old saves must load,
   **no new tests** (CLAUDE.md), hide never remove, one home per thing.

Your final message to the coordinator should be five lines: the file path,
your top three by name, and anything you could not verify. The file is the
deliverable; long final messages are truncated in transit.
