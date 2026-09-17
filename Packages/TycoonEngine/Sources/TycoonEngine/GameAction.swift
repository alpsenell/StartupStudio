import Foundation

/// Player-initiated commands, applied synchronously via `Reducer.apply`.
public enum GameAction: Codable, Equatable, Sendable {
    case startProduct(typeID: String, topicID: String, name: String, focus: PhaseFocus)
    case setPhaseFocus(productID: UUID, focus: PhaseFocus)
    case ship(productID: UUID)
    case hire(candidateID: UUID)
    // MARK: T3 (people)
    /// `payNotice` (T3): the player's plain firing pays notice — a week of
    /// salary per quarter served, up to four — and is refused when the cash
    /// is short. `nil` (the default, and every old caller: the resignation
    /// sheet, the bots, the tests) is the old free firing, and an optional
    /// keeps the synthesized encoding of the old case byte for byte.
    case fire(employeeID: UUID, payNotice: Bool? = nil)
    // MARK: end T3
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

    /// The founder opened the Business tab's finances. The one flag
    /// `DirtyMoneySystem` reads before anything else: an offer may arrive
    /// from here, and never in a run that never looks at its own money.
    case noticeFinancesOpened
    /// Banks the cheque on the table. Refused with `DirtyMoneyRefusal`,
    /// which the card puts on the button.
    case takeDirtyMoney
    /// Turns the offer down. They keep the number.
    case declineDirtyMoney
    /// Comply, stall or refuse the string they are pulling this week.
    case answerDirtyMoneyDemand(DirtyMoneyAnswer)
    /// The cheque back, times a multiple, plus a surcharge for the heat.
    case payOffBacker
    /// A statement, and N1's courtroom on the laundering.
    case turnWitnessOnBacker
    /// Sells them the company. A `.soldUp` ending.
    case sellUpToBacker
    /// `-autoDirtyMoney <backer>`: puts an offer on the table for a
    /// screenshot. Applied only in debug builds; nothing in the game
    /// sends it.
    case seedDirtyMoneyOffer(backer: String)
    /// `-autoDirtyMoneyDemand <kind>`: pulls one of the strings today, so
    /// a headless pass can photograph the sheet without waiting a quarter
    /// for the calendar to pull it. Debug builds only.
    case seedDirtyMoneyDemand(kind: String)

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

    /// Has one of the five things done to a studio: a private
    /// investigator on their founder, a mole in their office, the poach
    /// the dossier makes possible, their roadmap bought, or their
    /// storefront taken down for the week they launch.
    ///
    /// Costs are taken once, the odds are the ones the card printed, and
    /// the operation goes on N1's record whatever happens —
    /// `EspionageSystem.refusal` says why a refused one is refused, on the
    /// button, before it is pressed.
    case runEspionageOperation(operation: EspionageOperation, rivalID: UUID)

    // MARK: W4 (inside)

    /// What today inside is spent on. One a day; sending it again before
    /// the day ticks replaces it, because nothing has been spent yet.
    case chooseInsideDay(choice: PrisonDayChoice)
    /// In with the wing, or out. Offered once, answered once.
    case answerPrisonGang(joining: Bool)
    /// Over the wall. One attempt, ever.
    case attemptEscape
    /// The parole board: open it, say one of five things, and let it rule.
    case openParole
    case sayAtParole(exchange: PrisonParoleExchange)
    case decideParole
    /// Serve a sentence of `weeks`, for `-autoInside <weeks>`.
    /// Applied only in debug builds; nothing in the game sends it — a real
    /// sentence comes from a verdict.
    case serveSentence(weeks: Int)

    // MARK: J1 (doors)
    /// A person is at the controls: the doors may open. Sent by the app's
    /// HUD, once per game; bots, replays and tests never send it, which
    /// is the doors' whole identity gate.
    case armDoors
    /// The founder's answer at one of the four doors. Refused (a no-op)
    /// once the door has closed or for an answer that door does not take.
    case answerDoor(kind: DoorKind, choice: DoorChoice)
    /// Opens a door today whatever the state says, for `-autoDoor <kind>`.
    /// Applied only in debug builds; nothing in the game sends it.
    case openDoor(kind: DoorKind)
    // MARK: end J1
    // MARK: J2 (record)
    /// Dress the founder's record for a screenshot: `-autoStanding <name>`,
    /// `-autoBoardReview case|offer`, `-autoSpotlight <level>`. Applied
    /// only in debug builds; nothing in the game sends it.
    case standingDebug(scenario: String)
    // MARK: end J2
    // MARK: J3 (rivals and the market)
    /// The market board was opened. Sent by the app, never by a bot; the
    /// gate for rivals following the money. Idempotent.
    case noticeMarketOpened
    /// Match, out-ship or outlast a rival's price war. Refused with a
    /// reason (`RivalMarket.refusal(answering:…)`) past the answer window,
    /// on a war already answered, or with nothing on sale.
    case answerPriceWar(rivalID: UUID, answer: RivalMarketPriceWarAnswer)
    /// `-autoRivalMarket boom|crash`, `-autoPriceWar`, `-autoCopied`: the
    /// world doing it now, for a screenshot. Applied only in debug builds;
    /// nothing in the game sends it.
    case seedRivalMarket(scenario: String)
    // MARK: end J3
    // MARK: J4 (house field)
    // MARK: end J4
    // MARK: J5 (announce)
    /// Tell the press `day` is the ship date of a build in development.
    /// Refused (no events) for the reasons `AnnounceRefusal` names.
    case announceShipDate(productID: UUID, day: Int)
    /// Miss the standing date now, for `-autoAnnounce slip`. Applied only
    /// in debug builds; nothing in the game sends it.
    case announceForceSlip(productID: UUID)
    // MARK: end J5
    // MARK: J6 (queue)
    /// `-autoQueue`, `-autoChild <stage>`, `-autoCampus` and
    /// `-autoStakes <eventID>`: dresses one situation for a screenshot
    /// (`QueueDebugSeed`). Applied only in debug builds; nothing in the
    /// game sends it.
    case queueDebugSeed(kind: String, value: String)
    // MARK: end J6
    // MARK: P1 (purchases: engine)
    /// A verified App Store transaction, in game terms. Idempotent by
    /// `transactionID`; refused by `PurchaseRule`; never sent by a bot or a
    /// fixture, so an unbought run is byte-identical. Handled before the
    /// game-over guard because the second chance answers an ended game.
    case applyPurchase(kind: PurchaseKind, transactionID: UInt64)
    // MARK: end P1
    // MARK: P2 (purchases: StoreKit and the session)
    // MARK: end P2
    // MARK: P3 (purchases: surfaces and copy)
    // MARK: end P3
    // MARK: U1 (ux: the first-hour fixes)
    // MARK: end U1
    // MARK: V1 (ux: Life folded, rooms dormant)
    // MARK: end V1
    // MARK: V2 (ux: one inbox, one home per thing)
    // MARK: end V2
    // MARK: V3 (ux: card weights, the Now card)
    // MARK: end V3
    // MARK: K1 (founder money)
    /// Iteration 15 — K1: lend the company `amount` from the wallet. Owed
    /// back on demand and repaid out of the next accepted round first.
    /// Refused at stake 2 (no credit) and past what the wallet holds.
    case lendToCompany(amount: Int)
    /// Repay up to `amount` of the director's loan out of company cash.
    case repayDirectorLoan(amount: Int)
    /// Pay `amount` out to the cap table; the founder takes
    /// `equityRemaining`% of it home. See `FounderMoneySystem`.
    case declareDividend(amount: Int)
    /// Answer the landlord's question (armed runs only).
    case answerRescue(FounderMoneyRescueAnswer)
    /// DEBUG only: `-autoFounderMoney <kind>` dresses a screenshot.
    /// Ignored in a release build.
    case founderMoneyDebugSeed(kind: String)
    // MARK: end K1
    // MARK: K2 (product lifecycle)
    /// Retire a live product: hosting stops, its subscribers leave, the
    /// store says *Discontinued*, and its topic loses the live presence it
    /// gave. Refused (no events) for the reasons `LifecycleRefusal` names.
    /// Sent only by the product page's *Retire*; no bot sends it.
    case sunsetProduct(productID: UUID)
    /// Ship a build as `ship` does, then retire `parentID` the same day: the
    /// parent is left out of the build's launch saturation and genre
    /// fatigue, and the successor opens with `lifecycle.successorBookCarry`
    /// of its subscribers (a one-time product carries its hype instead).
    /// Same type and topic only. Sent only by the ship confirmation.
    case shipReplacing(productID: UUID, parentID: UUID)
    /// The priced price change: a rise churns the book (or dents a one-time
    /// product's next weeks), a cut is a sale once a quarter, and changes
    /// are `lifecycle.changeCooldownDays` apart. Sent only by the price
    /// sheet; `setPriceTier` stays the free, silent move the rivals' code
    /// and the tests use.
    case repriceProduct(productID: UUID, tier: PriceTier)
    /// `-autoRoute k2-…`: dresses the save for a screenshot
    /// (`LifecycleDebugSeed`). Applied only in debug builds; nothing in the
    /// game sends it.
    case lifecycleDebug(scenario: String)
    // MARK: end K2
    // MARK: K3 (the ladder)
    /// Options instead of pay: `percent` (1 or 2) points of the company
    /// for a pay cut of a fraction of fair pay, vesting over four years
    /// after a one-year cliff. Sent only from the manage sheet; no bot
    /// grants.
    case grantEquity(employeeID: UUID, percent: Int)
    // MARK: end K3
    // MARK: K4 (deals and exits)
    /// Iteration 15 — K4 (A2): hang the for-sale sign at `askMultiple` ×
    /// today's valuation, snapped to tenths inside `deals.askMin…askMax`.
    /// Rivals bid every `deals.bidIntervalDays` on the `pendingBuyout`
    /// path while the office bleeds. Sent only from the app.
    case listForSale(askMultiple: Double)
    /// Takes the sign down. The bleed stops; a bid already on the desk
    /// stands until it lapses.
    case takeDownSign
    /// K4 (A4): sell to the strongest rival at the distress price today,
    /// from the first day in the red. Ends the run as *Sold up*.
    case sellUp
    /// K4 (C5): buy a rival for equity instead of cash. Their founder
    /// takes a board seat and joins the address book.
    case acquireRivalForStock(rivalID: UUID)
    // MARK: end K4
    // MARK: K5 (hand over the keys)
    /// K5: the founder hands the company to `successorID` and keeps
    /// `keptPercent` (10, 25 or 50) of their holding as a silent round; the
    /// successor becomes the founder with a fresh life and the run becomes
    /// `.custom`. `predecessorRunID` is the id the app gives the outgoing
    /// founder's `LegacyRun`, so the new `lineage` points at it without
    /// the engine minting an id. Refused with `handOverBlocker` /
    /// `handOverSuccessorBlocker`'s reason. Sent only from the app.
    case handOverKeys(successorID: UUID, keptPercent: Int, predecessorRunID: UUID)
    // MARK: end K5
    // MARK: K6 (home and rooms)
    /// Moves the founder's home to `district`: `home.moveRentWeeks` of the
    /// new rent from the wallet and an evening; the weekly rent then reads
    /// the district's multiplier and a far commute costs an evening a week
    /// (`HomeSystem`). Sent only from the Home card's move sheet.
    case moveHome(district: DistrictID)
    /// Plans the coming weekend as a family holiday: the vacation, with the
    /// partner and the children along (`HomeSystem`). Sent only from the
    /// weekend card.
    case planFamilyHoliday
    /// A paid break in the game room, the cafeteria or the gym: everyone's
    /// morale up, the next day's build progress at `home.breakDayFactor`,
    /// once a week (`HomeSystem`). Sent only from the amenities sheet.
    case callBreak(amenity: Amenity)
    // MARK: end K6
    // MARK: K7 (partner and diary)
    /// Put the founder's partner on payroll: skills from their stored
    /// seed, fair pay, the bond they already have. Refused for the reasons
    /// `GameState.partnerHireBlocker` names. No bot sends it.
    case hirePartner
    /// Buy the ex's slice of the company back at the balance's multiple,
    /// wallet first and company cash for the rest. Refused for the reasons
    /// `GameState.exBuyOutBlocker` names. No bot sends it.
    case buyOutEx
    /// On a launch that landed on a diary date: skip the party and keep
    /// the date. Hype at launch ×0.85, no launch-party vice, the date
    /// counts as kept. No bot sends it.
    case keepTheDate(productID: UUID)
    /// `-autoPartner <stage>`: dresses one K7 situation for a screenshot
    /// (`PartnerDebugSeed`). Applied only in debug builds; nothing in the
    /// game sends it.
    case partnerDebugSeed(stage: String)
    // MARK: end K7
    // MARK: S2 (office downgrade)
    /// Move one office tier down: the rent difference saved every week,
    /// an owned office sold at today's value, for a moving cost, a
    /// quarter's morale drag and a reputation dent. Refused for the
    /// reasons `GameState.officeDowngradeBlocker` names. No bot sends it.
    case downgradeOffice
    /// `-autoRoute s2-downgrade|s2-refused`: dresses the loaded save so the
    /// move down is legal (`legal`) or leaves it as it is (`refused`), for
    /// a screenshot (`OfficeDowngradeDebugSeed`). Applied only in debug
    /// builds; nothing in the game sends it.
    case officeDowngradeDebugSeed(scenario: String)
    // MARK: end S2
    // MARK: T1 (exits and joins)
    /// Sells to the pending buyout for cash with the unvested options
    /// answered: `accelerate` vests them today and pays them from the
    /// price; `false` lets them lapse home to the founder. The buyout sheet
    /// sends it. `.acceptBuyout` — the bots' action, unchanged in shape and
    /// bytes — is this with `accelerate: false`.
    case exitAcceptBuyout(accelerate: Bool)
    /// The earn-out, with the unvested answered the same way. During an
    /// earn-out a lapsed holder leaves at the next weekly pass.
    case exitAcceptBuyoutEarnOut(accelerate: Bool)
    /// Sells up before the receiver, with the unvested answered.
    case exitSellUp(accelerate: Bool)
    /// The morning after the founder fired their partner with cause:
    /// `packBag` ends the marriage (the settlement follows); `false` stays
    /// and pays for it again. Ignored with no question open.
    case answerPartnerFiring(packBag: Bool)
    /// `-autoRoute t1-…`: dresses the loaded save for a screenshot
    /// (`ExitsDebugSeed`). Applied only in debug builds; nothing in the
    /// game sends it.
    case exitsDebugSeed(scenario: String)
    // MARK: end T1
    // MARK: T2 (the build)
    /// O3: put a build in development into the drawer — its slot frees,
    /// its hype goes, an announced date slips, its crew idles, its points
    /// keep and decay. Refused for the reasons `BuildRefusal` names. No
    /// bot sends it.
    case shelveBuild(productID: UUID)
    /// O3: take a shelved build back into a free slot.
    case unshelveBuild(productID: UUID)
    /// P2: scrap a build (in a slot or on the shelf): half its points into
    /// the type's codebase, its crew's morale, no review.
    case scrapBuild(productID: UUID)
    /// J4: `startProductOnCodebase` from the "v2 of…" chip, which also
    /// writes the parent (same type and topic, released) on the build. The
    /// old two start actions are untouched, so every bot sends what it did.
    case startProductAsV2(
        typeID: String, topicID: String, name: String, focus: PhaseFocus,
        codebaseID: String?, parentID: UUID
    )
    /// P1: `ship` with the price named on the ship sheet. `.ship` is
    /// untouched and is `.standard`, which is every bot's ship.
    case shipAt(productID: UUID, tier: PriceTier)
    /// P1 × K2: `shipReplacing` with the price named on the ship sheet.
    case shipReplacingAt(productID: UUID, parentID: UUID, tier: PriceTier)
    /// `-autoRoute t2-…`: dresses the loaded save for a screenshot
    /// (`BuildDebugSeed`). Applied only in debug builds; nothing in the
    /// game sends it.
    case buildDebugSeed(scenario: String)
    // MARK: end T2
    // MARK: T3 (people)
    /// Let several people go at once: everyone's notice paid, the room −2
    /// morale a head (capped at −10), reputation −1 for every three, and a
    /// seated board watching headcount reads it as a miss. Refused while
    /// the notice is more than the cash. No bot sends it.
    case layOff(employeeIDs: [UUID])
    /// `-autoRoute t3-claim`: fires `employeeID` with cause and files the
    /// wrongful-dismissal claim without the draw, for a screenshot. Applied
    /// only in debug builds; nothing in the game sends it.
    case severanceDebugClaim(employeeID: UUID)
    // MARK: end T3
    // MARK: T4 (publisher)
    /// Shop a build in development to the strongest rival at
    /// `publisher.minStrength`: the advance `publisherTerms` prints in
    /// cash, their share of the product's revenue for as long as it sells,
    /// and their date announced. Refused for the reasons
    /// `PublisherRefusal` names. No bot sends it.
    case shopToPublisher(productID: UUID)
    /// Buy the publisher on a product out at `publisherBuyoutPrice`: the
    /// share stops today. Refused for the reasons
    /// `GameState.publisherBuyoutBlocker` names. No bot sends it.
    case buyOutPublisher(productID: UUID)
    // MARK: end T4
    // MARK: T5 (expo and pre-orders)
    /// Iteration 17 — T5 (G2). Book this year's expo for a build in
    /// development: a booth at the office tier's price or the hallway, with
    /// the founder or a marketer at it. Paid now; pointing it at another
    /// build or person is free until the day, and on the day it is shown.
    /// Sent only from the app.
    case showAtExpo(productID: UUID, booth: ExpoBooth, attendee: ExpoAttendee)
    /// Let this year's expo go (a booth already paid for is not refunded).
    case skipExpo
    /// Iteration 17 — T5 (G6/P4). Sell part of an announced one-time
    /// build's launch week now, at a discount; a slip refunds some.
    case openPreorders(productID: UUID)
    /// `-autoExpo <scenario>`: dresses the loaded save for a screenshot
    /// (`ExpoDebugSeed`). Applied only in debug builds; nothing in the
    /// game sends it.
    case expoDebugSeed(scenario: String)
    // MARK: end T5
    // MARK: T6 (away)
    /// Sends a hired person on a course in `skill`: `away.courseCost`
    /// (× People & HR's training factor) now, `away.courseDays` away from
    /// the desk, `away.courseSkillBoost` in the skill the day they are
    /// back. Refused for the founder, while they are already away, and
    /// without the cash. No bot sends it.
    case sendOnCourse(employeeID: UUID, skill: TrainableSkill)
    /// DEBUG: dresses the running game for a T6 screenshot
    /// (`AwayDebugSeed`). Applied only in debug builds.
    case awayDebugSeed(scenario: String)
    // MARK: end T6
    // MARK: T7 (press and stakes)
    /// Gives `outlet` the exclusive on a product that shipped today
    /// (`PressSystem.grantExclusive`). Sent by the ship confirmation right
    /// after the ship itself, so it composes with every way a build ships.
    case grantExclusive(productID: UUID, outlet: String)
    /// Buys a `percent` (0.05, 0.10 or 0.25) stake in a rival for company
    /// cash (`RivalSystem.buyRivalStake`).
    case buyRivalStake(rivalID: UUID, percent: Double)
    /// Sells the stake held in a rival back at `valuation × sellBack ×
    /// percent`.
    case sellRivalStake(rivalID: UUID)
    /// `-autoRoute t7-…`: dresses the loaded save for a screenshot
    /// (`PressStakeDebugSeed`). Applied only in debug builds; nothing in
    /// the game sends it.
    case pressStakeDebugSeed(scenario: String)
    // MARK: end T7
    // MARK: end of Iteration 17
    // MARK: end of Iteration 15
    // MARK: S1 (seating)
    /// Puts `employeeID` at `desk` in the office grid; whoever sat there
    /// takes the mover's old desk. The first move writes today's whole
    /// room into `Company.seating`, so nobody else shifts, and from then on
    /// neighbours matter (`SeatingSystem`). Refused with
    /// `GameState.seatingMoveBlocker`'s reason. Sent only from the app.
    case seatingMove(employeeID: UUID, desk: Int)
    /// Tears the plan up: `Company.seating` back to empty, the office's own
    /// rule seats everyone, and every seating effect stops. Sent only from
    /// the app.
    case seatingClear
    // MARK: end S1
    // MARK: Iteration 18 — the studio mark
    /// Sets the studio's mark to the glyph `seed` draws
    /// (`StudioMarkBuilder`); `nil` takes the mark away again. Sent once,
    /// by the naming step of the new-game flow, and by nothing else — no
    /// bot sends it, so every fixture and every recorded run keeps
    /// `company.markSeed` nil and writes the bytes it always wrote.
    /// Draws nothing and moves no number: a mark is a picture.
    case chooseStudioMark(seed: UInt64?)
    // MARK: end of Iteration 18
    // MARK: end of Iteration 14
    // MARK: end of Iteration 13
    // MARK: end of Iteration 12
    // MARK: end of Iteration 11, wave two
}

/// The skill a training course targets.
public enum TrainableSkill: String, Codable, Equatable, Sendable, CaseIterable {
    case coding, design, marketing
}
