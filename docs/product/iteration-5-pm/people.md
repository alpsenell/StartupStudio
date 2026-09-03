# Iteration 5 — People and life

Lens: employees and team dynamics, hiring and traits, the founder's own life,
the networking floor, and the narrative. Read: `README.md`, the iteration 3
and 4 docs and the workstream status, `git log`, the people half of the engine
(`Employee`, `Social`, `Life`, `Networking`, `Narrative`, `TraitEffects`,
`Organization`, and `EmployeeSystem`, `SocialSystem`, `RelationshipSystem`,
`LifeSystem`, `LifeEventSystem`, `NarrativeSystem`, `NetworkingSystem*`,
`TraitSystem`, `HiringSystem`), the six content tables, the Team and Life
screens, `Balance.json`'s `staff` / `social` / `relationships` / `life` /
`networking` blocks, and `BalanceTargetsTests`. Screenshots from a bot run on
the Pro Max simulator are under `scratchpad/pm/people/` (`life-01.png`: the
clock stopped at Jan W3 on a legal question; `team-01/02.png`: the Team tab at
Feb W5 and W8, one row).

A note on the brief. It asks for "a person who does something back, a
relationship with a memory, a story with a second act, a life decision that
changes how the company plays". That is the right ask — but the thin place is
not the *amount* of people content (11 staff kinds, 59 life beats, 14 traits,
42 bios, 44 headlines is plenty). It is that almost none of it remembers
anything, and the story's effect vocabulary cannot reach the three
relationship numbers the game added this week. Every idea below is an edge
between things that already exist.

## Where people and life are thin now

**1. Staff moments have no memory, and the copy promises they do.**
`StaffEvents.json` is 11 kinds, every one a supportive/strict pair of instant
deltas (`StaffEventDef.Outcome`: cash, morale, loyalty, moraleAll, reputation,
salaryPercent, clearsAssignment, skill, setFlag — no follow-up, no gate on a
flag). Four outcomes write flags — `ip_generous`, `good_leave_policy`,
`remote_friendly`, `process_trusted` — and `grep` over the engine and the app
finds no reader for any of them; the only `hasFlag` is its own definition
(`Narrative.swift:139`). `parentalLeave`'s body says *"There is no policy.
Whatever you say next becomes the policy."* It doesn't. `promotionDemand` says
they *"watched someone else get called senior for less"*; the engine never
knows who was promoted over whom (`EmployeeSystem.promote`, `:922`, is salary
+15% and morale +15, pure upside for cash). `SocialSystem.applyStaffChoice`
(`:308`) applies the numbers and forgets the person asked.

**2. The life story has no second act and cannot touch the numbers that
end things.** `LifeEvents.json`: 59 beats, **0** with a follow-up, **0** flags
set, 31 with no choice at all; of the 62 choices in the other 28, all 62 spend
`founderMeters`. `EventEffect` has 15 cases and not one reaches
`life.family.affection` (the number `RelationshipSystem.driftAffection` uses to
end a relationship), `eveningsSpentThisWeek` (the Life tab's scarce resource,
per `Life.swift:475-486`), or `founderBond`. So `partner_asks_future` offers
*"Give them a real answer with a date in it · you have to keep it"* and
schedules nothing; `partner_job_offer` offers *"Ask them to stay one more
year · they stay"* — no year, no return. The engine already supports
`followUpOnly` and `followUpEventID` on `LifeEventDef` (`NarrativeSystem.fireLife`,
`isEligible(_:state:)`); the content just never uses it. Children are
`Child(name, bornDay, seed)` whose whole life is `childDrift` (−0.3 energy,
+0.2 mood a day) and $80 a week; six beats gate on `requiresChildren`, all
meter pops.

**3. Leaving is deletion.** A quit (`EmployeeSystem.swift:219`), a firing
(`:1036`) and a successful poach (`RivalSystem.poachSucceeds`) remove the
employee; `pruneEconomyBookkeeping` (`:48`) then scrubs their recognition day.
The reverse path is closed too: hiring a contact sets `outcome = .hired`, and a
closed contact "never appear[s] in a room again" (`Networking.swift:692-695`).
The poach sheet is therefore *pay the premium* or *lose them forever*
(`GameAction.matchPoachOffer` / `declinePoachOffer`); nothing you built with
a person — bond, friendships, an interview — survives their leaving.

**4. Nobody wants anything but pay and a nice office.** The morale target in
`EmployeeSystem.updateMoraleAndQuits` (`:146-163`) is: pay ratio, office tier,
perks, workplace conditions, traits, crunch, leadership, bond, stagnation.
Never the assignment. `Assignment` has six cases and the person in the seat is
indifferent between all of them. The manage sheet's `moraleCauses`
(`EmployeeManageSheet.swift:162-201`) can name pay, the office, perks, HR and
personality; it cannot say "they hate the contract work" because there is no
such fact. Iteration 3 named this (idea #3, *Ambitions*) and it was not built.

**5. The address book cannot be dialled, and nobody in it ever calls.**
`NetworkingSystem.run` does two things on its own: decay rapport 0.15/day and
settle holdings. Every other verb — `talk`, `makeOffer`, `leaveEvent` — is the
player's, and `talkToContact` is gated on a `pendingEvent` that contains them.
The address-book row shipped this week says *"Fading — call this week"*
(`AddressBookSheet.swift:111`); there is no call. The only way to see a contact
again is to spend a $150 weekend and hope they are one of the two returning
faces `startEvent` seats.

**The pacing contract, for everything below.** `BalanceTargetsTests` runs
with `rivals.rivalCount = 0` (`:31`), so poach-side effects are quarantined;
the two gates anything on the morale target can break are
`neglectfulBossLosesPeople` (`:296`) and `lookingAfterPeopleKeepsThem`
(`:306`); and `autoPausesStayWithinBudget` (`:438`) counts pauses, so **no
idea here adds a roll** — new beats take the slot of an existing roll
(life every 14 days at 0.35, staff every 21 at 0.5) or ride the scheduled
follow-up path. Every new multiplier reads 1.0, every new delta 0, at the
shipped default; where a bot could feel a term, the doc says which gate.

---

## Candidates, ranked

### 1. The answer becomes the policy · M

**The player's sentence.** "I gave Priya three months' paid leave in year one,
so when Marco asked in year two nobody asked me — it just came out of the
account. And I told Yusuf he couldn't go remote, and he remembered."

**Problem.** Finding 1. Eleven good scenes that never compound.

**How it plays.** A *supportive* answer to a policy-shaped staff moment
(`parentalLeave`, `remoteRequest`, `sideProject`, `harassmentComplaint`,
`raiseRequest`, `roleSwitch`) sets a **policy** — the flag the content already
writes. From then on the same kind does not pause for the next person: the
policy answers, the same numbers land, and the rail and ledger say so
("Parental leave: Marco — −$4,000 · the policy"). Policies show on a new
*How we do things here* card on Team, each with the day and the person who
set it, and each can be **reversed** — publicly: everyone who benefited takes
`moraleAll −N` and loyalty, the flag flips to its inverse (`leave_statutory`),
and the next asker gets the sheet again. The strict answer sets no policy by
default — refusing one person is not a rule — but the sheet offers "…and make
that the rule" as a third button, which is the cheap-now, remembered-later
choice.

Second acts ride the flags: `StaffEventDef.Outcome` gains `followUpEventID` /
`followUpDelayDays` and `Gate` gains `flagsAll` / `flagsNone`, so content can
write the scenes the bodies already promise — a `sideProject` answered strict
returns in 90 days as the same person handing in notice with a reason
(`PendingResignation` gains `reason`) and the office-scene box under their
desk; `harassmentComplaint` answered with "a quiet word" returns in 30 as a
second complainant and reputation −6; `remote_friendly` makes `teamConflict`
twice as likely and halves `bondGrowthPerWeek` for people who never share a
room; `good_leave_policy` takes 5% off every candidate's ask
(`refreshCandidates`, one multiplier, 1.0 without the flag). The optional
cross-lane act: `sideProject` strict + they leave → the project ships as a
rival copycat in their old topic (`RivalSystem.copycat` already exists).

**The decision.** The generous answer at headcount 4 is a commitment paid at
headcount 14, automatically, in a bad quarter. The strict answer is free today
and makes one specific person's second act likelier. Reversing is possible and
everybody sees it. Lands from the first staff moment (day ~21–42).

**Touches.** `StaffEventDef` (+follow-up, +flag gate — decode with defaults),
`SocialSystem.staffEventCheck` (policy short-circuit before the pending event;
still counts as the beat), `applyStaffChoice`, `isEligible` (flags),
`ScheduledNarrativeEvent` (+`source: .staff`, +`employeeID: UUID?` —
append-only enum, optional field), `NarrativeSystem.fireScheduled` (staff
branch → `pendingStaffEvent`), `PendingResignation.reason`, `Economy`/
`NarrativeState.flags` (already persisted), `StaffEvents.json` (+8–10
follow-up defs), `EmployeeManageSheet.moraleCauses` (+"You said no in March"),
new `PoliciesCard` on Team, the staff sheet's third button. Save: optional
fields only, no format bump.

**Balance.** The bots never answer supportively (`autoResolveStaffEvent` picks
strict at the deadline), so no policy is ever set in a pacing run and the
baseline table is byte-identical. Policy auto-answers apply the *same*
outcome the sheet would have, so a player's roster numbers move exactly as
they do today, minus a pause — which helps `autoPausesStayWithinBudget`.

**Risk.** It reads as the "culture toggles" iteration 3 cut. The guard: a
policy can only be *created* by a person asking, never from the card; the card
shows and reverses. If playtesters never reverse one, the reversal cost is too
high or the follow-ups are too soft.

**Verify.** Engine test: answer `parentalLeave` supportive for A; fire it for
B → no pending event, cash −4,000, ledger line, flag; reverse → `moraleAll`
delta on A, flag flipped, B's next request pauses. A test that
`StaffEvents.json` follow-ups all resolve to a def. Snapshot of the card.

### 2. The date in the diary · M

**The player's sentence.** "Sam's birthday is launch week. I'm on crunch, I
have one evening, and I've already promised it to the coach."

**Problem.** Finding 2. The Life tab has a scarce resource and nothing that
claims it on a date; the family beats name the collision and then spend a
meter on both sides.

**How it plays.** Three new effect types — `affection(amount)`, `evening`
(the option books one; with `requires.minEveningsLeft` on the option, "Go"
greys out when the week is spent, which is the bite: on crunch that is one
evening), and `bond(amount, pick)` — and the family gets a **calendar**: an
anniversary on `stageSinceDay + 365`, each child's birthday on
`bornDay + 365k`, and the follow-up a promise creates (`partner_asks_future`
"a date in it" → 90 days later, an option gated on `hasLiveProduct`: you kept
it or you didn't). Dated beats are *scheduled*, not rolled — but they take the
life roll's slot on the next interval day inside a 10-day window rather than
adding a pause, and they land on the rail as a deferred choice with a real
countdown, which WS-A and WS-D built for exactly this. Missing one costs
affection −20 and sets a flag the next beat reads ("You missed the last one
too"). Ten to fourteen new life defs give the eight existing partner/kid
beats a second and third act (`partner_job_offer` "stay one more year" →
the year ends; `recital_vs_dinner` → the kid brings it up; `kid_sick_night`
→ the second night).

**The decision.** A named evening in a named week against crunch's one
evening, the coach, or the new hire a rival is courting; or move the launch
(`wedding_on_launch_week` already prices that at hype −18). Lands ~day 365 of
a relationship and from year two for children — mid-run, when the company is
big enough that a week matters.

**Touches.** `EventEffect` (+3 cases), `NarrativeSystem.apply` (+3 arms),
`EventRequirements` (+`minEveningsLeft`; `availableOptions` already filters),
`LifeSystem.advanceRelationship` / `haveChild` / `NetworkingSystem.askOut`
(schedule the dates into `NarrativeState.scheduled`, source `.life`),
`NarrativeSystem.rollLifeEvent` (a due dated beat pre-empts the weighted
pick), `LifeEvents.json` (+~12 `followUpOnly` defs), `FamilyCard` (a "next:
Sam's birthday · 9 days" line), `PartnerCard`, `DecisionSheet` (a greyed
option with its reason — the sheet has never had one). Save: nothing new;
`scheduled` is already persisted.

**Balance.** Bots are single and childless, so no date is ever scheduled and
the life roll is unchanged. If a bot ever dates, the miss option is the
auto-answer, so an unattended partner loses affection the way neglect drift
already does; check `threeYearsOfPlayProducesRealConsequences`.

**Risk.** Nagging. One dated obligation per person per 60 days, the
auto-answer is always the polite miss, and never a date inside the first 90
days of a stage. If playtesters always send flowers, the affection cost is
too low or the evening gate never bit — check how often "Go" was greyed.

**Verify.** Engine test: dating on day 10, spend the week's evenings, run to
day 375 → the anniversary is pending on the next interval day with "Go"
absent from `options`, "miss" → affection −20 and the flag; the second act
30 days later requires it. Snapshot the sheet with the greyed option.

### 3. The boomerang · S–M

**The player's sentence.** "Marco left for Meridian Works in March. I ran
into him at demo day in September, senior now, and hired him back for less
than the match would have cost."

**Problem.** Finding 3.

**How it plays.** Anyone who leaves — quit, poached, fired — becomes (or
re-opens as) a `Contact`: archetype from their role (the inverse of
`ContactArchetype.employeeRole`), skills carried, `rapport = founderBond`,
`isRevealed = true` (you know their traits), `askingSalary` = the poach offer
if poached else fair pay × 1.1, plus `leftDay` and `leftReason`. They keep
moving off-screen: +3 skill points a quarter away, and a `prodigy` or
`showman` who leaves gets `companyName` and a valuation after 180 days —
they went and founded something, and `backThem` opens. They appear as the
returning faces `startEvent` already seats, and the address book rows read
"Left in March · was your backend dev". Recruiting them back is the existing
`.recruit` offer at the new ask; `founderBond` comes back with them. A firing
with a bond under 30 leaves at rapport 0, `.lost` — you burned them.

**The decision.** The poach sheet gets a third future: match the premium now
(and the salary band moves), or let a Flight Risk go warm and buy the senior
version back next year. Firing a friend now costs the friend's morale
(already) *and* the contact. Lands the first time somebody leaves.

**Touches.** `NetworkingSystem` (+`departed(_:reason:state:)`), three call
sites — `EmployeeSystem.updateMoraleAndQuits` quit path, `EmployeeSystem.fire`,
`RivalSystem.poachSucceeds` (one line, cross-lane) — `Contact` (+`leftDay`,
`leftReason`, decodeIfPresent), a weekly skill drift in `NetworkingSystem.run`
for former employees, `AddressBookSheet` / `ContactSheet` header copy, the
poach `DecisionSheet` copy ("You'll see them again"). Save: optional fields.

**Balance.** Creating the contact draws nothing (id and appearance reused).
Bots run with rivals off and never plan a networking weekend, so the address
book is inert in every pacing run; `trimContacts` (cap 40) handles a long
game. Verify that `PacingBots` never plan `.networking` — if one does, the
returning-faces slot *reduces* `socialRNG` draws and the run must be re-pinned.

**Risk.** It is a reward if the boomerang is always good. The ask carries the
premium they left for, half the alumni come back at rapport 0, and an alum
takes a room slot (3–5) a stranger would have had. If nobody ever hires one
back, the ask is too high; if everybody does, the rival premium is too low.

**Verify.** Engine test: hire, let quit → contact with rapport = bond and
`leftReason`; open a room → they're in it; `.recruit` → on payroll at the new
ask, `hiredDay` today, bond restored. Fired with bond 10 → rapport 0,
`.lost`.

### 4. What they want · M

**The player's sentence.** "Priya wants product work and I've had her on the
client job for two months. Marco wants the title I just gave Priya."

**Problem.** Finding 4. Iteration 3's *Ambitions*, unbuilt, sharpened with the
one want that is a second act of *your* action.

**How it plays.** Every hire has one **want**, derived from traits and role
the way traits derive from the seed — a pure function, no RNG, no save
field: *build things* (product, not contract or support), *learn* (a `mentor`
on the roster, or the founder mentoring or training them inside 60 days),
*a credit* (be on a product the day it ships), *the title* (nobody junior to
them promoted first). A frustrated want, after 28 days, is −8 on the morale
target — smaller than underpaid's 25, a nudge you can ignore for a month —
and it is the *first* line on the manage sheet and the roster's status row
("Wants product work · 9 weeks on a contract"). *The title* is the grievance:
`promote` sweeps for anyone at the same rank with an earlier `hiredDay` and
sets `passedOverDay`; `promotionDemand` becomes eligible only from a
grievance, so the scene the content wrote finally has the cause it describes.
Relief valves already exist: reassign, `mentor`, `train`, `oneOnOne` (clears
the streak), `promote`.

**The decision.** The best backend dev wants product work and the contract
that pays payroll needs exactly them. Promote the prodigy and the workhorse
who has been there a year longer starts reading job ads. Lands from the
second hire.

**Touches.** `Employee` (+`wantFrustratedSinceDay: Int?`, +`passedOverDay:
Int?`), `TraitEffects` (+`derivedWant(appearanceSeed:role:)`),
`EmployeeSystem.updateMoraleAndQuits` (+one term), `EmployeeSystem.promote`,
`SocialSystem.isEligible` (`promotionDemand` requires a grievance),
`EmployeeManageSheet.moraleCauses`, `EmployeeStatus`, `TeamScreen` row,
`Balance.json` (`wantFrustrationPenalty`, `wantPatienceDays`). Save: two
optional fields.

**Balance.** The bots assign everyone to product work (*build* satisfied),
never promote (*title* never frustrated), and ship products (*credit*
satisfied); only *learn* can bite a bot — so *learn* must count `train` and a
`mentor` colleague as satisfied, and the penalty must be verified against the
baseline table before it ships. The two gates are `neglectfulBossLosesPeople`
and `lookingAfterPeopleKeepsThem`. The satisfied bonus is 0, not positive.

**Risk.** Iteration 3's own note: with four people there is no slack, so early
it is pure punishment. −8 with 28 days' patience and a want that most rosters
satisfy by default keeps it a nudge; if the first-month resignation rate
rises in playtests, gate the frustration on headcount ≥ 5.

**Verify.** Engine test: *build* want on a contract 28 days → target −8 vs.
control; promote a junior over a longer-tenured peer → `passedOverDay`,
`promotionDemand` eligible; the two morale gates unchanged.

### 5. They call you · M

**The player's sentence.** "Yusuf from the rooftop party rang. He's quit, he
wants a desk by Friday at ten percent under what he asked in June, or he takes
the other offer."

**Problem.** Finding 5. The floor is a place you go; nobody in it does
anything back.

**How it plays.** Two halves. The small one is the missing verb:
`callContact(contactID:)` costs an evening, restores `talkRapport × 0.6 ×
charm`, and refreshes `lastMetDay` — the action the "call this week" row is
asking for. The real one is the call coming the other way: on a life-roll
interval day, a warm open contact (rapport ≥ 50) may take the slot instead of
a random beat, keyed by archetype: an engineer or designer *has quit* — hire
them this week at asking −10% or they close as `.lost`; a founder's *round
closes in five days* — `stakePrice` at a discount, from the wallet; an
investor *has a term sheet* — the existing `angelTerms` with a deadline; an
operator or marketer *wants an intro to your best engineer* — say yes and that
person is `courtedUntilDay` for 60 days (poach chance ×1.5, and the
`rivalOfferRumor` staff moment is true for once), say no and rapport −20.
Each is a `PendingChoice` whose options *are* the existing offers, so the
terms come from `Contact` and cannot drift from the sheet.

**The decision.** The hire you didn't plan at a headcount cap ("No desk for
them" — upgrade early?) against losing a warm contact for good; a favour that
puts your own person at risk. Lands after the first networking weekend that
went well.

**Touches.** `GameAction` (+`callContact`), `NetworkingSystem` (+call,
+`contactCall` generator: pure function of state plus one `socialRNG` word on
the interval), `NarrativeSource` (+`.contact`), `Reducer.resolveChoice`
branch, `Employee` (+`courtedUntilDay: Int?`), `RivalSystem.poachCheck` (one
read, cross-lane), `ContactSheet` (call button, the offer as a decision),
`AddressBookSheet`, six to eight templates in a small `ContactCalls.json`.
Save: one optional field.

**Balance.** Bots never network, so no bot has a contact and no call ever
fires; the life roll's draw count is unchanged when no warm contact exists.

**Risk.** The engineer call is a free hire if −10% is always good; the desk
cap and payroll are the cost, and the call only comes at rapport ≥ 50, which
took a weekend and turns to earn. If every call is accepted, drop the
discount to 0.

**Verify.** Engine test: warm engineer contact, interval day → pending
contact choice; accept at the cap → "No desk"; decline → `.lost`; no warm
contact → identical RNG stream to today.

---

## Rejected

- **Headlines with hands** (a rival's layoffs flood the candidate pool; a
  rival's round raises poach risk) — an opportunity with no cost on the other
  side; the 44 headlines are cosmetic on purpose and this would not make one a
  decision.
- **Referrals** (an employee vouches for a candidate: hidden trait free, an
  instant friendship) — pure upside dressed as a mechanic; the interview
  already prices the reveal at a day of energy.
- **Hire your partner / a co-founder on payroll** — one great scene, then a
  permanent coupling of affection to morale, pay and firing that every other
  system has to know about; too much scaffolding for the one moment. (Also
  cut: children who grow up — realism, no decision.)

## If you build one thing from this lane

**The answer becomes the policy.** It is content-driven, it makes the eleven
scenes already written compound instead of evaporate, the bots cannot feel it,
and it removes pauses rather than adding them. The diary is the life half's
equivalent and should follow it, because both share the same three effect
types and the same follow-up plumbing.
