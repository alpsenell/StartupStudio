import TycoonContent

/// The pure simulation reducer. One call to `tick` advances the state by
/// exactly one game day — always, regardless of simulation speed. Player
/// commands go through `apply` between ticks.
public enum Reducer {
    /// A simulation system: a pure function advancing one slice of the state
    /// for the current day, returning any events it produced.
    typealias System = @Sendable (inout GameState, BalanceConfig, ContentCatalog) -> [GameEvent]

    /// Systems run in this order every day:
    /// Life → Market → Rival → Employee → Social → Product → Contract →
    /// Research → Marketing → City → Finance → Event, then each
    /// workstream's own, then Relationship → Networking.
    /// Life runs first so today's founder condition scales today's output;
    /// Market shifts before sales post so a weekly shift prices the same
    /// day's sales; Rival runs after Market (a rival shipping dents the
    /// fresh multipliers) and before Employee (a poach resolving today
    /// precedes the morale/quit sweep); Social runs right after Employee
    /// so loyalty and bonds track the post-sweep roster; City settles
    /// property tax and address prestige just before Finance's weekly
    /// bill. Rival, Social, and City draw only from `worldRNG`, so their
    /// positions never disturb the original `rng` stream.
    static let systems: [System] = [
        LifeSystem.run,
        MarketSystem.run,
        RivalSystem.run,
        EmployeeSystem.run,
        SocialSystem.run,
        ProductSystem.run,
        ContractSystem.run,
        ResearchSystem.run,
        MarketingSystem.run,
        CitySystem.run,
        FinanceSystem.run,
        EventSystem.run,

        // Reserved regions — each workstream appends its new systems inside
        // its own region and nowhere else. A system's position in this
        // array fixes when it runs (and, for anything drawing from `rng`,
        // the draw order), so never insert outside your region.

        // MARK: WS-A

        // Live ops runs last: support desks, the wild's bug discovery and
        // landing patches all read the day the rest of the simulation just
        // produced (notably the sales week `ProductSystem` posts).
        LiveOpsSystem.run,

        // MARK: WS-B

        // Runs after everything else so it sees the finished day: a choice
        // whose deadline passed is answered, a scheduled follow-up fires,
        // and the industry-news drum beats. Draws only from `worldRNG`, and
        // only when `News.json` has templates.
        NarrativeSystem.run,

        // MARK: WS-F

        // Runs on the post-sweep roster: the trait effects that need the
        // whole team (mentoring, the mood of the room, press).
        TraitSystem.run,
        // Then the investor cadence (offers, quarterly board reviews),
        // which can end the run. Draws only from `investorRNG`, its own
        // stream, so repricing the term sheets never reshuffles the world.
        InvestorSystem.run,
        // Progression measures last, so a goal that a system finished
        // today completes today.
        ProgressionSystem.run,

        // MARK: Founder & people

        // The founder's own life, after the company's day. Relationships
        // sees the post-quit roster and the loyalty `SocialSystem` settled
        // on; networking closes a room the player is done with and settles
        // the founder's personal stakes. Both draw only from `socialRNG`,
        // their own stream, so their position here disturbs nothing.
        RelationshipSystem.run,
        NetworkingSystem.run,

        // MARK: Iteration 9 — the Life tab

        // Each lane appends its daily system between its own markers. All
        // of them run after the company's day and the founder's, so they
        // read a finished day; none may draw from `rng` or `worldRNG`
        // (use `socialRNG`, and only when the feature is engaged).

        // MARK: L1 (phone)
        // The phone is a mirror: the only thing it does on its own is the
        // office's Sunday numbers. Every other message is posted from the
        // system that caused it.
        PhoneSystem.run,

        // MARK: L2 (life score, Walked away)

        // MARK: L3 (children)

        // The children's day: stages turned over, the memory ledger fed
        // from yesterday's log, summers ended, bonds slid. Returns on its
        // first line for a founder with no children, which is every
        // pacing bot — and it draws from no stream at all.
        ChildhoodSystem.run,

        // MARK: L4 (friends)
        FriendSystem.run,

        // MARK: L5 (side project)
        // Returns on its first line unless a project is under way, and
        // only the marathon has anything to do daily at all.
        SideProjectSystem.run,

        // MARK: L6 (sabbatical)

        // The caretaker's week. Runs after everything else because it
        // reads a finished day and, on a decision day, plays a player
        // action back into the same day through `Reducer.apply`. Draws
        // only from `socialRNG`, and only while the founder is away.
        SabbaticalSystem.run,

        // MARK: L7 (furnish)

        // MARK: end of Iteration 9

        // MARK: Iteration 10 — after everything, no `rng`/`worldRNG` draws

        // MARK: M1 (feature board)

        // MARK: M2 (pitch room)

        // The pitch room. A no-op in every run whose `state.pitch` is
        // `nil`, which is every run in which nobody pressed *Talk first*.
        PitchSystem.run,

        // MARK: M3 (incident room)

        // Nothing here on purpose. An incident is raised from
        // `LiveOpsSystem`'s M3 region, at the end of the live-ops day,
        // where the facts it reads (the patch that just landed, the week
        // the wild just had) are freshest — and behind a gate the pacing
        // bots never open. The room itself is all actions.

        // MARK: M4 (leagues)

        // MARK: M5 (morning desk)

        // MARK: M6 (bug hunt)

        // MARK: end of Iteration 10

        // MARK: Iteration 11 — after everything, no `rng`/`worldRNG` draws

        // MARK: N1 (crime and the courtroom)
        // Returns on its first line while `state.crime` is empty, which is
        // every run that has never pressed an offence button.
        CrimeSystem.run,

        // MARK: N2 (people menus)

        // MARK: N3 (assets, vices and the doctor)

        // The founder's own balance sheet, weekly: the bills, the
        // breakdowns, the vet, the wallet that moves on its own, and the
        // vices' week. A no-op in every run whose `state.assets` is
        // `.empty`, which is every run in which nobody opened the Assets
        // screen. (The *daily* half — the drift and the doctor — runs
        // from `LifeSystem`'s N3 region, where the meters are.)
        AssetsSystem.run,

        // MARK: N4 (fame and the feed)

        // The feed's day: the fame curve, the steps it crosses, a beef
        // going cold, the applicants fame brings, and the weekly roll for
        // an old post surfacing. Returns on its first line for every run
        // whose `state.fame` is still `.empty` — which is every run in
        // which nobody has pressed *Post*.
        FameSystem.run,

        // MARK: N5 (office secrets)

        // Last of all, and behind its own gate: the office's slow-burn
        // threads read the roster after every quit, fire and hire the day
        // has already done.
        OfficeSecretsSystem.run,

        // MARK: end of Iteration 11

        // MARK: Iteration 11, wave two — after everything, no `rng`/`worldRNG` draws

        // MARK: W1 (dirty money)

        // Last, after the week's money has posted: the offer reads the
        // cash position the day left behind, and the strings read the
        // payments the day already made.
        DirtyMoneySystem.run,

        // MARK: W2 (family drama)

        // The affair's weekly discovery roll, the parents ageing, the
        // sibling escalating. Returns on its first line until the founder
        // has opened the room or started an affair.
        FamilyDramaSystem.run,

        // MARK: W3 (espionage)

        // The mole's report coming due, and what being ready for it is
        // worth. Returns on its first line while `state.espionage` is
        // empty, which is every run that has never opened a rival's page
        // and pressed one of five buttons.
        EspionageSystem.run,

        // MARK: W4 (inside)

        // MARK: end of Iteration 11, wave two
    ]

    /// Advances the state by one game day. No-op once the game is over.
    /// Returned events are also appended to `state.eventLog`.
    @discardableResult
    public static func tick(
        _ state: inout GameState,
        balance: BalanceConfig,
        content: ContentCatalog
    ) -> [GameEvent] {
        guard state.gameOver == nil else { return [] }

        state.day += 1

        var events: [GameEvent] = []
        for system in systems {
            events.append(contentsOf: system(&state, balance, content))
        }

        // Decide here, not in the UI shell, so a headless run sees exactly
        // the pauses a played game would: the policy needs the day's state
        // and spends the pause budget.
        let pausing = PausePolicy.pausingEvents(events, state: state, balance: balance)
        state.economy.pauseEvents = pausing
        if pausing.contains(where: { $0.severity != .critical }) {
            state.economy.lastNonCriticalPauseDay = state.day
        }

        state.logEvents(events)
        return events
    }

    /// Applies a player action synchronously. Invalid actions are ignored and
    /// return no events; the game being over ignores everything. Returned
    /// events are also appended to `state.eventLog`.
    @discardableResult
    public static func apply(
        _ action: GameAction,
        to state: inout GameState,
        balance: BalanceConfig,
        content: ContentCatalog
    ) -> [GameEvent] {
        // Iteration 7 (R5): the one action an ended game answers, so it is
        // handled before the guard below — the guard is the thing it is
        // for. Everything else about an ended run stays refused.
        if case .continueAfterEnding = action {
            let events = continueAfterEnding(&state)
            state.logEvents(events)
            return events
        }
        guard state.gameOver == nil else { return [] }
        // Iteration 8: a stake can forbid an action (no credit, no crunch).
        guard !StakeLadder.refuses(action, at: state.rules.stake) else { return [] }

        let events: [GameEvent]
        switch action {
        case let .startProduct(typeID, topicID, name, focus):
            events = ProductSystem.startProduct(
                typeID: typeID, topicID: topicID, name: name, focus: focus,
                state: &state, balance: balance, content: content
            )
        case let .startProductOnCodebase(typeID, topicID, name, focus, codebaseID):
            events = ProductSystem.startProduct(
                typeID: typeID, topicID: topicID, name: name, focus: focus,
                codebaseID: codebaseID, state: &state, balance: balance, content: content
            )
        case let .setPhaseFocus(productID, focus):
            events = ProductSystem.setPhaseFocus(productID: productID, focus: focus, state: &state)
        case let .ship(productID):
            events = ProductSystem.ship(
                productID: productID, state: &state, balance: balance, content: content
            )
        case let .hire(candidateID):
            events = EmployeeSystem.hire(candidateID: candidateID, state: &state, balance: balance)
        case let .fire(employeeID):
            events = EmployeeSystem.fire(employeeID: employeeID, state: &state, balance: balance)
        case let .assign(employeeID, assignment):
            events = EmployeeSystem.assign(employeeID: employeeID, to: assignment, state: &state)
        case let .startResearch(nodeID):
            events = ResearchSystem.startResearch(nodeID: nodeID, state: &state, content: content)
        case .cancelResearch:
            events = ResearchSystem.cancelResearch(state: &state)
        case let .acceptContract(offerID):
            events = ContractSystem.acceptContract(offerID: offerID, state: &state)
        case let .startCampaign(kindID, productID):
            events = MarketingSystem.startCampaign(
                kindID: kindID, productID: productID,
                state: &state, balance: balance, content: content
            )
        case .upgradeOffice:
            events = FinanceSystem.upgradeOffice(state: &state, balance: balance)
        case let .setWorkSchedule(schedule):
            events = LifeSystem.setWorkSchedule(schedule, state: &state)
        case let .setFounderSalary(amount):
            events = LifeSystem.setFounderSalary(amount, state: &state, balance: balance)
        case let .planWeekend(activity):
            events = LifeSystem.planWeekend(activity, state: &state)
        case .upgradeHome:
            events = LifeSystem.upgradeHome(state: &state, balance: balance)
        case .advanceRelationship:
            events = LifeSystem.advanceRelationship(state: &state, balance: balance, content: content)
        case .haveChild:
            events = LifeSystem.haveChild(state: &state, balance: balance, content: content)
        case let .praise(employeeID):
            events = EmployeeSystem.praise(employeeID: employeeID, state: &state, balance: balance)
        case let .adjustSalary(employeeID, weeklySalary):
            events = EmployeeSystem.adjustSalary(
                employeeID: employeeID, weeklySalary: weeklySalary, state: &state, balance: balance
            )
        case let .promote(employeeID):
            events = EmployeeSystem.promote(employeeID: employeeID, state: &state, balance: balance)
        case let .demote(employeeID):
            events = EmployeeSystem.demote(employeeID: employeeID, state: &state, balance: balance)
        case let .train(employeeID, skill):
            events = EmployeeSystem.train(
                employeeID: employeeID, skill: skill, state: &state, balance: balance
            )
        case let .takeLoan(amount):
            events = FinanceSystem.takeLoan(amount: amount, state: &state, balance: balance)
        case let .repayLoan(amount):
            events = FinanceSystem.repayLoan(amount: amount, state: &state)
        case let .buildAmenity(amenity):
            events = FinanceSystem.buildAmenity(amenity, state: &state, balance: balance)
        case .matchPoachOffer:
            events = RivalSystem.matchPoachOffer(state: &state, balance: balance)
        case .declinePoachOffer:
            events = RivalSystem.declinePoachOffer(state: &state, balance: balance)
        case .acceptBuyout:
            events = RivalSystem.acceptBuyout(state: &state)
        case .declineBuyout:
            events = RivalSystem.declineBuyout(state: &state)
        case let .acquireRival(rivalID):
            events = RivalSystem.acquireRival(
                rivalID: rivalID, state: &state, balance: balance, content: content
            )
        case let .relocateOffice(district):
            events = CitySystem.relocateOffice(district: district, state: &state, balance: balance)
        case .buyOffice:
            events = CitySystem.buyOffice(state: &state, balance: balance)
        case .sellOffice:
            events = CitySystem.sellOffice(state: &state)
        case let .doInstantActivity(activity):
            events = LifeSystem.doInstantActivity(activity, state: &state, balance: balance)
        case let .buyItem(itemID):
            events = LifeSystem.buyItem(itemID: itemID, state: &state, balance: balance)
        case let .grabCoffee(employeeID):
            events = SocialSystem.grabCoffee(employeeID: employeeID, state: &state, balance: balance)
        case let .oneOnOne(employeeID):
            events = SocialSystem.oneOnOne(employeeID: employeeID, state: &state, balance: balance)
        case let .giveGift(employeeID):
            events = SocialSystem.giveGift(employeeID: employeeID, state: &state, balance: balance)
        case .teamDinner:
            events = SocialSystem.teamDinner(state: &state, balance: balance)
        case let .resolveStaffEvent(choice):
            events = SocialSystem.resolveStaffEvent(
                choice: choice, state: &state, balance: balance, content: content
            )

        // Reserved regions — each workstream adds the handlers for the
        // cases it appended to `GameAction` inside its own region and
        // nowhere else. The switch stays exhaustive: no `default`.

        // MARK: WS-A

        case let .setPriceTier(productID, tier):
            events = ProductSystem.setPriceTier(
                productID: productID, tier: tier, state: &state, balance: balance
            )
        case let .startUpdate(productID):
            events = ProductSystem.startUpdate(
                productID: productID, state: &state, balance: balance, content: content
            )
        case let .setWorkPace(pace):
            events = EmployeeSystem.setWorkPace(pace, state: &state)

        // MARK: WS-B

        case let .resolveChoice(eventID, optionIndex):
            events = NarrativeSystem.resolveChoice(
                eventID: eventID, optionIndex: optionIndex,
                state: &state, balance: balance, content: content
            )

        // MARK: WS-F
        case .acceptInvestment:
            events = InvestorSystem.acceptOffer(state: &state, balance: balance)
            // WS-G: signing closes the independent ladder; the goals card
            // flips the same day.
            if !events.isEmpty {
                ProgressionSystem.termSheetAnswered(declined: false, state: &state, content: content)
            }
        case .declineInvestment:
            events = InvestorSystem.declineOffer(state: &state)
            // WS-G: "Stay independent" is the declaration that opens it.
            if !events.isEmpty {
                ProgressionSystem.termSheetAnswered(declined: true, state: &state, content: content)
            }
        case .fileIPO:
            events = InvestorSystem.fileIPO(state: &state, balance: balance)
        case let .interviewCandidate(candidateID):
            events = HiringSystem.interview(
                candidateID: candidateID, state: &state, balance: balance
            )
        case let .passOnCandidate(candidateID):
            events = HiringSystem.pass(candidateID: candidateID, state: &state)

        // MARK: Founder & people

        case let .trainFounderSkill(skill, method):
            events = FounderSystem.train(
                skill, method: method, state: &state, balance: balance
            )
        case let .talkToContact(contactID, topic):
            events = NetworkingSystem.talk(
                contactID: contactID, topic: topic, state: &state, balance: balance
            )
        case let .makeNetworkingOffer(contactID, offer):
            events = NetworkingSystem.makeOffer(
                contactID: contactID, offer: offer,
                state: &state, balance: balance, content: content
            )
        case .leaveNetworkingEvent:
            events = NetworkingSystem.leaveEvent(state: &state, balance: balance)
        case let .spendTimeWithPartner(activity):
            events = RelationshipSystem.spendTimeWithPartner(
                activity, state: &state, balance: balance
            )
        case let .hangOutWith(employeeID):
            events = RelationshipSystem.hangOut(
                employeeID: employeeID, state: &state, balance: balance
            )
        case let .mentorEmployee(employeeID, skill):
            events = RelationshipSystem.mentor(
                employeeID: employeeID, skill: skill, state: &state, balance: balance
            )
        case let .takeSecuredLoan(amount):
            events = FinanceSystem.takeSecuredLoan(
                amount: amount, state: &state, balance: balance
            )

        // MARK: Iteration 5

        // Scaffold stubs: each lane replaces its own `break` with its
        // system call and nothing else in this region.

        // MARK: WS-A (category fight)
        case .concedeCategory:
            events = RivalSystem.concedeCategory(state: &state)
        case let .defendCategory(topicID, defense):
            events = RivalSystem.defendCategory(
                topicID: topicID, defense: defense,
                state: &state, balance: balance, content: content
            )

        // MARK: WS-B (board)
        case let .buyBackRound(investorID):
            events = InvestorSystem.buyBackRound(
                investorID: investorID, state: &state, balance: balance
            )
        case .acceptBuyoutEarnOut:
            events = InvestorSystem.acceptBuyoutEarnOut(state: &state, balance: balance)

        // MARK: WS-D (policy)
        case let .reverseStaffPolicy(flag):
            events = SocialSystem.reverseStaffPolicy(
                flag: flag, state: &state, balance: balance, content: content
            )

        // MARK: WS-G (ladders)
        case .declareIndependence:
            events = InvestorSystem.declareIndependence(state: &state, balance: balance)

        // MARK: Iteration 7 — R5 (endless)
        // Handled above, before the game-over guard — an ended game is the
        // only place it applies, so this arm is unreachable.
        case .continueAfterEnding:
            events = []

        // MARK: Iteration 9 — the Life tab (handlers, one region per lane)

        // MARK: L1 (phone)
        case let .markPhoneThreadRead(counterpart):
            state.life.phone.markRead(counterpart, day: state.day)
            events = []

        // MARK: L2 (life score, Walked away)

        case .walkAway:
            events = LifeScore.walkAway(state: &state, balance: balance)

        // MARK: L3 (children)
        case let .spendTimeWithChild(childID):
            events = ChildhoodSystem.spendEvening(
                childID: childID, state: &state, balance: balance
            )
        case let .hireChildIntern(childID):
            events = ChildhoodSystem.hireIntern(
                childID: childID, state: &state, balance: balance
            )
        case let .endChildInternship(childID):
            events = ChildhoodSystem.endInternshipEarly(
                childID: childID, state: &state, balance: balance
            )

        // MARK: L4 (friends)
        case let .callFriend(friendID):
            events = FriendSystem.call(
                friendID: friendID, state: &state, balance: balance, content: content
            )
        case let .seeFriend(friendID):
            events = FriendSystem.see(
                friendID: friendID, state: &state, balance: balance, content: content
            )
        case let .hireFriend(friendID):
            events = FriendSystem.hire(
                friendID: friendID, state: &state, balance: balance, content: content
            )
        case let .investInFriend(friendID, amount):
            events = FriendSystem.invest(
                friendID: friendID, amount: amount, state: &state, balance: balance, content: content
            )
        case let .borrowFromFriend(friendID, amount):
            events = FriendSystem.borrow(
                friendID: friendID, amount: amount, state: &state, balance: balance, content: content
            )
        case let .repayFriend(friendID, amount):
            events = FriendSystem.repay(
                friendID: friendID, amount: amount, state: &state, balance: balance, content: content
            )

        // MARK: L5 (side project)
        case let .startSideProject(track):
            events = SideProjectSystem.start(track: track, state: &state, balance: balance)
        case .workOnSideProject:
            events = SideProjectSystem.work(state: &state, balance: balance)
        case .abandonSideProject:
            events = SideProjectSystem.abandon(state: &state, balance: balance)

        // MARK: L6 (sabbatical)
        case let .startSabbatical(caretakerID, weeks):
            events = SabbaticalSystem.start(
                caretakerID: caretakerID, weeks: weeks,
                state: &state, balance: balance, content: content
            )
        case .endSabbaticalEarly:
            events = SabbaticalSystem.endEarly(state: &state, balance: balance)

        // MARK: L7 (furnish)
        case .placeDecor(let slot, let itemID):
            events = []
            // Bought things have to be owned; earned decor is gated by the
            // ledger, which the engine cannot see, so the app offers only
            // what has been unlocked.
            let isShopItem = HomeDecor.shopItems.contains { $0.id == itemID }
            if !isShopItem || state.life.possessions.contains(itemID) {
                HomeDecor.place(
                    itemID: itemID, slot: slot, tier: state.life.home, decor: &state.life.decor
                )
            }
        case .removeDecor(let slot):
            events = []
            HomeDecor.remove(slot: slot, tier: state.life.home, decor: &state.life.decor)

        // MARK: end of Iteration 9

        // MARK: Iteration 10 — handlers, one region per lane

        // MARK: M1 (feature board)

        // The board is a plan, not news: placing a card moves no meter,
        // draws nothing and posts no event. It changes what the thing
        // being designed *is*, and the press finds out at launch.
        case let .placeFeature(productID, cardID, slot):
            events = []
            _ = FeatureBoard.place(
                productID: productID, cardID: cardID, slot: slot,
                state: &state, content: content, balance: balance
            )
        case let .removeFeature(productID, slot):
            events = []
            _ = FeatureBoard.remove(
                productID: productID, slot: slot,
                state: &state, content: content, balance: balance
            )

        // MARK: M2 (pitch room)

        case let .openPitch(counterpart, subjectID):
            events = PitchSystem.open(
                counterpart: counterpart, subjectID: subjectID,
                state: &state, balance: balance, content: content
            )
        case let .sayInPitch(topic):
            events = PitchSystem.say(
                topic: topic, state: &state, balance: balance, content: content
            )
        case .leavePitch:
            events = PitchSystem.leave(state: &state, balance: balance, content: content)

        // MARK: M3 (incident room)

        case let .assignToIncident(employeeID, thread):
            events = IncidentSystem.assign(
                employeeID: employeeID, thread: thread, state: &state, balance: balance
            )
        case let .chooseIncidentStatement(id):
            events = IncidentSystem.chooseStatement(id: id, state: &state, content: content)
        case .advanceIncident:
            events = IncidentSystem.advance(state: &state, balance: balance)
        case .resolveIncident:
            events = IncidentSystem.resolve(state: &state, balance: balance, content: content)
        case .noticeProductsOpened:
            state.economy.incidents.hasOpenedProducts = true
            events = []

        // MARK: M4 (leagues)

        // MARK: M5 (morning desk)
        case let .clearDeskCard(part, today):
            events = []
            // Clearing the third paper marks the day; the streak itself
            // lives in the ledger, which the app writes when it sees
            // `desk.isCleared(on:)` become true.
            state.desk.mark(part, on: today)

        // MARK: M6 (bug hunt)
        case let .squashBug(productID):
            events = ProductSystem.squash(productID: productID, state: &state, balance: balance)

        // MARK: end of Iteration 10

        // MARK: Iteration 11 — handlers, one region per lane

        // MARK: N1 (crime and the courtroom)
        case let .commitOffence(offence, rivalID, productID):
            events = CrimeSystem.commit(
                offence: offence, rivalID: rivalID, productID: productID,
                state: &state, balance: balance, content: content
            )
        case let .confessOffence(entryID):
            events = CrimeSystem.confess(entryID: entryID, state: &state, balance: balance)
        case .settleCase:
            events = CrimeSystem.settle(state: &state, balance: balance)
        case let .hireLawyer(tier):
            events = CrimeSystem.hire(lawyer: tier, state: &state, balance: balance)
        case let .chooseDefence(defence):
            events = CrimeSystem.choose(defence: defence, state: &state)
        case .openHearing:
            events = CrimeSystem.openHearing(state: &state, balance: balance)
        case let .sayInCourt(exchange):
            events = CrimeSystem.say(exchange, state: &state, balance: balance)
        case .restCase:
            events = CrimeSystem.rest(state: &state, balance: balance)
        case let .sueRival(rivalID):
            events = CrimeSystem.sue(rivalID: rivalID, state: &state, balance: balance)

        // MARK: N2 (people menus)
        case let .interact(target, interaction):
            events = InteractionSystem.perform(
                target: target, interactionID: interaction,
                state: &state, balance: balance, content: content
            )
        case .breakUp:
            events = InteractionSystem.breakUp(
                state: &state, balance: balance, content: content
            )
        case let .fireWithCause(employeeID):
            events = InteractionSystem.fireWithCause(
                employeeID: employeeID, state: &state, balance: balance
            )

        // MARK: N3 (assets, vices and the doctor)
        case .noticeAssetsOpened:
            events = AssetsSystem.noticeOpened(&state)
        case let .buyAsset(assetID):
            events = AssetsSystem.buy(assetID, state: &state, balance: balance)
        case let .sellAsset(assetID):
            events = AssetsSystem.sell(assetID, state: &state, balance: balance)
        case let .repairAsset(assetID):
            events = AssetsSystem.repair(assetID, state: &state, balance: balance)
        case let .treatAilment(ailmentID):
            events = AssetsSystem.treat(ailmentID, state: &state, balance: balance)
        case .attendTherapy:
            events = AssetsSystem.therapy(state: &state, balance: balance)
        case let .quitVice(viceID):
            events = AssetsSystem.quit(viceID, state: &state, balance: balance)
        case let .abandonQuit(viceID):
            events = AssetsSystem.abandonQuit(viceID, state: &state)
        case let .playCasinoGame(gameID, stake):
            events = AssetsSystem.gamble(gameID, stake: stake, state: &state, balance: balance)
        case .buyLotteryTicket:
            events = AssetsSystem.buyTicket(state: &state, balance: balance)
        case let .tradeCrypto(dollars):
            events = AssetsSystem.trade(dollars: dollars, state: &state, balance: balance)

        // MARK: N4 (fame and the feed)
        case let .postToFeed(kind, subject):
            events = FameSystem.post(
                kind: kind, subject: subject, state: &state, balance: balance, content: content
            )
        case let .answerFeedBeef(escalate):
            events = FameSystem.answerBeef(
                escalate: escalate, state: &state, balance: balance, content: content
            )
        case let .answerFameCancellation(response):
            events = FameSystem.answerCancellation(
                response: response, state: &state, balance: balance, content: content
            )

        // MARK: N5 (office secrets)
        case .watchTheOffice:
            events = OfficeSecretsSystem.watch(&state)
        case let .respondToSecret(response):
            events = OfficeSecretsSystem.respond(
                response, state: &state, balance: balance, content: content
            )
        case let .seedOfficeSecret(kind, stage):
            #if DEBUG
            events = SecretKind(rawValue: kind).map {
                OfficeSecretsSystem.seed(
                    $0, stage: stage, state: &state, balance: balance, content: content
                )
            } ?? []
            #else
            events = []
            #endif

        // MARK: end of Iteration 11

        // MARK: Iteration 11, wave two — handlers

        // MARK: W1 (dirty money)

        case .noticeFinancesOpened:
            // The identity gate. Nothing else in the lane can happen
            // until a player has looked at their own finances, and this
            // is the only thing that makes `state.dirtyMoney` non-empty.
            if !state.dirtyMoney.noticed {
                state.dirtyMoney.noticed = true
            }
            events = []
        case .takeDirtyMoney:
            events = DirtyMoneySystem.take(state: &state, balance: balance)
        case .declineDirtyMoney:
            events = DirtyMoneySystem.declineOffer(state: &state)
        case let .answerDirtyMoneyDemand(answer):
            events = DirtyMoneySystem.answer(answer, state: &state, balance: balance)
        case .payOffBacker:
            events = DirtyMoneySystem.payOff(state: &state, balance: balance)
        case .turnWitnessOnBacker:
            events = DirtyMoneySystem.turnWitness(state: &state, balance: balance)
        case .sellUpToBacker:
            events = DirtyMoneySystem.sellUp(state: &state, balance: balance)
        case let .seedDirtyMoneyOffer(backer):
            #if DEBUG
            events = DirtyMoneySystem.debugSeedOffer(
                backer: backer, state: &state, balance: balance
            )
            #else
            events = []
            #endif
        case let .seedDirtyMoneyDemand(kind):
            #if DEBUG
            events = DirtyMoneySystem.debugSeedDemand(
                kind: kind, state: &state, balance: balance
            )
            #else
            events = []
            #endif

        // MARK: W2 (family drama)

        case .openFamilyRoom:
            events = FamilyDramaSystem.openRoom(
                state: &state, balance: balance, content: content
            )

        case let .confrontFamily(answer):
            events = FamilyDramaSystem.confront(
                answer, state: &state, balance: balance, content: content
            )

        case let .divorceSettlement(keep, lawyer):
            events = FamilyDramaSystem.divorce(
                keep: keep, lawyer: lawyer, state: &state, balance: balance, content: content
            )

        case .fileCustody:
            events = FamilyDramaSystem.fileCustody(state: &state, balance: balance)

        case let .answerFamilyAsk(accept):
            events = FamilyDramaSystem.answerAsk(
                accept: accept, state: &state, balance: balance, content: content
            )

        case let .familySpareRoom(accept):
            events = FamilyDramaSystem.spareRoom(
                accept: accept, state: &state, balance: balance
            )

        case let .seeRelative(relation):
            events = FamilyDramaSystem.visit(relation, state: &state, balance: balance)

        case let .signWill(heir, childID):
            events = FamilyDramaSystem.signWill(
                heir: heir, childID: childID, state: &state, balance: balance,
                content: content
            )

        case let .settleFuneral(answer):
            events = FamilyDramaSystem.settleFuneral(
                answer, state: &state, balance: balance
            )

        case let .seedFamilyDrama(stage):
            #if DEBUG
            events = FamilyDramaSystem.seed(
                stage, state: &state, balance: balance, content: content
            )
            #else
            events = []
            #endif

        // MARK: W3 (espionage)
        case let .runEspionageOperation(operation, rivalID):
            events = EspionageSystem.operate(
                operation, against: rivalID,
                state: &state, balance: balance, content: content
            )

        // MARK: W4 (inside)

        // MARK: end of Iteration 11, wave two
        }

        state.logEvents(events)
        return events
    }

    // MARK: Iteration 7 — R5 (endless)

    /// Keeps the company running past an ending that allows it.
    ///
    /// Only the two endings the founder walks away from on their own terms
    /// — the IPO and *Still yours* — can be played past: a bankruptcy, an
    /// ousting, a sale and an acquisition all hand the company to somebody
    /// else, and there is nothing left to run. The ending is remembered in
    /// `state.epilogue` rather than thrown away, so the biography, the
    /// front door and the systems that must stand down (no board, no term
    /// sheets, no buyers) can all read one fact.
    ///
    /// Refused when there is no ending, when the ending is one of the four
    /// that end it, and when the company is already running an epilogue.
    /// Draws nothing and moves no number: an epilogue run is the same
    /// simulation with three doors closed.
    private static func continueAfterEnding(_ state: inout GameState) -> [GameEvent] {
        guard let ending = state.gameOver,
              ending.kind == .ipo || ending.kind == .independent,
              state.epilogue == nil
        else { return [] }
        // The clock has not moved since the ending — `tick` refuses an
        // ended game — so this is both the day it ended and the day the
        // founder decided to carry on.
        state.epilogue = Epilogue(ending: ending.kind, day: state.day)
        state.gameOver = nil
        return [.continuedAfterEnding(ending: ending.kind, day: state.day)]
    }
}
