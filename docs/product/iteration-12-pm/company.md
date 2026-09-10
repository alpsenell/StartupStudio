# Company-sim lens: where it's thin, and what to build

*Opus PM pass, 10 September 2026, read-only over `iteration-11` @ a12f3be.*

**Where I disagree with the brief.** Rivals don't lack life any more: since iteration 11 they carry grudges and run espionage, you can sue them, and the incumbent exists. What's thin is that none of that is about the *market*. Rivals never read the market, the market never reads rivals, and two screens in this lens still have one right answer: the price tier and the tech tree.

## What I found

- **Premium is never the right price.** In `Balance.json` (`economy.priceTiers`), premium earns 1.6 × 0.6 = **0.96** of standard's revenue, gets a 0.85 share weight, and is penalised below a 70 review.
  - A comment at `App/Sources/Components/LiveOps.swift:38` admits that "standard won every time". The fix changed the caption, not the maths.
  - Budget earns 0.90 and only wins in a topic a rival is also selling into.
  - No bot ever sets premium. Only `DefenderBot` sets budget (`RivalFightBots.swift:83`).
- **The tech tree is a shopping list, and then it ends.**
  - `TechTree.json` has 20 nodes costing 3,260 RP in total.
  - The seven +0.05 quality nodes add up to exactly the `techQualityMultiplierCap` of 1.35, so the cap never bites.
  - Switching nodes refunds 100% of progress (`ResearchSystem.swift:55`).
  - A researcher with 50/50 skills makes about 4 RP a day, so two of them finish the tree in about 14 months. After that, the research desk banks points nothing can spend.
  - `TechNode.Effect` has four cases, and none of them reaches the codebase, live ops, the feature board or contracts.
  - "Bet the tree" was put off twice (iterations 3 and 5) as "a coin flip until the sides are proven different". Those sides now exist.
- **Rivals don't read the market.**
  - `RivalSystem.evolve` picks a rival's launch topic with `pick(rival.focusTopicIDs, &worldRNG)`, uniformly.
  - A market boom is read only by the feature board's appetite and the `crashesWeathered` counter.
  - Every rival product is typed `content.productTypes.first` (`launchProduct`), so `TopicDetailView.swift:312` labels them all mobile apps.
- **The forecast says the same thing in every topic.** `MarketForecast.project` shows ±0.24 over three weeks and a 27% jump chance (1 − 0.9³) for every topic; only the clamps at 0.4 and 1.8 make topics differ. That forecast is the whole phase-one reward for holding standing of 50 or more.
- **A price war stops the clock and asks nothing.** `.priceWarStarted` is graded `.notable` (`GameState.swift:773`). It takes 0.10 of your share for four weeks (`RivalDepthTuning`), and the only counter is a perk that delays it by a week.
- **Nothing commits the player to a ship date.** `ShipETA` and `BuildETA` project a day and nothing uses it. Hype decays 2% a day, so the only marketing skill is buying late.
- **You can't retire a product.** `GameAction` has no action for it. A product leaves only when its sales drop below 2% of demand, while SaaS hosting costs $150 a week and enterprise $250.
- **Contracts forget.** `ContractSystem.refreshOffers` draws the client name fresh every week, and delivery quality disappears into the one company reputation number. Contract pay grows only 25% a year, so contracts stop mattering by chapter 3. The iteration-3 "named clients" idea was never built.
- **The feature a copycat copies is recorded and read by nothing.** `copiedFeature` is iteration 10's "not done".
- **Codebases stop at the product type.** `availableCodebases(typeID:)` filters `$0.id == typeID`, so your first SaaS product starts from zero, and an IPO requires a subscription product.

**One fact that matters for any timing idea.** The market walk never drifts back toward 1.0. Its weekly variance is 0.0196, and about 80% of it comes from the ±0.4 boom and crash jumps. By year two, topics sit anywhere between the 0.4 and 1.8 clamps. So a boom is a level shift that lasts until the next jump, not a window that closes.

**How every idea below stays balance-neutral.** Each one either:
- is a new action that no bot sends, or
- only runs after the player opens a screen, using the existing `notice*Opened` actions (`noticeProductsOpened`, `noticeAssetsOpened`, `noticeFinancesOpened`) that headless runs never send.

New fields are encoded only when set, and nothing adds a `rng`/`worldRNG` draw on the default path. The pacing suite runs at `rivalCount = 0`, so rival changes can't reach its 19 gates.

---

## A) Five new features, best first

### 1. Rivals follow the money — M (3–4 days)
*"Fitness boomed and two studios moved in within a quarter. Music crashed and everyone left, so I stayed and owned it."*

- **Booms attract rivals.** A rival's launch topic still uses one `worldRNG` draw, now weighted by multiplier²: a ×1.4 topic is 1.96 times as likely, a ×0.6 topic 0.36 times.
- **A boom brings one new entrant.** When a topic crosses ×1.35 (the feature board's existing `boomAppetiteThreshold`), the strongest non-incumbent rival above strength 40 adds it to its focus. No draw is needed, and at a 10% weekly ship chance it arrives in about a quarter.
- **A crash empties the topic.** A rival drops any focus topic that stays under ×0.7 for four weekly shifts, keeping at least one. Once its product ages out after 26 weeks, your share returns to 1.0 in a category you still hold.
- **Rival products get a real type:** the argmax of the topic's `fitByType`, with catalog order breaking ties. No draw, and it fixes the mobile-app labelling.
- **The forecast card gets its first line that differs by topic:** which rivals are circling, and why.

**The decision:** take a boom's ×1.4 demand knowing company arrives within a quarter, or build in a quiet topic where the 0.55 standing floor protects your share. Or sit through a crash and inherit the category.

**Hooks:** `RivalSystem.evolve` and `launchProduct`, `MarketState`, `MarketForecast` in `Market.swift`, `MarketMapScreen` (siege markers), `CategoryStripCard`, and the newspaper's market column. It needs a new `noticeMarketOpened` gate, so a player who never opens the market keeps today's rivals.

**Why it's the thin spot:** it connects the two biggest systems in the lens, which today don't touch.

**How it fails:** if a rival always arrives, ×1.4 demand at half the share is worse than staying out, and "never enter a boom" becomes the new single answer. Early check: in a debug run of the fight bots over 10 seeds, a product launched into a boom should out-earn one in a quiet topic by 15–30% over 26 weeks. Losing is wrong, and so is winning by 80%.

### 2. Announce the date — M (3 days)
*"I told the press 14 March. On 9 March it was at 88% with the crew on crunch."*

- **Announcing:** a build with a ShipETA gets an *Announce for <day>* action on a pixel-paper sheet, at least three weeks ahead.
- **What it buys:** hype decays at 1% a day instead of 2%, and campaigns land ×1.25. Over 30 days you keep 74% of your hype instead of 55%. The newspaper prints the date and the war room counts down to it.
- **Missing it:**
  - First miss: reputation −4, hype ×0.6, and a "slipped" headline.
  - Second miss: reputation −8, hype ×0.4, and the announcement is void.
- **Rivals read it:** the copycat treats an announced product as ripe 4 weeks after launch instead of 8 (`copycatDelayWeeks`).

**The decision:** commit to a date and maybe crunch to hit it (0.15 codebase debt a day, morale target −18), or ship it rough. Or stay quiet: a smaller launch with no deadline and no early copycat.

**Hooks:** `MarketingSystem.decayHype` and `startCampaign`, `ShipETA`, `RivalSystem.copycatCheck`, `WarRoomScreen`, the notice rail, the newspaper, and the launch-week interview in the pitch room. `Product.announcedDay` and `slips` are encoded only when set.

**Why it's the thin spot:** today the ETA is information you can't act on.

**How it fails:** the ETA assumes nothing changes, and skills grow, so builds tend to finish early. If announcing at ETA + 2 weeks never misses, it's pure upside. Early check: in a debug run, measure actual ship day against the ETA taken at 50% progress. If 90% or more ship on time, reward only early announcements.

### 3. Sunset and successor — S–M (2–3 days)
*"Pulse v1 still earned $900 a week and held Fitness. I shut it down and shipped v2 six weeks later with 40% of its subscribers."*

- **Sunsetting:** a new `sunsetProduct` action takes a product off the market now. Hosting stops and its support crew goes idle.
- **The cost:** its topic then loses 1.5 standing a week (the existing empty-topic rule), and the product stops counting as live for the share floor and for challenge eligibility.
- **The payoff:** a same-topic successor shipped within 8 weeks skips the sunset product's saturation penalty (×0.75 on the peak today, so skipping it is worth +33%). For subscription types, 40% of the old subscribers carry over.

**The decision:** keep a tired product alive to hold standing and the category, or cut its hosting and live-bug drag to make room for its successor.

**Hooks:** `ProductSystem.launchMarketScale` and `weeklyHostingCost`, `StandingSystem.liveTopicIDs`, `ReleaseInfo` (a new `sunsetDay`), the live-ops section of `ProductDetailScreen`, the storefront's "Discontinued", and the newspaper. It is a new action, so no bot uses it.

**How it fails:** if sunsetting and relaunching always wins, every studio churns out a new version every six months. Check by hand from the balance, for a SaaS product at week 40, whether the answer changes with standing and share.

### 4. Buy in the downturn — S (2 days)
*"Both their markets had crashed. Quill was cheap, and so was I."*

- **When it opens:** a new `acquireRivalDistressed` action appears when the mean multiplier of a rival's focus topics is 0.8 or less.
- **The price:** valuation × 1.3 × clamp(mean multiplier, 0.5, 1). At 0.6 you pay 0.78 of its valuation, and the dominance requirement drops from 1.5 to 1.0.
- **The squeeze:** you fund it with the existing secured loan, but the credit limit reads 12 weeks of your revenue, which the same crash has cut.
- **The bet:** the products you absorb (`absorbShelf`) sit in a crashed topic. Recovery waits on a +0.4 boom jump, about 20 weeks on average at a 5% boom chance, and the topic can fall further first.

**The decision:** a bet against the cycle, made when cash and credit are tightest. It also gives loans a second job besides survival.

**Hooks:** `RivalSystem.acquireRival` (reuse its body with a price parameter), `Rival.valuation`, `FinanceSystem.creditLimit` and `takeSecuredLoan`, `RivalProfileScreen.swift:521`, and a "for sale" flag on the market map. `InvestorBot` only sends the ordinary acquisition, so the suite doesn't move.

**How it fails:** across 12 topics at 5% each, there is a crash somewhere about every two weeks. Gated on "a crash happened", the discount would be permanent, so the gate must be on the rival's own topics. Early check: count qualifying windows in a debug run with rivals on, and aim for about one per rival per game year.

### 5. Named clients and the retainer — M (3–4 days)
*"Brightline asked for us by name, then offered a retainer for two of my people for six months."*

- **Clients remember you.** A client is identified by the name that's already drawn, and the name pool is finite so names already repeat: no new draws. A `clientBook` tracks deliveries once the Contracts screen has been opened.
- **After two great deliveries**, that client's next offer asks for you: deadline slack ×1.25 and a warmer start in the pitch room.
- **After three**, they offer a retainer on pixel paper: 26 weeks at 0.6 of what two people would earn on open contracts. Those two people are locked on `.contract`; breaking it early costs four weeks' fee and the client.
- **A miss or a poor delivery** loses that client for a year, and they warn the next client in pool order.

**The decision:** a steady weekly income that survives a crash, or two people off the build. In a two-slot loft that's a third of the studio. An agency run gets a real identity, so a second playthrough can look different.

**Hooks:** `ContractSystem.refreshOffers` and `settleContracts`, `Contract.swift`, the pitch room's client counterpart in `PitchSystem`, `ContractsView`, and the phone.

**How it fails:** contracts are meant to be the dull safety net. A retainer that pays too well makes the agency path the obvious one, and independent-track players have no board to push back. Early check: does anyone take it at 0.6?

---

## B) Five improvements to existing features, best first

### 1. Premium means something — S (1 day)
- **Today:** premium earns 0.96 of standard's revenue and has no upside (`Balance.json`, `LiveOps.swift:38`).
- **Change:** premium demand becomes 0.6 + 0.02 × (review − 75), capped at 0.8, so revenue reaches ×1.28 from a review of 85. Live bugs cost premium twice the usual sales penalty. The caption shows the real percentage at this product's score.
- **The decision it creates:** premium suits a great product in a topic nobody else is selling into, with support staffed. The copycat arrives in your best product's topic after 8 weeks, and then premium's 0.85 share weight starts to hurt, so premium has a window. Budget is for the fight.
- **Neutrality:** no bot ever sets premium.
- **How it fails:** "premium at 85 or above" becomes the new single answer. Watch whether players switch back when the copy arrives.

### 2. Research forks into what shipped since — M (4 days)
- **Today:** 20 nodes, all upside, with a full refund if you switch (`TechTree.json`, `ResearchSystem.swift:55`).
- **Change:** after tier 3, four exclusive pairs open up. Each costs 300–400 RP plus cash, refunds 50% if abandoned, and locks out its partner for the rest of the run:
  - Static Analysis (crunch debt ×0.5) **vs** Hot Reload (refactoring ×1.6)
  - Crash Reporting (bugs found in the wild ×0.67) **vs** Canary Releases (patch pool 0.3 → 0.2)
  - Feature Flags (+1 feature board slot) **vs** Design Tokens (synergy ×1.5)
  - Client Portal (contract skill bar −10) **vs** Growth Lab (campaign hype ×1.25)
- **Neutrality:** the forks live in their own `TechForks.json`, outside `content.techTree`, so the tree the bots walk (`ProgressionBots.swift:73` uses `techTree.first(where:)`, `PacingBots.swift:287` a fixed path) never sees them. Every new effect case does nothing until a fork is unlocked, and a missing `unlockedForks` decodes as empty.
- **Hooks:** `TechNode.Effect`, `ResearchState`, `CodebaseSystem`, `LiveOpsSystem`, `FeatureBoard.slots`, `ContractSystem` grading, `MarketingSystem`, `ResearchView`.
- **How it fails:** it's a coin flip again. Before writing content, price each pair per quarter for a contract-heavy run and a product-heavy run, and redesign any pair with the same winner in both.

### 3. Answer the price war — S (1–2 days)
- **Today:** the clock stops and there's nothing to decide (`RivalSystem.priceWarCheck`, `GameState.swift:773`).
- **Change:** the war becomes a decision sheet with three answers:
  - **Match:** go budget for the four weeks and the share penalty is lifted. The rival bleeds 1.5 strength a week (three times the usual), but its grudge rises by 25. Two matches against the same rival push it past `rivalGrudgeToAct` (45), and it starts running espionage against you.
  - **Out-ship:** a patch that lands during the war ends it and gives +8 standing.
  - **Outlast:** today's behaviour, and the default if you don't answer.
- **The maths:** at 0.6 share, matching roughly breaks even with peace and earns about 20% more than outlasting. The real cost is making an enemy, which links price competition to espionage.
- **Neutrality:** the sheet reads the rival's `priceWarUntilDay` on the app side, the answers are new actions, and the default is today's behaviour.
- **How it fails:** if a rival at grudge 45 rarely acts, matching is free.

### 4. The copycat takes the feature — S (1 day)
- **Today:** `copycatCheck` stores `copiedFeature` and nothing reads it (`RivalSystem.swift:484–501`).
- **Change:**
  - While the copy competes (26 weeks), that feature's fit value drops from 1.0 to 0.5 for your products in that topic, and the copy gets +4 quality.
  - W3's "feed false plans" answer makes the copycat take your *worst* feature instead.
  - A "copied by Northwind" chip shows on the feature before you place it, and reviews can say "everyone has this now" through the existing `bestFeature` token.
- **The decision:** use your signature feature where you'll defend it, or hold it until the copy has aged out.
- **Neutrality:** a player who never places features has nothing to copy.
- **How it fails:** a hidden penalty that punishes without warning. The chip has to ship with it.

### 5. Port a codebase to another product type — S–M (2 days)
- **Today:** a codebase only serves its own product type (`availableCodebases` in `Codebase.swift`).
- **Change:** a new product can build on another type's codebase. It gets that codebase's carried points, capped at the target type's pools (about 19% of a SaaS build when coming from a web app), but inherits its debt live at 1.5 times. Refactoring the source still helps, and the lineage it leaves at ship is its own type's.
- **The decision:** a head start on your flagship product type, at the price of carrying the old product's mess into the product your IPO depends on.
- **Neutrality:** it's a new option in `startProductOnCodebase`; the codebase bots only build on the same type.
- **How it fails:** the carried points are small. If a hand calculation at debt 30 says greenfield always wins, cut it.

---

## Cut list

- **A forecast that predicts real moves** (mean reversion, hidden fundamentals). It would change the market walk that every pacing bot sells into, so it can't stay neutral by default. Peeking ahead at the RNG doesn't work either, because other systems draw from the same `rng` between shifts.
- **A board that expects category leadership.** A new investor persona reshuffles the `investorRNG` eligible-index draw and moves all 9 investor gates, for one more version of the same quarterly check.
- **"Blame the market" at the board meeting.** It tests knowledge; it isn't a trade-off.
- **Counting a topic you hold alone as "owned".** The gap is real: `dominatedTopicCount` needs share below 1.0, so driving out every rival un-dominates the topic. But the stat is a high-water mark, so it rarely bites, and the fix writes new state in every run with rivals.
- **Rivals patching or sequelling their products.** More pressure, no new decision.
- **Licensing your codebase to a rival.** Duplicates Build It For Them, the rival-sponsored contracts from iteration 5.
- **Loan terms and covenants.** More bookkeeping; Buy in the downturn gives loans a second job instead.
- **Campaigns aimed at a rival's launch.** Rival launches are a 10% weekly roll you can't see coming.
- **Something to spend research points on after the tree.** Pure upside; the forks do this job better.
- **More campaign kinds, topics or product types.** More options with the same answer.

**If you build one thing, build Rivals follow the money.** If you build one cheap thing, build Premium means something: one day, no balance risk, and it makes premium a price worth choosing.
