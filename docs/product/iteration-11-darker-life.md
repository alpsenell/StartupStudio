# Iteration 11 — the founder's darker life: things that happen to you

*Direction doc for nine lanes in two waves. Wave one, five lanes, on the
`scaffold-11` tag of `iteration-11`. Wave two, four lanes, is cut from
wave one's merge and reads the seams wave one leaves. Read this whole
file, then `iteration-10-features.md` for what the last round learned.*

## Why

BitLife is a life first: absurd things happen to you, you mess with the
people around you, you collect assets and vices, you commit crimes and go
to court, and the world remembers. Startup Studio's founder has a rich but
polite life: seventy-eight life events, three or four buttons per person,
no way to do anything wrong, nothing to own but a home, and a body that is
four meters. This round gives the founder a darker life and the world a
way to answer it.

## The rule every feature keeps

Iterations 5 through 10's rules, unchanged, and every lane reads them
before touching code:

1. **Identity at the default.** A run that never does any of this writes
   the same JSON it wrote before. The byte-identical fixture tests
   (`OriginTests`, `ReleaseFixtureGenerator`) and the pacing bots enforce
   it. No bot commits a crime, posts a take, buys a car or pranks anyone.
2. **No new draws from `rng` or `worldRNG`.** `socialRNG`, or a private
   stream derived from `state.seed`, and only when engaged.
3. **No new tests.** Run every suite; extend none; re-pin only when your
   feature legitimately changes a count, and say so with old and new.
4. **Read the Executed line.** `Executed N tests, with 0 failures` for the
   app, `✔ Test run with N tests … passed` for a package. Do not run the
   app suite while every lane is building on the same machine: two heavy
   snapshot tests get killed under load and it looks like a crash.
5. **Old saves load.** Decode-if-present, encode-when-non-default.
6. **Pixel, not SF.** Study the pitch room, the incident room, the phone,
   `NetworkingVenueSheet` and the `Theme` first. Palette-only sprites.
7. **Every action shows its consequence on the button**, and a refused
   action says why.
8. **Prefix every new type with your lane's subject.** `CrimeCard`,
   `PeopleMenu`, `AssetRow`, `FeedPost`, `SecretThread`: never a generic
   name.
9. **A new `BalanceConfig+X.swift` block needs its key in
   `Resources/Balance.json`** (append after `"bugHunt"`).
10. **Insert only between your own two markers** in shared files. A change
    you need in a file you do not own is a follow-up in your report.
11. **Dark, not cruel.** BitLife's humour is dry and absurd. Write crime,
    vice, scandal and betrayal the way the game already writes eviction
    and burnout: short, specific, deadpan. Nothing that targets a real
    group of people, and nothing sexual beyond "an affair" as a fact.
12. **Events are content.** Every lane ships thirty or more new events in
    JSON with ids prefixed by its lane (`crime_`, `people_`, `asset_`,
    `vice_`, `fame_`, `office_`), appended at the END of the right file.
    Merge order decides who appends first; expect a trivial both-added
    merge and nothing else.

## The scaffold

Committed at `scaffold-11`:

- Engine files, one per wave-one lane: `Crime.swift` (N1), `Interactions.
  swift` (N2), `Assets.swift` (N3), `Fame.swift` (N4), `OfficeSecrets.
  swift` (N5). Lanes own and may reshape them, with two exceptions that
  wave two reads: `CrimeState.notoriety` (0…100) and `CrimeState.cases`
  keep their names and meaning.
- `GameState` slots `crime`, `interactions`, `assets`, `fame`, `secrets`,
  each decode-if-present and encode-when-non-default. **Do not add fields
  to `GameState`.**
- Marker regions `// MARK: N<n> (…)` in `GameAction.swift`, `Reducer.swift`
  (systems and handlers), `GameState.swift` (`GameEvent`), `AppRouter.swift`
  (`Route` and its tab switch), `DebugLaunch.swift` (flags and route
  names), `LifeScreen.swift` (cards, destinations, destination switch,
  `consumeRoute`), `TeamScreen.swift` (`consumeRoute`, N2 and N5),
  `HQScreen.swift` (`consumeRoute`, N5), `BusinessScreen.swift`
  (`consumeRoute`, N1).

## File ownership — wave one

| Lane | Owns |
|---|---|
| N1 | `Crime.swift`, `Systems/CrimeSystem.swift`, `Balance/BalanceConfig+Crime.swift`, `App/Sources/Screens/Life/Crime/**` (the courtroom lives here), `Systems/FinanceSystem.swift` marked region (tax), `Systems/HiringSystem.swift` marked region (NDA poach), `Systems/RivalSystem.swift` marked region (sue a rival, plant a story), `App/Sources/Screens/Business/RivalProfileScreen.swift` marked region, `Systems/SabbaticalSystem.swift` marked region (the caretaker while in prison), `Events.json` append (`crime_`), `LifeEvents.json` append (`crime_`) |
| N2 | `Interactions.swift`, `Systems/InteractionSystem.swift`, a `Interactions.json` in TycoonContent with `ContentCatalog` wiring (decode-if-present), `App/Sources/Screens/People/**` (the menu sheet, reused by every person's card), marked regions in `EmployeeManageSheet.swift`, `PartnerCard.swift`, `FamilyCard.swift`, `FriendSheet.swift` (L4's), `ContactSheet.swift`, `ChildSheet.swift` (L3's), `RivalProfileScreen.swift` (nemesis, marked, coordinate with N1's region there), `LifeEvents.json` append (`people_`) |
| N3 | `Assets.swift`, `Systems/AssetsSystem.swift`, `Balance/BalanceConfig+Assets.swift`, `App/Sources/Screens/Life/Assets/**` (the Assets screen, the doctor's office, the casino), `Investors.swift` marked region (`founderNetWorth` counts assets), `Systems/LifeSystem.swift` marked region (vice drift from crunch and parties; ailments from the meters; the existing `chronicCondition`, `hospitalizationDays`, `burnoutDays` in `EconomyState` are read, not moved), `MoneyCard.swift` marked region, `HomeDecor.swift` marked region (a car in the driveway slot), PixelKit `HomeSpriteLibrary.swift` marked region (car, pet sprites), `LifeEvents.json` append (`asset_`, `vice_`) |
| N4 | `Fame.swift`, `Systems/FameSystem.swift`, `Balance/BalanceConfig+Fame.swift`, a `Feed.json` in TycoonContent (takes, replies, headlines), `App/Sources/Screens/Life/Feed/**`, `Systems/MarketingSystem.swift` marked region (fame feeds hype), `Systems/HiringSystem.swift` marked region (fame widens the pool; coordinate: N1 has a region there too, both append), `NewspaperComposer.swift` marked region (the beef column), `LifeEvents.json` append (`fame_`) |
| N5 | `OfficeSecrets.swift`, `Systems/OfficeSecretsSystem.swift`, `Balance/BalanceConfig+OfficeSecrets.swift`, `App/Sources/Screens/Team/Secrets/**`, marked regions in `TeamScreen.swift` (a card), `OfficeCard.swift` (clues in the scene: two people at one desk, a shredder, a closed door), `Social.swift` (new `StaffEventKind`s in a marked region and every switch over it), `StaffEvents.json` append (`office_`), `Events.json` append (`office_`, after N1's) |

Shared, marker-only: `GameAction`, `Reducer`, `GameState`, `AppRouter`,
`DebugLaunch`, `LifeScreen`, `TeamScreen`, `HQScreen`, `BusinessScreen`.
`RivalProfileScreen` and `HiringSystem` each have two lanes' regions; add
yours under your own marker and expect a both-added merge.

## Wave one

### N1 — Crime, scandal and the courtroom

**What.** Fudge the numbers, dodge taxes, poach under an NDA, bribe a
journalist, fake a demo, plant a story about a rival. Each is a real
action with a real gain and a notoriety meter that raises the odds of an
audit, a whistleblower or a lawsuit. A lawsuit is a courtroom scene; the
verdict is a fine, a settlement or prison, which hands the company to a
caretaker for the sentence. You can also sue a rival.

**Build.**

- Six offences as actions in the N1 region, each gated and priced: *cook
  the books* (valuation up for a quarter, notoriety up; an audit finds
  it), *dodge taxes* (the quarterly tax bill halves; notoriety), *the NDA
  poach* (poach a rival's named employee at +50% success; notoriety and a
  rival grudge), *bribe a journalist* (one outlet's review band up a
  notch; notoriety, and the pitch room's journalist remembers), *fake the
  demo* (hype spike for the launch; a live-bug landslide if shipped
  within a fortnight), *plant a story* (a rival's reputation down; their
  strength up if traced). Every gain is a balance value that is identity
  when the action is never taken.
- `notoriety` decays a point a week; the Legal department halves the
  chance any offence is found. Discovery is a weekly `socialRNG` roll per
  offence in the record, and only when the record is non-empty.
- **The case.** Discovery raises a `LegalCase` with a hearing day four to
  eight weeks out; the newspaper leads with it; the phone's office thread
  and the partner post. Until the hearing the player can settle (a
  wallet or company payment scaled by the offence) or prepare: hire a
  lawyer (three tiers, wallet cost) and pick a defence.
- **The courtroom** is a stopped-clock sheet in the pitch room's grammar:
  the judge and the prosecutor across the table, three exchanges (deny,
  explain, apologise, blame the CFO, the lawyer objects), graded on the
  lawyer tier, the founder's conversation attribute and the evidence
  (the record entry's age and the Legal department). Verdict: acquitted,
  a fine, a settlement with a gag order, or a sentence in weeks.
- **Prison** reuses the sabbatical's caretaker autopilot: the founder is
  away with `awayReason` "inside", the meters slide, affection slides
  faster, the board's patience halves, and wave two's *Inside* lane makes
  it a place. Until then, a sentence is a sabbatical you did not choose.
- **Sue a rival** from their profile: a case against them with the same
  machinery reversed; win and take cash and a product off their shelf.
- App: `CrimeCard` in the You section (notoriety as a needle, the record,
  the pending case with its clock), `CourtroomSheet`, the offence buttons
  where they belong (the finance ledger for the books and taxes, the
  hiring sheet for the NDA poach, the war room's press strip for the
  bribe, the launch flow for the fake demo, the rival profile for the
  story and the suit). `-autoRoute courtroom` on a fixture with a case.

### N2 — People you can mess with

**What.** Every person gets a BitLife-sized interaction menu instead of
three buttons: compliment, insult, prank, argue, apologise, flirt, gift,
ask for money, lend money, confide, threaten, mentor, and the big ones
where they apply (propose, divorce, have an affair, disown, fire with
cause). Each has a random outcome line and a visible bar that moves. A
rival founder becomes a personal nemesis you can taunt, sabotage or
befriend.

**Build.**

- `Interactions.json`: for each interaction, the targets it applies to,
  the bar it moves and by how much on a good or bad roll, the cost (an
  evening, wallet, nothing), the cooldown, and eight to twelve outcome
  lines per target kind in the game's voice. Around twenty interactions,
  four hundred lines. Decode-if-present in `ContentCatalog`.
- `InteractionSystem.perform(target, id)`: rolls on `socialRNG` against
  the founder's conversation attribute and the current bar, applies the
  delta to the right bar (`founderBond`/`morale`, `affection`, `Child.
  bond`, `Friend.bond`, `Contact.rapport`, and a new `Rival.grudge` you
  add in a marked region of `Rival.swift`, decode-if-present), posts the
  outcome line to the phone thread, and for children appends a memory
  (`ChildMemory`). Existing actions (`praise`, `giveGift`, `hangOutWith`,
  `spendTimeWithPartner`, `seeFriend` and the rest) stay and are listed
  in the same menu, so nothing the bots do changes.
- The big ones: *propose* and *divorce* route to the existing
  `advanceRelationship` and a new `.breakUp` you add (affection
  collapses, the home stays, the kids stay); *affair* with a contact at
  rapport ≥ 70 is a flag with a discovery roll that wave two's family
  drama reads; *disown* on a grown child; *fire with cause* on an
  employee is `fire` plus a cause line that stops the boomerang.
- Nemesis: the rival with the highest grudge is named on the profile;
  taunt (a feed post if N4 exists, else a press line), sabotage (a
  notoriety cost, reads N1's slot), befriend (grudge down, a joint
  press line).
- App: `PeopleMenuSheet` opened from every person's card with the menu
  grouped (nice, mean, money, serious), each row carrying its cost and
  the bar it moves, the outcome line played on pixel paper with the
  person's portrait. `-autoRoute people` opens it on the partner.

### N3 — Assets, vices and the doctor

**What.** An Assets tab: cars that break down and get stolen, a second
property that rents or floods, pets with names and vet bills, and a
casino, a lottery ticket and a crypto wallet for the founder's own money.
A doctor's office with named ailments and treatments, therapy, and vices
that creep in from launch parties and crunch, with dependency loops and
interventions from the people who love you. Net worth counts all of it.

**Build.**

- Catalog in `BalanceConfig+Assets.swift`: four cars (price, weekly cost,
  breakdown and theft odds, mood and prestige), two properties (price,
  rent, flood odds), three pets (adoption cost, weekly cost, mood drift,
  the vet), the casino (three games with house edges), the lottery (a
  weekly ticket), crypto (a random walk on `socialRNG` seeded from the
  seed, only while a wallet is open). Every asset is bought with the
  wallet; net worth (`founderNetWorth`, marked region) adds resale value.
- Ailments: burnout, RSI, insomnia, a bad back, the chronic condition
  (existing), each with a cause (crunch weeks, low health, a vice), a
  drift on the meters while held, and a treatment at the doctor (wallet,
  days). Therapy is a weekly evening that lowers vice dependency and
  raises mood.
- Vices: drink, caffeine, gambling, and the phone. Dependency 0…100 grows
  from launch parties, crunch and casino visits, drifts mood and health,
  and above 60 triggers an intervention event from the partner or a
  friend. Quitting is a run of evenings with a relapse roll.
- App: `AssetsScreen` from the Money and home section (garage, property,
  pets, wallet games), `DoctorSheet`, `VicesCard`. The car appears in the
  pixel home's driveway slot (decor region) and the pet in the room.
  `-autoRoute assets`, `-autoAssets` fills a garage for screenshots.

### N4 — Fame and the feed

**What.** The founder has a public feed and a follower count. Post a take,
a launch, an office photo, a subtweet about a rival. Things go viral,
sometimes for the right reason. Fame buys hype, hires, a book deal, a
podcast, a keynote, a TV slot. It also buys a cancellation when an old
post surfaces, a stalker, a parody account, a beef the newspaper covers,
and fans at your door.

**Build.**

- `Feed.json`: post templates by kind (take, launch, photo, subtweet,
  reply), replies from the world, and the headlines fame earns. Posting
  is an action (`.post(kind, subject)`), free, one a day; reach is a
  `socialRNG` roll scaled by fame, the post kind and the day's news.
  Followers accumulate; fame is a slow function of followers and recent
  reach; it decays.
- Fame effects, all identity at zero fame: hype on launches
  (`MarketingSystem` region), the candidate pool's size (`HiringSystem`
  region), a rival's grudge on a subtweet (reads N2's `grudge` if
  present, else a press line), and the pitch room's journalist warmth.
- Fame events (`fame_`): the book deal, the podcast, the keynote, the TV
  slot, the cancellation (an old post surfaces: apologise, double down,
  delete), the stalker, the parody account, fans at the door, the beef
  (a rival founder replies; escalate or let it go). The newspaper's
  marked region prints the beef.
- App: `FeedScreen` scrolled like the phone (the founder's posts and the
  world's replies, reach as a number that rolls), `FameCard` in the You
  section (followers, fame as a meter, the next thing fame buys), the
  compose sheet with the four kinds. `-autoRoute feed`, `-autoFame`
  seeds followers for screenshots.

### N5 — The office has secrets

**What.** Your employees do things to you. A mole sells your roadmap to a
rival. Two people are sleeping together and one reports to the other.
Somebody is embezzling through expenses. A clique freezes out the new
hire. A union drive starts the week the round closes. The co-founder is
counting votes for a coup. Each is a slow-burn thread with clues and a
menu of responses, and getting it wrong is a lawsuit or a walkout.

**Build.**

- Six thread kinds, each a small state machine in `OfficeSecretsSystem`:
  a start condition (headcount, a rival grudge, a co-founder origin, a
  round closing, morale), three to four stages with a clue at each (a
  journal line, a phone message from a third party, a change in the
  office scene, an expense line in the ledger), and an ending if ignored
  (the roadmap leaks and a rival ships your topic; the couple splits
  and one quits; the money is gone; the new hire leaves; the union
  changes the pace rules; the coup removes you as an ending only in a
  co-founded run). At most one thread at a time, none before day 120,
  each kind once per company, all on `socialRNG` and only once headcount
  ≥ 4 so the garage bots never see one.
- Responses as actions: investigate (an evening, reveals the stage),
  confront (a staff moment through the existing `StaffEvent` machinery
  with new kinds in `Social.swift`), hire a PI (wallet, reveals all),
  call HR (needs the department), fire with cause (N2's, or plain fire),
  make a deal (money or a policy), ignore.
- App: `SecretsCard` on the Team tab (the thread's clues so far, the
  responses with their costs), the clues in the office scene through
  `OfficeCard`'s marked region (two people at one desk, a shredder by
  the printer, a closed meeting-room door), and staff moments as they
  already appear. `-autoSecret <kind>` on a fixture with a full team.

## Wave two — cut from wave one's merge (`scaffold-11b`)

Wave one is merged and green. These four lanes are cut from that merge
and build on the seams the wave-one reports left (each lane's report
under `iteration-11-lanes/n<n>.md` has a "Seams for wave two" section:
read the ones named in your brief before touching code). The same twelve
rules apply, and rule 12 (thirty or more events, ids prefixed `money_`,
`family_`, `spy_`, `inside_`) too.

### The scaffold (wave two)

- Engine files, one per lane: `DirtyMoney.swift` (W1), `FamilyDrama.swift`
  (W2), `Espionage.swift` (W3), `Prison.swift` (W4).
- `GameState` slots `dirtyMoney`, `familyDrama`, `espionage`, `prison`,
  decode-if-present and encode-when-non-default. Do not add fields to
  `GameState`.
- Marker regions `// MARK: W<n> (…)` in `GameAction`, `Reducer` (systems
  and handlers), `GameEvent`, `AppRouter` (`Route` and its tab switch),
  `DebugLaunch` (flags and route names), `LifeScreen` (cards,
  destinations, destination switch, `consumeRoute`), `BusinessScreen`
  (`consumeRoute`: W1, W3), `TeamScreen` (`consumeRoute`: W3), and
  `EventCopy.swift` (a region per lane, so nobody prints "Something
  happened").
- **Balance keys** go after `"assets"` in `Balance.json`.
- **A test that passes the balance by value at many call sites blows the
  stack in a debug build** (wave one found this). Do not write one; you
  are not writing tests anyway.

### File ownership — wave two

| Lane | Owns |
|---|---|
| W1 | `DirtyMoney.swift`, `Systems/DirtyMoneySystem.swift`, `Balance/BalanceConfig+DirtyMoney.swift`, `App/Sources/Screens/Business/DirtyMoney/**`, marked regions in `InvestorsView.swift` and `FinancesView.swift` (the offer appears where money is), `Crime.swift` marked region (a seventh `CrimeOffence`: laundering), `Systems/CrimeSystem.swift` marked region, `Systems/FinanceSystem.swift` marked region (the invoice to nowhere), `Events.json` append (`money_`), `LifeEvents.json` append (`money_`) |
| W2 | `FamilyDrama.swift`, `Systems/FamilyDramaSystem.swift`, `Balance/BalanceConfig+FamilyDrama.swift`, `App/Sources/Screens/Life/Family/**` (the divorce sheet, the custody hearing's opener, the will, the in-laws), marked regions in `PartnerCard.swift`, `FamilyCard.swift`, `Interactions.swift` (affair discovery), `Assets.swift` (the split), `Crime.swift`/`Systems/CrimeSystem.swift` (a custody hearing through `LegalCase.isFounderSuing` with its own opener and verdict copy), `Systems/FamilyCalendar.swift` (parents' birthdays, the anniversary you now dread), `Legacy.swift` marked region (the will decides the successor), `LifeEvents.json` append (`family_`) |
| W3 | `Espionage.swift`, `Systems/EspionageSystem.swift`, `Balance/BalanceConfig+Espionage.swift`, `App/Sources/Screens/Business/Espionage/**`, marked regions in `RivalProfileScreen.swift` (the spy menu; N1 and N2 have regions there, add yours under your own marker), `OfficeSecrets.swift`/`Systems/OfficeSecretsSystem.swift` (a rival running a thread against you is a new `SecretKind`; counterintelligence is new `SecretResponse`s), `Systems/RivalSystem.swift` marked region, `Crime.swift`/`Systems/CrimeSystem.swift` marked region (`raiseCase(against:)` on discovery), `Events.json` append (`spy_`), `StaffEvents.json` append (`spy_`) |
| W4 | `Prison.swift`, `Systems/PrisonSystem.swift`, `Balance/BalanceConfig+Prison.swift`, `App/Sources/Screens/Life/Inside/**`, marked regions in `Systems/SabbaticalSystem.swift` (the "inside" report variant), `Systems/CrimeSystem.swift` (`servingTime` hands the days to the prison), `Networking.swift` (a cellmate is a `Contact` with a new archetype in a marked region), `AppRootView.swift` marked region (the prison as a full-screen mode while inside, the war room's presentation), `LifeEvents.json` append (`inside_`) |

Shared, marker-only: the scaffold files above. `Crime.swift` and
`CrimeSystem.swift` have three lanes' regions (W1, W2, W3, W4 each under
their own marker); `RivalProfileScreen` has N1, N2 and W3.

### W1 — Dirty money

**What.** When the bank says no and the term sheets dry up, other money
appears: an oligarch's family office, a fund that is a front, a loan
shark who found you at demo day. Fast cash, no board, no diligence, and
strings that tighten every quarter. Refuse and things happen to your
office, your car and your friends. Take it and laundering becomes a line
in the ledger the auditor can find.

**Build.**

- Three backers as content in `BalanceConfig+DirtyMoney.swift`: the family
  office (large cheque, a "consultant" on payroll from month two, a
  product that must ship into a market they name by month six), the
  front (medium cheque, an invoice to a company that does not exist every
  quarter, then "hire my nephew"), the shark (small cheque, weekly vig,
  a visit when a payment is late). An offer appears only when the company
  is in the red or a term sheet was declined this quarter, and only after
  the player has opened the Business tab's finances (an identity gate
  like `noticeAssetsOpened`).
- `DirtyMoneyState`: the backer, the cheque, the strings as a list of
  `Demand`s with due days, the compliance record, and `heat`. Each
  demand is a story sheet with comply / stall / refuse; comply costs what
  it says (payroll, cash, a launch you did not choose), stall raises
  heat, refuse raises heat a lot. Heat pays out as events (`money_`): the
  office window, the car (reads N3's `owned`), a friend's bond, a
  rival's sudden strength. Every payment through them is laundering: a
  seventh `CrimeOffence` in N1's marked region, with its own discovery
  odds, so the auditor can find it and the courtroom can hear it.
- The way out: pay them off (the cheque times a multiple), turn witness
  (`CrimeSystem.confess` on the laundering, a sentence that W4 makes a
  place, and the backer's heat becomes a permanent event source), or
  sell the company to them (the buyout machinery with a `soldUp` ending
  and a line in the biography).
- App: `DirtyMoneyCard` on the Business tab's finances section (the
  offer, the strings with their clocks, heat as a thermometer), the
  demand sheets, `-autoRoute dirtymoney` on a fixture in the red.

### W2 — Family drama

**What.** Marriage has a downside. Affairs get discovered (N2's flag).
Divorce splits the assets (N3's) and the home, and custody of the kids is
a courtroom case (N1's room) with a judge who has read your calendar. The
in-laws have opinions and a spare room. A sibling wants a job, then a
stake, then a loan. Your parents get old and someone pays for the care.
A will decides who gets the company if you die, and the family argues
about it at the funeral.

**Build.**

- Discovery: `FamilyDramaSystem` reads `state.interactions.affairContactID`
  and rolls discovery weekly on `socialRNG` (higher with a standing
  vice intervention, N3's `intervened`, and with fame, N4's), sets
  `affairDiscoveredDay`, posts to the partner's thread, and opens the
  confrontation sheet: confess, deny, end it, leave.
- Divorce: `InteractionSystem.breakUp` first, then the settlement: the
  home stays with whoever the kids stay with; assets split by
  `assetResaleValue` with a wallet transfer; the pet by name; the
  company's equity untouched unless married past a threshold, in which
  case a slice goes (a co-founder-style holder on the cap table). The
  partner's lawyer tier versus yours.
- Custody: a `LegalCase` with `isFounderSuing` and a family opener; the
  evidence is the children's memory ledgers (missed birthdays count
  against you, summers at the studio for you). Verdict: full, shared,
  weekends, none. The children's bond moves with the verdict.
- In-laws (a couple with faces, seeded from the partner's), a sibling
  (one, from onboarding's family), parents (two, ageing on the calendar,
  a care bill that lands on the wallet from year three, a death that
  lands on the phone). The will: a sheet naming the heir (partner, a
  child, the longest-serving employee, the sibling), which the dynasty's
  successor list reads (`Legacy.swift` region). The funeral: a stopped
  day with the family in the room and one argument to settle.
- App: `FamilyDramaCard` under Family, the confrontation sheet, the
  divorce sheet (two columns, drag things between them), the will sheet,
  `-autoRoute divorce` on the family fixture.

### W3 — Espionage

**What.** Do to rivals what the mole is doing to you. A PI on a rival
founder. A mole in their studio. Poaching with dirt. Buying their
roadmap. Hacking their storefront the week of their launch. Rivals run
the same playbook against you, and a counterintelligence menu lets you
sweep the office, audit the roster and feed a mole false plans.

**Build.**

- Five operations as actions in the W3 region, each with a wallet cost,
  a success roll against the rival's strength (and their Legal, if you
  give rivals one: a per-rival flag), a discovery roll with
  `Crime.discoveryChance` and `evidenceWeight`, and a payoff: the PI
  returns dirt (a `Contact`-style dossier that raises your pitch warmth
  against them and your grudge leverage), the mole reports their next
  launch a month early (a rival column line and a board card in M1's
  feature board: "they are shipping X"), poaching with dirt succeeds
  where the NDA poach fails, the bought roadmap lets you ship their
  topic first (copy `leakRoadmap` reversed), the hack drops their launch
  week's sales and raises notoriety most. Discovery raises a case
  against you (`raiseCase`) and a feud (grudge to max).
- Rivals against you: a `SecretKind` per operation on N5's machine (a
  rival's mole, a rival's PI, a rival's hack), started by grudge and by
  your standing in their topics; the counterintelligence menu is new
  `SecretResponse`s (sweep the office, audit the roster, feed false
  plans, which sends the rival into a topic that is about to crash).
- App: `EspionageCard` on the rival's profile (operations with their odds
  and costs, the dossier once you have one), a counterintelligence row on
  N5's `SecretsCard`, `-autoRoute spy`.

### W4 — Inside

**What.** Prison as a place. When N1's courtroom hands down a sentence,
the founder goes inside for its weeks: days with a morning, a yard and a
night, cellmates who become contacts, a gang to join or refuse, a riot,
an escape attempt, parole hearings, and the company running on the
caretaker's autopilot outside while the phone brings you the news.

**Build.**

- `PrisonState`: the sentence, the day count, the cellmate (a `Contact`
  with the new `inmate` archetype, drawn on `socialRNG`, who becomes an
  address-book entry with a rapport when you leave), the gang standing,
  infractions, and parole eligibility. `PrisonSystem.run` replaces
  `CrimeSystem.servingTime`'s daily cost with a day inside: one choice a
  day from a small menu (keep your head down, work in the library, the
  yard, the phone call home, the deal) with meter effects, and events
  (`inside_`: the riot, the shakedown, the visit, the letter from a kid,
  the rival's founder in the next cell).
- The gang: join for protection (bond with the cellmate, a favour owed
  on release that lands as a `money_`-style demand if W1 exists, else a
  contact who asks for a job), refuse for infractions. Escape: one
  attempt, a roll, and failure doubles the sentence; success is a run
  with `awayReason` "on the run" and a case that never closes. Parole:
  a hearing at the halfway mark in the courtroom's grammar, graded on
  infractions and the caretaker's report.
- The caretaker's report on release becomes the "inside" variant in
  `SabbaticalSystem`'s marked region (headed like a release, not a
  holiday). The children's memory ledger records it; the partner's
  affection slides faster; the phone is the only window.
- App: `InsideScreen` as a full-screen mode while the sentence runs
  (pixel cell, the day's menu, the calendar of days left, the phone),
  the parole sheet, `-autoInside <weeks>` on any fixture.

### Working method (wave two)

Same as wave one: worktree per lane, branch `w<n>-<slug>` from
`scaffold-11b`, simulators `ws-l1` … `ws-l4`, every suite plus
`make apptest SIM=ws-l<n>`, report as `iteration-11-lanes/w<n>.md`. The
PM merges W2 → W1 → W3 → W4, runs `make strings` once, and appends the
record to `iteration-11-features.md`.

## Working method

- **Worktree per lane**, branch `n<n>-<slug>` from `scaffold-11`.
- **Simulator per lane:** `ws-l1` … `ws-l5`. Build with `xcodebuild
  -project StartupStudio.xcodeproj -scheme StartupStudio -destination
  'platform=iOS Simulator,name=ws-l<n>' -derivedDataPath build build`
  after `make gen`; launch with `-unlocked -autoSpeed x4` and your flags.
- **Verify before you report:** every package suite you touched plus
  TycoonEngine, and `make apptest SIM=ws-l<n>`. Paste the summary lines.
- **Report** as `docs/product/iteration-11-lanes/n<n>.md` with screenshots.
- **Commit on your branch**; no merge, no push. The PM merges N2 → N1 →
  N3 → N5 → N4, runs `make strings` once, then cuts wave two.

## What "done" looks like

A founder who can cook the books and stand in a courtroom for it, prank
their CTO and apologise, lose the car in a game of cards, post a take that
gets them cancelled, and find out the intern has been selling the roadmap.
And every one of those is a story the player tells.
