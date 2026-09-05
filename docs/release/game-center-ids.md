# Game Center — the identifiers to create

*Iteration 7, lane R3. Generated from `Goals.json`, `EndingKind` and
`GameCenterCatalog`; `GameCenterDailyTests` pins every string below, so
this file and the app cannot drift apart.*

Create these in App Store Connect under the app's **Game Center**
configuration, then attach the achievement and leaderboard sets to the
version being submitted. Enable the Game Center capability on the App ID
first (the entitlement is already in `project.yml`).

- **48 achievements** — 42 goals at 10 points, 6 endings at 50: **720**
  points of the 1,000 a game may award.
- **8 leaderboards** — six ranked all-time boards, one tenure board, and
  the recurring daily.

Every id is bundle-prefixed (`com.alpsenel.startupstudio.…`) so the
whole table can be pasted.

## Achievements — goals (10 points each, hidden: no)

| # | Identifier | Reference name / title | Description |
|---|---|---|---|
| 1 | `com.alpsenel.startupstudio.goal.g1_name_a_product` | Name your first product | Nothing exists until it has a name on it. |
| 2 | `com.alpsenel.startupstudio.goal.g1_ship_it` | Ship it | Finished beats perfect. Get version one out the door. |
| 3 | `com.alpsenel.startupstudio.goal.g1_review_40` | Score 40 or better | The press won't love your first one. Make them not hate it. |
| 4 | `com.alpsenel.startupstudio.goal.g1_first_hire` | Hire somebody | You can't be the whole company forever. |
| 5 | `com.alpsenel.startupstudio.goal.g1_first_contract` | Sign a client contract | Client work pays the rent while the product finds its feet. |
| 6 | `com.alpsenel.startupstudio.goal.g1_week_in_the_black` | End a week in the black | One Sunday night with more money than you started with. |
| 7 | `com.alpsenel.startupstudio.goal.g2_reach_the_loft` | Move into the loft | Three people is the garage's ceiling. |
| 8 | `com.alpsenel.startupstudio.goal.g2_team_of_three` | Build a team of three | You, and three people who chose to be here. |
| 9 | `com.alpsenel.startupstudio.goal.g2_review_60` | Score 60 or better | The second one should be visibly better than the first. |
| 10 | `com.alpsenel.startupstudio.goal.g2_research_two_techs` | Research two technologies | Somebody has to think about next year. |
| 11 | `com.alpsenel.startupstudio.goal.g2_take_a_weekend` | Take a real weekend | Rest doesn't count. Go and do something. |
| 12 | `com.alpsenel.startupstudio.goal.g2_go_on_a_date` | Go on a date | There is a life outside the loft. Allegedly. |
| 13 | `com.alpsenel.startupstudio.goal.g3_reach_the_studio` | Take the studio lease | Fourteen desks, a whiteboard, and a rent bill to match. |
| 14 | `com.alpsenel.startupstudio.goal.g3_form_a_department` | Form a department | Hire a lawyer, an HR lead or an ops manager and let them run it. |
| 15 | `com.alpsenel.startupstudio.goal.g3_review_75` | Score 75 or better | Good enough that people recommend it unprompted. |
| 16 | `com.alpsenel.startupstudio.goal.g3_weather_three_crashes` | Weather three market crashes | Still trading when the third one clears. |
| 17 | `com.alpsenel.startupstudio.goal.g3_a_hundred_and_fifty_k_product` | Earn $75,000 from one product | Lifetime revenue, not a good week. |
| 18 | `com.alpsenel.startupstudio.goal.g3_move_in_together` | Move in together | Somebody else's coffee cups in your sink. |
| 19 | `com.alpsenel.startupstudio.goal.g3i_six_tenured` | Keep six people a year | Six people who have each been with you twelve months. Hiring is easy; this isn't. |
| 20 | `com.alpsenel.startupstudio.goal.g3i_four_profitable_quarters` | Four profitable quarters in a row | More in the account at the end of each quarter than the start. Four times, no gaps. |
| 21 | `com.alpsenel.startupstudio.goal.g3i_own_a_topic` | Own a topic | Beat every rival's share in a market you ship into. |
| 22 | `com.alpsenel.startupstudio.goal.g3i_buy_the_office` | Buy your office | Stop paying rent. The deeds, with your name on them. |
| 23 | `com.alpsenel.startupstudio.goal.g4_raise_a_round` | Raise a round | Somebody else's money, and somebody else's opinions. |
| 24 | `com.alpsenel.startupstudio.goal.g4_twenty_on_payroll` | Put twenty people on payroll | The point where you stop knowing what everyone did today. |
| 25 | `com.alpsenel.startupstudio.goal.g4_own_a_topic` | Own a topic | Beat every rival's share in a market you ship into. |
| 26 | `com.alpsenel.startupstudio.goal.g4_acquire_a_rival` | Buy a rival outright | Their team, their market, their name off the door. |
| 27 | `com.alpsenel.startupstudio.goal.g4_reach_the_campus` | Open the campus | Forty desks and a lobby with your name in it. |
| 28 | `com.alpsenel.startupstudio.goal.g4_three_amenities` | Build three amenities | The perks that make people stay when a rival calls. |
| 29 | `com.alpsenel.startupstudio.goal.g4i_two_products_live` | Keep two products live for 26 weeks | Half a year with two things on sale at once. A company, not a product. |
| 30 | `com.alpsenel.startupstudio.goal.g4i_eight_profitable_quarters` | Eight profitable quarters in a row | Two straight years in the black. The number Still yours asks for. |
| 31 | `com.alpsenel.startupstudio.goal.g4i_review_85` | Score 85 or better | The one the investors start calling about. Let them. |
| 32 | `com.alpsenel.startupstudio.goal.g4i_quarter_million` | Bank $250,000 | Cash on hand, and none of it anybody else's. |
| 33 | `com.alpsenel.startupstudio.goal.g4i_form_a_department` | Form a department | Hire a lawyer, an HR lead or an ops manager and let them run it. |
| 34 | `com.alpsenel.startupstudio.goal.g4i_marry` | Get married | Somebody who was there for all of it. |
| 35 | `com.alpsenel.startupstudio.goal.g5_ready_to_go_public` | Be ready to go public | A $5M valuation, three profitable quarters, and something that bills monthly. |
| 36 | `com.alpsenel.startupstudio.goal.g5_review_90` | Score 90 or better | The one they'll still be writing about in five years. |
| 37 | `com.alpsenel.startupstudio.goal.g5_millionaire` | Be worth a million | Your wallet plus your slice of what you built. |
| 38 | `com.alpsenel.startupstudio.goal.g5_frontier_research` | Reach the frontier | Research something at the top of the tech tree. |
| 39 | `com.alpsenel.startupstudio.goal.g5_three_children` | Raise three children | The other thing you built. |
| 40 | `com.alpsenel.startupstudio.goal.g5_five_million_company` | Be worth five million | The number that makes acquirers pick up the phone. |
| 41 | `com.alpsenel.startupstudio.goal.g5i_ready_to_stay_independent` | Be ready to call it built | Eight profitable quarters in a row, a name people know, and every share still yours. |
| 42 | `com.alpsenel.startupstudio.goal.g5i_five_years_in` | Five years in | Most companies never get here. Yours did, on its own money. |

## Achievements — endings (50 points each, hidden: no)

| # | Identifier | Reference name / title | Description |
|---|---|---|---|
| 1 | `com.alpsenel.startupstudio.ending.bankruptcy` | Bankrupt | Run a company all the way into the ground. |
| 2 | `com.alpsenel.startupstudio.ending.acquired` | Acquired | Sell the company to somebody who wanted it. |
| 3 | `com.alpsenel.startupstudio.ending.ipo` | Public | Take the company public and ring the bell. |
| 4 | `com.alpsenel.startupstudio.ending.oustedByBoard` | Replaced | Be replaced by the board you invited in. |
| 5 | `com.alpsenel.startupstudio.ending.soldUp` | Sold up | Sell the name and the desks to get out. |
| 6 | `com.alpsenel.startupstudio.ending.independent` | Still yours | Keep every share and build something that lasts. |

## Leaderboards

| # | Identifier | Name | Score format | Sort | Type |
|---|---|---|---|---|---|
| 1 | `com.alpsenel.startupstudio.lb.ipo_days.easy` | Days to IPO — Easy | Integer | Low to High | Classic (all time) |
| 2 | `com.alpsenel.startupstudio.lb.ipo_days.normal` | Days to IPO — Normal | Integer | Low to High | Classic (all time) |
| 3 | `com.alpsenel.startupstudio.lb.ipo_days.hard` | Days to IPO — Hard | Integer | Low to High | Classic (all time) |
| 4 | `com.alpsenel.startupstudio.lb.still_yours_net_worth.easy` | Still yours — Easy | Money (US Dollar, no decimals) | High to Low | Classic (all time) |
| 5 | `com.alpsenel.startupstudio.lb.still_yours_net_worth.normal` | Still yours — Normal | Money (US Dollar, no decimals) | High to Low | Classic (all time) |
| 6 | `com.alpsenel.startupstudio.lb.still_yours_net_worth.hard` | Still yours — Hard | Money (US Dollar, no decimals) | High to Low | Classic (all time) |
| 7 | `com.alpsenel.startupstudio.lb.tenure_days` | Longest anyone stayed | Integer | High to Low | Classic (all time) |
| 8 | `com.alpsenel.startupstudio.lb.daily` | Today's company | Money (US Dollar, no decimals) | High to Low | **Recurring — 1 day, starts 00:00 UTC** |

## What the game posts, and when

| Event | Posts |
|---|---|
| `GameEvent.goalCompleted(goalID:)` | `…goal.<goalID>`, in every mode — a custom company and the daily earn achievements too |
| `GameEvent.gameOver` | `…ending.<EndingKind.rawValue>`, in every mode |
| Ending `.ipo`, `state.isRanked` | `…lb.ipo_days.<difficulty>` — the day the run ended |
| Ending `.independent`, `state.isRanked` | `…lb.still_yours_net_worth.<difficulty>` — `founderNetWorth` |
| Any ending, any mode, with at least one hire | `…lb.tenure_days` — `day − min(hiredDay)`, founder excluded |
| The daily stopping (its ending, or day 364) | `…lb.daily` — `founderNetWorth`, only while that UTC day is still open |

`state.isRanked` is standard or daily mode with no heirloom: a custom
company (R4) earns achievements and never posts to a ranked board.

Reports made while signed out are queued in `UserDefaults` under `gc.queue`
(capped at 100, oldest dropped) and flushed on the next authentication, so
an offline IPO still lands.

## Also outside the repo

- Enable **Game Center** on the App ID (the entitlement ships already).
- A **sandbox tester** signed into Game Center on a device or simulator, to
  see a banner on `…goal.g1_ship_it` and a row on `…lb.daily`. Nothing in
  this lane can be verified on a simulator with no Game Center account:
  signed out, the game queues and never crashes, which is what the app
  suite tests against `NoopGameCenter`.
- Localised titles are not needed for the first submission — the game ships
  in English (R9 owns the string catalog).

