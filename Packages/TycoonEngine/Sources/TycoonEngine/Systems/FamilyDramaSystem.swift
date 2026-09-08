import Foundation
import TycoonContent

// Iteration 11, wave two — W2 (family drama). W2 owns this file.
//
// The daily half of the lane: the affair's weekly discovery roll, the
// parents ageing towards a care bill and a funeral, the sibling
// escalating, the in-laws in the spare room, and the custody hearing's
// verdict when N1's room hands it back.
//
// Rule 1: this returns on its first line until the founder has either
// opened the family room or started an affair. Neither happens by
// accident, so no bot ever reaches the second line and a run that never
// touches this writes the bytes it always wrote.
//
// Rule 2: every draw is `socialRNG`.
enum FamilyDramaSystem {

    // MARK: - The tick

    static func run(
        state: inout GameState,
        balance: BalanceConfig,
        content: ContentCatalog
    ) -> [GameEvent] {
        guard isEngaged(state) else { return [] }
        var events: [GameEvent] = []
        events.append(contentsOf: weeklySweep(&state, balance, content))
        events.append(contentsOf: careClock(&state, balance))
        return events
    }

    /// The identity gate. The founder has to have done something.
    static func isEngaged(_ state: GameState) -> Bool {
        state.interactions.hasAffair || state.familyDrama != .empty
    }

    // MARK: The weekly sweep

    private static func weeklySweep(
        _ state: inout GameState,
        _ balance: BalanceConfig,
        _ content: ContentCatalog
    ) -> [GameEvent] {
        guard state.day > 0, state.day.isMultiple(of: GameState.daysPerWeek),
              state.familyDrama.lastSweepDay != state.day
        else { return [] }
        state.familyDrama.lastSweepDay = state.day
        var events: [GameEvent] = []
        events.append(contentsOf: discoveryRoll(&state, balance))
        events.append(contentsOf: parentsAge(&state, balance, content))
        events.append(contentsOf: siblingAsks(&state, balance, content))
        inLawsWeek(&state, balance)
        silence(&state, balance)
        return events
    }

    // MARK: Discovery

    /// One roll a week while there is a secret affair. N2 started it; W2
    /// is the lane that ends it.
    private static func discoveryRoll(
        _ state: inout GameState, _ balance: BalanceConfig
    ) -> [GameEvent] {
        guard state.interactions.affairIsSecret,
              state.life.family.stage != .single
        else { return [] }
        let config = balance.familyDrama
        let weeks = state.interactions.affairWeeksRunning(day: state.day)
        let chance = FamilyDrama.discoveryChance(
            weeksRunning: weeks,
            intervened: !state.assets.intervened.isEmpty,
            fame: state.fame.fame,
            balance: config
        )
        guard state.socialRNG.nextUniform() < chance else { return [] }

        state.interactions.markAffairDiscovered(day: state.day)
        state.familyDrama.confrontedDay = state.day
        state.familyDrama.confessionAnswer = nil
        state.life.family.affection = max(
            0, state.life.family.affection - config.discoveryAffectionHit
        )
        state.narrative.flags.insert(FamilyDrama.discoveredFlag)
        state.life.phone.post(
            "We need to talk tonight. Not on here.", from: .partner, day: state.day
        )
        state.speed = .paused
        return [.familyAffairDiscovered(day: state.day)]
    }

    // MARK: The parents

    /// They get a year older every year, and eventually one of two things
    /// happens: a bill, or a funeral. Only ever for a founder who has
    /// already engaged with the room — the gate at the top of `run` — and
    /// only from the balance's third year.
    private static func parentsAge(
        _ state: inout GameState, _ balance: BalanceConfig, _ content: ContentCatalog
    ) -> [GameEvent] {
        let config = balance.familyDrama
        guard state.familyDrama.openedDay != nil,
              state.day / FamilyKin.daysPerYear + 1 >= config.careMinYear
        else { return [] }
        var events: [GameEvent] = []
        let relatives = state.familyRelatives(names: content.names)
        for relative in relatives where relative.relation.isParent {
            let record = state.familyDrama.record(relative.relation)
            guard record?.isAlive != false else { continue }

            // The care question, once, when they are old enough.
            if relative.age >= config.careAge, record?.careSinceDay == nil {
                state.familyDrama.upsert(relative.relation) { $0.careSinceDay = state.day }
                state.familyDrama.careWeeklyBill += config.careWeeklyBill
                state.narrative.flags.insert(FamilyDrama.careFlag)
                state.life.phone.post(
                    "They've had a fall. It's not serious. The home wants a number by Friday.",
                    from: .partner, day: state.day
                )
                events.append(.familyCareStarted(
                    relation: relative.relation.rawValue,
                    name: relative.name,
                    weekly: config.careWeeklyBill,
                    day: state.day
                ))
                continue
            }

            // And then, one week, the phone call.
            guard relative.age >= config.deathAge,
                  state.socialRNG.nextUniform() < config.deathWeekly
            else { continue }
            state.familyDrama.upsert(relative.relation) {
                $0.diedDay = state.day
                $0.careSinceDay = nil
            }
            state.familyDrama.careWeeklyBill = max(
                0, state.familyDrama.careWeeklyBill - config.careWeeklyBill
            )
            state.familyDrama.funeralDay = state.day
            state.familyDrama.funeralRelation = relative.relation.rawValue
            state.familyDrama.funeralAnswer = nil
            state.life.wallet += config.inheritance
            state.life.meters.apply(mood: config.bereavementMood)
            state.narrative.flags.insert(FamilyDrama.bereavedFlag)
            state.life.phone.post(
                "It was this morning. It was quick. Come when you can.",
                from: .partner, day: state.day
            )
            state.life.awayUntilDay = state.day + config.funeralAwayDays
            state.life.awaySinceDay = state.day
            state.life.awayReason = "Funeral"
            state.speed = .paused
            events.append(.familyParentDied(
                relation: relative.relation.rawValue, name: relative.name, day: state.day
            ))
            break
        }
        return events
    }

    /// The weekly bill for whoever is in a home.
    private static func careClock(
        _ state: inout GameState, _ balance: BalanceConfig
    ) -> [GameEvent] {
        guard state.familyDrama.careWeeklyBill > 0,
              state.day > 0, state.day.isMultiple(of: GameState.daysPerWeek)
        else { return [] }
        state.life.wallet -= state.familyDrama.careWeeklyBill
        return []
    }

    // MARK: The sibling

    /// A job, then a stake, then a loan — each one asked once, each one
    /// waiting for an answer on the card.
    private static func siblingAsks(
        _ state: inout GameState, _ balance: BalanceConfig, _ content: ContentCatalog
    ) -> [GameEvent] {
        let config = balance.familyDrama
        guard state.familyDrama.openedDay != nil,
              state.company.cash >= config.askMinCash
        else { return [] }
        let record = state.familyDrama.record(.sibling)
        guard record?.hasOpenAsk != true, (record?.askStage ?? 0) < FamilyAsk.loan.rawValue
        else { return [] }
        if let last = record?.askOpenDay ?? record?.lastSeenDay,
           state.day - last < config.askCooldownDays {
            return []
        }
        guard state.socialRNG.nextUniform() < config.askWeekly else { return [] }
        let stage = (record?.askStage ?? 0) + 1
        state.familyDrama.upsert(.sibling) {
            $0.askStage = stage
            $0.askOpenDay = state.day
        }
        let name = state.familyRelativeName(.sibling, content: content)
        state.life.phone.post(
            FamilyAsk(rawValue: stage)?.askLine(name: state.company.name) ?? "Are you about?",
            from: .partner, day: state.day
        )
        return [.familyKinAsk(relation: FamilyRelation.sibling.rawValue, name: name,
                              stage: stage, day: state.day)]
    }

    // MARK: The in-laws

    /// A week with the in-laws in the spare room: the rent they save, the
    /// mood they cost, and the affection they buy.
    private static func inLawsWeek(_ state: inout GameState, _ balance: BalanceConfig) {
        guard state.familyDrama.record(.motherInLaw)?.movedInDay != nil,
              state.life.family.stage != .single
        else { return }
        let config = balance.familyDrama
        state.life.wallet += config.inLawsWeeklySaving
        state.life.meters.apply(mood: config.inLawsMoodDrift)
        state.life.family.affection = min(
            100, state.life.family.affection + config.inLawsAffectionDrift
        )
    }

    /// Nobody calls anybody. The bond slides.
    private static func silence(_ state: inout GameState, _ balance: BalanceConfig) {
        let config = balance.familyDrama
        for index in state.familyDrama.kin.indices {
            guard state.familyDrama.kin[index].isAlive else { continue }
            let last = state.familyDrama.kin[index].lastSeenDay ?? state.familyDrama.openedDay ?? 0
            guard state.day - last > GameState.daysPerWeek * 2 else { continue }
            state.familyDrama.kin[index].bond = max(
                0, state.familyDrama.kin[index].bond - config.silenceDecay
            )
        }
    }

    // MARK: - The founder's own moves

    /// The room is open. This is the only place the lane starts costing
    /// bytes for a founder who never had an affair.
    static func openRoom(
        state: inout GameState, balance: BalanceConfig, content: ContentCatalog
    ) -> [GameEvent] {
        guard state.familyDrama.openedDay == nil else { return [] }
        state.familyDrama.openedDay = state.day
        state.familyDrama.calendarSeededDay = state.day
        state.narrative.flags.insert(FamilyDrama.openedFlag)
        FamilyCalendar.parentsArrived(&state, balance: balance, content: content)
        return []
    }

    /// What the founder says the night it comes out.
    static func confront(
        _ answer: FamilyConfession,
        state: inout GameState,
        balance: BalanceConfig,
        content: ContentCatalog
    ) -> [GameEvent] {
        guard state.familyDrama.isConfrontationOpen else { return [] }
        let config = balance.familyDrama
        state.familyDrama.confessionAnswer = answer.rawValue
        if answer.endsAffair { state.interactions.endAffair() }
        let affection: Double = switch answer {
        case .confess: config.confessAffection
        case .deny: config.denyAffection
        case .endIt: config.endItAffection
        case .leave: 0
        }
        state.life.family.affection = max(0, state.life.family.affection + affection)
        state.life.meters.apply(mood: config.confrontationMood)
        state.life.phone.post(answer.line, from: .partner, day: state.day, fromFounder: true)
        var events: [GameEvent] = [.familyConfronted(answer: answer.rawValue, day: state.day)]
        if answer == .leave {
            events.append(contentsOf: InteractionSystem.breakUp(
                state: &state, balance: balance, content: content
            ))
        }
        return events
    }

    // MARK: The settlement

    /// Divides the estate. `InteractionSystem.breakUp` runs first — that
    /// is N2's deliberate end of a relationship, and it deliberately
    /// leaves the home, the children and the things alone — and then this
    /// divides what is left.
    ///
    /// `keep` is what the player dragged into their own column: catalog
    /// ids, plus `FamilyDramaSystem.homeToken` for the roof and
    /// `petToken` for the dog. Everything not in it goes.
    static func divorce(
        keep: [String],
        lawyer: CrimeLawyer,
        state: inout GameState,
        balance: BalanceConfig,
        content: ContentCatalog
    ) -> [GameEvent] {
        guard state.life.family.stage != .single, !state.familyDrama.isDivorced
        else { return [] }
        let config = balance.familyDrama
        let exName = state.life.family.partnerName ?? "your ex"
        let marriedDays = state.life.family.stage == .married
            ? max(0, state.day - state.life.family.stageSinceDay)
            : 0
        // Their side hires one tier off yours, which is what money does.
        let theirLawyer = opposingLawyer(for: lawyer, state: &state)
        let fee = FamilyDrama.lawyerFee(lawyer, balance: config)
        state.life.wallet -= fee

        var events = InteractionSystem.breakUp(
            state: &state, balance: balance, content: content
        )

        // What the whole estate is worth, and what the founder is owed of
        // it. Anything they keep above that is settled in cash.
        let share = FamilyDrama.entitlement(
            lawyer: lawyer,
            theirLawyer: theirLawyer,
            affairDiscovered: state.interactions.affairDiscoveredDay != nil,
            marriedDays: marriedDays,
            balance: config
        )
        let estate = state.assetResaleValue(balance: balance)
        let kept = Set(keep)
        var keptValue = 0
        var keptIDs: [String] = []
        var lostIDs: [String] = []
        var petName = ""
        var petKept = false

        for owned in state.assets.owned {
            let value = resale(owned, balance: balance)
            if !owned.petName.isEmpty { petName = owned.petName }
            if kept.contains(owned.catalogID) || (kept.contains(petToken) && !owned.petName.isEmpty) {
                keptValue += value
                keptIDs.append(owned.catalogID)
                if !owned.petName.isEmpty { petKept = true }
            } else {
                lostIDs.append(owned.catalogID)
            }
        }
        // The crypto wallet is not draggable — it is money, and money is
        // split as money.
        let crypto = state.assets.crypto?.value ?? 0
        keptValue += crypto / 2

        // The home follows the children: whoever has them keeps the roof,
        // unless there are none, in which case the column decides.
        let keepsHome: Bool
        if state.life.family.children.isEmpty {
            keepsHome = kept.contains(homeToken)
        } else {
            keepsHome = state.familyDrama.custody?.keepsTheHouse ?? kept.contains(homeToken)
        }

        let owed = Int((Double(estate) * share).rounded())
        var transfer = owed - keptValue
        if !keepsHome {
            // The roof is the biggest thing in the room and it is not on
            // the resale list: losing it is paid back in cash.
            transfer += homeValue(state.life.home, balance: balance)
            downgradeHome(&state)
        }
        state.life.wallet += transfer

        // Everything not kept stops existing, which takes the weekly bill,
        // the mood drift, the net worth and the driveway with it.
        for id in lostIDs {
            state.assets.owned.removeAll { $0.catalogID == id }
            if let def = balance.assets.asset(id),
               let slot = HomeDecor.assetSlotID(for: def.assetKind) {
                _ = HomeDecor.remove(slot: slot, tier: state.life.home, decor: &state.life.decor)
            }
        }
        // Half the wallet is theirs: the units go, not the price.
        if state.assets.crypto != nil {
            state.assets.crypto?.units /= 2
        }

        // The company: a long marriage costs a slice of it, held the way
        // a co-founder holds theirs — not a round, no board seat, simply
        // not the founder's any more.
        let equity = FamilyDrama.equityToEx(
            marriedDays: marriedDays,
            equityRemaining: state.investors.equityRemaining,
            balance: config
        )
        if equity > 0 {
            state.investors.equityRemaining = max(0, state.investors.equityRemaining - equity)
        }

        state.familyDrama.divorcedDay = state.day
        state.familyDrama.settlement = FamilySettlement(
            day: state.day,
            keptHome: keepsHome,
            keptAssetIDs: keptIDs.sorted(),
            lostAssetIDs: lostIDs.sorted(),
            petName: petName,
            petKept: petKept,
            cashTransfer: transfer,
            equityGiven: equity,
            lawyer: lawyer.rawValue,
            theirLawyer: theirLawyer.rawValue,
            exName: exName
        )
        // The in-laws were the partner's. They go with them.
        state.familyDrama.kin.removeAll { $0.kind?.isInLaw == true }
        state.life.meters.apply(mood: config.divorceMood)
        state.narrative.flags.insert(FamilyDrama.divorcedFlag)
        state.speed = .paused

        events.append(.familyDivorced(
            exName: exName,
            cashTransfer: transfer,
            keptHome: keepsHome,
            equityGiven: equity,
            day: state.day
        ))
        return events
    }

    /// The token the settlement sheet drags for the roof and the dog.
    static let homeToken = "home"
    static let petToken = "pet"

    /// Their solicitor, one draw on `socialRNG`: usually a tier below
    /// yours, sometimes the same, occasionally better, because somebody
    /// in their family knows somebody.
    private static func opposingLawyer(
        for lawyer: CrimeLawyer, state: inout GameState
    ) -> CrimeLawyer {
        let ladder = CrimeLawyer.ladder
        let mine = ladder.firstIndex(of: lawyer) ?? 0
        let roll = state.socialRNG.nextUniform()
        let offset = roll < 0.55 ? -1 : (roll < 0.9 ? 0 : 1)
        return ladder[min(ladder.count - 1, max(0, mine + offset))]
    }

    private static func resale(_ owned: AssetOwned, balance: BalanceConfig) -> Int {
        guard let def = balance.assets.asset(owned.catalogID) else { return 0 }
        let base = Double(def.price) * def.resaleFraction
        let docked = owned.needsRepair ? base * balance.assets.brokenResaleFactor : base
        return Int(docked.rounded())
    }

    /// What the roof is worth in a settlement — the ladder's own price for
    /// the tier, so a penthouse costs more to lose than a studio flat.
    private static func homeValue(_ tier: HomeTier, balance: BalanceConfig) -> Int {
        balance.life.home(tier).upgradeCost
    }

    /// Losing the house is one rung down the ladder, which is exactly what
    /// an eviction already does — and L7's decor goes with the tier.
    private static func downgradeHome(_ state: inout GameState) {
        guard let previous = state.life.home.previous else { return }
        state.life.home = previous
    }

    // MARK: Custody

    /// Files for the children. The same machinery N1 runs, with a family
    /// opener and a family verdict: `LegalCase.isFounderSuing` is the
    /// seam, and `kind` says which room it is.
    static func fileCustody(
        state: inout GameState, balance: BalanceConfig
    ) -> [GameEvent] {
        let config = balance.familyDrama
        guard state.crime.pendingCase == nil,
              state.familyDrama.custodyCaseID == nil,
              !state.life.family.children.isEmpty,
              state.life.wallet >= config.custodyFilingFee
        else { return [] }
        state.life.wallet -= config.custodyFilingFee
        let weeks = state.socialRNG.nextInt(in: config.custodyHearingWeeksMin...max(
            config.custodyHearingWeeksMin, config.custodyHearingWeeksMax
        ))
        let hearingDay = state.day + weeks * GameState.daysPerWeek
        let id = "custody-\(state.day)"
        let standing = FamilyDrama.custodyStanding(
            children: state.life.family.children,
            affairDiscovered: state.interactions.affairDiscoveredDay != nil,
            lawyer: .dutySolicitor,
            balance: config
        )
        state.crime.cases.append(LegalCase(
            id: id,
            kind: FamilyDrama.custodyCaseKind,
            raisedDay: state.day,
            hearingDay: hearingDay,
            isFounderSuing: true,
            // The evidence is the childhood, mapped onto the courtroom's
            // 0…1 paper scale so N1's grading reads it unchanged.
            evidence: min(0.95, max(0.05, 0.5 - standing / 200))
        ))
        state.familyDrama.custodyCaseID = id
        state.life.phone.post(
            "The hearing is listed. Bring the diary, all of it.",
            from: .office, day: state.day
        )
        return [.familyCustodyFiled(hearingDay: hearingDay, day: state.day)]
    }

    /// N1's `deliver` hands a custody case here rather than reading it as
    /// a crime. The bands are the family court's, the money is nobody's,
    /// and the children's bond moves with the verdict.
    static func deliverCustody(
        standing: Double,
        index: Int,
        state: inout GameState,
        balance: BalanceConfig
    ) -> [GameEvent] {
        let config = balance.familyDrama
        // The room's own arithmetic settles it: the exchanges moved the
        // standing that the childhood opened.
        let verdict = FamilyDrama.custodyVerdict(standing, balance: config)
        state.crime.cases[index].verdict = verdict.keepsTheHouse ? .acquitted : .fine
        state.familyDrama.custodyVerdict = verdict.rawValue
        state.familyDrama.custodyDecidedDay = state.day
        for childIndex in state.life.family.children.indices {
            state.life.family.children[childIndex].bond = min(100, max(
                0, state.life.family.children[childIndex].bond + verdict.bondDelta
            ))
        }
        state.life.meters.apply(mood: verdict.keepsTheHouse ? 6 : -14)
        for child in state.life.family.children {
            state.life.phone.post(
                verdict.keepsTheHouse
                    ? "so is it just normal now"
                    : "mum says i can call whenever. is that true",
                from: .child(child.id), day: state.day
            )
        }
        return [.familyCustodyDecided(verdict: verdict.rawValue, day: state.day)]
    }

    // MARK: The relatives

    /// An evening with somebody who is not the company.
    static func visit(
        _ relation: FamilyRelation, state: inout GameState, balance: BalanceConfig
    ) -> [GameEvent] {
        let config = balance.familyDrama
        guard state.hasEveningFree(balance),
              state.familyDrama.record(relation)?.isAlive != false
        else { return [] }
        if let last = state.familyDrama.record(relation)?.lastSeenDay,
           state.day - last < config.visitCooldownDays {
            return []
        }
        state.spendEvening(balance)
        state.familyDrama.upsert(relation) {
            $0.bond = min(100, $0.bond + config.visitBond)
            $0.lastSeenDay = state.day
        }
        state.life.meters.apply(mood: config.visitMood, relationships: 3)
        return []
    }

    /// Yes or no to whatever the sibling wants this time.
    static func answerAsk(
        accept: Bool,
        state: inout GameState,
        balance: BalanceConfig,
        content: ContentCatalog
    ) -> [GameEvent] {
        let config = balance.familyDrama
        guard let record = state.familyDrama.record(.sibling), record.hasOpenAsk,
              let ask = FamilyAsk(rawValue: record.askStage)
        else { return [] }
        let name = state.familyRelativeName(.sibling, content: content)
        state.familyDrama.upsert(.sibling) {
            $0.askOpenDay = nil
            $0.lastSeenDay = state.day
            $0.bond = min(100, max(0, $0.bond + (accept ? config.askYesBond : config.askNoBond)))
        }
        guard accept else {
            return [.familyKinAnswered(
                relation: FamilyRelation.sibling.rawValue, accepted: false, day: state.day
            )]
        }
        switch ask {
        case .job:
            let hire = Employee(
                id: UUID(from: &state.socialRNG),
                name: name,
                skills: SkillSet(coding: 12, design: 10, marketing: 14),
                weeklySalary: config.siblingSalary,
                assignment: .idle,
                isFounder: false,
                hiredDay: state.day,
                appearanceSeed: state.socialRNG.next(),
                level: .junior,
                loyalty: 80,
                role: .marketer
            )
            state.employees.append(hire)
            state.familyDrama.upsert(.sibling) { $0.employeeID = hire.id }
        case .stake:
            let points = min(state.investors.equityRemaining, config.siblingStakePoints)
            state.investors.equityRemaining = max(0, state.investors.equityRemaining - points)
            state.familyDrama.upsert(.sibling) { $0.stakePoints += points }
        case .loan:
            state.life.wallet -= config.siblingLoan
            state.familyDrama.upsert(.sibling) { $0.lentAmount += config.siblingLoan }
        }
        return [.familyKinAnswered(
            relation: FamilyRelation.sibling.rawValue, accepted: true, day: state.day
        )]
    }

    /// The in-laws and the spare room.
    static func spareRoom(
        accept: Bool, state: inout GameState, balance: BalanceConfig
    ) -> [GameEvent] {
        guard state.life.family.stage != .single else { return [] }
        let occupied = state.familyDrama.record(.motherInLaw)?.movedInDay != nil
        guard accept != occupied else { return [] }
        for relation in [FamilyRelation.motherInLaw, .fatherInLaw] {
            state.familyDrama.upsert(relation) { $0.movedInDay = accept ? state.day : nil }
        }
        if accept {
            state.life.family.affection = min(100, state.life.family.affection + 6)
        }
        return [.familyInLawsMoved(movedIn: accept, day: state.day)]
    }

    /// The will. Nothing happens today; the dynasty reads it at the end.
    static func signWill(
        heir: FamilyHeir,
        childID: UUID?,
        state: inout GameState,
        balance: BalanceConfig,
        content: ContentCatalog
    ) -> [GameEvent] {
        let name = heirName(heir, childID: childID, state: state, content: content)
        guard heir != .child || childID != nil else { return [] }
        state.familyDrama.heir = heir.rawValue
        state.familyDrama.heirChildID = heir == .child ? childID : nil
        state.familyDrama.heirName = name
        state.familyDrama.willSignedDay = state.day
        state.narrative.flags.insert(FamilyDrama.willFlag)
        return [.familyWillSigned(heir: heir.rawValue, name: name, day: state.day)]
    }

    /// Who the will actually names, resolved against the live state.
    static func heirName(
        _ heir: FamilyHeir, childID: UUID?, state: GameState, content: ContentCatalog
    ) -> String {
        switch heir {
        case .partner:
            state.life.family.partnerName ?? "Your partner"
        case .child:
            state.life.family.children.first { $0.id == childID }?.name ?? "Your child"
        case .employee:
            state.employees
                .filter { !$0.isFounder }
                .min { ($0.hiredDay, $0.name) < ($1.hiredDay, $1.name) }?
                .name ?? "The longest-serving"
        case .sibling:
            state.familyRelativeName(.sibling, content: content)
        case .nobody:
            "Nobody"
        }
    }

    /// The one argument at the funeral.
    static func settleFuneral(
        _ answer: FamilyDrama.FuneralArgument,
        state: inout GameState,
        balance: BalanceConfig
    ) -> [GameEvent] {
        guard state.familyDrama.isFuneralOpen else { return [] }
        state.familyDrama.funeralAnswer = answer.rawValue
        let bond: Double = switch answer {
        case .takeIt: -18
        case .letThemHaveIt: 12
        case .walkOut: -8
        }
        let mood: Double = switch answer {
        case .takeIt: 6
        case .letThemHaveIt: -8
        case .walkOut: -4
        }
        state.familyDrama.upsert(.sibling) { $0.bond = min(100, max(0, $0.bond + bond)) }
        state.life.meters.apply(mood: mood)
        return [.familyFuneralSettled(choice: answer.rawValue, day: state.day)]
    }

    // MARK: - The screenshot pass

    #if DEBUG
    /// `-autoFamily <stage>`: puts the lane in a state worth a picture.
    /// Debug only, and every step goes through the lane's own functions so
    /// a screenshot is of the real thing.
    static func seed(
        _ stage: String,
        state: inout GameState,
        balance: BalanceConfig,
        content: ContentCatalog
    ) -> [GameEvent] {
        var events = openRoom(state: &state, balance: balance, content: content)
        guard stage != "room" else { return events }

        // An affair with the warmest contact in the book, started a season
        // ago — N2's fields, written the way N2 writes them.
        if state.interactions.affairContactID == nil {
            let contact = state.networking.contacts.max { $0.rapport < $1.rapport }
            state.interactions.affairContactID = contact?.id ?? UUID(from: &state.socialRNG)
            state.interactions.affairSinceDay = max(0, state.day - 90)
        }
        guard stage != "affair" else { return events }

        events.append(contentsOf: discover(state: &state, balance: balance))
        guard stage != "discovered" else { return events }

        if stage == "will" { return events }
        if stage == "table" {
            // A table with something on it: the wallet is topped up and
            // every thing is bought through `AssetsSystem.buy`, so the
            // resale values the sheet prints are the catalog's own.
            state.life.wallet += 120_000
            for id in ["coupe", "hatchback", "flatToLet", "dog"] {
                _ = AssetsSystem.buy(id, state: &state, balance: balance)
            }
            return events
        }
        if stage == "ask" {
            state.familyDrama.upsert(.sibling) {
                $0.askStage = FamilyAsk.stake.rawValue
                $0.askOpenDay = state.day
            }
            return events
        }
        if stage == "funeral" {
            state.familyDrama.upsert(.mother) { $0.diedDay = state.day }
            state.familyDrama.funeralDay = state.day
            state.familyDrama.funeralRelation = FamilyRelation.mother.rawValue
            state.familyDrama.funeralAnswer = nil
            return events
        }
        if stage == "custody" {
            events.append(contentsOf: confront(
                .leave, state: &state, balance: balance, content: content
            ))
            events.append(contentsOf: fileCustody(state: &state, balance: balance))
            if let pending = state.crime.pendingCase {
                state.crime.cases[state.crime.cases.count - 1].hearingDay = state.day
                _ = pending
            }
        }
        return events
    }

    /// The discovery roll's consequence without the roll — the sheet the
    /// screenshot pass wants open.
    private static func discover(
        state: inout GameState, balance: BalanceConfig
    ) -> [GameEvent] {
        guard state.interactions.affairIsSecret else { return [] }
        state.interactions.markAffairDiscovered(day: state.day)
        state.familyDrama.confrontedDay = state.day
        state.familyDrama.confessionAnswer = nil
        state.life.family.affection = max(
            0, state.life.family.affection - balance.familyDrama.discoveryAffectionHit
        )
        state.narrative.flags.insert(FamilyDrama.discoveredFlag)
        state.life.phone.post(
            "We need to talk tonight. Not on here.", from: .partner, day: state.day
        )
        return [.familyAffairDiscovered(day: state.day)]
    }
    #endif
}

// MARK: - Gates and derived facts the app reads

extension GameState {
    /// The family onboarding never made, derived fresh: the founder's
    /// mother, father and sibling, and the partner's parents when there is
    /// a partner. Costs nothing and writes nothing.
    public func familyRelatives(names: NamePools) -> [FamilyRelative] {
        FamilyKin.derive(
            seed: seed,
            partnerSeed: life.family.partnerAppearanceSeed,
            names: names,
            day: day
        )
    }

    /// One relative's name, for a phone line or a card.
    public func familyRelativeName(
        _ relation: FamilyRelation, content: ContentCatalog
    ) -> String {
        familyRelatives(names: content.names)
            .first { $0.relation == relation }?.name ?? relation.displayName
    }

    /// Why a divorce would be refused today, or `nil` when it would land.
    public var familyDivorceRefusal: String? {
        if life.family.stage == .single { return "There is nobody to divorce." }
        if familyDrama.isDivorced { return "You have done this already." }
        return nil
    }

    /// Why filing for custody would be refused, or `nil`.
    public func familyCustodyRefusal(balance: BalanceConfig) -> String? {
        if life.family.children.isEmpty { return "There are no children to be about." }
        if familyDrama.custodyCaseID != nil { return "It is already listed." }
        if crime.pendingCase != nil { return "You are already in one court." }
        if life.wallet < balance.familyDrama.custodyFilingFee {
            return "The filing fee is \(balance.familyDrama.custodyFilingFee.crimeMoney)."
        }
        return nil
    }

    /// What the custody hearing would open on today, for the button.
    public func familyCustodyStanding(balance: BalanceConfig) -> Double {
        FamilyDrama.custodyStanding(
            children: life.family.children,
            affairDiscovered: interactions.affairDiscoveredDay != nil,
            lawyer: crime.pendingCase?.lawyer ?? .dutySolicitor,
            balance: balance.familyDrama
        )
    }
}

extension FamilyAsk {
    /// The line the ask arrives as, on the phone.
    func askLine(name: String) -> String {
        switch self {
        case .job: "any jobs going at \(name)? asking for me"
        case .stake: "been thinking. we should talk about the paperwork"
        case .loan: "awkward one. can you call me when you're free"
        }
    }
}
