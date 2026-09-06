# Iteration 8 — ideas for pull and rivalry

*6 September 2026. Seven feature ideas that would make the game harder to put down and give players somebody to beat, ranked by how much they add against what they cost, and grounded in what the genre's best-retained games actually do. Each one names the seam in the codebase it builds on.*

## What the research says

- **Game Dev Tycoon** is loved for one play-through and criticised for the second: "once you know what to expect", no content past year 35, "the endgame is just making more games". Its developers deliberately built no retention mechanics at all. That is the gap this game can own.
- **Game Dev Story**'s loop is called addictive for one reason: the Hall of Fame threshold and the yearly awards give every product a bar to clear and a December to look forward to; Hall of Fame products earn sequels, which extends the loop indefinitely.
- **Mad Games Tycoon 2** turned its IP/franchise ratings and year-end awards into the thing players chase, and added 4-player competition for the charts.
- **Balatro** (8 stakes) and **Slay the Spire** (20 ascensions, a daily climb with modifiers and a board) are the modern template for "the same game, again, harder, and ranked". **Hades** showed meta-progression turns a loss into "you still made progress".
- **Wordle**'s stickiness is one puzzle a day, a streak, and a spoiler-free share grid; five years on it still has millions of daily players.
- **Phantom Abyss** and **Dark Souls** populate a single-player world with the ghosts of real players; **Spelunky**'s daily is a shared seed raced for money and time.
- **RollerCoaster Tycoon** and **Two Point** are remembered for scenarios: a preset situation, an objective, a deadline, and stars.
- **Football Manager** players stay for years because of the *story* of a save — a dynasty, a rivalry, a club taken from the bottom — and get bored the moment winning is guaranteed.
- Live-ops data: a predictable event calendar every 2–4 weeks is one of the strongest D30 retention levers on mobile; top titles grew their event count 35% in 18 months.

## The seven, ranked

| # | Idea | The loop it creates | Builds on | Effort |
|---|---|---|---|---|
| 1 | Rival ghosts | Beat a real person's company, by name, in today's market | the daily, `RivalSystem`, seed codes | High |
| 2 | Stakes | The same seed, one notch harder, ranked per notch | `GameRules`, the boards, the ledger | Medium |
| 3 | Scenarios | A situation, an objective, a deadline, three stars; one featured per week | R8's fixture saves, the goal system | Medium |
| 4 | Awards night and the Hall of Fame | A December to chase; a sequel to a great product | rivals, reviews, codebases, the ledger | Medium |
| 5 | Seasons | A four-week ruleset with a twist, a board and a cosmetic to earn | the daily's date-derived seeds, recurring boards | Medium-low |
| 6 | The dynasty | The next founder is your child or your longest-serving employee | the ledger, family, origins | Medium |
| 7 | The share grid | A spoiler-free year in coloured squares, pasted anywhere | the daily result card, the share cards | Low |

---

### 1. Rival ghosts — real players in the field

**What.** In the daily, and later in a season, the four rival studios are not scripts: they are the companies of real players who played the same seed before you. Each daily run records a *ghost log* — the launches (day, topic, type, quality, price tier), the campaigns, the hires count and the valuation curve, a few hundred bytes — and the engine's `RivalSystem` gains a replay mode that plays a ghost's launches into the shared market on the days they happened. You are out-sold on day 88 by *Overcast*, shipped by a named player, and the rival column of your newspaper says so. The result card shows where you finished against the ghosts you played with.

**Why it works.** Phantom Abyss and Dark Souls make a single-player world feel inhabited with nothing but replayed data; Spelunky's daily is a race precisely because everyone ran the same seed. This game's engine is deterministic and its market already splits demand by quality-weighted share, so a ghost's launch lands with exactly the effect it had for them. It is competitive without a server tick, and it is *personal* in a way a leaderboard row is not.

**Cost and risk.** The ghost log needs somewhere to live. Game Center leaderboards cannot carry a blob, so this is CloudKit's public database (free with the developer account, no server code) — the one thing the release doc deferred as "when anything is shared between players". The replay must draw no RNG (the ghost's outcomes are facts, not rolls) so the daily stays deterministic per ghost set, and the ghost set must be fixed per day (the top N of yesterday's board, chosen once) so everyone on a day sees the same field. Ghosts are rivals' *products*; nothing of a player's account is exposed beyond a display name.

### 2. Stakes — the same game, harder, ranked

**What.** Ten stacking modifiers, unlocked one at a time by reaching an ending at the previous stake, each with a named cost and a score multiplier:

1. *Thin press* — every review expects five more points.
2. *No credit* — the bank will not lend.
3. *Hungry rivals* — rival strength ×1.5, the copycat arrives in four weeks not eight.
4. *A seated board* — a term sheet is signed on day 1; the quarterly review starts at once.
5. *No crunch* — the crunch pace is gone; the team's evenings are theirs.
6. *Jumpy market* — booms and crashes twice as often.
7. *Poachers* — every hire is a Flight Risk.
8. *The incumbent from day 100.*
9. *Cold rooms* — networking rapport fades twice as fast.
10. *Mortal* — one hospital stay is a chronic condition; two end the run.

Each stake is a `GameRules` preset (the mechanism R4 built: identity at `.standard`, so the pinned pacing suites never move), shown on the custom page as a ladder with padlocks, and every ranked board gains a per-stake column. The biography's banner carries the stake pennant.

**Why it works.** Balatro's stakes and Slay the Spire's ascensions are why those games are played for hundreds of hours: the *same* content, re-read under pressure. Stakes turn "I know what to expect" — Game Dev Tycoon's second-play-through problem — into the point. And because the modifiers are all existing balance values or existing mechanics with one switch, most of the work is copy, the ladder UI, and the board columns.

**Cost and risk.** Balatro's community argues some stakes "add challenge in an unfun way"; the fix is that no stake removes a *choice*, only a cushion — no stake takes away hiring, shipping or the life tab. Measure each with the existing bots before it ships.

### 3. Scenarios — a situation, an objective, a deadline

**What.** Ten hand-authored starts, each a fixture save plus an objective and a clock, scored one to three stars:

- **The turnaround.** Day 400, fourteen people, −$9k a week, a board with two quarters of patience. *Profitable quarter in 26 weeks.*
- **Launch week.** A build shipping in seven days with forty live bugs and a rival's copycat due the week after. *Score 75 or better.*
- **Empty chairs.** Three resignations in their notice period. *Keep two of them.*
- **The copycat war.** You hold a topic; a price war starts today. *Hold the category for a year.*
- **The crash.** Day 200, your best topic just crashed. *Ship into a new topic and reach 30% share.*
- **Two founders.** Co-founded, and the partner wants out. *Buy them out without a loan.*
- **The giant.** The incumbent arrives on day 1. *Hold both of your markets for six months.*
- **Bootstrapped.** No investors ever. *Still yours in three years.*
- **The inheritance.** A campus, forty people, and a founder who just burned out. *Two restorative weekends, no resignations.*
- **Garage, hard, no evenings.** *Ship it by day 60.*

One scenario is *featured* each week (date-derived, like the daily) with its own recurring board. Stars persist in the ledger and unlock the next scenario; a run's stars go on the share card.

**Why it works.** RollerCoaster Tycoon's scenarios are the thing people remember about it; Two Point built a whole series on the format. This game already has 83 events and 70 life beats that only fire when a situation arises — scenarios *start* in the situation, so a new player meets the crash, the copycat and the board in their first hour instead of their fortieth. R8 built the fixture-save machinery (`-autoFixture`, `ReleaseFixtureGenerator`); a scenario is a fixture, a goal and a deadline.

**Cost and risk.** Content: ten fixtures that are fair, tested with bots. The goal system already grades conditions on `GameState`; a deadline and the star thresholds are new.

### 4. Awards night and the Hall of Fame

**What.** Every December the trade press holds its awards: **Product of the Year** (best review score across you and every rival that year), **Studio of the Year** (revenue share), **Best Newcomer** (a first-year studio), **Best in Topic** ×12, **The Comeback** (biggest year-on-year rise). The ceremony is a screen in the pixel hand — the rivals' studios lit up, envelopes, a speech line from your founder — and a win pays reputation, a perk pennant on the office wall and a line in the biography. Products with a review of 85+ enter the **Hall of Fame**, which persists in the ledger across companies and is browsable from the title screen: the best thing ever shipped in each topic, by which company, which year, which founder. A Hall of Fame product can get a **sequel** — `startProductOnCodebase` already exists — that launches with inherited hype and a fan base, and a franchise line on the storefront.

**Why it works.** Game Dev Story's reviewers call this exact loop the addictive core: the 32-point Hall of Fame bar, the December awards, sequels for the inducted. Mad Games Tycoon 2 made IP ratings and year-end awards the thing the multiplayer fights over. The game has rivals with named products and per-outlet review voices already; it lacks the ceremony that makes a year *end*.

**Cost and risk.** A yearly event on the calendar (the diary already lands dated beats), the judging (pure functions over what shipped), the screen, the ledger's hall. Sequels need a hype carry-over rule that is neutral when unused.

### 5. Seasons — a four-week world with a twist

**What.** Every four weeks a new season, derived from the date the way the daily is (no server): a fixed seed, an origin, a difficulty, and **one twist** that changes the world for the month — *the platform launch* (a new product type appears in week 2 with a boom), *the funding winter* (no term sheets, cheap talent), *the crash season*, *the poaching season*, *the press year* (reviews swing wider). Seasons have their own recurring board (Game Center supports a weekly/monthly period), one attempt per season, and a **cosmetic** to earn by rank or by finishing: an office poster, a plant, a founder look, a masthead flourish on the newspaper. Purely cosmetic, never a stat.

**Why it works.** The live-ops numbers are unambiguous: a predictable calendar of events every two to four weeks is one of the strongest D30 levers there is, and it re-engages lapsed players as much as it feeds active ones. The daily gives the game a reason to open it tomorrow; a season gives it a reason to come back next month. And because seasons are derived from the date like the daily, they cost no backend and collect nothing — the privacy manifest stays true.

**Cost and risk.** The twists are `GameRules` presets plus one or two new knobs (a scripted boom, a scripted product type); the cosmetics are PixelKit sprites that must respect the palette rule; the board is one more recurring id.

### 6. The dynasty — who founds the next company

**What.** When a run ends, the ledger offers not just an heirloom but a **successor**: your child, grown up, with traits that grew from the household (a kid who saw two burnouts is a Grumbler; one who saw the launch parties is a Speedster); your longest-serving employee, as a co-founder origin with the old company's name on the door; or you again, older, with the chronic condition if you had one. The ledger becomes a **family tree** on the title screen: three generations, the companies each founded, the endings, the products in the Hall of Fame. The newspaper's masthead can carry the dynasty's name.

**Why it works.** Football Manager players keep a save for years because of the *story* — the dynasty, the rise from the bottom — and Hades shows that meta-progression is what turns a loss into "you still made progress". This game already has family, bonds, traits derived from faces, and a ledger that survives everything; the dynasty is the story those systems have been setting up.

**Cost and risk.** A successor is a `FounderProfile` and an origin built from the ledger (the way heirlooms are built now), plus the tree screen. Keep every inherited trait neutral in the pacing bots (no bot has a family).

### 7. The share grid — the year in squares

**What.** The daily result card and the biography card gain a spoiler-free strip: fifty-two squares, one per week — green for a week in the black, red for a loss, gold for a launch, black for a crash, purple for a round — followed by the score and the seed code, as text the share sheet pastes anywhere:

```
STARTUP STUDIO · Sat 5 Sep
🟩🟩🟥🟥🟨🟩🟩🟩🟪🟩🟩🟥🟥⬛🟩🟩🟨🟩🟩🟩
$15,481 · Bankrupt on day 123 · SS1-2M000000-000114KV-8
```

**Why it works.** Wordle's growth *was* the emoji grid: a humblebrag that spoils nothing and invites the reader to try the same puzzle. The seed code on the end does what Wordle's date does — the reader plays the identical company. It costs a day.

## What I would build first

Stakes (2) and the share grid (7) first: both ride entirely on what iteration 7 built, and together they make the daily and the boards worth talking about. Then scenarios (3) for the first-hour problem and weekly cadence, and awards night (4) for the yearly one. Rival ghosts (1) is the biggest idea here and the only one that needs CloudKit; build it once the daily has players to be ghosts of. Seasons (5) and the dynasty (6) are the second update.

## Sources

- Game Dev Tycoon reception and endgame: [Metacritic user reviews](https://www.metacritic.com/game/game-dev-tycoon/user-reviews/), [Steam: only bad games towards the end](https://steamcommunity.com/app/239820/discussions/0/1743358239838571543/), [Gamecritics review](https://gamecritics.com/tayo-stalnaker/game-dev-tycoon-review/), [Greenheart Games](https://www.greenheartgames.com/app/game-dev-tycoon/)
- Game Dev Story's Hall of Fame and awards loop: [Kairosoft wiki](https://kairosoft.wiki.gg/wiki/Game_Dev_Story), [Maximum Utmost review](https://maxutmost.com/review-game-dev-story/)
- Mad Games Tycoon 2 IP ratings, awards, 4-player competition: [Steam](https://store.steampowered.com/app/1342330/Mad_Games_Tycoon_2/), [what's new](https://steamcommunity.com/app/1342330/discussions/0/3193616250037923074/)
- Startup Company (poaching, buying competitors): [Steam](https://store.steampowered.com/app/606800/Startup_Company/); Software Inc. (subsidiaries, stock market): [Steam](https://store.steampowered.com/app/362620/Software_Inc/), [stock market thread](https://steamcommunity.com/app/362620/discussions/0/1470841715957812650/)
- Balatro stakes: [Balatro Wiki](https://balatrowiki.org/w/Stakes), [community debate](https://steamcommunity.com/app/2379780/discussions/0/596264973809807214/)
- Slay the Spire daily climb and scoring: [wiki](https://slay-the-spire.fandom.com/wiki/Daily_Challenge), [Spire Codex](https://spire-codex.com/mechanics/score-formula); Spelunky daily: [The ritual](https://playingsoftware.substack.com/p/the-ritual)
- Hades meta-progression: [Bugnet](https://bugnet.io/blog/how-to-design-a-roguelite-meta-progression), [Switchblade Gaming](https://www.switchbladegaming.com/strategy-games/roguelike-vs-roguelite-explained/)
- Asynchronous ghosts: [Phantom Abyss (Unreal)](https://www.unrealengine.com/en-US/developer-interviews/phantom-abyss-combines-battle-royal-asynchronous-multiplayer-and-procedural-generation), [single-player multiplayer](https://sobanthestranger.substack.com/p/the-worlds-first-single-player-multiplayer)
- RollerCoaster Tycoon scenarios: [Scenario](https://rct.fandom.com/wiki/Scenario), [Scenario goals](https://rct.fandom.com/wiki/Scenario_Goals)
- Football Manager long saves: [The Higher Tempo Press](https://www.thehighertempopress.com/2025/07/how-to-build-a-football-manager-save-that-lasts/), [FM26 save ideas](https://www.footballmanager.com/the-dugout/12-long-term-save-ideas-fm26)
- Wordle's share grid and streak: [The Hard Copy](https://thehardcopy.co/wordles-viral-success-is-based-on-design/), [MoEngage](https://www.moengage.com/blog/wordle-viral-growth-story/), [Dinogame](https://dinogame.gg/blog/why-is-wordle-so-popular/)
- Live-ops and seasonal cadence: [Gamesforum](https://www.globalgamesforum.com/news-media/the-trends-shaping-the-world-of-liveops), [GGA retention benchmarks](https://gamegrowthadvisor.com/blog/2026-03-17-mobile-game-retention-strategies-2026/), [AC&A seasonal events](https://adriancrook.com/how-seasonal-events-boost-player-retention/)
