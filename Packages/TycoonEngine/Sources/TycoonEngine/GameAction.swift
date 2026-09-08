import Foundation

/// Player-initiated commands, applied synchronously via `Reducer.apply`.
public enum GameAction: Codable, Equatable, Sendable {
    case startProduct(typeID: String, topicID: String, name: String, focus: PhaseFocus)
    case setPhaseFocus(productID: UUID, focus: PhaseFocus)
    case ship(productID: UUID)
    case hire(candidateID: UUID)
    case fire(employeeID: UUID)
    case assign(employeeID: UUID, to: Assignment)
    case startResearch(nodeID: String)
    case cancelResearch
    case acceptContract(offerID: UUID)
    case startCampaign(kindID: String, productID: UUID)
    case upgradeOffice
    case setWorkSchedule(WorkSchedule)
    /// Weekly founder salary, clamped to 0...`balance.life.founderSalaryMax`.
    case setFounderSalary(Int)
    case planWeekend(WeekendActivity)
    case upgradeHome
    case advanceRelationship
    case haveChild
    /// One-on-one morale boost, at most once per praise cooldown.
    case praise(employeeID: UUID)
    /// Sets a new weekly salary (raises lift morale, cuts hurt it).
    case adjustSalary(employeeID: UUID, weeklySalary: Int)
    case promote(employeeID: UUID)
    case demote(employeeID: UUID)
    /// Paid training: boosts one skill and morale, per-employee cooldown.
    case train(employeeID: UUID, skill: TrainableSkill)
    case takeLoan(amount: Int)
    case repayLoan(amount: Int)
    /// Buys an office amenity (tier-gated, cash up front, weekly upkeep).
    case buildAmenity(Amenity)
    /// Matches a rival's pending poach offer: the employee's salary rises
    /// to the offered amount and their loyalty jumps.
    case matchPoachOffer
    /// Lets the poached employee leave for the rival.
    case declinePoachOffer
    /// Sells the company to the rival behind the pending buyout offer —
    /// ends the run as a successful exit.
    case acceptBuyout
    case declineBuyout
    /// Buys a rival studio outright (cash- and dominance-gated); part of
    /// its team joins.
    case acquireRival(rivalID: UUID)
    /// Moves the office to another district (an owned space is auto-sold
    /// first).
    case relocateOffice(district: DistrictID)
    /// Buys the current office space instead of renting it.
    case buyOffice
    /// Sells an owned office space and goes back to renting.
    case sellOffice
    /// Does a same-day life activity (gym, walk, cinema, restaurant) —
    /// instant meter effects, wallet cost, cooldown-gated.
    case doInstantActivity(InstantActivity)
    /// Buys a possession from the shop (wallet money, once per item).
    case buyItem(itemID: String)
    /// Coffee with one employee (small morale + loyalty, cooldown-gated).
    case grabCoffee(employeeID: UUID)
    /// A one-on-one: big loyalty, clears the low-morale streak.
    case oneOnOne(employeeID: UUID)
    /// A gift (pricier, big morale + loyalty).
    case giveGift(employeeID: UUID)
    /// Dinner for the whole team (per-head cost, global cooldown).
    case teamDinner
    /// Answers the pending staff event.
    case resolveStaffEvent(choice: StaffEventChoice)

    // Reserved regions — each workstream appends its new cases inside its
    // own region and nowhere else, so six branches never touch the same
    // line. Keep the regions in this order.

    // MARK: WS-A

    /// Repositions a released product on the price ladder. Budget trades
    /// margin for reach, premium the reverse — and a premium price on a
    /// product the press did not love drives subscribers away.
    case setPriceTier(productID: UUID, tier: PriceTier)
    /// Puts a released product back into a short patch cycle. On
    /// completion it gains quality, is re-reviewed, and gets one bumper
    /// sales week.
    case startUpdate(productID: UUID)
    /// Sets the pace the whole company works at.
    case setWorkPace(WorkPace)

    // MARK: WS-B

    /// Answers the pending narrative choice. `eventID` must match the
    /// choice on screen (a stale sheet can't resolve a newer beat) and
    /// `optionIndex` is the option's index in the definition, which
    /// `ChoiceOption.index` carries.
    case resolveChoice(eventID: String, optionIndex: Int)

    // MARK: WS-F

    /// Takes the investor's money: cash in, equity out, and a board seat
    /// if the term sheet asked for one.
    case acceptInvestment
    /// Turns the term sheet down and stays independent.
    case declineInvestment
    /// Files to go public. Gated on valuation, profitable quarters and
    /// recurring revenue; ends the run as an IPO.
    case fileIPO
    /// Spends a day of founder time interviewing a candidate, revealing
    /// the trait their CV didn't mention.
    case interviewCandidate(candidateID: UUID)
    /// Clears a candidate out of the pool without hiring them.
    case passOnCandidate(candidateID: UUID)

    // MARK: The codebase

    /// Starts a new product on the codebase a previous product left
    /// behind: part of the pools already filled, and its technical debt
    /// inherited along with them.
    ///
    /// A separate case rather than an extra parameter on `startProduct`
    /// (Swift enum payloads take no defaults) — and separate is the better
    /// shape anyway: greenfield stays the action it always was, byte for
    /// byte, and the one screen that offers the trade is the only caller
    /// that has to know the trade exists.
    case startProductOnCodebase(
        typeID: String, topicID: String, name: String, focus: PhaseFocus, codebaseID: String
    )

    // MARK: Founder & people

    /// Spends the day getting better at one of the founder's own five
    /// attributes. Wallet money above self-study, energy always.
    case trainFounderSkill(skill: FounderSkill, method: TrainingMethod)
    /// One exchange with somebody standing in the networking room.
    case talkToContact(contactID: UUID, topic: ConversationTopic)
    /// Puts a deal to a contact on the terms they have already named.
    case makeNetworkingOffer(contactID: UUID, offer: NetworkingOffer)
    /// Calls it a night and closes the room.
    case leaveNetworkingEvent
    /// Spends the founder's own evening on their partner.
    case spendTimeWithPartner(PartnerActivity)
    /// An evening out with somebody on the team, on the founder rather
    /// than on the company.
    case hangOutWith(employeeID: UUID)
    /// The founder teaches somebody one of the three trainable skills.
    case mentorEmployee(employeeID: UUID, skill: TrainableSkill)
    /// Borrows past what the bank will lend the company on its own name,
    /// against the founder's home. Draws the unsecured headroom first.
    case takeSecuredLoan(amount: Int)

    // MARK: Iteration 5

    // Appended by the scaffold; each lane implements its own handler in
    // its own `Reducer.apply` region.

    /// WS-A: lets a challenged category go without answering. The
    /// answers that defend it are actions the game already has.
    case concedeCategory
    /// WS-A: answers a challenge with one of those actions — budget tier,
    /// a patch, a social push — routed to the player's best live product
    /// in the topic. The challenge counts as answered only when the
    /// routed action took effect.
    case defendCategory(topicID: String, defense: CategoryDefense)
    /// WS-B: pays a seated round out of the cap table and its ask off the board.
    case buyBackRound(investorID: String)
    /// WS-B: takes a strategic buyout as 60% now and the rest over two
    /// quarterly reviews with the acquirer seated as the board.
    case acceptBuyoutEarnOut
    /// WS-D: reverses a staff policy, publicly.
    case reverseStaffPolicy(flag: String)
    /// WS-G: declares the company built, still owning all of it. Gated the
    /// way `fileIPO` is; ends the run as `.independent`.
    case declareIndependence

    // MARK: Iteration 7

    // Appended by the scaffold; R5 implements the handler in its own
    // `Reducer.apply` region. Heirlooms, rules and modes are `newGame`
    // parameters or state, not actions.

    /// R5: keeps running the company after an ending that allows it (IPO,
    /// *Still yours*). Handled before the game-over guard; refused after
    /// every other ending.
    case continueAfterEnding

    // MARK: Iteration 9 — the Life tab

    // Reserved regions again: each lane appends its cases between its own
    // two markers and nowhere else, and implements the handler in the
    // matching region of `Reducer.apply`.

    // MARK: L1 (phone)

    /// Opening a thread on the phone: everything in it counts as seen, and
    /// the Life tab's unread badge drops by that much. Bookkeeping only.
    case markPhoneThreadRead(counterpart: PhoneCounterpart)

    // MARK: L2 (life score, Walked away)

    /// The founder hands the company over and goes. Refused unless
    /// `GameState.canWalkAway` — the button reads `walkAwayBlocker` and
    /// says why before it is pressed.
    case walkAway

    // MARK: L3 (children)

    /// One evening, one child: a stage-appropriate vignette, a bond bump
    /// and a memory. Refused while away, while the child is grown, inside
    /// the per-child cooldown, or with no evening left this week.
    case spendTimeWithChild(childID: UUID)
    /// A teenager with a strong enough bond spends the summer at the
    /// studio: a temporary, unpaid seat on the roster for eight weeks.
    case hireChildIntern(childID: UUID)
    /// Ends that summer early. Costs bond, and they remember it.
    case endChildInternship(childID: UUID)

    // MARK: L4 (friends)

    /// A phone call to a friend: free, once a week, a little bond.
    case callFriend(friendID: UUID)
    /// An evening with a friend: one evening, a small bill, bond and the
    /// relationships meter.
    case seeFriend(friendID: UUID)
    /// Puts a friend on the payroll, carrying the bond they already had.
    case hireFriend(friendID: UUID)
    /// Backs a friend's company out of the founder's own wallet.
    case investInFriend(friendID: UUID, amount: Int)
    /// A personal loan from a friend: no interest, and no company money.
    case borrowFromFriend(friendID: UUID, amount: Int)
    /// Pays some of that loan back.
    case repayFriend(friendID: UUID, amount: Int)

    // MARK: L5 (side project)

    /// L5: picks up one of the five tracks. Free, and refused while
    /// another one is under way.
    case startSideProject(track: String)
    /// L5: one evening on the current project.
    case workOnSideProject
    /// L5: puts it down. Finished chapters stay finished; the current one
    /// does not.
    case abandonSideProject

    // MARK: L6 (sabbatical)

    /// Hand the company to `caretakerID` and go away for `weeks`.
    /// Refused with a reason from `GameState.sabbaticalBlocker` /
    /// `caretakerBlocker` — tenure, bond, a build about to land, and a
    /// wallet that has to cover the whole trip up front.
    case startSabbatical(caretakerID: UUID, weeks: Int)
    /// Fly home early. Costs the caretaker's bond; refunds nothing.
    case endSabbaticalEarly

    // MARK: L7 (furnish)

    /// L7: stands an owned possession or an earned piece of decor in one
    /// of the home's slots, moving it out of any slot it was in and
    /// evicting whatever was there. Cosmetic: no meter moves.
    case placeDecor(slot: String, itemID: String)
    /// L7: empties a slot. The thing goes back on the shelf, not away.
    case removeDecor(slot: String)

    // MARK: end of Iteration 9

    // MARK: Iteration 10 — interactive rooms

    // MARK: M1 (feature board)

    /// M1: puts a feature card in one of a product's board slots. A slot
    /// past the last placed card appends; a slot inside the board replaces
    /// what was there. Refused once design is finished, and for a card the
    /// studio has not researched.
    case placeFeature(productID: UUID, cardID: String, slot: Int)
    /// M1: takes the card in `slot` off a product's board.
    case removeFeature(productID: UUID, slot: Int)

    // MARK: M2 (pitch room)

    /// M2: sits the founder down with the person behind a term sheet, a
    /// contract offer, a launch or a board review. `subjectID` names the
    /// offer or product when there is a choice; `nil` takes the one the
    /// engine would pick. Refused with a room already open, with nothing
    /// to talk about, and once that subject has been talked to.
    case openPitch(counterpart: PitchCounterpart, subjectID: UUID? = nil)
    /// M2: one exchange in the room, in the networking floor's grammar.
    case sayInPitch(topic: ConversationTopic)
    /// M2: gets up. Whatever was said is priced into the paperwork.
    case leavePitch

    // MARK: M3 (incident room)

    /// M3: puts somebody on one of the room's three lanes, or takes them
    /// off it (`thread: nil`). Refused for a founder who is away.
    case assignToIncident(employeeID: UUID, thread: IncidentThread?)
    /// M3: picks what the company says in public. Changeable until the
    /// room closes; it lands at `.resolveIncident`.
    case chooseIncidentStatement(id: String)
    /// M3: one hour of the room. The room's own clock is an action so the
    /// whole incident replays from the log.
    case advanceIncident
    /// M3: closes the room and lands it on the world. Refused until a
    /// statement has been chosen.
    case resolveIncident
    /// M3: the app's one flag — the player has opened the Products tab in
    /// this run, so incidents may be raised. Nothing else sets it, which
    /// is what keeps the pacing bots and the fixtures where they are.
    case noticeProductsOpened

    // MARK: M4 (leagues)

    // MARK: M5 (morning desk)

    /// M5: records one of the morning desk's three papers as done on the
    /// wall-clock day `today` (`yyyymmdd`). The day is passed in because
    /// the desk is the one part of the game that lives on the player's
    /// calendar rather than the simulation's — the engine is told what
    /// day it is and never asks.
    ///
    /// Bookkeeping only: it moves no meter, spends nothing and never
    /// advances the clock. The three papers dispatch ordinary actions of
    /// their own (`.markPhoneThreadRead`, `.praise`, `.grabCoffee`)
    /// alongside this one.
    case clearDeskCard(part: DeskPart, today: Int)

    // MARK: M6 (bug hunt)

    /// A thumb on a bug crawling over a coder's desk: takes one off that
    /// build's `openBugs`, at most `balance.bugHunt.perDay` a day.
    /// Refused past the cap, on a build that has shipped, and on one
    /// nobody has started coding — `BugHunt.refusal` says which.
    case squashBug(productID: UUID)

    // MARK: end of Iteration 10

    // MARK: Iteration 11 — the founder's darker life

    // MARK: N1 (crime and the courtroom)

    /// Does one of the six things a founder should not do. `rivalID` and
    /// `productID` name the subject where the offence has one; `nil` means
    /// "the obvious one" (the first rival, the build in flight).
    /// Refused when a case is already pending, while the founder is away,
    /// with an empty wallet, and per-offence — `CrimeRefusal` says which.
    case commitOffence(offence: CrimeOffence, rivalID: UUID? = nil, productID: UUID? = nil)
    /// Walks into a police station about a specific entry on the record
    /// (or the most recent one). Raises the case today with a third of the
    /// evidence against you. Refused while a case is already pending.
    case confessOffence(entryID: String? = nil)
    /// Pays the other side to make the pending case go away. Wallet first,
    /// company for the rest; refused when the two together cannot cover it.
    case settleCase
    /// Buys representation for the pending case, out of the founder's own
    /// wallet. Refused once the hearing has started.
    case hireLawyer(tier: CrimeLawyer)
    /// Picks the line the founder will run. Free, and changeable up to the
    /// moment they stand up.
    case chooseDefence(CrimeDefence)
    /// Stands the founder up in front of the judge. Only on or after the
    /// hearing day, and it stops the clock.
    case openHearing
    /// One of the three exchanges. `objection` needs a lawyer who has one
    /// left.
    case sayInCourt(CrimeExchange)
    /// Stops talking and takes the verdict on what has been said.
    case restCase
    /// Files against a studio. Costs the company the filing fee and puts a
    /// hearing on the books with the same machinery, reversed.
    case sueRival(rivalID: UUID)

    // MARK: N2 (people menus)

    /// The people menu's one verb: do `interaction` to `target`. The id is
    /// a row in `Interactions.json`; the outcome is a roll on `socialRNG`
    /// against the founder's conversation attribute and the bar that
    /// person sits on. Refused actions do nothing at all —
    /// `GameState.interactionBlocker` says why, on the button.
    ///
    /// Every existing people action (`praise`, `giveGift`, `hangOutWith`,
    /// `spendTimeWithPartner`, `seeFriend`, `talkToContact`,
    /// `advanceRelationship`, `fire` and the rest) stays exactly as it was
    /// and is listed in the same menu, which is why nothing a pacing bot
    /// does changes.
    case interact(target: InteractionTarget, interaction: String)

    /// The founder ends the relationship deliberately, rather than letting
    /// the relationships meter do it over a fortnight. Affection collapses,
    /// the home stays, the children stay. Wave two's family drama takes
    /// this and `InteractionState.affairContactID` as its two seams.
    case breakUp

    /// `fire`, plus a cause on the record: the alumnus entry is closed as
    /// lost whatever the bond was, so the boomerang never brings this one
    /// back through the address book. N5's office secrets route their
    /// harshest response here.
    case fireWithCause(employeeID: UUID)

    // MARK: N3 (assets, vices and the doctor)

    /// N3: the app's one flag — the player has opened the Assets screen in
    /// this run, so the vices, the ailments and the weekly upkeep may
    /// start. Nothing else sets it, which is what keeps the pacing bots
    /// and the byte-identical fixtures where they are.
    case noticeAssetsOpened
    /// Buys a car, a second property or a pet from
    /// `balance.assets` with the founder's own wallet.
    case buyAsset(assetID: String)
    /// Sells it back at the catalog's resale fraction.
    case sellAsset(assetID: String)
    /// Pays the garage, the plumber or the roofer.
    case repairAsset(assetID: String)
    /// Starts a course of treatment at the doctor's: the bill now, the
    /// clearance in the ailment's `treatmentDays`. One evening.
    case treatAilment(ailmentID: String)
    /// An hour on the couch: every dependency down, the mood up. One
    /// evening, once a week.
    case attendTherapy
    /// One evening off a vice. The first starts the run; the rest roll
    /// against a relapse.
    case quitVice(viceID: String)
    /// Gives up on giving up.
    case abandonQuit(viceID: String)
    /// One hand at one of the casino's three tables.
    case playCasinoGame(gameID: String, stake: Int)
    /// One ticket, drawn at the weekend.
    case buyLotteryTicket
    /// Dollars in (positive) or out (negative) of the crypto wallet, at
    /// today's price less the spread.
    case tradeCrypto(dollars: Int)

    // MARK: N4 (fame and the feed)

    /// N4: puts something on the founder's public feed. Free, one a day.
    /// `subject` names the rival a subtweet is about; `nil` takes the
    /// strongest studio on the board. `FameSystem.postBlocker` says why a
    /// post is refused before the button is tapped.
    case postToFeed(kind: FamePostKind, subject: String? = nil)
    /// N4: the rival answered. Escalating buys followers and costs the
    /// company reputation and the founder a night's sleep; letting it go
    /// costs the last word and nothing else.
    case answerFeedBeef(escalate: Bool)
    /// N4: an old post surfaced. Apologise, double down, or delete it —
    /// every answer costs followers, fame, reputation and mood, and the
    /// button says how much of each.
    case answerFameCancellation(response: FameCancelResponse)

    // MARK: N5 (office secrets)

    /// The founder opened the Team tab. The one flag `OfficeSecretsSystem`
    /// reads before anything else: threads may start from here, and never
    /// in a run that never looks at its own team.
    case watchTheOffice
    /// One answer to the thread the office is running — ask around, hire a
    /// PI, say it to their face, take it to HR, make a deal, leave it.
    /// Refused answers change nothing; `OfficeSecretsSystem.refusal` says
    /// why, and the card puts the reason on the button.
    case respondToSecret(SecretResponse)
    /// `-autoSecret <kind>`: starts a thread at a stage for a screenshot.
    /// Applied only in debug builds; nothing in the game sends it.
    case seedOfficeSecret(kind: String, stage: Int)

    // MARK: end of Iteration 11

    // MARK: Iteration 11, wave two

    // MARK: W1 (dirty money)

    // MARK: W2 (family drama)

    /// The family room was opened. The identity gate: nothing in this lane
    /// costs a byte until this lands, and only the player can send it.
    case openFamilyRoom
    /// What the founder says the night the affair comes out.
    case confrontFamily(FamilyConfession)
    /// Divide the estate. `keep` is what the player dragged into their own
    /// column: catalog ids plus `"home"` and `"pet"`.
    case divorceSettlement(keep: [String], lawyer: CrimeLawyer)
    /// File for the children. The hearing is N1's room with a family
    /// opener and a family verdict.
    case fileCustody
    /// Yes or no to whatever the sibling wants this time.
    case answerFamilyAsk(accept: Bool)
    /// The in-laws and the spare room.
    case familySpareRoom(accept: Bool)
    /// An evening with somebody who is not the company.
    case seeRelative(FamilyRelation)
    /// Name an heir. The dynasty reads it when the run ends.
    case signWill(heir: FamilyHeir, childID: UUID?)
    /// The one argument at the funeral.
    case settleFuneral(FamilyDrama.FuneralArgument)
    /// `-autoFamily <stage>`: puts the lane in a state worth a screenshot.
    /// Applied only in debug builds; nothing in the game sends it.
    case seedFamilyDrama(stage: String)

    // MARK: W3 (espionage)

    // MARK: W4 (inside)

    // MARK: end of Iteration 11, wave two
}

/// The skill a training course targets.
public enum TrainableSkill: String, Codable, Equatable, Sendable, CaseIterable {
    case coding, design, marketing
}
